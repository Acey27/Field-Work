-- Phase 4 admin checks. Run the WHOLE script in the Supabase SQL editor of the
-- DEV project, after migrations 012 to 018 are applied.
--
-- It pretends to be an admin (and a technician) by setting the sign-in claims
-- inside one transaction, creates its own test fields and workers, and ends
-- with ROLLBACK, so nothing is kept. A failed check stops the script with an
-- error that starts with FAIL. If you see the last SELECT, everything passed.
--
-- Needs: at least one active admin (or super admin) and one active technician.
-- Do not run it close to midnight Philippine time (dates are checked).

begin;

-- ---------------------------------------------------------------- helpers
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

-- Run a statement and require that it fails with exactly this error code.
create function pg_temp.expect_error(p_sql text, p_code text) returns void
language plpgsql as $$
declare got text;
begin
  begin
    execute p_sql;
    got := null;
  exception when others then
    got := sqlerrm;
  end;
  if got is distinct from p_code then
    raise exception 'FAIL: expected % but got %. SQL: %',
      p_code, coalesce(got, 'no error'), p_sql;
  end if;
end $$;

-- A Philippine local date and time as a timestamptz.
create function pg_temp.ph(p_date date, p_time time) returns timestamptz
language sql as $$ select (p_date + p_time) at time zone 'Asia/Manila' $$;

-- ------------------------------------------------------------------ setup
do $$
declare
  admin_id uuid;
  tech_id uuid;
  field_a uuid;
  field_b uuid;
  worker_1 text;
  worker_2 text;
begin
  select id into admin_id from public.profiles
   where role in ('admin', 'super_admin') and active limit 1;
  select id into tech_id from public.profiles
   where role = 'technician' and active limit 1;
  if admin_id is null or tech_id is null then
    raise exception 'Need an active admin and an active technician';
  end if;
  -- The sign-in rule needs a finished first login (CONTRACT.md 1.7).
  update public.profiles set must_change_password = false
   where id in (admin_id, tech_id);

  insert into public.fields (name) values ('ZZ Test Field A') returning id into field_a;
  insert into public.fields (name) values ('ZZ Test Field B') returning id into field_b;
  insert into public.workers (name, qr_check) values ('ZZ Test Worker 1', 'abc')
    returning id into worker_1;
  insert into public.workers (name, qr_check) values ('ZZ Test Worker 2', 'abc')
    returning id into worker_2;

  insert into t_fx values
    ('admin', admin_id::text), ('tech', tech_id::text),
    ('field_a', field_a::text), ('field_b', field_b::text),
    ('w1', worker_1), ('w2', worker_2);
end $$;

-- ------------------------------------- 1. roles: a technician is refused
do $$
declare tech uuid := pg_temp.fx('tech')::uuid;
begin
  perform pg_temp.as_user(tech);
  perform pg_temp.expect_error('select public.get_today_field_days()', 'E_FORBIDDEN');
  perform pg_temp.expect_error('select public.get_stats_today()', 'E_FORBIDDEN');
  perform pg_temp.expect_error(
    'select public.get_stats_week(public.ph_week_start(public.ph_today()))', 'E_FORBIDDEN');
  perform pg_temp.expect_error('select public.get_flagged_items()', 'E_FORBIDDEN');
  perform pg_temp.expect_error('select public.get_sessions_for_date()', 'E_FORBIDDEN');
  perform pg_temp.expect_error(
    format('select public.get_paper_sheet(%L)', tech), 'E_FORBIDDEN');
  perform pg_temp.expect_error(
    format('select public.admin_set_technician_active(%L, false)', tech), 'E_FORBIDDEN');
  perform pg_temp.expect_error(
    $q$select public.import_workers('[]'::jsonb, false)$q$, 'E_FORBIDDEN');
  perform pg_temp.expect_error(
    format('select public.admin_assign_field(%L, %L)', tech, pg_temp.fx('field_a')),
    'E_FORBIDDEN');
end $$;

-- ---------------------- 2. today's field days and the manual End field day
do $$
declare
  admin uuid := pg_temp.fx('admin')::uuid;
  tech uuid := pg_temp.fx('tech')::uuid;
  fld uuid := pg_temp.fx('field_a')::uuid;
  w1 text := pg_temp.fx('w1');
  today date := public.ph_today();
  fd uuid;
  result jsonb;
  row_json jsonb;
