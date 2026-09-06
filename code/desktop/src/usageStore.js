// Persistent per-feature selection counts — the "how often has this been
// picked before" signal that boosts domTreeEngine's ranking. Deliberately
// a plain frequency count, not an LLM call or a trained model: cheap,
// explainable, and it's the free labeled data docs/tech/research/08
// §3 flags as the natural input to a real ML ranker later, if one is
// ever built.

import fs from 'node:fs';
import path from 'node:path';

const DEFAULT_PATH = path.resolve(import.meta.dirname, '../data/usage-counts.json');

export function loadUsageCounts(filePath = DEFAULT_PATH) {
  try {
    return JSON.parse(fs.readFileSync(filePath, 'utf8'));
  } catch {
    return {};
  }
}

export function recordSelection(signature, filePath = DEFAULT_PATH) {
  const counts = loadUsageCounts(filePath);
  counts[signature] = (counts[signature] ?? 0) + 1;
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  fs.writeFileSync(filePath, JSON.stringify(counts, null, 2));
  return counts[signature];
}
