'use strict';
// Plafond salarial des clubs gérés (carrière Monde, world-champ) : un club mis juste sous le plafond de sa
// ligue reçoit une urgence (espoir promu, renfort d'urgence), des renouvellements indispensables, des
// compléments d'effectif et un retour de prêt. Aucun ne franchit le plafond, la retenue forcée ne sert
// pas, et le club du manager n'est pas touché. Déterministe (graine fixe), sans Godot.
const assert = require('node:assert/strict');
const { ouvrir, creer } = require('./helpers/carriere-monde.cjs');

const jeu = ouvrir({ hebdomadaire: true, testVm: true });
try {
  creer(jeu, 0);
  const run = src => jeu.bridge.vm.run(src);
  const lire = src => JSON.parse(run('JSON.stringify(' + src + ')'));
  // Outils dans le moteur : clubs plafonnés, mise « juste sous le plafond », relevé des dépassements.
  run(`var T={
   cap:c=>{const l=budgetLigue(c.id),p=nativeClubBudget.PLAFOND_SALARIAL[l];return p?Math.floor((p+nativeClubBudget.creditAcademie(l,c.players,c.id))/52):Infinity},
   plancher:c=>nativeStartingSalaries.plancherHebdo(S,budgetLigue(c.id)),
   plafonnes:()=>S.clubs.filter(c=>c.id!==S.club&&Number.isFinite(T.cap(c))),
   serrer:(c,marge=60)=>{const top=c.players.slice().sort((a,b)=>b.salary-a.salary||a.id.localeCompare(b.id))[0];
    top.salary=Math.max(T.plancher(c),top.salary+T.cap(c)-marge-aiRosterPayroll(c));},
   depasse:()=>T.plafonnes().filter(c=>aiRosterPayroll(c)>T.cap(c)).map(c=>[c.id,aiRosterPayroll(c),T.cap(c)]),
   retenues:()=>Object.keys(S.clubDirections.tally).filter(k=>k.endsWith('|plafond:retenue-forcee')),
   compte:k=>Object.entries(S.clubDirections.tally).filter(([x])=>x.endsWith('|plafond:'+k)).reduce((n,[,v])=>n+v,0)};`);
  assert.ok(lire('T.plafonnes().length') >= 4, 'des clubs gérés de ligues plafonnées');
  const manager = lire('club().players.map(p=>[p.id,p.salary])');

  // 1. Urgence : poste vidé, club à 60 € du plafond, espoir coûteux au centre.
  const urgence = lire(`(()=>{const c=T.plafonnes()[0],a=aiRosterAcademy(c);T.serrer(c);
   const slot=1,avant=c.players.length;c.players=c.players.filter(p=>!slotEligible(p,slot)||p.salary>5000).slice(0,avant);
   const espoir=a.players.find(p=>p.age>=18&&slotEligible(p,slot))||(()=>{const p=academyPlayer(c.id,slot,S.season,777,false,c);p.age=19;a.players.push(p);return p})();
   espoir.salary=9000;T.serrer(c);
   const ok=aiRosterPromote(c,slot,true);
   return {ok,masse:aiRosterPayroll(c),plafond:T.cap(c),plancher:T.plancher(c),salaire:espoir.salary};})()`);
  assert.ok(urgence.masse <= urgence.plafond, 'urgence : ' + urgence.masse + ' > ' + urgence.plafond);
  if (urgence.ok) assert.ok(urgence.salaire < 9000, 'l’espoir promu en urgence signe sous sa demande (plancher ou reste de la limite)');

  // 2. Renouvellements : beaucoup de contrats échus dont des indispensables, club à 60 € du plafond.
  const renouv = lire(`(()=>{const cs=T.plafonnes().slice(1,3);
   for(const c of cs){T.serrer(c);for(const p of c.players)if(slotEligible(p,0)||slotEligible(p,1)||slotEligible(p,2)||seedHash(p.id)%3===0)p.contractEnd=S.season;}
   S.aiRoster.lastContracts=0;aiRosterContracts();
   return cs.map(c=>[aiRosterPayroll(c),T.cap(c)]);})()`);
  for (const [masse, plafond] of renouv) assert.ok(masse <= plafond, 'renouvellements : ' + masse + ' > ' + plafond);

  // 3. Compléments d'effectif : club sous 40 professionnels, déjà au plafond.
  const complement = lire(`(()=>{const c=T.plafonnes()[3];c.players=c.players.slice(0,36);T.serrer(c,10);
   budgetAvantProfondeur();nativeProfessionalDepth.fill(S);budgetProfondeur();
   return {n:c.players.length,masse:aiRosterPayroll(c),plafond:T.cap(c)};})()`);
  assert.ok(complement.n >= 40, 'effectif complété : ' + complement.n);
  assert.ok(complement.masse <= complement.plafond, 'compléments : ' + complement.masse + ' > ' + complement.plafond);

  // 4. Retour de prêt d'un joueur cher chez un club au plafond.
  const pret = lire(`(()=>{const home=T.plafonnes()[1],host=S.clubs.find(h=>h.id!==S.club&&h.id!==home.id&&!Number.isFinite(T.cap(h)))||T.plafonnes()[2];
   const p=host.players.slice().sort((a,b)=>b.salary-a.salary)[0];p.salary=Math.max(p.salary,20000);
   host.players.forEach(q=>{if(q!==p)q.salary=T.plancher(host)});
   S.clubDirections.loans.push({playerId:p.id,from:home.id,to:host.id,until:S.season-1});T.serrer(home);
   nativeClubDirections._internal.returnLoans();
   return {masse:aiRosterPayroll(home),plafond:T.cap(home)};})()`);
  assert.ok(pret.masse <= pret.plafond, 'retour de prêt : ' + pret.masse + ' > ' + pret.plafond);

  // Bilan : personne au-dessus du plafond, le filet n'a pas servi, le club du manager est intact.
  assert.deepEqual(lire('T.depasse()'), [], 'aucun club géré au-dessus du plafond de sa ligue');
  run('budgetConformite()');
  assert.deepEqual(lire('T.retenues()'), [], 'la retenue forcée n’a pas servi');
  assert.deepEqual(lire('club().players.map(p=>[p.id,p.salary])'), manager, 'club du manager inchangé');
  const comptes = lire(`['liberation','contrat-plancher','renouvellement-baisse','urgence-limite-club','urgence-refusee','renouvellement-refuse','complement-remplace','pret-prolonge','retour-pret-libere'].map(k=>[k,T.compte(k)])`);
  assert.ok(comptes.some(([, v]) => v > 0), 'les décisions sous plafond sont comptées');
  console.log('plafond-clubs-ia : OK', JSON.stringify(Object.fromEntries(comptes.filter(([, v]) => v))));
} finally { jeu.fermer(); }
