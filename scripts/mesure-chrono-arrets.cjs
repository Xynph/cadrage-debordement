'use strict';
// Mesure du chrono des arrêts de jeu (docs/chrono-arrets-de-jeu-20261118.md), carrière world-champ, moteur complet.
//
//   reels   : N rencontres de Top 14 (affiches du calendrier, vrais effectifs, IA contre IA) : points, essais, pénalités,
//             cartons, actions de jeu par match, durée (minutes jouées, temps additionnel), temps entre l'action qui
//             marque et l'action suivante (pénalité réussie, essai), victoires à domicile, arrêts comptés par le chrono.
//   styles  : XV identiques (club de base copié des deux côtés), consignes figées : large, près (conquete), occupation
//             contre « Équilibré », domicile alterné. Part de victoires et points.
//   courbe  : banc de la courbe de niveau (tests/helpers/courbe-niveau.cjs) à 0 et +15 points : domicile, surprises.
//   bonus   : mené de 8 à la 60e et à la 72e (scripts/mesure-bonus-fin-de-match.cjs, situation « defensif ») : bonus défensif
//             selon la consigne (pénalités tentées ou pénaltouche).
// Crochets en lecture seule (aucun tirage ajouté).
//
// Usage : node --max-old-space-size=1400 scripts/mesure-chrono-arrets.cjs [--reels=600] [--styles=200] [--courbe=150]
//         [--bonus=400] [--parties=reels,styles,courbe,bonus] [--json fichier]
const fs = require('node:fs');
const { context } = require('../tests/monde-harness.cjs');
const B = require('../tests/helpers/courbe-niveau.cjs');

const args = process.argv.slice(2);
const opt = (k, d) => { const a = args.find(x => x.startsWith(`--${k}=`)); return a ? a.slice(k.length + 3) : d; };
const N = { reels: +opt('reels', 600), styles: +opt('styles', 200), courbe: +opt('courbe', 150), bonus: +opt('bonus', 400) };
const parties = opt('parties', 'reels,styles,courbe,bonus').split(',');
const json = opt('json', null);

const VM = String.raw`globalThis.__chronoMesure=function(o){
 const fixtures=S.worldMode.fixtures.filter(f=>f.competitionId==='elite'&&f.phase==='league');
 let x=o.graine>>>0;const alea=()=>{x=(Math.imul(x,1664525)+1013904223)>>>0;return x/4294967296};
 const jouer=(pair,f,regler)=>{S.worldMode.fixtures.push(f);const fpa=advanceFlowPlay,trace={actions:0,ecarts:{goal:[],try:[]},attente:null};
  advanceFlowPlay=function(l){const t=l.chrono?l.chrono.debut:(l.minute-1)*60;if(trace.attente){trace.ecarts[trace.attente.kind].push(t-trace.attente.t);trace.attente=null}
   const n0=l.events.length;fpa(l);trace.actions++;for(let i=n0;i<l.events.length;i++){if(l.events[i].type==='try'||l.events[i].type==='goal')trace.attente={kind:l.events[i].type,t}}};
  let l;try{l=createRugbyMatch(pair,null,true);if(regler)regler(l);for(let n=0;!l.finished&&n<700;n++){l.paused=false;advanceRugby(l)}}
  finally{advanceFlowPlay=fpa;S.worldMode.fixtures.splice(S.worldMode.fixtures.indexOf(f),1)}
  const fin=l.flow?(l.flow.firstEnd!=null?40+l.minute-l.flow.firstEnd:l.minute):l.minute;
  return{score:l.score,tries:l.tries,goals:l.stats.map(s=>s.goals),goalAttempts:l.stats.map(s=>s.goalAttempts),yellows:l.stats.map(s=>s.yellows||0),
   reds:l.sheets.map(s=>(s.redCards||[]).length+(s.sentOff||[]).length),penalties:l.stats.map(s=>s.penalties||0),actions:trace.actions,ecarts:trace.ecarts,
   firstEnd:l.flow?.firstEnd??null,fin,arrets:l.chrono?{...l.chrono.arrets}:null,chrono:l.chronoVersion===1};};
 const out=[];
 if(o.partie==='reels'){
  for(let i=0;i<o.n;i++){const g=fixtures[Math.floor(alea()*fixtures.length)];
   for(const id of [g.homeId,g.awayId]){CDFranceCareer.ensureAISheet(S.clubs[id]);for(const p of S.clubs[id].players){p.condition=100;p.injury=0;p.suspension=0}}
   const f={...g,id:'chrono-'+i,week:S.round};out.push(jouer([g.homeId,g.awayId],f));}
 }else if(o.partie==='styles'){
  const slots=[7,11],originals=slots.map(i=>S.clubs[i]),base=S.clubs[o.base],am=adaptManager;
  const copie=(slot,tag)=>{const c=JSON.parse(JSON.stringify(base)),s=originals[slots.indexOf(slot)];c.id=s.id;c.name=s.name;c.abbr=s.abbr;c.morale=75;for(const p of c.players){p.id=p.id+'#'+tag;p.condition=100;p.injury=0;p.suspension=0}return c};
  adaptManager=()=>{};
  try{for(let i=0;i<o.n;i++){S.clubs[7]=copie(7,'a');S.clubs[11]=copie(11,'b');const testDom=i%2===0,pair=testDom?[7,11]:[11,7],cote=testDom?0:1;
    const f={id:'chrono-style-'+i,week:S.round,date:fixtures[0].date,homeId:pair[0],awayId:pair[1],competitionId:'elite',phase:'league',round:1,neutral:false};
    const r=jouer(pair,f,l=>{l.tactics=['equilibre','equilibre'];l.defences=['equilibre','equilibre'];l.tactics[cote]=o.style});r.cote=cote;out.push(r)}}
  finally{adaptManager=am;slots.forEach((i,j)=>{S.clubs[i]=originals[j]})}
 }
 return JSON.stringify(out);
};`;

