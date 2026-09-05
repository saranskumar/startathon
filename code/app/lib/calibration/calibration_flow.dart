import 'dart:async';

import 'package:flutter/material.dart';

import '../model/profile.dart';
import '../theme/haiku_theme.dart';
import 'results.dart';
import 'sense_steps.dart';
import 'step_frame.dart';
import 'touch_steps.dart';

/// One test in the gated sequence -- which of these run is decided by the
/// intro's Motor / Speech / Vision toggles, not fixed at seven.
enum _StepKind { reach, buttons, joystick, trackpad, hold, voice, vision }

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
  const CalibrationFlow({super.key, required this.onComplete, this.onAxesChanged});

  final void Function(CapabilityProfile profile) onComplete;

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

  /// -1 = intro, 0.._stepCount-1 = tests, _stepCount = results. Populated once
  /// the intro's Start is pressed, from whichever axes are still on.
  List<_StepKind> _steps = const [];
  int get _stepCount => _steps.length;

  int _step = -1;
  int _consecutiveIdleSkips = 0;
  Timer? _idle;
  String? _toast;

  @override
  void initState() {
    super.initState();
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
        _StepKind.joystick,
        _StepKind.trackpad,
        _StepKind.hold,
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
    if (_step < 0) return _intro();
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

  /// "What should we measure?" -- who is answering that, and for which
  /// environments. Never "which disability do you have": the wording and the
  /// large-target-only controls both hold that line deliberately.
  Widget _intro() {
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
          const SizedBox(height: 28),
          _sectionLabel(scheme, 'WHO IS CHOOSING THE AXES'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _bigToggle(
                  scheme,
                  label: 'I am doing this',
                  selected: !_draft.helperChoseAxes,
                  onTap: () => setState(() => _draft.helperChoseAxes = false),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _bigToggle(
                  scheme,
                  label: 'Someone is\nhelping me choose',
                  selected: _draft.helperChoseAxes,
                  onTap: () => setState(() => _draft.helperChoseAxes = true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          _sectionLabel(scheme, 'WHICH ENVIRONMENTS'),
          const SizedBox(height: 10),
          _axisToggle(
            scheme,
            color: HaikuTheme.motorSeed,
            label: 'Motor',
            detail: 'reach, buttons, joystick, trackpad, hold',
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

  Widget _bigToggle(
    ColorScheme scheme, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 84,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: selected ? scheme.primary : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 3 : 1,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: selected ? scheme.onPrimary : scheme.onSurface,
            ),
          ),
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
