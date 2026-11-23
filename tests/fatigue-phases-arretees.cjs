'use strict';
// Fatigue des phases arrêtées (docs/fatigue-phases-arretees-20261116.md) en carrière Monde (world-champ, club 102) :
// courbe de la compétence au but selon la condition, réussite au but par tranche de 10 minutes sur 300 matchs IA
// contre IA, jeu courant inchangé, déterminisme et compatibilité des rencontres commencées avant.
const test = require('node:test');
const assert = require('node:assert/strict');
const {context} = require('./monde-harness.cjs');

const shared = context(827381, {club: 102, console: false}).toMatch(), base = shared.checkpoint();
test.after(() => shared.close());
const setup = () => shared.restore(base);

// Affiches IA contre IA de la semaine (hors club du manager), graine fixe par match, conditions et blessures
// rétablies après chaque match. Pour chaque tentative au but : tranche de 10 minutes, probabilité, réussite
// (le tirage qui suit goalChance est celui du tir), condition et compétence au but du buteur.
// Seulement les tirs décidés par le buteur et son banc (consigne « auto ») : depuis le dilemme du bonus (#925), les clubs IA
// mènent ou courent après le score avec la consigne « prendre les points », qui tire de plus loin en fin de match (réussite
// 73,5 % au lieu de 74,7 % après la 70e). Ce choix de distance n'est pas de la fatigue et faussait la comparaison.
const SIMULER = `var simuler=(n,regles)=>{const fx=CDWorldCareer.fixtures(S).filter(f=>f.homeId!==S.club&&f.awayId!==S.club),rng=Math.random,avant=SET_PIECE_FATIGUE_RULES,gc=goalChance;
 const b=Array.from({length:9},()=>({n:0,p:0,ref:0,ok:0,cond:0,but:0})),acc={b,touches:0,touchesGagnees:0,points:0,matchs:0,signature:[]};let cur=null;
 goalChance=function(l,side){const p=gc.apply(this,arguments);if((l.penaltyPolicies?.[side]||'auto')!=='auto')return p;const k=chooseScorer(S.clubs[l.pair[side]],activePlayers(l,side).map(x=>x.id),l),i=Math.min(8,Math.floor(l.minute/10)),c=b[i];cur={i,p};c.n++;c.p+=p;c.ref+=goalChanceEstimate(l,side,35,35);c.cond+=k.condition;c.but+=skill(k,'goal',fitArrete(l));return p};
 SET_PIECE_FATIGUE_RULES=regles;
 try{for(let k=0;k<n;k++){const f=fx[k%fx.length];let x=(k*2654435761+1)>>>0;
  Math.random=()=>{x=(Math.imul(x,1664525)+1013904223)>>>0;const r=x/4294967296;if(cur){if(r<cur.p)b[cur.i].ok++;cur=null}return r};
  for(const id of [f.homeId,f.awayId])CDFranceCareer.ensureAISheet(S.clubs[id]);
  const snap=[f.homeId,f.awayId].flatMap(id=>S.clubs[id].players.map(p=>[p,p.condition,p.injury]));
  const l=createRugbyMatch([f.homeId,f.awayId],null,true);
  for(let g=0;!l.finished&&g<600;g++){l.paused=false;advanceRugby(l)}for(const [p,c,i] of snap){p.condition=c;p.injury=i}
  for(const st of l.stats){acc.touches+=st.lineouts;acc.touchesGagnees+=st.lineoutsWon}acc.points+=l.score[0]+l.score[1];acc.matchs++;
  acc.signature.push(l.score.join('-')+':'+l.events.length+':'+(l.setPieceFatigueVersion||0))}}
 finally{Math.random=rng;goalChance=gc;SET_PIECE_FATIGUE_RULES=avant}
 return acc};`;
const simuler = (h, n, regles) => JSON.parse(h.run(SIMULER + `JSON.stringify(simuler(${n},${regles}))`));
const tranches = a => a.b.map((c, i) => ({tranche: `${i * 10}-${i * 10 + 9}`, tentatives: c.n, reussite: +(100 * c.ok / c.n).toFixed(1), probabilite: +(100 * c.p / c.n).toFixed(1), reference: +(100 * c.ref / c.n).toFixed(1), condition: +(c.cond / c.n).toFixed(1), but: +(c.but / c.n).toFixed(1)}));
// Probabilité moyenne de réussite du buteur en jeu sur un tir de référence (pénalité face aux poteaux à 35 m : fatigue,
// mental et météo, sans le mélange des tirs) sur un groupe de tranches. Depuis la réussite au but recalée
// (docs/penalites-au-but-20261123.md), distance et angle pèsent nettement : la probabilité des tirs réels baisse de ~3 points
// après la 60e parce que les tirs y sont un peu plus longs et moins souvent des transformations, pas par fatigue.
const proba = (a, ids) => {const c = ids.map(i => a.b[i]); return 100 * c.reduce((s, x) => s + x.ref, 0) / c.reduce((s, x) => s + x.n, 0)};
const reussite = a => 100 * a.b.reduce((s, x) => s + x.ok, 0) / a.b.reduce((s, x) => s + x.n, 0);

