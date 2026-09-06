import 'package:flutter/material.dart';

import '../inputs/voice_modes.dart';
import '../model/profile.dart';
import '../runtime/task_spec.dart';
import '../theme/haiku_theme.dart';
import 'step_frame.dart';

/// The four groups the results are split into, so the screen is a small
/// set of focused sections you jump between, not one long scroll -- "Your
/// setup" is a report to read through, and a report is easier to navigate in
/// pages than in one continuous scroll.
enum _Section { overview, methods, voice, tasks }

extension on _Section {
  String get label => switch (this) {
        _Section.overview => 'Overview',
        _Section.methods => 'Methods',
        _Section.voice => 'Voice & text',
        _Section.tasks => 'Tasks',
      };

  IconData get icon => switch (this) {
        _Section.overview => Icons.dashboard_outlined,
        _Section.methods => Icons.speed,
        _Section.voice => Icons.record_voice_over_outlined,
        _Section.tasks => Icons.checklist,
      };
}

/// What calibration produced, in the user's terms and in the system's.
///
/// The score table is shown rather than hidden because the whole claim of the
/// project is that a person is a set of measurements, not a label -- and
/// because a demo that shows the numbers can be argued with, which a demo that
/// shows a verdict cannot.
class CalibrationResults extends StatefulWidget {
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
  State<CalibrationResults> createState() => _CalibrationResultsState();
}

class _CalibrationResultsState extends State<CalibrationResults> {
  _Section _section = _Section.overview;

  CalibrationDraft get draft => widget.draft;

