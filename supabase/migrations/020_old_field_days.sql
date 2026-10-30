-- Fixes after testing, round 3.
--
-- "Field days not ended" counted every field day still 'working' from an
-- earlier date (get_stats_today, 017), but Today's field days only listed the
-- requested date, so the admin saw a 1 on the tile with nothing to act on.
-- Called without a date (the dashboard), get_today_field_days now also returns
-- the earlier field days that were never ended, as 'not_ended', so the list
-- and the tile agree and the admin can end them (admin_end_field_day takes
-- any work date). Called with a date, nothing changes.

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

  select coalesce(jsonb_agg(to_jsonb(r) order by r.work_date desc, r.technician_name), '[]'::jsonb)
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
        or (p_date is null
            and fd.status = 'working'
            and fd.work_date < public.ph_today())
  ) r;
  return result;
end;
$$;

revoke execute on function public.get_today_field_days(date) from public, anon;
grant execute on function public.get_today_field_days(date) to authenticated;
