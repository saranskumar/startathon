import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'haptics.dart';

/// How many marked cells a level can hold before it splits into a sub-grid --
/// matches how many distinguishable sound bursts (docs/idea/22: "four or
/// five setting options") a user can reliably produce and tell apart. Beyond
/// this, a cell becomes a *group* that descends into its own sub-grid rather
/// than the grid growing past what's selectable in one shot.
const int kMaxMarkersPerLevel = 5;
const List<String> kMarkerLetters = ['A', 'B', 'C', 'D', 'E'];

/// One cell of the recursive marker tree: either a resolved option (leaf) or
/// a further-subdivided group of options.
class MarkerNode {
  MarkerNode.leaf(this.label, this.value) : children = const [];
  MarkerNode.group(this.label, this.children) : value = null;

  final String label;
  final String? value;
  final List<MarkerNode> children;

  bool get isLeaf => children.isEmpty;
}

List<List<String>> _splitInto(List<String> options, int parts) {
  final size = (options.length / parts).ceil();
  return [
    for (var i = 0; i < options.length; i += size)
      options.sublist(i, math.min(i + size, options.length)),
  ];
}

/// Builds a recursive marker tree from a flat option list: at most
/// [kMaxMarkersPerLevel] cells per level, each holding either one option or
/// a further-subdivided group -- so a list of any size is reachable in
/// ceil(log5(n)) marker picks instead of one linear scan.
List<MarkerNode> buildMarkerLevel(List<String> options) {
  if (options.length <= kMaxMarkersPerLevel) {
    return [for (final o in options) MarkerNode.leaf(o, o)];
  }
  return [
    for (final chunk in _splitInto(options, kMaxMarkersPerLevel))
      chunk.length == 1
          ? MarkerNode.leaf(chunk.first, chunk.first)
          : MarkerNode.group(
              '${chunk.first} +${chunk.length - 1} more',
              buildMarkerLevel(chunk),
            ),
  ];
}

/// Holds the recursive-descent state for one marker-grid session and turns a
/// burst count into a marker pick. Kept separate from the widget so the
/// cells (pure information, shown wherever there's room) and the actual
/// microphone control (must sit in the user's reachable zone, same as every
/// other input surface) can be placed independently via [InputOverlay]'s
/// content/dock split.
class MarkerGridController extends ChangeNotifier {
  MarkerGridController(
    List<String> options, {
    required this.onResolve,
    this.onRaw,
  })  : _options = options,
        _level = buildMarkerLevel(options);

  final List<String> _options;
  final void Function(int index, String value) onResolve;
  final void Function(String raw)? onRaw;

  List<MarkerNode> _level;
  final List<List<MarkerNode>> _stack = <List<MarkerNode>>[];

  List<MarkerNode> get level => _level;
  bool get canGoBack => _stack.isNotEmpty;

  String get instructionLabel => _level.length == 1
      ? 'Make 1 sound for A'
      : 'Make 1-${_level.length} sounds for A-${kMarkerLetters[_level.length - 1]}';

  /// Feed this directly to [HoldToSpeak.onUtterance].
  void onUtterance(int soundCount, int heldMs) {
    final index = soundCount - 1;
    if (index < 0 || index >= _level.length) {
      onRaw?.call('marker: $soundCount sounds -- no matching cell');
      return;
    }
    final node = _level[index];
    onRaw?.call('marker ${kMarkerLetters[index]} -> ${node.label}');
    if (node.isLeaf) {
      Haptics.confirm();
      onResolve(_options.indexOf(node.value!), node.value!);
      return;
    }
    Haptics.navigate();
    _stack.add(_level);
    _level = node.children;
    notifyListeners();
  }

  void back() {
    if (_stack.isEmpty) return;
    Haptics.navigate();
    _level = _stack.removeLast();
    notifyListeners();
  }
}

/// The lettered cells themselves -- purely informational (nothing here is a
/// touch target; selection happens by voice through [MarkerGridController]).
class MarkerGrid extends StatelessWidget {
  const MarkerGrid({super.key, required this.controller, this.textScale = 1.0});

  final MarkerGridController controller;
  final double textScale;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final scheme = Theme.of(context).colorScheme;
        final level = controller.level;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (controller.canGoBack)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: controller.back,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('back'),
                ),
              ),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (var i = 0; i < level.length; i++) _cell(scheme, i, level[i]),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _cell(ColorScheme scheme, int i, MarkerNode node) => Container(
        width: 140,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(shape: BoxShape.circle, color: scheme.primary),
              alignment: Alignment.center,
              child: Text(
                kMarkerLetters[i],
                style: TextStyle(color: scheme.onPrimary, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              node.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13 * textScale, fontWeight: FontWeight.w600),
            ),
            if (!node.isLeaf)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Icon(Icons.more_horiz, size: 16, color: scheme.onSurfaceVariant),
              ),
          ],
        ),
      );
}
