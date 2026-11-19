'use strict';
// Incidents de match (native/engine/incidents-match.cjs) en carrière Monde :
//   1. Blessures et saignements tirés sans aléa du moteur : même graine, même déroulé ; le blessé ne revient pas, le
//      joueur qui saigne revient au plus tard 15 minutes de jeu après sa sortie ; la durée de la blessure n'est
//      appliquée qu'après le match ; la sauvegarde du direct reste valide ; jamais de choix pour l'équipe de l'IA.
//   2. Pas de choix en match délégué ; un match commencé sans `incidentsVersion` reste tel quel.
//   3. Choix du manager (commande `match_incident_choice`) : autre remplaçant après une blessure (« entrant »), autre
//      joueur sorti pour une couverture de première ligne (« sortant ») ; clé ou joueur invalides refusés ; choix
//      présenté au direct (`live.incidentChoix`) et arrêt-décision du direct en temps forts (`live.direct.arret`).
const assert = require('node:assert/strict');
const { test } = require('node:test');
const M = require('./helpers/carriere-monde.cjs');
const { skipMatchTalk } = require('./helpers/scene-match-talks.cjs');

const API = "nativeSystems.domain('matchIncidents')";
let jeu = null, vm = null, graine = null;
test.after(() => jeu?.fermer());
const run = source => vm.run(source);
const json = source => JSON.parse(run('JSON.stringify(' + source + ')'));
// Carrière Monde au jour du premier match, état d'avant le coup d'envoi mémorisé dans la VM (incidentsBase).
const preparer = () => {
  if (jeu) return jeu;
  jeu = M.ouvrir({ hebdomadaire: true, testVm: true });
  vm = jeu.bridge.vm;
  let m = M.jusquAuMatch(jeu, M.creer(jeu));
  if (m.selection?.errors?.length) m = jeu.call('auto_lineup');
  graine = vm.seed();
  run('globalThis.incidentsBase = JSON.stringify(S);');
  return jeu;
};
const restaurer = () => { run('S = JSON.parse(incidentsBase);'); vm.setSeed(graine); };

