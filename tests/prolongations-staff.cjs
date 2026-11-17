'use strict';
// Prolongations confiées au directeur sportif (décision de Léo, 17/11/2026, suite de #870 ;
// native/engine/prolongations-staff.cjs, courriers ds_prolongation / ds_depart de club-mail.json).
//   1. Plan pur : utiles prolongés dans la masse que le club s'autorise, jamais au-dessus du plafond de la ligue,
//      consignes « économe » et « jeunes », ordre déterministe.
//   2. Carrière Monde (Toulouse, club 0) : case cochée par défaut (champ absent de la sauvegarde), rien hors de la
//      fenêtre mars-juin, toutes les échéances tranchées, masse engagée sous la limite et le plafond, un courrier par
//      décision avec ses réponses (annuler, prolonger quand même, consignes), sauvegarde valide, case décochée = rien.
//   3. Filet de la bascule de saison : les échéances non tranchées le sont avant le départ des joueurs libres,
//      avec les mêmes décisions (jugement déterministe).
const assert = require('node:assert/strict');
const { test } = require('node:test');
const P = require('../native/engine/prolongations-staff.cjs');
const M = require('./helpers/carriere-monde.cjs');

const joueur = (id, estime, extra = {}) => ({ id, estime, potentiel: estime, age: 27, demande: 1000, prime: 2000, profondeur: 3, ...extra });
const contexte = (extra = {}) => ({ base: 80, engage: 10000, limite: 14000, plafond: 20000, tresorerie: 1e6, restants: 30, cible: 30, consigne: 'equilibre', ...extra });

test('Plan pur : utiles prolongés dans la limite du club, jamais au-dessus du plafond', () => {
  const liste = [joueur('a', 90), joueur('b', 85), joueur('c', 84), joueur('d', 83), joueur('e', 82), joueur('f', 60)];
  const plan = P.planifier(liste, contexte());
  const par = Object.fromEntries(plan.map(x => [x.id, x]));
  assert.deepEqual(plan.filter(x => x.decision === 'prolonge').map(x => x.id), ['a', 'b', 'c', 'd'], 'les meilleurs d’abord, 4 × 1 000 € sous la limite de 14 000 €');
  assert.equal(par.e.raison, 'budget');
  assert.equal(par.f.raison, 'niveau');
  const plafond = P.planifier(liste, contexte({ limite: 50000, plafond: 12500 }));
  assert.equal(plafond.filter(x => x.decision === 'prolonge').length, 2, 'le plafond de la ligue l’emporte sur la limite du club');
  assert.ok(plafond.filter(x => x.decision === 'libere' && x.estime !== 60).some(x => x.raison === 'plafond'));
  assert.deepEqual(P.planifier([...liste].reverse(), contexte()), plan, 'ordre des candidats sans effet');
  const pauvre = P.planifier([joueur('a', 90, { prime: 5000 })], contexte({ tresorerie: 4000 }));
  assert.equal(pauvre[0].raison, 'tresorerie');
});

test('Plan pur : consignes économe et jeunes, profondeur et effectif', () => {
  const liste = Array.from({ length: 6 }, (_, i) => joueur('j' + i, 84));
  const n = c => P.planifier(liste, contexte({ consigne: c, limite: 16000 })).filter(x => x.decision === 'prolonge').length;
  assert.equal(n('equilibre'), 6);
  assert.ok(n('econome') < n('equilibre'), 'économe : marge sous la masse autorisée');
  const jeune = joueur('jeune', 70, { age: 20, potentiel: 84 }), vieux = joueur('vieux', 74, { age: 32 });
  const eq = P.planifier([jeune, vieux], contexte()), je = P.planifier([jeune, vieux], contexte({ consigne: 'jeunes' }));
  assert.equal(eq.find(x => x.id === 'jeune').decision, 'libere');
  assert.equal(je.find(x => x.id === 'jeune').decision, 'prolonge', 'consigne jeunes : le jeune prometteur est gardé');
  assert.equal(P.planifier([joueur('p', 70, { profondeur: 1 })], contexte())[0].raison, 'profondeur');
  assert.equal(P.planifier([joueur('p', 71)], contexte({ restants: 20 }))[0].raison, 'effectif');
  assert.equal(P.saisonsAjoutees(24, 10), 3);
  assert.equal(P.saisonsAjoutees(29, 10), 2);
  assert.equal(P.saisonsAjoutees(34, 2), 1);
  assert.equal(P.saisonsAjoutees(36, 1), 0, 'retraite prévue : pas de prolongation');
});

