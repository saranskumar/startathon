import 'package:flutter/material.dart';

import '../model/profile.dart';
import '../model/session.dart';

/// The output region.
///
/// Nothing is connected to the laptop yet, so this strip is where every
/// resolved intent goes instead of onto a wire. It is deliberately placed in
/// the screen row the profile says the user cannot comfortably reach
/// ([CapabilityProfile.outputRow]) -- that area is dead space for input, so it
/// is the honest place to spend on output. One line, always the same shape:
/// the live signal on the left, the last committed intent on the right.
class OutputStrip extends StatelessWidget {
  const OutputStrip({
    super.key,
    required this.state,
    required this.onOpenLog,
    this.atBottom = false,
  });

  final AppState state;
  final VoidCallback onOpenLog;
  final bool atBottom;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final latest = state.latest;
    final raw = state.raw;

    return Material(
      color: scheme.inverseSurface,
      child: InkWell(
        onTap: onOpenLog,
        child: SafeArea(
          top: !atBottom,
          bottom: atBottom,
          child: SizedBox(
            height: 46,
            child: Row(
              children: [
                const SizedBox(width: 12),
                Icon(Icons.laptop_mac,
                    size: 16,
                    color: scheme.onInverseSurface.withValues(alpha: 0.7)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    latest?.line ?? 'waiting for input',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: scheme.onInverseSurface,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (raw != null)
                  Flexible(
                    child: Text(
                      raw.line,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: scheme.onInverseSurface.withValues(alpha: 0.6),
                        fontSize: 11,
                      ),
                    ),
                  ),
                IconButton(
                  onPressed: onOpenLog,
                  icon: Icon(Icons.expand_more,
                      color: scheme.onInverseSurface, size: 20),
                  tooltip: 'Open the log',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The full history, for when the one-line strip is not enough -- pitch
/// rehearsals, debugging a mapping, or showing a judge what the phone actually
/// decided and when.
class EventLogSheet extends StatelessWidget {
  const EventLogSheet({super.key, required this.state});

  final AppState state;

  static void show(BuildContext context, AppState state) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.8,
        child: EventLogSheet(state: state),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final events = state.events;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'What would go to the laptop',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              TextButton(
                onPressed: state.clearLog,
                child: const Text('Clear'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text(
            state.profile.summary,
            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: events.isEmpty
              ? const Center(child: Text('Nothing yet.'))
              : ListView.separated(
                  itemCount: events.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final e = events[i];
                    return ListTile(
                      dense: true,
                      leading: _KindChip(kind: e.kind, urgent: e.consequential),
                      title: Text(
                        e.text,
                        style: const TextStyle(
                            fontSize: 13),
                      ),
                      subtitle: Text(
                        '${e.stamp}'
                        '${e.method == null ? "" : "  via ${e.method!.label}"}',
                        style: TextStyle(
                            fontSize: 11, color: scheme.onSurfaceVariant),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _KindChip extends StatelessWidget {
  const _KindChip({required this.kind, required this.urgent});

  final String kind;
  final bool urgent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = urgent ? scheme.error : scheme.primary;
    return Container(
      width: 62,
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Text(
        kind,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          color: color,
        ),
      ),
    );
  }
}
