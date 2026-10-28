import 'package:flutter/material.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/utils/ph_time.dart';

typedef EndFieldDayChoice = ({DateTime endedAt, String reason});

/// Asks for the end time and reason of a manual End field day.
///
/// [suggested] is the technician's last scan (UTC). It is pre-filled only for
/// today; for a past date the admin must type the time (spec section 8).
class EndFieldDayDialog extends StatefulWidget {
  const EndFieldDayDialog({
    required this.workDate,
    required this.suggested,
    super.key,
  });

  final DateTime workDate;
  final DateTime? suggested;

  @override
  State<EndFieldDayDialog> createState() => _EndFieldDayDialogState();
}

class _EndFieldDayDialogState extends State<EndFieldDayDialog> {
  final _reason = TextEditingController();
  DateTime? _endedAt;

  @override
  void initState() {
    super.initState();
    final isToday = widget.workDate == phDateOf(DateTime.now());
    if (isToday) _endedAt = widget.suggested;
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final current = _endedAt?.toUtc().add(const Duration(hours: 8));
    final picked = await showTimePicker(
      context: context,
      initialTime: current == null
          ? const TimeOfDay(hour: 17, minute: 0)
          : TimeOfDay(hour: current.hour, minute: current.minute),
    );
    if (picked == null) return;
    setState(() {
      _endedAt = phTimeToUtc(widget.workDate, picked.hour, picked.minute);
    });
  }

  bool get _canConfirm =>
      _endedAt != null && _reason.text.trim().length >= 3;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final endedAt = _endedAt;
    return AlertDialog(
      title: Text(l10n.manualEndFieldDay),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OutlinedButton.icon(
              onPressed: _pickTime,
              icon: const Icon(Icons.schedule),
              label: Text(
                endedAt == null
                    ? l10n.endTime
                    : '${l10n.endTime}: ${formatPhTime(endedAt)}',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              endedAt == null || widget.suggested == null
                  ? l10n.endTimeRequired
                  : l10n.suggestedEndTime,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _reason,
              decoration: InputDecoration(labelText: l10n.reason),
              minLines: 2,
              maxLines: 4,
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _canConfirm
              ? () => Navigator.pop<EndFieldDayChoice>(context, (
                  endedAt: endedAt!,
                  reason: _reason.text.trim(),
                ))
              : null,
          child: Text(l10n.confirm),
        ),
      ],
    );
  }
}
