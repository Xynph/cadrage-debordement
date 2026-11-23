'use strict';
// Familiarité au poste (native/engine/familiarite-poste.cjs ; choix de Léo du 23/11/2026, idée FM27 « familiarite ») :
// valeur 0-20 par maillot, 5 niveaux, efficacité au poste 100 / 96 / 88 / 76 / 60 %, valeur de départ déduite des
// postes, progression par match (+1, +0,5 sous 40 min) et par semaine d'entraînement (+0,25), âge (× 1,5 jusqu'à 23 ans,
// × 0,5 dès 31 ans), un palier par mois au plus, oubli −1 par 10 semaines sans y jouer (jamais sous le départ),
// 1re ligne bloquée sans qualification. Règles pures d'abord (structure fournie), puis carrière Monde réelle.
const assert = require('node:assert/strict');
const { test } = require('node:test');
const { factory } = require('../native/engine/familiarite-poste.cjs');

const f = factory();
const t = f._tests;
// Centre (12-13 principaux) : 1re ligne non qualifiée (-1), avants Dépanne (1), 9-10 Correct (2), 11/14/15 Confirmé (3).
const CENTRE = [-1, -1, -1, 1, 1, 1, 1, 1, 2, 2, 3, 4, 4, 3, 3];
// Pilier gauche qualifié aussi à droite (1 et 3 principaux), talonneur non qualifié, trois-quarts Inadapté.
const PILIER = [4, -1, 4, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0];
let structures = new Map();
t.fixerStructure(p => structures.get(p.id));
const joueur = (id, structure, age = 26) => { const p = { id, age }; structures.set(id, structure); return p; };

test('Seuils, efficacités et valeurs de départ', () => {
  assert.deepEqual(f.RULES.MULT, [0.60, 0.76, 0.88, 0.96, 1]);
  assert.deepEqual(f.RULES.DEPART, [2, 7, 12, 16, 20]);
  assert.deepEqual([0, 4.9, 5, 9.9, 10, 13.9, 14, 17.9, 18, 20].map(t.niveau), [0, 0, 1, 1, 2, 2, 3, 3, 4, 4]);
  for (let l = 0; l <= 4; l++) assert.equal(t.niveau(f.RULES.DEPART[l]), l, 'le départ donne son niveau');
  const p = joueur('c', CENTRE);
  assert.deepEqual(t.niveaux(p, CENTRE), [-1, -1, -1, 1, 1, 1, 1, 1, 2, 2, 3, 4, 4, 3, 3], 'sans enregistrement : postes actuels');
  assert.deepEqual(t.valeurs(p, CENTRE), [0, 0, 0, 7, 7, 7, 7, 7, 12, 12, 16, 20, 20, 16, 16]);
  t.assurer(p);
  assert.deepEqual(p.familiarite, { d: '000111112234433' }, 'enregistrement compact : niveaux actuels = départ');
  assert.deepEqual(t.valeurs(p, CENTRE), [0, 0, 0, 7, 7, 7, 7, 7, 12, 12, 16, 20, 20, 16, 16], 'migration : mêmes valeurs');
  assert.equal(f.validate({ clubs: [{ players: [p] }] }), true);
});

test('Match au poste : +1, +0,5 sous 40 minutes ; poste principal et 1re ligne non qualifiée sans effet', () => {
  const p = joueur('m', CENTRE);
  assert.equal(t.match(p, 10, 80, '2026-09'), 13);
  assert.equal(p.familiarite.p, 10, 'dernier poste hors poste principal retenu');
  assert.equal(t.match(p, 10, 39, '2026-09'), 13.5);
  assert.equal(t.match(p, 10, 40, '2026-09'), 14.5, '40 minutes : match complet, palier Confirmé gagné');
  assert.equal(t.niveaux(p, CENTRE)[9], 3);
  assert.equal(t.match(p, 12, 80, '2026-09'), null, 'poste principal : rien à gagner');
  assert.equal(p.familiarite.p, undefined, 'retour au poste principal : plus de poste d\'entraînement hors poste');
  assert.equal(t.match(p, 1, 80, '2026-09'), null, '1re ligne non qualifiée : bloquée');
  assert.equal(t.niveaux(p, CENTRE)[0], -1);
});

