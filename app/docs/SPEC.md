# **QR Attendance System**

**For:** a local tobacco company, Echague, Isabela, Philippines **Stack:** Flutter (Android app and web) with Supabase **Goal:** record when each worker starts and stops work, every day and every week, replacing pen and paper at zero or near-zero running cost. Payroll is not part of this system.

## **1\. Overview**

The company has field workers who are supervised by technicians. The system works like this:

1. Every worker gets a printed QR card.  
2. The technician scans the card with their phone camera when a worker starts. This works offline.  
3. When the technician leaves the field, they tap **End field day**. Everyone still clocked in under that technician is clocked out at that moment.  
4. The admin checks that every technician ended their field day, and watches simple daily and weekly statistics.  
5. Every week the admin exports the masterlist as an Excel file and gives it to the accountant. The accountant handles pay outside this system.

Workers never use the app. If a worker wants to know their status, they ask a technician.

**What the system does not do:** payroll, late or absent tracking, or break and lunch tracking. It only records when each worker clocked in and out.

## **2\. Roles and permissions**

| Role | ID prefix | What they can do |
| :---- | :---- | :---- |
| **Super Admin** | (own account) | Permission control, audit logs, scan hours and retention settings, manage admins |
| **Admin** | A- | Add, view, and delete workers, fields, and technicians. Assign technicians to fields. Create technician accounts. Monitor field days and statistics. End a technician's field day manually. Add or fix missing time records by hand. Export the weekly masterlist. |
| **Technician** (also called staff) | T- | Scan workers in and out, tap End field day, monitor their own field, and look up a worker's time record for the current week (Monday to Sunday) when a worker asks. Nothing else. |
| **Worker** | W- | A record only. No login and no app. Identified by the printed QR card. |

**Important:** workers are database records, not login accounts. This keeps the system simple and well inside free-tier user limits.

## **3\. Registration of workers and technicians**

Admins can add people in two ways:

* **Manual entry** through a simple form.  
* **CSV upload** with these columns: name, cp\_no, address, gender, date\_of\_birth.

After saving, the system automatically:

* Generates a unique ID, for example W-00123, T-00007, A-00002.  
* Generates a QR code for that ID.  
* Makes printable cards (name, ID, and QR).

### **CSV upload rules**

* Show a preview before saving.  
* Reject bad rows with a clear message, for example: Row 12: date of birth is not valid. One bad row does not stop the whole upload.  
* Warn about possible duplicates (same name and date of birth).

### **Accounts for technicians**

Admins create the login for each technician. Many technicians may not have an email address, so:

* The admin enters a **username** and a starting password.  
* The app maps the username to a hidden email behind the scenes.  
* Account creation runs in a Supabase Edge Function, so the secret service key is never inside the app.

## **4\. QR codes**

* The QR contains only the ID plus a short checksum, for example W-00123.k7x.  
* Printed cards can be copied, so after each scan the technician sees the worker's **name** and confirms it is the right person.  
* A lost or damaged card is reprinted by the admin. A new checksum can be issued, and the old one stops working. Cards should be laminated or waterproof, with the worker's name and ID printed on them.

## **5\. Days, weeks, and field days**

* **A day is the calendar date**, in Philippine time (UTC+8). A new date is a new day. There are no shifts or cutoff hours.  
* **A week runs Monday to Sunday.**  
* Workers can work any day of the week if they choose, under an **active** technician and an **active** field.  
* Each technician has one **field day** per date. It ends when the technician taps **End field day**, or when the admin ends it.  
* The system stores times in a standard way but always works out the date using Philippine time, so a 7:00 AM scan never lands on the wrong date.

## **6\. Scanning**

### **Scan flow**

1. The technician opens the app, which goes straight to the scanner.  
2. The technician points the camera at the worker's card.  
3. The app shows the worker's name with a big green confirmation, for example **Juan Dela Cruz: CLOCKED IN 6:02 AM**.  
4. If the worker leaves early, the technician scans the card again to clock them out.

### **Rules**

* A repeat scan of the same card within about 30 seconds is ignored (accidental double scan).  
* A scan on a new date is always a new time in. It never becomes the previous day's time out.  
* A scan for an inactive worker, field, or technician is blocked with a clear message. A scan outside the allowed scan hours (set by the Super Admin, for example 4:00 AM to 9:00 PM) is saved but flagged for the admin.  
* Technicians cannot edit times. Corrections are made by an admin and recorded in the audit log.  
* Every scan saves the technician and the field, so old weeks always show the correct names, even if a technician changes fields later.

### **Working in different fields on the same date**

