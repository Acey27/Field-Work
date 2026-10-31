# CONTRACT.md: QR Attendance System

**Status:** DRAFT v0.1, 27 Oct 2026. Not agreed until both developers sign off at the bottom.
**Parties:** Person A (field app) and Person B (database, security, admin website).
**Source of truth:** `docs/SPEC.md`. If this file and the spec disagree, the spec wins until the spec is changed. Then fix this file in the same pull request.

## 0. How to use this file

- Every table, column, function, error code, and setting that both of you depend on is listed here. If it is not here, do not depend on it.
- Anything marked **[P]** is a proposal that fills a gap in the spec. It is not in the spec. Confirm or change each one in your first sync (see Section 17).
- Unmarked rules come directly from the spec.
- Change rule: a change to this file goes in the same pull request as the code that needs it, the other person must approve it, and you add a line to the Change log (Section 18).
- Copilot prompts start with: "Read docs/SPEC.md section N and docs/CONTRACT.md."

---

## 1. Conventions

### 1.1 Naming

| Thing | Rule | Example |
| --- | --- | --- |
| Tables, columns, functions, enum values | `snake_case` | `attendance_sessions`, `time_in` |
| JSON keys (function inputs and outputs) | `snake_case` | `scan_id`, `worker_id` |
| Function parameters | `p_` prefix | `p_work_date` |
| Dart fields | `camelCase`, mapped in the model's `fromJson` | `workDate` |
| l10n keys (ARB files) | `camelCase` | `endFieldDay` |
| Error l10n keys | `err` + PascalCase of the code without `E_` | `E_DEVICE_NOT_APPROVED` becomes `errDeviceNotApproved` |
| Migrations | `NNN_short_name.sql`, never edited after merge | `001_core_tables.sql` |

### 1.2 People IDs

| Who | Format | Primary key |
| --- | --- | --- |
| Worker | `W-00001` | `workers.id` (text, this is the key) |
| Technician | `T-00001` | `profiles.id` is a uuid (Supabase Auth user id). `profiles.code` holds `T-00001`. |
| Admin | `A-00001` | Same as technician. |
| Super Admin | no code (`code` is null) | `profiles.id` |

- Counters have **5 digits**. Examples in the spec that show `T-001` are shorthand. The real format is `T-00001`.
- IDs come only from the database function `next_id(prefix)`. The app never makes an ID.
- Technicians and workers are referred to by `workers.id` (text) and `profiles.id` (uuid) in every table and function. `code` is for display and for QR cards.

### 1.3 QR payload

- Format: `<worker id>.<qr_check>`, for example `W-00123.k7x`.
- `qr_check` is 3 random lowercase base36 characters, stored in `workers.qr_check`. **[P]** A new card gets a new random value and the old one stops working.
- Valid pattern: `^W-\d{5}\.[0-9a-z]{3}$`. The app splits on the last `.`.
- The QR holds nothing else. No name, no phone number.

### 1.4 Time (most common bug source, read carefully)

- Every timestamp is stored as `timestamptz`, which means UTC underneath.
- Attendance times (`time_in`, `time_out`, `scanned_at` used for sessions) are **truncated to the minute** before storing: `date_trunc('minute', ...)`.
- A **date** (`work_date`, `week_start`) is always the calendar date in `Asia/Manila` (UTC+8). Never use `current_date`, `now()::date`, or `DateTime.now().toLocal()` to decide a date.
- A **week** runs Monday to Sunday. `week_start` is always a Monday.
- Boundary to remember: `15:59 UTC` is 11:59 PM Philippine time on the same date. `16:00 UTC` is 12:00 AM on the next date.

Database helpers (internal, not callable by the app):

| Function | Returns | Rule |
| --- | --- | --- |
| `ph_date(ts timestamptz)` | `date` | `(ts at time zone 'Asia/Manila')::date`, immutable |
| `ph_today()` | `date` | `ph_date(now())` |
| `ph_week_start(d date)` | `date` | `date_trunc('week', d)::date` (Monday) |
| `ph_time_of_day(ts timestamptz)` | `time` | local clock time in Manila, used for scan-hours checks |

Dart helpers in `core/utils/ph_time.dart` **[P names]**:

| Function | Rule |
| --- | --- |
| `DateTime phDateOf(DateTime utc)` | Returns the Philippine calendar date (UTC+8) as a date-only value |
| `DateTime phWeekStart(DateTime phDate)` | Returns the Monday of that week |
| `String formatMinutes(int minutes)` | See Section 12 |

Wire format: timestamps are ISO 8601 in UTC with `Z` (`2026-10-19T22:02:00Z`). Dates are `YYYY-MM-DD`.

### 1.5 Roles

| Role value | Notes |
| --- | --- |
| `super_admin` | Can do everything an admin can, plus audit logs, retention, and managing admins |
| `admin` | Everything in spec section 2 for Admin |
| `technician` | Scanner, End field day, own field, worker lookup for the current week. Nothing else. |

- Workers are rows in `workers`. They never log in.
- A logged-out request (`anon`) must get nothing from any table or function except `ping()`.

**Sessions and logging out (app).**

- The app has a real log out (`auth.signOut`): the Log out button on the admin and super admin screens and the icon in the scanner bar. Waiting scans stay in the phone's database; a technician who logs out with scans waiting is asked first.
- A technician who is still logged in when the admin turns the account off, or turns this phone off (revoked), is logged out by the app: `get_my_context` (checked about every 30 seconds while online, and on every sync) answers `E_ACCOUNT_DISABLED` or `E_DEVICE_REVOKED`, the app stops scanning, signs out and shows the reason on the login page. A phone with no internet cannot learn this until it reaches the server; the server refuses every upload from a disabled account regardless. Other codes (`E_DEVICE_PENDING`, `E_DEVICE_NOT_APPROVED`, `E_NO_ACTIVE_FIELD`) stop scanning with a message but do not log out, and the phone looks again every 30 seconds.
- Uploads only carry the signed-in technician's own waiting scans (`pendingScans(technicianId)`), so another technician who logs in on the same phone never uploads someone else's scans.
- An access token that expired while a browser tab or computer slept (`401` with `PGRST303`, "JWT expired") is renewed by the HTTP client and the same request is sent once more. When the refresh token is gone too, the session is ended and the app returns to the login page with "Your session ended" (`E_SESSION_ENDED`, an app-side code, not returned by the database).

### 1.6 Soft delete

Nothing a person can delete from the screen is erased at once.

- Workers: `active = false` and `deleted_at` set.
- Fields with history: `archived_at` set (and `active = false`). A field with no history may be erased.
- Technicians and admins: `active = false` (and the Auth user is banned by the Edge Function).
- Only the retention jobs (Section 9) remove attendance rows and logs.

### 1.7 Database function rules (for Person B)

- Client-callable functions are `SECURITY DEFINER` with `set search_path = public`.
- Run `revoke execute on all functions in schema public from public, anon`. Then `grant execute` only on the functions listed in Section 4 to `authenticated`.
- Every client-callable function starts with `require_active_user()` (profile exists, `active`, and `must_change_password` is false) and then checks the role it needs.
- Do not name anything `current_role`. It is a reserved word in Postgres. Use `app_role()`.

Role helpers (internal): `app_role()`, `is_admin()` (true for `admin` and `super_admin`), `is_super_admin()`, `is_technician()`.

---

## 2. Tables

Types: `uuid`, `text`, `int`, `bool`, `date`, `timestamptz`, `jsonb`. "FK" means foreign key. Every table also has `created_at timestamptz not null default now()` unless noted.

### 2.1 `profiles` (technicians, admins, super admin)

| Column | Type | Notes |
| --- | --- | --- |
| `id` | uuid PK | = `auth.users.id` |
| `code` | text unique null | `T-00001` or `A-00001`. Null for super admin. Default from `next_id()` |
| `role` | `app_role` not null | |
| `full_name` | text not null | |
| `username` | text unique null | Technicians only. Lowercase, 3 to 30 chars, letters, digits, `.`, `_` |
| `active` | bool not null default true | |
| `must_change_password` | bool not null default true | True until first login completes (Section 5) |
| `created_by` | uuid FK profiles null | |
| `deactivated_at` | timestamptz null | |

### 2.2 `workers`

| Column | Type | Notes |
| --- | --- | --- |
| `id` | text PK | `W-00001`, default `next_id('W')` |
| `name` | text not null | |
| `cp_no` | text null | Personal data |
| `address` | text null | Personal data |
| `gender` | text null | **[P]** Not used since migration 018 (SPEC section 3). The column stays; the app and the import neither read nor write it |
| `date_of_birth` | date null | Not used since migration 018. The column stays; nothing reads or writes it |
| `qr_check` | text not null | See 1.3. Default: random 3 characters |
| `qr_version` | int not null default 1 | +1 on every reissue |
| `active` | bool not null default true | |
| `deleted_at` | timestamptz null | |
| `updated_at` | timestamptz not null default now() | Used by the phone cache sync |

