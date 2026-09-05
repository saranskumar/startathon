import 'package:flutter/material.dart';

import '../inputs/surfaces.dart';
import '../inputs/voice.dart';
import '../inputs/voice_modes.dart';
import '../model/profile.dart';
import '../model/session.dart';
import 'dock.dart';
import 'output_bar.dart';

/// After calibration (or a preset), show the actual controllers and the
/// laptop-preview strip before any task starts.
///
/// The runtime tasks only mount the method that task needs, so a joystick
/// profile never sees buttons, and the strip can sit at the bottom. This
/// screen is the opposite: every surface is tryable, and the preview is
/// pinned to the top so "what would go to the computer" is always in view.
class InputPreviewScreen extends StatefulWidget {
  const InputPreviewScreen({
    super.key,
    required this.onContinue,
    required this.onRecalibrate,
  });

  final VoidCallback onContinue;
  final VoidCallback onRecalibrate;

  @override
  State<InputPreviewScreen> createState() => _InputPreviewScreenState();
}

enum _Surface { buttons, joystick, trackpad, switchScan, voice }

class _InputPreviewScreenState extends State<InputPreviewScreen> {
  _Surface? _surface;

  _Surface _current(CapabilityProfile profile) {
    if (_surface != null) return _surface!;
    return switch (profile.bestMethod) {
      TouchMethod.buttons => _Surface.buttons,
      TouchMethod.joystick => _Surface.joystick,
      TouchMethod.trackpad => _Surface.trackpad,
      TouchMethod.switchScan => _Surface.switchScan,
    };
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final profile = state.profile;
    final surface = _current(profile);
    final scale = profile.vision.textScale;
    final strip = OutputStrip(
      state: state,
      onOpenLog: () => EventLogSheet.show(context, state),
    );

    return Scaffold(
      body: Column(
        children: [
          strip,
          Expanded(
            child: SafeArea(
              top: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Your controllers',
                                style: TextStyle(
                                  fontSize: 22 * scale,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Try them. The dark strip above is the laptop '
                                'preview -- live signal on the right, last '
                                'intent on the left.',
                                style: TextStyle(
                                  fontSize: 12 * scale,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: widget.onRecalibrate,
                          icon: const Icon(Icons.tune),
                          tooltip: 'Recalibrate',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final s in _Surface.values)
                          ChoiceChip(
                            label: Text(_chipLabel(s, profile)),
                            selected: surface == s,
                            onSelected: (_) => setState(() => _surface = s),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Text(
                      _hint(surface, profile),
                      style: TextStyle(
                        fontSize: 13 * scale,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: _pad(state, profile, surface),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: SizedBox(
                      height: 64,
                      child: FilledButton(
                        onPressed: widget.onContinue,
                        child: Text(
                          'Start tasks',
                          style: TextStyle(fontSize: 18 * scale),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _chipLabel(_Surface s, CapabilityProfile p) {
    final strongest = switch (p.bestMethod) {
      TouchMethod.buttons => _Surface.buttons,
      TouchMethod.joystick => _Surface.joystick,
      TouchMethod.trackpad => _Surface.trackpad,
      TouchMethod.switchScan => _Surface.switchScan,
    };
    final name = switch (s) {
      _Surface.buttons => 'Buttons',
      _Surface.joystick => 'Joystick',
      _Surface.trackpad => 'Trackpad',
      _Surface.switchScan => 'Switch',
      _Surface.voice => 'Voice',
    };
    return s == strongest ? '$name · yours' : name;
  }

  String _hint(_Surface s, CapabilityProfile p) => switch (s) {
        _Surface.buttons =>
          'Targets are ${p.minTargetSize.round()} dp -- the size calibration measured.',
        _Surface.joystick =>
          'Floats where your hand reached. Drag to move, tap the knob to confirm.',
        _Surface.trackpad =>
          'Drag anywhere on the pad. Position is what would drive the cursor.',
        _Surface.switchScan =>
          'One large press. No aiming. This is the floor-case controller.',
        _Surface.voice => textComposeModeFor(p.clarity).detail,
      };

  Widget _pad(AppState state, CapabilityProfile profile, _Surface surface) {
    final method = switch (surface) {
      _Surface.buttons => TouchMethod.buttons,
      _Surface.joystick => TouchMethod.joystick,
      _Surface.trackpad => TouchMethod.trackpad,
      _Surface.switchScan => TouchMethod.switchScan,
      _Surface.voice => profile.bestMethod,
    };

    void raw(String text) => state.emitRaw(text, method: method);
    void intent(String text) => state.emit(InputEvent(
          kind: 'INTENT',
          method: method,
          text: text,
        ));

    return switch (surface) {
      _Surface.buttons => Align(
          alignment: profile.reachAnchor,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final label in const ['Option A', 'Option B', 'Option C'])
                  CalibratedButton(
                    label: label,
                    minSize: profile.minTargetSize,
                    textScale: profile.vision.textScale,
                    onPressed: () {
                      raw('tap $label');
                      intent('preview tap = $label');
                    },
                  ),
              ],
            ),
          ),
        ),
      _Surface.joystick => Align(
          alignment: profile.reachAnchor,
          child: JoystickPad(
            size: 180,
            label: 'TRY',
            onVector: (v) {
              if (v == Offset.zero) {
                raw('stick released');
              } else {
                raw(
                  'stick ${v.dx.toStringAsFixed(2)}, ${v.dy.toStringAsFixed(2)}',
                );
              }
            },
            onPress: () => intent('preview stick press'),
          ),
        ),
      _Surface.trackpad => TrackpadSurface(
          hint: 'drag here',
          onMove: (n, _) => raw(
            'pad ${n.dx.toStringAsFixed(2)}, ${n.dy.toStringAsFixed(2)}',
          ),
          onEnd: (n) => intent(
            'preview pad at ${n.dx.toStringAsFixed(2)}, ${n.dy.toStringAsFixed(2)}',
          ),
        ),
      _Surface.switchScan => Align(
          alignment: Alignment.bottomCenter,
          child: SwitchTrigger(
            label: 'PRESS TO FIRE',
            onPress: () {
              raw('switch press');
              intent('preview switch press');
            },
          ),
        ),
      _Surface.voice => _VoicePad(profile: profile, state: state),
    };
  }
}

class _VoicePad extends StatelessWidget {
  const _VoicePad({required this.profile, required this.state});

  final CapabilityProfile profile;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final mode = textComposeModeFor(profile.clarity);
    return InputOverlay(
      profile: profile,
      content: Center(
        child: Text(
          mode.title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18 * profile.vision.textScale,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      // Prompts can sit anywhere; the control itself docks inside the
      // reachable zone the calibration reach test actually found, same as
      // every other input surface in this app.
      dock: HoldToSpeak(
        enabled: profile.clarity != SpeechClarity.none,
        onUtterance: (sounds, heldMs) {
          final kind = VocalClassifier.classify(
            soundCount: sounds,
            heldMs: heldMs,
            clarity: profile.clarity,
          );
          state.emitRaw('${kind.label}: $sounds burst(s), ${heldMs}ms');
          state.emit(InputEvent(
            kind: 'VOICE',
            method: profile.bestMethod,
            text: 'preview ${kind.label} ($sounds, ${heldMs}ms)',
          ));
        },
      ),
    );
  }
}
