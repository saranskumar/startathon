import 'package:flutter_test/flutter_test.dart';
import 'package:startathon/inputs/voice_modes.dart';
import 'package:startathon/model/profile.dart';

void main() {
  group('VocalClassifier', () {
    test('sounds: short single pulse is a nod (yes)', () {
      expect(
        VocalClassifier.classify(
          soundCount: 1,
          heldMs: 150,
          clarity: SpeechClarity.sounds,
        ),
        VocalKind.nod,
      );
    });

    test('sounds: long single hold is a hum (yes)', () {
      expect(
        VocalClassifier.classify(
          soundCount: 1,
          heldMs: 900,
          clarity: SpeechClarity.sounds,
        ),
        VocalKind.hum,
      );
    });

    test('sounds: two bursts skip', () {
      final kind = VocalClassifier.classify(
        soundCount: 2,
        heldMs: 400,
        clarity: SpeechClarity.sounds,
      );
      expect(kind, VocalKind.burst);
      expect(kind.skipsSuggestion, isTrue);
      expect(kind.acceptsSuggestion, isFalse);
    });

    test('full clarity classifies as speech', () {
      expect(
        VocalClassifier.classify(
          soundCount: 1,
          heldMs: 800,
          clarity: SpeechClarity.full,
        ),
        VocalKind.speech,
      );
    });
  });

  test('TextComposeMode follows clarity', () {
    expect(
      textComposeModeFor(SpeechClarity.full),
      TextComposeMode.dictate,
    );
    expect(
      textComposeModeFor(SpeechClarity.sounds),
      TextComposeMode.vocalConfirm,
    );
    expect(
      textComposeModeFor(SpeechClarity.none),
      TextComposeMode.touchPick,
    );
  });
}
