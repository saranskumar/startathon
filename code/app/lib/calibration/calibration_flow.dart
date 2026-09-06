import 'dart:async';

import 'package:flutter/material.dart';

import '../model/profile.dart';
import '../onboarding/recorded_voice.dart';
import '../theme/haiku_theme.dart';
import '../training/caregiver_training.dart';
import 'results.dart';
import 'sense_steps.dart';
import 'step_frame.dart';
import 'touch_steps.dart';

/// One test in the gated sequence -- which of these run is decided by the
/// intro's Motor / Speech / Vision toggles, not fixed at seven.
enum _StepKind { reach, buttons, hold, joystick, trackpad, voice, vision }

/// The whole calibration sequence.
///
/// Two rules shape it, and they are the reason it is a flow rather than a form:
///
///  1. **No step may be a trap.** Every test can be skipped with one large
///     control, and every test gives up on its own if the user cannot do it.
///     Someone who can operate none of the methods still reaches the end --
///     they arrive with a low-score profile, which is a real answer, not an
///     error state.
///  2. **Nothing is asked twice.** Reach is measured once and then reused to
///     place the button test, so precision is not scored down by a target the
///     user simply could not get to.
class CalibrationFlow extends StatefulWidget {
  const CalibrationFlow({
    super.key,
    required this.onComplete,
    this.onAxesChanged,
    this.startAssisted = false,
    this.locale = 'en',
  });

  final void Function(CapabilityProfile profile) onComplete;
  final bool startAssisted;
  final String locale;

  /// Fired the instant the intro's Motor / Speech / Vision toggles change, so
  /// the app-wide theme can react before any test has produced a score.
  final void Function(bool motor, bool speech, bool vision)? onAxesChanged;

  @override
  State<CalibrationFlow> createState() => _CalibrationFlowState();
}

class _CalibrationFlowState extends State<CalibrationFlow> {
  /// If nothing at all is registered for this long, the step gives up. This is
  /// what lets a user with no usable touch reach the end of calibration.
  static const _idleLimit = Duration(seconds: 20);

  final CalibrationDraft _draft = CalibrationDraft();

  /// -3 = caregiver training, -2 = universal entry,
  /// -1 = axis picker, 0.._stepCount-1 = tests, _stepCount = results.
  /// Populated once the axis picker's Start is pressed, from whichever axes
  /// are still on.
  List<_StepKind> _steps = const [];
  int get _stepCount => _steps.length;

  int _step = -2;
  int _consecutiveIdleSkips = 0;
  Timer? _idle;
  String? _toast;

  @override
  void initState() {
    super.initState();
    _draft.locale = widget.locale;
    if (widget.startAssisted) {
      _draft.helperChoseAxes = true;
      _step = -3;
    }
    widget.onAxesChanged?.call(
      _draft.measureMotor,
      _draft.measureSpeech,
      _draft.measureVision,
    );
  }

  @override
  void dispose() {
    _idle?.cancel();
    super.dispose();
  }

  void _armIdle() {
    _idle?.cancel();
    if (_step < 0 || _step >= _stepCount) return;
    _idle = Timer(_idleLimit, _idleSkip);
  }

  void _pokeIdle() {
    _consecutiveIdleSkips = 0;
    _armIdle();
  }

  void _idleSkip() {
    if (!mounted) return;
    _consecutiveIdleSkips++;
    _draft.skipped.add('idle:$_step');
    _showToast(
      _consecutiveIdleSkips >= 3
          ? 'Still nothing registering. Skipping to the end -- we will use '
              'the most forgiving setup.'
          : 'No input detected. Moving on -- that is fine.',
    );
    if (_consecutiveIdleSkips >= 3) {
      setState(() => _step = _stepCount);
      _idle?.cancel();
    } else {
      _next();
    }
  }

  void _showToast(String message) {
    setState(() => _toast = message);
    Timer(const Duration(seconds: 4), () {
      if (mounted && _toast == message) setState(() => _toast = null);
    });
  }

  void _next() {
    setState(() => _step = _step + 1);
    _armIdle();
  }

  void _skip() {
    _showToast('Skipped. That method will score as untested.');
    _next();
  }

