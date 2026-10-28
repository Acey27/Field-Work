-- Phase 4 completion, part 1: Today's field days and manual End field day,
-- aligned with CONTRACT.md sections 4.8 and 4.9.
-- Replaces the draft admin_today_field_days() and admin_end_field_day(uuid, text).

drop function if exists public.admin_today_field_days();
drop function if exists public.admin_end_field_day(uuid, text);

create or replace function public.get_today_field_days(p_date date default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  profile public.profiles;
  target_date date;
  reminder time;
  result jsonb;
begin
  profile := public.require_active_user();
  if not public.is_admin() then
    raise exception 'E_FORBIDDEN';
  end if;
  target_date := coalesce(p_date, public.ph_today());
  select (value #>> '{}')::time into reminder
    from public.settings where key = 'reminder_time';
  reminder := coalesce(reminder, time '17:00');

  select coalesce(jsonb_agg(to_jsonb(r) order by r.technician_name), '[]'::jsonb)
    into result
  from (
    select fd.id as field_day_id,
           fd.work_date,
           p.id as technician_id,
           p.code as technician_code,
           p.full_name as technician_name,
           f.id as field_id,
           f.name as field_name,
           case
             when fd.status = 'ended' then 'ended'
             when fd.work_date < public.ph_today()
               or (fd.work_date = public.ph_today()
                   and public.ph_time_of_day(now()) >= reminder)
               then 'not_ended'
             else 'working'
           end as status,
           fd.ended_at,
           (select count(*) from public.attendance_sessions s
             where s.field_day_id = fd.id and s.time_out is null) as clocked_in_count,
           (select count(distinct s.worker_id) from public.attendance_sessions s
             where s.field_day_id = fd.id) as worked_count,
           (select max(d.last_sync_at) from public.devices d
             where d.technician_id = p.id) as last_sync_at
      from public.field_days fd
      join public.profiles p on p.id = fd.technician_id
      join public.fields f on f.id = fd.field_id
     where fd.work_date = target_date
  ) r;
  return result;
end;
$$;

create or replace function public.suggest_end_time(
  p_technician_id uuid,
  p_work_date date
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  profile public.profiles;
  last_scan timestamptz;
begin
  profile := public.require_active_user();
  if not public.is_admin() then
    raise exception 'E_FORBIDDEN';
  end if;
  select max(scanned_at) into last_scan
    from public.scans
   where technician_id = p_technician_id
     and public.ph_date(scanned_at) = p_work_date
     and result in ('clocked_in', 'clocked_out');
  return jsonb_build_object(
    'time', case when last_scan is null then null
                 else date_trunc('minute', last_scan) end);
end;
$$;

create or replace function public.admin_end_field_day(
  p_technician_id uuid,
  p_work_date date,
  p_ended_at timestamptz,
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
  day public.field_days;
  ended_minute timestamptz;
  closed_count integer;
begin
  profile := public.require_active_user();
  if not public.is_admin() then
    raise exception 'E_FORBIDDEN';
  end if;
  if length(trim(coalesce(p_reason, ''))) < 3 then
    raise exception 'E_REASON_REQUIRED';
  end if;
  if p_ended_at is null then
    raise exception 'E_TIME_OUT_BEFORE_IN';
  end if;
  ended_minute := date_trunc('minute', p_ended_at);
  if ended_minute > now() then
    raise exception 'E_TIME_IN_FUTURE';
  end if;
  if public.ph_date(ended_minute) <> p_work_date then
    raise exception 'E_DATE_MISMATCH';
  end if;

  select * into day from public.field_days
   where technician_id = p_technician_id and work_date = p_work_date
   for update;
  if day.id is null then
    raise exception 'E_FIELD_DAY_NOT_FOUND';
  end if;

  update public.attendance_sessions
     set time_out = ended_minute, closed_by = 'admin'
   where field_day_id = day.id
     and time_out is null
     and time_in <= ended_minute;
  get diagnostics closed_count = row_count;

  update public.field_days
     set status = 'ended', ended_at = ended_minute,
         ended_by = profile.id, end_method = 'admin'
   where id = day.id;

  insert into public.audit_logs(actor_id, actor_role, action, table_name,
    record_id, before, after, reason)
  values (profile.id, profile.role::text, 'field_day_ended_manually',
    'field_days', day.id::text, to_jsonb(day),
    jsonb_build_object('status', 'ended', 'ended_at', ended_minute,
      'closed_count', closed_count),
    p_reason);

  return jsonb_build_object('field_day_id', day.id,
    'closed_count', closed_count, 'ended_at', ended_minute);
end;
$$;

revoke execute on function public.get_today_field_days(date) from public, anon;
revoke execute on function public.suggest_end_time(uuid, date) from public, anon;
revoke execute on function public.admin_end_field_day(uuid, date, timestamptz, text)
  from public, anon;
grant execute on function public.get_today_field_days(date) to authenticated;
grant execute on function public.suggest_end_time(uuid, date) to authenticated;
grant execute on function public.admin_end_field_day(uuid, date, timestamptz, text)
  to authenticated;
