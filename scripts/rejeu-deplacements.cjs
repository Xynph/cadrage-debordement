#!/usr/bin/env node
'use strict';
// Rejeu des déplacements d'un club en saison de carrière Monde (docs/top14-dispute-20261117.md §8).
// Au moment où la saison crée le match (feuilles de match, bancs, condition, moral, choix de l'IA déjà faits),
// le même match est recréé et joué N fois dans plusieurs variantes, puis le curseur de tirage est remis où il était :
// la saison continue exactement comme sans rejeu. Comparé à la courbe de niveau du banc (pente 0,206, terrain 0,95
// pour le Top 14, sur l'écart de niveau joué), cela dit si le surplus d'un club naît de l'état au coup d'envoi.
// Variantes : reel (tel quel), moral (les deux moraux à 75), forme (condition pleine des 23), neutre (terrain neutre),
// buteur (pied au but des deux camps plafonné à 80),
// creation (feuille du match de la saison reprise telle quelle, seuls les tirages du match changent).
// Usage : node --max-old-space-size=1400 scripts/rejeu-deplacements.cjs [graine=7] [--cible TCX] [--comp elite] [--n 100]
//         [--variantes reel,moral,forme] [--domicile] [--tous] [--json fichier] [--regler code]
// --tous : tous les matchs du championnat (point de vue du recevant), pour comparer la saison à ses rejeux sur la courbe.
const fs = require('node:fs');
const { context } = require('../tests/monde-harness.cjs');

const args = process.argv.slice(2);
const opt = (n, d) => { const i = args.indexOf(n); return i >= 0 ? args[i + 1] : d; };
const libres = args.filter((a, i) => !a.startsWith('--') && !(i > 0 && args[i - 1].startsWith('--')));
const graine = Number(libres[0] ?? 7), comp = opt('--comp', 'elite'), N = Number(opt('--n', 100));
const variantes = opt('--variantes', 'reel,moral,forme').split(','), domicile = args.includes('--domicile'), tous = args.includes('--tous');
const pente = Number(opt('--pente', .206)), terrainBanc = Number(opt('--terrain', .95));

const h = context(graine, { console: false, selections: true });
h.start(Number(opt('--club', 102)));
if (opt('--regler', '')) h.run(opt('--regler', ''));
const noms = JSON.parse(h.run('JSON.stringify(S.clubs.map(c=>c.abbr))'));
const membres = JSON.parse(h.run(`JSON.stringify(S.worldMode.leagues[${JSON.stringify(comp)}].members)`));
const force = JSON.parse(h.run(`JSON.stringify(S.clubs.map(c=>{const n=c.players.filter(p=>!p.injury).map(p=>roleNote(p)).sort((a,b)=>b-a).slice(0,23);return n.reduce((a,b)=>a+b,0)/Math.max(1,n.length)}))`));
const cible = opt('--cible', null) ? noms.indexOf(opt('--cible')) : [...membres].sort((a, b) => force[b] - force[a])[0];
if (cible < 0) throw Error('club cible inconnu');
h.ctx.__curseur = () => h.seed();
h.ctx.__remettre = v => h.setSeed(v);

