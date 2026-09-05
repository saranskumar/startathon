import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../inputs/voice.dart';
import '../model/profile.dart';
import 'step_frame.dart';
import 'touch_steps.dart' show CalibrationStep;

// ---------------------------------------------------------------------------
// 6. Voice
// ---------------------------------------------------------------------------

/// 3.1 -- "ask the user to say one short fixed phrase", bucketed into
/// full / partial / sounds / none.
///
/// The press-and-hold timing and the sound count are measured for real. The
/// recogniser is not: there is no microphone plugin in this build, so the
/// quality of recognition is chosen explicitly and labelled SIMULATED on
/// screen. That keeps the demo honest and, usefully, lets any tier be demoed on
/// demand instead of hoping the room's acoustics cooperate.
class VoiceStep extends CalibrationStep {
  const VoiceStep({
    super.key,
    required super.draft,
    required super.index,
    required super.total,
    required super.onNext,
    required super.onSkip,
    super.textScale,
  });

  @override
  State<VoiceStep> createState() => _VoiceStepState();
}

class _VoiceStepState extends State<VoiceStep> {
  static const _phrase = 'the quick brown fox';

  final SpeechSource _source = SimulatedSpeechSource(phrases: [_phrase]);

  /// What the stub recogniser should pretend to hear.
  SpeechClarity _simulated = SpeechClarity.full;

  bool _busy = false;
  SpeechResult? _result;
  int _lastSounds = 0;
  int _lastHeldMs = 0;

  Future<void> _onUtterance(int sounds, int heldMs) async {
    setState(() {
      _busy = true;
      _lastSounds = sounds;
      _lastHeldMs = heldMs;
    });
    final r = await _source.capture(
      heldMs: heldMs,
      soundCount: sounds,
      clarity: _simulated,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _result = r;
    });
  }

  /// Measured signal first, simulated recognition second: no vocalisation at
  /// all means `none` regardless of what the stub would have returned.
  SpeechClarity get _derived {
    if (_lastHeldMs < 120 && _lastSounds == 0) return SpeechClarity.none;
    final r = _result;
    if (r == null || !r.ok) {
      return _lastSounds > 0 ? SpeechClarity.sounds : SpeechClarity.none;
    }
    if (r.transcript.isEmpty) return SpeechClarity.sounds;
    return r.confidence >= 0.75 ? SpeechClarity.full : SpeechClarity.partial;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final r = _result;
    return StepFrame(
      title: 'Voice',
      instruction: 'Hold the button and say: "$_phrase"',
      status: 'Any sound counts. If words are hard, just make a sound -- that '
          'still becomes a usable yes/no signal.',
      index: widget.index,
      total: widget.total,
      textScale: widget.textScale,
      onSkip: () {
        widget.draft.skipped.add('voice');
        widget.draft.clarity = SpeechClarity.none;
        widget.onSkip();
      },
      footer: r == null
          ? null
          : SizedBox(
              height: 64,
              child: FilledButton(
                onPressed: () {
                  widget.draft.clarity = _derived;
                  widget.onNext();
                },
                child: Text('Use "${_derived.label}" and continue'),
              ),
            ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            HoldToSpeak(onUtterance: _onUtterance),
            const SizedBox(height: 14),
            if (_busy)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: LinearProgressIndicator(),
              ),
            if (r != null) _resultCard(scheme, r),
            const SizedBox(height: 18),
            _simulationControls(scheme),
          ],
        ),
      ),
    );
  }

  Widget _resultCard(ColorScheme scheme, SpeechResult r) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('heard: ${r.transcript.isEmpty ? "(no words)" : r.transcript}',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              'confidence ${r.confidence.toStringAsFixed(2)} | '
              'sounds ${r.soundCount} | held ${_lastHeldMs}ms',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Text('tier: ${_derived.label} -- ${_derived.grants}',
                style: TextStyle(color: scheme.primary)),
          ],
        ),
      );

  Widget _simulationControls(ColorScheme scheme) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.error.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.science_outlined, size: 16, color: scheme.error),
                const SizedBox(width: 6),
                Text(
                  'SIMULATED RECOGNISER',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w800,
                    color: scheme.error,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'No microphone is wired up yet. Pick what the recogniser should '
              'return; the hold timing and sound count above are real.',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final c in SpeechClarity.values)
                  ChoiceChip(
                    label: Text(c.label),
                    selected: _simulated == c,
                    onSelected: (_) => setState(() => _simulated = c),
                  ),
              ],
            ),
          ],
        ),
      );
}

// ---------------------------------------------------------------------------
// 7. Vision
// ---------------------------------------------------------------------------

/// 3.1 left this open ("likely a direct question, or a shrinking-font check").
///
/// Self-report is the weak version -- people say yes to "can you read this?"
/// out of politeness. So this is a forced choice: the stimulus shrinks, while
/// the two answer buttons stay large. Getting it right is proof of reading it;
/// the answer buttons never become the limiting factor.
class VisionStep extends CalibrationStep {
  const VisionStep({
    super.key,
    required super.draft,
    required super.index,
    required super.total,
    required super.onNext,
    required super.onSkip,
    super.textScale,
  });

  @override
  State<VisionStep> createState() => _VisionStepState();
}

class _VisionStepState extends State<VisionStep> {
  static const _rungs = <double>[44, 30, 20, 14];
  static const _words = <String>['river', 'candle', 'window', 'pocket'];

  final math.Random _rng = math.Random(3);

  int _rung = 0;
  late String _shown;
  late List<String> _choices;
  double? _smallestRead;

  @override
  void initState() {
    super.initState();
    _newRound();
  }

  void _newRound() {
    _shown = _words[_rng.nextInt(_words.length)];
    final other = _words.where((w) => w != _shown).toList()
      ..shuffle(_rng);
    _choices = [_shown, other.first]..shuffle(_rng);
  }

  void _answer(String choice) {
    final correct = choice == _shown;
    if (correct) _smallestRead = _rungs[_rung];
    if (!correct || _rung >= _rungs.length - 1) {
      _commit();
      return;
    }
    setState(() {
      _rung++;
      _newRound();
    });
  }

  void _commit() {
    final s = _smallestRead;
    widget.draft.vision = s == null
        ? VisionMode.none
        : (s <= 20 ? VisionMode.screen : VisionMode.large);
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    return StepFrame(
      title: 'Vision',
      instruction: 'Which word is shown above?',
      status: 'Text size ${_rungs[_rung].round()}. '
          'If you cannot tell, pick either -- a wrong answer just stops the '
          'test here, it is not a failure.',
      index: widget.index,
      total: widget.total,
      textScale: widget.textScale,
      onSkip: () {
        widget.draft.skipped.add('vision');
        widget.draft.vision = VisionMode.large;
        widget.onSkip();
      },
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Center(
                child: Text(
                  _shown,
                  style: TextStyle(
                    fontSize: _rungs[_rung],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            for (final c in _choices)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SizedBox(
                  height: 76,
                  child: FilledButton.tonal(
                    onPressed: () => _answer(c),
                    child: Text(c, style: const TextStyle(fontSize: 26)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
