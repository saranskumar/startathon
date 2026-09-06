import 'package:flutter/material.dart';

import '../inputs/marker_grid.dart';
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
  });

  final CapabilityProfile profile;
  final TouchMethod method;
  final String fieldLabel;
  final void Function(String text) onResolve;
  final void Function(String raw) onRaw;

  /// Log-worthy events (a capture, a rejected transcript) as opposed to live
  /// raw movement.
  final void Function(String note) onNote;

  @override
  State<TextTaskView> createState() => _TextTaskViewState();
}

class _TextTaskViewState extends State<TextTaskView> {
  /// Context-predictive phrases -- the "context-based text input" idea from
  /// docs/idea/20, and the fallback whenever dictation is not available.
  static const _suggestions = <String>[
    'Leave it at the front desk',
    'Ring the bell twice',
    'Call me when you arrive',
    'Leave it with a neighbour',
  ];

  final SpeechSource _speech = SimulatedSpeechSource();

  String? _proposal;
  bool _listening = false;
  int _suggestion = 0;
  double _confidence = 0;

  double get _scale => widget.profile.vision.textScale;
  bool get _canDictate => widget.profile.clarity.canDictate;
  bool get _soundsOnly =>
      textComposeModeFor(widget.profile.clarity) == TextComposeMode.vocalConfirm;

  MarkerGridController? _markerController;

  MarkerGridController get _markerCtrl => _markerController ??= MarkerGridController(
        _suggestions,
        onResolve: (i, value) {
          widget.onNote('marker grid picked "$value"');
          setState(() => _proposal = value);
        },
        onRaw: widget.onRaw,
      );

  @override
  void dispose() {
    _markerController?.dispose();
    super.dispose();
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
                // Marker-grid mode shows every suggestion at once below (no
                // single "current" one to preview here); touch-pick mode has
                // no cycling either, so this stays a static first-option peek.
                !_canDictate && !_soundsOnly ? _suggestions[_suggestion] : 'empty',
                style: TextStyle(
                  fontSize: 20 * _scale,
                  fontWeight: FontWeight.w600,
                  color: !_canDictate && !_soundsOnly
                      ? scheme.onSurface
                      : scheme.outline,
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
      // Each phrase is its own lettered marker -- one burst count jumps
      // straight to a phrase instead of cycling through them one at a time
      // (docs/idea/22's "personalized tone" grid, reusing the same
      // burst-count signal HoldToSpeak already measures for real).
      return InputOverlay(
        profile: widget.profile,
        content: Padding(
          padding: const EdgeInsets.all(16),
          child: MarkerGrid(controller: _markerCtrl, textScale: _scale),
        ),
        dock: ListenableBuilder(
          listenable: _markerCtrl,
          builder: (context, _) => HoldToSpeak(
            height: 130,
            label: _markerCtrl.instructionLabel,
            onUtterance: _markerCtrl.onUtterance,
          ),
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
