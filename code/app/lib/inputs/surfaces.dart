import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Raw input surfaces. These know nothing about tasks -- they only turn finger
/// movement into normalised numbers. Every task-specific behaviour (cycling a
/// list, scrolling, placing a cursor) is built on top of these in tasks.dart,
/// which is what lets the same physical surface drive a discrete choice, a
/// continuous adjust, or free pointing.

/// A translucent, floating joystick.
///
/// Deliberately an overlay rather than a docked panel: it is anchored to the
/// user's reachable zone (profile.reachAnchor) and floats above the task
/// content so it can sit wherever the hand actually rests, not where the layout
/// would prefer.
class JoystickPad extends StatefulWidget {
  const JoystickPad({
    super.key,
    required this.onVector,
    this.onPress,
    this.onRelease,
    this.size = 180,
    this.label,
    this.tint,
    this.deadZone = 0.18,
  });

  /// Normalised stick displacement, each axis in -1..1, magnitude clamped to 1.
  /// Emits Offset.zero on release.
  final ValueChanged<Offset> onVector;

  /// Tap on the stick without dragging -- the joystick's "confirm" button.
  final VoidCallback? onPress;
  final VoidCallback? onRelease;
  final double size;
  final String? label;
  final Color? tint;
  final double deadZone;

  @override
  State<JoystickPad> createState() => _JoystickPadState();
}

class _JoystickPadState extends State<JoystickPad> {
  Offset _knob = Offset.zero;
  bool _active = false;

  void _update(Offset local) {
    final r = widget.size / 2;
    var v = Offset((local.dx - r) / r, (local.dy - r) / r);
    if (v.distance > 1) v = v / v.distance;
    if (v.distance < widget.deadZone) v = Offset.zero;
    setState(() => _knob = v);
    widget.onVector(v);
  }

  void _end() {
    setState(() {
      _knob = Offset.zero;
      _active = false;
    });
    widget.onVector(Offset.zero);
    widget.onRelease?.call();
  }

