'use strict';
// IA de match réaliste (26/11/2026, docs/ia-decisions-match-20261126.md) : remplacements par vagues, choix au but ou en
// touche selon la distance, le score et la minute, première ligne remplacée par une première ligne, buteur titulaire.
// Matchs IA contre IA (createRugbyMatch automatisé) de Premiership, d'URC et de Top 14 en carrière Monde (graine fixe).
// Avant (main 29118f15a, mêmes matchs) : un changement toutes les cinq minutes pile (96 % des minutes multiples de 5,
// 15 % après la 75e, un changement à la 80e dans presque chaque match), choix de pénalité tiré au hasard hors Top 14
// (au but 56 % du temps à 10-22 m en Premiership), tirs au but sans enjeu en fin de match, meilleur buteur sur le banc.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { context } = require('./monde-harness.cjs');

const N = { prem: 70, urc: 70, elite: 70 };
const pct = (a, b) => (b ? 100 * a / b : 0);

function jouer(h, comp, n) {
  return JSON.parse(h.run(`(()=>{
   const pens=[],sheets=[];let frontSlots=0,steps=0;
   const exe=executePenaltyChoice,sub=makeSub;
   executePenaltyChoice=function(l,side){const d=side===0?100-l.territory:l.territory,y=penaltySpotY(l,side),a=l.stats[side].goalAttempts,k=l.events.length,
    rec={m:matchMinute(l),diff:l.score[side]-l.score[1-side],d,pol:l.penaltyPolicies?.[side]||'auto',portee:postsInRange(l,side,d,y),p:goalChanceEstimate(l,side,d,y),
     bd:nativeMatchBonus.regleDuMatch(l)?.defensif?.ecart??null,sirene:typeof penaliteApresSirene==='function'&&penaliteApresSirene(l)};
    const r=exe.apply(this,arguments);const t=l.events.slice(k).map(e=>e.text).join(' ');
    rec.c=l.stats[side].goalAttempts>a?'but':/à la main|joue vite/.test(t)?'main':/choisit la mêlée/.test(t)?'melee':'touche';pens.push(rec);return r};
   makeSub=function(l,side,slot){const n=l.subs.length,r=sub.apply(this,arguments);if(l.subs.length>n){l.subs.at(-1).mm=matchMinute(l);l.subs.at(-1).slot=slot}return r};
   const fx=S.worldMode.fixtures.filter(f=>f.competitionId==='${comp}'&&f.phase==='league'&&f.homeId!==S.club&&f.awayId!==S.club),out=[];
   try{for(let i=0;i<${n};i++){const f=fx[(i*7)%fx.length];S.round=f.week;const pair=[f.homeId,f.awayId];for(const id of pair)CDFranceCareer.ensureAISheet(S.clubs[id]);
    for(const id of pair)S.clubs[id].players.forEach(p=>{p.condition=100});
    pens.length=0;const l=createRugbyMatch(pair,null,true),fam={};
    for(const s of [0,1]){const c=S.clubs[pair[s]],sh=l.sheets[s],P=id=>c.players.find(p=>p.id===id),g=p=>skill(p,'goal'),k=chooseScorer(c,sh.on.filter(Boolean)),b=sh.bench.map(P).filter(p=>p&&p.fam>=5).sort((x,y)=>g(y)-g(x))[0];
     sheets.push({ecart:b?g(b)-g(k):-99});for(const id of [...sh.on,...sh.bench])if(id)fam[id]=P(id)?.fam}
    let n=0;while(!l.finished){if(++n>5000)throw Error('boucle');l.paused=false;advanceRugby(l);steps++;for(const s of [0,1])for(let i=0;i<3;i++){const id=l.sheets[s].on[i];if(id&&fam[id]>1)frontSlots++}}
    out.push({score:l.score,ga:l.stats[0].goalAttempts+l.stats[1].goalAttempts,
     subs:l.subs.map(x=>({m:x.mm??x.minute,slot:x.slot??null,s:x.side,r:x.reason||'tactical',ret:!!x.returning,fo:fam[x.out],fi:fam[x.in]})),pens:pens.slice()})}}
   finally{executePenaltyChoice=exe;makeSub=sub}
   return JSON.stringify({matchs:out,sheets,frontSlots,steps})})()`));
}

let donnees = null;
function mesures() {
  if (donnees) return donnees;
  const h = context(4242, { club: 102, console: false });
  try {
    donnees = {};
    for (const comp of Object.keys(N)) donnees[comp] = jouer(h, comp, N[comp]);
  } finally { h.close(); }
  return donnees;
}
const tous = () => Object.values(mesures()).flatMap(d => d.matchs);

