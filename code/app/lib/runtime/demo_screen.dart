import 'package:flutter/material.dart';

import '../model/profile.dart';
import '../model/session.dart';
import 'continuous_view.dart';
import 'discrete_view.dart';
import 'output_bar.dart';
import 'pointing_view.dart';
import 'task_spec.dart';
import 'text_view.dart';

/// The runtime: a short chain of tasks, each rendered with whichever input
/// method this user's profile resolves to.
///
/// Nothing here talks to an agent or a browser. Each resolved task is logged as
/// an intent, and the final review is the one consequential action -- gated by
/// an explicit confirmation, per 2.4.
class DemoScreen extends StatefulWidget {
  const DemoScreen({super.key, required this.onRecalibrate});

  final VoidCallback onRecalibrate;

  @override
  State<DemoScreen> createState() => _DemoScreenState();
}

class _DemoScreenState extends State<DemoScreen> {
  int _taskIndex = 0;
  bool _review = false;
  bool _sent = false;
  final Map<String, String> _collected = {};

  /// Bumped whenever a task should restart from scratch, so the interrupt
  /// really does reset the view's internal state rather than just its label.
  int _epoch = 0;

  TaskSpec get _spec => DemoTasks.all[_taskIndex];

  void _resolveTask(AppState state, String value, TouchMethod method) {
    _collected[_spec.title] = value;
    state.emit(InputEvent(
      kind: 'INTENT',
      method: method,
      text: '${_spec.id} = $value',
    ));
    setState(() {
      if (_taskIndex < DemoTasks.all.length - 1) {
        _taskIndex++;
      } else {
        _review = true;
      }
      _epoch++;
    });
  }

  void _interrupt(AppState state) {
    state.emit(InputEvent(kind: "CANCEL", text: "user interrupted"));
    setState(() => _epoch++);
  }

