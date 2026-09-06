import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Phone-side client of the demo relay (`role=phone`).
class LiveLink extends ChangeNotifier {
  WebSocketChannel? _ch;
  StreamSubscription<dynamic>? _sub;

  Map<String, dynamic>? pageState;
  Map<String, dynamic>? lastActed;
  bool connected = false;
  bool pagePresent = false;
  int phones = 0;
  String? lastError;
  String room = 'DEMO';

  static String socketUrl({required String host, required String room}) {
    var h = host.trim();
    if (h.endsWith('/')) h = h.substring(0, h.length - 1);
    if (h.startsWith('http://')) h = 'ws://${h.substring(7)}';
    if (h.startsWith('https://')) h = 'wss://${h.substring(8)}';
    if (!h.startsWith('ws://') && !h.startsWith('wss://')) {
      final secure = h.contains('workers.dev') ||
          h.contains('fly.dev') ||
          h.contains('onrender.com') ||
          h.contains('railway.app');
      h = '${secure ? 'wss' : 'ws'}://$h';
    }
    final uri = Uri.parse(h);
    final path = uri.path.isEmpty || uri.path == '/' ? '/ws' : uri.path;
    return uri
        .replace(
          path: path,
          queryParameters: {'room': room.toUpperCase(), 'role': 'phone'},
        )
        .toString();
  }

  Future<void> connect({required String host, required String room}) async {
    await disconnect();
    this.room = room.trim().toUpperCase();
    lastError = null;
    notifyListeners();
    try {
      final url = socketUrl(host: host, room: this.room);
      final ch = WebSocketChannel.connect(Uri.parse(url));
      _ch = ch;
      _sub = ch.stream.listen(
        _onMessage,
        onError: (Object e) {
          lastError = e.toString();
          connected = false;
          notifyListeners();
        },
        onDone: () {
          connected = false;
          pagePresent = false;
          notifyListeners();
        },
      );
    } catch (e) {
      lastError = e.toString();
      connected = false;
      notifyListeners();
    }
  }

  void _onMessage(dynamic raw) {
    Map<String, dynamic> msg;
    try {
      final decoded = raw is String ? jsonDecode(raw) : raw;
      if (decoded is! Map) return;
      msg = decoded.cast<String, dynamic>();
    } catch (_) {
      return;
    }
    final type = msg['type'];
    if (type == 'joined') {
      connected = true;
      pagePresent = msg['peer'] == true;
      lastError = null;
    } else if (type == 'peer') {
      pagePresent = msg['page'] == true;
      phones = (msg['phones'] as num?)?.toInt() ?? 0;
    } else if (type == 'state') {
      pageState = msg;
    } else if (type == 'acted') {
      lastActed = msg;
    }
    notifyListeners();
  }

  void send(Map<String, dynamic> msg) {
    final ch = _ch;
    if (ch == null || !connected) return;
    ch.sink.add(jsonEncode(msg));
  }

  void focus(String id, {int? group}) {
    send({
      'type': 'focus',
      'id': id,
      'group': ?group,
    });
  }

  void act(String id, {String? value, bool confirm = false}) {
    send({
      'type': 'act',
      'id': id,
      'value': ?value,
      if (confirm) 'confirm': true,
    });
  }

  void inputMethod({
    required String method,
    required int arity,
    required List<String> vocabulary,
  }) {
    send({
      'type': 'inputMethod',
      'method': method,
      'arity': arity < 2 ? 2 : arity,
      'vocabulary': vocabulary,
    });
  }

  Future<void> disconnect() async {
    await _sub?.cancel();
    _sub = null;
    try {
      await _ch?.sink.close();
    } catch (_) {}
    _ch = null;
    connected = false;
    pagePresent = false;
    pageState = null;
    lastActed = null;
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(disconnect());
    super.dispose();
  }
}
