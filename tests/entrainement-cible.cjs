'use strict';
// Entraînement ciblé et flèches de progression (choix de Léo du 24/11/2026) : chaque séance collective ne fait
// progresser que son groupe de qualités, l'entraînement au poste et au rôle les qualités liées ; relevé des qualités
// chaque semaine ; flèches seulement sur les qualités qui sortent du lot, flèche du niveau = moyenne des 36.
// Carrière Monde (world-champ), déterministe.
const test = require('node:test'), assert = require('node:assert/strict');
const { context } = require('./monde-harness.cjs');
const cible = require('../native/engine/entrainement-cible.cjs').factory();

const h = context(827381, { club: 102, console: false });
const run = src => h.run(src);
const json = src => JSON.parse(run('JSON.stringify(' + src + ')'));
test.after(() => h.close());

test('chaque séance a son groupe de qualités ; le jeu au pied touche à peine les avants, la récupération rien', () => {
  assert.deepEqual(cible.qualitesSeance({ kind: 'kicking', label: 'Jeu au pied' }).avants, []);
  assert.ok(cible.qualitesSeance({ kind: 'kicking', label: 'Jeu au pied' }).arrieres.includes('kickDistance'));
  assert.deepEqual(cible.qualitesSeance({ kind: 'recovery', label: 'Récupération' }), { avants: [], arrieres: [] });
  const melee = cible.qualitesSeance({ kind: 'team', label: 'Ateliers par poste', forwards: 'Mêlée', backs: 'Lancements' });
  assert.ok(melee.avants.includes('scrumTechnique') && !melee.arrieres.includes('scrumTechnique'));
  for (const [nom, liste] of Object.entries(cible.GROUPES)) {
    if (nom !== 'recuperation') assert.ok(liste.length >= 3 && liste.length <= 6, nom + ' : groupe cohérent de 3 à 6 qualités');
    for (const k of liste) assert.ok(cible.CLES.includes(k), nom + ' : ' + k);
  }
});

test('poids de la semaine : séances du programme, poste et rôle ; le reste presque immobile', () => {
  const r = json(`(()=>{const D=nativeSystems.domain('entrainementCible'),c=S.clubs[S.club].players;
    const avant=c.find(p=>p.fam<=3&&!p.injury),arriere=c.find(p=>/Ailier/.test(p.pos)&&!p.injury);
    const somme=w=>Math.round(w.reduce((a,b)=>a+b,0)*1e6)/1e6,i=k=>D.CLES.indexOf(k);
    const pose=seances=>{globalThis.nativeProgrammeEffets={season:S.season,round:S.round,effects:{},seances};};
    pose([{kind:'kicking',label:'Jeu au pied'}]);
    const piedAvant=D.poids(avant),piedArriere=D.poids(arriere);
    pose([{kind:'recovery',label:'Récupération'}]);
    const repos=D.poids(arriere);
    pose([{kind:'team',label:'Ateliers par poste',forwards:'Touche',backs:'Circulation'}]);
    const touche=D.poids(avant);
    // Rôle désigné : lanceur en touche (club du manager).
    const roles=S.playerRoles;S.playerRoles={...(roles||{}),lanceur:avant.id};const lanceur=D.poids(avant);if(roles===undefined)delete S.playerRoles;else S.playerRoles=roles;
    delete globalThis.nativeProgrammeEffets;
    const autre=S.clubs.find((x,k)=>k!==S.club).players.find(p=>p.fam>=7);
    return {sommes:[piedAvant,piedArriere,repos,touche,lanceur,D.poids(autre)].map(somme),
      piedArriere:piedArriere[i('kickDistance')],piedAvant:piedAvant[i('kickDistance')],
      reposPied:repos[i('kickDistance')],toucheSaut:touche[i('lineoutJump')],toucheBut:touche[i('goalAccuracy')],
      lanceur:lanceur[i('lineoutThrow')],sansRole:touche[i('lineoutThrow')],
      immobiles:piedArriere.filter(x=>x<.01).length};})()`);
  for (const s of r.sommes) assert.ok(Math.abs(s - 1) < 1e-6, 'somme des poids : ' + s);
  assert.ok(r.piedArriere > 3 * r.piedAvant, 'jeu au pied : arrières bien plus que les avants');
  assert.ok(r.reposPied < r.piedArriere / 3, 'semaine de récupération : pas de jeu au pied travaillé');
  assert.ok(r.toucheSaut > 5 * r.toucheBut, 'atelier touche : saut en touche, pas le but');
  assert.ok(r.lanceur > r.sansRole, 'rôle de lanceur : le lancer progresse plus');
  assert.ok(r.immobiles >= 12, 'qualités non travaillées : ' + r.immobiles);
});

