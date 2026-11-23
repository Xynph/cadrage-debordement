'use strict';
// Mesure de la réussite au but (docs/penalites-au-but-20261123.md), carrière world-champ, moteur complet.
//
//   reels      : N rencontres de Top 14 (affiches du calendrier, vrais effectifs, IA contre IA) : chaque tir au but
//                (pénalité, transformation) avec sa distance, son angle, la note de but du buteur, la probabilité donnée
//                par goalChance et l'issue ; réussite par tranche de distance et par qualité de buteur ; points, essais,
//                choix sur pénalité (au but, pénaltouche, à la main) par match.
//   politiques : XV identiques (club de base copié des deux côtés), l'une des deux équipes avec une consigne sur pénalité
//                figée (« Chercher les points », « Chercher la pénaltouche »), l'autre en « Selon le contexte » ; domicile
//                alterné. Part de victoires de la consigne.
// Crochets en lecture seule (aucun tirage ajouté).
//
// Usage : node --max-old-space-size=1400 scripts/mesure-buteurs.cjs [--reels=400] [--politiques=300]
//         [--parties=reels,politiques] [--liste=points,touch,auto] [--contre=auto] [--json fichier]
// --contre : consigne de l'adversaire (auto par défaut ; points pour opposer directement pénaltouche et tirs au but).
const fs = require('node:fs');
const { context } = require('../tests/monde-harness.cjs');

const args = process.argv.slice(2);
const opt = (k, d) => { const a = args.find(x => x.startsWith(`--${k}=`)); return a ? a.slice(k.length + 3) : d; };
const N = { reels: +opt('reels', 400), politiques: +opt('politiques', 300) };
const parties = opt('parties', 'reels,politiques').split(',');
const liste = opt('liste', 'points,touch').split(',');
const json = opt('json', null), contre = opt('contre', 'auto');

const VM = String.raw`globalThis.__mesureButeurs=function(o){
 const fixtures=S.worldMode.fixtures.filter(f=>f.competitionId==='elite'&&f.phase==='league');
 let x=o.graine>>>0;const alea=()=>{x=(Math.imul(x,1664525)+1013904223)>>>0;return x/4294967296};
 const gc=goalChance,ngk=noteGoalKick,epc=executePenaltyChoice;
 const jouer=(pair,f,regler,chaquePas)=>{S.worldMode.fixtures.push(f);const tirs=[],choix=[[0,0,0],[0,0,0]],touches=[],bilans=[];let attente=null,suivi=null;const fenetres=[];
  goalChance=function(l,side,conversion=false,tryY=35){const p=gc.apply(this,arguments),k=goalKicker(l,side),g=goalKickGeometry(conversion,arguments.length>3?tryY:35,l.territory,side);
   attente={side,conv:conversion?1:0,d:Math.round(g.distance*10)/10,a:Math.round(g.angle*100)/100,note:k?skill(k,'goal'):null,p:Math.round(p*1000)/1000};return p};
  noteGoalKick=function(l,side,ok){if(attente&&attente.side===side){attente.ok=ok?1:0;tirs.push(attente)}attente=null;return ngk.apply(this,arguments)};
  executePenaltyChoice=function(l,side){const avant=l.stats[side].goalAttempts,ev=l.events.length,avantScore=l.score[side];const r=epc.apply(this,arguments);
   const k=l.stats[side].goalAttempts>avant?0:l.events.slice(ev).some(e=>/vite|rapide|à la main/i.test(e.text||''))?2:1;choix[side][k]++;if(k<2)fenetres.push({k,side,d:side===0?100-l.territory:l.territory,fin:l.minute+o.fenetre,net:l.score[side]-l.score[1-side]-(k===0?l.score[side]-avantScore:0)});if(k===1&&!suivi)suivi={side,pts:l.score[side]-0,tries:l.tries[side],n:0,d:side===0?100-l.territory:l.territory};return r};
  let l;try{l=createRugbyMatch(pair,null,true);if(regler)regler(l);for(let n=0;!l.finished&&n<700;n++){l.paused=false;if(chaquePas)chaquePas(l);advanceRugby(l);
   /* Bilan net (points marqués moins encaissés, le tir compris) sur les « fenetre » minutes qui suivent le choix. */
   for(let i=fenetres.length-1;i>=0;i--){const w=fenetres[i];if(l.minute>=w.fin||l.finished){bilans.push([w.k,l.score[w.side]-l.score[1-w.side]-w.net,w.d]);fenetres.splice(i,1)}}
   /* Suite d'une pénaltouche : points marqués avant que le ballon change de camp (essai, pénalité ou transformation compris). */
   if(suivi&&(l.score[suivi.side]!==suivi.pts||l.possession!==suivi.side||l.finished||++suivi.n>60)){touches.push([l.score[suivi.side]-suivi.pts,l.tries[suivi.side]-suivi.tries,suivi.d]);suivi=null}}}
  finally{goalChance=gc;noteGoalKick=ngk;executePenaltyChoice=epc;S.worldMode.fixtures.splice(S.worldMode.fixtures.indexOf(f),1)}
  return{score:l.score,tries:l.tries,goals:l.stats.map(s=>s.goals),goalAttempts:l.stats.map(s=>s.goalAttempts),conv:l.stats.map(s=>s.conversions),convAtt:l.stats.map(s=>s.conversionAttempts),tirs,choix,touches,bilans};};
 const out=[];
 if(o.partie==='reels'){
  for(let i=0;i<o.n;i++){const g=fixtures[Math.floor(alea()*fixtures.length)];
   for(const id of [g.homeId,g.awayId]){CDFranceCareer.ensureAISheet(S.clubs[id]);for(const p of S.clubs[id].players){p.condition=100;p.injury=0;p.suspension=0}}
   const f={...g,id:'buteurs-'+i,week:S.round};out.push(jouer([g.homeId,g.awayId],f));}
 }else if(o.partie==='politiques'){
  const slots=[7,11],originals=slots.map(i=>S.clubs[i]),base=S.clubs[o.base],am=adaptManager;
  const copie=(slot,tag)=>{const c=JSON.parse(JSON.stringify(base)),s=originals[slots.indexOf(slot)];c.id=s.id;c.name=s.name;c.abbr=s.abbr;c.morale=75;for(const p of c.players){p.id=p.id+'#'+tag;p.condition=100;p.injury=0;p.suspension=0}return c};
  adaptManager=()=>{};
  try{for(let i=0;i<o.n;i++){S.clubs[7]=copie(7,'a');S.clubs[11]=copie(11,'b');const testDom=i%2===0,pair=testDom?[7,11]:[11,7],cote=testDom?0:1;
    const f={id:'buteurs-pol-'+i,week:S.round,date:fixtures[0].date,homeId:pair[0],awayId:pair[1],competitionId:'elite',phase:'league',round:1,neutral:false};
    const pol=()=>{const p=[o.contre,o.contre];p[cote]=o.politique;return p};
    const r=jouer(pair,f,l=>{l.tactics=['equilibre','equilibre'];l.defences=['equilibre','equilibre'];l.penaltyPolicies=pol()},l=>{l.penaltyPolicies=pol()});r.cote=cote;out.push(r)}}
  finally{adaptManager=am;slots.forEach((i,j)=>{S.clubs[i]=originals[j]})}
 }
 return JSON.stringify(out);
};`;

