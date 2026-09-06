import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../inputs/voice.dart';
import '../inputs/voice_vocab.dart';
import '../model/profile.dart';
import '../runtime/dock.dart';
import '../runtime/discrete_view.dart';
import 'step_frame.dart';
import 'touch_steps.dart' show CalibrationStep;

// ---------------------------------------------------------------------------
// 6. Voice
// ---------------------------------------------------------------------------

/// Issue #3 — walk natural sentences, keep the words that land, bucket the
/// rest into full / partial+vocab / sounds / none.
///
/// The press-and-hold timing and the sound count are measured for real. The
/// recogniser is not: there is no microphone plugin in this build, so whether
/// the target word "landed" is chosen explicitly and labelled SIMULATED.
class VoiceStep extends CalibrationStep {
  const VoiceStep({
    super.key,
    required super.draft,
    required super.index,
    required super.total,
    required super.onNext,
    required super.onSkip,
    super.onBack,
    super.textScale,
  });

  @override
  State<VoiceStep> createState() => _VoiceStepState();
}

class _VoiceStepState extends State<VoiceStep> {
  final SpeechSource _source = SimulatedSpeechSource(
    phrases: [for (final p in kVoiceProbes) p.sentence],
  );

  /// What the stub recogniser should pretend to hear for this sentence.
  SpeechClarity _simulated = SpeechClarity.full;

  int _probe = 0;
  final Set<String> _landed = <String>{};
  bool _busy = false;
  SpeechResult? _result;
  int _lastSounds = 0;
  int _lastHeldMs = 0;
  bool _heardAnySound = false;

  VoiceProbe get _current => kVoiceProbes[_probe];

  Future<void> _onUtterance(int sounds, int heldMs) async {
    setState(() {
      _busy = true;
      _lastSounds = sounds;
      _lastHeldMs = heldMs;
      if (sounds > 0 || heldMs > 120) _heardAnySound = true;
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
      if (_simulated == SpeechClarity.full ||
          _simulated == SpeechClarity.partial) {
        _landed.add(_current.target);
      }
    });
  }

  void _markLanded(bool yes) {
    setState(() {
      if (yes) {
        _landed.add(_current.target);
      } else {
        _landed.remove(_current.target);
      }
    });
  }

  void _advance() {
    if (_probe < kVoiceProbes.length - 1) {
      setState(() {
        _probe++;
        _result = null;
      });
      return;
    }
    widget.draft.vocabulary = _landed.toList();
    widget.draft.clarity = _derived;
    widget.onNext();
  }

  /// Words first, then sounds, then none. A large personal list still
  /// stays `partial` so runtime uses vocab mapping instead of free dictation.
  SpeechClarity get _derived {
    if (_landed.length >= 6) return SpeechClarity.full;
    if (_landed.isNotEmpty) return SpeechClarity.partial;
    if (_heardAnySound || _lastSounds > 0) return SpeechClarity.sounds;
    return SpeechClarity.none;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final r = _result;
    // Confirming a captured utterance is sequenced *after* recording, not
    // shown alongside the mic dock -- both want the same InputOverlay dock
    // slot, and this way the confirm choice itself routes through whatever
    // input method motor calibration already found instead of needing a
    // small always-visible tap chip. See GH #11 / docs/idea/30 §10.
    if (r != null) {
      final profile = widget.draft.build();
      return StepFrame(
        title: 'Voice',
        instruction: 'Did "${_current.target}" land?',
        status: 'heard: ${r.transcript.isEmpty ? "(no words)" : r.transcript}',
        index: widget.index,
        total: widget.total,
        textScale: widget.textScale,
        onSkip: () {
          widget.draft.skipped.add('voice');
          widget.draft.clarity = SpeechClarity.none;
          widget.draft.vocabulary = const [];
          widget.onSkip();
        },
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: _resultCard(scheme, r),
            ),
            Expanded(
              child: DiscreteTaskView(
                profile: profile,
                method: profile.bestMethod,
                options: const ['That word was clear', 'Not this one'],
                onResolve: (i, _) {
                  _markLanded(i == 0);
                  setState(() => _result = null);
                },
                onRaw: (_) {},
              ),
            ),
          ],
        ),
      );
    }
    return StepFrame(
      title: 'Voice',
      instruction: 'Try to say: "${_current.sentence}"',
      status: 'Sentence ${_probe + 1} of ${kVoiceProbes.length}. '
          'The word we keep is "${_current.target}". '
          'Any sound still becomes a yes/no signal.',
      index: widget.index,
      total: widget.total,
      textScale: widget.textScale,
      minTargetSize: widget.draft.minTargetSize,
      onBack: widget.onBack,
      onSkip: () {
        widget.draft.skipped.add('voice');
        widget.draft.clarity = SpeechClarity.none;
        widget.draft.vocabulary = const [];
        widget.onSkip();
      },
      footer: SizedBox(
              height: 64,
              child: FilledButton(
                onPressed: _advance,
                child: Text(_probe < kVoiceProbes.length - 1
                    ? 'Next sentence'
                    : 'Use "${_derived.label}"'
                        '${_landed.isEmpty ? '' : ' · ${_landed.length} words'}'),
              ),
            ),
      // Prompts and readouts scroll; the microphone itself docks in the
      // reachable zone the reach test already found, like every other
      // control -- speech-only sessions (no reach step at all) fall back to
      // reachableRect's own lower-half default.
      child: InputOverlay(
        profile: widget.draft.build(),
        content: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_busy)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: LinearProgressIndicator(),
                ),
              Text(
                'Your words so far: ${_landed.isEmpty ? 'none yet' : _landed.join(', ')}',
                style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 18),
              _simulationControls(scheme),
            ],
          ),
        ),
        dock: HoldToSpeak(onUtterance: _onUtterance),
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

