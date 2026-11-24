'use strict';
// Progression par qualité (idée FM27 n° 14, choix de Léo du 23/11/2026) : relevé mensuel des qualités
// (native/engine/releve-qualites.cjs) et progression étalée sur la saison (native/engine/in-season-development.cjs).
// Carrière Monde (world-champ), déterministe.
const test = require('node:test'), assert = require('node:assert/strict');
const { context } = require('./monde-harness.cjs');

const h = context(827381, { club: 102, console: false });
const run = src => h.run(src);
const json = src => JSON.parse(run('JSON.stringify(' + src + ')'));
test.after(() => h.close());

test('carrière neuve : un premier relevé pour chaque joueur, au mois de la création', () => {
  const m = json('S.releveQualites');
  assert.equal(m.m, run('CDWorldCareer.calendarToday(S).slice(0,7)'));
  const r = json(`(()=>{const ps=[...S.clubs.flatMap(c=>c.players),...S.economy.freeAgents];return {n:ps.length,avec:ps.filter(p=>typeof p.rq==='string').length};})()`);
  assert.equal(r.avec, r.n, 'tous les joueurs des clubs et agents libres relevés');
  // Le relevé lu redonne les qualités au dixième et le niveau.
  const p = json(`(()=>{const p=S.clubs[S.club].players[0],l=CDReleveQualites.lire(p.rq);return {l,a:p.attributesV2,r:p.rating};})()`);
  assert.equal(p.l.mois.length, 1);
  assert.equal(p.l.niveau[0], p.r);
  for (const [k, v] of Object.entries(p.a)) assert.equal(p.l.qualites[k][0], Math.round(v * 10) / 10, k);
  run('validateCareer(S)');
});

test('fenêtre de 12 mois glissants, mois manqué vide, valeurs exactes au dixième', () => {
  const r = json(`(()=>{const R=nativeSystems.domain('releveQualites')._tests;
    const p=JSON.parse(JSON.stringify(S.clubs[S.club].players[1]));delete p.rq;
    const attendu=[];let mois='2026-01';
    for(let k=0;k<16;k++){
      if(k===5){mois=R.moisSuivant(mois);attendu.push(null);} // mois sans relevé
      for(const c of Object.keys(p.attributesV2))p.attributesV2[c]=Math.max(20,Math.min(97,Math.round((p.attributesV2[c]+(k%3)*.37-(c==='topSpeed'?1.26:0)+(c==='passing'&&k===7?4.4:0))*100)/100));
      p.rating+=k%4===0?1:0;
      R.relever(p,mois);attendu.push({m:mois,pass:Math.round(p.attributesV2.passing*10)/10,vit:Math.round(p.attributesV2.topSpeed*10)/10,n:p.rating});
      mois=R.moisSuivant(mois);
    }
    return {l:CDReleveQualites.lire(p.rq),attendu,rq:p.rq};})()`);
  assert.equal(r.l.mois.length, 12, '12 mois au plus');
  const fin = r.attendu.slice(-12);
  fin.forEach((a, i) => {
    if (a === null) { assert.equal(r.l.niveau[i], null); return; }
    assert.equal(r.l.mois[i], a.m);
    assert.equal(r.l.qualites.passing[i], a.pass);
    assert.equal(r.l.qualites.topSpeed[i], a.vit);
    assert.equal(r.l.niveau[i], a.n);
  });
  assert.ok(r.rq.length < 400, 'relevé compact : ' + r.rq.length + ' caractères');
});

test('un mois de jeu ajoute un relevé ; ancienne sauvegarde : courbe qui commence au chargement', () => {
  const debut = run('S.releveQualites.m');
  for (let i = 0; i < 6 && run('S.releveQualites.m') === debut; i++) h.week(1);
  assert.notEqual(run('S.releveQualites.m'), debut, 'nouveau mois relevé');
  assert.equal(json('CDReleveQualites.lire(S.clubs[S.club].players[0].rq).mois.length'), 2);
  // Ancienne sauvegarde : ni relevé ni marque ; le premier relevé est pris à la première commande de jeu après le
  // chargement (une lecture seule, « snapshot », n'écrit rien).
  run('delete S.releveQualites;for(const c of S.clubs)for(const p of c.players)delete p.rq;for(const p of S.economy.freeAgents)delete p.rq;');
  h.command('snapshot');
  assert.equal(run('S.releveQualites'), undefined);
  h.command('auto_lineup');
  run('delete S.clubMeetings');
  assert.equal(json('CDReleveQualites.lire(S.clubs[S.club].players[0].rq).mois.length'), 1);
  assert.equal(run('S.releveQualites.m'), run('CDWorldCareer.calendarToday(S).slice(0,7)'));
  run('validateCareer(S)');
});

test('relevé illisible refusé par la validation', () => {
  assert.throws(() => run('(()=>{const p=S.clubs[S.club].players[0],rq=p.rq;p.rq="2026-13:xx";try{validateCareer(S);}finally{p.rq=rq;}})()'), /Relevé des qualités/);
});

