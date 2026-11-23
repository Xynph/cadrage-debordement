'use strict';
// File « prochain arrêt de jeu » et pilotage individuel en direct (native/engine/match-arrets.cjs, idée FM27 n° 32) en
// carrière Monde : un remplacement, un rôle du poste, des consignes individuelles ou un réglage du plan attendent le
// prochain arrêt de jeu ; l'entrant garde son vrai numéro de la feuille (16 à 23) ; rôles et consignes individuelles
// changent vraiment le jeu (mesuré en moyenne sur des lots de matchs, mêmes graines, un seul réglage change) ; moral
// des remplaçants suivi depuis le banc ; une rencontre sans ces champs (ancienne sauvegarde) se relit et se joue.
const assert = require('node:assert/strict');
const { ouvrir, creer, jusquAuMatch } = require('./helpers/carriere-monde.cjs');

const jeu = ouvrir({ hebdomadaire: true, testVm: true });
const vm = jeu.bridge.vm;
const J = code => JSON.parse(vm.run(`JSON.stringify((()=>{${code}})())`, 600000));
try {
  let m = jusquAuMatch(jeu, creer(jeu));
  if (m.selection?.errors?.length) m = jeu.call('auto_lineup');
  m = jeu.call('begin_match');
  const scene = m.clubLife?.matchTalks?.scene;
  if (scene) m = jeu.call('match_talk_continue', { key: scene.key, phase: scene.phase, skip: true });
  vm.run('globalThis.__depart=JSON.stringify(S.live);');
  assert.ok(m.live.pilotage.arrets, 'file projetée dans le pilotage');
  const cat = m.live.pilotage.arrets.catalogue;
  assert.deepEqual(Object.keys(cat), ['avant', 'demi', 'ouvreur', 'trois', 'arriere']);
  assert.ok(Object.values(cat).every(l => l.length === 4 && l.every(c => c.id && c.label)), 'quatre consignes par famille');
  // Mêmes rôles (identifiants, familles, qualités) que la fiche joueur de Godot.
  const gd = require('node:fs').readFileSync(require('node:path').join(__dirname, '../native/godot/ui/immersive08/fiche_roles.gd'), 'utf8');
  const rolesGd = [...gd.matchAll(/^	\["([a-z-]+)", "([a-z]+)", "[^"]+", \[([^\]]+)\], \[([^\]]+)\]\]/gm)].map(x => [x[1], x[2], x[3].replace(/[" ]/g, ''), x[4].replace(/[" ]/g, '')].join('|'));
  const rolesMoteur = J('return CDMatchArrets.ROLES_DETAIL.map(r=>[r[0],r[1],r[3].join(","),r[4].join(",")].join("|"))');
  assert.equal(rolesGd.length, 30, 'trente rôles dans la fiche');
  assert.deepEqual(rolesMoteur, rolesGd, 'table des rôles identique au moteur et à l’écran');

  // Vrais numéros de la feuille (1 à 23), les deux camps.
  const numeros = m.live.numeros;
  m.live.lineup.forEach((p, i) => assert.equal(numeros[p.id], i + 1, 'titulaire n° ' + (i + 1)));
  m.live.reserves.forEach((p, i) => assert.equal(numeros[p.id], 16 + i, 'remplaçant n° ' + (16 + i)));
  assert.equal(Object.keys(numeros).length, 46, 'deux feuilles de 23');

  // Moral des remplaçants suivi dès le coup d'envoi.
  m = jeu.call('tick', { steps: 2 });
  for (const p of m.live.reserves) assert.ok(m.live.pilotage.moral[p.id]?.label, 'moral du remplaçant ' + p.name);

  // Avancer jusqu'à une minute sans arrêt à venir n'est pas prévisible : on enfile, puis on avance minute par minute
  // en vérifiant que rien ne change avant la minute qui contient un arrêt de jeu.
  const arretDans = (debut) => J(`const ev=S.live.events.slice(${debut});const T=new Set(['try','penalty','goal','miss','card','sub','break','end','restart','setup']),K=new Set(['touch','ingoal','kickoff','lineout','scrum','try','penalty','goal','card']);return ev.some(e=>T.has(e.type)||K.has(e.scene?.kind))`);
  const neuf = m.live.lineup[8], dix = m.live.lineup[9];
  const roles = J(`const l=S.live,sh=l.sheets[l.userSide];return [8,9].map(s=>({id:sh.on[s],nat:CDMatchArrets.roleNaturel(matchPlayer(l,l.userSide,sh.on[s]),s)[0]}))`);
  const autreRole = roles[1].nat === 'ouvreur-attaquant' ? 'ouvreur-stratege' : 'ouvreur-attaquant';
  const slot = m.live.substitutions.findIndex(s => s.slot >= 5 && s.inIds.length);
  assert.ok(slot >= 0, 'un changement autorisé');
  const sub = m.live.substitutions[slot], entrant = sub.inIds[0], sortant = sub.outId;
  const numeroEntrant = numeros[entrant];
  assert.ok(numeroEntrant >= 16 && numeroEntrant <= 23);
  assert.equal(m.live.paused, false, 'le match joue : aucune pause demandée');
  m = jeu.call('substitute', { slot, outId: sortant, inId: entrant });
  assert.equal(m.meta.fileArret.enAttente, true, 'remplacement mis en attente');
  m = jeu.call('file_arret', { action: 'ajouter', change: { type: 'role', id: dix.id, role: autreRole } });
  m = jeu.call('file_arret', { action: 'ajouter', change: { type: 'consignes', id: neuf.id, valeurs: ['pied'] } });
  m = jeu.call('set_consignes', { axe: 'rythme', valeur: 'rapide' });
  m = jeu.call('set_role_direct', { role: 'buteur', id: dix.id });
  assert.deepEqual(m.live.pilotage.arrets.file.map(e => e.type), ['remplacement', 'role', 'consignes', 'consigne', 'responsabilite']);
  assert.ok(m.live.pilotage.arrets.file.every(e => e.texte), 'chaque attente a son libellé');
  assert.equal(m.live.lineup[slot].id, sortant, 'rien ne change avant l’arrêt');
  assert.equal(m.live.pilotage.consignes.rythme, 'normal');
  // Mêmes clés : la dernière demande remplace la précédente ; ramener l'état actuel annule.
  m = jeu.call('file_arret', { action: 'ajouter', change: { type: 'consignes', id: neuf.id, valeurs: ['pied', 'avants'] } });
  assert.equal(m.live.pilotage.arrets.file.filter(e => e.type === 'consignes').length, 1);
  assert.equal(jeu.brut('file_arret', { action: 'ajouter', change: { type: 'consignes', id: neuf.id, valeurs: ['pied', 'accelerer'] } }).ok, false, 'consignes qui s’excluent refusées');
  assert.equal(jeu.brut('file_arret', { action: 'ajouter', change: { type: 'consignes', id: neuf.id, valeurs: ['pied', 'avants', 'intervalle'] } }).ok, false, 'deux consignes au plus');
  assert.equal(jeu.brut('file_arret', { action: 'ajouter', change: { type: 'role', id: neuf.id, role: autreRole } }).ok, false, 'rôle d’un autre poste refusé');
  m = jeu.call('set_role_direct', { role: 'buteur', id: null });
  assert.equal(m.meta.fileArret.annule, true, 'retour à l’état actuel : demande annulée');
  assert.equal(m.live.pilotage.arrets.file.length, 4);
  let applique = null;
  for (let i = 0; i < 30 && !applique; i++) {
    const debut = J('return S.live.events.length');
    m = jeu.call('tick');
    const arret = arretDans(debut);
    if (m.live.pilotage.arrets.file.length) { assert.equal(arret, false, 'file gardée tant que le ballon vit'); continue; }
    assert.equal(arret, true, 'la file part à la minute qui contient un arrêt de jeu');
    applique = m.live.minute;
  }
  assert.ok(applique, 'la file s’applique au prochain arrêt');
  assert.equal(m.live.lineup[slot].id, entrant, 'l’entrant est sur le terrain');
  assert.equal(m.live.numeros[entrant], numeroEntrant, 'il garde son vrai numéro de remplaçant');
  assert.equal(m.live.pilotage.consignes.rythme, 'rapide');
  assert.equal(m.live.pilotage.arrets.roles[dix.id].role, autreRole);
  assert.deepEqual(m.live.pilotage.arrets.consignes[neuf.id], ['pied', 'avants']);
  const faits = m.live.pilotage.arrets.appliques;
  assert.equal(faits.length, 4);
  assert.ok(faits.every(f => f.ok && f.minute === applique && f.cause === 'arret'));
  assert.ok(m.live.pilotage.journal.some(j => /^Arrêt de jeu : .+ remplace .+\.$/.test(j.texte)), 'journal du staff');
  // Sauvegarde : export / import avec une file en attente, puis une rencontre sans ces champs (ancienne).
  m = jeu.call('file_arret', { action: 'ajouter', change: { type: 'role', id: dix.id, role: null } });
  // (Un import rouvre la journée avant le match : la sauvegarde du direct se contrôle par sa validation.)
  assert.equal(J('validateCareer(S);return S.live.pilotage.file.length'), 1, 'file en attente acceptée par la validation');
  assert.equal(J('const t=JSON.parse(JSON.stringify(S));validateCareer(t);return t.live.pilotage.file[0].type'), 'role', 'file gardée par la copie de sauvegarde');
  vm.run('delete S.live.pilotage.file;delete S.live.pilotage.arrets;delete S.live.pilotage.indiv;validateCareer(S);');
  m = jeu.call('snapshot');
  assert.deepEqual(m.live.pilotage.arrets.file, [], 'ancienne rencontre : file vide');
  m = jeu.call('tick', { steps: 3 });
  assert.ok(m.live.minute > applique, 'ancienne rencontre jouée');
  m = jeu.call('file_arret', { action: 'ajouter', change: { type: 'consignes', id: neuf.id, valeurs: ['pied'] } });
  assert.ok(m.meta.fileArret.enAttente || m.meta.fileArret.applique, 'ancienne rencontre : la file s’ouvre');

  // --- Effets réels : lots de matchs depuis le coup d'envoi, mêmes graines, banc adverse figé. ---
  const seed = 'Math.random=(()=>{let x=(i*7919+17)>>>0;return()=>{x=(Math.imul(x,1664525)+1013904223)>>>0;return x/4294967296}})();';
  const mesurer = (reglage, n) => J(`const acc={coups:0,pen:0,arraches:0,metres:0,pertes:0,energie:0,ecart:0,matchs:0};
    for(let i=0;i<${n};i++){S.live=JSON.parse(__depart);const l=S.live;delete l.pilotage.consignesAdverses;delete l.pilotage.adversaire;
     const u=l.userSide,sh=l.sheets[u],snap=S.clubs[l.pair[u]].players.map(p=>[p,p.condition]);
     ${reglage}${seed}let k=0;while(!l.finished&&k++<400){l.paused=false;advanceRugby(l)}
     const o=1-u;acc.coups+=l.tacticalStats?.[u]?.kicks||0;acc.pen+=l.stats[u].penalties;acc.arraches+=l.tacticalStats?.[o]?.handErrors||0;
     acc.metres+=l.tacticalStats?.[u]?.metres||0;acc.pertes+=l.tacticalStats?.[u]?.handErrors||0;acc.ecart+=l.score[u]-l.score[o];
     acc.energie+=sh.initial.slice(0,8).reduce((n,id)=>n+(matchPlayer(l,u,id)?.condition||0),0)/8;
     for(const [p,c] of snap)p.condition=c;acc.matchs++}
    for(const k of Object.keys(acc))if(k!=='matchs')acc[k]/=acc.matchs;return acc`);
  const poser = (quoi) => `const ind=l.pilotage.indiv={roles:{},consignes:{},v:1};${quoi}`;
  const N = 160;
  const base = mesurer(poser(''), N);
  // Charnière et arrière « Jouer au pied » : plus de coups de pied.
  const pied = mesurer(poser('ind.consignes[sh.on[8]]=["pied"];ind.consignes[sh.on[9]]=["pied"];ind.consignes[sh.on[14]]=["pied"];'), N);
  // Avants « Gratter au sol » : plus de ballons arrachés, plus de pénalités, plus de fatigue.
  const gratter = mesurer(poser('for(const s of [1,5,6,7])ind.consignes[sh.on[s]]=["gratter"];'), N);
  // Rôles : ouvreur stratège contre attaquant (jeu au pied).
  const stratege = mesurer(poser('ind.roles[sh.on[9]]="ouvreur-stratege";ind.roles[sh.on[8]]="demi-tacticien";ind.roles[sh.on[14]]="arriere-botteur";'), N);
  const attaquant = mesurer(poser('ind.roles[sh.on[9]]="ouvreur-attaquant";ind.roles[sh.on[8]]="demi-eclaireur";ind.roles[sh.on[14]]="arriere-relanceur";'), N);
  const r = x => Math.round(x * 100) / 100;
  console.log('coups de pied : base', r(base.coups), '· consignes « au pied »', r(pied.coups), '| rôles stratège', r(stratege.coups), '· attaquant', r(attaquant.coups));
  console.log('ballons arrachés : base', r(base.arraches), '· gratteurs', r(gratter.arraches), '| pénalités : base', r(base.pen), '· gratteurs', r(gratter.pen), '| énergie des avants : base', r(base.energie), '· gratteurs', r(gratter.energie));
  console.log('écart de score : base', r(base.ecart), '· pied', r(pied.ecart), '· gratteurs', r(gratter.ecart), '· stratège', r(stratege.ecart), '· attaquant', r(attaquant.ecart));
  assert.ok(pied.coups > base.coups * 1.08, 'consignes « Jouer au pied » : plus de jeu au pied');
  assert.ok(pied.coups < base.coups * 1.6, 'effet modéré');
  assert.ok(gratter.arraches > base.arraches && gratter.pen > base.pen, 'gratteurs : plus de ballons arrachés et de pénalités');
  assert.ok(gratter.energie < base.energie, 'gratteurs : plus de fatigue');
  assert.ok(stratege.coups > attaquant.coups * 1.08, 'rôles : le stratège occupe plus que l’attaquant');
  for (const x of [pied, gratter, stratege, attaquant]) assert.ok(Math.abs(x.ecart - base.ecart) < 6, 'aucun effet absurde sur le score');
  console.log('Match en direct : file du prochain arrêt, vrais numéros, rôles et consignes individuelles, moral du banc PASS');
} finally { jeu.fermer?.(); }
process.exit(0);
