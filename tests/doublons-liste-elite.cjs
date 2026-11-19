'use strict';
// Doublons et liste élite des Bleus (native/engine/doublons.cjs), carrière Monde (world-champ, club 0 = Top 14).
//   - liste de 33 à l'ouverture, marqueur sur les joueurs ;
//   - règle « 2 repos sur 8 matchs » : calcul, application par les clubs de l'ordinateur, suivi des feuilles ;
//   - alerte de feuille du club du manager ;
//   - courrier « doublon » et ses trois réponses ; courrier de la cellule FFR-LNR et ses trois réponses.
const assert = require('node:assert/strict');
const test = require('node:test');
const { context } = require('./monde-harness.cjs');

let shared = null, base = null;
test.after(() => shared?.close());
function world() {
 if (!shared) {
  shared = context(827381, { selections: true });
  // Premier match du club, puis observation du worker (liste de la saison).
  shared.run(`while (!CDWorldCareer.userFixture(S)) CDWorldCareer.finishWeek();
   nativeSystems.domain('doublons').observe();
   var fixture = CDWorldCareer.userFixture(S);
   var opp = S.clubs[fixture.homeId === S.club ? fixture.awayId : fixture.homeId];`);
  base = shared.checkpoint();
 }
 shared.restore(base);
 shared.run('var fixture = CDWorldCareer.userFixture(S); var D = nativeSystems.domain("doublons");');
 return shared;
}
// Réception du courrier à `jours` avant la rencontre (la première réception n'écrit que la mémoire).
const receive = (h, jours) => h.run(`(()=>{const at=n=>new Date(Date.parse(fixture.date+'T00:00:00Z')-n*86400000).toISOString().slice(0,10),D=nativeSystems.domain('clubMail');
  if(!S.clubMail||S.clubMail.last===null)D.recevoir(S,at(${jours}+1));
  D.recevoir(S,at(${jours}));})()`);
// Convocation de la France sur la date du match du club : les `n` mieux notés du club partent.
const call = (h, n) => h.run(`(()=>{const club=S.clubs[S.club];
  const gone=club.players.filter(p=>!p.injury).sort((a,b)=>b.rating-a.rating||(a.id<b.id?-1:1)).slice(0,${n}).map(p=>p.id);
  S.national.career.callups.push({nation:'FRA',competitionId:'nations-championship-2026',from:fixture.date,through:fixture.date,playerIds:gone});
  return gone;})()`);

test('la liste compte 33 joueurs éligibles à la France et se montre sur leur fiche', () => {
 const h = world();
 assert.equal(h.run('S.doublons.ids.length'), 33);
 assert.equal(h.run('new Set(S.doublons.ids).size'), 33);
 assert.equal(h.run('S.doublons.ids.every(id=>nativeFacts.eligible(id,"FRA"))'), true);
 assert.equal(h.run('S.doublons.ids.every(id=>D.isListed(S,id))'), true);
 assert.equal(h.run('JSON.stringify(nativePlayerAttributes(S.clubs.find(c=>c.players.some(p=>S.doublons.ids.includes(p.id))).players.find(p=>S.doublons.ids.includes(p.id))).playerFacts.listeElite)'), 'true');
 assert.doesNotThrow(() => h.run('validateCareer(S)'));
});

test('fenêtre glissante : au moins 2 repos sur 8 matchs', () => {
 const h = world();
 const must = text => h.run(`(()=>{const id=S.doublons.ids[0];S.doublons.rests[id]=${JSON.stringify(text)};return D.mustRest(S,id,fixture);})()`);
 assert.equal(must(''), false, 'début de saison : rien d’obligatoire');
 assert.equal(must('jjjjj'), false, 'cinq matchs sans repos : encore deux matchs pour deux repos... trois places restent');
 assert.equal(must('jjjjjj'), true, 'six matchs sans repos : deux places, deux repos à faire');
 assert.equal(must('jjjjjjj'), true, 'sept matchs sans repos');
 assert.equal(must('jjrjjjj'), true, 'un seul repos sur sept : le huitième doit en être un');
 assert.equal(must('jjrjjrj'), false, 'deux repos : la règle est tenue');
 assert.equal(must('jnnxjjj'), true, 'sélection et blessure ne sont pas des repos');
 assert.equal(must('rjjjjjjj'), true, 'le repos le plus ancien est sorti de la fenêtre : rien dans les sept derniers');
});

