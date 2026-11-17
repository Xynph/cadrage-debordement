'use strict';
// Jalons de joueurs par courrier (17/11/2026, native/engine/club-mail.cjs + club-mail.json, type `jalon_carriere`) :
// un joueur de l'effectif qui franchit un cap de matchs en carrière (50, 100, 150… : saisons closes + saison en cours)
// écrit au manager ; un seul courrier par cap, rien sans franchissement, rien pour un joueur déjà au-dessus à son arrivée.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { test } = require('node:test');
const DATA = require('../native/engine/club-mail.json');
const M = require('./helpers/carriere-monde.cjs');

test('Données : type jalon_carriere complet', () => {
  const t = DATA.types.jalon_carriere;
  assert.ok(t && t.declencheur === 'jalon_carriere' && DATA.categories[t.categorie]);
  assert.deepEqual(t.seuils.caps, [50, 100, 150, 200, 250, 300]);
  assert.ok(t.formulations.length >= 2 && t.reponses.length >= 2);
  for (const f of t.formulations) assert.match(f.sujet + f.corps, /\{joueur\}/);
});

test('Carrière Monde : cap de matchs en carrière franchi → un courrier, une seule fois', { timeout: 600000 }, () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'rl27-jalons-'));
  const jeu = M.ouvrir({ dataDir: dir, deferredCommits: true, testVm: true, mandatoryPress: false, journal: true, savePolicy: 'semaine' });
  try {
    jeu.regler(jeu.call('new_career', { mode: 'world-champ', club: 102, start: 'veille' }));
    const vm = jeu.bridge.vm;
    const recevoir = () => JSON.parse(vm.run(`(()=>{const d=CDWorldCareer.calendarToday(S),n=S.clubMail.mails.length;
      S.clubMail.last=new Date(Date.parse(d+'T00:00:00Z')-86400000).toISOString().slice(0,10);
      nativeSystems.domain('clubMail').recevoir(S,d);
      return JSON.stringify(S.clubMail.mails.slice(n).filter(m=>m.type==='jalon_carriere').map(m=>({player:m.player,n:m.vars.n,carriere:m.vars.carriere,status:m.status})));})()`));
    // Joueur test : 45 matchs d'anciennes saisons + 4 cette saison = 49 ; le 50e franchit le cap.
    const id = vm.run(`(()=>{const p=S.clubs[S.club].players[0];ensureDevelopment(p);p.dev.history=[{season:2024,appearances:25},{season:2025,appearances:20}];p.dev.appearances=4;return p.id})()`);
    assert.deepEqual(recevoir(), [], 'aucun courrier à 49 matchs');
    vm.run(`S.clubs[S.club].players.find(p=>p.id==='${id}').dev.appearances=5`);
    const recu = recevoir();
    assert.equal(recu.length, 1, 'un courrier au 50e match');
    assert.equal(recu[0].player, id);
    assert.equal(recu[0].n, 50);
    assert.equal(recu[0].carriere, 50);
    assert.equal(recu[0].status, 'nouveau');
    assert.deepEqual(recevoir(), [], 'pas de second courrier pour le même cap');
    // Joueur arrivé avec 120 matchs, absent de la mémoire (transfert, ancienne sauvegarde) : aucun courrier.
    const autre = vm.run(`(()=>{const p=S.clubs[S.club].players[1];ensureDevelopment(p);p.dev.history=[{season:2025,appearances:120}];p.dev.appearances=0;delete S.clubMail.memo.careerApps[p.id];return p.id})()`);
    assert.deepEqual(recevoir().filter(x => x.player === autre), [], 'cap déjà dépassé avant la mémoire : rien');
    // Cap suivant (100e) : un seul courrier pour le plus haut cap franchi d'un coup.
    vm.run(`S.clubs[S.club].players.find(p=>p.id==='${id}').dev.appearances=60`);
    const cent = recevoir();
    assert.equal(cent.length, 1);
    assert.equal(cent[0].n, 100);
    // Plafond hebdomadaire de la catégorie « moments » atteint : le cap n'est pas perdu, il sort dès qu'une place se libère.
    const joueur = vm.run(`(()=>{const p=S.clubs[S.club].players[2];ensureDevelopment(p);p.dev.history=[{season:2025,appearances:149}];p.dev.appearances=0;S.clubMail.memo.careerApps[p.id]=149;return p.id})()`);
    vm.run(`(()=>{const d=CDWorldCareer.calendarToday(S);S.clubMail.mails.push({id:'x1',type:'serie',date:d,f:0,vars:{n:4},player:null,status:'info',choice:null},{id:'x2',type:'serie',date:d,f:0,vars:{n:6},player:null,status:'info',choice:null});S.clubs[S.club].players.find(p=>p.id==='${joueur}').dev.appearances=1})()`);
    assert.deepEqual(recevoir().filter(x => x.player === joueur), [], 'plafond atteint : pas de courrier');
    vm.run(`S.clubMail.mails=S.clubMail.mails.filter(m=>m.type!=='serie'&&m.type!=='jalon_carriere')`);
    const rattrape = recevoir().filter(x => x.player === joueur);
    assert.equal(rattrape.length, 1, 'cap rattrapé quand la place se libère');
    assert.equal(rattrape[0].n, 150);
    // Historique tronqué (12 saisons) : le total ne régresse pas, pas de courrier en double.
    vm.run(`(()=>{const p=S.clubs[S.club].players.find(p=>p.id==='${joueur}');p.dev.history=[];p.dev.appearances=1})()`);
    assert.deepEqual(recevoir().filter(x => x.player === joueur), [], 'total qui baisse : aucun courrier');
    // Réponse du manager : décision ordinaire.
    const mail = JSON.parse(vm.run(`JSON.stringify(S.clubMail.mails.filter(m=>m.type==='jalon_carriere').pop())`));
    const r = jeu.brut('club_mail_reply', { id: mail.id, choice: 'feliciter' });
    assert.equal(r.ok, true, r.error);
  } finally {
    jeu.fermer?.();
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
