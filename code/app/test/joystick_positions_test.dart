import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:startathon/inputs/surfaces.dart';

void main() {
  testWidgets('JoystickPad reports and renders all 8 directions consistently',
      (tester) async {
    Offset? lastVector;
    const size = 200.0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: JoystickPad(
              size: size,
              deadZone: 0.0,
              onVector: (v) => lastVector = v,
            ),
          ),
        ),
      ),
    );

    final padCenter = tester.getCenter(find.byType(JoystickPad));
    final r = size / 2;
    final diag = math.sqrt(0.5);

    final directions = <String, Offset>{
      'up': const Offset(0, -1),
      'down': const Offset(0, 1),
      'left': const Offset(-1, 0),
      'right': const Offset(1, 0),
      'up-left': Offset(-diag, -diag),
      'up-right': Offset(diag, -diag),
      'down-left': Offset(-diag, diag),
      'down-right': Offset(diag, diag),
    };

    double? knobToVectorRatio;

    for (final entry in directions.entries) {
      final want = entry.value;
      final target = padCenter + want * (r * 0.9);
      final gesture = await tester.startGesture(padCenter);
      await gesture.moveTo(target);
      await tester.pump();

      // The stick reported a vector pointing the same way we pushed it.
      expect(lastVector, isNotNull, reason: '${entry.key}: no vector emitted');
      final v = lastVector!;
      final dot = (v.dx * want.dx + v.dy * want.dy) / v.distance;
      expect(dot, closeTo(1.0, 0.01),
          reason: '${entry.key}: onVector=$v does not point toward $want');
      expect(v.distance, closeTo(0.9, 0.05),
          reason: '${entry.key}: onVector magnitude $v off from the 0.9 push');

      // The knob itself moved -- every direction gets pixels, not just the
      // cardinals -- and by the same fraction of the reported vector
      // regardless of which of the 8 directions it is (no axis is favored).
      final knobCenter =
          tester.getCenter(find.byKey(const ValueKey('joystick-knob')));
      final rendered = (knobCenter - padCenter) / r;
      expect(rendered.distance, greaterThan(0.1),
          reason: '${entry.key}: knob did not visibly move');
      final renderedDot =
          (rendered.dx * want.dx + rendered.dy * want.dy) / rendered.distance;
      expect(renderedDot, closeTo(1.0, 0.01),
          reason: '${entry.key}: knob rendered off-axis at $rendered');

      final ratio = rendered.distance / v.distance;
      knobToVectorRatio ??= ratio;
      expect(ratio, closeTo(knobToVectorRatio, 0.02),
          reason: '${entry.key}: knob-to-vector scale is not uniform '
              'across directions ($ratio vs $knobToVectorRatio)');

      await gesture.up();
      await tester.pump();
    }
  });
}
