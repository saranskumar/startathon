import 'package:flutter/material.dart';

import 'calibration/calibration_flow.dart';
import 'model/profile.dart';
import 'model/session.dart';
import 'onboarding/recorded_voice.dart';
import 'runtime/demo_screen.dart';
import 'runtime/preview_screen.dart';
import 'theme/contrast_theme.dart';
import 'theme/haiku_theme.dart';
import 'vision/field_shell.dart';

/// Adaptive Capability-Profile Access Layer -- input layer only.
///
/// This build is the phone side of docs/idea/07-architecture.md and nothing
/// else: calibration produces a capability profile, and the profile decides how
/// every task is operated. There is no agent, no browser automation and no
/// connection to a laptop -- resolved intents are written to the output strip
/// instead, which is placed in whichever screen region calibration found the
/// user cannot reach anyway.
void main() => runApp(const AccessLayerApp());

class AccessLayerApp extends StatefulWidget {
  const AccessLayerApp({super.key});

  @override
  State<AccessLayerApp> createState() => _AccessLayerAppState();
}

enum _Screen { home, calibrate, preview, demo }

class _AccessLayerAppState extends State<AccessLayerApp> {
  final AppState _state = AppState();
  _Screen _screen = _Screen.home;
  bool _assisted = false;

  /// Live during calibration: updated the moment the intro's axis toggles
  /// change, so the theme reacts before any test has produced a score.
  HaikuTheme _liveTheme = HaikuTheme.fallback;

  @override
  void initState() {
    super.initState();
    _state.addListener(_onState);
  }

  void _onState() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _state.removeListener(_onState);
    _state.dispose();
    super.dispose();
  }

  void _use(CapabilityProfile p) {
    _state.setProfile(p);
    setState(() {
      _liveTheme = p.haikuTheme;
      _screen = _Screen.preview;
    });
  }

  void _onAxesChanged(bool motor, bool speech, bool vision) {
    setState(() {
      _liveTheme = HaikuTheme.compute(motor: motor, speech: speech, vision: vision);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = _screen == _Screen.home && !_state.isCalibrated
        ? HaikuTheme.fallback
        : _liveTheme;
    return AppScope(
      state: _state,
      child: Builder(
        builder: (context) {
          final mq = MediaQuery.maybeOf(context) ??
              MediaQueryData.fromView(View.of(context));
          final highContrast = _state.highContrast || mq.highContrast;
          final scheme =
              highContrast ? ContrastTheme.scheme() : theme.colorScheme;
          return MaterialApp(
            title: 'Access Layer',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              colorScheme: scheme,
              useMaterial3: true,
            ),
            home: Builder(
              builder: (context) {
                final body = switch (_screen) {
                  _Screen.home => _HomeScreen(
                      onCalibrate: (assisted) => setState(() {
                        _assisted = assisted;
                        _screen = _Screen.calibrate;
                      }),
                      onPreset: _use,
                    ),
                  _Screen.calibrate => Scaffold(
                      body: SafeArea(
                        child: CalibrationFlow(
                          startAssisted: _assisted,
                          locale: _state.locale,
                          onComplete: _use,
                          onAxesChanged: _onAxesChanged,
                        ),
                      ),
                    ),
                  _Screen.preview => InputPreviewScreen(
                      onContinue: () =>
                          setState(() => _screen = _Screen.demo),
                      onRecalibrate: () =>
                          setState(() => _screen = _Screen.home),
                    ),
                  _Screen.demo => DemoScreen(
                      onRecalibrate: () =>
                          setState(() => _screen = _Screen.home),
                      onOpenPreview: () =>
                          setState(() => _screen = _Screen.preview),
                    ),
                };
                final profile = _state.profile;
                return VisualFieldShell(
                  field: _screen == _Screen.home
                      ? VisualField.full
                      : profile.visualField,
                  outputAtBottom: profile.outputAtBottom,
                  child: body,
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/// Entry point and profile switch in one.
///
/// The presets are here because 05-scope item 3 makes the visible A/B reshape
/// non-negotiable, and a live calibration run takes two minutes -- too long to
/// repeat in front of a judge. Calibrating for real and picking a preset both
/// end in the same object, so the runtime cannot tell them apart.
class _HomeScreen extends StatelessWidget {
  const _HomeScreen({required this.onCalibrate, required this.onPreset});

  final void Function(bool assisted) onCalibrate;
  final void Function(CapabilityProfile) onPreset;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final state = AppScope.of(context);
    return Scaffold(
      body: SafeArea(
        child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onCalibrate(false),
                onLongPress: () => onCalibrate(false),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Access layer',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tap or hold this block to start. There is no small '
                      'button to find first.',
                      style: TextStyle(
                          color: scheme.onSurfaceVariant, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    RecordedNarration(
                      clipId: 'welcome',
                      locale: state.locale,
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 36),
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Tap anywhere to start',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: scheme.onPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 56,
                child: OutlinedButton(
                  onPressed: () => onCalibrate(true),
                  child: const Text(
                    'Someone is helping set this up',
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: FilterChip(
                      label: const Text('High contrast'),
                      selected: state.highContrast,
                      onSelected: state.setHighContrast,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: Text(state.locale == 'ml' ? 'മലയാളം' : 'English'),
                    selected: true,
                    onSelected: (_) => state.setLocale(
                      state.locale == 'en' ? 'ml' : 'en',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Text(
                'OR START FROM A SAVED PROFILE',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w800,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(height: 12),
              for (final p in ProfilePresets.all)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _PresetCard(profile: p, onTap: () => onPreset(p)),
                ),
            ],
        ),
      ),
    );
  }
}

class _PresetCard extends StatelessWidget {
  const _PresetCard({required this.profile, required this.onTap});

  final CapabilityProfile profile;
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
            Row(
              children: [
                Expanded(
                  child: Text(
                    profile.label,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    profile.bestMethod.label,
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              profile.summary,
              style: TextStyle(
                fontSize: 11,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
