'use strict';
// Lois manquantes (docs/lois-manquantes-20261126.md) : matchs de Top 14 joués par le vrai moteur (carrière world-champ,
// harnais du monde, graine fixe), journal lu fait par fait.
// - fréquences par match proches du réel d'élite : coups francs (3-5), passes en avant (2-4), essais de pénalité
//   (~0,1), drops tentés (~0,2), mêlées accordées (12-15) et cartons jaunes (~1,3) ;
// - coup franc (loi 20) : jeu à la main ou coup de pied du bénéficiaire, jamais de tir au but ni de mêlée ; touche directe
//   depuis ses 22 : lancer adverse ;
// - essai de pénalité (loi 8) : 7 points sans transformation, carton jaune du fautif juste avant ;
// - passe en avant (loi 11) : mêlée adverse (ou avantage à l'adversaire) ;
// - drop : 3 points, surtout dans le dernier quart d'heure ;
// - champ `loi` du fait (scene.loi) : présent sur chaque fait du bloc des lois, jamais ailleurs ;
// - fil du score de l'après-match (match-direct) : la somme de ses points = le score final, essais de pénalité et drops compris ;
//   la frise (`reperes`) montre les mêmes points ;
// - direct 3D : chaque fait des lois sans image est écrit après un plan d'un temps fort (`direct.lois`) ;
// - rien après le coup de sifflet final ;
// - « Tirs de pénalité » affichés = buts − drops sur tirs − drops tentés (les drops ont leurs propres compteurs).
const assert = require('node:assert/strict');
const { test } = require('node:test');
const { worldYouth } = require('./helpers/youth-world-harness.cjs');
const direct = require('../native/engine/match-direct.cjs');

const N = 144, COMP = 'elite';
const BRUIT = new Set(['sub', 'tactic', 'card', 'advantage']);

function jouer(n) {
  const matchs = [];
  for (let monde = 0; matchs.length < n; monde++) {
    const t = worldYouth({ seed: 61126 + monde * 101, club: monde * 7 });
    const total = Number(t.run(`S.worldMode.fixtures.filter(f=>f.competitionId==='${COMP}'&&f.phase==='league').length`));
    for (let i = 0; i < 48 && matchs.length < n; i++) {
      matchs.push(JSON.parse(t.run(`(()=>{const f=S.worldMode.fixtures.filter(f=>f.competitionId==='${COMP}'&&f.phase==='league')[(${i}*7+${monde}*13)%${total}];
        S.round=f.week;const pair=[f.homeId,f.awayId];for(const id of pair)CDFranceCareer.ensureAISheet(S.clubs[id]);S.club=pair[0];
        const l=createRugbyMatch(pair,null,false);for(let n=0;!l.finished;n++){if(n>4000)throw Error('boucle');l.paused=false;advanceRugby(l)}
        return JSON.stringify({abbr:pair.map(id=>S.clubs[id].abbr),score:l.score,tries:l.tries,yellows:l.stats[0].yellows+l.stats[1].yellows,
          transfos:l.stats.map(s=>({c:s.conversions,a:s.conversionAttempts,pt:s.penaltyTries||0,panneau:statsPanel(l).includes((s.conversions-(s.penaltyTries||0))+' / '+(s.conversionAttempts-(s.penaltyTries||0)))})),
          tirs:l.stats.map(s=>({g:s.goals,a:s.goalAttempts,d:s.drops||0,da:s.dropAttempts||0})),
          panneauTirs:statsPanel(l).includes('<strong>'+(l.stats[0].goals-(l.stats[0].drops||0))+' / '+(l.stats[0].goalAttempts-(l.stats[0].dropAttempts||0))+'</strong><span>Tirs de pénalité</span><strong>'+(l.stats[1].goals-(l.stats[1].drops||0))+' / '+(l.stats[1].goalAttempts-(l.stats[1].dropAttempts||0))+'</strong>'),
          journal:l.events.map(e=>e.scene?{min:e.min,type:e.type,text:e.text,period:e.period,scene:{kind:e.scene.kind,team:e.scene.team,possession:e.scene.possession,period:e.scene.period,actor:e.scene.actor,cause:e.scene.cause,loi:e.scene.loi,move:e.scene.move,incident:e.scene.incident,origin:e.scene.origin,conversion:e.scene.conversion,from:e.scene.from,to:e.scene.to,score:e.scene.score,tries:e.scene.tries}}:{min:e.min,type:e.type,text:e.text,period:e.period}),
          events:l.events.map(e=>({min:e.min,type:e.type,text:e.text,s:e.scene?{kind:e.scene.kind,team:e.scene.team,cause:e.scene.cause,loi:e.scene.loi,score:e.scene.score}:{}}))});})()`)));
    }
  }
  return matchs;
}

