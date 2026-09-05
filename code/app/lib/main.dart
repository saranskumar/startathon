import 'package:flutter/material.dart';

import 'calibration/calibration_flow.dart';
import 'model/profile.dart';
import 'model/session.dart';
import 'runtime/demo_screen.dart';
import 'runtime/preview_screen.dart';

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

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  void _use(CapabilityProfile p) {
    _state.setProfile(p);
    setState(() => _screen = _Screen.preview);
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: _state,
      child: MaterialApp(
        title: 'Access Layer',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF2F5BEA),
            brightness: Brightness.light,
          ),
          useMaterial3: true,
        ),
        home: Builder(
          builder: (context) => switch (_screen) {
            _Screen.home => _HomeScreen(
                onCalibrate: () => setState(() => _screen = _Screen.calibrate),
                onPreset: _use,
              ),
            _Screen.calibrate => Scaffold(
                body: SafeArea(
                  child: CalibrationFlow(onComplete: _use),
                ),
              ),
            _Screen.preview => InputPreviewScreen(
                onContinue: () => setState(() => _screen = _Screen.demo),
                onRecalibrate: () => setState(() => _screen = _Screen.home),
              ),
            _Screen.demo => DemoScreen(
                onRecalibrate: () => setState(() => _screen = _Screen.home),
                onOpenPreview: () => setState(() => _screen = _Screen.preview),
              ),
          },
        ),
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

  final VoidCallback onCalibrate;
  final void Function(CapabilityProfile) onPreset;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
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
              'Input layer only. Nothing is connected to a computer yet -- '
              'what would be sent shows up in the strip at the edge of the '
              'screen.',
              style: TextStyle(color: scheme.onSurfaceVariant, height: 1.4),
            ),
            const SizedBox(height: 26),
            SizedBox(
              height: 84,
              child: FilledButton.icon(
                onPressed: onCalibrate,
                icon: const Icon(Icons.tune),
                label: const Text(
                  'Calibrate me',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Seven tests, about two minutes. Every one can be skipped.',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 30),
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
