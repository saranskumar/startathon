import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:startathon/calibration/step_frame.dart';
import 'package:startathon/calibration/touch_steps.dart';
import 'package:startathon/inputs/surfaces.dart';
import 'package:startathon/model/profile.dart';
import 'package:startathon/model/session.dart';

import 'support/harness.dart';

/// Sweeps the joystick through [count] of the 8 octants. Each is its own
/// press-move-release (the octant set accumulates across the whole round
/// regardless). Note a round auto-advances the instant 6 distinct octants
/// are hit (JoystickStep's own `_octantsNeeded` early-exit, so a user is
/// never made to keep circling after already proving coverage) -- so
/// [count] above 6 would bleed into the *next* round, not stay in this one.
Future<void> _sweep(WidgetTester tester, Finder pad, int count) async {
  const r = 170 / 2 * 0.9;
  for (var i = 0; i < count; i++) {
    final center = tester.getCenter(pad);
    final angle = i * math.pi / 4;
    final gesture = await tester.startGesture(center);
    await gesture.moveTo(
      center + Offset(r * math.cos(angle), r * math.sin(angle)),
    );
    await tester.pump();
    await gesture.up();
    await tester.pump();
  }
}

void main() {
  group('joystick swing calibration', () {
    testWidgets('one round per reachable cell, home cell is the steadiest',
        (tester) async {
      usePhoneSurface(tester);
      final draft = CalibrationDraft()
        // Grid is 3 cols x 4 rows. Cell 4 (col 1, row 1) sits near the
        // centre; cell 11 (col 2, row 3) sits in the far corner -- distinct
        // distances so centre-first ordering is unambiguous.
        ..reachableCells.addAll({4, 11});
      var completed = false;

      await tester.pumpWidget(harness(
        AppState(),
        Scaffold(
          body: JoystickStep(
            draft: draft,
            index: 2,
            total: 7,
            onNext: () => completed = true,
            onSkip: () {},
          ),
        ),
      ));

      // Round 1: cell 4, centre-first -- enough octants to pass (auto-stops
      // at 6, so this is a clean win rather than a bare-minimum one).
      await _sweep(tester, find.byType(JoystickPad), 6);
      expect(draft.joystickOctants[4], 6);

      // Round 2: cell 11 -- only a partial sweep, then let it time out.
      await _sweep(tester, find.byType(JoystickPad), 3);
      await tester.pump(const Duration(seconds: 7));

      expect(completed, isTrue);
      expect(draft.joystickOctants[11], lessThan(6));
      expect(draft.joystickHomeCell, 4, reason: 'cell 4 scored higher (6 vs <6)');
      expect(draft.scores[TouchMethod.joystick]!.tested, isTrue);
      await teardownTree(tester);
    });

    testWidgets('a tie prefers the centre-most cell', (tester) async {
      usePhoneSurface(tester);
      final draft = CalibrationDraft()
        // Cell 4 (near centre) and cell 0 (corner) -- both pass with the
        // same octant count, so the tie-break (not the score) decides.
        ..reachableCells.addAll({4, 0});

      await tester.pumpWidget(harness(
        AppState(),
        Scaffold(
          body: JoystickStep(
            draft: draft,
            index: 2,
            total: 7,
            onNext: () {},
            onSkip: () {},
          ),
        ),
      ));

      await _sweep(tester, find.byType(JoystickPad), 6);
      await _sweep(tester, find.byType(JoystickPad), 6);

      expect(draft.joystickOctants[4], 6);
      expect(draft.joystickOctants[0], 6);
      expect(draft.joystickHomeCell, 4, reason: 'cell 4 is closer to centre');
      await teardownTree(tester);
    });

    testWidgets('no reachable cells falls back to the single-centre hold test',
        (tester) async {
      usePhoneSurface(tester);
      final draft = CalibrationDraft(); // reachableCells left empty

      await tester.pumpWidget(harness(
        AppState(),
        Scaffold(
          body: JoystickStep(
            draft: draft,
            index: 2,
            total: 7,
            onNext: () {},
            onSkip: () {},
          ),
        ),
      ));

      expect(find.textContaining('and hold it there'), findsOneWidget);
      expect(draft.joystickHomeCell, isNull);
      await teardownTree(tester);
    });
  });
}
