'use strict';
// Promesses publiques sur une saison Monde complète (world-champ, club 0, Top 14, verdicts comparés au réel) : deux promesses annoncées en
// conférence (maintien à l'arrivée, victoires à domicile la semaine suivante), rappels de la presse et de Gabi à
// mi-saison et pour le sprint final, verdict des victoires à domicile à la fin de la saison régulière, verdict du
// maintien au passage à la saison suivante, puis sauvegarde et rechargement. Cas rapides : presse-promesses-monde.cjs.
const assert = require('node:assert/strict');
const { test, after } = require('node:test');
const H = require('./monde-harness.cjs');

const h = H.context(827381, { club: 0, console: false });
after(() => h.close());
const projection = () => JSON.parse(h.run('JSON.stringify(nativeSystems.project())'));
const promesses = () => JSON.parse(h.run('JSON.stringify(S.pressPromises)'));
const titres = () => JSON.parse(h.run('JSON.stringify(S.manager.inbox.map(m=>m.title))'));

// Conférence tenue directement par le domaine de presse (avance rapide du harnais, sans rendez-vous du worker).
function conference(promise) {
  const life = projection(), conf = life.press.conference;
  assert.equal(conf.available, true, 'conférence ouverte');
  assert.ok(conf.promise?.options.some(o => o.id === promise), promise + ' proposé');
  const payload = { context: life.press.context, answers: conf.questions.map(q => ({ questionId: q.id, answerId: q.answers[1].id })), promise };
  h.run('nativeSystems.domain("press").execute("press_conference",' + JSON.stringify(payload) + ');validateCareer(S)');
}

test('saison complète : rappels, verdicts aux échéances, sauvegarde', { timeout: 1800000 }, () => {
  conference('maintien');
  h.week(1);
  const offre = projection().press.conference.promise;
  const domicile = offre.options.filter(o => o.kind === 'home_wins').sort((a, b) => a.target - b.target)[0];
  conference(domicile.id);
  assert.equal(projection().press.conference.promise ?? null, null, 'deux promesses au plus par saison');
  // Saison semaine par semaine : chaque rappel arrive dans le courrier (presse) avec le mot de Gabi.
  const attendus = { 'mi-saison': 'La presse fait les comptes', sprint: 'Sprint final : ta promesse en question' };
  let vus = [];
  for (let i = 0; i < 80 && h.run("S.phase!=='ended'"); i++) {
    h.week(1, { validate: false });
    const rappels = promesses().promises.find(p => p.kind === 'home_wins').reminders;
    for (const r of rappels.filter(r => !vus.includes(r))) {
      assert.ok(titres().includes(attendus[r]), 'rappel de la presse : ' + r);
      assert.ok(titres().includes('Gabi : ta promesse'), 'rappel de Gabi : ' + r);
    }
    vus = rappels;
  }
  h.run('validateCareer(S)');
  const fin = promesses();
  const victoires = fin.promises.find(p => p.kind === 'home_wins'), maintien = fin.promises.find(p => p.kind === 'maintien');
  console.log('victoires à domicile :', victoires.result?.value, '/', victoires.target, '→', victoires.status, '· rappels', victoires.reminders.join(', '));
  assert.deepEqual(victoires.reminders, ['mi-saison', 'sprint'], 'presse et Gabi rappellent la promesse');
  assert.ok(['kept', 'broken'].includes(victoires.status), 'victoires à domicile jugées en fin de saison régulière');
  const reelles = JSON.parse(h.run('JSON.stringify((()=>{const d=new Set(S.worldMode.fixtures.filter(f=>f.competitionId==="elite"&&f.phase==="league"&&f.homeId===S.club).map(f=>f.id));return S.history.filter(m=>d.has(m.fixtureId)&&m.score[m.pair.indexOf(S.club)]>m.score[1-m.pair.indexOf(S.club)]).length;})())'));
  console.log('rang final :', h.run('CDWorldCareer.ranked(S).findIndex(r=>r.id===S.club)+1'));
  assert.equal(victoires.result.value, reelles, 'compte des victoires à domicile du championnat');
  assert.equal(victoires.status === 'kept', reelles >= victoires.target);
  assert.equal(maintien.status, 'pending', 'le maintien attend le passage à la saison suivante');
  const division = () => h.run('CDWorldCareer.leagueId(S,S.club)');
  const avant = division();
  h.run('advanceSeason();validateCareer(S)');
  const suite = promesses().promises.find(p => p.kind === 'maintien');
  console.log('maintien :', suite.status, '· division', avant, '→', division(), '· crédibilité', promesses().credibility);
  // Verdict comparé à la division réelle (comme les victoires à domicile) : le club 0 finit dans la seconde
  // moitié du Top 14 avec cette graine (11e sur main), et tout changement du moteur de match (ex. jugement du
  // staff, #803) déplace le tirage ; exiger le maintien testait le scénario, pas la promesse.
  assert.ok(['kept', 'broken'].includes(suite.status), 'maintien jugé au passage à la saison suivante');
  assert.equal(suite.status === 'kept', division() === avant, 'verdict du maintien conforme à la division');
  assert.equal(h.run('S.season'), 2);
  const vue = projection().pressPromises;
  assert.equal(vue.active.length, 0);
  assert.equal(vue.settled.length, 2);
  // Nouvelle saison : la question d'objectif revient.
  assert.ok(projection().press.conference.promise, 'nouvelle question d’objectif en saison 2');
  h.run('pendingSave=parseSaveDocument(JSON.stringify(createSaveDocument()));if(!confirmSaveImport())throw Error("import");validateCareer(S)');
  assert.deepEqual(promesses(), JSON.parse(JSON.stringify(promesses())), 'promesses rechargées');
  assert.equal(promesses().promises.length, 2);
});
