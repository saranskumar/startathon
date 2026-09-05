import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../inputs/surfaces.dart';
import '../model/profile.dart';
import '../model/session.dart';
import 'step_frame.dart';

/// Shared constructor arguments for every calibration step.
abstract class CalibrationStep extends StatefulWidget {
  const CalibrationStep({
    super.key,
    required this.draft,
    required this.index,
    required this.total,
    required this.onNext,
    required this.onSkip,
    this.textScale = 1.0,
  });

  final CalibrationDraft draft;
  final int index;
  final int total;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final double textScale;
}

// ---------------------------------------------------------------------------
// 1. Reachable zone
// ---------------------------------------------------------------------------

/// docs/idea/03-input-calibration.md 3.1 -- "tap a grid of points spread across
/// the screen and record which register reliably".
///
/// A cell that is never tapped is *not* a failure the user has to sit through:
/// each target gives up after a few seconds and moves on. Tapping any cell
/// marks that cell reachable even when it was not the one being asked for --
/// the user just proved they can reach it, and discarding that would be
/// perverse.
class ReachStep extends CalibrationStep {
  const ReachStep({
    super.key,
    required super.draft,
    required super.index,
    required super.total,
    required super.onNext,
    required super.onSkip,
    super.textScale,
  });

  @override
  State<ReachStep> createState() => _ReachStepState();
}

class _ReachStepState extends State<ReachStep> {
  static const _perTarget = Duration(milliseconds: 3500);

  late final List<int> _order;
  int _cursor = 0;
  int? _lastTapped;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Fixed seed: the same demo runs the same way twice.
    _order = List<int>.generate(CapabilityProfile.reachCellCount, (i) => i)
      ..shuffle(math.Random(7));
    _arm();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _arm() {
    _timer?.cancel();
    _timer = Timer(_perTarget, _advance);
  }

  void _advance() {
    if (!mounted) return;
    if (_cursor >= _order.length - 1) {
      _timer?.cancel();
      widget.onNext();
      return;
    }
    setState(() {
      _cursor++;
      _lastTapped = null;
    });
    _arm();
  }

