import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:startathon/calibration/sense_steps.dart';
import 'package:startathon/calibration/step_frame.dart';
import 'package:startathon/calibration/touch_steps.dart';
import 'package:startathon/inputs/voice_vocab.dart';
import 'package:startathon/model/session.dart';

import 'support/harness.dart';

/// Issue #8: calibration headlines describe the attempt, not a required hit.
void main() {
  group('Calibration headlines (issue #8 attempt-only framing)', () {
    Future<void> pumpStep(WidgetTester tester, Widget step) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(harness(AppState(), Scaffold(body: step)));
    }

    testWidgets('buttons and trackpad lead with Try to, not a required hit',
        (tester) async {
      final draft = CalibrationDraft();
      await pumpStep(
        tester,
        ButtonsStep(
          draft: draft,
          index: 1,
          total: 7,
          onNext: () {},
          onSkip: () {},
        ),
      );
      expect(find.text('Try to press the button.'), findsOneWidget);
      expect(find.text('Press the button.'), findsNothing);
      await teardownTree(tester);

      await pumpStep(
        tester,
        TrackpadStep(
          draft: draft,
          index: 3,
          total: 7,
          onNext: () {},
          onSkip: () {},
        ),
      );
      expect(
        find.text('Try to drag the dot into the ring, then let go.'),
        findsOneWidget,
      );
      expect(
        find.text('Drag the dot into the ring, then let go.'),
        findsNothing,
      );
      await teardownTree(tester);
    });

    testWidgets('every motor/voice/vision headline is attempt-framed',
        (tester) async {
      final empty = CalibrationDraft();
      final reached = CalibrationDraft()..reachableCells.addAll({3, 6, 7});

      final cases = <(Widget, String)>[
        (
          ReachStep(
            draft: empty,
            index: 0,
            total: 7,
            onNext: () {},
            onSkip: () {},
          ),
          'Try to tap the highlighted square.',
        ),
        (
          JoystickStep(
            draft: reached,
            index: 2,
            total: 7,
            onNext: () {},
            onSkip: () {},
          ),
          'Try to circle the stick all the way around, right here.',
        ),
        (
          JoystickStep(
            draft: empty,
            index: 2,
            total: 7,
            onNext: () {},
            onSkip: () {},
          ),
          'Try to push the stick up and hold it there.',
        ),
        (
          HoldStep(
            draft: empty,
            index: 4,
            total: 7,
            onNext: () {},
            onSkip: () {},
          ),
          'Try to press anywhere below and hold still.',
        ),
        (
          VoiceStep(
            draft: empty,
            index: 5,
            total: 7,
            onNext: () {},
            onSkip: () {},
          ),
          'Try to say: "${kVoiceProbes.first.sentence}"',
        ),
        (
          VisionStep(
            draft: empty,
            index: 6,
            total: 7,
            onNext: () {},
            onSkip: () {},
          ),
          'Try to read the word above.',
        ),
      ];

      for (final (step, headline) in cases) {
        await pumpStep(tester, step);
        expect(find.text(headline), findsOneWidget);
        await teardownTree(tester);
      }
    });
  });
}