begin
  perform pg_temp.as_user(admin);

  insert into public.field_days (technician_id, field_id, work_date, status)
  values (tech, fld, today, 'working')
  on conflict (technician_id, work_date) do update
    set status = 'working', ended_at = null, field_id = excluded.field_id
  returning id into fd;
  insert into public.attendance_sessions
    (worker_id, technician_id, field_id, field_day_id, work_date, time_in)
  values (w1, tech, fld, fd, today, date_trunc('minute', now()) - interval '5 minutes');

  -- "Not ended" is computed from the reminder time (CONTRACT.md 4.9).
  update public.settings set value = '"00:00"' where key = 'reminder_time';
  select r into row_json from jsonb_array_elements(public.get_today_field_days()) r
   where r->>'field_day_id' = fd::text;
  perform pg_temp.ensure(row_json->>'status' = 'not_ended',
    'after the reminder time a working field day is not_ended');
  perform pg_temp.ensure((row_json->>'clocked_in_count')::int >= 1,
    'clocked_in_count counts the open session');
  perform pg_temp.ensure(row_json->'last_sync_at' is not null and row_json->'worked_count' is not null,
    'last_sync_at and worked_count are returned');

  update public.settings set value = '"23:59"' where key = 'reminder_time';
  if public.ph_time_of_day(now()) < time '23:58' then
    select r into row_json from jsonb_array_elements(public.get_today_field_days()) r
     where r->>'field_day_id' = fd::text;
    perform pg_temp.ensure(row_json->>'status' = 'working',
      'before the reminder time it is working');
  end if;

  perform pg_temp.ensure(
    (public.suggest_end_time(tech, today))->'time' is not null, 'suggest_end_time returns a time key');

  -- Errors (CONTRACT.md 4.8).
  perform pg_temp.expect_error(
    format('select public.admin_end_field_day(%L,%L,%L,%L)', tech, today, now(), 'ab'),
    'E_REASON_REQUIRED');
  perform pg_temp.expect_error(
    format('select public.admin_end_field_day(%L,%L,%L,%L)',
           tech, today, now() + interval '1 hour', 'test end'),
    'E_TIME_IN_FUTURE');
  perform pg_temp.expect_error(
    format('select public.admin_end_field_day(%L,%L,%L,%L)',
           tech, today, now() - interval '1 day', 'test end'),
    'E_DATE_MISMATCH');
  perform pg_temp.expect_error(
    format('select public.admin_end_field_day(%L,%L,%L,%L)',
           gen_random_uuid(), today, now(), 'test end'),
    'E_FIELD_DAY_NOT_FOUND');

  result := public.admin_end_field_day(tech, today, date_trunc('minute', now()), 'test end');
  perform pg_temp.ensure((result->>'closed_count')::int >= 1, 'the open session was closed');
  perform pg_temp.ensure(
    (select status::text from public.field_days where id = fd) = 'ended'
    and (select end_method::text from public.field_days where id = fd) = 'admin',
    'the field day is ended by admin');
  perform pg_temp.ensure(
    (select closed_by::text from public.attendance_sessions
      where field_day_id = fd and worker_id = w1) = 'admin',
    'the session was closed by admin');
  select r into row_json from jsonb_array_elements(public.get_today_field_days()) r
   where r->>'field_day_id' = fd::text;
  perform pg_temp.ensure(row_json->>'status' = 'ended', 'the list shows ended');
  perform pg_temp.ensure(
    exists (select 1 from public.audit_logs
             where action = 'field_day_ended_manually' and record_id = fd::text),
    'the manual End field day is in the audit log');
end $$;

-- ------------- 2b. a field day from an earlier date that was never ended
-- The tile "Field days not ended" counts it, so the dashboard list (called
-- without a date) must show it too, and ending it clears both (migration 020).
do $$
declare
  admin uuid := pg_temp.fx('admin')::uuid;
  tech uuid := pg_temp.fx('tech')::uuid;
  fld uuid := pg_temp.fx('field_b')::uuid;
  y date := public.ph_today() - 3;
  fd uuid;
  before_count int;
  after_count int;
  row_json jsonb;
