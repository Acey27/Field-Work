-- 018: fixes after testing on real devices.
--   1. A technician is told when a worker is clocked out on their phone by
--      another technician's scan (the "safety net" in SPEC.md section 2).
--   2. The field admin functions return jsonb, like every other admin function.
--   3. Worker CSV import no longer reads gender or date of birth; a duplicate
--      is the same name (SPEC.md section 3).
--   4. The paper sheet also lists workers whose time was entered by the admin.
--   5. A signed-in phone can call ping(), so "online" is a real answer from
--      the server and not just the type of the network link.

-- 5. ping() was granted to anon only (003). The scanner now asks the server
--    whether it is reachable, and a signed-in user is not the anon role.
grant execute on function public.ping() to authenticated;

-- 1. Safety-net notice. ingest_scans closes the first technician's session with
--    closed_by = 'safety_net' when a second technician scans a worker who is
--    still clocked in. Nothing told the first technician. The notice holds data
--    only; the phone builds the sentence (CONTRACT.md section 15). Admin closes
--    are not announced here: ending a field day would send one per worker.
create or replace function public.notify_safety_net_close()
returns trigger
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
  worker_name text;
begin
  select name into worker_name from public.workers where id = new.worker_id;
  insert into public.notifications (recipient_id, type, params)
  values (
    new.technician_id,
    'worker_clocked_out',
    jsonb_build_object(
      'worker_id', new.worker_id,
      'worker_name', worker_name,
      'reason', 'safety_net',
      'session_id', new.id,
      'time_out', new.time_out
    )
  );
  return new;
end;
$$;

revoke execute on function public.notify_safety_net_close()
  from public, anon, authenticated;

drop trigger if exists attendance_sessions_safety_net_notice
  on public.attendance_sessions;
create trigger attendance_sessions_safety_net_notice
after update of time_out, closed_by on public.attendance_sessions
for each row
when (old.time_out is null
      and new.time_out is not null
      and new.closed_by = 'safety_net')
execute function public.notify_safety_net_close();

-- 2. Fields: the three functions returned the table's row type. They now return
--    jsonb (to_jsonb of the row), the same shape the app already reads.
drop function if exists public.admin_create_field(text, text, text);
drop function if exists public.admin_update_field(uuid, text, text, text);
drop function if exists public.admin_set_field_active(uuid, boolean);

create function public.admin_create_field(
  p_name text,
  p_location text default null,
  p_address text default null
)
returns jsonb
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
  values (profile.id, profile.role::text, 'field_created', 'fields',
          field_row.id::text, to_jsonb(field_row));
  return to_jsonb(field_row);
end;
$$;

create function public.admin_update_field(
  p_field_id uuid,
  p_name text,
  p_location text default null,
  p_address text default null
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
  profile public.profiles;
  old_row public.fields;
  field_row public.fields;
begin
  profile := public.require_active_user();
  if not public.is_admin() then raise exception 'E_FORBIDDEN'; end if;
  if nullif(trim(p_name), '') is null then raise exception 'E_FIELD_NAME_MISSING'; end if;
  select * into old_row from public.fields where id = p_field_id for update;
  if old_row.id is null then raise exception 'E_FIELD_NOT_FOUND'; end if;
  update public.fields
     set name = trim(p_name),
         location = nullif(trim(p_location), ''),
         address = nullif(trim(p_address), '')
   where id = p_field_id
   returning * into field_row;
  insert into public.audit_logs (actor_id, actor_role, action, table_name,
    record_id, before, after)
  values (profile.id, profile.role::text, 'field_updated', 'fields',
    field_row.id::text, to_jsonb(old_row), to_jsonb(field_row));
  return to_jsonb(field_row);
end;
$$;

create function public.admin_set_field_active(
  p_field_id uuid,
  p_active boolean
)
returns jsonb
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
    'fields', field_row.id::text, to_jsonb(field_row)
  );
  return to_jsonb(field_row);
end;
$$;

revoke execute on function public.admin_create_field(text, text, text) from public, anon;
revoke execute on function public.admin_update_field(uuid, text, text, text) from public, anon;
revoke execute on function public.admin_set_field_active(uuid, boolean) from public, anon;
grant execute on function public.admin_create_field(text, text, text) to authenticated;
grant execute on function public.admin_update_field(uuid, text, text, text) to authenticated;
grant execute on function public.admin_set_field_active(uuid, boolean) to authenticated;

