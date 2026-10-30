import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fieldwork_attendance/core/utils/refresh_group.dart';
import 'package:fieldwork_attendance/shared/widgets/refresh_button.dart';

void main() {
  Widget host(Future<void> Function() onRefresh) => MaterialApp(
    home: Scaffold(
      appBar: AppBar(
        actions: [RefreshButton(tooltip: 'Refresh', onRefresh: onRefresh)],
      ),
    ),
  );

  AnimationStatus status(WidgetTester tester) => tester
      .widget<RotationTransition>(
        find.descendant(
          of: find.byType(RefreshButton),
          matching: find.byType(RotationTransition),
        ),
      )
      .turns
      .status;

  testWidgets('the icon turns while the page loads and stops after', (
    tester,
  ) async {
    final done = Completer<void>();
    await tester.pumpWidget(host(() => done.future));
    expect(status(tester), AnimationStatus.dismissed);

    await tester.tap(find.byTooltip('Refresh'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(status(tester), AnimationStatus.forward);

    done.complete();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(status(tester), AnimationStatus.dismissed);
  });

  testWidgets('a quick answer still shows the turning for a moment', (
    tester,
  ) async {
    await tester.pumpWidget(host(() async {}));
    await tester.tap(find.byTooltip('Refresh'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(status(tester), AnimationStatus.forward);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(status(tester), AnimationStatus.dismissed);
  });

  testWidgets('a second tap while loading does not start another load', (
    tester,
  ) async {
    var calls = 0;
    final done = Completer<void>();
    await tester.pumpWidget(
      host(() {
        calls++;
        return done.future;
      }),
    );
    await tester.tap(find.byTooltip('Refresh'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byTooltip('Refresh'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(calls, 1);

    done.complete();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
  });

  testWidgets('a failed load ends the turning and can be tried again', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      host(() async {
        calls++;
        throw StateError('offline');
      }),
    );
    await tester.tap(find.byTooltip('Refresh'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(status(tester), AnimationStatus.dismissed);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Refresh'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(calls, 2);
  });

  test('RefreshGroup.run completes when every section is done', () async {
    final group = RefreshGroup();
    final first = Completer<void>();
    var secondDone = false;
    Future<void> firstLoader() => first.future;
    Future<void> secondLoader() async => secondDone = true;
    group
      ..add(firstLoader)
      ..add(secondLoader);

    var finished = false;
    final run = group.run().then((_) => finished = true);
    await Future<void>.delayed(Duration.zero);
    expect(secondDone, isTrue);
    expect(finished, isFalse);

    first.complete();
    await run;
    expect(finished, isTrue);

    // A removed section is no longer waited for.
    group.remove(firstLoader);
    await group.run();
  });
}
