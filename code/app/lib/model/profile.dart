import 'dart:math' as math;
import 'package:flutter/painting.dart';

import '../theme/haiku_theme.dart';

/// The four touch input methods the system can drive a task with.
///
/// `switchScan` is the floor case from docs/idea/03-input-calibration.md 3.5 --
/// documented there as "not built"; it is implemented here because it costs
/// little once the other three share a task-controller interface.
enum TouchMethod { buttons, joystick, trackpad, switchScan }

extension TouchMethodLabel on TouchMethod {
  String get label => switch (this) {
        TouchMethod.buttons => 'Buttons',
        TouchMethod.joystick => 'Joystick',
        TouchMethod.trackpad => 'Trackpad',
        TouchMethod.switchScan => 'Switch scan',
      };

  String get shortLabel => switch (this) {
        TouchMethod.buttons => 'BTN',
        TouchMethod.joystick => 'JOY',
        TouchMethod.trackpad => 'TRK',
        TouchMethod.switchScan => 'SWI',
      };
}

/// docs/idea/02-core-model.md 2.1 -- speech clarity axis.
enum SpeechClarity { full, partial, sounds, none }

extension SpeechClarityLabel on SpeechClarity {
  String get label => switch (this) {
        SpeechClarity.full => 'full',
        SpeechClarity.partial => 'partial',
        SpeechClarity.sounds => 'sounds',
        SpeechClarity.none => 'none',
      };

  /// What this tier is actually allowed to do, per 3.1.
  String get grants => switch (this) {
        SpeechClarity.full => 'free-text dictation',
        SpeechClarity.partial => 'dictation, patient, confirm each field',
        SpeechClarity.sounds =>
          'nod / sound / hum = yes; two sounds = next phrase',
        SpeechClarity.none => 'voice not offered',
      };

  bool get canDictate =>
      this == SpeechClarity.full || this == SpeechClarity.partial;
}

/// docs/idea/02-core-model.md 2.1 -- vision axis, drives output mode.
enum VisionMode { screen, large, none }

extension VisionModeLabel on VisionMode {
  String get label => switch (this) {
        VisionMode.screen => 'screen',
        VisionMode.large => 'large',
        VisionMode.none => 'none',
      };

  /// Multiplier applied to every runtime control and label.
  double get textScale => switch (this) {
        VisionMode.screen => 1.0,
        VisionMode.large => 1.45,
        VisionMode.none => 1.6,
      };
}

/// Visual *field* shape — independent of acuity ([VisionMode]).
/// Issue #4 / research 09 covers size; this covers how much of the screen
/// is visible at once, and where.
enum VisualField { full, tunnel, peripheral }

extension VisualFieldLabel on VisualField {
  String get label => switch (this) {
        VisualField.full => 'full field',
        VisualField.tunnel => 'tunnel',
        VisualField.peripheral => 'peripheral only',
      };

  String get detail => switch (this) {
        VisualField.full => 'the whole screen is in play',
        VisualField.tunnel =>
          'output sits in one window; input still works anywhere',
        VisualField.peripheral =>
          'center is unused; information lives on the edges',
      };
}

/// Progressive input complexity (issue #1 item 5). Everyone starts at
/// [one]; they opt into more choices. The capability profile still picks
/// *which* method — this only caps how many targets that method shows.
enum InputLevel { one, two, many }

extension InputLevelLabel on InputLevel {
  String get label => switch (this) {
        InputLevel.one => 'one target',
        InputLevel.two => 'two targets',
        InputLevel.many => 'full set',
      };

  int get optionCap => switch (this) {
        InputLevel.one => 1,
        InputLevel.two => 2,
        InputLevel.many => 99,
      };

  InputLevel get next => switch (this) {
        InputLevel.one => InputLevel.two,
        InputLevel.two => InputLevel.many,
        InputLevel.many => InputLevel.many,
      };

  InputLevel get previous => switch (this) {
        InputLevel.one => InputLevel.one,
        InputLevel.two => InputLevel.one,
        InputLevel.many => InputLevel.two,
      };
}

