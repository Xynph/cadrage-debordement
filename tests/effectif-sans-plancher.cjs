'use strict';
// Club joué sans plancher de 40 professionnels (décision de Léo du 19/11/2026, docs/gdd/calendrier-mutations.md
// § 3 quater, points 2 et 3) — carrière Monde `world-champ` seulement :
//   1. Création : le club joué ne reçoit aucun joueur de complément (« depth-… ») ; les clubs gérés gardent leur
//      plancher de 40 (et ne l'ont plus avec CD_PLANCHER_CLUBS_GERES=0).
//   2. Passage de saison (même remplissage que après chaque commande, nativeProfessionalDepth.fill) : club joué
//      sous 40 jamais complété, club géré complété.
//   3. Effectif vidé (piliers droits blessés) : alerte « Effectif trop juste » de « Continuer » au plus tard la
//      veille, puis un espoir du centre monte sur la feuille pour ce match seulement et retourne au centre après.
const assert = require('node:assert/strict');
const { test } = require('node:test');
const M = require('./helpers/carriere-monde.cjs');
const { skipMatchTalk } = require('./helpers/scene-match-talks.cjs');
const professionalDepth = require('../native/engine/professional-depth.cjs');

const CLUB = 102;
const ouvrir = () => M.ouvrir({ testVm: true, mandatoryPress: false });
const vm = (jeu, source) => JSON.parse(jeu.bridge.vm.run('JSON.stringify(' + source + ')'));
const effectifs = jeu => vm(jeu, 'S.clubs.map(c=>({id:c.id,n:c.players.length,depth:c.players.filter(p=>p.id.startsWith("depth-")).length}))');

test('Création Monde : aucun joueur de complément au club joué, plancher gardé pour les clubs gérés', () => {
  const jeu = ouvrir();
  try {
    M.creer(jeu, CLUB);
    const clubs = effectifs(jeu), own = clubs.find(c => c.id === CLUB), geres = clubs.filter(c => c.id !== CLUB);
    assert.equal(own.depth, 0, 'club joué : aucun « depth-… »');
    assert.ok(geres.every(c => c.n >= 40), 'clubs gérés : 40 professionnels au moins');
    assert.ok(geres.some(c => c.depth > 0), 'clubs gérés : des joueurs de complément existent');
    assert.equal(vm(jeu, 'S.clubs[S.club].players.filter(p=>p.id.startsWith("academy-")).length'), 0, 'aucun renfort généré à la création');
  } finally { jeu.fermer(); }
});

test('CD_PLANCHER_CLUBS_GERES=0 : plus de joueurs de complément, même pour les clubs gérés', () => {
  const avant = process.env.CD_PLANCHER_CLUBS_GERES;
  process.env.CD_PLANCHER_CLUBS_GERES = '0';
  const jeu = ouvrir();
  try {
    M.creer(jeu, CLUB);
    assert.equal(effectifs(jeu).reduce((n, c) => n + c.depth, 0), 0);
  } finally {
    jeu.fermer();
    if (avant === undefined) delete process.env.CD_PLANCHER_CLUBS_GERES; else process.env.CD_PLANCHER_CLUBS_GERES = avant;
  }
});

