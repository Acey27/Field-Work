-- Phase 5: weekly masterlist and export tracking.

create or replace function public.weekly_masterlist(p_week_start date)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  profile public.profiles;
  result jsonb;
begin
  profile := public.require_active_user();
  if not public.is_admin() then
    raise exception 'E_FORBIDDEN';
  end if;
  if p_week_start <> public.ph_week_start(p_week_start) then
    raise exception 'E_WEEK_NOT_MONDAY';
  end if;

  select coalesce(jsonb_agg(to_jsonb(rows)
    order by rows.technician_code, rows.field_name, rows.worker_id), '[]'::jsonb)
    into result
  from (
    select p.id as technician_id,
           p.code as technician_code,
           p.full_name as technician_name,
           f.id as field_id,
           f.name as field_name,
           f.location as field_location,
           f.address as field_address,
           w.id as worker_id,
           w.name as worker_name,
           sum(case when s.work_date = p_week_start
                    then case when s.time_out is null then 0
                              else floor(extract(epoch from (s.time_out - s.time_in)) / 60)::int
                         end end)::int as mon_minutes,
           sum(case when s.work_date = p_week_start + 1
                    then case when s.time_out is null then 0
                              else floor(extract(epoch from (s.time_out - s.time_in)) / 60)::int
                         end end)::int as tue_minutes,
           sum(case when s.work_date = p_week_start + 2
                    then case when s.time_out is null then 0
                              else floor(extract(epoch from (s.time_out - s.time_in)) / 60)::int
                         end end)::int as wed_minutes,
           sum(case when s.work_date = p_week_start + 3
                    then case when s.time_out is null then 0
                              else floor(extract(epoch from (s.time_out - s.time_in)) / 60)::int
                         end end)::int as thu_minutes,
           sum(case when s.work_date = p_week_start + 4
                    then case when s.time_out is null then 0
                              else floor(extract(epoch from (s.time_out - s.time_in)) / 60)::int
                         end end)::int as fri_minutes,
           sum(case when s.work_date = p_week_start + 5
                    then case when s.time_out is null then 0
                              else floor(extract(epoch from (s.time_out - s.time_in)) / 60)::int
                         end end)::int as sat_minutes,
           sum(case when s.work_date = p_week_start + 6
                    then case when s.time_out is null then 0
                              else floor(extract(epoch from (s.time_out - s.time_in)) / 60)::int
                         end end)::int as sun_minutes,
           sum(case when s.time_out is null then 0
                    else floor(extract(epoch from (s.time_out - s.time_in)) / 60)::int
               end)::int as total_minutes,
           count(distinct s.work_date)::int as present_days
      from public.attendance_sessions s
      join public.profiles p on p.id = s.technician_id
      join public.fields f on f.id = s.field_id
      join public.workers w on w.id = s.worker_id
     where s.work_date between p_week_start and p_week_start + 6
     group by p.id, p.code, p.full_name, f.id, f.name, f.location,
              f.address, w.id, w.name
  ) rows;
  return result;
end;
$$;

create or replace function public.get_unended_field_days(p_week_start date)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  profile public.profiles;
  result jsonb;
begin
  profile := public.require_active_user();
  if not public.is_admin() then
    raise exception 'E_FORBIDDEN';
  end if;
  if p_week_start <> public.ph_week_start(p_week_start) then
    raise exception 'E_WEEK_NOT_MONDAY';
  end if;

  select coalesce(jsonb_agg(to_jsonb(rows)
    order by rows.work_date, rows.technician_code), '[]'::jsonb)
    into result
  from (
    select fd.id as field_day_id,
           fd.work_date,
           p.code as technician_code,
           p.full_name as technician_name,
           f.name as field_name,
           (select count(*) from public.attendance_sessions s
             where s.field_day_id = fd.id and s.time_out is null)::int
             as clocked_in_count
      from public.field_days fd
      join public.profiles p on p.id = fd.technician_id
      join public.fields f on f.id = fd.field_id
     where fd.work_date between p_week_start and p_week_start + 6
       and fd.status = 'working'
  ) rows;
  return result;
end;
$$;

create or replace function public.record_weekly_export(
  p_week_start date,
  p_file_name text,
  p_row_count int
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
  profile public.profiles;
  export_id uuid;
begin
  profile := public.require_active_user();
  if not public.is_admin() then
    raise exception 'E_FORBIDDEN';
  end if;
  if p_week_start <> public.ph_week_start(p_week_start) then
    raise exception 'E_WEEK_NOT_MONDAY';
  end if;
  insert into public.weekly_exports(week_start, exported_by, file_name, row_count)
  values (p_week_start, profile.id, nullif(trim(p_file_name), ''), p_row_count)
  returning id into export_id;
  insert into public.audit_logs(actor_id, actor_role, action, table_name, record_id, meta)
  values (profile.id, profile.role::text, 'weekly_masterlist_export',
          'weekly_exports', export_id::text,
          jsonb_build_object('week_start', p_week_start,
                             'file_name', p_file_name,
                             'row_count', p_row_count));
  return jsonb_build_object('id', export_id, 'week_start', p_week_start);
end;
$$;

create or replace function public.mark_weekly_export_changed()
returns trigger
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
  affected_date date;
begin
  affected_date := case when tg_op = 'DELETE' then old.work_date else new.work_date end;
  update public.weekly_exports
     set changed_after_export = true,
         changed_at = now()
   where id = (
     select e.id
       from public.weekly_exports e
      where e.week_start = affected_date
      order by e.exported_at desc
      limit 1
   )
     and exported_at < now();
  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

drop trigger if exists attendance_sessions_mark_export_changed
  on public.attendance_sessions;
create trigger attendance_sessions_mark_export_changed
after insert or update or delete on public.attendance_sessions
for each row execute function public.mark_weekly_export_changed();

revoke execute on function public.weekly_masterlist(date) from public, anon;
revoke execute on function public.get_unended_field_days(date) from public, anon;
revoke execute on function public.record_weekly_export(date, text, int) from public, anon;
grant execute on function public.weekly_masterlist(date) to authenticated;
grant execute on function public.get_unended_field_days(date) to authenticated;
grant execute on function public.record_weekly_export(date, text, int) to authenticated;
