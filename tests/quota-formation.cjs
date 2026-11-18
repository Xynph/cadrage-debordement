'use strict';
// Quotas de joueurs formés localement par championnat (JIFF Top 14 / Pro D2 avec doublon, EQP Premiership),
// carrière Monde (world-champ) : comptage, amende, IA conforme, valorisation au recrutement, alerte de Gabi, courrier.
const test = require('node:test');
const assert = require('node:assert/strict');
const { context } = require('./monde-harness.cjs');

let shared = null;
test.after(() => shared?.close());
function world() {
  if (!shared) {
    shared = context(827381, { selections: true });
    shared.toMatch();
    shared.week(8);
    shared.base = shared.checkpoint();
  }
  shared.restore(shared.base);
  return shared;
}

test('Barème EQP : proportionnel à l’écart, plafonné à 250 000 £ (287 000 € environ)', () => {
  const h = world();
  const r = JSON.parse(h.run('JSON.stringify([15,14.5,14,13,12,5].map(a=>[CDJiff.fineFor(a),CDJiff.fineEuros(CDJiff.fineFor(a))]))'));
  assert.deepEqual(r[0], [0, 0]);
  assert.ok(r[1][0] > 0 && r[1][0] < r[2][0] && r[2][0] < r[3][0], 'croît avec l’écart');
  assert.equal(r[4][0], 250000);
  assert.equal(r[5][0], 250000);
  assert.equal(r[5][1], 287000);
});

test('Premiership : feuilles comptées en EQP, IA conforme (15 de moyenne)', () => {
  const h = world();
  const r = JSON.parse(h.run(`JSON.stringify(S.worldMode.leagues.prem.members.map(ci=>[ci,S.jiff.counts[ci]]))`));
  assert.equal(r.length, 10);
  for (const [ci, row] of r) { assert.ok(row && row[0] >= 4, 'feuilles comptées'); assert.ok(row[1] / row[0] >= 15, 'club ' + ci + ' : ' + row[1] / row[0]); }
  assert.equal(h.run('CDJiff.quota(S,S.worldMode.leagues.prem.members[0]).kind'), 'eqp');
  assert.equal(h.run('CDJiff.quota(S,S.worldMode.leagues.urc.members[0])'), null, 'aucun quota en URC');
  assert.equal(h.run('CDJiff.quota(S,S.worldMode.leagues.champ.members[0])'), null, 'aucun quota en Championship');
});

test('Fin de saison Premiership : amende en euros débitée, jamais de retrait de points ; état valide', () => {
  const h = world();
  const r = JSON.parse(h.run(`(()=>{const ci=S.worldMode.leagues.prem.members[0],c=S.clubs[ci];S.jiff.counts[ci]=[18,18*13];const cash=c.cash;
   const pending=CDJiff.closeSeason(S,S.season);const row=S.jiff.results.find(x=>x.clubId===ci);
   return JSON.stringify({cash:cash-c.cash,row,pending,validate:CDJiff.validate(S)});})()`));
  assert.equal(r.row.league, 'prem');
  assert.equal(r.row.deduction, 0);
  assert.equal(r.row.fine, r.cash);
  assert.ok(r.cash > 0 && r.cash <= 287500);
  assert.equal(r.pending[String(r.row.clubId)], undefined, 'aucun retrait de points en Premiership');
  assert.equal(r.validate, true);
});

