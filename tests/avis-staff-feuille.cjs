'use strict';
// Jugement du staff, lot 3 (docs/jugement-staff-20261116.md § Lot 3) : avis du staff sur la feuille de match,
// erreurs crédibles d'un staff faible (penchant stable, attribution des postes comprise), apprentissage avec
// le temps. Carrière Monde (world-champ, club 102), sans hasard.
const test = require('node:test');
const assert = require('node:assert/strict');
const {context} = require('./monde-harness.cjs');

const shared = context(827381, {club: 102}).toMatch(), base = shared.checkpoint();
test.after(() => shared.close());
const setup = () => shared.restore(base);

// Staff du club du manager remplacé par un staff de niveau donné (identité propre à `graine`).
const STAFF = `var avecStaff=(niveau,graine,fn)=>{const orig=staffJudges;
 staffJudges=id=>{const j=orig(id);for(const k of Object.keys(j))j[k]={...j[k],id:j[k].id+':'+graine,level:niveau};return j};
 try{return fn()}finally{staffJudges=orig}};
var optimum=()=>{const r=STAFF_JUDGEMENT_RULES;STAFF_JUDGEMENT_RULES=0;try{return buildSheet(club())}finally{STAFF_JUDGEMENT_RULES=r}};
var valeur=ids=>ids.reduce((s,id,i)=>s+fitScore(player(id),FAMILIES[i]),0);
var perte=s=>valeur(optimum().lineup)-valeur(s.lineup);
var autres=s=>{const o=new Set(optimum().lineup);return s.lineup.filter(id=>!o.has(id)).length};`;

test('Staff faible : erreurs visibles dans le XV et en première ligne ; staff excellent fiable', () => {
  const h = setup();
  const r = JSON.parse(h.run(`${STAFF};JSON.stringify([45,85].map(n=>{let xv=0,pl=0,p=0;const o=optimum();for(let g=0;g<12;g++)avecStaff(n,g,()=>{const s=buildSheet(club());xv+=autres(s);pl+=[0,1,2].filter(i=>s.lineup[i]!==o.lineup[i]).length;p+=perte(s)});return {xv:xv/12,pl:pl/12,perte:p/12}}))`));
  console.log('Staff 45 / 85 :', JSON.stringify(r));
  const [faible, fort] = r;
  assert.ok(faible.xv >= 2.5, 'staff faible : plusieurs titulaires différents de l’optimum');
  assert.ok(faible.pl > 0, 'staff faible : la première ligne peut aussi être mal jugée');
  assert.ok(faible.perte > 5 && faible.perte < 30, 'staff faible : feuille moins bonne, effet modéré');
  assert.equal(fort.pl, 0, 'staff excellent : première ligne juste');
  assert.ok(fort.perte < 1.5, 'staff excellent : feuille quasi optimale');
});

test('Feuille toujours valide, même choix d’une semaine à l’autre, IA inchangée', () => {
  const h = setup();
  const r = JSON.parse(h.run(`${STAFF};JSON.stringify(avecStaff(45,7,()=>{autoLineup();const a=[...S.lineup,...S.reserves],ok=sheetErrors().length===0;autoLineup();
   const ai=S.clubs.find(c=>c.id!==S.club&&c.players?.length>=23),x=buildSheet(ai),rr=STAFF_JUDGEMENT_RULES;STAFF_JUDGEMENT_RULES=0;const y=buildSheet(ai);STAFF_JUDGEMENT_RULES=rr;
   return {ok,stable:a.join()===[...S.lineup,...S.reserves].join(),ia:x.lineup.join()===y.lineup.join()&&x.bench.join()===y.bench.join()}}))`));
  assert.deepEqual(r, {ok: true, stable: true, ia: true});
});

