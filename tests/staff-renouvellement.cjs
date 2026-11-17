'use strict';
// Staff du club joué renouvelé par le directeur sportif (décision de Léo, 17/11/2026, suite de #874/#875 ;
// native/engine/staff-renouvellement.cjs, courrier ds_staff de club-mail.json).
//   1. Plan pur : prolonge les utiles, laisse partir surnombre, retraite et nettement moins bons que le marché ;
//      recrues à la portée du club (plafond de niveau selon la base et la consigne), jamais de poste laissé vide.
//   2. Carrière Monde (Toulouse) : régression de #875 — case décochée, le staff dont le contrat expire part et le
//      club n'a plus personne aux postes clés ; case cochée, le directeur sportif prolonge en mars et remplace les
//      départs à la saison suivante ; un courrier résume ; sauvegarde valide.
const assert = require('node:assert/strict');
const { test } = require('node:test');
const R = require('../native/engine/staff-renouvellement.cjs');
const M = require('./helpers/carriere-monde.cjs');

const CORE = ['coach', 'assistant', 'formation', 'scout', 'analyst'];
const membre = (id, role, estime, extra = {}) => ({ id, role, estime, age: 50, ansMax: 15, ...extra });

test('Plan pur : prolonge les utiles, laisse partir surnombre, retraite et moins bons que le marché', () => {
  const x = { base: 78, besoin: { coach: 1, assistant: 2, scout: 1 }, restants: { assistant: 1 }, marche: { coach: 70, assistant: 72, scout: 80 } };
  const plan = R.planifier([membre('c', 'coach', 75), membre('a1', 'assistant', 74), membre('a2', 'assistant', 73), membre('s', 'scout', 66), membre('v', 'coach', 80, { ansMax: 1 })], x);
  const par = Object.fromEntries(plan.map(d => [d.id, d]));
  assert.equal(par.v.raison, 'retraite');
  assert.equal(par.c.decision, 'prolonge');
  assert.equal(par.a1.decision, 'prolonge');
  assert.equal(par.a2.raison, 'surnombre', 'un adjoint suffit en plus de celui encore sous contrat');
  assert.equal(par.s.raison, 'mieux', 'le marché offre 80 contre 66');
  const stable = R.planifier([membre('b', 'scout', 74)], { ...x, marche: { scout: 84 } });
  assert.equal(stable[0].decision, 'prolonge', 'un membre au niveau du club reste, même si le marché offre mieux');
  assert.ok(plan.filter(d => d.decision === 'prolonge').every(d => d.ans >= 2 && d.ans <= 3), 'prolongation = au moins une saison de plus');
  assert.deepEqual(R.planifier([...[membre('c', 'coach', 75), membre('a1', 'assistant', 74)]].reverse(), x), R.planifier([membre('c', 'coach', 75), membre('a1', 'assistant', 74)], x), 'ordre sans effet');
});

test('Plan pur : recrues à la portée du club, jamais de poste vide', () => {
  assert.equal(R.plafondNiveau(70, 'equilibre'), 78);
  assert.equal(R.plafondNiveau(70, 'econome'), 73);
  assert.equal(R.plafondNiveau(90, 'equilibre'), 85);
  const cand = [{ id: 'top', role: 'coach', level: 85, estime: 86, ansMax: 10 }, { id: 'bon', role: 'coach', level: 76, estime: 74, ansMax: 10 }, { id: 'moyen', role: 'coach', level: 60, estime: 63, ansMax: 10 },
    { id: 'cher', role: 'analyst', level: 84, estime: 84, ansMax: 10 }, { id: 'cher2', role: 'analyst', level: 82, estime: 80, ansMax: 1 }];
  const r = R.recruter({ coach: 2, analyst: 1 }, cand, 78);
  assert.deepEqual(r.map(x => x.id), ['bon', 'moyen', 'cher2'], 'les deux meilleurs à sa portée, puis le moins exigeant faute de mieux');
  assert.ok(r.every(x => x.ans >= 1));
});

const COMPTE = `JSON.stringify(Object.fromEntries(${JSON.stringify(CORE)}.map(r=>[r,S.staffCareer.people.flat().filter(p=>p.clubId===S.club&&p.role===r).length])))`;
// Bascule du staff seule (comme à la fin de saison) : contrats échus, clubs IA complétés, club joué laissé tel quel.
const BASCULE = 'S.season++;CDStaffCareer.advance(S,S.season-1)';