begin
  perform pg_temp.as_user(admin);
  before_count := (public.get_stats_today()->>'field_days_not_ended')::int;

  insert into public.field_days (technician_id, field_id, work_date, status)
  values (tech, fld, y, 'working')
  on conflict (technician_id, work_date) do update
    set status = 'working', ended_at = null, field_id = excluded.field_id
  returning id into fd;

  after_count := (public.get_stats_today()->>'field_days_not_ended')::int;
  -- It may already have been counted if the technician had an unended day then.
  perform pg_temp.ensure(after_count >= before_count and after_count >= 1,
    'an unended earlier day counts in field_days_not_ended');

  select r into row_json from jsonb_array_elements(public.get_today_field_days()) r
   where r->>'field_day_id' = fd::text;
  perform pg_temp.ensure(row_json is not null,
    'the dashboard list shows the unended earlier day');
  perform pg_temp.ensure(row_json->>'status' = 'not_ended'
    and row_json->>'work_date' = y::text, 'it is not_ended with its own date');

  -- Asking for a specific date still returns only that date.
  perform pg_temp.ensure(
    not exists (select 1 from jsonb_array_elements(
                  public.get_today_field_days(public.ph_today())) r
                 where r->>'field_day_id' = fd::text),
    'a dated request does not include other days');

  perform public.admin_end_field_day(tech, y, pg_temp.ph(y, '17:00'), 'test end');
  select r into row_json from jsonb_array_elements(public.get_today_field_days()) r
   where r->>'field_day_id' = fd::text;
  perform pg_temp.ensure(row_json is null,
    'an ended earlier day is no longer in the dashboard list');
  perform pg_temp.ensure(
    (public.get_stats_today()->>'field_days_not_ended')::int = after_count - 1,
    'ending it lowers field_days_not_ended by one');
end $$;

-- --------------------------------- 3. manual time records and their fixes
do $$
declare
  admin uuid := pg_temp.fx('admin')::uuid;
  tech uuid := pg_temp.fx('tech')::uuid;
  fld uuid := pg_temp.fx('field_a')::uuid;
  w1 text := pg_temp.fx('w1');
  w2 text := pg_temp.fx('w2');
  y date := public.ph_today() - 1;
  first_id uuid;
  second_id uuid;
  before_week jsonb;
  after_week jsonb;
  monday date := public.ph_week_start(public.ph_today() - 1);
  idx int := (public.ph_today() - 1 - public.ph_week_start(public.ph_today() - 1));
