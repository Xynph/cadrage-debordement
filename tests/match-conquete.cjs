'use strict';
// Conquête réaliste (docs/conquete-realiste-20261126.md) : une équipe garde sa mêlée et sa touche sur son propre
// lancer aussi souvent qu'au réel (hors pénalités : mêlée 90-95 %, touche 85-88 %), avec un écart net entre un gros
// pack et un pack faible, et moins de touches gagnées sous la pluie. Carrière Monde (world-champ), graine fixe,
// matchs complets du Top 14 et de l'URC simulés par le vrai moteur.
const assert = require('node:assert/strict');
const { test } = require('node:test');
const { worldYouth } = require('./helpers/youth-world-harness.cjs');

const MATCHS = 120; // par championnat
const COMPETITIONS = ['elite', 'urc'];

// Relevé en lecture seule autour de contestSetPiece : issue (gagnée, perdue, pénalité, non disputée), écart des avants
// qui disputent (même mesure que le moteur), niveau de pluie. Aucun tirage ajouté.
const RELEVE = `(()=>{globalThis.__conquete=[];const orig=contestSetPiece;contestSetPiece=function(l,side,kind){
 const st=l.stats[side],k=kind==='scrum'?'scrums':'lineouts',w=kind==='scrum'?'scrumsWon':'lineoutsWon',n0=st[k],w0=st[w],e0=l.events.length;
 const f=kind==='scrum'?p=>p.fam<=2:p=>p.fam===1||p.fam===2,d=unit(l,side,kind,f)-unit(l,1-side,kind,f);
 const r=orig.apply(this,arguments);
 if(st[k]>n0){const evs=l.events.slice(e0);let o=st[w]>w0?'win':evs.some(e=>e.type==='penalty')?'pen':'loss';
  if(o!=='pen'&&evs.some(e=>/non disputée/.test(e.text)))o='unc';
  globalThis.__conquete.push([kind,o,d,meteoNiveau(l,'pluie')])}
 return r}})()`;

function simuler() {
  const t = worldYouth({ seed: 827381, club: 0 });
  t.run(RELEVE);
  const lignes = [];
  let matchs = 0;
  for (const comp of COMPETITIONS) {
    const total = Number(t.run(`S.worldMode.fixtures.filter(f=>f.competitionId==='${comp}'&&f.phase==='league').length`));
    assert.ok(total >= 60, `${comp} : calendrier trouvé`);
    for (let i = 0; i < MATCHS; i++) {
      lignes.push(...JSON.parse(t.run(`(()=>{globalThis.__conquete=[];const f=S.worldMode.fixtures.filter(f=>f.competitionId==='${comp}'&&f.phase==='league')[(${i}*7)%${total}];S.round=f.week;
       const pair=[f.homeId,f.awayId];for(const id of pair)CDFranceCareer.ensureAISheet(S.clubs[id]);
       S.club=pair[0];const l=createRugbyMatch(pair,null,false);for(let n=0;!l.finished;n++){if(n>4000)throw Error('boucle');l.paused=false;advanceRugby(l)}
       return JSON.stringify(globalThis.__conquete)})()`)));
      matchs++;
    }
  }
  return { t, lignes, matchs };
}

const { t, lignes, matchs } = simuler();
const disputees = (kind, filtre = () => true) => lignes.filter(([k, o, d, p]) => k === kind && (o === 'win' || o === 'loss') && filtre(d, p));
const garde = (kind, filtre) => { const l = disputees(kind, filtre); return { n: l.length, pct: 100 * l.filter(x => x[1] === 'win').length / l.length }; };
const parMatch = (kind, issue) => lignes.filter(([k, o]) => k === kind && o === issue).length / matchs;

test('Mêlée et touche gardées sur son lancer comme au réel (hors pénalités)', () => {
  const melee = garde('scrum'), touche = garde('lineout');
  console.log('conquête gardée : mêlée %s %% (%d), touche %s %% (%d)', melee.pct.toFixed(1), melee.n, touche.pct.toFixed(1), touche.n);
  assert.ok(melee.n > 1500 && touche.n > 3000, `échantillon : ${melee.n} mêlées, ${touche.n} touches`);
  assert.ok(melee.pct >= 89 && melee.pct <= 95, `mêlée gardée ${melee.pct.toFixed(1)} % (réel 90-95 %)`);
  assert.ok(touche.pct >= 84 && touche.pct <= 89.5, `touche gardée ${touche.pct.toFixed(1)} % (réel 85-88 %)`);
  // Pertes par match : ~0,5-1 mêlée et ~3 touches (réel), au lieu de 1,5 et 4,2.
  assert.ok(parMatch('scrum', 'loss') <= 1.1, `mêlées perdues par match ${parMatch('scrum', 'loss').toFixed(2)}`);
  assert.ok(parMatch('lineout', 'loss') <= 3.6, `touches perdues par match ${parMatch('lineout', 'loss').toFixed(2)}`);
});

