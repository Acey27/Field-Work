/// Whether the technician's phone can scan, and if not, why.
///
/// Codes come from `register_device` and `get_my_context`
/// (CONTRACT.md sections 4.2, 4.4 and 13).
enum ScanReadiness {
  loading,
  ready,
  devicePending,
  deviceNotApproved,
  deviceRevoked,
  noField,
  accountDisabled,
  mustChangePassword,

  /// The server could not be reached, or an unexpected error happened.
  offline,
}

ScanReadiness readinessFromCode(String? code) => switch (code) {
  'E_DEVICE_PENDING' => ScanReadiness.devicePending,
  'E_DEVICE_NOT_APPROVED' => ScanReadiness.deviceNotApproved,
  'E_DEVICE_REVOKED' => ScanReadiness.deviceRevoked,
  'E_NO_ACTIVE_FIELD' => ScanReadiness.noField,
  'E_ACCOUNT_DISABLED' => ScanReadiness.accountDisabled,
  'E_MUST_CHANGE_PASSWORD' => ScanReadiness.mustChangePassword,
  _ => ScanReadiness.offline,
};

/// The `get_my_context` answer: ready only when both the profile and the
/// current field are present. A missing field is `E_NO_ACTIVE_FIELD`.
ScanReadiness readinessFromContext(Map<String, dynamic> response) {
  if (response['profile'] is! Map) return ScanReadiness.offline;
  if (response['field'] is! Map) return ScanReadiness.noField;
  return ScanReadiness.ready;
}