test('Blessures et saignements : déterminisme, blessé hors jeu, retour après soins, durée après le match, IA sans choix', { timeout: 600000 }, () => {
  preparer();
  const deroule = () => run(`(() => {
    beginMatch();
    const l = S.live, side = l.userSide, api = ${API}, report = {offField: [], blocked: [], aiChoices: 0, userChoices: [], valid: 0, avantMatch: {}};
    let forced = 0;
    for (let n = 0; !l.finished && n < 400; n++) {
      l.paused = false; advanceRugby(l);
      // Incidents provoqués (une équipe puis l'autre) en plus de ceux du hasard.
      if ([3, 15, 28, 44, 57, 66].includes(l.minute) && !l.finished) for (const s of [side, 1 - side]) {
        const kind = forced % 2 ? 'saignement' : 'blessure', slot = [10, 12, 6, 13, 9, 5][forced % 6];
        if (api.start(l, s, slot, kind)) forced++;
      }
      for (const x of l.incidents || []) {
        const sh = l.sheets[x.side];
        if (x.etat === 'en_cours' || x.etat === 'definitif') {
          if (sh.on.includes(x.id)) report.offField.push(x.id + '@' + l.minute);
          if (legalChange(l, x.side, x.slot, x.id) || sh.on.some((id, slot) => eligibleChanges(l, x.side, slot).some(p => p.id === x.id))) report.blocked.push(x.id);
        }
      }
      if (l.incidentChoix) { if (l.incidentChoix.side !== side) report.aiChoices++; else if (!report.userChoices.includes(l.incidentChoix.cle)) report.userChoices.push(l.incidentChoix.cle); }
      if (l.minute % 10 === 0) { validateCareer(S); report.valid++; }
    }
    // Indisponibilité : rien pendant le match, la durée tirée après le coup de sifflet.
    for (const x of l.incidents.filter(x => x.kind === 'blessure')) report.avantMatch[x.id] = matchPlayer(l, x.side, x.id).injury || 0;
    applyMatchInjuries(l);
    validateCareer(S);
    const apres = Object.fromEntries(l.incidents.filter(x => x.kind === 'blessure').map(x => [x.id, matchPlayer(l, x.side, x.id).injury]));
    return JSON.stringify({report, incidents: l.incidents, apres, choixApres: l.incidentChoix === undefined, forced,
      subs: l.subs.filter(x => ['blessure', 'saignement', 'saignement-retour'].includes(x.reason)), events: l.events.filter(e => /Blessure|Saignement|soigné|saignement/.test(e.text)).map(e => ({min: e.min, text: e.text, type: e.type})), score: l.score});
  })()`);
  let premier, second;
  try {
    premier = JSON.parse(deroule());
    restaurer();
    second = JSON.parse(deroule());
  } finally { restaurer(); }
  assert.ok(premier.forced >= 8, premier.forced + ' incidents provoqués');
  assert.deepEqual(premier.report.offField, [], 'blessé ou joueur en soins : hors du terrain');
  assert.deepEqual(premier.report.blocked, [], 'aucun changement ne le fait revenir');
  assert.equal(premier.report.aiChoices, 0, 'jamais de choix pour l’équipe de l’IA');
  assert.ok(premier.report.userChoices.length >= 3, 'choix proposés au manager : ' + premier.report.userChoices.length);
  assert.ok(premier.report.valid >= 6, 'sauvegarde du direct validée en cours de match');
  assert.equal(premier.choixApres, true, 'choix en attente effacé au coup de sifflet final');
  const blessures = premier.incidents.filter(x => x.kind === 'blessure'), saignements = premier.incidents.filter(x => x.kind === 'saignement');
  assert.ok(blessures.length >= 3 && saignements.length >= 3, blessures.length + ' blessures, ' + saignements.length + ' saignements');
  for (const x of blessures) {
    assert.equal(x.etat, 'definitif');
    assert.ok([1, 2, 3, 4, 6, 8].includes(x.semaines), 'gravité ' + x.semaines);
    assert.ok(premier.report.avantMatch[x.id] < x.semaines || premier.report.avantMatch[x.id] === 0, 'durée non appliquée pendant le match');
    assert.ok(premier.apres[x.id] >= x.semaines, 'durée appliquée après le match : ' + premier.apres[x.id] + ' >= ' + x.semaines);
    assert.ok(premier.events.some(e => e.min === x.minute && e.type === 'sub' && /^.+ · Blessure : /.test(e.text)), 'blessure annoncée dans le fil');
  }
  for (const x of saignements) {
    assert.ok(x.until - x.minute >= 4 && x.until - x.minute <= 15, 'soins de 4 à 15 minutes : ' + (x.until - x.minute));
    assert.ok(['retour', 'apte', 'definitif'].includes(x.etat), 'soins terminés : ' + x.etat);
    if (x.etat === 'retour') {
      const r = premier.subs.find(s => s.reason === 'saignement-retour' && s.in === x.id && s.minute >= x.minute);
      assert.ok(r && r.minute === x.until && r.minute - x.minute <= 15, 'retour dans les 15 minutes');
    }
  }
  assert.ok(saignements.some(x => x.etat === 'retour'), 'au moins un retour après saignement');
  assert.deepEqual(second.incidents, premier.incidents, 'déterminisme des incidents');
  assert.deepEqual(second.score, premier.score, 'déterminisme du score');
});

