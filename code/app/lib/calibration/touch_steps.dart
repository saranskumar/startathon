import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../inputs/surfaces.dart';
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
    super.onBack,
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
      instruction: 'Try to tap the highlighted square.',
      status: "If you can't reach it, wait -- it moves on by itself. "
          '${widget.draft.reachableCells.length} reached so far.',
      index: widget.index,
      total: widget.total,
      textScale: widget.textScale,
      minTargetSize: widget.draft.minTargetSize,
      onBack: widget.onBack,
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
      instruction: 'Try to press the button.',
      status: 'It gets smaller each time. Missing is useful data, not failure. '
          '$_feedback',
      index: widget.index,
      total: widget.total,
      textScale: widget.textScale,
      minTargetSize: widget.draft.minTargetSize,
      onBack: widget.onBack,
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
  Timer? _timeoutTimer;
  String _feedback = '';

  /// True once reach found at least one usable cell -- the normal path. False
  /// only for the floor case, which keeps today's single-centre hold test.
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
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(_sweepTimeout, _finishSweepRound);
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
    _timeoutTimer?.cancel();
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
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(_holdTimeout, () => _finishHold(false));
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
    _timeoutTimer?.cancel();
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
        _timeoutTimer?.cancel();
        widget.draft.skipped.add('joystick');
        widget.onSkip();
      },
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
      instruction: 'Try to drag the dot into the ring, then let go.',
      status: '$_feedback${_round + 1} of ${_targets.length}.',
      index: widget.index,
      total: widget.total,
      textScale: widget.textScale,
      minTargetSize: widget.draft.minTargetSize,
      onBack: widget.onBack,
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
    super.onBack,
    super.textScale,
  });

  @override
  State<HoldStep> createState() => _HoldStepState();
}

class _HoldStepState extends State<HoldStep> {
  Offset? _origin;
  double _jitter = 0;
  bool _done = false;
  String _feedback = '';

  void _complete(bool ok) {
    if (_done) return;
    _done = true;
    widget.draft.holdCapable = ok;
    // 60 logical pixels of wander during a still hold is the point at which
    // hold-based controls start firing by accident.
    widget.draft.steadiness = ok ? (1 - (_jitter / 60)).clamp(0.05, 1.0) : 0.1;
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return StepFrame(
      title: 'Touch and hold',
      instruction: 'Try to press anywhere below and hold still.',
      status: _feedback.isEmpty
          ? 'About one and a half seconds. Shaking is fine -- it is measured, '
              'not judged.'
          : _feedback,
      index: widget.index,
      total: widget.total,
      textScale: widget.textScale,
      minTargetSize: widget.draft.minTargetSize,
      onBack: widget.onBack,
      onSkip: () {
        widget.draft.skipped.add('hold');
        widget.draft.holdCapable = false;
        widget.onSkip();
      },
      // Constrained to the zone the reach test already found, same as every
      // other control -- there is no point measuring hold in a spot the user
      // cannot otherwise reach.
      child: LayoutBuilder(
        builder: (context, constraints) {
          final reach = widget.draft.build().reachableRect(
                Size(constraints.maxWidth, constraints.maxHeight),
              );
          return Stack(
            children: [
              Positioned.fromRect(
                rect: reach.deflate(8),
                child: HoldFill(
                  armed: !_done,
                  onDown: (p) {
                    _origin = p;
                    _jitter = 0;
                  },
                  onMove: (p) {
                    if (_origin == null) return;
                    final d = distanceBetween(p, _origin!);
                    if (d > _jitter) setState(() => _jitter = d);
                  },
                  onComplete: () => _complete(true),
                  onCancel: (held) {
                    if (_done) return;
                    setState(() {
                      _feedback =
                          'Released after ${held.inMilliseconds}ms -- try once more, or skip.';
                    });
                  },
                  builder: (context, progress) {
                    return Container(
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest
                            .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: scheme.outlineVariant),
                      ),
                      child: Center(
                        child: HoldFillRing(
                          progress: progress,
                          size: 140,
                          strokeWidth: 12,
                          child: Text(
                            progress >= 1
                                ? 'done'
                                : '${(progress * 100).round()}%',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
