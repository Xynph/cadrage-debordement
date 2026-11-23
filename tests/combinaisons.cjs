'use strict';
// Combinaisons de phases arrêtées branchées au match (Tactique › Phases arrêtées, idée FM27 n° 21, choix de Léo du
// 23/11/2026) : touche, mêlée, pénalité et renvoi, en attaque et en défense, enregistrées dans la sauvegarde.
// Carrière Monde (world-champ), vraies commandes du worker. Règles vérifiées sans dépendre d'une graine :
// effets lus dans le moteur (aucun tirage), décisions forcées (tirage BAS / HAUT), sauvegarde stricte.
const assert = require('node:assert/strict');
const fs = require('node:fs'), os = require('node:os'), path = require('node:path');
const { test } = require('node:test');
const { createBridge } = require('../native/engine/worker.cjs');
const { settleClubMeetings } = require('./helpers/club-meetings.cjs');
const { advanceToNextMatch } = require('./helpers/monde-matchs.cjs');
const { skipMatchTalk } = require('./helpers/scene-match-talks.cjs');

const root = fs.mkdtempSync(path.join(os.tmpdir(), 'cd-combinaisons-'));
let b, n = 0, m;
const good = (command, payload = {}) => { const r = b.handle({ id: ++n, command, payload }); assert.equal(r.ok, true, command + ': ' + r.error); return m = r.model; };
const bad = (command, payload) => b.handle({ id: ++n, command, payload });
const run = code => b.vm.run(code);
const combo = (cle, action, extra = {}) => good('playbook_combo', { context: m.clubLife.playbook.context, cle, action, ...extra });
const state = () => JSON.parse(good('export').meta.exportText).state;

test.before(() => {
  b = createBridge({ dataDir: root, seed: 2311, now: 1700000000000, testVm: true });
  settleClubMeetings(good('new_career', { mode: 'world-champ', club: 29 }), (c, p) => good(c, p));
});
test.after(() => b?.close());

test('Le carnet expose les huit listes (attaque et défense des quatre phases), choix et effets du moteur', () => {
  const c = m.clubLife.playbook.combinaisons;
  assert.deepEqual(Object.keys(c).sort(), ['kickoff_attaque', 'kickoff_defense', 'lineout_attaque', 'lineout_defense', 'penalty_attaque', 'penalty_defense', 'scrum_attaque', 'scrum_defense']);
  for (const [cle, d] of Object.entries(c)) {
    assert.ok(d.liste.length >= 2 && d.active === 0, cle + ' : combinaisons proposées');
    assert.ok(d.pivots.length >= 1 && d.pivots.every(p => p.options.length >= 2), cle + ' : choix');
    // Première combinaison : neutre (aucun effet), comme un club géré par l'ordinateur.
    assert.ok(d.liste[0].effets.every(e => e[1] === 0), cle + ' : la première combinaison ne change rien');
  }
  assert.deepEqual(c.scrum_attaque.pivots[0].options.map(o => o.id), ['equilibre', 'pousser', 'vite', 'huit'], '8 qui part en mêlée');
  assert.deepEqual(c.penalty_attaque.pivots.map(p => p.id), ['pres', 'portee', 'loin'], 'pénalité réglée par zone');
  assert.deepEqual(c.penalty_attaque.pivots[0].options.map(o => o.id), ['staff', 'poteaux', 'touche', 'melee', 'main']);
  // Aucune option sans contrepartie : chaque choix d'attaque qui gagne quelque part perd ailleurs.
  for (const cle of ['lineout_attaque', 'scrum_attaque', 'kickoff_attaque']) for (const p of c[cle].pivots) for (const o of p.options) {
    const v = run(`JSON.stringify(combiEffets('${cle}',{...combiNeutre('${cle}'),${p.id}:'${o.id}'}))`);
    const e = JSON.parse(v).map(x => x[1] * x[3]);
    if (e.some(x => x > 0)) assert.ok(e.some(x => x < 0), `${cle}.${p.id}=${o.id} : un gain a une contrepartie`);
  }
});

