alter table public.scans
  add column submitted_worker_id text;

alter table public.scans
  alter column worker_id drop not null;

alter table public.scans
  add constraint scans_worker_reference_check check (
    worker_id is not null or submitted_worker_id is not null
  );

create or replace function public._scan_device(p_device_uuid uuid)
returns public.devices
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  current_device public.devices;
begin
  select * into current_device
  from public.devices
  where technician_id = auth.uid()
    and device_uuid = p_device_uuid;

  if current_device.id is null then
    raise exception 'E_DEVICE_NOT_APPROVED';
  end if;
  if current_device.status = 'pending' then
    raise exception 'E_DEVICE_PENDING';
  end if;
  if current_device.status = 'revoked' then
    raise exception 'E_DEVICE_REVOKED';
  end if;
  return current_device;
end;
$$;

create or replace function public.get_worker_cache(
  p_since timestamptz default null
)
returns setof jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  perform public.require_active_user();
  if public.app_role() <> 'technician' then
    raise exception 'E_FORBIDDEN';
  end if;

  return query
  select jsonb_build_object(
    'id', id,
    'name', name,
    'active', active,
    'qr_check', qr_check,
    'updated_at', updated_at
  )
  from public.workers
  where p_since is null or updated_at > p_since
  order by id;
end;
$$;

