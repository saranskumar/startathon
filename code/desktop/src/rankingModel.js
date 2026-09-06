// A single, small, trainable ranking model -- logistic regression over
// structural features, trained from real selection history. Not an LLM, not
// a general-purpose model: one linear model, ~11 numbers, that learns which
// KIND of feature this user (or this deployment) tends to pick, from the
// exact same signals domTreeEngine's heuristic already computes.
//
// Every act() call in browserSession.js is a labeled example for free: the
// feature actually picked is a positive, the other candidates shown in that
// same scan are negatives -- the standard pointwise learning-to-rank setup,
// with zero extra instrumentation. See docs/tech/research/08 §3, which flags
// exactly this ("a small classifier... every candidate/rejected node from
// tier-1 heuristics is a free labeled example") as the natural v2 once real
// usage data exists.
//
// Deterministic, offline, no network call, no package beyond Node's fs --
// same constraints as the rest of the desktop backend.

import fs from 'node:fs';
import path from 'node:path';

export const FEATURE_NAMES = [
  'isLandmark', 'isHeading', 'headingLevelNorm', 'isInteractive', 'isAmbiguous',
  'hasName', 'nameLengthNorm', 'linkDensity', 'hidden', 'offscreen', 'disabled',
];

function clamp(v, lo, hi) { return Math.min(Math.max(v, lo), hi); }

/**
 * The same structural signals domTreeEngine.js already computes per node,
 * read back off the ranked feature object (not recomputed) so the model
 * trains on exactly what the heuristic saw.
 */
export function extractFeatureVector(feature) {
  const level = feature.level ?? 0;
  const nameLen = feature.name ? feature.name.length : 0;
  return [
    feature.isLandmark ? 1 : 0,
    feature.isHeading ? 1 : 0,
    level ? clamp(level, 1, 6) / 6 : 0,
    feature.isInteractive ? 1 : 0,
    feature.isAmbiguous ? 1 : 0,
    feature.name ? 1 : 0,
    Math.min(nameLen / 40, 1),
    clamp(feature.linkDensity ?? 0, 0, 1),
    feature.hidden ? 1 : 0,
    feature.offscreen ? 1 : 0,
    feature.disabled ? 1 : 0,
  ];
}

function sigmoid(z) {
  if (z >= 0) { const e = Math.exp(-z); return 1 / (1 + e); }
  const e = Math.exp(z);
  return e / (1 + e);
}

/** Plain logistic regression: predict(), one trainStep(), and a batch train(). */
export class LogisticRanker {
  constructor(featureCount = FEATURE_NAMES.length) {
    this.weights = new Array(featureCount).fill(0);
    this.bias = 0;
  }

  predict(features) {
    let z = this.bias;
    for (let i = 0; i < features.length; i++) z += features[i] * this.weights[i];
    return sigmoid(z);
  }

  trainStep(features, label, lr) {
    const p = this.predict(features);
    const error = label - p;
    for (let i = 0; i < features.length; i++) this.weights[i] += lr * error * features[i];
    this.bias += lr * error;
  }

  /** Full-batch gradient descent over every stored example, `epochs` passes. */
  train(examples, { epochs = 200, lr = 0.1, l2 = 0.001 } = {}) {
    for (let e = 0; e < epochs; e++) {
      for (const { features, label } of examples) this.trainStep(features, label, lr);
      // Light L2 shrinkage between epochs -- keeps weights from running away
      // on a small, noisy example set.
      for (let i = 0; i < this.weights.length; i++) this.weights[i] *= (1 - l2);
    }
    return this;
  }

  toJSON() { return { weights: this.weights, bias: this.bias }; }

  static fromJSON(json) {
    const model = new LogisticRanker(json.weights.length);
    model.weights = [...json.weights];
    model.bias = json.bias;
    return model;
  }
}

const DEFAULT_EXAMPLES_PATH = path.resolve(import.meta.dirname, '../data/ranking-examples.jsonl');
const DEFAULT_MODEL_PATH = path.resolve(import.meta.dirname, '../data/ranking-model.json');
const MAX_NEGATIVES_PER_SELECTION = 10;

/**
 * One selection = one training batch: the picked feature is a positive
 * example, up to [MAX_NEGATIVES_PER_SELECTION] of the other candidates shown
 * in the same scan are negatives. Appended as JSONL so recording never has
 * to read the whole history back in.
 */
export function recordRankingExample(picked, candidates, examplesPath = DEFAULT_EXAMPLES_PATH) {
  const lines = [];
  lines.push(JSON.stringify({ features: extractFeatureVector(picked), label: 1 }));
  const others = candidates.filter(c => c !== picked).slice(0, MAX_NEGATIVES_PER_SELECTION);
  for (const c of others) {
    lines.push(JSON.stringify({ features: extractFeatureVector(c), label: 0 }));
  }
  fs.mkdirSync(path.dirname(examplesPath), { recursive: true });
  fs.appendFileSync(examplesPath, lines.join('\n') + '\n');
  return lines.length;
}

export function loadRankingExamples(examplesPath = DEFAULT_EXAMPLES_PATH) {
  let text;
  try {
    text = fs.readFileSync(examplesPath, 'utf8');
  } catch {
    return [];
  }
  return text.split('\n').filter(Boolean).map(line => JSON.parse(line));
}

/**
 * Retrain from scratch over every recorded example and persist the result.
 * Cheap enough (a few hundred examples, ~11 weights) to just run fresh each
 * time rather than maintaining incremental state on disk.
 */
export function trainAndSaveRankingModel(options = {}) {
  const examplesPath = options.examplesPath ?? DEFAULT_EXAMPLES_PATH;
  const modelPath = options.modelPath ?? DEFAULT_MODEL_PATH;
  const examples = loadRankingExamples(examplesPath);
  const model = new LogisticRanker().train(examples, options);
  fs.mkdirSync(path.dirname(modelPath), { recursive: true });
  fs.writeFileSync(modelPath, JSON.stringify(model.toJSON(), null, 2));
  return { model, exampleCount: examples.length };
}

/** Null if nothing has been trained yet -- callers treat that as "no model". */
export function loadRankingModel(modelPath = DEFAULT_MODEL_PATH) {
  try {
    return LogisticRanker.fromJSON(JSON.parse(fs.readFileSync(modelPath, 'utf8')));
  } catch {
    return null;
  }
}

/** How many recorded examples exist -- used to decide whether it's worth
 * retraining yet, without loading and parsing the whole file. */
export function countRankingExamples(examplesPath = DEFAULT_EXAMPLES_PATH) {
  try {
    const text = fs.readFileSync(examplesPath, 'utf8');
    return text.split('\n').filter(Boolean).length;
  } catch {
    return 0;
  }
}