const moy = a => a.length ? a.reduce((s, v) => s + v, 0) / a.length : NaN;
const r1 = v => Math.round(v * 10) / 10, r2 = v => Math.round(v * 100) / 100;
const pc = (ok, n) => n ? r1(100 * ok / n) : null;
const TRANCHES_DISTANCE = [['près (< 30 m)', 0, 30], ['moyen (30-40 m)', 30, 40], ['loin (≥ 40 m)', 40, 1e9]];
const TRANCHES_NOTE = [['note < 65', -1e9, 65], ['65-74', 65, 75], ['75-84', 75, 85], ['85 et plus', 85, 1e9]];
const TRANCHES_ANGLE = [['face (< 0,3 rad)', 0, .3], ['biais (0,3-0,7)', .3, .7], ['coin (≥ 0,7)', .7, 9]];
function table(tirs, tranches, cle) {
  return tranches.map(([nom, a, b]) => { const t = tirs.filter(k => k[cle] != null && k[cle] >= a && k[cle] < b);
    return { tranche: nom, tirs: t.length, reussite: pc(t.filter(k => k.ok).length, t.length), attendu: t.length ? r1(100 * moy(t.map(k => k.p))) : null }; });
}
function resumeReels(m) {
  const tirs = m.flatMap(x => x.tirs), pen = tirs.filter(k => !k.conv), tr = tirs.filter(k => k.conv);
  const ch = [0, 1, 2].map(k => m.reduce((s, x) => s + x.choix[0][k] + x.choix[1][k], 0)), tot = ch[0] + ch[1] + ch[2];
  const pres = pen.filter(k => k.d < 30);
  const touches = m.flatMap(x => x.touches || []);
  const bilans = m.flatMap(x => x.bilans || []);
  return {
    matchs: m.length,
    points: r1(moy(m.map(x => x.score[0] + x.score[1]))), essais: r2(moy(m.map(x => x.tries[0] + x.tries[1]))),
    penalitesTentees: r2(moy(m.map(x => x.goalAttempts[0] + x.goalAttempts[1]))), penalitesReussies: r2(moy(m.map(x => x.goals[0] + x.goals[1]))),
    choixAuBut: pc(ch[0], tot), choixTouche: pc(ch[1], tot), choixMain: pc(ch[2], tot),
    pointsParTir: r2(3 * pen.filter(k => k.ok).length / Math.max(1, pen.length)), pointsParTouche: r2(moy(touches.map(t => t[0]))), essaiParTouche: pc(touches.filter(t => t[1] > 0).length, touches.length),
    pointsParToucheProche: r2(moy(touches.filter(t => t[2] < 30).map(t => t[0]))), bilanProcheAuBut: r2(moy(bilans.filter(b => b[0] === 0 && b[2] < 30).map(b => b[1]))), bilanProcheTouche: r2(moy(bilans.filter(b => b[0] === 1 && b[2] < 30).map(b => b[1]))),
    bilan10minAuBut: r2(moy(bilans.filter(b => b[0] === 0).map(b => b[1]))), bilan10minTouche: r2(moy(bilans.filter(b => b[0] === 1).map(b => b[1]))),
    reussiteGlobale: pc(tirs.filter(k => k.ok).length, tirs.length), reussitePenalites: pc(pen.filter(k => k.ok).length, pen.length), reussiteTransfos: pc(tr.filter(k => k.ok).length, tr.length),
    penalitesDistance: table(pen, TRANCHES_DISTANCE, 'd'), penalitesNote: table(pen, TRANCHES_NOTE, 'note'), penalitesPresNote: table(pres, TRANCHES_NOTE, 'note'),
    penalitesAngle: table(pen, TRANCHES_ANGLE, 'a'), transfosAngle: table(tr, TRANCHES_ANGLE, 'a'), transfosNote: table(tr, TRANCHES_NOTE, 'note'),
  };
}
function resumePolitique(politique, m) {
  const v = moy(m.map(x => { const a = x.score[x.cote], b = x.score[1 - x.cote]; return a > b ? 1 : a === b ? 0.5 : 0; }));
  return { politique, matchs: m.length, victoires: r1(100 * v), points: r1(moy(m.map(x => x.score[x.cote]))), encaisses: r1(moy(m.map(x => x.score[1 - x.cote]))),
    essais: r2(moy(m.map(x => x.tries[x.cote]))), tentees: r2(moy(m.map(x => x.goalAttempts[x.cote]))),
    reussite: pc(m.reduce((s, x) => s + x.goals[x.cote], 0), m.reduce((s, x) => s + x.goalAttempts[x.cote], 0)),
    bilanAuBut: r2(moy(m.flatMap(x => x.bilans).filter(b => b[0] === 0 && b[2] < 53).map(b => b[1]))), bilanTouche: r2(moy(m.flatMap(x => x.bilans).filter(b => b[0] === 1 && b[2] < 53).map(b => b[1]))) };
}
const imprimer = (titre, lignes) => { console.log(titre + '\ntranche | tirs | réussite % | attendu %'); for (const t of lignes) console.log([t.tranche, t.tirs, t.reussite, t.attendu].join(' | ')); };

