create or replace function public.admin_add_time_record(
  p_worker_id text,
  p_field_id uuid,
  p_technician_id uuid,
  p_work_date date,
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
  field_day_id uuid;
  session_id uuid;
begin
  profile := public.require_active_user();
  if not public.is_admin() then raise exception 'E_FORBIDDEN'; end if;
  if nullif(trim(p_reason), '') is null then raise exception 'E_REASON_REQUIRED'; end if;
  if p_time_out is null or p_time_out <= p_time_in then raise exception 'E_TIME_OUT_BEFORE_IN'; end if;
  if public.ph_date(p_time_in) <> public.ph_date(p_time_out)
     or public.ph_date(p_time_in) <> p_work_date then raise exception 'E_DATE_MISMATCH'; end if;
  if p_time_out > now() then raise exception 'E_TIME_IN_FUTURE'; end if;
  if not exists (select 1 from public.workers where id = p_worker_id) then
    raise exception 'E_SESSION_NOT_FOUND';
  end if;
  insert into public.field_days(technician_id, field_id, work_date)
  values (p_technician_id, p_field_id, p_work_date)
  on conflict (technician_id, work_date) do update set field_id = excluded.field_id
  returning id into field_day_id;
  insert into public.attendance_sessions(
    worker_id, technician_id, field_id, field_day_id, work_date,
    time_in, time_out, entered_by_admin, manual_reason, closed_by
  ) values (
    p_worker_id, p_technician_id, p_field_id, field_day_id, p_work_date,
    date_trunc('minute', p_time_in), date_trunc('minute', p_time_out),
    true, p_reason, 'admin'
  ) returning id into session_id;
  insert into public.audit_logs(actor_id, actor_role, action, table_name, record_id, reason)
  values (profile.id, profile.role::text, 'admin_add_time_record',
          'attendance_sessions', session_id::text, p_reason);
  return jsonb_build_object('session_id', session_id);
end;
$$;

create or replace function public.admin_weekly_masterlist(
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
  if not public.is_admin() then raise exception 'E_FORBIDDEN'; end if;
  return coalesce((
    select jsonb_agg(to_jsonb(rows) order by rows.worker_name, rows.work_date)
    from (
      select s.worker_id, w.name as worker_name, s.work_date,
             p.code as technician_code, p.full_name as technician_name,
             f.name as field_name, s.time_in, s.time_out,
             extract(epoch from (s.time_out - s.time_in) / 60)::int as minutes
      from public.attendance_sessions s
      join public.workers w on w.id = s.worker_id
      join public.profiles p on p.id = s.technician_id
      join public.fields f on f.id = s.field_id
      where s.work_date between p_from and p_to
      order by w.name, s.work_date
    ) rows
  ), '[]'::jsonb);
end;
$$;

create or replace function public.admin_set_setting(p_key text, p_value jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
  profile public.profiles;
  previous jsonb;
begin
  profile := public.require_active_user();
  if not public.is_admin() then raise exception 'E_FORBIDDEN'; end if;
  if p_key not in ('scan_hours_start', 'scan_hours_end', 'reminder_time',
                   'technician_reminder_enabled') then
    raise exception 'E_SETTING_UNKNOWN';
  end if;
  select value into previous from public.settings where key = p_key for update;
  if previous is null then raise exception 'E_SETTING_UNKNOWN'; end if;
  update public.settings set value = p_value where key = p_key;
  insert into public.audit_logs(actor_id, actor_role, action, table_name, record_id, before, after)
  values (profile.id, profile.role::text, 'setting_changed', 'settings', p_key,
          jsonb_build_object('value', previous), jsonb_build_object('value', p_value));
  return jsonb_build_object('key', p_key, 'value', p_value);
end;
$$;

grant execute on function public.admin_add_time_record(text, uuid, uuid, date, timestamptz, timestamptz, text) to authenticated;
grant execute on function public.admin_weekly_masterlist(date, date) to authenticated;
grant execute on function public.admin_set_setting(text, jsonb) to authenticated;
