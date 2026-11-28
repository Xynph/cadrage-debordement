'use strict';
// Arrêts informatifs de « Continuer » pendant la saison (décision de Léo, 16/11/2026) : façon Football Manager,
// l'avance s'arrête aussi sur des moments sans décision (veille et lendemain de match, rapport médical, mi-saison,
// fin de phase, marché, recruteur), avec parcimonie, et plusieurs fois le même jour si besoin.
//   1. Règle pure (continuer.cjs + continuer-arrets.json) : types toujours actifs, priorité, un arrêt d'info par jour,
//      un arrêt par courrier à réponse, routine rangée.
//   2. CI de PR (rapide) : carrière Monde (`world-champ`, calendrier journalier) partie de la veille de la saison,
//      jouée à « Continuer » sur une fenêtre courte : veille, lendemain, rapport médical, un jour à plusieurs arrêts,
//      arrêt du même jour sans avancer ; puis même graine sans arrêts informatifs : état identique en fin de fenêtre.
//   3. `ARRETS_SAISON_COMPLETE=1` (créneau lourd régulier sur main, .github/workflows/career-resilience.yml) :
//      saison complète, arrêts informatifs répartis (nombre par mois borné), état comparé au 15/12 (~30 min).
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { test } = require('node:test');
const C = require('../native/engine/continuer.cjs');
const M = require('./helpers/carriere-monde.cjs');
const { skipMatchTalk } = require('./helpers/scene-match-talks.cjs');

const FACULTATIFS = Object.keys(C.STOPS).filter(k => !C.STOPS[k].mandatory);
const opts = (extra = {}) => C.validate({ fromDate: '2026-09-01', stops: { ...extra } });

