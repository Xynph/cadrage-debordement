'use strict';
// Protocole commotion du rugby d'élite (World Rugby, depuis le 1er juillet 2022 ; native/engine/club-support.cjs) en
// carrière Monde, pour tous les clubs :
//   1. En match : choc à la tête -> évaluation HIA1 hors du terrain avec remplacement temporaire (retour s'il passe le
//      test) ou sortie définitive sur signes évidents ; le joueur évalué ne peut pas revenir par un changement ; le fait
//      apparaît dans le fil du match sans annoncer l'issue ; la sauvegarde du direct reste valide ; même graine, même
//      déroulé.
//   2. Après le match : 12 jours de repos au moins, jour par jour (calendrier journalier) ; le joueur n'est ni sur la
//      feuille du club ni sur celle de l'IA ; antécédents gardés ; aucune perte de satisfaction ; ni rendez-vous médical
//      générique ni courrier « temps de jeu » à cause de ces absences.
//   3. Exception à 7 jours : seulement sans antécédent, hors signes évidents, avis du spécialiste demandé par le courrier
//      du médecin (club du manager) ou d'office (clubs de l'IA).
const assert = require('node:assert/strict');
const { test } = require('node:test');
const M = require('./helpers/carriere-monde.cjs');

const API = "nativeSystems.domain('clubSupport').commotion";
let jeu = null, vm = null;
test.after(() => jeu?.fermer());
const ouvrir = () => {
  if (!jeu) { jeu = M.ouvrir({ testVm: true, mandatoryPress: false }); vm = jeu.bridge.vm; }
  return jeu;
};
const run = source => vm.run(source);
const json = source => JSON.parse(run('JSON.stringify(' + source + ')'));

test('En match : HIA avec remplacement temporaire, sortie définitive, fil du match, sauvegarde valide, déterminisme', { timeout: 600000 }, () => {
  const j = ouvrir();
  let m = M.creer(j, 102);
  m = M.jusquAuMatch(j, m);
  if (!m.selection.valid) m = j.call('auto_lineup');
  // Rencontre du club en direct (carrière réelle, règles du rugby pro) ; points de reprise pour rejouer à l'identique.
  const graine = vm.seed();
  run(`var hiaBase = JSON.stringify(S); beginMatch();`);
  assert.equal(run('S.live.hiaVersion'), undefined, 'version posée à la première minute');
  const deroule = () => run(`(() => {
    const l = S.live, side = l.userSide, api = ${API}, report = {offField: [], blocked: [], valid: 0};
    let forced = 0;
    for (let n = 0; !l.finished && n < 400; n++) {
      l.paused = false; advanceRugby(l);
      // Chocs provoqués sur six minutes (un par équipe et par minute choisie) en plus de ceux du hasard.
      if ([5, 20, 33, 47, 58, 66].includes(l.minute) && !l.finished) for (const s of [side, 1 - side]) {
        const slot = [10, 12, 6, 13, 9, 5][forced % 6], h = api.startHia(l, s, slot, false); if (h) forced++;
      }
      for (const h of l.hia || []) {
        const on = l.sheets[h.side].on.includes(h.id);
        if (h.etat === 'en_cours' || h.etat === 'definitif') { if (on) report.offField.push(h.id + '@' + l.minute); if (legalChange(l, h.side, 0, h.id) || eligibleChanges(l, h.side, h.slot).some(p => p.id === h.id)) report.blocked.push(h.id); }
      }
      if (l.minute % 10 === 0) { validateCareer(S); report.valid++; }
    }
    validateCareer(S);
    return JSON.stringify({report, hia: l.hia, subs: l.subs.filter(x => ['hia', 'hia-retour', 'commotion'].includes(x.reason)), events: l.events.filter(e => /HIA|commotion/.test(e.text)).map(e => ({min: e.min, text: e.text, type: e.type})), finished: l.finished, score: l.score});
  })()`);
  let premier, second;
  try {
    premier = JSON.parse(deroule());
    // Même graine, même carrière : même déroulé.
    run('S = JSON.parse(hiaBase);'); vm.setSeed(graine); run('beginMatch();');
    second = JSON.parse(deroule());
  } finally { run('S = JSON.parse(hiaBase); delete globalThis.hiaBase;'); vm.setSeed(graine); }
  assert.equal(premier.finished, true);
  assert.deepEqual(premier.report.offField, [], 'joueur en évaluation ou sorti : hors du terrain');
  assert.deepEqual(premier.report.blocked, [], 'aucun changement ne le fait revenir');
  assert.ok(premier.report.valid >= 6, 'sauvegarde du direct validée en cours de match');
  const etats = premier.hia.map(h => h.etat);
  assert.ok(premier.hia.length >= 8, premier.hia.length + ' évaluations');
  assert.ok(etats.includes('retour'), 'au moins un retour après HIA : ' + etats.join(','));
  assert.ok(etats.includes('definitif'), 'au moins une sortie définitive : ' + etats.join(','));
  for (const h of premier.hia.filter(x => x.etat === 'retour')) {
    assert.ok(premier.subs.some(x => x.reason === 'hia-retour' && x.in === h.id && x.minute >= h.until), 'retour après les 12 minutes');
  }
  // Fil du match : le choc est annoncé sans son issue, l'issue n'apparaît qu'à la fin de l'évaluation.
  for (const h of premier.hia.filter(x => x.kind === 'hia1')) {
    const debut = premier.events.find(e => e.min === h.minute && e.text.includes('sort pour une évaluation HIA'));
    assert.ok(debut && debut.type === 'sub', 'choc annoncé dans le fil');
    assert.doesNotMatch(debut.text, /revient|ne reviendra pas|passé/, 'issue non annoncée au choc');
    if (h.etat === 'retour' || (h.etat === 'definitif' && h.until <= 80)) assert.ok(premier.events.some(e => e.min >= h.until && /a passé son évaluation HIA|ne reviendra pas/.test(e.text)), 'issue annoncée à la fin de l’évaluation');
  }
  assert.deepEqual(second.hia, premier.hia, 'déterminisme des évaluations');
  assert.deepEqual(second.score, premier.score, 'déterminisme du score');
});