test('Remplacements de l’IA par vagues : première ligne vers 50’, gros des changements entre 50’ et 70’, presque rien après 75’', { timeout: 600000 }, () => {
  const subs = tous().flatMap(r => r.subs.filter(s => s.r === 'tactical'));
  const minutes = subs.map(s => s.m).sort((a, b) => a - b), med = minutes[Math.floor(minutes.length / 2)];
  const front = subs.filter(s => s.fo <= 1), frontMoy = front.reduce((a, s) => a + s.m, 0) / front.length;
  const multiples5 = pct(subs.filter(s => s.m % 5 === 0).length, subs.length), apres75 = pct(subs.filter(s => s.m > 75).length, subs.length);
  const fenetre = pct(subs.filter(s => s.m >= 45 && s.m <= 72).length, subs.length), a80 = tous().filter(r => r.subs.some(s => s.r === 'tactical' && s.m >= 79)).length;
  const parCamp = subs.length / tous().length / 2;
  console.log(JSON.stringify({ parCamp: +parCamp.toFixed(2), mediane: med, premiereLigne: +frontMoy.toFixed(1), multiples5: +multiples5.toFixed(1), fenetre: +fenetre.toFixed(1), apres75: +apres75.toFixed(1), matchsAvecChangement79: a80 }));
  assert.ok(parCamp >= 5.5 && parCamp <= 8, `changements tactiques par camp : ${parCamp.toFixed(2)} (réel 6-8)`);
  assert.ok(frontMoy >= 46 && frontMoy <= 58, `première ligne remplacée en moyenne à la ${frontMoy.toFixed(1)}e (réel 45-55)`);
  assert.ok(med >= 54 && med <= 64, `minute médiane des changements : ${med}`);
  assert.ok(multiples5 < 35, `pas d'horloge : ${multiples5.toFixed(1)} % des changements à une minute multiple de 5`);
  assert.ok(fenetre >= 85, `${fenetre.toFixed(1)} % des changements entre la 45e et la 72e`);
  assert.ok(apres75 <= 2, `${apres75.toFixed(1)} % des changements tactiques après la 75e (joueur à bout seulement)`);
  assert.ok(a80 <= tous().length * 0.02, `${a80} matchs avec un changement tactique à la 79e ou après`);
  // Aucun retour tactique de l'IA : au plus huit entrées hors saignement, protocole commotion, première ligne et rouge de 20 minutes.
  const retours = subs.filter(s => s.ret).length;
  assert.equal(retours, 0, 'retours tactiques de joueurs déjà remplacés');
  const huit = tous().every(r => [0, 1].every(s => r.subs.filter(x => x.s === s && !x.ret && ['tactical', 'blessure', 'commotion'].includes(x.r)).length <= 8));
  assert.ok(huit, 'au plus huit remplaçants entrés hors exceptions de la loi 3');
});

