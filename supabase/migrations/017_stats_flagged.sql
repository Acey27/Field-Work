-- Phase 4 completion: statistics and the flagged list, with the names and
-- shapes from CONTRACT.md section 4.12. Replaces the draft
-- admin_statistics() and admin_flagged_scans().
-- Statistics read from attendance_sessions, not from raw scans (SPEC.md 16).
-- An open session adds 0 minutes (CONTRACT.md 2.8).

drop function if exists public.admin_statistics(date, date);
drop function if exists public.admin_flagged_scans(date, date);

-- The burst check counts one phone's scans inside a short window.
create index if not exists scans_device_scanned_idx
  on public.scans (device_id, scanned_at);

-- Today: clocked in now, finished, technicians and fields working,
-- field days not ended (SPEC.md section 11).
create or replace function public.get_stats_today()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  profile public.profiles;
  today date := public.ph_today();
  reminder time;
begin
  profile := public.require_active_user();
  if not public.is_admin() then raise exception 'E_FORBIDDEN'; end if;
  select (value #>> '{}')::time into reminder
    from public.settings where key = 'reminder_time';
  reminder := coalesce(reminder, time '17:00');

  return jsonb_build_object(
    'clocked_in_now', (
      select count(distinct worker_id) from public.attendance_sessions
       where work_date = today and time_out is null),
    'finished', (
      select count(distinct s.worker_id) from public.attendance_sessions s
       where s.work_date = today and s.time_out is not null
         and not exists (
           select 1 from public.attendance_sessions o
            where o.worker_id = s.worker_id and o.work_date = today
              and o.time_out is null)),
    'technicians_working', (
      select count(*) from public.field_days
       where work_date = today and status = 'working'),
    'fields_working', (
      select count(distinct field_id) from public.field_days
       where work_date = today and status = 'working'),
    -- Same rule as get_today_field_days: still working after the reminder
    -- time, or from an earlier date.
    'field_days_not_ended', (
      select count(*) from public.field_days
       where status = 'working'
         and (work_date < today
              or (work_date = today
                  and public.ph_time_of_day(now()) >= reminder)))
  );
end;
$$;

-- A week: workers and hours per day, attendance per field, and the totals of
-- the week before for the comparison (SPEC.md section 11).
create or replace function public.get_stats_week(p_week_start date)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  profile public.profiles;
begin
  profile := public.require_active_user();
  if not public.is_admin() then raise exception 'E_FORBIDDEN'; end if;
  if p_week_start is null or p_week_start <> public.ph_week_start(p_week_start) then
    raise exception 'E_WEEK_NOT_MONDAY';
  end if;

  return (
    with sess as (
      select work_date, worker_id, field_id,
             case when time_out is null then 0
                  else floor(extract(epoch from (time_out - time_in)) / 60)::int
             end as minutes
        from public.attendance_sessions
       where work_date between p_week_start - 7 and p_week_start + 6
    ),
    per_day as (
      select work_date, count(distinct worker_id) as present,
             sum(minutes)::int as minutes
        from sess group by work_date
    )
    select jsonb_build_object(
      'week_start', p_week_start,
      'days', (
        select jsonb_agg(jsonb_build_object(
                 'date', d::date,
                 'workers_present', coalesce(pd.present, 0),
                 'total_minutes', coalesce(pd.minutes, 0)) order by d)
          from generate_series(p_week_start::timestamp,
                               (p_week_start + 6)::timestamp,
                               interval '1 day') d
          left join per_day pd on pd.work_date = d::date),
      'attendance_by_field', coalesce((
        select jsonb_agg(jsonb_build_object(
                 'field_id', y.field_id, 'field_name', y.field_name,
                 'present_days', y.present_days,
                 'total_minutes', y.total_minutes) order by y.field_name)
          from (
            select f.id as field_id, f.name as field_name,
                   count(distinct s.worker_id || '|' || s.work_date::text)
                     as present_days,
                   coalesce(sum(s.minutes), 0)::int as total_minutes
              from sess s
              join public.fields f on f.id = s.field_id
             where s.work_date >= p_week_start
             group by f.id, f.name
          ) y), '[]'::jsonb),
      'totals', (
        select jsonb_build_object(
                 'workers_present', coalesce(sum(present), 0)::int,
                 'total_minutes', coalesce(sum(minutes), 0)::int)
          from per_day where work_date >= p_week_start),
      'previous', (
        select jsonb_build_object(
                 'workers_present', coalesce(sum(present), 0)::int,
                 'total_minutes', coalesce(sum(minutes), 0)::int)
          from per_day where work_date < p_week_start)
    )
  );
end;
$$;

-- Flagged list (SPEC.md section 17): saved flags, plus bursts computed by a
-- query (more than burst_scan_count scans from one phone within
-- burst_window_seconds). Row shape is CONTRACT.md 4.12.
create or replace function public.get_flagged_items(
  p_from date default null,
  p_to date default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  profile public.profiles;
  from_date date;
  to_date date;
  burst_count integer;
  burst_window double precision;
begin
  profile := public.require_active_user();
  if not public.is_admin() then raise exception 'E_FORBIDDEN'; end if;
  from_date := coalesce(p_from, public.ph_today());
  to_date := coalesce(p_to, from_date);
  if to_date < from_date then
    to_date := from_date;
  end if;
  select (value #>> '{}')::integer into burst_count
    from public.settings where key = 'burst_scan_count';
  burst_count := coalesce(burst_count, 10);
  select (value #>> '{}')::double precision into burst_window
    from public.settings where key = 'burst_window_seconds';
  burst_window := coalesce(burst_window, 10);

  return coalesce((
    select jsonb_agg(to_jsonb(r) order by r.at desc)
    from (
      select fl.flag as kind, s.scan_id,
             p.code as technician_code, p.full_name as technician,
             coalesce(w.name, s.submitted_worker_id) as worker,
             s.worker_id, s.scanned_at as at,
             jsonb_build_object('field_name', f.name, 'result', s.result::text,
                                'lat', s.lat, 'lng', s.lng) as detail
        from public.scans s
        cross join lateral unnest(s.flags) as fl(flag)
        join public.profiles p on p.id = s.technician_id
        join public.fields f on f.id = s.field_id
        left join public.workers w on w.id = s.worker_id
       where public.ph_date(s.scanned_at) between from_date and to_date
      union all
      select 'burst' as kind, b.scan_id,
             p.code, p.full_name,
             coalesce(w.name, b.submitted_worker_id), b.worker_id, b.scanned_at,
             jsonb_build_object('field_name', f.name, 'result', b.result::text,
                                'lat', b.lat, 'lng', b.lng)
        from (
          select s.*,
                 (select count(*) from public.scans x
                   where x.device_id = s.device_id
                     and x.scanned_at <= s.scanned_at
                     and x.scanned_at > s.scanned_at
                           - make_interval(secs => burst_window)) as burst_n
            from public.scans s
           where public.ph_date(s.scanned_at) between from_date and to_date
        ) b
        join public.profiles p on p.id = b.technician_id
        join public.fields f on f.id = b.field_id
        left join public.workers w on w.id = b.worker_id
       where b.burst_n > burst_count
    ) r
  ), '[]'::jsonb);
end;
$$;

revoke execute on function public.get_stats_today() from public, anon;
revoke execute on function public.get_stats_week(date) from public, anon;
revoke execute on function public.get_flagged_items(date, date) from public, anon;
grant execute on function public.get_stats_today() to authenticated;
grant execute on function public.get_stats_week(date) to authenticated;
grant execute on function public.get_flagged_items(date, date) to authenticated;
