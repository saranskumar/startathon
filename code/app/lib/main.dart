import 'package:flutter/material.dart';

import 'calibration/calibration_flow.dart';
import 'live/link_setup_screen.dart';
import 'live/live_screen.dart';
import 'live/live_store.dart';
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
/// Launch is a full-bleed Start gate, then Setup. Demo presets live behind
/// the settings circle. Once the user confirms a profile, the rest of the
/// session stays on that calibrated UI.
void main() => runApp(const AccessLayerApp());

class AccessLayerApp extends StatefulWidget {
  const AccessLayerApp({super.key});

  @override
  State<AccessLayerApp> createState() => _AccessLayerAppState();
}

enum _Screen { start, link, home, calibrate, preview, demo, live }

class _AccessLayerAppState extends State<AccessLayerApp> {
  final AppState _state = AppState();
  _Screen _screen = _Screen.start;
  bool _assisted = false;

  /// Bumped on redo so CalibrationFlow remounts with a fresh draft.
  int _setupEpoch = 0;

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
    _state.setProfile(p, confirm: true);
    LiveStore.saveProfile(p);
    setState(() {
      _liveTheme = p.haikuTheme;
      _screen = _Screen.preview;
      _assisted = false;
    });
  }

  void _onDraftChanged(CapabilityProfile p) {
    _state.applyLiveProfile(p);
    // Avoid setState during CalibrationFlow build/init.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _liveTheme = p.haikuTheme);
    });
  }

  void _onAxesChanged(bool motor, bool speech, bool vision) {
    final next =
        HaikuTheme.compute(motor: motor, speech: speech, vision: vision);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _liveTheme = next);
    });
  }

  void _redoSetup({bool assisted = false}) {
    _state.clearProfile();
    setState(() {
      _assisted = assisted;
      _setupEpoch++;
      _liveTheme = HaikuTheme.fallback;
      // Redo returns to Setup, not the Start gate. Helper from settings
      // skips Setup and opens training inside calibration.
      _screen = assisted ? _Screen.calibrate : _Screen.home;
    });
  }

  void _beginCalibration(bool assisted) {
    setState(() {
      _assisted = assisted;
      _screen = _Screen.calibrate;
    });
  }

  void _openSettings(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _DemoSettingsSheet(
        state: _state,
        onPreset: (p) {
          Navigator.pop(ctx);
          _use(p);
        },
        onRedoSetup: () {
          Navigator.pop(ctx);
          _redoSetup();
        },
        onHelping: () {
          Navigator.pop(ctx);
          _redoSetup(assisted: true);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = _liveTheme;
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
                  _Screen.start => _StartGateScreen(
                      onStart: () => setState(() => _screen = _Screen.link),
                    ),
                  _Screen.link => LinkSetupScreen(
                      onContinue: () =>
                          setState(() => _screen = _Screen.home),
                    ),
                  _Screen.home => _HomeScreen(
                      onCalibrate: _beginCalibration,
                      showSettings: () => _openSettings(context),
                    ),
                  _Screen.calibrate => Scaffold(
                      body: SafeArea(
                        child: CalibrationFlow(
                          key: ValueKey('setup-$_setupEpoch-$_assisted'),
                          startAssisted: _assisted,
                          locale: _state.locale,
                          onComplete: _use,
                          onAxesChanged: _onAxesChanged,
                          onDraftChanged: _onDraftChanged,
                          showSettings: () => _openSettings(context),
                        ),
                      ),
                    ),
                  _Screen.preview => Stack(
                      children: [
                        InputPreviewScreen(
                          onContinue: () =>
                              setState(() => _screen = _Screen.demo),
                          onConnect: () =>
                              setState(() => _screen = _Screen.live),
                          onRecalibrate: _redoSetup,
                        ),
                        Positioned(
                          top: MediaQuery.paddingOf(context).top + 8,
                          right: 8,
                          child: _SettingsCircle(
                            onPressed: () => _openSettings(context),
                          ),
                        ),
                      ],
                    ),
                  _Screen.demo => Stack(
                      children: [
                        DemoScreen(
                          onRecalibrate: _redoSetup,
                          onOpenPreview: () =>
                              setState(() => _screen = _Screen.preview),
                        ),
                        Positioned(
                          top: MediaQuery.paddingOf(context).top + 8,
                          right: 8,
                          child: _SettingsCircle(
                            onPressed: () => _openSettings(context),
                          ),
                        ),
                      ],
                    ),
                  _Screen.live => Stack(
                      children: [
                        LiveScreen(
                          onRecalibrate: _redoSetup,
                          onOpenPreview: () =>
                              setState(() => _screen = _Screen.preview),
                        ),
                        Positioned(
                          top: MediaQuery.paddingOf(context).top + 8,
                          right: 8,
                          child: _SettingsCircle(
                            onPressed: () => _openSettings(context),
                          ),
                        ),
                      ],
                    ),
                };
                final profile = _state.profile;
                // Start gate, laptop link, and Setup stay full-field.
                // Draft.visualField is full until vision commits, then the
                // veil applies.
                final field = (_screen == _Screen.start ||
                        _screen == _Screen.link ||
                        _screen == _Screen.home)
                    ? VisualField.full
                    : profile.visualField;
                return VisualFieldShell(
                  field: field,
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

class _StartGateScreen extends StatelessWidget {
  const _StartGateScreen({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SizedBox.expand(
        child: GestureDetector(
          key: const Key('start-gate'),
          behavior: HitTestBehavior.opaque,
          onTap: onStart,
          onLongPress: onStart,
          child: ColoredBox(
            color: scheme.primary,
            child: Semantics(
              button: true,
              label: 'Tap or hold to continue',
              child: Center(
                child: Icon(
                  Icons.touch_app,
                  size: 72,
                  color: scheme.onPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Setup: helper / contrast / locale sit up top, out of the thumb zone.
/// The reachable lower region is only the tap/hold-to-start block.
class _HomeScreen extends StatelessWidget {
  const _HomeScreen({
    required this.onCalibrate,
    required this.showSettings,
  });

  final void Function(bool assisted) onCalibrate;
  final VoidCallback showSettings;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final state = AppScope.of(context);
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 56),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            OutlinedButton(
                              onPressed: () => onCalibrate(true),
                              child: const Text(
                                'Someone is helping set this up',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            FilterChip(
                              label: const Text('High contrast'),
                              selected: state.highContrast,
                              onSelected: state.setHighContrast,
                            ),
                            FilterChip(
                              label: Text(
                                state.locale == 'ml' ? '??????' : 'English',
                              ),
                              selected: true,
                              onSelected: (_) => state.setLocale(
                                state.locale == 'en' ? 'ml' : 'en',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Set up how you control things',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'There is no pass or fail. Tap or hold the block '
                          'below when you are ready.',
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 12),
                        RecordedNarration(
                          clipId: 'welcome',
                          locale: state.locale,
                          autoplay: true,
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onCalibrate(false),
                      onLongPress: () => onCalibrate(false),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Center(
                          child: Text(
                            'Tap anywhere to start',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: scheme.onPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              top: 8,
              right: 8,
              child: _SettingsCircle(onPressed: showSettings),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsCircle extends StatelessWidget {
  const _SettingsCircle({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(Icons.settings, size: 22, color: scheme.onSurface),
        ),
      ),
    );
  }
}

/// Demo / judge controls: presets, contrast, locale, redo, helper training.
/// Kept out of the first-run path so Setup stays a single tap/hold.
class _DemoSettingsSheet extends StatelessWidget {
  const _DemoSettingsSheet({
    required this.state,
    required this.onPreset,
    required this.onRedoSetup,
    required this.onHelping,
  });

  final AppState state;
  final void Function(CapabilityProfile) onPreset;
  final VoidCallback onRedoSetup;
  final VoidCallback onHelping;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Text(
            'Settings',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Demo presets. High contrast and language also sit on Setup, '
            'above the tap-to-start block.',
            style: TextStyle(color: scheme.onSurfaceVariant, height: 1.35),
          ),
          const SizedBox(height: 16),
          if (state.setupConfirmed) ...[
            SizedBox(
              height: 56,
              width: double.infinity,
              child: FilledButton.tonal(
                onPressed: onRedoSetup,
                child: const Text('Redo setup'),
              ),
            ),
            const SizedBox(height: 10),
          ],
          SizedBox(
            height: 56,
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onHelping,
              child: const Text(
                'Someone is helping set this up',
                textAlign: TextAlign.center,
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
                label: Text(state.locale == 'ml' ? '??????' : 'English'),
                selected: true,
                onSelected: (_) => state.setLocale(
                  state.locale == 'en' ? 'ml' : 'en',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
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
          FutureBuilder<CapabilityProfile?>(
            future: LiveStore.loadProfile(),
            builder: (context, snap) {
              final saved = snap.data;
              if (saved == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _PresetCard(
                  profile: saved,
                  onTap: () => onPreset(saved),
                ),
              );
            },
          ),
          for (final p in ProfilePresets.all)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _PresetCard(profile: p, onTap: () => onPreset(p)),
            ),
        ],
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
