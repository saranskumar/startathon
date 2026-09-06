import 'package:flutter/material.dart';

import '../model/profile.dart';

/// Visual-field overlay (issue #4).
///
/// Tunnel: input still hits anywhere (the mask ignores pointers); *output*
/// is condensed into one window so they do not have to scan the whole screen.
/// Peripheral: issue #4 flagged this as research-first. The shipped pattern
/// for central vision loss is eccentric viewing — keep information off the
/// scotoma (the center) and on the ring, plus high contrast on the theme.
/// The veil is IgnorePointer so aiming is not constrained to the visible hole.
class VisualFieldShell extends StatelessWidget {
  const VisualFieldShell({
    super.key,
    required this.field,
    required this.child,
    this.outputAtBottom = false,
  });

  final VisualField field;
  final Widget child;
  final bool outputAtBottom;

  @override
  Widget build(BuildContext context) {
    if (field == VisualField.full) return child;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return Stack(
          fit: StackFit.expand,
          children: [
            child,
            IgnorePointer(
              child: CustomPaint(
                size: size,
                painter: _FieldMaskPainter(
                  field: field,
                  window: _window(size),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Rect _window(Size size) {
    if (field == VisualField.tunnel) {
      final w = size.width * 0.72;
      final h = size.height * 0.34;
      final top = outputAtBottom ? size.height - h - 16 : 16.0;
      return Rect.fromLTWH((size.width - w) / 2, top, w, h);
    }
    // Peripheral: the *blocked* region is the center. The painter inverts.
    final w = size.width * 0.46;
    final h = size.height * 0.40;
    return Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: w,
      height: h,
    );
  }
}

class _FieldMaskPainter extends CustomPainter {
  _FieldMaskPainter({required this.field, required this.window});

  final VisualField field;
  final Rect window;

  @override
  void paint(Canvas canvas, Size size) {
    final veil = Paint()..color = const Color(0xCC000000);
    final hole = Path()
      ..addRRect(RRect.fromRectAndRadius(window, const Radius.circular(18)));
    if (field == VisualField.tunnel) {
      final full = Path()..addRect(Offset.zero & size);
      canvas.drawPath(
        Path.combine(PathOperation.difference, full, hole),
        veil,
      );
      final rim = Paint()
        ..color = const Color(0xFFFFFF00)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(window, const Radius.circular(18)),
        rim,
      );
    } else {
      // Peripheral-only: veil the center, leave the edges.
      canvas.drawPath(hole, veil);
    }
  }

  @override
  bool shouldRepaint(covariant _FieldMaskPainter old) =>
      old.field != field || old.window != window;
}
