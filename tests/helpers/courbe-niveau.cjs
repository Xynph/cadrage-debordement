'use strict';
// Banc de la courbe de niveau (lot 0 du chantier « notes réalistes », 14/11/2026).
// Deux copies d'un même club Monde s'affrontent, l'une décalée de k points sur la note, la base
// des compétences, les 11 compétences et les 36 attributs (V2). Le domicile alterne d'un match à
// l'autre. On mesure, pour le moteur complet (createRugbyMatch + advanceRugby du vrai moteur natif)
// et pour le résultat rapide (CDLeagueDetail.simulate), la part de victoires du plus fort, l'avantage
// du terrain et les scores. Carrière world-champ (tests/monde-harness.cjs), aucun ancien mode.
// Utilisé par tests/match-rating-curve.cjs (CI, court) et tests/match-rating-curve-long.cjs (manuel).

// Code exécuté dans la VM du moteur : `__bancCourbe(options)` renvoie les matchs bruts.
const VM_SOURCE = String.raw`globalThis.__bancCourbe=function(o){
 const slots=o.slots,originals=slots.map(i=>S.clubs[i]),base=S.clubs[o.base];
 const date=(S.worldMode.fixtures.find(f=>f.week===S.round)||S.worldMode.fixtures[0]).date;
 const copie=(slot,tag,k)=>{const c=JSON.parse(JSON.stringify(base)),s=originals[slots.indexOf(slot)];
  c.id=s.id;c.name=s.name;c.abbr=s.abbr;c.color=s.color;c.morale=75;
  for(const p of c.players){p.id=p.id+'#'+tag;p.condition=100;p.injury=0;p.suspension=0;
   if(k){p.rating+=k;p.skillBase=(p.skillBase??p.rating-k)+k;for(const s in p.skills)p.skills[s]=Math.min(99,p.skills[s]+k);
    if(p.attributesV2)for(const s in p.attributesV2)if(typeof p.attributesV2[s]==='number')p.attributesV2[s]=Math.min(99,p.attributesV2[s]+k);}}
  return c;};
 const out=[];
 try{
  for(let i=0;i<o.n;i++){
   // Domicile alterné à chaque match, emplacement du plus fort alterné tous les deux matchs
   // (le staff et l'histoire d'un club restent liés à son emplacement).
   const fortSlot=slots[(i>>1)%2],faibleSlot=slots[1-(i>>1)%2];
   S.clubs[faibleSlot]=copie(faibleSlot,'a',0);S.clubs[fortSlot]=copie(fortSlot,'b',o.k);
   const strongHome=i%2===0,pair=strongHome?[fortSlot,faibleSlot]:[faibleSlot,fortSlot];
   const f={id:'banc-courbe-'+i,week:S.round,date,homeId:pair[0],awayId:pair[1],competitionId:o.competitionId||'elite',phase:'league',round:1,neutral:false};
   let score,tries;
   if(o.mode==='rapide'){const r=CDLeagueDetail.simulate(S,f);score=r.score;tries=r.tries;}
   else{S.worldMode.fixtures.push(f);
    try{const l=createRugbyMatch(pair,null,true);for(let n=0;!l.finished&&n<700;n++){l.paused=false;advanceRugby(l);}score=l.score.slice();tries=l.tries.slice();}
    finally{S.worldMode.fixtures.splice(S.worldMode.fixtures.indexOf(f),1);}}
   out.push([strongHome?1:0,score[0],score[1],tries[0],tries[1]]);
  }
 }finally{slots.forEach((i,j)=>{S.clubs[i]=originals[j];});}
 return JSON.stringify(out);
};`;

function installer(h) { h.run(VM_SOURCE); }

// Matchs bruts : [fortADomicile, scoreDom, scoreExt, essaisDom, essaisExt].
function jouer(h, options) { return JSON.parse(h.run(`__bancCourbe(${JSON.stringify(options)})`, 1800000)); }

