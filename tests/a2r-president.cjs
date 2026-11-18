'use strict';
// Règles financières du rugby français (native/engine/a2r.cjs, president-reprise.cjs, branchements dans club-mail.cjs,
// gestion.cjs, interclub-market.cjs, club-directions.cjs).
//   1. Unitaires purs : niveaux de l'A2R, soutien du propriétaire, réponse de l'actionnaire, homologation, joueurs désignés.
//   2. Moteur Monde (`world-champ`, club 0) : audition de juin, mesures du club joué et des clubs gérés, courrier et
//      réponses (apport, appel), échéance du 30 juin, fin des mesures au mercato d'été.
//   3. Moteur Monde : le président désigne des ventes après un achat, un seul courrier, vente à l'échéance, renonce si la
//      caisse remonte, pas deux interventions rapprochées ; un club géré passe en « vente » tant qu'il attend.
const assert = require('node:assert/strict');
const { test } = require('node:test');
const A = require('../native/engine/a2r.cjs');
const P = require('../native/engine/president-reprise.cjs');
const DATA = require('../native/engine/club-mail.json');
const { ouvrir, creer } = require('./helpers/carriere-monde.cjs');

test('A2R : niveaux par part des recettes, tolérance, pas d’aggravation automatique', () => {
  const r = 10e6;
  assert.equal(A.examen({ trou: 0, recettes: r }).niveau, 0);
  assert.equal(A.examen({ trou: 0.03 * r, recettes: r }).niveau, 0, 'tolérance de 3 %');
  assert.equal(A.examen({ trou: 0.04 * r, recettes: r }).niveau, 1);
  assert.equal(A.examen({ trou: 0.06 * r, recettes: r }).niveau, 2);
  assert.equal(A.examen({ trou: 0.1 * r, recettes: r }).niveau, 3);
  assert.equal(A.examen({ trou: 0.2 * r, recettes: r }).niveau, 4);
  assert.equal(A.examen({ trou: 0.04 * r, recettes: r, recidive: true }).niveau, 1, 'la récidive n’aggrave pas');
});

test('A2R : situation de fin de saison avec le soutien promis du propriétaire, et la dette', () => {
  const compte = { enveloppe: 1e6, reserve: 2e6 };
  // Caisse à −0,5 M€ après 3 M€ de pertes : le propriétaire comble jusqu'à son enveloppe (1 M€) → caisse finale +0,5 M€,
  // soit 1,5 M€ sous la réserve de 2 M€ : la perte non comblée a entamé la réserve.
  let s = A.situation({ tresorerie: -0.5e6, depart: 2.5e6, compte });
  assert.equal(s.apportPrevu, 1e6); assert.equal(s.caisseFin, 0.5e6); assert.equal(s.trou, 1.5e6);
  s = A.situation({ tresorerie: -2e6, depart: 2.5e6, compte });
  assert.equal(s.caisseFin, -1e6); assert.equal(s.trou, 3e6);
  // Perte absorbée en restant au-dessus de la réserve : club sain. Bénéfice sous la réserve : sain aussi.
  assert.equal(A.situation({ tresorerie: 5e6, depart: 6e6, compte }).trou, 0);
  assert.equal(A.situation({ tresorerie: 1e6, depart: 0.5e6, compte }).trou, 0);
  // Perte qui fait passer de 2,5 à 1,2 M€ : 0,8 M€ sous la réserve.
  assert.equal(A.situation({ tresorerie: 1.2e6, depart: 2.5e6, compte: { enveloppe: 0, reserve: 2e6 } }).trou, 0.8e6);
  s = A.situation({ tresorerie: 3e6, depart: 1e6, compte, dette: 0.4e6 });
  assert.equal(s.trou, 0.4e6, 'la dette compte');
  assert.equal(A.situation({ tresorerie: -1e6, depart: 0, compte: { enveloppe: 0, reserve: 1e6 } }).trou, 1e6, 'pas compté deux fois');
});

