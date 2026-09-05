import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../model/profile.dart';

/// Voice input.
///
/// There is no microphone plugin in this build on purpose: the app has no
/// package dependencies beyond the Flutter SDK, and nothing is wired to a real
/// recogniser yet (docs/tech/README.md still lists the speech API as undecided).
/// So the *interaction* is real -- press-and-hold timing, sound counting, the
/// clarity tiers, the confirmation gate -- and only the recogniser behind it is
/// a stub. Swapping in a real one means implementing [SpeechSource] once;
/// nothing else in the app touches recognition.

class SpeechResult {
  const SpeechResult({
    required this.ok,
    this.transcript = '',
    this.confidence = 0,
    this.soundCount = 0,
  });

  final bool ok;
  final String transcript;
  final double confidence;

  /// Number of separate vocalisations detected. The `sounds` tier's whole
  /// vocabulary (docs/idea/20: 1 sound = yes, 2 = no).
  final int soundCount;
}

abstract class SpeechSource {
  /// [heldMs] is total vocalisation time, [soundCount] the number of separate
  /// utterances -- both measured by the UI, not by the recogniser, so they stay
  /// meaningful even for a user whose words are not parseable.
  Future<SpeechResult> capture({
    required int heldMs,
    required int soundCount,
    required SpeechClarity clarity,
  });
}

/// Stub recogniser. Degrades its output by clarity tier so the downstream
/// confirmation behaviour is exercised the way it would be with a real API.
class SimulatedSpeechSource implements SpeechSource {
  SimulatedSpeechSource({List<String>? phrases, math.Random? random})
      : _phrases = phrases ??
            const [
              'leave it at the front desk',
              'ring the bell twice',
              'call me when you arrive',
              'the gate code is four four two one',
            ],
        _random = random ?? math.Random();

  final List<String> _phrases;
  final math.Random _random;
  int _next = 0;

  @override
  Future<SpeechResult> capture({
    required int heldMs,
    required int soundCount,
    required SpeechClarity clarity,
  }) async {
    // Recognition latency scales with how long the user spoke, so the patience
    // the `partial` tier needs is visible in the demo rather than hypothetical.
    await Future<void>.delayed(
      Duration(milliseconds: 350 + (heldMs ~/ 4).clamp(0, 900)),
    );

    if (clarity == SpeechClarity.none) return const SpeechResult(ok: false);

    if (clarity == SpeechClarity.sounds) {
      // No words -- only that something was vocalised, and how many times.
      return SpeechResult(ok: heldMs > 120, soundCount: soundCount);
    }

    // Too short to be a phrase: treat as a failed capture, which is the common
    // real-world case and the one the retry path exists for.
    if (heldMs < 400) {
      return SpeechResult(ok: false, soundCount: soundCount);
    }

    final phrase = _phrases[_next++ % _phrases.length];
    if (clarity == SpeechClarity.full) {
      return SpeechResult(
        ok: true,
        transcript: phrase,
        confidence: 0.86 + _random.nextDouble() * 0.12,
        soundCount: soundCount,
      );
    }
    // partial: drop a word here and there and report low confidence, so the
    // "confirm each field" behaviour has something to confirm.
    final words = phrase.split(' ');
    final kept = <String>[
      for (final w in words)
        if (_random.nextDouble() > 0.22) w else '...',
    ];
    return SpeechResult(
      ok: true,
      transcript: kept.join(' '),
      confidence: 0.42 + _random.nextDouble() * 0.22,
      soundCount: soundCount,
    );
  }
}

/// Press and hold to vocalise. Counts separate presses inside a short window so
/// the `sounds` tier gets its 1-sound / 2-sound vocabulary, and reports total
/// held time so the recogniser stub can behave like a patient one.
class HoldToSpeak extends StatefulWidget {
  const HoldToSpeak({
    super.key,
    required this.onUtterance,
    this.label = 'Hold to speak',
    this.height = 110,
    this.settleMs = 900,
    this.enabled = true,
  });

  /// Fired once the user has stopped vocalising for [settleMs].
  final void Function(int soundCount, int heldMs) onUtterance;
  final String label;
  final double height;

  /// How long a gap ends the utterance. Generous on purpose -- a user whose
  /// speech is slow should not have their sentence cut in half.
  final int settleMs;
  final bool enabled;

  @override
  State<HoldToSpeak> createState() => _HoldToSpeakState();
}

class _HoldToSpeakState extends State<HoldToSpeak> {
  final Stopwatch _watch = Stopwatch();
  Timer? _settle;
  int _sounds = 0;
  int _heldMs = 0;
  bool _down = false;

  @override
  void dispose() {
    _settle?.cancel();
    super.dispose();
  }

  void _start() {
    if (!widget.enabled) return;
    _settle?.cancel();
    _watch.reset();
    _watch.start();
    setState(() => _down = true);
  }

  void _stop() {
    if (!_down) return;
    _watch.stop();
    _heldMs += _watch.elapsedMilliseconds;
    _sounds += 1;
    setState(() => _down = false);
    _settle = Timer(Duration(milliseconds: widget.settleMs), () {
      final sounds = _sounds, held = _heldMs;
      _sounds = 0;
      _heldMs = 0;
      if (mounted) setState(() {});
      widget.onUtterance(sounds, held);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = _down;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _start(),
      onTapUp: (_) => _stop(),
      onTapCancel: _stop,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: widget.height,
        decoration: BoxDecoration(
          color: !widget.enabled
              ? scheme.surfaceContainerHighest
              : active
                  ? scheme.tertiary.withValues(alpha: 0.35)
                  : scheme.tertiary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: widget.enabled
                ? scheme.tertiary.withValues(alpha: active ? 1 : 0.5)
                : scheme.outlineVariant,
            width: active ? 3 : 2,
          ),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              active ? Icons.graphic_eq : Icons.mic_none,
              size: 30,
              color: widget.enabled ? scheme.tertiary : scheme.outline,
            ),
            const SizedBox(height: 6),
            Text(
              !widget.enabled
                  ? 'voice not available for this profile'
                  : active
                      ? 'listening...'
                      : widget.label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: widget.enabled ? scheme.onSurface : scheme.outline,
              ),
            ),
            if (_sounds > 0 && !active)
              Text(
                'sounds: $_sounds',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
          ],
        ),
      ),
    );
  }
}
