import 'package:flutter/material.dart';

import '../../../core/l10n/app_localizations.dart';
import '../domain/scan_readiness.dart';

enum ScanFeedbackKind { idle, detected, success, attention, error }

/// The message that tells the technician why scanning cannot start yet.
ScanFeedback feedbackForReadiness(
  AppLocalizations l10n,
  ScanReadiness readiness,
) {
  return switch (readiness) {
    ScanReadiness.loading => ScanFeedback(
      ScanFeedbackKind.idle,
      l10n.scanLoading,
    ),
    ScanReadiness.ready => const ScanFeedback.idle(),
    ScanReadiness.devicePending => ScanFeedback(
      ScanFeedbackKind.attention,
      l10n.errDevicePending,
    ),
    ScanReadiness.deviceNotApproved => ScanFeedback(
      ScanFeedbackKind.error,
      l10n.errDeviceNotApproved,
    ),
    ScanReadiness.deviceRevoked => ScanFeedback(
      ScanFeedbackKind.error,
      l10n.errDeviceRevoked,
    ),
    ScanReadiness.noField => ScanFeedback(
      ScanFeedbackKind.attention,
      l10n.errNoActiveField,
    ),
    ScanReadiness.accountDisabled => ScanFeedback(
      ScanFeedbackKind.error,
      l10n.errAccountDisabled,
    ),
    ScanReadiness.mustChangePassword => ScanFeedback(
      ScanFeedbackKind.attention,
      l10n.errMustChangePassword,
    ),
    ScanReadiness.offline => ScanFeedback(
      ScanFeedbackKind.error,
      l10n.errScanOffline,
    ),
  };
}

/// What the scanner screen tells the technician right now.
class ScanFeedback {
  const ScanFeedback(this.kind, this.message);
  const ScanFeedback.idle() : kind = ScanFeedbackKind.idle, message = '';

  final ScanFeedbackKind kind;
  final String message;
}

/// Forest green = success, yellow = needs attention, red = error (SPEC §14).
({Color color, IconData icon}) feedbackStyle(
  BuildContext context,
  ScanFeedbackKind kind,
) {
  final colors = Theme.of(context).colorScheme;
  return switch (kind) {
    ScanFeedbackKind.success => (color: colors.primary, icon: Icons.check_circle),
    ScanFeedbackKind.detected => (color: colors.secondary, icon: Icons.qr_code_2),
    ScanFeedbackKind.attention => (color: colors.secondary, icon: Icons.info),
    ScanFeedbackKind.error => (color: colors.error, icon: Icons.error),
    ScanFeedbackKind.idle => (
      color: colors.outline,
      icon: Icons.qr_code_scanner,
    ),
  };
}

/// Big message under the camera: looking, detected, or the scan result.
class ScanFeedbackBanner extends StatelessWidget {
  const ScanFeedbackBanner({required this.feedback, super.key});

  final ScanFeedback feedback;

  @override
  Widget build(BuildContext context) {
    final style = feedbackStyle(context, feedback.kind);
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        color: style.color,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(style.icon, color: Colors.white, size: 36),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                feedback.message,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A square frame over the camera that changes color when a QR code is seen.
class ScanFrame extends StatelessWidget {
  const ScanFrame({required this.kind, super.key});

  final ScanFeedbackKind kind;

  @override
  Widget build(BuildContext context) {
    final color = kind == ScanFeedbackKind.idle
        ? Colors.white
        : feedbackStyle(context, kind).color;
    return IgnorePointer(
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 240,
          height: 240,
          decoration: BoxDecoration(
            border: Border.all(color: color, width: 6),
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

class CameraOffPanel extends StatelessWidget {
  const CameraOffPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam_off, size: 64),
              const SizedBox(height: 12),
              Text(
                AppLocalizations.of(context).cameraOff,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CameraErrorPanel extends StatelessWidget {
  const CameraErrorPanel({required this.onRetry, super.key});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ColoredBox(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.no_photography, size: 64),
              const SizedBox(height: 12),
              Text(
                l10n.cameraError,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: Text(l10n.retry)),
            ],
          ),
        ),
      ),
    );
  }
}