test('A2R : réponse de l’actionnaire (association, montant, déterminisme)', () => {
  assert.deepEqual(A.reponseActionnaire({ type: 'association', montant: 1, enveloppe: 9e9, recettes: 1e7, cle: 'x' }), { accepte: false, motif: 'association' });
  assert.equal(A.reponseActionnaire({ type: 'entreprise', montant: 5e6, enveloppe: 1e6, recettes: 1e7, cle: 'x' }).motif, 'montant');
  let oui = 0;
  for (let i = 0; i < 200; i++) {
    const r = A.reponseActionnaire({ type: 'mecene', montant: 1e6, enveloppe: 1e6, recettes: 1e7, cle: 'k' + i });
    assert.deepEqual(r, A.reponseActionnaire({ type: 'mecene', montant: 1e6, enveloppe: 1e6, recettes: 1e7, cle: 'k' + i }), 'déterministe');
    if (r.accepte) oui++;
  }
  assert.ok(oui > 140 && oui < 195, 'un mécène suit le plus souvent : ' + oui);
  for (const m of Object.values(A.REFUS)) assert.ok(m.length <= 200, 'verdict court');
});

test('A2R : homologation des recrues et masse des clubs gérés', () => {
  const d = n => ({ niveau: n, encadrement: 50000, montant: 1e6 });
  assert.equal(A.refusRecrue(null, { masseHebdo: 1, salaire: 1 }), '');
  assert.equal(A.refusRecrue(d(1), { masseHebdo: 45000, salaire: 5000 }), '', 'sous l’encadrement');
  assert.match(A.refusRecrue(d(1), { masseHebdo: 45000, salaire: 5001 }), /encadre la masse salariale/);
  assert.match(A.refusRecrue(d(2), { masseHebdo: 0, salaire: 1 }), /n’homologue pas/);
  assert.match(A.refusRecrue(d(3), { masseHebdo: 0, salaire: 1 }), /30 juin/);
  assert.match(A.refusRecrue(d(4), { masseHebdo: 0, salaire: 1 }), /interdit/);
  assert.equal(A.limiteGeree(null, { limite: 70000, masseHebdo: 60000 }), 70000);
  assert.equal(A.limiteGeree(d(1), { limite: 70000, masseHebdo: 60000 }), 50000);
  assert.equal(A.limiteGeree(d(4), { limite: 70000, masseHebdo: 60000 }), 60000, 'gelée : aucune place pour une recrue');
});

test('Président : déclenchement après un achat, joueurs désignés hors des douze meilleurs', () => {
  assert.equal(P.declenche({ avant: 5e6, apres: 3e6, reserve: 4e6, date: '2026-09-01' }), true, 'franchit la réserve');
  assert.equal(P.declenche({ avant: 5e6, apres: 4.5e6, reserve: 4e6, date: '2026-09-01' }), false, 'reste au-dessus');
  assert.equal(P.declenche({ avant: 3e6, apres: 2.9e6, reserve: 4e6, date: '2026-09-01' }), false, 'déjà dessous, à peine creusée');
  assert.equal(P.declenche({ avant: 3e6, apres: 2.5e6, reserve: 4e6, date: '2026-09-01' }), true, 'déjà dessous, nettement creusée');
  assert.equal(P.declenche({ avant: 5e6, apres: 3e6, reserve: 4e6, date: '2026-10-01', derniere: '2026-09-01' }), false, 'pas deux fois en quatre mois');
  assert.equal(P.declenche({ avant: 5e6, apres: 3e6, reserve: 4e6, date: '2027-01-15', derniere: '2026-09-01' }), true);
  const joueurs = Array.from({ length: 30 }, (_, i) => ({ id: 'p' + String(i).padStart(2, '0'), name: 'J' + i, pos: 'C', note: 90 - i, salaire: 1000 * (i % 7 + 1), valeur: 100000 + i * 1000, bloque: i === 20 }));
  const d = P.designer(joueurs, { manque: 150000 });
  assert.ok(d.length >= 2 && d.length <= 3, d.length + ' joueurs');
  assert.ok(d.every(p => p.note <= 90 - 12), 'jamais un des douze meilleurs');
  assert.ok(!d.some(p => p.bloque), 'pas de joueur bloqué');
  assert.ok(d[0].salaire >= d[1].salaire, 'les mieux payés d’abord');
  assert.equal(P.designer(joueurs, { manque: 9e9 }).length, 3, 'trois au plus');
  const v = P.courrier({ echeance: '2027-02-14', joueurs: d }, { tresorerie: 3e6, reserve: 4e6 });
  assert.equal(v.echeance, '14 février'); assert.match(v.manque, /1 000 000 €/); assert.equal(v.liste.split('(').length - 1, d.length); assert.doesNotMatch(v.liste, /\n/);
});

