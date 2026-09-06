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
    this.onTap,
    this.textScale = 1.0,
    this.minTargetSize = 56,
    this.compact = false,
  });

  final List<String> options;
  final int highlight;
  final void Function(int index)? onTap;
  final double textScale;
  final double minTargetSize;

  /// When another surface owns selection, rows do not need to be tap targets
  /// and can be tighter.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
        final selected = i == highlight;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Semantics(
            button: true,
            selected: selected,
            label: options[i],
            child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap == null ? null : () => onTap!(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 110),
              constraints: BoxConstraints(
                minHeight: compact ? 48 : minTargetSize,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                color: selected
                    ? scheme.primary
                    : scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected ? scheme.primary : scheme.outlineVariant,
                  width: selected ? 3 : 1,
                ),
              ),
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      options[i],
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 18 * textScale,
                        fontWeight:
                            selected ? FontWeight.w800 : FontWeight.w600,
                        color:
                            selected ? scheme.onPrimary : scheme.onSurface,
                      ),
                    ),
                  ),
                  if (selected)
                    Icon(Icons.chevron_right, color: scheme.onPrimary),
                ],
              ),
            ),
            ),
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
