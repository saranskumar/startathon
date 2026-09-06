import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:startathon/calibration/hold_fill.dart';
import 'package:startathon/calibration/touch_steps.dart';
import 'package:startathon/calibration/step_frame.dart';
import 'package:startathon/inputs/surfaces.dart';
import 'package:startathon/inputs/voice.dart';
import 'package:startathon/model/profile.dart';
import 'package:startathon/model/session.dart';
import 'package:startathon/runtime/continuous_view.dart';
import 'package:startathon/runtime/demo_screen.dart';
import 'package:startathon/runtime/discrete_view.dart';
import 'package:startathon/runtime/pointing_view.dart';
import 'package:startathon/runtime/preview_screen.dart';
import 'package:startathon/runtime/task_spec.dart';
import 'package:startathon/runtime/text_view.dart';

import 'support/harness.dart';

/// Every interaction pattern in 3.3, driven the way a finger would drive it.
void main() {
  const options = ['Starter', 'Standard', 'Pro', 'Team'];

  Widget discrete(
    AppState state,
    TouchMethod method,
    void Function(int, String) onResolve, {
    CapabilityProfile? profile,
  }) =>
      harness(
        state,
        Scaffold(
          body: DiscreteTaskView(
            profile: profile ?? ProfilePresets.profileA,
            method: method,
            options: options,
            onRaw: (_) {},
            onResolve: onResolve,
          ),
        ),
      );

  group('discrete choice', () {
    testWidgets('buttons: a direct tap resolves that option', (tester) async {
      usePhoneSurface(tester);
      int? index;
      await tester.pumpWidget(
        discrete(AppState(), TouchMethod.buttons, (i, _) => index = i),
      );
      await tester.tap(find.text('Pro'));
      await tester.pump();
      expect(index, 2);
    });

    testWidgets('buttons: only maxControls options are shown at once',
        (tester) async {
      usePhoneSurface(tester);
      final tight = ProfilePresets.profileFloor; // maxControls == 4 -> 2 here
      await tester.pumpWidget(
        discrete(AppState(), TouchMethod.buttons, (_, _) {},
            profile: tight.copyWith(
              methodScores: {
                for (final m in TouchMethod.values)
                  m: const MethodScore(
                      successRate: 0.2,
                      timeNormalized: 0.9,
                      errorNormalized: 0.9,
                      attempts: 4),
              },
            )),
      );
      expect(find.text('Starter'), findsOneWidget);
      expect(find.text('Pro'), findsNothing);
      expect(find.text('More options'), findsOneWidget);
    });

    testWidgets('joystick: pushing down moves the highlight, press confirms',
        (tester) async {
      usePhoneSurface(tester);
      int? index;
      await tester.pumpWidget(
        discrete(AppState(), TouchMethod.joystick, (i, _) => index = i),
      );

      final pad = find.byType(JoystickPad);
      expect(pad, findsOneWidget);

      final gesture = await tester.startGesture(tester.getCenter(pad));
      await gesture.moveBy(const Offset(0, 60));
      await tester.pump(const Duration(milliseconds: 30));
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 30));

      // One step down from 'Starter' is 'Standard'.
      await tester.tap(pad);
      await tester.pump();
      expect(index, 1);
    });

    testWidgets('trackpad: dragging hovers, releasing selects', (tester) async {
      usePhoneSurface(tester);
      int? index;
      await tester.pumpWidget(
        discrete(AppState(), TouchMethod.trackpad, (i, _) => index = i),
      );

      final pad = find.byType(TrackpadSurface);
      final rect = tester.getRect(pad);
      final gesture = await tester.startGesture(rect.centerLeft + const Offset(20, 0));
      // Drag most of the way down the pad -> the last option.
      await gesture.moveTo(Offset(rect.center.dx, rect.bottom - 4));
      await tester.pump(const Duration(milliseconds: 20));
      await gesture.up();
      await tester.pump();
      expect(index, options.length - 1);
    });

    testWidgets('switch scan: row-then-column, two presses to select',
        (tester) async {
      usePhoneSurface(tester);
      int? index;
      await tester.pumpWidget(
        discrete(AppState(), TouchMethod.switchScan, (i, _) => index = i,
            profile: ProfilePresets.profileFloor),
      );

      // 4 options -> a 2x2 grid. First press locks whichever row the scan
      // has dwelt on, it does not select yet.
      await tester.pump(const Duration(milliseconds: 3600));
      await tester.tap(find.byType(SwitchTrigger));
      await tester.pump();
      expect(index, isNull, reason: 'first press only locks the row in a 2x2 grid');

      // Column phase, then the second press actually selects.
      await tester.pump(const Duration(milliseconds: 3600));
      await tester.tap(find.byType(SwitchTrigger));
      await tester.pump();
      expect(index, isNotNull);
      expect(index, inInclusiveRange(0, options.length - 1));
      await teardownTree(tester);
    });

    testWidgets('long option labels stay readable, not clipped to Se',
        (tester) async {
      usePhoneSurface(tester);
      const seats = ['Seat 12 Window', 'Seat 12 Aisle', 'Seat 14 Window'];
      await tester.pumpWidget(harness(
        AppState(),
        Scaffold(
          body: DiscreteTaskView(
            profile: ProfilePresets.profileA,
            method: TouchMethod.buttons,
            options: seats,
            livePaging: true,
            onRaw: (_) {},
            onResolve: (_, _) {},
          ),
        ),
      ));
      await tester.pump();
      expect(find.text('Seat 12 Window'), findsOneWidget);
      expect(find.text('Se'), findsNothing);
      await teardownTree(tester);
    });

    testWidgets('joystick highlight paints the current option', (tester) async {
      usePhoneSurface(tester);
      final hits = <OptionHighlight>[];
      await tester.pumpWidget(harness(
        AppState(),
        Scaffold(
          body: DiscreteTaskView(
            profile: ProfilePresets.profileA,
            method: TouchMethod.joystick,
            options: options,
            onRaw: (_) {},
            onHighlight: hits.add,
            onResolve: (_, _) {},
          ),
        ),
      ));
      await tester.pump();
      expect(hits, isNotEmpty);
      expect(hits.last.value, 'Starter');
      expect(find.text('Starter'), findsWidgets);
      await teardownTree(tester);
    });
  });

  group('continuous adjust', () {
    Widget continuous(TouchMethod method, void Function(int) onResolve,
            {CapabilityProfile? profile}) =>
        harness(
          AppState(),
          Scaffold(
            body: ContinuousTaskView(
              profile: profile ?? ProfilePresets.profileA,
              method: method,
              spec: DemoTasks.setQuantity,
              onRaw: (_) {},
              onResolve: onResolve,
            ),
          ),
        );

    testWidgets('buttons: the stepper moves one unit per press',
        (tester) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(continuous(TouchMethod.buttons, (_) {}));
      expect(find.text('26'), findsOneWidget); // midpoint of 1..50

      await tester.tap(find.text('+'));
      await tester.pump();
      expect(find.text('27'), findsOneWidget);

      await tester.tap(find.text('-'));
      await tester.pump();
      expect(find.text('26'), findsOneWidget);
    });

    testWidgets('joystick: holding up keeps increasing the value',
        (tester) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(continuous(TouchMethod.joystick, (_) {}));

      final pad = find.byType(JoystickPad);
      final gesture = await tester.startGesture(tester.getCenter(pad));
      await gesture.moveBy(const Offset(0, -70));
      await tester.pump(const Duration(milliseconds: 400));
      await gesture.up();
      await tester.pump();

      expect(find.text('26'), findsNothing, reason: 'value should have moved');
      await teardownTree(tester);
    });

    testWidgets('buttons: confirm resolves with the current value',
        (tester) async {
      usePhoneSurface(tester);
      int? value;
      await tester.pumpWidget(continuous(TouchMethod.buttons, (v) => value = v));
      await tester.tap(find.textContaining('Confirm'));
      await tester.pump();
      expect(value, 26);
    });
  });

  group('free pointing', () {
    testWidgets('buttons: three narrowing steps place the marker',
        (tester) async {
      usePhoneSurface(tester);
      Offset? placed;
      await tester.pumpWidget(harness(
        AppState(),
        Scaffold(
          body: PointingTaskView(
            profile: ProfilePresets.profileB,
            method: TouchMethod.buttons,
            goal: const Offset(0.72, 0.34),
            onRaw: (_) {},
            onResolve: (p, _) => placed = p,
          ),
        ),
      ));

      for (var i = 0; i < 3; i++) {
        expect(placed, isNull);
        await tester.tap(find.text('top right'));
        await tester.pump();
      }
      expect(placed, isNotNull);
      // Three top-right picks land in the top-right eighth of the field.
      expect(placed!.dx, greaterThan(0.8));
      expect(placed!.dy, lessThan(0.2));
    });

    testWidgets('trackpad: release places the marker where the drag ended',
        (tester) async {
      usePhoneSurface(tester);
      Offset? placed;
      await tester.pumpWidget(harness(
        AppState(),
        Scaffold(
          body: PointingTaskView(
            profile: ProfilePresets.profileA,
            method: TouchMethod.trackpad,
            goal: const Offset(0.5, 0.5),
            onRaw: (_) {},
            onResolve: (p, _) => placed = p,
          ),
        ),
      ));

      final rect = tester.getRect(find.byType(TrackpadSurface));
      final gesture = await tester.startGesture(rect.center);
      await gesture.moveTo(Offset(rect.left + rect.width * 0.25, rect.center.dy));
      await tester.pump(const Duration(milliseconds: 20));
      await gesture.up();
      await tester.pump();

      expect(placed, isNotNull);
      expect(placed!.dx, closeTo(0.25, 0.06));
    });
  });

  group('voice fusion (Thesis B)', () {
    testWidgets('sounds tier: two sounds cycle, one sound accepts',
        (tester) async {
      usePhoneSurface(tester);
      String? resolved;
      await tester.pumpWidget(harness(
        AppState(),
        Scaffold(
          body: TextTaskView(
            profile: ProfilePresets.profileFloor, // clarity: sounds
            method: TouchMethod.switchScan,
            fieldLabel: 'Delivery note',
            onRaw: (_) {},
            onNote: (_) {},
            onResolve: (t) => resolved = t,
          ),
        ),
      ));

      expect(find.text('Leave it at the front desk'), findsOneWidget);

      // Two sounds inside one utterance window -> next suggestion.
      final mic = find.byType(HoldToSpeak);
      await tester.tap(mic);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(mic);
      await tester.pump(const Duration(milliseconds: 1200));
      expect(find.text('Ring the bell twice'), findsOneWidget);

      // One sound -> accept, which moves to the confirmation gate.
      await tester.tap(mic);
      await tester.pump(const Duration(milliseconds: 1200));
      expect(find.textContaining('Put this in'), findsOneWidget);
      expect(resolved, isNull, reason: 'nothing is entered before confirming');

      // Confirming uses the same input method as everything else.
      await tester.pump(const Duration(milliseconds: 2000));
      await tester.tap(find.byType(SwitchTrigger));
      await tester.pump();
      await teardownTree(tester);
    });

    testWidgets('dictation is confirmed before it becomes the value',
        (tester) async {
      usePhoneSurface(tester);
      String? resolved;
      await tester.pumpWidget(harness(
        AppState(),
        Scaffold(
          body: TextTaskView(
            profile: ProfilePresets.profileA, // clarity: full
            method: TouchMethod.buttons,
            fieldLabel: 'Delivery note',
            onRaw: (_) {},
            onNote: (_) {},
            onResolve: (t) => resolved = t,
          ),
        ),
      ));

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(HoldToSpeak)),
      );
      // HoldToSpeak times the hold with a real Stopwatch, which fake test time
      // does not advance -- so this one wait has to happen in real time.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 600)),
      );
      await gesture.up();
      // Settle window, then the stub recogniser's latency.
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pump(const Duration(milliseconds: 1500));

      expect(find.textContaining('Put this in'), findsOneWidget);
      expect(resolved, isNull);

      await tester.tap(find.text('Yes, use this'));
      await tester.pump();
      expect(resolved, isNotNull);
    });

    testWidgets('trackpad/switch preset picks phrases by touch, not dictation',
        (tester) async {
      usePhoneSurface(tester);
      String? resolved;
      await tester.pumpWidget(harness(
        AppState(),
        Scaffold(
          body: TextTaskView(
            profile: ProfilePresets.profileTrackpadSwitch,
            method: TouchMethod.trackpad,
            fieldLabel: 'Delivery note',
            onRaw: (_) {},
            onNote: (_) {},
            onResolve: (t) => resolved = t,
          ),
        ),
      ));

      expect(find.byType(HoldToSpeak), findsNothing);
      expect(find.byType(TrackpadSurface), findsOneWidget);
      expect(find.text('Leave it at the front desk'), findsWidgets);
      expect(resolved, isNull);
      await teardownTree(tester);
    });
  });

  group('calibration', () {
    testWidgets('reach: tapping a cell records it as reachable',
        (tester) async {
      usePhoneSurface(tester);
      final draft = CalibrationDraft();
      await tester.pumpWidget(harness(
        AppState(),
        Scaffold(
          body: ReachStep(
            draft: draft,
            index: 0,
            total: 7,
            onNext: () {},
            onSkip: () {},
          ),
        ),
      ));

      await tester.tapAt(const Offset(60, 500));
      await tester.pump();
      // A single tap is tentative only -- the draft isn't committed until
      // the step ends (overall timer), not on every tap.
      expect(draft.reachableCells, isEmpty);
      await tester.pump(const Duration(seconds: 2, milliseconds: 100));
      expect(draft.reachableCells, isEmpty,
          reason: '2s idle must not end the step while the 10s timer remains');
      await tester.pump(const Duration(seconds: 10));
      expect(draft.reachableCells, isNotEmpty);
      expect(draft.lockedCells, isEmpty); // one tap = tentative, not locked
      await teardownTree(tester);
    });

    testWidgets('reach: tapping a cell twice locks it in as confirmed',
        (tester) async {
      usePhoneSurface(tester);
      final draft = CalibrationDraft();
      await tester.pumpWidget(harness(
        AppState(),
        Scaffold(
          body: ReachStep(
            draft: draft,
            index: 0,
            total: 7,
            onNext: () {},
            onSkip: () {},
          ),
        ),
      ));

      await tester.tapAt(const Offset(60, 500));
      await tester.pump();
      await tester.tapAt(const Offset(60, 500));
      await tester.pump();
      await tester.pump(const Duration(seconds: 11));
      expect(draft.reachableCells, isNotEmpty);
      expect(draft.lockedCells, isNotEmpty);
      await teardownTree(tester);
    });

    testWidgets('reach: locking every cell starts the moving-on countdown',
        (tester) async {
      usePhoneSurface(tester);
      final draft = CalibrationDraft();
      var nextCalled = 0;
      await tester.pumpWidget(harness(
        AppState(),
        Scaffold(
          body: ReachStep(
            draft: draft,
            index: 0,
            total: 7,
            onNext: () => nextCalled++,
            onSkip: () {},
          ),
        ),
      ));

      for (var n = 1; n <= CapabilityProfile.reachCellCount; n++) {
        await tester.tap(find.text('$n'));
        await tester.pump();
        await tester.tap(find.text('$n'));
        await tester.pump();
      }
      expect(find.textContaining('Locked. Next input method'), findsOneWidget);
      expect(nextCalled, 0);
      await tester.pump(const Duration(seconds: 4));
      expect(nextCalled, 1);
      expect(draft.lockedCells, hasLength(CapabilityProfile.reachCellCount));
      await teardownTree(tester);
    });

    testWidgets('buttons: a miss does not end the round before the timer',
        (tester) async {
      usePhoneSurface(tester);
      final draft = CalibrationDraft();
      var nextCalled = 0;
      await tester.pumpWidget(harness(
        AppState(),
        Scaffold(
          body: ButtonsStep(
            draft: draft,
            index: 1,
            total: 7,
            onNext: () => nextCalled++,
            onSkip: () {},
          ),
        ),
      ));

      expect(find.text('140'), findsOneWidget);
      await tester.tapAt(const Offset(24, 280));
      await tester.pump();
      expect(find.text('140'), findsOneWidget);
      expect(find.text('104'), findsNothing);

      await tester.tap(find.text('140'));
      await tester.pump();
      expect(find.text('104'), findsOneWidget);
      expect(nextCalled, 0);
      await teardownTree(tester);
    });

    testWidgets('buttons: last round shows locked countdown before onNext',
        (tester) async {
      usePhoneSurface(tester);
      final draft = CalibrationDraft();
      var nextCalled = 0;
      await tester.pumpWidget(harness(
        AppState(),
        Scaffold(
          body: ButtonsStep(
            draft: draft,
            index: 1,
            total: 7,
            onNext: () => nextCalled++,
            onSkip: () {},
          ),
        ),
      ));

      for (final label in ['140', '104', '76', '54']) {
        await tester.tap(find.text(label));
        await tester.pump();
      }
      expect(find.textContaining('Locked. Next input method'), findsOneWidget);
      expect(nextCalled, 0);
      await tester.pump(const Duration(seconds: 4));
      expect(nextCalled, 1);
      await teardownTree(tester);
    });

    testWidgets(
        'hold: runs once per tappable button, records per-button holdable',
        (tester) async {
      usePhoneSurface(tester);
      final draft = CalibrationDraft();
      draft.tappableButtons.addAll([
        ButtonTarget(cell: 0, size: 100, placement: const Alignment(-0.5, -0.5)),
        ButtonTarget(cell: 1, size: 100, placement: const Alignment(0.5, 0.5)),
      ]);
      var nextCalled = 0;
      await tester.pumpWidget(harness(
        AppState(),
        Scaffold(
          body: HoldStep(
            draft: draft,
            index: 2,
            total: 7,
            onNext: () => nextCalled++,
            onSkip: () {},
          ),
        ),
      ));

      expect(find.text('100'), findsNWidgets(2));

      // First button: hold long enough to succeed.
      final gesture1 = await tester.startGesture(
        tester.getCenter(find.byType(HoldFill)),
      );
      await tester.pump(const Duration(milliseconds: 1600));
      await gesture1.up();
      await tester.pump();
      expect(draft.tappableButtons[0].holdable, isTrue);

      // Second (and last) button: release early, then let the round's own
      // timeout resolve it as a miss rather than hanging.
      final gesture2 = await tester.startGesture(
        tester.getCenter(find.byType(HoldFill)),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await gesture2.up();
      await tester.pump(const Duration(seconds: 7, milliseconds: 500));

      expect(draft.tappableButtons[1].holdable, isFalse);
      expect(nextCalled, 0); // locked countdown still running
      expect(find.textContaining('Locked. Next input method'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      expect(nextCalled, 1);
      expect(draft.holdCapable, isTrue); // any(true) across the two buttons
      await teardownTree(tester);
    });

    testWidgets('hold: round timer does not fail a hold in progress',
        (tester) async {
      usePhoneSurface(tester);
      final draft = CalibrationDraft();
      draft.tappableButtons.add(
        ButtonTarget(cell: 0, size: 100, placement: Alignment.center),
      );
      var nextCalled = 0;
      await tester.pumpWidget(harness(
        AppState(),
        Scaffold(
          body: HoldStep(
            draft: draft,
            index: 2,
            total: 7,
            onNext: () => nextCalled++,
            onSkip: () {},
          ),
        ),
      ));

      await tester.pump(const Duration(seconds: 6));
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(HoldFill)),
      );
      await tester.pump(const Duration(milliseconds: 1600));
      await gesture.up();
      await tester.pump();
      expect(draft.tappableButtons[0].holdable, isTrue);
      expect(nextCalled, 0);
      await tester.pump(const Duration(seconds: 4));
      expect(nextCalled, 1);
      await teardownTree(tester);
    });

    testWidgets('every step offers a skip, so no test can trap the user',
        (tester) async {
      usePhoneSurface(tester);
      final draft = CalibrationDraft();
      var skipped = false;
      await tester.pumpWidget(harness(
        AppState(),
        Scaffold(
          body: ButtonsStep(
            draft: draft,
            index: 1,
            total: 7,
            onNext: () {},
            onSkip: () => skipped = true,
          ),
        ),
      ));

      await tester.tap(find.text('Skip this test'));
      await tester.pump();
      expect(skipped, isTrue);
      expect(draft.skipped, contains('buttons'));
      await teardownTree(tester);
    });
  });

  group('runtime wiring', () {
    testWidgets('after a profile is chosen, controllers and the top strip show',
        (tester) async {
      usePhoneSurface(tester);
      final state = AppState()..setProfile(ProfilePresets.profileB);
      await tester.pumpWidget(
        harness(
          state,
          InputPreviewScreen(onContinue: () {}, onRecalibrate: () {}),
        ),
      );
      await tester.pump();

      expect(find.text('Your controllers'), findsOneWidget);
      expect(find.byType(JoystickPad), findsOneWidget);
      expect(find.textContaining('profile loaded'), findsOneWidget);
      expect(
        tester.getTopLeft(find.textContaining('profile loaded')).dy,
        lessThan(80),
      );

      await tester.tap(find.text('Buttons'));
      await tester.pump();
      await tester.ensureVisible(find.text('Option A'));
      await tester.pump();
      await tester.tap(find.text('Option A'));
      await tester.pump();
      expect(state.latest!.text, contains('preview tap = Option A'));
      await teardownTree(tester);
    });

    testWidgets('profile B falls back to the joystick for a discrete task',
        (tester) async {
      usePhoneSurface(tester);
      final state = AppState()..setProfile(ProfilePresets.profileB);
      await tester.pumpWidget(
        harness(state, DemoScreen(onRecalibrate: () {})),
      );
      await tester.pump();

      expect(find.byType(JoystickPad), findsOneWidget);
      expect(find.textContaining('fallback'), findsWidgets);
      await teardownTree(tester);
    });

    testWidgets('profile A uses buttons and logs the intent to the strip',
        (tester) async {
      usePhoneSurface(tester);
      final state = AppState()..setProfile(ProfilePresets.profileA);
      await tester.pumpWidget(
        harness(state, DemoScreen(onRecalibrate: () {})),
      );
      await tester.pump();

      expect(find.byType(JoystickPad), findsNothing);
      await tester.tap(find.text('Standard'));
      await tester.pump();

      expect(state.latest, isNotNull);
      expect(state.latest!.text, contains('pick-plan = Standard'));
      expect(find.textContaining('pick-plan = Standard'), findsOneWidget);
      await teardownTree(tester);
    });

    testWidgets('the output strip sits opposite the reachable zone',
        (tester) async {
      usePhoneSurface(tester);
      // Profile B reaches the lower-left, so output belongs at the top.
      final state = AppState()..setProfile(ProfilePresets.profileB);
      await tester.pumpWidget(
        harness(state, DemoScreen(onRecalibrate: () {})),
      );
      await tester.pump();

      final stripTop = tester.getTopLeft(find.textContaining('profile loaded'));
      expect(stripTop.dy, lessThan(100));
      await teardownTree(tester);
    });

    testWidgets('sending is gated behind an explicit confirmation',
        (tester) async {
      usePhoneSurface(tester);
      final state = AppState()..setProfile(ProfilePresets.profileA);
      await tester.pumpWidget(
        harness(state, DemoScreen(onRecalibrate: () {})),
      );
      await tester.pump();

      // 1. discrete
      await tester.tap(find.text('Standard'));
      await tester.pump();
      // 2. continuous
      await tester.tap(find.textContaining('Confirm'));
      await tester.pump();
      // 3. pointing (trackpad for profile A)
      final rect = tester.getRect(find.byType(TrackpadSurface));
      final gesture = await tester.startGesture(rect.center);
      await gesture.moveBy(const Offset(40, 40));
      await tester.pump(const Duration(milliseconds: 20));
      await gesture.up();
      await tester.pump();
      // 4. text
      final mic = await tester.startGesture(
        tester.getCenter(find.byType(HoldToSpeak)),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 600)),
      );
      await mic.up();
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.tap(find.text('Yes, use this'));
      await tester.pump();

      // Review: nothing has been "sent" yet.
      expect(find.textContaining('About to send'), findsOneWidget);
      expect(state.events.any((e) => e.kind == 'SENT'), isFalse);

      await tester.tap(find.text('Send it'));
      await tester.pump();
      expect(state.events.any((e) => e.kind == 'SENT' && e.consequential),
          isTrue);
      await teardownTree(tester);
    });
  });
}
