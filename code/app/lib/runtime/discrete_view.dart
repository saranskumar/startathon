import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../inputs/haptics.dart';
import '../inputs/surfaces.dart';
import '../model/profile.dart';
import '../model/session.dart';
import 'dock.dart';
import 'hold_repeater.dart';

/// Discrete choice, driven by whichever method the profile selected.
///
/// docs/idea/03-input-calibration.md 3.3: a fallback is not the same widget
/// made worse, it is a different interaction reaching the same outcome --
/// tap for buttons, cycle-and-confirm for the joystick, hover-and-release for
/// the trackpad, auto-scan-and-press for the switch.
class DiscreteTaskView extends StatefulWidget {
  const DiscreteTaskView({
    super.key,
    required this.profile,
    required this.method,
    required this.options,
    required this.onResolve,
    required this.onRaw,
  });

  final CapabilityProfile profile;
  final TouchMethod method;
  final List<String> options;
  final void Function(int index, String value) onResolve;
  final void Function(String raw) onRaw;

  @override
  State<DiscreteTaskView> createState() => _DiscreteTaskViewState();
}

class _DiscreteTaskViewState extends State<DiscreteTaskView> {
  int _highlight = 0;
  int _page = 0;
  String? _lastDirection;
  Timer? _scan;
  late final HoldRepeater _repeater;

  double get _scale => widget.profile.vision.textScale;

  @override
  void initState() {
    super.initState();
    _repeater = HoldRepeater(_stepFromDirection);
    if (widget.method == TouchMethod.switchScan) _startScan();
  }

  @override
  void dispose() {
    _scan?.cancel();
    _repeater.stop();
    super.dispose();
  }

  // --- switch scanning -------------------------------------------------

  /// Dwell time is stretched for an unsteady user: the whole risk of scanning
  /// is pressing one item late, so steadiness buys speed rather than being
  /// fixed for everyone.
  Duration get _dwell => Duration(
        milliseconds:
            (900 + (1 - widget.profile.steadiness).clamp(0.0, 1.0) * 900)
                .round(),
      );

  /// Row-then-column scanning, the same shape [PointingTaskView] already uses
  /// for its switch fallback -- for a floor-case user, scanning every option
  /// one at a time doesn't scale (6 plans = up to 6 dwells); a grid needs at
  /// most rows+cols (2 rows x 3 cols = at most 5). Degenerates to a single
  /// column pass automatically when there's only one row's worth of options.
  int get _scanCols => math.max(1, math.sqrt(widget.options.length).ceil());
  int get _scanRows => (widget.options.length / _scanCols).ceil();

  int _scanPhase = 0; // 0 = scanning rows, 1 = scanning the chosen row's columns
  int _scanRow = 0;
  int _scanCol = 0;

  void _tickScan() {
    if (!mounted) return;
    Haptics.navigate();
    setState(() {
      if (_scanPhase == 0) {
        _scanRow = (_scanRow + 1) % _scanRows;
      } else {
        _scanCol = (_scanCol + 1) % _scanCols;
      }
    });
    widget.onRaw(_scanPhase == 0 ? 'scan row $_scanRow' : 'scan col $_scanCol');
  }

  void _startScan() {
    _scan?.cancel();
    _scanPhase = _scanRows > 1 ? 0 : 1;
    _scanRow = 0;
    _scanCol = 0;
    _scan = Timer.periodic(_dwell, (_) => _tickScan());
  }

  /// The switch's one press: picks the row on the first press (if there is
  /// more than one), then the cell within that row on the second. The same
  /// running timer just switches what it increments -- no restart needed.
  void _switchPress() {
    if (_scanPhase == 0) {
      setState(() => _scanPhase = 1);
      return;
    }
    final index = _scanRow * _scanCols + _scanCol;
    if (index < widget.options.length) {
      _resolve(index);
    } else {
      // Grid isn't fully filled (e.g. 4 options in a 2x3 grid) and landed on
      // an empty cell -- restart rather than silently doing nothing.
      _startScan();
    }
  }

  // --- joystick --------------------------------------------------------

  void _stepFromDirection() {
    final dir = _lastDirection;
    if (dir == null) return;
    Haptics.navigate();
    final delta = (dir == 'up' || dir == 'left') ? -1 : 1;
    setState(() {
      _highlight =
          (_highlight + delta + widget.options.length) % widget.options.length;
    });
    widget.onRaw('$dir -> ${widget.options[_highlight]}');
  }

  void _onVector(Offset v) {
    final dir = cardinalOf(v, deadZone: 0.45);
    if (dir == _lastDirection) return;
    _lastDirection = dir;
    if (dir == null) {
      _repeater.stop();
    } else {
      _repeater.start();
    }
  }

  // --- resolution ------------------------------------------------------

  void _resolve(int index) {
    Haptics.confirm();
    _scan?.cancel();
    _repeater.stop();
    widget.onResolve(index, widget.options[index]);
  }