test('Courrier : types, variables présentes, réponses', () => {
  const vars = { ...A.courrier({ montant: 1.2e6, part: 0.1, dette: 0, encadrement: 100000, recidive: true }, { saison: '2027-2028' }), constat: 'x' };
  for (const id of ['a2r_conditions', 'a2r_homologation', 'a2r_apport', 'a2r_interdiction']) {
    const t = DATA.types[id];
    assert.equal(t.declencheur, 'a2r'); assert.ok(t.arret, id);
    for (const f of t.formulations) for (const [, k] of (f.sujet + f.corps).matchAll(/\{([^}]+)\}/g)) assert.ok(k in vars, id + ' : ' + k);
  }
  assert.equal(DATA.types.a2r_conditions.reponses.length, 0, 'niveau 1 : simple information');
  assert.deepEqual(DATA.types.a2r_apport.reponses.map(r => r.id), ['apport', 'appel', 'acte']);
  const rv = P.courrier({ echeance: '2027-02-14', joueurs: [] }, { tresorerie: 1, reserve: 2 });
  for (const f of DATA.types.reprise_president.formulations) for (const [, k] of (f.sujet + f.corps).matchAll(/\{([^}]+)\}/g)) assert.ok(k in rv, 'reprise : ' + k);
  assert.deepEqual(DATA.types.reprise_president.reponses.map(r => r.id), ['lister', 'confier', 'delai']);
});

// --- Moteur ---
const outils = jeu => {
  const run = s => jeu.bridge.vm.run(s), lire = s => JSON.parse(run('JSON.stringify(' + s + ')'));
  const recevoir = date => lire(`(()=>{nativeSystems.domain('clubMail').recevoir(S,'${date}');return S.clubMail.mails.filter(m=>/^(a2r_|reprise_president)/.test(m.type)).map(m=>({id:m.id,type:m.type,status:m.status,vars:m.vars}));})()`);
  return { run, lire, recevoir };
};