h.run(`globalThis.__rejeux=[];(()=>{
 const CIBLE=${tous ? -1 : cible},COMP=${JSON.stringify(comp)},N=${N},VARIANTES=${JSON.stringify(variantes)},DOM=${domicile};
 const cree=createRugbyMatch;let occupe=false;
 const niveau=l=>[teamLevel(activePlayers(l,0)),teamLevel(activePlayers(l,1))];
 function jouer(l){const n=[0,0],c=niveau(l);let pas=0;for(let k=0;!l.finished;k++){if(k>600)throw Error('rejeu sans fin');l.paused=false;const v=niveau(l);n[0]+=v[0];n[1]+=v[1];pas++;advanceRugby(l);}
  return {s:l.score.slice(),t:l.tries.slice(),niv:[n[0]/pas,n[1]/pas],coup:c};}
 // Le match joue sur les joueurs de la partie (condition, blessures, renfort d'urgence des jeunes à la création) :
 // après chaque rejeu, les deux clubs et leurs centres de formation sont remis en place sans changer d'objets,
 // pour que le match de la saison, déjà créé, garde ses références.
 function remettre(cible,source){
  if(Array.isArray(source)){cible.length=source.length;}else for(const k of Object.keys(cible))if(!(k in source))delete cible[k];
  for(const k of Object.keys(source)){const v=source[k];
   if(v&&typeof v==='object'&&cible[k]&&typeof cible[k]==='object'&&Array.isArray(v)===Array.isArray(cible[k]))remettre(cible[k],v);else cible[k]=v;}
 }
 const etat=pair=>({clubs:pair.map(id=>S.clubs[id]),ecoles:pair.map(id=>S.aiRoster?.academies?.[id]).filter(Boolean)});
 let photo='';function variante(nom,pair,modele){
  // Moral et terrain se règlent sur l'état de la partie (rétabli après) ; condition et feuille sur le match créé.
  const moraux=pair.map(id=>S.clubs[id].morale),moralJoueur=S.morale;
  if(nom==='moral'){pair.forEach(id=>{if(id===S.club)S.morale=75;else S.clubs[id].morale=75;});}
  try{
   let l;
   if(nom==='creation'){l=JSON.parse(modele);}else l=cree(pair,null,true);
   if(nom==='neutre')l.worldContext={...l.worldContext,neutral:true};
   // buteur : pied au but des 23 des deux camps plafonné à 80 (médiane des meilleurs buteurs du Top 14).
   if(nom==='buteur')for(const s of [0,1])for(const id of [...l.sheets[s].on,...l.sheets[s].bench].filter(Boolean)){const p=matchPlayer(l,s,id);if(p&&p.skills){const b=p.rating-(p.skillBase??p.rating);p.skills.goal=Math.min(p.skills.goal,80-b);}}
   if(nom==='forme')for(const s of [0,1])for(const id of [...l.sheets[s].on,...l.sheets[s].bench].filter(Boolean)){const p=matchPlayer(l,s,id);if(p)p.condition=100;}
   return jouer(l);
  }finally{remettre(etat(pair),JSON.parse(photo));pair.forEach((id,i)=>{S.clubs[id].morale=moraux[i];});S.morale=moralJoueur;}
 }
 createRugbyMatch=function(pair,legacy,automated){
  const l=cree.apply(this,arguments);
  const wc=l.worldContext;
  if(occupe||!automated||!wc||wc.competitionId!==COMP||wc.phase!=='league'||(CIBLE>=0&&pair[DOM?0:1]!==CIBLE))return l;
  occupe=true;const curseur=__curseur(),empreinte=JSON.stringify(S).length,modele=JSON.stringify(l);photo=JSON.stringify(etat(pair));
  try{
   const r={semaine:S.round,pair:pair.slice(),moral:pair.map(clubMorale),feuille:niveau(l),variantes:{}};
   for(const v of VARIANTES){r.variantes[v]=[];for(let i=0;i<N;i++)r.variantes[v].push(variante(v,pair,modele));}
   r.etatModifie=JSON.stringify(S).length!==empreinte;r.matchModifie=JSON.stringify(l)!==modele;
   l.__rejeu=r;__rejeux.push(r);
  }finally{__remettre(curseur);occupe=false;}
  return l;
 };
 const fin=finishRugbyMatch;finishRugbyMatch=function(l){const r=fin.apply(this,arguments);if(l.finished&&l.__rejeu&&!l.__rejeu.saison)l.__rejeu.saison={s:l.score.slice(),t:l.tries.slice()};return r;};
})();`);

