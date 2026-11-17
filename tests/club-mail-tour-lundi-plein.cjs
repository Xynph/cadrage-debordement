'use strict';
// Courrier du club (native/engine/club-mail.cjs) : « Le tour du championnat » ne disparaît pas quand le lundi est plein.
// Recette native du 17/11/2026 : trois mails par jour au plus ; les lundis réels portaient déjà le bilan du match et deux
// mails plus prioritaires, le tour (permis le seul lundi) était perdu chaque semaine. Il est désormais repoussé au mardi
// ou au mercredi. Le lundi est rempli ici par trois suites prioritaires (la file `suites` passe avant les autres mails).
// Carrière Monde (`world-champ`), départ « veille ».
const assert = require('node:assert/strict');
const { test } = require('node:test');
const M = require('./helpers/carriere-monde.cjs');

const jour = iso => new Date(iso + 'T00:00:00Z').getUTCDay(); // 0 = dimanche
const plus = (iso, n) => new Date(Date.parse(iso + 'T00:00:00Z') + n * 86400000).toISOString().slice(0, 10);

test('Carrière Monde : lundi plein, le tour du championnat arrive quand même dans la semaine', { timeout: 600000 }, () => {
  const jeu = M.ouvrir({ testVm: true, mandatoryPress: false });
  try {
    let m = jeu.regler(jeu.call('new_career', { mode: 'world-champ', club: 102, start: 'veille' }));
    const vm = jeu.bridge.vm;
    // Jusqu'au dimanche qui suit le premier match du club (résultats de la journée connus).
    let joue = false;
    for (let i = 0; i < 160 && !(joue && jour(m.meta.calendarToday) === 0); i++) {
      m = jeu.regler(m);
      if (m.meta.calendarCadence?.matchReady && m.next) { m = M.jouerLeMatch(jeu, m); joue = true; continue; }
      m = jeu.call('advance_day', { fromDate: m.meta.calendarToday });
    }
    assert.ok(joue && jour(m.meta.calendarToday) === 0, 'dimanche après le premier match : ' + m.meta.calendarToday);
    const lundi = plus(m.meta.calendarToday, 1), mercredi = plus(lundi, 2);
    // Trois suites prioritaires dues lundi : elles occupent les trois places du jour.
    vm.run(`(()=>{const st=S.clubMail;for(let i=0;i<3;i++)st.suites.push({date:${JSON.stringify(lundi)},type:'gene',key:'test-lundi-plein-'+i,vars:{}});})()`);
    for (let i = 0; i < 6 && m.meta.calendarToday <= mercredi; i++) {
      m = jeu.regler(m);
      if (m.meta.calendarCadence?.matchReady && m.next) { m = M.jouerLeMatch(jeu, m); continue; }
      m = jeu.call('advance_day', { fromDate: m.meta.calendarToday });
    }
    const mails = m.clubLife.clubMail.mails;
    const duLundi = mails.filter(x => x.date === lundi);
    assert.equal(duLundi.filter(x => x.type === 'gene').length, 3, 'lundi rempli par les trois suites : ' + duLundi.map(x => x.type).join(', '));
    const tours = mails.filter(x => x.type === 'tour_championnats' && x.date >= lundi && x.date <= mercredi);
    assert.equal(tours.length, 1, 'tour du championnat reçu une fois dans la semaine : ' + mails.filter(x => x.date >= lundi).map(x => x.date + ' ' + x.type).join(', '));
    assert.doesNotMatch(tours[0].sujet + tours[0].corps, /\{|\}|undefined|NaN|null/);
  } finally {
    jeu.fermer();
  }
});