  void _tap(int cell) {
    widget.draft.reachableCells.add(cell);
    setState(() => _lastTapped = cell);
    if (cell == _order[_cursor]) {
      _advance();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final target = _order[_cursor];
    return StepFrame(
      title: 'Reachable zone',
      instruction: 'Tap the highlighted square.',
      status: "If you can't reach it, wait -- it moves on by itself. "
          '${widget.draft.reachableCells.length} reached so far.',
      index: widget.index,
      total: widget.total,
      textScale: widget.textScale,
      onSkip: widget.onSkip,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            for (var row = 0; row < CapabilityProfile.reachGridRows; row++)
              Expanded(
                child: Row(
                  children: [
                    for (var col = 0;
                        col < CapabilityProfile.reachGridCols;
                        col++)
                      Expanded(
                        child: _cell(
                          scheme,
                          row * CapabilityProfile.reachGridCols + col,
                          target,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _cell(ColorScheme scheme, int cell, int target) {
    final isTarget = cell == target;
    final reached = widget.draft.reachableCells.contains(cell);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _tap(cell),
      child: Container(
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isTarget
              ? scheme.primary
              : reached
                  ? scheme.primaryContainer.withValues(alpha: 0.55)
                  : scheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isTarget ? scheme.primary : scheme.outlineVariant,
            width: isTarget ? 3 : 1,
          ),
        ),
        alignment: Alignment.center,
        child: isTarget
            ? Icon(Icons.touch_app, color: scheme.onPrimary, size: 30)
            : reached
                ? Icon(Icons.check, color: scheme.primary, size: 20)
                : (_lastTapped == cell
                    ? Icon(Icons.circle, size: 8, color: scheme.outline)
                    : null),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 2. Buttons
// ---------------------------------------------------------------------------

/// 3.1 -- "show 2-3 buttons at varying size/position; ask the user to press
/// each in sequence". Shrinking sizes give [CalibrationDraft.minTargetSize] as
/// a by-product: the smallest button the user actually landed.
class ButtonsStep extends CalibrationStep {
  const ButtonsStep({
    super.key,
    required super.draft,
    required super.index,
    required super.total,
    required super.onNext,
    required super.onSkip,
    super.textScale,
  });

  @override
  State<ButtonsStep> createState() => _ButtonsStepState();
}

class _ButtonsStepState extends State<ButtonsStep> {
  static const _sizes = <double>[140, 104, 76, 54];
  static const _timeout = Duration(seconds: 7);

  final _trials = TrialCollector(referenceMs: 4000, referenceError: 140);
  final _stopwatch = Stopwatch();
  final math.Random _rng = math.Random(11);

  int _round = 0;
  double? _smallestHit;
  Offset _buttonCenter = Offset.zero;
  Alignment _placement = const Alignment(0, 0.2);
  Timer? _timer;
  String _feedback = '';

  @override
  void initState() {
    super.initState();
    _startRound();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startRound() {
    // Place inside the zone the user already proved they can reach, so this
    // test measures precision, not reach -- those are separate axes and mixing
    // them would double-count the same limitation.
    final cells = widget.draft.reachableCells.isEmpty
        ? List<int>.generate(CapabilityProfile.reachCellCount, (i) => i)
        : widget.draft.reachableCells.toList();
    final cell = cells[_rng.nextInt(cells.length)];
    final col = cell % CapabilityProfile.reachGridCols;
    final row = cell ~/ CapabilityProfile.reachGridCols;
    setState(() {
      _placement = Alignment(
        ((col + 0.5) / CapabilityProfile.reachGridCols) * 2 - 1,
        ((row + 0.5) / CapabilityProfile.reachGridRows) * 2 - 1,
      );
    });
    _stopwatch
      ..reset()
      ..start();
    _timer?.cancel();
    _timer = Timer(_timeout, () => _finishRound(hit: false, error: 140));
  }

  void _finishRound({required bool hit, required double error}) {
    if (!mounted) return;
    _timer?.cancel();
    _stopwatch.stop();
    _trials.record(
      success: hit,
      ms: _stopwatch.elapsedMilliseconds,
      error: error,
    );
    if (hit) {
      final size = _sizes[_round];
      _smallestHit = _smallestHit == null
          ? size
          : math.min(_smallestHit!, size);
    }
    setState(() {
      _feedback = hit
          ? 'Got it (${_stopwatch.elapsedMilliseconds} ms)'
          : 'Missed that one -- fine, moving on';
      _round++;
    });
    if (_round >= _sizes.length) {
      _commit();
      widget.onNext();
    } else {
      _startRound();
    }
  }

  void _commit() {
    widget.draft.scores[TouchMethod.buttons] = _trials.build();
    widget.draft.minTargetSize = _smallestHit ?? 200;
  }

  @override
  Widget build(BuildContext context) {
    final size = _sizes[math.min(_round, _sizes.length - 1)];
    return StepFrame(
      title: 'Buttons',
      instruction: 'Press the button.',
      status: 'It gets smaller each time. Missing is useful data, not failure. '
          '$_feedback',
      index: widget.index,
      total: widget.total,
      textScale: widget.textScale,
      onSkip: () {
        _timer?.cancel();
        widget.draft.skipped.add('buttons');
        widget.onSkip();
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final area = Size(constraints.maxWidth, constraints.maxHeight);
          _buttonCenter = Offset(
            (_placement.x + 1) / 2 * area.width,
            (_placement.y + 1) / 2 * area.height,
          );
          return Listener(
            behavior: HitTestBehavior.deferToChild,
            // Every press in the whole area is measured, so a near-miss lands
            // in the error term instead of being silently discarded.
            onPointerDown: (event) {
              final d = distanceBetween(event.localPosition, _buttonCenter);
              final hit = d <= size / 2;
              _finishRound(hit: hit, error: hit ? d : math.max(d, size));
            },
            child: Container(
              color: Colors.transparent,
              child: Align(
                alignment: _placement,
                child: IgnorePointer(
                  child: Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${size.round()}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 3. Joystick
// ---------------------------------------------------------------------------

/// 3.1 -- "show a target direction/zone; ask the user to move the stick there
/// and hold". The hold requirement is what separates this from a flick: it
/// measures sustained control, which is what continuous tasks need.
class JoystickStep extends CalibrationStep {
  const JoystickStep({
    super.key,
    required super.draft,
    required super.index,
    required super.total,
    required super.onNext,
    required super.onSkip,
    super.textScale,
  });

  @override
  State<JoystickStep> createState() => _JoystickStepState();
}

class _JoystickStepState extends State<JoystickStep> {
  // All 8 positions, not just the 4 cardinals -- a stick that is accurate on
  // the axes but sloppy on the diagonals would otherwise score as fully
  // calibrated while still under-serving half of a free-pointing task.
  static const _targets = <String>[
    'up', 'up-right', 'right', 'down-right',
    'down', 'down-left', 'left', 'up-left',
  ];
  static const _holdMs = 500;
  static const _timeout = Duration(seconds: 9);

  final _trials = TrialCollector(referenceMs: 5000, referenceError: 1.2);
  final Stopwatch _stopwatch = Stopwatch();

  int _round = 0;
  Timer? _timeoutTimer;
  Timer? _holdTimer;
  double _errorSum = 0;
  int _errorSamples = 0;
  String _feedback = '';
  bool _onTarget = false;

  @override
  void initState() {
    super.initState();
    _startRound();
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _holdTimer?.cancel();
    super.dispose();
  }

  void _startRound() {
    _errorSum = 0;
    _errorSamples = 0;
    _onTarget = false;
    _stopwatch
      ..reset()
      ..start();
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(_timeout, () => _finish(false));
  }

  static final double _diag = math.sqrt(0.5); // unit-length diagonal component

  Offset _targetVector(String dir) => switch (dir) {
        'up' => const Offset(0, -1),
        'down' => const Offset(0, 1),
        'left' => const Offset(-1, 0),
        'right' => const Offset(1, 0),
        'up-right' => Offset(_diag, -_diag),
        'down-right' => Offset(_diag, _diag),
        'down-left' => Offset(-_diag, _diag),
        _ => Offset(-_diag, -_diag), // 'up-left'
      };

  void _onVector(Offset v) {
    final want = _targetVector(_targets[_round]);
    if (v.distance < 0.45) {
      _holdTimer?.cancel();
      _holdTimer = null;
      if (_onTarget) setState(() => _onTarget = false);
      return;
    }
    // Angular deviation in radians, 0 = perfectly on target.
    final dot = (v.dx * want.dx + v.dy * want.dy) / v.distance;
    final deviation = math.acos(dot.clamp(-1.0, 1.0));
    _errorSum += deviation;
    _errorSamples++;

    final within = deviation < math.pi / 5; // ~36 degrees
    if (within && _holdTimer == null) {
      setState(() => _onTarget = true);
      _holdTimer = Timer(
        const Duration(milliseconds: _holdMs),
        () => _finish(true),
      );
    } else if (!within) {
      _holdTimer?.cancel();
      _holdTimer = null;
      if (_onTarget) setState(() => _onTarget = false);
    }
  }

  void _finish(bool success) {
    if (!mounted) return;
    _holdTimer?.cancel();
    _holdTimer = null;
    _timeoutTimer?.cancel();
    _stopwatch.stop();
    final meanErr = _errorSamples == 0 ? 1.2 : _errorSum / _errorSamples;
    _trials.record(
      success: success,
      ms: _stopwatch.elapsedMilliseconds,
      error: success ? meanErr : math.max(meanErr, 1.2),
    );
    setState(() {
      _feedback = success ? 'Held it. ' : 'Not this time. ';
      _round++;
      _onTarget = false;
    });
    if (_round >= _targets.length) {
      widget.draft.scores[TouchMethod.joystick] = _trials.build();
      widget.onNext();
    } else {
      _startRound();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dir = _targets[math.min(_round, _targets.length - 1)];
    return StepFrame(
      title: 'Joystick',
      instruction: 'Push the stick $dir and hold it there.',
      status: '$_feedback${_round + 1} of ${_targets.length}. '
          'Hold for half a second to register.',
      index: widget.index,
      total: widget.total,
      textScale: widget.textScale,
      onSkip: () {
        _timeoutTimer?.cancel();
        _holdTimer?.cancel();
        widget.draft.skipped.add('joystick');
        widget.onSkip();
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            switch (dir) {
              'up' => Icons.arrow_upward,
              'down' => Icons.arrow_downward,
              'left' => Icons.arrow_back,
              'right' => Icons.arrow_forward,
              'up-right' => Icons.north_east,
              'down-right' => Icons.south_east,
              'down-left' => Icons.south_west,
              _ => Icons.north_west, // 'up-left'
            },
            size: 64,
            color: _onTarget ? scheme.primary : scheme.outline,
          ),
          Text(
            _onTarget ? 'holding...' : 'push and hold',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 18),
          JoystickPad(
            size: 210,
            onVector: _onVector,
            tint: _onTarget ? scheme.primary : null,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 4. Trackpad
// ---------------------------------------------------------------------------

/// 3.1 -- "show a target zone; ask the user to drag a pointer into it".
///
/// Also answers the axis question raised in docs/idea/20: X error and Y error
/// are accumulated separately, so a user who can swipe reliably on one axis but
/// not the other is detected instead of being scored as bad at trackpad.
class TrackpadStep extends CalibrationStep {
  const TrackpadStep({
    super.key,
    required super.draft,
    required super.index,
    required super.total,
    required super.onNext,
    required super.onSkip,
    super.textScale,
  });

  @override
  State<TrackpadStep> createState() => _TrackpadStepState();
}

class _TrackpadStepState extends State<TrackpadStep> {
  static const _targets = <Offset>[
    Offset(0.85, 0.2),
    Offset(0.15, 0.75),
    Offset(0.5, 0.15),
  ];
  static const _timeout = Duration(seconds: 10);
  static const _hitRadius = 0.13; // fraction of pad size

  final _trials = TrialCollector(referenceMs: 6000, referenceError: 0.5);
  final Stopwatch _stopwatch = Stopwatch();

  int _round = 0;
  Timer? _timer;
  Offset _cursor = const Offset(0.5, 0.5);
  double _errXSum = 0, _errYSum = 0;
  int _errSamples = 0;
  String _feedback = '';

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    _stopwatch
      ..reset()
      ..start();
    _timer?.cancel();
    _timer = Timer(_timeout, () => _finish(false, 0.5));
  }

  void _finish(bool success, double error) {
    if (!mounted) return;
    _timer?.cancel();
    _stopwatch.stop();
    _trials.record(
      success: success,
      ms: _stopwatch.elapsedMilliseconds,
      error: error,
    );
    setState(() {
      _feedback = success ? 'In the zone. ' : 'Timed out, moving on. ';
      _round++;
    });
    if (_round >= _targets.length) {
      widget.draft.scores[TouchMethod.trackpad] = _trials.build();
      _commitAxis();
      widget.onNext();
    } else {
      _start();
    }
  }

  /// If one axis is consistently much worse than the other, record it -- the
  /// runtime then stops asking that axis to do work (surfaces.dart axisLock).
  void _commitAxis() {
    if (_errSamples < 5) return;
    final ex = _errXSum / _errSamples;
    final ey = _errYSum / _errSamples;
    const floor = 0.04;
    if (ex > math.max(ey * 2.2, floor)) {
      widget.draft.axisLock = Axis.vertical; // only Y is usable
    } else if (ey > math.max(ex * 2.2, floor)) {
      widget.draft.axisLock = Axis.horizontal; // only X is usable
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final target = _targets[math.min(_round, _targets.length - 1)];
    return StepFrame(
      title: 'Trackpad',
      instruction: 'Drag the dot into the ring, then let go.',
      status: '$_feedback${_round + 1} of ${_targets.length}.',
      index: widget.index,
      total: widget.total,
      textScale: widget.textScale,
      onSkip: () {
        _timer?.cancel();
        widget.draft.skipped.add('trackpad');
        widget.onSkip();
      },
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth, h = constraints.maxHeight;
            return Stack(
              children: [
                Positioned.fill(
                  child: TrackpadSurface(
                    hint: 'drag anywhere on this pad',
                    showCursor: false,
                    onStart: (n) => setState(() => _cursor = n),
                    onMove: (n, d) {
                      setState(() => _cursor = n);
                      _errXSum += (n.dx - target.dx).abs();
                      _errYSum += (n.dy - target.dy).abs();
                      _errSamples++;
                    },
                    onEnd: (n) {
                      final err = (n - target).distance;
                      _finish(err <= _hitRadius, err);
                    },
                  ),
                ),
                Positioned(
                  left: target.dx * w - 44,
                  top: target.dy * h - 44,
                  child: IgnorePointer(
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: scheme.primary, width: 4),
                        color: scheme.primary.withValues(alpha: 0.10),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: _cursor.dx * w - 18,
                  top: _cursor.dy * h - 18,
                  child: IgnorePointer(
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: scheme.tertiary,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 5. Touch and hold
// ---------------------------------------------------------------------------

/// Raised in docs/idea/20 as a primitive the calibration set was missing.
/// It gives two things nothing else measures: whether hold-based interactions
/// (press-and-hold to scroll, hold-to-talk) can be offered at all, and a
/// steadiness number for tremor tolerance (02-core-model 2.3).
class HoldStep extends CalibrationStep {
  const HoldStep({
    super.key,
    required super.draft,
    required super.index,
    required super.total,
    required super.onNext,
    required super.onSkip,
    super.textScale,
  });

  @override
  State<HoldStep> createState() => _HoldStepState();
}

class _HoldStepState extends State<HoldStep> {
  static const _requiredMs = 1500;

  Timer? _ticker;
  Offset? _origin;
  double _jitter = 0;
  int _elapsed = 0;
  bool _done = false;
  String _feedback = '';

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _down(Offset p) {
    _origin = p;
    _jitter = 0;
    _elapsed = 0;
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 50), (t) {
      if (!mounted) return;
      setState(() => _elapsed += 50);
      if (_elapsed >= _requiredMs) _complete(true);
    });
  }

  void _move(Offset p) {
    if (_origin == null) return;
    final d = distanceBetween(p, _origin!);
    if (d > _jitter) setState(() => _jitter = d);
  }

  void _up() {
    if (_done) return;
    _ticker?.cancel();
    if (_elapsed < _requiredMs) {
      setState(() {
        _feedback = 'Released after ${_elapsed}ms -- try once more, or skip.';
        _elapsed = 0;
      });
    }
  }

  void _complete(bool ok) {
    if (_done) return;
    _done = true;
    _ticker?.cancel();
    widget.draft.holdCapable = ok;
    // 60 logical pixels of wander during a still hold is the point at which
    // hold-based controls start firing by accident.
    widget.draft.steadiness = ok ? (1 - (_jitter / 60)).clamp(0.05, 1.0) : 0.1;
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final progress = (_elapsed / _requiredMs).clamp(0.0, 1.0);
    return StepFrame(
      title: 'Touch and hold',
      instruction: 'Press anywhere below and hold still.',
      status: _feedback.isEmpty
          ? 'About one and a half seconds. Shaking is fine -- it is measured, '
              'not judged.'
          : _feedback,
      index: widget.index,
      total: widget.total,
      textScale: widget.textScale,
      onSkip: () {
        _ticker?.cancel();
        widget.draft.skipped.add('hold');
        widget.draft.holdCapable = false;
        widget.onSkip();
      },
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (e) => _down(e.localPosition),
        onPointerMove: (e) => _move(e.localPosition),
        onPointerUp: (_) => _up(),
        onPointerCancel: (_) => _up(),
        child: Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Center(
            child: SizedBox(
              width: 160,
              height: 160,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 140,
                    height: 140,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 12,
                    ),
                  ),
                  Text(
                    progress >= 1
                        ? 'done'
                        : '${(progress * 100).round()}%',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
