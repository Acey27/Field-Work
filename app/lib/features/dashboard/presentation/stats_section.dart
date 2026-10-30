import 'package:flutter/material.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/utils/ph_time.dart';
import '../../../core/utils/refresh_group.dart';
import '../data/admin_service.dart';
import '../domain/admin_stats.dart';

/// Statistics with a Daily / Weekly filter (SPEC.md section 11).
class StatsSection extends StatefulWidget {
  const StatsSection({required this.service, this.refresh, super.key});

  final AdminService service;

  /// The dashboard runs this every few seconds and when the admin taps
  /// refresh. The numbers are fetched again without losing the Daily / Weekly
  /// choice or the week being looked at, and a failed fetch keeps the numbers
  /// already on screen.
  final RefreshGroup? refresh;

  @override
  State<StatsSection> createState() => _StatsSectionState();
}

class _StatsSectionState extends State<StatsSection> {
  bool _weekly = false;
  late DateTime _weekStart;
  TodayStats? _today;
  bool _todayFailed = false;
  WeekStats? _week;
  bool _weekFailed = false;

  /// Only the newest week request may fill the screen (the arrows can be
  /// tapped faster than the server answers).
  int _weekRequest = 0;

  @override
  void initState() {
    super.initState();
    _weekStart = phWeekStart(phDateOf(DateTime.now()));
    widget.refresh?.add(_reload);
    _loadToday();
  }

  @override
  void didUpdateWidget(StatsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refresh != widget.refresh) {
      oldWidget.refresh?.remove(_reload);
      widget.refresh?.add(_reload);
    }
  }

  @override
  void dispose() {
    widget.refresh?.remove(_reload);
    super.dispose();
  }

  Future<void> _reload() =>
      Future.wait([_loadToday(), if (_weekly) _loadWeek()]);

  Future<void> _loadToday() async {
    try {
      final stats = await widget.service.statsToday();
      if (mounted) {
        setState(() {
          _today = stats;
          _todayFailed = false;
        });
      }
    } on Object {
      if (mounted && _today == null) setState(() => _todayFailed = true);
    }
  }

  /// [clear] forgets the week on screen first (the admin moved to another
  /// week); without it the old numbers stay until the new ones arrive.
  Future<void> _loadWeek({bool clear = false}) async {
    final request = ++_weekRequest;
    if (clear) {
      setState(() {
        _week = null;
        _weekFailed = false;
      });
    }
    try {
      final stats = await widget.service.statsWeek(_weekStart);
      if (mounted && request == _weekRequest) {
        setState(() {
          _week = stats;
          _weekFailed = false;
        });
      }
    } on Object {
      if (mounted && request == _weekRequest && _week == null) {
        setState(() => _weekFailed = true);
      }
    }
  }

  void _moveWeek(int weeks) {
    setState(() => _weekStart = _weekStart.add(Duration(days: 7 * weeks)));
    _loadWeek(clear: true);
  }

  void _showWeekly(bool weekly) {
    setState(() => _weekly = weekly);
    if (weekly) _loadWeek();
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
          onSelectionChanged: (value) => _showWeekly(value.first),
        ),
        const SizedBox(height: 12),
        if (_weekly) _weekView(l10n) else _todayView(l10n),
      ],
    );
  }

  Widget _todayView(AppLocalizations l10n) {
    final stats = _today;
    if (stats == null) {
      return _todayFailed
          ? Text(l10n.adminLoadError)
          : const Center(child: CircularProgressIndicator());
    }
    final cards = [
      (l10n.clockedInNow, stats.clockedInNow, Icons.groups, false),
      (l10n.finishedWorkers, stats.finished, Icons.task_alt, false),
      (l10n.techniciansWorking, stats.techniciansWorking, Icons.badge, false),
      (l10n.fieldsWorking, stats.fieldsWorking, Icons.landscape, false),
      (
        l10n.fieldDaysNotEnded,
        stats.fieldDaysNotEnded,
        Icons.warning_amber,
        stats.fieldDaysNotEnded > 0,
      ),
    ];
    return StatGrid(
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
        if (_week != null)
          _weekDetails(l10n, _week!)
        else if (_weekFailed)
          Text(l10n.adminLoadError)
        else
          const Center(child: CircularProgressIndicator()),
      ],
    );
  }

  Widget _weekDetails(AppLocalizations l10n, WeekStats stats) {
    final material = MaterialLocalizations.of(context);
    String dayLabel(DateTime date) => material.narrowWeekdays[date.weekday % 7];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StatGrid(
          children: [
            StatCard(
              label: l10n.thisWeek,
              value: l10n.durationShort(stats.totalMinutes),
              caption: '${l10n.workersWeekTotal}: ${stats.workersPresent}',
              icon: Icons.calendar_view_week,
            ),
            StatCard(
              label: l10n.lastWeek,
              value: l10n.durationShort(stats.previousTotalMinutes),
              caption:
                  '${l10n.workersWeekTotal}: ${stats.previousWorkersPresent}',
              icon: Icons.history,
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

/// Cards in rows of equal width. Each row is as tall as its tallest card, so a
/// label that wraps to three lines (a narrow window, large text, Filipino)
/// never overflows; a fixed tile height cannot promise that.
class StatGrid extends StatelessWidget {
  const StatGrid({required this.children, super.key});

  final List<Widget> children;

  static const _spacing = 12.0;

  /// A card is never narrower than this, so its label has room to wrap.
  static const _minCardWidth = 150.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns =
            ((constraints.maxWidth + _spacing) / (_minCardWidth + _spacing))
                .floor()
                .clamp(1, children.length);
        return Column(
          children: [
            for (var start = 0; start < children.length; start += columns)
              Padding(
                padding: EdgeInsets.only(top: start == 0 ? 0 : _spacing),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < columns; i++) ...[
                        if (i > 0) const SizedBox(width: _spacing),
                        Expanded(
                          child: start + i < children.length
                              ? children[start + i]
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        );
      },
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
        // No Spacer: the dashboard scrolls, so a card can get unbounded
        // height, and a Spacer there cannot be laid out (a blank page).
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: attention ? colors.secondary : null),
            const SizedBox(height: 12),
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
  const BarValue({
    required this.label,
    required this.value,
    required this.text,
  });
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
    final maxValue = bars.fold<int>(
      0,
      (max, bar) => bar.value > max ? bar.value : max,
    );
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
