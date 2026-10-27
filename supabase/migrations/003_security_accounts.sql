create or replace function public.ping()
returns jsonb
language sql
stable
as $$
  select jsonb_build_object('now', now());
$$;

create or replace function public.app_role()
returns public.app_role
language sql
stable
security definer
set search_path = public
as $$
  select role from public.profiles
  where id = auth.uid() and active = true
  limit 1;
$$;

create or replace function public.require_active_user()
returns public.profiles
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  current_profile public.profiles;
begin
  select * into current_profile
  from public.profiles
  where id = auth.uid();

  if current_profile.id is null or not current_profile.active then
    raise exception 'E_ACCOUNT_DISABLED';
  end if;
  if current_profile.must_change_password then
    raise exception 'E_MUST_CHANGE_PASSWORD';
  end if;
  return current_profile;
end;
$$;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.app_role() in ('admin', 'super_admin');
$$;

create or replace function public.is_super_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.app_role() = 'super_admin';
$$;

create or replace function public.register_device(
  p_device_uuid uuid,
  p_label text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  current_profile public.profiles;
  existing_device public.devices;
  device_status public.device_status;
  device_id uuid;
begin
  current_profile := public.require_active_user();
  if current_profile.role <> 'technician' then
    raise exception 'E_FORBIDDEN';
  end if;

  select * into existing_device
  from public.devices
  where technician_id = current_profile.id and device_uuid = p_device_uuid;

  if existing_device.id is not null then
    update public.devices
    set last_seen_at = now(), label = coalesce(nullif(trim(p_label), ''), label)
    where id = existing_device.id
    returning id, status into device_id, device_status;
    return jsonb_build_object('device_id', device_id, 'status', device_status::text);
  end if;

  if exists (
    select 1 from public.devices
    where technician_id = current_profile.id and status = 'approved'
  ) then
    device_status := 'pending';
  else
    device_status := 'approved';
  end if;

  insert into public.devices (technician_id, device_uuid, label, status, approved_by, approved_at)
  values (
    current_profile.id, p_device_uuid, nullif(trim(p_label), ''), device_status,
    case when device_status = 'approved' then current_profile.id end,
    case when device_status = 'approved' then now() end
  )
  returning id into device_id;

  if device_status = 'pending' then
    insert into public.notifications (recipient_id, type, params, target)
    select id, 'device_approval_needed',
      jsonb_build_object('technician_id', current_profile.id, 'device_id', device_id),
      'devices'
    from public.profiles
    where role in ('admin', 'super_admin') and active;
  end if;

  return jsonb_build_object('device_id', device_id, 'status', device_status::text);
end;
$$;

create or replace function public.approve_device(p_device_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  current_profile public.profiles;
  selected_device public.devices;
begin
  current_profile := public.require_active_user();
  if current_profile.role not in ('admin', 'super_admin') then
    raise exception 'E_FORBIDDEN';
  end if;

  select * into selected_device from public.devices where id = p_device_id for update;
  if selected_device.id is null then
    raise exception 'E_DEVICE_NOT_FOUND';
  end if;

  update public.devices
  set status = 'revoked'
  where technician_id = selected_device.technician_id
    and status = 'approved'
    and id <> p_device_id;

  update public.devices
  set status = 'approved', approved_by = current_profile.id, approved_at = now()
  where id = p_device_id;

  return jsonb_build_object('device_id', p_device_id, 'status', 'approved');
end;
$$;

create or replace function public.revoke_device(p_device_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  current_profile public.profiles;
begin
  current_profile := public.require_active_user();
  if current_profile.role not in ('admin', 'super_admin') then
    raise exception 'E_FORBIDDEN';
  end if;
  update public.devices set status = 'revoked' where id = p_device_id;
  if not found then
    raise exception 'E_DEVICE_NOT_FOUND';
  end if;
  return jsonb_build_object('device_id', p_device_id, 'status', 'revoked');
end;
$$;

create or replace function public.get_my_context(p_device_uuid uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  current_profile public.profiles;
  current_device public.devices;
  current_assignment public.field_assignments;
  current_field public.fields;
begin
  current_profile := public.require_active_user();
  if current_profile.role <> 'technician' then
    raise exception 'E_FORBIDDEN';
  end if;

  select * into current_device from public.devices
  where technician_id = current_profile.id and device_uuid = p_device_uuid;
  if current_device.id is null then
    raise exception 'E_DEVICE_NOT_APPROVED';
  end if;
  if current_device.status = 'pending' then
    raise exception 'E_DEVICE_PENDING';
  end if;
  if current_device.status = 'revoked' then
    raise exception 'E_DEVICE_REVOKED';
  end if;

  update public.devices set last_seen_at = now() where id = current_device.id;

  select * into current_assignment from public.field_assignments
  where technician_id = current_profile.id
    and unassigned_at is null
  order by assigned_at desc
  limit 1;
  if current_assignment.id is not null then
    select * into current_field from public.fields where id = current_assignment.field_id;
  end if;

  return jsonb_build_object(
    'profile', jsonb_build_object(
      'id', current_profile.id, 'code', current_profile.code,
      'full_name', current_profile.full_name
    ),
    'field', case when current_field.id is null then null else jsonb_build_object(
      'id', current_field.id, 'name', current_field.name,
      'location', current_field.location
    ) end,
    'device', jsonb_build_object('status', current_device.status::text),
    'settings', coalesce((
      select jsonb_object_agg(key, value) from public.settings
      where key in ('scan_hours_start', 'scan_hours_end', 'reminder_time')
    ), '{}'::jsonb),
    'server_time', now()
  );
end;
$$;

do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'profiles', 'workers', 'fields', 'field_assignments', 'devices',
    'field_days', 'scans', 'attendance_sessions', 'weekly_exports',
    'settings', 'audit_logs', 'notifications'
  ]
  loop
    execute format('alter table public.%I enable row level security', table_name);
  end loop;
end;
$$;

create policy profiles_select on public.profiles for select to authenticated
using (id = auth.uid() or public.is_admin());
create policy profiles_admin_write on public.profiles for all to authenticated
using (public.is_admin()) with check (public.is_admin());

create policy workers_admin_all on public.workers for all to authenticated
using (public.is_admin()) with check (public.is_admin());
create policy fields_admin_all on public.fields for all to authenticated
using (public.is_admin()) with check (public.is_admin());
create policy assignments_admin_all on public.field_assignments for all to authenticated
using (public.is_admin()) with check (public.is_admin());

create policy devices_owner_or_admin on public.devices for select to authenticated
using (technician_id = auth.uid() or public.is_admin());
create policy devices_admin_write on public.devices for all to authenticated
using (public.is_admin()) with check (public.is_admin());

create policy field_days_owner_or_admin on public.field_days for select to authenticated
using (technician_id = auth.uid() or public.is_admin());
create policy field_days_admin_write on public.field_days for all to authenticated
using (public.is_admin()) with check (public.is_admin());

create policy scans_owner_or_admin on public.scans for select to authenticated
using (technician_id = auth.uid() or public.is_admin());
create policy scans_owner_insert on public.scans for insert to authenticated
with check (technician_id = auth.uid() or public.is_admin());

create policy sessions_owner_or_admin on public.attendance_sessions for select to authenticated
using (technician_id = auth.uid() or public.is_admin());
create policy sessions_admin_write on public.attendance_sessions for all to authenticated
using (public.is_admin()) with check (public.is_admin());

create policy exports_admin_all on public.weekly_exports for all to authenticated
using (public.is_admin()) with check (public.is_admin());
create policy settings_admin_select on public.settings for select to authenticated
using (public.is_admin());
create policy settings_super_write on public.settings for all to authenticated
using (public.is_super_admin()) with check (public.is_super_admin());
create policy audit_super_select on public.audit_logs for select to authenticated
using (public.is_super_admin());
create policy notifications_recipient on public.notifications for select to authenticated
using (recipient_id = auth.uid() or public.is_admin());
create policy notifications_recipient_update on public.notifications for update to authenticated
using (recipient_id = auth.uid() or public.is_admin())
with check (recipient_id = auth.uid() or public.is_admin());

revoke all on all tables in schema public from anon;
revoke all on all tables in schema public from authenticated;
grant select on public.profiles, public.devices, public.field_days,
  public.scans, public.attendance_sessions, public.notifications to authenticated;
grant select, insert, update, delete on public.workers, public.fields,
  public.field_assignments, public.weekly_exports to authenticated;
grant select on public.settings to authenticated;
grant select on public.audit_logs to authenticated;

revoke execute on all functions in schema public from public, anon;
grant execute on function public.ping() to anon;
grant execute on function public.register_device(uuid, text) to authenticated;
grant execute on function public.approve_device(uuid) to authenticated;
grant execute on function public.revoke_device(uuid) to authenticated;
grant execute on function public.get_my_context(uuid) to authenticated;
