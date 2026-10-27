begin;

select plan(9);

select ok(has_function_privilege(
  'anon', 'public.ingest_scans(uuid,timestamptz,jsonb)', 'execute'
) is false, 'anon cannot ingest scans');
select ok(has_function_privilege(
  'authenticated', 'public.ingest_scans(uuid,timestamptz,jsonb)', 'execute'
) , 'authenticated can ingest scans');
select ok(has_function_privilege(
  'authenticated', 'public.end_field_day(uuid,date,timestamptz)', 'execute'
) , 'authenticated can end field day');
select ok(has_function_privilege(
  'authenticated', 'public.get_worker_cache(timestamptz)', 'execute'
) , 'authenticated can read worker cache');

select ok((select prokind = 'f' and prosecdef and provolatile = 'v'
from pg_proc
where oid = 'public.ingest_scans(uuid,timestamptz,jsonb)'::regprocedure), 'ingest scans is volatile security definer');

select ok((select prokind = 'f' and prosecdef
from pg_proc
where oid = 'public.end_field_day(uuid,date,timestamptz)'::regprocedure), 'end field day is security definer');

select ok(pg_get_functiondef(
  'public.ingest_scans(uuid,timestamptz,jsonb)'::regprocedure
) like '%pg_advisory_xact_lock%', 'ingest scans locks worker');

select ok(public.ph_date('2026-10-19 15:59:59+00') = date '2026-10-19',
  'scan date before Philippine midnight');
select ok(public.ph_date('2026-10-19 16:00:00+00') = date '2026-10-20',
  'scan date at Philippine midnight');

select * from finish();
rollback;
