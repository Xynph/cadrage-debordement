'use strict';
// Les remplaçants comptent (lot K3, docs/remplacants-20261126.md), carrière Monde (world-champ, club 102), matchs IA
// contre IA à tirage fixe : un remplaçant frais change la suite du match nettement plus souvent qu'avant, dans le bon
// sens et sans écraser le hasard ; il pèse plus s'il est du niveau du sortant ; l'ordinateur remplace AU POSTE (jamais
// un demi de mêlée à l'aile quand un trois-quarts est libre sur le banc, talonneur pour talonneur).
const test = require('node:test');
const assert = require('node:assert/strict');
const {context} = require('./monde-harness.cjs');

const shared = context(827381, {club: 102, console: false}).toMatch(), base = shared.checkpoint();
test.after(() => shared.close());
const setup = () => shared.restore(base);
const SEUILS = {suite: 35, margeMax: 3}, N_POSTE = 200;

// Affiche k de la saison (hors club du manager), tirage fixe par match, conditions et blessures rétablies après.
const PREPARER = `var ligne=[0,0,1,1,2,2,3,3,3];
var affiche=(k,tous)=>{const fx=S.worldMode.fixtures.filter(f=>(tous||f.competitionId==='elite'&&f.phase==='league')&&f.homeId!==S.club&&f.awayId!==S.club);return fx[(k*7)%fx.length]};
var jouer=(k,graine,avant,tous)=>{const f=affiche(k,tous),pair=[f.homeId,f.awayId],rng=Math.random;S.round=f.week;for(const id of pair)CDFranceCareer.ensureAISheet(S.clubs[id]);
 const snap=pair.flatMap(id=>S.clubs[id].players.map(p=>[p,p.condition,p.injury,p.rating]));for(const id of pair)S.clubs[id].players.forEach(p=>{p.condition=100});
 let x=graine>>>0;Math.random=()=>{x=(Math.imul(x,1664525)+1013904223)>>>0;return x/4294967296};
 try{const l=createRugbyMatch(pair,null,true);if(typeof initPilotageIA==='function')initPilotageIA(l,f);let n=0;
  while(!l.finished){if(++n>5000)throw Error('boucle');if(avant&&avant(l))break;l.paused=false;advanceRugby(l)}return l}
 finally{Math.random=rng;retablir=()=>{for(const [p,c,j,r] of snap){p.condition=c;p.injury=j;p.rating=r}}}};
var retablir=()=>{};
var minute=l=>typeof matchMinute==='function'?matchMinute(l):l.minute;`;

// Camp 0 sans remplacement de l'ordinateur ; variante : un remplacement imposé à la 50e (même famille, premier libre du
// banc), le reste identique ; suite, marge finale, pénalités concédées et porteurs qui avancent après la 50e comparés.
const SUITE = `${PREPARER}
var suite=(n)=>{const R=[],ria=remplacementsIA;remplacementsIA=function(l,side){return side===0?undefined:ria.apply(this,arguments)};
 try{for(let k=0;k<n;k++){const g=(k*2654435761+97)>>>0;
 const sig=l=>[l.score.join('-'),l.tries.join('-'),l.stats[0].penalties,l.stats[1].penalties].join(':');
 const vu=l=>({pen:l.stats[0].penalties||0,car:l.tacticalStats[0].carries||0,adv:l.tacticalStats[0].advances||0}),apres=(a,b)=>({pen:b.pen-a.pen,av:(b.adv-a.adv)/Math.max(1,b.car-a.car)});
 let r50=null;const ref=jouer(k,g,l=>{if(!r50&&minute(l)>=50)r50=vu(l);return false});retablir();const s0=sig(ref),m0=ref.score[0]-ref.score[1],a0=apres(r50,vu(ref));
 for(const slot of [0,5,8,10]){let fait=null,v50=null;
  const l=jouer(k,g,l=>{if(fait===null&&minute(l)>=50){fait=false;v50=vu(l);const sh=l.sheets[0],out=matchPlayer(l,0,sh.on[slot]);
   const id=sh.bench.find(b=>!sh.used.includes(b)&&matchPlayer(l,0,b)?.fam===out?.fam&&!matchPlayer(l,0,b).injury&&legalChange(l,0,slot,b));
   if(id!=null)fait=!!makeSub(l,0,slot,id)}return false});retablir();
  if(fait){const a1=apres(v50,vu(l));R.push({slot,change:sig(l)!==s0,marge:(l.score[0]-l.score[1])-m0,pen:a1.pen-a0.pen,av:a1.av-a0.av})}}}}
 finally{remplacementsIA=ria}
 return R};`;

test('un remplaçant frais change la suite du match nettement plus souvent sans écraser le hasard', () => {
  setup();
  const R = JSON.parse(shared.run(SUITE + 'JSON.stringify(suite(80))'));
  const part = a => a.filter(r => r.change).length / a.length, marge = a => a.reduce((s, r) => s + r.marge, 0) / a.length;
  const detail = [0, 5, 8, 10].map(slot => { const a = R.filter(r => r.slot === slot); return {slot, n: a.length, suite: +(100 * part(a)).toFixed(1), marge: +marge(a).toFixed(2)}; });
  const moy = k => R.reduce((s, r) => s + r[k], 0) / R.length;
  const bilan = {n: R.length, suite: +(100 * part(R)).toFixed(1), marge: +marge(R).toFixed(2), penalites: +moy('pen').toFixed(3), avancent: +(100 * moy('av')).toFixed(2), detail};
  assert.ok(R.length >= 200, `trop peu de remplacements imposés : ${JSON.stringify(bilan)}`);
  // Avant le lot, sur ces 248 remplacements : suite changée 17 % ; après : 50 % (docs/remplacants-20261126.md).
  assert.ok(bilan.suite >= SEUILS.suite, `remplaçant sans effet : ${JSON.stringify(bilan)}`);
  // Borne : le hasard reste maître (marge moyenne déplacée de moins de 3 points ; +0,41 ± 0,4 ici). Le sens de chaque effet
  // est vérifié sans bruit par le test suivant ; sur 1 400 remplacements (doc), la marge bouge de −0,1 à +1,5 point.
  assert.ok(Math.abs(bilan.marge) <= SEUILS.margeMax, `effet sur la marge hors bornes : ${JSON.stringify(bilan)}`);
});