test('Pénalité : au but à portée quand 3 points comptent, en touche quand il faut un essai, jamais un tir inutile en fin de match', { timeout: 600000 }, () => {
  const d = mesures();
  const hors = c => c !== 'main' && c !== 'melee';
  const anglo = [...d.prem.matchs, ...d.urc.matchs].flatMap(r => r.pens).filter(p => !p.sirene && hors(p.c));
  // Milieu de match, au but facile (10-22 m, réussite attendue d'au moins 85 %) : les poteaux, Premiership et URC compris.
  const facile = anglo.filter(p => p.m < 65 && p.d >= 10 && p.d < 22 && p.portee && p.p >= 0.85 && p.pol === 'auto');
  const butFacile = pct(facile.filter(p => p.c === 'but').length, facile.length);
  // La distance compte : plus souvent au but à 10-22 m qu'à 30-40 m, et à 30-40 m qu'au-delà de 40 m.
  const zone = (lo, hi) => { const z = anglo.filter(p => p.m < 65 && p.d >= lo && p.d < hi); return pct(z.filter(p => p.c === 'but').length, z.length); };
  const [z1, z2, z3] = [zone(10, 22), zone(30, 40), zone(40, 60)];
  const fin = Object.values(d).flatMap(x => x.matchs).flatMap(r => r.pens).filter(p => p.m >= 75 && hors(p.c));
  // Mené de 1 à 3 dans les dix dernières minutes, à portée : les poteaux (égalité ou victoire).
  const serre = Object.values(d).flatMap(x => x.matchs).flatMap(r => r.pens).filter(p => p.m >= 70 && hors(p.c)).filter(p => p.diff < 0 && p.diff >= -3 && p.portee);
  const butSerre = pct(serre.filter(p => p.c === 'but').length, serre.length);
  // Mené de 4 points ou plus : un tir au but seulement pour revenir dans le bonus défensif.
  const inutiles = fin.filter(p => p.c === 'but' && p.diff < -3 && !(p.bd !== null && -p.diff > p.bd && -p.diff - 3 <= p.bd));
  const parMatch = (x => x.matchs.reduce((a, r) => a + r.ga, 0) / x.matchs.length);
  const tirs = { prem: parMatch(d.prem), urc: parMatch(d.urc), elite: parMatch(d.elite) };
  console.log(JSON.stringify({ butFacile: +butFacile.toFixed(1), nFacile: facile.length, zones: [z1, z2, z3].map(x => +x.toFixed(1)), butSerre: +butSerre.toFixed(1), nSerre: serre.length, inutiles: inutiles.length, nFin: fin.length, tirs }));
  assert.ok(facile.length >= 30 && butFacile >= 90, `au but facile en milieu de match : ${butFacile.toFixed(1)} % sur ${facile.length}`);
  assert.ok(z1 > z2 + 10 && z2 > z3, `au but selon la distance : ${z1.toFixed(1)} / ${z2.toFixed(1)} / ${z3.toFixed(1)} %`);
  assert.ok(serre.length >= 8 && butSerre >= 90, `mené de 1 à 3 en fin de match, à portée : au but ${butSerre.toFixed(1)} % sur ${serre.length}`);
  assert.equal(inutiles.length, 0, 'tirs au but qui ne ramènent ni l’égalité ni le bonus défensif : ' + JSON.stringify(inutiles.slice(0, 3)));
  // Premiership et URC jouent plus la touche que le Top 14, sans renoncer aux points : au moins 70 % des tirs du Top 14 (réel,
  // tests/fixtures/realite-matchs-20261125.json, points moins essais et transformations : ≈ 2,9 pénalités réussies par match,
  // soit ≈ 3,4 tirs ; le Top 14 du moteur tire ≈ 4-4,5 fois ; main ≈ 55-60 % du Top 14).
  for (const c of ['prem', 'urc']) assert.ok(tirs[c] >= 0.7 * tirs.elite && tirs[c] < tirs.elite + 0.3, `${c} : ${tirs[c].toFixed(2)} tirs au but par match (Top 14 ${tirs.elite.toFixed(2)})`);
});

test('Première ligne remplacée par une première ligne, buteur titulaire', { timeout: 600000 }, () => {
  const d = mesures();
  // Remplacements proprement dits (changements et rouges de 20 minutes) : un spécialiste aux n° 1 à 3, jamais un pilier ou
  // un talonneur dans les lignes arrières.
  const mauvais = tous().flatMap(r => r.subs).filter(s => !/^front/.test(s.r) && s.slot !== null && s.fi != null && (s.slot < 3 ? s.fi > 1 : s.slot >= 8 && s.fi <= 1));
  assert.equal(mauvais.length, 0, 'premières lignes remplacées par un autre poste : ' + JSON.stringify(mauvais.slice(0, 3)));
  for (const x of Object.values(d)) assert.equal(x.frontSlots, 0, 'joueur hors première ligne aux n° 1 à 3');
  // Meilleur buteur de la feuille : titulaire, sauf s'il tire à peine mieux (moins de 6 points au but) que celui du XV.
  const sheets = Object.values(d).flatMap(x => x.sheets), banc = sheets.filter(s => s.ecart >= 6).length;
  console.log(JSON.stringify({ feuilles: sheets.length, buteurNettementMeilleurSurLeBanc: banc }));
  assert.ok(pct(banc, sheets.length) <= 3, `meilleur buteur sur le banc dans ${banc} feuilles sur ${sheets.length}`);
  // Rouge de 20 minutes d'un ailier : l'IA fait entrer un trois-quarts, pas le talonneur remplaçant, même mieux noté.
  const h = context(4242, { club: 102, console: false });
  try {
    const r = JSON.parse(h.run(`(()=>{const f=S.worldMode.fixtures.find(f=>f.competitionId==='prem'&&f.phase==='league'&&f.homeId!==S.club&&f.awayId!==S.club);S.round=f.week;
     const pair=[f.homeId,f.awayId];for(const id of pair)CDFranceCareer.ensureAISheet(S.clubs[id]);const l=createRugbyMatch(pair,null,true),side=1,sh=l.sheets[side],P=id=>matchPlayer(l,side,id);
     const hooker=sh.bench.map(P).find(p=>p.fam===1),wing=sh.on[10];for(const k of Object.keys(hooker.skills))hooker.skills[k]=99;
     l.minute=50;giveMatchCard(l,side,wing,'red20');l.minute=71;restoreRedReplacements(l,side);const inn=P(sh.on[10]);return JSON.stringify({fam:inn?.fam??null,hooker:inn?.id===hooker.id})})()`));
    assert.ok(r.fam >= 4 && !r.hooker, 'remplaçant de l’ailier exclu : ' + JSON.stringify(r));
  } finally { h.close(); }
});
