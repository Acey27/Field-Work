-- Takeover rule checks (migration 019). Run the WHOLE script in the Supabase
-- SQL editor of the DEV project, after migrations 012 to 019 are applied.
--
-- It pretends to be two technicians scanning the same worker through
-- ingest_scans, inside one transaction, and ends with ROLLBACK, so nothing is
-- kept. A failed check stops the script with an error that starts with FAIL.
-- If you see the last SELECT, everything passed.
--
-- Needs: at least one active admin (or super admin) and TWO active technicians.
-- Do not run it close to midnight Philippine time (dates are checked).
--
-- The rule: technician 2 may take over a worker whom technician 1 left clocked
-- in, once. After that only technician 2 can clock the worker out; a scan by
-- technician 1 is refused (blocked_held_elsewhere). When technician 2 clocks
-- the worker out, anyone can clock them in again.

begin;

create temp table t_fx (k text primary key, v text) on commit drop;

create function pg_temp.fx(p_key text) returns text
language sql as $$ select v from t_fx where k = p_key $$;

-- Sign in as this profile for the rest of the transaction.
create function pg_temp.as_user(p_id uuid) returns void
language sql as $$
  select set_config(
    'request.jwt.claims',
    json_build_object('sub', p_id, 'role', 'authenticated', 'aal', 'aal2')::text,
    true)
$$;

create function pg_temp.ensure(p_ok boolean, p_msg text) returns void
language plpgsql as $$
begin
  if p_ok is not true then raise exception 'FAIL: %', p_msg; end if;
end $$;

-- One scan of the test worker by one technician; returns the server's result.
-- Scans are minutes apart, so the 30-second repeat rule never applies.
create function pg_temp.scan(p_tech text, p_minutes int) returns text
language plpgsql as $$
declare
  at_time timestamptz :=
    date_trunc('minute', now()) - interval '90 minutes' + make_interval(mins => p_minutes);
  res jsonb;
begin
  perform pg_temp.as_user(pg_temp.fx(p_tech)::uuid);
  res := public.ingest_scans(
    pg_temp.fx(p_tech || '_device')::uuid,
    at_time,
    jsonb_build_array(jsonb_build_object(
      'scan_id', gen_random_uuid(),
      'worker_id', pg_temp.fx('worker'),
      'qr_check', 'abc',
      'field_id', pg_temp.fx('field'),
      'scanned_at', at_time)));
  return res -> 'results' -> 0 ->> 'result';
end $$;

create function pg_temp.open_sessions() returns int
language sql as $$
  select count(*)::int from public.attendance_sessions
   where worker_id = pg_temp.fx('worker') and time_out is null
$$;

create function pg_temp.holder() returns text
language sql as $$
  select technician_id::text from public.attendance_sessions
   where worker_id = pg_temp.fx('worker') and time_out is null
$$;

create function pg_temp.notices(p_tech text) returns int
language sql as $$
  select count(*)::int from public.notifications
   where recipient_id = pg_temp.fx(p_tech)::uuid
     and type = 'worker_clocked_out'
     and params ->> 'worker_id' = pg_temp.fx('worker')
$$;

-- ------------------------------------------------------------------ setup
do $$
declare
  admin_id uuid;
  tech_1 uuid;
  tech_2 uuid;
  field_id uuid;
  worker_id text;
  device_1 uuid := gen_random_uuid();
  device_2 uuid := gen_random_uuid();
begin
  select id into admin_id from public.profiles
   where role in ('admin', 'super_admin') and active limit 1;
  select id into tech_1 from public.profiles
   where role = 'technician' and active order by id limit 1;
  select id into tech_2 from public.profiles
   where role = 'technician' and active and id <> tech_1 order by id limit 1;
  if admin_id is null or tech_1 is null or tech_2 is null then
    raise exception 'Need an active admin and two active technicians';
  end if;
  update public.profiles set must_change_password = false
   where id in (admin_id, tech_1, tech_2);

  insert into public.fields (name) values ('ZZ Takeover Field') returning id into field_id;
  insert into public.workers (name, qr_check) values ('ZZ Takeover Worker', 'abc')
    returning id into worker_id;

  -- Both technicians work in this field since three hours ago, each with one
  -- approved phone. The real assignments and phones come back on ROLLBACK.
  update public.field_assignments set unassigned_at = now()
   where technician_id in (tech_1, tech_2) and unassigned_at is null;
  insert into public.field_assignments (technician_id, field_id, assigned_at, assigned_by)
  values (tech_1, field_id, now() - interval '3 hours', admin_id),
         (tech_2, field_id, now() - interval '3 hours', admin_id);
  update public.devices set status = 'revoked'
   where technician_id in (tech_1, tech_2) and status = 'approved';
  insert into public.devices (technician_id, device_uuid, label, status, approved_by, approved_at)
  values (tech_1, device_1, 'ZZ phone 1', 'approved', admin_id, now()),
         (tech_2, device_2, 'ZZ phone 2', 'approved', admin_id, now());

  insert into t_fx values
    ('tech_1', tech_1::text), ('tech_2', tech_2::text),
    ('tech_1_device', device_1::text), ('tech_2_device', device_2::text),
    ('field', field_id::text), ('worker', worker_id);
