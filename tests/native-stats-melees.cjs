'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');
const { context } = require('./france-harness.cjs');
const nativeModel = require('../native/engine/model.cjs');

function statsRows(match) {
  return JSON.parse(match.run(`JSON.stringify((${nativeModel.toString()})().live.statsRows)`));
}

test('Native stats show non-disputed scrums under the introducing team and retain them on reload', () => {
  const match = context();
  match.run(`start(0, 'france'); beginMatch(); pauseMatch();
    var live = S.live, affected = live.userSide, sheet = live.sheets[affected];`);
  assert.equal(statsRows(match).some(row => row.label === 'Dont non disputées'), false);
  match.run(`live.minute = 10;
    giveMatchCard(live, affected, sheet.on[0]); prepareFrontRows(live);
    live.minute = 12; giveMatchCard(live, affected, sheet.on[0]); prepareFrontRows(live);
    var introducing = 1 - affected;
    grantSetPiece(live, 'scrum', introducing, 50, 'knock-on', affected);`);
  assert.equal(match.run('live.uncontestedScrums[introducing]'), 1);
  const rows = statsRows(match);
  const introduction = match.run('introducing');
  const expected = { label: 'Dont non disputées', home: introduction === 0 ? 1 : 0, away: introduction === 1 ? 1 : 0 };
  assert.deepEqual(rows[rows.findIndex(row => row.label === 'Mêlées conservées') + 1], expected);

  const resumed = context();
  resumed.ctx.scrumSave = match.run('JSON.stringify(createSaveDocument())');
  assert.equal(resumed.run('pendingSave = parseSaveDocument(scrumSave); confirmSaveImport()'), true);
  assert.deepEqual(statsRows(resumed).find(row => row.label === expected.label), expected);
});
