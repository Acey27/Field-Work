import 'package:flutter/material.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/utils/ph_time.dart';
import '../data/admin_service.dart';
import '../domain/admin_stats.dart';

/// Statistics with a Daily / Weekly filter (SPEC.md section 11).
class StatsSection extends StatefulWidget {
  const StatsSection({required this.service, super.key});

  final AdminService service;

  @override
  State<StatsSection> createState() => _StatsSectionState();
}

class _StatsSectionState extends State<StatsSection> {
  bool _weekly = false;
  late DateTime _weekStart;
  late Future<TodayStats> _today;
  late Future<WeekStats> _week;

  @override
  void initState() {
    super.initState();
    _weekStart = phWeekStart(phDateOf(DateTime.now()));
    _today = widget.service.statsToday();
    _week = widget.service.statsWeek(_weekStart);
  }

  void _moveWeek(int weeks) {
    setState(() {
      _weekStart = _weekStart.add(Duration(days: 7 * weeks));
      _week = widget.service.statsWeek(_weekStart);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<bool>(
          segments: [
            ButtonSegment(value: false, label: Text(l10n.daily)),
            ButtonSegment(value: true, label: Text(l10n.weekly)),
          ],
          selected: {_weekly},
          onSelectionChanged: (value) => setState(() => _weekly = value.first),
        ),
        const SizedBox(height: 12),
        if (_weekly) _weekView(l10n) else _todayView(l10n),
      ],
    );
  }

  Widget _todayView(AppLocalizations l10n) {
    return FutureBuilder<TodayStats>(
      future: _today,
      builder: (context, snapshot) {
        if (snapshot.hasError) return Text(l10n.adminLoadError);
        final stats = snapshot.data;
        if (stats == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final cards = [
          (l10n.clockedInNow, stats.clockedInNow, Icons.groups, false),
          (l10n.finishedWorkers, stats.finished, Icons.task_alt, false),
          (
            l10n.techniciansWorking,
            stats.techniciansWorking,
            Icons.badge,
            false,
          ),
          (l10n.fieldsWorking, stats.fieldsWorking, Icons.landscape, false),
          (
            l10n.fieldDaysNotEnded,
            stats.fieldDaysNotEnded,
            Icons.warning_amber,
            stats.fieldDaysNotEnded > 0,
          ),
        ];
        return GridView.count(
          crossAxisCount: MediaQuery.sizeOf(context).width > 700 ? 5 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.4,
          children: [
            for (final card in cards)
              StatCard(
                label: card.$1,
                value: '${card.$2}',
                icon: card.$3,
                attention: card.$4,
              ),
          ],
        );
      },
    );
  }

  Widget _weekView(AppLocalizations l10n) {
    final weekEnd = _weekStart.add(const Duration(days: 6));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: l10n.previousWeek,
              onPressed: () => _moveWeek(-1),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                '${formatPhDate(_weekStart)} – ${formatPhDate(weekEnd)}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              tooltip: l10n.nextWeek,
              onPressed: () => _moveWeek(1),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        FutureBuilder<WeekStats>(
          future: _week,
          builder: (context, snapshot) {
            if (snapshot.hasError) return Text(l10n.adminLoadError);
            final stats = snapshot.data;
            if (stats == null) {
              return const Center(child: CircularProgressIndicator());
            }
            return _weekDetails(l10n, stats);
          },
        ),
      ],
    );
  }

  Widget _weekDetails(AppLocalizations l10n, WeekStats stats) {
    final material = MaterialLocalizations.of(context);
    String dayLabel(DateTime date) =>
        material.narrowWeekdays[date.weekday % 7];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: StatCard(
                label: l10n.thisWeek,
                value: l10n.durationShort(stats.totalMinutes),
                caption: '${l10n.workersWeekTotal}: ${stats.workersPresent}',
                icon: Icons.calendar_view_week,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                label: l10n.lastWeek,
                value: l10n.durationShort(stats.previousTotalMinutes),
                caption:
                    '${l10n.workersWeekTotal}: ${stats.previousWorkersPresent}',
                icon: Icons.history,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          l10n.workersPerDay,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        BarChart(
          bars: [
            for (final day in stats.days)
              BarValue(
                label: dayLabel(day.date),
                value: day.workersPresent,
                text: '${day.workersPresent}',
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text(l10n.hoursPerDay, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        BarChart(
          bars: [
            for (final day in stats.days)
              BarValue(
                label: dayLabel(day.date),
                value: day.totalMinutes,
                text: (day.totalMinutes / 60).toStringAsFixed(1),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          l10n.attendanceByField,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (stats.byField.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(l10n.noTimeRecords),
          ),
        for (final field in stats.byField)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.landscape),
            title: Text(field.fieldName),
            subtitle: Text(
              '${l10n.presentDaysValue(field.presentDays)} · '
              '${l10n.durationShort(field.totalMinutes)}',
            ),
          ),
      ],
    );
  }
}

/// A big number with a label (SPEC.md section 14: big numbers).
class StatCard extends StatelessWidget {
  const StatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.caption,
    this.attention = false,
    super.key,
  });

  final String label;
  final String value;
  final String? caption;
  final IconData icon;

  /// Yellow when there is something the admin should act on.
  final bool attention;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: attention ? colors.secondaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: attention ? colors.secondary : null),
            const Spacer(),
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
            Text(label),
            if (caption != null)
              Text(caption!, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class BarValue {
  const BarValue({required this.label, required this.value, required this.text});
  final String label;
  final int value;
  final String text;
}

/// A simple bar chart with no extra package: one bar per value, tallest bar
/// fills the height, and the number is written above each bar.
class BarChart extends StatelessWidget {
  const BarChart({required this.bars, this.height = 120, super.key});

  final List<BarValue> bars;
  final double height;

  @override
  Widget build(BuildContext context) {
    final maxValue = bars.fold<int>(0, (max, bar) => bar.value > max ? bar.value : max);
    final color = Theme.of(context).colorScheme.primary;
    // The bar area takes whatever height is left after the two text lines,
    // so large text sizes never overflow.
    return SizedBox(
      height: height + 64,
      child: Row(
        children: [
          for (final bar in bars)
            Expanded(
              child: Column(
                children: [
                  Text(bar.text, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 2),
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: bar.value == 0 || maxValue == 0
                          // A thin line so an empty day is still visible.
                          ? Container(
                              key: ValueKey('bar-${bar.label}'),
                              height: 2,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              color: color,
                            )
                          : FractionallySizedBox(
                              heightFactor: bar.value / maxValue,
                              child: Container(
                                key: ValueKey('bar-${bar.label}'),
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(bar.label),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
