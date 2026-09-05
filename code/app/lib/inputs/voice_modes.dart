import '../model/profile.dart';

/// How the text field is filled, given this user's speech clarity.
enum TextComposeMode {
  /// Words are expected. Hold-to-speak goes to [SpeechSource].
  dictate,

  /// No words. Suggestions + nod / sound / hum / burst vocabulary.
  vocalConfirm,

  /// No voice. Suggestions chosen with the touch method.
  touchPick,
}

TextComposeMode textComposeModeFor(SpeechClarity clarity) {
  if (clarity.canDictate) return TextComposeMode.dictate;
  if (clarity == SpeechClarity.sounds) return TextComposeMode.vocalConfirm;
  return TextComposeMode.touchPick;
}

extension TextComposeModePlan on TextComposeMode {

  String get title => switch (this) {
        TextComposeMode.dictate => 'Dictate, then confirm',
        TextComposeMode.vocalConfirm => 'Nod, sound, or hum to confirm',
        TextComposeMode.touchPick => 'Pick a phrase by touch',
      };

  String get detail => switch (this) {
        TextComposeMode.dictate =>
          'Touch selects the field. Voice fills it. Nothing is stored until confirm.',
        TextComposeMode.vocalConfirm =>
          'The app proposes phrases. A short nod or sound, or a hum, means yes. '
          'Two sounds means next phrase.',
        TextComposeMode.touchPick =>
          'Voice is not offered. The same phrases are chosen with the calibrated touch method.',
      };
}

/// What one capture was, after calibration has already decided [SpeechClarity].
enum VocalKind {
  /// Short single pulse — yes. Vocal stand-in for a head nod.
  nod,

  /// One ordinary vocalisation — yes.
  sound,

  /// Long single hold — sustained yes (hum / dwell).
  hum,

  /// Two or more separate sounds — no / next.
  burst,

  /// Words; send to the recogniser.
  speech,

  silence,
}

extension VocalKindLabel on VocalKind {
  String get label => switch (this) {
        VocalKind.nod => 'nod',
        VocalKind.sound => 'sound',
        VocalKind.hum => 'hum',
        VocalKind.burst => 'sounds (×2+)',
        VocalKind.speech => 'speech',
        VocalKind.silence => 'silence',
      };

  /// True if this event should accept the current suggestion in vocal-confirm.
  bool get acceptsSuggestion =>
      this == VocalKind.nod ||
      this == VocalKind.sound ||
      this == VocalKind.hum;

  /// True if this event should advance to the next suggestion.
  bool get skipsSuggestion => this == VocalKind.burst;
}

/// Turns hold time + burst count into a [VocalKind].
///
/// The UI already measures both (see [HoldToSpeak]). A real VAD later should
/// feed the same two numbers; this function does not change.
class VocalClassifier {
  static const int nodMaxMs = 280;
  static const int humMinMs = 800;
  static const int silenceMaxMs = 120;

  static VocalKind classify({
    required int soundCount,
    required int heldMs,
    required SpeechClarity clarity,
  }) {
    if (clarity.canDictate) {
      if (heldMs < 400 && soundCount <= 1) return VocalKind.silence;
      return VocalKind.speech;
    }

    if (clarity == SpeechClarity.none) return VocalKind.silence;

    if (soundCount <= 0 || heldMs < silenceMaxMs) return VocalKind.silence;
    if (soundCount >= 2) return VocalKind.burst;
    if (heldMs >= humMinMs) return VocalKind.hum;
    if (heldMs < nodMaxMs) return VocalKind.nod;
    return VocalKind.sound;
  }
}
