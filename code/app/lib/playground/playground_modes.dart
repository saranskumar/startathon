import 'package:flutter/material.dart';

import '../model/profile.dart';

/// Input modes the gear-menu Playground can open. Not a screen per mode —
/// the hub and session compose existing steps and [DiscreteTaskView].
enum PlaygroundMode {
  buttons,
  hold,
  joystick,
  trackpad,
  switchScan,
  voice,
  vision,
}

extension PlaygroundModeInfo on PlaygroundMode {
  String get label => switch (this) {
        PlaygroundMode.buttons => 'Buttons',
        PlaygroundMode.hold => 'Hold',
        PlaygroundMode.joystick => 'Joystick',
        PlaygroundMode.trackpad => 'Trackpad',
        PlaygroundMode.switchScan => 'Switch scan',
        PlaygroundMode.voice => 'Voice',
        PlaygroundMode.vision => 'Vision',
      };

  IconData get icon => switch (this) {
        PlaygroundMode.buttons => Icons.grid_view_rounded,
        PlaygroundMode.hold => Icons.touch_app,
        PlaygroundMode.joystick => Icons.gamepad_outlined,
        PlaygroundMode.trackpad => Icons.swipe,
        PlaygroundMode.switchScan => Icons.switch_left,
        PlaygroundMode.voice => Icons.mic_none,
        PlaygroundMode.vision => Icons.visibility_outlined,
      };

  TouchMethod? get touchMethod => switch (this) {
        PlaygroundMode.buttons => TouchMethod.buttons,
        PlaygroundMode.joystick => TouchMethod.joystick,
        PlaygroundMode.trackpad => TouchMethod.trackpad,
        PlaygroundMode.switchScan => TouchMethod.switchScan,
        PlaygroundMode.hold ||
        PlaygroundMode.voice ||
        PlaygroundMode.vision =>
          null,
      };

  /// Switch scan is measured through the Buttons test.
  bool get calibrateDisabled => this == PlaygroundMode.switchScan;

  /// Hold re-tests the buttons already found tappable.
  bool get needsButtonsFirst => this == PlaygroundMode.hold;
}

const playgroundModes = PlaygroundMode.values;
