import 'dart:async';

import 'package:flutter/material.dart';

import '../model/profile.dart';
import '../theme/haiku_theme.dart';
import '../training/caregiver_training.dart';
import 'hold_fill.dart';
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
///     From the second test on, Back is the same size and returns to the
///     previous test as untested -- so a mis-tap is not Redo-from-the-start.
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
    this.onDraftChanged,
    this.startAssisted = false,
    this.locale = 'en',
    this.showSettings,
  });

  final void Function(CapabilityProfile profile) onComplete;
  final bool startAssisted;
  final String locale;

  /// Fired the instant the intro's Motor / Speech / Vision toggles change, so
  /// the app-wide theme can react before any test has produced a score.
  final void Function(bool motor, bool speech, bool vision)? onAxesChanged;

  /// Fired after every step commits or skips, with the partial profile so the
  /// next screen (and the rest of the app) is already shaped.
  final void Function(CapabilityProfile profile)? onDraftChanged;

  /// Optional settings control shown on the Setup (entry) screen.
  final VoidCallback? showSettings;

  @override
  State<CalibrationFlow> createState() => _CalibrationFlowState();
}

class _CalibrationFlowState extends State<CalibrationFlow> {
  /// If nothing at all is registered for this long, the step gives up. This is
  /// what lets a user with no usable touch reach the end of calibration.
  static const _idleLimit = Duration(seconds: 20);

  final CalibrationDraft _draft = CalibrationDraft();

  /// -3 = caregiver training, -2 = slim continue (post-Setup),
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
      _publishDraft();
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

  void _publishDraft() {
    widget.onDraftChanged?.call(_draft.build());
  }

  void _next() {
    _publishDraft();
    setState(() => _step = _step + 1);
    if (_step >= _stepCount) _publishDraft();
    _armIdle();
  }

  void _skip() {
    _showToast('Skipped. That method will score as untested.');
    _next();
  }

  /// Back one step inside the gated test list.
  ///
  /// The destination test starts over as untested -- the same honesty as Skip
  /// -- so back-then-forward cannot leave a mix of old and new scores.
  /// In-progress writes on the current step are discarded too. Hidden on the
  /// first test (back into the axis picker is out of scope).
  void _previous() {
    if (_step <= 0) return;
    _clearStep(_steps[_step], _step);
    _clearStep(_steps[_step - 1], _step - 1);
    _consecutiveIdleSkips = 0;
    _publishDraft();
    setState(() => _step = _step - 1);
    _showToast('Going back. That test starts over.');
    _armIdle();
  }

  void _clearStep(_StepKind kind, int index) {
    _draft.skipped.remove('idle:$index');
    switch (kind) {
      case _StepKind.reach:
        _draft.reachableCells.clear();
      case _StepKind.buttons:
        _draft.scores[TouchMethod.buttons] = const MethodScore.untested();
        _draft.minTargetSize = 96;
        _draft.skipped.remove('buttons');
      case _StepKind.joystick:
        _draft.scores[TouchMethod.joystick] = const MethodScore.untested();
        _draft.joystickHomeCell = null;
        _draft.joystickOctants.clear();
        _draft.skipped.remove('joystick');
      case _StepKind.trackpad:
        _draft.scores[TouchMethod.trackpad] = const MethodScore.untested();
        _draft.axisLock = null;
        _draft.skipped.remove('trackpad');
      case _StepKind.hold:
        _draft.holdCapable = false;
        _draft.steadiness = 0.5;
        _draft.skipped.remove('hold');
      case _StepKind.voice:
        _draft.clarity = SpeechClarity.none;
        _draft.vocabulary = <String>[];
        _draft.skipped.remove('voice');
      case _StepKind.vision:
        _draft.vision = VisionMode.screen;
        _draft.visualField = VisualField.full;
        _draft.skipped.remove('vision');
    }
  }

