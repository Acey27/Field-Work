begin;

select is(public.next_id('W'), 'W-00001', 'worker IDs start at W-00001');
select is(public.next_id('W'), 'W-00002', 'worker IDs increment safely');
select is(public.next_id('T'), 'T-00001', 'technician IDs use T prefix');
select is(public.next_id('A'), 'A-00001', 'admin IDs use A prefix');

select is(
  public.ph_date('2026-10-27 15:59:00+00'),
  date '2026-10-27',
  '15:59 UTC is still the same Philippine date'
);
select is(
  public.ph_date('2026-10-27 16:00:00+00'),
  date '2026-10-28',
  '16:00 UTC is the next Philippine date'
);
select is(
  public.ph_week_start(date '2026-10-28'),
  date '2026-10-26',
  'week starts on Monday'
);
select is(
  public.ph_time_of_day('2026-10-27 16:00:00+00'),
  time '00:00:00',
  'time helper uses Asia/Manila'
);

select is(
  (select value from public.settings where key = 'reminder_time'),
  '"17:00"'::jsonb,
  'default reminder time is 17:00'
);
select is(
  (select value from public.settings where key = 'retention_days'),
  '15'::jsonb,
  'default retention is 15 days'
);

rollback;
