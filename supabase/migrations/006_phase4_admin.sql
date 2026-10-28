create or replace function public.admin_today_field_days()
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

  select coalesce(jsonb_agg(to_jsonb(rows) order by rows.full_name), '[]'::jsonb)
    into result
  from (
    select p.id as technician_id,
           p.code as technician_code,
           p.full_name,
           f.id as field_id,
           f.name as field_name,
           f.location as field_location,
           coalesce(fd.status::text, 'working') as status,
           count(s.session_id) filter (
             where s.session_id is not null
               and asess.time_out is null
           ) as open_workers,
           max(s.received_at) as last_sync_at,
           fd.ended_at
      from public.profiles p
      left join public.field_assignments fa
        on fa.technician_id = p.id and fa.unassigned_at is null
      left join public.fields f on f.id = fa.field_id
      left join public.field_days fd
        on fd.technician_id = p.id and fd.work_date = public.ph_today()
      left join public.scans s
        on s.technician_id = p.id
       and s.field_id = f.id
       and public.ph_date(s.scanned_at) = public.ph_today()
      left join public.attendance_sessions asess on asess.id = s.session_id
     where p.role = 'technician' and p.active
     group by p.id, p.code, p.full_name, f.id, f.name, f.location,
              fd.status, fd.ended_at
  ) rows;
  return result;
end;
$$;

create or replace function public.admin_flagged_scans(
  p_from date default public.ph_today(),
  p_to date default public.ph_today()
)
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
  if not public.is_admin() then
    raise exception 'E_FORBIDDEN';
  end if;
  return coalesce((
    select jsonb_agg(to_jsonb(rows) order by rows.scanned_at desc)
    from (
      select s.scan_id, s.scanned_at, s.result::text, s.flags,
             w.id as worker_id, w.name as worker_name,
             p.code as technician_code, p.full_name as technician_name,
             f.name as field_name
        from public.scans s
        join public.workers w on w.id = s.worker_id
        join public.profiles p on p.id = s.technician_id
        join public.fields f on f.id = s.field_id
       where public.ph_date(s.scanned_at) between p_from and p_to
         and cardinality(s.flags) > 0
    ) rows
  ), '[]'::jsonb);
end;
$$;

create or replace function public.admin_statistics(
  p_from date default public.ph_week_start(public.ph_today()),
  p_to date default public.ph_today()
)
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
  if not public.is_admin() then
    raise exception 'E_FORBIDDEN';
  end if;
  return jsonb_build_object(
    'workers_present', (
      select count(distinct worker_id)
      from public.attendance_sessions
      where work_date between p_from and p_to
    ),
    'total_minutes', (
      select coalesce(sum(extract(epoch from (coalesce(time_out, now()) - time_in) / 60)::int), 0)
      from public.attendance_sessions
      where work_date between p_from and p_to
    ),
    'field_days', (
      select count(*) from public.field_days
      where work_date between p_from and p_to
    ),
    'not_ended', (
      select count(*) from public.field_days
      where work_date between p_from and p_to and status = 'working'
    ),
    'daily', coalesce((
      select jsonb_agg(to_jsonb(rows) order by rows.work_date)
      from (
        select work_date,
               count(distinct worker_id) as workers_present,
               coalesce(sum(extract(epoch from
                 (coalesce(time_out, now()) - time_in) / 60)::int), 0) as minutes
          from public.attendance_sessions
         where work_date between p_from and p_to
         group by work_date
      ) rows
    ), '[]'::jsonb)
  );
end;
$$;

