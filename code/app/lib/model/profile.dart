import 'dart:math' as math;
import 'package:flutter/painting.dart';

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
        SpeechClarity.sounds => 'sound-count vocabulary: 1 sound yes, 2 no',
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
}

/// docs/idea/02-core-model.md 2.3 -- the one object everything runs off.
class CapabilityProfile {
  CapabilityProfile({
    required this.methodScores,
    required this.reachableCells,
    required this.minTargetSize,
    required this.steadiness,
    required this.holdCapable,
    required this.clarity,
    required this.vision,
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
        label: 'Uncalibrated',
      );

  final Map<TouchMethod, MethodScore> methodScores;

  /// Indices into a [reachGridCols] x [reachGridRows] grid that the user hit
  /// reliably. Drives where input surfaces are anchored and -- the inverse --
  /// which strip of screen is safe to use for output.
  final Set<int> reachableCells;

  final double minTargetSize;
  final double steadiness;
  final bool holdCapable;
  final SpeechClarity clarity;
  final VisionMode vision;
  final String label;

  static const int reachGridCols = 3;
  static const int reachGridRows = 4;
  static const int reachCellCount = reachGridCols * reachGridRows;

  bool get speechAvailable => clarity != SpeechClarity.none;

  double scoreOf(TouchMethod m) => methodScores[m]?.score ?? 0;

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

  CapabilityProfile copyWith({
    Map<TouchMethod, MethodScore>? methodScores,
    Set<int>? reachableCells,
    double? minTargetSize,
    double? steadiness,
    bool? holdCapable,
    SpeechClarity? clarity,
    VisionMode? vision,
    String? label,
  }) =>
      CapabilityProfile(
        methodScores: methodScores ?? this.methodScores,
        reachableCells: reachableCells ?? this.reachableCells,
        minTargetSize: minTargetSize ?? this.minTargetSize,
        steadiness: steadiness ?? this.steadiness,
        holdCapable: holdCapable ?? this.holdCapable,
        clarity: clarity ?? this.clarity,
        vision: vision ?? this.vision,
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
        '| vision ${vision.label}';
  }
}
