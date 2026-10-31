-- Fixes after testing Phase 5: "Changed after export" never appeared.
--
-- mark_weekly_export_changed (021) compared weekly_exports.week_start, which
-- is always a Monday, with the changed session's own work_date, so only a
-- change dated Monday marked the week. It now works out the Monday of the
-- changed date. For an update it also marks the week the session came from
-- (a time record can be moved to another date). A session that only gets its
-- bookkeeping touched (nothing the masterlist shows) no longer marks anything.
-- Only the latest export of a week is marked, and only once.

create or replace function public.mark_weekly_export_changed()
returns trigger
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
  weeks date[] := '{}';
begin
  if tg_op = 'UPDATE'
     and old.work_date = new.work_date
     and old.worker_id = new.worker_id
     and old.technician_id = new.technician_id
     and old.field_id = new.field_id
     and old.time_in is not distinct from new.time_in
     and old.time_out is not distinct from new.time_out then
    return new;
  end if;

  if tg_op in ('INSERT', 'UPDATE') then
    weeks := weeks || public.ph_week_start(new.work_date);
  end if;
  if tg_op in ('UPDATE', 'DELETE') then
    weeks := weeks || public.ph_week_start(old.work_date);
  end if;

  update public.weekly_exports e
     set changed_after_export = true,
         changed_at = now()
   where e.changed_after_export = false
     and e.id in (
       select distinct on (x.week_start) x.id
         from public.weekly_exports x
        where x.week_start = any(weeks)
        order by x.week_start, x.exported_at desc
     );

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;
