'use strict';
// Plantage de la causerie d'avant-match (« contexte réel de la phase », pronostic différent à la validation) :
// le pronostic lit le Niveau calculé (niveauMatch), qui dépend des qualités détaillées ; un joueur de complément sans
// qualités (youth-…) n'en reçoit qu'en fin de commande (nativeAttributeStore.complete). Le pronostic figé au coup
// d'envoi doit donc être calculé APRÈS la pose des qualités, sinon la validation le recalcule autrement.
// Reproduit sur la carrière réelle : graine 2026 saison 1 (tour 6) et graine 4242 saison 3 (tour 3) ; ce test en
// isole le mécanisme, sans rejouer de saison (instantané : un adversaire dont un titulaire n'a pas encore de qualités).
const assert = require('node:assert/strict'), vm = require('node:vm'), fs = require('node:fs'), path = require('node:path');
const domain = require('../native/engine/match-talks.cjs');
const clone = x => JSON.parse(JSON.stringify(x));

function essai() {
  const mine = Array.from({ length: 25 }, (_, i) => ({ id: 'p' + i, fam: i < 8 ? 3 : 6, age: 24, rating: 70, attr: 70 }));
  // Adversaire : 15 titulaires de complément (youth-…) sans qualités : lus à leur note (55) tant que le moteur ne leur en
  // a pas posé, puis à leur Niveau calculé (70).
  const adv = Array.from({ length: 15 }, (_, i) => ({ id: 'youth-16-1-' + i, fam: i < 8 ? 3 : 6, age: 17, rating: 55 }));
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
    var nativeAttributeStore={complete(s,previous,liveOnly){for(const c of s.live.pair)for(const p of s.clubs[c].players)if(p.attr===undefined)p.attr=70;}};
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

const t = essai();
t.talks('observe', 'begin_match');
// Fin de la même commande : le moteur pose les qualités manquantes (nativeAttributeStore.complete), puis valide la carrière.
t.run('nativeAttributeStore.complete(S,null,true)');
assert.doesNotThrow(() => t.talks('validate', t.state), 'validation après la pose des qualités : le pronostic figé doit rester vrai');
assert.equal(t.state.contextualMatch.current.phases[0].context.pronostic, undefined, 'pronostic figé avec les qualités posées : aucun favori (écart nul)');
console.log("Causerie d'avant-match : pronostic figé avec les qualités détaillées déjà posées PASS.");
