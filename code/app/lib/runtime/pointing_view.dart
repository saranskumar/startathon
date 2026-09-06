import 'dart:async';

import 'package:flutter/material.dart';

import '../inputs/haptics.dart';
import '../inputs/surfaces.dart';
import '../model/profile.dart';
import 'dock.dart';

/// Free 2D pointing.
///
/// This is where 2.4's precision-inference coupling shows up most plainly: the
/// trackpad version asks the user for an exact point, while the buttons version
/// -- the most indirect fallback in the whole matrix -- narrows the screen for
/// them a quadrant at a time and lets the agent suggest which quadrant to take.
/// The less the input can specify, the more the system fills in.
class PointingTaskView extends StatefulWidget {
  const PointingTaskView({
    super.key,
    required this.profile,
    required this.method,
    required this.goal,
    required this.onResolve,
    required this.onRaw,
    this.agentAssist = true,
  });

  final CapabilityProfile profile;
  final TouchMethod method;

  /// Where the task actually wants the marker, normalised 0..1. Used to score
  /// the result, and -- for the indirect fallbacks only -- to let the agent
  /// hint at the right region.
  final Offset goal;
  final void Function(Offset point, double errorFraction) onResolve;
  final void Function(String raw) onRaw;
  final bool agentAssist;

  @override
  State<PointingTaskView> createState() => _PointingTaskViewState();
}

class _PointingTaskViewState extends State<PointingTaskView> {
  Offset _cursor = const Offset(0.5, 0.5);

  /// Buttons fallback: the region still in play.
  Rect _region = const Rect.fromLTWH(0, 0, 1, 1);
  int _level = 0;

  /// Switch fallback: 0 = scanning rows, 1 = scanning columns.
  int _phase = 0;
  int _row = 0;
  int _col = 0;
  Timer? _scan;
  Timer? _joyTicker;
  Offset _joyVector = Offset.zero;

  static const _gridN = 4;

  double get _scale => widget.profile.vision.textScale;

  @override
  void initState() {
    super.initState();
    if (widget.method == TouchMethod.switchScan) _startScan();
  }

  @override
  void dispose() {
    _scan?.cancel();
    _joyTicker?.cancel();
    super.dispose();
  }

  void _resolve(Offset point) {
    Haptics.confirm();
    _scan?.cancel();
    _joyTicker?.cancel();
    final err = (point - widget.goal).distance;
    widget.onResolve(point, err);
  }

  // --- switch scanning -------------------------------------------------

  Duration get _dwell => widget.profile.scanDwell;

  void _startScan() {
    _scan?.cancel();
    _scan = Timer.periodic(_dwell, (_) {
      if (!mounted) return;
      Haptics.navigate();
      setState(() {
        if (_phase == 0) {
          _row = (_row + 1) % _gridN;
        } else {
          _col = (_col + 1) % _gridN;
        }
      });
      widget.onRaw(_phase == 0 ? 'scan row $_row' : 'scan column $_col');
    });
  }

  void _switchPress() {
    if (_phase == 0) {
      setState(() => _phase = 1);
      _startScan();
      return;
    }
    _resolve(Offset((_col + 0.5) / _gridN, (_row + 0.5) / _gridN));
  }

  // --- joystick --------------------------------------------------------

  void _onVector(Offset v) {
    _joyVector = v;
    if (v.distance < 0.2) {
      _joyTicker?.cancel();
      _joyTicker = null;
      return;
    }
    _joyTicker ??= Timer.periodic(const Duration(milliseconds: 60), (_) {
      setState(() {
        _cursor = Offset(
          (_cursor.dx + _joyVector.dx * 0.02).clamp(0.0, 1.0),
          (_cursor.dy + _joyVector.dy * 0.02).clamp(0.0, 1.0),
        );
      });
      widget.onRaw(
          'cursor ${_cursor.dx.toStringAsFixed(2)}, ${_cursor.dy.toStringAsFixed(2)}');
    });
  }

  // --- buttons: coarse-to-fine ----------------------------------------

  /// Which quadrant of the current region contains the goal. This is the
  /// agent's inference, shown as a suggestion and never auto-applied -- 2.4's
  /// confirmation gate applies to help as much as to actions.
  int get _suggestedQuadrant {
    final cx = _region.left + _region.width / 2;
    final cy = _region.top + _region.height / 2;
    final right = widget.goal.dx >= cx;
    final bottom = widget.goal.dy >= cy;
    return (bottom ? 2 : 0) + (right ? 1 : 0);
  }