  /// Builds the gated step sequence from the intro's toggles and starts it.
  /// An axis left off contributes no steps at all -- a speech-only session
  /// never sees a joystick, not even a skippable one.
  void _startCalibration() {
    // Safety net: all three start on, and the last remaining row cannot be
    // held off, but if a caller still arrives with nothing selected, measure
    // everything rather than producing an empty step list.
    if (!_atLeastOneAxis) {
      _draft.measureMotor = true;
      _draft.measureSpeech = true;
      _draft.measureVision = true;
    }
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
    final onBack = _step > 0 ? _previous : null;
    return switch (_steps[_step]) {
      _StepKind.reach => ReachStep(
          draft: _draft,
          index: _step,
          total: _stepCount,
          onNext: _next,
          onSkip: _skip,
          onBack: onBack,
          textScale: _textScale,
        ),
      _StepKind.buttons => ButtonsStep(
          draft: _draft,
          index: _step,
          total: _stepCount,
          onNext: _next,
          onSkip: _skip,
          onBack: onBack,
          textScale: _textScale,
        ),
      _StepKind.joystick => JoystickStep(
          draft: _draft,
          index: _step,
          total: _stepCount,
          onNext: _next,
          onSkip: _skip,
          onBack: onBack,
          textScale: _textScale,
        ),
      _StepKind.trackpad => TrackpadStep(
          draft: _draft,
          index: _step,
          total: _stepCount,
          onNext: _next,
          onSkip: _skip,
          onBack: onBack,
          textScale: _textScale,
        ),
      _StepKind.hold => HoldStep(
          draft: _draft,
          index: _step,
          total: _stepCount,
          onNext: _next,
          onSkip: _skip,
          onBack: onBack,
          textScale: _textScale,
        ),
      _StepKind.voice => VoiceStep(
          draft: _draft,
          index: _step,
          total: _stepCount,
          onNext: _next,
          onSkip: _skip,
          onBack: onBack,
          textScale: _textScale,
        ),
      _StepKind.vision => VisionStep(
          draft: _draft,
          index: _step,
          total: _stepCount,
          onNext: _next,
          onSkip: _skip,
          onBack: onBack,
          textScale: _textScale,
        ),
    };
  }

  void _setAxis({bool? motor, bool? speech, bool? vision}) {
    final nextMotor = motor ?? _draft.measureMotor;
    final nextSpeech = speech ?? _draft.measureSpeech;
    final nextVision = vision ?? _draft.measureVision;
    if (!nextMotor && !nextSpeech && !nextVision) {
      _showToast('Keep at least one environment on.');
      return;
    }
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

  /// Post-tap continue screen (`_step == -2`). Setup already asked the helper
  /// question and played the welcome clip; [startAssisted] skips this screen
  /// entirely and opens training, so neither control is repeated here.
  ///
  /// Reach-zone: one short line sits out of the thumb area; the lower region
  /// is a single large tap/hold target (issue #6).
  Widget _entry() {
    final scheme = Theme.of(context).colorScheme;
    void continueSolo() => setState(() {
          _draft.helperChoseAxes = false;
          _step = -1;
        });
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 56, 28, 12),
              child: Text(
                "We'll measure what works.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
            ),
            Expanded(
              child: Semantics(
                button: true,
                label: 'Continue',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: continueSolo,
                  onLongPress: continueSolo,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        width: double.infinity,
                        height: 88,
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Continue',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: scheme.onPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (widget.showSettings != null)
          Positioned(
            top: 8,
            right: 8,
            child: Material(
              color: scheme.surfaceContainerHighest,
              shape: const CircleBorder(),
              elevation: 1,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: widget.showSettings,
                child: const SizedBox(
                  width: 48,
                  height: 48,
                  child: Icon(Icons.settings, size: 22),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// "What should we measure?" -- for which environments. Reached only after
  /// [_entry] already let the person in. All three axes start on; skipping
  /// one is a hold, not a tap (issue #7), so this screen cannot be harder
  /// than the motor test it gates.
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
            'All three start on. Hold a row to skip it -- a tap will not turn '
            'it off. Skipped is untested, not failed.',
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
              onPressed: _startCalibration,
              child: const Text(
                'Start',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
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

  /// A whole-row target, not a small checkbox. Defaults on; turning it off
  /// takes a hold (issue #7), so a user with motor difficulty is not gated
  /// by the row's own control. A tap on an off row turns it back on.
  Widget _axisToggle(
    ColorScheme scheme, {
    required Color color,
    required String label,
    required String detail,
    required bool selected,
    required void Function(bool) onChanged,
  }) {
    return Semantics(
      button: true,
      selected: selected,
      label:
          '$label. ${selected ? 'Hold to skip' : 'Tap to measure'}. $detail',
      child: HoldFill(
        key: ValueKey('axis-$label'),
        armed: selected,
        onComplete: () => onChanged(false),
        onTap: selected ? null : () => onChanged(true),
        builder: (context, progress) {
          final hint = progress > 0
              ? 'Keep holding to skip'
              : selected
                  ? 'Hold to skip · $detail'
                  : 'Tap to measure · $detail';
          return ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: selected
                          ? color.withValues(alpha: 0.16)
                          : scheme.surfaceContainerHighest
                              .withValues(alpha: 0.4),
                    ),
                  ),
                ),
                if (progress > 0)
                  Positioned.fill(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: progress,
                        heightFactor: 1,
                        child: ColoredBox(
                          color: color.withValues(alpha: 0.28),
                        ),
                      ),
                    ),
                  ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
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
                        decoration: BoxDecoration(
                            shape: BoxShape.circle, color: color),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(label,
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700)),
                            Text(hint,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: scheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 28,
                        height: 28,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            if (progress > 0)
                              HoldFillRing(
                                progress: progress,
                                size: 28,
                                strokeWidth: 3,
                              ),
                            Icon(
                              selected
                                  ? Icons.check_circle
                                  : Icons.circle_outlined,
                              color: selected ? color : scheme.outline,
                              size: 26,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
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