test('Règle : types informatifs toujours actifs, priorité, plusieurs arrêts le même jour', () => {
  // Réglage en données : chaque type a un libellé et une priorité ; plus de niveaux (décision de Léo, 16/11).
  for (const [k, t] of Object.entries(C.ARRETS.types)) {
    assert.ok(t.label && Number.isFinite(t.priorite), k);
    assert.equal(t.flux, undefined, k + ' : pas de niveau');
  }
  assert.equal(C.STOPS.info.mandatory, false, 'un arrêt informatif est toujours facultatif');
  const base = { today: '2026-10-09', matchReady: false, canAdvance: true, ended: false, live: false, meeting: null, press: false, pressIds: [],
    sceneActive: null, sceneIds: [], serial: 3, inbox: [], national: [], nationalTitles: {}, fixtures: 'f', next: { date: '2026-10-10', opponent: 'Rivaux' },
    starters: ['t1'], injured: [], names: { t1: 'Titulaire', r1: 'Remplaçant' }, tired: [], squad: 't1,r1', window: null, preseason: false,
    round: 12, season: 1, leagueId: 'champ', phases: { champ: { phase: 'league', champion: null } }, longInjured: [], injuryWeeks: {}, missions: [] };
  const hier = { ...base, today: '2026-10-08' };
  const veille = { id: 'champ:2026:league:5:1', opponent: 'Rivaux', home: true, competitionId: 'champ', phase: 'league', sheet: 23, sheetInjured: 1, form: 'VVDNV', rank: 3, ownRank: 6 };
  // Veille de match seule : arrêt informatif, détail du manager (feuille, adversaire).
  let r = C.arrets(hier, { ...base, veille }, opts());
  assert.equal(r.stop.kind, 'info');
  assert.equal(r.stop.type, 'veille');
  assert.equal(r.stop.detail, 'Demain, réception de Rivaux : feuille de match complète (23), 1 blessé à remplacer. Adversaire : Rivaux 3e, nous 6e, forme V-V-D-N-V.');
  assert.deepEqual(r.queue, []);
  assert.equal(C.arrets({ ...hier, veille }, { ...base, veille }, opts()).stop, null, 'déjà vu la veille : pas de nouvel arrêt');
  assert.equal(C.arrets(base, { ...base, veille }, opts()).stop, null, 'même jour : rien de neuf');
  // Plusieurs éléments d'info le même jour (décision de Léo, 18/11/2026) : un seul arrêt, le plus important en tête,
  // les autres rangés dedans (types gardés dans l'ordre de priorité par informatifs()).
  const jour = { ...base, veille, longInjured: ['r1'], injured: ['r1'], injuryWeeks: { r1: 6 }, round: 12, phases: { champ: { phase: 'league', champion: null } } };
  r = C.arrets({ ...hier, round: 11 }, jour, opts());
  assert.deepEqual(r.queue, [], JSON.stringify(r));
  assert.equal(r.stop.type, 'groupe');
  assert.equal(r.stop.label, 'Veille de match');
  assert.equal(r.stop.elements, 3);
  assert.match(r.stop.detail, /^Demain, réception de Rivaux .* · Rapport médical : Absence longue : Remplaçant \(6 sem\.\).* · Marché des transferts : .*marché dans une semaine/);
  assert.equal(r.stop.ecran, 'Composition', 'sans courrier : écran du plus important');
  // Ancien réglage de niveau (`flux`) ignoré : mêmes éléments ; « info » ignoré (outils, essais) : rien.
  for (const flux of ['allege', 'equilibre', 'complet'])
    assert.deepEqual(C.informatifs({ ...hier, round: 11 }, jour, opts({ flux })).map(x => x.type), ['veille', 'medical', 'mercato'], flux);
  assert.deepEqual(C.informatifs({ ...hier, round: 11 }, jour, opts({ ignorer: ['info'] })), []);
  // Arrêt principal (obligatoire ou existant) d'abord, puis l'arrêt d'info du jour (un seul).
  const charge = { ...jour, meeting: { kind: 'board', id: 'b' }, missions: [{ id: 'mission-1', n: 2 }], lendemain: { id: 'x', opponent: 'Autres', home: false, us: 20, them: 13, injured: 1 } };
  r = C.arrets({ ...hier, round: 11 }, charge, opts());
  assert.equal(r.stop.kind, 'rendez_vous');
  assert.equal(r.queue.length, 1, 'un seul arrêt d\'info le même jour');
  assert.equal(r.queue[0].type, 'groupe');
  assert.match(r.queue[0].detail, /Rapport de recruteur : 2 profils proposés/);
  // Courrier du jour selon sa nature : chaque courrier à réponse a son arrêt ; les courriers d'info et de routine sont
  // rangés dans l'arrêt d'info du jour (veille), la Réception s'ouvrant sur le plus important ; de la routine seule
  // n'arrête jamais l'avance. Rien ne disparaît : `mails` liste tous les courriers rangés.
  const mail = (id, nature, priorite, sujet) => ({ id, nature, priorite, type: 't', sujet, expediteur: 'Exp', ecran: 'Bureau' });
  const courrier = [mail('mail-1', 'routine', 8, 'Bulletin météo'), mail('mail-2', 'action', 12, 'Une gêne'), mail('mail-3', 'routine', 66, 'Leur plan'), mail('mail-4', 'info', 30, 'Retour')];
  r = C.arrets(hier, { ...base, veille, courrier }, opts());
  assert.deepEqual([r.stop.type, ...r.queue.map(x => x.type)], ['groupe', 'courrier'], JSON.stringify(r));
  assert.equal(r.stop.label, 'Veille de match');
  assert.deepEqual(r.stop.mails, ['mail-4', 'mail-1', 'mail-3']);
  assert.equal(r.stop.mail, 'mail-4');
  assert.equal(r.stop.ecran, 'Réception');
  assert.match(r.stop.detail, /^Demain, .* · Exp : Retour · Exp : Bulletin météo · Exp : Leur plan$/);
  assert.equal(r.queue[0].mail, 'mail-2');
  assert.equal(r.queue[0].nature, 'action');
  // Veille avec seulement de la routine : arrêt « veille » (pas « groupe ») qui ouvre toujours la composition, la
  // routine rangée dedans et lisible en Réception.
  r = C.arrets(hier, { ...base, veille, courrier: [courrier[0], courrier[2]] }, opts());
  assert.equal(r.stop.type, 'veille');
  assert.equal(r.stop.ecran, 'Composition');
  assert.match(r.stop.detail, / · Exp : Bulletin météo · Exp : Leur plan$/);
  assert.deepEqual(r.stop.mails, ['mail-1', 'mail-3']);
  assert.deepEqual(r.queue, []);
  // Routine seule : aucun arrêt. Info seule : un arrêt. Deux infos : un seul arrêt.
  assert.equal(C.arrets(hier, { ...base, courrier: [courrier[0]] }, opts()).stop, null);
  r = C.arrets(hier, { ...base, courrier: [courrier[3], mail('mail-5', 'info', 40, 'Rumeur'), courrier[0]] }, opts());
  assert.equal(r.stop.mail, 'mail-4');
  assert.deepEqual(r.stop.mails, ['mail-4', 'mail-5', 'mail-1']);
  assert.deepEqual(r.queue, []);
  // Fin de phase et mi-saison.
  const fin = { ...base, phases: { champ: { phase: 'semi', champion: null } }, standing: { rank: 2, points: 70, played: 26, size: 14 } };
  r = C.arrets(hier, fin, opts());
  assert.equal(r.stop.type, 'fin_phase');
  assert.equal(r.stop.detail, 'Championnat : fin de phase (phase régulière), nous terminons 2e sur 14 (70 pts, 26 matchs). Suite : demi-finales.');
  r = C.arrets(hier, { ...base, miSaison: { rank: 4, points: 30, played: 13, size: 14, goal: 'Viser les phases finales' } }, opts());
  assert.equal(r.stop.detail, 'Mi-saison : 4e sur 14 (30 pts, 13 matchs). Objectif de la direction : viser les phases finales.');
  // Mi-saison rangée avec un courrier d'info : un seul arrêt, sans libellé en double (« Mi-saison : Mi-saison : », 28/11).
  r = C.arrets(hier, { ...base, courrier: [courrier[3]], miSaison: { rank: 4, points: 30, played: 13, size: 14, goal: null } }, opts());
  assert.equal(r.stop.type, 'groupe');
  assert.match(r.stop.detail, /Mi-saison : 4e sur 14/);
  assert.doesNotMatch(r.stop.detail, /Mi-saison : Mi-saison/);
  // Veille de la 1re journée déjà annoncée par la préparation (« À noter ») : pas en double.
  assert.equal(C.informatifs(hier, { ...base, veille, notes: ['veille:2026-10-09'] }, opts()).length, 0);
  // Prochain arrêt annoncé : mi-saison puis veille ; arrêts informatifs ignorés : le match.
  assert.deepEqual(C.plan({ ...base, today: '2026-10-05', halfDate: '2026-10-06' }), { kind: 'info', date: '2026-10-07', detail: 'mi-saison' });
  assert.deepEqual(C.plan({ ...base, today: '2026-10-08' }), { kind: 'info', date: '2026-10-09', detail: 'veille du match contre Rivaux' });
  assert.deepEqual(C.plan({ ...base, today: '2026-10-05', halfDate: '2026-10-06' }, null, ['info']), { kind: 'match', date: '2026-10-10', opponent: 'Rivaux' });
});

