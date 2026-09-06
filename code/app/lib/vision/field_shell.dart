import 'package:flutter/material.dart';

import '../model/profile.dart';

/// Visual-field shell (issue #4).
///
/// The overlay is **not painted** right now — tunnel / peripheral values stay
/// on the profile for later. When the real tunnel layout ships, all buttons,
/// text, and options live inside one square (see docs/app/04).
///
/// Keep this widget in the tree so callers do not special-case field. The
/// mask painter is retained unused so the later layout can reuse the window
/// math.
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
  Widget build(BuildContext context) => child;

  /// Visible-window rect the later tunnel layout will use. Not painted today.
  Rect windowFor(Size size) {
    if (field == VisualField.tunnel) {
      final w = size.width * 0.72;
      final h = size.height * 0.34;
      final top = outputAtBottom ? size.height - h - 16 : 16.0;
      return Rect.fromLTWH((size.width - w) / 2, top, w, h);
    }
    final w = size.width * 0.46;
    final h = size.height * 0.40;
    return Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: w,
      height: h,
    );
  }
}

/// Kept for the later field layout. Not mounted while the overlay is deferred.
class FieldMaskPainter extends CustomPainter {
  FieldMaskPainter({required this.field, required this.window});

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
      canvas.drawPath(hole, veil);
    }
  }

  @override
  bool shouldRepaint(covariant FieldMaskPainter old) =>
      old.field != field || old.window != window;
}
