import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AppLocalizations {
  const AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = [Locale('en'), Locale('fil')];
  static const delegate = _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        const AppLocalizations(Locale('en'));
  }

  String get appTitle => _text('appTitle');
  String get login => _text('login');
  String get logOut => _text('logOut');
  String logOutWithPending(int count) =>
      _text('logOutWithPending').replaceFirst('{count}', '$count');
  String get oldFieldDaysHint => _text('oldFieldDaysHint');
  String get username => _text('username');
  String get email => _text('email');
  String get password => _text('password');
  String get signIn => _text('signIn');
  String get chooseRole => _text('chooseRole');
  String get technician => _text('technician');
  String get admin => _text('admin');
  String get superAdmin => _text('superAdmin');
  String get scan => _text('scan');
  String get endFieldDay => _text('endFieldDay');
  String workersStillClockedIn(int count) =>
      _text('workersStillClockedIn').replaceFirst('{count}', '$count');
  String get offline => _text('offline');
  String get syncing => _text('syncing');
  String get online => _text('online');
  String offlineWithPending(int count) =>
      _text('offlineWithPending').replaceFirst('{count}', '$count');
  String get confirm => _text('confirm');
  String get invalidQr => _text('invalidQr');
  String get workerNotCached => _text('workerNotCached');
  String get scanSaved => _text('scanSaved');
  String get errDateNotToday => _text('errDateNotToday');
  String get errFieldDayNotFound => _text('errFieldDayNotFound');
  String get errDevice => _text('errDevice');
  String endFieldDayConfirm(int count, String time) =>
      _text('endFieldDayConfirm')
          .replaceFirst('{count}', '$count')
          .replaceFirst('{time}', time);
  String scansNotUploaded(int count) =>
      _text('scansNotUploaded').replaceFirst('{count}', '$count');
  String get dashboard => _text('dashboard');
  String get settings => _text('settings');
  String get placeholder => _text('placeholder');
  String get language => _text('language');
  String get english => _text('english');
  String get filipino => _text('filipino');
  String get usernameHint => _text('usernameHint');
  String get emailHint => _text('emailHint');
  String authError(String code) => switch (code) {
    'E_SERVER_CONFIG' => _text('errServerConfig'),
    'E_ACCOUNT_DISABLED' => _text('errAccountDisabled'),
    'E_DEVICE_REVOKED' => _text('errDeviceRevoked'),
    'E_SESSION_ENDED' => _text('errSessionEnded'),
    'E_MUST_CHANGE_PASSWORD' => _text('errMustChangePassword'),
    'E_PASSWORD_WEAK' => _text('errPasswordWeak'),
    'E_PASSWORD_UPDATE_FAILED' => _text('errPasswordUpdateFailed'),
    'E_EMAIL_TAKEN' => _text('errEmailTaken'),
    'E_ACCOUNT_CREATE_FAILED' => _text('errAccountCreateFailed'),
    'E_INPUT_INVALID' => _text('errAdminInput'),
    'E_INVALID_LOGIN' => _text('errInvalidLogin'),
    'E_LOGIN_STATE_FAILED' => _text('errLoginStateFailed'),
    'E_LOGIN_FAILED' => _text('errLoginFailed'),
    'E_WORKER_NOT_FOUND' => _text('errWorkerNotFound'),
    _ => _text('errLoginFailed'),
  };
  String get passwordHint => _text('passwordHint');
  String get firstLoginTitle => _text('firstLoginTitle');
  String get firstLoginDescription => _text('firstLoginDescription');
  String get newPassword => _text('newPassword');
  String get confirmPassword => _text('confirmPassword');
  String get savePassword => _text('savePassword');
  String get errPasswordChangeInvalid => _text('errPasswordChangeInvalid');
  String get refresh => _text('refresh');
  String get adminLoadError => _text('adminLoadError');
  String get todayFieldDays => _text('todayFieldDays');
  String get noFieldDays => _text('noFieldDays');
  String get flaggedActivity => _text('flaggedActivity');
  String get noFlaggedActivity => _text('noFlaggedActivity');
  String get workersPresent => _text('workersPresent');
  String get totalMinutes => _text('totalMinutes');
  String get fieldDays => _text('fieldDays');
  String get notEnded => _text('notEnded');
  String get noField => _text('noField');
  String get openWorkers => _text('openWorkers');
  String get ended => _text('ended');
  String get working => _text('working');
  String get manualEndFieldDay => _text('manualEndFieldDay');
  String get reason => _text('reason');
  String get cancel => _text('cancel');
  String get fieldDayEnded => _text('fieldDayEnded');
  String clockedInCount(int count) =>
      _text('clockedInCount').replaceFirst('{count}', '$count');
  String workedCount(int count) =>
      _text('workedCount').replaceFirst('{count}', '$count');
  String get lastSync => _text('lastSync');
  String get neverSynced => _text('neverSynced');
  String endedAt(String time) => _text('endedAt').replaceFirst('{time}', time);
  String get endTime => _text('endTime');
  String get suggestedEndTime => _text('suggestedEndTime');
  String get endTimeRequired => _text('endTimeRequired');
  String adminError(String code) => switch (code) {
    'E_REASON_REQUIRED' => _text('errReasonRequired'),
    'E_TIME_IN_FUTURE' => _text('errTimeInFuture'),
    'E_DATE_MISMATCH' => _text('errDateMismatch'),
    'E_TIME_OUT_BEFORE_IN' => _text('errTimeOutBeforeIn'),
    'E_OVERLAP' => _text('errOverlap'),
    'E_FIELD_DAY_NOT_FOUND' => _text('errFieldDayNotFound'),
    'E_FORBIDDEN' => _text('errForbidden'),
    'E_SETTING_INVALID' => _text('errSettingInvalid'),
    'E_SESSION_NOT_FOUND' => _text('errSessionNotFound'),
    'E_FIELD_NOT_FOUND' => _text('errFieldNotFound'),
    'E_WEEK_NOT_MONDAY' => _text('errWeekNotMonday'),
    _ => _text('errAdminAction'),
  };
  String get errDevicePending => _text('errDevicePending');
  String get errDeviceNotApproved => _text('errDeviceNotApproved');
  String get errDeviceRevoked => _text('errDeviceRevoked');
  String get errNoActiveField => _text('errNoActiveField');
  String get errScanOffline => _text('errScanOffline');
  String get errAccountDisabled => _text('errAccountDisabled');
  String get errMustChangePassword => _text('errMustChangePassword');
  String get scanLoading => _text('scanLoading');
  String get cameraOpen => _text('cameraOpen');
  String get cameraClose => _text('cameraClose');
  String get cameraOff => _text('cameraOff');
  String get cameraError => _text('cameraError');
  String get scanLooking => _text('scanLooking');
  String get scanDetected => _text('scanDetected');
  String get scanBadCard => _text('scanBadCard');
  String get scanInactive => _text('scanInactive');

  /// A scan the server refused after the phone had already shown it
  /// (CONTRACT.md section 13): "Juan: not saved. Another technician has this
  /// worker clocked in...". [result] is the `blocked_*` value.
  String scanRefused(String name, String result) =>
      _text('scanRefused')
          .replaceFirst('{name}', name)
          .replaceFirst('{reason}', switch (result) {
            'blocked_held_elsewhere' => _text('refusedHeldElsewhere'),
            'blocked_bad_qr' => _text('scanBadCard'),
            'blocked_unknown_worker' => _text('refusedUnknownWorker'),
            'blocked_inactive_worker' => _text('scanInactive'),
            'blocked_inactive_field' => _text('refusedInactiveField'),
            'blocked_inactive_technician' => _text('refusedInactiveTechnician'),
            'blocked_not_assigned' => _text('refusedNotAssigned'),
            _ => _text('refusedOther'),
          });
  String get scanRepeat => _text('scanRepeat');
  String get scanNotReady => _text('scanNotReady');
  String clockedInAt(String name, String time) =>
      _text('clockedInAt')
          .replaceFirst('{name}', name)
          .replaceFirst('{time}', time);
  String clockedOutAt(String name, String time) =>
      _text('clockedOutAt')
          .replaceFirst('{name}', name)
          .replaceFirst('{time}', time);
  String get notifications => _text('notifications');
  String get noNotifications => _text('noNotifications');
  String notifFieldDayNotEnded(int count, String names) =>
      _text('notifFieldDayNotEnded')
          .replaceFirst('{count}', '$count')
          .replaceFirst('{names}', names);
  String notifFieldDayNotEndedOne(String names) =>
      _text('notifFieldDayNotEndedOne').replaceFirst('{names}', names);
  String get notifDeviceApproval => _text('notifDeviceApproval');

  /// "Worker clocked out: Juan (scanned by another technician)". [reason] is
  /// the data kept in the notification, never translated text.
  String notifWorkerClockedOut(String name, String? reason) =>
      _text('notifWorkerClockedOut')
          .replaceFirst('{name}', name)
          .replaceFirst(
            '{reason}',
            _text(
              reason == 'safety_net' ? 'reasonSafetyNet' : 'reasonClosedOther',
            ),
          );
  String get notifGeneric => _text('notifGeneric');
  String get reminderRepeatMinutes => _text('reminderRepeatMinutes');

  /// Under the reminder settings: the reminder only tells the admin. [button]
  /// is the name of the End field day button.
  String reminderHint(String button) =>
      _text('reminderHint').replaceFirst('{button}', button);
  String minutesValue(int count) =>
      _text('minutesValue').replaceFirst('{count}', '$count');
  // Time records
  String get timeRecords => _text('timeRecords');
  String get fixTimeRecord => _text('fixTimeRecord');
  String get enteredByAdmin => _text('enteredByAdmin');
  String get noTimeRecords => _text('noTimeRecords');
  String get workerLabel => _text('workerLabel');
  String get fieldLabel => _text('fieldLabel');
  String get chooseWorker => _text('chooseWorker');
  String get previousDay => _text('previousDay');
  String get nextDay => _text('nextDay');
  String get chooseDate => _text('chooseDate');
  String get notClockedOut => _text('notClockedOut');
  String get timeRecordIncomplete => _text('timeRecordIncomplete');
  String get openTimeRecords => _text('openTimeRecords');
  // Paper sheet
  String get paperSheet => _text('paperSheet');
  String get paperSheetHint => _text('paperSheetHint');
  String get printSheet => _text('printSheet');
  String get sheetTitle => _text('sheetTitle');
  String get sheetTechnician => _text('sheetTechnician');
  String get sheetField => _text('sheetField');
  String get sheetDate => _text('sheetDate');
  String get sheetNo => _text('sheetNo');
  String get sheetId => _text('sheetId');
  String get sheetName => _text('sheetName');
  String get sheetTimeIn => _text('sheetTimeIn');
  String get sheetTimeOut => _text('sheetTimeOut');
  String get sheetExtra => _text('sheetExtra');
  // Cards
  String get printAllCards => _text('printAllCards');
  String get noCardsToPrint => _text('noCardsToPrint');
  // CSV import
  String get chooseCsvFile => _text('chooseCsvFile');
  String get csvHelp => _text('csvHelp');
  String get csvChecking => _text('csvChecking');
  String get csvImporting => _text('csvImporting');
  String get csvNoNameColumn => _text('csvNoNameColumn');
  String get csvEmpty => _text('csvEmpty');
  String get csvReadError => _text('csvReadError');
  String get csvRowsInFile => _text('csvRowsInFile');
  String get includeDuplicates => _text('includeDuplicates');
  String get close => _text('close');
  String importRowLine(int row, String message) =>
      _text('importRowLine')
          .replaceFirst('{row}', '$row')
          .replaceFirst('{message}', message);
  String importDuplicateLine(int row, String workerId) =>
      _text('importDuplicateLine')
          .replaceFirst('{row}', '$row')
          .replaceFirst('{id}', workerId);
  String importDone(int count) =>
      _text('importDone').replaceFirst('{count}', '$count');
  String importMore(int count) =>
      _text('importMore').replaceFirst('{count}', '$count');
  String importRepeatLine(int row, int firstRow) =>
      _text('importRepeatLine')
          .replaceFirst('{row}', '$row')
          .replaceFirst('{first}', '$firstRow');

  /// "Column 'cp number' was not used": a header the system does not know.
  String csvColumnNotUsed(String name) =>
      _text('csvColumnNotUsed').replaceFirst('{name}', name);

  /// "Row 12: The name is missing." message for a CSV row code.
  String csvError(String code) => switch (code) {
    'E_CSV_NAME_MISSING' => _text('csvNameMissing'),
    'E_CSV_ROW_TOO_LONG' => _text('csvRowTooLong'),
    _ => _text('errAdminAction'),
  };
  // Fields and technicians
  String get editField => _text('editField');
  String get turnOffAccount => _text('turnOffAccount');
  String get turnOnAccount => _text('turnOnAccount');
  String get accountOff => _text('accountOff');
  String confirmTurnOff(String name) =>
      _text('confirmTurnOff').replaceFirst('{name}', name);
  String confirmTurnOn(String name) =>
      _text('confirmTurnOn').replaceFirst('{name}', name);
  // Statistics and flagged list
  String get statsToday => _text('statsToday');
  String get statsWeek => _text('statsWeek');
  String get daily => _text('daily');
  String get weekly => _text('weekly');
  String get clockedInNow => _text('clockedInNow');
  String get finishedWorkers => _text('finishedWorkers');
  String get techniciansWorking => _text('techniciansWorking');
  String get fieldsWorking => _text('fieldsWorking');
  String get fieldDaysNotEnded => _text('fieldDaysNotEnded');
  String get workersPerDay => _text('workersPerDay');
  String get hoursPerDay => _text('hoursPerDay');
  String get attendanceByField => _text('attendanceByField');
  String get thisWeek => _text('thisWeek');
  String get lastWeek => _text('lastWeek');
  String get previousWeek => _text('previousWeek');
  String get nextWeek => _text('nextWeek');
  String get workersWeekTotal => _text('workersWeekTotal');
  String get totalHours => _text('totalHours');
  String get flaggedFrom => _text('flaggedFrom');
  String get flaggedTo => _text('flaggedTo');
  String presentDaysValue(int count) =>
      _text('presentDaysValue').replaceFirst('{count}', '$count');

  /// Hours and minutes in the current language, for example "5 h 33 min".
  String durationShort(int minutes) =>
      _text('durationShort')
          .replaceFirst('{h}', '${minutes ~/ 60}')
          .replaceFirst('{m}', '${minutes % 60}');

  /// Readable name of a flag kind from `get_flagged_items`.
  String flagLabel(String kind) => switch (kind) {
    'outside_hours' => _text('flagOutsideHours'),
    'clock_skew' => _text('flagClockSkew'),
    'after_field_end' => _text('flagAfterFieldEnd'),
    'safety_net_close' => _text('flagSafetyNet'),
    'no_location' => _text('flagNoLocation'),
    'burst' => _text('flagBurst'),
    _ => kind,
  };
  String get timeNotSet => _text('timeNotSet');
  String get pickTime => _text('pickTime');
  String get retry => _text('retry');
  String get workers => _text('workers');
  String get fields => _text('fields');
  String get technicians => _text('technicians');
  String get manageTechnicians => _text('manageTechnicians');
  String get createTechnician => _text('createTechnician');
  String get assignField => _text('assignField');
  String get pendingDevices => _text('pendingDevices');
  String get technicianOperationFailed => _text('technicianOperationFailed');
  String get deviceApprovals => _text('deviceApprovals');
  String get device => _text('device');
  String get approveDevice => _text('approveDevice');
  String get revokeDevice => _text('revokeDevice');

  /// The status of a phone as the admin reads it (not the stored word).
  String deviceStatus(String status) => switch (status) {
    'approved' => _text('deviceApproved'),
    'revoked' => _text('deviceRevoked'),
    _ => _text('devicePending'),
  };
  String get adminTools => _text('adminTools');
  String get scanHoursStart => _text('scanHoursStart');
  String get scanHoursEnd => _text('scanHoursEnd');
  String get reminderTime => _text('reminderTime');
  String get timeFormat => _text('timeFormat');
  String get manualTimeRecord => _text('manualTimeRecord');
  String get manualTimeRecordHint => _text('manualTimeRecordHint');
  String get addTimeRecord => _text('addTimeRecord');
  String get weeklyMasterlist => _text('weeklyMasterlist');
  String get loadMasterlist => _text('loadMasterlist');
  String get selectWeek => _text('selectWeek');
  String get exportMasterlist => _text('exportMasterlist');
  String get printMasterlist => _text('printMasterlist');
  String get masterlistHeaders => _text('masterlistHeaders');
  String get noMasterlistRows => _text('noMasterlistRows');
  String unendedWeekWarning(int count) =>
      _text('unendedWeekWarning').replaceFirst('{count}', '$count');
  String get notEndedCell => _text('notEndedCell');
  String get exportSaved => _text('exportSaved');
  String get changedAfterExport => _text('changedAfterExport');
  String get workerLookup => _text('workerLookup');
  String get lookupWorkerId => _text('lookupWorkerId');
  String get loadWorkerWeek => _text('loadWorkerWeek');
  String get noWorkerWeek => _text('noWorkerWeek');
  String get workerId => _text('workerId');
  String get fieldId => _text('fieldId');
  String get technicianId => _text('technicianId');
  String get workDate => _text('workDate');
  String get timeIn => _text('timeIn');
  String get timeOut => _text('timeOut');
  String get saved => _text('saved');
  String get adminToolsOperationFailed => _text('adminToolsOperationFailed');
  String get manageWorkers => _text('manageWorkers');
  String get manageFields => _text('manageFields');
  String get addField => _text('addField');
  String get searchFields => _text('searchFields');
  String get noFields => _text('noFields');
  String get fieldName => _text('fieldName');
  String get location => _text('location');
  String get fieldOperationFailed => _text('fieldOperationFailed');
  String get addWorker => _text('addWorker');
  String get editWorker => _text('editWorker');
  String get searchWorkers => _text('searchWorkers');
  String get noWorkers => _text('noWorkers');
  String get cpNumber => _text('cpNumber');
  String get address => _text('address');
  String get save => _text('save');
  String get qrReissued => _text('qrReissued');
  String get active => _text('active');
  String get inactive => _text('inactive');
  String get activate => _text('activate');
  String get deactivate => _text('deactivate');
  String get reissueCard => _text('reissueCard');
  String get workerOperationFailed => _text('workerOperationFailed');
  String get importWorkers => _text('importWorkers');
  String get csvData => _text('csvData');
  String get importPreview => _text('importPreview');
  String get validRows => _text('validRows');
  String get invalidRows => _text('invalidRows');
  String get duplicateRows => _text('duplicateRows');
  String get preview => _text('preview');
  String get import => _text('import');
  String get printCard => _text('printCard');
  String get adminAccounts => _text('adminAccounts');
  String get adminAccountDescription => _text('adminAccountDescription');
  String get fullName => _text('fullName');
  String get startingPassword => _text('startingPassword');
  String get startingPasswordHint => _text('startingPasswordHint');
  String get createAdmin => _text('createAdmin');
  String get errAdminInput => _text('errAdminInput');
  String adminCreated(String code) =>
      _text('adminCreated').replaceFirst('{code}', code);

  String _text(String key) {
    Intl.defaultLocale = locale.languageCode;
    return (_messages[locale.languageCode] ?? _messages['en'])![key]!;
  }

  static const _messages = <String, Map<String, String>>{
    'en': {
      'appTitle': 'QR Attendance',
      'login': 'Log in',
      'logOut': 'Log out',
      'logOutWithPending': '{count} scans have not been uploaded yet. They stay on this phone. Log out anyway?',
      'errSessionEnded': 'Your session ended. Please log in again.',
      'oldFieldDaysHint': 'Earlier days that were never ended are listed here too. End them so their workers are clocked out.',
      'username': 'Username',
      'email': 'Email',
      'password': 'Password',
      'signIn': 'Sign in',
      'chooseRole': 'Choose a placeholder role',
      'technician': 'Technician',
      'admin': 'Admin',
      'superAdmin': 'Super admin',
      'scan': 'Scan',
      'endFieldDay': 'End field day',
      'workersStillClockedIn': '{count} workers still clocked in',
      'offline': 'Offline',
      'syncing': 'Syncing...',
      'online': 'Online',
      'offlineWithPending': 'Offline: {count} items waiting',
      'confirm': 'Confirm',
      'invalidQr': 'Invalid worker QR code',
      'workerNotCached':
          'This worker is not on this phone yet. Tap sync, then scan again.',
      'scanSaved': 'Scan saved',
      'errDateNotToday': 'The field day date does not match today.',
      'errFieldDayNotFound': 'No field day was found for this technician.',
      'errDevice':
          'This device cannot sync. Check device approval and try again.',
      'endFieldDayConfirm': 'Clock out {count} workers at {time}?',
      'scansNotUploaded':
          '{count} scans not uploaded. Connect to the internet.',
      'dashboard': 'Dashboard',
      'settings': 'Settings',
      'placeholder': 'This screen is a scaffold placeholder.',
      'language': 'Language',
      'english': 'English',
      'filipino': 'Filipino',
      'usernameHint': 'Enter username',
      'emailHint': 'Enter email',
      'errServerConfig': 'The app is not connected to the attendance server.',
      'errAccountDisabled':
          'This account is turned off. Please contact your admin.',
      'errMustChangePassword': 'Please choose a new password first.',
      'errPasswordWeak': 'Choose a password with at least 10 characters.',
      'errPasswordUpdateFailed':
          'The password could not be updated. Try again.',
      'errForbidden': 'You are not allowed to do this. Ask your admin.',
      'passwordHint': 'Enter password',
      'firstLoginTitle': 'Set your password',
      'firstLoginDescription':
          'Choose a new password before using the attendance system.',
      'newPassword': 'New password',
      'confirmPassword': 'Confirm password',
      'savePassword': 'Save password',
      'errPasswordChangeInvalid':
          'Passwords must match and contain at least 10 characters.',
      'refresh': 'Refresh',
      'adminLoadError':
          'The admin data could not be loaded. Check access and try again.',
      'todayFieldDays': "Today's field days",
      'noFieldDays': 'No active technicians were found for today.',
      'flaggedActivity': 'Flagged activity',
      'noFlaggedActivity': 'No flagged activity for today.',
      'workersPresent': 'Workers present',
      'totalMinutes': 'Total minutes',
      'fieldDays': 'Field days',
      'notEnded': 'Not ended',
      'noField': 'No field',
      'openWorkers': 'workers still open',
      'ended': 'Ended',
      'working': 'Working',
      'manualEndFieldDay': 'End field day manually',
      'reason': 'Reason',
      'cancel': 'Cancel',
      'fieldDayEnded': 'The field day was ended.',
      'clockedInCount': '{count} still clocked in',
      'workedCount': '{count} worked',
      'lastSync': 'Last sync',
      'neverSynced': 'Never',
      'endedAt': 'Ended {time}',
      'endTime': 'End time',
      'suggestedEndTime': 'Suggested: last scan of the day',
      'endTimeRequired': 'Type the end time. There was no scan on this date.',
      'errReasonRequired': 'Please write a reason.',
      'errTimeInFuture': 'This time has not happened yet. Check the time.',
      'errDateMismatch': 'The time must be on the same date.',
      'errTimeOutBeforeIn': 'Time out must be later than time in.',
      'errOverlap': 'This worker already has time recorded at that time. Check the other records.',
      'errAdminAction': 'The action could not be completed. Try again.',
      'errWeekNotMonday': 'Choose a Monday for the week.',
      'errSettingInvalid': 'This value is not allowed for this setting.',
      'errDevicePending':
          'This phone is waiting for approval. Ask your admin to approve it.',
      'errDeviceNotApproved':
          'This phone is not registered. Log in again to register it.',
      'errDeviceRevoked': 'This phone is no longer allowed. Ask your admin.',
      'errNoActiveField':
          'You have no field yet. Ask your admin to assign one.',
      'errScanOffline': 'Cannot reach the server. Connect to the internet, then tap Try again.',
      'scanLoading': 'Getting your field ready...',
      'cameraOpen': 'Open camera',
      'cameraClose': 'Close camera',
      'cameraOff': 'Camera is off. Tap Open camera to scan.',
      'cameraError': 'The camera cannot be used. Allow camera access in settings, then try again.',
      'scanLooking': 'Looking for a QR code...',
      'scanDetected': 'QR code detected',
      'scanBadCard': 'This card is not valid. Ask your admin for a new card.',
      'scanInactive': 'This worker is turned off. Tell your admin.',
      'scanRefused': '{name}: not saved. {reason}',
      'refusedHeldElsewhere': 'Another technician has this worker clocked in. Only that technician can clock them out.',
      'refusedUnknownWorker':
          'This worker is not in the system. Tell your admin.',
      'refusedInactiveField': 'This field is turned off. Tell your admin.',
      'refusedInactiveTechnician':
          'Your account is turned off. Tell your admin.',
      'refusedNotAssigned':
          'You are not assigned to this field. Tell your admin.',
      'refusedOther': 'The scan was not saved. Tell your admin.',
      'scanRepeat': 'Already scanned a moment ago.',
      'scanNotReady': 'Scanning is not ready. Connect to the internet, check that you have a field, then tap sync.',
      'clockedInAt': '{name}: CLOCKED IN {time}',
      'clockedOutAt': '{name}: CLOCKED OUT {time}',
      'notifications': 'Notifications',
      'noNotifications': 'No notifications yet.',
      'notifFieldDayNotEnded':
          '{count} technicians have not ended their field day: {names}',
      'notifFieldDayNotEndedOne':
          '1 technician has not ended their field day: {names}',
      'notifDeviceApproval': 'A phone is waiting for your approval.',
      'notifWorkerClockedOut': 'Worker clocked out: {name} ({reason})',
      'reasonSafetyNet': 'scanned by another technician',
      'reasonClosedOther': 'closed by the system',
      'notifGeneric': 'You have a new notice.',
      'reminderRepeatMinutes': 'Minutes before the second reminder',
      'reminderHint': 'At the reminder time you get a notice about field days that are not ended. It does not end them: use "{button}" on the dashboard.',
      'minutesValue': '{count} minutes',
      // Time records
      'timeRecords': 'Time records',
      'fixTimeRecord': 'Fix time record',
      'enteredByAdmin': 'Entered by admin',
      'noTimeRecords': 'No time records for this date.',
      'workerLabel': 'Worker',
      'fieldLabel': 'Field',
      'chooseWorker': 'Search worker by name or ID',
      'previousDay': 'Previous day',
      'nextDay': 'Next day',
      'chooseDate': 'Choose date',
      'notClockedOut': 'Not clocked out',
      'timeRecordIncomplete': 'Choose a worker, a technician and a field.',
      'errSessionNotFound': 'This time record was not found. Refresh the list.',
      'errFieldNotFound': 'This field was not found. Refresh the list.',
      'openTimeRecords': 'Open time records',
      // Paper sheet
      'paperSheet': 'Daily paper sheet',
      'paperSheetHint': 'Print a sheet for one technician and one date. Keep a few copies in case the phone fails.',
      'printSheet': 'Print sheet',
      'sheetTitle': 'Daily attendance sheet',
      'sheetTechnician': 'Technician',
      'sheetField': 'Field',
      'sheetDate': 'Date',
      'sheetNo': 'No.',
      'sheetId': 'ID',
      'sheetName': 'Name',
      'sheetTimeIn': 'Time in',
      'sheetTimeOut': 'Time out',
      'sheetExtra': 'Extra workers: write the ID number.',
      // Cards
      'printAllCards': 'Print all cards',
      'noCardsToPrint': 'There are no active workers to print.',
      // CSV import
      'chooseCsvFile': 'Choose CSV file',
      'csvHelp': 'The first row must be the column names: name, cp_no, address. Any other column is not used.',
      'csvChecking': 'Checking the file...',
      'csvImporting': 'Adding workers...',
      'csvNoNameColumn': 'The file needs a "name" column in the first row.',
      'csvEmpty': 'The file has no workers.',
      'csvReadError': 'The file could not be read. Choose a CSV file.',
      'csvRowsInFile': 'Rows in file',
      'importRowLine': 'Row {row}: {message}',
      'importDuplicateLine': 'Row {row}: possible duplicate of {id}',
      'importRepeatLine': 'Row {row}: same name as row {first} in this file',
      'csvColumnNotUsed': "Column '{name}' was not used.",
      'csvNameMissing': 'The name is missing.',
      'csvRowTooLong': 'A value in this row is too long.',
      'includeDuplicates': 'Also add the possible duplicates',
      'importDone': 'Added {count} workers.',
      'importMore': '+{count} more',
      'close': 'Close',
      // Fields and technicians
      'editField': 'Edit field',
      'turnOffAccount': 'Turn off account',
      'turnOnAccount': 'Turn on account',
      'accountOff': 'Account off',
      'confirmTurnOff': "Turn off {name}'s account? They will not be able to scan until you turn it on again.",
      'confirmTurnOn': "Turn on {name}'s account?",
      // Statistics and flagged list
      'statsToday': 'Today',
      'statsWeek': 'Week',
      'daily': 'Daily',
      'weekly': 'Weekly',
      'clockedInNow': 'Clocked in now',
      'finishedWorkers': 'Finished',
      'techniciansWorking': 'Technicians working',
      'fieldsWorking': 'Fields working',
      'fieldDaysNotEnded': 'Field days not ended',
      'workersPerDay': 'Workers per day',
      'hoursPerDay': 'Hours per day',
      'attendanceByField': 'Attendance by field',
      'thisWeek': 'This week',
      'lastWeek': 'Last week',
      'previousWeek': 'Previous week',
      'nextWeek': 'Next week',
      'presentDaysValue': '{count} days present',
      'workersWeekTotal': 'Workers present (all days)',
      'totalHours': 'Total hours',
      'durationShort': '{h} h {m} min',
      'flagOutsideHours': 'Outside scan hours',
      'flagClockSkew': 'Phone clock is wrong',
      'flagAfterFieldEnd': 'Scan after the field day ended',
      'flagSafetyNet': "Closed another technician's time",
      'flagNoLocation': 'No location saved',
      'flagBurst': 'Many scans at once',
      'flaggedFrom': 'From',
      'flaggedTo': 'To',
      'timeNotSet': 'Not set',
      'pickTime': 'Choose time',
      'retry': 'Try again',
      'workers': 'Workers',
      'fields': 'Fields',
      'technicians': 'Technicians',
      'manageTechnicians': 'Manage technicians',
      'createTechnician': 'Create technician',
      'assignField': 'Assign field',
      'pendingDevices': 'pending devices',
      'technicianOperationFailed': 'The technician action could not be completed. Refresh and try again.',
      'deviceApprovals': 'Device approvals',
      'device': 'Device',
      'approveDevice': 'Approve device',
      'revokeDevice': 'Revoke device',
      'deviceApproved': 'Approved',
      'deviceRevoked': 'Revoked',
      'devicePending': 'Waiting for approval',
      'adminTools': 'Admin tools',
      'scanHoursStart': 'Scan hours start',
      'scanHoursEnd': 'Scan hours end',
      'reminderTime': 'Reminder time',
      'timeFormat': 'Time (HH:MM)',
      'manualTimeRecord': 'Manual time record',
      'manualTimeRecordHint': 'Use database IDs for the field and technician. The reason is required and audited.',
      'addTimeRecord': 'Add time record',
      'weeklyMasterlist': 'Weekly masterlist',
      'loadMasterlist': 'Load masterlist',
      'selectWeek': 'Select week',
      'exportMasterlist': 'Export Excel',
      'printMasterlist': 'Print masterlist',
      'masterlistHeaders': 'ID,Name of the Worker,Monday,Tuesday,Wednesday,Thursday,Friday,Saturday,Sunday,Total Weekly Hours,Total Weekly Present,Signature',
      'noMasterlistRows': 'No attendance was recorded for this week.',
      'unendedWeekWarning': '{count} field days in this week are not ended. You can export anyway.',
      'notEndedCell': 'Not ended',
      'exportSaved': 'Masterlist exported.',
      'changedAfterExport': 'This week changed after its last export.',
      'workerLookup': 'Worker lookup',
      'lookupWorkerId': 'Worker ID',
      'loadWorkerWeek': 'Load current week',
      'noWorkerWeek': 'No attendance recorded this week.',
      'workerId': 'Worker ID',
      'fieldId': 'Field ID',
      'technicianId': 'Technician ID',
      'workDate': 'Work date (YYYY-MM-DD)',
      'timeIn': 'Time in (HH:MM)',
      'timeOut': 'Time out (HH:MM)',
      'saved': 'Saved',
      'adminToolsOperationFailed': 'The admin operation could not be completed. Check the values and try again.',
      'manageWorkers': 'Manage workers',
      'manageFields': 'Manage fields',
      'addField': 'Add field',
      'searchFields': 'Search fields',
      'noFields': 'No fields found.',
      'fieldName': 'Field name',
      'location': 'Location',
      'fieldOperationFailed':
          'The field action could not be completed. Refresh and try again.',
      'addWorker': 'Add worker',
      'editWorker': 'Edit worker',
      'searchWorkers': 'Search by name or Worker ID',
      'noWorkers': 'No workers found.',
      'cpNumber': 'CP number',
      'address': 'Address',
      'save': 'Save',
      'qrReissued': 'QR card reissued',
      'active': 'Active',
      'inactive': 'Inactive',
      'activate': 'Activate',
      'deactivate': 'Deactivate',
      'reissueCard': 'Reissue QR card',
      'workerOperationFailed':
          'The worker action could not be completed. Refresh and try again.',
      'importWorkers': 'Import workers',
      'csvData': 'Paste CSV data',
      'importPreview': 'Import preview',
      'validRows': 'Valid rows',
      'invalidRows': 'Invalid rows',
      'duplicateRows': 'Possible duplicates',
      'preview': 'Preview',
      'import': 'Import',
      'printCard': 'Print QR card',
      'adminAccounts': 'Admin accounts',
      'adminAccountDescription': 'Create an admin with a temporary password. They must choose a new password at first login.',
      'fullName': 'Full name',
      'startingPassword': 'Temporary password',
      'startingPasswordHint': 'At least 10 characters',
      'createAdmin': 'Create admin account',
      'errAdminInput': 'Enter a full name, a valid email, and a password with at least 10 characters.',
      'adminCreated': 'Admin {code} was created. Give them the temporary password securely.',
      'errEmailTaken': 'This email is already used. Try another email.',
      'errAccountCreateFailed': 'The account could not be created. Try again.',
      'errInvalidLogin': 'The email or password is incorrect.',
      'errLoginStateFailed': 'Login succeeded, but the account profile could not be loaded. Contact your administrator.',
      'errLoginFailed':
          'Login could not be completed. Check your connection and try again.',
      'errWorkerNotFound':
          'The worker could not be updated. Refresh the list and try again.',
    },
    'fil': {
      'appTitle': 'QR Attendance',
      'login': 'Mag-log in',
      'logOut': 'Mag-log out',
      'logOutWithPending': '{count} scan ang hindi pa naa-upload. Mananatili ang mga ito sa telepono. Mag-log out pa rin?',
      'errSessionEnded': 'Natapos ang iyong session. Mag-log in muli.',
      'oldFieldDaysHint': 'Kasama rin dito ang mga naunang araw na hindi natapos. Tapusin ang mga ito para ma-clock out ang mga manggagawa.',
      'username': 'Username',
      'email': 'Email',
      'password': 'Password',
      'signIn': 'Mag-sign in',
      'chooseRole': 'Pumili ng placeholder na tungkulin',
      'technician': 'Technician',
      'admin': 'Admin',
      'superAdmin': 'Super admin',
      'scan': 'Mag-scan',
      'endFieldDay': 'Tapusin ang araw sa field',
      'workersStillClockedIn': '{count} manggagawa ay naka-clock in pa',
      'offline': 'Walang internet',
      'syncing': 'Nagsi-sync...',
      'online': 'May internet',
      'offlineWithPending': 'Walang internet: {count} naghihintay',
      'confirm': 'Kumpirmahin',
      'invalidQr': 'Hindi wastong QR code ng manggagawa',
      'workerNotCached': 'Wala pa sa teleponong ito ang manggagawa. Pindutin ang sync, saka mag-scan muli.',
      'scanSaved': 'Na-save ang scan',
      'errDateNotToday': 'Hindi tugma ang petsa ng field day sa araw na ito.',
      'errFieldDayNotFound': 'Walang field day para sa technician na ito.',
      'errDevice':
          'Hindi makapag-sync ang device. Suriin ang approval at subukan muli.',
      'endFieldDayConfirm': 'I-clock out ang {count} manggagawa sa {time}?',
      'scansNotUploaded':
          '{count} scan ang hindi pa na-upload. Kumonekta sa internet.',
      'dashboard': 'Dashboard',
      'settings': 'Settings',
      'placeholder': 'Placeholder lamang ang screen na ito.',
      'language': 'Wika',
      'english': 'English',
      'filipino': 'Filipino',
      'usernameHint': 'Ilagay ang username',
      'emailHint': 'Ilagay ang email',
      'errServerConfig': 'Hindi nakakonekta ang app sa server ng attendance.',
      'errAccountDisabled':
          'Naka-off ang account na ito. Makipag-ugnayan sa admin.',
      'errMustChangePassword': 'Pumili muna ng bagong password.',
      'errPasswordWeak':
          'Pumili ng password na may hindi bababa sa 10 character.',
      'errPasswordUpdateFailed': 'Hindi ma-update ang password. Subukan muli.',
      'errForbidden': 'Hindi ka pinapayagang gawin ito. Tanungin ang admin.',
      'passwordHint': 'Ilagay ang password',
      'firstLoginTitle': 'Itakda ang iyong password',
      'firstLoginDescription':
          'Pumili ng bagong password bago gamitin ang attendance system.',
      'newPassword': 'Bagong password',
      'confirmPassword': 'Kumpirmahin ang password',
      'savePassword': 'I-save ang password',
      'errPasswordChangeInvalid':
          'Dapat magkapareho ang password at may hindi bababa sa 10 character.',
      'refresh': 'I-refresh',
      'adminLoadError':
          'Hindi ma-load ang admin data. Suriin ang access at subukan muli.',
      'todayFieldDays': 'Mga field day ngayong araw',
      'noFieldDays': 'Walang aktibong technician para sa araw na ito.',
      'flaggedActivity': 'Mga na-flag na aktibidad',
      'noFlaggedActivity': 'Walang na-flag na aktibidad ngayong araw.',
      'workersPresent': 'Mga manggagawang pumasok',
      'totalMinutes': 'Kabuuang minuto',
      'fieldDays': 'Mga field day',
      'notEnded': 'Hindi pa natatapos',
      'noField': 'Walang field',
      'openWorkers': 'manggagawang bukas pa',
      'ended': 'Natapos',
      'working': 'Nagtatrabaho',
      'manualEndFieldDay': 'Manu-manong tapusin ang field day',
      'reason': 'Dahilan',
      'cancel': 'Kanselahin',
      'fieldDayEnded': 'Natapos na ang field day.',
      'clockedInCount': '{count} ang naka-clock in pa',
      'workedCount': '{count} ang nagtrabaho',
      'lastSync': 'Huling sync',
      'neverSynced': 'Wala pa',
      'endedAt': 'Natapos {time}',
      'endTime': 'Oras ng pagtatapos',
      'suggestedEndTime': 'Mungkahi: huling scan ng araw',
      'endTimeRequired':
          'I-type ang oras ng pagtatapos. Walang scan sa petsang ito.',
      'errReasonRequired': 'Magsulat ng dahilan.',
      'errTimeInFuture':
          'Hindi pa dumarating ang oras na ito. Tingnan ang oras.',
      'errDateMismatch': 'Dapat nasa parehong petsa ang oras.',
      'errTimeOutBeforeIn':
          'Dapat mas huli ang oras ng labas kaysa oras ng pasok.',
      'errOverlap': 'May naitala nang oras ang manggagawang ito sa oras na iyon. Tingnan ang ibang talaan.',
      'errAdminAction': 'Hindi natapos ang aksyon. Subukan muli.',
      'errWeekNotMonday': 'Pumili ng Lunes para sa linggo.',
      'errSettingInvalid':
          'Hindi pinapayagan ang halagang ito sa setting na ito.',
      'errDevicePending': 'Naghihintay ng pag-apruba ang teleponong ito. Hilingin sa admin na aprubahan ito.',
      'errDeviceNotApproved': 'Hindi pa rehistrado ang teleponong ito. Mag-log in muli para marehistro ito.',
      'errDeviceRevoked':
          'Hindi na pinapayagan ang teleponong ito. Magtanong sa admin.',
      'errNoActiveField':
          'Wala ka pang field. Hilingin sa admin na magtalaga ng isa.',
      'errScanOffline': 'Hindi maabot ang server. Kumonekta sa internet, saka pindutin ang Subukan muli.',
      'scanLoading': 'Inihahanda ang iyong field...',
      'cameraOpen': 'Buksan ang camera',
      'cameraClose': 'Isara ang camera',
      'cameraOff':
          'Nakasara ang camera. Pindutin ang Buksan ang camera para mag-scan.',
      'cameraError': 'Hindi magamit ang camera. Payagan ang camera sa settings, saka subukan muli.',
      'scanLooking': 'Naghahanap ng QR code...',
      'scanDetected': 'May nakitang QR code',
      'scanBadCard':
          'Hindi valid ang card na ito. Humingi ng bagong card sa admin.',
      'scanInactive': 'Naka-off ang manggagawang ito. Sabihin sa admin.',
      'scanRefused': '{name}: hindi na-save. {reason}',
      'refusedHeldElsewhere': 'Naka-clock in ang manggagawang ito sa ibang technician. Ang technician lang na iyon ang puwedeng mag-clock out sa kanya.',
      'refusedUnknownWorker':
          'Wala sa sistema ang manggagawang ito. Sabihin sa admin.',
      'refusedInactiveField': 'Naka-off ang field na ito. Sabihin sa admin.',
      'refusedInactiveTechnician': 'Naka-off ang account mo. Sabihin sa admin.',
      'refusedNotAssigned':
          'Hindi ka naka-assign sa field na ito. Sabihin sa admin.',
      'refusedOther': 'Hindi na-save ang scan. Sabihin sa admin.',
      'scanRepeat': 'Na-scan na ito kani-kanina lang.',
      'scanNotReady': 'Hindi pa handa ang pag-scan. Kumonekta sa internet, tiyaking may field ka, saka pindutin ang sync.',
      'clockedInAt': '{name}: NAKA-CLOCK IN {time}',
      'clockedOutAt': '{name}: NAKA-CLOCK OUT {time}',
      'notifications': 'Mga abiso',
      'noNotifications': 'Wala pang abiso.',
      'notifFieldDayNotEnded':
          '{count} technician ang hindi pa nagtatapos ng field day: {names}',
      'notifFieldDayNotEndedOne':
          '1 technician ang hindi pa nagtatapos ng field day: {names}',
      'notifDeviceApproval': 'May teleponong naghihintay ng iyong pag-apruba.',
      'notifWorkerClockedOut': 'Na-clock out ang manggagawa: {name} ({reason})',
      'reasonSafetyNet': 'na-scan ng ibang technician',
      'reasonClosedOther': 'isinara ng sistema',
      'notifGeneric': 'May bago kang abiso.',
      'reminderRepeatMinutes': 'Minuto bago ang ikalawang paalala',
      'reminderHint': 'Sa oras ng paalala, makakatanggap ka ng abiso tungkol sa mga field day na hindi pa tapos. Hindi nito tinatapos ang mga ito: gamitin ang "{button}" sa dashboard.',
      'minutesValue': '{count} minuto',
      // Time records
      'timeRecords': 'Mga talaan ng oras',
      'fixTimeRecord': 'Ayusin ang talaan ng oras',
      'enteredByAdmin': 'Inilagay ng admin',
      'noTimeRecords': 'Walang talaan ng oras sa petsang ito.',
      'workerLabel': 'Manggagawa',
      'fieldLabel': 'Field',
      'chooseWorker': 'Hanapin ang manggagawa sa pangalan o ID',
      'previousDay': 'Nakaraang araw',
      'nextDay': 'Susunod na araw',
      'chooseDate': 'Pumili ng petsa',
      'notClockedOut': 'Hindi pa naka-clock out',
      'timeRecordIncomplete': 'Pumili ng manggagawa, technician at field.',
      'errSessionNotFound':
          'Hindi nakita ang talaan ng oras na ito. I-refresh ang listahan.',
      'errFieldNotFound':
          'Hindi nakita ang field na ito. I-refresh ang listahan.',
      'openTimeRecords': 'Buksan ang mga talaan ng oras',
      // Paper sheet
      'paperSheet': 'Papel na sheet para sa araw',
      'paperSheetHint': 'Mag-print ng sheet para sa isang technician at isang petsa. Magtabi ng ilang kopya kung masira ang telepono.',
      'printSheet': 'I-print ang sheet',
      'sheetTitle': 'Sheet ng pagpasok sa araw',
      'sheetTechnician': 'Technician',
      'sheetField': 'Field',
      'sheetDate': 'Petsa',
      'sheetNo': 'Blg.',
      'sheetId': 'ID',
      'sheetName': 'Pangalan',
      'sheetTimeIn': 'Oras ng pasok',
      'sheetTimeOut': 'Oras ng labas',
      'sheetExtra': 'Mga dagdag na manggagawa: isulat ang ID number.',
      // Cards
      'printAllCards': 'I-print ang lahat ng card',
      'noCardsToPrint': 'Walang aktibong manggagawa na ipi-print.',
      // CSV import
      'chooseCsvFile': 'Pumili ng CSV file',
      'csvHelp': 'Dapat pangalan ng mga column ang unang hilera: name, cp_no, address. Hindi ginagamit ang ibang column.',
      'csvChecking': 'Sinusuri ang file...',
      'csvImporting': 'Idinadagdag ang mga manggagawa...',
      'csvNoNameColumn':
          'Kailangan ng column na "name" sa unang hilera ng file.',
      'csvEmpty': 'Walang manggagawa sa file.',
      'csvReadError': 'Hindi mabasa ang file. Pumili ng CSV file.',
      'csvRowsInFile': 'Mga hilera sa file',
      'importRowLine': 'Hilera {row}: {message}',
      'importDuplicateLine': 'Hilera {row}: posibleng kapareho ni {id}',
      'importRepeatLine':
          'Hilera {row}: kapareho ng pangalan sa hilera {first} ng file',
      'csvColumnNotUsed': "Hindi ginamit ang column na '{name}'.",
      'csvNameMissing': 'Walang pangalan.',
      'csvRowTooLong': 'Masyadong mahaba ang isang halaga sa hilerang ito.',
      'includeDuplicates': 'Idagdag din ang mga posibleng doble',
      'importDone': 'Naidagdag ang {count} manggagawa.',
      'importMore': '+{count} pa',
      'close': 'Isara',
      // Fields and technicians
      'editField': 'I-edit ang field',
      'turnOffAccount': 'I-off ang account',
      'turnOnAccount': 'I-on ang account',
      'accountOff': 'Naka-off ang account',
      'confirmTurnOff': 'I-off ang account ni {name}? Hindi siya makakapag-scan hangga\'t hindi mo ito ibinabalik.',
      'confirmTurnOn': 'I-on ang account ni {name}?',
      // Statistics and flagged list
      'statsToday': 'Ngayon',
      'statsWeek': 'Linggo',
      'daily': 'Araw-araw',
      'weekly': 'Lingguhan',
      'clockedInNow': 'Naka-clock in ngayon',
      'finishedWorkers': 'Tapos na',
      'techniciansWorking': 'Technician na nagtatrabaho',
      'fieldsWorking': 'Field na may trabaho',
      'fieldDaysNotEnded': 'Field day na hindi pa natatapos',
      'workersPerDay': 'Manggagawa bawat araw',
      'hoursPerDay': 'Oras bawat araw',
      'attendanceByField': 'Pagpasok bawat field',
      'thisWeek': 'Ngayong linggo',
      'lastWeek': 'Nakaraang linggo',
      'previousWeek': 'Nakaraang linggo',
      'nextWeek': 'Susunod na linggo',
      'presentDaysValue': '{count} araw na pumasok',
      'workersWeekTotal': 'Manggagawang pumasok (lahat ng araw)',
      'totalHours': 'Kabuuang oras',
      'durationShort': '{h} oras {m} min',
      'flagOutsideHours': 'Labas sa oras ng pag-scan',
      'flagClockSkew': 'Mali ang orasan ng telepono',
      'flagAfterFieldEnd': 'Scan matapos ang field day',
      'flagSafetyNet': 'Isinara ang oras ng ibang technician',
      'flagNoLocation': 'Walang nai-save na lokasyon',
      'flagBurst': 'Sabay-sabay na maraming scan',
      'flaggedFrom': 'Mula',
      'flaggedTo': 'Hanggang',
      'timeNotSet': 'Hindi pa naitakda',
      'pickTime': 'Pumili ng oras',
      'retry': 'Subukan muli',
      'workers': 'Mga manggagawa',
      'fields': 'Mga field',
      'technicians': 'Mga technician',
      'manageTechnicians': 'Pamahalaan ang mga technician',
      'createTechnician': 'Gumawa ng technician',
      'assignField': 'Magtalaga ng field',
      'pendingDevices': 'nakabinbing device',
      'technicianOperationFailed': 'Hindi nakumpleto ang aksyon sa technician. I-refresh at subukan muli.',
      'deviceApprovals': 'Pag-apruba ng device',
      'device': 'Device',
      'approveDevice': 'Aprubahan ang device',
      'revokeDevice': 'Bawiin ang device',
      'deviceApproved': 'Aprubado',
      'deviceRevoked': 'Binawi',
      'devicePending': 'Naghihintay ng pag-apruba',
      'adminTools': 'Mga admin tool',
      'scanHoursStart': 'Simula ng oras ng scan',
      'scanHoursEnd': 'Pagtatapos ng oras ng scan',
      'reminderTime': 'Oras ng paalala',
      'timeFormat': 'Oras (HH:MM)',
      'manualTimeRecord': 'Manwal na tala ng oras',
      'manualTimeRecordHint': 'Gamitin ang database ID ng field at technician. Kailangan ang dahilan at ito ay ia-audit.',
      'addTimeRecord': 'Magdagdag ng tala ng oras',
      'weeklyMasterlist': 'Lingguhang masterlist',
      'loadMasterlist': 'I-load ang masterlist',
      'selectWeek': 'Pumili ng linggo',
      'exportMasterlist': 'I-export sa Excel',
      'printMasterlist': 'I-print ang masterlist',
      'masterlistHeaders': 'ID,Pangalan ng manggagawa,Lunes,Martes,Miyerkules,Huwebes,Biyernes,Sabado,Linggo,Kabuuang oras sa linggo,Kabuuang araw na pumasok,Signature',
      'noMasterlistRows': 'Walang attendance para sa linggong ito.',
      'unendedWeekWarning': '{count} field day sa linggong ito ang hindi pa tapos. Maaari pa ring mag-export.',
      'notEndedCell': 'Hindi pa tapos',
      'exportSaved': 'Na-export ang masterlist.',
      'changedAfterExport':
          'Nagbago ang linggong ito matapos ang huling export.',
      'workerLookup': 'Hanapin ang worker',
      'lookupWorkerId': 'Worker ID',
      'loadWorkerWeek': 'I-load ang kasalukuyang linggo',
      'noWorkerWeek': 'Walang attendance ngayong linggo.',
      'workerId': 'Worker ID',
      'fieldId': 'Field ID',
      'technicianId': 'Technician ID',
      'workDate': 'Petsa (YYYY-MM-DD)',
      'timeIn': 'Oras ng in (HH:MM)',
      'timeOut': 'Oras ng out (HH:MM)',
      'saved': 'Nai-save',
      'adminToolsOperationFailed': 'Hindi nakumpleto ang admin operation. Suriin ang values at subukan muli.',
      'manageWorkers': 'Pamahalaan ang mga manggagawa',
      'manageFields': 'Pamahalaan ang mga field',
      'addField': 'Magdagdag ng field',
      'searchFields': 'Maghanap ng field',
      'noFields': 'Walang nahanap na field.',
      'fieldName': 'Pangalan ng field',
      'location': 'Lokasyon',
      'fieldOperationFailed':
          'Hindi nakumpleto ang aksyon sa field. I-refresh at subukan muli.',
      'addWorker': 'Magdagdag ng manggagawa',
      'editWorker': 'I-edit ang manggagawa',
      'searchWorkers': 'Maghanap ayon sa pangalan o Worker ID',
      'noWorkers': 'Walang nahanap na manggagawa.',
      'cpNumber': 'CP number',
      'address': 'Address',
      'save': 'I-save',
      'qrReissued': 'Na-isyu muli ang QR card',
      'active': 'Aktibo',
      'inactive': 'Hindi aktibo',
      'activate': 'I-activate',
      'deactivate': 'I-deactivate',
      'reissueCard': 'Mag-isyu muli ng QR card',
      'workerOperationFailed': 'Hindi nakumpleto ang aksyon sa manggagawa. I-refresh at subukan muli.',
      'importWorkers': 'Mag-import ng manggagawa',
      'csvData': 'I-paste ang CSV data',
      'importPreview': 'Preview ng import',
      'validRows': 'Balidong row',
      'invalidRows': 'Hindi balidong row',
      'duplicateRows': 'Posibleng duplicate',
      'preview': 'Preview',
      'import': 'Mag-import',
      'printCard': 'I-print ang QR card',
      'adminAccounts': 'Mga admin account',
      'adminAccountDescription': 'Gumawa ng admin na may pansamantalang password. Dapat itong palitan sa unang login.',
      'fullName': 'Buong pangalan',
      'startingPassword': 'Pansamantalang password',
      'startingPasswordHint': 'Hindi bababa sa 10 character',
      'createAdmin': 'Gumawa ng admin account',
      'errAdminInput': 'Maglagay ng buong pangalan, wastong email, at password na may hindi bababa sa 10 character.',
      'adminCreated': 'Nagawa ang admin {code}. Ibigay nang ligtas ang pansamantalang password.',
      'errEmailTaken': 'Ginagamit na ang email na ito. Sumubok ng iba.',
      'errAccountCreateFailed': 'Hindi nagawa ang account. Subukan muli.',
      'errInvalidLogin': 'Mali ang email o password.',
      'errLoginStateFailed': 'Nagtagumpay ang login ngunit hindi ma-load ang profile. Makipag-ugnayan sa administrator.',
      'errLoginFailed':
          'Hindi nakumpleto ang login. Suriin ang koneksyon at subukan muli.',
      'errWorkerNotFound': 'Hindi na-update ang manggagawa. I-refresh ang listahan at subukan muli.',
    },
  };
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => AppLocalizations.supportedLocales.any(
    (supported) => supported.languageCode == locale.languageCode,
  );

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
