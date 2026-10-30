-- Phase 4 completion: manual time records with the overlap check, a day list
-- of time records ("Entered by admin"), the paper sheet data, field edit,
-- atomic field assignment, and technician on/off.
-- CONTRACT.md sections 4.8, 4.14, 17 (item 3) and SPEC.md sections 8, 10, 17.

drop function if exists public.admin_correct_session(uuid, timestamptz, timestamptz, text);

-- 1. admin_add_time_record: adds the E_OVERLAP check (CONTRACT.md 4.8) and no
--    longer moves an existing field day to another field.
create or replace function public.admin_add_time_record(
  p_worker_id text,
  p_field_id uuid,
  p_technician_id uuid,
  p_work_date date,
  p_time_in timestamptz,
  p_time_out timestamptz,
  p_reason text
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
  profile public.profiles;
  in_minute timestamptz;
  out_minute timestamptz;
  day_id uuid;
  new_session_id uuid;
begin
  profile := public.require_active_user();
  if not public.is_admin() then raise exception 'E_FORBIDDEN'; end if;
  if length(trim(coalesce(p_reason, ''))) < 3 then
    raise exception 'E_REASON_REQUIRED';
  end if;
  if p_time_in is null or p_time_out is null then
    raise exception 'E_TIME_OUT_BEFORE_IN';
  end if;
  in_minute := date_trunc('minute', p_time_in);
  out_minute := date_trunc('minute', p_time_out);
  if out_minute <= in_minute then raise exception 'E_TIME_OUT_BEFORE_IN'; end if;
  if public.ph_date(in_minute) <> public.ph_date(out_minute)
     or public.ph_date(in_minute) <> p_work_date then
    raise exception 'E_DATE_MISMATCH';
  end if;
  if out_minute > now() then raise exception 'E_TIME_IN_FUTURE'; end if;
  if not exists (select 1 from public.workers where id = p_worker_id) then
    raise exception 'E_SESSION_NOT_FOUND';
  end if;
  if exists (
    select 1 from public.attendance_sessions s
     where s.worker_id = p_worker_id
       and s.time_in < out_minute
       and coalesce(s.time_out, 'infinity'::timestamptz) > in_minute
  ) then
    raise exception 'E_OVERLAP';
  end if;

  insert into public.field_days (technician_id, field_id, work_date)
  values (p_technician_id, p_field_id, p_work_date)
  on conflict (technician_id, work_date)
    do update set technician_id = excluded.technician_id
  returning id into day_id;

  insert into public.attendance_sessions (
    worker_id, technician_id, field_id, field_day_id, work_date,
    time_in, time_out, entered_by_admin, manual_reason, closed_by
  ) values (
    p_worker_id, p_technician_id, p_field_id, day_id, p_work_date,
    in_minute, out_minute, true, trim(p_reason), 'admin'
  ) returning id into new_session_id;

  insert into public.audit_logs (actor_id, actor_role, action, table_name,
    record_id, after, reason)
  values (profile.id, profile.role::text, 'time_record_added',
    'attendance_sessions', new_session_id::text,
    jsonb_build_object('worker_id', p_worker_id, 'time_in', in_minute,
                       'time_out', out_minute),
    trim(p_reason));
  return jsonb_build_object('session_id', new_session_id);
end;
$$;

-- 2. admin_fix_time_record (CONTRACT.md 4.8): change the times of one record.
create or replace function public.admin_fix_time_record(
  p_session_id uuid,
  p_time_in timestamptz,
  p_time_out timestamptz,
  p_reason text
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
  profile public.profiles;
  current_session public.attendance_sessions;
  in_minute timestamptz;
  out_minute timestamptz;
begin
  profile := public.require_active_user();
  if not public.is_admin() then raise exception 'E_FORBIDDEN'; end if;
  if length(trim(coalesce(p_reason, ''))) < 3 then
    raise exception 'E_REASON_REQUIRED';
  end if;
  if p_time_in is null or p_time_out is null then
    raise exception 'E_TIME_OUT_BEFORE_IN';
  end if;
  in_minute := date_trunc('minute', p_time_in);
  out_minute := date_trunc('minute', p_time_out);
  if out_minute <= in_minute then raise exception 'E_TIME_OUT_BEFORE_IN'; end if;
  if out_minute > now() then raise exception 'E_TIME_IN_FUTURE'; end if;

  select * into current_session
    from public.attendance_sessions where id = p_session_id for update;
  if current_session.id is null then raise exception 'E_SESSION_NOT_FOUND'; end if;
  if public.ph_date(in_minute) <> current_session.work_date
     or public.ph_date(out_minute) <> current_session.work_date then
    raise exception 'E_DATE_MISMATCH';
  end if;
  if exists (
    select 1 from public.attendance_sessions s
     where s.worker_id = current_session.worker_id
       and s.id <> current_session.id
       and s.time_in < out_minute
       and coalesce(s.time_out, 'infinity'::timestamptz) > in_minute
  ) then
    raise exception 'E_OVERLAP';
  end if;

  update public.attendance_sessions
     set time_in = in_minute, time_out = out_minute,
         entered_by_admin = true, manual_reason = trim(p_reason),
         closed_by = 'admin'
   where id = p_session_id;

  insert into public.audit_logs (actor_id, actor_role, action, table_name,
    record_id, before, after, reason)
  values (profile.id, profile.role::text, 'time_record_fixed',
    'attendance_sessions', p_session_id::text,
    jsonb_build_object('time_in', current_session.time_in,
                       'time_out', current_session.time_out),
    jsonb_build_object('time_in', in_minute, 'time_out', out_minute),
    trim(p_reason));
  return jsonb_build_object('session_id', p_session_id);
end;
$$;

-- 3. get_sessions_for_date: the day's time records for the admin screen,
--    with the "Entered by admin" mark (CONTRACT.md 10.3).
create or replace function public.get_sessions_for_date(p_date date default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  profile public.profiles;
  target date;
begin
  profile := public.require_active_user();
  if not public.is_admin() then raise exception 'E_FORBIDDEN'; end if;
  target := coalesce(p_date, public.ph_today());
  return coalesce((
    select jsonb_agg(to_jsonb(r) order by r.worker_name, r.time_in)
      from (
        select s.id as session_id, s.worker_id, w.name as worker_name,
               p.id as technician_id, p.code as technician_code,
               p.full_name as technician_name,
               f.id as field_id, f.name as field_name,
               s.work_date, s.time_in, s.time_out, s.closed_by::text as closed_by,
               s.entered_by_admin, s.manual_reason
          from public.attendance_sessions s
          join public.workers w on w.id = s.worker_id
          join public.profiles p on p.id = s.technician_id
          join public.fields f on f.id = s.field_id
         where s.work_date = target
      ) r
  ), '[]'::jsonb);
end;
$$;

-- 4. get_paper_sheet: data for the printable daily sheet (SPEC.md section 8).
--    The "usual workers" are those the technician scanned in the last 14 days
--    (CONTRACT.md section 17, item 3).
create or replace function public.get_paper_sheet(
  p_technician_id uuid,
  p_date date default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  profile public.profiles;
  tech public.profiles;
  target date;
  sheet_field public.fields;
begin
  profile := public.require_active_user();
  if not public.is_admin() then raise exception 'E_FORBIDDEN'; end if;
  target := coalesce(p_date, public.ph_today());

  select * into tech from public.profiles
   where id = p_technician_id and role = 'technician';
  if tech.id is null then raise exception 'E_FIELD_DAY_NOT_FOUND'; end if;

  select f.* into sheet_field
    from public.field_assignments fa
    join public.fields f on f.id = fa.field_id
   where fa.technician_id = tech.id and fa.unassigned_at is null
   order by fa.assigned_at desc
   limit 1;
  if sheet_field.id is null then
    select f.* into sheet_field
      from public.field_days fd
      join public.fields f on f.id = fd.field_id
     where fd.technician_id = tech.id
     order by fd.work_date desc
     limit 1;
  end if;

  return jsonb_build_object(
    'technician', jsonb_build_object(
      'id', tech.id, 'code', tech.code, 'name', tech.full_name),
    'field', case when sheet_field.id is null then null
      else jsonb_build_object('id', sheet_field.id, 'name', sheet_field.name,
                              'location', sheet_field.location) end,
    'work_date', target,
    'workers', coalesce((
      select jsonb_agg(jsonb_build_object('id', x.id, 'name', x.name)
                       order by x.name)
        from (
          select distinct w.id, w.name
            from public.scans s
            join public.workers w on w.id = s.worker_id
           where s.technician_id = tech.id
             and s.result in ('clocked_in', 'clocked_out')
             and w.active
             and public.ph_date(s.scanned_at) between target - 14 and target
        ) x
    ), '[]'::jsonb)
  );
end;
$$;

-- 5. Fields: edit (SPEC.md section 10).
-- A previous development deployment may already have the JSONB version from
-- the post-testing fix. Drop it so this migration remains replayable; 018
-- recreates the final JSONB signature after the legacy row-returning version.
drop function if exists public.admin_update_field(uuid, text, text, text);

create or replace function public.admin_update_field(
  p_field_id uuid,
  p_name text,
  p_location text default null,
  p_address text default null
)
returns public.fields
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
  profile public.profiles;
  old_row public.fields;
  field_row public.fields;
begin
  profile := public.require_active_user();
  if not public.is_admin() then raise exception 'E_FORBIDDEN'; end if;
  if nullif(trim(p_name), '') is null then raise exception 'E_FIELD_NAME_MISSING'; end if;
  select * into old_row from public.fields where id = p_field_id for update;
  if old_row.id is null then raise exception 'E_FIELD_NOT_FOUND'; end if;
  update public.fields
     set name = trim(p_name),
         location = nullif(trim(p_location), ''),
         address = nullif(trim(p_address), '')
   where id = p_field_id
   returning * into field_row;
  insert into public.audit_logs (actor_id, actor_role, action, table_name,
    record_id, before, after)
  values (profile.id, profile.role::text, 'field_updated', 'fields',
    field_row.id::text, to_jsonb(old_row), to_jsonb(field_row));
  return field_row;
end;
$$;

-- 6. Assign a technician to a field in one step: closes the current
--    assignment and opens the new one together (CONTRACT.md 2.4).
create or replace function public.admin_assign_field(
  p_technician_id uuid,
  p_field_id uuid
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
  profile public.profiles;
  new_id uuid;
begin
  profile := public.require_active_user();
  if not public.is_admin() then raise exception 'E_FORBIDDEN'; end if;
  if not exists (select 1 from public.profiles
                  where id = p_technician_id and role = 'technician') then
    raise exception 'E_FORBIDDEN';
  end if;
  if not exists (select 1 from public.fields
                  where id = p_field_id and active) then
    raise exception 'E_FIELD_NOT_FOUND';
  end if;
  -- Already assigned to this field: nothing to do.
  if exists (select 1 from public.field_assignments
              where technician_id = p_technician_id
                and field_id = p_field_id and unassigned_at is null) then
    return jsonb_build_object('assignment_id', null, 'changed', false);
  end if;
  update public.field_assignments
     set unassigned_at = now()
   where technician_id = p_technician_id and unassigned_at is null;
  insert into public.field_assignments (technician_id, field_id, assigned_by)
  values (p_technician_id, p_field_id, profile.id)
  returning id into new_id;
  insert into public.audit_logs (actor_id, actor_role, action, table_name,
    record_id, after)
  values (profile.id, profile.role::text, 'field_assigned',
    'field_assignments', new_id::text,
    jsonb_build_object('technician_id', p_technician_id, 'field_id', p_field_id));
  return jsonb_build_object('assignment_id', new_id, 'changed', true);
end;
$$;

-- 7. Turn a technician account off or on (SPEC.md section 17: "the admin can
--    disable a technician's account right away if a phone is lost").
--    A profile with active = false can read nothing and call nothing
--    (CONTRACT.md 7). Turning one off also revokes the approved phone
--    (CONTRACT.md 5, set_account_active).
create or replace function public.admin_set_technician_active(
  p_technician_id uuid,
  p_active boolean
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
  profile public.profiles;
  target public.profiles;
  revoked_count integer := 0;
begin
  profile := public.require_active_user();
  if not public.is_admin() then raise exception 'E_FORBIDDEN'; end if;
  select * into target from public.profiles
   where id = p_technician_id and role = 'technician' for update;
  if target.id is null then raise exception 'E_FORBIDDEN'; end if;

  update public.profiles
     set active = p_active,
         deactivated_at = case when p_active then null else now() end
   where id = target.id;

  if not p_active then
    update public.devices set status = 'revoked'
     where technician_id = target.id and status = 'approved';
    get diagnostics revoked_count = row_count;
  end if;

  insert into public.audit_logs (actor_id, actor_role, action, table_name,
    record_id, after)
  values (profile.id, profile.role::text,
    case when p_active then 'account_enabled' else 'account_disabled' end,
    'profiles', target.id::text,
    jsonb_build_object('active', p_active, 'devices_revoked', revoked_count));
  return jsonb_build_object('technician_id', target.id, 'active', p_active);
end;
$$;

-- Grants: only signed-in users, and every function checks the admin role.
revoke execute on function public.admin_add_time_record(text, uuid, uuid, date, timestamptz, timestamptz, text) from public, anon;
revoke execute on function public.admin_fix_time_record(uuid, timestamptz, timestamptz, text) from public, anon;
revoke execute on function public.get_sessions_for_date(date) from public, anon;
revoke execute on function public.get_paper_sheet(uuid, date) from public, anon;
revoke execute on function public.admin_update_field(uuid, text, text, text) from public, anon;
revoke execute on function public.admin_assign_field(uuid, uuid) from public, anon;
revoke execute on function public.admin_set_technician_active(uuid, boolean) from public, anon;
grant execute on function public.admin_add_time_record(text, uuid, uuid, date, timestamptz, timestamptz, text) to authenticated;
grant execute on function public.admin_fix_time_record(uuid, timestamptz, timestamptz, text) to authenticated;
grant execute on function public.get_sessions_for_date(date) to authenticated;
grant execute on function public.get_paper_sheet(uuid, date) to authenticated;
grant execute on function public.admin_update_field(uuid, text, text, text) to authenticated;
grant execute on function public.admin_assign_field(uuid, uuid) to authenticated;
grant execute on function public.admin_set_technician_active(uuid, boolean) to authenticated;