A worker may work in more than one field on the same date.

* Each in-and-out pair is saved as a **session** with its field and technician.  
* The worker's hours for the date are the total of all sessions.  
* The worker counts as present once for that date.  
* Ideally the worker is clocked out at the same field where they clocked in. As a **safety net**, if a second technician scans a worker who is still clocked in under the first technician, the system automatically closes the first session at that moment, so the hours are never counted twice.

## **7\. End field day**

There is no work in a field when the technician is not there, so the technician leaving ends everyone's time.

* The technician's home screen has one big button: **End field day**. It shows how many workers are still clocked in, for example: 5 workers still clocked in.  
* The technician taps it when leaving the field. A short confirmation appears: Clock out 5 workers at 4:52 PM?  
* After confirming, everyone still clocked in is clocked out at the current time.  
* It works only for the same date.  
* Hours therefore run until the technician ends the day, unless a worker was scanned out earlier. This is accepted for simplicity.  
* **Breaks and lunch** are not tracked or managed by the system. A worker who wants a break can ask to be clocked out. Only recorded clock-in and clock-out times matter.  
* **Before leaving the field**, if scans are not uploaded yet, the app warns: 3 scans not uploaded. Connect to the internet. This protects the day's data if a phone is lost.

## **8\. Admin monitoring: Today's field days**

The admin's main check is one screen:

| Technician | Field | Status | Workers | Last sync |
| :---- | :---- | :---- | :---- | :---- |
| John Doe (T-001) | Field 1 | **Working** | 5 clocked in | 2 min ago |
| Alex Eve (T-002) | Field 2 | **Ended 4:52 PM** | 6 worked | 4:53 PM |
| Mark Cruz (T-003) | Field 3 | **Not ended** | 4 still clocked in | Yesterday |

* **Working:** the technician is in the field.  
* **Ended:** the technician tapped End field day.  
* **Not ended:** it is past the reminder time and nobody ended it. This is the only status the admin needs to act on.  
* **Last sync** shows when each technician's phone last uploaded. A technician with no signal may look Not ended only because their scans have not arrived yet.

### **Reminder time**

* The admin sets a **reminder time** in settings. The starting value is **5:00 PM**.  
* At that time the system checks which technicians have not ended their field day and sends the admin a notification, for example: 2 technicians have not ended their field day: Mark Cruz (Field 3), Ana Reyes (Field 1).  
* Tapping the notification opens this screen.  
* If a technician is still not ended after about 30 minutes, the admin gets one more reminder, then no more.  
* The notification shows inside the app and website for free. A phone push notification (Firebase, also free) can be added after the first version works.  
* The technician's app can show a gentle reminder at the same time: Are you leaving the field? Tap End field day. The admin can turn this off.

### **Ending a field day manually**

1. The admin taps **End field day** on that technician's row.  
2. The app suggests a time, which is the technician's last scan of that day. The admin accepts it or types another time.  
3. Everyone still clocked in under that technician is clocked out at that time.  
4. For a past date, the admin must type the time.  
5. The action is saved in the audit log.

### **Adding or fixing time records by hand**

If a technician's phone dies or the app cannot be used, the technician may go back to pen and paper for that day. The admin then enters the records into the system:

* The admin picks the worker, field, technician, date, time in, and time out.  
* A reason is required, for example: phone broke, paper record used.  
* The record is marked **Entered by admin**.  
* Every manual entry or fix is saved in the audit log.  
* Manually entered days are included in the weekly masterlist like any other day.

### **Printable daily paper sheet**

To make the pen and paper fallback easy, the admin can print a sheet for one technician and one date from the website (a print page or PDF). Technicians keep a few copies in case their phone fails.

* The header shows the technician's ID and name, the field, and the date.  
* The usual workers of that technician are already listed with their ID and name. Blank rows are left for extra workers, who are written in by ID.  
* Each row has two boxes: time in and time out.  
* The text is large and follows the language toggle (English or Filipino).  
* At the end of the day, the technician gives the sheet to the admin, who enters it through the manual time records above.  
* How long the company keeps the paper sheets is the company's decision.

## **9\. Offline mode and sync**

Signal in the fields can be weak, so scanning must always work.

* The app keeps a local database on the phone (SQLite through the Drift package).  
* Each scan is saved on the phone first, with a unique scan ID, the worker, the technician and field, and the phone's time.  
* When internet comes back, the app uploads waiting scans in small batches automatically. Each scan has its own ID, so uploading twice never creates duplicates.  
* The server also records when it received each scan. If the phone's clock and server time differ by a lot, the scan is flagged for the admin.  
* The app shows a small status: **Online**, **Offline: 12 scans waiting**, or **Syncing...**.  
* The phone keeps a small copy of the worker list for the technician's field (ID, name, active status), so names can be confirmed with no signal. Addresses and phone numbers are not kept on the phone.