Indexes: `lower(name)`, and `(lower(name), date_of_birth)` (not unique). Duplicate warnings compare `lower(btrim(name))` only (migration 018).

### 2.3 `fields`

| Column | Type | Notes |
| --- | --- | --- |
| `id` | uuid PK | |
| `name` | text not null | For example `Field 1` |
| `location` | text null | |
| `address` | text null | |
| `active` | bool not null default true | |
| `archived_at` | timestamptz null | |

### 2.4 `field_assignments`

| Column | Type | Notes |
| --- | --- | --- |
| `id` | uuid PK | |
| `technician_id` | uuid FK profiles not null | |
| `field_id` | uuid FK fields not null | |
| `assigned_at` | timestamptz not null default now() | |
| `unassigned_at` | timestamptz null | Null means current |
| `assigned_by` | uuid FK profiles | |

**[P]** Partial unique index on `(technician_id) where unassigned_at is null`: a technician has at most one current field. A field can have many technicians.

### 2.5 `devices`

| Column | Type | Notes |
| --- | --- | --- |
| `id` | uuid PK | |
| `technician_id` | uuid FK profiles not null | |
| `device_uuid` | uuid not null | Made by the app on first install, kept in `local_meta` |
| `label` | text null | Phone model, for the admin |
| `status` | `device_status` not null | `pending`, `approved`, `revoked` |
| `registered_at` | timestamptz not null default now() | |
| `approved_by` | uuid null | |
| `approved_at` | timestamptz null | |
| `last_seen_at` | timestamptz null | |
| `last_sync_at` | timestamptz null | Updated by `ingest_scans`. Shown as "Last sync" |

Unique: `(technician_id, device_uuid)`. Partial unique: `(technician_id) where status = 'approved'` (one approved phone each).

### 2.6 `field_days`

| Column | Type | Notes |
| --- | --- | --- |
| `id` | uuid PK | |
| `technician_id` | uuid FK profiles not null | |
| `field_id` | uuid FK fields not null | |
| `work_date` | date not null | Philippine date |
| `status` | `field_day_status` not null default `working` | `working` or `ended`. **"Not ended" is never stored** (see 4.9) |
| `ended_at` | timestamptz null | |
| `ended_by` | uuid FK profiles null | |
| `end_method` | `end_method` null | `technician` or `admin` |
| `first_reminder_at` | timestamptz null | Set by the reminder job |
| `second_reminder_at` | timestamptz null | |

Unique: `(technician_id, work_date)`. **[P]** The row is created automatically by `ingest_scans` on the technician's first accepted scan of that date, or by an admin manual entry.

### 2.7 `scans`

One row per scan received, including ignored and blocked ones, so uploading twice is safe.

| Column | Type | Notes |
| --- | --- | --- |
| `scan_id` | uuid PK | Made by the phone. This is what makes uploads safe to repeat |
| `worker_id` | text FK workers null | Null for an unknown worker rejected by validation |
| `submitted_worker_id` | text null | Original worker ID submitted by the phone; retained for blocked unknown-worker scans |
| `technician_id` | uuid FK profiles not null | |
| `field_id` | uuid FK fields not null | |
| `device_id` | uuid FK devices not null | |
| `scanned_at` | timestamptz not null | Phone time, truncated to the minute for sessions but stored to the second here **[P]** (the 30-second rule needs seconds) |
| `received_at` | timestamptz not null default now() | Server time |
| `lat` / `lng` | numeric null | Only if the technician allowed location |
| `result` | `scan_result` not null | See Section 3 |
| `session_id` | uuid FK attendance_sessions null | Session opened or closed by this scan |
| `flags` | text[] not null default '{}' | See Section 3 |
| `clock_offset_seconds` | int null | Phone clock minus server clock at upload **[P]** |

Indexes: `(technician_id, scanned_at)`, `(worker_id, scanned_at)`, `(received_at)`.

### 2.8 `attendance_sessions`

One row per in-and-out pair. Hours always come from here, never from raw scans.

| Column | Type | Notes |
| --- | --- | --- |
| `id` | uuid PK | |
| `worker_id` | text FK workers not null | |
| `technician_id` | uuid FK profiles not null | The technician who clocked the worker **in** |
| `field_id` | uuid FK fields not null | |
| `field_day_id` | uuid FK field_days not null | |
| `work_date` | date not null | `ph_date(time_in)`, set by trigger, not by the caller |
| `time_in` | timestamptz not null | Minute precision |
| `time_out` | timestamptz null | Null means still clocked in |
| `closed_by` | `close_reason` null | `scan`, `end_field_day`, `admin`, `safety_net` |
| `in_scan_id` / `out_scan_id` | uuid FK scans null | Null for manual records |
| `taken_over` | bool not null default false | True when this session was opened by a scan that closed another technician's open session (safety net). While it is open, only its own technician can clock the worker out (Section 4.6, rule 6). Added in migration 019 |
| `entered_by_admin` | bool not null default false | Shown as "Entered by admin" |
| `manual_reason` | text null | Required when `entered_by_admin` is true |

Constraints:
- `time_out is null or time_out >= time_in`.
- `time_out is null or ph_date(time_out) = work_date` (a session never crosses midnight).
- Partial unique index on `(worker_id, work_date) where time_out is null`: a worker has at most one open session per date.
- No two sessions of the same worker may overlap in time (enforced by the functions, error `E_OVERLAP`).

Indexes: `(worker_id, work_date)`, `(technician_id, work_date)`, `(work_date)`.
Minutes of a session = whole minutes between `time_in` and `time_out`. An open session counts as 0 minutes.

### 2.9 `weekly_exports`

| Column | Type | Notes |
| --- | --- | --- |
| `id` | uuid PK | |
| `week_start` | date not null | Monday |
| `exported_at` | timestamptz not null default now() | |
| `exported_by` | uuid FK profiles not null | |
| `file_name` | text null | |
| `row_count` | int null | |
| `changed_after_export` | bool not null default false | |
| `changed_at` | timestamptz null | |

A week may have several exports (corrected copies). The **latest** export row of a week is the one that matters. A trigger on `attendance_sessions` sets `changed_after_export = true` on the latest export of the affected week when a session of that week is inserted, updated, or deleted after `exported_at`.

### 2.10 `settings`

`key text PK`, `value jsonb not null`, `updated_by uuid`, `updated_at timestamptz`. Keys are in Section 14.

### 2.11 `audit_logs`

| Column | Type | Notes |
| --- | --- | --- |
| `id` | bigint identity PK | |
| `at` | timestamptz not null default now() | |
| `actor_id` | uuid null | Null for the system (cron jobs) |
| `actor_role` | text null | |
| `action` | text not null | `insert`, `update`, `delete`, or an event name from the list below |
| `table_name` | text null | |
| `record_id` | text null | |
| `before` / `after` | jsonb null | |
| `reason` | text null | |
| `meta` | jsonb null | |

Event names for actions that are not row changes: `login`, `login_failed`, `csv_upload`, `weekly_export`, `field_day_ended_manually`, `time_record_added`, `time_record_fixed`, `setting_changed`, `role_changed`, `account_disabled`, `device_approved`, `device_revoked`.

- Row-change entries are written by **database triggers** on every table except `audit_logs`, `scans`, and `id_counters` **[P]** (scans are too many, their content is already in `scans`).
- The reason for a change is passed to the trigger with `set_config('app.audit_reason', p_reason, true)` before the change. The trigger reads it with `current_setting('app.audit_reason', true)`. **[P]**
- Nobody can update or delete audit rows from the app. Only the retention job removes old rows.

### 2.12 `notifications`

| Column | Type | Notes |
| --- | --- | --- |
| `id` | uuid PK | |
| `recipient_id` | uuid FK profiles not null | |
| `type` | text not null | See Section 15 |
| `params` | jsonb not null default '{}' | Data only. The app builds the sentence from l10n. **Never store translated text.** |
| `target` | text null | Where a tap goes, for example `today_field_days` |
| `read_at` | timestamptz null | |

### 2.13 `id_counters` (internal)

`prefix text PK` (`W`, `T`, `A`), `last_value bigint not null`. No app access. `next_id(prefix)` does `update ... set last_value = last_value + 1 returning last_value`, which locks the row, so two admins can never get the same number. Result: `prefix || '-' || lpad(n::text, 5, '0')`.

---

## 3. Enums and flags