test('Avis du staff : conseils par poste litigieux, raison et tutoiement ; rien quand le staff est d’accord', () => {
  const h = setup();
  const r = JSON.parse(h.run(`${STAFF};JSON.stringify((()=>{const o=optimum();S.lineup=[...o.lineup];S.reserves=[...o.bench];
   const fort=avecStaff(85,1,()=>staffSheetAdvice());let faible=null,g=0;for(;g<12&&!(faible?.conseils.length);g++)faible=avecStaff(45,g,()=>staffSheetAdvice());
   const deux=avecStaff(45,g-1,()=>staffSheetAdvice());
   avecStaff(45,g-1,()=>{autoLineup()});const accord=avecStaff(45,g-1,()=>staffSheetAdvice());
   return {fort:fort.conseils.length,faible,meme:JSON.stringify(deux)===JSON.stringify(faible),accord:accord.conseils.length}})())`));
  assert.equal(r.fort, 0, 'staff excellent : aucun désaccord avec la feuille optimale');
  assert.ok(r.faible.conseils.length > 0 && r.faible.conseils.length <= 4, 'staff faible : quelques conseils, pas plus de 4');
  for (const c of r.faible.conseils) {
    assert.match(c.texte, /^Ton .* préfère .+ à .+ (au poste|sur le banc)/, c.texte);
    assert.ok(['fraicheur', 'forme', 'experience', 'adversaire', 'niveau'].includes(c.raison));
    assert.ok(c.ecart >= 1.5 && c.staffId !== c.chosenId);
  }
  console.log('Avis :', r.faible.conseils.map(c => c.texte).join(' | '));
  assert.ok(r.meme, 'même avis à la demande suivante');
  assert.equal(r.accord, 0, 'feuille du staff : aucun conseil');
});

test('Le staff apprend à connaître ses joueurs : erreurs corrigées avec le temps', () => {
  const h = setup();
  const r = JSON.parse(h.run(`${STAFF};JSON.stringify((()=>{let avant=0,apres=0;const st=staffJudgementEnsure();
   for(let g=0;g<12;g++)avecStaff(45,g,()=>{delete st.connu;avant+=perte(buildSheet(club()));
    const j=staffJudges(S.club);st.connu={};for(const p of club().players)st.connu[p.id]=[judgeTag(p.fam<=3?j.avants:j.arrieres),10];apres+=perte(buildSheet(club()))});
   // Apprentissage réel en fin de match : joueurs ayant joué au moins 20 minutes, remis à zéro si le membre change.
   delete st.connu;const j=staffJudges(S.club),ids=club().players.slice(0,3).map(p=>p.id);
   const l={pair:[S.club,(S.club+1)%S.clubs.length],staffJudges:[j,j],sheets:[{minutes:{[ids[0]]:80,[ids[1]]:10,[ids[2]]:25}},{minutes:{}}]};
   learnStaffJudgement(l,st);learnStaffJudgement(l,st);const n=ids.map(id=>st.connu[id]?.[1]||0);
   const autre={...j,avants:{...j.avants,id:'autre'},arrieres:{...j.arrieres,id:'autre'}};
   const oublie=staffKnowledge(autre,player(ids[0]))===1&&staffKnowledge(j.avants.id===j.arrieres.id?j.avants:(player(ids[0]).fam<=3?j.avants:j.arrieres),player(ids[0]))<1;
   const valide=!!parseSaveDocument(JSON.stringify(createSaveDocument()));
   st.connu[ids[0]]=[1,500];let refuse=false;try{parseSaveDocument(JSON.stringify(createSaveDocument()))}catch(e){refuse=true}delete st.connu;
   return {avant:avant/12,apres:apres/12,n,oublie,valide,refuse}})())`));
  console.log('Perte avant / après 10 matchs :', r.avant.toFixed(2), r.apres.toFixed(2));
  assert.ok(r.apres < r.avant * .7, 'erreurs nettement réduites après dix matchs sous ses ordres');
  assert.deepEqual(r.n, [2, 0, 2]);
  assert.equal(r.oublie, true, 'un nouveau membre du staff repart de zéro');
  assert.equal(r.valide, true, 'sauvegarde valide avec la connaissance du staff');
  assert.equal(r.refuse, true, 'connaissance hors bornes refusée');
});

test('Moteur versionné : rencontres nouvelles en version 2, anciennes inchangées', () => {
  const h = setup();
  const r = JSON.parse(h.run(`JSON.stringify((()=>{const f=CDWorldCareer.fixtures(S).find(f=>f.homeId===S.club||f.awayId===S.club),pair=[f.homeId,f.awayId];
   const l=createRugbyMatch(pair),own=l.pair.indexOf(S.club),p=club().players[0];
   const v2=staffSubsFit(l,own)(p,p.fam);l.staffJudgementSubs=1;const v1=staffSubsFit(l,own)(p,p.fam);
   return {version:createRugbyMatch(pair).staffJudgementSubs,v1:v1===perceivedFitV1(l.staffJudges[own],p,p.fam),v2:v2===perceivedFit(l.staffJudges[own],p,p.fam),ia:staffSubsFit(l,1-own)===fitScore}})())`));
  assert.deepEqual(r, {version: 2, v1: true, v2: true, ia: true});
});
