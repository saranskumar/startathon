@Tags(['golden'])
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:startathon/calibration/calibration_flow.dart';
import 'package:startathon/calibration/results.dart';
import 'package:startathon/calibration/sense_steps.dart';
import 'package:startathon/calibration/step_frame.dart';
import 'package:startathon/calibration/touch_steps.dart';
import 'package:startathon/model/profile.dart';
import 'package:startathon/model/session.dart';
import 'package:startathon/runtime/demo_screen.dart';
import 'package:startathon/runtime/preview_screen.dart';
import 'package:startathon/runtime/pointing_view.dart';
import 'package:startathon/main.dart';
import 'package:startathon/playground/playground_screen.dart';
import 'package:startathon/runtime/text_view.dart';

import 'support/harness.dart';

/// Renders every screen to a PNG under test/goldens/ so the interface can be
/// reviewed without a device. Run with:
///
///   flutter test --update-goldens test/golden_screens_test.dart
///
/// These are documentation shots rather than strict regression goldens -- they
/// are regenerated on purpose whenever the UI changes.
void main() {
  setUpAll(loadRealFonts);

  Future<void> shoot(WidgetTester tester, String name) async {
    await tester.pump(const Duration(milliseconds: 250));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/$name.png'),
    );
  }

  CalibrationDraft filledDraft() {
    final d = CalibrationDraft();
    d.scores[TouchMethod.buttons] = const MethodScore(
        successRate: 0.5, timeNormalized: 0.7, errorNormalized: 0.6,
        attempts: 4);
    d.scores[TouchMethod.joystick] = const MethodScore(
        successRate: 1, timeNormalized: 0.4, errorNormalized: 0.3, attempts: 4);
    d.scores[TouchMethod.trackpad] = const MethodScore(
        successRate: 0.66, timeNormalized: 0.6, errorNormalized: 0.5,
        attempts: 3);
    d.reachableCells.addAll({3, 6, 7, 9, 10});
    d.minTargetSize = 104;
    d.steadiness = 0.42;
    d.holdCapable = true;
    d.clarity = SpeechClarity.partial;
    d.vision = VisionMode.large;
    d.axisLock = Axis.vertical;
    d.skipped.add('switch scan');
    return d;
  }

  testWidgets('home', (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(const AccessLayerAppForTest());
    await shoot(tester, '01-home');
  });

  testWidgets('calibration flow screens', (tester) async {
    usePhoneSurface(tester);
    final state = AppState();
    final draft = CalibrationDraft();

    await tester.pumpWidget(
      harness(state, Scaffold(body: SafeArea(child: CalibrationFlow(onComplete: (_) {})))),
    );
    await shoot(tester, '02-calibration-intro');
    await teardownTree(tester);

    Future<void> step(Widget w, String name) async {
      await tester.pumpWidget(harness(state, Scaffold(body: SafeArea(child: w))));
      await shoot(tester, name);
      await teardownTree(tester);
    }

    await step(
      ReachStep(draft: draft, index: 0, total: 7, onNext: () {}, onSkip: () {}),
      '03-reach',
    );
    await step(
      ButtonsStep(
          draft: draft, index: 1, total: 7, onNext: () {}, onSkip: () {}),
      '04-buttons',
    );
    await step(
      HoldStep(
        draft: CalibrationDraft()
          ..tappableButtons.addAll([
            ButtonTarget(
              cell: 9,
              size: 104,
              placement: const Alignment(-0.4, 0.35),
            ),
            ButtonTarget(
              cell: 11,
              size: 76,
              placement: const Alignment(0.45, 0.55),
            ),
          ]),
        index: 2,
        total: 7,
        onNext: () {},
        onSkip: () {},
      ),
      '05-hold',
    );
    await step(
      JoystickStep(
          draft: draft, index: 3, total: 7, onNext: () {}, onSkip: () {}),
      '06-joystick',
    );
    await step(
      TrackpadStep(
          draft: draft, index: 4, total: 7, onNext: () {}, onSkip: () {}),
      '07-trackpad',
    );
    await step(
      VoiceStep(draft: draft, index: 5, total: 7, onNext: () {}, onSkip: () {}),
      '08-voice',
    );
    await step(
      VisionStep(
        draft: draft,
        index: 6,
        total: 7,
        onNext: () {},
        onSkip: () {},
        random: math.Random(3),
      ),
      '09-vision',
    );
    await step(
      CalibrationResults(
          draft: filledDraft(), onUse: () {}, onRedo: () {}),
      '10-results',
    );
  });

  testWidgets('controller playground after calibration', (tester) async {
    usePhoneSurface(tester);
    final state = AppState()..setProfile(ProfilePresets.profileB);
    await tester.pumpWidget(
      harness(state, InputPreviewScreen(onContinue: () {}, onRecalibrate: () {})),
    );
    await tester.pump();
    await shoot(tester, '10b-controllers-preview');
    await tester.tap(find.text('Voice'));
    await tester.pump();
    await shoot(tester, '10c-controllers-voice');
    await teardownTree(tester);
  });

  testWidgets('gear-menu playground hub', (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(harness(
      AppState()..setProfile(ProfilePresets.profileA),
      PlaygroundScreen(profile: ProfilePresets.profileA, onClose: () {}),
    ));
    await tester.pump();
    await shoot(tester, '10d-playground-hub');
    await tester.tap(find.text('Buttons'));
    await tester.pump();
    await shoot(tester, '10e-playground-buttons');
    await tester.tap(find.text('Try a demo'));
    await tester.pump();
    await shoot(tester, '10f-playground-demo');
    await teardownTree(tester);
  });

  testWidgets('runtime screens per profile', (tester) async {
    usePhoneSurface(tester);

    Future<AppState> load(CapabilityProfile p) async {
      final state = AppState()..setProfile(p);
      await tester.pumpWidget(harness(state, DemoScreen(onRecalibrate: () {})));
      await tester.pump();
      return state;
    }

    // Profile A: buttons, direct tap, output strip at the top.
    await load(ProfilePresets.profileA);
    await shoot(tester, '11-runtime-a-discrete-buttons');
    await tester.tap(find.text('Standard'));
    await tester.pump();
    await shoot(tester, '12-runtime-a-continuous-stepper');
    await tester.tap(find.textContaining('Confirm'));
    await tester.pump();
    await shoot(tester, '13-runtime-a-pointing-trackpad');
    await teardownTree(tester);

    // Profile B: same task, joystick fallback, floating overlay.
    await load(ProfilePresets.profileB);
    await shoot(tester, '14-runtime-b-discrete-joystick');
    await teardownTree(tester);

    // Floor case: single-switch scanning.
    await load(ProfilePresets.profileFloor);
    await shoot(tester, '15-runtime-floor-discrete-switch');
    await teardownTree(tester);

    // Issue #19: trackpad/switch, no voice — discrete hover+release.
    await load(ProfilePresets.profileTrackpadSwitch);
    await shoot(tester, '15b-runtime-trackpad-switch-discrete');
    await teardownTree(tester);
  });

  testWidgets('pointing fallback and voice fusion', (tester) async {
    usePhoneSurface(tester);
    final state = AppState();

    await tester.pumpWidget(harness(
      state,
      Scaffold(
        body: PointingTaskView(
          profile: ProfilePresets.profileB,
          method: TouchMethod.buttons,
          goal: const Offset(0.72, 0.34),
          onRaw: (_) {},
          onResolve: (_, _) {},
        ),
      ),
    ));
    await shoot(tester, '16-pointing-quadrant-narrowing');
    await tester.tap(find.text('top right'));
    await shoot(tester, '17-pointing-narrowed-once');
    await teardownTree(tester);

    await tester.pumpWidget(harness(
      state,
      Scaffold(
        body: TextTaskView(
          profile: ProfilePresets.profileB,
          method: TouchMethod.joystick,
          fieldLabel: 'Delivery note',
          onRaw: (_) {},
          onNote: (_) {},
          onResolve: (_) {},
        ),
      ),
    ));
    await shoot(tester, '18-text-dictation');
    await teardownTree(tester);

    await tester.pumpWidget(harness(
      state,
      Scaffold(
        body: TextTaskView(
          profile: ProfilePresets.profileFloor,
          method: TouchMethod.switchScan,
          fieldLabel: 'Delivery note',
          onRaw: (_) {},
          onNote: (_) {},
          onResolve: (_) {},
        ),
      ),
    ));
    await shoot(tester, '19-text-sound-count');
    await teardownTree(tester);
  });
}

/// The real app, minus main()'s runApp, so the home screen can be shot as the
/// user first meets it.
class AccessLayerAppForTest extends StatelessWidget {
  const AccessLayerAppForTest({super.key});

  @override
  Widget build(BuildContext context) => const AccessLayerApp();
}