test('Doublon : un JIFF convoqué par la France compte dans la feuille de son club', () => {
  const h = world();
  const r = JSON.parse(h.run(`(()=>{const ci=S.worldMode.leagues.elite.members.find(x=>x!==S.club),c=S.clubs[ci],f=S.worldMode.fixtures.find(x=>x.phase==='league'&&x.competitionId==='elite'&&(x.homeId===ci||x.awayId===ci));
   const sheet=new Set([...buildSheet(c).lineup,...buildSheet(c).bench]);
   const away=c.players.filter(p=>CDJiff.isJiff(S,p)&&!sheet.has(p.id)).slice(0,2);
   const none=CDJiff.doublon(S,c,f.date,sheet);
   S.national={role:{club:true,nation:'FRA'},career:{callups:[{nation:'FRA',from:f.date,through:f.date,playerIds:away.map(p=>p.id)},{nation:'ENG',from:f.date,through:f.date,playerIds:c.players.filter(p=>CDJiff.isJiff(S,p)&&!sheet.has(p.id)).slice(2,4).map(p=>p.id)}]}};
   const twice=CDJiff.doublon(S,c,f.date,sheet),other=CDJiff.doublon(S,c,'2020-01-01',sheet);
   const before=(S.jiff.counts[ci]||[0,0])[1];S.jiff.lastCount=null;const sv=CDWorldCareer.fixtures;
   return JSON.stringify({none,twice,other,n:away.length});})()`));
  assert.equal(r.none, 0);
  assert.equal(r.n, 2);
  assert.equal(r.twice, 2, 'les 2 JIFF convoqués par la France comptent, pas ceux convoqués par l’Angleterre');
  assert.equal(r.other, 0, 'hors des dates de la convocation');
});

test('Trajectoire : besoin du prochain match (cas du dernier match à 18 JIFF)', () => {
  const h = world();
  const r = JSON.parse(h.run(`(()=>{const ci=S.worldMode.leagues.elite.members.find(x=>x!==S.club);const f=S.worldMode.fixtures.filter(x=>x.phase==='league'&&x.competitionId==='elite'&&(x.homeId===ci||x.awayId===ci));
   const total=f.length,remaining=S.worldMode.fixtures.filter(x=>x.phase==='league'&&x.competitionId==='elite'&&(x.homeId===ci||x.awayId===ci)&&x.week>=S.worldMode.week).length;
   const played=total-remaining;S.jiff.counts[ci]=[played,16*played-5];const a=CDJiff.standing(S,ci);
   S.jiff.counts[ci]=[played,16*played+60];const b=CDJiff.standing(S,ci);
   S.jiff.counts[ci]=[played,23*played];const c=CDJiff.standing(S,ci);
   return JSON.stringify({a,b,c,remaining});})()`));
  assert.ok(r.a.need > 16 && r.a.margin === -5, 'en retard : plus de 16 à aligner');
  assert.ok(r.b.need < 16 && r.b.margin === 60, 'en avance : moins de 16');
  assert.equal(r.c.need, Math.max(0, Math.ceil((16 * (r.c.sheets + r.remaining) - r.c.total) / r.remaining)));
  // Un seul match restant : le manque se rattrape en entier sur ce match (Racing 92 : 18 JIFF à la dernière journée).
  const last = JSON.parse(h.run(`(()=>{const ci=S.worldMode.leagues.elite.members.find(x=>x!==S.club);const all=S.worldMode.fixtures.filter(x=>x.phase==='league'&&x.competitionId==='elite'&&(x.homeId===ci||x.awayId===ci));
   S.worldMode.week=all[all.length-1].week;S.jiff.counts[ci]=[all.length-1,16*all.length-18];return JSON.stringify(CDJiff.standing(S,ci));})()`));
  assert.equal(last.remaining, 1);
  assert.equal(last.need, 18);
});

test('Alerte : feuille sous la trajectoire, Gabi propose des échanges concrets non qualifié -> qualifié', () => {
  const h = world();
  const r = JSON.parse(h.run(`(()=>{const own=S.clubs[S.club];S.jiff.counts[S.club]=[8,8*14];
   const p=CDJiff.project();const adv=nativePositionAptitudes.quotaAdvice(own,S.lineup,S.reserves);
   const ok=adv&&adv.changes.every(c=>!CDJiff.isJiff(S,own.players.find(x=>x.id===c.sortant))&&CDJiff.isJiff(S,own.players.find(x=>x.id===c.playerId)));
   S.jiff.counts[S.club]=[8,8*23];const calm=nativePositionAptitudes.quotaAdvice(own,S.lineup,S.reserves);
   return JSON.stringify({alert:p.alert,need:p.need,adv,ok,calm});})()`));
  assert.equal(r.alert, true);
  assert.ok(r.need > r.adv.current);
  assert.ok(r.adv.changes.length > 0 && r.ok, 'échanges non qualifié -> JIFF');
  assert.equal(r.calm, null, 'rien à signaler quand la marge est confortable');
});