/// One method's calibration result. Kept as its three components rather than a
/// bare number so the results screen can show *why* a method scored what it did.
class MethodScore {
  const MethodScore({
    required this.successRate,
    required this.timeNormalized,
    required this.errorNormalized,
    this.attempts = 0,
  });

  const MethodScore.untested()
      : successRate = 0,
        timeNormalized = 1,
        errorNormalized = 1,
        attempts = 0;

  final double successRate;
  final double timeNormalized;
  final double errorNormalized;
  final int attempts;

  /// docs/idea/03-input-calibration.md 3.1, verbatim:
  /// 0.5 * success_rate + 0.3 * (1 - time_norm) + 0.2 * (1 - error_norm)
  double get score =>
      0.5 * successRate +
      0.3 * (1 - timeNormalized) +
      0.2 * (1 - errorNormalized);

  bool get tested => attempts > 0;

  Map<String, dynamic> toJson() => {
        'successRate': successRate,
        'timeNormalized': timeNormalized,
        'errorNormalized': errorNormalized,
        'attempts': attempts,
      };

  factory MethodScore.fromJson(Map<String, dynamic> j) => MethodScore(
        successRate: (j['successRate'] as num?)?.toDouble() ?? 0,
        timeNormalized: (j['timeNormalized'] as num?)?.toDouble() ?? 1,
        errorNormalized: (j['errorNormalized'] as num?)?.toDouble() ?? 1,
        attempts: (j['attempts'] as num?)?.toInt() ?? 0,
      );
}

/// docs/idea/02-core-model.md 2.3 -- the one object everything runs off.
class CapabilityProfile {
  CapabilityProfile({
    required this.methodScores,
    required this.reachableCells,
    this.lockedCells = const <int>{},
    required this.minTargetSize,
    required this.steadiness,
    required this.holdCapable,
    this.tappableButtonCount = 0,
    this.holdableButtonCount = 0,
    required this.clarity,
    required this.vision,
    this.measureMotor = true,
    this.measureSpeech = true,
    this.measureVision = true,
    this.joystickHomeCell,
    this.visualField = VisualField.full,
    this.inputLevel = InputLevel.one,
    this.vocabulary = const [],
    this.locale = 'en',
    this.label = 'Calibrated',
  });

  /// Everything scored 0, nothing reachable -- the state before calibration.
  factory CapabilityProfile.blank() => CapabilityProfile(
        methodScores: {
          for (final m in TouchMethod.values) m: const MethodScore.untested(),
        },
        reachableCells: <int>{},
        minTargetSize: 96,
        steadiness: 0.5,
        holdCapable: false,
        clarity: SpeechClarity.none,
        vision: VisionMode.screen,
        visualField: VisualField.full,
        inputLevel: InputLevel.one,
        vocabulary: const [],
        locale: 'en',
        label: 'Uncalibrated',
      );

  final Map<TouchMethod, MethodScore> methodScores;

  /// Indices into a [reachGridCols] x [reachGridRows] grid that the user hit
  /// reliably -- both a single confirming tap (tentative) and a
  /// second-tap-to-lock (see [lockedCells]) count as reachable. Drives where
  /// input surfaces are anchored and -- the inverse -- which strip of screen
  /// is safe to use for output.
  final Set<int> reachableCells;

  /// Subset of [reachableCells] the user tapped a *second* time during the
  /// Reach step, confirming it rather than leaving it as a one-tap tentative
  /// guess. Higher-confidence than the plain union -- a follow-up consumer
  /// (e.g. where Buttons/Hold place their targets) can prefer this over
  /// [reachableCells] when it wants only confirmed cells.
  final Set<int> lockedCells;

  final double minTargetSize;
  final double steadiness;
  final bool holdCapable;

  /// How many distinct buttons [ButtonsStep] confirmed tappable, and how many
  /// of those [HoldStep] also confirmed holdable -- e.g. 5 tappable, 2 also
  /// holdable. Zero on a skipped/floor-case run, same as any other untested
  /// axis. See [usableInputCount].
  final int tappableButtonCount;
  final int holdableButtonCount;
  final SpeechClarity clarity;
  final VisionMode vision;
  final VisualField visualField;

  /// How many discrete targets to show at once. Starts at [InputLevel.one]
  /// after calibration; the user levels up (issue #1).
  final InputLevel inputLevel;

