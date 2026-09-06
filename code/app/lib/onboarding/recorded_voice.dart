import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

/// Fixed onboarding scripts, recorded-voice shaped.
///
/// Research 11 §5: recorded human voice is worth it for this small, said-once
/// content. Dynamic narration stays TTS later. There is no audio package in
/// this build, so playback is the timed human transcript plus a screen-reader
/// announcement — the same words a recording would say. Drop a WAV at
/// [OnboardingClip.assetPath] later; the catalog and locale key stay.
class OnboardingClip {
  const OnboardingClip({
    required this.id,
    required this.locale,
    required this.transcript,
    required this.duration,
    this.assetPath,
  });

  final String id;
  final String locale;
  final String transcript;
  final Duration duration;

  /// Optional future file, e.g. `assets/audio/en/welcome.wav`.
  final String? assetPath;
}

abstract final class OnboardingCatalog {
  static const locales = ['en', 'ml'];

  static const clips = <OnboardingClip>[
    OnboardingClip(
      id: 'welcome',
      locale: 'en',
      duration: Duration(seconds: 8),
      transcript:
          'Welcome. Tap or hold the large block at the bottom to set up how '
          'you control things. There is no pass or fail. If someone is '
          'helping you, they can use the smaller button at the top.',
    ),
    OnboardingClip(
      id: 'welcome',
      locale: 'ml',
      duration: Duration(seconds: 9),
      transcript:
          'സ്വാഗതം. താഴെയുള്ള വലിയ ബ്ലോക്ക് തട്ടിയാലോ പിടിച്ചാലോ സജ്ജീകരണം '
          'തുടങ്ങും. പരാജയമില്ല. സഹായിക്കുന്ന ആളാണെങ്കിൽ മുകളിലുള്ള ചെറിയ '
          'ബട്ടൺ മതി.',
    ),
    OnboardingClip(
      id: 'training',
      locale: 'en',
      duration: Duration(seconds: 9),
      transcript:
          'A helper will guide your hand through one motion at a time. '
          'Start with their hand under yours. When you can do the motion '
          'from the words alone, we measure how precisely you do it.',
    ),
    OnboardingClip(
      id: 'training',
      locale: 'ml',
      duration: Duration(seconds: 9),
      transcript:
          'സഹായി ഒരു ചലനം വീതം കാണിച്ചുതരും. '
          'ആദ്യം കൈ കീഴില്‍ വെച്ച് നീക്കുക. '
          'വാക്ക് മാത്രം കേട്ട് ചെയ്യുമ്പോള്‍ കൃത്യത അളക്കും.',
    ),
  ];

  static OnboardingClip? find(String id, String locale) {
    OnboardingClip? fallback;
    for (final c in clips) {
      if (c.id != id) continue;
      if (c.locale == locale) return c;
      fallback ??= c;
    }
    return fallback;
  }
}

/// Plays a catalog clip: announces it, then walks the transcript on a timer.
class RecordedNarration extends StatefulWidget {
  const RecordedNarration({
    super.key,
    required this.clipId,
    required this.locale,
    this.autoplay = false,
  });

  final String clipId;
  final String locale;
  final bool autoplay;

  @override
  State<RecordedNarration> createState() => _RecordedNarrationState();
}

class _RecordedNarrationState extends State<RecordedNarration>
    with SingleTickerProviderStateMixin {
  AnimationController? _clock;
  bool _playing = false;

  OnboardingClip? get _clip =>
      OnboardingCatalog.find(widget.clipId, widget.locale);

  @override
  void initState() {
    super.initState();
    if (widget.autoplay) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _play();
      });
    }
  }

  @override
  void dispose() {
    _clock?.dispose();
    super.dispose();
  }

  Future<void> _play() async {
    final clip = _clip;
    if (clip == null) return;
    _clock?.dispose();
    final clock = AnimationController(vsync: this, duration: clip.duration);
    _clock = clock;
    setState(() => _playing = true);
    if (mounted) {
      SemanticsService.sendAnnouncement(
        View.of(context),
        clip.transcript,
        Directionality.maybeOf(context) ?? TextDirection.ltr,
      );
    }
    clock.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _playing = false);
      }
    });
    await clock.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final clip = _clip;
    if (clip == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      label: _playing ? clip.transcript : 'Recorded welcome, play',
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.record_voice_over, size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _playing ? 'Playing recorded voice' : 'Recorded welcome',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                      color: scheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  widget.locale.toUpperCase(),
                  style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              clip.transcript,
              maxLines: _playing ? 8 : 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(height: 1.35, fontSize: 14),
            ),
            const SizedBox(height: 10),
            if (_playing && _clock != null)
              AnimatedBuilder(
                animation: _clock!,
                builder: (context, _) =>
                    LinearProgressIndicator(value: _clock!.value),
              )
            else
              SizedBox(
                height: 48,
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _play,
                  child: const Text(
                    'Play recording',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