const moy = a => a.length ? a.reduce((s, v) => s + v, 0) / a.length : NaN;
const r1 = v => Math.round(v * 10) / 10, r2 = v => Math.round(v * 100) / 100;
const mmss = s => Number.isFinite(s) ? `${Math.floor(s / 60)} min ${String(Math.round(s % 60)).padStart(2, '0')}` : '—';

function resumeReels(m) {
  const somme = (f) => moy(m.map(f));
  const ecarts = k => m.flatMap(x => x.ecarts[k]);
  const arrets = {}; for (const x of m) for (const [k, v] of Object.entries(x.arrets || {})) arrets[k] = (arrets[k] || 0) + v;
  for (const k in arrets) arrets[k] = r1(arrets[k] / m.length / 60);
  return {
    matchs: m.length, chrono: m.some(x => x.chrono),
    points: r1(somme(x => x.score[0] + x.score[1])), essais: r2(somme(x => x.tries[0] + x.tries[1])),
    penalitesReussies: r2(somme(x => x.goals[0] + x.goals[1])), penalitesTentees: r2(somme(x => x.goalAttempts[0] + x.goalAttempts[1])),
    fautes: r1(somme(x => x.penalties[0] + x.penalties[1])), jaunes: r2(somme(x => x.yellows[0] + x.yellows[1])), rouges: r2(somme(x => x.reds[0] + x.reds[1])),
    domicile: r1(100 * somme(x => x.score[0] > x.score[1] ? 1 : x.score[0] === x.score[1] ? 0.5 : 0)),
    actions: r1(somme(x => x.actions)), dureeMinutes: r1(somme(x => x.fin)), premiereMiTemps: r1(moy(m.map(x => x.firstEnd).filter(v => v != null))),
    apresPenalite: mmss(moy(ecarts('goal'))), apresEssai: mmss(moy(ecarts('try'))), arretsMinutes: arrets,
  };
}
function resumeStyle(style, m) {
  const v = moy(m.map(x => { const a = x.score[x.cote], b = x.score[1 - x.cote]; return a > b ? 1 : a === b ? 0.5 : 0; }));
  return { style, matchs: m.length, victoires: r1(100 * v), points: r1(moy(m.map(x => x.score[x.cote]))), encaisses: r1(moy(m.map(x => x.score[1 - x.cote]))),
    essais: r2(moy(m.map(x => x.tries[x.cote]))), actions: r1(moy(m.map(x => x.actions))) };
}

const resultat = { ref: process.env.GITHUB_SHA || null, N };
const h = context(20261118);
try {
  h.start(102); h.run(VM); B.installer(h);
  const cp = h.checkpoint();
  if (parties.includes('reels')) {
    h.restore(cp);
    const m = JSON.parse(h.run(`__chronoMesure(${JSON.stringify({ partie: 'reels', n: N.reels, graine: 4242 })})`, 3600000));
    resultat.reels = resumeReels(m);
    console.log('## Top 14, vrais effectifs, IA contre IA\n' + JSON.stringify(resultat.reels, null, 1));
  }
  if (parties.includes('styles')) {
    resultat.styles = [];
    for (const style of ['equilibre', 'large', 'conquete', 'occupation']) {
      h.restore(cp);
      const m = JSON.parse(h.run(`__chronoMesure(${JSON.stringify({ partie: 'styles', n: N.styles, style, base: 4, graine: 1 })})`, 3600000));
      resultat.styles.push(resumeStyle(style, m));
    }
    console.log('## Styles contre « Équilibré » (XV identiques, consignes figées)\nstyle | matchs | victoires % | points | encaissés | essais | actions');
    for (const s of resultat.styles) console.log([s.style, s.matchs, s.victoires, s.points, s.encaisses, s.essais, s.actions].join(' | '));
  }
  if (parties.includes('courbe')) {
    h.restore(cp);
    const c = B.mesurer(h, { mode: 'complet', ecarts: [0, 15], n: N.courbe, base: 4, slots: [7, 11] });
    resultat.courbe = c.resumes.map(r => ({ k: r.k, n: r.n, victoiresFort: r1(100 * r.victoires), fortADomicile: r1(100 * r.aDomicile), fortExterieur: r1(100 * r.aExterieur), domicile: r1(100 * r.domicile), points: r1(r.points), essais: r2(r.essais) }));
    console.log('## Courbe de niveau (moteur complet)\n' + B.tableau('complet, club de base 4', c.resumes));
  }
} finally { h.close(); }
if (parties.includes('bonus')) {
  const { mesurer } = require('./mesure-bonus-fin-de-match.cjs');
  resultat.bonus = {};
  for (const minute of [60, 72]) {
    const r = resultat.bonus[minute] = mesurer({ n: N.bonus, minute, situations: ['defensif'] }).defensif;
    console.log(`## Mené de 8 à la ${minute}e (${N.bonus} fins de match par consigne)\nconsigne | V | N | D | BD | pts | essais + | essais − | actions`);
    for (const [id, t] of Object.entries(r)) console.log([id, t.victoire, t.nul, t.defaite, t.bonusDefensif, t.points, t.essaisMarques, t.essaisEncaisses, t.actions].join(' | '));
  }
}
if (json) fs.writeFileSync(json, JSON.stringify(resultat, null, 1));
