-- Validate settings values (CONTRACT.md sections 4.15 and 14).
-- Times are stored as 24-hour "HH:MM" Philippine time. The app shows them as
-- 12-hour AM/PM, but the stored format does not change.
-- scan_hours_* can be changed by the super admin only; the reminder settings
-- by any admin.

create or replace function public.admin_set_setting(p_key text, p_value jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
  profile public.profiles;
  previous jsonb;
begin
  profile := public.require_active_user();
  if not public.is_admin() then raise exception 'E_FORBIDDEN'; end if;
  if p_key not in ('scan_hours_start', 'scan_hours_end', 'reminder_time',
                   'technician_reminder_enabled') then
    raise exception 'E_SETTING_UNKNOWN';
  end if;
  if p_key in ('scan_hours_start', 'scan_hours_end')
     and not public.is_super_admin() then
    raise exception 'E_FORBIDDEN';
  end if;

  if p_key = 'technician_reminder_enabled' then
    if jsonb_typeof(p_value) <> 'boolean' then
      raise exception 'E_SETTING_INVALID';
    end if;
  else
    if jsonb_typeof(p_value) <> 'string'
       or (p_value #>> '{}') !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$' then
      raise exception 'E_SETTING_INVALID';
    end if;
  end if;

  select value into previous from public.settings where key = p_key for update;
  if previous is null then raise exception 'E_SETTING_UNKNOWN'; end if;
  update public.settings
     set value = p_value, updated_by = profile.id, updated_at = now()
   where key = p_key;
  insert into public.audit_logs(actor_id, actor_role, action, table_name,
    record_id, before, after)
  values (profile.id, profile.role::text, 'setting_changed', 'settings', p_key,
          jsonb_build_object('value', previous),
          jsonb_build_object('value', p_value));
  return jsonb_build_object('key', p_key, 'value', p_value);
end;
$$;

revoke execute on function public.admin_set_setting(text, jsonb) from public, anon;
grant execute on function public.admin_set_setting(text, jsonb) to authenticated;
