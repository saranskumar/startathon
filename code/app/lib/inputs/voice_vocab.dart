/// Sentence probes and the mapping from a personal vocabulary onto menus.
///
/// Issue #3: people who can say *some* words, not all. Calibration walks
/// natural sentences (not a word list), keeps the words that landed, then
/// maps that list either onto option labels (small N) or onto next / previous
/// / select (large N).
library;

class VoiceProbe {
  const VoiceProbe({
    required this.sentence,
    required this.target,
    required this.difficulty,
  });

  final String sentence;
  final String target;

  /// 1 = easy / short, 3 = harder / multisyllabic.
  final int difficulty;
}

/// 8 sentences, mixed difficulty. The spoken line is the whole sentence;
/// only [VoiceProbe.target] is scored into the vocabulary.
const kVoiceProbes = <VoiceProbe>[
  VoiceProbe(sentence: 'Yes, I am ready.', target: 'yes', difficulty: 1),
  VoiceProbe(sentence: 'No, not that one.', target: 'no', difficulty: 1),
  VoiceProbe(sentence: "Let's go to the gym.", target: 'go', difficulty: 1),
  VoiceProbe(sentence: 'Water, please.', target: 'water', difficulty: 1),
  VoiceProbe(sentence: 'I want to eat that.', target: 'eat', difficulty: 2),
  VoiceProbe(sentence: 'Please wait for me.', target: 'wait', difficulty: 2),
  VoiceProbe(sentence: 'Stop at the yellow gate.', target: 'yellow', difficulty: 2),
  VoiceProbe(sentence: 'Call my sister later.', target: 'sister', difficulty: 3),
];

abstract final class VocabMapping {
  static const next = 'next';
  static const previous = 'previous';
  static const select = 'select';

  /// Direct mapping when the menu is no bigger than the vocabulary;
  /// otherwise the first three words become next / previous / select.
  static Map<String, String> mapWords({
    required List<String> vocabulary,
    required List<String> options,
  }) {
    if (vocabulary.isEmpty) return const {};
    final words = [
      for (final w in vocabulary) w.trim().toLowerCase(),
    ].where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return const {};

    if (options.length <= words.length) {
      return {
        for (var i = 0; i < options.length; i++) words[i]: options[i],
      };
    }

    final out = <String, String>{words[0]: next};
    if (words.length > 1) out[words[1]] = previous;
    if (words.length > 2) out[words[2]] = select;
    return out;
  }

  /// First vocabulary word that appears in [transcript], or null.
  static String? resolve(String transcript, Map<String, String> mapping) {
    if (transcript.trim().isEmpty || mapping.isEmpty) return null;
    final t = ' ${transcript.toLowerCase()} ';
    for (final entry in mapping.entries) {
      if (t.contains(' ${entry.key} ')) return entry.value;
    }
    // Also accept a bare word with no spaces (single-word utterance).
    final bare = transcript.trim().toLowerCase();
    return mapping[bare];
  }
}
