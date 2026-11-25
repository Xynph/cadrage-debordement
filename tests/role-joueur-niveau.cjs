'use strict';
// Rôle choisi par le club et Niveau du match (native/engine/role-joueur.cjs, 25/11/2026) : le match lit le Niveau
// calculé au poste et au rôle (niveau-calcule.cjs) là où il lisait `rating`. Règles pures (rôle de repli, mémoire,
// validation), puis carrière Monde réelle : commande set_player_role, projection, teamLevel, sauvegarde et rechargement,
// ancienne sauvegarde sans rôle (ou avec un rôle périmé), semaine jouée ensuite.
const assert = require('node:assert/strict');
const { test } = require('node:test');
const NC = require('../native/engine/niveau-calcule.cjs');
const { factory } = require('../native/engine/role-joueur.cjs');

// Joueur typique de 3e ligne aile (36 qualités à 60), profil gratteur marqué.
const ailier3 = (extra = {}) => {
  const a = Object.fromEntries(NC.CLES.map(k => [k, 60]));
  Object.assign(a, { jackal: 74, ruckClearout: 70, anticipation: 66, tackling: 58 });
  return { id: 'p1', pos: 'Troisième ligne aile', rating: 63, attributesV2: a, ...extra };
};

test('Règles : rôle choisi, repli sur le meilleur rôle, mémoire invalidée, validation', () => {
  globalThis.CDNiveauCalcule = NC;
  try {
    const f = factory(), t = f._tests;
    const p = ailier3();
    const meilleur = NC.niveauJoueur(p), roles = Object.fromEntries(meilleur.roles.map(r => [r.id, r.niveau]));
    assert.equal(meilleur.role, 'aile-gratteur');
    // Sans rôle : meilleur rôle de son poste (comme avant la bascule).
    assert.equal(f.niveauMatch(p), meilleur.niveau);
    // Rôle choisi : le Niveau à ce rôle (la mémoire suit le changement de rôle).
    const pire = meilleur.roles[meilleur.roles.length - 1].id;
    t.choisir(p, pire);
    assert.equal(p.roleId, pire);
    assert.equal(f.niveauMatch(p), roles[pire]);
    assert.ok(f.niveauMatch(p) < meilleur.niveau, `un rôle moins adapté baisse le Niveau du match : ${JSON.stringify(meilleur.roles)}`);
    // Qualités changées (nouvel objet, comme la progression) : la mémoire est relue.
    p.attributesV2 = { ...p.attributesV2, ballCarry: 80, explosiveness: 80, offload: 78, strength: 78 };
    assert.equal(f.niveauMatch(p), NC.niveauJoueur(p, { roleId: pire }).niveau);
    // Refus : rôle inconnu, rôle d'un autre poste ; null efface.
    assert.throws(() => t.choisir(p, 'pilier-mobile'), /autre poste/);
    assert.throws(() => t.choisir(p, 'aile-inconnu'), /inconnu/);
    t.choisir(p, null);
    assert.equal(p.roleId, undefined);
    // Repli propre : rôle périmé (changement de poste) ou inconnu dans une sauvegarde → meilleur rôle, sans erreur.
    const vieux = ailier3({ roleId: 'pilier-mobile' }), inconnu = ailier3({ roleId: 'role-disparu' });
    assert.equal(f.roleDe(vieux), null);
    assert.equal(f.niveauMatch(vieux), meilleur.niveau);
    assert.equal(f.niveauMatch(inconnu), meilleur.niveau);
    // Qualités ou poste inconnus : `rating`.
    assert.equal(f.niveauMatch({ id: 'x', pos: 'Centre', rating: 71 }), 71);
    assert.equal(f.niveauMatch({ id: 'y', pos: 'Poste inconnu', rating: 66, attributesV2: p.attributesV2 }), 66);
    // Validation de sauvegarde : seul un roleId qui n'est pas un texte court est refusé.
    const etat = roster => ({ clubs: [{ players: roster }] });
    assert.equal(f.validate(etat([ailier3(), vieux, inconnu])), true);
    assert.throws(() => f.validate(etat([ailier3({ roleId: 12 })])), /Rôle du joueur invalide/);
  } finally {
    delete globalThis.CDNiveauCalcule;
  }
});