// ------------------------------------------------------------------ carrière Monde jouée à « Continuer »
const sha = text => crypto.createHash('sha256').update(text, 'utf8').digest('hex');
const COMPLETE = process.env.ARRETS_SAISON_COMPLETE === '1';
const jours = (a, b) => Math.round((Date.parse(b) - Date.parse(a)) / 86400000);

// Joue à « Continuer » depuis la carrière `origine` ; rend les arrêts [date, kind, type, detail, jours],
// l'empreinte de l'état au jour `repere` (atteint exactement, avance bornée) et la date finale (`fin` : arrêt).
// Carrière créée une seule fois (étape coûteuse) puis copiée pour chaque parcours.
const ouvrir = dir => M.ouvrir({ dataDir: dir, deferredCommits: true, testVm: true, mandatoryPress: false });
function creer(start) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'rl27-arrets-saison-'));
  const jeu = ouvrir(dir);
  try { jeu.regler(jeu.call('new_career', { mode: 'world-champ', club: 102, start })); jeu.call('save'); } finally { jeu.bridge.close(); }
  return dir;
}
function parcours(origine, { ignorer = [], repere = null, fin = null } = {}) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'rl27-arrets-saison-'));
  fs.cpSync(origine, dir, { recursive: true });
  fs.rmSync(path.join(dir, 'PrototypeGodot', 'profil.lock'), { force: true });
  const jeu = ouvrir(dir);
  const arrets = [];
  let empreinte = null;
  try {
    let m = jeu.regler(jeu.call('snapshot'));
    for (const decision of m.clubLife?.reprise?.due || []) m = jeu.call('reprise_decide', { decision, option: 'equilibre' });
    for (let i = 0; i < 900; i++) {
      m = jeu.regler(m);
      if (repere && !empreinte && m.meta.calendarToday === repere)
        empreinte = { etat: sha(jeu.bridge.vm.run('JSON.stringify(S)')), graine: jeu.bridge.vm.seed() };
      if (fin && m.meta.calendarToday >= fin) break;
      if (m.meta.calendarCadence?.matchReady && m.next) { m = M.jouerLeMatch(jeu, m); continue; }
      if (m.live) { m = jeu.regler(skipMatchTalk(jeu.call('finish_round'), jeu.call)); continue; }
      const borne = repere && !empreinte && m.meta.calendarToday < repere ? { maxDays: Math.min(C.MAX_DAYS, jours(m.meta.calendarToday, repere)) } : {};
      const r = jeu.brut('advance_until_event', { fromDate: m.meta.calendarToday, ...borne, stops: { messages: 'aucun', ignorer } });
      if (!r.ok) {
        if (jeu.bridge.vm.run('S.phase') === 'ended') break;
        assert.fail('Continuer refusé le ' + m.meta.calendarToday + ' : ' + r.error);
      }
      m = r.model;
      const a = m.meta.advanceUntilEvent;
      if (a.stop.kind !== 'limite') arrets.push([m.meta.calendarToday, a.stop.kind, a.stop.type || null, a.stop.detail, a.days, a.stop.nature || null]);
      if (a.stop.kind === 'blocage') {
        if (/terminée/.test(a.stop.detail || '')) break;
        assert.fail('blocage : ' + JSON.stringify(a.stop));
      }
      // Scène d'entretien ouverte : refermée sans réponse, comme un joueur qui la remet à plus tard.
      const scene = jeu.bridge.vm.run('S.sceneInvitations?.activeId||null');
      if (scene) m = jeu.call('scene_invitation_close', { id: scene, dismiss: true });
    }
    return { arrets, empreinte, date: m.meta.calendarToday };
  } finally { jeu.fermer(); fs.rmSync(dir, { recursive: true, force: true }); }
}

