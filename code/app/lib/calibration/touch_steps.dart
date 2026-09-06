import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../inputs/surfaces.dart';
import '../inputs/timed_cue.dart';
import '../model/profile.dart';
import '../model/session.dart';
import 'hold_fill.dart';
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
    this.onBack,
    this.textScale = 1.0,
  });

  final CalibrationDraft draft;
  final int index;
  final int total;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final VoidCallback? onBack;
  final double textScale;
}

// ---------------------------------------------------------------------------
// 1. Reachable zone
// ---------------------------------------------------------------------------

/// docs/idea/03-input-calibration.md 3.1 -- "tap a grid of points spread across
/// the screen and record which register reliably".
///
/// Every cell is shown and tappable at once, in any order -- no one cell is
/// "the" target, so nobody waits on a highlight they cannot reach in time.
/// A first tap marks a cell tentative; a second tap on that same cell locks
/// it in as confirmed. A cell tapped only once still counts as reachable
/// (see [CapabilityProfile.reachableCells]) -- it is just lower-confidence
/// than a locked one ([CapabilityProfile.lockedCells]). The step ends when
/// the visible overall timer runs out, using whatever state every cell is in
/// at that point -- an unconfirmed guess is data, not a failure. If every
/// cell is locked before then, a short countdown at the top precedes the
/// next input method.
class ReachStep extends CalibrationStep {
  const ReachStep({
    super.key,
    required super.draft,
    required super.index,
    required super.total,
    required super.onNext,
    required super.onSkip,
    super.onBack,
    super.textScale,
  });

  @override
  State<ReachStep> createState() => _ReachStepState();
}

class _ReachStepState extends State<ReachStep> {
  // Hard ceiling -- the visible top bar is this window, and it is the only
  // clock that can end the step (plus Skip, plus locking every cell).
  static const _overallTimeout = Duration(seconds: 10);

