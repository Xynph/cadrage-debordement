'use strict';
// Conférence de presse : chaque ton est un compromis lisible (consolidation du 14/11/2026), carrière Monde.
//   1. Balayage de la banque : aucun ton n'est meilleur ou égal sur tous les axes (moral, médias, confiance de la
//      direction, relation) dans plus de ~30 % des questions, quel que soit le style du journaliste et le contexte
//      (neutre, série de défaites, série de victoires, derby).
//   2. Échantillon de vraies conférences (carrière `world-champ`, calendrier de presse façon FM du 18/11/2026 : rentrée
//      la semaine du 1er match, puis après-matchs et conférences d'événement) : même exigence sur les aperçus affichés, puis la
//      délégation à Gabi ne donne jamais de moral ni de confiance de la direction ; à partir de la 3e conférence de
//      suite déléguée, la confiance de la direction baisse ; une conférence en personne remet la série à zéro.
//   3. Compatibilité : archives (identifiants de réponse et textes cités) inchangées par le rééquilibrage.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { test, before, after } = require('node:test');
const M = require('./helpers/carriere-monde.cjs');
const { skipMatchTalk } = require('./helpers/scene-match-talks.cjs');
const C = require('../native/engine/continuer.cjs');
const relations = require('../dist/press-relations.js');
const bank = require('../dist/press-question-bank.js');

const FACULTATIFS = Object.keys(C.STOPS).filter(k => !C.STOPS[k].mandatory);
const TONS = ['confident', 'honest', 'aggressive', 'cautious', 'humour'];
const SEUIL = 0.3;
const axes = e => [e.morale, e.media, -e.pressure, e.relation];

// Un ton « domine » une question s'il est meilleur ou égal à tous les autres tons sur chaque axe.
function dominants(effetsParTon) {
  return TONS.filter(t => TONS.every(u => u === t || axes(effetsParTon[t]).every((v, i) => v >= axes(effetsParTon[u])[i])));
}
function parts(questions) {
  const n = Object.fromEntries(TONS.map(t => [t, 0]));
  for (const effets of questions) for (const t of dominants(effets)) n[t]++;
  return Object.fromEntries(TONS.map(t => [t, n[t] / questions.length]));
}

test('Balayage de la banque : aucun ton dominant, quel que soit le contexte', () => {
  const contextes = { neutre: {}, defaites: { slump: true }, victoires: { run: true }, derby: { derby: true } };
  const styles = Object.keys(relations.dialogueStyles);
  for (const [nom, sit] of Object.entries(contextes)) {
    const echantillon = [];
    for (const q of bank.questions) for (const style of styles) {
      echantillon.push(Object.fromEntries(TONS.map(t => [t, relations.dialogueEffect({ style }, t, q.theme, 0, sit)])));
    }
    const p = parts(echantillon);
    console.log('contexte', nom.padEnd(9), TONS.map(t => t + ' ' + Math.round(p[t] * 100) + ' %').join(' · '));
    for (const t of TONS) assert.ok(p[t] <= SEUIL, `${t} domine ${Math.round(p[t] * 100)} % des questions (${nom})`);
    // Plus strict : aucun ton n'écrase systématiquement un autre (meilleur ou égal sur tous les axes) dans plus de 30 % des cas.
    for (const a of TONS) for (const b of TONS) {
      if (a === b) continue;
      const n = echantillon.filter(e => axes(e[a]).every((v, i) => v >= axes(e[b])[i])).length / echantillon.length;
      assert.ok(n <= SEUIL, `${a} écrase ${b} dans ${Math.round(n * 100)} % des questions (${nom})`);
    }
  }
});

