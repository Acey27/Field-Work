insert into public.id_counters (prefix, last_value)
values ('W', 0), ('T', 0), ('A', 0)
on conflict (prefix) do nothing;

create or replace function public.next_id(p_prefix text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  next_value bigint;
begin
  if p_prefix not in ('W', 'T', 'A') then
    raise exception 'Unsupported ID prefix: %', p_prefix;
  end if;

  update public.id_counters
  set last_value = last_value + 1
  where prefix = p_prefix
  returning last_value into next_value;

  if next_value is null then
    raise exception 'ID counter is not initialized for prefix: %', p_prefix;
  end if;

  return p_prefix || '-' || lpad(next_value::text, 5, '0');
end;
$$;

create or replace function public.ph_date(p_ts timestamptz)
returns date
language sql
immutable
as $$
  select (p_ts at time zone 'Asia/Manila')::date;
$$;

create or replace function public.ph_today()
returns date
language sql
stable
as $$
  select public.ph_date(now());
$$;

create or replace function public.ph_week_start(p_date date)
returns date
language sql
immutable
as $$
  select date_trunc('week', p_date)::date;
$$;

create or replace function public.ph_time_of_day(p_ts timestamptz)
returns time
language sql
immutable
as $$
  select (p_ts at time zone 'Asia/Manila')::time;
$$;

insert into public.settings (key, value)
values
  ('reminder_time', '"17:00"'::jsonb),
  ('scan_hours_start', '"04:00"'::jsonb),
  ('scan_hours_end', '"21:00"'::jsonb),
  ('retention_days', '15'::jsonb),
  ('clock_skew_minutes', '5'::jsonb),
  ('burst_threshold', '10'::jsonb)
on conflict (key) do nothing;

create or replace function public.audit_row_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  old_record jsonb;
  new_record jsonb;
  record_key text;
begin
  old_record := case when tg_op in ('UPDATE', 'DELETE') then to_jsonb(old) end;
  new_record := case when tg_op in ('INSERT', 'UPDATE') then to_jsonb(new) end;
  record_key := coalesce(
    new_record ->> 'id',
    new_record ->> 'scan_id',
    old_record ->> 'id',
    old_record ->> 'scan_id'
  );

  insert into public.audit_logs (
    actor_id, actor_role, action, table_name, record_id, before, after, reason
  )
  values (
    auth.uid(),
    nullif(current_setting('app.actor_role', true), ''),
    lower(tg_op),
    tg_table_name,
    record_key,
    old_record,
    new_record,
    nullif(current_setting('app.audit_reason', true), '')
  );

  return coalesce(new, old);
end;
$$;

do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'profiles',
    'workers',
    'fields',
    'field_assignments',
    'devices',
    'field_days',
    'attendance_sessions',
    'weekly_exports',
    'settings',
    'notifications'
  ]
  loop
    execute format(
      'create trigger %I_audit_row_change after insert or update or delete on public.%I for each row execute function public.audit_row_change()',
      table_name,
      table_name
    );
  end loop;
end;
$$;
