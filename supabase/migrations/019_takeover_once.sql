-- 019: a worker taken over by a second technician can only be clocked out by
-- that technician.
--
-- Until now (SPEC.md section 6, the "safety net") a scan by any other
-- technician closed the holder's session and opened a new one, whoever the
-- holder was. Two technicians could take the same worker back and forth, and
-- the first one's phone showed CLOCKED OUT while the server recorded a
-- clock-in.
--
-- New rule, decided 2026-10-30:
--   * Technician 2 may still take over a worker whom technician 1 left
--     clocked in (the safety net stays, once).
--   * That new session is marked `taken_over`. While it is open, only its own
--     technician can clock the worker out. A scan by anyone else is refused
--     with the new result `blocked_held_elsewhere` and changes nothing.
--   * When the holder clocks the worker out (or ends the field day, or the
--     admin fixes the record), any technician can clock the worker in again.

-- 1. The new refused result.
alter type public.scan_result add value if not exists 'blocked_held_elsewhere';

-- 2. Which sessions were opened by a takeover.
alter table public.attendance_sessions
  add column if not exists taken_over boolean not null default false;

comment on column public.attendance_sessions.taken_over is
  'True when the session was opened by a scan that closed another technician''s open session (safety net). Only this session''s technician can clock the worker out.';

-- 3. ingest_scans (CONTRACT.md section 4.6). Same as migration 004, except:
--    * after finding the worker's open session, a scan by another technician
--      is refused when that session was itself opened by a takeover;
--    * the takeover session is saved with taken_over = true;
--    * a refused scan is stored like a blocked one: no session, no field day.
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

      if open_session.id is not null
         and open_session.technician_id <> current_profile.id
         and open_session.taken_over then
        -- Another technician took this worker over, so only that technician
        -- clocks them out. Nothing changes, not even this technician's field
        -- day.
        result := 'blocked_held_elsewhere';
      else
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
          -- Safety net: the first technician left this worker clocked in.
          update public.attendance_sessions
          set time_out = greatest(normalized_time, time_in), closed_by = 'safety_net'
          where id = open_session.id
          returning * into new_session;
          closed_session_id := open_session.id;
          flags := array_append(flags, 'safety_net_close');
          insert into public.attendance_sessions (
            worker_id, technician_id, field_id, field_day_id, work_date, time_in,
            taken_over
          )
          values (
            scan_worker_id, current_profile.id, scan_field_id, field_day.id, scan_work_date, normalized_time,
            true
          )
          returning * into new_session;
          result := 'clocked_in';
        end if;
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
      case when result in ('ignored_repeat', 'blocked_held_elsewhere')
        then null else new_session.id end,
      flags, clock_offset
    );

    if result not in ('ignored_repeat', 'blocked_held_elsewhere')
       and new_session.id is not null then
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
      'session_id', case when result in ('ignored_repeat', 'blocked_held_elsewhere')
        then null else new_session.id end,
      'time', normalized_time, 'closed_session_id', closed_session_id,
      'flags', to_jsonb(flags)
    ));
  end loop;

  return jsonb_build_object('server_time', received_at, 'results', output);
end;
$$;

revoke execute on function public.ingest_scans(uuid, timestamptz, jsonb) from public, anon;
grant execute on function public.ingest_scans(uuid, timestamptz, jsonb) to authenticated;
