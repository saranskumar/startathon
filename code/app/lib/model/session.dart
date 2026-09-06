import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'profile.dart';

/// One line of "what the phone would send to the laptop".
///
/// Nothing is connected to an agent yet (per current build scope), so every
/// resolved intent lands here instead of on a wire. The output strip renders
/// the newest one; the log sheet renders the history.
class InputEvent {
  InputEvent({
    required this.kind,
    required this.text,
    this.method,
    this.consequential = false,
  }) : at = DateTime.now();

  /// Short tag: RAW, INTENT, SENT, CONFIRM, CANCEL, VOICE, SYSTEM.
  final String kind;
  final String text;
  final TouchMethod? method;

  /// Would have executed something on the real world -- 2.4's confirmation gate.
  final bool consequential;
  final DateTime at;

  String get stamp {
    final h = at.hour.toString().padLeft(2, '0');
    final m = at.minute.toString().padLeft(2, '0');
    final s = at.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  String get line {
    final src = method == null ? '' : '[${method!.shortLabel}] ';
    return '$src$text';
  }
}

/// App-wide mutable state: the profile calibration produced, and the event log
/// standing in for the agent connection.
class AppState extends ChangeNotifier {
  CapabilityProfile _profile = CapabilityProfile.blank();
  final List<InputEvent> _events = <InputEvent>[];
  bool highContrast = false;
  String locale = 'en';

  /// Raw, high-frequency events (joystick ticks, trackpad drags) are useful to
  /// watch live but would flood the log, so they are kept separately and only
  /// the latest is shown.
  InputEvent? _raw;

  CapabilityProfile get profile => _profile;
  List<InputEvent> get events => List.unmodifiable(_events.reversed);
  InputEvent? get raw => _raw;
  InputEvent? get latest => _events.isEmpty ? null : _events.last;

  bool get isCalibrated => _profile.reachableCells.isNotEmpty ||
      _profile.methodScores.values.any((s) => s.tested);

  void setProfile(CapabilityProfile p) {
    _profile = p;
    emit(InputEvent(kind: 'SYSTEM', text: 'profile loaded: ${p.label}'));
  }

  void setHighContrast(bool value) {
    if (highContrast == value) return;
    highContrast = value;
    notifyListeners();
  }

  void setLocale(String value) {
    if (locale == value) return;
    locale = value;
    notifyListeners();
  }

  void setInputLevel(InputLevel level) {
    _profile = _profile.copyWith(inputLevel: level);
    emit(InputEvent(kind: 'SYSTEM', text: 'input level: ${level.label}'));
  }

  /// Transient signal from an input surface -- shown live, not logged.
  void emitRaw(String text, {TouchMethod? method}) {
    _raw = InputEvent(kind: 'RAW', text: text, method: method);
    notifyListeners();
  }

  void emit(InputEvent e) {
    _events.add(e);
    if (_events.length > 200) _events.removeAt(0);
    notifyListeners();
  }

  void clearLog() {
    _events.clear();
    _raw = null;
    notifyListeners();
  }
}

/// Plain InheritedNotifier so no third-party state package is needed -- the app
/// must build with only the Flutter SDK.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope missing above this widget');
    return scope!.notifier!;
  }
}

/// Accumulates per-attempt measurements for one calibration test and turns them
/// into a [MethodScore] using the formula in 3.1.
class TrialCollector {
  TrialCollector({required this.referenceMs, required this.referenceError});

  /// Time (ms) at which time_normalized saturates to 1 (worst).
  final double referenceMs;

  /// Error magnitude at which error_normalized saturates to 1 (worst). Units
  /// are per-test: logical pixels off-target for buttons/trackpad/pointing,
  /// misses for scanning.
  final double referenceError;

  final List<bool> _success = <bool>[];
  final List<double> _times = <double>[];
  final List<double> _errors = <double>[];

  void record({required bool success, required int ms, required double error}) {
    _success.add(success);
    _times.add(ms.toDouble());
    _errors.add(error);
  }

  bool get isEmpty => _success.isEmpty;
  int get count => _success.length;

  MethodScore build() {
    if (_success.isEmpty) return const MethodScore.untested();
    final successRate =
        _success.where((s) => s).length / _success.length.toDouble();
    final meanTime = _times.reduce((a, b) => a + b) / _times.length;
    final meanError = _errors.reduce((a, b) => a + b) / _errors.length;
    return MethodScore(
      successRate: successRate,
      timeNormalized: (meanTime / referenceMs).clamp(0.0, 1.0),
      errorNormalized: (meanError / referenceError).clamp(0.0, 1.0),
      attempts: _success.length,
    );
  }
}