| Enum | Values |
| --- | --- |
| `app_role` | `super_admin`, `admin`, `technician` |
| `device_status` | `pending`, `approved`, `revoked` |
| `field_day_status` | `working`, `ended` |
| `end_method` | `technician`, `admin` |
| `close_reason` | `scan`, `end_field_day`, `admin`, `safety_net` |
| `scan_result` | `clocked_in`, `clocked_out`, `ignored_repeat`, `blocked_bad_qr`, `blocked_unknown_worker`, `blocked_inactive_worker`, `blocked_inactive_field`, `blocked_inactive_technician`, `blocked_not_assigned`, `blocked_held_elsewhere` (added in migration 019) |

**Scan flags** (values inside `scans.flags`) **[P names]**:

| Flag | Meaning |
| --- | --- |
| `outside_hours` | `ph_time_of_day(scanned_at)` is outside `scan_hours_start` to `scan_hours_end`. The scan is saved and counted |
| `clock_skew` | The phone clock differed from the server clock by more than `clock_skew_minutes` at upload |
| `after_field_end` | Scan arrived for a field day that was already ended (see Section 17, item 6) |
| `safety_net_close` | This scan closed another technician's open session |
| `no_location` | No coordinates were sent |

The flagged list (admin) also shows **burst** scans, which are computed by a query and not stored (Section 4.12).

---

## 4. Database functions (called by the app with `supabase.rpc`)

Errors are raised as `RAISE EXCEPTION '<E_CODE>' USING ERRCODE = 'P0001', DETAIL = '<json params>'`. The app reads `PostgrestException.message` as the code. All codes are in Section 13.

### 4.1 `ping()` returns `{ "now": "<utc>" }`

Callable by `anon` and, since migration 018, by signed-in users. Used by the keep-alive job and by the scanner, which asks the server a real question before it says Online (a wifi or mobile link alone does not mean the internet works). Touches no table.

### 4.2 `register_device(p_device_uuid uuid, p_label text)` (technician)

Returns `{ "device_id": uuid, "status": "approved" | "pending" }`.

- First phone for this technician: status `approved` at once.
- A different phone when one is already approved: status `pending`, and every admin gets a `device_approval_needed` notification. The new phone cannot sync until approved.
- Same `device_uuid` called again: returns its current status.

### 4.3 `approve_device(p_device_id uuid)` and `revoke_device(p_device_id uuid)` (admin)

- `approve_device`: sets the chosen device `approved`, and sets any other approved device of that technician to `revoked` (the old phone is logged out the next time it syncs, error `E_DEVICE_REVOKED`).
- `revoke_device`: sets `revoked`. Used when a phone is lost.
- Both write an audit entry.

### 4.4 `get_my_context(p_device_uuid uuid)` (technician)

Called on app start and after every login. Returns:

```json
{
  "profile": { "id": "uuid", "code": "T-00007", "full_name": "John Doe" },
  "field": { "id": "uuid", "name": "Field 1", "location": "…" },
  "device": { "status": "approved" },
  "settings": {
    "scan_hours_start": "04:00", "scan_hours_end": "21:00",
    "reminder_time": "17:00", "technician_reminder_enabled": true
  },
  "server_time": "2026-10-19T22:02:00Z"
}
```

`get_login_state()` is a signed-in bootstrap helper used only after Auth
login. It returns the caller's role and `must_change_password` state without
exposing profile rows to a first-login account. It is not a substitute for
`require_active_user()`.

`field` is null when the technician has no current assignment (the app shows `E_NO_ACTIVE_FIELD`). The app may use `server_time` to warn about a wrong phone clock.

### 4.5 `get_worker_cache(p_since timestamptz default null)` (technician)

Returns rows `{ id, name, active, qr_check, updated_at }` for workers changed since `p_since` (all of them when null). Deleted workers come back with `active = false`. **Never** returns address, phone, date of birth, or gender.
**[P]** The cache holds **all** workers, not only one field's, because the spec lets a worker move between fields and does not define a per-technician worker list (Section 17, item 3).

### 4.6 `ingest_scans(p_device_uuid uuid, p_device_time timestamptz, p_scans jsonb)` (technician)

Input `p_scans` is an array of at most **50** items, sorted by `scanned_at` ascending:

```json
[
  { "scan_id": "uuid", "worker_id": "W-00123", "qr_check": "k7x",
    "field_id": "uuid", "scanned_at": "2026-10-19T22:02:41Z",
    "lat": 16.7, "lng": 121.6 }
]
```

`p_device_time` is the phone's clock at the moment of upload. The server computes `clock_offset_seconds = p_device_time - now()` and sets `clock_skew` on every scan of the batch when the absolute offset is over `clock_skew_minutes`. **[P]** (The spec says to flag when phone and server time "differ by a lot". Comparing `scanned_at` to `received_at` would flag every offline scan, so the offset is measured at upload instead.)

Output:

```json
{
  "server_time": "2026-10-19T22:30:00Z",
  "results": [
    { "scan_id": "uuid", "result": "clocked_in", "duplicate": false,
      "session_id": "uuid", "time": "2026-10-19T22:02:00Z",
      "closed_session_id": null, "flags": [] }
  ]
}
```

A batch-level problem (device not approved, account disabled, more than 50 items) raises an error and **nothing** is saved. Per-scan problems never raise. They come back in `result`.

Rules, in order, for each scan (the server decides in or out, never the phone):

