'use strict';
// Plantage de la causerie d'avant-match (« Causerie de match incohérente : contexte réel de la phase », coup d'envoi
// refusé ou simulation arrêtée) : le pronostic figé au coup d'envoi (observe) devait rester égal à celui que la validation
// recalcule en fin de commande. Il ne l'était pas quand le Niveau d'un joueur de la feuille bougeait ENTRE les deux :
//  1. un joueur de complément (youth-…, sans attributesV2) voit ses qualités détaillées dérivées de ses compétences ;
//     skill() contient le modificateur de PILOTAGE du match (confiance, nervosité : transitoire, nul avant le coup
//     d'envoi, -3 ou -5 après), compté comme une progression en fin de commande et écrit pour de bon dans ses qualités ;
//  2. toute autre entrée du pronostic qui bouge avant la validation (progression de la séance lancée par le coup d'envoi,
//     condition, composition modifiée avant la causerie) : la causerie en attente suit désormais le contexte réel.
// Graine 2026 saison 3 (tour 27, joueur youth-23-1-60051 : Niveau 64 → 61, écart -3,18 → -2,98, outsider → rien).
const assert = require('node:assert/strict'), vm = require('node:vm'), fs = require('node:fs'), path = require('node:path');
const domain = require('../native/engine/match-talks.cjs');
const { ouvrir, creer, jusquAuMatch } = require('./helpers/carriere-monde.cjs');
const { skipMatchTalk } = require('./helpers/scene-match-talks.cjs');
const clone = x => JSON.parse(JSON.stringify(x));

// --- 1. Mécanisme isolé (VM minimale) : la causerie en attente suit le contexte réel jusqu'à la fin de la commande.
function essai() {
  const mine = Array.from({ length: 25 }, (_, i) => ({ id: 'p' + i, fam: i < 8 ? 3 : 6, age: 24, rating: 70, attr: 70 }));
  const adv = Array.from({ length: 15 }, (_, i) => ({ id: 'adv' + i, fam: i < 8 ? 3 : 6, age: 25, rating: 70, attr: 70 }));
  const state = { season: 1, round: 0, phase: 'league', club: 0, morale: 75, economy: { week: 0 }, clubs: [{ id: 0, players: mine }, { id: 1, players: adv }], live: null };
  const ctx = vm.createContext({ S: state, JSON, Math, Set, Map, console });
  vm.runInContext(`
    var RELACHEMENT={seuil:3,intentions:[]};
    function niveauMatch(p){return p.attr!==undefined?p.attr:p.rating;}
    function teamLevel(ps){return ps.reduce((a,p)=>a+niveauMatch(p),0)/ps.length;}
    function activePlayers(l,side){const byId=new Map(S.clubs[l.pair[side]].players.map(p=>[p.id,p]));return l.sheets[side].on.map(id=>byId.get(id));}
    function atHalftime(l){return !!l.flow.atBreak;}
    function tick(){}
    function continueMatch(){S.live.paused=false;}
    function finishRound(){S.live=null;}
  `, ctx);
  vm.runInContext(fs.readFileSync(path.join(__dirname, '../dist/native-scene-dialogues.js'), 'utf8'), ctx);
  vm.runInContext(fs.readFileSync(path.join(__dirname, '../dist/match-pilotage.js'), 'utf8'), ctx);
  vm.runInContext(`var talks=(${domain.factory.toString()})();talks.installHooks();`, ctx);
  const run = src => vm.runInContext(src, ctx);
  const ids = players => players.slice(0, 15).map(p => p.id);
  state.live = { pair: [0, 1], userSide: 0, minute: 0, score: [0, 0], finished: false, paused: false, flow: { atBreak: false },
    sheets: [{ initial: ids(mine), bench: mine.slice(15, 23).map(p => p.id), on: ids(mine) }, { initial: ids(adv), bench: [], on: ids(adv) }] };
  return { state, run, talks: (name, ...args) => { ctx.args = args; return clone(run('talks.' + name + '(...args)') ?? null); } };
}

