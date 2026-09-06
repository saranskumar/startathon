import 'package:flutter/material.dart';

import '../calibration/hold_fill.dart';
import '../calibration/sense_steps.dart';
import '../calibration/step_frame.dart';
import '../calibration/touch_steps.dart';
import '../inputs/voice.dart';
import '../model/profile.dart';
import '../model/session.dart';
import '../runtime/discrete_view.dart';
import '../vision/field_shell.dart';
import 'playground_modes.dart';
import 'playground_seed.dart';

/// Gear-menu Playground: mode cards, then Calibration or a lightweight Demo.
///
/// Does not replace [InputPreviewScreen] or the task [DemoScreen] chain.
class PlaygroundScreen extends StatefulWidget {
  const PlaygroundScreen({
    super.key,
    required this.profile,
    required this.onClose,
    this.onRaw,
    this.onIntent,
  });

  final CapabilityProfile profile;
  final VoidCallback onClose;
  final void Function(String raw)? onRaw;
  final void Function(String text)? onIntent;

  @override
  State<PlaygroundScreen> createState() => _PlaygroundScreenState();
}

enum _PlayAction { demo, calibrate }

class _PlaygroundScreenState extends State<PlaygroundScreen> {
  PlaygroundMode? _mode;
  _PlayAction? _action;
  late CalibrationDraft _draft;
  int _demoEpoch = 0;

  @override
  void initState() {
    super.initState();
    _draft = draftFromProfile(widget.profile);
  }

  void _back() {
    if (_action != null) {
      setState(() {
        _action = null;
        _draft = draftFromProfile(widget.profile);
      });
      return;
    }
    if (_mode != null) {
      setState(() => _mode = null);
      return;
    }
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _mode == null
            ? _hub(context)
            : _action == null
                ? _modeActions(context, _mode!)
                : _action == _PlayAction.demo
                    ? _demo(context, _mode!)
                    : _calibrate(context, _mode!),
      ),
    );
  }

  Widget _chrome({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
          child: Row(
            children: [
              IconButton(
                onPressed: _back,
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Back',
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(child: child),
      ],
    );
  }

  Widget _hub(BuildContext context) {
    return _chrome(
      title: 'Playground',
      subtitle: 'Try a mode, or re-run its calibration step.',
      child: GridView.count(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.05,
        children: [
          for (final mode in playgroundModes) _ModeCard(mode: mode, onTap: () {
            setState(() => _mode = mode);
          }),
        ],
      ),
    );
  }

  Widget _modeActions(BuildContext context, PlaygroundMode mode) {
    final scheme = Theme.of(context).colorScheme;
    final holdBlocked =
        mode.needsButtonsFirst && _draft.tappableButtons.isEmpty;
    return _chrome(
      title: mode.label,
      subtitle: 'Calibration uses the existing step. Demo is a short list.',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          SizedBox(
            height: 64,
            child: FilledButton(
              onPressed: () => setState(() => _action = _PlayAction.demo),
              child: const Text('Try a demo'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 64,
            child: FilledButton.tonal(
              onPressed: mode.calibrateDisabled
                  ? () => setState(() {
                        _mode = PlaygroundMode.buttons;
                        _action = _PlayAction.calibrate;
                      })
                  : holdBlocked
                      ? null
                      : () =>
                          setState(() => _action = _PlayAction.calibrate),
              child: Text(
                mode.calibrateDisabled
                    ? 'Calibrate via Buttons'
                    : 'Calibration',
              ),
            ),
          ),
          if (mode.calibrateDisabled) ...[
            const SizedBox(height: 10),
            Text(
              'Switch scan is measured through the Buttons test.',
              style: TextStyle(color: scheme.onSurfaceVariant, height: 1.35),
            ),
          ],
          if (holdBlocked) ...[
            const SizedBox(height: 10),
            Text(
              'Hold needs buttons first. Calibrate Buttons, then come back.',
              style: TextStyle(color: scheme.onSurfaceVariant, height: 1.35),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => setState(() {
                _mode = PlaygroundMode.buttons;
                _action = _PlayAction.calibrate;
              }),
              child: const Text('Calibrate Buttons first'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _demo(BuildContext context, PlaygroundMode mode) {
    return _chrome(
      title: 'Demo · ${mode.label}',
      subtitle: 'Lightweight demonstration — not the full calibration flow.',
      child: _demoBody(mode),
    );
  }

  Widget _demoBody(PlaygroundMode mode) {
    final touch = mode.touchMethod;
    if (touch != null) {
      return DiscreteTaskView(
        key: ValueKey('pg-demo-$_demoEpoch-$touch'),
        profile: widget.profile,
        method: touch,
        options: const ['Red', 'Green', 'Blue'],
        preferList: true,
        onRaw: (s) => widget.onRaw?.call(s),
        onResolve: (i, value) {
          widget.onIntent?.call('playground $value');
          setState(() => _demoEpoch++);
        },
      );
    }
    if (mode == PlaygroundMode.hold) {
      return Center(
        child: HoldFill(
          builder: (context, progress) {
            return HoldFillRing(
              progress: progress,
              child: Text(
                progress >= 1 ? 'Held' : 'Hold',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            );
          },
          onComplete: () => widget.onIntent?.call('playground hold'),
        ),
      );
    }
    if (mode == PlaygroundMode.voice) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text('Hold to speak. A sound count is the demo signal.'),
            const Spacer(),
            HoldToSpeak(
              label: 'Hold to speak',
              onUtterance: (sounds, heldMs) {
                widget.onIntent?.call('playground voice $sounds / ${heldMs}ms');
              },
            ),
          ],
        ),
      );
    }
    return VisualFieldShell(
      field: widget.profile.visualField,
      outputAtBottom: widget.profile.outputAtBottom,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Field recorded: ${widget.profile.visualField.label}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(
              'Overlay not applied. When tunnel layout ships, all buttons, '
              'text, and options live inside one square.',
              style: TextStyle(
                height: 1.4,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _calibrate(BuildContext context, PlaygroundMode mode) {
    void done() => _back();
    final step = switch (mode) {
      PlaygroundMode.buttons => ButtonsStep(
          draft: _draft,
          index: 0,
          total: 1,
          onNext: done,
          onSkip: done,
        ),
      PlaygroundMode.hold => HoldStep(
          draft: _draft,
          index: 0,
          total: 1,
          onNext: done,
          onSkip: done,
        ),
      PlaygroundMode.joystick => JoystickStep(
          draft: _draft,
          index: 0,
          total: 1,
          onNext: done,
          onSkip: done,
        ),
      PlaygroundMode.trackpad => TrackpadStep(
          draft: _draft,
          index: 0,
          total: 1,
          onNext: done,
          onSkip: done,
        ),
      PlaygroundMode.switchScan => ButtonsStep(
          draft: _draft,
          index: 0,
          total: 1,
          onNext: done,
          onSkip: done,
        ),
      PlaygroundMode.voice => VoiceStep(
          draft: _draft,
          index: 0,
          total: 1,
          onNext: done,
          onSkip: done,
        ),
      PlaygroundMode.vision => VisionStep(
          draft: _draft,
          index: 0,
          total: 1,
          onNext: done,
          onSkip: done,
        ),
    };
    return _chrome(
      title: 'Calibrate · ${mode.label}',
      subtitle: 'Existing calibration step. Skip or finish to return.',
      child: step,
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({required this.mode, required this.onTap});

  final PlaygroundMode mode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(mode.icon, size: 36, color: scheme.primary),
            const Spacer(),
            Text(
              mode.label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
