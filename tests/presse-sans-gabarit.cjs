'use strict';
// Conférences de presse : aucune question ni réponse où l'on voit le modèle (décision de Léo, 18/11/2026).
// Refusé : thème inséré entre guillemets (« Comment « avenir au club » influence-t-il… »), accolades de gabarit,
// tournures-gabarits (« la situation concernant », « sur le sujet », « dans le domaine »…). Balaye toute la banque,
// tous les tirages possibles (saisons, semaines, graines, presse de chaque pays) et une vraie conférence Monde.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const bank = require('../dist/press-question-bank.js');

const GABARITS = [/[«»{}]/, /concernant/i, /\bsur le (sujet|th[eè]me)\b/i, /\b(le|du) (sujet|th[eè]me) [a-zé]/i,
  /dans le domaine/i, /\bautour de (la|le|l’|les) [a-zé]+ ?\?/i, /quel regard portes-tu/i, /assumes-tu personnellement les choix/i];
const propre = (texte, ou) => {
  assert.equal(typeof texte, 'string', ou);
  for (const r of GABARITS) assert.ok(!r.test(texte), ou + ' : tournure-gabarit ' + r + ' dans « ' + texte + ' »');
};

test('Banque : 500 questions écrites une à une, 5 réponses chacune, sans gabarit', () => {
  assert.equal(bank.questions.length, 500);
  const vues = new Set();
  for (const q of bank.questions) {
    assert.equal(q.variants.length, 1, q.id);
    const question = q.variants[0];
    propre(question, q.id);
    assert.ok(question.endsWith('?') && (question.match(/\?/g) || []).length === 1, q.id + ' : une seule question');
    assert.ok(!question.toLowerCase().includes(q.subject.toLowerCase()) || !/[«"]/.test(question), q.id);
    assert.ok(!vues.has(question), 'question en double : ' + question); vues.add(question);
    assert.deepEqual(q.answers.map(a => a.tone), ['confident', 'honest', 'aggressive', 'cautious', 'humour'], q.id);
    assert.equal(new Set(q.answers.map(a => a.text)).size, 5, q.id);
    for (const a of q.answers) {
      propre(a.text, q.id + '/' + a.id);
      const mots = a.text.split(/\s+/).length;
      assert.ok(mots >= 6 && mots <= 34, q.id + '/' + a.id + ' : réponse courte et complète (' + mots + ' mots)');
    }
  }
  // Une réponse n'est jamais partagée entre deux questions : elle répond à la sienne.
  const reponses = bank.questions.flatMap(q => q.answers.map(a => a.text));
  assert.equal(new Set(reponses).size, reponses.length, 'réponses toutes propres à leur question');
});

test('Tirages : toutes les questions générables, dans toutes les presses', () => {
  const regions = Object.keys(bank.regions).filter(r => r !== 'eu');
  let n = 0;
  for (const region of regions) for (let seed = 0; seed < 6; seed++) for (let week = 0; week < 30; week++) {
    for (const q of bank.pick({ season: 1 + seed % 3, week, count: 4, seed, region })) {
      propre(q.question, region + ' ' + q.id); for (const a of q.answers) propre(a.text, region + ' ' + q.id + '/' + a.id); n++;
    }
  }
  assert.ok(n > 4000, 'balayage large : ' + n);
});

test('Vraie conférence en carrière Monde : questions contextuelles comprises', { timeout: 170000 }, () => {
  const Monde = require('./helpers/carriere-monde.cjs');
  const jeu = Monde.ouvrir();
  try {
    let model = jeu.call('new_career', { mode: 'world-champ', club: 0, start: 'premiers-clubs' });
    for (let i = 0; i < 40 && !model.clubLife?.press?.conference?.questions?.length; i++) {
      for (const decision of model?.clubLife?.reprise?.due || []) model = jeu.call('reprise_decide', { decision, option: 'equilibre' });
      const r = jeu.brut('advance_until_event', { fromDate: model.meta.calendarToday });
      if (!r.ok) break;
      model = r.model;
    }
    const questions = model.clubLife?.press?.conference?.questions || [];
    assert.ok(questions.length >= 2, 'une conférence a eu lieu avant le 1er match');
    for (const q of questions) {
      // Seul rappel autorisé entre guillemets : la citation d'une vraie réponse passée du manager.
      const texte = q.question.replace(/tu avais répondu : « [^»]+ »\. /, '');
      propre(texte, 'conférence ' + q.id);
      for (const a of q.answers) propre(a.text, 'conférence ' + q.id + '/' + a.id);
    }
  } finally { jeu.fermer(); }
});