  void _pickQuadrant(int q) {
    final half = Size(_region.width / 2, _region.height / 2);
    final left = _region.left + (q % 2 == 1 ? half.width : 0);
    final top = _region.top + (q >= 2 ? half.height : 0);
    final next = Rect.fromLTWH(left, top, half.width, half.height);
    setState(() {
      _region = next;
      _level++;
      _cursor = next.center;
    });
    widget.onRaw('narrowed to '
        '${next.left.toStringAsFixed(2)},${next.top.toStringAsFixed(2)} '
        '(${next.width.toStringAsFixed(2)} wide)');
    if (_level >= 3) _resolve(next.center);
  }

  // --- build -----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return switch (widget.method) {
      TouchMethod.trackpad => InputOverlay(
          profile: widget.profile,
          content: _field(context),
          dock: SizedBox(
            height: 200,
            child: TrackpadSurface(
              hint: 'drag to move the marker, let go to place it',
              axisLock: null,
              // Tapping repositions the marker but does not place it: placing
              // is always a deliberate release at the end of a drag.
              onTapAt: (n) => setState(() => _cursor = n),
              onStart: (n) => setState(() => _cursor = n),
              onMove: (n, _) {
                setState(() => _cursor = n);
                widget.onRaw('cursor '
                    '${n.dx.toStringAsFixed(2)}, ${n.dy.toStringAsFixed(2)}');
              },
              onEnd: (n) => _resolve(n),
            ),
          ),
        ),
      TouchMethod.joystick => InputOverlay(
          profile: widget.profile,
          content: _field(context),
          overlay: JoystickPad(
            size: 160,
            label: 'PLACE',
            onVector: _onVector,
            onPress: () => _resolve(_cursor),
            onRelease: () {
              _joyTicker?.cancel();
              _joyTicker = null;
            },
          ),
        ),
      TouchMethod.buttons => InputOverlay(
          profile: widget.profile,
          content: _field(context),
          dock: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.agentAssist)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Icon(Icons.auto_awesome,
                          size: 16,
                          color: Theme.of(context).colorScheme.tertiary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'suggested: '
                          '${_quadrantNames[_suggestedQuadrant]} '
                          '(step ${_level + 1} of 3)',
                          style: TextStyle(
                            fontSize: 12 * _scale,
                            color: Theme.of(context).colorScheme.tertiary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Row(
                children: [
                  Expanded(child: _quadrantButton(0)),
                  Expanded(child: _quadrantButton(1)),
                ],
              ),
              Row(
                children: [
                  Expanded(child: _quadrantButton(2)),
                  Expanded(child: _quadrantButton(3)),
                ],
              ),
            ],
          ),
        ),
      TouchMethod.switchScan => InputOverlay(
          profile: widget.profile,
          content: _field(context),
          dock: SwitchTrigger(
            label: _phase == 0 ? 'PRESS ON THE ROW' : 'PRESS ON THE COLUMN',
            onPress: _switchPress,
          ),
        ),
    };
  }

  static const _quadrantNames = [
    'top left',
    'top right',
    'bottom left',
    'bottom right',
  ];

  Widget _quadrantButton(int q) => CalibratedButton(
        label: _quadrantNames[q],
        minSize: widget.profile.minTargetSize,
        textScale: _scale * 0.9,
        highlighted: widget.agentAssist && q == _suggestedQuadrant,
        onPressed: () => _pickQuadrant(q),
      );

  Widget _field(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth, h = constraints.maxHeight;
          return Container(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Stack(
              children: [
                // Goal.
                Positioned(
                  left: widget.goal.dx * w - 22,
                  top: widget.goal.dy * h - 22,
                  child: Icon(Icons.place_outlined,
                      size: 44, color: scheme.tertiary),
                ),
                // Switch scanning bands.
                if (widget.method == TouchMethod.switchScan) ...[
                  Positioned(
                    left: 0,
                    right: 0,
                    top: _row * h / _gridN,
                    height: h / _gridN,
                    child: Container(
                      color: scheme.primary
                          .withValues(alpha: _phase == 0 ? 0.28 : 0.14),
                    ),
                  ),
                  if (_phase == 1)
                    Positioned(
                      top: 0,
                      bottom: 0,
                      left: _col * w / _gridN,
                      width: w / _gridN,
                      child:
                          Container(color: scheme.primary.withValues(alpha: 0.28)),
                    ),
                ],
                // Buttons narrowing region.
                if (widget.method == TouchMethod.buttons)
                  Positioned(
                    left: _region.left * w,
                    top: _region.top * h,
                    width: _region.width * w,
                    height: _region.height * h,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: scheme.primary, width: 3),
                        color: scheme.primary.withValues(alpha: 0.10),
                      ),
                    ),
                  ),
                // Cursor.
                if (widget.method == TouchMethod.trackpad ||
                    widget.method == TouchMethod.joystick)
                  Positioned(
                    left: _cursor.dx * w - 16,
                    top: _cursor.dy * h - 16,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: scheme.primary.withValues(alpha: 0.4),
                        border: Border.all(color: scheme.primary, width: 3),
                      ),
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
