# QR Attendance

This is the Flutter app for the Echague, Isabela QR attendance system. It
targets Android and web from one platform-neutral codebase. Phase 2 adds protected database access, email/password authentication,
technician account provisioning, and device registration/approval. Phase 4 adds the admin monitoring dashboard and management surfaces backed by
Supabase RPCs: workers, fields, technician accounts and assignments, device
approvals, CSV worker import preview/commit, printable QR cards, weekly
masterlist viewing, manual time records, settings, statistics, flagged scans,
and audited manual field-day ending. Complete Phase 3 development-project
verification remains part of the rollout gate.

## Requirements

- Flutter 3.47.8 (Dart 3.13.7)
- Android Studio or an Android SDK for Android builds
- Chrome for web development

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

## Tests and checks

```powershell
flutter analyze
flutter test
dart format lib test
```

The Philippine-time tests cover the 15:59/16:00 UTC date boundary, Monday week
starts, exact hours, 61 minutes, and zero minutes.

## Admin navigation

The login screen routes authenticated users by role:

- Technician: scanner and field-day workflow
- Admin: dashboard, workers, fields, technicians, device approvals, and admin tools
- Super admin: admin-account provisioning and settings

Worker Management also supports editing, CSV preview/commit, QR reissue, and
printable QR cards. Admin Tools provides weekly masterlist data, audited manual
time records, and scan/reminder settings.

The English/Filipino toggle is stored on the device using
`SharedPreferences`.