test('Moteur Monde : audition de juin, mesures, courrier, apport, appel, échéance, fin au mercato d’été', { timeout: 170000 }, () => {
  const jeu = ouvrir({ hebdomadaire: true, testVm: true });
  try {
    creer(jeu, 0);
    const { run, lire, recevoir } = outils(jeu);
    assert.equal(lire('budgetLigue(S.club)'), 'elite');
    recevoir('2027-06-13'); // première réception de la boîte : mémoire seule
    // Comptes de la saison simulés : 20 M€ de recettes partout ; club joué à −2 M€ (10 % : apport demandé) ; trois clubs
    // gérés français à −5 M€ (25 % : interdiction), −0,8 M€ (4 % : conditions), −1,2 M€ (6 % : homologation). Pas d'enveloppe.
    const ids = lire(`(()=>{const fr=S.clubs.filter(c=>c.id!==S.club&&nativeA2R.DIVISIONS.includes(budgetLigue(c.id))).map(c=>c.id).slice(0,3);
      const etr=S.clubs.find(c=>!nativeA2R.DIVISIONS.includes(budgetLigue(c.id))).id;
      for(const c of S.clubs){const k=S.clubBudget.clubs[c.id];k.recettes=20e6;k.depart=Math.max(0,c.cash);}
      const rouge=(id,cash)=>{S.clubs[id].cash=cash;S.clubBudget.clubs[id].enveloppe=0;S.clubBudget.clubs[id].depart=0;};
      rouge(S.club,-2e6);rouge(fr[0],-5e6);rouge(fr[1],-0.8e6);rouge(fr[2],-1.2e6);rouge(etr,-5e6);
      a2rAudition('2027-06-14');return {fr,etr};})()`);
    const dec = lire('S.a2r.decisions');
    assert.equal(dec[0].niveau, 3); assert.equal(dec[0].montant, 2e6);
    assert.equal(dec[ids.fr[0]].niveau, 4); assert.equal(dec[ids.fr[1]].niveau, 1); assert.equal(dec[ids.fr[2]].niveau, 2);
    assert.equal(dec[ids.etr], undefined, 'l’A2R ne contrôle que les clubs français');
    assert.equal(Object.keys(dec).length, 4, 'les clubs aux comptes sains ne sont pas convoqués');
    // Étiquette de santé financière (club-finance-health.cjs) : seuls les clubs « Fragile » passent devant la commission.
    assert.equal(lire('typeof santeFiche'), 'function');
    assert.ok([0, ...ids.fr].every(id => lire(`santeFiche(${id}).etiquette`) === 'fragile'));
    // Mesures : club joué sans recrue ; club géré interdit = masse gelée ; encadré = masse du jour de l'audition.
    assert.match(lire('a2rRefusRecrue(1000)'), /30 juin/);
    const g = lire(`(()=>{const a=S.clubs[${ids.fr[0]}],b=S.clubs[${ids.fr[1]}];return {a:aiRosterWageLimit(a),am:Math.min(budgetMasse(a),aiRosterWageLimitA2RV1(a)),b:aiRosterWageLimit(b),be:S.a2r.decisions[${ids.fr[1]}].encadrement,bv:aiRosterWageLimitA2RV1(b)};})()`);
    assert.equal(g.a, g.am, 'interdiction : aucune place pour une recrue');
    assert.equal(g.b, Math.min(g.be, g.bv), 'conditions : masse encadrée');
    // Courrier : un seul, du niveau décidé, avec ses réponses.
    let mails = recevoir('2027-06-15');
    assert.equal(mails.length, 1, JSON.stringify(mails)); assert.equal(mails[0].type, 'a2r_apport');
    assert.doesNotMatch(JSON.stringify(mails[0].vars), /undefined|NaN/);
    assert.equal(recevoir('2027-06-16').length, 1, 'pas de second courrier');
    // Réponse : demande d'apport au propriétaire (club 0 : sa réponse est déterministe).
    const avant = lire('({cash:club().cash,trust:S.trust})');
    const r = jeu.brut('club_mail_reply', { id: mails[0].id, choice: 'apport' });
    assert.equal(r.ok, true, r.error);
    const d0 = lire('S.a2r.decisions[S.club]');
    if (d0.apport === 'verse') {
      assert.equal(d0.niveau, 1); assert.equal(lire('club().cash'), avant.cash + 2e6); assert.equal(lire('S.trust'), Math.max(0, avant.trust - 3));
    } else {
      assert.equal(d0.apport, 'refuse'); assert.equal(d0.niveau, 3);
      // Échéance du 30 juin sans comptes rétablis : interdiction de recruter.
      run(`a2rEcheances('2027-06-30',false)`);
      assert.equal(lire('S.a2r.decisions[S.club].niveau'), 4);
      assert.match(lire('a2rRefusRecrue(1000)'), /interdit/);
    }
    // Appel (une seule fois) : frais payés, verdict déterministe.
    run(`S.a2r.decisions[S.club].niveau=4;S.a2r.decisions[S.club].initial=4;S.clubMail.sent={};`);
    mails = recevoir('2027-06-20').filter(m => m.type === 'a2r_interdiction');
    assert.equal(mails.length, 1);
    jeu.regler(jeu.call('snapshot')); // rendez-vous de la direction éventuel (confiance entamée)
    const c0 = lire('club().cash');
    const ra = jeu.brut('club_mail_reply', { id: mails[0].id, choice: 'appel' });
    assert.equal(ra.ok, true, ra.error);
    assert.equal(lire('club().cash'), c0 - A.APPEL.frais);
    const da = lire('S.a2r.decisions[S.club]');
    assert.ok(['gagne', 'perdu'].includes(da.appel)); assert.equal(da.niveau, da.appel === 'gagne' ? 1 : 4);
    assert.equal(lire(`a2rRefus('appel')`), 'Le club a déjà fait appel.');
    // Échéance des clubs gérés : un apport attendu est versé ou devient une interdiction.
    run(`S.a2r.decisions[${ids.fr[2]}].niveau=3;`);
    run(`a2rEcheances('2027-06-30',false)`);
    const d2 = lire(`S.a2r.decisions[${ids.fr[2]}]`);
    assert.ok(d2.niveau === 1 && d2.apport === 'verse' || d2.niveau === 4, JSON.stringify(d2));
    // Comptes rétablis (homologation) : la mesure redescend à « conditions » à la semaine suivante.
    run(`S.a2r.decisions[${ids.fr[1]}].niveau=2;S.clubs[${ids.fr[1]}].cash=5e6;`);
    run(`a2rSemaine()`);
    assert.equal(lire(`S.a2r.decisions[${ids.fr[1]}].niveau`), 1);
    // Fin du mercato d'été (3e semaine de la saison suivante) : plus aucune mesure.
    const fin = lire(`(()=>{const w=S.worldMode.week,e=S.a2r;for(const d of Object.values(e.decisions))d.saison=S.season-1;S.worldMode.week=3;
      const r={refus:a2rRefusRecrue(1e6),lim:aiRosterWageLimit(S.clubs[${ids.fr[0]}])===aiRosterWageLimitA2RV1(S.clubs[${ids.fr[0]}])};S.worldMode.week=1;r.avant=!!a2rDecision(${ids.fr[0]});S.worldMode.week=w;return r;})()`);
    assert.deepEqual(fin, { refus: '', lim: true, avant: true });
    // Récidive : mentionnée dans le courrier, sans aggraver la mesure.
    run(`(()=>{for(const d of Object.values(S.a2r.decisions))d.saison=S.season;S.a2r.historique[${ids.fr[1]}]=S.season-1;S.clubs[${ids.fr[1]}].cash=-0.8e6;S.a2r.saison=null;a2rAudition('2027-06-14');})()`);
    assert.equal(lire(`S.a2r.decisions[${ids.fr[1]}].niveau`), 1);
    assert.equal(lire(`S.a2r.decisions[${ids.fr[1]}].recidive`), true);
    assert.equal(lire('nativeA2R.valide(S.a2r)'), true);
  } finally { jeu.fermer(); }
});