test('Chaque ton a une signature lisible', () => {
  const e = (t, theme, style = 'technique', sit = {}) => relations.dialogueEffect({ style }, t, theme, 0, sit);
  // Affirmé : moral en hausse, relation légèrement en baisse ou nulle.
  assert.ok(e('confident', 'avant_match').morale > e('honest', 'avant_match').morale);
  assert.ok(e('confident', 'avant_match', 'enquete').relation < 0);
  // Honnête : relation en hausse, mais le moral et la confiance de la direction baissent quand on admet une faiblesse.
  assert.ok(e('honest', 'defaite').relation > e('cautious', 'defaite').relation);
  assert.ok(e('honest', 'defaite').morale < 0 && e('honest', 'defaite').pressure > 0, 'admettre une faiblesse coûte');
  assert.ok(e('honest', 'avant_match').pressure <= 0, 'sur un sujet léger, la franchise ne coûte rien à la direction');
  assert.ok(e('cautious', 'avant_match').pressure < e('honest', 'avant_match').pressure, 'seul le prudent rassure la direction');
  // Agressif : moral ++, presse --, pression du conseil.
  for (const t of ['confident', 'honest', 'cautious', 'humour']) assert.ok(e('aggressive', 'avant_match').morale > e(t, 'avant_match').morale);
  assert.ok(e('aggressive', 'avant_match').media <= -3 && e('aggressive', 'avant_match').pressure >= 3);
  // Prudent : neutre, petit gain de confiance, presse légèrement en baisse.
  assert.equal(e('cautious', 'avant_match').morale, 0);
  assert.ok(e('cautious', 'avant_match').pressure < 0 && e('cautious', 'avant_match').media < 0);
  // Humour : relation en hausse avec certains styles, en baisse avec d'autres ; moral +.
  assert.ok(e('humour', 'avant_match', 'interview').relation > 0 && e('humour', 'avant_match', 'enquete').relation < 0);
  assert.ok(e('humour', 'avant_match').morale > 0);
  // Contexte : en série de défaites, l'affirmé sonne creux et l'agressif défend le groupe ; en derby, il passe mieux.
  assert.ok(e('confident', 'avant_match', 'technique', { slump: true }).morale < e('confident', 'avant_match').morale);
  assert.ok(e('aggressive', 'avant_match', 'technique', { slump: true }).morale > e('aggressive', 'avant_match').morale);
  assert.ok(e('aggressive', 'avant_match', 'technique', { derby: true }).media > e('aggressive', 'avant_match').media);
  for (const t of TONS) for (const th of ['avant_match', 'crise']) {
    const fx = relations.dialogueEffect({ style: 'editorial' }, t, th, 100, { slump: true, derby: true });
    assert.ok(Object.values(fx).every(n => Number.isInteger(n) && Math.abs(n) <= 6), 'bornes ±6');
  }
});

let racine, origine;
before(() => {
  racine = fs.mkdtempSync(path.join(os.tmpdir(), 'rl27-presse-dilemmes-'));
  origine = path.join(racine, 'origine');
  const jeu = M.ouvrir({ dataDir: origine });
  try {
    // Club 0 (le plus fort effectif du Monde) : l'échantillon de conférences d'après-match n'est pas noyé par une série de
    // défaites (3 revers de suite = « crise », grand moment obligatoire en personne, jamais délégable).
    jeu.call('new_career', { mode: 'world-champ', club: 0, start: 'premiers-clubs' });
    jeu.call('save');
  } finally { jeu.bridge.close(); }
});
after(() => { if (racine) fs.rmSync(racine, { recursive: true, force: true }); });

const conferenceOuverte = model => model.clubLife?.press?.conference?.available === true;
// Avance (décisions de reprise et rendez-vous hors presse réglés) jusqu'à la conférence d'arrivée : lundi de la semaine du 1er match.
function jusquALArrivee(jeu, model, garde = 40) {
  for (let i = 0; i < garde; i++) {
    model = jeu.reglerSaufPresse(model);
    if (conferenceOuverte(model)) return model;
    model = jeu.call('advance_until_event', { fromDate: model.meta.calendarToday, stops: { messages: 'aucun', ignorer: FACULTATIFS } });
  }
  assert.fail('la conférence d’arrivée ne s’ouvre pas');
}
// Prochaine conférence ouverte (après-match du match joué, ou conférence d'événement) : on avance jour par jour et on joue
// (match délégué) le jour de la rencontre sans régler l'après-match.
function jusquALaConference(jeu, model, garde = 150) {
  for (let i = 0; i < garde; i++) {
    model = jeu.reglerSaufPresse(model);
    if (conferenceOuverte(model)) return model;
    if (model.meta.calendarCadence?.matchReady && model.next) {
      if (!model.selection.valid) model = jeu.call('auto_lineup');
      model = skipMatchTalk(jeu.call('begin_match'), jeu.call);
      model = skipMatchTalk(jeu.call('delegate'), jeu.call);
      if (model.live) model = skipMatchTalk(jeu.call('finish_round'), jeu.call);
      continue;
    }
    assert.equal(model.meta.calendarCadence?.canAdvance, true, 'journée autorisée (' + model.meta.calendarToday + ')');
    model = jeu.call('advance_day', { fromDate: model.meta.calendarToday });
  }
  assert.fail('aucune conférence ouverte');
}
const apercu = conf => conf.questions.map(q => Object.fromEntries(q.answers.map(a => [a.tone, a.effects])));