test('Après le match : diagnostic, 12 jours jour par jour, feuilles du club et de l’IA, antécédents, satisfaction', { timeout: 600000 }, () => {
  const j = ouvrir();
  let m = j.regler(j.call('auto_lineup'));
  const today = m.meta.calendarToday;
  // Commotion confirmée (signes évidents) d'un titulaire du club la veille, et d'un cadre d'un club de l'IA.
  const info = json(`(() => {
    const api = ${API}, own = S.clubs[S.club], p = own.players.find(x => x.id === S.lineup[10]);
    const f = CDWorldCareer.userFixture(S), ai = f.homeId === S.club ? f.awayId : f.homeId;
    const q = buildSheet(S.clubs[ai]).lineup.map(id => S.clubs[ai].players.find(x => x.id === id))[9];
    p.satisfaction = p.satisfaction || {version: 1, score: 65, season: S.season, baseline: p.dev?.minutes || 0, promise: null, history: []};
    const veille = api.shiftDate(CDWorldCareer.calendarToday(S), -1);
    api.diagnose(S, S.club, p, veille, 1, 'test-club');
    api.diagnose(S, ai, q, veille, 1, 'test-ia');
    return {id: p.id, ai, aiPlayer: q.id, veille, satisfaction: p.satisfaction.score, retour: p.commotion.protocole.retour, retourIa: q.commotion.protocole.retour};
  })()`);
  assert.equal(info.retour, run(`${API}.shiftDate(${JSON.stringify(info.veille)}, 12)`), '12 jours de repos');
  assert.equal(info.retourIa, info.retour, 'même règle pour l’IA');
  assert.ok(run(`buildSheet(S.clubs[${info.ai}]).lineup.concat(buildSheet(S.clubs[${info.ai}]).bench).every(id => id !== ${JSON.stringify(info.aiPlayer)})`), 'l’IA ne l’aligne pas');
  // Rencontre de l'IA jouée en résultat rapide : le joueur en protocole ne joue pas.
  const minutesIa = run(`(() => { const q = S.clubs[${info.ai}].players.find(x => x.id === ${JSON.stringify(info.aiPlayer)}), before = q.dev?.minutes || 0;
    const copy = JSON.parse(JSON.stringify(S)), real = S; S = copy; try { const f = CDWorldCareer.fixtures(S).find(x => x.homeId !== S.club && x.awayId !== S.club);
      const c = S.clubs.findIndex(c => c.players.some(x => x.id === ${JSON.stringify(info.aiPlayer)}));
      const g = {...f, homeId: c, awayId: f.homeId === c ? f.awayId : f.homeId, id: 'test-rapide'}; CDLeagueDetail.simulate(S, g);
      return (S.clubs[c].players.find(x => x.id === ${JSON.stringify(info.aiPlayer)}).dev?.minutes || 0) - before; } finally { S = real; } })()`);
  assert.equal(minutesIa, 0, 'résultat rapide : pas de minute pour le joueur en protocole');
  // Jour par jour jusqu'au retour : indisponible avant, disponible le jour du retour ; matchs du club joués entre-temps.
  let jours = 0, matchs = 0, rdvMedical = false;
  const joueur = `S.clubs[S.club].players.find(x => x.id === ${JSON.stringify(info.id)})`;
  for (let i = 0; i < 30; i++) {
    m = j.regler(m);
    const d = m.meta.calendarToday;
    assert.equal(run(`${joueur}.injury > 0`), d < info.retour, d + ' : indisponible jusqu’au ' + info.retour);
    rdvMedical = rdvMedical || run(`(S.clubMeetings?.queue || []).concat(S.clubMeetings?.current || []).some(e => e.kind === 'medical' && e.playerId === ${JSON.stringify(info.id)})`);
    if (d >= info.retour) break;
    if (m.meta.calendarCadence?.matchReady && m.next) {
      const avant = run(`${joueur}.dev?.minutes || 0`);
      m = M.jouerLeMatch(j, m); matchs++;
      assert.equal(run(`${joueur}.dev?.minutes || 0`), avant, d + ' : pas aligné par le club');
      continue;
    }
    m = j.call('advance_day', { fromDate: d }); jours++;
  }
  assert.ok(jours >= 8, jours + ' jours passés');
  assert.equal(run(`${joueur}.injury`), 0, 'disponible le jour du retour');
  assert.equal(rdvMedical, false, 'pas de rendez-vous médical générique : la décision est médicale');
  const apres = json(`(() => { const p = S.clubs[S.club].players.find(x => x.id === ${JSON.stringify(info.id)}); return {injury: p.injury, commotion: p.commotion, satisfaction: p.satisfaction?.score, mails: S.clubMail.mails.filter(x => x.player === ${JSON.stringify(info.id)}).map(x => x.type)}; })()`);
  assert.equal(apres.injury, 0);
  assert.equal(apres.commotion.protocole, null, 'protocole terminé');
  assert.deepEqual(apres.commotion.hist, [{ date: info.veille, retour: info.retour }], 'antécédent gardé (date, nombre)');
  assert.equal(apres.commotion.n, 1);
  assert.ok(apres.satisfaction >= info.satisfaction, 'aucune perte de satisfaction : ' + info.satisfaction + ' -> ' + apres.satisfaction);
  assert.ok(apres.mails.includes('commotion'), 'courrier du médecin : ' + apres.mails.join(','));
  assert.ok(!apres.mails.includes('temps_de_jeu'), 'pas de courrier « temps de jeu » pour une absence médicale');
  // Infirmerie : antécédents visibles.
  const medical = m.clubLife.clubSupport.medical;
  assert.ok(medical.antecedents.some(x => x.id === info.id && x.commotions === 1 && x.derniere === info.veille), 'antécédents à l’infirmerie');
  // Matchs manqués comptés hors du temps de jeu.
  assert.ok(run(`${API}.missedMatches(S, S.clubs[S.club].players.find(x => x.id === ${JSON.stringify(info.id)}), [{date: ${JSON.stringify(run(`${API}.shiftDate(${JSON.stringify(info.veille)}, 5)`))}}])`) === 1);
  run('validateCareer(S)');
});

