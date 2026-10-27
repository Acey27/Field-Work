begin;

select has_table_privilege('anon', 'public.workers', 'select') is false
  as anon_cannot_read_workers;
select relrowsecurity
from pg_class
where oid = 'public.profiles'::regclass
  and relrowsecurity;
select relrowsecurity
from pg_class
where oid = 'public.workers'::regclass
  and relrowsecurity;
select relrowsecurity
from pg_class
where oid = 'public.devices'::regclass
  and relrowsecurity;

select has_function_privilege(
  'anon', 'public.ping()', 'execute'
) as anon_can_ping;
select has_function_privilege(
  'anon', 'public.register_device(uuid,text)', 'execute'
) is false as anon_cannot_register_devices;
select has_function_privilege(
  'authenticated', 'public.register_device(uuid,text)', 'execute'
) as authenticated_can_register_devices;
select has_function_privilege(
  'authenticated', 'public.approve_device(uuid)', 'execute'
) as authenticated_can_approve_devices;
select has_function_privilege(
  'authenticated', 'public.get_login_state()', 'execute'
) as authenticated_can_read_login_state;

select has_table_privilege(
  'authenticated', 'public.scans', 'insert'
) is false as authenticated_cannot_insert_scans;
select has_table_privilege(
  'authenticated', 'public.attendance_sessions', 'update'
) is false as authenticated_cannot_update_sessions;
select has_table_privilege(
  'authenticated', 'public.devices', 'update'
) is false as authenticated_cannot_update_devices;
select prokind = 'f' and provolatile = 'v' as context_function_is_volatile
from pg_proc
where oid = 'public.get_my_context(uuid)'::regprocedure;

select count(*) = 1 as one_technician_device_policy
from pg_policies
where schemaname = 'public'
  and tablename = 'devices'
  and policyname = 'devices_owner_or_admin';
select count(*) = 1 as one_super_admin_audit_policy
from pg_policies
where schemaname = 'public'
  and tablename = 'audit_logs'
  and policyname = 'audit_super_select';

rollback;