const matchs = jouer(N);
const suivant = (ev, j) => { let q = j + 1; while (q < ev.length && BRUIT.has(ev[q].type)) q++; return ev[q] || null; };
const scoreAvant = (ev, j) => { for (let q = j - 1; q >= 0; q--) if (ev[q].s.score) return ev[q].s.score; return [0, 0]; };

test('Fréquences par match : coups francs, passes en avant, essais de pénalité, drops, mêlées, jaunes', () => {
  const c = {}, add = (k, v = 1) => { c[k] = (c[k] || 0) + v; };
  for (const m of matchs) {
    add('jaunes', m.yellows);
    for (const e of m.events) {
      if (/^Coup franc pour /.test(e.text)) add('cf');
      if (e.s.kind === 'hand-fault' && e.s.cause === 'forward-pass') add('passes');
      if (e.type === 'try' && /^\S+ · Essai de pénalité/.test(e.text)) add('essaisPen');
      if (/ tente le drop /.test(e.text)) add('drops');
      if (e.type === 'setup' && e.s.kind === 'scrum') add('melees');
    }
  }
  const p = k => (c[k] || 0) / matchs.length;
  const bilan = Object.fromEntries(['cf', 'passes', 'essaisPen', 'drops', 'melees', 'jaunes'].map(k => [k, +p(k).toFixed(2)]));
  console.log('lois complètes, par match :', JSON.stringify(bilan), 'essais de pénalité', c.essaisPen || 0, 'drops', c.drops || 0);
  assert.ok(p('cf') >= 2.4 && p('cf') <= 5, 'coups francs par match (réel 3-5) : ' + JSON.stringify(bilan));
  assert.ok(p('passes') >= 1.8 && p('passes') <= 4.5, 'passes en avant par match (réel 2-4) : ' + JSON.stringify(bilan));
  assert.ok(c.essaisPen >= 3 && p('essaisPen') <= 0.25, 'essais de pénalité (réel 0,07-0,15 par match) : ' + JSON.stringify(bilan));
  assert.ok(p('drops') >= 0.08 && p('drops') <= 0.5, 'drops tentés (réel ~0,2 par match) : ' + JSON.stringify(bilan));
  assert.ok(p('melees') >= 11.2, 'mêlées accordées (Top 14 réel 12-15) : ' + JSON.stringify(bilan));
  assert.ok(p('jaunes') >= 0.9 && p('jaunes') <= 1.7, 'cartons jaunes (réel 1,1-1,5) : ' + JSON.stringify(bilan));
});

test('Coup franc : jeu à la main ou coup de pied, ni tir au but ni mêlée ; touche directe = lancer adverse', () => {
  const fautes = []; let vus = 0, touches = 0;
  for (const m of matchs) m.events.forEach((e, j) => {
    const r = /^Coup franc pour (\S+) : /.exec(e.text);
    if (!r) return;
    vus++;
    const side = m.abbr.indexOf(r[1]), suite = suivant(m.events, j);
    if (side < 0 || e.s.team !== side) { fautes.push('bénéficiaire : ' + e.text); return; }
    if (!suite) return;
    if (['goal', 'miss'].includes(suite.type) || /pénalité|poteaux|drop/i.test(suite.text)) fautes.push('tir au but sur coup franc : ' + suite.text);
    if (suite.type === 'setup') fautes.push('mêlée ou touche sur coup franc : ' + suite.text);
    if (!(suite.s.team === side && ['carry', 'touch', 'kick', 'ingoal'].includes(suite.s.kind))) fautes.push(`suite inattendue : ${e.text} -> ${suite.text}`);
    if (suite.s.kind === 'touch') {
      touches++;
      const lancer = suivant(m.events, m.events.indexOf(suite));
      if (lancer && lancer.type === 'setup' && lancer.s.kind === 'lineout' && lancer.s.team !== 1 - side) fautes.push('lancer au botteur du coup franc : ' + suite.text);
      if (suite.s.cause === '50-22') fautes.push('50:22 sur coup franc : ' + suite.text);
    }
  });
  assert.ok(vus >= 150 && touches >= 10, `assez de coups francs observés (${vus}, dont ${touches} en touche)`);
  assert.deepEqual(fautes.slice(0, 5), [], `${fautes.length}/${vus} coups francs irréguliers`);
});

