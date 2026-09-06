import 'package:flutter/services.dart';

/// Haptic output, named by what it means rather than by intensity -- callers
/// should never have to remember which raw [HapticFeedback] level means what.
/// Uses `flutter/services.dart` only: no package, works everywhere the SDK
/// itself does.
abstract final class Haptics {
  /// Highlight moved during navigation (joystick cycle, switch-scan tick).
  /// Deliberately the lightest tier -- this fires often and must not feel
  /// like a rebuke.
  static void navigate() => _try(HapticFeedback.selectionClick);

  /// A choice was resolved / confirmed.
  static void confirm() => _try(HapticFeedback.mediumImpact);

  /// A test round was missed, timed out, or an action failed.
  static void error() => _try(HapticFeedback.heavyImpact);

  static void _try(Future<void> Function() fn) {
    try {
      fn().ignore();
    } catch (_) {
      // No ServicesBinding in plain unit tests; the meaning still happened.
    }
  }
}