test('fraîcheur : un entrant frais rend son camp plus frais, moins s’il est bien plus faible, effet borné', () => {
  setup();
  const r = JSON.parse(shared.run(`${PREPARER}(()=>{let out=null;const l=jouer(3,12345,l=>minute(l)>=55);
   const avant=fraicheurEcart(l,0,'jeu'),jeu0=fraicheurJeu(l,0),faute0=fraicheurFaute(l,0),main0=fraicheurMain(l,0),melee0=fraicheurMelee(l,0),sh=l.sheets[0],slot=5,sortant=matchPlayer(l,0,sh.on[slot]);
   const id=sh.bench.find(b=>!sh.used.includes(b)&&matchPlayer(l,0,b)?.fam===sortant.fam&&legalChange(l,0,slot,b));
   const p=matchPlayer(l,0,id);const ok=!!makeSub(l,0,slot,id);const frais=fraicheurEcart(l,0,'jeu'),jeu=fraicheurJeu(l,0),faute=fraicheurFaute(l,0),main=fraicheurMain(l,0),melee=fraicheurMelee(l,0);
   p.rating-=25;l.subs=l.subs.map(s=>({...s}));const faible=fraicheurEcart(l,0,'jeu');retablir();
   return JSON.stringify({ok,avant,frais,faible,jeu0,jeu,faute0,faute,main0,main,melee0,melee,cond:[sortant.condition,p.condition]})})()`));
  assert.ok(r.ok, `remplacement refusé : ${JSON.stringify(r)}`);
  assert.ok(r.frais > r.avant + 0.05, `l'entrant frais n'apporte rien : ${JSON.stringify(r)}`);
  assert.ok(r.faible < r.frais - 0.02, `un remplaçant bien plus faible pèse autant : ${JSON.stringify(r)}`);
  // Sens : chaque effet bouge en faveur du camp qui fait entrer le joueur frais ; bornes : un seul joueur ne renverse rien.
  assert.ok(r.jeu > r.jeu0 && r.jeu - r.jeu0 <= 0.05 && Math.abs(r.jeu) <= 0.1, `avantage d'attaque : sens ou borne : ${JSON.stringify(r)}`);
  assert.ok(r.faute < r.faute0 && r.faute >= 0.7 && r.faute <= 1.3, `pénalités : sens ou borne : ${JSON.stringify(r)}`);
  assert.ok(r.main < r.main0 && Math.abs(r.main) <= 0.03, `fautes de main : sens ou borne : ${JSON.stringify(r)}`);
  assert.ok(r.melee >= r.melee0 && Math.abs(r.melee) <= 0.1, `mêlée : sens ou borne : ${JSON.stringify(r)}`);
});

test('l’ordinateur remplace au poste : jamais un demi de mêlée à l’aile ni un non-talonneur au talon quand le banc a le bon joueur', () => {
  setup();
  const acc = JSON.parse(shared.run(`${PREPARER}(()=>{const acc={subs:0,auPoste:0,demiAile:0,talon:0,ex:[]},ms=makeSub;
   makeSub=function(l,side,slot,id){const sh=l.sheets[side],p=matchPlayer(l,side,id),f=FAMILIES[slot];
    const libres=sh.bench.filter(b=>b!==id&&!sh.used.includes(b)).map(b=>matchPlayer(l,side,b)).filter(q=>q&&!q.injury&&legalChange(l,side,slot,q.id));
    const ok=ms.apply(this,arguments);
    if(ok&&p){acc.subs++;if(p.fam===f)acc.auPoste++;
     if(p.fam===4&&ligne[f]===3&&libres.some(q=>ligne[q.fam]===3)){acc.demiAile++;if(acc.ex.length<5)acc.ex.push({slot,libres:libres.map(q=>q.fam)})}
     if(f===1&&p.fam!==1&&libres.some(q=>q.fam===1)){acc.talon++;if(acc.ex.length<5)acc.ex.push({slot,talon:p.fam})}}
    return ok};
   try{for(let k=0;k<${N_POSTE};k++){jouer(k,(k*40503+11)>>>0,null,true);retablir()}}finally{makeSub=ms}
   return JSON.stringify(acc)})()`));
  assert.ok(acc.subs >= 8 * N_POSTE, `trop peu de remplacements de l'ordinateur : ${JSON.stringify(acc)}`);
  assert.equal(acc.demiAile, 0, `demi de mêlée mis à l'aile avec un trois-quarts libre : ${JSON.stringify(acc)}`);
  assert.equal(acc.talon, 0, `talonneur remplacé par un autre poste avec un talonneur libre : ${JSON.stringify(acc)}`);
});