const DECISIONS = 'JSON.stringify(S.manager.contractDesk.decisions.map(x=>[x.id,x.d,x.raison,x.salary,x.end]))';

test('Carrière Monde : le directeur sportif tranche, écrit, et le manager garde la main', () => {
  const jeu = M.ouvrir({ hebdomadaire: true, testVm: true });
  const r = x => jeu.bridge.vm.run(x);
  try {
    let model = M.creer(jeu, 0);
    assert.equal(model.decisions.delegation.contracts, true, 'cochée par défaut');
    assert.equal(r('S.manager.delegation.contracts'), undefined, 'champ absent tant que le joueur n’a rien choisi');
    assert.equal(r('dsContratsObserver()'), false, 'rien en été : la fenêtre ouvre en mars');
    const echeances = r('club().players.filter(p=>p.contractEnd===S.season&&nativeProlongations.saisonsAjoutees(p.age,careerContractYears(p))>=1).length');
    assert.ok(echeances >= 5, echeances + ' échéances');
    const n = r('dsContratsTrancher(false)');
    assert.equal(n, echeances, 'toutes les échéances ouvertes sont tranchées');
    assert.equal(r('dsContratsTrancher(false)'), 0, 'une seule décision par joueur');
    const plan = JSON.parse(r(DECISIONS));
    const gardes = plan.filter(x => x[1] === 'prolonge'), partis = plan.filter(x => x[1] === 'libere');
    console.log(`Toulouse : ${gardes.length} prolongés, ${partis.length} laissés partir (${partis.map(x => x[2]).join(', ')})`);
    assert.ok(gardes.length >= 3 && partis.length >= 1, 'il garde des joueurs et en laisse partir');
    const masse = JSON.parse(r('JSON.stringify({engage:club().players.filter(p=>p.contractEnd>S.season).reduce((t,p)=>t+dsContratsSalaireSuivant(p),0),courant:club().players.reduce((t,p)=>t+p.salary,0),...dsContratsLimites()})'));
    assert.ok(masse.engage <= masse.limite + 1, 'masse engagée sous la limite que le club s’autorise');
    assert.ok(masse.engage <= masse.plafond + 1, 'jamais au-dessus du plafond de la ligue');

    const courant = r('club().players.reduce((t,p)=>t+p.salary,0)');
    assert.equal(courant, masse.courant);
    for (const [id, , , salaire, fin] of gardes) {
      const p = JSON.parse(r(`JSON.stringify(club().players.find(p=>p.id===${JSON.stringify(id)}))`));
      assert.equal(p.contractEnd, fin); assert.ok(fin > r('S.season'));
      assert.equal(r(`dsContratsSalaireSuivant(club().players.find(p=>p.id===${JSON.stringify(id)}))`), salaire, 'nouveau salaire dès la saison prochaine');
    }
    // Courrier : un mail par décision, réponses disponibles.
    r("{const d=nativeSystems.domain('clubMail');d.recevoir(S,'2026-08-16');for(let i=17;i<=30;i++)d.recevoir(S,'2026-08-'+i);}");
    const mails = JSON.parse(r("JSON.stringify(S.clubMail.mails.filter(m=>m.type.startsWith('ds_')).map(m=>({id:m.id,type:m.type,player:m.player,vars:m.vars,status:m.status})))"));
    assert.ok(mails.length >= 3, mails.length + ' courriers du directeur sportif');
    assert.ok(mails.every(m => /directeur sportif/.test(m.vars.signature) && m.vars.raison), 'signature et raison');
    assert.equal(new Set(mails.map(m => m.player)).size, mails.length, 'un courrier par joueur');
    const ouverts = mails.filter(m => m.status === 'nouveau'), prolonge = ouverts.find(m => m.type === 'ds_prolongation'), departs = ouverts.filter(m => m.type === 'ds_depart'), depart = departs.find(m => !JSON.parse(r(`JSON.stringify(dsContratsRefus('forcer',${JSON.stringify(m.player)}))`))) || departs[0];
    assert.ok(mails.some(m => m.type === 'ds_prolongation') && mails.some(m => m.type === 'ds_depart'), 'prolongations et départs annoncés');
    assert.ok(prolonge && depart, 'des courriers encore ouverts');
    assert.ok(mails.length >= 20, 'toutes les décisions annoncées en deux semaines (' + mails.length + ')');
    // Annuler une prolongation : ancien contrat, prime remboursée, il partira.
    const avant = JSON.parse(r(`JSON.stringify((()=>{const e=S.manager.contractDesk.decisions.find(x=>x.id===${JSON.stringify(prolonge.player)});return {cash:club().cash,fee:e.fee,old:club().players.find(p=>p.id===e.id).salary,oldEnd:e.oldEnd}})())`));
    model = jeu.call('club_mail_reply', { id: prolonge.id, choice: 'annuler' });
    const apres = JSON.parse(r(`JSON.stringify((()=>{const p=club().players.find(p=>p.id===${JSON.stringify(prolonge.player)});return {cash:club().cash,salary:p.salary,end:p.contractEnd}})())`));
    assert.equal(apres.salary, avant.old); assert.equal(apres.end, avant.oldEnd);
    assert.equal(apres.cash, avant.cash + avant.fee, 'prime remboursée');
    assert.equal(jeu.brut('club_mail_reply', { id: prolonge.id, choice: 'annuler' }).ok, false, 'une seule réponse');
    // Prolonger quand même un joueur laissé partir (sous le plafond).
    const raisonDepart = JSON.parse(r(`JSON.stringify(dsContratsRefus('forcer',${JSON.stringify(depart.player)}))`));
    if (!raisonDepart) {
      model = jeu.call('club_mail_reply', { id: depart.id, choice: 'garder' });
      assert.ok(r(`club().players.find(p=>p.id===${JSON.stringify(depart.player)}).contractEnd>S.season`), 'prolongé à la demande du manager');
      assert.ok(r('club().players.filter(p=>p.contractEnd>S.season).reduce((t,p)=>t+dsContratsSalaireSuivant(p),0)<=dsContratsLimites().plafond+1'), 'toujours sous le plafond');
    } else console.log('prolonger quand même indisponible : ' + raisonDepart);
    // Consignes : « équilibre » indisponible tant que c'est déjà la consigne ; « économe » la change.
    const autre = ouverts.find(m => m.type === 'ds_prolongation' && m.id !== prolonge.id);
    if (autre) {
      assert.equal(jeu.brut('club_mail_reply', { id: autre.id, choice: 'equilibre' }).ok, false, 'déjà la consigne');
      model = jeu.call('club_mail_reply', { id: autre.id, choice: 'econome' });
      assert.equal(model.decisions.delegation.contractsPolicy, 'econome');
    }
    assert.doesNotThrow(() => r('validateCareer(JSON.parse(JSON.stringify(S)))'), 'sauvegarde valide');
    assert.throws(() => r('{const s=JSON.parse(JSON.stringify(S));s.manager.delegation.contractsPolicy="tout";validateCareer(s)}'), /consigne/);
    // Case décochée : plus rien n'est tranché.
    model = jeu.call('set_delegation', { key: 'contracts', enabled: false });
    assert.equal(model.decisions.delegation.contracts, false);
    r('S.manager.contractDesk.decisions=[]');
    assert.equal(r('dsContratsTrancher(false)'), 0, 'décochée : le manager gère seul');
  } finally { jeu.fermer(); }
});