test('Courbe : la compétence au but ne s’effondre plus avec la fatigue ; le jeu courant garde la sienne', () => {
  const h = setup();
  // Échantillon : les cinq meilleurs buteurs du championnat du club, compétence nue.
  const courbe = JSON.parse(h.run(`(function(){const c=S.clubs[S.club],ps=CDWorldCareer.fixtures(S).flatMap(f=>[f.homeId,f.awayId]).flatMap(id=>S.clubs[id].players).sort((a,b)=>skill(b,'goal')-skill(a,'goal')||String(a.id).localeCompare(String(b.id))).slice(0,5);
   return JSON.stringify(ps.map(p=>{const c0=p.condition,r={nu:skill(p,'goal'),points:[]};for(const cond of [100,90,80,70,60,50,40,30,20,11,0]){p.condition=cond;r.points.push({cond,avant:+skill(p,'goal',true).toFixed(1),apres:+skill(p,'goal','arrete').toFixed(1),touche:+skill(p,'lineout','arrete').toFixed(1),toucheAvant:+skill(p,'lineout',true).toFixed(1),plaquage:skill(p,'tackle','arrete'),plaquageAvant:skill(p,'tackle',true)})}p.condition=c0;return r}))})()`));
  console.log(JSON.stringify(courbe.map(r => ({nu: r.nu, points: r.points.map(x => `${x.cond}:${x.avant}→${x.apres}`).join(' ')}))));
  for (const r of courbe) for (const x of r.points) {
    const perteAvant = r.nu - x.avant, perteApres = r.nu - x.apres;
    assert.ok(Math.abs(perteApres - .2 * perteAvant) < .15, `but : perte pondérée par 0,2 (${r.nu}, condition ${x.cond})`);
    assert.ok(x.apres >= .9 * r.nu - .1, `but : au plus 10 % de perte même à condition ${x.cond}`);
    assert.ok(x.touche >= x.toucheAvant, 'touche : jamais plus pénalisée qu’avant');
    assert.equal(x.plaquage, x.plaquageAvant, 'jeu courant (plaquage) : fatigue inchangée');
  }
  // Cas signalé : un buteur à 97 à condition 11 tombait à 54 ; il reste à 88.
  const p97 = JSON.parse(h.run(`(function(){const p=S.clubs[S.club].players[0],s={...p.skills},c=p.condition;p.skills.goal+=97-skill(p,'goal');p.condition=11;const r=[skill(p,'goal'),skill(p,'goal',true),skill(p,'goal','arrete')];p.skills=s;p.condition=c;return JSON.stringify(r)})()`));
  assert.equal(p97[0], 97);
  assert.equal(Math.round(p97[1]), 54, 'ancienne règle');
  assert.equal(Math.round(p97[2]), 88, 'nouvelle règle');
});

