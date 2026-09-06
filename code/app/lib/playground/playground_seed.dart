import 'package:flutter/material.dart';

import '../calibration/step_frame.dart';
import '../model/profile.dart';

/// Seed a calibration draft from the current profile so a single playground
/// step can remount without a full axis-picker run.
CalibrationDraft draftFromProfile(CapabilityProfile profile) {
  final draft = CalibrationDraft();
  draft.scores
    ..clear()
    ..addAll(profile.methodScores);
  draft.reachableCells.addAll(profile.reachableCells);
  draft.lockedCells.addAll(profile.lockedCells);
  draft.minTargetSize = profile.minTargetSize;
  draft.steadiness = profile.steadiness;
  draft.holdCapable = profile.holdCapable;
  draft.clarity = profile.clarity;
  draft.vision = profile.vision;
  draft.visualField = profile.visualField;
  draft.inputLevel = profile.inputLevel;
  draft.vocabulary = List.of(profile.vocabulary);
  draft.locale = profile.locale;
  draft.joystickHomeCell = profile.joystickHomeCell;
  draft.measureMotor = profile.measureMotor;
  draft.measureSpeech = profile.measureSpeech;
  draft.measureVision = profile.measureVision;
  final n = profile.tappableButtonCount.clamp(0, 6);
  for (var i = 0; i < n; i++) {
    final cells = profile.reachableCells.toList();
    final cell = cells.isEmpty ? i : cells[i % cells.length];
    draft.tappableButtons.add(
      ButtonTarget(
        cell: cell,
        size: profile.minTargetSize,
        placement: Alignment(0, -0.25 + (i * 0.18)),
      ),
    );
  }
  return draft;
}
