import 'package:flutter/material.dart';

/// The messages above the camera: why scanning is not ready, scans the server
/// refused, and "worker clocked out" notices. Up to three banners can be
/// showing at once; on a short phone they would push the fixed rows below the
/// camera off the screen (a RenderFlex overflow), so together they take at
/// most [maxShare] of the screen height and scroll inside that.
class ScannerBanners extends StatelessWidget {
  const ScannerBanners({
    required this.closeLabel,
    required this.retryLabel,
    this.readinessMessage,
    this.onRetry,
    this.refused = const [],
    this.onCloseRefused,
    this.notices = const [],
    this.onCloseNotices,
    this.maxShare = 0.25,
    super.key,
  });

  final String closeLabel;
  final String retryLabel;

  /// Shown with a Retry button while scanning cannot work.
  final String? readinessMessage;
  final VoidCallback? onRetry;

  /// One line for each scan the server refused.
  final List<String> refused;
  final VoidCallback? onCloseRefused;

  /// The text of each unread "worker clocked out" notice.
  final List<String> notices;
  final VoidCallback? onCloseNotices;

  final double maxShare;

  @override
  Widget build(BuildContext context) {
    final readiness = readinessMessage;
    if (readiness == null && refused.isEmpty && notices.isEmpty) {
      return const SizedBox.shrink();
    }
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * maxShare,
      ),
      child: SingleChildScrollView(
        child: Column(
          children: [
            if (readiness != null)
              MaterialBanner(
                content: Text(readiness),
                actions: [
                  TextButton(onPressed: onRetry, child: Text(retryLabel)),
                ],
              ),
            if (refused.isNotEmpty)
              MaterialBanner(
                leading: const Icon(Icons.block),
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [for (final line in refused) Text(line)],
                ),
                actions: [
                  TextButton(
                    onPressed: onCloseRefused,
                    child: Text(closeLabel),
                  ),
                ],
              ),
            if (notices.isNotEmpty)
              MaterialBanner(
                leading: const Icon(Icons.person_off),
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [for (final text in notices) Text(text)],
                ),
                actions: [
                  TextButton(
                    onPressed: onCloseNotices,
                    child: Text(closeLabel),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// The scanner screen from top to bottom: status row, banners, the camera,
/// and the rows below it. The camera takes the height that is left. The banners
/// and the rows below it are each capped and scroll inside their share, so a
/// short phone or larger text never makes the column taller than the screen
/// (a RenderFlex overflow on the bottom).
class ScannerLayout extends StatelessWidget {
  const ScannerLayout({
    required this.status,
    required this.banners,
    required this.camera,
    required this.footer,
    this.footerShare = 0.4,
    super.key,
  });

  final Widget status;

  /// Normally a [ScannerBanners].
  final Widget banners;

  /// Fills the height that is left.
  final Widget camera;

  /// The feedback bar, the camera button, the count and End field day.
  final List<Widget> footer;

  final double footerShare;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        status,
        banners,
        Expanded(child: camera),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * footerShare,
          ),
          child: SingleChildScrollView(child: Column(children: footer)),
        ),
      ],
    );
  }
}