  /// Words this person can say and have recognized (issue #3). Empty when
  /// unused. Size can be 2 or 160 — mapping switches on option count.
  final List<String> vocabulary;

  /// Onboarding-audio / script locale (`en`, `ml`). Recorded clips do not
  /// localize for free; this is the key they are looked up under.
  final String locale;

  /// Which environments this session measured -- chosen on the calibration
  /// intro, at least one always true. An axis left off stays untested, the
  /// same status as any other skipped step; it never reads as a failure.
  final bool measureMotor;
  final bool measureSpeech;
  final bool measureVision;

  /// Reachable-cell index the joystick swing test found steadiest, or null
  /// when untested / nothing reached 6 of 8 octants anywhere.
  final int? joystickHomeCell;

  final String label;

  static const int reachGridCols = 3;
  static const int reachGridRows = 4;
  static const int reachCellCount = reachGridCols * reachGridRows;

  bool get speechAvailable => clarity != SpeechClarity.none;

  /// Middle voice tier: some words, not free dictation. Issue #3.
  bool get usesWordVocab =>
      vocabulary.isNotEmpty &&
      clarity != SpeechClarity.full &&
      clarity != SpeechClarity.none;

  /// Discrete lists show this many options, capped by both the level-up
  /// path and the measured [maxControls].
  int get visibleOptionCount {
    final cap = inputLevel.optionCap;
    if (inputLevel == InputLevel.many) return maxControls;
    return cap.clamp(1, maxControls);
  }

  double scoreOf(TouchMethod m) => methodScores[m]?.score ?? 0;

  /// A holdable button contributes both a tap-input and a hold-input, so
  /// 5 tappable + 2 also-holdable is 7 usable inputs, not 5.
  int get usableInputCount => tappableButtonCount + holdableButtonCount;

  /// The user's genuine best method -- a relative comparison, never a threshold
  /// (3.3: an absolute cutoff would call everything non-viable for a user whose
  /// best is mediocre).
  TouchMethod get bestMethod {
    var best = TouchMethod.buttons;
    for (final m in TouchMethod.values) {
      if (scoreOf(m) > scoreOf(best)) best = m;
    }
    return best;
  }

  /// docs/idea/02-core-model.md 2.3 -- how many controls to show at once.
  int get maxControls {
    final s = scoreOf(bestMethod);
    if (s >= 0.75) return 6;
    if (s >= 0.55) return 4;
    if (s >= 0.35) return 3;
    return 2;
  }

  /// Bounding box of the reachable cells, in a [size]-sized screen. Falls back
  /// to the lower half of the screen when nothing was calibrated.
  Rect reachableRect(Size size) {
    if (reachableCells.isEmpty) {
      return Rect.fromLTWH(0, size.height / 2, size.width, size.height / 2);
    }
    var minCol = reachGridCols, maxCol = -1, minRow = reachGridRows, maxRow = -1;
    for (final i in reachableCells) {
      final col = i % reachGridCols, row = i ~/ reachGridCols;
      minCol = math.min(minCol, col);
      maxCol = math.max(maxCol, col);
      minRow = math.min(minRow, row);
      maxRow = math.max(maxRow, row);
    }
    final cw = size.width / reachGridCols, ch = size.height / reachGridRows;
    return Rect.fromLTRB(
        minCol * cw, minRow * ch, (maxCol + 1) * cw, (maxRow + 1) * ch);
  }

  /// Where a floating surface (the joystick overlay) should sit: the centre of
  /// the reachable area, expressed as an [Alignment].
  Alignment get reachAnchor {
    if (reachableCells.isEmpty) return const Alignment(0, 0.6);
    var sx = 0.0, sy = 0.0;
    for (final i in reachableCells) {
      sx += ((i % reachGridCols) + 0.5) / reachGridCols;
      sy += ((i ~/ reachGridCols) + 0.5) / reachGridRows;
    }
    final n = reachableCells.length;
    return Alignment((sx / n) * 2 - 1, (sy / n) * 2 - 1);
  }