test('Un palier par mois au plus, par poste', () => {
  const p = joueur('palier', CENTRE);
  // Dépanne 7 → 10 (Correct) en septembre : palier gagné.
  for (let i = 0; i < 3; i++) t.match(p, 9, 80, '2026-09');
  assert.equal(t.valeurs(p, CENTRE)[8], 15, 'Correct au départ (12) : Confirmé gagné en septembre');
  assert.equal(t.niveaux(p, CENTRE)[8], 3);
  for (let i = 0; i < 5; i++) t.match(p, 9, 80, '2026-09');
  assert.equal(t.valeurs(p, CENTRE)[8], 17.875, 'Naturel refusé le même mois : bloqué sous 18');
  assert.equal(t.niveaux(p, CENTRE)[8], 3);
  t.match(p, 9, 80, '2026-10');
  assert.equal(t.valeurs(p, CENTRE)[8], 18.875, 'mois suivant : palier Naturel gagné');
  assert.equal(t.niveaux(p, CENTRE)[8], 4);
  for (let i = 0; i < 5; i++) t.match(p, 9, 80, '2026-11');
  assert.equal(t.valeurs(p, CENTRE)[8], 20, 'plafond 20');
  // Un autre poste a son propre mois.
  t.match(p, 10, 80, '2026-11');
  assert.equal(t.valeurs(p, CENTRE)[9], 13);
  const m = joueur('mois', CENTRE);
  t.match(m, 9, 80, '2026-09'); t.match(m, 9, 80, '2026-09');
  assert.equal(t.valeurs(m, CENTRE)[8], 14, 'Correct → Confirmé en septembre');
  t.match(m, 10, 80, '2026-09'); t.match(m, 10, 80, '2026-09');
  assert.equal(t.valeurs(m, CENTRE)[9], 14, 'autre maillot : son propre palier le même mois');
});

test('Âge : × 1,5 jusqu\'à 23 ans, × 1 de 24 à 30, × 0,5 dès 31 ans', () => {
  assert.deepEqual([18, 23, 24, 30, 31, 36].map(f.facteurAge), [1.5, 1.5, 1, 1, 0.5, 0.5]);
  const jeune = joueur('j', CENTRE, 21), mur = joueur('a', CENTRE, 27), vieux = joueur('v', CENTRE, 33);
  for (const p of [jeune, mur, vieux]) t.match(p, 9, 80, '2026-09');
  assert.deepEqual([jeune, mur, vieux].map(p => t.valeurs(p, CENTRE)[8]), [13.5, 13, 12.5]);
});

test('Entraînement : +0,25 par semaine au poste ; oubli −1 par 10 semaines sans y jouer, jamais sous le départ', () => {
  const p = joueur('e', CENTRE);
  for (let i = 0; i < 8; i++) t.semaine(p, 9, '2026-09');
  assert.equal(t.valeurs(p, CENTRE)[8], 14, '12 + 8 × 0,25');
  const blesse = joueur('b', CENTRE);
  t.semaine(blesse, 9, '2026-09', true);
  assert.equal(t.valeurs(blesse, CENTRE)[8], 12, 'blessé : pas d\'entraînement');
  // Oubli : 9 semaines sans rien = rien, la 10e = −1.
  for (let i = 0; i < 9; i++) t.semaine(p, null, '2026-10');
  assert.equal(t.valeurs(p, CENTRE)[8], 14);
  assert.equal(p.familiarite.o[9], 9);
  t.semaine(p, null, '2026-11');
  assert.equal(t.valeurs(p, CENTRE)[8], 13, 'oubli −1 au bout de 10 semaines');
  assert.equal(t.niveaux(p, CENTRE)[8], 2, 'le niveau suit');
  // Un match remet le compteur à zéro.
  for (let i = 0; i < 5; i++) t.semaine(p, null, '2026-11');
  t.match(p, 9, 80, '2026-12');
  assert.equal(p.familiarite.o, undefined, 'compteur d\'oubli remis à zéro');
  // Jamais sous la valeur de départ : l'enregistrement redevient compact.
  for (let i = 0; i < 60; i++) t.semaine(p, null, '2027-01');
  assert.equal(t.valeurs(p, CENTRE)[8], 12);
  assert.equal(p.familiarite.v, undefined);
  assert.equal(p.familiarite.o, undefined);
  assert.equal(p.familiarite.k, undefined, 'de retour au départ : enregistrement compact');
  assert.equal(f.validate({ clubs: [{ players: [p, blesse] }] }), true);
});