test('Un clic applique : choisir, ajouter, changer un choix ; sauvegardé et ancien carnet tenu à jour', () => {
  combo('lineout_attaque', 'choisir', { index: 1 });
  assert.equal(m.clubLife.playbook.combinaisons.lineout_attaque.active, 1);
  let s = state();
  assert.equal(s.manager.playbook.combos.lineout_attaque.active, 1, 'combinaison active dans la sauvegarde');
  assert.equal(s.manager.playbook.lineout, 'maul', 'Maul des 22 : ancien carnet « ballon porté »');
  combo('scrum_attaque', 'ajouter');
  combo('scrum_attaque', 'pivot', { pivot: 'sortie', valeur: 'huit' });
  s = state();
  const e = s.manager.playbook.combos.scrum_attaque;
  assert.equal(e.liste.length, 5); assert.equal(e.active, 4); assert.equal(e.liste[4].nom, 'Combinaison 5'); assert.equal(e.liste[4].choix.sortie, 'huit');
  combo('penalty_attaque', 'pivot', { pivot: 'pres', valeur: 'melee' });
  assert.equal(state().manager.playbook.combos.penalty_attaque.liste[0].choix.pres, 'melee');
  // Ancien carnet (en match) → combinaison active.
  good('playbook_set', { context: m.clubLife.playbook.context, key: 'scrum', value: 'pousser' });
  assert.equal(state().manager.playbook.combos.scrum_attaque.liste[4].choix.sortie, 'pousser');
  combo('scrum_attaque', 'pivot', { pivot: 'sortie', valeur: 'huit' });
  // Refus sans rien changer : choix inconnu, phase inconnue, index hors liste, champ en trop.
  const figee = good('export').meta.exportText;
  for (const p of [{ cle: 'scrum_attaque', action: 'pivot', pivot: 'sortie', valeur: 'triche' }, { cle: 'maul_attaque', action: 'choisir', index: 0 }, { cle: 'scrum_attaque', action: 'choisir', index: 9 }, { cle: 'scrum_attaque', action: 'choisir', index: 0, extra: 1 }]) {
    assert.equal(bad('playbook_combo', { context: m.clubLife.playbook.context, ...p }).ok, false, JSON.stringify(p));
  }
  assert.equal(good('export').meta.exportText, figee);
  // Sauvegarde stricte.
  for (const casse of ['c.scrum_attaque.liste[0].choix.sortie="triche"', 'c.inconnue={active:0,liste:[]}', 'c.scrum_attaque.active=12', 'c.scrum_attaque.liste=Array.from({length:9},()=>({nom:"x",choix:{}}))']) {
    assert.throws(() => run(`(()=>{const s=JSON.parse(JSON.stringify(S));const c=s.manager.playbook.combos;${casse};validateCareer(s)})()`), casse);
  }
});

test('Match : la combinaison suit le direct, en pause seulement ; club adverse neutre', () => {
  advanceToNextMatch(m, good); settleClubMeetings(good('train'), (c, p) => good(c, p)); good('auto_lineup');
  skipMatchTalk(good('begin_match'), good); good('pause', { paused: true });
  const live = JSON.parse(run('JSON.stringify({v:S.live.combiVersion,u:S.live.playbooks[S.live.userSide].combos,o:S.live.playbooks[1-S.live.userSide].combos||null})'));
  assert.equal(live.v, 1); assert.equal(live.u.scrum_attaque.liste[live.u.scrum_attaque.active].choix.sortie, 'huit'); assert.equal(live.o, null, 'adversaire : carnet neutre');
  combo('kickoff_defense', 'choisir', { index: 2 });
  assert.equal(run('S.live.playbooks[S.live.userSide].combos.kickoff_defense.active'), 2, 'en pause : la rencontre suit aussitôt');
  good('pause', { paused: false });
  assert.equal(bad('playbook_combo', { context: m.clubLife.playbook.context, cle: 'kickoff_defense', action: 'choisir', index: 0 }).ok, false, 'pas pendant le jeu');
  good('pause', { paused: true });
});

