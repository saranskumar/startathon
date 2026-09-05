import 'dart:async';

/// Key-repeat behaviour for held inputs: fire once immediately, pause, then
/// repeat. Used by the joystick and the switch so "hold to keep going" feels
/// the same wherever it appears.
class HoldRepeater {
  HoldRepeater(
    this.onTick, {
    this.initialDelay = const Duration(milliseconds: 420),
    this.interval = const Duration(milliseconds: 240),
  });

  final void Function() onTick;
  final Duration initialDelay;
  final Duration interval;

  Timer? _timer;
  bool get running => _timer != null;

  void start() {
    stop();
    onTick();
    _timer = Timer(initialDelay, () {
      _timer = Timer.periodic(interval, (_) => onTick());
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