  @override
  Widget build(BuildContext context) {
    return switch (widget.method) {
      TouchMethod.buttons => _buttons(),
      TouchMethod.joystick => _joystick(),
      TouchMethod.trackpad => _trackpad(),
      TouchMethod.switchScan => _switch(),
    };
  }

  /// Ideal pattern: direct tap. Only [CapabilityProfile.maxControls] options
  /// are on screen at once -- 2.4's rule that lower precision means lower
  /// interface resolution, not smaller buttons.
  Widget _buttons() {
    final perPage = widget.profile.maxControls;
    final pages = (widget.options.length / perPage).ceil();
    final start = _page * perPage;
    final slice = widget.options.skip(start).take(perPage).toList();

    return InputOverlay(
      profile: widget.profile,
      content: OptionList(
        options: slice,
        highlight: -1,
        textScale: _scale,
        minTargetSize: widget.profile.minTargetSize,
        onTap: (i) => _resolve(start + i),
      ),
      dock: pages <= 1
          ? null
          : Row(
              children: [
                Expanded(
                  child: CalibratedButton(
                    label: 'More options',
                    subtitle: 'page ${_page + 1} of $pages',
                    minSize: widget.profile.minTargetSize,
                    textScale: _scale,
                    onPressed: () {
                      setState(() => _page = (_page + 1) % pages);
                      widget.onRaw('page ${_page + 1}/$pages');
                    },
                  ),
                ),
              ],
            ),
    );
  }

  /// Fallback pattern: cycle the highlight, press the stick to confirm --
  /// a game menu, which is a pattern most people already know.
  Widget _joystick() => InputOverlay(
        profile: widget.profile,
        content: OptionList(
          options: widget.options,
          highlight: _highlight,
          textScale: _scale,
          compact: true,
        ),
        overlay: JoystickPad(
          size: 170,
          label: 'SELECT',
          onVector: _onVector,
          onPress: () => _resolve(_highlight),
          onRelease: () {
            _lastDirection = null;
            _repeater.stop();
          },
        ),
      );

  /// Fallback pattern: drag to hover, release to select. Position on the pad
  /// maps to position in the list, so the whole list is one gesture away.
  Widget _trackpad() => InputOverlay(
        profile: widget.profile,
        content: OptionList(
          options: widget.options,
          highlight: _highlight,
          textScale: _scale,
          compact: true,
        ),
        dock: SizedBox(
          height: 190,
          child: TrackpadSurface(
            hint: 'drag up and down, let go to choose',
            axisLock: Axis.vertical,
            // A tap moves the highlight without committing, so a stray tap is
            // never a wrong selection.
            onTapAt: (n) => _hover(n.dy),
            onStart: (n) => _hover(n.dy),
            onMove: (n, _) => _hover(n.dy),
            onEnd: (_) => _resolve(_highlight),
          ),
        ),
      );

  void _hover(double y) {
    final i = (y * widget.options.length)
        .floor()
        .clamp(0, widget.options.length - 1);
    if (i == _highlight) return;
    setState(() => _highlight = i);
    widget.onRaw('hover -> ${widget.options[i]}');
  }

  /// Floor case (3.5): row-then-column auto-scan, one press advances the
  /// phase or selects.
  Widget _switch() => InputOverlay(
        profile: widget.profile,
        content: Padding(
          padding: const EdgeInsets.all(16),
          child: _scanGrid(),
        ),
        dock: SwitchTrigger(
          label: 'PRESS TO SELECT',
          onPress: _switchPress,
        ),
      );

  Widget _scanGrid() {
    final scheme = Theme.of(context).colorScheme;
    final cols = _scanCols;
    final rows = _scanRows;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var r = 0; r < rows; r++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                for (var c = 0; c < cols; c++)
                  Expanded(child: _scanCell(scheme, r, c, cols)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _scanCell(ColorScheme scheme, int row, int col, int cols) {
    final index = row * cols + col;
    final has = index < widget.options.length;
    final rowActive = row == _scanRow;
    final cellActive = _scanPhase == 1 && rowActive && col == _scanCol;
    final rowOnlyActive = _scanPhase == 0 && rowActive;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 110),
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: !has
              ? Colors.transparent
              : cellActive
                  ? scheme.primary
                  : rowOnlyActive
                      ? scheme.primaryContainer.withValues(alpha: 0.55)
                      : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          border: has
              ? Border.all(
                  color: cellActive || rowOnlyActive
                      ? scheme.primary
                      : scheme.outlineVariant,
                  width: cellActive ? 3 : 1,
                )
              : null,
        ),
        alignment: Alignment.center,
        child: has
            ? Text(
                widget.options[index],
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14 * _scale,
                  fontWeight: cellActive ? FontWeight.w800 : FontWeight.w600,
                  color: cellActive ? scheme.onPrimary : scheme.onSurface,
                ),
              )
            : null,
      ),
    );
  }
}