{
  const t = essai();
  t.talks('observe', 'begin_match');
  assert.equal(t.state.contextualMatch.current.phases[0].context.pronostic, undefined, 'départ : niveaux égaux, aucun favori');
  // Fin de la même commande : les qualités des 15 titulaires bougent (ici +5 : une progression de séance, un Niveau
  // dérivé autrement) AVANT la validation. Le worker règle ensuite la causerie en attente (settle) puis valide.
  for (const p of t.state.clubs[0].players) p.attr += 5;
  assert.throws(() => t.talks('validate', t.state), /contexte réel de la phase/u, 'sans réglage de fin de commande, la validation voit un autre pronostic');
  assert.equal(t.talks('settle'), true, 'le contexte en attente est recalculé');
  assert.doesNotThrow(() => t.talks('validate', t.state), 'après le réglage de fin de commande, le pronostic est celui que la validation recalcule');
  assert.equal(t.state.contextualMatch.current.phases[0].context.pronostic, 'favorite', '+5 de Niveau : favori');
  assert.equal(t.talks('settle'), false, 'rien à régler une seconde fois');

  // Composition modifiée avant la causerie (remplacement au coup d'envoi) : même chose.
  const u = essai();
  u.talks('observe', 'begin_match');
  u.state.live.sheets[0].on[0] = 'p20'; u.state.clubs[0].players[20].attr = 40;
  u.state.clubs[0].players.slice(0, 15).forEach(p => { p.attr = 70; });
  for (let i = 0; i < 15; i++) u.state.clubs[1].players[i].attr = 80;
  assert.equal(u.talks('settle'), true);
  assert.doesNotThrow(() => u.talks('validate', u.state));
  assert.equal(u.state.contextualMatch.current.phases[0].context.pronostic, 'underdog');

  // Causerie décidée ou passée : son contexte est archivé, plus recalculé.
  const v = essai();
  v.talks('observe', 'begin_match');
  v.state.contextualMatch.current.phases[0].closed = true;
  v.state.clubs[0].players.forEach(p => { p.attr += 9; });
  assert.equal(v.talks('settle'), false, 'phase close : contexte laissé tel quel');
}
console.log('Causerie d\'avant-match : contexte en attente réglé en fin de commande (mécanisme isolé) PASS.');

// --- 2. Carrière réelle : le modificateur de pilotage ne s'écrit pas dans les qualités d'un joueur de complément.
{
  const jeu = ouvrir({ testVm: true, hebdomadaire: true, rapide: true, seed: 2026 });
  try {
    creer(jeu, 29);
    const run = src => jeu.bridge.vm.run(src);
    // Un joueur du club sans attributesV2 (comme les joueurs de complément youth-…) : qualités dérivées de ses compétences.
    run(`{const p=S.clubs[S.club].players[0];delete p.attributesV2;delete p.nativeAttributesV1;nativeAttributeStore.complete(S);}`);
    const avant = run('S.clubs[S.club].players[0].nativeAttributesV1');
    assert.match(avant, /^\d{72}$/u, 'qualités dérivées posées');
    // Début de commande, puis un match en cours dont le pilotage retranche 3 à toutes les compétences du joueur.
    run('globalThis.__bl=nativeAttributeStore.before(S,false,false);globalThis.__pm=pilotageSkillMod;pilotageSkillMod=()=>-3;');
    run('nativeAttributeStore.complete(S,__bl,false)');
    const apres = run('S.clubs[S.club].players[0].nativeAttributesV1');
    run('pilotageSkillMod=__pm;');
    assert.equal(apres, avant, 'un modificateur de match transitoire n\'est pas une progression du joueur');
  } finally { jeu.fermer(); }
  console.log('Causerie d\'avant-match : qualités des joueurs de complément insensibles au pilotage du match PASS.');
}

// --- 3. Carrière réelle : un remplacement avant la causerie ne fait pas refuser la commande ; la causerie suit la feuille.
{
  const jeu = ouvrir({ testVm: true, hebdomadaire: true, seed: 2026 });
  try {
    let model = creer(jeu, 29);
    model = jusquAuMatch(jeu, model);
    model = jeu.regler(model);
    if (!model.selection.valid) model = jeu.call('auto_lineup');
    const depart = jeu.brut('begin_match');
    assert.equal(depart.ok, true, 'begin_match : ' + depart.error);
    const run = src => jeu.bridge.vm.run(src);
    assert.ok(run('S.contextualMatch.current.phases[0].phase') === 'pre' && run('!S.contextualMatch.current.phases[0].closed'), 'causerie d\'avant-match en attente');
    // Ma feuille bien reposée, l'adversaire à bout : l'écart de Niveau passe nettement en notre faveur avant le remplacement.
    run(`{const l=S.live;activePlayers(l,l.userSide).forEach(p=>{p.condition=100});activePlayers(l,1-l.userSide).forEach(p=>{p.condition=10});}`);
    const pairs = JSON.parse(run(`JSON.stringify((()=>{const l=S.live,sh=l.sheets[l.userSide],ps=new Map(S.clubs[S.club].players.map(p=>[p.id,p]));const out=[];
      sh.on.forEach((id,slot)=>sh.bench.forEach(b=>{if(ps.get(id)&&ps.get(b)&&ps.get(id).pos===ps.get(b).pos)out.push([slot,b,id]);}));return out;})())`));
    assert.ok(pairs.length, 'un remplaçant au même poste');
    let remplace = false;
    for (const [slot, inId] of pairs) {
      const r = jeu.brut('substitute', { slot, inId });
      assert.equal(r.ok, true, 'remplacement avant la causerie : ' + r.error);
      if (run(`S.live.sheets[S.live.userSide].on[${slot}]`) === inId) { remplace = true; break; }
    }
    assert.ok(remplace, 'un remplacement a eu lieu');
    assert.equal(run('S.contextualMatch.current.phases[0].context.pronostic'), 'favorite', 'la causerie en attente suit la feuille et l\'état réels');
    skipMatchTalk(jeu.call('snapshot'), jeu.call);
  } finally { jeu.fermer(); }
  console.log('Causerie d\'avant-match : remplacement avant la causerie accepté, pronostic à jour PASS.');
}
