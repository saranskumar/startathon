import 'dart:async';

import 'package:flutter/material.dart';

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

  void _startScan() {
    _scan?.cancel();
    _scan = Timer.periodic(_dwell, (_) {
      if (!mounted) return;
      setState(() => _highlight = (_highlight + 1) % widget.options.length);
      widget.onRaw('scan -> ${widget.options[_highlight]}');
    });
  }

  // --- joystick --------------------------------------------------------

  void _stepFromDirection() {
    final dir = _lastDirection;
    if (dir == null) return;
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

  /// Floor case (3.5): the highlight moves on its own, one press selects.
  Widget _switch() => InputOverlay(
        profile: widget.profile,
        content: OptionList(
          options: widget.options,
          highlight: _highlight,
          textScale: _scale,
          compact: true,
        ),
        dock: SwitchTrigger(
          label: 'PRESS TO SELECT',
          onPress: () => _resolve(_highlight),
        ),
      );
}
