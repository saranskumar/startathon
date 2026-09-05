import 'package:flutter/material.dart';

import '../model/profile.dart';
import '../runtime/task_spec.dart';
import 'step_frame.dart';

/// What calibration produced, in the user's terms and in the system's.
///
/// The score table is shown rather than hidden because the whole claim of the
/// project is that a person is a set of measurements, not a label -- and
/// because a demo that shows the numbers can be argued with, which a demo that
/// shows a verdict cannot.
class CalibrationResults extends StatelessWidget {
  const CalibrationResults({
    super.key,
    required this.draft,
    required this.onUse,
    required this.onRedo,
  });

  final CalibrationDraft draft;
  final VoidCallback onUse;
  final VoidCallback onRedo;

  @override
  Widget build(BuildContext context) {
    final profile = draft.build();
    final scheme = Theme.of(context).colorScheme;
    final scale = profile.vision.textScale;

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your setup',
                  style: TextStyle(
                    fontSize: 26 * scale,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Nothing here is a diagnosis. It is what the tests measured, '
                  'and it can be redone at any time.',
                  style: TextStyle(
                    fontSize: 13 * scale,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              children: [
                _section(scheme, scale, 'Touch methods'),
                for (final m in TouchMethod.values)
                  _scoreRow(scheme, scale, m, profile),
                const SizedBox(height: 18),
                _section(scheme, scale, 'Other axes'),
                _fact(scheme, scale, 'Reachable area',
                    '${profile.reachableCells.length} of '
                    '${CapabilityProfile.reachCellCount} zones'),
                _fact(scheme, scale, 'Smallest reliable target',
                    '${profile.minTargetSize.round()} dp'),
                _fact(scheme, scale, 'Steadiness',
                    profile.steadiness.toStringAsFixed(2)),
                _fact(scheme, scale, 'Touch and hold',
                    profile.holdCapable ? 'usable' : 'not usable'),
                _fact(scheme, scale, 'Voice',
                    '${profile.clarity.label} -- ${profile.clarity.grants}'),
                _fact(scheme, scale, 'Vision', profile.vision.label),
                if (draft.axisLock != null)
                  _fact(
                    scheme,
                    scale,
                    'Swipe axis',
                    draft.axisLock == Axis.horizontal
                        ? 'left-right only'
                        : 'up-down only',
                  ),
                if (draft.skipped.isNotEmpty)
                  _fact(scheme, scale, 'Skipped',
                      draft.skipped.join(', ')),
                const SizedBox(height: 18),
                _section(scheme, scale, 'What each task will use'),
                for (final shape in TaskShape.values)
                  _mappingRow(scheme, scale, shape, profile),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 64,
                    child: OutlinedButton(
                      onPressed: onRedo,
                      child: Text('Redo',
                          style: TextStyle(fontSize: 17 * scale)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 64,
                    child: FilledButton(
                      onPressed: onUse,
                      child: Text('Use this setup',
                          style: TextStyle(fontSize: 17 * scale)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(ColorScheme scheme, double scale, String title) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 11 * scale,
            letterSpacing: 1.4,
            fontWeight: FontWeight.w800,
            color: scheme.primary,
          ),
        ),
      );

  Widget _scoreRow(
    ColorScheme scheme,
    double scale,
    TouchMethod method,
    CapabilityProfile profile,
  ) {
    final s = profile.methodScores[method] ?? const MethodScore.untested();
    final isBest = profile.bestMethod == method && s.tested;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                method.label,
                style: TextStyle(
                  fontSize: 15 * scale,
                  fontWeight: isBest ? FontWeight.w800 : FontWeight.w500,
                ),
              ),
              if (isBest) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('strongest',
                      style: TextStyle(
                          fontSize: 10 * scale,
                          fontWeight: FontWeight.w700,
                          color: scheme.onPrimaryContainer)),
                ),
              ],
              const Spacer(),
              Text(
                s.tested ? s.score.toStringAsFixed(2) : 'untested',
                style: TextStyle(
                  fontSize: 15 * scale,
                  fontWeight: FontWeight.w700,
                  color: s.tested ? scheme.onSurface : scheme.outline,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: s.score.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: scheme.surfaceContainerHighest,
            ),
          ),
          if (s.tested)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                'hit ${(s.successRate * 100).round()}% | '
                'speed ${((1 - s.timeNormalized) * 100).round()}% | '
                'accuracy ${((1 - s.errorNormalized) * 100).round()}% | '
                '${s.attempts} tries',
                style: TextStyle(
                    fontSize: 11 * scale, color: scheme.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }

  Widget _fact(
          ColorScheme scheme, double scale, String label, String value) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 150 * scale.clamp(1.0, 1.2),
              child: Text(label,
                  style: TextStyle(
                      fontSize: 13 * scale, color: scheme.onSurfaceVariant)),
            ),
            Expanded(
              child: Text(value,
                  style: TextStyle(
                      fontSize: 13 * scale, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );

  Widget _mappingRow(
    ColorScheme scheme,
    double scale,
    TaskShape shape,
    CapabilityProfile profile,
  ) {
    final choice = chooseMethod(profile, shape);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(shape.label,
                    style: TextStyle(
                        fontSize: 14 * scale, fontWeight: FontWeight.w700)),
              ),
              Text(
                choice.method.label,
                style: TextStyle(
                  fontSize: 14 * scale,
                  fontWeight: FontWeight.w700,
                  color: choice.isFallback ? scheme.tertiary : scheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${choice.isFallback ? "fallback" : "ideal"}: '
            '${patternFor(shape, choice.method)}',
            style:
                TextStyle(fontSize: 12 * scale, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