test('les clubs de l’ordinateur laissent hors de la feuille le joueur qui doit souffler', () => {
 const h = world();
 const out = h.run(`(()=>{const c=opp, list=S.doublons.ids;
  // On inscrit un joueur de l'adversaire sur la liste, au repos obligatoire.
  const first=buildSheet(c).lineup.find(Boolean);
  S.doublons.ids[0]=first;S.doublons.rests[first]='jjjjjjj';
  const sheet=buildSheet(c),all=[...sheet.lineup,...sheet.bench];
  const waived=(S.doublons.rests[first]='jrjjrjj',buildSheet(c));
  return {first,absent:!all.includes(first),complete:all.filter(Boolean).length===23,back:[...waived.lineup,...waived.bench].includes(first)};})()`);
 assert.equal(out.absent, true, 'le joueur est reposé');
 assert.equal(out.complete, true, 'feuille complète');
 assert.equal(out.back, true, 'une fois la règle tenue, il rejoue');
});

test('le suivi des feuilles distingue repos, sélection et blessure', () => {
 const h = world();
 const codes = h.run(`(()=>{
  const club=S.clubs[S.club],ids=club.players.slice(0,4).map(p=>p.id);
  S.doublons.ids.splice(0,4,...ids);
  club.players[1].injury=2;
  S.national.career.callups.push({nation:'FRA',competitionId:'x',from:fixture.date,through:fixture.date,playerIds:[ids[2]]});
  const l={injuriesApplied:false,worldContext:fixture,pair:[S.club,S.club===fixture.homeId?fixture.awayId:fixture.homeId],sheets:[{nominated:[ids[0]]},{nominated:[]}]};
  D.record(l);
  return ids.map(id=>S.doublons.rests[id]);})()`);
 assert.deepEqual([...codes], ['j', 'x', 'n', 'r']);
});

test('alerte de feuille : le joueur de la liste qui doit souffler est signalé avec son remplaçant', () => {
 const h = world();
 const info = h.run(`(()=>{const club=S.clubs[S.club],id=S.lineup[2];
  S.doublons.ids[0]=id;S.doublons.rests[id]='jjjjjjj';
  const p=D.project();
  return {applies:p.applies,reposer:p.reposer.map(x=>x.playerId),changes:p.changes.map(c=>[c.sortant,c.playerId]),id,must:p.players.find(x=>x.id===id).mustRest};})()`);
 assert.equal(info.applies, true);
 assert.deepEqual([...info.reposer], [info.id]);
 assert.equal(info.must, true);
 assert.equal(info.changes.length, 1);
 assert.notEqual(info.changes[0][1], info.id);
});

