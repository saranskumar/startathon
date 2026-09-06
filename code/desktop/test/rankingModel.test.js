// node --test test/

import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {
  LogisticRanker,
  extractFeatureVector,
  recordRankingExample,
  loadRankingExamples,
  trainAndSaveRankingModel,
  loadRankingModel,
  countRankingExamples,
  FEATURE_NAMES,
} from '../src/rankingModel.js';
import { buildAuxiliaryTree } from '../src/domTreeEngine.js';

function tmpFile(name) {
  return path.join(fs.mkdtempSync(path.join(os.tmpdir(), 'ranking-test-')), name);
}

test('extractFeatureVector has one entry per named feature', () => {
  const vec = extractFeatureVector({ isInteractive: true, name: 'Submit', level: 2 });
  assert.equal(vec.length, FEATURE_NAMES.length);
});

test('LogisticRanker learns a linearly separable toy pattern', () => {
  // "interactive" (index 3) predicts the label perfectly; everything else is
  // noise. A model that actually learns should end up confident either way.
  const examples = [];
  for (let i = 0; i < 40; i++) {
    const interactive = i % 2 === 0;
    const vec = new Array(FEATURE_NAMES.length).fill(0);
    vec[3] = interactive ? 1 : 0;
    vec[6] = Math.random(); // noise feature, uncorrelated with the label
    examples.push({ features: vec, label: interactive ? 1 : 0 });
  }
  const model = new LogisticRanker().train(examples, { epochs: 300, lr: 0.3, l2: 0 });

  const interactiveVec = new Array(FEATURE_NAMES.length).fill(0);
  interactiveVec[3] = 1;
  const notInteractiveVec = new Array(FEATURE_NAMES.length).fill(0);

  assert.ok(model.predict(interactiveVec) > 0.8, 'should confidently predict the positive pattern');
  assert.ok(model.predict(notInteractiveVec) < 0.2, 'should confidently predict the negative pattern');
});

test('recordRankingExample writes one positive and N negatives, capped', () => {
  const examplesPath = tmpFile('examples.jsonl');
  const picked = { isInteractive: true, name: 'Submit' };
  const candidates = [picked, ...Array.from({ length: 15 }, (_, i) => ({ name: 'opt' + i }))];

  const written = recordRankingExample(picked, candidates, examplesPath);
  const loaded = loadRankingExamples(examplesPath);

  assert.equal(written, loaded.length);
  assert.ok(written <= 11, 'capped at 1 positive + 10 negatives');
  assert.equal(loaded.filter(e => e.label === 1).length, 1);
  assert.equal(loaded.filter(e => e.label === 0).length, written - 1);
});

test('trainAndSaveRankingModel round-trips through disk', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'ranking-test-'));
  const examplesPath = path.join(dir, 'examples.jsonl');
  const modelPath = path.join(dir, 'model.json');

  // The picked feature must be the *same reference* as one of the
  // candidates -- exactly how browserSession.js calls this (findFeature()
  // returns a reference into the same array act() passes as candidates).
  const picked = { isInteractive: true, name: 'Submit' };
  recordRankingExample(picked, [picked, { isInteractive: false, name: 'text' }], examplesPath);

  assert.equal(loadRankingModel(modelPath), null, 'nothing trained yet');
  const { exampleCount } = trainAndSaveRankingModel({ examplesPath, modelPath, epochs: 20 });
  assert.equal(exampleCount, 2);

  const loaded = loadRankingModel(modelPath);
  assert.ok(loaded instanceof LogisticRanker);
  assert.equal(loaded.weights.length, FEATURE_NAMES.length);
});

test('countRankingExamples is 0 for a file that does not exist', () => {
  assert.equal(countRankingExamples(tmpFile('missing.jsonl')), 0);
});

test('buildAuxiliaryTree with no rankingModel behaves exactly as before (no-op)', () => {
  const raw = [{
    role: 'main', ref: 'e1', box: { x: 0, y: 0, width: 800, height: 600 },
    children: [{ role: 'button', name: 'Submit', ref: 'e2', box: { x: 0, y: 0, width: 100, height: 40 } }],
  }];
  const withoutModel = buildAuxiliaryTree(raw);
  const explicitlyNull = buildAuxiliaryTree(raw, { rankingModel: null });
  assert.deepEqual(withoutModel.navigation, explicitlyNull.navigation);
});

test('buildAuxiliaryTree applies a trained model as one explainable extra term', () => {
  const raw = [{
    role: 'main', ref: 'e1', box: { x: 0, y: 0, width: 800, height: 600 },
    children: [{ role: 'button', name: 'Submit', ref: 'e2', box: { x: 0, y: 0, width: 100, height: 40 } }],
  }];
  const model = new LogisticRanker();
  model.bias = 5; // predict(anything) ~= 1, a strong positive boost regardless of features

  const { navigation } = buildAuxiliaryTree(raw, { rankingModel: model });
  const feature = navigation[0];
  assert.ok(feature.parts.some(p => p.label.startsWith('learned from usage')));
  assert.ok(feature.parts.find(p => p.label.startsWith('learned from usage')).value > 0);
});