begin
  perform pg_temp.as_user(admin);
  before_week := public.get_stats_week(monday);

  first_id := ((public.admin_add_time_record(w1, fld, tech, y,
    pg_temp.ph(y, '08:00'), pg_temp.ph(y, '09:00'), 'paper sheet'))->>'session_id')::uuid;
  perform pg_temp.ensure(first_id is not null, 'a manual record is added');

  -- Back to back is fine, overlapping is not.
  second_id := ((public.admin_add_time_record(w1, fld, tech, y,
    pg_temp.ph(y, '09:00'), pg_temp.ph(y, '10:00'), 'paper sheet'))->>'session_id')::uuid;
  perform pg_temp.ensure(second_id is not null, 'back to back records are allowed');
  perform pg_temp.expect_error(
    format('select public.admin_add_time_record(%L,%L,%L,%L,%L,%L,%L)', w1, fld, tech, y,
           pg_temp.ph(y, '08:30'), pg_temp.ph(y, '09:30'), 'paper sheet'),
    'E_OVERLAP');
  -- Another worker may have the same hours.
  perform public.admin_add_time_record(w2, fld, tech, y,
    pg_temp.ph(y, '08:30'), pg_temp.ph(y, '09:30'), 'paper sheet');

  perform pg_temp.expect_error(
    format('select public.admin_add_time_record(%L,%L,%L,%L,%L,%L,%L)', w1, fld, tech, y,
           pg_temp.ph(y, '12:00'), pg_temp.ph(y, '11:00'), 'paper sheet'),
    'E_TIME_OUT_BEFORE_IN');
  perform pg_temp.expect_error(
    format('select public.admin_add_time_record(%L,%L,%L,%L,%L,%L,%L)', w1, fld, tech, y,
           pg_temp.ph(y, '23:00'), pg_temp.ph(y + 1, '01:00'), 'paper sheet'),
    'E_DATE_MISMATCH');
  perform pg_temp.expect_error(
    format('select public.admin_add_time_record(%L,%L,%L,%L,%L,%L,%L)', w1, fld, tech,
           public.ph_today() + 1, pg_temp.ph(public.ph_today() + 1, '08:00'),
           pg_temp.ph(public.ph_today() + 1, '09:00'), 'paper sheet'),
    'E_TIME_IN_FUTURE');
  perform pg_temp.expect_error(
    format('select public.admin_add_time_record(%L,%L,%L,%L,%L,%L,%L)', w1, fld, tech, y,
           pg_temp.ph(y, '13:00'), pg_temp.ph(y, '14:00'), 'x'),
    'E_REASON_REQUIRED');
  perform pg_temp.expect_error(
    format('select public.admin_add_time_record(%L,%L,%L,%L,%L,%L,%L)', 'W-99999', fld, tech, y,
           pg_temp.ph(y, '13:00'), pg_temp.ph(y, '14:00'), 'paper sheet'),
    'E_SESSION_NOT_FOUND');

  -- The day list marks them "Entered by admin" (CONTRACT.md 10.3).
  perform pg_temp.ensure(
    (select count(*) from jsonb_array_elements(public.get_sessions_for_date(y)) r
      where r->>'worker_id' = w1 and (r->>'entered_by_admin')::boolean) = 2,
    'both records show Entered by admin');

  -- Statistics read the same sessions: 2 more workers present and
  -- 3 sessions of 60 minutes = 180 more minutes.
  after_week := public.get_stats_week(monday);
  perform pg_temp.ensure(
    (after_week->'days'->idx->>'workers_present')::int
      - (before_week->'days'->idx->>'workers_present')::int = 2,
    'the week shows 2 more workers present');
  perform pg_temp.ensure(
    (after_week->'days'->idx->>'total_minutes')::int
      - (before_week->'days'->idx->>'total_minutes')::int = 180,
    'the week shows 180 more minutes');

  -- Fix a record.
  perform public.admin_fix_time_record(first_id, pg_temp.ph(y, '07:00'),
    pg_temp.ph(y, '08:30'), 'wrong time on paper');
  perform pg_temp.ensure(
    (select time_in = pg_temp.ph(y, '07:00') and time_out = pg_temp.ph(y, '08:30')
       from public.attendance_sessions where id = first_id),
    'the record was fixed');
  perform pg_temp.expect_error(
    format('select public.admin_fix_time_record(%L,%L,%L,%L)', first_id,
           pg_temp.ph(y, '07:00'), pg_temp.ph(y, '09:30'), 'wrong time'),
    'E_OVERLAP');
  perform pg_temp.expect_error(
    format('select public.admin_fix_time_record(%L,%L,%L,%L)', first_id,
           pg_temp.ph(y - 1, '07:00'), pg_temp.ph(y - 1, '08:00'), 'wrong date'),
    'E_DATE_MISMATCH');
  perform pg_temp.expect_error(
    format('select public.admin_fix_time_record(%L,%L,%L,%L)', gen_random_uuid(),
           pg_temp.ph(y, '07:00'), pg_temp.ph(y, '08:00'), 'missing'),
    'E_SESSION_NOT_FOUND');
  perform pg_temp.ensure(
    exists (select 1 from public.audit_logs
             where action = 'time_record_fixed' and record_id = first_id::text),
    'the fix is in the audit log');
end $$;

-- ----------------- 4. fields, assignment (one step) and technician on/off
do $$
declare
  admin uuid := pg_temp.fx('admin')::uuid;
  tech uuid := pg_temp.fx('tech')::uuid;
  field_a uuid := pg_temp.fx('field_a')::uuid;
  field_b uuid := pg_temp.fx('field_b')::uuid;
  result jsonb;