test('courrier doublon : chiffre l’impact et propose trois actions aux effets réels', () => {
 const h = world();
 const gone = JSON.parse(JSON.stringify(call(h, 6)));
 const mail = () => { receive(h, 3); return JSON.parse(h.run(`JSON.stringify(S.clubMail.mails.filter(m=>m.type==='doublon'))`)); };
 const mails = mail();
 assert.equal(mails.length, 1, 'un seul courrier par doublon');
 assert.equal(mails[0].vars.n, 6);
 assert.ok(Number(mails[0].vars.titulaires) >= 1);
 assert.ok(mails[0].vars.postes.length > 0);
 const model = h.command('snapshot');
 const projected = model.clubLife.clubMail.mails.find(m => m.type === 'doublon');
 assert.deepEqual(projected.reponses.map(r => r.id), ['rotation', 'forte', 'jeunes']);
 assert.match(projected.corps, /6 joueurs|6 internationaux|sans 6|prend 6/);
 // Pas de second courrier pour la même rencontre.
 assert.equal(mail().length, 1);

 // Rotation : les cadres fatigués passent en repos, rendus après le match.
 const prep = h.run(`(()=>{for(const p of S.clubs[S.club].players.filter(p=>!${JSON.stringify(gone)}.includes(p.id)).sort((a,b)=>b.rating-a.rating).slice(0,5)){ensurePhysicalLoad(p).fatigue=40;}return true;})()`);
 assert.equal(prep, true);
 const reply = h.command('club_mail_reply', { id: mails[0].id, choice: 'rotation' });
 assert.equal(h.run(`S.clubs[S.club].players.filter(p=>p.physicalLoad?.plan==='repos').length`) >= 1, true);
 assert.equal(h.run('S.doublons.rotation.fixtureId===fixture.id'), true);
 h.run(`S.history.push({fixtureId:fixture.id,pair:[fixture.homeId,fixture.awayId],score:[10,10]});D.observe();`);
 assert.equal(h.run(`S.clubs[S.club].players.filter(p=>p.physicalLoad?.plan==='repos').length`), 0, 'plan rendu après le match');
 assert.ok(reply);
});

test('courrier doublon : « aligner la plus forte » et « lancer des jeunes » changent la feuille', () => {
 for (const choice of ['forte', 'jeunes']) {
  const h = world();
  const gone = JSON.parse(JSON.stringify(call(h, 5)));
  receive(h, 3);
  const id = h.run(`S.clubMail.mails.find(m=>m.type==='doublon').id`);
  if (choice === 'jeunes') h.run(`S.development.academy.forEach(y=>{y.age=Math.max(y.age,19);y.injury=0;});`);
  const before = h.run('JSON.stringify(S.lineup)+JSON.stringify(S.reserves)');
  const youth = h.run('S.development.academy.length');
  const r = h.brut ? null : null;
  let answer;
  try { answer = h.command('club_mail_reply', { id, choice }); } catch (e) { answer = e; }
  if (choice === 'forte') {
   assert.ok(!(answer instanceof Error), String(answer));
   assert.equal(h.run(`[...S.lineup,...S.reserves].filter(Boolean).every(id=>!${JSON.stringify(gone)}.includes(id))`), true, 'aucun absent sur la feuille');
   assert.notEqual(h.run('JSON.stringify(S.lineup)+JSON.stringify(S.reserves)'), before);
  } else if (answer instanceof Error) {
   assert.match(answer.message, /jeune|centre/i, 'refus motivé quand le centre n’a personne');
  } else {
   assert.ok(h.run('S.development.academy.length') < youth, 'un jeune signe');
   assert.equal(h.run(`[...S.lineup,...S.reserves].some(id=>S.clubs[S.club].players.find(p=>p.id===id)?.joinedSeason===S.season&&S.clubs[S.club].players.find(p=>p.id===id)?.academy===false)`), true);
  }
  assert.doesNotThrow(() => h.run('validateCareer(S)'));
  void r;
 }
});

