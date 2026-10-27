create extension if not exists pgcrypto;

create type public.app_role as enum ('super_admin', 'admin', 'technician');
create type public.device_status as enum ('pending', 'approved', 'revoked');
create type public.field_day_status as enum ('working', 'ended');
create type public.end_method as enum ('technician', 'admin');
create type public.close_reason as enum ('scan', 'end_field_day', 'admin', 'safety_net');
create type public.scan_result as enum (
  'clocked_in',
  'clocked_out',
  'ignored_repeat',
  'blocked_bad_qr',
  'blocked_unknown_worker',
  'blocked_inactive_worker',
  'blocked_inactive_field',
  'blocked_inactive_technician',
  'blocked_not_assigned'
);

create table public.profiles (
  id uuid primary key references auth.users(id),
  code text unique,
  role public.app_role not null,
  full_name text not null,
  username text unique,
  active boolean not null default true,
  must_change_password boolean not null default true,
  created_by uuid references public.profiles(id),
  deactivated_at timestamptz,
  created_at timestamptz not null default now(),
  constraint profiles_username_format check (
    username is null or username ~ '^[a-z0-9._]{3,30}$'
  )
);

create table public.workers (
  id text primary key,
  name text not null,
  cp_no text,
  address text,
  gender text check (gender is null or gender in ('male', 'female', 'other')),
  date_of_birth date,
  qr_check text not null check (qr_check ~ '^[0-9a-z]{3}$'),
  qr_version integer not null default 1 check (qr_version > 0),
  active boolean not null default true,
  deleted_at timestamptz,
  updated_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create table public.fields (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  location text,
  address text,
  active boolean not null default true,
  archived_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.field_assignments (
  id uuid primary key default gen_random_uuid(),
  technician_id uuid not null references public.profiles(id),
  field_id uuid not null references public.fields(id),
  assigned_at timestamptz not null default now(),
  unassigned_at timestamptz,
  assigned_by uuid references public.profiles(id),
  created_at timestamptz not null default now()
);

create table public.devices (
  id uuid primary key default gen_random_uuid(),
  technician_id uuid not null references public.profiles(id),
  device_uuid uuid not null,
  label text,
  status public.device_status not null default 'pending',
  registered_at timestamptz not null default now(),
  approved_by uuid references public.profiles(id),
  approved_at timestamptz,
  last_seen_at timestamptz,
  last_sync_at timestamptz,
  created_at timestamptz not null default now(),
  unique (technician_id, device_uuid)
);

create table public.field_days (
  id uuid primary key default gen_random_uuid(),
  technician_id uuid not null references public.profiles(id),
  field_id uuid not null references public.fields(id),
  work_date date not null,
  status public.field_day_status not null default 'working',
  ended_at timestamptz,
  ended_by uuid references public.profiles(id),
  end_method public.end_method,
  first_reminder_at timestamptz,
  second_reminder_at timestamptz,
  created_at timestamptz not null default now(),
  unique (technician_id, work_date)
);

create table public.scans (
  scan_id uuid primary key,
  worker_id text not null references public.workers(id),
  technician_id uuid not null references public.profiles(id),
  field_id uuid not null references public.fields(id),
  device_id uuid not null references public.devices(id),
  scanned_at timestamptz not null,
  received_at timestamptz not null default now(),
  lat numeric,
  lng numeric,
  result public.scan_result not null,
  session_id uuid,
  flags text[] not null default '{}',
  clock_offset_seconds integer,
  created_at timestamptz not null default now()
);

create table public.attendance_sessions (
  id uuid primary key default gen_random_uuid(),
  worker_id text not null references public.workers(id),
  technician_id uuid not null references public.profiles(id),
  field_id uuid not null references public.fields(id),
  field_day_id uuid not null references public.field_days(id),
  work_date date not null,
  time_in timestamptz not null,
  time_out timestamptz,
  closed_by public.close_reason,
  in_scan_id uuid references public.scans(scan_id),
  out_scan_id uuid references public.scans(scan_id),
  entered_by_admin boolean not null default false,
  manual_reason text,
  created_at timestamptz not null default now(),
  constraint attendance_time_order check (time_out is null or time_out >= time_in),
  constraint attendance_manual_reason check (
    entered_by_admin = false or nullif(trim(manual_reason), '') is not null
  )
);

alter table public.scans
  add constraint scans_session_fk foreign key (session_id)
  references public.attendance_sessions(id);

create table public.weekly_exports (
  id uuid primary key default gen_random_uuid(),
  week_start date not null,
  exported_at timestamptz not null default now(),
  exported_by uuid not null references public.profiles(id),
  file_name text,
  row_count integer,
  changed_after_export boolean not null default false,
  changed_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.settings (
  key text primary key,
  value jsonb not null,
  updated_by uuid references public.profiles(id),
  updated_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create table public.audit_logs (
  id bigint generated always as identity primary key,
  at timestamptz not null default now(),
  actor_id uuid,
  actor_role text,
  action text not null,
  table_name text,
  record_id text,
  before jsonb,
  after jsonb,
  reason text,
  meta jsonb
);

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references public.profiles(id),
  type text not null,
  params jsonb not null default '{}',
  target text,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.id_counters (
  prefix text primary key check (prefix in ('W', 'T', 'A')),
  last_value bigint not null default 0 check (last_value >= 0)
);

create unique index field_assignments_current_technician
  on public.field_assignments (technician_id)
  where unassigned_at is null;
create unique index devices_approved_technician
  on public.devices (technician_id)
  where status = 'approved';
create index workers_name_idx on public.workers (lower(name));
create index workers_duplicate_idx on public.workers (lower(name), date_of_birth);
create index scans_technician_scanned_at_idx on public.scans (technician_id, scanned_at);
create index scans_worker_scanned_at_idx on public.scans (worker_id, scanned_at);
create index scans_received_at_idx on public.scans (received_at);
create unique index open_session_per_worker_date
  on public.attendance_sessions (worker_id, work_date)
  where time_out is null;
create index attendance_worker_date_idx on public.attendance_sessions (worker_id, work_date);
create index attendance_technician_date_idx on public.attendance_sessions (technician_id, work_date);
create index attendance_work_date_idx on public.attendance_sessions (work_date);

comment on table public.workers is 'Worker records; workers never authenticate.';
comment on table public.scans is 'Every received scan, including ignored and blocked results.';
comment on table public.attendance_sessions is 'Authoritative in/out pairs used for attendance hours.';