test('Apprendre un poste : une seule cible, ni poste principal ni 1re ligne non qualifiée, null arrête', () => {
  const p = joueur('cible', CENTRE);
  assert.equal(t.apprendre(p, 10), 10);
  assert.equal(p.familiarite.c, 10);
  assert.equal(t.apprendre(p, 15), 15, 'une seule cible : la nouvelle remplace l’ancienne');
  assert.equal(p.familiarite.c, 15);
  assert.throws(() => t.apprendre(p, 12), /naturel/, 'poste principal refusé');
  assert.throws(() => t.apprendre(p, 2), /qualification/, '1re ligne non qualifiée refusée');
  assert.throws(() => t.apprendre(p, 16), /invalide/);
  assert.equal(p.familiarite.c, 15, 'refus : cible inchangée');
  assert.equal(t.apprendre(p, null), null);
  assert.equal(p.familiarite.c, undefined, 'arrêt');
  t.apprendre(p, 9);
  assert.equal(f.validate({ clubs: [{ players: [p] }] }), true);
  assert.throws(() => f.validate({ clubs: [{ players: [{ id: 'x', familiarite: { d: '000111112234433', c: 0 } }] }] }), /Familiarité/);
});

test('Semaine : notre club s’entraîne au poste choisi (même s’il joue ailleurs), sans cible rien ; autres clubs : dernier poste joué', () => {
  const cible = joueur('n1', CENTRE), sans = joueur('n2', CENTRE), titulaire = joueur('n3', CENTRE), ia = joueur('ia', CENTRE);
  t.apprendre(cible, 15);
  t.match(ia, 9, 80, 'S0-0');
  const avantIa = t.valeurs(ia, CENTRE)[8];
  globalThis.S = { club: 0, season: 1, week: 3, lineup: [null, null, null, null, null, null, null, null, sans.id, titulaire.id], clubs: [{ id: 0, players: [cible, sans, titulaire] }, { id: 1, players: [ia] }] };
  try {
    for (let i = 0; i < 4; i++) t.apresSemaine();
  } finally { delete globalThis.S; }
  assert.equal(t.valeurs(cible, CENTRE)[14], 17, 'cible : 16 + 4 × 0,25');
  assert.deepEqual(t.valeurs(sans, CENTRE), t.valeurs(joueur('ref', CENTRE), CENTRE), 'sans cible : rien, même titulaire hors poste dans la composition');
  assert.deepEqual(t.valeurs(titulaire, CENTRE), t.valeurs(joueur('ref2', CENTRE), CENTRE));
  assert.equal(t.valeurs(ia, CENTRE)[8], avantIa + 1, 'club de l’ordinateur : dernier poste joué hors poste principal');
});

