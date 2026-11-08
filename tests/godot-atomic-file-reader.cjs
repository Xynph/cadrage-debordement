'use strict';
// Independent reader: the caller creates the initial file before starting us.
const fs = require('node:fs');
const { parentPort, workerData } = require('node:worker_threads');
if (parentPort && workerData) {
const control = new Int32Array(workerData.control);
const result = { samples: 0, missing: 0, invalid: 0, other: 0 };
parentPort.postMessage('ready');
while (Atomics.load(control, 0) === 0) {
  try {
    const value = JSON.parse(fs.readFileSync(workerData.destination, 'utf8'));
    if (!Number.isInteger(value.sequence) || value.payload !== 'é'.repeat(4096)) result.invalid++;
  } catch (error) {
    if (error.code === 'ENOENT') result.missing++;
    else if (error instanceof SyntaxError) result.invalid++;
    else result.other++;
  }
  result.samples++;
}
parentPort.postMessage(result);
}
