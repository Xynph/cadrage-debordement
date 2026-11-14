'use strict';
// Conférence de presse : chaque ton est un compromis lisible (consolidation du 14/11/2026), carrière Monde.
//   1. Balayage de la banque : aucun ton n'est meilleur ou égal sur tous les axes (moral, médias, confiance de la
//      direction, relation) dans plus de ~30 % des questions, quel que soit le style du journaliste et le contexte
//      (neutre, série de défaites, série de victoires, derby).
//   2. Échantillon de vraies conférences (carrière `world-champ`) : même exigence sur les aperçus affichés, puis la
//      délégation à Gabi ne donne jamais de moral ni de confiance de la direction ; à partir de la 3e conférence de
//      suite déléguée, la confiance de la direction baisse ; une conférence en personne remet la série à zéro.
//   3. Compatibilité : archives (identifiants de réponse et textes cités) inchangées par le rééquilibrage.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { test, before, after } = require('node:test');
const M = require('./helpers/carriere-monde.cjs');
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
    jeu.call('new_career', { mode: 'world-champ', club: 102, start: 'premiers-clubs' });
    jeu.call('save');
  } finally { jeu.bridge.close(); }
});
after(() => { if (racine) fs.rmSync(racine, { recursive: true, force: true }); });

const conferenceOuverte = model => model.clubLife?.press?.conference?.available === true;
function jusquALaConference(jeu, model, garde = 30) {
  for (let i = 0; i < garde; i++) {
    if (conferenceOuverte(model)) return model;
    if (model.clubLife?.clubMeetings?.scene) model = jeu.regler(model);
    if (conferenceOuverte(model)) return model;
    model = jeu.call('advance_until_event', { fromDate: model.meta.calendarToday, stops: { messages: 'aucun', ignorer: FACULTATIFS } });
    if (model.meta.advanceUntilEvent?.stop?.kind === 'match') model = M.jouerLeMatch(jeu, model);
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
    // Arrivée (grand moment) : en personne, ton honnête partout.
    let conf = model.clubLife.press.conference;
    assert.equal(conf.moment?.kind, 'arrivee');
    echantillon.push(...apercu(conf));
    for (const q of conf.questions) for (const a of q.answers) assert.ok(a.effects && Number.isFinite(a.effects.relation));
    model = jeu.call('press_conference', { context: model.clubLife.press.context, invitationId: conf.invitationId,
      answers: conf.questions.map(q => ({ questionId: q.id, answerId: q.answers.find(a => a.tone === 'honest').id })) });
    assert.equal(model.clubLife.press.history.filter(h => h.delegated).length, 0);
    // Quatre conférences ordinaires déléguées de suite, puis une en personne, puis une déléguée.
    const resultats = [];
    for (let n = 1; n <= 6; n++) {
      model = jeu.regler(model);
      model = jusquALaConference(jeu, model);
      const press = model.clubLife.press;
      conf = press.conference;
      if (conf.moment) { // grand moment éventuel : en personne (remet la série à zéro comme une conférence ordinaire)
        model = jeu.call('press_conference', { context: press.context, invitationId: conf.invitationId,
          answers: conf.questions.map(q => ({ questionId: q.id, answerId: q.answers.find(a => a.tone === 'cautious').id })) });
        resultats.push({ n, enPersonne: true, moment: true });
        n--; continue;
      }
      echantillon.push(...apercu(conf));
      const avant = press.metrics;
      const attendu = resultats.filter(r => r.delegue).length;
      const enPersonne = n === 5;
      if (enPersonne) {
        model = jeu.call('press_conference', { context: press.context, invitationId: conf.invitationId,
          answers: conf.questions.map(q => ({ questionId: q.id, answerId: q.answers.find(a => a.tone === 'honest').id })) });
        resultats.push({ n, enPersonne: true });
      } else {
        assert.equal(conf.delegation.allowed, true);
        const serie = conf.delegation.streak;
        model = jeu.call('press_delegate', { context: press.context, invitationId: conf.invitationId });
        const issue = model.clubLife.press.lastOutcome;
        assert.equal(issue.delegated, true);
        assert.ok(issue.delta.morale <= 0, `Gabi ne donne pas de moral (${issue.delta.morale})`);
        const malus = serie >= 3 ? 2 : serie === 2 ? 1 : 0;
        assert.equal(issue.delta.trust, malus ? -malus : 0, `confiance de la direction : ${-malus} (série précédente ${serie})`);
        assert.equal(issue.delta.mediaTrust <= -2 || avant.mediaTrust <= 2, true, 'coût médias conservé');
        assert.ok(model.clubLife.press.metrics.boardPressure >= avant.boardPressure, 'pression du conseil jamais réduite par Gabi');
        resultats.push({ n, delegue: true, serie, malus });
      }
      if (model.clubLife?.clubMeetings?.scene?.completed) model = jeu.call('club_meeting_continue', { meetingId: model.clubLife.clubMeetings.scene.id });
    }
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