/// Common 2-syllable nouns in the same length/familiarity band as the original
/// four (`river`, `candle`, `window`, `pocket`). Issue #12: a four-word pool
/// with a fixed seed made every run show the same two words.
const kVisionWords = <String>[
  'river',
  'candle',
  'window',
  'pocket',
  'garden',
  'button',
  'pencil',
  'table',
  'bottle',
  'jacket',
  'flower',
  'basket',
  'pillow',
  'forest',
  'castle',
  'mirror',
  'camera',
  'rocket',
  'lemon',
  'rabbit',
  'market',
  'engine',
  'onion',
  'planet',
  'hammer',
  'cookie',
  'temple',
  'village',
];

/// One acuity trial: the shrinking stimulus and the two large answer buttons.
class VisionWordRound {
  const VisionWordRound({required this.shown, required this.choices});

  final String shown;
  final List<String> choices;
}

/// Session-shuffled deck so consecutive rungs deal distinct words.
class VisionWordDeck {
  VisionWordDeck({math.Random? random, List<String> words = kVisionWords})
      : _rng = random ?? math.Random(),
        _deck = List<String>.of(words) {
    _deck.shuffle(_rng);
  }

  final math.Random _rng;
  final List<String> _deck;
  var _index = 0;

  VisionWordRound next() {
    final shown = _deck[_index % _deck.length];
    _index++;
    final others = [for (final w in _deck) if (w != shown) w];
    final foil = others[_rng.nextInt(others.length)];
    final choices = [shown, foil]..shuffle(_rng);
    return VisionWordRound(shown: shown, choices: choices);
  }
}

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
    super.onBack,
    super.textScale,
    this.random,
  });

  /// Goldens and tests inject a seed. Live calibration draws a fresh session RNG.
  final math.Random? random;

  @override
  State<VisionStep> createState() => _VisionStepState();
}

class _VisionStepState extends State<VisionStep> {
  static const _rungs = <double>[44, 30, 20, 14];

  late final VisionWordDeck _deck;

  int _rung = 0;
  late String _shown;
  late List<String> _choices;
  double? _smallestRead;
  bool _pickingField = false;

  @override
  void initState() {
    super.initState();
    _deck = VisionWordDeck(random: widget.random);
    _newRound();
  }

  void _newRound() {
    final round = _deck.next();
    _shown = round.shown;
    _choices = round.choices;
  }

  void _answer(String choice) {
    final correct = choice == _shown;
    if (correct) _smallestRead = _rungs[_rung];
    if (!correct || _rung >= _rungs.length - 1) {
      _commitAcuity();
      return;
    }
    setState(() {
      _rung++;
      _newRound();
    });
  }

  void _commitAcuity() {
    final s = _smallestRead;
    widget.draft.vision = s == null
        ? VisionMode.none
        : (s <= 20 ? VisionMode.screen : VisionMode.large);
    setState(() => _pickingField = true);
  }

  void _commitField(VisualField field) {
    widget.draft.visualField = field;
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    // By the time Vision runs, every motor step has already resolved --
    // route both of this step's choices through whatever input method that
    // measured, rather than a fixed set of plain tap buttons. See GH #11 /
    // docs/idea/30 §10.
    final profile = widget.draft.build();
    final method = profile.bestMethod;
    if (_pickingField) {
      return StepFrame(
        title: 'Vision',
        instruction: 'How much of the screen can you see at once?',
        status: 'Acuity is already measured. This is field shape — a different axis.',
        index: widget.index,
        total: widget.total,
        textScale: widget.textScale,
        minTargetSize: widget.draft.minTargetSize,
        onBack: widget.onBack,
        onSkip: () => _commitField(VisualField.full),
        child: DiscreteTaskView(
          profile: profile,
          method: method,
          options: [
            for (final f in VisualField.values) '${f.label} — ${f.detail}',
          ],
          onResolve: (i, _) => _commitField(VisualField.values[i]),
          onRaw: (_) {},
        ),
      );
    }
    return StepFrame(
      title: 'Vision',
      instruction: 'Try to read the word above.',
      status: 'Text size ${_rungs[_rung].round()}. '
          'If you cannot tell, pick either -- a wrong answer just stops the '
          'test here, it is not a failure.',
      index: widget.index,
      total: widget.total,
      textScale: widget.textScale,
      minTargetSize: widget.draft.minTargetSize,
      onBack: widget.onBack,
      onSkip: () {
        widget.draft.skipped.add('vision');
        widget.draft.vision = VisionMode.large;
        widget.onSkip();
      },
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Expanded(
              flex: 2,
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
            Expanded(
              flex: 3,
              child: DiscreteTaskView(
                profile: profile,
                method: method,
                options: _choices,
                onResolve: (_, value) => _answer(value),
                onRaw: (_) {},
              ),
            ),
          ],
        ),
      ),
    );
  }
}
