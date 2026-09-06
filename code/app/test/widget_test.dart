import 'package:flutter_test/flutter_test.dart';
import 'package:startathon/model/profile.dart';
import 'package:startathon/model/session.dart';
import 'package:startathon/runtime/task_spec.dart';

void main() {
  group('MethodScore', () {
    test('matches the formula in docs/idea/03-input-calibration.md', () {
      const s = MethodScore(
        successRate: 1,
        timeNormalized: 0,
        errorNormalized: 0,
        attempts: 3,
      );
      expect(s.score, closeTo(1.0, 1e-9));

      const worst = MethodScore(
        successRate: 0,
        timeNormalized: 1,
        errorNormalized: 1,
        attempts: 3,
      );
      expect(worst.score, closeTo(0.0, 1e-9));

      const mixed = MethodScore(
        successRate: 0.5,
        timeNormalized: 0.5,
        errorNormalized: 0.5,
        attempts: 3,
      );
      // 0.5*0.5 + 0.3*0.5 + 0.2*0.5
      expect(mixed.score, closeTo(0.5, 1e-9));
    });

    test('an untested method scores zero rather than throwing', () {
      expect(const MethodScore.untested().score, 0);
      expect(const MethodScore.untested().tested, isFalse);
    });
  });

  group('fallback rule (3.3)', () {
    test('keeps the ideal method when nothing beats it by the margin', () {
      final p = ProfilePresets.profileA;
      final choice = chooseMethod(p, TaskShape.discrete);
      expect(choice.method, TouchMethod.buttons);
      expect(choice.isFallback, isFalse);
    });

    test('falls back when another method scores meaningfully higher', () {
      final p = ProfilePresets.profileB;
      final choice = chooseMethod(p, TaskShape.discrete);
      expect(choice.method, TouchMethod.joystick);
      expect(choice.isFallback, isTrue);
    });

    test('trackpad/switch preset uses trackpad, never buttons or joystick', () {
      final p = ProfilePresets.profileTrackpadSwitch;
      expect(p.bestMethod, TouchMethod.trackpad);
      expect(p.clarity, SpeechClarity.none);
      expect(p.vision, VisionMode.screen);
      expect(p.visualField, VisualField.full);
      expect(p.reachableCells, ProfilePresets.profileB.reachableCells);
      expect(p.minTargetSize, ProfilePresets.profileB.minTargetSize);
      for (final shape in TaskShape.values) {
        final choice = chooseMethod(p, shape);
        expect(choice.method, TouchMethod.trackpad, reason: '$shape');
        expect(
          choice.method,
          isNot(anyOf(TouchMethod.buttons, TouchMethod.joystick)),
        );
      }
    });

    test('trackpad/switch falls to switch when trackpad is untested', () {
      final scores = Map<TouchMethod, MethodScore>.from(
        ProfilePresets.profileTrackpadSwitch.methodScores,
      );
      scores[TouchMethod.trackpad] = const MethodScore.untested();
      final p = ProfilePresets.profileTrackpadSwitch
          .copyWith(methodScores: scores);
      expect(p.bestMethod, TouchMethod.switchScan);
      expect(
        chooseMethod(p, TaskShape.discrete).method,
        TouchMethod.switchScan,
      );
    });

    test('gear menu lists trackpad/switch first', () {
      expect(
        ProfilePresets.all.first.label,
        'Trackpad / switch (no voice)',
      );
      expect(
        ProfilePresets.all.map((p) => p.label).toList(),
        [
          'Trackpad / switch (no voice)',
          'Calibrated (default)',
          'Profile A (precise touch, clear speech)',
          'Profile B (imprecise touch, slurred speech)',
          'Floor case (single-switch scanning)',
        ],
      );
    });

    test('is relative, so a uniformly weak user still gets their best', () {
      final weak = CapabilityProfile.blank().copyWith(
        methodScores: const {
          TouchMethod.buttons: MethodScore(
              successRate: 0.1,
              timeNormalized: 0.9,
              errorNormalized: 0.9,
              attempts: 4),
          TouchMethod.joystick: MethodScore(
              successRate: 0.1,
              timeNormalized: 0.9,
              errorNormalized: 0.9,
              attempts: 4),
          TouchMethod.trackpad: MethodScore(
              successRate: 0.1,
              timeNormalized: 0.9,
              errorNormalized: 0.9,
              attempts: 4),
          TouchMethod.switchScan: MethodScore(
              successRate: 0.7,
              timeNormalized: 0.8,
              errorNormalized: 0.3,
              attempts: 4),
        },
      );
      final choice = chooseMethod(weak, TaskShape.discrete);
      expect(choice.method, TouchMethod.switchScan);
      expect(choice.isFallback, isTrue);
    });
  });

  group('profile geometry', () {
    test('output goes to the row the user can reach least', () {
      // Reachable only along the bottom two rows.
      final p = CapabilityProfile.blank()
          .copyWith(reachableCells: {6, 7, 8, 9, 10, 11});
      expect(p.outputRow, 0);
      expect(p.outputAtBottom, isFalse);
    });

    test('output moves to the bottom when the top is the reachable part', () {
      final p =
          CapabilityProfile.blank().copyWith(reachableCells: {0, 1, 2, 3, 4, 5});
      expect(p.outputRow, CapabilityProfile.reachGridRows - 1);
      expect(p.outputAtBottom, isTrue);
    });

    test('the joystick anchors inside the reachable area', () {
      final p = CapabilityProfile.blank().copyWith(reachableCells: {9, 10});
      final anchor = p.reachAnchor;
      expect(anchor.y, greaterThan(0.3));
    });

    test('fewer controls are offered as scores drop', () {
      expect(
        ProfilePresets.profileFloor.maxControls,
        lessThan(ProfilePresets.profileA.maxControls),
      );
    });

    test('visibleCountForHeight clamps by target size, not a hard-coded 6', () {
      final a = ProfilePresets.profileA;
      expect(a.visibleCountForHeight(400), a.visibleOptionCount);
      expect(a.visibleCountForHeight(100), 1);
      final floor = ProfilePresets.profileFloor;
      expect(floor.visibleOptionCount, 1);
      expect(floor.visibleCountForHeight(250), 1);
      expect(
        floor.copyWith(inputLevel: InputLevel.many).visibleCountForHeight(250),
        1,
      );
    });

    test('Floor switch dwell is about 2.5s (issue #20)', () {
      expect(
        ProfilePresets.profileFloor.scanDwell.inMilliseconds,
        closeTo(2500, 50),
      );
      expect(
        ProfilePresets.profileA.scanDwell.inMilliseconds,
        lessThan(1500),
      );
    });
  });

  group('TrialCollector', () {
    test('normalises time and error against the reference values', () {
      final c = TrialCollector(referenceMs: 4000, referenceError: 100);
      c.record(success: true, ms: 2000, error: 50);
      c.record(success: false, ms: 6000, error: 200);
      final s = c.build();
      expect(s.attempts, 2);
      expect(s.successRate, 0.5);
      // mean 4000ms -> 1.0 after clamping
      expect(s.timeNormalized, closeTo(1.0, 1e-9));
      expect(s.errorNormalized, closeTo(1.0, 1e-9));
    });
  });
}