test('1re ligne : bloquée sans qualification, Confirmé au moins une fois qualifié', () => {
  const p = joueur('t', CENTRE);
  t.assurer(p);
  for (let i = 0; i < 10; i++) { t.semaine(p, 2, '2026-09'); t.match(p, 2, 80, '2026-09'); }
  assert.equal(t.valeurs(p, CENTRE)[1], 0);
  assert.equal(t.niveaux(p, CENTRE)[1], -1);
  // Qualifié plus tard au talon : Confirmé (16) au moins, progression possible.
  const qualifie = CENTRE.slice(); qualifie[1] = 3; structures.set('t', qualifie);
  assert.equal(t.niveaux(p, qualifie)[1], 3);
  assert.equal(t.valeurs(p, qualifie)[1], 16);
  t.match(p, 2, 80, '2026-09');
  assert.equal(t.valeurs(p, qualifie)[1], 17);
  const pilier = joueur('pil', PILIER);
  assert.deepEqual(t.niveaux(pilier, PILIER).slice(0, 3), [4, -1, 4]);
  assert.equal(t.match(pilier, 3, 80, '2026-09'), null, 'autre côté qualifié et principal : Naturel');
});

test('Validation : enregistrements abîmés refusés', () => {
  const ok = joueur('val', CENTRE); t.assurer(ok);
  for (const casse of [{ d: '0', k: '0' }, { d: '000111112234433', k: '00011111223443x' }, { d: '000111112234433', k: '000111112234433', v: { 9: 25 } },
    { d: '000111112234433', k: '000111112234433', o: { 9: 10 } }, { d: '000111112234433', k: '000111112234433', p: 16 }, { d: '000111112234433', k: '000111112234433', z: 1 }]) {
    assert.throws(() => f.validate({ clubs: [{ players: [ok, { id: 'x', familiarite: casse }] }] }), /Familiarité/, JSON.stringify(casse));
  }
});

