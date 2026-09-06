import 'package:flutter/material.dart';

import '../model/profile.dart';

/// Lays out one task: content, plus the input surface it is being driven with.
///
/// The joystick is passed as [overlay] and floats -- translucent, anchored to
/// the middle of the user's reachable zone -- because a docked stick would be
/// pinned wherever the layout wants it rather than where the hand rests.
/// Everything else is passed as [dock] and sits at the bottom of the reachable
/// area, where it can be a fixed, predictable target.
class InputOverlay extends StatelessWidget {
  const InputOverlay({
    super.key,
    required this.profile,
    required this.content,
    this.overlay,
    this.dock,
  });

  final CapabilityProfile profile;
  final Widget content;
  final Widget? overlay;
  final Widget? dock;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final reach = profile.reachableRect(size);
        return Stack(
          children: [
            Positioned.fill(
              child: Column(
                children: [
                  Expanded(child: content),
                  if (dock != null)
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        // Keep the dock inside the horizontal span the user can
                        // actually reach, rather than full-bleed.
                        reach.left.clamp(0.0, size.width * 0.4),
                        8,
                        (size.width - reach.right).clamp(0.0, size.width * 0.4),
                        12,
                      ),
                      child: dock!,
                    ),
                ],
              ),
            ),
            if (overlay != null)
              Positioned.fill(
                child: Align(
                  // The joystick swing test (if it ran) knows exactly which
                  // reachable cell the stick is steadiest at; fall back to the
                  // reachable area's centroid otherwise.
                  alignment: profile.joystickAnchor,
                  child: overlay!,
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Shared highlight tokens for every input mode.
///
/// Item = the option that will commit. Group = the active section (scan row
/// or page). Idle = everything else. Joystick already used this language;
/// other modes reuse the same paint.
enum HighlightTier { idle, group, item }

class OptionHighlightStyle {
  static HighlightTier tier({required bool item, bool group = false}) {
    if (item) return HighlightTier.item;
    if (group) return HighlightTier.group;
    return HighlightTier.idle;
  }

  static BoxDecoration decoration(ColorScheme scheme, HighlightTier tier) {
    switch (tier) {
      case HighlightTier.item:
        return BoxDecoration(
          color: scheme.primary,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.primary, width: 3),
        );
      case HighlightTier.group:
        return BoxDecoration(
          color: scheme.primaryContainer.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.primary, width: 1),
        );
      case HighlightTier.idle:
        return BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.outlineVariant, width: 1),
        );
    }
  }

  static Color foreground(ColorScheme scheme, HighlightTier tier) =>
      tier == HighlightTier.item ? scheme.onPrimary : scheme.onSurface;
}

/// One option row or grid cell, painted with [OptionHighlightStyle].
class SelectionCell extends StatelessWidget {
  const SelectionCell({
    super.key,
    required this.label,
    required this.tier,
    this.onTap,
    this.minHeight = 56,
    this.textScale = 1.0,
    this.compact = false,
    this.center = false,
    this.showChevron = true,
  });

  final String label;
  final HighlightTier tier;
  final VoidCallback? onTap;
  final double minHeight;
  final double textScale;
  final bool compact;
  final bool center;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = OptionHighlightStyle.foreground(scheme, tier);
    final selected = tier == HighlightTier.item;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 110),
          constraints: BoxConstraints(minHeight: compact ? 48 : minHeight),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: OptionHighlightStyle.decoration(scheme, tier),
          alignment: center ? Alignment.center : Alignment.centerLeft,
          child: Row(
            mainAxisAlignment:
                center ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  label,
                  textAlign: center ? TextAlign.center : TextAlign.start,
                  softWrap: true,
                  style: TextStyle(
                    fontSize: (center ? 15 : 18) * textScale,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: fg,
                    height: 1.2,
                  ),
                ),
              ),
              if (showChevron && selected && !center)
                Icon(Icons.chevron_right, color: fg),
            ],
          ),
        ),
      ),
    );
  }
}

/// The shared way options are shown, whatever method is driving the highlight.
///
/// One list, four input methods: buttons tap it directly, the joystick and the
/// switch move [highlight] through it, the trackpad hovers it. Keeping a single
/// presentation is deliberate -- a fallback should change how you operate the
/// control, not turn the screen into something unrecognisable.
class OptionList extends StatelessWidget {
  const OptionList({
    super.key,
    required this.options,
    required this.highlight,
    this.groupIndexes = const [],
    this.onTap,
    this.textScale = 1.0,
    this.minTargetSize = 56,
    this.compact = false,
  });

  final List<String> options;
  final int highlight;

  /// Local indexes in the current section (page / scan row). Painted as group
  /// when they are not the item highlight.
  final List<int> groupIndexes;
  final void Function(int index)? onTap;
  final double textScale;
  final double minTargetSize;

  /// When another surface owns selection, rows do not need to be tap targets
  /// and can be tighter.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      container: true,
      label: highlight >= 0 && highlight < options.length
          ? '${options[highlight]}, selected'
          : 'options',
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: options.length,
        itemBuilder: (context, i) {
          final tier = OptionHighlightStyle.tier(
            item: i == highlight,
            group: groupIndexes.contains(i),
          );
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SelectionCell(
              label: options[i],
              tier: tier,
              textScale: textScale,
              minHeight: minTargetSize,
              compact: compact,
              onTap: onTap == null ? null : () => onTap!(i),
            ),
          );
        },
      ),
    );
  }
}

/// A large, unmissable commit control for methods that have no natural "press"
/// of their own (trackpad, buttons-driven continuous adjust).
class CommitBar extends StatelessWidget {
  const CommitBar({
    super.key,
    required this.label,
    required this.onPressed,
    this.height = 72,
    this.textScale = 1.0,
  });

  final String label;
  final VoidCallback onPressed;
  final double height;
  final double textScale;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: FilledButton(
        onPressed: onPressed,
        child: Text(label, style: TextStyle(fontSize: 19 * textScale)),
      ),
    );
  }
}
