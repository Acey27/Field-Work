create or replace function public.admin_create_field(
  p_name text,
  p_location text default null,
  p_address text default null
)
returns public.fields
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
  profile public.profiles;
  field_row public.fields;
begin
  profile := public.require_active_user();
  if not public.is_admin() then raise exception 'E_FORBIDDEN'; end if;
  if nullif(trim(p_name), '') is null then raise exception 'E_FIELD_NAME_MISSING'; end if;

  insert into public.fields(name, location, address)
  values (trim(p_name), nullif(trim(p_location), ''), nullif(trim(p_address), ''))
  returning * into field_row;

  insert into public.audit_logs(actor_id, actor_role, action, table_name, record_id, after)
  values (profile.id, profile.role::text, 'field_created', 'fields', field_row.id, to_jsonb(field_row));
  return field_row;
end;
$$;

create or replace function public.admin_set_field_active(
  p_field_id uuid,
  p_active boolean
)
returns public.fields
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
  profile public.profiles;
  field_row public.fields;
begin
  profile := public.require_active_user();
  if not public.is_admin() then raise exception 'E_FORBIDDEN'; end if;

  update public.fields
  set active = p_active,
      archived_at = case when p_active then null else coalesce(archived_at, now()) end
  where id = p_field_id
  returning * into field_row;
  if field_row.id is null then raise exception 'E_FIELD_NOT_FOUND'; end if;

  insert into public.audit_logs(actor_id, actor_role, action, table_name, record_id, after)
  values (
    profile.id, profile.role::text,
    case when p_active then 'field_activated' else 'field_deactivated' end,
    'fields', field_row.id, to_jsonb(field_row)
  );
  return field_row;
end;
$$;

grant execute on function public.admin_create_field(text, text, text) to authenticated;
grant execute on function public.admin_set_field_active(uuid, boolean) to authenticated;
