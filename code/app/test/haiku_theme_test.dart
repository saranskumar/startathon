import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:startathon/calibration/calibration_flow.dart';
import 'package:startathon/calibration/step_frame.dart';
import 'package:startathon/inputs/surfaces.dart';
import 'package:startathon/model/session.dart';
import 'package:startathon/theme/haiku_theme.dart';

import 'support/harness.dart';

void main() {
  group('HaikuTheme', () {
    test('a motor-only mix leans toward the motor seed', () {
      final theme = HaikuTheme.compute(motor: true, speech: false, vision: false);
      expect(theme.seedColor, HaikuTheme.motorSeed);
      expect(theme.emotion, isNotEmpty);
      expect(theme.value, isNotEmpty);
      expect(theme.blessing.split('\n').length, 3, reason: 'a haiku is three lines');
    });

    test('motor+speech is a different mix than speech+vision', () {
      final motorSpeech =
          HaikuTheme.compute(motor: true, speech: true, vision: false);
      final speechVision =
          HaikuTheme.compute(motor: false, speech: true, vision: false);
      final speechVisionOn =
          HaikuTheme.compute(motor: false, speech: true, vision: true);

      expect(motorSpeech.seedColor, isNot(speechVisionOn.seedColor));
      expect(motorSpeech.value, isNot(speechVisionOn.value));
      // Sanity: turning speech-only into speech+vision actually changes it too.
      expect(speechVision.seedColor, isNot(speechVisionOn.seedColor));
    });

    test('a higher score shifts the blend further toward that axis', () {
      final low = HaikuTheme.compute(
          motor: true, speech: true, vision: false, motorScore: 0, speechScore: 0);
      final high = HaikuTheme.compute(
          motor: true, speech: true, vision: false, motorScore: 1, speechScore: 0);
      // Weighting motor higher should pull the blend measurably toward the
      // motor seed (higher red/green, since motor is yellow) vs. the
      // even-weighted low-score case.
      expect(high.seedColor.r, greaterThan(low.seedColor.r));
    });
  });

  group('CalibrationFlow axis gating', () {
    testWidgets('a speech-only session never mounts the joystick step',
        (tester) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(harness(
        AppState(),
        Scaffold(body: CalibrationFlow(onComplete: (_) {})),
      ));

      // The universal entry screen: any tap gets past it, straight to the
      // axis picker (docs: issue #1 -- entry must not gate on anything
      // harder than a single tap anywhere).
      await tester.tap(find.text('Tap anywhere to start'));
      await tester.pump();

      // Turn Motor and Vision off, leaving only Speech.
      await tester.tap(find.text('Motor'));
      await tester.pump();
      await tester.tap(find.text('Vision'));
      await tester.pump();
      await tester.ensureVisible(find.text('Start'));
      await tester.pump();
      await tester.tap(find.text('Start'));
      await tester.pump();

      expect(find.byType(JoystickPad), findsNothing);
      expect(find.text('Voice'), findsWidgets); // the VoiceStep title
      await teardownTree(tester);
    });

    testWidgets('helper-chose-axes does not touch any scores', (tester) async {
      final draft = CalibrationDraft();
      final beforeScores = Map.of(draft.scores);
      draft.helperChoseAxes = true;
      expect(draft.scores, equals(beforeScores));
      expect(draft.build().methodScores.values.every((s) => !s.tested), isTrue);
    });
  });
}
