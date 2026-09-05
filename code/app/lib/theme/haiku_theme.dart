import 'package:flutter/material.dart';

/// A depiction of the measured mix, not a "personality of disability".
///
/// Each environment the user chose to measure (Motor / Speech / Vision) has a
/// seed color. The theme blends whichever seeds are on, weighted a little
/// toward the ones that scored well once calibration has real numbers -- so
/// motor+speech looks different from speech+vision, and everyone's particular
/// mix is its own combination rather than one of three flat skins.
///
/// The four lines below are decorative framing around the real numbers
/// (still shown on the results screen as plain scores) -- never a clinical
/// summary, and the wording never uses "defective" / "impaired" / a
/// diagnosis. See docs/desgin/desgin.md.
class HaikuTheme {
  const HaikuTheme({
    required this.colorScheme,
    required this.seedColor,
    required this.emotion,
    required this.value,
    required this.blessing,
  });

  final ColorScheme colorScheme;
  final Color seedColor;

  /// Short vibe word from the mix (e.g. "steady", "soft", "bright").
  final String emotion;

  /// One principle the mix implies (e.g. "controls stay where your hand is").
  final String value;

  /// Three-line haiku. Decorative only.
  final String blessing;

  static const Color motorSeed = Color(0xFFE4B301); // yellow
  static const Color speechSeed = Color(0xFF2F5BEA); // blue -- the app's original seed
  static const Color visionSeed = Color(0xFFE45A8C); // pink

  static const HaikuTheme fallback = HaikuTheme(
    colorScheme: ColorScheme.light(primary: speechSeed),
    seedColor: speechSeed,
    emotion: 'steady',
    value: 'the interface waits for you, not the other way around',
    blessing: 'Quiet screen, one light --\nhands find their own steady pace,\nthe door opens soft.',
  );

  /// [motorScore] / [speechScore] / [visionScore] are 0..1, 0 before
  /// calibration has run. At least one of the three booleans must be true;
  /// callers (the intro screen) enforce that.
  factory HaikuTheme.compute({
    required bool motor,
    required bool speech,
    required bool vision,
    double motorScore = 0,
    double speechScore = 0,
    double visionScore = 0,
    Brightness brightness = Brightness.light,
  }) {
    final weighted = <(Color, double)>[
      if (motor) (motorSeed, 0.4 + 0.6 * motorScore.clamp(0.0, 1.0)),
      if (speech) (speechSeed, 0.4 + 0.6 * speechScore.clamp(0.0, 1.0)),
      if (vision) (visionSeed, 0.4 + 0.6 * visionScore.clamp(0.0, 1.0)),
    ];
    if (weighted.isEmpty) return fallback;

    final blended = _blend(weighted);
    final scheme = ColorScheme.fromSeed(
      seedColor: blended,
      brightness: brightness,
    );

    final enabled = <String>[
      if (motor) 'motor',
      if (speech) 'speech',
      if (vision) 'vision',
    ];
    final avgScore = weighted.isEmpty
        ? 0.0
        : weighted.map((e) => e.$2).reduce((a, b) => a + b) / weighted.length;

    return HaikuTheme(
      colorScheme: scheme,
      seedColor: blended,
      emotion: _emotion(enabled, avgScore),
      value: _value(enabled),
      blessing: _blessing(enabled),
    );
  }

  static Color _blend(List<(Color, double)> weighted) {
    final total = weighted.map((e) => e.$2).reduce((a, b) => a + b);
    var r = 0.0, g = 0.0, b = 0.0;
    for (final (color, weight) in weighted) {
      final share = weight / total;
      r += color.r * share;
      g += color.g * share;
      b += color.b * share;
    }
    return Color.from(alpha: 1.0, red: r, green: g, blue: b);
  }

  static String _emotion(List<String> axes, double avgScore) {
    final tier = avgScore < 0.35 ? 0 : (avgScore < 0.7 ? 1 : 2);
    final key = axes.join('+');
    const words = <String, List<String>>{
      'motor': ['gentle', 'steady', 'sure'],
      'speech': ['quiet', 'clear', 'warm'],
      'vision': ['soft', 'bright', 'vivid'],
      'motor+speech': ['patient', 'grounded', 'confident'],
      'motor+vision': ['careful', 'balanced', 'sharp'],
      'speech+vision': ['gentle', 'attentive', 'radiant'],
      'motor+speech+vision': ['tentative', 'blended', 'whole'],
    };
    final list = words[key] ?? const ['steady', 'steady', 'steady'];
    return list[tier];
  }

