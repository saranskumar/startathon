import 'package:flutter/material.dart';

import '../model/profile.dart';
import '../model/session.dart';
import '../runtime/continuous_view.dart';
import '../runtime/discrete_view.dart';
import '../runtime/output_bar.dart';
import '../runtime/task_spec.dart';
import '../runtime/text_view.dart';
import 'live_link.dart';
import 'live_store.dart';

/// Live laptop link. Renders the pushed interaction list with the existing
/// runtime surfaces — it picks `interaction.inputs[method]`, it does not
/// decide how something should be driven.
class LiveScreen extends StatefulWidget {
  const LiveScreen({
    super.key,
    required this.onRecalibrate,
    this.onOpenPreview,
    this.link,
  });

  final VoidCallback onRecalibrate;
  final VoidCallback? onOpenPreview;
  final LiveLink? link;

  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

enum _Phase { pick, fill, confirm }

class _LiveScreenState extends State<LiveScreen> {
  late final LiveLink _link = widget.link ?? LiveLink();
  late final bool _ownsLink = widget.link == null;
  final _host = TextEditingController(text: LiveStore.defaultHost);
  final _room = TextEditingController(text: LiveStore.defaultRoom);
  _Phase _phase = _Phase.pick;
  Map<String, dynamic>? _selected;
  int _epoch = 0;
  bool _sentMethod = false;

  @override
  void initState() {
    super.initState();
    _link.addListener(_onLink);
    _restore();
  }

  Future<void> _restore() async {
    final saved = await LiveStore.loadLink();
    if (!mounted) return;
    setState(() {
      _host.text = saved.host;
      _room.text = saved.room;
    });
  }

  void _onLink() {
    if (!mounted) return;
    final screen = _link.pageState?['screen'];
    if (screen != null &&
        _selected != null &&
        _selected!['_screen'] != screen) {
      _phase = _Phase.pick;
      _selected = null;
      _epoch++;
    }
    if (_link.connected && !_sentMethod) _sendMethod();
    if (_link.lastActed != null) {
      final acted = _link.lastActed!;
      AppScope.of(context).emit(InputEvent(
        kind: acted['ok'] == true ? 'SENT' : 'CANCEL',
        method: _choice().method,
        consequential: _selected?['consequential'] == true,
        text: acted['ok'] == true
            ? 'acted ${acted['id']}'
            : 'act failed: ${acted['note']}',
      ));
      _link.lastActed = null;
    }
    setState(() {});
  }

  MethodChoice _choice() =>
      chooseMethod(AppScope.of(context).profile, TaskShape.discrete);

  void _sendMethod() {
    final profile = AppScope.of(context).profile;
    final choice = chooseMethod(profile, TaskShape.discrete);
    _link.inputMethod(
      method: choice.method.name,
      arity: profile.visibleOptionCount,
      vocabulary: profile.vocabulary,
    );
    _sentMethod = true;
  }

