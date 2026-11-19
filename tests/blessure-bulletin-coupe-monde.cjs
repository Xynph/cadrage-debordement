'use strict';
// Bulletin médical après un match de coupe d'Europe (carrière Monde réelle, club du Top 14 ; demande de Léo, 18/11/2026) :
// l'origine (rencontre avec son id, adversaire nommé) est enregistrée sur chaque blessure au moment du match et le bulletin
// nomme le vrai adversaire de la coupe, jamais « l'adversaire » par défaut. Hasard des blessures rendu déterministe :
// pendant le traitement des blessures du match, tout joueur utilisé est blessé (tirage figé par un crochet de test).
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { test } = require('node:test');
const M = require('./helpers/carriere-monde.cjs');

const COUPES = ['champions', 'challenge'];

test('Coupe d’Europe, carrière Monde : le bulletin nomme l’adversaire et l’origine est sur la blessure', { timeout: 900000 }, () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'rl27-blessure-coupe-'));
  const jeu = M.ouvrir({ dataDir: dir, deferredCommits: true, testVm: true, mandatoryPress: false, journal: true, savePolicy: 'semaine' });
  try {
    let model = jeu.regler(jeu.call('new_career', { mode: 'world-champ', club: 0, start: 'veille' }));
    const vm = jeu.bridge.vm;
    const prochaine = () => JSON.parse(vm.run(`(()=>{const f=S.worldMode.fixtures.find(f=>f.week===S.round&&(f.homeId===S.club||f.awayId===S.club));
      return JSON.stringify(f?{id:f.id,comp:f.competitionId||f.competition||String(f.id).split(':')[0],date:f.date,home:f.homeId,away:f.awayId,opp:f.homeId===S.club?f.awayId:f.homeId,
      oppName:S.clubs[f.homeId===S.club?f.awayId:f.homeId]?.name||null,domicile:f.homeId===S.club}:null)})()`));
    let fixture = null;
    for (let k = 0; k < 20; k++) {
      model = M.jusquAuMatch(jeu, model);
      fixture = prochaine();
      assert.ok(fixture, 'rencontre du club au calendrier');
      if (COUPES.includes(fixture.comp)) break;
      model = M.jouerLeMatch(jeu, model);
      model = M.jusquALaSemaineSuivante(jeu, model);
      fixture = null;
    }
    assert.ok(fixture, 'un match de coupe d’Europe est atteint');
    assert.ok(fixture.oppName, 'adversaire de coupe nommé dans la base : ' + JSON.stringify(fixture));
    // Blessures du match rendues déterministes : la vraie fonction (applyMatchInjuries) tourne ; seul le hasard est figé
    // pendant son appel (tout joueur utilisé est blessé), puis on ne garde que trois blessés du club pour que la
    // carrière reste jouable. Elle s'exécute à la clôture de la semaine.
    vm.run(`(()=>{const o=applyMatchInjuries;applyMatchInjuries=Object.assign(function(){
      const avant=new Set(S.clubs[S.club].players.filter(p=>p.injury>0).map(p=>p.id));
      const r=Math.random;Math.random=()=>0;let res;try{res=o.apply(this,arguments)}finally{Math.random=r}
      const own=S.clubs[S.club].players.filter(p=>p.injury>0&&!avant.has(p.id));
      for(const p of own.slice(3)){p.injury=0;delete p.injuryOrigin}
      for(const p of S.clubs[S.club].players.filter(p=>p.injury>0&&!avant.has(p.id)&&!p.injuryOrigin))p.injury=0
      return res},o)})()`);
    model = M.jouerLeMatch(jeu, model);
    // La clôture de la semaine (blessures du match) a lieu à la première journée suivante.
    model = jeu.regler(model);
    model = jeu.call('advance_day', { fromDate: model.meta.calendarToday });
    model = jeu.regler(model);
    const blesses = JSON.parse(vm.run(`JSON.stringify(S.clubs[S.club].players.filter(p=>p.injury>0&&p.injuryOrigin&&p.injuryOrigin.type==='match').map(p=>({id:p.id,origin:p.injuryOrigin||null})))`));
    assert.equal(blesses.length, 3, 'trois blessés conservés après le match');
    for (const b of blesses) {
      assert.ok(b.origin, b.id + ' : origine enregistrée à la blessure');
      assert.equal(b.origin.type, 'match');
      assert.equal(b.origin.fixtureId, fixture.id, 'id de la rencontre de coupe');
      assert.equal(b.origin.opp, fixture.opp);
      assert.equal(b.origin.oppName, fixture.oppName);
      assert.equal(b.origin.home, fixture.domicile);
      assert.equal(b.origin.neutral, false);
    }
    // Le bulletin du médecin arrive dans les jours qui suivent : il nomme l'adversaire de la coupe.
    for (let j = 0; j < 3; j++) { assert.equal(model.meta.calendarCadence?.canAdvance, true, 'journée autorisée'); model = jeu.regler(jeu.call('advance_day', { fromDate: model.meta.calendarToday })); }
    const causes = JSON.parse(vm.run(`JSON.stringify(S.clubMail.mails.filter(m=>m.type==='blessure'&&m.date>='${fixture.date}').map(m=>m.vars.cause))`));
    assert.ok(causes.length >= 1, 'au moins un bulletin médical après le match de coupe');
    for (const cause of causes) {
      assert.ok(cause.includes(fixture.oppName), 'bulletin : adversaire de coupe nommé (' + cause + ')');
      assert.doesNotMatch(cause, /l'adversaire/, 'jamais « l’adversaire » par défaut');
      assert.equal(/à domicile contre/.test(cause), fixture.domicile, 'lieu du match');
    }
  } finally {
    jeu.fermer();
  }
});