## **10\. Fields and assignments**

* Admins can **view, add, and delete** fields.  
* Admins assign one or more technicians to each field.  
* Deleting a field that has history archives it instead of erasing it, so old records still make sense.  
* A technician sees and scans only for their assigned field.

## **11\. Statistics (Admin)**

The dashboard is simple, with big numbers and a few charts.

**Today:** workers clocked in now, workers who finished, technicians and fields working, field days not ended.

**This week and past weeks:** workers per day, total hours per day, attendance per field, and a comparison with last week.

A filter lets the admin choose **Daily** or **Weekly**.

## **12\. Weekly masterlist (Excel export)**

Every week the admin exports the masterlist and gives it to the accountant. It is an Excel file (.xlsx), laid out like the company's reference sheet.

* One section per technician, with the technician's ID, name, field (location), and address.  
* One row per worker in that section.  
* Columns: ID, Name of the Worker, Monday to Sunday hours, Total Weekly Hours, Total Weekly Present, Signature.  
* Hours are shown in full detail, for example **5 hours 33 minutes**.  
* **Total Weekly Present** is the number of dates the worker had a time in.  
* **Signature** is always left blank, for the accountant's use outside the system. There is no Pay column.  
* A worker who worked in two fields appears in each technician's section, with the hours for that field.  
* After exporting, getting the file to the accountant is the admin's responsibility.

* If the technician scans a Worker on at least one or more than a  day of the week, the worker hours will appear in the weekly masterlist. 