function bilan(arrets) {
  const infos = arrets.filter(x => x[1] === 'info'), types = {}, parMois = {}, parJour = {};
  for (const x of infos) { types[x[2]] = (types[x[2]] || 0) + 1; parMois[x[0].slice(0, 7)] = (parMois[x[0].slice(0, 7)] || 0) + 1; }
  for (const x of arrets) parJour[x[0]] = (parJour[x[0]] || 0) + 1;
  const multiples = Object.entries(parJour).filter(([, n]) => n > 1);
  console.log(arrets.length, 'arrêts dont', infos.length, 'informatifs · par type', JSON.stringify(types), '· par mois', JSON.stringify(parMois));
  console.log('Jours à plusieurs arrêts :', JSON.stringify(multiples));
  for (const x of infos.slice(0, 10)) console.log('  ', x[0], x[2], '·', x[3]);
  // Un seul arrêt d'info par jour (hors courriers à réponse, qui ont chacun le leur).
  const infoParJour = {};
  for (const x of infos.filter(x => !(x[2] === 'courrier' && x[5] === 'action'))) infoParJour[x[0]] = (infoParJour[x[0]] || 0) + 1;
  for (const [d, n] of Object.entries(infoParJour)) assert.equal(n, 1, d + ' : ' + n + ' arrêts d\'info');
  assert.ok(multiples.length > 0, 'au moins un jour à plusieurs arrêts');
  assert.ok(arrets.some(x => x[4] === 0 && x[1] === 'info'), 'arrêt du même jour sans avancer');
  return { infos, types, parMois };
}

