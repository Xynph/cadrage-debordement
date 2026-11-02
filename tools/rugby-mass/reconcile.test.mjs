import test from 'node:test';
import assert from 'node:assert/strict';
import { reconcile } from './reconcile.mjs';

const profile = (overrides={}) => ({
  id: 'lnr:100', realName: 'Émile Dupont', club: 'Club A',
  league: 'TOP14', performance2025_2026: null, ...overrides
});
const observed = (overrides={}) => ({
  name: 'Emile Dupont', club: 'Club A', league: 'TOP14',
  season: '2025-2026', sourceUrl: 'https://www.rugbydata.fr/statistics/competition/1',
  matches: 21, minutes: 1390, tries: 4, points: 20, ...overrides
});
const run = (rows, players=[profile()]) => reconcile({players}, rows);

test('rapprochement sans écriture : conservation identité et valeurs vérifiées', () => {
  const players=[profile()];
  const before=JSON.stringify(players);
  const result=run([observed()],players);
  assert.deepEqual(result.summary,{input:1,accepted:1,newPlayers:1,rejected:0});
  assert.deepEqual(result.proposedChanges[0],{
    id:'lnr:100',
    performance2025_2026:{competition:'TOP14',season:'2025-2026',
      matches:21,minutes:1390,tries:4,points:20}
  });
  assert.equal(JSON.stringify(players),before);
});

test('les inconnues restent null, jamais transformées en zéro',()=>{
  const result=run([observed({minutes:null,tries:null,points:null})]);
  assert.equal(result.summary.newPlayers,1);
  assert.equal(result.proposedChanges[0].performance2025_2026.minutes,null);
  assert.equal(result.proposedChanges[0].performance2025_2026.tries,null);
  assert.equal(result.proposedChanges[0].performance2025_2026.points,null);
});

test('rejet des noms ambigus même lorsque le club diffère',()=>{
  const result=run([observed()],[profile(),profile({id:'lnr:101',club:'Club B'})]);
  assert.equal(result.summary.newPlayers,0);
  assert.equal(result.rejected[0].issue,'ambiguous-name');
});

test('rejet transferts, saison incorrecte et compétition différente',()=>{
  for(const [override,issue] of [
    [{club:'Club B'},'club-or-transfer'],
    [{season:'2026-2027'},'season'],
    [{league:'PROD2'},'league-or-transfer']
  ]) assert.equal(run([observed(override)]).rejected[0].issue,issue);
});

test('rejet données invraisemblables et absence de statistiques',()=>{
  for(const row of [
    observed({minutes:2000,matches:10}),
    observed({points:10,tries:4}),
    observed({matches:-1}),
    observed({matches:3.5}),
    observed({matches:null,minutes:null,tries:null,points:null})
  ]) {
    const result=run([row]);
    assert.equal(result.summary.accepted,0);
    assert.equal(result.summary.rejected,1);
  }
});

test('déduplication des observations du même identifiant',()=>{
  const result=run([observed(),observed()]);
  assert.equal(result.summary.accepted,1);
  assert.equal(result.summary.newPlayers,1);
  assert.equal(result.rejected[0].issue,'duplicate');
});

test('ne jamais remplacer silencieusement une observation existante différente',()=>{
  const existing={competition:'TOP14',season:'2025-2026',matches:1,minutes:40,tries:0,points:0};
  const result=run([observed()],[profile({performance2025_2026:existing})]);
  assert.equal(result.summary.newPlayers,0);
  assert.equal(result.rejected[0].issue,'existing-observation-conflict');
});

test('une ligne sans provenance HTTPS est rejetée',()=>{
  assert.equal(run([observed({sourceUrl:''})]).summary.accepted,0);
});
