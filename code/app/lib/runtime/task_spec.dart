import '../model/profile.dart';

/// docs/idea/03-input-calibration.md 3.2 -- a task's shape is fixed at design
/// time, and the shape alone decides the *ideal* input method. Nothing here is
/// inferred live by an agent.
enum TaskShape { discrete, continuous, pointing, text }

extension TaskShapeInfo on TaskShape {
  String get label => switch (this) {
        TaskShape.discrete => 'Discrete choice',
        TaskShape.continuous => 'Continuous / directional',
        TaskShape.pointing => 'Free 2D pointing',
        TaskShape.text => 'Free text (fused)',
      };

  /// The static task-to-input mapping from 3.2.
  TouchMethod get idealMethod => switch (this) {
        TaskShape.discrete => TouchMethod.buttons,
        TaskShape.continuous => TouchMethod.joystick,
        TaskShape.pointing => TouchMethod.trackpad,
        // Text is selection + content; selection follows discrete.
        TaskShape.text => TouchMethod.buttons,
      };
}

class TaskSpec {
  const TaskSpec({
    required this.id,
    required this.title,
    required this.prompt,
    required this.shape,
    this.options = const <String>[],
    this.unit = '',
    this.min = 0,
    this.max = 100,
    this.fieldLabel = '',
  });

  final String id;
  final String title;

  /// What the user is being asked to do, in one sentence.
  final String prompt;
  final TaskShape shape;
  final List<String> options;
  final String unit;
  final int min;
  final int max;
  final String fieldLabel;
}

/// The demo tasks. These mirror the mock target site (code/mock) closely enough
/// to show each interaction pattern, without needing the agent connection.
class DemoTasks {
  static const pickPlan = TaskSpec(
    id: 'pick-plan',
    title: 'Pick a plan',
    prompt: 'Choose one of the plans.',
    shape: TaskShape.discrete,
    options: ['Starter', 'Standard', 'Pro', 'Team', 'Enterprise', 'Custom'],
  );

  static const setQuantity = TaskSpec(
    id: 'set-quantity',
    title: 'Set seat count',
    prompt: 'Adjust the number of seats.',
    shape: TaskShape.continuous,
    unit: 'seats',
    min: 1,
    max: 50,
  );

  static const placeMarker = TaskSpec(
    id: 'place-marker',
    title: 'Mark a spot',
    prompt: 'Place the marker on the delivery point.',
    shape: TaskShape.pointing,
  );

  static const writeNote = TaskSpec(
    id: 'write-note',
    title: 'Add a note',
    prompt: 'Fill the note field.',
    shape: TaskShape.text,
    fieldLabel: 'Delivery note',
  );

  static const List<TaskSpec> all = [
    pickPlan,
    setQuantity,
    placeMarker,
    writeNote,
  ];
}

/// The result of applying 3.3's fallback rule for one task and one profile.
class MethodChoice {
  const MethodChoice({
    required this.method,
    required this.ideal,
    required this.isFallback,
    required this.reason,
  });

  final TouchMethod method;
  final TouchMethod ideal;
  final bool isFallback;
  final String reason;
}

/// docs/idea/03-input-calibration.md 3.3:
///
/// > Use the task's ideal input type unless a different method scores
/// > meaningfully higher for this user.
///
/// Relative, never absolute: [margin] is how much better "meaningfully higher"
/// has to be, so a small scoring wobble does not yank the user's interface out
/// from under them, and a user whose best score is mediocre still gets their
/// genuine best rather than being declared non-viable.
MethodChoice chooseMethod(
  CapabilityProfile profile,
  TaskShape shape, {
  double margin = 0.12,
}) {
  final ideal = shape.idealMethod;
  final idealScore = profile.scoreOf(ideal);
  final best = profile.bestMethod;
  final bestScore = profile.scoreOf(best);

  if (best == ideal || bestScore < idealScore + margin) {
    return MethodChoice(
      method: ideal,
      ideal: ideal,
      isFallback: false,
      reason: 'ideal for ${shape.label.toLowerCase()}; '
          '${ideal.shortLabel} ${idealScore.toStringAsFixed(2)} '
          'not beaten by ${margin.toStringAsFixed(2)}',
    );
  }
  return MethodChoice(
    method: best,
    ideal: ideal,
    isFallback: true,
    reason: '${ideal.shortLabel} ${idealScore.toStringAsFixed(2)} -> '
        '${best.shortLabel} ${bestScore.toStringAsFixed(2)}; '
        'fallback uses ${best.label.toLowerCase()} native pattern',
  );
}

/// One-line description of the interaction pattern a (shape, method) pair
/// resolves to -- the 3.3 matrix, made inspectable so the demo can say out loud
/// what it just did.
String patternFor(TaskShape shape, TouchMethod method) =>
    switch ((shape, method)) {
      (TaskShape.discrete, TouchMethod.buttons) => 'direct tap on the option',
      (TaskShape.discrete, TouchMethod.joystick) =>
        'cycle highlight, press to confirm',
      (TaskShape.discrete, TouchMethod.trackpad) =>
        'drag to hover, release to select',
      (TaskShape.discrete, TouchMethod.switchScan) =>
        'auto-scan highlight, press to select',
      (TaskShape.continuous, TouchMethod.joystick) =>
        'push and hold to move continuously',
      (TaskShape.continuous, TouchMethod.buttons) =>
        'stepper: previous / next',
      (TaskShape.continuous, TouchMethod.trackpad) => 'drag to scrub',
      (TaskShape.continuous, TouchMethod.switchScan) =>
        'scan direction, press to start/stop motion',
      (TaskShape.pointing, TouchMethod.trackpad) =>
        'drag cursor, release to place',
      (TaskShape.pointing, TouchMethod.joystick) =>
        'steer cursor, press to place',
      (TaskShape.pointing, TouchMethod.buttons) =>
        'coarse-to-fine zone narrowing (agent-assisted)',
      (TaskShape.pointing, TouchMethod.switchScan) =>
        'row scan, then column scan',
      (TaskShape.text, _) => 'touch selects the field, voice supplies content',
    };
