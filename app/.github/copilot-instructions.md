# QR Attendance development rules

- Read `docs/SPEC.md` and `docs/CONTRACT.md` before working.
- All dates and weeks use Philippine time (UTC+8); weeks run Monday to Sunday.
- Store timestamps as UTC and convert them with `core/utils/ph_time.dart`.
- Use Riverpod for state.
- Put every user-visible string through l10n in English and Filipino.
- Never put secrets in code.
- Prefer small files and small functions.
- Write tests with new logic.
- Never edit an existing Supabase migration file after it is merged.
- Technicians must never receive addresses, phone numbers, or birth dates.
