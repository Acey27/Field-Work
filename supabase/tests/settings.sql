-- Run in the Supabase SQL editor of the DEV project while signed in as a
-- test admin (or set request.jwt.claims for the admin's user id).
-- Each statement shows what it should do. Nothing here changes data that
-- cannot be set back; the last statement restores the defaults.

-- 1. Valid times are saved (admin, not only super admin).
select public.admin_set_setting('scan_hours_start', '"05:30"'::jsonb);
select public.admin_set_setting('scan_hours_end', '"20:00"'::jsonb);
select public.admin_set_setting('reminder_time', '"17:15"'::jsonb);

-- 2. These must fail with E_SETTING_INVALID.
-- select public.admin_set_setting('reminder_time', '"99:99"'::jsonb);
-- select public.admin_set_setting('reminder_time', '"5:00 PM"'::jsonb);
-- select public.admin_set_setting('reminder_time', '17'::jsonb);
-- select public.admin_set_setting('technician_reminder_enabled', '"yes"'::jsonb);

-- 3. This must fail with E_SETTING_UNKNOWN.
-- select public.admin_set_setting('not_a_setting', '"04:00"'::jsonb);

-- 4. The saved values are what the technician phone and the reminder use.
select key, value, updated_at from public.settings
 where key in ('scan_hours_start', 'scan_hours_end', 'reminder_time');

-- 5. Restore the defaults (CONTRACT section 14).
select public.admin_set_setting('scan_hours_start', '"04:00"'::jsonb);
select public.admin_set_setting('scan_hours_end', '"21:00"'::jsonb);
select public.admin_set_setting('reminder_time', '"17:00"'::jsonb);
