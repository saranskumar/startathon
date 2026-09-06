import 'dart:async';

import 'package:flutter/material.dart';

/// Press-and-hold until [duration] elapses, then [onComplete].
///
/// Shared by the axis picker (hold a row to skip it) and [HoldStep] (the
/// calibration test). A quick tap never counts as a hold -- turning something
/// off has to be harder than leaving it on, because this screen is used by
/// the same people the later motor test is measuring.
class HoldFill extends StatefulWidget {
  const HoldFill({
    super.key,
    required this.builder,
    this.duration = standard,
    this.armed = true,
    this.onComplete,
    this.onCancel,
    this.onTap,
    this.onDown,
    this.onMove,
    this.behavior = HitTestBehavior.opaque,
  });

  /// Same length the hold calibration test uses, so "hold" means the same
  /// thing everywhere in this app.
  static const Duration standard = Duration(milliseconds: 1500);

  final Duration duration;

  /// When false, pointer-down does not start a fill. A short press then
  /// becomes [onTap] (re-enable an axis that was skipped).
  final bool armed;

  final VoidCallback? onComplete;
  final void Function(Duration held)? onCancel;
  final VoidCallback? onTap;
  final void Function(Offset localPosition)? onDown;
  final void Function(Offset localPosition)? onMove;
  final HitTestBehavior behavior;
  final Widget Function(BuildContext context, double progress) builder;

  @override
  State<HoldFill> createState() => _HoldFillState();
}

class _HoldFillState extends State<HoldFill> {
  static const _tick = Duration(milliseconds: 50);

  Timer? _ticker;
  int _elapsedMs = 0;
  bool _holding = false;
  bool _completedThisPress = false;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _down(Offset local) {
    widget.onDown?.call(local);
    _completedThisPress = false;
    _elapsedMs = 0;
    _ticker?.cancel();
    if (!widget.armed) return;
    _holding = true;
    _ticker = Timer.periodic(_tick, (_) {
      if (!mounted) return;
      setState(() => _elapsedMs += _tick.inMilliseconds);
      if (_elapsedMs >= widget.duration.inMilliseconds) _complete();
    });
  }

  void _complete() {
    if (_completedThisPress) return;
    _completedThisPress = true;
    _ticker?.cancel();
    setState(() => _elapsedMs = widget.duration.inMilliseconds);
    widget.onComplete?.call();
  }

  void _up() {
    _ticker?.cancel();
    final completed = _completedThisPress;
    final wasHolding = _holding;
    final held = Duration(milliseconds: _elapsedMs);
    _holding = false;
    _completedThisPress = false;
    if (mounted && _elapsedMs != 0) {
      setState(() => _elapsedMs = 0);
    }
    // A completed hold must not also fire [onTap] on release -- otherwise
    // skipping an axis would immediately turn it back on.
    if (completed) return;
    if (wasHolding) {
      widget.onCancel?.call(held);
      return;
    }
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final progress =
        (_elapsedMs / widget.duration.inMilliseconds).clamp(0.0, 1.0);
    return Listener(
      behavior: widget.behavior,
      onPointerDown: (e) => _down(e.localPosition),
      onPointerMove: (e) => widget.onMove?.call(e.localPosition),
      onPointerUp: (_) => _up(),
      onPointerCancel: (_) => _up(),
      child: widget.builder(context, progress),
    );
  }
}

/// Circular ring that fills with [progress]. Same visual language as the
/// hold calibration test, sized down for a row when needed.
class HoldFillRing extends StatelessWidget {
  const HoldFillRing({
    super.key,
    required this.progress,
    this.size = 140,
    this.strokeWidth = 12,
    this.child,
  });

  final double progress;
  final double size;
  final double strokeWidth;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: strokeWidth,
            ),
          ),
          ?child,
        ],
      ),
    );
  }
}
