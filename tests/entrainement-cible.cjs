'use strict';
// Entraînement ciblé et flèches de progression (choix de Léo du 24/11/2026) : chaque séance collective ne fait
// progresser que son groupe de qualités, l'entraînement au poste et au rôle les qualités liées ; relevé des qualités
// chaque semaine ; flèche sur toute qualité qui a vraiment bougé (hausse ou baisse, sans limite), flèche du niveau =
// moyenne des 36.
// Carrière Monde (world-champ), déterministe.
const test = require('node:test'), assert = require('node:assert/strict');
const { context } = require('./monde-harness.cjs');
const fs = require('node:fs'), path = require('node:path');
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

test('rôle de jeu de la fiche : même table que l’écran ; un Plaqueur et un Gratteur ne progressent pas pareil', () => {
  const gd = fs.readFileSync(path.join(__dirname, '../native/godot/ui/immersive08/fiche_roles.gd'), 'utf8');
  const ecran = [...gd.matchAll(/\["([a-z-]+)", "([a-z]+)", "([^"]+)", \[([^\]]*)\], \[([^\]]*)\]\]/g)]
    .map(m => [m[1], m[2], m[3], JSON.parse('[' + m[4] + ']'), JSON.parse('[' + m[5] + ']')]);
  assert.deepEqual(cible.ROLES_JEU.map(r => [r[0], r[1], r[2], [...r[3]], [...r[4]]]), ecran, 'table des rôles identique à fiche_roles.gd');
  const r = json(`(()=>{const D=nativeSystems.domain('entrainementCible'),i=k=>D.CLES.indexOf(k);
    const base=S.clubs.flatMap(c=>c.players).find(p=>p.pos===POS[5]&&p.attributesV2);
    const plaqueur=JSON.parse(JSON.stringify(base)),gratteur=JSON.parse(JSON.stringify(base));
    plaqueur.id+='-plaqueur';gratteur.id+='-gratteur';
    for(const k of Object.keys(base.attributesV2)){plaqueur.attributesV2[k]=50;gratteur.attributesV2[k]=50;}
    for(const k of ['tackling','workRate','endurance','positioning'])plaqueur.attributesV2[k]=80;
    for(const k of ['jackal','tackling','anticipation','workRate'])gratteur.attributesV2[k]=80;
    const wp=D.poids(plaqueur),wg=D.poids(gratteur);
    return {rp:D.roleJeu(plaqueur)?.[2],rg:D.roleJeu(gratteur)?.[2],grattageP:wp[i('jackal')],grattageG:wg[i('jackal')],
      enduranceP:wp[i('endurance')],enduranceG:wg[i('endurance')],ind:D.individuel(base),
      pilier:D.individuel(S.clubs.flatMap(c=>c.players).find(p=>p.fam===0&&p.attributesV2)).poste.qualites};})()`);
  assert.ok(r.pilier.includes('scrumTechnique') && r.pilier.includes('strength'), 'pilier : mêlée et force au poste : ' + r.pilier.join(','));
  assert.equal(r.rp, 'Plaqueur'); assert.equal(r.rg, 'Gratteur');
  assert.ok(r.grattageG > r.grattageP * 1.3, 'le Gratteur travaille plus le grattage : ' + r.grattageG + ' / ' + r.grattageP);
  assert.ok(r.enduranceP > r.enduranceG * 1.3, 'le Plaqueur travaille plus l’endurance : ' + r.enduranceP + ' / ' + r.enduranceG);
  assert.ok(r.ind.poste.qualites.length === 6 && r.ind.role && r.ind.role.cles.length === 4 && r.ind.role.utiles.length === 4, 'fiche : poste et rôle travaillés');
});

test('relevé chaque semaine : 5 semaines glissantes, référence d’il y a 4 semaines', () => {
  const debut = json('S.releveQualites');
  assert.match(debut.s, /^\d{4}-\d{2}-\d{2}$/, 'lundi du premier relevé');
  h.week(6);
  run('delete S.clubMeetings');
  const r = json(`(()=>{const R=nativeSystems.domain('releveQualites')._tests,p=S.clubs[S.club].players[0],l=R.decoder(CDReleveQualites.texteHebdo(p),R.SEMAINE);
    return {points:l.points.length,lundi:S.releveQualites.s,debut:l.debut};})()`);
  assert.equal(r.points, 5, '5 relevés hebdomadaires');
  assert.equal(r.debut, json(`nativeSystems.domain('releveQualites')._tests.lundiSuivant(${JSON.stringify(r.lundi)},-4)`));
  run('validateCareer(S)');
  assert.throws(() => run('(()=>{const p=S.clubs[S.club].players[0],rh=p.rh;p.rh="2026-13-01:xx";try{validateCareer(S);}finally{p.rh=rh;}})()'), /Relevé hebdomadaire/);
});

test('flèches : toute qualité qui a vraiment bougé, hausse ou baisse, sans limite ; niveau = moyenne des 36', () => {
  const r = json(`(()=>{const R=nativeSystems.domain('releveQualites')._tests;
    const p=JSON.parse(JSON.stringify(S.clubs[S.club].players.find(p=>p.attributesV2)));delete p.rh;
    for(const k of Object.keys(p.attributesV2))p.attributesV2[k]=Math.min(90,Math.max(30,p.attributesV2[k]));
    R.relever(p,'2026-09-07',R.SEMAINE);
    const a=p.attributesV2;for(const k of Object.keys(a))a[k]+=.1;a.passing+=1.2;a.tackling+=.5;a.topSpeed-=.6;a.agility-=.3;a.vision+=.1;
    const f1=CDReleveQualites.fleches(p);
    for(const k of Object.keys(a))a[k]+=.4;
    const f2=CDReleveQualites.fleches(p);
    for(const k of Object.keys(a))a[k]-=1.5;
    const f3=CDReleveQualites.fleches(p);
    return {f1,f2,f3,ventes:CDReleveQualites.fleches({...p,rh:undefined})};})()`);
  assert.deepEqual(r.f1.q, { passing: 3, tackling: 2, agility: -1, topSpeed: -2 }, 'bruit écarté (+0,1, +0,2), baisse de 0,2 gardée : ' + JSON.stringify(r.f1.q));
  assert.equal(r.f1.n, 1, 'niveau : moyenne des 36 (+0,1)');
  assert.ok(Object.keys(r.f2.q).length >= 33, 'sans limite : ' + Object.keys(r.f2.q).length + ' qualités ont bougé');
  assert.equal(r.f2.n, 2, 'niveau : moyenne des 36 (+0,5)');
  assert.ok(Object.values(r.f3.q).filter(c => c < 0).length >= 30 && r.f3.n < 0, 'baisses : chevrons vers le bas, niveau en baisse');
  assert.equal(r.ventes, null, 'sans relevé hebdomadaire : rien');
});

test('déclin de l’âge : les joueurs âgés ont des flèches en baisse au fil de la saison', () => {
  const r = json(`(()=>{const vieux=S.clubs.flatMap(c=>c.players).filter(p=>p.age>=32&&p.attributesV2);
    return {n:vieux.length,baisse:vieux.filter(p=>Object.values(CDReleveQualites.fleches(p)?.q||{}).some(c=>c<0)).length};})()`);
  // Seuil de baisse 0,2 point : six semaines après la reprise, le déclin de l'âge est déjà visible.
  assert.ok(r.n > 50 && r.baisse > r.n / 4, 'joueurs de 32 ans et plus avec une baisse : ' + r.baisse + ' / ' + r.n);
});

test('fiche, Effectif et Centre reçoivent les flèches du moteur', () => {
  const m = h.command('snapshot');
  const joueur = (m.squad || []).find(p => p.fleches);
  assert.ok(joueur, 'joueur de l’effectif avec ses flèches');
  assert.ok(Number.isInteger(joueur.fleches.n) && Object.values(joueur.fleches.q).every(c => Number.isInteger(c) && c !== 0 && Math.abs(c) <= 3));
  const planning = m.calendarPlanning;
  if (planning?.sessionCatalogue) for (const item of planning.sessionCatalogue) assert.ok(item.qualites && Array.isArray(item.qualites.avants), item.label);
});