  /// Per-cell state: 0 untouched, 1 tentative (tapped once), 2 locked
  /// (tapped a second time -- final, no further change via tap).
  late final List<int> _stage;
  late final TimedCue _overallCue;
  final MovingOnLock _movingOn = MovingOnLock();
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _stage = List<int>.filled(CapabilityProfile.reachCellCount, 0);
    _overallCue = TimedCue(duration: _overallTimeout, onEnd: _finish)..start();
  }

  @override
  void dispose() {
    _movingOn.dispose();
    _overallCue.dispose();
    super.dispose();
  }

  void _tap(int cell) {
    if (_finished || _movingOn.active) return;
    final stage = _stage[cell];
    if (stage >= 2) return; // locked -- no further change via tap
    setState(() => _stage[cell] = stage + 1);
    if (_stage.every((s) => s == 2)) _beginMovingOn();
  }

  void _beginMovingOn() {
    _overallCue.cancel();
    _movingOn.start(onEnd: _finish);
    setState(() {});
  }

  /// Any tap -- even one that never gets confirmed -- is proof the user
  /// reached that cell, so it is banked whether the step ends by timing out
  /// or by an explicit Skip (see the class doc comment).
  void _commit() {
    for (var cell = 0; cell < _stage.length; cell++) {
      if (_stage[cell] >= 1) widget.draft.reachableCells.add(cell);
      if (_stage[cell] >= 2) widget.draft.lockedCells.add(cell);
    }
  }

  void _finish() {
    if (_finished || !mounted) return;
    _finished = true;
    _movingOn.cancel();
    _overallCue.cancel();
    _commit();
    widget.onNext();
  }

  /// Bottom-left = 1, ascending upward then left-to-right -- a purely
  /// cosmetic relabeling of the existing top-left-origin, row-major cell
  /// index every other consumer (reachableRect, reachAnchor, ...) still
  /// relies on.
  int _displayNumber(int cell) {
    const cols = CapabilityProfile.reachGridCols;
    const rows = CapabilityProfile.reachGridRows;
    final row = cell ~/ cols;
    final col = cell % cols;
    return ((rows - 1 - row) * cols) + col + 1;
  }

  StepFrame _frame({
    required String instruction,
    required String status,
    required bool locked,
    required ValueListenable<double>? elapsed,
    required Widget child,
  }) {
    return StepFrame(
      title: 'Reachable zone',
      instruction: instruction,
      status: status,
      index: widget.index,
      total: widget.total,
      textScale: widget.textScale,
      minTargetSize: widget.draft.minTargetSize,
      onBack: widget.onBack,
      onSkip: () {
        _movingOn.cancel();
        _overallCue.cancel();
        _commit();
        widget.onSkip();
      },
      elapsedFraction: elapsed,
      locked: locked,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final locked = _stage.where((s) => s == 2).length;
    final tentative = _stage.where((s) => s == 1).length;
    final grid = Padding(
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
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
    if (_movingOn.active) {
      return MovingOnListener(
        lock: _movingOn,
        builder: (context, instruction) => _frame(
          instruction: instruction,
          status: 'Every square is locked in.',
          locked: true,
          elapsed: _movingOn.elapsed,
          child: grid,
        ),
      );
    }
    return _frame(
      instruction:
          'Try to tap every square you can reach. Tap it again to confirm.',
      status: '$locked confirmed, $tentative tentative so far.',
      locked: false,
      elapsed: _overallCue.elapsed,
      child: grid,
    );
  }

  Widget _cell(ColorScheme scheme, int cell) {
    final stage = _stage[cell];
    final fill = switch (stage) {
      2 => scheme.primary,
      1 => scheme.primaryContainer.withValues(alpha: 0.55),
      _ => scheme.surfaceContainerHighest.withValues(alpha: 0.4),
    };
    final border = stage >= 1 ? scheme.primary : scheme.outlineVariant;
    final borderWidth = switch (stage) { 2 => 3.0, 1 => 1.5, _ => 1.0 };
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _tap(cell),
      child: Container(
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border, width: borderWidth),
        ),
        alignment: Alignment.center,
        child: stage == 2
            ? Icon(Icons.check, color: scheme.onPrimary, size: 20)
            : Text(
                '${_displayNumber(cell)}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: stage == 1 ? scheme.primary : scheme.onSurfaceVariant,
                ),
              ),
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
    super.onBack,
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
  final MovingOnLock _movingOn = MovingOnLock();

  int _round = 0;
  double? _smallestHit;
  Alignment _placement = const Alignment(0, 0.2);
  int _cell = 0;
  TimedCue? _cue;
  String _feedback = '';
  bool _roundClosed = false;
  bool _lastHit = false;

  @override
  void initState() {
    super.initState();
    _startRound();
  }

  @override
  void dispose() {
    _movingOn.dispose();
    _cue?.dispose();
    super.dispose();
  }

  void _startRound() {
    // Place inside the zone the user already proved they can reach, so this
    // test measures precision, not reach -- those are separate axes and mixing
    // them would double-count the same limitation.
    // TODO(#9/Hold-reorder): reachableCells includes both locked and
    // tentative-only cells (see ReachStep) -- consider preferring
    // draft.lockedCells here once Hold's per-button rework lands, if
    // higher-confidence placement turns out to matter.
    final cells = widget.draft.reachableCells.isEmpty
        ? List<int>.generate(CapabilityProfile.reachCellCount, (i) => i)
        : widget.draft.reachableCells.toList();
    final cell = cells[_rng.nextInt(cells.length)];
    _cell = cell;
    final col = cell % CapabilityProfile.reachGridCols;
    final row = cell ~/ CapabilityProfile.reachGridCols;
    _roundClosed = false;
    setState(() {
      _placement = Alignment(
        ((col + 0.5) / CapabilityProfile.reachGridCols) * 2 - 1,
        ((row + 0.5) / CapabilityProfile.reachGridRows) * 2 - 1,
      );
    });
    _stopwatch
      ..reset()
      ..start();
    _cue?.cancel();
    _cue = TimedCue(
      duration: _timeout,
      onEnd: () => _finishRound(hit: false, error: 140),
    )..start();
  }

  void _onHit() {
    if (_movingOn.active || _roundClosed) return;
    _finishRound(hit: true, error: 0);
  }

  void _onMiss() {
    if (_movingOn.active || _roundClosed) return;
    setState(() {
      _feedback = 'Missed -- keep trying until the timer runs out.';
    });
  }

  void _finishRound({required bool hit, required double error}) {
    if (!mounted || _roundClosed || _movingOn.active) return;
    _roundClosed = true;
    _cue?.cancel();
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
      widget.draft.tappableButtons.add(
        ButtonTarget(cell: _cell, size: size, placement: _placement),
      );
    }
    _lastHit = hit;
    setState(() {
      _feedback = hit
          ? 'Got it (${_stopwatch.elapsedMilliseconds} ms)'
          : 'Missed that one -- fine, moving on';
      _round++;
    });
    if (_round >= _sizes.length) {
      _commit();
      _beginMovingOn();
    } else {
      _startRound();
    }
  }

  void _beginMovingOn() {
    _cue?.cancel();
    _movingOn.start(onEnd: () {
      if (!mounted) return;
      widget.onNext();
    });
    setState(() {});
  }

  void _commit() {
    widget.draft.scores[TouchMethod.buttons] = _trials.build();
    widget.draft.minTargetSize = _smallestHit ?? 200;
  }

  @override
  Widget build(BuildContext context) {
    final size = _sizes[math.min(_round, _sizes.length - 1)];
    final pad = Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) => _onMiss(),
          ),
        ),
        Align(
          alignment: _placement,
          child: GestureDetector(
            onTapDown: (_) => _onHit(),
            child: _CalCircle(
              size: size,
              label: '${size.round()}',
              showCheck: _movingOn.active && _lastHit,
            ),
          ),
        ),
      ],
    );

    StepFrame frame({
      required String instruction,
      required String status,
      required bool locked,
      required ValueListenable<double>? elapsed,
    }) {
      return StepFrame(
        title: 'Buttons',
        instruction: instruction,
        status: status,
        index: widget.index,
        total: widget.total,
        textScale: widget.textScale,
        minTargetSize: widget.draft.minTargetSize,
        onBack: widget.onBack,
        onSkip: () {
          _movingOn.cancel();
          _cue?.cancel();
          widget.draft.skipped.add('buttons');
          widget.onSkip();
        },
        elapsedFraction: elapsed,
        locked: locked,
        child: pad,
      );
    }

    if (_movingOn.active) {
      return MovingOnListener(
        lock: _movingOn,
        builder: (context, instruction) => frame(
          instruction: instruction,
          status: 'Those buttons are locked in.',
          locked: true,
          elapsed: _movingOn.elapsed,
        ),
      );
    }
    return frame(
      instruction: 'Try to press the button.',
      status:
          'It gets smaller each time. Missing is useful data, not failure. '
          '$_feedback',
      locked: false,
      elapsed: _cue?.elapsed,
    );
  }
}

