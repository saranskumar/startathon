import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../model/profile.dart';

/// One button [ButtonsStep] placed and confirmed as tappable, carried forward
/// so [HoldStep] can re-visit the exact same spot instead of an arbitrary one
/// -- see docs/idea/30 §8 ("5 tappable, 2 also holdable -> 7 usable inputs").
class ButtonTarget {
  ButtonTarget({required this.cell, required this.size, required this.placement});

  /// Reach-grid cell index the button sat in -- informational parity with
  /// [CalibrationDraft.reachableCells], not read by [HoldStep] directly.
  final int cell;
  final double size;
  final Alignment placement;

  /// null = not yet tested by [HoldStep] (including "step was skipped before
  /// reaching this button"); true/false = tested result. Nullable so an
  /// untested button never reads as a failed one, same rule as
  /// [CalibrationDraft.skipped].
  bool? holdable;
}

/// What the calibration steps write into as they run. Turned into a
/// [CapabilityProfile] by the results step.
class CalibrationDraft {
  final Map<TouchMethod, MethodScore> scores = {
    for (final m in TouchMethod.values) m: const MethodScore.untested(),
  };
  final Set<int> reachableCells = <int>{};

  /// Subset of [reachableCells] confirmed by a second tap during the Reach
  /// step (see [ReachStep]) rather than left as a one-tap tentative guess.
  final Set<int> lockedCells = <int>{};

  /// Buttons [ButtonsStep] confirmed as tappable, in placement order --
  /// [HoldStep] tests hold on each of these rather than one arbitrary spot.
  final List<ButtonTarget> tappableButtons = <ButtonTarget>[];

  double minTargetSize = 96;
  double steadiness = 0.5;
  bool holdCapable = false;

  /// null = both axes usable; set when the trackpad test finds one axis is
  /// markedly worse (docs/idea/20 -- axis-limited swiping).
  Axis? axisLock;

  SpeechClarity clarity = SpeechClarity.none;
  VisionMode vision = VisionMode.screen;
  VisualField visualField = VisualField.full;
  InputLevel inputLevel = InputLevel.one;
  List<String> vocabulary = <String>[];
  String locale = 'en';

  /// Which environments this session measures, chosen on the intro screen.
  /// All three start on. Turning one off takes a hold, not a tap. An axis
  /// left off is untested, same status as a skipped step -- never a failed
  /// one. At least one stays on (the last remaining row cannot be skipped).
  bool measureMotor = true;
  bool measureSpeech = true;
  bool measureVision = true;

  /// True when a friend/helper picked the axes above and handed the phone
  /// back, rather than the tested person choosing for themselves. Does not
  /// change scoring -- it is provenance, not a different profile shape.
  bool helperChoseAxes = false;

  /// Reachable-cell index the joystick was steadiest at, from the per-cell
  /// swing test (see JoystickStep) -- where the stick should be docked at
  /// runtime. Null when untested or every cell failed.
  int? joystickHomeCell;

  /// Cell index -> how many of the 8 octants were reliably reached there
  /// (0..8), for the results screen and for picking [joystickHomeCell].
  final Map<int, int> joystickOctants = <int, int>{};

  /// Steps the user skipped or that timed out, for honesty on the results
  /// screen -- an untested method must not look like a failed one.
  final Set<String> skipped = <String>{};

  CapabilityProfile build() => CapabilityProfile(
        methodScores: Map.of(scores),
        reachableCells: Set.of(reachableCells),
        lockedCells: Set.of(lockedCells),
        tappableButtonCount: tappableButtons.length,
        holdableButtonCount:
            tappableButtons.where((t) => t.holdable == true).length,
        minTargetSize: minTargetSize,
        steadiness: steadiness,
        holdCapable: holdCapable,
        clarity: clarity,
        vision: vision,
        measureMotor: measureMotor,
        measureSpeech: measureSpeech,
        measureVision: measureVision,
        joystickHomeCell: joystickHomeCell,
        visualField: visualField,
        inputLevel: inputLevel,
        vocabulary: List.of(vocabulary),
        locale: locale,
        label: 'Calibrated',
      );
}

/// Shared chrome for every calibration step.
///
/// Four things here are deliberate rather than decorative:
///  * the instruction is one short line, always in the same place;
///  * "Skip this test" is always present and always the same size -- a user who
///    cannot operate the method under test must never be trapped by it;
///  * "Back" is the same size, opposite Skip, from the second test on -- a
///    mis-tap or a changed mind must not require Redo-from-the-start;
///  * progress is explicit, because an untimed sequence of unfamiliar tests is
///    the main reason people abandon calibration.
///
/// Headline copy is attempt-only (issue #8): lead with "Try to …" so a miss is
/// already valid data. Honesty must not live only in the secondary status line.
class StepFrame extends StatelessWidget {
  const StepFrame({
    super.key,
    required this.title,
    required this.instruction,
    required this.index,
    required this.total,
    required this.onSkip,
    required this.child,
    this.onBack,
    this.status,
    this.textScale = 1.0,
    this.minTargetSize = 56,
    this.footer,
    this.elapsedFraction,
  });

  final String title;
  final String instruction;
  final int index;
  final int total;
  final VoidCallback onSkip;

  /// When null (first test in the gated list), Skip stays full-width. Back
  /// into the axis picker is out of scope for this chrome.
  final VoidCallback? onBack;
  final Widget child;

  /// Live feedback ("2 of 4 done", "hold steady...").
  final String? status;
  final double textScale;

  /// Skip / Back control height follows what buttons calibration measured.
  final double minTargetSize;
  final Widget? footer;

  /// 0.0..1.0 through this *step's own* timed window (a per-round timeout,
  /// an idle-reset window), independent of the step-of-total bar above --
  /// see [TimedCue]. Null when the step has no timed window of its own.
  final ValueListenable<double>? elapsedFraction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final skipH = minTargetSize.clamp(56.0, 120.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Step ${index + 1} of $total',
                    style: TextStyle(
                      fontSize: 12 * textScale,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w700,
                      color: scheme.primary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12 * textScale,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: total == 0 ? 0 : (index + 1) / total,
                  minHeight: 6,
                ),
              ),
              if (elapsedFraction != null) ...[
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: ValueListenableBuilder<double>(
                    valueListenable: elapsedFraction!,
                    builder: (context, value, _) => LinearProgressIndicator(
                      value: value,
                      minHeight: 3,
                      color: scheme.tertiary,
                      backgroundColor: scheme.surfaceContainerHighest,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Text(
                instruction,
                style: TextStyle(
                  fontSize: 20 * textScale,
                  height: 1.25,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (status != null) ...[
                const SizedBox(height: 6),
                Text(
                  status!,
                  style: TextStyle(
                    fontSize: 14 * textScale,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        Expanded(child: child),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: footer!,
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
          child: SizedBox(
            height: skipH,
            width: double.infinity,
            child: Row(
              children: [
                if (onBack != null) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onBack,
                      icon: const Icon(Icons.arrow_back),
                      label: Text(
                        'Back',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 17 * textScale),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onSkip,
                    icon: const Icon(Icons.skip_next),
                    label: Text(
                      'Skip this test',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 17 * textScale),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