// Fenêtre courte (CI de PR) : départ « veille » (préparation confiée au staff, 1re journée le 19/09), deux
// semaines de saison : veilles, lendemains et un jour à deux arrêts (01/10). Le rapport médical, la mi-saison et
// la fin de phase sont vérifiés par la saison complète. Comparaison sans arrêts informatifs au 21/09 (après le
// premier lendemain de match).
const FIN_COURTE = '2026-10-02', REPERE_COURT = '2026-09-21';
test('Fenêtre de saison : veille, lendemain, plusieurs arrêts le même jour, monde inchangé', { skip: COMPLETE, timeout: 600000 }, () => {
  const t0 = Date.now(), origine = creer('veille');
  try {
  const avec = parcours(origine, { repere: REPERE_COURT, fin: FIN_COURTE });
  console.log('Fenêtre', avec.date, '·', Math.round((Date.now() - t0) / 1000), 's');
  const { types } = bilan(avec.arrets);
  assert.ok(types.veille >= 2 && types.lendemain >= 2, 'veilles et lendemains : ' + JSON.stringify(types));
  const sans = parcours(origine, { ignorer: ['info'], repere: REPERE_COURT, fin: REPERE_COURT });
  assert.ok(avec.empreinte && sans.empreinte, 'repère atteint dans les deux parcours');
  assert.equal(sans.empreinte.etat, avec.empreinte.etat, 'état de carrière identique avec ou sans arrêts informatifs');
  assert.equal(sans.empreinte.graine, avec.empreinte.graine, 'graine identique');
  assert.ok(!sans.arrets.some(x => x[1] === 'info'));
  console.log('Durée totale', Math.round((Date.now() - t0) / 1000), 's');
  } finally { fs.rmSync(origine, { recursive: true, force: true }); }
});

// Saison complète (créneau lourd régulier sur main) : répartition sur l'année, mi-saison, fin de phase.
test('Saison complète : arrêts informatifs répartis, monde inchangé au 15/12', { skip: !COMPLETE, timeout: 3600000 }, () => {
  const REPERE = '2026-12-15', origine = creer('premiers-clubs');
  try {
  const avec = parcours(origine, { repere: REPERE });
  console.log('Saison jusqu’au', avec.date);
  const { types, parMois } = bilan(avec.arrets);
  assert.ok(Object.keys(parMois).length >= 6, 'répartis sur la saison : ' + Object.keys(parMois).join(', '));
  // Mi-saison seule ou rangée dans l'arrêt d'info du jour (« groupe », un seul arrêt d'info par jour, décision de Léo du
  // 18/11/2026) : sonde du 28/11, rangée le 27/12 avec le bulletin médical, le lendemain de match et la presse.
  const miSaisons = avec.arrets.filter(x => x[1] === 'info' && (x[2] === 'mi_saison' || x[2] === 'groupe' && /(^| · )Mi-saison : /.test(x[3] || '')));
  assert.equal(miSaisons.length, 1, 'une mi-saison : ' + JSON.stringify(miSaisons));
  assert.ok(types.fin_phase >= 1, 'au moins une fin de phase');
  // Parcimonie : jamais un arrêt informatif par jour ; au plus 14 par mois (11 mesurés en décembre, le 16/11).
  for (const [k, n] of Object.entries(parMois)) assert.ok(n <= 14, k + ' : ' + n + ' arrêts informatifs');
  const sans = parcours(origine, { ignorer: ['info'], repere: REPERE, fin: REPERE });
  assert.ok(avec.empreinte && sans.empreinte, 'repère atteint dans les deux parcours');
  assert.equal(sans.empreinte.etat, avec.empreinte.etat, 'état de carrière identique avec ou sans arrêts informatifs');
  assert.equal(sans.empreinte.graine, avec.empreinte.graine, 'graine identique');
  } finally { fs.rmSync(origine, { recursive: true, force: true }); }
});
