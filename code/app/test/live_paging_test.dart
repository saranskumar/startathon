import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:startathon/inputs/surfaces.dart';
import 'package:startathon/model/profile.dart';
import 'package:startathon/model/session.dart';
import 'package:startathon/runtime/discrete_view.dart';

import 'support/harness.dart';

/// Issue #20: Live discrete lists cap visible options, auto-page, slow Floor.
void main() {
  const seats = [
    'Seat 1A',
    'Seat 1B',
    'Seat 1C',
    'Seat 1D',
    'Seat 2A',
    'Seat 2B',
    'Seat 2C',
    'Seat 2D',
  ];

  Widget liveDiscrete(
    TouchMethod method,
    CapabilityProfile profile, {
    List<String> options = seats,
    void Function(int, String)? onResolve,
    void Function(OptionHighlight)? onHighlight,
  }) =>
      harness(
        AppState()..setProfile(profile),
        Scaffold(
          body: DiscreteTaskView(
            profile: profile,
            method: method,
            options: options,
            livePaging: true,
            onRaw: (_) {},
            onHighlight: onHighlight,
            onResolve: onResolve ?? (_, _) {},
          ),
        ),
      );

  group('live paging cap', () {
    testWidgets('Floor switch never dumps the whole seat list', (tester) async {
      usePhoneSurface(tester);
      final profile = ProfilePresets.profileFloor;
      await tester.pumpWidget(liveDiscrete(TouchMethod.switchScan, profile));
      await tester.pump();

      expect(find.text('Seat 1A'), findsOneWidget);
      expect(find.text('Seat 1B'), findsNothing);
      expect(find.text('Seat 2D'), findsNothing);
      expect(tester.takeException(), isNull);
      await teardownTree(tester);
    });

    testWidgets('Profile A buttons respect visibleOptionCount', (tester) async {
      usePhoneSurface(tester);
      final profile = ProfilePresets.profileA;
      await tester.pumpWidget(liveDiscrete(TouchMethod.buttons, profile));
      await tester.pump();

      expect(find.text('Seat 1A'), findsOneWidget);
      expect(profile.visibleOptionCount, 6);
      expect(find.text('Seat 2D'), findsNothing);
      expect(find.text('More options'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await teardownTree(tester);
    });

    testWidgets('offline joystick still shows the full short list',
        (tester) async {
      usePhoneSurface(tester);
      const options = ['Starter', 'Standard', 'Pro', 'Team'];
      await tester.pumpWidget(harness(
        AppState(),
        Scaffold(
          body: DiscreteTaskView(
            profile: ProfilePresets.profileA,
            method: TouchMethod.joystick,
            options: options,
            onRaw: (_) {},
            onResolve: (_, _) {},
          ),
        ),
      ));
      await tester.pump();
      for (final o in options) {
        expect(find.text(o), findsOneWidget);
      }
      expect(find.text('More options'), findsNothing);
      await teardownTree(tester);
    });
  });

  group('auto-advance after a pass', () {
    testWidgets('switch wrap moves to the next page', (tester) async {
      usePhoneSurface(tester);
      final profile = ProfilePresets.profileFloor;
      await tester.pumpWidget(liveDiscrete(TouchMethod.switchScan, profile));
      await tester.pump();
      expect(find.text('Seat 1A'), findsOneWidget);
      expect(find.text('Seat 1B'), findsNothing);

      await tester.pump(profile.scanDwell);
      expect(find.text('Seat 1B'), findsOneWidget);
      expect(find.text('Seat 1A'), findsNothing);
      await teardownTree(tester);
    });

    testWidgets('joystick step past the last item opens the next page',
        (tester) async {
      usePhoneSurface(tester);
      final profile =
          ProfilePresets.profileA.copyWith(inputLevel: InputLevel.two);
      const options = ['A', 'B', 'C', 'D'];
      await tester.pumpWidget(
        liveDiscrete(TouchMethod.joystick, profile, options: options),
      );
      await tester.pump();
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      expect(find.text('C'), findsNothing);

      final pad = find.byType(JoystickPad);
      Future<void> nudgeDown() async {
        final gesture = await tester.startGesture(tester.getCenter(pad));
        await gesture.moveBy(const Offset(0, 60));
        await tester.pump(const Duration(milliseconds: 30));
        await gesture.up();
        await tester.pump();
      }

      await nudgeDown(); // A -> B
      await nudgeDown(); // wrap onto page 2
      expect(find.text('C'), findsOneWidget);
      expect(find.text('D'), findsOneWidget);
      expect(find.text('A'), findsNothing);
      await teardownTree(tester);
    });

    testWidgets('trackpad dwell on the last slot opens the next page',
        (tester) async {
      usePhoneSurface(tester);
      final profile =
          ProfilePresets.profileA.copyWith(inputLevel: InputLevel.two);
      const options = ['A', 'B', 'C', 'D'];
      await tester.pumpWidget(
        liveDiscrete(TouchMethod.trackpad, profile, options: options),
      );
      await tester.pump();
      expect(find.text('C'), findsNothing);

      final pad = find.byType(TrackpadSurface);
      final rect = tester.getRect(pad);
      final gesture =
          await tester.startGesture(rect.centerLeft + const Offset(20, 0));
      await gesture.moveTo(Offset(rect.center.dx, rect.bottom - 4));
      await tester.pump();
      await tester.pump(profile.scanDwell);
      expect(find.text('C'), findsOneWidget);
      expect(find.text('A'), findsNothing);
      await gesture.up();
      await tester.pump();
      await teardownTree(tester);
    });
  });

  group('issue #21 highlight sync', () {
    testWidgets('live switch ticks emit the current page ids', (tester) async {
      usePhoneSurface(tester);
      final hits = <OptionHighlight>[];
      final profile =
          ProfilePresets.profileA.copyWith(inputLevel: InputLevel.two);
      await tester.pumpWidget(liveDiscrete(
        TouchMethod.switchScan,
        profile,
        options: const ['A', 'B', 'C', 'D'],
        onHighlight: hits.add,
      ));
      await tester.pump();
      expect(hits, isNotEmpty);
      expect(hits.last.phase, 'item');
      expect(hits.last.groupIndexes, isNotEmpty);

      await tester.pump(profile.scanDwell);
      expect(hits.last.index, greaterThan(0));
      expect(hits.last.groupIndexes, contains(hits.last.index));
      await teardownTree(tester);
    });

    testWidgets('joystick highlight stays inside the visible page group',
        (tester) async {
      usePhoneSurface(tester);
      final hits = <OptionHighlight>[];
      final profile =
          ProfilePresets.profileA.copyWith(inputLevel: InputLevel.two);
      await tester.pumpWidget(liveDiscrete(
        TouchMethod.joystick,
        profile,
        options: const ['A', 'B', 'C', 'D'],
        onHighlight: hits.add,
      ));
      await tester.pump();
      final pad = find.byType(JoystickPad);
      final gesture = await tester.startGesture(tester.getCenter(pad));
      await gesture.moveBy(const Offset(0, 60));
      await tester.pump(const Duration(milliseconds: 30));
      await gesture.up();
      await tester.pump();
      expect(hits.last.value, 'B');
      expect(hits.last.groupIndexes, [0, 1]);
      await teardownTree(tester);
    });

    testWidgets('buttons paging still emits highlight + group', (tester) async {
      usePhoneSurface(tester);
      final hits = <OptionHighlight>[];
      final profile =
          ProfilePresets.profileA.copyWith(inputLevel: InputLevel.two);
      await tester.pumpWidget(liveDiscrete(
        TouchMethod.buttons,
        profile,
        options: const ['A', 'B', 'C', 'D'],
        onHighlight: hits.add,
      ));
      await tester.pump();
      expect(hits, isNotEmpty);
      expect(hits.last.phase, 'item');
      expect(hits.last.groupIndexes, [0, 1]);
      await teardownTree(tester);
    });

    testWidgets('fill-style list keeps phase and groupIndexes', (tester) async {
      usePhoneSurface(tester);
      final hits = <OptionHighlight>[];
      await tester.pumpWidget(liveDiscrete(
        TouchMethod.trackpad,
        ProfilePresets.profileA,
        options: const ['Window', 'Aisle', 'None'],
        onHighlight: hits.add,
      ));
      await tester.pump();
      expect(hits.last.phase, 'item');
      expect(hits.last.groupIndexes, isNotEmpty);
      expect(hits.last.value, anyOf('Window', 'Aisle', 'None'));
      await teardownTree(tester);
    });

    testWidgets('confirm-style two options emit a highlight', (tester) async {
      usePhoneSurface(tester);
      final hits = <OptionHighlight>[];
      await tester.pumpWidget(liveDiscrete(
        TouchMethod.joystick,
        ProfilePresets.profileA,
        options: const ['Send it', 'Go back'],
        onHighlight: hits.add,
      ));
      await tester.pump();
      expect(hits, isNotEmpty);
      expect(hits.last.phase, 'item');
      expect(hits.last.groupIndexes, [0, 1]);
      await teardownTree(tester);
    });
  });
}