test('Moteur Monde : le président désigne des ventes, un seul courrier, vend à l’échéance ou renonce', { timeout: 170000 }, () => {
  const jeu = ouvrir({ hebdomadaire: true, testVm: true });
  try {
    creer(jeu, 0);
    const { run, lire, recevoir } = outils(jeu);
    const jour = lire('CDWorldCareer.calendarToday(S)');
    // Achat simulé : la caisse tombe 1,5 M€ sous la réserve.
    const r = lire(`(()=>{const c=club(),res=S.clubBudget.clubs[c.id].reserve,avant=res+1e6;c.cash=res-1.5e6;
      return {ok:repriseApresAchat(c,avant),res,plan:S.presidentReprise.clubs[c.id]};})()`);
    assert.equal(r.ok, true); assert.ok(r.plan.joueurs.length >= 2 && r.plan.joueurs.length <= 3);
    const top = lire('club().players.slice().sort((a,b)=>b.rating-a.rating).slice(0,12).map(p=>p.id)');
    assert.ok(r.plan.joueurs.every(j => !top.includes(j.id)), 'aucun des douze meilleurs');
    assert.equal(lire(`repriseApresAchat(club(),club().cash+1e6)`), false, 'une intervention à la fois');
    // Un seul courrier, avec ses trois réponses (première réception de la boîte : mémoire seule).
    recevoir(P.decaler(jour, -1));
    let mails = recevoir(jour);
    assert.equal(mails.length, 1); assert.equal(mails[0].type, 'reprise_president');
    assert.doesNotMatch(JSON.stringify(mails[0].vars), /undefined|NaN/);
    assert.equal(recevoir(P.decaler(jour, 1)).length, 1, 'pas de relance');
    // « Les mettre sur la liste des transferts ».
    const rl = jeu.brut('club_mail_reply', { id: mails[0].id, choice: 'lister' });
    assert.equal(rl.ok, true, rl.error);
    const listes = lire('Object.keys(S.economy.listings)');
    assert.ok(r.plan.joueurs.every(j => listes.includes(j.id)), 'joueurs désignés en vente');
    // Avant l'échéance : rien ; à l'échéance, toujours sous la réserve : le président vend lui-même.
    run('repriseSemaine()');
    assert.equal(lire('S.presidentReprise.clubs[S.club].etat'), 'en_cours');
    const v = lire(`(()=>{const p=S.presidentReprise.clubs[S.club],c=club(),n=c.players.length,avant=c.cash;p.echeance=CDWorldCareer.calendarToday(S);repriseSemaine();
      return {etat:p.etat,partis:n-c.players.length,gain:c.cash-avant,ligne:S.ledger.some(e=>/Vente décidée par le président/.test(e.title)),
        ailleurs:p.joueurs.filter(j=>!c.players.some(x=>x.id===j.id)).every(j=>S.clubs.some(x=>x.id!==c.id&&x.players.some(y=>y.id===j.id)))};})()`);
    assert.equal(v.etat, 'vendu'); assert.ok(v.partis >= 1 && v.partis <= 3); assert.ok(v.gain > 0); assert.equal(v.ligne, true); assert.equal(v.ailleurs, true);
    // Pas de nouvelle intervention avant quatre mois.
    assert.equal(lire(`(()=>{const c=club();const a=c.cash;c.cash=S.clubBudget.clubs[c.id].reserve-3e6;return repriseApresAchat(c,a+5e6);})()`), false);
    // Caisse revenue au-dessus de la réserve : il renonce, sans vendre.
    const w = lire(`(()=>{const c=club();S.presidentReprise.derniere={};delete S.presidentReprise.clubs[c.id];const ok=repriseApresAchat(c,S.clubBudget.clubs[c.id].reserve+1e6);
      const n=c.players.length;c.cash=S.clubBudget.clubs[c.id].reserve+1;repriseSemaine();return {ok,etat:S.presidentReprise.clubs[c.id].etat,n:n-c.players.length};})()`);
    assert.deepEqual(w, { ok: true, etat: 'retabli', n: 0 });
    // Délai plaidé : deux semaines de plus, une seule fois, confiance −3.
    const d = lire(`(()=>{const c=club();S.presidentReprise.derniere={};delete S.presidentReprise.clubs[c.id];c.cash=S.clubBudget.clubs[c.id].reserve-2e6;
      repriseApresAchat(c,S.clubBudget.clubs[c.id].reserve+1e6);const e0=S.presidentReprise.clubs[c.id].echeance;const r1=repriseAction('delai');
      return {e0,e1:S.presidentReprise.clubs[c.id].echeance,r1:r1.ok,r2:repriseRefus('delai')};})()`);
    assert.equal(d.e1, P.decaler(d.e0, P.RALLONGE)); assert.equal(d.r1, true); assert.match(d.r2, /déjà accordé/);
    // Club géré : même règle, la direction passe en « vente » tant que le président attend.
    const ia = lire(`(()=>{const c=S.clubs.find(x=>x.id!==S.club&&budgetLigue(x.id)==='elite');const res=S.clubBudget.clubs[c.id].reserve;c.cash=res-2e6;
      const ok=repriseApresAchat(c,res+1e6);return {ok,vente:repriseIAVente(c.id),joue:repriseIAVente(S.club)};})()`);
    assert.deepEqual(ia, { ok: true, vente: true, joue: false });
    assert.equal(lire('nativePresidentReprise.valide(S.presidentReprise)'), true);
  } finally { jeu.fermer(); }
});