1. **Device and account.** Device must be `approved` and belong to the caller. Otherwise `E_DEVICE_NOT_APPROVED` / `E_DEVICE_PENDING` / `E_DEVICE_REVOKED`. Technician `active` or `E_ACCOUNT_DISABLED`. Update `devices.last_sync_at` and `last_seen_at`.
2. **Already received.** If `scan_id` exists: return the stored result with `duplicate: true`. Change nothing.
3. **Lock.** Take `pg_advisory_xact_lock(hashtext(worker_id))` so two technicians uploading at the same time cannot double-count a worker.
4. **Validate.** Worker exists (`blocked_unknown_worker`), `qr_check` matches (`blocked_bad_qr`), worker active (`blocked_inactive_worker`), field active (`blocked_inactive_field`), technician active (`blocked_inactive_technician`), and a `field_assignments` row for this technician and field covers `scanned_at` (`blocked_not_assigned`). A blocked scan is saved in `scans` with its result and creates no session.
5. **Repeat.** If the same worker was already accepted (`clocked_in` or `clocked_out`) by the same technician less than **30 seconds** before this scan, the result is `ignored_repeat` and nothing else happens.
6. **Date.** `work_date = ph_date(scanned_at)`. Find the worker's open session with that `work_date`. A session from an earlier date is never touched (a scan on a new date is always a new time in).
   - No open session: create the field day if needed, open a session, result `clocked_in`.
   - Open session by the **same** technician: close it at `date_trunc('minute', scanned_at)` with `closed_by = 'scan'`, result `clocked_out`.
   - Open session by **another** technician that was **not** itself a takeover (safety net): close that session at this scan's minute with `closed_by = 'safety_net'`, open a new session for this technician with `taken_over = true`, result `clocked_in`, flags include `safety_net_close`, and `closed_session_id` is returned. The first technician gets a `worker_clocked_out` notification (Section 15).
   - Open session by **another** technician that **was** a takeover (`taken_over = true`): the scan is refused with result `blocked_held_elsewhere`. It is saved in `scans` with no session, and nothing else changes (not even this technician's field day). Only the technician who holds the worker can clock them out. When they do, or End field day or the admin closes the session, any technician can clock the worker in again (migration 019).
7. **Flags.** Add `outside_hours`, `no_location`, and `after_field_end` where they apply. Flags never stop a scan.

### 4.7 `end_field_day(p_device_uuid uuid, p_work_date date, p_ended_at timestamptz)` (technician)

Returns `{ "field_day_id": uuid, "closed_count": 5, "ended_at": "…" }`.

- `p_work_date` must equal `ph_date(p_ended_at)` or `E_DATE_NOT_TODAY`. The server clamps `p_ended_at` to at most `now()` and truncates to the minute.
- Closes every open session of this technician for `p_work_date` with `time_in <= ended_at`: `time_out = ended_at`, `closed_by = 'end_field_day'`.
- Sets the field day to `ended`, `end_method = 'technician'`.
- Calling it again for an ended field day returns `closed_count: 0` with the original `ended_at`, and does not raise.
- **[P]** The phone may call this offline later (Section 10.4), so `p_ended_at` is phone time. The app must upload all scans first, in the same sync run.

### 4.8 Admin time functions (admin)

All of these require a `p_reason` of at least 3 characters (`E_REASON_REQUIRED`) and write an audit entry.

| Function | Input | Result |
| --- | --- | --- |
| `suggest_end_time(p_technician_id uuid, p_work_date date)` | | `{ "time": "<utc>" or null }`, the technician's last scan of that date |
| `admin_end_field_day(p_technician_id uuid, p_work_date date, p_ended_at timestamptz, p_reason text)` | Time is always required (the app fills in the suggestion for today) | Same shape as 4.7. Sessions closed with `closed_by = 'admin'`, field day `end_method = 'admin'` |
| `admin_add_time_record(p_worker_id text, p_field_id uuid, p_technician_id uuid, p_work_date date, p_time_in timestamptz, p_time_out timestamptz, p_reason text)` | | `{ "session_id": uuid }`. Creates the field day if missing. `entered_by_admin = true` |
| `admin_fix_time_record(p_session_id uuid, p_time_in timestamptz, p_time_out timestamptz, p_reason text)` | | `{ "session_id": uuid }`. The times must stay on the record's own date. Marks the record `entered_by_admin` |
| `get_sessions_for_date(p_date date default null)` **[P]** | `p_date` defaults to `ph_today()` | One row per session of that date for the admin day list: `session_id, worker_id, worker_name, technician_id, technician_code, technician_name, field_id, field_name, work_date, time_in, time_out, closed_by, entered_by_admin, manual_reason` |

Checks: `E_TIME_OUT_BEFORE_IN`, `E_TIME_IN_FUTURE`, `E_OVERLAP` (the worker already has a session overlapping that time; two records that only touch, such as 08:00 to 09:00 and 09:00 to 10:00, are allowed), `E_DATE_MISMATCH` (time out on a different Philippine date), `E_SESSION_NOT_FOUND` (unknown worker or record).

### 4.9 `get_today_field_days(p_date date default null)` (admin)

`p_date` defaults to `ph_today()`. Returns one row per field day:
`field_day_id, work_date, technician_id, technician_code, technician_name, field_id, field_name, status, ended_at, clocked_in_count, worked_count, last_sync_at`.
`field_day_id` and `work_date` are returned so the app can call `admin_end_field_day` for the right technician and date.
`last_sync_at` is the latest `devices.last_sync_at` of that technician.

`status` is one of `working`, `ended`, `not_ended`, and it is **computed**:
`not_ended` when the stored status is `working` and (`work_date < ph_today()` or the Philippine time is at or after `reminder_time`). Technicians with no field day on that date are not listed **[P]**.

**Earlier days (migration 020).** When `p_date` is null (the dashboard call), the result also includes the field days of earlier dates that are still `working` (never ended), as `not_ended`, newest date first. They are the same days the tile `field_days_not_ended` of `get_stats_today` counts, so the list and the tile always agree, and the admin can end them with `admin_end_field_day` (which takes any `work_date`). With a date passed, only that date is returned.

### 4.10 `get_my_field_day(p_work_date date default null)` (technician)

Returns the caller's own field day only:

```json
{ "field_day": { "status": "working", "ended_at": null },
  "clocked_in_count": 5,
  "sessions": [ { "worker_id": "W-00123", "worker_name": "Juan Dela Cruz",
                  "time_in": "…", "time_out": null } ] }
```

### 4.11 `get_worker_week(p_worker_id text)` (technician)

The technician "looks up a worker's time record for the current week". The week is always the current Philippine week, and there is no date input, so older weeks cannot be asked for.

```json
{ "worker_id": "W-00001", "name": "Zeann",
  "week_start": "2026-10-19", "week_end": "2026-10-25",
  "days": [ { "date": "2026-10-19", "minutes": 333 }, { "date": "2026-10-20", "minutes": null } ],
  "total_minutes": 1623, "present_days": 5 }
```

`minutes` is the total across **all** fields and technicians for that date **[P]**. It returns no field names and no technician names. Null means no time in that date.

### 4.12 Statistics and flagged list (admin)

| Function | Returns |
| --- | --- |
| `get_stats_today()` | `{ clocked_in_now, finished, technicians_working, fields_working, field_days_not_ended }` |
| `get_stats_week(p_week_start date)` | Per date: `workers_present`, `total_minutes`. Per field: `attendance_by_field` (field, present_days, total_minutes). Same two totals for the previous week for the comparison |
| `get_flagged_items(p_from date, p_to date)` | Rows `{ kind, scan_id, technician, worker, at, detail }` where `kind` is `outside_hours`, `clock_skew`, `after_field_end`, `safety_net_close`, `no_location`, or `burst`. `burst` = more than `burst_scan_count` scans from one device within `burst_window_seconds` |

Statistics read from `attendance_sessions`, not from `scans`. An open session adds 0 minutes.

How the numbers are worked out (migration 017):

- `get_stats_today`: `clocked_in_now` = workers with an open session today. `finished` = workers with a closed session today and none open. `technicians_working` and `fields_working` = field days of today whose stored status is `working` (this includes the ones that are already "Not ended"). `field_days_not_ended` = stored `working` and (earlier date, or today and the Philippine time is at or after `reminder_time`), the same rule as 4.9.
- `get_stats_week`: returns `{ week_start, days: [7 x { date, workers_present, total_minutes }], attendance_by_field: [{ field_id, field_name, present_days, total_minutes }], totals: { workers_present, total_minutes }, previous: { workers_present, total_minutes } }`. `workers_present` of a week is the sum of the daily counts (worker-days). `E_WEEK_NOT_MONDAY` if the date is not a Monday.
- `get_flagged_items`: `p_from` and `p_to` default to today. Each row also has `technician_code`, `worker_id`, and `detail = { field_name, result, lat, lng }`. `burst` rows are scans that have more than `burst_scan_count` scans from the same phone inside the previous `burst_window_seconds` (the index `scans_device_scanned_idx` supports this).

### 4.13 Weekly masterlist (admin)

| Function | Purpose |
| --- | --- |
| `weekly_masterlist(p_week_start date)` | The data for the Excel file and the print sheet. Rows described below. `E_WEEK_NOT_MONDAY` if the date is not a Monday |
| `get_unended_field_days(p_week_start date)` | Field days of that week still `not_ended`. The app calls it before export to show the warning |
| `record_weekly_export(p_week_start date, p_file_name text, p_row_count int)` | Inserts the `weekly_exports` row and an audit entry. Called by the app **after** the Excel file is made |

`weekly_masterlist` returns one row per technician, field, and worker:

```
technician_id, technician_code, technician_name,
field_id, field_name, field_location, field_address,
worker_id, worker_name,
mon_minutes, tue_minutes, wed_minutes, thu_minutes, fri_minutes, sat_minutes, sun_minutes,
total_minutes, present_days
```

Day columns are `int` minutes or `null`. Formatting into "5 hours 33 minutes" is done by the app with `formatMinutes` (Section 12). The exact rules are in Section 11.

**The files the app makes from it (migration 022 and the app fixes of 2026-11-01).**

- **Excel:** one sheet named `Masterlist`, and it is the sheet the file opens on (a new workbook has an empty `Sheet1`; the app renames that one, so there is no blank first tab). For each technician and field: a line with `ID`, `Name of Technician` and `Date` (the week, e.g. `Date: 19 Oct 2026 - 25 Oct 2026`) only (the field and its address are not printed, decided 2026-11-01), the 12 column headers, one row per worker, and a blank row. It is drawn as a table (borders on every cell, shaded headers, tall rows to sign in) and each column is as wide as its longest text. No Pay column; the Signature cells are empty. The text is always English, whatever the app language is (decision 12).
- **Print / PDF:** a 720 x 520 pt landscape page (smaller than A4 and Letter landscape on purpose: the browser prints the PDF at full size on Letter by default, and a full A4 landscape page lost the Signature column there), shown first in a full-screen landscape preview (`MasterlistPreviewPage`) with print and download buttons; the browser print window decides the paper layout, so the page tells the admin to choose Layout: Landscape, or to download the PDF and print it from a PDF viewer. The app passes `format: PdfPageFormat.a4.landscape` to `Printing.layoutPdf`, so the preview and the printer start in landscape. The table columns are shares of the page width, so the Signature column (the widest after the name) is inside the margins.
- **Before exporting:** if `get_unended_field_days` returned any field day of the week, the app asks the admin to confirm (SPEC section 12). 
- **Recording an export:** the app calls `record_weekly_export` after every successful export on every platform. On the web the file is downloaded and no path comes back, so a missing path is not a cancel there.
- **Changed after export:** the trigger on `attendance_sessions` marks the latest `weekly_exports` row of the Monday-week of the changed date (and of the old date, when a record moves). An update that changes no worker, technician, field, date or time marks nothing. A newer export of the same week starts unmarked.

### 4.14 Workers and import (admin)

Workers, fields, and field assignments are managed with normal table calls (`insert`, `update`) under the Row Level Security rules in Section 7. IDs and `qr_check` come from column defaults. There is no hard delete.

| Function | Purpose |
| --- | --- |
| `reissue_card(p_worker_id text)` | Sets a new random `qr_check`, `qr_version + 1`, `updated_at = now()`. Returns `{ "qr_payload": "W-00123.p2m" }`. Audit entry |
| `import_workers(p_rows jsonb, p_commit bool)` | See below |

`import_workers` input rows: `{ "row": 12, "name": "…", "cp_no": "…", "address": "…" }`. The app reads the CSV (columns `name, cp_no, address`), then sends the rows in chunks of at most 500. A header the app does not read (for example `cp number`, `gender`, `date_of_birth`) is not sent; the preview says "Column 'cp number' was not used". An extra `gender` or `date_of_birth` key sent by another client is ignored.

Output:

```json
{ "valid": 1987,
  "errors": [ { "row": 12, "code": "E_CSV_NAME_MISSING" } ],
  "duplicates": [ { "row": 40, "worker_id": "W-00031" } ],
  "inserted": 0 }
```

- `p_commit = false`: validate only (the preview). `p_commit = true`: insert every valid row. A bad row never stops the others. Duplicates (the same `lower(btrim(name))` as a saved worker) are inserted only if the admin confirms, so the app sends the confirmed duplicate rows in the next call with `"allow_duplicate": true` on the row. A preview inserts nothing, so the server cannot see a name repeated inside the file; the app finds those itself (the later rows are "same name as row N in this file") and confirms them with the same box. On commit the server also skips a later row whose name an earlier row of the same call or file just saved.
- Row error codes: `E_CSV_NAME_MISSING`, `E_CSV_ROW_TOO_LONG`. The app turns them into "Row 12: The name is missing". `E_CSV_DOB_INVALID` and `E_CSV_GENDER_INVALID` are no longer returned (migration 018).
- One audit entry per commit with the counts in `meta`.

Fields and technician accounts (migration 016). The app uses these instead of direct table writes:

| Function | Purpose |
| --- | --- |
| `admin_create_field(p_name text, p_location text, p_address text)` | Add a field. `E_FIELD_NAME_MISSING`. Audit entry |
| `admin_update_field(p_field_id uuid, p_name text, p_location text, p_address text)` | Edit a field. `E_FIELD_NAME_MISSING`, `E_FIELD_NOT_FOUND`. Audit entry |
| `admin_set_field_active(p_field_id uuid, p_active bool)` | Turn a field off or on. `E_FIELD_NOT_FOUND`. Audit entry |

The three field functions return the field as `jsonb` (`to_jsonb` of the row) since migration 018. Before that they returned the table row type, and the app's reading of the answer could fail after the change had already been saved.
| `admin_assign_field(p_technician_id uuid, p_field_id uuid)` | Closes the technician's current assignment and opens the new one in one step (2.4). Returns `{ assignment_id, changed }`; `changed` is false when the technician already has that field. `E_FIELD_NOT_FOUND`. Audit entry |
| `admin_set_technician_active(p_technician_id uuid, p_active bool)` | Turns a technician account off or on. Off also sets the approved phone to `revoked`. A profile with `active = false` can call nothing (Section 7). Audit events `account_disabled` / `account_enabled` |

`admin_set_technician_active` only changes the profile. Section 5 also describes an Edge Function `set_account_active` that bans the Supabase Auth user; that function is not built yet, so a turned-off technician can still sign in but every call is refused.

### 4.15 Settings and notifications

| Function | Who | Purpose |
| --- | --- | --- |
| `set_setting(p_key text, p_value jsonb)` | admin or super admin, depending on the key (Section 14) | Validates the type and range. `E_SETTING_UNKNOWN`, `E_SETTING_INVALID`, `E_FORBIDDEN`. Audit entry with before and after |
| `mark_notification_read(p_id uuid)` | recipient | Sets `read_at` |
| `get_my_notifications(p_limit int default 50)` | any signed-in user | The caller's own notifications, newest first: `id, type, params, target, read_at, created_at` (added with migration 015, so the app never reads other people's rows) |