test('relevé chaque semaine : 5 semaines glissantes, référence d’il y a 4 semaines', () => {
  const debut = json('S.releveQualites');
  assert.match(debut.s, /^\d{4}-\d{2}-\d{2}$/, 'lundi du premier relevé');
  h.week(6);
  run('delete S.clubMeetings');
  const r = json(`(()=>{const R=nativeSystems.domain('releveQualites')._tests,p=S.clubs[S.club].players[0],l=R.decoder(p.rh,R.SEMAINE);
    return {points:l.points.length,lundi:S.releveQualites.s,debut:l.debut};})()`);
  assert.equal(r.points, 5, '5 relevés hebdomadaires');
  assert.equal(r.debut, json(`nativeSystems.domain('releveQualites')._tests.lundiSuivant(${JSON.stringify(r.lundi)},-4)`));
  run('validateCareer(S)');
  assert.throws(() => run('(()=>{const p=S.clubs[S.club].players[0],rh=p.rh;p.rh="2026-13-01:xx";try{validateCareer(S);}finally{p.rh=rh;}})()'), /Relevé hebdomadaire/);
});

test('flèches : seulement les qualités qui sortent du lot ; niveau = moyenne des 36', () => {
  const r = json(`(()=>{const R=nativeSystems.domain('releveQualites')._tests;
    const p=JSON.parse(JSON.stringify(S.clubs[S.club].players.find(p=>p.attributesV2)));delete p.rh;
    for(const k of Object.keys(p.attributesV2))p.attributesV2[k]=Math.min(90,p.attributesV2[k]);
    R.relever(p,'2026-09-07',R.SEMAINE);
    const a=p.attributesV2;for(const k of Object.keys(a))a[k]+=.1;a.passing+=1.2;a.tackling+=.5;a.topSpeed-=.6;
    const f1=CDReleveQualites.fleches(p);
    for(const k of Object.keys(a))a[k]+=.4;
    const f2=CDReleveQualites.fleches(p);
    return {f1,f2,ventes:CDReleveQualites.fleches({...p,rh:undefined})};})()`);
  assert.deepEqual(r.f1.q, { passing: 3, tackling: 2, topSpeed: -2 }, 'trois qualités sortent du lot : ' + JSON.stringify(r.f1.q));
  assert.equal(r.f1.n, 1, 'niveau : moyenne des 36 (+0,1)');
  assert.equal(r.f2.n, 2, 'niveau : moyenne des 36 (+0,5)');
  assert.equal(r.ventes, null, 'sans relevé hebdomadaire : rien');
});

test('fiche, Effectif et Centre reçoivent les flèches du moteur', () => {
  const m = h.command('snapshot');
  const joueur = (m.squad || []).find(p => p.fleches);
  assert.ok(joueur, 'joueur de l’effectif avec ses flèches');
  assert.ok(Number.isInteger(joueur.fleches.n) && Object.keys(joueur.fleches.q).length <= 6);
  const planning = m.calendarPlanning;
  if (planning?.sessionCatalogue) for (const item of planning.sessionCatalogue) assert.ok(item.qualites && Array.isArray(item.qualites.avants), item.label);
});
