-- Reminder job test. Run the whole script in the Supabase SQL editor of the
-- DEV project. It changes data inside a transaction and ends with ROLLBACK,
-- so nothing is kept. Every check raises an error if it fails; if you reach
-- the last SELECT, all checks passed.
--
-- Needs: at least one active technician, one field, and one active admin.

begin;

do $$
declare
  tech public.profiles;
  fld public.fields;
  admins integer;
  before_count integer;
  sent integer;
  fd_id uuid;
  base timestamptz := now();
begin
  select * into tech from public.profiles
   where role = 'technician' and active limit 1;
  select * into fld from public.fields where active limit 1;
  select count(*) into admins from public.profiles
   where role in ('admin', 'super_admin') and active;
  if tech.id is null or fld.id is null or admins = 0 then
    raise exception 'Need an active technician, field and admin to run this test';
  end if;

  -- Reminder time 00:00 so "now" is always after it, repeat after 30 minutes.
  update public.settings set value = '"00:00"' where key = 'reminder_time';
  update public.settings set value = '30' where key = 'reminder_repeat_minutes';

  -- A working field day today, never reminded.
  insert into public.field_days (technician_id, field_id, work_date, status)
  values (tech.id, fld.id, public.ph_date(base), 'working')
  on conflict (technician_id, work_date) do update
    set status = 'working', ended_at = null,
        first_reminder_at = null, second_reminder_at = null
  returning id into fd_id;

  select count(*) into before_count from public.notifications
   where type = 'field_day_not_ended';

  -- 1. First run sends one notice to every admin and sets first_reminder_at.
  sent := public.job_field_day_reminders(base);
  if sent < 1 then raise exception 'FAIL 1: nothing was sent'; end if;
  if (select count(*) from public.notifications
       where type = 'field_day_not_ended') - before_count < admins then
    raise exception 'FAIL 1: not every admin got the notice';
  end if;
  if (select first_reminder_at from public.field_days where id = fd_id) is null then
    raise exception 'FAIL 1: first_reminder_at not set';
  end if;

  -- 2. Running again right away sends nothing for this field day.
  select count(*) into before_count from public.notifications
   where type = 'field_day_not_ended' and params->>'work_date' = public.ph_date(base)::text
     and (params->>'reminder_number')::int = 1;
  perform public.job_field_day_reminders(base + interval '1 minute');
  if (select count(*) from public.notifications
       where type = 'field_day_not_ended'
         and params->>'work_date' = public.ph_date(base)::text
         and (params->>'reminder_number')::int = 1) <> before_count then
    raise exception 'FAIL 2: first reminder sent twice';
  end if;

  -- 3. Before 30 minutes, no second reminder.
  perform public.job_field_day_reminders(base + interval '29 minutes');
  if (select second_reminder_at from public.field_days where id = fd_id) is not null then
    raise exception 'FAIL 3: second reminder sent too early';
  end if;

  -- 4. After 30 minutes, exactly one second reminder.
  perform public.job_field_day_reminders(base + interval '31 minutes');
  if (select second_reminder_at from public.field_days where id = fd_id) is null then
    raise exception 'FAIL 4: second reminder missing';
  end if;

  -- 5. Then no more.
  select count(*) into before_count from public.notifications
   where type = 'field_day_not_ended';
  perform public.job_field_day_reminders(base + interval '90 minutes');
  if (select count(*) from public.notifications
       where type = 'field_day_not_ended') <> before_count then
    raise exception 'FAIL 5: a third reminder was sent';
  end if;

  -- 6. An ended field day is never reminded.
  update public.field_days
     set status = 'ended', first_reminder_at = null, second_reminder_at = null
   where id = fd_id;
  select count(*) into before_count from public.notifications
   where type = 'field_day_not_ended';
  perform public.job_field_day_reminders(base + interval '2 hours');
  if (select count(*) from public.notifications
       where type = 'field_day_not_ended') <> before_count then
    raise exception 'FAIL 6: reminded an ended field day';
  end if;

  -- 7. Before the reminder time nothing is sent.
  update public.settings set value = '"23:59"' where key = 'reminder_time';
  update public.field_days
     set status = 'working', first_reminder_at = null where id = fd_id;
  if public.job_field_day_reminders(public.ph_date(base)::timestamp
       at time zone 'Asia/Manila' + interval '10 hours') <> 0 then
    raise exception 'FAIL 7: sent before the reminder time';
  end if;
end;
$$;

select 'reminders.sql: all checks passed' as result;

rollback;