test('Entraînement, carrière Monde : l’origine est posée à la blessure, le bulletin n’a pas besoin du journal', { timeout: 300000 }, () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'rl27-blessure-entrainement-'));
  const jeu = M.ouvrir({ dataDir: dir, deferredCommits: true, testVm: true, mandatoryPress: false, journal: true, savePolicy: 'semaine' });
  try {
    jeu.regler(jeu.call('new_career', { mode: 'world-champ', club: 0, start: 'veille' }));
    const vm = jeu.bridge.vm;
    // Séance du club en mode intense avec le hasard figé : la vraie semaine d'entraînement blesse (journal compris).
    const blesses = vm.run(`(()=>{const own=S.clubs[S.club].players;own.forEach(p=>{p.injury=0});S.trained=false;
      const m=physicalModeFor,r=Math.random;physicalModeFor=()=>'intense';Math.random=()=>0;
      try{trainWeek()}finally{physicalModeFor=m;Math.random=r}
      return JSON.stringify(own.filter(p=>p.injury>0).map(p=>({id:p.id,origin:p.injuryOrigin&&p.injuryOrigin.type})))})()`);
    const liste = JSON.parse(blesses);
    assert.ok(liste.length >= 5, 'des blessés à l’entraînement');
    assert.ok(liste.every(b => b.origin === 'entrainement'), 'origine « entraînement » enregistrée sur chaque blessure');
    // Journal vidé : l'ancienne lecture ne trouvait plus rien ; le bulletin lit l'origine enregistrée.
    const causes = JSON.parse(vm.run(`(()=>{S.news=[];const d=CDWorldCareer.calendarToday(S),mail=nativeSystems.domain('clubMail'),n=S.clubMail.mails.length;
      mail.blessures.typer(S,d);S.clubMail.last=new Date(Date.parse(d+'T00:00:00Z')-86400000).toISOString().slice(0,10);mail.recevoir(S,d);
      return JSON.stringify(S.clubMail.mails.slice(n).filter(m=>m.type==='blessure').map(m=>m.vars.cause))})()`));
    assert.ok(causes.length >= 1, 'au moins un bulletin médical');
    for (const cause of causes) assert.match(cause, /s'est blessé à l'entraînement, le \d{2}\/\d{2}\./, 'cause connue sans le journal : ' + cause);
  } finally {
    jeu.fermer();
  }
});