const t0 = Date.now();
for (let w = 0; w < 80 && h.run("S.phase!=='ended'"); w++) {
  h.week(1, { validate: false });
  if (w % 5 === 0) process.stderr.write(`semaine ${w + 1} : ${h.run('__rejeux.length')} déplacements rejoués, ${Math.round((Date.now() - t0) / 1000)} s\n`);
}
const rejeux = JSON.parse(h.run('JSON.stringify(__rejeux)'));
h.close();
if (tous) {
  // Saison et rejeux ajustés de la même façon : logit P(recevant gagne) = pente × écart joué + terrain.
  const L = x => 1 / (1 + Math.exp(-x)), y = s => s[0] > s[1] ? 1 : s[0] === s[1] ? .5 : 0;
  const ajuste = pts => { let a = .2, b = .8; for (let i = 0; i < 6000; i++) { let ga = 0, gb = 0; for (const [g, v, w] of pts) { const p = L(a * g + b); ga += w * (v - p) * g; gb += w * (v - p); } const W = pts.reduce((t, p) => t + p[2], 0); a += ga / W * .01; b += gb / W * .1; } return [a, b]; };
  const saisonPts = [], rejeuPts = [];
  let dom = 0, domRejeu = 0, fav = 0, favRejeu = 0, nfav = 0;
  for (const r of rejeux) {
    const xs = r.variantes.reel, g = xs.reduce((t, x) => t + x.niv[0] - x.niv[1], 0) / xs.length;
    const m = xs.reduce((t, x) => t + y(x.s), 0) / xs.length;
    saisonPts.push([g, y(r.saison.s), 1]); for (const x of xs) rejeuPts.push([x.niv[0] - x.niv[1], y(x.s), 1 / xs.length]);
    dom += y(r.saison.s); domRejeu += m;
    if (Math.abs(g) >= 1) { nfav++; fav += g > 0 ? y(r.saison.s) : 1 - y(r.saison.s); favRejeu += g > 0 ? m : 1 - m; }
  }
  const [a1, b1] = ajuste(saisonPts), [a2, b2] = ajuste(rejeuPts);
  console.log(`Graine ${graine}, ${comp}, ${rejeux.length} matchs, ${N} rejeux chacun.`);
  console.log(`Victoires à domicile : saison ${dom} (${Math.round(dom / rejeux.length * 100)} %), rejeux ${domRejeu.toFixed(1)} (${Math.round(domRejeu / rejeux.length * 100)} %)`);
  console.log(`Favori (écart joué ≥ 1) : saison ${fav} sur ${nfav}, rejeux ${favRejeu.toFixed(1)}`);
  console.log(`Courbe saison : pente ${a1.toFixed(3)} terrain ${b1.toFixed(2)} ; courbe des rejeux : pente ${a2.toFixed(3)} terrain ${b2.toFixed(2)}`);
  if (opt('--json', null)) fs.writeFileSync(opt('--json', null), JSON.stringify({ graine, comp, N, noms, rejeux }));
  process.exit(0);
}

// Résultat du point de vue de la cible ; attendu par la courbe du banc sur l'écart de niveau joué.
const L = x => 1 / (1 + Math.exp(-x)), cote = domicile ? 0 : 1;
const issue = s => s[cote] > s[1 - cote] ? 1 : s[cote] === s[1 - cote] ? .5 : 0;
const attendu = (niv, neutre) => { const g = niv[cote] - niv[1 - cote]; return L(pente * g + (neutre ? 0 : (cote ? -terrainBanc : terrainBanc))); };
const total = {}, lignes = [];
let saison = 0, saisonAtt = 0;
for (const r of rejeux) {
  const ligne = { semaine: r.semaine, adversaire: noms[r.pair[1 - cote]], saison: r.saison ? issue(r.saison.s) : '?', moraux: r.moral.map(Math.round).join('/'), etat: r.etatModifie ? 'MODIFIÉ' : 'ok' };
  if (r.saison) { saison += issue(r.saison.s); }
  for (const [v, xs] of Object.entries(r.variantes)) {
    const g = xs.reduce((a, x) => a + issue(x.s), 0) / xs.length, a = xs.reduce((s, x) => s + attendu(x.niv, v === 'neutre'), 0) / xs.length;
    const ecart = xs.reduce((s, x) => s + (x.niv[cote] - x.niv[1 - cote]), 0) / xs.length;
    ligne[v] = `${Math.round(g * 100)} % / ${Math.round(a * 100)} % (${ecart >= 0 ? '+' : ''}${ecart.toFixed(1)})`;
    const t = total[v] ||= { g: 0, a: 0, n: 0 }; t.g += g; t.a += a; t.n++;
    if (v === 'reel') saisonAtt += a;
  }
  lignes.push(ligne);
}
console.log(`Graine ${graine}, ${noms[cible]} ${domicile ? 'à domicile' : 'à l’extérieur'} en ${comp} : ${rejeux.length} matchs, ${N} rejeux par variante.`);
console.log(`Saison : ${saison} victoires (nuls 0,5) pour ${saisonAtt.toFixed(1)} attendues (courbe sur le niveau joué des rejeux « reel »).`);
const cols = ['semaine', 'adversaire', 'saison', 'moraux', ...variantes, 'etat'];
console.log(['| ' + cols.join(' | ') + ' |', '|' + cols.map(() => '---').join('|') + '|', ...lignes.map(l => '| ' + cols.map(c => l[c] ?? '').join(' | ') + ' |')].join('\n'));
for (const [v, t] of Object.entries(total)) console.log(`${v} : ${(t.g).toFixed(1)} victoires rejouées pour ${(t.a).toFixed(1)} attendues sur ${t.n} matchs`);
if (opt('--json', null)) fs.writeFileSync(opt('--json', null), JSON.stringify({ graine, cible, comp, domicile, N, noms, rejeux }));