test('Essai de pénalité : 7 points sans transformation, carton jaune du fautif', () => {
  const fautes = []; let vus = 0;
  for (const m of matchs) m.events.forEach((e, j) => {
    if (!(e.type === 'try' && /Essai de pénalité/.test(e.text))) return;
    vus++;
    const side = e.s.team, avant = scoreAvant(m.events, j);
    if (!e.s.score || e.s.score[side] - avant[side] !== 7 || e.s.score[1 - side] !== avant[1 - side]) fautes.push('pas 7 points : ' + e.text);
    if (/transform/.test(e.text.replace('sans transformation', ''))) fautes.push('transformation : ' + e.text);
    const apres = m.events.slice(j + 1, j + 4).filter(x => !BRUIT.has(x.type));
    if (apres.some(x => /transform|poteaux/.test(x.text) || x.type === 'goal' || x.type === 'miss')) fautes.push('tir après l’essai de pénalité : ' + e.text);
    let q = j - 1; while (q >= 0 && m.events[q].type === 'card') q--;
    const cartons = m.events.slice(q + 1, j);
    if (!cartons.some(x => /^Carton (jaune|rouge)|carton rouge|second jaune/.test(x.text))) fautes.push('sans carton : ' + e.text);
    if (m.events[q]?.type !== 'penalty' || m.events[q].s.team !== side) fautes.push('sans faute sifflée juste avant : ' + e.text);
  });
  // Statistiques du match vues par le joueur : transformations tentées = essais marqués hors essais de pénalité.
  for (const m of matchs) for (const side of [0, 1]) {
    const t = m.transfos[side], vusIci = m.events.filter(e => e.type === 'try' && /Essai de pénalité/.test(e.text) && e.s.team === side).length;
    if (t.pt !== vusIci) fautes.push(`compte des essais de pénalité ${t.pt} ≠ ${vusIci}`);
    if (t.a - t.pt !== m.tries[side] - vusIci) fautes.push(`transformations tentées affichées ${t.a - t.pt} pour ${m.tries[side] - vusIci} essais marqués`);
    if (!t.panneau) fautes.push('statistiques du match : transformations sans retrait des essais de pénalité');
  }
  assert.ok(vus >= 3, `assez d’essais de pénalité observés (${vus})`);
  assert.deepEqual(fautes.slice(0, 5), [], `${fautes.length}/${vus} essais de pénalité irréguliers`);
});

test('Passe en avant : mêlée adverse, ou avantage à l’adversaire', () => {
  const fautes = []; let vus = 0, melees = 0;
  for (const m of matchs) m.events.forEach((e, j) => {
    if (!(e.type === 'play' && e.s.kind === 'hand-fault' && e.s.cause === 'forward-pass')) return;
    vus++;
    const fautif = e.s.team, adverse = m.abbr[1 - fautif], suite = suivant(m.events, j), avantage = m.events[j + 1];
    if (!/passe en avant/.test(e.text)) fautes.push('cause sans récit : ' + e.text);
    if (/ : introduction adverse\.$/.test(e.text)) {
      if (suite && suite.type === 'setup') { melees++; if (!(suite.s.kind === 'scrum' && suite.s.team === 1 - fautif)) fautes.push(`pas de mêlée adverse : ${e.text} -> ${suite.text}`); }
    } else if (!(avantage && (avantage.text === `Avantage sur passe en avant pour ${adverse}.` || /^Avantage sur passe en avant pour /.test(avantage.text) && avantage.text.includes(adverse) || /^Aucun avantage obtenu/.test(avantage.text)))) {
      fautes.push(`ni mêlée ni avantage adverse : ${e.text} -> ${avantage ? avantage.text : 'rien'}`);
    }
  });
  assert.ok(vus >= 150 && melees >= 50, `assez de passes en avant observées (${vus}, ${melees} mêlées directes)`);
  assert.deepEqual(fautes.slice(0, 5), [], `${fautes.length}/${vus} passes en avant mal sanctionnées`);
});