### 4.16 Paper sheet data (admin) **[P]**

`get_paper_sheet(p_technician_id uuid, p_date date default null)` returns the data for the printable daily sheet (SPEC section 8):

```json
{ "technician": { "id": "uuid", "code": "T-00001", "name": "John Doe" },
  "field": { "id": "uuid", "name": "Field 1", "location": "…" },
  "work_date": "2026-10-29",
  "workers": [ { "id": "W-00001", "name": "Zeann" } ] }
```

`workers` are the active workers that technician scanned (clocked in or out) or had a time record for (including records the admin typed in, which have no scan) in the 14 days up to `p_date`, plus anyone with a record in the sheet's field on `p_date` (Section 17, item 3; widened in migration 018). The time boxes are not in the answer: they are written by hand. `field` is the current assignment, or the field of the last field day, or null. `E_FIELD_DAY_NOT_FOUND` if the technician does not exist. The app draws the PDF in the current language, with at least 25 rows and at least 8 blank rows.

---

## 5. Edge Functions (the service key lives only here)

Each one is called with the user's JWT. It checks the caller's role from `profiles` before doing anything. Error response: HTTP 4xx with `{ "error": "E_CODE", "params": { } }`.

| Function | Caller | Input | What it does |
| --- | --- | --- | --- |
| `create_technician_account` | admin | `{ email, full_name, starting_password }` | Creates the Auth user with the supplied email, `email_confirm = true`, inserts the profile (`T-` code, `must_change_password = true`). Returns `{ profile_id, code, email }`. Errors: `E_EMAIL_TAKEN`, `E_INPUT_INVALID`, `E_PASSWORD_WEAK` |
| `create_admin_account` | super admin | `{ email, full_name, starting_password }` | Same, with a real email and an `A-` code. Admin must set up MFA at first login |
| `reset_account_password` | admin (technicians), super admin (anyone) | `{ profile_id, new_starting_password }` | Sets a new one-time password and `must_change_password = true` |
| `set_account_active` | admin (technicians), super admin (anyone) | `{ profile_id, active }` | Sets `profiles.active`, bans or unbans the Auth user, signs out sessions. Disabling a technician also sets their approved device to `revoked`. Audit entry |
| `complete_first_login` | the user | `{ new_password }` | Checks the password rules, sets the new password, sets `must_change_password = false`. This makes the starting password work only once |
| `log_auth_event` **[P]** | anyone (rate limited) | `{ username_or_email, success }` | Writes `login` / `login_failed` audit entries and raises the "many failures" notice. Best effort, because failed logins happen inside Supabase Auth (Section 17, item 9) |

- Phase 2 uses normal email/password login for technicians. The original hidden-email username flow is deferred; the `profiles.username` column remains available for a later migration if the company requires username-only login.
- Password rules: minimum 10 characters, not on a common-password list **[P]**. The same rule applies in the app (for the message) and the Edge Function (for the real check).

---

## 6. Local database on the phone (Drift)

Owned by Person A. Listed here so Person B knows what the sync expects.

| Local table | Columns |
| --- | --- |
| `local_workers` | `id`, `name`, `active`, `qr_check`, `updated_at` |
| `local_scans` | `scan_id` (uuid, PK), `worker_id`, `field_id`, `technician_id`, `scanned_at` (UTC), `lat`, `lng`, `local_direction` (`in`, `out`, `ignored`), `upload_status` (`pending`, `uploaded`, `rejected`), `server_result`, `attempts`, `last_error`, `uploaded_at` |
| `local_events` | `event_id` (uuid, PK), `type` (`end_field_day`), `work_date`, `ended_at`, `upload_status`, `attempts`, `last_error` |
| `local_meta` | `key`, `value`: `device_uuid`, `last_worker_sync`, `last_sync_at`, `language` |

Rules:
- A scan is saved to `local_scans` **before** anything else happens, including the on-screen confirmation.
- The phone decides in or out locally only to show the confirmation, using its own scans of today. The server decides for real, and the result is stored in `server_result`. If the server disagrees, the next screen shows the server's result.
- Keep `uploaded` rows for at least 2 days, then delete them. Never delete `pending` rows.
- The phone stores only `id`, `name`, `active`, `qr_check` for workers. No address, phone, or birth date.

---

## 7. Row Level Security

Rule: Postgres RLS works per row, not per column. So a technician gets **no direct table access** to `workers`, `scans`, or `attendance_sessions`. They use the functions in Section 4, which return only the safe columns.

`R` = select, `I` = insert, `U` = update, `D` = delete, `fn` = only through a function, `none` = no access, `own` = only rows that belong to the caller.

