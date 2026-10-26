# QR Attendance

This is the Flutter scaffold for the Echague, Isabela QR attendance system. It
targets Android and web from one platform-neutral codebase. Real attendance
features and Supabase migrations are intentionally not included in this task.

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

The scaffold can also start without these values so that the placeholder
screens can be developed before Supabase is configured.

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

## Scaffold navigation

The login screen has placeholder role selection so the three destinations can
be previewed:

- Technician: scanner placeholder and large **End field day** button
- Admin: dashboard placeholder
- Super admin: settings placeholder

The English/Filipino toggle is stored on the device using
`SharedPreferences`.
