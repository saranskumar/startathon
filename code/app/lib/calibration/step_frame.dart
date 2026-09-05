import 'package:flutter/material.dart';

import '../model/profile.dart';

/// What the calibration steps write into as they run. Turned into a
/// [CapabilityProfile] by the results step.
class CalibrationDraft {
  final Map<TouchMethod, MethodScore> scores = {
    for (final m in TouchMethod.values) m: const MethodScore.untested(),
  };
  final Set<int> reachableCells = <int>{};

  double minTargetSize = 96;
  double steadiness = 0.5;
  bool holdCapable = false;

  /// null = both axes usable; set when the trackpad test finds one axis is
  /// markedly worse (docs/idea/20 -- axis-limited swiping).
  Axis? axisLock;

  SpeechClarity clarity = SpeechClarity.none;
  VisionMode vision = VisionMode.screen;

  /// Steps the user skipped or that timed out, for honesty on the results
  /// screen -- an untested method must not look like a failed one.
  final Set<String> skipped = <String>{};

  CapabilityProfile build() => CapabilityProfile(
        methodScores: Map.of(scores),
        reachableCells: Set.of(reachableCells),
        minTargetSize: minTargetSize,
        steadiness: steadiness,
        holdCapable: holdCapable,
        clarity: clarity,
        vision: vision,
        label: 'Calibrated',
      );
}

/// Shared chrome for every calibration step.
///
/// Three things here are deliberate rather than decorative:
///  * the instruction is one short line, always in the same place;
///  * "Skip this test" is always present and always the same size -- a user who
///    cannot operate the method under test must never be trapped by it;
///  * progress is explicit, because an untimed sequence of unfamiliar tests is
///    the main reason people abandon calibration.
class StepFrame extends StatelessWidget {
  const StepFrame({
    super.key,
    required this.title,
    required this.instruction,
    required this.index,
    required this.total,
    required this.onSkip,
    required this.child,
    this.status,
    this.textScale = 1.0,
    this.footer,
  });

  final String title;
  final String instruction;
  final int index;
  final int total;
  final VoidCallback onSkip;
  final Widget child;

  /// Live feedback ("2 of 4 done", "hold steady...").
  final String? status;
  final double textScale;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
            height: 64,
            child: OutlinedButton.icon(
              onPressed: onSkip,
              icon: const Icon(Icons.skip_next),
              label: Text(
                "Skip this test",
                style: TextStyle(fontSize: 17 * textScale),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