test('Exception à 7 jours : sans antécédent seulement, avis du spécialiste par le courrier ou d’office pour l’IA', { timeout: 600000 }, () => {
  const j = ouvrir();
  let m = j.regler(M.jusquAuMatch(j, j.regler(j.call('auto_lineup'))));
  if (m.meta.calendarCadence?.matchReady && m.next) m = M.jouerLeMatch(j, m);
  const r = json(`(() => {
    const api = ${API}, today = CDWorldCareer.calendarToday(S), veille = api.shiftDate(today, -1), club = S.clubs[S.club];
    const fresh = club.players.filter(p => !p.commotion && !p.injury);
    // Critère 1 : jamais d'exception.
    const c1 = fresh[0]; api.diagnose(S, S.club, c1, veille, 1, 'x1');
    // Antécédent récent (moins de 3 mois) : jamais d'exception.
    const old = fresh[1]; old.commotion = {version: 1, n: 1, hist: [{date: api.shiftDate(veille, -40), retour: api.shiftDate(veille, -28)}], protocole: null};
    api.diagnose(S, S.club, old, veille, 2, 'x2');
    // Clubs de l'IA, sans antécédent : l'exception s'ouvre selon le HIA3 et l'avis est demandé d'office.
    const ai = S.clubs.findIndex((c, i) => i !== S.club && c.players.length > 20), seen = {};
    let aiCase = null;
    for (const p of S.clubs[ai].players.filter(p => !p.commotion && !p.injury).slice(0, 12)) { api.diagnose(S, ai, p, veille, 3, 'x4'); const e = p.commotion.protocole.exception; seen[e] = (seen[e] || 0) + 1; if (e !== 'non' && !aiCase) aiCase = p.commotion.protocole; }
    // Club du manager, sans antécédent, critère 2, HIA3 revenu à la normale : exception ouverte.
    const open = fresh[2]; api.diagnose(S, S.club, open, veille, 2, 'x3');
    if (open.commotion.protocole.exception === 'non') open.commotion.protocole.exception = 'possible';
    return {c1: c1.commotion.protocole.exception, old: old.commotion.protocole, open: open.id, other: c1.id, seen, aiCase, veille};
  })()`);
  assert.equal(r.c1, 'non', 'signes évidents : 12 jours');
  assert.equal(r.old.exception, 'non', 'antécédent : 12 jours');
  assert.equal(r.old.antecedent, true);
  assert.ok(!r.seen.possible && r.seen.non > 0 && (r.seen.accordee || 0) + (r.seen.refusee || 0) > 0, 'IA : ' + JSON.stringify(r.seen));
  assert.ok(r.aiCase && ['accordee', 'refusee'].includes(r.aiCase.exception), 'IA : avis demandé d’office');
  assert.equal(r.aiCase.jours, r.aiCase.exception === 'accordee' ? 7 : 12);
  // Le courrier du médecin arrive dans les jours qui suivent, avec la demande d'avis ; une seule réponse.
  let mail = null, other = null;
  for (let i = 0; i < 4 && !(mail && other); i++) {
    m = j.regler(m);
    if (m.meta.calendarCadence?.matchReady && m.next) m = M.jouerLeMatch(j, m);
    m = j.regler(j.call('advance_day', { fromDate: m.meta.calendarToday }));
    mail = m.clubLife.clubMail.mails.find(x => x.type === 'commotion_exception' && x.joueur === r.open);
    other = m.clubLife.clubMail.mails.find(x => x.type === 'commotion' && x.joueur === r.other);
  }
  assert.ok(mail, 'courrier « exception à 7 jours »');
  assert.doesNotMatch(mail.sujet + mail.corps, /\{|\}|undefined/);
  const ids = mail.reponses.map(x => x.id);
  assert.deepEqual(ids, ['specialiste', 'remplacant', 'infirmerie']);
  assert.ok(mail.reponses.find(x => x.id === 'specialiste').disponible);
  assert.ok(other && !other.reponses.some(x => x.id === 'specialiste'), 'sans exception : pas de demande d’avis');
  const reply = j.call('club_mail_reply', { id: mail.id, choice: 'specialiste' });
  const prot = json(`S.clubs[S.club].players.find(x => x.id === ${JSON.stringify(r.open)}).commotion.protocole`);
  assert.ok(['accordee', 'refusee'].includes(prot.exception));
  assert.equal(prot.retour, run(`${API}.shiftDate(${JSON.stringify(r.veille)}, ${prot.exception === 'accordee' ? 7 : 12})`));
  assert.match(reply.meta.clubMailReply.resultat, /spécialiste indépendant/);
  assert.match(j.brut('club_mail_reply', { id: mail.id, choice: 'specialiste' }).error, /déjà répondu/);
  // Composition : « Préparer son remplaçant » ouvre l'écran de la feuille.
  { const o = j.call('club_mail_reply', { id: other.id, choice: 'remplacant' }); assert.equal(o.meta.clubMailReply.ecran, 'Composition'); assert.equal(o.meta.clubMailReply.ouvrir, true); }
  // Décision médicale : aucun protocole générique ne s'applique à un joueur en protocole commotion.
  const ctx = j.call('auto_lineup').clubLife.clubSupport.context;
  assert.match(j.brut('medical_protocol', { context: ctx, id: r.open, protocol: 'accelere' }).error || '', /commotion|décision/i);
  run('validateCareer(S)');
});