// Résumé d'une série à écart k : victoires du plus fort (nul = ½), à domicile / à l'extérieur, scores.
function resume(k, matchs) {
  let fort = 0, fortDom = 0, nDom = 0, fortExt = 0, nExt = 0, dom = 0, points = 0, essais = 0, ecart = 0, nuls = 0;
  for (const [fortADom, sd, se, ed, ee] of matchs) {
    const sf = fortADom ? sd : se, sa = fortADom ? se : sd, v = sf > sa ? 1 : sf === sa ? 0.5 : 0;
    fort += v; if (fortADom) { fortDom += v; nDom++; } else { fortExt += v; nExt++; }
    dom += sd > se ? 1 : sd === se ? 0.5 : 0; if (sd === se) nuls++;
    points += sd + se; essais += ed + ee; ecart += Math.abs(sd - se);
  }
  const n = matchs.length;
  return { k, n, victoires: fort / n, aDomicile: fortDom / Math.max(1, nDom), aExterieur: fortExt / Math.max(1, nExt),
    domicile: dom / n, nuls, points: points / n, essais: essais / n, ecart: ecart / n };
}

// Ajustement logistique commun à toutes les séries : logit P(fort gagne) = pente·k ± terrain.
// Renvoie la pente par point, l'avantage du terrain (logit) et la courbe neutre / à domicile qui en découle.
function ajuster(series) {
  const pts = [];
  for (const { k, matchs } of series) for (const [fortADom, sd, se] of matchs) {
    const sf = fortADom ? sd : se, sa = fortADom ? se : sd;
    pts.push([k, fortADom ? 1 : -1, sf > sa ? 1 : sf === sa ? 0.5 : 0]);
  }
  let a = 0, b = 0;
  for (let it = 0; it < 4000; it++) {
    let ga = 0, gb = 0;
    for (const [k, d, y] of pts) { const p = 1 / (1 + Math.exp(-(a * k + b * d))); ga += (y - p) * k; gb += (y - p) * d; }
    a += 0.02 * ga / pts.length; b += 0.5 * gb / pts.length;
  }
  const P = x => 1 / (1 + Math.exp(-x));
  return { pente: a, terrain: b, domicileNiveauEgal: P(b), neutre: k => P(a * k), domicile: k => P(a * k + b) };
}

const pct = x => (100 * x).toFixed(1) + ' %';
function tableau(titre, resumes, fit) {
  const lignes = [`${titre}`, 'écart | matchs | victoires du plus fort | à domicile | à l’extérieur | points/match | essais/match | écart moyen'];
  for (const r of resumes) lignes.push(`${r.k >= 0 ? '+' : ''}${r.k} | ${r.n} | ${pct(r.victoires)} | ${pct(r.aDomicile)} | ${pct(r.aExterieur)} | ${r.points.toFixed(1)} | ${r.essais.toFixed(2)} | ${r.ecart.toFixed(1)}`);
  if (fit) lignes.push(`logistique : ${fit.pente.toFixed(3)} par point, terrain ${fit.terrain.toFixed(2)} → domicile à niveau égal ${pct(fit.domicileNiveauEgal)} ; neutre +3 ${pct(fit.neutre(3))}, +6 ${pct(fit.neutre(6))}, +10 ${pct(fit.neutre(10))}, +15 ${pct(fit.neutre(15))}, −10 ${pct(fit.neutre(-10))}`);
  return lignes.join('\n');
}

// Série complète : pour chaque écart, n matchs dans le mode demandé.
function mesurer(h, { mode, ecarts, n, base = 4, slots = [7, 11], competitionId = 'elite' }) {
  installer(h);
  const series = ecarts.map(k => ({ k, matchs: jouer(h, { mode, k, n, base, slots, competitionId }) }));
  return { series, resumes: series.map(s => resume(s.k, s.matchs)), fit: ajuster(series) };
}

module.exports = { VM_SOURCE, installer, jouer, resume, ajuster, tableau, mesurer, pct };