  @override
  Widget build(BuildContext context) {
    final tint = widget.tint ?? Theme.of(context).colorScheme.primary;
    final r = widget.size / 2;
    final knobSize = widget.size * 0.42;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onPress,
      onPanStart: (d) {
        setState(() => _active = true);
        _update(d.localPosition);
      },
      onPanUpdate: (d) => _update(d.localPosition),
      onPanEnd: (_) => _end(),
      onPanCancel: _end,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Base ring -- translucent so the task content stays readable
            // underneath it.
            Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: tint.withValues(alpha: _active ? 0.16 : 0.10),
                border: Border.all(
                  color: tint.withValues(alpha: _active ? 0.75 : 0.45),
                  width: 2,
                ),
              ),
            ),
            // Cardinal hints.
            ..._cardinals(tint, r),
            Positioned(
              left: r + _knob.dx * (r - knobSize / 2) - knobSize / 2,
              top: r + _knob.dy * (r - knobSize / 2) - knobSize / 2,
              child: Container(
                key: const ValueKey('joystick-knob'),
                width: knobSize,
                height: knobSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: tint.withValues(alpha: _active ? 0.92 : 0.65),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: widget.label == null
                    ? null
                    : Center(
                        child: Text(
                          widget.label!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _cardinals(Color tint, double r) {
    final glyphs = <Alignment, IconData>{
      Alignment.topCenter: Icons.keyboard_arrow_up,
      Alignment.bottomCenter: Icons.keyboard_arrow_down,
      Alignment.centerLeft: Icons.keyboard_arrow_left,
      Alignment.centerRight: Icons.keyboard_arrow_right,
    };
    return [
      for (final e in glyphs.entries)
        Align(
          alignment: e.key,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(e.value, size: 18, color: tint.withValues(alpha: 0.5)),
          ),
        ),
    ];
  }
}

/// A drag surface. Reports both absolute position (0..1 within the pad) and
/// per-axis delta, so a task can treat it as absolute pointing or as relative
/// scrolling without a second widget.
class TrackpadSurface extends StatefulWidget {
  const TrackpadSurface({
    super.key,
    this.onStart,
    this.onMove,
    this.onEnd,
    this.onTapAt,
    this.hint,
    this.showCursor = true,
    this.axisLock,
  });

  final void Function(Offset normalized)? onStart;

  /// [normalized] is the current point in 0..1; [delta] is the movement since
  /// the previous callback, also normalised to pad size.
  final void Function(Offset normalized, Offset delta)? onMove;
  final void Function(Offset normalized)? onEnd;
  final void Function(Offset normalized)? onTapAt;
  final String? hint;
  final bool showCursor;

  /// Per-axis capability from calibration: null = both axes, Axis.horizontal =
  /// X-only, Axis.vertical = Y-only. The meeting notes in docs/idea/20 asked
  /// for this; movement on the unusable axis is discarded rather than fought.
  final Axis? axisLock;

  @override
  State<TrackpadSurface> createState() => _TrackpadSurfaceState();
}

class _TrackpadSurfaceState extends State<TrackpadSurface> {
  Offset? _point;
  Size _size = Size.zero;

  Offset _norm(Offset local) => Offset(
        _size.width == 0 ? 0 : (local.dx / _size.width).clamp(0.0, 1.0),
        _size.height == 0 ? 0 : (local.dy / _size.height).clamp(0.0, 1.0),
      );

  Offset _applyLock(Offset delta) => switch (widget.axisLock) {
        Axis.horizontal => Offset(delta.dx, 0),
        Axis.vertical => Offset(0, delta.dy),
        null => delta,
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        _size = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) {
            final n = _norm(d.localPosition);
            setState(() => _point = n);
            widget.onTapAt?.call(n);
          },
          onPanStart: (d) {
            final n = _norm(d.localPosition);
            setState(() => _point = n);
            widget.onStart?.call(n);
          },
          onPanUpdate: (d) {
            final n = _norm(d.localPosition);
            final delta = _applyLock(Offset(
              _size.width == 0 ? 0 : d.delta.dx / _size.width,
              _size.height == 0 ? 0 : d.delta.dy / _size.height,
            ));
            setState(() => _point = n);
            widget.onMove?.call(n, delta);
          },
          onPanEnd: (_) {
            final n = _point ?? Offset.zero;
            widget.onEnd?.call(n);
          },
          child: Container(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Stack(
              children: [
                if (widget.hint != null && _point == null)
                  Center(
                    child: Text(
                      widget.hint!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ),
                if (widget.showCursor && _point != null)
                  Positioned(
                    left: _point!.dx * _size.width - 16,
                    top: _point!.dy * _size.height - 16,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: scheme.primary.withValues(alpha: 0.35),
                        border: Border.all(color: scheme.primary, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The single always-reachable trigger for switch scanning (3.5). One big zone,
/// no aiming required.
class SwitchTrigger extends StatelessWidget {
  const SwitchTrigger({
    super.key,
    required this.onPress,
    this.label = 'PRESS',
    this.height = 120,
  });

  final VoidCallback onPress;
  final String label;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => onPress(),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: scheme.primary.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: scheme.primary, width: 3),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
            color: scheme.primary,
          ),
        ),
      ),
    );
  }
}

/// A tap target whose size comes from the profile, not from the layout.
class CalibratedButton extends StatelessWidget {
  const CalibratedButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.minSize = 56,
    this.highlighted = false,
    this.subtitle,
    this.textScale = 1.0,
  });

  final String label;
  final String? subtitle;
  final VoidCallback onPressed;
  final double minSize;
  final bool highlighted;
  final double textScale;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Builder(
        builder: (context) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            constraints: BoxConstraints(minHeight: minSize, minWidth: minSize),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: highlighted
                  ? scheme.primary
                  : scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: highlighted ? scheme.primary : scheme.outlineVariant,
                width: highlighted ? 3 : 1,
              ),
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17 * textScale,
                    fontWeight: FontWeight.w700,
                    color: highlighted ? scheme.onPrimary : scheme.onSurface,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12 * textScale,
                      color: highlighted
                          ? scheme.onPrimary.withValues(alpha: 0.85)
                          : scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Distance in logical pixels between two points, used by the calibration
/// tests to compute the error term.
double distanceBetween(Offset a, Offset b) =>
    math.sqrt(math.pow(a.dx - b.dx, 2) + math.pow(a.dy - b.dy, 2));
