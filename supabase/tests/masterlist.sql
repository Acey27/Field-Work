-- Phase 5 masterlist regression test (including the Zeann and Czar worked example). Run after migrations 021 and 022 in the DEV project.
begin;

create function pg_temp.as_user(p_id uuid) returns void
language sql as $$
  select set_config(
    'request.jwt.claims',
    json_build_object('sub', p_id, 'role', 'authenticated', 'aal', 'aal2')::text,
    true)
$$;

create function pg_temp.ensure(p_ok boolean, p_message text) returns void
language plpgsql as $$
begin
  if p_ok is not true then raise exception 'FAIL: %', p_message; end if;
end
$$;

do $$
declare
  admin_id uuid;
  tech_1 uuid;
  tech_2 uuid;
  field_1 uuid;
  field_2 uuid;
  worker_1 text;
  worker_2 text;
  monday date := date '2026-10-19';
  next_monday date := date '2026-10-26';
  day_1 uuid;
  day_2 uuid;
  wed_day uuid;
  wed_session uuid;
  export_1 uuid;
  export_2 uuid;
  export_3 uuid;
  rows jsonb;
  zeann jsonb;
  czar jsonb;
begin
  select id into admin_id from public.profiles
   where role in ('admin', 'super_admin') and active limit 1;
  select id into tech_1 from public.profiles
   where role = 'technician' and active limit 1;
  select id into tech_2 from public.profiles
   where role = 'technician' and active and id <> tech_1 limit 1;
  if admin_id is null or tech_1 is null or tech_2 is null then
    raise exception 'Need an admin and two active technicians';
  end if;
  update public.profiles set must_change_password = false
   where id in (admin_id, tech_1, tech_2);

  insert into public.fields(name) values ('ZZ Masterlist Field 1') returning id into field_1;
  insert into public.fields(name) values ('ZZ Masterlist Field 2') returning id into field_2;
  insert into public.workers(name, qr_check) values ('ZZ Masterlist Zeann', 'a11') returning id into worker_1;
  insert into public.workers(name, qr_check) values ('ZZ Masterlist Czar', 'a12') returning id into worker_2;

  insert into public.field_days(technician_id, field_id, work_date)
    values (tech_1, field_1, monday) returning id into day_1;
  insert into public.field_days(technician_id, field_id, work_date)
    values (tech_2, field_2, monday) returning id into day_2;

  -- Zeann: 333 minutes with tech 1 on Monday and 180 with tech 2 on Tuesday.
  insert into public.attendance_sessions
    (worker_id, technician_id, field_id, field_day_id, work_date, time_in, time_out)
  values
    (worker_1, tech_1, field_1, day_1, monday,
     '2026-10-19 00:00+00', '2026-10-19 05:33+00'),
    (worker_1, tech_2, field_2, day_2, monday + 1,
     '2026-10-20 00:00+00', '2026-10-20 03:00+00');

  -- Czar: an open Monday session; it is present but contributes zero minutes.
  insert into public.attendance_sessions
    (worker_id, technician_id, field_id, field_day_id, work_date, time_in)
  values (worker_2, tech_1, field_1, day_1, monday, '2026-10-19 01:00+00');

  perform pg_temp.as_user(admin_id);
  rows := public.weekly_masterlist(monday);
  select row into zeann from jsonb_array_elements(rows) row
   where row->>'worker_id' = worker_1 and row->>'technician_id' = tech_1::text;
  select row into czar from jsonb_array_elements(rows) row
   where row->>'worker_id' = worker_2 and row->>'technician_id' = tech_1::text;

  perform pg_temp.ensure(zeann->>'mon_minutes' = '333', 'Zeann Monday minutes');
  perform pg_temp.ensure(zeann->>'tue_minutes' is null, 'Zeann Tuesday is blank for tech 1');
  perform pg_temp.ensure(zeann->>'total_minutes' = '333', 'Zeann total');
  perform pg_temp.ensure(zeann->>'present_days' = '1', 'Zeann present days');
  perform pg_temp.ensure(czar->>'mon_minutes' = '0', 'open session contributes zero minutes');
  perform pg_temp.ensure(czar->>'present_days' = '1', 'open session counts as present');
  perform pg_temp.ensure(
    jsonb_array_length(rows) = 3,
    'workers are grouped by technician and field');

  perform pg_temp.ensure(
    (select count(*) from jsonb_array_elements(rows) row
      where row->>'worker_id' = worker_1 and row->>'technician_id' = tech_2::text) = 1,
    'worker appears in both technician sections');

  perform pg_temp.ensure(
    jsonb_array_length(public.get_unended_field_days(monday)) = 2,
    'unended field days are returned for the selected week');

  -- "Changed after export" (migration 022). A Wednesday session is corrected
  -- after the week was exported: that export must be marked, not only when
  -- the change falls on a Monday.
  insert into public.field_days(technician_id, field_id, work_date)
    values (tech_1, field_1, monday + 2) returning id into wed_day;
  insert into public.attendance_sessions
    (worker_id, technician_id, field_id, field_day_id, work_date, time_in, time_out)
  values (worker_1, tech_1, field_1, wed_day, monday + 2,
          '2026-10-21 00:00+00', '2026-10-21 03:00+00')
  returning id into wed_session;

  export_1 := ((public.record_weekly_export(monday, 'week-1.xlsx', 3))->>'id')::uuid;
  export_2 := ((public.record_weekly_export(next_monday, 'week-2.xlsx', 1))->>'id')::uuid;
  perform pg_temp.ensure(
    not (select changed_after_export from public.weekly_exports where id = export_1),
    'a fresh export is not marked as changed');

  perform public.admin_fix_time_record(
    wed_session, '2026-10-21 00:30+00', '2026-10-21 04:00+00', 'test fix');
  perform pg_temp.ensure(
    (select changed_after_export from public.weekly_exports where id = export_1),
    'correcting a Wednesday record marks that week as changed after export');
  perform pg_temp.ensure(
    (select changed_at is not null from public.weekly_exports where id = export_1),
    'the time of the change is saved');
  perform pg_temp.ensure(
    not (select changed_after_export from public.weekly_exports where id = export_2),
    'a change in one week does not mark another week');

  -- A second export of the same week starts clean; the next change marks only
  -- that newest export. (Inside one transaction now() is the same for every
  -- row, so the newer export is moved forward by hand.)
  export_3 := ((public.record_weekly_export(monday, 'week-1-again.xlsx', 3))->>'id')::uuid;
  update public.weekly_exports set exported_at = exported_at + interval '1 minute'
   where id = export_3;
  perform pg_temp.ensure(
    not (select changed_after_export from public.weekly_exports where id = export_3),
    'a new export of the same week starts unmarked');
  perform public.admin_fix_time_record(
    wed_session, '2026-10-21 00:15+00', '2026-10-21 04:00+00', 'test fix again');
  perform pg_temp.ensure(
    (select changed_after_export from public.weekly_exports where id = export_3),
    'the newest export of the week is marked by the next change');

  -- An update that changes nothing the masterlist shows marks nothing.
  update public.weekly_exports set changed_after_export = false, changed_at = null
   where id = export_3;
  update public.attendance_sessions set closed_by = closed_by where id = wed_session;
  perform pg_temp.ensure(
    not (select changed_after_export from public.weekly_exports where id = export_3),
    'an update that changes no time does not mark the week');