  /// The answer to "where do we put output the user cannot reach anyway": the
  /// grid row with the fewest reachable cells, and among equals the one
  /// furthest from where the hand actually works -- so output never crowds the
  /// input area even when several rows are equally unreachable.
  /// Returns 0 for the top strip, [reachGridRows] - 1 for the bottom.
  int get outputRow {
    if (reachableCells.isEmpty) return 0;
    final centroidRow = reachableCells
            .map((i) => i ~/ reachGridCols)
            .reduce((a, b) => a + b) /
        reachableCells.length;

    var bestRow = 0;
    var bestCount = reachGridCols + 1;
    var bestDistance = -1.0;
    for (var row = 0; row < reachGridRows; row++) {
      var count = 0;
      for (var col = 0; col < reachGridCols; col++) {
        if (reachableCells.contains(row * reachGridCols + col)) count++;
      }
      final distance = (row - centroidRow).abs();
      if (count < bestCount || (count == bestCount && distance > bestDistance)) {
        bestCount = count;
        bestDistance = distance;
        bestRow = row;
      }
    }
    return bestRow;
  }

  bool get outputAtBottom => outputRow >= reachGridRows - 1;

  /// Where the joystick overlay should float: the swing test's own home cell
  /// when it found one, otherwise the reachable area's centroid.
  Alignment get joystickAnchor {
    final cell = joystickHomeCell;
    if (cell == null) return reachAnchor;
    final col = cell % reachGridCols, row = cell ~/ reachGridCols;
    return Alignment(
      ((col + 0.5) / reachGridCols) * 2 - 1,
      ((row + 0.5) / reachGridRows) * 2 - 1,
    );
  }

  /// 0..1 versions of the three measured axes, for the haiku theme blend --
  /// a depiction of the measured mix, not a diagnosis.
  double get motorScore01 => measureMotor
      ? TouchMethod.values.map(scoreOf).reduce(math.max).clamp(0.0, 1.0)
      : 0.0;
  double get speechScore01 => measureSpeech
      ? switch (clarity) {
          SpeechClarity.full => 1.0,
          SpeechClarity.partial => 0.65,
          SpeechClarity.sounds => 0.35,
          SpeechClarity.none => 0.0,
        }
      : 0.0;
  double get visionScore01 => measureVision
      ? switch (vision) {
          VisionMode.screen => 1.0,
          VisionMode.large => 0.55,
          VisionMode.none => 0.2,
        }
      : 0.0;

  /// The measured mix, as a theme. See [HaikuTheme] for what this is and
  /// (deliberately) is not.
  HaikuTheme get haikuTheme => HaikuTheme.compute(
        motor: measureMotor,
        speech: measureSpeech,
        vision: measureVision,
        motorScore: motorScore01,
        speechScore: speechScore01,
        visionScore: visionScore01,
      );

  CapabilityProfile copyWith({
    Map<TouchMethod, MethodScore>? methodScores,
    Set<int>? reachableCells,
    Set<int>? lockedCells,
    double? minTargetSize,
    double? steadiness,
    bool? holdCapable,
    int? tappableButtonCount,
    int? holdableButtonCount,
    SpeechClarity? clarity,
    VisionMode? vision,
    bool? measureMotor,
    bool? measureSpeech,
    bool? measureVision,
    int? joystickHomeCell,
    VisualField? visualField,
    InputLevel? inputLevel,
    List<String>? vocabulary,
    String? locale,
    String? label,
  }) =>
      CapabilityProfile(
        methodScores: methodScores ?? this.methodScores,
        reachableCells: reachableCells ?? this.reachableCells,
        lockedCells: lockedCells ?? this.lockedCells,
        minTargetSize: minTargetSize ?? this.minTargetSize,
        steadiness: steadiness ?? this.steadiness,
        holdCapable: holdCapable ?? this.holdCapable,
        tappableButtonCount: tappableButtonCount ?? this.tappableButtonCount,
        holdableButtonCount: holdableButtonCount ?? this.holdableButtonCount,
        clarity: clarity ?? this.clarity,
        vision: vision ?? this.vision,
        measureMotor: measureMotor ?? this.measureMotor,
        measureSpeech: measureSpeech ?? this.measureSpeech,
        measureVision: measureVision ?? this.measureVision,
        joystickHomeCell: joystickHomeCell ?? this.joystickHomeCell,
        visualField: visualField ?? this.visualField,
        inputLevel: inputLevel ?? this.inputLevel,
        vocabulary: vocabulary ?? this.vocabulary,
        locale: locale ?? this.locale,
        label: label ?? this.label,
      );