test('Passage de saison (remplissage du moteur) : club joué jamais complété, club géré complété, anciens « depth-… » gardés', () => {
  // Règle pure, telle qu'installée dans la VM : `fill` est appelé à la création, au chargement, au passage de saison
  // et après chaque commande hors match (worker.cjs). Fixture : POS/FAMILIES/… minimaux du moteur.
  const POS = ['Pilier gauche', 'Talonneur', 'Pilier droit', 'Deuxième ligne', 'Deuxième ligne', 'Troisième ligne', 'Troisième ligne', 'Numéro 8', 'Demi de mêlée', 'Demi d’ouverture', 'Ailier', 'Centre', 'Centre', 'Ailier', 'Arrière'];
  const vmGlobals = { POS, FAMILIES: POS.map((_, i) => i), FIRST: ['Jean'], LAST: ['Martin'], ATTR: { a: 1 },
    seedHash: s => [...String(s)].reduce((h, c) => (h * 31 + c.charCodeAt(0)) >>> 0, 7),
    slotEligible: (p, i) => p.pos === POS[i], roleNote: p => p.rating,
    ensureSkills: p => ({ ...p, skills: { a: p.rating } }), ensureDevelopment: p => { p.dev = { potential: p.rating + 5 }; } };
  const build = options => new Function(...Object.keys(vmGlobals), 'return (' + professionalDepth.toString() + ')(' + JSON.stringify(options) + ');')(...Object.values(vmGlobals));
  const roster = (club, n, extra = []) => [...Array.from({ length: n }, (_, k) => ({ id: `world:${club}-${k}`, name: 'Joueur ' + k, pos: POS[k % 15], rating: 60 })), ...extra];
  const state = () => ({ worldMode: {}, club: 0, season: 2, round: 0, phase: 'ended', market: [], economy: { freeAgents: [] },
    clubs: [{ id: 0, players: roster(0, 30, [{ id: 'depth-0-1-1', name: 'Ancien Complément', pos: POS[2], rating: 50 }]) }, { id: 1, players: roster(1, 30) }] });
  let s = state();
  build({}).fill(s);
  assert.equal(s.clubs[0].players.length, 31, 'club joué : rien ajouté');
  assert.ok(s.clubs[0].players.some(p => p.id === 'depth-0-1-1'), 'ancien joueur de complément gardé sous contrat');
  assert.equal(s.clubs[1].players.length, 40, 'club géré complété à 40');
  s = state();
  build({ managedFloor: false }).fill(s);
  assert.equal(s.clubs[1].players.length, 30, 'CD_PLANCHER_CLUBS_GERES=0 : club géré non complété');
  // Hors Monde (anciens modes), comportement d'origine.
  s = state(); delete s.worldMode;
  build({}).fill(s);
  assert.equal(s.clubs[0].players.length, 40);
});

