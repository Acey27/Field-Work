# QR Attendance

This is the Flutter app for the Echague, Isabela QR attendance system. It
targets Android and web from one platform-neutral codebase, backed by Supabase
(see `../supabase/`).

## Status

| Phase | State |
| --- | --- |
| 1 Foundation, 2 Security and accounts | Built |
| 3 Attendance core (scanner, offline queue, sync, End field day) | Built. Offline scan, sync once, and End field day were tried on a phone; the rest of the build guide section 10 attendance checklist is still to be run (30-second repeat, two technicians, 7:00 AM / 11:59 PM dates, outside scan hours) |
| 4 Admin | Built, waiting for the "simulated day" test (see below) |
| 5 Masterlist | Not started: a draft `admin_weekly_masterlist` exists, but `weekly_masterlist`, the Excel export, "Changed after export" and the worker lookup are Phase 5 |
| 6 Audit and retention, 7 Polish and pilot | Not started |

Phase 4 contains: workers (add, edit with gender and date of birth, turn on/off,
reissue card, print one card or all cards), CSV upload (file picker, preview
with "Row 12: ..." messages and duplicate warnings, chunks of 500), fields
(add, edit, turn on/off), technicians (create, assign a field in one step, turn
the account on/off, approve or revoke phones), Today's field days (Working,
Ended, Not ended, last sync, manual End field day with a suggested time),
reminders and the notification inbox, time records (day list, add, fix,
"Entered by admin"), the printable daily paper sheet, statistics (Daily or
Weekly) and the flagged list.

## Requirements

- Flutter 3.47.8 (Dart 3.13.7)
- Android Studio or an Android SDK for Android builds
- Chrome for web development
- A real Android phone for scanner work (an emulator cannot test the camera well)

Both developers should read [`docs/SPEC.md`](docs/SPEC.md) and
[`docs/CONTRACT.md`](docs/CONTRACT.md) before changing the app.

## Install

```powershell
flutter pub get
```

## Supabase dart-defines

The app never hard-codes Supabase credentials. Pass the project URL and
anonymous key when running:

```powershell
flutter run -d chrome `
  --dart-define=SUPABASE_URL=https://your-project.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

Use the same two `--dart-define` values with an Android device:

```powershell
flutter run -d <android-device-id> `
  --dart-define=SUPABASE_URL=https://your-project.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

The app can start without these values for UI work, but authentication requires
the Supabase values to be configured.

## Run on Android and web

```powershell
flutter devices
flutter run -d chrome
flutter run -d <android-device-id>
```

Do not use iPhone-specific code. The app is designed to remain platform-neutral
for Android and web.

## Database (Supabase)

Migrations are numbered files in `../supabase/migrations/` and are never edited
after they have been applied. Apply them to the **dev** project first (never
test on prod):

```powershell
supabase link --project-ref <dev-project-ref>
supabase db push
```

Or paste each new file into the Supabase SQL editor, in order. Enable the
`pg_cron` extension (Database, Extensions) before migration 015, which schedules
the "not ended" reminder job.

SQL checks live in `../supabase/tests/`. Open the file, paste the whole script
into the SQL editor of the dev project and run it. The ones that change data
(`admin.sql`, `reminders.sql`) run inside a transaction and end with
`rollback`, so nothing is kept. A failed check stops with an error that starts
with `FAIL`.

| File | Checks |
| --- | --- |
| `admin.sql` | roles, Today's field days, manual End field day, time records and overlaps, fields and assignment, technician on/off, 2,000-row CSV import, statistics, flagged list, paper sheet, settings |
| `reminders.sql` | the reminder job: first reminder, no duplicates, one repeat, nothing for ended days |
| `settings.sql` | time settings and their validation |
| `attendance.sql`, `security.sql`, `foundation.sql` | Phases 1 to 3 |

## Tests and checks

```powershell
flutter analyze
flutter test
dart format lib test
```

The Philippine-time tests cover the 15:59/16:00 UTC date boundary, Monday week
starts, 12-hour display of settings, exact hours, 61 minutes, and zero minutes.
The CSV tests cover a 2,000-row file in chunks of 500.

## Admin navigation

The login screen routes authenticated users by role:

- Technician: scanner and field-day workflow
- Admin: dashboard (statistics, Today's field days, flagged list, bell for
  notifications), workers, fields, technicians, and admin tools (settings,
  time records, paper sheet)
- Super admin: admin-account provisioning and settings

The English/Filipino toggle is stored on the device using
`SharedPreferences`.

## Phase 4 simulated day (manual test)

Build guide section 7: the admin can run a full simulated day without help. Use
the dev project, one admin, two technicians on two phones, and a few workers.

1. Upload a CSV of workers (include one bad date and one repeated name) and
   check the "Row N" messages and the duplicate warning. Print the cards.
2. Create two technicians, assign each a field, approve their phones.
3. Print the paper sheet for a technician.
4. Technician A scans three workers and ends the field day; technician B scans
   two and does not.
5. After the reminder time, B shows "Not ended" in red and the bell shows the
   reminder. End B's day from the admin screen (suggested time, reason).
6. Add a time record by hand (paper sheet), try an overlapping one, and fix one.
7. Check the statistics (Daily and Weekly) and the flagged list.
