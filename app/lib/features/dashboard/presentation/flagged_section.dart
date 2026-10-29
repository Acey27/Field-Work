import 'package:flutter/material.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/utils/ph_time.dart';
import '../data/admin_service.dart';
import '../domain/admin_stats.dart';

/// The flagged list with a date range (SPEC.md section 17).
class FlaggedSection extends StatefulWidget {
  const FlaggedSection({required this.service, super.key});

  final AdminService service;

  @override
  State<FlaggedSection> createState() => _FlaggedSectionState();
}

class _FlaggedSectionState extends State<FlaggedSection> {
  late DateTime _from;
  late DateTime _to;
  late Future<List<FlaggedItem>> _items;

  @override
  void initState() {
    super.initState();
    _from = _to = phDateOf(DateTime.now());
    _items = widget.service.flaggedItems(_from, _to);
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
      _items = widget.service.flaggedItems(_from, _to);
    });
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
        FutureBuilder<List<FlaggedItem>>(
          future: _items,
          builder: (context, snapshot) {
            if (snapshot.hasError) return Text(l10n.adminLoadError);
            final items = snapshot.data;
            if (items == null) {
              return const Center(child: CircularProgressIndicator());
            }
            if (items.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(l10n.noFlaggedActivity),
                ),
              );
            }
            return Column(
              children: [for (final item in items) FlaggedTile(item: item)],
            );
          },
        ),
      ],
    );
  }
}

class FlaggedTile extends StatelessWidget {
  const FlaggedTile({required this.item, super.key});

  final FlaggedItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final when =
        '${formatPhDate(phDateOf(item.at))} ${formatPhTime(item.at)}';
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
