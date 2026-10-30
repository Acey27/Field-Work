-- Phase 5 masterlist regression test. Run after migration 021 in the DEV project.
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
  day_1 uuid;
  day_2 uuid;
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
end
$$;

rollback;