  @override
  Widget build(BuildContext context) {
    final profile = draft.build();
    final scheme = Theme.of(context).colorScheme;
    final scale = profile.vision.textScale;
    final haiku = profile.haikuTheme;
    final target = profile.minTargetSize.clamp(56.0, 120.0);

    return SafeArea(
      child: Column(
        children: [
          Stack(
            children: [
              Positioned.fill(child: HaikuMotif(color: haiku.seedColor)),
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
                      'and it can be redone at any time. This report already uses '
                      'your measured size and field.',
                      style: TextStyle(
                        fontSize: 13 * scale,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: _sectionNav(scheme, scale, target),
          ),
          Expanded(
            child: ListView(
              key: ValueKey(_section),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              children: switch (_section) {
                _Section.overview => [
                    _section_(scheme, scale, 'Measured environments'),
                    _axesRow(scheme, scale, profile),
                    if (draft.helperChoseAxes)
                      _fact(scheme, scale, 'Chosen by',
                          'someone helping, not the person tested'),
                    const SizedBox(height: 18),
                    _section_(scheme, scale, 'This mix'),
                    _haikuCard(scheme, scale, haiku),
                  ],
                _Section.methods => [
                    _section_(scheme, scale, 'Touch methods'),
                    for (final m in TouchMethod.values)
                      _scoreRow(scheme, scale, m, profile),
                    const SizedBox(height: 18),
                    _section_(scheme, scale, 'Other axes'),
                    _fact(scheme, scale, 'Reachable area',
                        '${profile.reachableCells.length} of '
                        '${CapabilityProfile.reachCellCount} zones'),
                    _fact(scheme, scale, 'Joystick home',
                        profile.joystickHomeCell == null
                            ? 'not placed'
                            : 'zone ${profile.joystickHomeCell} -- '
                                '${draft.joystickOctants[profile.joystickHomeCell] ?? 0} of 8 directions'),
                    _fact(scheme, scale, 'Smallest reliable target',
                        '${profile.minTargetSize.round()} dp'),
                    _fact(scheme, scale, 'Steadiness',
                        profile.steadiness.toStringAsFixed(2)),
                    _fact(scheme, scale, 'Touch and hold',
                        profile.holdCapable ? 'usable' : 'not usable'),
                    _fact(scheme, scale, 'Voice',
                        '${profile.clarity.label} -- ${profile.clarity.grants}'),
                    _fact(scheme, scale, 'Vision',
                        '${profile.vision.label} · ${profile.visualField.label}'),
                    _fact(scheme, scale, 'Input level', profile.inputLevel.label),
                    if (profile.vocabulary.isNotEmpty)
                      _fact(scheme, scale, 'Personal words',
                          profile.vocabulary.join(', ')),
                  ],
                _Section.voice => [
                    _section_(scheme, scale, 'Voice and text plan'),
                    _voicePlan(scheme, scale, profile),
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
                      _fact(scheme, scale, 'Skipped', draft.skipped.join(', ')),
                  ],
                _Section.tasks => [
                    _section_(scheme, scale, 'What each task will use'),
                    for (final shape in TaskShape.values)
                      _mappingRow(scheme, scale, shape, profile),
                  ],
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
            child: target >= 96
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: target,
                        child: FilledButton(
                          onPressed: widget.onUse,
                          child: Text('Use this setup',
                              style: TextStyle(fontSize: 17 * scale)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: target,
                        child: OutlinedButton(
                          onPressed: widget.onRedo,
                          child: Text('Redo',
                              style: TextStyle(fontSize: 17 * scale)),
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: target,
                          child: OutlinedButton(
                            onPressed: widget.onRedo,
                            child: Text('Redo',
                                style: TextStyle(fontSize: 17 * scale)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: SizedBox(
                          height: target,
                          child: FilledButton(
                            onPressed: widget.onUse,
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

  /// Four large, always-visible buttons -- not a swipeable tab strip, so
  /// jumping to a section is one direct tap, sized and reachable the same
  /// way every other control in this app is.
  Widget _sectionNav(ColorScheme scheme, double scale, double target) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final s in _Section.values)
            InkWell(
              onTap: () => setState(() => _section = s),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                constraints: BoxConstraints(minHeight: target.clamp(44.0, 72.0)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: s == _section
                      ? scheme.primary
                      : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: s == _section ? scheme.primary : scheme.outlineVariant,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(s.icon,
                        size: 18,
                        color: s == _section ? scheme.onPrimary : scheme.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Text(
                      s.label,
                      style: TextStyle(
                        fontSize: 13 * scale,
                        fontWeight: FontWeight.w700,
                        color: s == _section ? scheme.onPrimary : scheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );

  Widget _axesRow(ColorScheme scheme, double scale, CapabilityProfile profile) {
    Widget chip(String label, Color color, bool on) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: on
                ? color.withValues(alpha: 0.18)
                : scheme.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: on ? color : scheme.outlineVariant),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              ),
              const SizedBox(width: 6),
              Text(
                on ? label : '$label (not measured)',
                style: TextStyle(
                  fontSize: 12 * scale,
                  fontWeight: FontWeight.w700,
                  color: on ? scheme.onSurface : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          chip('Motor', HaikuTheme.motorSeed, profile.measureMotor),
          chip('Speech', HaikuTheme.speechSeed, profile.measureSpeech),
          chip('Vision', HaikuTheme.visionSeed, profile.measureVision),
        ],
      ),
    );
  }

  /// Score, emotion, value, and a decorative blessing -- four different ways
  /// of saying the same measured mix, never a verdict.
  Widget _haikuCard(ColorScheme scheme, double scale, HaikuTheme haiku) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: haiku.seedColor.withValues(alpha: 0.10),
          border: Border.all(color: haiku.seedColor.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              haiku.emotion.toUpperCase(),
              style: TextStyle(
                fontSize: 12 * scale,
                letterSpacing: 1.3,
                fontWeight: FontWeight.w800,
                color: haiku.seedColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              haiku.value,
              style: TextStyle(fontSize: 14 * scale, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Text(
              haiku.blessing,
              style: TextStyle(
                fontSize: 13 * scale,
                fontStyle: FontStyle.italic,
                height: 1.5,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );

  Widget _section_(ColorScheme scheme, double scale, String title) => Padding(
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

  Widget _voicePlan(
    ColorScheme scheme,
    double scale,
    CapabilityProfile profile,
  ) {
    final mode = textComposeModeFor(profile.clarity);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              mode.title,
              style: TextStyle(
                fontSize: 16 * scale,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              mode.detail,
              style: TextStyle(
                fontSize: 13 * scale,
                color: scheme.onSurfaceVariant,
              ),
            ),
            if (profile.usesWordVocab) ...[
              const SizedBox(height: 10),
              Text(
                profile.vocabulary.length <= 3
                    ? 'Your words map onto the choices when the menu is small, '
                        'or become next / previous / select when it is long.'
                    : 'A menu no bigger than your word list uses those words '
                        'as the choices. A longer menu uses the first three '
                        'as next, previous, and select.',
                style: TextStyle(
                  fontSize: 12 * scale,
                  color: scheme.primary,
                ),
              ),
            ],
            if (mode == TextComposeMode.vocalConfirm) ...[
              const SizedBox(height: 10),
              Text(
                'Nod = short yes · Sound = yes · Hum = long yes · '
                'Two sounds = next phrase',
                style: TextStyle(
                  fontSize: 12 * scale,
                  color: scheme.primary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

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