begin
  perform pg_temp.as_user(admin);

  perform public.admin_update_field(field_a, 'ZZ Renamed Field', 'Echague', 'Purok 1');
  perform pg_temp.ensure(
    (select name = 'ZZ Renamed Field' and location = 'Echague' and address = 'Purok 1'
       from public.fields where id = field_a), 'a field can be edited');
  perform pg_temp.expect_error(
    format('select public.admin_update_field(%L, %L)', field_a, '  '), 'E_FIELD_NAME_MISSING');
  perform pg_temp.expect_error(
    format('select public.admin_update_field(%L, %L)', gen_random_uuid(), 'x'),
    'E_FIELD_NOT_FOUND');

  -- The field functions return jsonb (migration 018).
  result := public.admin_create_field('  ZZ Created Field ', 'Echague', null);
  perform pg_temp.ensure(
    jsonb_typeof(result) = 'object' and result->>'name' = 'ZZ Created Field'
    and (result->>'active')::boolean, 'a field can be added and comes back as jsonb');
  perform pg_temp.expect_error(
    $q$select public.admin_create_field('   ')$q$, 'E_FIELD_NAME_MISSING');
  result := public.admin_set_field_active((result->>'id')::uuid, false);
  perform pg_temp.ensure(not (result->>'active')::boolean, 'a field can be turned off');
  result := public.admin_set_field_active((result->>'id')::uuid, true);
  perform pg_temp.ensure((result->>'active')::boolean, 'a field can be turned on again');
  perform pg_temp.expect_error(
    format('select public.admin_set_field_active(%L, false)', gen_random_uuid()),
    'E_FIELD_NOT_FOUND');
  perform pg_temp.ensure(
    exists (select 1 from public.audit_logs
             where action = 'field_created' and after->>'name' = 'ZZ Created Field'),
    'adding a field is in the audit log');

  result := public.admin_assign_field(tech, field_a);
  perform pg_temp.ensure((result->>'changed')::boolean, 'first assignment changes');
  result := public.admin_assign_field(tech, field_b);
  perform pg_temp.ensure((result->>'changed')::boolean, 'a new field changes the assignment');
  perform pg_temp.ensure(
    (select count(*) from public.field_assignments
      where technician_id = tech and unassigned_at is null) = 1
    and (select field_id from public.field_assignments
          where technician_id = tech and unassigned_at is null) = field_b,
    'exactly one current assignment, the new field');
  result := public.admin_assign_field(tech, field_b);
  perform pg_temp.ensure(not (result->>'changed')::boolean, 'the same field changes nothing');
  perform pg_temp.expect_error(
    format('select public.admin_assign_field(%L, %L)', tech, gen_random_uuid()),
    'E_FIELD_NOT_FOUND');

  -- Turning a technician off blocks them and revokes the approved phone.
  perform public.admin_set_technician_active(tech, false);
  perform pg_temp.ensure(
    (select not active from public.profiles where id = tech), 'the technician is off');
  perform pg_temp.ensure(
    not exists (select 1 from public.devices
                 where technician_id = tech and status = 'approved'),
    'approved phones were revoked');
  perform public.admin_set_technician_active(tech, true);
  perform pg_temp.ensure(
    (select active from public.profiles where id = tech), 'the technician is on again');
  perform pg_temp.ensure(
    exists (select 1 from public.audit_logs
             where action = 'account_disabled' and record_id = tech::text),
    'turning off is in the audit log');
end $$;

-- ----------------------------------------- 5. CSV import with 2,000 rows
do $$
declare
  admin uuid := pg_temp.fx('admin')::uuid;
  all_rows jsonb;
  chunk jsonb;
  res jsonb;
  c int;
  valid_total int := 0;
  inserted_total int := 0;
  dup_total int := 0;
  bad jsonb;
  codes text[];