  void _restart(AppState state) {
    state.clearLog();
    setState(() {
      _taskIndex = 0;
      _review = false;
      _sent = false;
      _collected.clear();
      _epoch++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final profile = state.profile;
    final strip = OutputStrip(
      state: state,
      atBottom: profile.outputAtBottom,
      onOpenLog: () => EventLogSheet.show(context, state),
    );

    return Scaffold(
      body: Column(
        children: [
          if (!profile.outputAtBottom) strip,
          Expanded(child: _body(context, state, profile)),
          if (profile.outputAtBottom) strip,
        ],
      ),
    );
  }

  Widget _body(BuildContext context, AppState state, CapabilityProfile p) {
    if (_sent) return _doneView(context, state, p);
    if (_review) return _reviewView(context, state, p);

    final choice = chooseMethod(p, _spec.shape);
    return Column(
      children: [
        _Ribbon(
          profile: p,
          spec: _spec,
          choice: choice,
          onRecalibrate: widget.onRecalibrate,
        ),
        Expanded(
          key: ValueKey('${_spec.id}-$_epoch-${choice.method}'),
          child: _taskView(state, p, choice),
        ),
        _InterruptBar(
          label: 'Stop / start this step over',
          textScale: p.vision.textScale,
          onPressed: () => _interrupt(state),
        ),
      ],
    );
  }

  Widget _taskView(AppState state, CapabilityProfile p, MethodChoice choice) {
    void raw(String s) => state.emitRaw(s, method: choice.method);

    switch (_spec.shape) {
      case TaskShape.discrete:
        return DiscreteTaskView(
          profile: p,
          method: choice.method,
          options: _spec.options,
          onRaw: raw,
          onResolve: (_, value) => _resolveTask(state, value, choice.method),
        );
      case TaskShape.continuous:
        return ContinuousTaskView(
          profile: p,
          method: choice.method,
          spec: _spec,
          onRaw: raw,
          onResolve: (v) =>
              _resolveTask(state, '$v ${_spec.unit}', choice.method),
        );
      case TaskShape.pointing:
        return PointingTaskView(
          profile: p,
          method: choice.method,
          goal: const Offset(0.72, 0.34),
          onRaw: raw,
          // The agent only helps where the fallback is indirect (2.4) -- with a
          // trackpad the user is specifying the point themselves.
          agentAssist: choice.method != TouchMethod.trackpad,
          onResolve: (point, err) {
            state.emit(InputEvent(
              kind: 'INTENT',
              method: choice.method,
              text: 'marker at ${point.dx.toStringAsFixed(2)}, '
                  '${point.dy.toStringAsFixed(2)} '
                  '(${(err * 100).round()}% off target)',
            ));
            _resolveTask(
              state,
              '${point.dx.toStringAsFixed(2)}, ${point.dy.toStringAsFixed(2)}',
              choice.method,
            );
          },
        );
      case TaskShape.text:
        return TextTaskView(
          profile: p,
          method: choice.method,
          fieldLabel: _spec.fieldLabel,
          onRaw: raw,
          onNote: (note) => state.emit(InputEvent(
            kind: 'VOICE',
            method: choice.method,
            text: note,
          )),
          onResolve: (text) => _resolveTask(state, '"$text"', choice.method),
        );
    }
  }

  /// The only consequential action in the whole flow, so the only one behind a
  /// confirmation -- and the confirmation is driven by the same method the user
  /// has been using, not by a small dialog button.
  Widget _reviewView(BuildContext context, AppState state, CapabilityProfile p) {
    final choice = chooseMethod(p, TaskShape.discrete);
    final scheme = Theme.of(context).colorScheme;
    final scale = p.vision.textScale;

    return Column(
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: scheme.errorContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('About to send to the computer',
                  style: TextStyle(
                    fontSize: 18 * scale,
                    fontWeight: FontWeight.w800,
                  )),
              const SizedBox(height: 8),
              for (final e in _collected.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('${e.key}: ${e.value}',
                      style: TextStyle(fontSize: 14 * scale)),
                ),
            ],
          ),
        ),
        Expanded(
          child: DiscreteTaskView(
            key: ValueKey('review-$_epoch'),
            profile: p,
            method: choice.method,
            options: const ['Send it', 'Go back and change something'],
            onRaw: (s) => state.emitRaw(s, method: choice.method),
            onResolve: (i, _) {
              if (i == 0) {
                state.emit(InputEvent(
                  kind: 'SENT',
                  method: choice.method,
                  consequential: true,
                  text: 'submit ${_collected.length} field(s) to the agent',
                ));
                setState(() => _sent = true);
              } else {
                state.emit(
                    InputEvent(kind: "CANCEL", text: "review rejected"));
                setState(() {
                  _review = false;
                  _taskIndex = 0;
                  _epoch++;
                });
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _doneView(BuildContext context, AppState state, CapabilityProfile p) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 72, color: scheme.primary),
            const SizedBox(height: 16),
            Text('Sent',
                style: TextStyle(
                    fontSize: 30 * p.vision.textScale,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              'In the full system this is where the agent takes over and fills '
              'the real form. Here it stops at the log.',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 28),
            SizedBox(
              height: 64,
              width: double.infinity,
              child: FilledButton(
                onPressed: () => _restart(state),
                child: const Text('Run it again'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 56,
              width: double.infinity,
              child: OutlinedButton(
                onPressed: widget.onRecalibrate,
                child: const Text('Recalibrate'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The line that says what the system just decided and why. Kept on screen
/// because "the same task, a different interface" is the claim being made, and
/// it is only convincing if the reason is visible.
class _Ribbon extends StatelessWidget {
  const _Ribbon({
    required this.profile,
    required this.spec,
    required this.choice,
    required this.onRecalibrate,
  });

  final CapabilityProfile profile;
  final TaskSpec spec;
  final MethodChoice choice;
  final VoidCallback onRecalibrate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final scale = profile.vision.textScale;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  spec.prompt,
                  style: TextStyle(
                    fontSize: 17 * scale,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: choice.isFallback
                            ? scheme.tertiaryContainer
                            : scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${choice.method.label}'
                        '${choice.isFallback ? " (fallback)" : ""}',
                        style: TextStyle(
                          fontSize: 10 * scale,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        patternFor(spec.shape, choice.method),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11 * scale,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRecalibrate,
            icon: const Icon(Icons.tune),
            tooltip: 'Profile and calibration',
          ),
        ],
      ),
    );
  }
}

/// Hard requirement from 05-scope item 6: an interrupt that is always present.
/// It is a full-width bar rather than a corner icon so it stays hittable for a
/// user whose targeting is poor -- the one most likely to need it.
class _InterruptBar extends StatelessWidget {
  const _InterruptBar({
    required this.label,
    required this.onPressed,
    required this.textScale,
  });

  final String label;
  final VoidCallback onPressed;
  final double textScale;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: Container(
        width: double.infinity,
        height: 52,
        color: scheme.errorContainer.withValues(alpha: 0.45),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14 * textScale,
            fontWeight: FontWeight.w700,
            color: scheme.onErrorContainer,
          ),
        ),
      ),
    );
  }
}
