'use strict';
// Jugement du staff, lot 2 (docs/jugement-staff-20261116.md) : composition confiée au staff, remplacements
// du staff et match délégué passent par la perception du staff du club du manager. Carrière Monde
// (world-champ, club 102), sans hasard : erreurs fixes par couple staff/joueur/poste.
const test = require('node:test');
const assert = require('node:assert/strict');
const {context} = require('./monde-harness.cjs');

const shared = context(827381, {club: 102}).toMatch(), base = shared.checkpoint();
test.after(() => shared.close());
const setup = () => shared.restore(base);

// Niveau du staff du club du manager imposé ; vraie valeur de la feuille et places différentes de l'optimum.
const MESURE = `var mesure=(niveau)=>{const orig=staffJudges,rules=STAFF_JUDGEMENT_RULES;
 try{STAFF_JUDGEMENT_RULES=0;const opt=buildSheet(club());STAFF_JUDGEMENT_RULES=rules;
  if(niveau!==null)staffJudges=id=>{const j=orig(id);for(const k of Object.keys(j))j[k]={...j[k],id:j[k].id+':'+niveau,level:niveau};return j};
  autoLineup();const a=[...S.lineup,...S.reserves];autoLineup();const b=[...S.lineup,...S.reserves];
  const val=ids=>ids.slice(0,15).reduce((s,id,i)=>s+fitScore(player(id),FAMILIES[i]),0);
  const o23=new Set([...opt.lineup,...opt.bench]),oxv=new Set(opt.lineup);
  // Joueurs retenus autrement (XV ou groupe), pas les permutations entre postes de même valeur (lot 3).
  return {ecarts:a.slice(0,15).filter(id=>!oxv.has(id)).length+a.slice(15).filter(id=>!o23.has(id)).length,perte:val(opt.lineup)-val(a),stable:a.join()===b.join()}}
 finally{staffJudges=orig;STAFF_JUDGEMENT_RULES=rules}}`;

test('Composition confiée au staff : proche de l’optimum avec un bon staff, écarts stables avec un staff faible', () => {
  const h = setup();
  const r = JSON.parse(h.run(`${MESURE};JSON.stringify({fort:mesure(85),faible:mesure(45),reel:mesure(null)})`));
  console.log('Composition du staff :', JSON.stringify(r));
  assert.ok(r.fort.ecarts <= 4 && r.fort.perte < 3, 'staff excellent : feuille proche de l’optimum');
  assert.ok(r.faible.ecarts > r.fort.ecarts, 'staff faible : plus d’écarts');
  assert.ok(r.faible.perte >= r.fort.perte, 'staff faible : feuille moins bonne');
  assert.ok(r.fort.stable && r.faible.stable && r.reel.stable, 'même couple, même choix d’une demande à l’autre');
});

test('Choix explicites du manager respectés ; IA et matchs anciens inchangés', () => {
  const h = setup();
  const r = JSON.parse(h.run(`JSON.stringify((()=>{autoLineup();
   const slot=13,cand=[...club().players].reverse().find(p=>!p.injury&&slotEligible(p,slot)&&!S.lineup.includes(p.id));
   S.reserves=S.reserves.map(id=>id===cand.id?null:id);S.lineup[slot]=cand.id;S.lineup[5]=null;repairSheet();const garde=S.lineup[slot]===cand.id,complet=S.lineup.every(Boolean);
   const f=CDWorldCareer.fixtures(S).find(f=>f.homeId===S.club||f.awayId===S.club),pair=[f.homeId,f.awayId];
   const l=createRugbyMatch(pair);const own=l.pair.indexOf(S.club),ai=1-own;
   const coupEnvoi=l.sheets[own].on[slot]===cand.id;
   const ia=staffSubsFit(l,ai)===fitScore,moi=staffSubsFit(l,own)!==fitScore;
   delete l.staffJudgementSubs;const ancien=staffSubsFit(l,own)===fitScore;
   const iaSheet=(()=>{const c=S.clubs[pair[ai]];const a=buildSheet(c);STAFF_JUDGEMENT_RULES=0;const b=buildSheet(c);STAFF_JUDGEMENT_RULES=1;return a.lineup.join()===b.lineup.join()})();
   return {garde,complet,coupEnvoi,ia,moi,ancien,iaSheet,version:createRugbyMatch(pair).staffJudgementSubs}})())`));
  assert.deepEqual(r, {garde: true, complet: true, coupEnvoi: true, ia: true, moi: true, ancien: true, iaSheet: true, version: 2});
  assert.equal(h.run('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'), true, 'sauvegarde valide');
});
