'use strict';
// Arrivée en urgence chez un club géré (carrière Monde, club 102) : le contrat se signe au plus à ce qui reste sous la limite
// de masse du club, jamais sous le plancher (docs/gdd/calendrier-mutations.md § 3 quinquies, décision 6).
const assert = require('node:assert/strict');
const { ouvrir } = require('./helpers/carriere-monde.cjs');

const jeu = ouvrir({ testVm: true, hebdomadaire: true });
try {
  jeu.regler(jeu.call('new_career', { mode: 'world-champ', club: 102, start: 'premiers-clubs', varyCurrent: true }));
  const run = src => JSON.parse(jeu.bridge.vm.run(src));
  // Arrange : un club géré dont la masse est juste sous sa limite, un espoir réclamant 2 000 € par semaine.
  const r = run(`(()=>{
   const c=S.clubs.find(x=>x.id!==S.club&&budgetLigue(x.id)==='champ'),limite=aiRosterWageLimit(c),plancher=aiRosterFloorWage(c);
   const total=c.players.reduce((n,q)=>n+q.salary,0);
   // masse ramenée à 400 € sous la limite : il ne reste de la place que pour un contrat modeste
   const ecart=total-(limite-400);c.players[0].salary=Math.max(plancher,c.players[0].salary-ecart);
   const avant=c.players.reduce((n,q)=>n+q.salary,0);
   const p={...c.players[1],id:'test-urgence',salary:2000};
   const ok=aiRosterFitWage(c,p,true);
   return JSON.stringify({ok,limite,plancher,avant,salaire:p.salary});})()`);
  assert.equal(r.ok, true, 'l\'urgence est acceptée');
  assert.ok(r.avant + r.salaire <= r.limite || r.salaire === r.plancher,
    'Contrat d\'urgence sous la limite du club (masse ' + r.avant + ' + ' + r.salaire + ' pour une limite de ' + r.limite + ', plancher ' + r.plancher + ')');
  assert.ok(r.salaire >= r.plancher, 'Jamais sous le plancher');
  // Une arrivée qui tient sous la limite garde son salaire.
  const r2 = run(`(()=>{const c=S.clubs.find(x=>x.id!==S.club&&budgetLigue(x.id)==='champ');
   const p={...c.players[1],id:'test-urgence-2',salary:aiRosterFloorWage(c)};const ok=aiRosterFitWage(c,p,true);return JSON.stringify({ok,salaire:p.salary,plancher:aiRosterFloorWage(c)});})()`);
  assert.equal(r2.salaire, r2.plancher, 'Un contrat au plancher n\'est pas touché');
  // Hors urgence (promotion au mérite) : un groupe de 20 dont la masse laisse 3 000 € sous la limite ne peut pas promouvoir un
  // espoir à 2 000 € : il faut garder 20 contrats au plancher pour atteindre le groupe minimal de 40.
  const r3 = run(`(()=>{const c=S.clubs.find(x=>x.id!==S.club&&budgetLigue(x.id)==='champ');
   c.players=c.players.slice(0,20);const plancher=aiRosterFloorWage(c),limite=aiRosterWageLimit(c);
   const total=c.players.reduce((n,q)=>n+q.salary,0);c.players[0].salary=Math.max(plancher,c.players[0].salary-(total-(limite-3000)));
   const p={...c.players[1],id:'test-merite',salary:2000};
   return JSON.stringify({ok:aiRosterFitWage(c,p,false),reste:limite-aiRosterPayroll(c),plancher});})()`);
  assert.ok(r3.reste >= 2000 && r3.reste < 2000 + 20 * r3.plancher, 'Scénario : la promotion tiendrait sous la limite mais pas avec le groupe minimal');
  assert.equal(r3.ok, false, 'Promotion refusée : elle prendrait la place du groupe minimal');
  console.log('contrat d\'urgence sous la limite du club : OK');
} finally { jeu.fermer(); }