test('courrier de la cellule FFR-LNR : reposer, aménagement (pas garanti) ou ignorer', () => {
 const results = {};
 for (const choice of ['reposer', 'amenagement', 'ignorer']) {
  const h = world();
  const id = h.run(`(()=>{const id=S.lineup[2];S.doublons.ids=[id,...S.doublons.ids.filter(x=>x!==id)].slice(0,33);S.doublons.rests[id]='jjjjjjj';return id;})()`);
  receive(h, 2);
  const mail = h.run(`JSON.parse(JSON.stringify(S.clubMail.mails.find(m=>m.type==='cellule_repos')||null))`);
  assert.ok(mail, 'courrier reçu');
  assert.equal(mail.player, id);
  assert.equal(h.run(`S.clubMail.mails.filter(m=>m.type==='cellule_repos').length`), 1);
  h.command('club_mail_reply', { id: mail.id, choice });
  const after = h.run(`({on:[...S.lineup,...S.reserves].includes(${JSON.stringify(id)}),relation:S.doublons.relation,waived:S.doublons.waivers[${JSON.stringify(id)}]===fixture.id,verdict:S.clubMail.mails.find(m=>m.type==='cellule_repos').verdict})`);
  results[choice] = after;
  assert.doesNotThrow(() => h.run('validateCareer(S)'));
 }
 assert.equal(results.reposer.on, false, 'reposé : sorti de la feuille');
 assert.equal(results.ignorer.relation, 57, 'ignorer coûte de la relation avec la fédération');
 assert.equal(results.ignorer.on, true);
 assert.ok(results.amenagement.verdict.length > 0);
 assert.equal(results.amenagement.waived, /accepte/.test(results.amenagement.verdict), 'accord ou refus, jamais garanti');
});

test('Bleus : la liste ne joue pas plus de 9 des 12 tests de la France', () => {
 const { createInternationalCareer } = require('../native/engine/international-career.cjs');
 const competitions = require('../native/engine/international-competitions.cjs');
 const callups = require('../native/engine/international-callups.cjs');
 const pos = ['Pilier gauche', 'Talonneur', 'Pilier droit', 'Deuxième ligne', 'Deuxième ligne', 'Troisième ligne', 'Troisième ligne', 'Numéro 8', 'Demi de mêlée', 'Demi d’ouverture', 'Ailier', 'Centre', 'Centre', 'Ailier', 'Arrière'];
 const fam = [0, 1, 0, 2, 2, 3, 3, 3, 4, 5, 6, 7, 7, 6, 8];
 // 30 joueurs : les 15 premiers (liste élite) sont les meilleurs.
 const make = listed => Array.from({ length: 30 }, (_, i) => ({ id: 'p' + i, pos: pos[i % 15], fam: fam[i % 15], rating: i < 15 ? 90 : 80, age: 27, listeElite: listed && i < 15 }));
 const facts = { players: Object.fromEntries(make(false).map(p => [p.id, { seniorNation: 'FRA', seniorCaps: 10 }])) };
 const game = createInternationalCareer(competitions, callups, facts);
 const start = game.initial('2026-12-01', 7);
 const opened = game.advance(start, { from: start.date, to: '2027-02-06', players: make(false), clubPlayerIds: [], managedNation: null }).state;
 // Deux joueurs (troisième ligne, ailier) de la liste ont joué 9 des 11 derniers tests ; les huit autres joueurs complètent les feuilles passées.
 const heavy = make(false).filter((p, i) => [5, 10].includes(i)).map(p => p.id), fill = make(false).slice(15, 23).map(p => p.id);
 const rows = games => Array.from({ length: 11 }, (_, i) => ({ fixtureId: 'avant' + i, date: '2026-11-' + String(i + 1).padStart(2, '0'), nation: 'FRA', playedIds: i < games ? heavy.concat(fill) : fill.concat(make(false).slice(0, 5).map(p => p.id)) }));
 const withRows = games => ({ ...opened, appearances: opened.appearances.filter(r => r.nation !== 'FRA').concat(rows(games)) });
 const sheet = (state, listed) => game.project(state, { date: '2027-02-06', players: make(listed), managedNation: 'FRA' }).sheet.lineup;
 assert.ok(sheet(withRows(9), false).some(id => heavy.includes(id)), 'sans le protocole : ils jouent');
 assert.ok(sheet(withRows(9), true).every(id => !heavy.includes(id)), 'protocole : 9 apparitions sur 11 tests, ils soufflent');
 assert.ok(sheet(withRows(8), true).some(id => heavy.includes(id)), 'moins de 9 apparitions : aucun repos imposé');
});