test('Réussite au but par tranche de 10 minutes sur 300 matchs IA contre IA : presque stable en fin de match', () => {
  const h = setup();
  const apres = simuler(h, 300, 1), avant = simuler(setup(), 150, 0);
  console.log(JSON.stringify({apres: tranches(apres), avant: tranches(avant), reussite: [+reussite(avant).toFixed(1), +reussite(apres).toFixed(1)], pointsParMatch: [+(avant.points / avant.matchs).toFixed(1), +(apres.points / apres.matchs).toFixed(1)], touche: [+(100 * avant.touchesGagnees / avant.touches).toFixed(1), +(100 * apres.touchesGagnees / apres.touches).toFixed(1)]}));
  assert.equal(apres.matchs, 300);
  const baisseApres = proba(apres, [0, 1]) - proba(apres, [6, 7, 8]), baisseAvant = proba(avant, [0, 1]) - proba(avant, [6, 7, 8]);
  // Ordre de grandeur réel : réussite d'élite à peu près stable sur le match (légère baisse au plus).
  assert.ok(baisseApres >= 0 && baisseApres < 2, `légère baisse de la probabilité de réussite en fin de match : ${baisseApres.toFixed(2)} point(s)`);
  assert.ok(baisseApres < baisseAvant / 2, `baisse divisée par plus de deux (avant ${baisseAvant.toFixed(2)}, après ${baisseApres.toFixed(2)})`);
  // La compétence au but moyenne du buteur en fin de match reste à moins de 2 points du début.
  // Moyennes regroupées comme pour la probabilité ci-dessus (0-19 contre 60-79) : la tranche 70-79 seule (≈ 150 tirs)
  // bouge de plus de 2 points selon le buteur présent sur le terrain, sans rapport avec la fatigue (relevé du 20/11/2026).
  const but = ids => ids.reduce((s, i) => s + apres.b[i].but, 0) / ids.reduce((s, i) => s + apres.b[i].n, 0);
  assert.ok(but([0, 1]) - but([6, 7]) < 2, `compétence au but stable (${but([0, 1]).toFixed(1)} puis ${but([6, 7]).toFixed(1)})`);
  // Réussite globale dans l'ordre de grandeur de l'élite (environ 70 à 80 %), touche gagnée sur lancer : inchangée à 2 points près.
  assert.ok(reussite(apres) > 68 && reussite(apres) < 80, 'réussite au but ' + reussite(apres).toFixed(1));
  assert.ok(Math.abs(100 * apres.touchesGagnees / apres.touches - 100 * avant.touchesGagnees / avant.touches) < 2, 'touche');
});

test('Déterminisme, compatibilité des rencontres commencées et sauvegarde', () => {
  const h = setup();
  const a = simuler(h, 20, 1), b = simuler(setup(), 20, 1);
  assert.deepEqual(a.signature, b.signature, 'même graine, mêmes matchs');
  assert.ok(a.signature.every(s => s.endsWith(':1')), 'nouvelles rencontres : version 1');
  const ancien = simuler(setup(), 20, 0);
  assert.ok(ancien.signature.every(s => s.endsWith(':0')), 'option coupée : aucune version');
  // Une rencontre commencée sans la version garde exactement l'ancienne fatigue (but, touche, jeu courant).
  const r = JSON.parse(setup().run(`(function(){const fx=CDWorldCareer.fixtures(S).find(f=>f.homeId!==S.club&&f.awayId!==S.club);for(const id of [fx.homeId,fx.awayId])CDFranceCareer.ensureAISheet(S.clubs[id]);
   const l=createRugbyMatch([fx.homeId,fx.awayId],null,true);for(const p of activePlayers(l,0))p.condition=40;const v=l.setPieceFatigueVersion,lire=()=>[unit(l,0,'lineout'),unit(l,0,'tackle'),goalChance(l,0,true,5)];
   const nouveau=lire();delete l.setPieceFatigueVersion;const vieux=lire();SET_PIECE_FATIGUE_RULES=0;const l0=createRugbyMatch([fx.homeId,fx.awayId],null,true);SET_PIECE_FATIGUE_RULES=1;
   return JSON.stringify({v,nouveau,vieux,fit:fitArrete(l),v0:l0.setPieceFatigueVersion??null})})()`));
  assert.equal(r.v, 1);
  assert.equal(r.fit, true, 'sans version : règles d’origine');
  assert.equal(r.v0, null);
  assert.ok(r.nouveau[0] > r.vieux[0] && r.nouveau[2] > r.vieux[2], 'touche et but moins pénalisés avec la version : ' + JSON.stringify(r));
  assert.equal(r.nouveau[1], r.vieux[1], 'plaquage identique');
  // Sauvegarde (validation du déroulement de la rencontre) : la version 1 est acceptée, une autre valeur refusée.
  const s = setup();
  s.run(`var lv=(function(){const fx=CDWorldCareer.fixtures(S).find(f=>f.homeId!==S.club&&f.awayId!==S.club);for(const id of [fx.homeId,fx.awayId])CDFranceCareer.ensureAISheet(S.clubs[id]);return createRugbyMatch([fx.homeId,fx.awayId],null,true)})()`);
  assert.equal(s.run('lv.setPieceFatigueVersion'), 1);
  s.run('validateFlowState(lv)');
  s.run('lv.setPieceFatigueVersion=2');
  assert.throws(() => s.run('validateFlowState(lv)'), /fatigue des phases arrêtées/);
});