// ---------------------------------------------------------------------------
// 3. Joystick
// ---------------------------------------------------------------------------

/// Reach tells us where a finger *lands*; this tells us where the stick can
/// *swing*, which is a different question -- someone can plant a finger fine
/// in a spot they cannot then steer from. So this runs one swing-round per
/// cell [ReachStep] already proved reachable (centre-most cell first), rather
/// than the old single-spot 8-direction hold test -- that old test survives
/// verbatim as the fallback for the floor case where reach found nothing to
/// place the stick on at all.
class JoystickStep extends CalibrationStep {
  const JoystickStep({
    super.key,
    required super.draft,
    required super.index,
    required super.total,
    required super.onNext,
    required super.onSkip,
    super.onBack,
    super.textScale,
  });

  @override
  State<JoystickStep> createState() => _JoystickStepState();
}

class _JoystickStepState extends State<JoystickStep> {
  static final double _diag = math.sqrt(0.5); // unit-length diagonal component

  static const _octantNames = <String>[
    'right', 'down-right', 'down', 'down-left',
    'left', 'up-left', 'up', 'up-right',
  ];

  /// Which of the 8 swept directions a live vector currently falls in, or
  /// null inside the dead zone. Order matches [_octantNames].
  static String? _octantOf(Offset v) {
    if (v.distance < 0.45) return null;
    final a = math.atan2(v.dy, v.dx);
    final idx = (a / (math.pi / 4)).round() % 8;
    return _octantNames[(idx + 8) % 8];
  }