test('Drop : 3 points, surtout en fin de match', () => {
  const fautes = []; let tentes = 0, reussis = 0, tard = 0;
  for (const m of matchs) m.events.forEach((e, j) => {
    if (/ tente le drop /.test(e.text)) { tentes++; if (e.min >= 60) tard++; }
    if (e.type === 'goal' && /Drop réussi/.test(e.text)) {
      reussis++;
      const side = e.s.team, avant = scoreAvant(m.events, j);
      if (!e.s.score || e.s.score[side] - avant[side] !== 3) fautes.push('pas 3 points : ' + e.text);
      if (!/ tente le drop /.test(m.events[j - 1]?.text || '')) fautes.push('drop réussi sans tentative : ' + e.text);
    }
  });
  assert.ok(tentes >= 8 && reussis >= 2, `assez de drops (${tentes} tentés, ${reussis} réussis)`);
  assert.ok(reussis / tentes >= 0.25 && reussis / tentes <= 0.75, `réussite crédible : ${reussis}/${tentes}`);
  assert.ok(tard / tentes >= 0.35, `drops surtout en fin de match : ${tard}/${tentes} après la 60e`);
  assert.deepEqual(fautes.slice(0, 5), [], `${fautes.length} drops irréguliers`);
});

// Champ `loi` du fait (dist/restarts.js, bloc LOIS) : lu par les gestes 3D, jamais déduit du texte. Il est présent sur
// chaque fait du bloc des lois, et sur eux seuls ; le raté du drop passe ensuite par missedGoal, qui a ses propres faits.
test('Faits des lois : scene.loi sur chaque coup franc, essai de pénalité, drop et ballon injouable', () => {
  const LOIS = [
    ['coup-franc', e => /^Coup franc pour /.test(e.text)],
    ['coup-franc-joue', e => / joue vite le coup franc ; /.test(e.text)],
    ['essai-penalite', e => e.type === 'try' && /^\S+ · Essai de pénalité/.test(e.text)],
    ['drop-tente', e => / tente le drop /.test(e.text)],
    ['drop-rate', e => /^Le drop de .* passe à côté des poteaux\.$/.test(e.text)],
    ['drop-reussi', e => e.type === 'goal' && /Drop réussi/.test(e.text)],
    ['injouable', e => /ballon injouable : mêlée pour /.test(e.text)],
  ];
  const vus = Object.fromEntries(LOIS.map(([k]) => [k, 0])), fautes = [];
  for (const m of matchs) for (const e of m.events) {
    const attendues = LOIS.filter(([, test]) => test(e)).map(([k]) => k);
    if (attendues.length > 1) fautes.push('fait ambigu : ' + e.text);
    const loi = e.s.loi;
    if (attendues.length === 0) { if (loi !== undefined) fautes.push(`loi ${loi} sur un fait étranger : ${e.text}`); continue; }
    vus[attendues[0]]++;
    if (loi !== attendues[0]) fautes.push(`${e.text} : loi ${loi} au lieu de ${attendues[0]}`);
    if (attendues[0] === 'coup-franc-joue' && e.s.kind !== 'carry') fautes.push('coup franc joué hors d’une course : ' + e.text);
  }
  for (const k of Object.keys(vus)) assert.ok(vus[k] > 0, `fait « ${k} » observé au moins une fois : ${JSON.stringify(vus)}`);
  assert.deepEqual(fautes.slice(0, 5), [], `${fautes.length} faits sans le bon champ loi ; ${JSON.stringify(vus)}`);
});

// Coup de sifflet final : dernier fait du journal. Un drop raté à la sirène (renvoi refusé) laissait l'action continuer
// après lui (1 match sur 144) ; de même un coup franc joué au pied en touche après la sirène sur une pénalité « mêlée ».
test('Rien après le coup de sifflet final', () => {
  const fautes = [];
  for (const [n, m] of matchs.entries()) {
    const fin = m.journal.findIndex(e => e.text === 'Coup de sifflet final.');
    if (fin < 0) { fautes.push(`match ${n} : pas de coup de sifflet final`); continue; }
    const apres = m.journal.slice(fin + 1);
    if (apres.length) fautes.push(`match ${n} (${m.abbr.join('-')}) : ${apres.length} fait(s) après le sifflet final, dont « ${apres[0].text} »`);
  }
  assert.deepEqual(fautes.slice(0, 5), [], `${fautes.length}/${matchs.length} matchs avec des faits après le coup de sifflet final`);
});

