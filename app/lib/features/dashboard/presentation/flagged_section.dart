import 'package:flutter/material.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/utils/ph_time.dart';
import '../../../core/utils/refresh_group.dart';
import '../data/admin_service.dart';
import '../domain/admin_stats.dart';

/// The flagged list with a date range (SPEC.md section 17).
class FlaggedSection extends StatefulWidget {
  const FlaggedSection({required this.service, this.refresh, super.key});

  final AdminService service;

  /// The dashboard runs this every few seconds and when the admin taps
  /// refresh; the list is fetched again for the same dates, and a failed fetch
  /// keeps the list already on screen.
  final RefreshGroup? refresh;

  @override
  State<FlaggedSection> createState() => _FlaggedSectionState();
}

class _FlaggedSectionState extends State<FlaggedSection> {
  late DateTime _from;
  late DateTime _to;
  List<FlaggedItem>? _items;
  bool _failed = false;

  /// Only the newest request may fill the screen (the dates can change faster
  /// than the server answers).
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _from = _to = phDateOf(DateTime.now());
    widget.refresh?.add(_load);
    _load();
  }

  @override
  void didUpdateWidget(FlaggedSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refresh != widget.refresh) {
      oldWidget.refresh?.remove(_load);
      widget.refresh?.add(_load);
    }
  }

  @override
  void dispose() {
    widget.refresh?.remove(_load);
    super.dispose();
  }

  /// [clear] forgets the list on screen first (other dates were picked).
  Future<void> _load({bool clear = false}) async {
    final request = ++_request;
    if (clear) {
      setState(() {
        _items = null;
        _failed = false;
      });
    }
    try {
      final items = await widget.service.flaggedItems(_from, _to);
      if (mounted && request == _request) {
        setState(() {
          _items = items;
          _failed = false;
        });
      }
    } on Object {
      if (mounted && request == _request && _items == null) {
        setState(() => _failed = true);
      }
    }
  }

  Future<void> _pick({required bool isFrom}) async {
    final current = isFrom ? _from : _to;
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(current.year, current.month, current.day),
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null) return;
    final date = DateTime.utc(picked.year, picked.month, picked.day);
    setState(() {
      if (isFrom) {
        _from = date;
        if (_to.isBefore(_from)) _to = _from;
      } else {
        _to = date;
        if (_from.isAfter(_to)) _from = _to;
      }
    });
    _load(clear: true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pick(isFrom: true),
                icon: const Icon(Icons.calendar_today),
                label: Text('${l10n.flaggedFrom}: ${formatPhDate(_from)}'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pick(isFrom: false),
                icon: const Icon(Icons.calendar_today),
                label: Text('${l10n.flaggedTo}: ${formatPhDate(_to)}'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ..._list(l10n),
      ],
    );
  }

  List<Widget> _list(AppLocalizations l10n) {
    final items = _items;
    if (items == null) {
      return [
        if (_failed)
          Text(l10n.adminLoadError)
        else
          const Center(child: CircularProgressIndicator()),
      ];
    }
    if (items.isEmpty) {
      return [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(l10n.noFlaggedActivity),
          ),
        ),
      ];
    }
    return [for (final item in items) FlaggedTile(item: item)];
  }
}

class FlaggedTile extends StatelessWidget {
  const FlaggedTile({required this.item, super.key});

  final FlaggedItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final when = '${formatPhDate(phDateOf(item.at))} ${formatPhTime(item.at)}';
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: ListTile(
        leading: const Icon(Icons.flag),
        title: Text(l10n.flagLabel(item.kind)),
        subtitle: Text(
          '${item.worker} · ${item.technician} (${item.technicianCode})\n'
          '${item.fieldName} · $when',
        ),
        isThreeLine: true,
      ),
    );
  }
}