| Table | technician | admin | super_admin | anon |
| --- | --- | --- | --- | --- |
| `profiles` | R own | R all, `U` only through Edge Functions | R all, `U` through Edge Functions | none |
| `workers` | none (uses `get_worker_cache`, `get_worker_week`) | R, I, U, no D | same as admin | none |
| `fields` | R own current field | R, I, U, D only if no history | same | none |
| `field_assignments` | R own | R, I, U | same | none |
| `devices` | R own | R, changes `fn` | same | none |
| `field_days` | R own | R, changes `fn` | same | none |
| `scans` | none | R | R | none |
| `attendance_sessions` | none | R, changes `fn` | same | none |
| `weekly_exports` | none | R, I `fn` | same | none |
| `settings` | none (uses `get_my_context`) | R, `U` `fn` | R, `U` `fn` | none |
| `audit_logs` | none | **none** | R | none |
| `notifications` | R own, U own (`read_at`) | R own, U own | R own, U own | none |
| `id_counters` | none | none | none | none |

Additional rules:
- `scans`, `attendance_sessions`, `field_days`, `devices`, `weekly_exports`, `audit_logs`: no `INSERT`, `UPDATE`, or `DELETE` policy for any app role. Writes go through the Section 4 functions and triggers.
- A profile with `active = false` or `must_change_password = true` can read nothing and call nothing.
- A technician can only add scans for the field they are currently assigned to (checked in `ingest_scans`, rule 4).
- Admin and Super Admin accounts require MFA (Supabase MFA, free). A session without MFA sees nothing.
- `supabase/tests/roles.sql` must try every forbidden action as each role and show it fails (Section 10 of the build guide).

---

## 8. Sync protocol (phone and server)

1. The phone saves each scan in `local_scans` (`pending`).
2. When online (check with `connectivity_plus` and then a real call), the sync loop runs. It never polls more often than once every 30 seconds **[P]**. The real call is `ping()` (4.1): the status says Online only after the server answered. The phone asks again every 10 seconds while Offline and every 30 seconds while Online, on every network change and when the app comes back to the front, and at the same time looks for the technician's own unread notices (`worker_clocked_out`, Section 15). A failed sync is retried (item 5) even when no scan is waiting.
3. Upload order: first `get_worker_cache` (if due), then `ingest_scans` in batches of **50**, oldest first, then any `local_events` (`end_field_day`) in order.
4. For each result in the response, mark the matching row `uploaded` and store `server_result`. A `blocked_*` result marks the row `rejected` and shows the technician a message (Section 13).
5. If the call fails because of the network or a server error, keep everything `pending`, increase `attempts`, and retry later with growing waits (30 s, 1 min, 2 min, then every 5 min). Repeating is safe because of `scan_id`.
6. A batch-level error (`E_DEVICE_*`, `E_ACCOUNT_DISABLED`) stops the loop and shows the message. Scans stay `pending`.
7. The status line shows: `Online`, `Offline: N scans waiting`, or `Syncing...`. N counts `pending` scans plus `pending` events.
8. Before End field day, if any scan is `pending`, the app warns: "3 scans not uploaded. Connect to the internet." The warning does not block the button **[P]** (Section 17, item 5).

---

## 9. Scheduled jobs

`pg_cron` runs on UTC. Philippine time is UTC+8, so 01:00 PH = 17:00 UTC the day before.

| Job | Schedule (UTC cron) | Philippine time | What it does |
| --- | --- | --- | --- |
| `job_field_day_reminders` | `*/5 * * * *` | every 5 minutes | If Philippine time is at or after `reminder_time`: for today's field days still `working` with `first_reminder_at` null, send **one** notification to all admins listing those technicians and set `first_reminder_at`. After `reminder_repeat_minutes`, do the same once more for those still `working` with `second_reminder_at` null. Then no more |
| `job_retention_notices` | `0 17 * * *` | 01:00 daily | For each week that will become eligible for deletion within `retention_notice_days`: notify admins (`attendance_deletion_notice`). Notify the super admin of audit rows that will be deleted (`audit_deletion_notice`) |
| `job_retention_delete` | `0 18 * * *` | 02:00 daily | See below |
| Keep-alive | GitHub Actions, every 3 days | n/a | Calls `ping()` |

`job_retention_delete`:
- **Attendance.** A week is eligible when its Sunday is older than `attendance_retention_days` and its latest `weekly_exports` row exists and has `changed_after_export = false` **[P]** (a week changed after export is kept until it is exported again). Delete that week's `attendance_sessions`, `scans`, and `field_days`. **A week that was never exported is never deleted.**
- **Audit.** Delete `audit_logs` older than `audit_retention_days`, only after the notice was sent.
- Write one audit entry with the counts.

Backups: the free plan has none. Who runs the weekly backup is an open item in the spec (Section 17, item 10). The backup contains personal data and stays private.

---

## 10. Behavior details both sides must share

### 10.1 End field day button (technician home)

- Shows `clocked_in_count` workers still clocked in. From `get_my_field_day` when online and nothing is waiting to upload (it knows about workers closed on another phone, Section 15); from `local_scans` when offline or while scans are waiting. The confirmation asks the server first, so it does not show a worker who was already clocked out elsewhere.
- Confirmation text: "Clock out 5 workers at 4:52 PM?" The time is the phone's time in Philippine time.

### 10.2 Hours for a date

Hours of a worker for a date and technician = sum of that technician's session minutes on that `work_date`. Present for a date = at least one session with that `work_date`.

### 10.3 Admin "Entered by admin"

Any session with `entered_by_admin = true` shows the label in the admin screens. In the Excel file it looks like any other day.

### 10.4 End field day offline **[P]**

The phone saves a `local_events` row with `ended_at` = the phone's time, shows the field day as ended locally, and uploads it after the scans. The server still validates the date (4.7). If the phone clock was wrong, the `clock_skew` flag on the batch tells the admin.

---

## 11. Weekly masterlist rules

Given `p_week_start` (Monday), the week is `p_week_start` to `p_week_start + 6`.

1. Take every `attendance_sessions` row with `work_date` in the week.
2. Group by **technician and field** (one section each), then by worker.
3. A worker appears in a technician's section **only if that technician has at least one session for that worker in the week**. If the technician has no sessions for that worker all week, the worker is not in that section at all.
4. Inside a section, each day column shows the sum of **that technician's** session minutes for that date. A day the worker was not scanned by this technician stays blank (null), even if the worker worked that day for another technician.
5. `total_minutes` = sum of the section's day columns.
6. `present_days` = number of dates in the section that have at least one session by this technician (a time in), **not** the number of non-blank hours.
7. A worker who worked for two technicians on the same date appears in both sections, each with its own hours. Hours are never counted twice because the safety net closes the first session when the second technician scans.
8. Sections are ordered by technician code, workers by worker id **[P]**.
9. Open sessions (no time out) count as present and add 0 minutes. In the Excel file that day shows `Not ended` so it is not mistaken for zero hours **[P]**.
10. No Pay column. The Signature column is always blank.
11. Section header: technician id, technician name, field name, and the field's address **[P]** (see Section 17, item 4). Week label: `19-25 Oct 2026`.

### Worked example (use as the test fixture)

Week 19 to 25 Oct 2026. Minutes in brackets.

**T-00001 John Doe, Field 1**

| ID | Name | Mon | Tue | Wed | Thu | Fri | Sat | Sun | Total | Present |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| W-00001 | Zeann | 5 hours 33 minutes [333] | 5 hours [300] | | 6 hours 10 minutes [370] | 5 hours [300] | | 5 hours 20 minutes [320] | 27 hours 3 minutes [1623] | 5 |
| W-00002 | Czar | 10 hours [600] | | | 8 hours 15 minutes [495] | 2 hours [120] | 9 hours [540] | | 29 hours 15 minutes [1755] | 4 |

**T-00002 Juan Reyes, Field 2**

| ID | Name | Mon | Tue | Wed | Thu | Fri | Sat | Sun | Total | Present |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| W-00001 | Zeann | | 3 hours [180] | 5 hours [300] | | | 9 hours [540] | | 17 hours [1020] | 3 |
| W-00002 | Czar | | 10 hours [600] | 5 hours [300] | | 5 hours [300] | | 5 hours 20 minutes [320] | 25 hours 20 minutes [1520] | 4 |

Zeann on Tuesday is in both sections (5 hours with T-00001, 3 hours with T-00002). That is the "two fields on one date" case. `supabase/tests/fixtures/masterlist_example.sql` must create exactly these sessions, and a test must compare `weekly_masterlist` output to the minute values above.

---

## 12. Formats and test vectors

### 12.1 `formatMinutes(int minutes)`

- Hours and minutes in words, hours first. Singular for exactly 1 hour and exactly 1 minute.
- Zero hours part is left out. Zero minutes part is left out unless the total is zero.
- Hours never roll into days. 1623 minutes is `27 hours 3 minutes`.

| Minutes | Output |
| --- | --- |
| 0 | `0 minutes` |
| 1 | `1 minute` |
| 59 | `59 minutes` |
| 60 | `1 hour` |
| 61 | `1 hour 1 minute` |
| 120 | `2 hours` |
| 333 | `5 hours 33 minutes` |
| 1623 | `27 hours 3 minutes` |