test('Gros pack contre pack faible : écart net, sans écraser le plus faible', () => {
  const fortM = garde('scrum', d => d >= 8), faibleM = garde('scrum', d => d <= -8);
  const fortT = garde('lineout', d => d >= 8), faibleT = garde('lineout', d => d <= -8);
  console.log('conquête gardée, gros pack / pack faible : mêlée %s / %s %%, touche %s / %s %%', fortM.pct.toFixed(1), faibleM.pct.toFixed(1), fortT.pct.toFixed(1), faibleT.pct.toFixed(1));
  for (const [nom, x] of Object.entries({ fortM, faibleM, fortT, faibleT })) assert.ok(x.n >= 150, `${nom} : ${x.n} phases`);
  assert.ok(fortM.pct >= 94, `gros pack en mêlée ${fortM.pct.toFixed(1)} %`);
  assert.ok(fortM.pct - faibleM.pct >= 6, `mêlée : écart ${(fortM.pct - faibleM.pct).toFixed(1)} points (fort ${fortM.pct.toFixed(1)}, faible ${faibleM.pct.toFixed(1)})`);
  assert.ok(faibleM.pct >= 75, `pack faible en mêlée ${faibleM.pct.toFixed(1)} %`);
  assert.ok(fortT.pct >= 92, `gros pack en touche ${fortT.pct.toFixed(1)} %`);
  assert.ok(fortT.pct - faibleT.pct >= 10, `touche : écart ${(fortT.pct - faibleT.pct).toFixed(1)} points (fort ${fortT.pct.toFixed(1)}, faible ${faibleT.pct.toFixed(1)})`);
  assert.ok(faibleT.pct >= 70, `pack faible en touche ${faibleT.pct.toFixed(1)} %`);
});

test('Pénalités de mêlée inchangées : environ un quart des mêlées', () => {
  const melees = lignes.filter(([k, o]) => k === 'scrum' && o !== 'unc').length;
  const part = 100 * lignes.filter(([k, o]) => k === 'scrum' && o === 'pen').length / melees;
  assert.ok(part >= 20 && part <= 32, `pénalités sur mêlée ${part.toFixed(1)} %`);
});

test('Pluie : touche et mêlée moins sûres, à packs égaux ; plafond et consignes conservés', () => {
  const r = JSON.parse(t.run(`(()=>{const f=S.worldMode.fixtures.find(f=>f.competitionId==='elite'&&f.phase==='league');S.round=f.week;
   const pair=[f.homeId,f.awayId];for(const id of pair)CDFranceCareer.ensureAISheet(S.clubs[id]);S.club=pair[0];
   const l=createRugbyMatch(pair,null,false);if(l.weatherVersion!==1||!l.meteo)throw Error('météo absente');
   const sec={...l.meteo,pluie:0},forte={...l.meteo,pluie:2},v=(m,kind,a,b)=>{l.meteo=m;return conqueteBase(l,kind,a,b)};
   return JSON.stringify({regles:conqueteRules(l),secT:v(sec,'lineout',70,70),forteT:v(forte,'lineout',70,70),secM:v(sec,'scrum',70,70),forteM:v(forte,'scrum',70,70),
    gros:v(sec,'lineout',80,70),faible:v(sec,'lineout',60,70),maxM:conqueteMax(l,'scrum'),maxT:conqueteMax(l,'lineout')})})()`));
  assert.equal(r.regles, true);
  assert.ok(r.secT - r.forteT >= .04, `touche : ${r.secT} au sec, ${r.forteT} sous forte pluie`);
  assert.ok(r.secM - r.forteM >= .02, `mêlée : ${r.secM} au sec, ${r.forteM} sous forte pluie`);
  assert.ok(r.gros > r.secT && r.faible < r.secT, 'qualité des sauteurs et du talonneur');
  assert.ok(r.maxM < 1 && r.maxT < 1, 'jamais garantie');
});