test('Recrutement : badge JIFF/EQP, valorisation modérée par les clubs IA quand leur moyenne est menacée', () => {
  const h = world();
  const r = JSON.parse(h.run(`(()=>{const ci=S.worldMode.leagues.prem.members[0],c=S.clubs[ci];
   const eq=c.players.find(p=>CDJiff.isEqp(p)),non=c.players.find(p=>!CDJiff.isEqp(p));
   const calm=CDJiff.recruitBonus(S,ci,eq);
   // Menace : seuls 8 EQP sur les 23 meilleurs ; on retire le statut aux autres en retirant la nation (mémo local).
   const ranked=c.players.slice().sort((a,b)=>b.rating-a.rating);
   const save=c.players.slice();c.players=ranked.filter(p=>!CDJiff.isEqp(p)).slice(0,30).concat(ranked.filter(p=>CDJiff.isEqp(p)).slice(0,6));
   const eq2=c.players.find(p=>CDJiff.isEqp(p));
   const hot=CDJiff.recruitBonus(S,ci,eq2),cold=CDJiff.recruitBonus(S,ci,c.players.find(p=>!CDJiff.isEqp(p)));
   c.players=save;
   const own=S.clubs[S.club];const badge=CDJiff.marketBadge(S,own.players[0]);
   return JSON.stringify({calm,hot,cold,badge,hasNon:!!non});})()`));
  assert.equal(r.calm, 0, 'aucune valorisation quand le quota est tenu');
  assert.ok(r.hot >= 4 && r.hot <= 14, 'effet modéré : ' + r.hot);
  assert.equal(r.cold, 0, 'un joueur qui ne compte pas n’est pas valorisé');
  assert.ok(r.badge && ['JIFF', 'EQP'].includes(r.badge.label) && typeof r.badge.ok === 'boolean');
  const market = h.command('snapshot').market;
  assert.ok(market.some(p => p.quota), 'le modèle du recrutement porte le statut quand le club a un quota');
});

test('Courrier de la ligue : retrait, amende, prime proposent des actions', () => {
  const DATA = require('../native/engine/club-mail.json');
  for (const id of ['quota_retrait', 'quota_amende', 'quota_prime']) {
    const t = DATA.types[id];
    assert.ok(t.formulations.length >= 2 && t.reponses.some(x => x.ouvrir) && t.reponses.some(x => x.effets.consigneDS === 'jeunes'), id);
    assert.ok(!/fictif|généré|\bIA\b/i.test(JSON.stringify(t)));
  }
  assert.equal(DATA.types.quota_retrait.ecran, 'Classements');
  const h = world();
  const r = JSON.parse(h.run(`(()=>{const own=S.clubs[S.club];S.season++;S.jiff.results.push({season:S.season-1,clubId:S.club,league:'elite',sheets:26,average:14.5,deduction:3,bonus:0});
   const m=nativeSystems.domain('clubMail'),d=CDWorldCareer.calendarToday(S),next=new Date(Date.parse(d+'T00:00:00Z')+86400000).toISOString().slice(0,10);m.recevoir(S,d);m.recevoir(S,next);
   return JSON.stringify((S.clubMail.mails||[]).filter(x=>x.type==='quota_retrait').map(x=>x.vars));})()`));
  assert.equal(r.length, 1);
  assert.equal(r[0].points, 3);
});
