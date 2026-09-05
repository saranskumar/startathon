import 'dart:async';

import 'package:flutter/material.dart';

import '../model/profile.dart';
import 'results.dart';
import 'sense_steps.dart';
import 'step_frame.dart';
import 'touch_steps.dart';

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
  const CalibrationFlow({super.key, required this.onComplete});

  final void Function(CapabilityProfile profile) onComplete;

  @override
  State<CalibrationFlow> createState() => _CalibrationFlowState();
}

class _CalibrationFlowState extends State<CalibrationFlow> {
  /// If nothing at all is registered for this long, the step gives up. This is
  /// what lets a user with no usable touch reach the end of calibration.
  static const _idleLimit = Duration(seconds: 20);
  static const _stepCount = 7;

  final CalibrationDraft _draft = CalibrationDraft();

  /// -1 = intro, 0.._stepCount-1 = tests, _stepCount = results.
  int _step = -1;
  int _consecutiveIdleSkips = 0;
  Timer? _idle;
  String? _toast;

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
    return switch (_step) {
      0 => ReachStep(
          draft: _draft,
          index: 0,
          total: _stepCount,
          onNext: _next,
          onSkip: _skip,
          textScale: _textScale,
        ),
      1 => ButtonsStep(
          draft: _draft,
          index: 1,
          total: _stepCount,
          onNext: _next,
          onSkip: _skip,
          textScale: _textScale,
        ),
      2 => JoystickStep(
          draft: _draft,
          index: 2,
          total: _stepCount,
          onNext: _next,
          onSkip: _skip,
          textScale: _textScale,
        ),
      3 => TrackpadStep(
          draft: _draft,
          index: 3,
          total: _stepCount,
          onNext: _next,
          onSkip: _skip,
          textScale: _textScale,
        ),
      4 => HoldStep(
          draft: _draft,
          index: 4,
          total: _stepCount,
          onNext: _next,
          onSkip: _skip,
          textScale: _textScale,
        ),
      5 => VoiceStep(
          draft: _draft,
          index: 5,
          total: _stepCount,
          onNext: _next,
          onSkip: _skip,
          textScale: _textScale,
        ),
      _ => VisionStep(
          draft: _draft,
          index: 6,
          total: _stepCount,
          onNext: _next,
          onSkip: _skip,
          textScale: _textScale,
        ),
    };
  }

  /// The intro is one enormous target: the whole screen. Nobody should fail to
  /// start calibration because the Start button was too small for them.
  Widget _intro() {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _next,
      child: Container(
        padding: const EdgeInsets.all(28),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
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
              'Seven short tests, about two minutes.\n\n'
              'There is no pass or fail. Each test measures what works for '
              'you, and anything you cannot do is skipped automatically.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                height: 1.45,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 36),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                'Tap anywhere to start',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: scheme.onPrimary,
                ),
              ),
            ),
          ],
        ),
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