begin
  perform pg_temp.as_user(admin);
  select jsonb_agg(jsonb_build_object(
           'row', i + 1, 'name', 'ZZ Import ' || i, 'cp_no', '0917' || i,
           'address', 'Echague')
         order by i)
    into all_rows from generate_series(1, 2000) i;

  -- Preview in chunks of 500, like the app (CONTRACT.md 4.14).
  for c in 0..3 loop
    select jsonb_agg(e order by n) into chunk
      from jsonb_array_elements(all_rows) with ordinality t(e, n)
     where n > c * 500 and n <= (c + 1) * 500;
    res := public.import_workers(chunk, false);
    valid_total := valid_total + (res->>'valid')::int;
    perform pg_temp.ensure((res->>'inserted')::int = 0, 'a preview inserts nothing');
  end loop;
  perform pg_temp.ensure(valid_total = 2000, '2,000 rows are valid in the preview');
  perform pg_temp.ensure(
    (select count(*) from public.workers where name like 'ZZ Import %') = 0,
    'the preview saved no workers');

  for c in 0..3 loop
    select jsonb_agg(e order by n) into chunk
      from jsonb_array_elements(all_rows) with ordinality t(e, n)
     where n > c * 500 and n <= (c + 1) * 500;
    res := public.import_workers(chunk, true);
    inserted_total := inserted_total + (res->>'inserted')::int;
  end loop;
  perform pg_temp.ensure(inserted_total = 2000, '2,000 workers were added');
  perform pg_temp.ensure(
    (select count(*) from public.workers where name like 'ZZ Import %') = 2000,
    '2,000 workers exist');

  -- The same file again: every row is a possible duplicate (the same name).
  for c in 0..3 loop
    select jsonb_agg(e order by n) into chunk
      from jsonb_array_elements(all_rows) with ordinality t(e, n)
     where n > c * 500 and n <= (c + 1) * 500;
    res := public.import_workers(chunk, false);
    dup_total := dup_total + jsonb_array_length(res->'duplicates');
  end loop;
  perform pg_temp.ensure(dup_total = 2000, 'every repeated row is a duplicate warning');

  -- A confirmed duplicate is added (allow_duplicate).
  res := public.import_workers(
    jsonb_build_array(all_rows->0 || '{"allow_duplicate": true}'::jsonb), true);
  perform pg_temp.ensure((res->>'inserted')::int = 1, 'a confirmed duplicate is inserted');

  -- Bad rows get a code and never stop the others. Gender and date of birth
  -- are not used any more (migration 018), so a leftover value is just ignored.
  -- A repeated name is a duplicate whatever its case or spaces.
  bad := jsonb_build_array(
    jsonb_build_object('row', 2, 'name', ''),
    jsonb_build_object('row', 3, 'name', '  zz IMPORT 5 '),
    jsonb_build_object('row', 4, 'name', repeat('x', 300)),
    jsonb_build_object('row', 5, 'name', 'ZZ Good Row'),
    jsonb_build_object('row', 6, 'name', 'ZZ Ignored Extras',
                       'gender', 'robot', 'date_of_birth', 'not a date'));
  res := public.import_workers(bad, false);
  select array_agg(e->>'code' order by (e->>'row')::int)
    into codes from jsonb_array_elements(res->'errors') e;
  perform pg_temp.ensure(
    codes = array['E_CSV_NAME_MISSING', 'E_CSV_ROW_TOO_LONG'],
    'each bad row has its own error code, got ' || coalesce(codes::text, 'none'));
  perform pg_temp.ensure(
    jsonb_array_length(res->'duplicates') = 1
    and (res->'duplicates'->0->>'row')::int = 3,
    'a name that differs only by case and spaces is a duplicate');
  perform pg_temp.ensure((res->>'valid')::int = 2,
    'the good rows are still valid, and gender / date of birth are ignored');
end $$;

-- ------------------- 6. statistics, flagged list, paper sheet, settings
do $$
declare
  admin uuid := pg_temp.fx('admin')::uuid;
  tech uuid := pg_temp.fx('tech')::uuid;
  today_stats jsonb;
  week jsonb;
  sheet jsonb;