test('progression étalée : le gain de niveau arrive dans les qualités semaine après semaine, même total', () => {
  const r = json(`(()=>{const I=nativeInSeasonDevelopment;
    const p=S.clubs.flatMap(c=>c.players).find(p=>p.age<=21&&p.worldRatingsVersion===1&&p.dev.potential>=p.rating+4&&!p.dev.etale);
    const a0={...p.attributesV2},n0=p.rating,note0=roleNote(p);p.dev.xp=0;
    growPlayer(p,1.4,false); // au moins un point de niveau
    const gain=p.rating-n0,apres={...p.attributesV2},note1=roleNote(p);
    const pas=[];let prec=a0.passing;
    for(let k=0;k<I.SAISON;k++){I.semaine(p);pas.push(Math.round((p.attributesV2.passing-prec)*100)/100);prec=p.attributesV2.passing;}
    return {gain,immobiles:Object.keys(a0).every(k=>apres[k]===a0[k]),note0,note1,pas,
      total:Object.keys(a0).map(k=>Math.round((p.attributesV2[k]-a0[k])*100)/100),attente:p.dev.etale?.n??0,noteFin:roleNote(p)};})()`);
  assert.ok(r.gain >= 1, 'point de niveau gagné');
  assert.ok(r.immobiles, 'aucune qualité ne bondit au moment du gain');
  assert.equal(r.note1, r.note0, 'note au poste inchangée au moment du gain');
  assert.equal(r.attente, 0, 'tout est libéré en fin de saison');
  assert.ok(Math.max(...r.pas) <= .5, 'plus gros pas hebdomadaire : ' + Math.max(...r.pas));
  // Entraînement ciblé (24/11/2026) : même total sur les 36 qualités qu'avant (36 × le gain), porté par les qualités
  // travaillées (séances, poste) ; les autres ne bougent presque pas.
  const somme = r.total.reduce((a, b) => a + b, 0);
  assert.ok(Math.abs(somme - 36 * r.gain) < .4, 'même total qu’avant (36 × ' + r.gain + ') : ' + somme.toFixed(2));
  assert.ok(r.total.filter(t => t < .3 * r.gain).length >= 10, 'qualités non travaillées presque immobiles : ' + r.total.join(','));
  assert.ok(Math.max(...r.total) >= 2 * r.gain, 'qualités travaillées : ' + r.total.join(','));
  assert.ok(r.noteFin >= r.note0 + r.gain - 1, 'note au poste montée à la fin');
});

test('déclin de l’âge étalé : même total qu’à la transition d’avant, sans chute d’un coup', () => {
  const r = json(`(()=>{const I=nativeInSeasonDevelopment;
    const source=S.clubs.flatMap(c=>c.players).find(p=>p.age>=33&&p.worldRatingsVersion===1&&p.gameplayPosition&&p.dev.lastYear!==S.season);
    const p=JSON.parse(JSON.stringify(source)),base=JSON.parse(JSON.stringify(source));
    p.dev.etale={s:S.season,t:0}; // saison prise depuis sa première semaine
    // Avant : tout à la transition (même calcul que LNR_V11_AGE à l'intersaison, sans exposition).
    const aged=LNR_V11_AGE.step({...base,gameplayPosition:base.gameplayPosition||base.pos,potential:Math.min(97,Math.max(base.rating,base.dev.potential))},
      {playerId:base.id,age:base.age,season:S.season,lastSeason:null},{minutes:0,training:0,injuryWeeks:0,load:0});
    const pas=[];let prec=p.attributesV2.topSpeed;
    for(let k=0;k<I.SAISON;k++){I.semaine(p);pas.push(Math.round((prec-p.attributesV2.topSpeed)*100)/100);prec=p.attributesV2.topSpeed;}
    const avantTransition={...p.attributesV2};
    ageDevelopmentPlayer(p,S.season);
    return {pas,ecarts:Object.keys(aged.player.attributesV2).map(k=>Math.round((p.attributesV2[k]-aged.player.attributesV2[k])*100)/100),
      transition:Object.keys(p.attributesV2).map(k=>Math.round((p.attributesV2[k]-avantTransition[k])*100)/100),age:p.age,age0:base.age,etale:p.dev.etale??null};})()`);
  assert.ok(r.pas.some(v => v > 0), 'déclin appliqué au fil des semaines');
  assert.ok(Math.max(...r.pas) <= .1, 'aucune semaine ne fait chuter une qualité de plus de 0,1');
  for (const e of r.ecarts) assert.ok(Math.abs(e) <= .011, 'même total qu’avant : écart ' + e);
  for (const t of r.transition) assert.ok(Math.abs(t) <= .011, 'rien d’autre à la transition : ' + t);
  assert.equal(r.age, r.age0 + 1);
  assert.equal(r.etale, null);
});

test('une saison jouée garde une carrière valide et des sauvegardes relisibles', () => {
  h.week(4);
  run('validateCareer(S)');
  run('pendingSave=parseSaveDocument(JSON.stringify(createSaveDocument()));if(!confirmSaveImport())throw Error("import");validateCareer(S)');
  const n = json(`S.clubs.flatMap(c=>c.players).filter(p=>p.dev?.etale).length`);
  assert.ok(n > 0, 'progressions en attente relues après import');
});