test('Filet de la bascule de saison : échéances tranchées avant le départ des joueurs libres, mêmes décisions', () => {
  const jeu = M.ouvrir({ hebdomadaire: true, testVm: true });
  const r = x => jeu.bridge.vm.run(x);
  try {
    M.creer(jeu, 0);
    const attendu = JSON.parse(r('(()=>{const t=JSON.stringify(S);dsContratsTrancher(false);const d=' + DECISIONS + ';S=JSON.parse(t);return d})()'));
    const gardes = attendu.filter(x => x[1] === 'prolonge').map(x => x[0]), partis = attendu.filter(x => x[1] === 'libere').map(x => x[0]);
    r('S.economy.settled=0;settleContracts()');
    const ids = new Set(JSON.parse(r('JSON.stringify(club().players.map(p=>p.id))')));
    assert.ok(gardes.every(id => ids.has(id)), 'les prolongés restent');
    for (const [id, , , salaire] of attendu.filter(x => x[1] === 'prolonge')) assert.equal(r(`club().players.find(p=>p.id===${JSON.stringify(id)}).salary`), salaire, 'nouveau salaire appliqué à la bascule');
    assert.ok(partis.every(id => !ids.has(id)), 'les autres partent libres');
    assert.ok(r('S.manager.contractDesk.decisions.every(x=>x.final)'), 'décisions du filet (sans courrier)');
    assert.deepEqual(JSON.parse(r(DECISIONS)).map(x => x.slice(0, 3)), attendu.map(x => x.slice(0, 3)), 'jugement déterministe');
  } finally { jeu.fermer(); }
});