  /// Compact one-line form, for the output strip and for eyeballing the profile
  /// while demoing.
  String get summary {
    final scores = TouchMethod.values
        .map((m) => '${m.shortLabel} ${scoreOf(m).toStringAsFixed(2)}')
        .join('  ');
    return '$scores | reach ${reachableCells.length}/$reachCellCount '
        '| target ${minTargetSize.round()}dp | voice ${clarity.label} '
        '| vision ${vision.label} ${visualField.label} '
        '| level ${inputLevel.label}'
        '${vocabulary.isEmpty ? '' : ' | vocab ${vocabulary.length}'}';
  }

  Map<String, dynamic> toJson() => {
        'label': label,
        'methodScores': {
          for (final e in methodScores.entries) e.key.name: e.value.toJson(),
        },
        'reachableCells': reachableCells.toList(),
        'lockedCells': lockedCells.toList(),
        'minTargetSize': minTargetSize,
        'steadiness': steadiness,
        'holdCapable': holdCapable,
        'tappableButtonCount': tappableButtonCount,
        'holdableButtonCount': holdableButtonCount,
        'clarity': clarity.name,
        'vision': vision.name,
        'visualField': visualField.name,
        'inputLevel': inputLevel.name,
        'vocabulary': vocabulary,
        'locale': locale,
        'measureMotor': measureMotor,
        'measureSpeech': measureSpeech,
        'measureVision': measureVision,
        'joystickHomeCell': joystickHomeCell,
      };

  factory CapabilityProfile.fromJson(Map<String, dynamic> j) {
    final rawScores = (j['methodScores'] as Map?)?.cast<String, dynamic>() ?? {};
    final scores = <TouchMethod, MethodScore>{
      for (final m in TouchMethod.values)
        m: rawScores[m.name] is Map
            ? MethodScore.fromJson(
                (rawScores[m.name] as Map).cast<String, dynamic>(),
              )
            : const MethodScore.untested(),
    };
    return CapabilityProfile(
      label: j['label'] as String? ?? 'Calibrated',
      methodScores: scores,
      reachableCells: {
        for (final n in (j['reachableCells'] as List? ?? const []))
          (n as num).toInt(),
      },
      lockedCells: {
        for (final n in (j['lockedCells'] as List? ?? const []))
          (n as num).toInt(),
      },
      minTargetSize: (j['minTargetSize'] as num?)?.toDouble() ?? 96,
      steadiness: (j['steadiness'] as num?)?.toDouble() ?? 0.5,
      holdCapable: j['holdCapable'] as bool? ?? false,
      tappableButtonCount: (j['tappableButtonCount'] as num?)?.toInt() ?? 0,
      holdableButtonCount: (j['holdableButtonCount'] as num?)?.toInt() ?? 0,
      clarity: SpeechClarity.values.firstWhere(
        (v) => v.name == j['clarity'],
        orElse: () => SpeechClarity.none,
      ),
      vision: VisionMode.values.firstWhere(
        (v) => v.name == j['vision'],
        orElse: () => VisionMode.screen,
      ),
      visualField: VisualField.values.firstWhere(
        (v) => v.name == j['visualField'],
        orElse: () => VisualField.full,
      ),
      inputLevel: InputLevel.values.firstWhere(
        (v) => v.name == j['inputLevel'],
        orElse: () => InputLevel.one,
      ),
      vocabulary: [
        for (final w in (j['vocabulary'] as List? ?? const [])) w.toString(),
      ],
      locale: j['locale'] as String? ?? 'en',
      measureMotor: j['measureMotor'] as bool? ?? true,
      measureSpeech: j['measureSpeech'] as bool? ?? true,
      measureVision: j['measureVision'] as bool? ?? true,
      joystickHomeCell: (j['joystickHomeCell'] as num?)?.toInt(),
    );
  }
}