  List<Map<String, dynamic>> get _items {
    final raw = _link.pageState?['interactions'];
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is Map) item.cast<String, dynamic>(),
    ];
  }

  Future<void> _connect() async {
    await LiveStore.saveLink(host: _host.text, room: _room.text);
    _sentMethod = false;
    await _link.connect(host: _host.text, room: _room.text);
  }

  void _pick(Map<String, dynamic> it) {
    _selected = {...it, '_screen': _link.pageState?['screen']};
    AppScope.of(context).emit(InputEvent(
      kind: 'INTENT',
      method: _choice().method,
      text: 'focus ${it['label']}',
    ));
    final shape = it['shape'] as String? ?? 'discrete';
    final options = (it['options'] as List?)?.map((e) => e.toString()).toList();
    if (it['consequential'] == true) {
      setState(() {
        _phase = _Phase.confirm;
        _epoch++;
      });
      return;
    }
    if (it['act'] == 'set' &&
        (shape == 'text' ||
            shape == 'continuous' ||
            (options != null && options.isNotEmpty))) {
      setState(() {
        _phase = _Phase.fill;
        _epoch++;
      });
      return;
    }
    _link.act(it['id'] as String);
    setState(() {
      _phase = _Phase.pick;
      _epoch++;
    });
  }

  void _confirmPay(bool yes) {
    final it = _selected;
    if (it == null) return;
    if (yes) {
      AppScope.of(context).emit(InputEvent(
        kind: 'SENT',
        method: _choice().method,
        consequential: true,
        text: 'confirm ${it['label']}',
      ));
      _link.act(it['id'] as String, confirm: true);
    } else {
      AppScope.of(context).emit(
        InputEvent(kind: 'CANCEL', text: 'confirm rejected'),
      );
    }
    setState(() {
      _phase = _Phase.pick;
      _selected = null;
      _epoch++;
    });
  }

  @override
  void dispose() {
    _link.removeListener(_onLink);
    if (_ownsLink) _link.dispose();
    _host.dispose();
    _room.dispose();
    super.dispose();
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
    if (!_link.connected) return _connectForm(context, p);
    return Column(
      children: [
        _liveRibbon(context, p),
        Expanded(
          key: ValueKey('live-$_phase-$_epoch-${_link.pageState?['screen']}'),
          child: _task(context, state, p),
        ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            state.emit(InputEvent(kind: 'CANCEL', text: 'user interrupted'));
            setState(() {
              _phase = _Phase.pick;
              _selected = null;
              _epoch++;
            });
          },
          child: Container(
            width: double.infinity,
            height: 52,
            color: Theme.of(context)
                .colorScheme
                .errorContainer
                .withValues(alpha: 0.45),
            alignment: Alignment.center,
            child: Text(
              'Stop / start this step over',
              style: TextStyle(
                fontSize: 14 * p.vision.textScale,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _liveRibbon(BuildContext context, CapabilityProfile p) {
    final scheme = Theme.of(context).colorScheme;
    final scale = p.vision.textScale;
    final title = _link.pageState?['title']?.toString() ?? 'Waiting for page';
    final choice = _choice();
    final peer = _link.pagePresent ? 'laptop live' : 'no page';
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
                Text(title,
                    style: TextStyle(
                        fontSize: 17 * scale, fontWeight: FontWeight.w700)),
                Text(
                  '${_link.room} · $peer · ${choice.method.label}',
                  style: TextStyle(
                      fontSize: 11 * scale, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (widget.onOpenPreview != null)
            IconButton(
              onPressed: widget.onOpenPreview,
              icon: const Icon(Icons.sports_esports_outlined),
              tooltip: 'Controllers',
            ),
          IconButton(
            onPressed: widget.onRecalibrate,
            icon: const Icon(Icons.tune),
            tooltip: 'Recalibrate',
          ),
        ],
      ),
    );
  }

  Widget _task(BuildContext context, AppState state, CapabilityProfile p) {
    final choice = _choice();
    void raw(String s) => state.emitRaw(s, method: choice.method);

    if (_phase == _Phase.confirm && _selected != null) {
      return DiscreteTaskView(
        profile: p,
        method: choice.method,
        options: const ['Send it', 'Go back'],
        onRaw: raw,
        onResolve: (i, _) => _confirmPay(i == 0),
      );
    }

    if (_phase == _Phase.fill && _selected != null) {
      final it = _selected!;
      final shape = it['shape'] as String? ?? 'discrete';
      if (shape == 'text') {
        final suggestions = (it['suggestions'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const <String>[];
        return TextTaskView(
          profile: p,
          method: choice.method,
          fieldLabel: it['label'] as String? ?? 'Field',
          suggestions: suggestions,
          onRaw: raw,
          onNote: (note) => state.emit(InputEvent(
            kind: 'VOICE',
            method: choice.method,
            text: note,
          )),
          onResolve: (text) {
            _link.act(it['id'] as String, value: text);
            state.emit(InputEvent(
              kind: 'INTENT',
              method: choice.method,
              text: '${it['id']} = $text',
            ));
            setState(() {
              _phase = _Phase.pick;
              _selected = null;
              _epoch++;
            });
          },
        );
      }
      if (shape == 'continuous') {
        final spec = TaskSpec(
          id: it['id'] as String,
          title: it['label'] as String? ?? 'Value',
          prompt: it['label'] as String? ?? 'Adjust',
          shape: TaskShape.continuous,
          min: (it['min'] as num?)?.toInt() ?? 1,
          max: (it['max'] as num?)?.toInt() ?? 120,
        );
        return ContinuousTaskView(
          profile: p,
          method: choice.method,
          spec: spec,
          onRaw: raw,
          onResolve: (v) {
            _link.act(it['id'] as String, value: '$v');
            state.emit(InputEvent(
              kind: 'INTENT',
              method: choice.method,
              text: '${it['id']} = $v',
            ));
            setState(() {
              _phase = _Phase.pick;
              _selected = null;
              _epoch++;
            });
          },
        );
      }
      final options =
          (it['options'] as List?)?.map((e) => e.toString()).toList() ??
              const <String>[];
      return DiscreteTaskView(
        profile: p,
        method: choice.method,
        options: options,
        onRaw: raw,
        onResolve: (i, value) {
          _link.act(it['id'] as String, value: value);
          state.emit(InputEvent(
            kind: 'INTENT',
            method: choice.method,
            text: '${it['id']} = $value',
          ));
          setState(() {
            _phase = _Phase.pick;
            _selected = null;
            _epoch++;
          });
        },
      );
    }

    final items = _items;
    if (items.isEmpty) {
      return Center(
        child: Text(
          _link.pagePresent
              ? 'Page is live, waiting for a screen.'
              : 'Connected. Open rail.html on the laptop.',
          textAlign: TextAlign.center,
        ),
      );
    }
    return DiscreteTaskView(
      profile: p,
      method: choice.method,
      options: [
        for (final it in items) it['label']?.toString() ?? it['id'].toString()
      ],
      onRaw: raw,
      onHighlight: (i, _) {
        if (i < 0 || i >= items.length) return;
        _link.focus(items[i]['id'] as String);
      },
      onResolve: (i, _) => _pick(items[i]),
    );
  }

  Widget _connectForm(BuildContext context, CapabilityProfile p) {
    final scheme = Theme.of(context).colorScheme;
    final scale = p.vision.textScale;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        children: [
          Text('Connect to laptop',
              style: TextStyle(
                  fontSize: 22 * scale, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(
            'Same room code as the RailLink overlay. Local demo uses the '
            'relay on port 7777. A hosted mock needs wss:// — plain ws:// '
            'is blocked on https pages.',
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              height: 1.35,
              fontSize: 13 * scale,
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _host,
            decoration: const InputDecoration(
              labelText: 'Relay host',
              hintText: '127.0.0.1:7777',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _room,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Room',
              hintText: 'DEMO',
              border: OutlineInputBorder(),
            ),
          ),
          if (_link.lastError != null) ...[
            const SizedBox(height: 12),
            Text(_link.lastError!,
                style: TextStyle(color: scheme.error, fontSize: 12 * scale)),
          ],
          const SizedBox(height: 20),
          SizedBox(
            height: 64,
            child: FilledButton(
              onPressed: _connect,
              child: Text('Join ${_room.text.isEmpty ? 'DEMO' : _room.text}'),
            ),
          ),
        ],
      ),
    );
  }
}