### 12.2 `phDateOf` / `ph_date` test vectors

| UTC time | Philippine date |
| --- | --- |
| `2026-10-19T15:59:59Z` | `2026-10-19` |
| `2026-10-19T16:00:00Z` | `2026-10-20` |
| `2026-10-19T23:00:00Z` | `2026-10-20` |
| `2026-10-19T00:00:00Z` | `2026-10-19` |

Both the Dart tests and the SQL tests must pass these four rows.

---

## 13. Error codes

The app never shows the code. It shows the l10n message for the key (Section 1.1). Messages say what to do next. English text below. Filipino goes in `app_fil.arb`.

| Code | English message |
| --- | --- |
| `E_FORBIDDEN` | You are not allowed to do this. Ask your admin. |
| `E_ACCOUNT_DISABLED` | This account is turned off. Please contact your admin. |
| `E_MUST_CHANGE_PASSWORD` | Please choose a new password first. |
| `E_PASSWORD_WEAK` | This password is too easy. Use at least 10 characters and avoid common passwords. |
| `E_USERNAME_TAKEN` | This username is already used. Try another one. |
| `E_USERNAME_INVALID` | Use 3 to 30 letters, numbers, dots, or underscores. |
| `E_DEVICE_PENDING` | This phone is waiting for approval. Ask your admin to approve it. |
| `E_DEVICE_NOT_APPROVED` | This phone is not registered. Log in again to register it. |
| `E_DEVICE_REVOKED` | This phone is no longer allowed. Ask your admin. |
| `E_NO_ACTIVE_FIELD` | You have no field yet. Ask your admin to assign one. |
| `E_BATCH_TOO_LARGE` | Too many scans at once. The app will send them in smaller groups. |
| `E_DATE_NOT_TODAY` | You can only end the field day for today. |
| `E_DATE_MISMATCH` | The time in and time out must be on the same date. |
| `E_TIME_OUT_BEFORE_IN` | Time out must be later than time in. |
| `E_TIME_IN_FUTURE` | This time has not happened yet. Check the time. |
| `E_OVERLAP` | This worker already has time recorded at that time. Check the other records. |
| `E_REASON_REQUIRED` | Please write a reason. |
| `E_SESSION_NOT_FOUND` | This time record was not found. Refresh the list. |
| `E_FIELD_DAY_NOT_FOUND` | There is no field day for this technician on that date. |
| `E_WEEK_NOT_MONDAY` | A week must start on a Monday. |
| `E_SETTING_UNKNOWN` | This setting does not exist. |
| `E_SETTING_INVALID` | This value is not allowed for this setting. |
| `E_CSV_NAME_MISSING` | The name is missing. |
| `E_CSV_DOB_INVALID` | Not returned since migration 018 (date of birth is not used). |
| `E_CSV_GENDER_INVALID` | Not returned since migration 018 (gender is not used). |
| `E_CSV_ROW_TOO_LONG` | A value in this row is too long. |

Scan results shown on the scanner screen (these are `scan_result` values, not exceptions):

| `scan_result` | Screen |
| --- | --- |
| `clocked_in` | Green: "Juan Dela Cruz: CLOCKED IN 6:02 AM" |
| `clocked_out` | Green: "Juan Dela Cruz: CLOCKED OUT 4:52 PM" |
| `ignored_repeat` | Yellow: "Already scanned a moment ago." |
| `blocked_bad_qr` | Red: "This card is not valid. Ask your admin for a new card." |
| `blocked_unknown_worker` | Red: "This worker is not in the system. Tell your admin." |
| `blocked_inactive_worker` | Red: "This worker is turned off. Tell your admin." |
| `blocked_inactive_field` | Red: "This field is turned off. Tell your admin." |
| `blocked_inactive_technician` | Red: "Your account is turned off. Tell your admin." |
| `blocked_not_assigned` | Red: "You are not assigned to this field. Tell your admin." |
| `blocked_held_elsewhere` | Red: "Another technician has this worker clocked in. Only that technician can clock them out." |

The phone shows a scan as saved at once and learns the server's answer when it syncs. A refused result then appears as a message with the worker's name ("Juan dela Cruz: not saved. …"), the scan is marked `rejected` and no longer counts for in or out on the phone. The phone also learns that a worker was taken over from the `worker_clocked_out` notification (Section 15): until that worker is clocked out by the new holder, this phone treats its own earlier scans of the worker as closed, so the next scan is shown as a clock in, never as a clock out.

---

## 14. Settings keys

Value types are fixed. Times are `"HH:MM"` in Philippine time.

| Key | Default | Type | Who can change | Meaning |
| --- | --- | --- | --- | --- |
| `reminder_time` | `"17:00"` | time | admin | When the "not ended" check runs |
| `reminder_repeat_minutes` | `30` | int, 5 to 120 | admin | Wait before the one repeat reminder |
| `technician_reminder_enabled` | `true` | bool | admin | Gentle reminder on the technician phone at `reminder_time` |
| `scan_hours_start` | `"04:00"` | time | admin | Start of allowed scan hours |
| `scan_hours_end` | `"21:00"` | time | admin | End of allowed scan hours |
| `attendance_retention_days` | `15` | int, 7 to 365 | super admin | See Section 9 |
| `audit_retention_days` | `15` | int, 1 to 365 | super admin | See Section 9 |
| `retention_notice_days` | `3` | int, 1 to 14 | super admin | Days of warning before deletion **[P]** |
| `clock_skew_minutes` | `10` | int, 1 to 120 | super admin | Phone clock difference that gets flagged **[P]** |
| `burst_scan_count` | `10` | int | super admin | Burst flag threshold **[P]** |
| `burst_window_seconds` | `10` | int | super admin | Burst flag window **[P]** |

**Constants (not settings, the same value must be used in app and database):**

| Constant | Value |
| --- | --- |
| Repeat-scan ignore window | 30 seconds |
| Sync batch size | 50 scans |
| Max CSV import chunk | 500 rows |
| Week | Monday to Sunday, Asia/Manila |

---

## 15. Notification types

`params` holds data only. The app writes the sentence.

| `type` | To | `params` | `target` |
| --- | --- | --- | --- |
| `field_day_not_ended` | all admins | `{ work_date, reminder_number (1 or 2), technicians: [{ id, code, name, field_name }] }` | `today_field_days` |
| `device_approval_needed` | all admins | `{ technician_id, technician_name, device_label }` | `devices` |
| `attendance_deletion_notice` | all admins | `{ weeks: ["2026-10-05"], delete_on }` | `weekly_exports` (with an export button) |
| `audit_deletion_notice` | super admin | `{ delete_before, row_count }` | `audit_logs` (with an Export CSV button) |
| `failed_logins` | all admins | `{ username, count }` | `audit_logs` or none |
| `bulk_action` | super admin | `{ actor_id, action, count }` | `audit_logs` |
| `new_device_login` | the admin or super admin who logged in | `{ device_label, at }` | none. Planned after the first version |
| `worker_clocked_out` | the technician whose session was closed | `{ worker_id, worker_name, reason ("safety_net"), session_id, time_out }` | none. Written by a trigger on `attendance_sessions` when a second technician's scan closes the first technician's session (SPEC section 6). The scanner reads it with `get_my_notifications`, shows it until the technician closes it, and marks it read. Admin closes send nothing |

---

## 16. Migrations and ownership