const resultat = { ref: process.env.GITHUB_SHA || null, N };
const h = context(20261123);
try {
  h.start(102); h.run(VM);
  const cp = h.checkpoint();
  if (parties.includes('reels')) {
    h.restore(cp);
    const m = JSON.parse(h.run(`__mesureButeurs(${JSON.stringify({ partie: 'reels', n: N.reels, graine: 4242, fenetre: 10 })})`, 3600000));
    const r = resultat.reels = resumeReels(m);
    console.log('## Top 14, vrais effectifs, IA contre IA');
    console.log(JSON.stringify({ matchs: r.matchs, points: r.points, essais: r.essais, penalitesTentees: r.penalitesTentees, penalitesReussies: r.penalitesReussies,
      choixAuBut: r.choixAuBut, choixTouche: r.choixTouche, choixMain: r.choixMain, pointsParTir: r.pointsParTir, pointsParTouche: r.pointsParTouche, essaiParTouche: r.essaiParTouche, bilan10minAuBut: r.bilan10minAuBut, bilan10minTouche: r.bilan10minTouche, pointsParToucheProche: r.pointsParToucheProche, bilanProcheAuBut: r.bilanProcheAuBut, bilanProcheTouche: r.bilanProcheTouche, reussiteGlobale: r.reussiteGlobale, reussitePenalites: r.reussitePenalites, reussiteTransfos: r.reussiteTransfos }));
    imprimer('### Pénalités par distance', r.penalitesDistance);
    imprimer('### Pénalités par note de but du buteur', r.penalitesNote);
    imprimer('### Pénalités de près (< 30 m) par note', r.penalitesPresNote);
    imprimer('### Pénalités par angle', r.penalitesAngle);
    imprimer('### Transformations par angle', r.transfosAngle);
    imprimer('### Transformations par note', r.transfosNote);
  }
  if (parties.includes('politiques')) {
    resultat.politiques = [];
    for (const politique of liste) {
      h.restore(cp);
      const m = JSON.parse(h.run(`__mesureButeurs(${JSON.stringify({ partie: 'politiques', n: N.politiques, politique, contre, base: 4, graine: 1, fenetre: 10 })})`, 3600000));
      resultat.politiques.push(resumePolitique(politique, m));
    }
    console.log('## Consigne sur pénalité contre « ' + contre + ' » (XV identiques)\nconsigne | matchs | victoires % | points | encaissés | essais | tentées | réussite % | bilan 10 min au but | bilan 10 min touche (tirs à moins de 53 m, deux camps)');
    for (const s of resultat.politiques) console.log([s.politique, s.matchs, s.victoires, s.points, s.encaisses, s.essais, s.tentees, s.reussite, s.bilanAuBut, s.bilanTouche].join(' | '));
  }
} finally { h.close(); }
if (json) fs.writeFileSync(json, JSON.stringify(resultat, null, 1));
