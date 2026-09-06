import 'package:flutter_test/flutter_test.dart';
import 'package:startathon/live/live_link.dart';
import 'package:startathon/model/profile.dart';
import 'package:startathon/model/session.dart';

void main() {
  test('socketUrl normalizes host and room', () {
    expect(
      LiveLink.socketUrl(host: '127.0.0.1:7777', room: 'demo'),
      'ws://127.0.0.1:7777/ws?room=DEMO&role=phone',
    );
    expect(
      LiveLink.socketUrl(host: '10.0.0.5:7777', room: 'demo'),
      'ws://10.0.0.5:7777/ws?room=DEMO&role=phone',
    );
    expect(
      LiveLink.socketUrl(
        host: 'https://kai-relay.example.workers.dev',
        room: 'stage',
      ),
      'wss://kai-relay.example.workers.dev/ws?room=STAGE&role=phone',
    );
  });

  test('calibrated preset round-trips through JSON', () {
    final original = ProfilePresets.calibrated;
    final copy = CapabilityProfile.fromJson(original.toJson());
    expect(copy.label, original.label);
    expect(copy.bestMethod, original.bestMethod);
    expect(copy.reachableCells, original.reachableCells);
    expect(copy.clarity, original.clarity);
    expect(copy.minTargetSize, original.minTargetSize);
  });

  test('trackpad/switch preset round-trips through JSON', () {
    final original = ProfilePresets.profileTrackpadSwitch;
    final copy = CapabilityProfile.fromJson(original.toJson());
    expect(copy.label, original.label);
    expect(copy.bestMethod, TouchMethod.trackpad);
    expect(copy.clarity, SpeechClarity.none);
    expect(copy.reachableCells, original.reachableCells);
    expect(copy.minTargetSize, original.minTargetSize);
    expect(copy.visualField, VisualField.full);
    // LiveScreen always asks chooseMethod(..., discrete) for the handshake.
    expect(
      copy.bestMethod,
      original.bestMethod,
    );
  });
}