// Copie du direct pour les règles (aucune écriture dans la carrière).
function fixture(setup = '') {
  run(`var __l=JSON.parse(JSON.stringify(S.live));__l.paused=false;var __u=__l.userSide,__o=1-__u;__l.penaltyPolicies=['auto','auto'];
    __l.playbooks.forEach(p=>{delete p.combos;p.scrum='equilibre';p.lineout='equilibre';p.kickoff='normal'});
    var __set=(side,cle,choix)=>{const p=__l.playbooks[side];p.combos=p.combos||{};p.combos[cle]={active:0,liste:[{nom:'t',choix:{...combiNeutre(cle),...choix}}]};syncLegacyMoves(p)};${setup}`);
}
const fx = (side, kind, fp = false) => JSON.parse(run(`JSON.stringify(setPieceEffects(__l,${side},'${kind}',${fp}))`));

test('Sans combinaisons : carnet neutre sans effet ni tirage ; ancien choix du carnet suivi dans le même sens', () => {
  // Club de l'ordinateur (carnet neutre) : aucun effet, aucun tirage de plus.
  fixture(); run('var __n=0,__r=Math.random;Math.random=()=>{__n++;return __r()};var __e=[setPieceEffects(__l,__u,"lineout"),setPieceEffects(__l,__u,"scrum")];var __k=kickoffPolicy(__l,__u,"kickoff");var __p=combiPlanPenalite(__l,__u,30);Math.random=__r');
  assert.equal(run('__n'), 0);
  assert.ok(run('__e.every(e=>e.win===0&&e.gain===0&&e.finish===0)&&__k.retain===0&&!__k.extra&&__p==="staff"'), 'neutre : aucun effet');
  // Ancien choix du carnet (sans combinaisons) : même nom et même sens d'effet que l'ancienne table.
  for (const [kind, moves] of [['lineout', ['courte', 'fond', 'maul']], ['scrum', ['securiser', 'pousser']]]) for (const move of moves) {
    fixture(`__l.playbooks[__u].${kind}='${move}'`);
    const neuf = fx('__u', kind);
    run('var __v=__l.combiVersion;delete __l.combiVersion');
    const ancien = fx('__u', kind);
    run('__l.combiVersion=__v');
    assert.equal(neuf.move, ancien.move, `${kind} ${move}`);
    for (const k of ['win', 'gain', 'finish']) assert.equal(Math.sign(neuf[k]), Math.sign(ancien[k]), `${kind} ${move} ${k}`);
  }
});

test('Touche et mêlée : choix d’attaque, contre adverse, 8 qui part selon le n° 8', () => {
  fixture(`__set(__u,'lineout_attaque',{alignement:'4',cible:'devant'})`);
  let e = fx('__u', 'lineout');
  assert.ok(e.win > 0 && e.finish < 0, 'touche courte à 4 : conserve plus, moins d’essais sur ballon porté');
  // Contre devant sur un lancer devant : conservation en baisse ; sur un lancer au fond : en hausse.
  run(`__set(__o,'lineout_defense',{contre:'devant'})`); const contre = fx('__u', 'lineout');
  assert.ok(contre.win < e.win, 'contre deviné : moins de touches gagnées');
  run(`__set(__u,'lineout_attaque',{alignement:'4',cible:'fond'})`); const fond = fx('__u', 'lineout');
  run(`__set(__o,'lineout_defense',{contre:'lire'})`); const fondLibre = fx('__u', 'lineout');
  assert.ok(fond.win > fondLibre.win, 'contre mal deviné : lancer au fond plus facile');
  run(`__set(__o,'lineout_defense',{contre:'maul'})`); const maul = fx('__u', 'lineout');
  assert.ok(maul.finish < fondLibre.finish && maul.win > fondLibre.win, 'contrer le maul : moins d’essais, pas de saut');
  // Mur contre le maul sur pénaltouche seulement.
  run(`__set(__o,'lineout_defense',{contre:'lire'});__set(__o,'penalty_defense',{repli:'mur'})`);
  assert.ok(fx('__u', 'lineout', true).finish < fx('__u', 'lineout', false).finish, 'mur : pénaltouche moins dangereuse');
  // 8 qui part : la puissance du n° 8 fait la différence.
  fixture(`__set(__u,'scrum_attaque',{sortie:'huit'});var __huit=matchPlayer(__l,__u,__l.sheets[__u].on[7]);ensureSkills(__huit);var __p0=__huit.skills.power`);
  run('__huit.skills.power=__p0+25'); const fort = fx('__u', 'scrum');
  run('__huit.skills.power=__p0-25'); const faible = fx('__u', 'scrum');
  run('__huit.skills.power=__p0');
  assert.ok(fort.gain > faible.gain && fort.finish > faible.finish && fort.huit, '8 puissant : plus de mètres et d’essais');
  const avant = fx('__u', 'scrum');
  assert.equal(run('combiBiaisMelee(__l,__u)'), 0);
  run(`__set(__o,'scrum_defense',{poussee:'pousser'})`);
  assert.ok(fx('__u', 'scrum').win < avant.win && run('combiBiaisMelee(__l,__u)') > 0, 'poussée adverse : moins de mêlées gagnées, plus de pénalités pour l’introducteur');
});