end
$$;

-- ------------------------------------------------------------------------
-- The worked example of CONTRACT.md section 11 and SPEC.md section 12:
-- Zeann and Czar with two technicians, week 14 to 20 Sep 2026. Technician 1
-- scans from 6:00 AM, technician 2 from 12:00 PM, so one worker's sessions
-- on the same date never overlap.
create function pg_temp.sess(
  p_worker text, p_tech uuid, p_field uuid, p_date date, p_minutes int, p_start time
) returns void language plpgsql as $$
declare
  fd uuid;
  t_in timestamptz;
begin
  insert into public.field_days(technician_id, field_id, work_date)
    values (p_tech, p_field, p_date)
    on conflict (technician_id, work_date) do update set field_id = excluded.field_id
    returning id into fd;
  t_in := (p_date + p_start) at time zone 'Asia/Manila';
  insert into public.attendance_sessions
    (worker_id, technician_id, field_id, field_day_id, work_date, time_in, time_out)
  values (p_worker, p_tech, p_field, fd, p_date, t_in,
          t_in + make_interval(mins => p_minutes));
end $$;

-- One section row must have exactly these minutes (Monday to Sunday, null for
-- a blank day), total and present days.
create function pg_temp.check_row(
  p_rows jsonb, p_worker text, p_tech uuid, p_days int[], p_total int, p_present int, p_label text
) returns void language plpgsql as $$
declare r jsonb;
begin
  select x into r from jsonb_array_elements(p_rows) x
   where x->>'worker_id' = p_worker and x->>'technician_id' = p_tech::text;
  if r is null then raise exception 'FAIL: % is missing from the masterlist', p_label; end if;
  perform pg_temp.ensure(
    array[(r->>'mon_minutes')::int, (r->>'tue_minutes')::int, (r->>'wed_minutes')::int,
          (r->>'thu_minutes')::int, (r->>'fri_minutes')::int, (r->>'sat_minutes')::int,
          (r->>'sun_minutes')::int] is not distinct from p_days,
    p_label || ': day minutes');
  perform pg_temp.ensure((r->>'total_minutes')::int = p_total, p_label || ': total');
  perform pg_temp.ensure((r->>'present_days')::int = p_present, p_label || ': present days');