// Fil du score de l'après-match (native/engine/match-direct.cjs, `direct.marques`) : il doit refaire le score, avec les
// essais de pénalité (7 points, sans marqueur) et les drops (3 points, le botteur) qui sont des faits « message ».
test('Fil du score : la somme des marques = le score final, essais de pénalité et drops compris', () => {
  const POINTS = { essai: 5, 'essai-transforme': 7, 'essai-penalite': 7, penalite: 3, drop: 3 };
  const lire = { scenes: indices => indices.map(() => null), transformation: () => null, etat: () => ({}), profils: () => ({}) };
  const fautes = []; let essaisPen = 0, drops = 0, reperesPen = 0, reperesDrops = 0;
  for (const [n, m] of matchs.entries()) {
    const events = m.journal.map(e => ({ min: e.min, type: e.type, text: e.text, ...(e.period ? { period: e.period } : {}), ...(e.scene ? { scene: e.scene } : {}) }));
    const d = direct.project({ live: { events, teams: [{ abbr: m.abbr[0], name: m.abbr[0] }, { abbr: m.abbr[1], name: m.abbr[1] }], finished: true, score: m.score, stats: [], statsRows: [] }, next: { phase: 'league' } }, 'dynamique', lire);
    const somme = [0, 0];
    for (const marque of d.marques) {
      if (!(marque.nature in POINTS)) { fautes.push(`match ${n} : nature inconnue ${marque.nature}`); continue; }
      somme[marque.equipe] += POINTS[marque.nature];
      if (marque.nature === 'essai-penalite') { essaisPen++; if (marque.joueur !== null || marque.buteur !== null || marque.kind !== 'try') fautes.push(`match ${n} : essai de pénalité avec marqueur ou botteur`); }
      if (marque.nature === 'drop') { drops++; if (marque.kind !== 'goal') fautes.push(`match ${n} : drop sans kind goal`); }
    }
    if (somme[0] !== m.score[0] || somme[1] !== m.score[1]) fautes.push(`match ${n} : fil ${somme} ≠ score ${m.score}`);
    if (d.marques.length && JSON.stringify(d.marques.at(-1).score) !== JSON.stringify(m.score)) fautes.push(`match ${n} : dernière marque ${d.marques.at(-1).score} ≠ score final ${m.score}`);
    // Frise (`direct.reperes`, entracte et après-match) : les mêmes points que le fil du score, dans le même ordre ;
    // essai de pénalité = repère « try » sans marqueur, drop réussi = repère « goal » du botteur.
    const points = d.reperes.filter(r => r.kind !== 'card');
    if (JSON.stringify(points.map(r => [r.kind, r.equipe, r.score])) !== JSON.stringify(d.marques.map(q => [q.kind, q.equipe, q.score]))) fautes.push(`match ${n} : frise ${JSON.stringify(points.map(r => r.score))} ≠ fil ${JSON.stringify(d.marques.map(q => q.score))}`);
    for (const r of points) {
      if (r.loi === 'essai-penalite') { reperesPen++; if (r.kind !== 'try' || r.joueur !== null) fautes.push(`match ${n} : repère d'essai de pénalité ${JSON.stringify(r)}`); }
      if (r.loi === 'drop-reussi') { reperesDrops++; if (r.kind !== 'goal') fautes.push(`match ${n} : repère de drop ${JSON.stringify(r)}`); }
    }
  }
  assert.ok(essaisPen >= 3 && drops >= 2, `essais de pénalité (${essaisPen}) et drops (${drops}) observés dans le fil`);
  assert.deepEqual([reperesPen, reperesDrops], [essaisPen, drops], 'essais de pénalité et drops sur la frise');
  assert.deepEqual(fautes.slice(0, 5), [], `${fautes.length} fils du score irréguliers`);
});

