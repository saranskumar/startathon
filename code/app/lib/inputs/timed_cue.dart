import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'haptics.dart';

/// Shared "time is running out" feedback for a calibration step's own timed
/// window (a per-round timeout, an idle-reset window, a hold duration): a
/// discrete audio pulse + haptic tick, repeating at a shrinking interval for
/// the *entire* window (not just the final stretch), plus an [elapsed]
/// fraction any progress UI can bind to directly.
///
/// See docs/idea/30 §6 / GH #14. Deliberately dependency-free --
/// [SystemSound.play] is Flutter-SDK-only, so this needs no audio package.
class TimedCue {
  TimedCue({
    required this.duration,
    this.minPulseGap = const Duration(milliseconds: 150),
    this.maxPulseGap = const Duration(milliseconds: 900),
    this.onEnd,
  });

  final Duration duration;

  /// Inter-pulse gap floor near the end of the window -- also a guard
  /// against calling [SystemSound.play] faster than a platform can
  /// reasonably be expected to handle repeated rapid calls.
  final Duration minPulseGap;

  /// Inter-pulse gap at the very start of the window.
  final Duration maxPulseGap;

  /// Fires once, when the window completes (not fired by [cancel]).
  final VoidCallback? onEnd;

  /// 0.0..1.0 through the window. Bind a `ValueListenableBuilder` to this
  /// directly for a progress bar -- see [StepFrame]'s `elapsedFraction`.
  final ValueNotifier<double> elapsed = ValueNotifier(0.0);

  // Deliberately *not* a Stopwatch/DateTime-driven clock: elapsed time is
  // tracked purely as the sum of the Timer gaps this class itself schedules,
  // so completion is driven entirely by the same fake-clock Timer chain
  // flutter_test's tester.pump(duration) fast-forwards -- a wall-clock
  // Stopwatch does not advance under that fake clock and would silently
  // never complete inside a pumped test.
  int _elapsedMs = 0;
  Timer? _pulseTimer;
  bool _running = false;

  bool get isRunning => _running;

  /// Begin the window from zero. Safe to call again after [cancel].
  void start() {
    if (_running) return;
    _running = true;
    _elapsedMs = 0;
    elapsed.value = 0.0;
    _tick();
  }

  /// Idle-window steps (e.g. Reach) call this on every user action to
  /// restart the window from zero without a separate dispose/recreate.
  void reset() {
    cancel();
    start();
  }

  /// Stop scheduling. Does not fire [onEnd] and does not dispose --
  /// [start] can be called again for a fresh window (a new round).
  void cancel() {
    _running = false;
    _pulseTimer?.cancel();
  }

  void dispose() {
    cancel();
    elapsed.dispose();
  }

  void _tick() {
    if (!_running) return;
    final f = (_elapsedMs / duration.inMilliseconds).clamp(0.0, 1.0);
    elapsed.value = f;
    if (f >= 1.0) {
      _running = false;
      onEnd?.call();
      return;
    }
    _fire();
    final gapMs = (minPulseGap.inMilliseconds +
            (maxPulseGap.inMilliseconds - minPulseGap.inMilliseconds) *
                math.pow(1 - f, 2))
        .round();
    _pulseTimer = Timer(Duration(milliseconds: gapMs), () {
      _elapsedMs += gapMs;
      _tick();
    });
  }

  void _fire() {
    // Best-effort: no ServicesBinding in a plain unit test, and no
    // documented guarantee against dropped/overlapping calls under rapid
    // repetition on every platform -- neither should ever crash a step.
    try {
      SystemSound.play(SystemSoundType.click);
    } catch (_) {
      // ignore
    }
    Haptics.tick();
  }
}
