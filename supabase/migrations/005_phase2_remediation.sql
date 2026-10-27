create or replace function public.get_login_state()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'role', role::text,
    'must_change_password', must_change_password
  )
  from public.profiles
  where id = auth.uid() and active = true;
$$;

create or replace function public.get_my_context(p_device_uuid uuid)
returns jsonb
language plpgsql
volatile
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

drop policy if exists profiles_admin_write on public.profiles;
drop policy if exists profiles_select on public.profiles;
drop policy if exists workers_admin_all on public.workers;
drop policy if exists assignments_admin_all on public.field_assignments;
drop policy if exists fields_admin_all on public.fields;
drop policy if exists devices_admin_write on public.devices;
drop policy if exists field_days_admin_write on public.field_days;
drop policy if exists scans_owner_insert on public.scans;
drop policy if exists sessions_admin_write on public.attendance_sessions;
drop policy if exists exports_admin_all on public.weekly_exports;
drop policy if exists settings_super_write on public.settings;

create policy profiles_select on public.profiles for select to authenticated
using ((id = auth.uid() and active and not must_change_password) or public.is_admin());

create policy workers_admin_select on public.workers for select to authenticated
using (public.is_admin());
create policy workers_admin_insert_update on public.workers
for insert to authenticated with check (public.is_admin());
create policy workers_admin_update on public.workers
for update to authenticated using (public.is_admin()) with check (public.is_admin());

create policy assignments_admin_insert_update on public.field_assignments
for insert to authenticated with check (public.is_admin());
create policy assignments_admin_update on public.field_assignments
for update to authenticated using (public.is_admin()) with check (public.is_admin());
create policy assignments_admin_select on public.field_assignments
for select to authenticated using (public.is_admin());

create policy fields_admin_select on public.fields for select to authenticated
using (public.is_admin());
create policy fields_admin_insert on public.fields
for insert to authenticated with check (public.is_admin());
create policy fields_admin_update on public.fields
for update to authenticated using (public.is_admin()) with check (public.is_admin());
create policy fields_admin_delete on public.fields
for delete to authenticated
using (
  public.is_admin()
  and not exists (
    select 1 from public.attendance_sessions
    where field_id = fields.id
  )
  and not exists (
    select 1 from public.field_days
    where field_id = fields.id
  )
);

create policy exports_admin_select on public.weekly_exports for select to authenticated
using (public.is_admin());

revoke insert, update, delete on public.profiles from authenticated;
revoke insert, update, delete on public.devices from authenticated;
revoke insert, update, delete on public.field_days from authenticated;
revoke insert, update, delete on public.scans from authenticated;
revoke insert, update, delete on public.attendance_sessions from authenticated;
revoke insert, update, delete on public.weekly_exports from authenticated;
revoke insert, update, delete on public.settings from authenticated;
revoke delete on public.workers from authenticated;
revoke delete on public.field_assignments from authenticated;

revoke execute on function public.get_login_state() from public, anon;
grant execute on function public.get_login_state() to authenticated;