end $$;

-- ------------------------------------------------------------------ checks
do $$
begin
  -- 1. Technician 1 clocks the worker in.
  perform pg_temp.ensure(pg_temp.scan('tech_1', 0) = 'clocked_in',
    'technician 1 clocks the worker in');
  perform pg_temp.ensure(pg_temp.open_sessions() = 1 and pg_temp.holder() = pg_temp.fx('tech_1'),
    'technician 1 holds the worker');
  perform pg_temp.ensure(
    not (select taken_over from public.attendance_sessions
          where worker_id = pg_temp.fx('worker') and time_out is null),
    'a normal clock in is not a takeover');

  -- 2. Technician 2 takes the worker over (the safety net, once).
  perform pg_temp.ensure(pg_temp.scan('tech_2', 5) = 'clocked_in',
    'technician 2 takes the worker over');
  perform pg_temp.ensure(pg_temp.open_sessions() = 1 and pg_temp.holder() = pg_temp.fx('tech_2'),
    'technician 2 holds the worker, and only one session is open');
  perform pg_temp.ensure(
    (select taken_over from public.attendance_sessions
      where worker_id = pg_temp.fx('worker') and time_out is null),
    'the takeover session is marked taken_over');
  perform pg_temp.ensure(
    (select closed_by::text from public.attendance_sessions
      where worker_id = pg_temp.fx('worker') and technician_id = pg_temp.fx('tech_1')::uuid)
      = 'safety_net',
    'technician 1''s session was closed by the safety net');
  perform pg_temp.ensure(pg_temp.notices('tech_1') = 1,
    'technician 1 got the Worker clocked out notice');

  -- 3. Technician 1 scans again: refused, nothing changes.
  perform pg_temp.ensure(pg_temp.scan('tech_1', 10) = 'blocked_held_elsewhere',
    'technician 1 cannot take the worker back');
  perform pg_temp.ensure(pg_temp.open_sessions() = 1 and pg_temp.holder() = pg_temp.fx('tech_2'),
    'technician 2 still holds the worker after the refused scan');
  perform pg_temp.ensure(
    (select count(*) from public.attendance_sessions
      where worker_id = pg_temp.fx('worker') and technician_id = pg_temp.fx('tech_1')::uuid) = 1,
    'the refused scan opened no session for technician 1');
  perform pg_temp.ensure(
    (select count(*) from public.scans
      where worker_id = pg_temp.fx('worker')
        and technician_id = pg_temp.fx('tech_1')::uuid
        and result = 'blocked_held_elsewhere' and session_id is null) = 1,
    'the refused scan is saved with its result and no session');
  perform pg_temp.ensure(pg_temp.notices('tech_1') = 1,
    'a refused scan sends no second notice');

  -- 4. Only technician 2 can clock the worker out.
  perform pg_temp.ensure(pg_temp.scan('tech_2', 15) = 'clocked_out',
    'technician 2 clocks the worker out');
  perform pg_temp.ensure(pg_temp.open_sessions() = 0, 'nobody holds the worker now');

  -- 5. Now anyone can clock the worker in again.
  perform pg_temp.ensure(pg_temp.scan('tech_1', 20) = 'clocked_in',
    'technician 1 can clock the worker in once technician 2 clocked them out');
  perform pg_temp.ensure(pg_temp.holder() = pg_temp.fx('tech_1'),
    'technician 1 holds the worker again');
  perform pg_temp.ensure(
    not (select taken_over from public.attendance_sessions
          where worker_id = pg_temp.fx('worker') and time_out is null),
    'that clock in is a normal one, not a takeover');

  -- 6. A takeover is possible again from a normal session.
  perform pg_temp.ensure(pg_temp.scan('tech_2', 25) = 'clocked_in',
    'technician 2 can take over from a normal session');
  perform pg_temp.ensure(pg_temp.scan('tech_1', 30) = 'blocked_held_elsewhere',
    'and technician 1 is refused again');
  perform pg_temp.ensure(pg_temp.open_sessions() = 1 and pg_temp.holder() = pg_temp.fx('tech_2'),
    'technician 2 holds the worker at the end');

  -- 7. Ending the field day frees the worker for everyone.
  perform pg_temp.as_user(pg_temp.fx('tech_2')::uuid);
  perform public.end_field_day(
    pg_temp.fx('tech_2_device')::uuid, public.ph_today(), date_trunc('minute', now()));
  perform pg_temp.ensure(pg_temp.open_sessions() = 0,
    'End field day by the holder closes the taken-over session');
end $$;

select 'takeover.sql: all checks passed' as result;

rollback;
