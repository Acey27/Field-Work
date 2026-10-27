begin;

select plan(15);

select ok(
  has_table_privilege('anon', 'public.workers', 'select') is false,
  'anon cannot read workers'
);
select ok((select relrowsecurity from pg_class
  where oid = 'public.profiles'::regclass), 'profiles have RLS');
select ok((select relrowsecurity from pg_class
  where oid = 'public.workers'::regclass), 'workers have RLS');
select ok((select relrowsecurity from pg_class
  where oid = 'public.devices'::regclass), 'devices have RLS');

select ok(has_function_privilege(
  'anon', 'public.ping()', 'execute'
) , 'anon can ping');
select ok(has_function_privilege(
  'anon', 'public.register_device(uuid,text)', 'execute'
) is false, 'anon cannot register devices');
select ok(has_function_privilege(
  'authenticated', 'public.register_device(uuid,text)', 'execute'
) , 'authenticated can register devices');
select ok(has_function_privilege(
  'authenticated', 'public.approve_device(uuid)', 'execute'
) , 'authenticated can approve devices');
select ok(has_function_privilege(
  'authenticated', 'public.get_login_state()', 'execute'
) , 'authenticated can read login state');

select ok(has_table_privilege(
  'authenticated', 'public.scans', 'insert'
) is false, 'authenticated cannot insert scans');
select ok(has_table_privilege(
  'authenticated', 'public.attendance_sessions', 'update'
) is false, 'authenticated cannot update sessions');
select ok(has_table_privilege(
  'authenticated', 'public.devices', 'update'
) is false, 'authenticated cannot update devices');
select ok((select prokind = 'f' and provolatile = 'v'
  from pg_proc
  where oid = 'public.get_my_context(uuid)'::regprocedure),
  'context function is volatile');

select ok((select count(*) = 1 from pg_policies
  where schemaname = 'public'
    and tablename = 'devices'
    and policyname = 'devices_owner_or_admin'),
  'one technician device policy');
select ok((select count(*) = 1 from pg_policies
  where schemaname = 'public'
    and tablename = 'audit_logs'
    and policyname = 'audit_super_select'),
  'one super admin audit policy');

select * from finish();
rollback;