  final _trials = TrialCollector(referenceMs: 6000, referenceError: 1.0);
  final Stopwatch _stopwatch = Stopwatch();
  TimedCue? _cue;
  String _feedback = '';

  /// True once reach found at least one usable cell -- the normal path. False
  /// only for the floor case, which keeps today's single-centre hold test.
  // TODO(#9/Hold-reorder): same reachableCells-vs-lockedCells note as
  // ButtonsStep._startRound above.
  bool get _sweepMode => widget.draft.reachableCells.isNotEmpty;

  // --- sweep mode: one round per reachable cell -------------------------

  static const _sweepTimeout = Duration(seconds: 6);
  static const _octantsNeeded = 6;

  late final List<int> _cellOrder;
  int _cellRound = 0;
  final Set<String> _visitedOctants = <String>{};

  List<int> _orderCellsCenterFirst(Set<int> cells) {
    const cols = CapabilityProfile.reachGridCols;
    const rows = CapabilityProfile.reachGridRows;
    const cx = (cols - 1) / 2, cy = (rows - 1) / 2;
    double distanceToCenter(int i) {
      final col = i % cols, row = i ~/ cols;
      return math.sqrt(math.pow(col - cx, 2) + math.pow(row - cy, 2));
    }

    return cells.toList()
      ..sort((a, b) => distanceToCenter(a).compareTo(distanceToCenter(b)));
  }

  void _startSweepRound() {
    _visitedOctants.clear();
    _stopwatch
      ..reset()
      ..start();
    _cue?.dispose();
    _cue = TimedCue(duration: _sweepTimeout, onEnd: _finishSweepRound)
      ..start();
  }

  void _onSweepVector(Offset v) {
    final octant = _octantOf(v);
    if (octant == null) return;
    final isNew = _visitedOctants.add(octant);
    if (isNew) setState(() {});
    if (_visitedOctants.length >= _octantsNeeded) _finishSweepRound();
  }

  void _finishSweepRound() {
    if (!mounted) return;
    _cue?.cancel();
    _stopwatch.stop();
    final cell = _cellOrder[_cellRound];
    final octants = _visitedOctants.length;
    widget.draft.joystickOctants[cell] = octants;
    _trials.record(
      success: octants >= _octantsNeeded,
      ms: _stopwatch.elapsedMilliseconds,
      error: 1 - octants / 8,
    );
    setState(() {
      _feedback = octants >= _octantsNeeded
          ? 'Full circle. '
          : 'Got $octants of 8 here -- moving on. ';
      _cellRound++;
    });
    if (_cellRound >= _cellOrder.length) {
      _commitSweep();
      widget.onNext();
    } else {
      _startSweepRound();
    }
  }

  /// The steadiest cell wins; on a tie the centre-most one does, since
  /// [_cellOrder] is already sorted that way and `reduce` only replaces the
  /// running best on a strict improvement.
  void _commitSweep() {
    widget.draft.scores[TouchMethod.joystick] = _trials.build();
    final entries = widget.draft.joystickOctants.entries
        .where((e) => _cellOrder.contains(e.key));
    if (entries.isEmpty) return;
    final best = entries.reduce((a, b) => b.value > a.value ? b : a);
    if (best.value > 0) widget.draft.joystickHomeCell = best.key;
  }