test('Effectif vidé : alerte avant le match, espoir sur la feuille pour ce match seulement, retour au centre', () => {
  const jeu = ouvrir();
  try {
    let m = M.creer(jeu, CLUB);
    // Jusqu'à trois jours du premier match.
    for (let j = 0; j < 150; j++) {
      m = jeu.regler(m);
      const d = vm(jeu, 'nativeSystems.domain("espoirsMatch").shortage(S)?.date||((S.worldMode.fixtures||[]).filter(f=>(f.homeId===S.club||f.awayId===S.club)&&f.date>=CDWorldCareer.calendarToday(S)).map(f=>f.date).sort()[0])||null');
      if (d && Math.round((Date.parse(d) - Date.parse(m.meta.calendarToday)) / 86400000) <= 3) break;
      m = jeu.call('advance_day', { fromDate: m.meta.calendarToday });
    }
    // Tous les piliers droits professionnels blessés ; le centre doit en avoir un apte (sinon le test le dit).
    vm(jeu, '(S.clubs[S.club].players.forEach(p=>{if(p.pos===POS[2])p.injury=4;}),0)');
    const court = vm(jeu, 'nativeSystems.domain("espoirsMatch").shortage(S)');
    assert.ok(court && court.slots.some(x => x.slot === 2), 'manque au poste de pilier droit : ' + JSON.stringify(court));
    assert.ok(court.youth >= 1, 'le centre a au moins un pilier droit apte : ' + JSON.stringify(court));
    // « Continuer » jusqu'au jour du match : l'alerte tombe au plus tard la veille.
    const arrets = [];
    for (let i = 0; i < 40 && !(m.meta.calendarCadence?.matchReady && m.next); i++) {
      m = jeu.regler(m);
      if (m.meta.calendarCadence?.matchReady && m.next) break;
      const r = jeu.brut('advance_until_event', { fromDate: m.meta.calendarToday, stops: { messages: 'aucun' } });
      assert.equal(r.ok, true, r.error);
      m = r.model;
      arrets.push({ date: m.meta.calendarToday, ...m.meta.advanceUntilEvent.stop });
    }
    assert.ok(m.meta.calendarCadence?.matchReady, 'jour de match atteint');
    const alerte = arrets.find(a => a.label === 'Effectif trop juste');
    assert.ok(alerte, 'alerte avant le match : ' + JSON.stringify(arrets.map(a => [a.date, a.kind, a.type, a.detail])));
    assert.ok(alerte.date < m.meta.calendarToday, 'alerte avant le jour du match');
    assert.equal(alerte.label, 'Effectif trop juste');
    // Postes regroupés : jamais « n°3 (pilier droit) et n°3 (pilier droit) » (titulaire et remplaçant au même poste).
    assert.match(alerte.detail, /(la place de pilier droit \(n°3\)|\d places de pilier droit)/);
    assert.doesNotMatch(alerte.detail, /pilier droit[^.]*pilier droit/);
    assert.match(alerte.detail, /du centre de formation à ce poste monter(a|ont) pour ce match seulement/);
    // Coup d'envoi : l'espoir monte (prêt, sans contrat professionnel), sans renfort signé.
    const avant = vm(jeu, 'S.clubs[S.club].players.map(p=>p.id)');
    m = skipMatchTalk(jeu.call('begin_match'), jeu.call);
    const pendant = vm(jeu, '({prets:S.clubs[S.club].players.filter(p=>p.espoirLoan).map(p=>({id:p.id,pos:p.pos})),feuille:[...S.live.sheets[S.live.userSide].on,...S.live.sheets[S.live.userSide].bench]})');
    assert.ok(pendant.prets.some(p => p.pos === 'Pilier droit' && pendant.feuille.includes(p.id)), 'pilier droit du centre sur la feuille : ' + JSON.stringify(pendant));
    const nouveaux = vm(jeu, 'S.clubs[S.club].players.map(p=>p.id)').filter(id => !avant.includes(id));
    assert.deepEqual(nouveaux.sort(), pendant.prets.map(p => p.id).sort(), 'aucune autre arrivée que les espoirs prêtés');
    assert.ok(vm(jeu, 'S.manager.inbox.some(x=>x.title==="Des espoirs montent pour le match")'), 'message du staff');
    // Non-régression (mesure 3 saisons, 19/11/2026) : un espoir souvent appelé atteignait un moral de 96+, que la
    // sauvegarde refuse (« données de carrière incohérentes » au finish_round). Moral déjà au maximum (95) : le match
    // (feuille = au moins +1) doit le laisser à 95 et l'enregistrement de fin de match doit passer.
    const ids = JSON.stringify(pendant.prets.map(p => p.id));
    // (Le moral d'un espoir naît lors d'un passage en équipe première, ensureSatisfaction ; on le pose ici d'emblée.)
    vm(jeu, `(${ids}.forEach(id=>{const p=S.clubs[S.club].players.find(q=>q.id===id);ensureSatisfaction(p);p.satisfaction.score=95;}),0)`);
    m = skipMatchTalk(jeu.call('delegate'), jeu.call);
    if (m.live) m = skipMatchTalk(jeu.call('finish_round'), jeu.call);
    m = M.jusquALaSemaineSuivante(jeu, jeu.regler(m));
    const apres = vm(jeu, `({prets:S.clubs[S.club].players.filter(p=>p.espoirLoan).length,
      centre:${JSON.stringify(pendant.prets.map(p => p.id))}.map(id=>S.development.academy.find(p=>p.id===id)).map(p=>p?{academy:p.academy,contrat:p.contractEnd??null,moral:p.satisfaction?.score??null}:null)})`);
    assert.ok(apres.centre.every(p => p && p.moral !== null && p.moral <= 95), 'moral des espoirs borné à 95 : ' + JSON.stringify(apres.centre));
    assert.equal(apres.prets, 0, 'plus aucun espoir prêté');
    assert.ok(apres.centre.every(p => p && p.academy === true && p.contrat === null), 'espoirs revenus au centre, sans contrat : ' + JSON.stringify(apres.centre));
  } finally { jeu.fermer(); }
});