test('Match délégué : pas de choix ; match commencé sans incidents : inchangé', { timeout: 600000 }, () => {
  preparer();
  try {
    const delegue = json(`(() => {
      beginMatch(); const l = S.live, side = l.userSide, api = ${API}, delegation = nativeSystems.domain('matchDelegation');
      for (let n = 0; n < 3; n++) { l.paused = false; advanceRugby(l); }
      delete l.incidentChoix;
      const slot = [10, 12, 13, 11, 9].find(s => eligibleChanges(l, side, s).length >= 2);
      delegation.setActive(true);
      let x; try { x = api.start(l, side, slot, 'blessure'); } finally { delegation.setActive(false); }
      const pendantDelegation = l.incidentChoix === undefined;
      const ia = api.start(l, 1 - side, slot, 'saignement');
      const iaChoix = l.incidentChoix === undefined;
      // Évaluation HIA dans l'équipe du manager (club-support.cjs) : même question que pour une blessure.
      const hiaSlot = [12, 13, 11, 9, 14].find(s => s !== slot && eligibleChanges(l, side, s).length >= 1);
      const h = nativeSystems.domain('clubSupport').commotion.startHia(l, side, hiaSlot, false), c = l.incidentChoix;
      return {version: l.incidentsVersion, x: !!x, pendantDelegation, ia: !!ia, iaChoix,
        hia: h && c ? {kind: c.kind, type: c.type, sortant: c.sortant === h.id, entrant: c.entrant === h.repl, premier: c.options[0] === h.repl, evenement: c.evenement === l.events.length - 1} : null};
    })()`);
    assert.deepEqual(delegue.hia, { kind: 'hia', type: 'entrant', sortant: true, entrant: true, premier: true, evenement: true }, 'choix proposé après un choc à la tête');
    assert.equal(delegue.version, 1);
    assert.ok(delegue.x && delegue.ia, 'incidents posés');
    assert.equal(delegue.pendantDelegation, true, 'match délégué : le choix du staff reste, sans question');
    assert.equal(delegue.iaChoix, true, 'équipe de l’IA : aucune question');
    restaurer();
    // Match repris d'une version précédente (pas de première minute vue par le protocole) : aucun incident.
    const ancien = json(`(() => {
      beginMatch(); const l = S.live, api = ${API}; l.minute = 5;
      for (let n = 0; !l.finished && n < 400; n++) { l.paused = false; advanceRugby(l); }
      validateCareer(S);
      const started = api.start(l, l.userSide, 10, 'blessure');
      return {version: l.incidentsVersion === undefined, incidents: l.incidents === undefined, choix: l.incidentChoix === undefined, started, raisons: l.subs.filter(x => ['blessure', 'saignement', 'saignement-retour'].includes(x.reason)).length, live: Object.keys(${API}.live(l))};
    })()`);
    assert.deepEqual(ancien, { version: true, incidents: true, choix: true, started: null, raisons: 0, live: [] });
  } finally { restaurer(); }
});