  /// Builds the gated step sequence from the intro's toggles and starts it.
  /// An axis left off contributes no steps at all -- a speech-only session
  /// never sees a joystick, not even a skippable one.
  void _startCalibration() {
    final steps = <_StepKind>[
      if (_draft.measureMotor) ...const [
        _StepKind.reach,
        _StepKind.buttons,
        _StepKind.hold,
        _StepKind.joystick,
        _StepKind.trackpad,
      ],
      if (_draft.measureSpeech) _StepKind.voice,
      if (_draft.measureVision) _StepKind.vision,
    ];
    if (!_draft.measureMotor) _draft.skipped.add('motor (not measured)');
    if (!_draft.measureSpeech) {
      _draft.skipped.add('speech (not measured)');
    }
    if (!_draft.measureVision) {
      _draft.skipped.add('vision (not measured)');
    }
    setState(() {
      _steps = steps;
      _step = 0;
    });
    _armIdle();
  }

  double get _textScale => _draft.vision.textScale;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.deferToChild,
      onPointerDown: (_) => _pokeIdle(),
      child: Stack(
        children: [
          Positioned.fill(child: _body()),
          if (_toast != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 100,
              child: _Toast(message: _toast!),
            ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_step == -3) {
      return CaregiverTraining(
        locale: widget.locale,
        onDone: () => setState(() => _step = -1),
        onSkipAll: () => setState(() => _step = -1),
      );
    }
    if (_step == -2) return _entry();
    if (_step == -1) return _axisPicker();
    if (_step >= _stepCount) {
      return CalibrationResults(
        draft: _draft,
        onUse: () => widget.onComplete(_draft.build()),
        onRedo: () => setState(() => _step = -1),
      );
    }
    return switch (_steps[_step]) {
      _StepKind.reach => ReachStep(
          draft: _draft,
          index: _step,
          total: _stepCount,
          onNext: _next,
          onSkip: _skip,
          textScale: _textScale,
        ),
      _StepKind.buttons => ButtonsStep(
          draft: _draft,
          index: _step,
          total: _stepCount,
          onNext: _next,
          onSkip: _skip,
          textScale: _textScale,
        ),
      _StepKind.joystick => JoystickStep(
          draft: _draft,
          index: _step,
          total: _stepCount,
          onNext: _next,
          onSkip: _skip,
          textScale: _textScale,
        ),
      _StepKind.trackpad => TrackpadStep(
          draft: _draft,
          index: _step,
          total: _stepCount,
          onNext: _next,
          onSkip: _skip,
          textScale: _textScale,
        ),
      _StepKind.hold => HoldStep(
          draft: _draft,
          index: _step,
          total: _stepCount,
          onNext: _next,
          onSkip: _skip,
          textScale: _textScale,
        ),
      _StepKind.voice => VoiceStep(
          draft: _draft,
          index: _step,
          total: _stepCount,
          onNext: _next,
          onSkip: _skip,
          textScale: _textScale,
        ),
      _StepKind.vision => VisionStep(
          draft: _draft,
          index: _step,
          total: _stepCount,
          onNext: _next,
          onSkip: _skip,
          textScale: _textScale,
        ),
    };
  }

  void _setAxis({bool? motor, bool? speech, bool? vision}) {
    setState(() {
      if (motor != null) _draft.measureMotor = motor;
      if (speech != null) _draft.measureSpeech = speech;
      if (vision != null) _draft.measureVision = vision;
    });
    widget.onAxesChanged?.call(
      _draft.measureMotor,
      _draft.measureSpeech,
      _draft.measureVision,
    );
  }

  bool get _atLeastOneAxis =>
      _draft.measureMotor || _draft.measureSpeech || _draft.measureVision;

  /// The actual entry point, and the only screen that has to work for
  /// *anyone*: no button to find, no question to parse first, no choice
  /// required. The whole screen is one tap target -- the same standard
  /// [ReachStep] itself uses ("tap the highlighted square, or wait, it moves
  /// on"), except here there isn't even a target to find. A caregiver gets a
  /// second, clearly separate way in that skips straight past the question
  /// this screen doesn't ask (docs: issue #1 -- the entry point must never be
  /// harder to operate than anything calibration itself measures).
  Widget _entry() {
    final scheme = Theme.of(context).colorScheme;
    void solo() => setState(() {
          _draft.helperChoseAxes = false;
          _step = -1;
        });
    return Column(
      children: [
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: solo,
            onLongPress: solo,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(28, 28, 28, 16),
              children: [
                Icon(Icons.tune, size: 64, color: scheme.primary),
                const SizedBox(height: 20),
                const Text(
                  'Set up how you control things',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 14),
                Text(
                  'There is no pass or fail. Each test measures what works for '
                  'you, and anything you cannot do is skipped automatically.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    height: 1.45,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Tap anywhere to start',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: scheme.onPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                RecordedNarration(clipId: 'welcome', locale: widget.locale),
              ],
            ),
          ),
        ),
        // Outside the full-screen gesture — research 11: caregiver path is a
        // normal control, shown at the same time, not gated behind the tap.
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: SizedBox(
            height: 56,
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => setState(() {
                _draft.helperChoseAxes = true;
                _step = -3;
              }),
              child: const Text(
                'Someone is helping set this up',
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// "What should we measure?" -- for which environments. Reached only after
  /// [_entry] already let the person in, so large-but-multiple targets here
  /// are fine; they are a refinement step, not the gate.
  Widget _axisPicker() {
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.tune, size: 56, color: scheme.primary),
          const SizedBox(height: 16),
          const Text(
            'What should we measure?',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Text(
            'There is no pass or fail. Each test measures what works for you, '
            'and anything left off or skipped is untested, not failed.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              height: 1.4,
              color: scheme.onSurfaceVariant,
            ),
          ),
          if (_draft.helperChoseAxes) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: scheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: scheme.onTertiaryContainer),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Setting this up for someone else',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onTertiaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 26),
          _sectionLabel(scheme, 'WHICH ENVIRONMENTS'),
          const SizedBox(height: 10),
          _axisToggle(
            scheme,
            color: HaikuTheme.motorSeed,
            label: 'Motor',
            detail: 'reach, buttons, hold, joystick, trackpad',
            selected: _draft.measureMotor,
            onChanged: (v) => _setAxis(motor: v),
          ),
          const SizedBox(height: 10),
          _axisToggle(
            scheme,
            color: HaikuTheme.speechSeed,
            label: 'Speech',
            detail: 'voice / hold-to-speak',
            selected: _draft.measureSpeech,
            onChanged: (v) => _setAxis(speech: v),
          ),
          const SizedBox(height: 10),
          _axisToggle(
            scheme,
            color: HaikuTheme.visionSeed,
            label: 'Vision',
            detail: 'shrinking-word read check',
            selected: _draft.measureVision,
            onChanged: (v) => _setAxis(vision: v),
          ),
          const SizedBox(height: 28),
          SizedBox(
            height: 72,
            child: FilledButton(
              onPressed: _atLeastOneAxis ? _startCalibration : null,
              child: Text(
                _atLeastOneAxis
                    ? 'Start'
                    : 'Choose at least one environment',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(ColorScheme scheme, String text) => Text(
        text,
        style: TextStyle(
          fontSize: 11,
          letterSpacing: 1.3,
          fontWeight: FontWeight.w800,
          color: scheme.primary,
        ),
      );

  /// A whole-row toggle, not a small checkbox -- consistent with every other
  /// control in this flow being a large target.
  Widget _axisToggle(
    ColorScheme scheme, {
    required Color color,
    required String label,
    required String detail,
    required bool selected,
    required void Function(bool) onChanged,
  }) =>
      InkWell(
        onTap: () => onChanged(!selected),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.16)
                : scheme.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? color : scheme.outlineVariant,
              width: selected ? 2.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    Text(detail,
                        style: TextStyle(
                            fontSize: 12, color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
                color: selected ? color : scheme.outline,
                size: 26,
              ),
            ],
          ),
        ),
      );
}

class _Toast extends StatelessWidget {
  const _Toast({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.inverseSurface,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text(
          message,
          style: TextStyle(color: scheme.onInverseSurface, fontSize: 14),
        ),
      ),
    );
  }
}
