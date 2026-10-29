-- Phase 4: "Not ended" reminders and the in-app notification inbox.
-- CONTRACT.md sections 4.15 (notifications), 9 (job_field_day_reminders),
-- 14 (settings) and 15 (notification types); SPEC.md section 8.
--
-- pg_cron must be enabled first (Supabase dashboard: Database > Extensions >
-- pg_cron). If it is not, this migration still succeeds and prints a notice;
-- enable the extension and run the schedule statement at the bottom again.

-- 1. Settings the reminder job and the admin tools need.
insert into public.settings (key, value) values
  ('reminder_repeat_minutes', '30'::jsonb),
  ('technician_reminder_enabled', 'true'::jsonb),
  ('burst_scan_count', '10'::jsonb),
  ('burst_window_seconds', '10'::jsonb)
on conflict (key) do nothing;

-- 2. admin_set_setting also accepts reminder_repeat_minutes (int, 5 to 120).
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
                   'reminder_repeat_minutes', 'technician_reminder_enabled') then
    raise exception 'E_SETTING_UNKNOWN';
  end if;

  if p_key = 'technician_reminder_enabled' then
    if jsonb_typeof(p_value) <> 'boolean' then
      raise exception 'E_SETTING_INVALID';
    end if;
  elsif p_key = 'reminder_repeat_minutes' then
    if jsonb_typeof(p_value) <> 'number'
       or (p_value #>> '{}') !~ '^[0-9]+$'
       or (p_value #>> '{}')::int not between 5 and 120 then
      raise exception 'E_SETTING_INVALID';
    end if;
  else
    if jsonb_typeof(p_value) <> 'string'
       or (p_value #>> '{}') !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$' then
      raise exception 'E_SETTING_INVALID';
    end if;
  end if;

  select value into previous from public.settings where key = p_key for update;
  if previous is null then raise exception 'E_SETTING_UNKNOWN'; end if;
  update public.settings
     set value = p_value, updated_by = profile.id, updated_at = now()
   where key = p_key;
  insert into public.audit_logs(actor_id, actor_role, action, table_name,
    record_id, before, after)
  values (profile.id, profile.role::text, 'setting_changed', 'settings', p_key,
          jsonb_build_object('value', previous),
          jsonb_build_object('value', p_value));
  return jsonb_build_object('key', p_key, 'value', p_value);
end;
$$;

-- 3. The reminder job. Internal: run by pg_cron, not callable from the app.
--    p_now exists so the SQL test can pretend it is a different time.
create or replace function public.job_field_day_reminders(
  p_now timestamptz default now()
)
returns integer
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
  reminder time;
  repeat_minutes integer;
  today date;
  ids uuid[];
  technicians jsonb;
  sent integer := 0;
begin
  select (value #>> '{}')::time into reminder
    from public.settings where key = 'reminder_time';
  reminder := coalesce(reminder, time '17:00');
  select (value #>> '{}')::integer into repeat_minutes
    from public.settings where key = 'reminder_repeat_minutes';
  repeat_minutes := coalesce(repeat_minutes, 30);

  today := public.ph_date(p_now);
  if public.ph_time_of_day(p_now) < reminder then
    return 0;
  end if;

  -- First reminder: today's field days still working, never reminded.
  select array_agg(fd.id),
         jsonb_agg(jsonb_build_object(
           'id', p.id, 'code', p.code, 'name', p.full_name,
           'field_name', f.name) order by p.full_name)
    into ids, technicians
    from public.field_days fd
    join public.profiles p on p.id = fd.technician_id
    join public.fields f on f.id = fd.field_id
   where fd.work_date = today
     and fd.status = 'working'
     and fd.first_reminder_at is null;
  if ids is not null then
    insert into public.notifications (recipient_id, type, params, target)
    select a.id, 'field_day_not_ended',
           jsonb_build_object('work_date', today, 'reminder_number', 1,
                              'technicians', technicians),
           'today_field_days'
      from public.profiles a
     where a.role in ('admin', 'super_admin') and a.active;
    update public.field_days set first_reminder_at = p_now
     where id = any(ids);
    sent := sent + 1;
  end if;

  -- One more reminder after reminder_repeat_minutes, for those still working.
  ids := null;
  technicians := null;
  select array_agg(fd.id),
         jsonb_agg(jsonb_build_object(
           'id', p.id, 'code', p.code, 'name', p.full_name,
           'field_name', f.name) order by p.full_name)
    into ids, technicians
    from public.field_days fd
    join public.profiles p on p.id = fd.technician_id
    join public.fields f on f.id = fd.field_id
   where fd.work_date = today
     and fd.status = 'working'
     and fd.first_reminder_at is not null
     and fd.second_reminder_at is null
     and p_now >= fd.first_reminder_at + make_interval(mins => repeat_minutes);
  if ids is not null then
    insert into public.notifications (recipient_id, type, params, target)
    select a.id, 'field_day_not_ended',
           jsonb_build_object('work_date', today, 'reminder_number', 2,
                              'technicians', technicians),
           'today_field_days'
      from public.profiles a
     where a.role in ('admin', 'super_admin') and a.active;
    update public.field_days set second_reminder_at = p_now
     where id = any(ids);
    sent := sent + 1;
  end if;

  return sent;
end;
$$;

revoke execute on function public.job_field_day_reminders(timestamptz)
  from public, anon, authenticated;

-- 4. Inbox functions for the app (the caller's own notifications only).
create or replace function public.get_my_notifications(p_limit integer default 50)
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
  return coalesce((
    select jsonb_agg(to_jsonb(n) order by n.created_at desc)
      from (
        select id, type, params, target, read_at, created_at
          from public.notifications
         where recipient_id = profile.id
         order by created_at desc
         limit least(greatest(coalesce(p_limit, 50), 1), 200)
      ) n
  ), '[]'::jsonb);
end;
$$;

create or replace function public.mark_notification_read(p_id uuid)
returns jsonb
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
  profile public.profiles;
begin
  profile := public.require_active_user();
  update public.notifications
     set read_at = coalesce(read_at, now())
   where id = p_id and recipient_id = profile.id;
  return jsonb_build_object('id', p_id);
end;
$$;

revoke execute on function public.get_my_notifications(integer)
  from public, anon;
revoke execute on function public.mark_notification_read(uuid)
  from public, anon;
revoke execute on function public.admin_set_setting(text, jsonb)
  from public, anon;
grant execute on function public.get_my_notifications(integer) to authenticated;
grant execute on function public.mark_notification_read(uuid) to authenticated;
grant execute on function public.admin_set_setting(text, jsonb) to authenticated;

-- 5. Schedule the job every 5 minutes (UTC cron, CONTRACT.md section 9).
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule(
      'job_field_day_reminders',
      '*/5 * * * *',
      'select public.job_field_day_reminders()'
    );
  else
    raise notice 'pg_cron is not enabled. Enable it (Database > Extensions), then run: select cron.schedule(''job_field_day_reminders'', ''*/5 * * * *'', ''select public.job_field_day_reminders()'');';
  end if;
end;
$$;
