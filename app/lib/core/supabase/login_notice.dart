import 'package:flutter/foundation.dart';

/// Why the app returned to the login page without the user asking to log out.
/// The login page shows it once and clears it. Values are error codes that
/// `AppLocalizations.authError` knows.
final loginNotice = ValueNotifier<String?>(null);

/// The session could not be renewed (CONTRACT.md section 1).
const sessionEndedNotice = 'E_SESSION_ENDED';