test('Choix du manager : autre remplaçant, autre sortant, refus, présentation au direct et arrêt-décision', { timeout: 600000 }, () => {
  const j = preparer();
  restaurer();
  let m = skipMatchTalk(j.call('begin_match'), j.call);
  for (let i = 0; i < 2; i++) m = j.call('tick', { minute: true, temps_forts: 'dynamique' });
  assert.equal(run('S.live.incidentsVersion'), 1, 'incidents actifs dès la première minute');
  // Blessure provoquée dans l'équipe du manager, à un poste où le banc offre plusieurs remplaçants.
  const pose = json(`(() => { const l = S.live, side = l.userSide; delete l.incidentChoix;
    const slot = [10, 12, 13, 11, 9, 14].find(s => eligibleChanges(l, side, s).length >= 2);
    const x = ${API}.start(l, side, slot, 'blessure'); return {slot, x, choix: l.incidentChoix, subs: l.sheets[side].subs}; })()`);
  assert.ok(pose.x && pose.choix, 'blessure et choix posés');
  assert.equal(pose.choix.type, 'entrant');
  assert.equal(pose.choix.entrant, pose.x.repl);
  assert.ok(pose.choix.options.length >= 2 && pose.choix.options[0] === pose.x.repl);
  // Direct en temps forts : arrêt-décision une fois le fait montré.
  let arret = null;
  for (let i = 0; i < 25 && !arret; i++) {
    m = j.call('tick', { minute: true, temps_forts: 'dynamique' });
    if (m.live.direct?.arret?.cle === pose.choix.cle) arret = m.live.direct.arret;
  }
  assert.ok(arret, 'arrêt-décision de l’incident au direct');
  assert.equal(arret.raison, 'blessure');
  assert.equal(arret.pourNous, false);
  assert.match(arret.texte, /Blessure/);
  assert.equal(typeof arret.horloge, 'string');
  const vue = m.live.incidentChoix;
  assert.ok(vue && vue.cle === pose.choix.cle, 'choix présenté au direct');
  assert.deepEqual(arret.choix, { type: 'entrant', options: vue.options });
  assert.ok(vue.options.every(o => typeof o.id === 'string' && o.nom && typeof o.poste === 'string' && Number.isInteger(o.energie)), 'options présentées');
  assert.deepEqual(vue.options.filter(o => o.actuel).map(o => o.id), [pose.x.repl], 'le choix du staff est marqué');
  assert.ok(m.live.incidents.some(x => x.id === pose.x.id && x.kind === 'blessure' && x.semaines === undefined), 'incidents du direct, durée tue pendant le match');
  // Refus : clé périmée, joueur non proposé (le blessé lui-même).
  assert.match(j.brut('match_incident_choice', { cle: 'incident-autre', id: vue.options[1].id }).error, /périmé/);
  assert.match(j.brut('match_incident_choice', { cle: vue.cle, id: pose.x.id }).error, /ne peut pas/);
  assert.match(j.brut('match_incident_choice', { cle: vue.cle, id: vue.options[1].id, autre: 1 }).error, /invalide/);
  // Choix appliqué : l'entrant du staff retourne sur le banc, sans changement de plus.
  const choisi = vue.options[1].id;
  m = j.call('match_incident_choice', { cle: vue.cle, id: choisi });
  const apres = json(`(() => { const l = S.live, sh = l.sheets[l.userSide], x = l.incidents.find(y => y.id === ${JSON.stringify(pose.x.id)}), rec = l.subs.find(r => r.reason === 'blessure' && r.out === x.id);
    validateCareer(S); return {sur: sh.on[${pose.slot}], banc: sh.bench.includes(${JSON.stringify(pose.x.repl)}), utilise: sh.used.includes(${JSON.stringify(pose.x.repl)}), recIn: rec.in, repl: x.repl, subs: sh.subs, choix: l.incidentChoix === undefined, texte: l.events.filter(e => /Choix du manager/.test(e.text)).map(e => e.text)}; })()`);
  assert.equal(apres.sur, choisi, 'le joueur choisi est entré');
  assert.equal(apres.banc, true, 'l’entrant du staff est sur le banc');
  assert.equal(apres.utilise, false, 'l’entrant du staff n’est pas compté comme utilisé');
  assert.equal(apres.recIn, choisi);
  assert.equal(apres.repl, choisi);
  assert.equal(apres.subs, pose.subs, 'pas de changement de plus');
  assert.equal(apres.choix, true, 'choix effacé');
  assert.equal(apres.texte.length, 1);
  assert.match(apres.texte[0], /Choix du manager : .+ entre à la place de .+\./);
  assert.equal(m.live.incidentChoix, null);
  assert.match(j.brut('match_incident_choice', { cle: vue.cle, id: choisi }).error, /périmé/, 'un seul choix');
  // Couverture de première ligne : carton jaune d'un pilier, le staff fait sortir un joueur ; le manager en choisit un autre.
  const couverture = json(`(() => { const l = S.live, side = l.userSide, sh = l.sheets[side]; delete l.incidentChoix;
    giveMatchCard(l, side, sh.on[0], 'yellow'); prepareFrontRows(l); return {choix: l.incidentChoix || null, held: sh.front.held}; })()`);
  assert.ok(couverture.choix, 'choix du sortant proposé');
  assert.equal(couverture.choix.type, 'sortant');
  assert.equal(couverture.choix.kind, 'premiere-ligne');
  assert.ok(couverture.choix.options.length >= 2 && couverture.choix.options[0] === couverture.choix.sortant);
  const donneur = couverture.choix.sortant, donneurPoste = couverture.held.find(h => h.id === donneur).slot;
  // Commande du direct : la carrière modifiée dans la VM devient l'état de référence (un refus la rétablit).
  m = j.call('pause', { paused: true });
  assert.equal(m.live.incidentChoix.type, 'sortant');
  const autre = m.live.incidentChoix.options.find(o => !o.actuel).id;
  assert.match(j.brut('match_incident_choice', { cle: couverture.choix.cle, id: couverture.choix.entrant }).error, /ne peut pas/);
  j.call('match_incident_choice', { cle: couverture.choix.cle, id: autre });
  const sortie = json(`(() => { const l = S.live, sh = l.sheets[l.userSide]; validateCareer(S);
    return {donneur: sh.on[${donneurPoste}], autreSurBanc: sh.bench.includes(${JSON.stringify(autre)}), autreSurTerrain: sh.on.includes(${JSON.stringify(autre)}), held: sh.front.held.map(h => h.id), rec: l.subs.filter(r => r.reason === 'frontcover').at(-1).out, actifs: activePlayers(l, l.userSide).length}; })()`);
  assert.equal(sortie.donneur, donneur, 'le joueur désigné par le staff reste en jeu');
  assert.equal(sortie.autreSurBanc, true);
  assert.equal(sortie.autreSurTerrain, false);
  assert.ok(sortie.held.includes(autre) && !sortie.held.includes(donneur), 'place gardée pour le retour');
  assert.equal(sortie.rec, autre);
  assert.equal(sortie.actifs, 14, 'effectif toujours réduit');
});