  Alignment _cellAlignment(int cell) {
    const cols = CapabilityProfile.reachGridCols;
    const rows = CapabilityProfile.reachGridRows;
    final col = cell % cols, row = cell ~/ cols;
    return Alignment(
      ((col + 0.5) / cols) * 2 - 1,
      ((row + 0.5) / rows) * 2 - 1,
    );
  }

  // --- floor-case fallback: today's single-centre 8-direction hold test -

  static const _holdTargets = <String>[
    'up', 'up-right', 'right', 'down-right',
    'down', 'down-left', 'left', 'up-left',
  ];
  static const _holdMs = 500;
  static const _holdTimeout = Duration(seconds: 9);

  int _holdRound = 0;
  Timer? _holdTimer;
  double _errorSum = 0;
  int _errorSamples = 0;
  bool _onTarget = false;

  void _startHoldRound() {
    _errorSum = 0;
    _errorSamples = 0;
    _onTarget = false;
    _stopwatch
      ..reset()
      ..start();
    _cue?.dispose();
    _cue = TimedCue(duration: _holdTimeout, onEnd: () => _finishHold(false))
      ..start();
  }

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

  void _onHoldVector(Offset v) {
    final want = _targetVector(_holdTargets[_holdRound]);
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
        () => _finishHold(true),
      );
    } else if (!within) {
      _holdTimer?.cancel();
      _holdTimer = null;
      if (_onTarget) setState(() => _onTarget = false);
    }
  }

  void _finishHold(bool success) {
    if (!mounted) return;
    _holdTimer?.cancel();
    _holdTimer = null;
    _cue?.cancel();
    _stopwatch.stop();
    final meanErr = _errorSamples == 0 ? 1.2 : _errorSum / _errorSamples;
    _trials.record(
      success: success,
      ms: _stopwatch.elapsedMilliseconds,
      error: success ? meanErr : math.max(meanErr, 1.2),
    );
    setState(() {
      _feedback = success ? 'Held it. ' : 'Not this time. ';
      _holdRound++;
      _onTarget = false;
    });
    if (_holdRound >= _holdTargets.length) {
      widget.draft.scores[TouchMethod.joystick] = _trials.build();
      widget.onNext();
    } else {
      _startHoldRound();
    }
  }

  // --- lifecycle ----------------------------------------------------------

  @override
  void initState() {
    super.initState();
    if (_sweepMode) {
      _cellOrder = _orderCellsCenterFirst(widget.draft.reachableCells);
      _startSweepRound();
    } else {
      _cellOrder = const [];
      _startHoldRound();
    }
  }

  @override
  void dispose() {
    _cue?.dispose();
    _holdTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _sweepMode ? _buildSweep(context) : _buildHold(context);
  }

  Widget _buildSweep(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Defensive: onNext() has already fired once _cellRound reaches the end
    // (see _finishSweepRound), but this widget may still be asked to build
    // one more frame before the parent replaces it -- same reason
    // _buildHold clamps _holdRound below.
    final cell = _cellOrder[math.min(_cellRound, _cellOrder.length - 1)];
    return StepFrame(
      title: 'Joystick',
      instruction: 'Try to circle the stick all the way around, right here.',
      status: '$_feedback Spot ${_cellRound + 1} of ${_cellOrder.length}. '
          'Need $_octantsNeeded of 8 directions.',
      index: widget.index,
      total: widget.total,
      textScale: widget.textScale,
      minTargetSize: widget.draft.minTargetSize,
      onBack: widget.onBack,
      onSkip: () {
        _cue?.cancel();
        widget.draft.skipped.add('joystick');
        widget.onSkip();
      },
      elapsedFraction: _cue?.elapsed,
      child: Stack(
        children: [
          Align(
            alignment: const Alignment(0, -0.55),
            child: _octantDots(scheme),
          ),
          Align(
            alignment: _cellAlignment(cell),
            child: JoystickPad(
              size: 170,
              onVector: _onSweepVector,
              tint: _visitedOctants.length >= _octantsNeeded
                  ? scheme.primary
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _octantDots(ColorScheme scheme) => Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        children: [
          for (final o in _octantNames)
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _visitedOctants.contains(o)
                    ? scheme.primary
                    : scheme.surfaceContainerHighest,
                border: Border.all(color: scheme.outlineVariant),
              ),
            ),
        ],
      );

  Widget _buildHold(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dir = _holdTargets[math.min(_holdRound, _holdTargets.length - 1)];
    return StepFrame(
      title: 'Joystick',
      instruction: 'Try to push the stick $dir and hold it there.',
      status: '$_feedback${_holdRound + 1} of ${_holdTargets.length}. '
          'Hold for half a second to register.',
      index: widget.index,
      total: widget.total,
      textScale: widget.textScale,
      minTargetSize: widget.draft.minTargetSize,
      onBack: widget.onBack,
      onSkip: () {
        _cue?.cancel();
        _holdTimer?.cancel();
        widget.draft.skipped.add('joystick');
        widget.onSkip();
      },
      elapsedFraction: _cue?.elapsed,
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
            onVector: _onHoldVector,
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
    super.onBack,
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
  TimedCue? _cue;
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
    _cue?.dispose();
    super.dispose();
  }

  void _start() {
    _stopwatch
      ..reset()
      ..start();
    _cue?.dispose();
    _cue = TimedCue(duration: _timeout, onEnd: () => _finish(false, 0.5))
      ..start();
  }

  void _finish(bool success, double error) {
    if (!mounted) return;
    _cue?.cancel();
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
      instruction: 'Try to drag the dot into the ring, then let go.',
      status: '$_feedback${_round + 1} of ${_targets.length}.',
      index: widget.index,
      total: widget.total,
      textScale: widget.textScale,
      minTargetSize: widget.draft.minTargetSize,
      onBack: widget.onBack,
      onSkip: () {
        _cue?.cancel();
        widget.draft.skipped.add('trackpad');
        widget.onSkip();
      },
      elapsedFraction: _cue?.elapsed,
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
///
/// Runs once per button [ButtonsStep] already confirmed tappable, so the
/// result is per-button (5 tappable, 2 also holdable -> 7 usable inputs), not
/// one undifferentiated yes/no -- see docs/idea/30 §8. Falls back to today's
/// single arbitrary-spot test only when Buttons found nothing (skipped, or
/// the floor case).
class HoldStep extends CalibrationStep {
  const HoldStep({
    super.key,
    required super.draft,
    required super.index,
    required super.total,
    required super.onNext,
    required super.onSkip,
    super.onBack,
    super.textScale,
  });

  @override
  State<HoldStep> createState() => _HoldStepState();
}

class _HoldStepState extends State<HoldStep> {
  static const _roundTimeout = Duration(seconds: 7);

  late final List<ButtonTarget> _targets;
  int _targetIndex = 0;
  final List<double> _roundSteadiness = <double>[];
  final MovingOnLock _movingOn = MovingOnLock();

  // Floor-case-only aggregate (no button targets to attach a result to).
  bool? _floorHoldable;

  TimedCue? _roundCue;
  TimedCue? _feedbackCue;
  bool _holding = false;

  Offset? _origin;
  double _jitter = 0;
  bool _done = false;
  String _feedback = '';

  bool get _floorCase => _targets.isEmpty;

  @override
  void initState() {
    super.initState();
    _targets = List.of(widget.draft.tappableButtons);
    _armRoundTimeout();
  }

  @override
  void dispose() {
    _movingOn.dispose();
    _roundCue?.dispose();
    _feedbackCue?.dispose();
    super.dispose();
  }

  // A round left untouched entirely (user never puts a finger down at all)
  // would otherwise hang until the flow's own 20s global idle-skip -- this
  // bounds a single round the same way every other timed step does.
  void _armRoundTimeout() {
    _roundCue?.cancel();
    _roundCue = TimedCue(
      duration: _roundTimeout,
      onEnd: () => _complete(false),
    )..start();
  }

  void _onDown(Offset p) {
    if (_movingOn.active || _done) return;
    // Cancel the round ceiling so a hold in progress cannot lose to it.
    _roundCue?.cancel();
    _origin = p;
    _jitter = 0;
    _holding = true;
    _feedbackCue?.cancel();
    _feedbackCue = TimedCue(duration: HoldFill.standard)..start();
    setState(() {});
  }

  void _onMove(Offset p) {
    if (_origin == null) return;
    final d = distanceBetween(p, _origin!);
    if (d > _jitter) setState(() => _jitter = d);
  }

  void _onCancel(Duration held) {
    if (_done || _movingOn.active) return;
    _holding = false;
    _feedbackCue?.cancel();
    _armRoundTimeout();
    setState(() {
      _feedback =
          'Released after ${held.inMilliseconds}ms -- try once more, or skip.';
    });
  }

  void _complete(bool ok) {
    if (_done || _movingOn.active) return;
    _done = true;
    _holding = false;
    _roundCue?.cancel();
    _feedbackCue?.cancel();
    // 60 logical pixels of wander during a still hold is the point at which
    // hold-based controls start firing by accident.
    _roundSteadiness.add(ok ? (1 - (_jitter / 60)).clamp(0.05, 1.0) : 0.1);
    if (_floorCase) {
      _floorHoldable = ok;
    } else {
      _targets[_targetIndex].holdable = ok;
    }
    _advanceOrFinish();
  }

  void _advanceOrFinish() {
    final isLast = _floorCase || _targetIndex >= _targets.length - 1;
    if (isLast) {
      _commit();
      _beginMovingOn();
      return;
    }
    setState(() {
      _targetIndex++;
      _done = false;
      _origin = null;
      _jitter = 0;
      _feedback = '';
    });
    _armRoundTimeout();
  }

  void _beginMovingOn() {
    _roundCue?.cancel();
    _feedbackCue?.cancel();
    _movingOn.start(onEnd: () {
      if (!mounted) return;
      widget.onNext();
    });
    setState(() {});
  }

  /// Distinct from [CalibrationStep.onSkip] (abandon the whole test) -- this
  /// keeps whatever buttons were already confirmed holdable and only leaves
  /// the remaining ones untested, per docs/idea/30 §8's own open question.
  void _skipRemaining() {
    _roundCue?.cancel();
    _feedbackCue?.cancel();
    _commit();
    widget.onNext();
  }

  void _commit() {
    widget.draft.holdCapable = _floorCase
        ? (_floorHoldable ?? false)
        : _targets.any((t) => t.holdable == true);
    widget.draft.steadiness = _roundSteadiness.isEmpty
        ? 0.1
        : _roundSteadiness.reduce((a, b) => a + b) / _roundSteadiness.length;
  }

  ValueListenable<double>? get _elapsed {
    if (_movingOn.active) return _movingOn.elapsed;
    if (_holding) return _feedbackCue?.elapsed;
    return _roundCue?.elapsed;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = _movingOn.active
        ? 'Those buttons are locked in.'
        : _feedback.isNotEmpty
            ? _feedback
            : _floorCase
                ? 'About one and a half seconds. Shaking is fine -- it is '
                    'measured, not judged.'
                : 'Button ${_targetIndex + 1} of ${_targets.length}. About one '
                    'and a half seconds each.';
    final instruction = _floorCase
        ? 'Try to press anywhere below and hold still.'
        : 'Try to hold down on this button.';

    final pad = LayoutBuilder(
      builder: (context, constraints) {
        final area = Size(constraints.maxWidth, constraints.maxHeight);
        final reach = widget.draft.build().reachableRect(area);
        if (_floorCase) {
          return Stack(
            children: [
              Positioned.fromRect(
                rect: reach.deflate(8),
                child: _movingOn.active
                    ? IgnorePointer(
                        child: _floorHoldVisual(scheme, progress: 0),
                      )
                    : HoldFill(
                        onDown: _onDown,
                        onMove: _onMove,
                        onComplete: () => _complete(true),
                        onCancel: _onCancel,
                        builder: (context, progress) =>
                            _floorHoldVisual(scheme, progress: progress),
                      ),
              ),
            ],
          );
        }
        return Stack(
          children: [
            for (var i = 0; i < _targets.length; i++) _placedButton(scheme, i),
          ],
        );
      },
    );

    StepFrame frame({
      required String instruction,
      required String status,
      required bool locked,
      required ValueListenable<double>? elapsed,
    }) {
      return StepFrame(
        title: 'Touch and hold',
        instruction: instruction,
        status: status,
        index: widget.index,
        total: widget.total,
        textScale: widget.textScale,
        minTargetSize: widget.draft.minTargetSize,
        onBack: widget.onBack,
        onSkip: () {
          _movingOn.cancel();
          _roundCue?.cancel();
          _feedbackCue?.cancel();
          widget.draft.skipped.add('hold');
          widget.draft.holdCapable = false;
          widget.onSkip();
        },
        footer: (!_floorCase &&
                !_movingOn.active &&
                _targetIndex < _targets.length - 1)
            ? Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _skipRemaining,
                  child: const Text('Skip remaining buttons'),
                ),
              )
            : null,
        elapsedFraction: elapsed,
        locked: locked,
        child: pad,
      );
    }

    if (_movingOn.active) {
      return MovingOnListener(
        lock: _movingOn,
        builder: (context, movingInstruction) => frame(
          instruction: movingInstruction,
          status: status,
          locked: true,
          elapsed: _movingOn.elapsed,
        ),
      );
    }
    return frame(
      instruction: instruction,
      status: status,
      locked: false,
      elapsed: _elapsed,
    );
  }

  Widget _floorHoldVisual(ColorScheme scheme, {required double progress}) {
    const diameter = 160.0;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant),
      ),
      alignment: Alignment.center,
      child: HoldFillRing(
        progress: progress,
        size: diameter,
        strokeWidth: 12,
        child: Text(
          progress >= 1 ? 'done' : '${(progress * 100).round()}%',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _placedButton(ColorScheme scheme, int i) {
    final target = _targets[i];
    final isActive = i == _targetIndex && !_movingOn.active && !_done;
    final holdable = target.holdable;
    Widget circle({double progress = 0}) => _CalCircle(
          size: target.size,
          label: '${target.size.round()}',
          showCheck: holdable == true,
          dimmed: !isActive && holdable != true,
          progress: isActive ? progress : 0,
        );
    return Align(
      alignment: target.placement,
      child: isActive
          ? HoldFill(
              onDown: _onDown,
              onMove: _onMove,
              onComplete: () => _complete(true),
              onCancel: _onCancel,
              builder: (context, progress) => circle(progress: progress),
            )
          : IgnorePointer(child: circle()),
    );
  }
}

/// Shared circular target used by [ButtonsStep] (tap) and [HoldStep] (hold)
/// so the two tests share a layout.
class _CalCircle extends StatelessWidget {
  const _CalCircle({
    required this.size,
    required this.label,
    this.dimmed = false,
    this.showCheck = false,
    this.progress = 0,
  });

  final double size;
  final String label;
  final bool dimmed;
  final bool showCheck;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fill = dimmed
        ? scheme.primary.withValues(alpha: 0.35)
        : scheme.primary;
    final circle = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: showCheck
          ? Icon(Icons.check, color: scheme.onPrimary, size: (size * 0.4).clamp(16.0, 36.0))
          : Text(
              label,
              style: TextStyle(
                color: scheme.onPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
    );
    if (progress <= 0) return circle;
    return SizedBox(
      width: size + 24,
      height: size + 24,
      child: Stack(
        alignment: Alignment.center,
        children: [
          HoldFillRing(
            progress: progress,
            size: size + 24,
            strokeWidth: 8,
          ),
          circle,
        ],
      ),
    );
  }
}
