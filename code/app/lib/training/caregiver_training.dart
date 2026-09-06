import 'package:flutter/material.dart';

import '../onboarding/recorded_voice.dart';

/// Prompt-fading phases, most-to-least (research 12 §2).
enum PromptPhase { fullPhysical, partialPhysical, independent }

extension PromptPhaseCopy on PromptPhase {
  String get title => switch (this) {
        PromptPhase.fullPhysical => 'Together',
        PromptPhase.partialPhysical => 'Start together, finish alone',
        PromptPhase.independent => 'From the words alone',
      };

  String get caregiver => switch (this) {
        PromptPhase.fullPhysical =>
          'Hand under theirs (gentler). Move through the motion together. '
          'Hand-over-hand only if they cannot start it at all.',
        PromptPhase.partialPhysical =>
          'Start the motion with them, then let go. They finish it.',
        PromptPhase.independent =>
          'Say the instruction. Do not touch. Watch whether the motion comes.',
      };

  PromptPhase? get next => switch (this) {
        PromptPhase.fullPhysical => PromptPhase.partialPhysical,
        PromptPhase.partialPhysical => PromptPhase.independent,
        PromptPhase.independent => null,
      };
}

class _Drill {
  const _Drill({
    required this.id,
    required this.instruction,
    required this.kind,
  });

  final String id;
  final String instruction;
  final _DrillKind kind;
}

enum _DrillKind { tap, dragLeft, dragUp }

const _drills = <_Drill>[
  _Drill(id: 'tap', instruction: 'Tap the square.', kind: _DrillKind.tap),
  _Drill(
    id: 'left',
    instruction: 'Slide left.',
    kind: _DrillKind.dragLeft,
  ),
  _Drill(
    id: 'up',
    instruction: 'Slide up.',
    kind: _DrillKind.dragUp,
  ),
];

/// Caregiver-guided training. No scores, no timeout. One motion at a time.
/// Graduation is per drill: three independent successes, then the next drill.
/// Issue #2 / research 12.
class CaregiverTraining extends StatefulWidget {
  const CaregiverTraining({
    super.key,
    required this.onDone,
    required this.onSkipAll,
    this.locale = 'en',
  });

  final VoidCallback onDone;
  final VoidCallback onSkipAll;
  final String locale;

  @override
  State<CaregiverTraining> createState() => _CaregiverTrainingState();
}

class _CaregiverTrainingState extends State<CaregiverTraining> {
  int _drill = 0;
  PromptPhase _phase = PromptPhase.fullPhysical;
  int _independentHits = 0;
  int _tries = 0;

  static const _need = 3;

  _Drill get _current => _drills[_drill];

  void _succeed() {
    setState(() {
      _tries++;
      if (_phase == PromptPhase.independent) {
        _independentHits++;
        if (_independentHits >= _need) {
          _graduateDrill();
          return;
        }
      } else {
        final next = _phase.next;
        if (next != null) _phase = next;
      }
    });
  }

  void _graduateDrill() {
    if (_drill >= _drills.length - 1) {
      widget.onDone();
      return;
    }
    _drill++;
    _phase = PromptPhase.fullPhysical;
    _independentHits = 0;
    _tries = 0;
  }

  void _again() => setState(() => _tries++);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            children: [
              Text(
                'Practice with a helper',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'No score. Repeat until the instruction and the motion belong '
                'together. Then we measure precision — a different question.',
                style: TextStyle(color: scheme.onSurfaceVariant, height: 1.35),
              ),
              const SizedBox(height: 10),
              RecordedNarration(clipId: 'training', locale: widget.locale),
              const SizedBox(height: 12),
              Text(
                'Motion ${_drill + 1} of ${_drills.length} · ${_phase.title}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _current.instruction,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                _phase.caregiver,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              if (_phase == PromptPhase.independent)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Independent: $_independentHits of $_need',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: scheme.primary,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              SizedBox(height: 200, child: _arena(scheme)),
              const SizedBox(height: 8),
              OutlinedButton(onPressed: _again, child: const Text('Try again')),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => setState(_graduateDrill),
                child: const Text('Skip this motion'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: TextButton(
            onPressed: widget.onSkipAll,
            child: const Text(
              'Skip all practice, go to measurement',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }

  Widget _arena(ColorScheme scheme) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _current.kind == _DrillKind.tap ? _succeed : null,
      onPanEnd: (d) {
        final v = d.velocity.pixelsPerSecond;
        if (_current.kind == _DrillKind.dragLeft && v.dx < -180) {
          _succeed();
        } else if (_current.kind == _DrillKind.dragUp && v.dy < -180) {
          _succeed();
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: scheme.outlineVariant),
        ),
        alignment: Alignment.center,
        child: _current.kind == _DrillKind.tap
            ? Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(18),
                ),
                alignment: Alignment.center,
                child: Text(
                  'TAP',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: scheme.onPrimary,
                  ),
                ),
              )
            : Text(
                _current.kind == _DrillKind.dragLeft
                    ? '←  slide this way'
                    : '↑  slide this way',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
      ),
    );
  }
}