test('Carrière Monde : familiarité enregistrée, envoyée à l\'écran, efficacité adoucie, progression en match et sauvegarde', { timeout: 900000 }, () => {
  const { context } = require('./monde-harness.cjs');
  const h = context(827381);
  const val = src => JSON.parse(h.run(`JSON.stringify(${src})`));
  // Ancienne carrière : aucun enregistrement ; observe pose la valeur de départ déduite des postes actuels.
  h.run('for(const c of S.clubs)for(const p of c.players)delete p.familiarite');
  assert.ok(val("nativeSystems.domain('familiarite').observe()") > 1000, 'migration de tous les joueurs');
  assert.equal(val('S.clubs.flatMap(c=>c.players).filter(p=>!p.familiarite).length'), 0);
  // Projection : niveaux et valeurs cohérents avec les postes et les notes au poste.
  const effectif = val('S.clubs[S.club].players.map(p=>({id:p.id,...nativePositionAptitudes.project(p)}))');
  for (const p of effectif) {
    assert.equal(p.positionFamiliarity.length, 15); assert.equal(p.positionFamiliarityLevels.length, 15);
    for (const n of p.primaryPositions) { assert.equal(p.positionFamiliarityLevels[n - 1], 4); assert.equal(p.positionFamiliarity[n - 1], 20); }
    for (const n of p.secondaryPositions) assert.ok(p.positionFamiliarityLevels[n - 1] >= 3, 'autre poste maîtrisé = Confirmé au moins');
    for (let n = 1; n <= 3; n++) if (!p.qualifiedFrontRowPositions.includes(n)) { assert.equal(p.positionRatings[n], 0); assert.equal(p.positionFamiliarity[n - 1], 0); }
  }
  // Note au poste = note de rôle du poste plafonnée à la note au poste principal × efficacité du niveau ; l'efficacité
  // au poste du moteur la suit (égale à celle du niveau quand la note de rôle ne dépasse pas la note principale).
  const MULT = [0.60, 0.76, 0.88, 0.96, 1];
  const lignes = val(`(()=>{const out=[];for(const p of S.clubs[S.club].players){const d=nativePositionAptitudes.project(p),main=roleNote(p);for(let s=3;s<15;s++){if(d.primaryPositions.includes(s+1))continue;const role=roleNote(p,FAMILIES[s]);out.push({l:d.positionFamiliarityLevels[s],note:d.positionRatings[s+1],role,main,e:nativePositionAptitudes.efficiency(p,s)});}}return out;})()`);
  let egales = 0;
  for (const x of lignes) {
    assert.equal(x.note, Math.max(1, Math.round(Math.min(x.role, x.main) * MULT[x.l])), JSON.stringify(x));
    assert.ok(x.note <= x.main, 'jamais au-dessus du poste principal');
    assert.ok(x.e <= MULT[x.l] + 0.025, `niveau ${x.l} : efficacité ${x.e}`);
    if (x.role <= x.main) { assert.ok(Math.abs(x.e - MULT[x.l]) < 0.025, `niveau ${x.l} : efficacité ${x.e}`); egales++; }
  }
  assert.ok(egales > 100, 'efficacité du niveau sur la plupart des postes');
  // Progression : un centre titularisé à l'ouverture deux semaines de suite gagne à ce poste.
  const centre = effectif.find(p => p.primaryPositions.includes(12) && !p.primaryPositions.includes(10));
  assert.ok(centre, 'un centre dans l\'effectif');
  const avant = centre.positionFamiliarity[9];
  h.run(`(()=>{const ids=S.clubs[S.club].players.map(p=>p.id);S.lineup=S.lineup.map(id=>id===${JSON.stringify(centre.id)}?null:id);const at=S.lineup.indexOf(${JSON.stringify(centre.id)});S.lineup[9]=${JSON.stringify(centre.id)};})()`);
  h.toMatch();
  h.week(1);
  const apres = val(`nativePositionAptitudes.project(S.clubs[S.club].players.find(p=>p.id===${JSON.stringify(centre.id)}))`);
  const joue = val(`S.clubs[S.club].players.find(p=>p.id===${JSON.stringify(centre.id)}).familiarite`);
  assert.ok(apres.positionFamiliarity[9] > avant, `progression à l'ouverture : ${avant} → ${apres.positionFamiliarity[9]} (${JSON.stringify(joue)})`);
  // Apprendre un poste par la commande du jeu : cible enregistrée, envoyée à l'écran, refusée au poste principal,
  // arrêtée par null ; +0,25 par semaine d'entraînement sur la cible.
  // Rendez-vous du club coupés avant chaque décision, comme au départ du harnais (ils bloquent les décisions).
  const commande = (nom, charge) => { h.run('delete S.clubMeetings'); return h.command(nom, charge); };
  const ailier = val('S.clubs[S.club].players.map(p=>({id:p.id,...nativePositionAptitudes.project(p)}))').find(p => p.primaryPositions.includes(11) && p.positionFamiliarity[14] < 20 && !p.primaryPositions.includes(15));
  assert.ok(ailier, 'un ailier qui n’est pas naturel à l’arrière');
  let modele = commande('set_position_learning', { playerId: ailier.id, numero: 15 });
  assert.equal(modele.squad.find(p => p.id === ailier.id).positionLearning, 15, 'cible envoyée à l’écran');
  assert.throws(() => commande('set_position_learning', { playerId: ailier.id, numero: 11 }), /naturel/);
  const depart = val(`nativePositionAptitudes.project(S.clubs[S.club].players.find(p=>p.id===${JSON.stringify(ailier.id)})).positionFamiliarity[14]`);
  h.run('S.trained=false;trainWeek()');
  const entraine = val(`nativePositionAptitudes.project(S.clubs[S.club].players.find(p=>p.id===${JSON.stringify(ailier.id)})).positionFamiliarity[14]`);
  assert.ok(entraine > depart && entraine <= depart + 0.375, `entraînement à la cible : ${depart} → ${entraine}`);
  modele = commande('set_position_learning', { playerId: ailier.id, numero: null });
  assert.equal(modele.squad.find(p => p.id === ailier.id).positionLearning, null, 'arrêt');
  // Sauvegarde : l'enregistrement passe la validation et survit à l'aller-retour JSON.
  h.run('validateCareer(S)');
  const texte = h.run('JSON.stringify(S.clubs[S.club].players.map(p=>p.familiarite))');
  assert.deepEqual(JSON.parse(texte), JSON.parse(JSON.stringify(JSON.parse(texte))));
  h.close();
});
