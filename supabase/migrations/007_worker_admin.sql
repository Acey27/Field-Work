create or replace function public.admin_create_worker(
  p_name text,
  p_cp_no text default null,
  p_address text default null,
  p_gender text default null,
  p_date_of_birth date default null
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
  profile public.profiles;
  worker public.workers;
begin
  profile := public.require_active_user();
  if not public.is_admin() then raise exception 'E_FORBIDDEN'; end if;
  if nullif(trim(p_name), '') is null then raise exception 'E_CSV_NAME_MISSING'; end if;
  if p_gender is not null and lower(p_gender) not in ('male', 'female', 'other') then
    raise exception 'E_CSV_GENDER_INVALID';
  end if;
  insert into public.workers(name, cp_no, address, gender, date_of_birth, qr_check)
  values (
    trim(p_name), nullif(trim(p_cp_no), ''), nullif(trim(p_address), ''),
    nullif(lower(trim(p_gender)), ''),
    p_date_of_birth,
    substr(md5(random()::text || clock_timestamp()::text), 1, 3)
  )
  returning * into worker;
  insert into public.audit_logs(actor_id, actor_role, action, table_name,
    record_id, after)
  values (profile.id, profile.role::text, 'worker_created', 'workers',
    worker.id, to_jsonb(worker));
  return jsonb_build_object(
    'id', worker.id, 'name', worker.name, 'cp_no', worker.cp_no,
    'address', worker.address, 'gender', worker.gender,
    'date_of_birth', worker.date_of_birth, 'qr_check', worker.qr_check,
    'active', worker.active
  );
end;
$$;

grant execute on function public.admin_create_worker(text, text, text, text, date)
  to authenticated;
