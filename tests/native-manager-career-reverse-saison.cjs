'use strict';
// Mobilité du manager, vrai worker de production, mode Monde (2/2) : après acceptation de l'offre Élite, la saison
// suivante est rejouée sur la carrière et sur un témoin (annulation), puis comparée : comptes, effectifs et centre de
// formation conservés (politique 3). Seconde moitié de l'ancien tests/manuel/native-manager-career-reverse.cjs ;
// la fin de saison vient de la sauvegarde générée par scripts/generer-sauvegarde-mobilite.cjs (cf. 1/2).
const assert = require('node:assert/strict');
const { settleClubMeetings } = require('./helpers/club-meetings.cjs');
const { banc } = require('./helpers/sauvegarde-mobilite.cjs');
const t = banc();
try {
 const { open, good, doc, act, ouvrirFinDeSaison, cibleElite } = t;
 const b = ouvrirFinDeSaison('accession');
 const target = cibleElite(b);
 act(b, 'manager_career_apply', { clubId: target.clubId }); const offerId = 'job-1-' + target.clubId;
 act(b, 'manager_career_accept', { offerId, confirmed: true });
 const control = open('control'); good(control, 'import', { text: good(b, 'export').meta.exportText }); act(control, 'manager_career_cancel');
 const regler = x => (command, payload) => good(x, command, payload);
 settleClubMeetings(good(control, 'next_season', { confirmed: true }), regler(control));
 settleClubMeetings(good(b, 'next_season', { confirmed: true }), regler(b));
 const a = doc(b).state, z = doc(control).state;
 assert.equal(a.club, target.clubId); assert.equal(a.managerMobility.history[0].fromClub, 29);
 assert.deepEqual(a.clubs.map(c => c.cash), z.clubs.map(c => c.cash));
 {// Effectifs conservés, à une différence près voulue par Léo (19/11/2026, docs/gdd/calendrier-mutations.md
  // § 3 quater) : le club joué n'a plus de plancher de 40, les clubs gérés le gardent. L'ancien club (29), devenu
  // géré dans la carrière, peut recevoir ses joueurs de complément de la nouvelle saison ; le club repris, joué, n'en
  // reçoit pas (et inversement chez le témoin). Tout le reste est identique, joueur par joueur et dans l'ordre.
  const fresh = (clubId, id) => id.startsWith('depth-' + clubId + '-' + a.season + '-');
  const ids = (s, clubId, sans) => s.clubs[clubId].players.map(p => p.id).filter(id => !(sans && fresh(clubId, id)));
  for (const c of a.clubs) {
   if (c.id === 29 || c.id === target.clubId) continue;
   assert.deepEqual(ids(a, c.id), ids(z, c.id), 'club ' + c.id);
  }
  assert.deepEqual(ids(a, 29, true), ids(z, 29), 'ancien club : seuls des joueurs de complément s’ajoutent');
  assert.ok(ids(z, 29).every(id => !fresh(29, id)), 'club joué du témoin : aucun joueur de complément');
  assert.deepEqual(ids(a, target.clubId), ids(z, target.clubId, true), 'club repris : seuls ses joueurs de complément manquent');
  assert.ok(ids(a, target.clubId).every(id => !fresh(target.clubId, id)), 'club repris : aucun joueur de complément');
  assert.ok(ids(a, 29).length >= 40 || ids(a, 29).length === ids(z, 29).length, 'ancien club : plancher retrouvé s’il manquait des joueurs');
 }
 {// Politique 3 : le club repris garde son centre ; sa nouvelle génération attend le choix du
  // manager au lieu du choix automatique, et ses Espoirs ne sont pas réduits par le staff.
  const mine = a.development.academy, ai = z.aiRoster.academies.find(c => c.clubId === target.clubId).players, season = a.season;
  const kept = ai.filter(p => !p.id.startsWith('youth-' + target.clubId + '-' + season + '-'));
  assert.deepEqual(mine.filter(p => kept.some(q => q.id === p.id)).map(p => p.id), kept.map(p => p.id));
  assert.ok(mine.filter(p => !kept.some(q => q.id === p.id)).every(p => p.age >= 18), 'seuls des Espoirs non retenus par le staff de l’ordinateur diffèrent');
  assert.equal(a.academyIntake.season, season); assert.ok(a.academyIntake.players.length >= 12);
 }
 console.log('PASS mobilité manager (2/2) : saison suivante, comptes/effectifs/centre conservés');
} finally { t.fermer(); }
