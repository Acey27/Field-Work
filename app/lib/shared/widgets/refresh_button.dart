import 'package:flutter/material.dart';

/// The refresh icon in an app bar. While [onRefresh] runs the icon turns, so
/// the admin can see that the page is being fetched again. The turning is
/// shown for at least [minimum], so a quick answer is still noticed.
class RefreshButton extends StatefulWidget {
  const RefreshButton({
    required this.onRefresh,
    required this.tooltip,
    this.minimum = const Duration(milliseconds: 700),
    super.key,
  });

  /// Completes when the page has its new data. Errors are the page's own
  /// business (it keeps the old data and says so); they only end the turning.
  final Future<void> Function() onRefresh;
  final String tooltip;
  final Duration minimum;

  @override
  State<RefreshButton> createState() => _RefreshButtonState();
}

class _RefreshButtonState extends State<RefreshButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _turn = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  bool _busy = false;

  @override
  void dispose() {
    _turn.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    if (_busy) return;
    setState(() => _busy = true);
    _turn.repeat();
    try {
      await Future.wait([
        () async {
          try {
            await widget.onRefresh();
          } on Object {
            // Reported by the page.
          }
        }(),
        Future<void>.delayed(widget.minimum),
      ]);
    } finally {
      if (mounted) {
        _turn.stop();
        _turn.value = 0;
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: widget.tooltip,
      // A second tap while fetching does nothing (see _run).
      onPressed: _run,
      icon: RotationTransition(turns: _turn, child: const Icon(Icons.refresh)),
    );
  }
}