/// The two demo profiles from docs/idea/06-user-model.md, used by the profile
/// switch so the interface can be reshaped live without re-running calibration.
class ProfilePresets {
  static CapabilityProfile get profileA => CapabilityProfile(
        label: 'Profile A (precise touch, clear speech)',
        methodScores: const {
          TouchMethod.buttons: MethodScore(
              successRate: 1, timeNormalized: 0.18, errorNormalized: 0.1,
              attempts: 6),
          TouchMethod.joystick: MethodScore(
              successRate: 0.9, timeNormalized: 0.35, errorNormalized: 0.2,
              attempts: 4),
          TouchMethod.trackpad: MethodScore(
              successRate: 0.95, timeNormalized: 0.28, errorNormalized: 0.15,
              attempts: 4),
          TouchMethod.switchScan: MethodScore(
              successRate: 0.9, timeNormalized: 0.7, errorNormalized: 0.2,
              attempts: 4),
        },
        reachableCells: {for (var i = 0; i < 12; i++) i},
        minTargetSize: 56,
        steadiness: 0.9,
        holdCapable: true,
        clarity: SpeechClarity.full,
        vision: VisionMode.screen,
        inputLevel: InputLevel.many,
      );

  /// Imprecise-but-present touch + slurred-but-present speech: the composition
  /// case Thesis B is built on.
  static CapabilityProfile get profileB => CapabilityProfile(
        label: 'Profile B (imprecise touch, slurred speech)',
        methodScores: const {
          TouchMethod.buttons: MethodScore(
              successRate: 0.45, timeNormalized: 0.8, errorNormalized: 0.7,
              attempts: 6),
          TouchMethod.joystick: MethodScore(
              successRate: 0.85, timeNormalized: 0.5, errorNormalized: 0.35,
              attempts: 4),
          TouchMethod.trackpad: MethodScore(
              successRate: 0.5, timeNormalized: 0.75, errorNormalized: 0.6,
              attempts: 4),
          TouchMethod.switchScan: MethodScore(
              successRate: 0.8, timeNormalized: 0.75, errorNormalized: 0.3,
              attempts: 4),
        },
        // Only the lower-left region registers reliably.
        reachableCells: {6, 7, 9, 10},
        minTargetSize: 120,
        steadiness: 0.35,
        holdCapable: false,
        clarity: SpeechClarity.partial,
        vision: VisionMode.large,
        vocabulary: const ['water', 'tank', 'yellow'],
        inputLevel: InputLevel.two,
      );

  /// The 3.5 floor case: no touch method works well, no usable speech.
  static CapabilityProfile get profileFloor => CapabilityProfile(
        label: 'Floor case (single-switch scanning)',
        methodScores: const {
          TouchMethod.buttons: MethodScore(
              successRate: 0.15, timeNormalized: 0.95, errorNormalized: 0.9,
              attempts: 6),
          TouchMethod.joystick: MethodScore(
              successRate: 0.2, timeNormalized: 0.9, errorNormalized: 0.85,
              attempts: 4),
          TouchMethod.trackpad: MethodScore(
              successRate: 0.1, timeNormalized: 0.95, errorNormalized: 0.95,
              attempts: 4),
          TouchMethod.switchScan: MethodScore(
              successRate: 0.75, timeNormalized: 0.85, errorNormalized: 0.25,
              attempts: 6),
        },
        reachableCells: {9, 10, 11},
        minTargetSize: 200,
        steadiness: 0.2,
        holdCapable: false,
        clarity: SpeechClarity.sounds,
        vision: VisionMode.large,
        visualField: VisualField.tunnel,
        inputLevel: InputLevel.one,
      );

  static List<CapabilityProfile> get all => [profileA, profileB, profileFloor];
}

/// Small helpers shared by the input surfaces.
double angleOf(Offset o) => math.atan2(o.dy, o.dx);

/// Nearest of the four cardinal directions for a vector, or null inside the
/// dead zone. Used by joystick + flick.
String? cardinalOf(Offset o, {double deadZone = 0.35}) {
  if (o.distance < deadZone) return null;
  final a = angleOf(o);
  const q = math.pi / 4;
  if (a >= -q && a < q) return 'right';
  if (a >= q && a < 3 * q) return 'down';
  if (a >= -3 * q && a < -q) return 'up';
  return 'left';
}