create or replace function public.admin_end_field_day(
  p_field_day_id uuid,
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
  closed_count integer;
begin
  profile := public.require_active_user();
  if not public.is_admin() then
    raise exception 'E_FORBIDDEN';
  end if;
  if nullif(trim(p_reason), '') is null then
    raise exception 'E_REASON_REQUIRED';
  end if;
  select * into day from public.field_days where id = p_field_day_id for update;
  if day.id is null then
    raise exception 'E_FIELD_DAY_NOT_FOUND';
  end if;
  update public.attendance_sessions
     set time_out = date_trunc('minute', now()),
         closed_by = 'admin',
         entered_by_admin = true,
         manual_reason = p_reason
   where field_day_id = day.id and time_out is null;
  get diagnostics closed_count = row_count;
  update public.field_days
     set status = 'ended', ended_at = date_trunc('minute', now()),
         ended_by = profile.id, end_method = 'admin'
   where id = day.id;
  insert into public.audit_logs(actor_id, actor_role, action, table_name,
    record_id, before, after, reason)
  values (profile.id, profile.role::text, 'admin_end_field_day', 'field_days',
    day.id::text, to_jsonb(day),
    jsonb_build_object('status', 'ended', 'closed_count', closed_count),
    p_reason);
  return jsonb_build_object('field_day_id', day.id,
    'closed_count', closed_count, 'ended_at', date_trunc('minute', now()));
end;
$$;

create or replace function public.admin_correct_session(
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
begin
  profile := public.require_active_user();
  if not public.is_admin() then raise exception 'E_FORBIDDEN'; end if;
  if nullif(trim(p_reason), '') is null then raise exception 'E_REASON_REQUIRED'; end if;
  if p_time_out is null or p_time_out <= p_time_in then
    raise exception 'E_TIME_OUT_BEFORE_IN';
  end if;
  if public.ph_date(p_time_in) <> public.ph_date(p_time_out) then
    raise exception 'E_DATE_MISMATCH';
  end if;
  if p_time_in > now() or p_time_out > now() then
    raise exception 'E_TIME_IN_FUTURE';
  end if;
  select * into current_session
    from public.attendance_sessions where id = p_session_id for update;
  if current_session.id is null then raise exception 'E_SESSION_NOT_FOUND'; end if;
  update public.attendance_sessions
     set time_in = date_trunc('minute', p_time_in),
         time_out = date_trunc('minute', p_time_out),
         entered_by_admin = true, manual_reason = p_reason, closed_by = 'admin'
   where id = p_session_id;
  insert into public.audit_logs(actor_id, actor_role, action, table_name,
    record_id, before, after, reason)
  values (profile.id, profile.role::text, 'admin_correct_session',
    'attendance_sessions', p_session_id::text, to_jsonb(current_session),
    jsonb_build_object('time_in', p_time_in, 'time_out', p_time_out), p_reason);
  return jsonb_build_object('session_id', p_session_id, 'updated', true);
end;
$$;

create or replace function public.reissue_card(p_worker_id text)
returns jsonb
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
  profile public.profiles;
  worker public.workers;
  next_check text;
begin
  profile := public.require_active_user();
  if not public.is_admin() then raise exception 'E_FORBIDDEN'; end if;
  select * into worker from public.workers where id = p_worker_id for update;
  if worker.id is null then raise exception 'E_SESSION_NOT_FOUND'; end if;
  next_check := substr(md5(random()::text || clock_timestamp()::text), 1, 3);
  update public.workers set qr_check = next_check, qr_version = qr_version + 1,
    updated_at = now() where id = p_worker_id;
  insert into public.audit_logs(actor_id, actor_role, action, table_name,
    record_id, before, after)
  values (profile.id, profile.role::text, 'reissue_card', 'workers', p_worker_id,
    jsonb_build_object('qr_version', worker.qr_version),
    jsonb_build_object('qr_version', worker.qr_version + 1));
  return jsonb_build_object('qr_payload', p_worker_id || '.' || next_check);
end;
$$;

grant execute on function public.admin_today_field_days() to authenticated;
grant execute on function public.admin_flagged_scans(date, date) to authenticated;
grant execute on function public.admin_statistics(date, date) to authenticated;
grant execute on function public.admin_end_field_day(uuid, text) to authenticated;
grant execute on function public.admin_correct_session(uuid, timestamptz, timestamptz, text) to authenticated;
grant execute on function public.reissue_card(text) to authenticated;
alter table public.workers
  alter column id set default public.next_id('W');

create or replace function public.import_workers(
  p_rows jsonb,
  p_commit boolean default false
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
  profile public.profiles;
  row_data jsonb;
  row_number integer;
  valid_count integer := 0;
  inserted_count integer := 0;
  errors jsonb := '[]'::jsonb;
  duplicates jsonb := '[]'::jsonb;
  parsed_dob date;
  existing_id text;
begin
  profile := public.require_active_user();
  if not public.is_admin() then raise exception 'E_FORBIDDEN'; end if;
  if jsonb_typeof(p_rows) <> 'array' then raise exception 'E_CSV_ROW_TOO_LONG'; end if;
  for row_data in select value from jsonb_array_elements(p_rows) loop
    row_number := coalesce((row_data->>'row')::integer, 0);
    if nullif(trim(row_data->>'name'), '') is null then
      errors := errors || jsonb_build_array(jsonb_build_object(
        'row', row_number, 'code', 'E_CSV_NAME_MISSING'));
      continue;
    end if;
    if length(coalesce(row_data->>'name', '')) > 200
       or length(coalesce(row_data->>'address', '')) > 500
       or length(coalesce(row_data->>'cp_no', '')) > 50 then
      errors := errors || jsonb_build_array(jsonb_build_object(
        'row', row_number, 'code', 'E_CSV_ROW_TOO_LONG'));
      continue;
    end if;
    parsed_dob := null;
    if nullif(trim(row_data->>'date_of_birth'), '') is not null then
      if row_data->>'date_of_birth' !~ '^\d{4}-\d{2}-\d{2}$' then
        errors := errors || jsonb_build_array(jsonb_build_object(
          'row', row_number, 'code', 'E_CSV_DOB_INVALID'));
        continue;
      end if;
      begin
        parsed_dob := (row_data->>'date_of_birth')::date;
      exception when others then
        errors := errors || jsonb_build_array(jsonb_build_object(
          'row', row_number, 'code', 'E_CSV_DOB_INVALID'));
        continue;
      end;
    end if;
    if nullif(trim(row_data->>'gender'), '') is not null
       and lower(row_data->>'gender') not in ('male', 'female', 'other') then
      errors := errors || jsonb_build_array(jsonb_build_object(
        'row', row_number, 'code', 'E_CSV_GENDER_INVALID'));
      continue;
    end if;
    select id into existing_id from public.workers
     where lower(name) = lower(row_data->>'name')
       and date_of_birth is not distinct from parsed_dob
     limit 1;
    if existing_id is not null and coalesce((row_data->>'allow_duplicate')::boolean, false) = false then
      duplicates := duplicates || jsonb_build_array(jsonb_build_object(
        'row', row_number, 'worker_id', existing_id));
      continue;
    end if;
    valid_count := valid_count + 1;
    if p_commit then
      insert into public.workers(name, cp_no, address, gender, date_of_birth, qr_check)
      values (
        row_data->>'name', nullif(row_data->>'cp_no', ''),
        nullif(row_data->>'address', ''), nullif(lower(row_data->>'gender'), ''),
        parsed_dob, substr(md5(random()::text || clock_timestamp()::text), 1, 3)
      );
      inserted_count := inserted_count + 1;
    end if;
  end loop;
  if p_commit then
    insert into public.audit_logs(actor_id, actor_role, action, table_name, meta)
    values (profile.id, profile.role::text, 'import_workers', 'workers',
      jsonb_build_object('valid', valid_count, 'inserted', inserted_count,
        'errors', jsonb_array_length(errors), 'duplicates', jsonb_array_length(duplicates)));
  end if;
  return jsonb_build_object('valid', valid_count, 'errors', errors,
    'duplicates', duplicates, 'inserted', inserted_count);
end;
$$;

grant execute on function public.import_workers(jsonb, boolean) to authenticated;