// Direct 3D (match filmé du 26/11 : essai de pénalité, drop et coup franc absents du fil et de la légende, seul le tiroir
// Journal les montrait) : chaque fait des lois sans image figure dans `direct.lois` dès qu'il est au journal, rattaché
// (`apres`) au dernier fait joué avant lui ; en match complet, ce fait est le dernier plan d'un temps fort reçu par la
// régie, qui écrit alors le fait des lois après ce plan (match_temps_forts_lecture.gd, lois_du_plan) : texte, score.
test('Direct 3D : chaque fait des lois est écrit après un plan d\'un temps fort (match complet)', () => {
  const LOIS = new Set(['coup-franc', 'essai-penalite', 'drop-tente', 'drop-rate', 'drop-reussi', 'injouable']);
  const lire = { scenes: ix => ix.map(i => ({ key: 'k' + i, players: [], ball: { x: 50, y: 35 }, origin: { x: 50, y: 35 } })), transformation: i => ({ key: 't' + i, players: [] }), etat: () => ({}), profils: () => ({}) };
  const projeter = (m, events, fini) => direct.project({ live: { events, teams: [{ abbr: m.abbr[0], name: m.abbr[0] }, { abbr: m.abbr[1], name: m.abbr[1] }], finished: fini, score: m.score, stats: [], statsRows: [] }, next: { phase: 'league' } }, 'integral', lire);
  const fautes = [], vus = {}; let ecrits = 0, total = 0;
  for (const [n, m] of matchs.slice(0, 36).entries()) {
    const events = m.journal.map(e => ({ min: e.min, type: e.type, text: e.text, ...(e.period ? { period: e.period } : {}), ...(e.scene ? { scene: e.scene } : {}) }));
    const faits = events.map((e, i) => ({ i, loi: e.scene?.loi })).filter(x => LOIS.has(x.loi));
    if (!faits.length) continue;
    // Plans reçus par la régie, temps fort par temps fort (le direct recalculé à chaque fait du journal).
    const plans = new Set(), cles = new Set();
    for (let k = 1; k <= events.length; k++) {
      const tf = projeter(m, events.slice(0, k), k === events.length).tempsFort;
      if (!tf || cles.has(tf.cle)) continue;
      cles.add(tf.cle);
      tf.plans.forEach((p, j) => { if (tf.plans[j + 1]?.index !== p.index) plans.add(p.index); });
    }
    for (const f of faits) {
      total++; vus[f.loi] = (vus[f.loi] || 0) + 1;
      const loi = projeter(m, events.slice(0, f.i + 1), false).lois.find(x => x.i === f.i);
      if (!loi) { fautes.push(`match ${n} : ${f.loi} absent de direct.lois : ${events[f.i].text}`); continue; }
      if (loi.texte !== events[f.i].text || loi.loi !== f.loi) fautes.push(`match ${n} : ${f.loi} mal recopié ${JSON.stringify(loi)}`);
      if (JSON.stringify(loi.score) !== JSON.stringify(events[f.i].scene.score)) fautes.push(`match ${n} : score de ${f.loi} ${loi.score} ≠ ${events[f.i].scene.score}`);
      if (f.loi === 'essai-penalite' && loi.kind !== 'try' || f.loi === 'drop-reussi' && loi.kind !== 'goal') fautes.push(`match ${n} : nature de ${f.loi} ${loi.kind}`);
      if (plans.has(loi.apres)) ecrits++; else fautes.push(`match ${n} : ${f.loi} après le fait ${loi.apres}, jamais un plan montré : ${events[f.i].text}`);
    }
  }
  console.log('direct 3D, faits des lois écrits après un plan :', ecrits, '/', total, JSON.stringify(vus));
  assert.ok(vus['coup-franc'] >= 20 && vus['injouable'] >= 10 && (vus['essai-penalite'] || 0) + (vus['drop-tente'] || 0) >= 1, 'assez de faits des lois observés : ' + JSON.stringify(vus));
  assert.deepEqual(fautes.slice(0, 5), [], `${fautes.length} faits des lois jamais écrits dans le direct 3D`);
});

// Drops : comptés avec les buts du moteur (score = essais × 5 + transformations × 2 + buts × 3, contrôlé à la sauvegarde),
// mais retirés de « Tirs de pénalité » : le joueur voit buts − drops sur tirs − drops tentés.
test('Tirs de pénalité affichés : buts − drops sur tirs − drops tentés', () => {
  const fautes = []; let drops = 0, tentes = 0;
  for (const [n, m] of matchs.entries()) {
    for (const side of [0, 1]) {
      const t = m.tirs[side];
      const vus = m.events.filter(e => e.s.team === side && e.s.loi === 'drop-reussi').length, essais = m.events.filter(e => e.s.team === side && e.s.loi === 'drop-tente').length;
      if (t.d !== vus) fautes.push(`match ${n} : drops comptés ${t.d} ≠ ${vus} dans le journal`);
      if (t.da !== essais) fautes.push(`match ${n} : drops tentés comptés ${t.da} ≠ ${essais} dans le journal`);
      if (t.d > t.da || t.d > t.g || t.da > t.a) fautes.push(`match ${n} : compteurs de drops incohérents ${JSON.stringify(t)}`);
      drops += t.d; tentes += t.da;
    }
    if (!m.panneauTirs) fautes.push(`match ${n} : « Tirs de pénalité » affiché ≠ buts − drops / tirs − drops tentés`);
  }
  assert.ok(tentes >= 8 && drops >= 2, `assez de drops pour contrôler la ligne (${tentes} tentés, ${drops} réussis)`);
  assert.deepEqual(fautes.slice(0, 5), [], `${fautes.length} lignes « Tirs de pénalité » irrégulières`);
});