  static String _value(List<String> axes) {
    const principles = <String, String>{
      'motor': 'controls stay where your hand actually rests',
      'speech': 'words are given time to land, however they arrive',
      'vision': 'text grows until it is actually readable',
      'motor+speech': 'controls stay where your hand rests, and words are given time to land',
      'motor+vision': 'controls stay in reach, sized for what you can actually see',
      'speech+vision': 'what you hear and what you read say the same thing, at a size that works',
      'motor+speech+vision': 'every part of this bends toward the one measurement that is actually you',
    };
    return principles[axes.join('+')] ?? principles['motor']!;
  }

  static String _blessing(List<String> axes) {
    const haiku = <String, String>{
      'motor': 'Steady hand, slow root --\nthe stick waits inside your reach,\nnothing asks for more.',
      'speech': 'Small sound, wide door --\nthe words that come are enough,\npatience holds the line.',
      'vision': 'Letters grow like light,\nuntil the word finally lands --\nnothing hides from you.',
      'motor+speech': 'Two hands, one soft voice --\nthe screen leans toward whichever\narrives at the door.',
      'motor+vision': 'Reach meets a wide leaf,\nthe target grows where you are --\nnothing asks you to.',
      'speech+vision': 'A word, a bright shape --\nboth say the same quiet thing,\nread it either way.',
      'motor+speech+vision': 'Three small roots, one tree --\nyellow, blue, and pink leaves turn\ntoward however you arrive.',
    };
    return haiku[axes.join('+')] ?? haiku['motor']!;
  }
}

/// A small, asset-free person + leaves motif, tinted with the theme's blend.
/// Decorative background accent -- used on the intro, results, and preview
/// strip, never behind text that needs full contrast.
class HaikuMotif extends StatelessWidget {
  const HaikuMotif({super.key, required this.color, this.opacity = 0.14});

  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Opacity(
        opacity: opacity,
        child: CustomPaint(
          painter: _HaikuMotifPainter(color: color),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _HaikuMotifPainter extends CustomPainter {
  _HaikuMotifPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final w = size.width, h = size.height;

    // A simple standing person, lower-right.
    final personCx = w * 0.86, personBaseY = h * 0.92;
    final headR = w * 0.02;
    canvas.drawCircle(Offset(personCx, personBaseY - headR * 5), headR, paint);
    final body = Path()
      ..moveTo(personCx - headR * 0.9, personBaseY - headR * 3.6)
      ..quadraticBezierTo(
        personCx, personBaseY - headR * 4.4,
        personCx + headR * 0.9, personBaseY - headR * 3.6,
      )
      ..lineTo(personCx + headR * 0.6, personBaseY)
      ..lineTo(personCx - headR * 0.6, personBaseY)
      ..close();
    canvas.drawPath(body, paint);

    // A scatter of simple leaf shapes.
    final leafSpots = <Offset>[
      Offset(w * 0.08, h * 0.15),
      Offset(w * 0.18, h * 0.08),
      Offset(w * 0.05, h * 0.30),
      Offset(w * 0.92, h * 0.20),
      Offset(w * 0.80, h * 0.08),
      Offset(w * 0.12, h * 0.85),
    ];
    for (var i = 0; i < leafSpots.length; i++) {
      _leaf(canvas, paint, leafSpots[i], (w * 0.05).clamp(10, 26), i.isEven);
    }
  }

  void _leaf(Canvas canvas, Paint paint, Offset at, double size, bool tiltRight) {
    final path = Path()..moveTo(at.dx, at.dy);
    final dx = tiltRight ? size : -size;
    path.quadraticBezierTo(at.dx + dx * 0.6, at.dy - size, at.dx + dx, at.dy);
    path.quadraticBezierTo(at.dx + dx * 0.6, at.dy + size, at.dx, at.dy);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _HaikuMotifPainter oldDelegate) =>
      oldDelegate.color != color;
}