test('Renvoi : réception adverse (avants devant / profonde) ; renvoi court toujours à 10 m au moins', () => {
  for (const [reception, signe] of [['avants', -1], ['profonde', 1]]) {
    fixture(`__set(__o,'kickoff_defense',{reception:'${reception}'})`);
    const p = JSON.parse(run('JSON.stringify(kickoffPolicy(__l,__u,"kickoff"))'));
    assert.equal(Math.sign(p.retain), signe, reception);
    run(`__set(__u,'kickoff_attaque',{renvoi:'court'})`);
    const court = JSON.parse(run('JSON.stringify(kickoffPolicy(__l,__u,"kickoff"))'));
    assert.ok(court.distance[0] + court.extra >= 10, 'loi 12 : dix mètres');
  }
});

test('Pénalité : plan d’avant-match par zone (au but, pénaltouche, mêlée, jouer vite), consigne du direct prioritaire', () => {
  const issue = (choix, distance, extra = '') => {
    fixture(`__set(__u,'penalty_attaque',${JSON.stringify(choix)});${extra}ballPossession(__l,__u,__u===0?100-${distance}:${distance});__l.minute=20;__l.events.push({type:'play',min:20,text:''});
      var __ev=__l.events.length,__g=__l.stats[__u].goalAttempts,__q=(__l.quickTaps||[0,0])[__u];Math.random=()=>0.9999999;executePenaltyChoice(__l,__u)`);
    return JSON.parse(run(`JSON.stringify({tir:__l.stats[__u].goalAttempts-__g,vite:(__l.quickTaps||[0,0])[__u]-__q,melee:__l.restartLog.some(r=>r.cause==='penalty-scrum'&&r.team===__u&&r.minute===20),touche:__l.restartLog.some(r=>r.cause==='penalty-touch'&&r.team===__u&&r.minute===20)})`));
  };
  assert.equal(issue({ pres: 'poteaux' }, 15).tir, 1, 'au but dans les 22');
  assert.ok(issue({ pres: 'touche' }, 15).touche, 'pénaltouche dans les 22');
  assert.ok(issue({ pres: 'melee' }, 15).melee, 'mêlée dans les 22 (loi 20)');
  assert.equal(issue({ pres: 'main' }, 15).vite, 1, 'jouée vite');
  assert.equal(issue({ portee: 'poteaux' }, 35).tir, 1, 'au but à portée');
  assert.equal(issue({ loin: 'poteaux' }, 58).tir, 0, 'hors de portée : pas de tir');
  assert.equal(issue({ pres: 'poteaux' }, 15, `__l.penaltyPolicies[__u]='touch';`).tir, 0, 'consigne du direct prioritaire');
});