-- 3. Worker CSV import. Gender and date of birth are not used any more, so a
--    worker is a duplicate when an existing worker has the same name (ignoring
--    case and spaces at the ends). Same signature as 006.
create or replace function public.import_workers(
  p_rows jsonb,
  p_commit boolean default false
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
  profile public.profiles;
  row_data jsonb;
  row_number integer;
  valid_count integer := 0;
  inserted_count integer := 0;
  errors jsonb := '[]'::jsonb;
  duplicates jsonb := '[]'::jsonb;
  clean_name text;
  existing_id text;
begin
  profile := public.require_active_user();
  if not public.is_admin() then raise exception 'E_FORBIDDEN'; end if;
  if jsonb_typeof(p_rows) <> 'array' then raise exception 'E_CSV_ROW_TOO_LONG'; end if;
  for row_data in select value from jsonb_array_elements(p_rows) loop
    row_number := coalesce((row_data->>'row')::integer, 0);
    clean_name := nullif(btrim(row_data->>'name'), '');
    if clean_name is null then
      errors := errors || jsonb_build_array(jsonb_build_object(
        'row', row_number, 'code', 'E_CSV_NAME_MISSING'));
      continue;
    end if;
    if length(clean_name) > 200
       or length(coalesce(row_data->>'address', '')) > 500
       or length(coalesce(row_data->>'cp_no', '')) > 50 then
      errors := errors || jsonb_build_array(jsonb_build_object(
        'row', row_number, 'code', 'E_CSV_ROW_TOO_LONG'));
      continue;
    end if;
    select id into existing_id from public.workers
     where lower(btrim(name)) = lower(clean_name)
     limit 1;
    if existing_id is not null
       and coalesce((row_data->>'allow_duplicate')::boolean, false) = false then
      duplicates := duplicates || jsonb_build_array(jsonb_build_object(
        'row', row_number, 'worker_id', existing_id));
      continue;
    end if;
    valid_count := valid_count + 1;
    if p_commit then
      insert into public.workers(name, cp_no, address, qr_check)
      values (
        clean_name, nullif(btrim(row_data->>'cp_no'), ''),
        nullif(btrim(row_data->>'address'), ''),
        substr(md5(random()::text || clock_timestamp()::text), 1, 3)
      );
      inserted_count := inserted_count + 1;
    end if;
  end loop;
  if p_commit then
    insert into public.audit_logs(actor_id, actor_role, action, table_name, meta)
    values (profile.id, profile.role::text, 'import_workers', 'workers',
      jsonb_build_object('valid', valid_count, 'inserted', inserted_count,
        'errors', jsonb_array_length(errors), 'duplicates', jsonb_array_length(duplicates)));
  end if;
  return jsonb_build_object('valid', valid_count, 'errors', errors,
    'duplicates', duplicates, 'inserted', inserted_count);
end;
$$;

grant execute on function public.import_workers(jsonb, boolean) to authenticated;

-- 4. Paper sheet. The "usual workers" were found only through scans, so a
--    worker whose time the admin typed in (no scan) never appeared. The list is
--    now the active workers this technician scanned or had a time record for in
--    the 14 days up to the date, plus anyone with a record in the sheet's field
--    on that date. The time boxes stay empty: they are filled in by hand.
create or replace function public.get_paper_sheet(
  p_technician_id uuid,
  p_date date default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  profile public.profiles;
  tech public.profiles;
  target date;
  sheet_field public.fields;
begin
  profile := public.require_active_user();
  if not public.is_admin() then raise exception 'E_FORBIDDEN'; end if;
  target := coalesce(p_date, public.ph_today());

  select * into tech from public.profiles
   where id = p_technician_id and role = 'technician';
  if tech.id is null then raise exception 'E_FIELD_DAY_NOT_FOUND'; end if;

  select f.* into sheet_field
    from public.field_assignments fa
    join public.fields f on f.id = fa.field_id
   where fa.technician_id = tech.id and fa.unassigned_at is null
   order by fa.assigned_at desc
   limit 1;
  if sheet_field.id is null then
    select f.* into sheet_field
      from public.field_days fd
      join public.fields f on f.id = fd.field_id
     where fd.technician_id = tech.id
     order by fd.work_date desc
     limit 1;
  end if;

  return jsonb_build_object(
    'technician', jsonb_build_object(
      'id', tech.id, 'code', tech.code, 'name', tech.full_name),
    'field', case when sheet_field.id is null then null
      else jsonb_build_object('id', sheet_field.id, 'name', sheet_field.name,
                              'location', sheet_field.location) end,
    'work_date', target,
    'workers', coalesce((
      select jsonb_agg(jsonb_build_object('id', x.id, 'name', x.name)
                       order by x.name, x.id)
        from (
          select w.id, w.name
            from public.workers w
           where w.active
             and (
               exists (
                 select 1 from public.scans s
                  where s.worker_id = w.id
                    and s.technician_id = tech.id
                    and s.result in ('clocked_in', 'clocked_out')
                    and public.ph_date(s.scanned_at) between target - 14 and target)
               or exists (
                 select 1 from public.attendance_sessions a
                  where a.worker_id = w.id
                    and a.technician_id = tech.id
                    and a.work_date between target - 14 and target)
               or (sheet_field.id is not null and exists (
                 select 1 from public.attendance_sessions a
                  where a.worker_id = w.id
                    and a.field_id = sheet_field.id
                    and a.work_date = target))
             )
        ) x
    ), '[]'::jsonb)
  );
end;
$$;

grant execute on function public.get_paper_sheet(uuid, date) to authenticated;
