import 'package:flutter/material.dart';

import '../inputs/voice.dart';
import '../inputs/voice_modes.dart';
import '../model/profile.dart';
import 'discrete_view.dart';
import 'dock.dart';

/// Free text: the one screen where two weak channels are used together.
///
/// docs/idea/02-core-model.md Thesis B -- touch is good at selection and bad at
/// text; voice is good at text and bad at precise selection. So selection stays
/// on whichever touch method the profile chose, and the content comes from
/// voice, at whatever tier the voice axis supports:
///
///  * full / partial -- dictate, then confirm the transcript (partial confirms
///    every time, because low confidence is expected rather than exceptional);
///  * sounds -- no words are parsed at all: the agent proposes phrases and one
///    sound accepts, two sounds move to the next (docs/idea/20);
///  * none -- the same proposals, selected by touch alone.
class TextTaskView extends StatefulWidget {
  const TextTaskView({
    super.key,
    required this.profile,
    required this.method,
    required this.fieldLabel,
    required this.onResolve,
    required this.onRaw,
    required this.onNote,
    this.suggestions,
  });

  final CapabilityProfile profile;
  final TouchMethod method;
  final String fieldLabel;
  final void Function(String text) onResolve;
  final void Function(String raw) onRaw;

  /// Log-worthy events (a capture, a rejected transcript) as opposed to live
  /// raw movement.
  final void Function(String note) onNote;

  /// Authored phrases for this field. Falls back to the demo defaults.
  final List<String>? suggestions;

  @override
  State<TextTaskView> createState() => _TextTaskViewState();
}

class _TextTaskViewState extends State<TextTaskView> {
  /// Context-predictive phrases -- the "context-based text input" idea from
  /// docs/idea/20, and the fallback whenever dictation is not available.
  static const _defaults = <String>[
    'Leave it at the front desk',
    'Ring the bell twice',
    'Call me when you arrive',
    'Leave it with a neighbour',
  ];

  List<String> get _suggestions {
    final extra = widget.suggestions;
    if (extra == null || extra.isEmpty) return _defaults;
    return extra;
  }

  final SpeechSource _speech = SimulatedSpeechSource();

  String? _proposal;
  bool _listening = false;
  int _suggestion = 0;
  double _confidence = 0;

  double get _scale => widget.profile.vision.textScale;
  bool get _canDictate => widget.profile.clarity.canDictate;
  bool get _soundsOnly =>
      textComposeModeFor(widget.profile.clarity) == TextComposeMode.vocalConfirm;

  void _onSoundGesture(int sounds, int heldMs) {
    final kind = VocalClassifier.classify(
      soundCount: sounds,
      heldMs: heldMs,
      clarity: widget.profile.clarity,
    );
    widget.onRaw('${kind.label}: $sounds burst(s), ${heldMs}ms');
    if (kind.acceptsSuggestion) {
      setState(() {
        _proposal = _suggestions[_suggestion];
        _confidence = 0;
      });
    } else if (kind.skipsSuggestion) {
      setState(() {
        _suggestion = (_suggestion + 1) % _suggestions.length;
      });
      widget.onNote('next suggestion: ${_suggestions[_suggestion]}');
    }
  }

  Future<void> _onUtterance(int sounds, int heldMs) async {
    setState(() => _listening = true);
    final r = await _speech.capture(
      heldMs: heldMs,
      soundCount: sounds,
      clarity: widget.profile.clarity,
    );
    if (!mounted) return;
    setState(() {
      _listening = false;
      _confidence = r.confidence;
      _proposal = r.ok && r.transcript.isNotEmpty ? r.transcript : null;
    });
    widget.onNote(r.ok
        ? 'heard "${r.transcript}" (confidence ${r.confidence.toStringAsFixed(2)})'
        : 'nothing usable captured -- retry offered');
  }

  @override
  Widget build(BuildContext context) {
    if (_proposal != null) return _confirmStage(context);
    return _composeStage(context);
  }

  /// Every capture is confirmed before it becomes the field's value, and the
  /// confirmation is driven by the same touch method as everything else -- the
  /// gate must not require an ability the user was never measured to have.
  Widget _confirmStage(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: scheme.tertiaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Put this in ${widget.fieldLabel}?',
                style: TextStyle(
                  fontSize: 13 * _scale,
                  color: scheme.onTertiaryContainer,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _proposal!,
                style: TextStyle(
                  fontSize: 22 * _scale,
                  fontWeight: FontWeight.w700,
                  color: scheme.onTertiaryContainer,
                ),
              ),
              if (_confidence > 0)
                Text(
                  'confidence ${_confidence.toStringAsFixed(2)}'
                  '${_confidence < 0.75 ? " -- low, so confirm carefully" : ""}',
                  style: TextStyle(
                    fontSize: 11 * _scale,
                    color: scheme.onTertiaryContainer.withValues(alpha: 0.8),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: DiscreteTaskView(
            profile: widget.profile,
            method: widget.method,
            options: const ['Yes, use this', 'No, try again'],
            onRaw: widget.onRaw,
            onResolve: (i, _) {
              if (i == 0) {
                widget.onResolve(_proposal!);
              } else {
                widget.onNote('rejected proposal');
                setState(() => _proposal = null);
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _composeStage(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.fieldLabel.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11 * _scale,
                    letterSpacing: 1.2,
                    color: scheme.onSurfaceVariant,
                  )),
              const SizedBox(height: 6),
              Text(
                _canDictate ? 'empty' : _suggestions[_suggestion],
                style: TextStyle(
                  fontSize: 20 * _scale,
                  fontWeight: FontWeight.w600,
                  color: _canDictate ? scheme.outline : scheme.onSurface,
                ),
              ),
            ],
          ),
        ),
        if (_listening)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: LinearProgressIndicator(),
          ),
        Expanded(child: _contentInput(context)),
      ],
    );
  }

  Widget _contentInput(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Both voice-input branches dock the control in the reachable zone the
    // reach test found, same as every touch surface -- a prompt can sit
    // wherever there is room, but the thing you actually press cannot.
    if (_canDictate) {
      return InputOverlay(
        profile: widget.profile,
        content: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Touch picks the field, voice fills it. '
            'Nothing is entered until you confirm it.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13 * _scale,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        dock: HoldToSpeak(
          height: 150,
          label: 'Hold and say the note',
          onUtterance: _onUtterance,
        ),
      );
    }

    if (_soundsOnly) {
      // SpeechClarity.sounds: one sound / nod / hum accepts, two sounds
      // advance. Marker-grid burst-picking stays available as its own
      // surface; the floor case is this two-way vocabulary (docs/idea/20).
      return InputOverlay(
        profile: widget.profile,
        content: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'A short sound means yes. Two sounds means the next phrase.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13 * _scale,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        dock: HoldToSpeak(
          height: 150,
          label: 'Sound once to accept, twice for next',
          onUtterance: _onSoundGesture,
        ),
      );
    }

    // Voice unavailable: the same predicted phrases, chosen by touch.
    return DiscreteTaskView(
      profile: widget.profile,
      method: widget.method,
      options: _suggestions,
      onRaw: widget.onRaw,
      onResolve: (i, value) => setState(() => _proposal = value),
    );
  }
}
