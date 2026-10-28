create or replace function public.admin_update_worker(
  p_worker_id text,
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
  previous_worker public.workers;
begin
  profile := public.require_active_user();
  if not public.is_admin() then raise exception 'E_FORBIDDEN'; end if;
  if nullif(trim(p_name), '') is null then raise exception 'E_CSV_NAME_MISSING'; end if;
  if p_gender is not null and lower(p_gender) not in ('male', 'female', 'other') then
    raise exception 'E_CSV_GENDER_INVALID';
  end if;
  select * into worker from public.workers where id = p_worker_id for update;
  if worker.id is null then raise exception 'E_SESSION_NOT_FOUND'; end if;
  previous_worker := worker;
  update public.workers set
    name = trim(p_name), cp_no = nullif(trim(p_cp_no), ''),
    address = nullif(trim(p_address), ''),
    gender = nullif(lower(trim(p_gender)), ''),
    date_of_birth = p_date_of_birth, updated_at = now()
  where id = p_worker_id returning * into worker;
  insert into public.audit_logs(actor_id, actor_role, action, table_name, record_id, before, after)
  values (profile.id, profile.role::text, 'worker_updated', 'workers', worker.id,
          to_jsonb(previous_worker), to_jsonb(worker));
  return to_jsonb(worker);
end;
$$;

grant execute on function public.admin_update_worker(text, text, text, text, text, date)
  to authenticated;