begin
  perform pg_temp.as_user(admin);

  today_stats := public.get_stats_today();
  perform pg_temp.ensure(
    today_stats->'clocked_in_now' is not null and today_stats->'finished' is not null
    and today_stats->'technicians_working' is not null and today_stats->'fields_working' is not null
    and today_stats->'field_days_not_ended' is not null, 'get_stats_today has all five numbers');

  perform pg_temp.expect_error(
    format('select public.get_stats_week(%L)', public.ph_week_start(public.ph_today()) + 1),
    'E_WEEK_NOT_MONDAY');
  week := public.get_stats_week(public.ph_week_start(public.ph_today()));
  perform pg_temp.ensure(jsonb_array_length(week->'days') = 7, 'a week has 7 days');
  perform pg_temp.ensure(
    week->'totals'->'workers_present' is not null and week->'previous'->'total_minutes' is not null
    and jsonb_typeof(week->'attendance_by_field') = 'array',
    'the week has totals, the previous week and per-field numbers');

  perform pg_temp.ensure(
    jsonb_typeof(public.get_flagged_items(public.ph_today() - 30, public.ph_today())) = 'array',
    'the flagged list is a list (bursts included)');
  perform pg_temp.ensure(
    jsonb_typeof(public.get_flagged_items()) = 'array', 'the flagged list has defaults');

  sheet := public.get_paper_sheet(tech, public.ph_today());
  perform pg_temp.ensure(
    sheet->'technician'->>'id' = tech::text and jsonb_typeof(sheet->'workers') = 'array',
    'the paper sheet has the technician and a workers list');
  -- Worker 1 only has time records with this technician (sections 2 and 3
  -- wrote them without a scan), so only the records can list them (018).
  perform pg_temp.ensure(
    exists (select 1 from jsonb_array_elements(sheet->'workers') x
             where x->>'id' = pg_temp.fx('w1')),
    'the paper sheet lists a worker who only has a time record');
  perform pg_temp.ensure(
    not exists (select 1 from jsonb_array_elements(sheet->'workers') x
                 where x->>'time_in' is not null or x->>'time_out' is not null),
    'the paper sheet leaves the time boxes to be written by hand');
  perform pg_temp.expect_error(
    format('select public.get_paper_sheet(%L)', gen_random_uuid()), 'E_FIELD_DAY_NOT_FOUND');

  -- Settings (see also settings.sql).
  perform public.admin_set_setting('reminder_repeat_minutes', '45'::jsonb);
  perform pg_temp.expect_error(
    $q$select public.admin_set_setting('reminder_repeat_minutes', '3'::jsonb)$q$,
    'E_SETTING_INVALID');
  perform pg_temp.expect_error(
    $q$select public.admin_set_setting('reminder_time', '"99:99"'::jsonb)$q$,
    'E_SETTING_INVALID');
end $$;

-- ------------------------------------ 7. the safety-net notice (018)
-- ingest_scans closes the first technician's session with closed_by =
-- 'safety_net' when a second technician scans the worker. That close tells the
-- first technician (type worker_clocked_out). Their own scan tells nobody.
do $$
declare
  tech uuid := pg_temp.fx('tech')::uuid;
  fld uuid := pg_temp.fx('field_a')::uuid;
  today date := public.ph_today();
  w3 text;
  fd uuid;
  s1 uuid;
  s2 uuid;
  before_count int;
  note record;
begin
  select id into fd from public.field_days
   where technician_id = tech and work_date = today;
  insert into public.workers (name, qr_check) values ('ZZ Test Worker 3', 'abc')
    returning id into w3;
  select count(*) into before_count from public.notifications
   where recipient_id = tech and type = 'worker_clocked_out';

  insert into public.attendance_sessions
    (worker_id, technician_id, field_id, field_day_id, work_date, time_in)
  values (w3, tech, fld, fd, today, date_trunc('minute', now()) - interval '20 minutes')
  returning id into s1;
  update public.attendance_sessions
     set time_out = date_trunc('minute', now()) - interval '15 minutes', closed_by = 'scan'
   where id = s1;
  perform pg_temp.ensure(
    (select count(*) from public.notifications
      where recipient_id = tech and type = 'worker_clocked_out') = before_count,
    'a technician''s own scan sends no notice');

  insert into public.attendance_sessions
    (worker_id, technician_id, field_id, field_day_id, work_date, time_in)
  values (w3, tech, fld, fd, today, date_trunc('minute', now()) - interval '10 minutes')
  returning id into s2;
  update public.attendance_sessions
     set time_out = date_trunc('minute', now()) - interval '5 minutes',
         closed_by = 'safety_net'
   where id = s2;

  perform pg_temp.ensure(
    (select count(*) from public.notifications
      where recipient_id = tech and type = 'worker_clocked_out') = before_count + 1,
    'a safety-net close sends exactly one notice to the first technician');
  select * into note from public.notifications
   where recipient_id = tech and type = 'worker_clocked_out'
   order by created_at desc, id limit 1;
  perform pg_temp.ensure(
    note.params->>'worker_id' = w3 and note.params->>'worker_name' = 'ZZ Test Worker 3'
    and note.params->>'reason' = 'safety_net' and note.read_at is null,
    'the notice holds data only: worker, reason, unread');

  -- A later fix of the same record does not send it again.
  update public.attendance_sessions
     set time_out = date_trunc('minute', now()) - interval '4 minutes'
   where id = s2;
  perform pg_temp.ensure(
    (select count(*) from public.notifications
      where recipient_id = tech and type = 'worker_clocked_out') = before_count + 1,
    'fixing the time later sends no second notice');
end $$;

select 'admin.sql: all checks passed' as result;

rollback;