* If the technician did not scan the laborer on one or more days but records attendance on at least one or more day, the laborer will still appear in the report. Example (Zeann tuesday (5hrs but on wednesday the laborer didn’t work in technician 1 and the worker work for technician 2 then it will show the hours in the technician 2 )

*  However, if the technician does not scan any laborers throughout the entire week, no results will be displayed. Example (Zeann did not work for technician 1 for the whole week it will not put any information of Zeann on technician 1\)

Example section:  
**Date:** 19-25 Oct 2026

**ID:** T-001   **Name of Technician:** John Doe   **Field (location):** Field 1  

| ID | Name of the Worker | Monday | Tuesday | Wednesday | Thursday | Friday | Saturday | Sunday | Total Weekly Hours | Total Weekly Present | Signature |
| :---- | :---- | :---- | :---- | :---- | :---- | :---- | :---- | :---- | :---- | :---- | :---- |
| W-00001 | Zeann | 5 hours 33 minutes | 5 hours |  | 6 hours 10 minutes | 5 hours |  | 5 hours 20 minutes | 27 hours 3 minutes | 5 |  |
| W-00002 | Czar | 10 hours |  |  | 8 hours 15 minutes | 2 hours | 9 hours |  | 29 hours 15 minutes | 4 |  |

**ID:** T-002   **Name of Technician:** Juan Reyes   **Field (location):** Field 2 

| ID | Name of the Worker | Monday | Tuesday | Wednesday | Thursday | Friday | Saturday | Sunday | Total Weekly Hours | Total Weekly Present | Signature |
| :---- | :---- | :---- | :---- | :---- | :---- | :---- | :---- | :---- | :---- | :---- | :---- |
| W-00001 | Zeann |  | 3 hours | 5 hours |  |  | 9 hours |  | 17 hours | 3 |  |
| W-00002 | Czar |  | 10 hours | 5 hours |  | 5 hours |  | 5 hours 20 minutes | 25 hours 20 minutes | 4 |  |

### **Before exporting**

* If any field day for that week is still **Not ended**, the system warns the admin. The admin can fix it first or export anyway after confirming.

### **Corrections after export**

* Every export is saved with its date.  
* If a time is corrected after a week was exported, that week is marked **Changed after export**, so the admin knows to send a corrected copy to the accountant.

## **13\. Audit logs (Super Admin)**

The audit log records every important action:

* Logins and failed logins  
* Creating, editing, or deleting workers, technicians, and fields  
* Role and permission changes  
* Time corrections and manually ended field days  
* CSV uploads and weekly exports  
* Changes to settings

Each entry stores who did it, what changed (before and after), and when.

### **Retention**

* Logs are deleted automatically after **15 days** by default. The Super Admin can set a different number of days in settings.  
* Before deletion, the Super Admin gets an in-app notification with an **Export CSV** button.  
* Logs are written by database triggers, so they cannot be skipped by a bug in the app.

## **14\. Easy to use (HCI)**

Many users are not used to technology, and the old system is pen and paper. So:

* **Simple English** and a **toggle to switch everything to Filipino**.  
* Large buttons, large text, high contrast, outdoor-friendly colors.  
* One main action per screen. Technicians see mostly the scanner and the End field day button.  
* Icons always have words beside them.  
* Clear colors: Forest green \= success, yellow \= needs attention, red \= error.  
* Confirmation before deleting anything, in plain words.  
* Error messages say what to do next, not codes.  
* Optional sound and vibration on a successful scan.  
* Language files built with Flutter's intl package (English and Filipino).

## **15\. Architecture**

Technician phone (Flutter, Any Platform)       Admin PC (Flutter Web, Any Platform)  
   \|  local SQLite (offline scans)            \|  
   \|  sync when online                         \|  
   \+-------------------+----------------------+  
                       \|  
                  Supabase  
      Auth \| Postgres \+ RLS \| Edge Functions \| pg\_cron

| Part | Tool | Cost |
| :---- | :---- | :---- |
| Mobile app and web app | Flutter (one codebase) | Free |
| Database, login, API | Supabase free tier | Free |
| Web hosting | Cloudflare Pages  | Free |
| QR scanning | mobile\_scanner package | Free |
| QR creation | qr\_flutter package | Free |
| Local offline storage | Drift (SQLite) | Free |
| Excel export | an Excel package for Dart | Free |
| Scheduled jobs and reminders | pg\_cron in Supabase | Free |
| Keep-alive ping | GitHub Actions or cron-job.org | Free |

## **16\. Database design**

| Table | Purpose |
| :---- | :---- |
| profiles | Technicians and admins (linked to Supabase Auth), role, active flag |
| workers | Worker records: ID, name, cp\_no, address, gender, date of birth, active flag |
| fields | Field name, location, address, active flag, archived flag |
| field\_assignments | Which technician works in which field |
| scans | One row per scan: scan UUID, worker, technician, field, phone time, server time, location (if allowed), outside-hours flag |
| attendance\_sessions | One row per in-and-out pair: worker, field, technician, time in, time out, how it was closed (scan, End field day, admin, safety net) |
| field\_days | One row per technician per date: status (working or ended), ended time, who ended it |
| weekly\_exports | Each export with its date and a Changed after export flag |
| settings | Reminder time, allowed scan hours, attendance and log retention days, and other admin settings |
| audit\_logs | Who, what, before, after, when |
| notifications | In-app notices (reminders, log export notices) |
| devices | Which phone is registered to which technician, approval status |

### **Unique IDs**

A counter per role creates IDs such as W-00123, T-00007, A-00002. IDs are created by a database function so two admins can never create the same ID.

### **Keeping the free database small**

* Times are stored to the minute, and the masterlist writes them as hours and minutes.  
* Compact columns and an index on worker and date.  
* One scan row is roughly 100 bytes, so the free 500 MB lasts a long time.  
* Dashboard statistics come from the sessions table, not from raw scans, so queries stay fast.  
* Attendance records are deleted automatically after 15 days by default. The Super Admin can change this number of days in settings. A week that was never exported is not deleted until it is exported, and the admin gets a notice before any attendance is deleted. The weekly Excel exports are the long-term record, so the admin must keep them safe.

**Size check:** about 2,000 workers, 26 technicians, and 26 fields (one technician per field, so roughly 75 workers per field) should produce a few thousand scans a day. With 15 days of records kept, that is roughly tens of thousands of rows, which fits easily in the free 500 MB. These are estimates and should be checked after the first month.

## **17\. Security**

* **Row Level Security (RLS)** on every table. Rules are enforced by the database, not just by hiding screens.  
* Technicians can only add scans for their assigned field. They can read a worker's name and time record for the current week only, but not addresses, phone numbers, or birth dates.  
* Only the Super Admin can read audit\_logs.  
* The Supabase service key is used only inside Edge Functions, never in the app.  
* Two-step login (MFA) for admins and the Super Admin. Supabase offers it for free.  
* The phone stores only name and ID of workers, requires a PIN or fingerprint, and the admin can disable a technician's account right away if a phone is lost.  
* Worker phone numbers, addresses, and birth dates are personal data. The Philippine Data Privacy Act (RA 10173\) applies, so limit who can export and avoid sharing the Excel file in public chats. Workers should be given a short notice that their details are stored.

### **Account security and misuse prevention**

No system can be completely hacker-proof. The goal is to make theft harder, limit what a stolen account can do, and make misuse easy to see.

#### **What a stolen account can do**

| Account | What a thief could do | How it is limited |
| :---- | :---- | :---- |
| **Technician** | Scan workers for that technician's field and see a worker's name and current-week hours | Cannot see addresses, phone numbers, or birth dates. Cannot edit or delete times. Cannot export. The admin can disable the account immediately. |
| **Admin** | Read worker data, edit times, delete records, export the masterlist | Two-step login (MFA), new-device alerts, and Super Admin notice for risky actions |
| **Super Admin** | Everything, including audit logs | Two-step login (MFA), a second admin, and a written recovery plan |

#### **Passwords and logins**

* Strong passwords: a minimum length and no common passwords.  
* Technicians choose their own password at first login. The starting password from the admin works only once.  
* One person, one account. Accounts are never shared.  
* Repeated wrong passwords are blocked. Failed logins are saved in the audit log, and the admin is notified after many failures.  
* Admins and the Super Admin are notified when their account logs in from a new device.  
* Website sessions expire after a period of no use.  
* Deleting many records or exporting all worker data notifies the Super Admin. Records are deactivated first so they can be recovered.

#### **One phone per technician**

* Each technician has one phone, registered to their account the first time they log in.  
* Logging in from a different phone needs the admin's approval.  
* When a technician changes phones, the admin approves the new phone and the account is updated to it. The old phone is logged out.  
* The admin can cut off a lost phone from the admin screen.

#### **Scan hours and saved location**

A person with a technician's username and password could try to log in somewhere else and scan their own card. To make this harder to do and easy to notice:

* Scans are accepted only during the **allowed scan hours**, for example 4:00 AM to 9:00 PM. The Super Admin can change these hours in settings. A scan outside them is saved but flagged for the admin.  
* Every scan quietly saves the phone's **location**, if the technician allows it. Nothing is checked or blocked automatically. If the admin suspects a problem, they can open that scan and see where it happened.  
* If a technician refuses location access, scans are still saved without a location, and the admin sees a note. Scanning never stops.

#### **Flagged list for the admin**

The admin's flagged list also shows:

* Scans outside the allowed scan hours.  
* Scans from a technician's phone on a date when that technician had no field day.  
* Many scans from one phone at the same moment.

#### **What this cannot stop**

* A worker who goes to the field and hands a phone to a friend.  
* Phishing: an admin giving their password and MFA code to a stranger. A short training for admins is the best defense.  
* A technician scanning workers who are not there. The flagged list and audit log help catch it, but it is a trust issue, not only a security issue.  
* Mistakes in the database rules. Before launch, test every role to confirm it cannot see or change anything it should not.

## **18\. Free-tier risks and how to handle them**

| Risk | What to do |
| :---- | :---- |
| Supabase pauses free projects after about 1 week with no activity | Technicians scan often, but add a free keep-alive ping as insurance |
| No automatic backups on the free plan | Admin downloads the weekly Excel export; add a scheduled backup to free storage |
| 500 MB database limit | Compact tables and scheduled cleanup of logs |
| Request limits | Batch the sync uploads; do not poll constantly |
| Publishing on Google Play costs a one-time fee | For now, share the Android APK directly at no cost, and plan how technicians get updates. iPhone support is not confirmed and would cost more |

## **19\. Build plan**

1. **Database:** tables, ID generators, RLS, triggers, Philippine-time date handling, pg\_cron jobs.  
2. **Login and roles:** accounts for the Super Admin, admin, and technician.  
3. **Worker and field management:** forms, CSV upload, QR generation, printable cards.  
4. **Technician app:** scanner, offline queue, sync, End field day, registered phone, saved location.  
5. **Admin screens:** Today's field days, reminders, manual End field day, manual time records, printable paper sheet, flagged list, statistics.  
6. **Weekly masterlist:** Excel export, Changed after export marking.  
7. **Audit logs and notifications:** log views, retention setting, export notice.  
8. **Language and polish:** English and Filipino, large UI, test with real technicians.  
9. **Pilot:** run one field for 2 weeks next to the paper system, then expand.

## **20\. Open items**

* **Super Admin:** held by a trusted IT staff member or developer. Name a second trusted person as backup, with a written recovery plan.  
* **Backups:** the free plan has no automatic backups. Name who downloads the weekly Excel export and a database backup.  
* **Retention:** attendance records are deleted after 15 days by default, so the weekly Excel exports are the only long-term record. Confirm with the accountant that this is enough.  
* **Any Platform:** Make everything viable in any platform except iphone