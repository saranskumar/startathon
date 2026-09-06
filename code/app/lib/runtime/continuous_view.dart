import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../inputs/haptics.dart';
import '../inputs/surfaces.dart';
import '../model/profile.dart';
import 'dock.dart';
import 'hold_repeater.dart';
import 'task_spec.dart';

/// Continuous / directional adjustment.
///
/// 3.3's matrix for this shape: joystick pushes and holds (ideal), buttons
/// become a stepper, the trackpad becomes a scrub gesture, and the switch scans
/// a direction then runs until pressed again.
class ContinuousTaskView extends StatefulWidget {
  const ContinuousTaskView({
    super.key,
    required this.profile,
    required this.method,
    required this.spec,
    required this.onResolve,
    required this.onRaw,
  });

  final CapabilityProfile profile;
  final TouchMethod method;
  final TaskSpec spec;
  final void Function(int value) onResolve;
  final void Function(String raw) onRaw;

  @override
  State<ContinuousTaskView> createState() => _ContinuousTaskViewState();
}

class _ContinuousTaskViewState extends State<ContinuousTaskView> {
  late int _value = ((widget.spec.min + widget.spec.max) / 2).round();

  /// Switch mode cycles through these; the selected one runs until the next
  /// press.
  static const _switchModes = ['decrease', 'increase', 'done'];
  int _switchMode = 0;
  Timer? _scan;
  Timer? _motion;

  Timer? _joyTicker;
  double _joyAxis = 0;
  late final HoldRepeater _stepper;

  double get _scale => widget.profile.vision.textScale;

  @override
  void initState() {
    super.initState();
    _stepper = HoldRepeater(() => _nudge(_stepDirection));
    if (widget.method == TouchMethod.switchScan) _startScan();
  }

  @override
  void dispose() {
    _scan?.cancel();
    _motion?.cancel();
    _joyTicker?.cancel();
    _stepper.stop();
    super.dispose();
  }

  int _stepDirection = 1;

  void _nudge(int delta) {
    final next = (_value + delta).clamp(widget.spec.min, widget.spec.max);
    if (next == _value) return;
    setState(() => _value = next);
    widget.onRaw('${widget.spec.fieldLabel.isEmpty ? "value" : widget.spec.fieldLabel} '
        '= $_value ${widget.spec.unit}');
  }

  // --- switch ----------------------------------------------------------

  Duration get _dwell => Duration(
        milliseconds:
            (900 + (1 - widget.profile.steadiness).clamp(0.0, 1.0) * 900)
                .round(),
      );

  void _startScan() {
    _scan?.cancel();
    _scan = Timer.periodic(_dwell, (_) {
      if (!mounted) return;
      Haptics.navigate();
      setState(() => _switchMode = (_switchMode + 1) % _switchModes.length);
      widget.onRaw('scan -> ${_switchModes[_switchMode]}');
    });
  }

  void _switchPress() {
    if (_motion != null) {
      // Second press stops the motion and resumes scanning.
      _motion?.cancel();
      _motion = null;
      _startScan();
      return;
    }
    final mode = _switchModes[_switchMode];
    if (mode == 'done') {
      _commit();
      return;
    }
    _scan?.cancel();
    final delta = mode == 'increase' ? 1 : -1;
    _motion = Timer.periodic(
      const Duration(milliseconds: 260),
      (_) => _nudge(delta),
    );
  }

  // --- joystick --------------------------------------------------------

  void _onVector(Offset v) {
    _joyAxis = -v.dy; // up increases
    if (_joyAxis.abs() < 0.25) {
      _joyTicker?.cancel();
      _joyTicker = null;
      return;
    }
    _joyTicker ??= Timer.periodic(const Duration(milliseconds: 90), (_) {
      // Displacement sets speed, not distance: a small push nudges, a full
      // push runs. This is the whole reason the joystick is ideal here.
      final step = (_joyAxis.abs() * 3).ceil() * (_joyAxis > 0 ? 1 : -1);
      _nudge(step);
    });
  }

  void _commit() {
    Haptics.confirm();
    _scan?.cancel();
    _motion?.cancel();
    _joyTicker?.cancel();
    _stepper.stop();
    widget.onResolve(_value);
  }

  @override
  Widget build(BuildContext context) {
    final content = _readout(context);
    return switch (widget.method) {
      TouchMethod.joystick => InputOverlay(
          profile: widget.profile,
          content: content,
          overlay: JoystickPad(
            size: 170,
            label: 'SET',
            onVector: _onVector,
            onPress: _commit,
            onRelease: () {
              _joyTicker?.cancel();
              _joyTicker = null;
            },
          ),
        ),
      TouchMethod.buttons => InputOverlay(
          profile: widget.profile,
          content: content,
          dock: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(child: _stepButton('-', -1)),
                  Expanded(child: _stepButton('+', 1)),
                ],
              ),
              const SizedBox(height: 8),
              CommitBar(
                label: 'Confirm $_value ${widget.spec.unit}',
                textScale: _scale,
                onPressed: _commit,
              ),
            ],
          ),
        ),
      TouchMethod.trackpad => InputOverlay(
          profile: widget.profile,
          content: content,
          dock: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 150,
                child: TrackpadSurface(
                  hint: 'drag up or down to scrub',
                  showCursor: false,
                  axisLock: Axis.vertical,
                  onMove: (n, d) {
                    final range = widget.spec.max - widget.spec.min;
                    final steps = (-d.dy * range * 1.6).round();
                    if (steps != 0) _nudge(steps);
                  },
                ),
              ),
              const SizedBox(height: 8),
              CommitBar(
                label: 'Confirm $_value ${widget.spec.unit}',
                textScale: _scale,
                onPressed: _commit,
              ),
            ],
          ),
        ),
      TouchMethod.switchScan => InputOverlay(
          profile: widget.profile,
          content: Column(
            children: [
              Expanded(child: content),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    for (var i = 0; i < _switchModes.length; i++)
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.all(4),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: i == _switchMode
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            _switchModes[i],
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: i == _switchMode
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          dock: SwitchTrigger(
            label: _motion == null ? 'PRESS TO START' : 'PRESS TO STOP',
            onPress: _switchPress,
          ),
        ),
    };
  }

  // Listener, not GestureDetector: press-and-hold to repeat has to work while
  // the button underneath still handles its own tap, and pointer events do not
  // compete in the gesture arena the way two detectors would.
  Widget _stepButton(String glyph, int delta) => Listener(
        onPointerDown: (_) {
          _stepDirection = delta;
          _stepper.start();
        },
        onPointerUp: (_) => _stepper.stop(),
        onPointerCancel: (_) => _stepper.stop(),
        child: CalibratedButton(
          label: glyph,
          minSize: math.max(widget.profile.minTargetSize, 72),
          textScale: _scale * 1.4,
          onPressed: () {},
        ),
      );

  Widget _readout(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final range = widget.spec.max - widget.spec.min;
    final t = range == 0 ? 0.0 : (_value - widget.spec.min) / range;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$_value',
            style: TextStyle(
              fontSize: 72 * _scale,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          Text(
            widget.spec.unit,
            style: TextStyle(
              fontSize: 18 * _scale,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(value: t, minHeight: 16),
          ),
        ],
      ),
    );
  }
}
