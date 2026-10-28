-- Phase 4 development-project checks.
-- Run after signing in as an admin against test data only.

select public.admin_today_field_days();
select public.admin_statistics(
  public.ph_week_start(public.ph_today()),
  public.ph_today()
);
select public.admin_flagged_scans(public.ph_today(), public.ph_today());

-- The following calls are confirmation-required integration checks:
-- select public.admin_end_field_day('<field-day-id>', 'Test admin correction');
-- select public.admin_correct_session(
--   '<session-id>', '2026-10-28T00:00:00Z',
--   '2026-10-28T08:00:00Z', 'Test correction');
-- select public.import_workers(
--   '[{"row":2,"name":"Phase 4 Test Worker","date_of_birth":"2000-01-01"}]'::jsonb,
--   false
-- );
