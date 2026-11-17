'use strict';
// La météo pèse sur le match (docs/meteo-match-20261116.md) en carrière Monde (world-champ, club 102) :
// matchs IA contre IA à graine fixe, même affiche jouée par temps sec, sous la pluie (forte, terrain lourd),
// par grand vent et par forte chaleur. Mesure en-avant, réussite au but, essais, mêlées, jeu au pied,
// essais sur ballon porté, condition en fin de match ; vérifie des écarts modérés, le déterminisme,
// la compatibilité des rencontres commencées avant et la validation de la sauvegarde.
const test = require('node:test');
const assert = require('node:assert/strict');
const {context} = require('./monde-harness.cjs');

const shared = context(827381, {club: 102, console: false}).toMatch(), base = shared.checkpoint();
test.after(() => shared.close());
const setup = () => shared.restore(base);
const N = 160;

// `temps` : null = météo tirée par le moteur ; sinon {weather, meteo} imposés juste après la création.
const SIMULER = `var simuler=(n,temps,regles)=>{const fx=CDWorldCareer.fixtures(S).filter(f=>f.homeId!==S.club&&f.awayId!==S.club),rng=Math.random,avant=WEATHER_RULES;
 const acc={matchs:0,enAvant:0,buts:0,butsTentes:0,essais:0,essaisPortes:0,melees:0,pieds:0,points:0,condition:0,joueurs:0,metres:0,avancees:0,signature:[]};
 WEATHER_RULES=regles;
 try{for(let k=0;k<n;k++){const f=fx[k%fx.length];let x=(k*2654435761+7)>>>0;
  Math.random=()=>{x=(Math.imul(x,1664525)+1013904223)>>>0;return x/4294967296};
  for(const id of [f.homeId,f.awayId])CDFranceCareer.ensureAISheet(S.clubs[id]);
  const snap=[f.homeId,f.awayId].flatMap(id=>S.clubs[id].players.map(p=>[p,p.condition,p.injury]));
  const l=createRugbyMatch([f.homeId,f.awayId],null,true);
  if(temps){l.weather=temps.weather;if(l.weatherVersion===1)l.meteo={...temps.meteo}}
  for(let g=0;!l.finished&&g<600;g++){l.paused=false;advanceRugby(l)}
  for(let s=0;s<2;s++){const t=l.tacticalStats?.[s]||{};acc.enAvant+=t.handErrors||0;acc.pieds+=t.kicks||0;acc.metres+=t.metres||0;acc.avancees+=t.advances||0;const st=l.stats[s];acc.buts+=st.goals+st.conversions;acc.butsTentes+=st.goalAttempts+st.conversionAttempts;acc.melees+=st.scrums;for(const p of activePlayers(l,s)){acc.condition+=p.condition;acc.joueurs++}}
  acc.essais+=l.tries[0]+l.tries[1];acc.essaisPortes+=l.events.filter(e=>/Essai.*sur (ballon porté|mêlée)/.test(e.text||'')).length;acc.points+=l.score[0]+l.score[1];acc.matchs++;
  acc.signature.push(l.score.join('-')+':'+l.events.length+':'+(l.weatherVersion||0)+':'+l.weather+':'+JSON.stringify(l.meteo||null));
  for(const [p,c,i] of snap){p.condition=c;p.injury=i}}}
 finally{Math.random=rng;WEATHER_RULES=avant}
 return acc};`;
const simuler = (h, n, temps, regles = 1) => JSON.parse(h.run(SIMULER + `JSON.stringify(simuler(${n},${JSON.stringify(temps)},${regles}))`));
const resume = a => ({
  enAvant: +(a.enAvant / a.matchs).toFixed(1), butPct: +(100 * a.buts / a.butsTentes).toFixed(1),
  essais: +(a.essais / a.matchs).toFixed(2), essaisPortes: +(a.essaisPortes / a.matchs).toFixed(2),
  melees: +(a.melees / a.matchs).toFixed(1), pieds: +(a.pieds / a.matchs).toFixed(1),
  points: +(a.points / a.matchs).toFixed(1), condition: +(a.condition / a.joueurs).toFixed(1),
  metresParAvancee: +(a.metres / Math.max(1, a.avancees)).toFixed(1)
});
const SEC = {weather: 'Sec', meteo: {pluie: 0, vent: 0, chaleur: 0, terrain: 'souple'}};
const PLUIE = {weather: 'Pluie', meteo: {pluie: 2, vent: 0, chaleur: 0, terrain: 'lourd'}};
const VENT = {weather: 'Vent', meteo: {pluie: 0, vent: 2, chaleur: 0, terrain: 'souple'}};
const CHALEUR = {weather: 'Sec', meteo: {pluie: 0, vent: 0, chaleur: 1, terrain: 'souple'}};