test('Carrière Monde : rôle choisi enregistré, lu par le match, sauvegardé, rechargé ; ancienne sauvegarde sans rôle', { timeout: 900000 }, () => {
  const { context } = require('./monde-harness.cjs');
  const h = context(827381);
  const val = src => JSON.parse(h.run(`JSON.stringify(${src})`));
  const commande = (nom, charge) => { h.run('delete S.clubMeetings'); return h.command(nom, charge); };
  try {
    // Le moteur de la carrière lit le Niveau calculé : même échelle que `rating` (écart moyen nul, écart absolu faible).
    const ecart = val(`(()=>{const ps=S.clubs.flatMap(c=>c.players);let a=0,m=0;for(const p of ps){const d=niveauMatch(p)-p.rating;a+=Math.abs(d);m+=d;}return {n:ps.length,abs:a/ps.length,moy:m/ps.length};})()`);
    assert.ok(ecart.n > 3000, 'tous les clubs du Monde');
    assert.ok(Math.abs(ecart.moy) < 0.5 && ecart.abs < 3, `Niveau à l'échelle de rating : ${JSON.stringify(ecart)}`);
    // Un joueur de notre effectif dont les rôles ont des Niveaux différents ; on choisit son moins bon rôle.
    const cible = val(`(()=>{for(const p of S.clubs[S.club].players){const n=CDNiveauCalcule.niveauJoueur(p);if(!n)continue;const pire=n.roles[n.roles.length-1];if(pire.niveau<n.niveau)return {id:p.id,meilleur:n.niveau,pire:pire.id,niveauPire:pire.niveau,rating:p.rating};}return null;})()`);
    assert.ok(cible, 'un joueur dont le rôle compte');
    assert.equal(val(`niveauMatch(S.clubs[S.club].players.find(p=>p.id===${JSON.stringify(cible.id)}))`), cible.meilleur, 'sans rôle choisi : meilleur rôle');
    const niveauXV = `(()=>{const c=S.clubs[S.club],p=c.players.find(x=>x.id===${JSON.stringify(cible.id)});return teamLevel([p]);})()`;
    const avant = val(niveauXV);
    commande('set_player_role', { playerId: cible.id, roleId: cible.pire });
    assert.equal(val(`nativeSystems.domain('roleJoueur').project().roles[${JSON.stringify(cible.id)}]`), cible.pire, 'rôle projeté pour l’écran');
    assert.equal(val(`S.clubs[S.club].players.find(p=>p.id===${JSON.stringify(cible.id)}).roleId`), cible.pire, 'rôle enregistré sur le joueur');
    assert.equal(val(`niveauMatch(S.clubs[S.club].players.find(p=>p.id===${JSON.stringify(cible.id)}))`), cible.niveauPire, 'le match lit le Niveau au rôle choisi');
    assert.ok(val(niveauXV) < avant, 'teamLevel suit le rôle choisi');
    assert.throws(() => commande('set_player_role', { playerId: cible.id, roleId: 'role-inconnu' }), /inconnu/);
    // Sauvegarde puis rechargement : le rôle est gardé, la carrière valide.
    h.run('pendingSave=parseSaveDocument(JSON.stringify(createSaveDocument()));if(!confirmSaveImport())throw Error("import");validateCareer(S)');
    assert.equal(val(`S.clubs[S.club].players.find(p=>p.id===${JSON.stringify(cible.id)}).roleId`), cible.pire, 'rôle rechargé');
    assert.equal(val(`niveauMatch(S.clubs[S.club].players.find(p=>p.id===${JSON.stringify(cible.id)}))`), cible.niveauPire);
    // Ancienne sauvegarde : aucun roleId (et un rôle périmé laissé par une version future ou un changement de poste).
    const autre = val(`S.clubs[S.club].players.find(p=>p.id!==${JSON.stringify(cible.id)}&&CDNiveauCalcule.niveauJoueur(p)).id`);
    h.run(`(()=>{for(const c of S.clubs)for(const p of c.players)delete p.roleId;const p=S.clubs[S.club].players.find(x=>x.id===${JSON.stringify(autre)});p.roleId='role-disparu';})()`);
    h.run('pendingSave=parseSaveDocument(JSON.stringify(createSaveDocument()));if(!confirmSaveImport())throw Error("import ancienne sauvegarde");validateCareer(S)');
    assert.equal(val('S.clubs.flatMap(c=>c.players).filter(p=>p.roleId!==undefined).length'), 1);
    assert.equal(val(`niveauMatch(S.clubs[S.club].players.find(p=>p.id===${JSON.stringify(autre)}))`), val(`CDNiveauCalcule.niveauJoueur(S.clubs[S.club].players.find(p=>p.id===${JSON.stringify(autre)})).niveau`), 'rôle périmé : meilleur rôle');
    assert.equal(val(`niveauMatch(S.clubs[S.club].players.find(p=>p.id===${JSON.stringify(cible.id)}))`), cible.meilleur, 'sans rôle : meilleur rôle');
    // La semaine suivante se joue normalement (le rôle périmé ne bloque rien).
    h.week(1);
    assert.ok(val('S.clubs.flatMap(c=>c.players).length') > 3000);
  } finally {
    h.close();
  }
});
