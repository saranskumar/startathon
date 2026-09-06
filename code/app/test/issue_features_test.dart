import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:startathon/calibration/calibration_flow.dart';
import 'package:startathon/inputs/voice_vocab.dart';
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
    testWidgets('tap anywhere still reaches the axis picker', (tester) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(harness(
        AppState(),
        Scaffold(body: CalibrationFlow(onComplete: (_) {})),
      ));
      await tester.ensureVisible(find.text('Tap anywhere to start'));
      await tester.pump();
      await tester.tap(find.text('Tap anywhere to start'));
      await tester.pump();
      expect(find.text('What should we measure?'), findsOneWidget);
      await teardownTree(tester);
    });

    testWidgets('caregiver path opens training before measurement',
        (tester) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(harness(
        AppState(),
        Scaffold(body: CalibrationFlow(onComplete: (_) {})),
      ));
      await tester.ensureVisible(find.text('Someone is helping set this up'));
      await tester.pump();
      await tester.tap(find.text('Someone is helping set this up'));
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
}