create or replace function public.ingest_scans(
  p_device_uuid uuid,
  p_device_time timestamptz,
  p_scans jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  current_profile public.profiles;
  current_device public.devices;
  item jsonb;
  scan_uuid uuid;
  scan_worker_id text;
  qr_check text;
  scan_field_id uuid;
  scan_at timestamptz;
  received_at timestamptz := now();
  scan_work_date date;
  current_worker public.workers;
  current_field public.fields;
  current_assignment public.field_assignments;
  field_day public.field_days;
  open_session public.attendance_sessions;
  prior_scan public.scans;
  new_session public.attendance_sessions;
  closed_session_id uuid;
  result public.scan_result;
  flags text[];
  clock_offset integer;
  skew_minutes integer;
  output jsonb := '[]'::jsonb;
  normalized_time timestamptz;
begin
  current_profile := public.require_active_user();
  if current_profile.role <> 'technician' then
    raise exception 'E_FORBIDDEN';
  end if;
  if p_scans is null
    or jsonb_typeof(p_scans) <> 'array'
    or jsonb_array_length(p_scans) > 50 then
    raise exception 'E_BATCH_TOO_LARGE';
  end if;

  current_device := public._scan_device(p_device_uuid);
  received_at := now();
  clock_offset := extract(epoch from (p_device_time - received_at))::integer;
  select coalesce((value #>> '{}')::integer, 5)
  into skew_minutes
  from public.settings
  where key = 'clock_skew_minutes';
  skew_minutes := coalesce(skew_minutes, 5);

  update public.devices
  set last_seen_at = received_at, last_sync_at = received_at
  where id = current_device.id;

  for item in select value from jsonb_array_elements(p_scans)
  loop
    scan_uuid := (item ->> 'scan_id')::uuid;
    scan_worker_id := item ->> 'worker_id';
    qr_check := item ->> 'qr_check';
    scan_field_id := (item ->> 'field_id')::uuid;
    scan_at := (item ->> 'scanned_at')::timestamptz;
    normalized_time := date_trunc('minute', scan_at);
    flags := array[]::text[];
    result := null;
    closed_session_id := null;
    new_session := null;

    select * into prior_scan from public.scans where scan_id = scan_uuid;
    if prior_scan.scan_id is not null then
      output := output || jsonb_build_array(jsonb_build_object(
        'scan_id', scan_uuid,
        'result', prior_scan.result::text,
        'duplicate', true,
        'session_id', prior_scan.session_id,
        'time', date_trunc('minute', prior_scan.scanned_at),
        'closed_session_id', null,
        'flags', to_jsonb(prior_scan.flags)
      ));
      continue;
    end if;

    if abs(clock_offset) > skew_minutes * 60 then
      flags := array_append(flags, 'clock_skew');
    end if;
    if item ->> 'lat' is null or item ->> 'lng' is null then
      flags := array_append(flags, 'no_location');
    end if;

    select * into current_worker from public.workers where id = scan_worker_id;
    select * into current_field from public.fields where id = scan_field_id;

    if current_worker.id is null then
      result := 'blocked_unknown_worker';
    elsif current_worker.qr_check <> qr_check then
      result := 'blocked_bad_qr';
    elsif not current_worker.active then
      result := 'blocked_inactive_worker';
    elsif current_field.id is null or not current_field.active then
      result := 'blocked_inactive_field';
    elsif not current_profile.active then
      result := 'blocked_inactive_technician';
    else
      select * into current_assignment
      from public.field_assignments
      where technician_id = current_profile.id
        and field_id = scan_field_id
        and assigned_at <= scan_at
        and (unassigned_at is null or unassigned_at > scan_at)
      order by assigned_at desc
      limit 1;
      if current_assignment.id is null then
        result := 'blocked_not_assigned';
      end if;
    end if;

    if result is not null then
      insert into public.scans (
        scan_id, worker_id, submitted_worker_id, technician_id, field_id, device_id,
        scanned_at, received_at, lat, lng, result, flags, clock_offset_seconds
      )
      values (
        scan_uuid, current_worker.id, scan_worker_id, current_profile.id,
        scan_field_id, current_device.id,
        normalized_time, received_at, (item ->> 'lat')::numeric,
        (item ->> 'lng')::numeric, result, flags, clock_offset
      );
      output := output || jsonb_build_array(jsonb_build_object(
        'scan_id', scan_uuid, 'result', result::text, 'duplicate', false,
        'session_id', null, 'time', normalized_time,
        'closed_session_id', null, 'flags', to_jsonb(flags)
      ));
      continue;
    end if;

    perform pg_advisory_xact_lock(hashtext(scan_worker_id));
    scan_work_date := public.ph_date(scan_at);
    select s.* into prior_scan
    from public.scans s
    where s.worker_id = scan_worker_id
      and s.technician_id = current_profile.id
      and s.result in ('clocked_in', 'clocked_out')
      and s.scanned_at >= scan_at - interval '30 seconds'
      and s.scanned_at < scan_at
    order by s.scanned_at desc
    limit 1;
    if prior_scan.scan_id is not null then
      result := 'ignored_repeat';
    else
      select * into open_session
      from public.attendance_sessions
      where attendance_sessions.worker_id = scan_worker_id
        and attendance_sessions.work_date = scan_work_date
        and time_out is null
      for update;

      select * into field_day
      from public.field_days
      where technician_id = current_profile.id and field_days.work_date = scan_work_date
      for update;

      if field_day.id is null then
        insert into public.field_days (technician_id, field_id, work_date)
        values (current_profile.id, scan_field_id, scan_work_date)
        returning * into field_day;
      elsif field_day.status = 'ended' then
        flags := array_append(flags, 'after_field_end');
        update public.field_days
        set status = 'working', ended_at = null, ended_by = null, end_method = null
        where id = field_day.id
        returning * into field_day;
      end if;

      if open_session.id is null then
        insert into public.attendance_sessions (
          worker_id, technician_id, field_id, field_day_id, work_date, time_in
        )
        values (
          scan_worker_id, current_profile.id, scan_field_id, field_day.id, scan_work_date, normalized_time
        )
        returning * into new_session;
        result := 'clocked_in';
      elsif open_session.technician_id = current_profile.id then
        update public.attendance_sessions
        set time_out = greatest(normalized_time, time_in), closed_by = 'scan'
        where id = open_session.id
        returning * into new_session;
        result := 'clocked_out';
      else
        update public.attendance_sessions
        set time_out = greatest(normalized_time, time_in), closed_by = 'safety_net'
        where id = open_session.id
        returning * into new_session;
        closed_session_id := open_session.id;
        flags := array_append(flags, 'safety_net_close');
        insert into public.attendance_sessions (
          worker_id, technician_id, field_id, field_day_id, work_date, time_in
        )
        values (
          scan_worker_id, current_profile.id, scan_field_id, field_day.id, scan_work_date, normalized_time
        )
        returning * into new_session;
        result := 'clocked_in';
      end if;
    end if;

    if public.ph_time_of_day(scan_at) < (
      select (value #>> '{}')::time from public.settings where key = 'scan_hours_start'
    ) or public.ph_time_of_day(scan_at) > (
      select (value #>> '{}')::time from public.settings where key = 'scan_hours_end'
    ) then
      flags := array_append(flags, 'outside_hours');
    end if;

    insert into public.scans (
      scan_id, worker_id, technician_id, field_id, device_id, scanned_at,
      received_at, lat, lng, result, session_id, flags, clock_offset_seconds
    )
    values (
      scan_uuid, scan_worker_id, current_profile.id, scan_field_id, current_device.id,
      normalized_time, received_at, (item ->> 'lat')::numeric,
      (item ->> 'lng')::numeric, result,
      case when result = 'ignored_repeat' then null else new_session.id end,
      flags, clock_offset
    );

    if result <> 'ignored_repeat' and new_session.id is not null then
      if result = 'clocked_in' then
        update public.scans set session_id = new_session.id where scan_id = scan_uuid;
        update public.attendance_sessions
        set in_scan_id = scan_uuid
        where id = new_session.id;
      else
        update public.scans set session_id = new_session.id where scan_id = scan_uuid;
        update public.attendance_sessions
        set out_scan_id = scan_uuid
        where id = new_session.id;
      end if;
    end if;

    output := output || jsonb_build_array(jsonb_build_object(
      'scan_id', scan_uuid, 'result', result::text, 'duplicate', false,
      'session_id', case when result = 'ignored_repeat' then null else new_session.id end,
      'time', normalized_time, 'closed_session_id', closed_session_id,
      'flags', to_jsonb(flags)
    ));
  end loop;

  return jsonb_build_object('server_time', received_at, 'results', output);
end;
$$;

create or replace function public.end_field_day(
  p_device_uuid uuid,
  p_work_date date,
  p_ended_at timestamptz
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  current_profile public.profiles;
  field_day public.field_days;
  clamped_ended_at timestamptz;
  closed_count integer := 0;
begin
  current_profile := public.require_active_user();
  if current_profile.role <> 'technician' then
    raise exception 'E_FORBIDDEN';
  end if;
  perform public._scan_device(p_device_uuid);
  if p_work_date <> public.ph_date(p_ended_at) then
    raise exception 'E_DATE_NOT_TODAY';
  end if;
  clamped_ended_at := date_trunc('minute', least(p_ended_at, now()));

  select * into field_day
  from public.field_days
  where technician_id = current_profile.id and work_date = p_work_date
  for update;
  if field_day.id is null then
    raise exception 'E_FIELD_DAY_NOT_FOUND';
  end if;
  if field_day.status = 'ended' then
    return jsonb_build_object(
      'field_day_id', field_day.id, 'closed_count', 0, 'ended_at', field_day.ended_at
    );
  end if;

  update public.attendance_sessions
  set time_out = greatest(clamped_ended_at, time_in), closed_by = 'end_field_day'
  where technician_id = current_profile.id
    and work_date = p_work_date
    and time_out is null
    and time_in <= clamped_ended_at;
  get diagnostics closed_count = row_count;

  update public.field_days
  set status = 'ended', ended_at = clamped_ended_at, ended_by = current_profile.id,
      end_method = 'technician'
  where id = field_day.id
  returning * into field_day;

  return jsonb_build_object(
    'field_day_id', field_day.id, 'closed_count', closed_count, 'ended_at', field_day.ended_at
  );
end;
$$;

create or replace function public.get_my_field_day(
  p_work_date date default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  current_profile public.profiles;
  requested_date date := coalesce(p_work_date, public.ph_today());
  field_day public.field_days;
begin
  current_profile := public.require_active_user();
  if current_profile.role <> 'technician' then
    raise exception 'E_FORBIDDEN';
  end if;
  select * into field_day
  from public.field_days
  where technician_id = current_profile.id and work_date = requested_date;
  if field_day.id is null then
    return jsonb_build_object(
      'field_day', null, 'clocked_in_count', 0, 'sessions', '[]'::jsonb
    );
  end if;
  return jsonb_build_object(
    'field_day', jsonb_build_object(
      'id', field_day.id, 'status', field_day.status::text, 'ended_at', field_day.ended_at
    ),
    'clocked_in_count', (
      select count(*) from public.attendance_sessions
      where technician_id = current_profile.id
        and work_date = requested_date and time_out is null
    ),
    'sessions', coalesce((
      select jsonb_agg(jsonb_build_object(
        'worker_id', s.worker_id, 'worker_name', w.name,
        'time_in', s.time_in, 'time_out', s.time_out
      ) order by s.time_in)
      from public.attendance_sessions s
      join public.workers w on w.id = s.worker_id
      where s.technician_id = current_profile.id and s.work_date = requested_date
    ), '[]'::jsonb)
  );
end;
$$;

create or replace function public.get_worker_week(p_worker_id text)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  current_profile public.profiles;
  week_start date := public.ph_week_start(public.ph_today());
  worker_name text;
  total_minutes integer;
  present_days integer;
begin
  current_profile := public.require_active_user();
  if current_profile.role <> 'technician' then
    raise exception 'E_FORBIDDEN';
  end if;
  select name into worker_name from public.workers where id = p_worker_id;
  if worker_name is null then
    raise exception 'E_SESSION_NOT_FOUND';
  end if;

  select coalesce(sum(case when time_out is null then 0
    else extract(epoch from (time_out - time_in))::integer / 60 end), 0),
    count(distinct work_date)
  into total_minutes, present_days
  from public.attendance_sessions
  where worker_id = p_worker_id
    and work_date between week_start and week_start + 6;

  return jsonb_build_object(
    'worker_id', p_worker_id, 'name', worker_name,
    'week_start', week_start, 'week_end', week_start + 6,
    'days', coalesce((
      select jsonb_agg(jsonb_build_object(
        'date', d.work_date,
        'minutes', case when x.work_date is null then null else x.minutes end
      ) order by d.work_date)
      from generate_series(week_start, week_start + 6, interval '1 day') as d(work_date)
      left join (
        select work_date,
          sum(case when time_out is null then 0
            else extract(epoch from (time_out - time_in))::integer / 60 end)::integer as minutes
        from public.attendance_sessions
        where worker_id = p_worker_id
          and work_date between week_start and week_start + 6
        group by work_date
      ) x on x.work_date = d.work_date
    ), '[]'::jsonb),
    'total_minutes', total_minutes, 'present_days', present_days
  );
end;
$$;

revoke execute on function public.get_worker_cache(timestamptz) from public, anon;
revoke execute on function public.ingest_scans(uuid, timestamptz, jsonb) from public, anon;
revoke execute on function public.end_field_day(uuid, date, timestamptz) from public, anon;
revoke execute on function public.get_my_field_day(date) from public, anon;
revoke execute on function public.get_worker_week(text) from public, anon;
revoke execute on function public._scan_device(uuid) from public, anon, authenticated;
grant execute on function public.get_worker_cache(timestamptz) to authenticated;
grant execute on function public.ingest_scans(uuid, timestamptz, jsonb) to authenticated;
grant execute on function public.end_field_day(uuid, date, timestamptz) to authenticated;
grant execute on function public.get_my_field_day(date) to authenticated;
grant execute on function public.get_worker_week(text) to authenticated;
