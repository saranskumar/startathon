import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../model/profile.dart';

/// Host / room / last live calibration. A missing plugin (widget tests
/// without a mock) is treated as empty — the committed Calibrated preset
/// still comes from [ProfilePresets.calibrated].
class LiveStore {
  static const _hostKey = 'kai.relayHost';
  static const _roomKey = 'kai.relayRoom';
  static const _profileKey = 'kai.calibratedProfile';

  static const defaultHost = '127.0.0.1:7777';
  static const defaultRoom = 'DEMO';

  static Future<SharedPreferences?> _prefs() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
  }

  static Future<({String host, String room})> loadLink() async {
    final p = await _prefs();
    return (
      host: p?.getString(_hostKey) ?? defaultHost,
      room: p?.getString(_roomKey) ?? defaultRoom,
    );
  }

  static Future<void> saveLink({
    required String host,
    required String room,
  }) async {
    final p = await _prefs();
    await p?.setString(_hostKey, host);
    await p?.setString(_roomKey, room);
  }

  static Future<CapabilityProfile?> loadProfile() async {
    final p = await _prefs();
    final raw = p?.getString(_profileKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return CapabilityProfile.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveProfile(CapabilityProfile profile) async {
    final p = await _prefs();
    await p?.setString(
      _profileKey,
      jsonEncode(profile.copyWith(label: 'Calibrated (default)').toJson()),
    );
  }
}
