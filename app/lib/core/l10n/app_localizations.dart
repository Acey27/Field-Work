import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AppLocalizations {
  const AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = [Locale('en'), Locale('fil')];
  static const localizationsDelegates = <LocalizationsDelegate<Object>>[
    _AppLocalizationsDelegate(),
  ];

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        const AppLocalizations(Locale('en'));
  }

  String get appTitle => _text('appTitle');
  String get login => _text('login');
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
    'E_MUST_CHANGE_PASSWORD' => _text('errMustChangePassword'),
    'E_PASSWORD_WEAK' => _text('errPasswordWeak'),
    'E_PASSWORD_UPDATE_FAILED' => _text('errPasswordUpdateFailed'),
    _ => _text('errForbidden'),
  };
  String get passwordHint => _text('passwordHint');
  String get firstLoginTitle => _text('firstLoginTitle');
  String get firstLoginDescription => _text('firstLoginDescription');
  String get newPassword => _text('newPassword');
  String get confirmPassword => _text('confirmPassword');
  String get savePassword => _text('savePassword');
  String get errPasswordChangeInvalid => _text('errPasswordChangeInvalid');

  String _text(String key) {
    Intl.defaultLocale = locale.languageCode;
    return (_messages[locale.languageCode] ?? _messages['en'])![key]!;
  }

  static const _messages = <String, Map<String, String>>{
    'en': {
      'appTitle': 'QR Attendance',
      'login': 'Log in',
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
    },
    'fil': {
      'appTitle': 'QR Attendance',
      'login': 'Mag-log in',
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