test('Carrière Monde : sans délégation le staff tombe à zéro, avec le directeur sportif il est renouvelé', () => {
  const jeu = M.ouvrir({ hebdomadaire: true, testVm: true });
  const r = x => jeu.bridge.vm.run(x);
  try {
    M.creer(jeu, 0);
    const depart = JSON.parse(r(COMPTE));
    assert.ok(CORE.every(x => depart[x] >= 1), 'staff complet au départ : ' + JSON.stringify(depart));
    const etat = r('JSON.stringify(S)');
    // Échéances de toute l'équipe cette saison (au départ, tous les contrats durent deux saisons).
    const echoir = 'for(const p of S.staffCareer.people.flat())if(p.clubId===S.club)p.contractEnd=S.season;';

    // Régression : case décochée, personne ne renouvelle.
    r(echoir + 'S.manager.delegation.contracts=false;');
    assert.equal(r('dsStaffObserver("2027-03-10")'), false, 'case décochée : rien');
    r(BASCULE);
    r('dsStaffObserver("2027-08-10")');
    const vide = JSON.parse(r(COMPTE));
    assert.ok(CORE.every(x => vide[x] === 0), 'sans directeur sportif : postes clés vides ' + JSON.stringify(vide));

    // Case cochée (défaut) : prolongations en mars, remplacements à la saison suivante.
    r('S=JSON.parse(' + JSON.stringify(etat) + ');' + echoir);
    assert.equal(r('dsStaffObserver("2026-08-20")'), false, 'été : postes déjà pourvus, échéances pas encore ouvertes');
    assert.equal(r('dsStaffObserver("2027-03-10")'), true);
    const desk = JSON.parse(r('JSON.stringify(S.manager.staffDesk)'));
    assert.ok(desk.decisions.length >= 5, desk.decisions.length + ' décisions');
    const prol = desk.decisions.filter(d => d.d === 'prolonge');
    console.log(`Toulouse : ${prol.length} prolongés, ${desk.decisions.length - prol.length} laissés partir (${desk.decisions.filter(d => d.d === 'libere').map(d => d.raison).join(', ')})`);
    assert.ok(prol.length >= 3, 'il garde des membres utiles');
    assert.equal(r('dsStaffObserver("2027-03-11")'), false, 'une seule décision par membre');
    assert.doesNotThrow(() => r('validateCareer(JSON.parse(JSON.stringify(S)))'), 'sauvegarde valide');
    r(BASCULE);
    r('dsStaffObserver("2027-07-14")');
    const apres = JSON.parse(r(COMPTE));
    assert.ok(CORE.every(x => apres[x] >= 1), 'postes clés pourvus après la bascule ' + JSON.stringify(apres));
    const lots = JSON.parse(r('JSON.stringify(S.manager.staffDesk.lots)'));
    assert.ok(lots.some(l => l.prolonges.length) && lots.some(l => l.recrues.length || l.departs.length === 0), 'prolongations et arrivées tracées');
    const plafond = R.plafondNiveau(r('club().base'), 'equilibre');
    const recrues = JSON.parse(r(`JSON.stringify(S.staffCareer.history.filter(e=>e.kind==='hire'&&e.season===S.season).map(e=>S.staffCareer.people.flat().find(p=>p.id===e.id)?.level))`));
    assert.ok(recrues.every(l => l <= plafond), 'recrues à la portée du club : ' + recrues.join(', ') + ' ≤ ' + plafond);

    // Courrier qui résume.
    r("{const d=nativeSystems.domain('clubMail');for(let i=14;i<=20;i++)d.recevoir(S,'2027-07-'+i);}");
    const mails = JSON.parse(r("JSON.stringify(S.clubMail.mails.filter(m=>m.type==='ds_staff').map(m=>({id:m.id,vars:m.vars})))"));
    assert.ok(mails.length >= 1, 'courrier du directeur sportif');
    assert.ok(mails.every(m => /directeur sportif/.test(m.vars.signature) && m.vars.resume.length > 20));
    assert.ok(mails.some(m => /Arrivés au club/.test(m.vars.resume)), mails.map(m => m.vars.resume).join(' | '));
    // Bascule partielle (staff seul) : on vérifie le bureau, pas toute la carrière.
    assert.doesNotThrow(() => r('nativeStaffRenouvellement.valider(S.manager,S.season)'));
    assert.throws(() => r('{const s=JSON.parse(JSON.stringify(S));s.manager.staffDesk.decisions.push({id:"x",name:"x",role:"chef",d:"prolonge",raison:"solide",date:"2027-03-10"});nativeStaffRenouvellement.valider(s.manager,s.season)}'), /staff/);
  } finally { jeu.fermer(); }
});
