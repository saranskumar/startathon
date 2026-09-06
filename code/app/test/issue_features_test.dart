import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:startathon/calibration/calibration_flow.dart';
import 'package:startathon/calibration/sense_steps.dart';
import 'package:startathon/calibration/step_frame.dart';
import 'package:startathon/inputs/voice_vocab.dart';
import 'package:startathon/main.dart';
import 'package:startathon/model/profile.dart';
import 'package:startathon/model/session.dart';
import 'package:startathon/onboarding/recorded_voice.dart';
import 'package:startathon/theme/contrast_theme.dart';
import 'package:startathon/training/caregiver_training.dart';
import 'package:startathon/vision/field_shell.dart';

import 'support/harness.dart';

void main() {
  group('VocabMapping (issue #3 + comment: water/tank/yellow)', () {
    test('small menu maps words onto the options themselves', () {
      final map = VocabMapping.mapWords(
        vocabulary: const ['water', 'tank', 'yellow'],
        options: const ['Tea', 'Coffee', 'Water'],
      );
      expect(map, {
        'water': 'Tea',
        'tank': 'Coffee',
        'yellow': 'Water',
      });
    });

    test('long menu maps the first three words to next / previous / select', () {
      final map = VocabMapping.mapWords(
        vocabulary: const ['water', 'tank', 'yellow'],
        options: const ['A', 'B', 'C', 'D', 'E', 'F'],
      );
      expect(map, {
        'water': VocabMapping.next,
        'tank': VocabMapping.previous,
        'yellow': VocabMapping.select,
      });
    });

    test('a two-word vocabulary still drives a long list', () {
      final map = VocabMapping.mapWords(
        vocabulary: const ['yes', 'no'],
        options: List.generate(20, (i) => 'item $i'),
      );
      expect(map['yes'], VocabMapping.next);
      expect(map['no'], VocabMapping.previous);
      expect(map.containsValue(VocabMapping.select), isFalse);
    });

    test('resolve finds the word inside a sentence', () {
      final map = VocabMapping.mapWords(
        vocabulary: const ['water', 'tank', 'yellow'],
        options: const ['A', 'B', 'C', 'D'],
      );
      expect(VocabMapping.resolve('I said water please', map), VocabMapping.next);
      expect(VocabMapping.resolve('YELLOW', map), VocabMapping.select);
      expect(VocabMapping.resolve('hello', map), isNull);
    });
  });

  group('ContrastTheme (issue #1 / research 11)', () {
    test('text on background clears WCAG 4.5:1', () {
      expect(
        ContrastTheme.ratio(
          ContrastTheme.foreground,
          ContrastTheme.background,
        ),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('accent on background clears WCAG 3:1 for UI chrome', () {
      expect(
        ContrastTheme.ratio(ContrastTheme.accent, ContrastTheme.background),
        greaterThanOrEqualTo(3.0),
      );
    });
  });

  group('Start gate + Setup defaults (issue #5)', () {
    test('high contrast starts on; locale stays English', () {
      final state = AppState();
      expect(state.highContrast, isTrue);
      expect(state.locale, 'en');
    });

    test('welcome clip points at the helper on top, start block below', () {
      final en = OnboardingCatalog.find('welcome', 'en')!.transcript;
      expect(en, contains('block at the bottom'));
      expect(en, contains('button at the top'));
      expect(en, isNot(contains('button at the bottom')));
    });

    testWidgets('Start gate is only a tap/hold — no chrome, audio, or toggles',
        (tester) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(const AccessLayerApp());
      await tester.pump();
      expect(find.byKey(const Key('start-gate')), findsOneWidget);
      expect(find.byIcon(Icons.settings), findsNothing);
      expect(find.text('High contrast'), findsNothing);
      expect(find.text('Someone is helping set this up'), findsNothing);
      expect(find.text('Recorded welcome'), findsNothing);
      expect(find.text('OR START FROM A SAVED PROFILE'), findsNothing);
      await tester.tap(find.byKey(const Key('start-gate')));
      await tester.pump();
      expect(find.text('Set up how you control things'), findsOneWidget);
      await tester.pump(const Duration(seconds: 9));
      await teardownTree(tester);
    });

    testWidgets('Setup autoplays welcome and keeps Play recording as replay',
        (tester) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(const AccessLayerApp());
      await tester.pump();
      await tester.tap(find.byKey(const Key('start-gate')));
      await tester.pump();
      await tester.pump(); // post-frame autoplay
      expect(find.text('Playing recorded voice'), findsOneWidget);
      expect(find.text('Play recording'), findsNothing);
      expect(find.text('Someone is helping set this up'), findsOneWidget);
      expect(find.text('High contrast'), findsOneWidget);
      expect(find.text('Tap anywhere to start'), findsOneWidget);
      expect(find.text('OR START FROM A SAVED PROFILE'), findsNothing);
      await tester.pump(const Duration(seconds: 9));
      expect(find.text('Play recording'), findsOneWidget);
      await teardownTree(tester);
    });
  });

  group('Onboarding catalog (issue #1 recorded voice + locale)', () {
    test('welcome exists in English and Malayalam', () {
      expect(OnboardingCatalog.find('welcome', 'en')?.locale, 'en');
      expect(OnboardingCatalog.find('welcome', 'ml')?.locale, 'ml');
      expect(OnboardingCatalog.find('training', 'en'), isNotNull);
    });

    test('unknown locale falls back rather than throwing', () {
      expect(OnboardingCatalog.find('welcome', 'xx')?.transcript, isNotEmpty);
    });
  });

  group('Progressive input level (issue #1 item 5)', () {
    test('visibleOptionCount follows the level-up path', () {
      final base = ProfilePresets.profileA;
      expect(base.copyWith(inputLevel: InputLevel.one).visibleOptionCount, 1);
      expect(base.copyWith(inputLevel: InputLevel.two).visibleOptionCount, 2);
      expect(
        base.copyWith(inputLevel: InputLevel.many).visibleOptionCount,
        base.maxControls,
      );
    });
  });

  group('Calibration entry (issue #1 comment: hold/tap anywhere)', () {
    testWidgets('continue still reaches the axis picker', (tester) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(harness(
        AppState(),
        Scaffold(body: CalibrationFlow(onComplete: (_) {})),
      ));
      await tester.ensureVisible(find.text('Continue'));
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await tester.pump();
      expect(find.text('What should we measure?'), findsOneWidget);
      await teardownTree(tester);
    });

    testWidgets('caregiver path opens training before measurement',
        (tester) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(harness(
        AppState(),
        Scaffold(
          body: CalibrationFlow(onComplete: (_) {}, startAssisted: true),
        ),
      ));
      await tester.pump();
      expect(find.byType(CaregiverTraining), findsOneWidget);
      expect(find.textContaining('Hand under'), findsOneWidget);
      await tester.ensureVisible(find.text('Skip all practice, go to measurement'));
      await tester.pump();
      await tester.tap(find.text('Skip all practice, go to measurement'));
      await tester.pump();
      expect(find.text('What should we measure?'), findsOneWidget);
      await teardownTree(tester);
    });

    testWidgets('onDraftChanged fires after a step advances', (tester) async {
      usePhoneSurface(tester);
      CapabilityProfile? live;
      await tester.pumpWidget(harness(
        AppState(),
        Scaffold(
          body: CalibrationFlow(
            onComplete: (_) {},
            onDraftChanged: (p) => live = p,
          ),
        ),
      ));
      await tester.tap(find.text('Continue'));
      await tester.pump();
      await tester.ensureVisible(find.text('Start'));
      await tester.tap(find.text('Start'));
      await tester.pump();
      expect(find.text('Skip this test'), findsOneWidget);
      await tester.tap(find.text('Skip this test'));
      await tester.pump();
      expect(live, isNotNull);
      expect(live!.label, 'Calibrated');
      // Toast timer from skip.
      await tester.pump(const Duration(seconds: 5));
      await teardownTree(tester);
    });

    testWidgets('AccessLayerApp opens on the Start gate, then Setup',
        (tester) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(const AccessLayerApp());
      await tester.pump();
      expect(find.byKey(const Key('start-gate')), findsOneWidget);
      expect(find.text('OR START FROM A SAVED PROFILE'), findsNothing);
      expect(find.text('Set up how you control things'), findsNothing);
      expect(find.text('Someone is helping set this up'), findsNothing);
      await tester.tap(find.byKey(const Key('start-gate')));
      await tester.pump();
      expect(find.text('Set up how you control things'), findsOneWidget);
      expect(find.text('Tap anywhere to start'), findsOneWidget);
      expect(find.text('Someone is helping set this up'), findsOneWidget);
      expect(find.text('High contrast'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
      expect(find.byIcon(Icons.settings), findsOneWidget);
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();
      expect(find.text('OR START FROM A SAVED PROFILE'), findsOneWidget);
      expect(find.textContaining('Profile A'), findsOneWidget);
      await teardownTree(tester);
    });
  });

  group('Calibration entry simplification (issue #6)', () {
    testWidgets('does not replay welcome or re-ask the helper question',
        (tester) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(harness(
        AppState(),
        Scaffold(body: CalibrationFlow(onComplete: (_) {})),
      ));
      expect(find.text('Continue'), findsOneWidget);
      expect(find.text("We'll measure what works."), findsOneWidget);
      expect(find.text('Set up how you control things'), findsNothing);
      expect(find.text('Someone is helping set this up'), findsNothing);
      expect(find.text('Recorded welcome'), findsNothing);
      expect(find.text('Tap anywhere to start'), findsNothing);
      await tester.tap(find.text('Continue'));
      await tester.pump();
      expect(find.text('What should we measure?'), findsOneWidget);
      await teardownTree(tester);
    });

    testWidgets('startAssisted skips entry and opens training', (tester) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(harness(
        AppState(),
        Scaffold(
          body: CalibrationFlow(onComplete: (_) {}, startAssisted: true),
        ),
      ));
      expect(find.text('Continue'), findsNothing);
      expect(find.byType(CaregiverTraining), findsOneWidget);
      await teardownTree(tester);
    });

    testWidgets('Setup tap lands on the slim continue screen, not a second welcome',
        (tester) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(const AccessLayerApp());
      await tester.pump();
      await tester.tap(find.byKey(const Key('start-gate')));
      await tester.pump();
      expect(find.text('Recorded welcome'), findsOneWidget);
      await tester.tap(find.text('Tap anywhere to start'));
      await tester.pump();
      expect(find.text('Continue'), findsOneWidget);
      expect(find.text("We'll measure what works."), findsOneWidget);
      expect(find.text('Recorded welcome'), findsNothing);
      expect(find.text('Someone is helping set this up'), findsNothing);
      await tester.tap(find.text('Continue'));
      await tester.pump();
      expect(find.text('What should we measure?'), findsOneWidget);
      await tester.pump(const Duration(seconds: 9));
      await teardownTree(tester);
    });
  });

  group('Axis picker (issue #7)', () {
    Future<void> openPicker(WidgetTester tester) async {
      await tester.pumpWidget(harness(
        AppState(),
        Scaffold(body: CalibrationFlow(onComplete: (_) {})),
      ));
      await tester.tap(find.text('Continue'));
      await tester.pump();
    }

    testWidgets('all three axes start on and Start is already enabled',
        (tester) async {
      usePhoneSurface(tester);
      await openPicker(tester);
      expect(find.byIcon(Icons.check_circle), findsNWidgets(3));
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Start'))
            .onPressed,
        isNotNull,
      );
      await teardownTree(tester);
    });

    testWidgets('a tap does not turn an on axis off', (tester) async {
      usePhoneSurface(tester);
      await openPicker(tester);
      await tester.tap(find.text('Motor'));
      await tester.pump();
      expect(find.byIcon(Icons.check_circle), findsNWidgets(3));
      expect(find.byIcon(Icons.circle_outlined), findsNothing);
      await teardownTree(tester);
    });

    testWidgets('holding a row turns that axis off; a tap turns it back on',
        (tester) async {
      usePhoneSurface(tester);
      await openPicker(tester);
      await holdToConfirm(tester, find.byKey(const ValueKey('axis-Motor')));
      expect(find.byIcon(Icons.check_circle), findsNWidgets(2));
      expect(find.byIcon(Icons.circle_outlined), findsOneWidget);
      await tester.tap(find.text('Motor'));
      await tester.pump();
      expect(find.byIcon(Icons.check_circle), findsNWidgets(3));
      await teardownTree(tester);
    });

    testWidgets('the last remaining axis cannot be held off', (tester) async {
      usePhoneSurface(tester);
      await openPicker(tester);
      await holdToConfirm(tester, find.byKey(const ValueKey('axis-Motor')));
      await holdToConfirm(tester, find.byKey(const ValueKey('axis-Speech')));
      await holdToConfirm(tester, find.byKey(const ValueKey('axis-Vision')));
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.text('Keep at least one environment on.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await teardownTree(tester);
    });
  });

  group('Vision word pool (issue #12)', () {
    test('pool is well beyond the original four words', () {
      expect(kVisionWords, containsAll(['river', 'candle', 'window', 'pocket']));
      expect(kVisionWords.toSet(), hasLength(kVisionWords.length));
      expect(kVisionWords.length, greaterThanOrEqualTo(16));
    });

    test('a session seed shuffles once and deals unique shown words', () {
      final deck = VisionWordDeck(random: math.Random(3));
      final shown = [for (var i = 0; i < 4; i++) deck.next().shown];
      expect(shown.toSet(), hasLength(4));
      for (final word in shown) {
        expect(kVisionWords, contains(word));
      }
    });

    test('the same seed is deterministic; a new session seed is not the old loop',
        () {
      List<String> deal(int seed) {
        final deck = VisionWordDeck(random: math.Random(seed));
        return [for (var i = 0; i < 4; i++) deck.next().shown];
      }

      expect(deal(3), deal(3));
      expect(deal(3), isNot(equals(deal(11))));
    });

    test('each round offers the shown word plus one other from the pool', () {
      final deck = VisionWordDeck(random: math.Random(7));
      final round = deck.next();
      expect(round.choices, hasLength(2));
      expect(round.choices, contains(round.shown));
      expect(kVisionWords, containsAll(round.choices));
      expect(round.choices.toSet(), hasLength(2));
    });

    testWidgets('VisionStep with a seed shows that deck\'s first word',
        (tester) async {
      usePhoneSurface(tester);
      final expected = VisionWordDeck(random: math.Random(3)).next().shown;
      await tester.pumpWidget(harness(
        AppState(),
        Scaffold(
          body: VisionStep(
            draft: CalibrationDraft(),
            index: 6,
            total: 7,
            onNext: () {},
            onSkip: () {},
            random: math.Random(3),
          ),
        ),
      ));
      expect(find.text(expected), findsWidgets);
      await teardownTree(tester);
    });

    test('an unseeded session deck is not locked to Random(3)', () {
      final locked = VisionWordDeck(random: math.Random(3));
      final lockedDeal = [for (var i = 0; i < 4; i++) locked.next().shown];
      var differed = false;
      for (var i = 0; i < 20; i++) {
        final live = VisionWordDeck();
        final deal = [for (var j = 0; j < 4; j++) live.next().shown];
        if (deal.join('|') != lockedDeal.join('|')) {
          differed = true;
          break;
        }
      }
      expect(differed, isTrue);
    });

    testWidgets('live VisionStep with no seed still shows a pool word',
        (tester) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(harness(
        AppState(),
        Scaffold(
          body: VisionStep(
            draft: CalibrationDraft(),
            index: 6,
            total: 7,
            onNext: () {},
            onSkip: () {},
          ),
        ),
      ));
      expect(
        kVisionWords.where((w) => find.text(w).evaluate().isNotEmpty),
        isNotEmpty,
      );
      await teardownTree(tester);
    });
  });

  group('Visual field (issue #4)', () {
    test('presets carry tunnel / full as expected', () {
      expect(ProfilePresets.profileFloor.visualField, VisualField.tunnel);
      expect(ProfilePresets.profileA.visualField, VisualField.full);
    });

    testWidgets('tunnel mask does not steal taps under the veil', (tester) async {
      usePhoneSurface(tester);
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: VisualFieldShell(
            field: VisualField.tunnel,
            child: Scaffold(
              body: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => taps++,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      );
      await tester.tapAt(const Offset(20, 700));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('peripheral veil also lets the center still receive taps',
        (tester) async {
      usePhoneSurface(tester);
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: VisualFieldShell(
            field: VisualField.peripheral,
            child: Scaffold(
              body: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => taps++,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      );
      await tester.tapAt(const Offset(195, 422));
      await tester.pump();
      expect(taps, 1);
    });
  });

  group('Calibration back-navigation (issue #10)', () {
    testWidgets('StepFrame shows Back opposite Skip when onBack is set',
        (tester) async {
      usePhoneSurface(tester);
      var backs = 0;
      var skips = 0;
      await tester.pumpWidget(harness(
        AppState(),
        Scaffold(
          body: StepFrame(
            title: 'Buttons',
            instruction: 'Press the button.',
            index: 1,
            total: 7,
            onSkip: () => skips++,
            onBack: () => backs++,
            child: const SizedBox.expand(),
          ),
        ),
      ));
      expect(find.text('Back'), findsOneWidget);
      expect(find.text('Skip this test'), findsOneWidget);
      await tester.tap(find.text('Back'));
      await tester.pump();
      expect(backs, 1);
      expect(skips, 0);
      await teardownTree(tester);
    });

    testWidgets('StepFrame hides Back on the first test', (tester) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(harness(
        AppState(),
        Scaffold(
          body: StepFrame(
            title: 'Reachable zone',
            instruction: 'Tap the highlighted square.',
            index: 0,
            total: 7,
            onSkip: () {},
            child: const SizedBox.expand(),
          ),
        ),
      ));
      expect(find.text('Back'), findsNothing);
      expect(find.text('Skip this test'), findsOneWidget);
      await teardownTree(tester);
    });

    testWidgets('first gated test has Skip but no Back into the axis picker',
        (tester) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(harness(
        AppState(),
        Scaffold(body: CalibrationFlow(onComplete: (_) {})),
      ));
      await tester.tap(find.text('Continue'));
      await tester.pump();
      await tester.ensureVisible(find.text('Start'));
      await tester.tap(find.text('Start'));
      await tester.pump();
      expect(find.text('Reachable zone'), findsOneWidget);
      expect(find.text('Skip this test'), findsOneWidget);
      expect(find.text('Back'), findsNothing);
      expect(find.text('What should we measure?'), findsNothing);
      await teardownTree(tester);
    });

    testWidgets('Back returns one step and starts that test over as untested',
        (tester) async {
      usePhoneSurface(tester);
      CapabilityProfile? live;
      await tester.pumpWidget(harness(
        AppState(),
        Scaffold(
          body: CalibrationFlow(
            onComplete: (_) {},
            onDraftChanged: (p) => live = p,
          ),
        ),
      ));
      await tester.tap(find.text('Continue'));
      await tester.pump();
      await tester.ensureVisible(find.text('Start'));
      await tester.tap(find.text('Start'));
      await tester.pump();

      await tester.tapAt(const Offset(60, 500));
      await tester.pump();
      await tester.tap(find.text('Skip this test'));
      await tester.pump();
      expect(find.text('Buttons'), findsOneWidget);
      expect(find.text('Back'), findsOneWidget);
      expect(live, isNotNull);
      expect(live!.reachableCells, isNotEmpty);

      await tester.tap(find.text('Skip this test'));
      await tester.pump();
      expect(find.text('Joystick'), findsOneWidget);

      await tester.tap(find.text('Back'));
      await tester.pump();
      expect(find.text('Buttons'), findsOneWidget);
      expect(live!.methodScores[TouchMethod.buttons]!.tested, isFalse);
      expect(live!.reachableCells, isNotEmpty,
          reason: 'Reach is two steps back; this Back only retakes Buttons');

      await tester.tap(find.text('Back'));
      await tester.pump();
      expect(find.text('Reachable zone'), findsOneWidget);
      expect(find.text('Back'), findsNothing);
      expect(find.text('What should we measure?'), findsNothing);
      expect(live!.reachableCells, isEmpty);

      await tester.pump(const Duration(seconds: 5));
      await teardownTree(tester);
    });
  });
}
