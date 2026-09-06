// Retrains the ranking model (rankingModel.js) from every selection recorded
// so far and saves it to data/ranking-model.json. Run this whenever you want
// the model to catch up on new usage; browserSession.js picks up the new
// file on its very next scan, no restart needed.
//
// No LLM, no network call, no external service: this is a few hundred
// gradient-descent steps over ~11 numbers, entirely local.
//
// Usage: npm run train

import { trainAndSaveRankingModel, countRankingExamples, FEATURE_NAMES } from './rankingModel.js';

const existing = countRankingExamples();
if (existing === 0) {
  console.log('No selections recorded yet -- nothing to train on.');
  console.log('Use `npm run aux` and act on a few features first (the "n<rank>"/"i<rank>" commands).');
  process.exit(0);
}

const { model, exampleCount } = trainAndSaveRankingModel();
console.log(`Trained on ${exampleCount} examples (${existing} recorded).`);
console.log('Learned weights:');
for (let i = 0; i < FEATURE_NAMES.length; i++) {
  console.log(`  ${FEATURE_NAMES[i].padEnd(16)} ${model.weights[i].toFixed(3)}`);
}
console.log(`  bias             ${model.bias.toFixed(3)}`);
console.log('\nSaved to data/ranking-model.json -- the next scan (npm run aux / npm run ui) will use it.');