| File | Owner | Content |
| --- | --- | --- |
| `001_core_tables.sql` | B | All tables and enums in Sections 2 and 3, indexes, comments |
| `002_ids_time_settings_audit.sql` | B | `id_counters`, `next_id`, time helpers, `settings` defaults, audit triggers, SQL tests |
| `003_rls.sql` | B (A reviews) | Section 7, role helpers, `revoke`/`grant` on functions, `tests/roles.sql` |
| `004_scan_functions.sql` | B (A reviews) | `register_device`, `get_my_context`, `get_worker_cache`, `ingest_scans`, `end_field_day`, `get_my_field_day`, `get_worker_week` |
| `005_phase2_remediation.sql` | B (A reviews) | `get_login_state`, corrected function volatility, and contract-aligned RLS/table privileges |
| `006_phase4_admin.sql` | B | Phase 4 admin dashboard, flagged activity, statistics, manual field-day ending, manual corrections, QR reissue, and CSV import |
| `021_masterlist.sql` | B (A tests lookup) | Section 4.13, export-change trigger, fixture, tests |
| `022_masterlist_export_fix.sql` | B | `mark_weekly_export_changed` uses the Monday of the changed date (section 4.13) |
| `007_worker_admin.sql` to `011_worker_audit_fix.sql` | B | Phase 4 worker, field, device and admin tool functions (already applied) |
| `012_field_days_admin.sql` | B | `get_today_field_days`, `suggest_end_time`, `admin_end_field_day` (sections 4.8, 4.9) |
| `013_settings_validation.sql` | B | `admin_set_setting` validates `HH:MM` and boolean values (`E_SETTING_INVALID`) |
| `014_settings_admin_scan_hours.sql` | B | Admins may change scan hours (section 14) |
| `015_reminders_notifications.sql` | B | `job_field_day_reminders` (pg_cron, every 5 minutes), `get_my_notifications`, `mark_notification_read`, settings `reminder_repeat_minutes`, `technician_reminder_enabled`, `burst_scan_count`, `burst_window_seconds` |
| `016_admin_records_sheet_assign.sql` | B | `admin_add_time_record` with `E_OVERLAP`, `admin_fix_time_record`, `get_sessions_for_date`, `get_paper_sheet`, `admin_update_field`, `admin_assign_field`, `admin_set_technician_active` (replaces the draft `admin_correct_session`) |
| `017_stats_flagged.sql` | B | `get_stats_today`, `get_stats_week`, `get_flagged_items` and the `scans_device_scanned_idx` index (replace the drafts `admin_statistics` and `admin_flagged_scans`) |
| `018_fixes_after_testing.sql` | B | Trigger `worker_clocked_out` notice (section 15), field functions return `jsonb` (section 4.14), `import_workers` without gender and date of birth, wider `get_paper_sheet` (section 4.16), `ping()` for signed-in users (section 4.1) |
| `019_takeover_once.sql` | B | `ingest_scans` refuses a scan for a worker another technician took over (`blocked_held_elsewhere`), new column `attendance_sessions.taken_over` (sections 2.8, 4.6, 13) |
| `020_old_field_days.sql` | B | `get_today_field_days` called without a date also lists earlier field days that were never ended (section 4.9) |
| `0NN_jobs_retention.sql` (planned) | B | Retention jobs, Section 9. Next free number after the migrations above |

App side (A): everything in Section 6 and 8, the scanner, End field day, and the technician screens. Both of you: this file, `core/l10n`, `core/router`, `core/theme`.

---

## 17. Open decisions (confirm in the first sync)

Each item has a recommended answer. Tick one when agreed.

1. **[ ] Super Admin can do everything an admin can.** Spec section 17 says "Everything", section 2 lists only extra powers. Recommended: yes, super admin includes admin.
2. **[ ] One current field per technician.** Spec says "assign one or more technicians to each field" and "each technician has one field day per date", but does not say a technician may have two fields. Recommended: one current field per technician (Section 2.4).
3. **[ ] Worker list on the phone.** The spec has no table that links workers to a technician or field, but it mentions "the usual workers of that technician" (paper sheet) and "the worker list for the technician's field" (phone cache). Recommended: the phone caches all active workers (names only), and the paper sheet lists workers that technician scanned in the last 14 days. If the company wants fixed rosters, add a `technician_workers` table later.
4. **[x] Masterlist section header "address".** Spec says "the technician's ID, name, field (location), and address". There is no technician address in the data. Decided 2026-11-01: neither the field nor its address is printed.
5. **[ ] End field day while offline.** The spec warns to connect before leaving, but does not say the button is blocked offline. Recommended: allowed offline, queued, uploaded after the scans (Sections 4.7, 8, 10.4).
6. **[ ] Scan after the field day was ended.** Spec does not say. Recommended: accept the scan, flag `after_field_end`, and set the field day back to `working` (clear `ended_at`) so the new session gets closed by the next End field day. The spec's flagged item "scans on a date when that technician had no field day" has no meaning, because a field day is created by the first scan. Recommended: replace it with `after_field_end`.
7. **[ ] Repeat-scan rule is per technician.** The 30-second ignore applies to the same worker and the same technician. A different technician scanning within 30 seconds is the safety-net case and is processed. Recommended: yes.
8. **[ ] Open sessions in the Excel file.** Recommended: count as present, 0 minutes, show `Not ended` (Section 11, rule 9).
9. **[ ] Failed-login logging.** Supabase Auth handles logins, so the app cannot write to the audit log by itself. Recommended: the app calls the `log_auth_event` Edge Function after each login attempt (client-reported, can be skipped by a hacked client). Supabase's own Auth logs remain the real record.
10. **[ ] Owners.** Super Admin account holder: ______ . Backup person: ______ . Weekly database backup: ______ , stored at: ______ .
11. **[ ] Burst threshold.** Default 10 scans in 10 seconds. A queue of workers scanned quickly at the start of the day could trigger it. Check with a real technician in the pilot.
12. **[ ] Excel language.** The accountant's file is always English. Recommended: yes, regardless of the app's language toggle.

---

## 18. Change log

| Date | Version | Who | Change |
| --- | --- | --- | --- |
| 2026-10-27 | 0.1 | draft | First draft from the spec and the build guide |
| 2026-10-28 | 0.1 | project note | Phase 3 integration verification is pending: technician account provisioning, field/worker test data, offline-to-Supabase sync, retry idempotency, role checks, and end-field-day behavior must be tested through the UI against the development project. Phase 4 may proceed, but Phase 3 is not signed off until these tests pass. |
| 2026-10-29 | 0.1 | project note | Section 4.9: `get_today_field_days` also returns `field_day_id` and `work_date`. Migrations 012 to 014 added (section 16). Section 14: admins (not only the super admin) change `scan_hours_start` and `scan_hours_end`, a company decision; SPEC section 2 updated in the same change. The technician app now calls `register_device` before `get_my_context` (sections 4.2, 4.4). |
| 2026-10-30 | 0.1 | project note | Migration 019: the safety net now happens once. A technician can take over a worker the first technician left clocked in; after that only the new holder can clock the worker out, and a scan by anyone else is refused (`blocked_held_elsewhere`, new `attendance_sessions.taken_over`). SPEC section 6 updated in the same change. The phone now shows a message for every refused (`blocked_*`) scan, and no longer shows CLOCKED OUT for a worker another technician took over. |
| 2026-10-29 | 0.1 | project note | Phase 4 completion (migrations 016, 017): sections 4.8 (`get_sessions_for_date`, overlap rule), 4.12 (how the statistics are worked out), 4.14 (field edit, one-step assignment, technician on/off) and new 4.16 (`get_paper_sheet`). The statistics and flagged functions now use the contract names; the drafts `admin_statistics`, `admin_flagged_scans` and `admin_correct_session` were dropped. The app now has a CSV file picker, chunks of 500, row-level messages and the duplicate confirmation. The Edge Function `set_account_active` (section 5) is still not built. |
| 2026-10-30 | 0.1 | project note | Fixes after testing on real devices (migration 018). Gender and date of birth are no longer used; duplicates are by name only (sections 2.2, 4.14; SPEC section 3). `worker_clocked_out` notification added (section 15). Field functions return `jsonb`. `get_paper_sheet` also lists workers with admin-entered records. `ping()` is open to signed-in users and the scanner uses it for Online or Offline. The scanner asks `get_my_field_day` for the clocked-in count when nothing is waiting to upload (section 10.1). The admin dashboard fetches again every 15 seconds while visible. The reminder time stays notice-only (SPEC section 8). Admin pages no longer call `setState` with a callback that returns a Future (a debug build threw before rebuilding, so saved changes did not show). |
| 2026-11-01 | 0.1 | project note | Phase 5 fixes after testing (migration 022). The Excel export no longer opens on a blank `Sheet1`: one sheet `Masterlist`, laid out per technician and field as SPEC section 12, always in English. The printout is A4 landscape in the preview and on paper, with column widths that fill the page so the Signature column is not cut. "Changed after export" now works: the trigger uses the Monday of the changed date, and the export is recorded on the web too (section 4.13). |
| 2026-10-31 | 0.1 | project note | Round 3 fixes after testing (migration 020). `get_today_field_days` without a date also lists earlier field days that were never ended, so the "Field days not ended" tile and the list agree (section 4.9). Real log out added; a technician whose account or phone the admin turned off is logged out automatically (section 1.5, "Sessions and logging out"). Expired access tokens are renewed and retried once, otherwise the app returns to the login page. Refresh buttons turn while a page loads. Layout fixes for small screens: the scanner banners and lower rows scroll inside a share of the height, the field-day tile no longer uses a ListTile trailing button, the statistics cards size to their text, the language toggle is compact on phones. |
| 2026-10-29 | 0.1 | project note | Migration 015: reminder job, `get_my_notifications` (section 4.15), reminder settings seeded (section 14). `device_approval_needed` currently carries `{ technician_id, device_id }` only; the app shows a generic message for it. |

---

## Sign-off

- [ ] Person A: ____________________  Date: ________
- [ ] Person B: ____________________  Date: ________
