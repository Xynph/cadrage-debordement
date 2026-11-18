'use strict';
// Fenêtre Équipe, carrière Monde : avis du staff (bouton « Appliquer ces consignes ») et rôles en direct
// (onglet Rôles : buteur, secours, lanceur, botteur). Aucun tirage ajouté : la suite des tirages est vérifiée.
const assert = require('node:assert/strict');
const { ouvrir, creer, jusquAuMatch } = require('./helpers/carriere-monde.cjs');

const jeu = ouvrir({ hebdomadaire: true, testVm: true });
try {
  let m = jusquAuMatch(jeu, creer(jeu));
  if (m.selection?.errors?.length) m = jeu.call('auto_lineup');
  m = jeu.call('begin_match');
  const scene = m.clubLife?.matchTalks?.scene;
  if (scene?.phase === 'pre') {
    m = jeu.call('match_talk_decide', { key: scene.key, phase: 'pre', choiceId: scene.options[0].id, audience: 'group', playerIds: [] });
    m = jeu.call('match_talk_continue', { key: scene.key, phase: 'pre' });
  }
  const vm = jeu.bridge.vm;
  const p0 = m.live.pilotage;
  assert.ok(p0.staff && Array.isArray(p0.staff.propositions), 'avis du staff projeté');
  assert.ok(p0.staff.niveau > 0, 'niveau du staff');

  // --- Rôles en direct ---
  const roles = p0.roles?.roles;
  assert.ok(roles, 'rôles projetés');
  assert.deepEqual(roles.map(r => r.id), ['buteur', 'secours', 'lanceur', 'pied']);
  for (const r of roles) {
    assert.ok(r.label && r.attribut, r.id);
    assert.ok(r.candidats.length >= 1 && r.candidats.every(c => c.id && c.name && c.num >= 1 && c.num <= 15 && Number.isFinite(c.value)), r.id + ' candidats');
    assert.ok(r.enJeu, r.id + ' : joueur en charge');
  }
  const buteur = roles.find(r => r.id === 'buteur');
  const autre = buteur.candidats.find(c => c.id !== buteur.enJeu.id);
  assert.ok(autre, 'un autre buteur possible');
  const banc = JSON.parse(vm.run('JSON.stringify(S.live.sheets[S.live.userSide].bench)'))[0];
  assert.equal(jeu.brut('set_role_direct', { role: 'buteur', id: banc }).ok, false, 'remplaçant refusé');
  assert.equal(jeu.brut('set_role_direct', { role: 'capitaine', id: autre.id }).ok, false, 'rôle inconnu refusé');
  const rng = () => vm.run('JSON.stringify(S.live.rngState??S.live.seed??null)');
  const avant = rng();
  m = jeu.call('set_role_direct', { role: 'buteur', id: autre.id });
  assert.equal(rng(), avant, 'aucun tirage');
  let b = m.live.pilotage.roles.roles.find(r => r.id === 'buteur');
  assert.equal(b.designe.id, autre.id);
  assert.equal(b.enJeu.id, autre.id, 'le désigné tire les buts');
  // Secours = buteur : le secours est retiré.
  m = jeu.call('set_role_direct', { role: 'secours', id: autre.id });
  assert.equal(m.live.pilotage.roles.roles.find(r => r.id === 'secours').designe, null);
  m = jeu.call('set_role_direct', { role: 'buteur', id: null });
  b = m.live.pilotage.roles.roles.find(r => r.id === 'buteur');
  assert.equal(b.designe, null, 'rendu au staff');
  assert.equal(b.enJeu.id, b.staff.id);

  // --- Avis du staff ---
  assert.equal(jeu.brut('appliquer_staff', {}).ok, false, 'sans avis : refus');
  // Mené de 12 en fin de match : le staff finit par le voir et propose de garder le ballon et d'accélérer.
  // Jusqu'à la 50e minute par le vrai direct (causerie de mi-temps comprise), puis mené de 12 : le staff finit par
  // le voir et propose de garder le ballon et d'accélérer.
  const avancer = () => {
    const sc = m.clubLife?.matchTalks?.scene;
    if (sc && !sc.decision) m = jeu.call('match_talk_decide', { key: sc.key, phase: sc.phase, choiceId: sc.options[0].id, audience: 'group', playerIds: [] });
    else if (sc) m = jeu.call('match_talk_continue', { key: sc.key, phase: sc.phase });
    else m = jeu.call('tick', { steps: 10 });
  };
  for (let k = 0; k < 400 && !m.live.finished && m.live.minute < 50; k++) avancer();
  for (let k = 0; k < 400 && !m.live.finished && !m.live.pilotage.staff.propositions.length; k++) {
    vm.run('(()=>{const l=S.live,u=l.userSide;l.score[1-u]=Math.max(l.score[1-u],l.score[u]+12)})()');
    avancer();
  }
  const avis = m.live.pilotage.staff.propositions;
  assert.ok(avis.length >= 1, 'le staff propose quelque chose');
  console.log('avis du staff :', avis.map(a => `${a.label} ${a.actuelLabel} → ${a.valeurLabel} (${a.raison})`).join(' | '));
  for (const a of avis) {
    assert.ok(a.label && a.valeurLabel && a.actuelLabel && a.raison, 'proposition lisible');
    assert.notEqual(m.live.pilotage.consignes[a.axe], a.valeur, 'proposition différente de la consigne en place');
  }
  const avantAvis = rng();
  m = jeu.call('appliquer_staff', {});
  assert.equal(rng(), avantAvis, 'aucun tirage');
  for (const a of avis) assert.equal(m.live.pilotage.consignes[a.axe], a.valeur, a.axe + ' appliquée');
  assert.equal(m.live.pilotage.staff.propositions.length, 0, 'avis épuisé');
  assert.ok(m.live.pilotage.journal.some(j => /Tu suis l’avis du staff/.test(j.texte)), 'journal');
  assert.equal(jeu.brut('appliquer_staff', {}).ok, false, 'second clic refusé');
  console.log('OK avis du staff et rôles en direct');
} finally {
  jeu.fermer?.();
}