end $$;

do $$
declare
  admin_id uuid;
  tech_1 uuid;
  tech_2 uuid;
  field_1 uuid;
  field_2 uuid;
  zeann text;
  czar text;
  mon date := date '2026-09-14';
  six time := time '06:00';
  noon time := time '12:00';
  rows jsonb;
begin
  select id into admin_id from public.profiles
   where role in ('admin', 'super_admin') and active limit 1;
  select id into tech_1 from public.profiles
   where role = 'technician' and active order by id limit 1;
  select id into tech_2 from public.profiles
   where role = 'technician' and active and id <> tech_1 order by id limit 1;
  insert into public.fields(name) values ('ZZ Example Field 1') returning id into field_1;
  insert into public.fields(name) values ('ZZ Example Field 2') returning id into field_2;
  insert into public.workers(name, qr_check) values ('ZZ Example Zeann', 'b11') returning id into zeann;
  insert into public.workers(name, qr_check) values ('ZZ Example Czar', 'b12') returning id into czar;

  -- T-00001: Zeann Mon 333, Tue 300, Thu 370, Fri 300, Sun 320.
  perform pg_temp.sess(zeann, tech_1, field_1, mon, 333, six);
  perform pg_temp.sess(zeann, tech_1, field_1, mon + 1, 300, six);
  perform pg_temp.sess(zeann, tech_1, field_1, mon + 3, 370, six);
  perform pg_temp.sess(zeann, tech_1, field_1, mon + 4, 300, six);
  perform pg_temp.sess(zeann, tech_1, field_1, mon + 6, 320, six);
  -- T-00001: Czar Mon 600, Thu 495, Fri 120, Sat 540.
  perform pg_temp.sess(czar, tech_1, field_1, mon, 600, six);
  perform pg_temp.sess(czar, tech_1, field_1, mon + 3, 495, six);
  perform pg_temp.sess(czar, tech_1, field_1, mon + 4, 120, six);
  perform pg_temp.sess(czar, tech_1, field_1, mon + 5, 540, six);
  -- T-00002: Zeann Tue 180, Wed 300, Sat 540.
  perform pg_temp.sess(zeann, tech_2, field_2, mon + 1, 180, noon);
  perform pg_temp.sess(zeann, tech_2, field_2, mon + 2, 300, noon);
  perform pg_temp.sess(zeann, tech_2, field_2, mon + 5, 540, noon);
  -- T-00002: Czar Tue 600, Wed 300, Fri 300, Sun 320.
  perform pg_temp.sess(czar, tech_2, field_2, mon + 1, 600, noon);
  perform pg_temp.sess(czar, tech_2, field_2, mon + 2, 300, noon);
  perform pg_temp.sess(czar, tech_2, field_2, mon + 4, 300, noon);
  perform pg_temp.sess(czar, tech_2, field_2, mon + 6, 320, noon);

  perform pg_temp.as_user(admin_id);
  rows := public.weekly_masterlist(mon);

  perform pg_temp.check_row(rows, zeann, tech_1,
    array[333, 300, null, 370, 300, null, 320], 1623, 5, 'Zeann with T-00001');
  perform pg_temp.check_row(rows, czar, tech_1,
    array[600, null, null, 495, 120, 540, null], 1755, 4, 'Czar with T-00001');
  perform pg_temp.check_row(rows, zeann, tech_2,
    array[null, 180, 300, null, null, 540, null], 1020, 3, 'Zeann with T-00002');
  perform pg_temp.check_row(rows, czar, tech_2,
    array[null, 600, 300, null, 300, null, 320], 1520, 4, 'Czar with T-00002');

  -- Rule 3: a worker one technician never scanned all week is not in that
  -- technician's section (only these two workers are in the example week).
  perform pg_temp.ensure(
    (select count(*) from jsonb_array_elements(rows) x
      where x->>'worker_id' in (zeann, czar)) = 4,
    'four section rows: two workers with two technicians each');
  perform pg_temp.ensure(
    not exists (select 1 from jsonb_array_elements(rows) x
                 where x ? 'pay' or x ? 'pay_amount'),
    'there is no pay in the masterlist data');
end
$$;

rollback;