test('Sec, pluie forte, grand vent, chaleur : écarts crédibles et modérés (même affiches, même graine)', () => {
  const r = {sec: resume(simuler(setup(), N, SEC)), pluie: resume(simuler(setup(), N, PLUIE)), vent: resume(simuler(setup(), N, VENT)), chaleur: resume(simuler(setup(), N, CHALEUR)),
    secAvant: resume(simuler(setup(), N, SEC, 0)), pluieAvant: resume(simuler(setup(), N, PLUIE, 0)), ventAvant: resume(simuler(setup(), N, VENT, 0))};
  console.log(JSON.stringify(r));
  const {sec, pluie, vent, chaleur} = r;
  // Pluie : plus d'en-avant et de mêlées, plus de jeu au pied, moins d'essais, au but un peu moins.
  assert.ok(pluie.enAvant > sec.enAvant * 1.15 && pluie.enAvant < sec.enAvant * 1.8, 'en-avant sous la pluie');
  assert.ok(pluie.melees > sec.melees * 1.08 && pluie.melees < sec.melees * 1.6, 'mêlées sous la pluie');
  assert.ok(pluie.pieds > sec.pieds * 1.1, 'jeu au pied sous la pluie');
  assert.ok(pluie.essais < sec.essais && pluie.essais > sec.essais * .6, 'essais sous la pluie : moins, sans effondrement');
  assert.ok(pluie.essaisPortes >= sec.essaisPortes, 'ballon porté et mêlée favorisés sous la pluie');
  assert.ok(pluie.butPct < sec.butPct && pluie.butPct > sec.butPct - 10, 'au but sous la pluie');
  assert.ok(pluie.metresParAvancee < sec.metresParAvancee, 'terrain lourd : moins de mètres par avancée');
  // Vent fort : réussite au but nettement en baisse, mais pas d'effondrement ; jeu au courant presque inchangé.
  assert.ok(vent.butPct < sec.butPct - 4 && vent.butPct > sec.butPct - 16, 'au but par grand vent');
  assert.ok(Math.abs(vent.enAvant - sec.enAvant) < sec.enAvant * .12, 'en-avant presque inchangés par le vent');
  // Chaleur : fatigue un peu plus rapide (condition de fin de match plus basse), le reste proche.
  assert.ok(chaleur.condition < sec.condition - 1 && chaleur.condition > sec.condition - 8, 'chaleur : condition finale');
  assert.ok(Math.abs(chaleur.essais - sec.essais) < sec.essais * .2, 'chaleur : essais proches');
});

test('Météo tirée par le moteur : déterministe, sans tirage supplémentaire, intensités cohérentes avec l’étiquette', () => {
  const a = simuler(setup(), 24, null), b = simuler(setup(), 24, null);
  assert.deepEqual(a.signature, b.signature, 'même graine, mêmes matchs');
  for (const s of a.signature) {
    const [, , v, w, m] = s.split(':'), meteo = JSON.parse(s.slice(s.indexOf('{')));
    assert.equal(v, '1');
    if (w === 'Pluie') assert.ok(meteo.pluie >= 1 && meteo.vent === 0, s);
    else if (w === 'Vent') assert.ok(meteo.vent >= 1 && meteo.pluie === 0, s);
    else assert.ok(meteo.pluie === 0 && meteo.vent === 0 && meteo.terrain === 'souple', s);
    assert.equal(meteo.terrain === 'lourd', meteo.pluie === 2, s);
    void m;
  }
  // Option coupée : même étiquette tirée (aucun tirage ajouté), aucune version ni intensité.
  const c = simuler(setup(), 24, null, 0);
  c.signature.forEach((s, i) => {assert.ok(s.endsWith(':0:' + a.signature[i].split(':')[3] + ':null'), s)});
});

test('Rencontre commencée sans la version : anciennes règles ; sauvegarde validée', () => {
  const s = setup();
  s.run(`var lv=(function(){const fx=CDWorldCareer.fixtures(S).find(f=>f.homeId!==S.club&&f.awayId!==S.club);for(const id of [fx.homeId,fx.awayId])CDFranceCareer.ensureAISheet(S.clubs[id]);return createRugbyMatch([fx.homeId,fx.awayId],null,true)})()`);
  assert.equal(s.run('lv.weatherVersion'), 1);
  const r = JSON.parse(s.run(`(function(){lv.weather='Vent';lv.meteo={pluie:0,vent:2,chaleur:0,terrain:'souple',sens:0};const nouveau=goalChance(lv,0,true,35);delete lv.weatherVersion;const vieux=goalChance(lv,0,true,35);lv.weatherVersion=1;return JSON.stringify({nouveau,vieux})})()`));
  assert.ok(r.nouveau > r.vieux, 'grand vent moins pénalisant que l’ancien forfait −16 points : ' + JSON.stringify(r));
  s.run('validateFlowState(lv)');
  s.run('lv.meteo.vent=7');
  assert.throws(() => s.run('validateFlowState(lv)'), /météo/i);
  s.run('lv.meteo.vent=2;lv.weatherVersion=2');
  assert.throws(() => s.run('validateFlowState(lv)'), /météo/i);
});