test('Échantillon de conférences : aucun ton dominant, délégation sans gain, malus de la série', { timeout: 3000000 }, () => {
  const dir = path.join(racine, 'jeu');
  fs.cpSync(origine, dir, { recursive: true });
  fs.rmSync(path.join(dir, 'PrototypeGodot', 'profil.lock'), { force: true });
  const jeu = M.ouvrir({ dataDir: dir, deferredCommits: true, testVm: true });
  try {
    let model = jeu.call('snapshot');
    const echantillon = [];
    // Arrivée (grand moment) : atteinte en avançant jusqu'à la semaine du 1er match, en personne, ton honnête partout.
    model = jusquALArrivee(jeu, model);
    let conf = model.clubLife.press.conference;
    assert.equal(conf.moment?.kind, 'arrivee');
    echantillon.push(...apercu(conf));
    for (const q of conf.questions) for (const a of q.answers) assert.ok(a.effects && Number.isFinite(a.effects.relation));
    model = jeu.call('press_conference', { context: model.clubLife.press.context, invitationId: conf.invitationId,
      answers: conf.questions.map(q => ({ questionId: q.id, answerId: q.answers.find(a => a.tone === 'honest').id })) });
    assert.equal(model.clubLife.press.history.filter(h => h.delegated).length, 0);
    // Conférences ordinaires (après-matchs, recrues, rumeurs) déléguées de suite jusqu'à ce que la série coûte, puis une en
    // personne (la série repart de zéro), puis une déléguée. Les grands moments (affiche, crise) se tiennent en personne.
    const resultats = [];
    let enPersonneFaite = false, apresPersonne = false;
    for (let n = 0; n < 24 && !apresPersonne; n++) {
      model = jeu.regler(model);
      model = jusquALaConference(jeu, model);
      const press = model.clubLife.press;
      conf = press.conference;
      const enPersonne = !!conf.moment || (!enPersonneFaite && resultats.some(r => r.delegue && r.malus >= 1));
      if (enPersonne) { // grand moment, ou conférence ordinaire en personne : remet la série à zéro
        echantillon.push(...apercu(conf));
        model = jeu.call('press_conference', { context: press.context, invitationId: conf.invitationId,
          answers: conf.questions.map(q => ({ questionId: q.id, answerId: q.answers.find(a => a.tone === (conf.moment ? 'cautious' : 'honest')).id })) });
        resultats.push({ n, enPersonne: true, moment: !!conf.moment });
        if (!conf.moment) enPersonneFaite = true;
      } else {
        echantillon.push(...apercu(conf));
        const avant = press.metrics;
        assert.equal(conf.delegation.allowed, true);
        const serie = conf.delegation.streak;
        if (enPersonneFaite) assert.equal(serie, 0, 'la conférence en personne remet la série à zéro');
        model = jeu.call('press_delegate', { context: press.context, invitationId: conf.invitationId });
        const issue = model.clubLife.press.lastOutcome;
        assert.equal(issue.delegated, true);
        // Coût fixe et annoncé (18/11/2026) : médias −2, relation −1 par journaliste, rien d'autre.
        assert.equal(issue.delta.morale, 0, `Gabi ne change pas le moral (${issue.delta.morale})`);
        assert.equal(issue.delta.fanTrust, 0, `Gabi ne change pas l'opinion des supporters (${issue.delta.fanTrust})`);
        assert.equal(issue.delta.mediaTrust, Math.max(-2, -avant.mediaTrust), 'coût médias exactement −2');
        for (const e of issue.exchanges) assert.equal(e.delta, e.before > -100 ? -1 : 0, 'relation −1 par journaliste');
        const malus = serie >= 3 ? 2 : serie === 2 ? 1 : 0;
        assert.equal(issue.delta.trust, malus ? -malus : 0, `confiance de la direction : ${-malus} (série précédente ${serie})`);
        assert.equal(model.clubLife.press.metrics.boardPressure, Math.min(100, avant.boardPressure + malus), 'pression du conseil : seul le malus de série');
        resultats.push({ n, delegue: true, serie, malus });
        if (enPersonneFaite) apresPersonne = true;
      }
      if (model.clubLife?.clubMeetings?.scene?.completed) model = jeu.call('club_meeting_continue', { meetingId: model.clubLife.clubMeetings.scene.id });
    }
    assert.ok(apresPersonne, 'série déléguée, conférence en personne, puis délégation : ' + JSON.stringify(resultats));
    console.log('séries de délégations :', JSON.stringify(resultats.map(r => r.delegue ? 'D' + r.serie + (r.malus ? '(−' + r.malus + ')' : '') : 'P')));
    const gabi = resultats.filter(r => r.delegue);
    assert.ok(gabi.some(r => r.malus >= 1), 'la série déléguée finit par coûter');
    assert.ok(gabi.filter(r => r.serie < 2).every(r => r.malus === 0), 'pas de malus avant la 3e');
    // Échantillon réel : aucun ton dominant.
    const p = parts(echantillon);
    console.log('échantillon de', echantillon.length, 'questions :', TONS.map(t => t + ' ' + Math.round(p[t] * 100) + ' %').join(' · '));
    assert.ok(echantillon.length >= 12);
    for (const t of TONS) assert.ok(p[t] <= SEUIL, `${t} domine ${Math.round(p[t] * 100)} % des questions réelles`);
    // Archives : mêmes identifiants de réponse (r0 à r4) et textes cités, rien d'inventé.
    const exp = jeu.call('export');
    assert.ok(exp.meta.exportText.includes('"pressConference"'));
    assert.ok(model.clubLife.press.history.every(h => ['r0', 'r1', 'r2', 'r3', 'r4'].includes(h.answerId)));
    assert.ok(model.clubLife.press.history.every(h => typeof h.question === 'string' && typeof h.answer === 'string'));
  } finally { jeu.bridge.close(); fs.rmSync(dir, { recursive: true, force: true }); }
});
