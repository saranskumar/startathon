import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:startathon/model/session.dart';
import 'package:startathon/playground/playground_screen.dart';
import 'package:startathon/runtime/discrete_view.dart';

import 'support/harness.dart';

void main() {
  testWidgets('hub is a 2-wide card grid of input modes', (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(harness(
      AppState()..setProfile(ProfilePresets.profileA),
      PlaygroundScreen(profile: ProfilePresets.profileA, onClose: () {}),
    ));
    await tester.pump();
    expect(find.text('Playground'), findsOneWidget);
    expect(find.text('Buttons'), findsOneWidget);
    expect(find.text('Hold'), findsOneWidget);
    expect(find.text('Joystick'), findsOneWidget);
    expect(find.text('Trackpad'), findsOneWidget);
    expect(find.text('Switch scan'), findsOneWidget);
    expect(find.text('Voice'), findsOneWidget);
    expect(find.text('Vision'), findsOneWidget);
    await teardownTree(tester);
  });

  testWidgets('buttons demo is a short color list, not the task chain',
      (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(harness(
      AppState()..setProfile(ProfilePresets.profileA),
      PlaygroundScreen(profile: ProfilePresets.profileA, onClose: () {}),
    ));
    await tester.pump();
    await tester.tap(find.text('Buttons'));
    await tester.pump();
    expect(find.text('Try a demo'), findsOneWidget);
    expect(find.text('Calibration'), findsOneWidget);
    await tester.tap(find.text('Try a demo'));
    await tester.pump();
    expect(find.text('Red'), findsOneWidget);
    expect(find.text('Green'), findsOneWidget);
    expect(find.text('Blue'), findsOneWidget);
    expect(find.text('Pick a plan'), findsNothing);
    expect(find.byType(DiscreteTaskView), findsOneWidget);
    await teardownTree(tester);
  });

  testWidgets('switch calibrate routes through Buttons', (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(harness(
      AppState()..setProfile(ProfilePresets.profileA),
      PlaygroundScreen(profile: ProfilePresets.profileA, onClose: () {}),
    ));
    await tester.pump();
    await tester.tap(find.text('Switch scan'));
    await tester.pump();
    expect(find.text('Calibrate via Buttons'), findsOneWidget);
    await teardownTree(tester);
  });
}
