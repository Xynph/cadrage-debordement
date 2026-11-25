'use strict';
// Récit du match cohérent (audit du journal sur 150 matchs, 25/11/2026) : ce que le joueur lit doit suivre ce qui se passe.
//  1. un « avantage sur en-avant » suit toujours un en-avant raconté, commis par l'autre équipe ;
//  2. une faute commise pendant l'avantage de l'adversaire n'est plus annoncée comme une pénalité : on revient à la
//     première faute, et le bénéficiaire annoncé est celui qui tape ;
//  3. le buteur est un joueur d'arrière (jamais un pilier ni un talonneur ; le demi de mêlée seulement à défaut) ;
//  4. une course arrêtée qui rend le ballon raconte qui est arrêté ;
//  5. un renvoi repris par l'équipe qui l'a botté est dit « renvoi court », pas une réception ordinaire.
// Les matchs sont joués par le vrai moteur (carrière Monde, comme scripts/stats-match-validation.cjs).
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { worldYouth } = require('./helpers/youth-world-harness.cjs');

const NOMBRE = Number(process.env.CD_RECIT_MATCHS) || 36;

function simuler(nombre) {
  const matchs = [];
  for (let monde = 0; matchs.length < nombre; monde++) {
    const t = worldYouth({ seed: 827381 + monde * 101, club: monde * 7 });
    const total = Number(t.run('CDWorldCareer.fixtures(S).length'));
    for (let i = 0; i < 42 && matchs.length < nombre; i++) {
      const k = matchs.length;
      matchs.push(JSON.parse(t.run(`(()=>{const f=CDWorldCareer.fixtures(S)[${i % total}];const pair=[f.homeId,f.awayId];for(const id of pair)CDFranceCareer.ensureAISheet(S.clubs[id]);
      S.club=pair[0];const l=createRugbyMatch(pair,null,false);for(let n=0;!l.finished;n++){if(n>4000)throw Error('boucle');l.paused=false;advanceRugby(l)}
      const joueurs={};for(const ci of pair)for(const p of S.clubs[ci].players)joueurs[p.id]={name:p.name,fam:p.fam,pos:p.pos};
      return JSON.stringify({k:${k},events:l.events,score:l.score,stats:l.stats,joueurs,abbr:pair.map(ci=>S.clubs[ci].abbr)});})()`)));
    }
  }
  return matchs;
}

const BRUIT = new Set(['card', 'sub', 'tactic', 'message']);
const avant = (ev, j, ok) => { for (let p = j - 1; p >= 0; p--) if (!BRUIT.has(ev[p].type) && ok(ev[p], p)) return ev[p]; else if (!BRUIT.has(ev[p].type)) return null; return null; };

let matchs = null;
const jouer = () => matchs || (matchs = simuler(NOMBRE));

test('« Avantage sur en-avant » : l’en-avant est raconté juste avant, par l’autre équipe', { timeout: 1800000 }, () => {
  let avantages = 0; const fautes = [];
  for (const m of jouer()) m.events.forEach((e, j) => {
    const a = /^Avantage sur en-avant pour (\S+)\./.exec(e.text);
    if (!a) return;
    avantages++;
    const prec = avant(m.events, j, () => true);
    const ok = prec && prec.scene && prec.scene.kind === 'hand-fault' && /en-avant/.test(prec.text) && !prec.text.startsWith(a[1] + ' ');
    if (!ok) fautes.push(`match ${m.k} [${j}] ${e.text} <- ${prec ? prec.text : 'rien'}`);
  });
  // Le récit suit ce qui arrive : la faute n'annonce pas un avantage que la ligne suivante annule.
  const contradictions = [];
  for (const m of jouer()) m.events.forEach((e, j) => {
    if (!(e.type === 'play' && e.scene.kind === 'hand-fault' && /laisse jouer/.test(e.text))) return;
    const suite = m.events[j + 1];
    if (!suite || !/^Avantage sur en-avant/.test(suite.text)) contradictions.push(`match ${m.k} [${j}] ${e.text} -> ${suite ? suite.text : 'rien'}`);
  });
  assert.deepEqual(contradictions.slice(0, 5), [], `${contradictions.length} « laisse jouer l’avantage » non suivis d’un avantage`);
  assert.ok(avantages >= 20, `assez d’avantages observés (${avantages})`);
  assert.deepEqual(fautes.slice(0, 5), [], `${fautes.length}/${avantages} avantages sur en-avant sans en-avant raconté`);
});

test('Faute pendant l’avantage : retour à la première faute, jamais de pénalité annoncée au mauvais camp', { timeout: 1800000 }, () => {
  let retours = 0; const fautes = [];
  for (const m of jouer()) {
    m.events.forEach((e, j) => {
      const r = /^Aucun avantage obtenu : retour à la pénalité pour (\S+)\./.exec(e.text);
      if (!r) return;
      retours++;
      // La dernière pénalité annoncée avant ce retour doit être celle de l’équipe qui reprend l’avantage.
      let p = j - 1; while (p >= 0 && !(m.events[p].type === 'penalty' && !/pendant l’avantage/.test(m.events[p].text))) p--;
      const ann = p >= 0 ? /Pénalité pour (\S+?)[ .]/.exec(m.events[p].text + ' ') : null;
      const benef = p >= 0 ? m.abbr[m.events[p].scene.team] : null;
      if (p < 0 || benef !== r[1] || (ann && ann[1] !== r[1])) fautes.push(`match ${m.k} [${p}-${j}] ${p >= 0 ? m.events[p].text : '?'} / ${e.text}`);
    });
    // Les fautes de la feuille sont toujours celles du journal.
    for (const side of [0, 1]) {
      const journal = m.events.filter(e => e.type === 'penalty' && e.scene.team === 1 - side).length;
      assert.equal(m.stats[side].penalties, journal, `match ${m.k} équipe ${side} : pénalités de la feuille et du journal`);
    }
  }
  assert.ok(retours >= 20, `assez de retours d’avantage observés (${retours})`);
  assert.deepEqual(fautes.slice(0, 5), [], `${fautes.length}/${retours} retours à la pénalité contredits par la pénalité annoncée juste avant`);
});

test('Buteur : jamais un avant, le demi de mêlée seulement à défaut', { timeout: 1800000 }, () => {
  // Cas construit : un pilier très fort au pied, un demi de mêlée meilleur que l’ouvreur, un ouvreur moyen.
  const t = worldYouth({ seed: 827381, club: 0 });
  const r = JSON.parse(t.run(`(()=>{
    const c=S.clubs[S.club],on=[0,4,5,6].map(fam=>c.players.find(p=>p.fam===fam));
    const pick=fam=>on.find(p=>p.fam===fam);
    const pilier=pick(0),demi=pick(4),ouvreur=pick(5),ailier=pick(6);
    for(const p of on)p.skills.goal=30;
    pilier.skills.goal=99;demi.skills.goal=90;ouvreur.skills.goal=55;ailier.skills.goal=40;
    const choisi=chooseScorer(c,on.map(p=>p.id));
    const sans=on.filter(p=>p.fam<=4);const aDefaut=chooseScorer(c,sans.map(p=>p.id));
    return JSON.stringify({choisi:choisi.id,ouvreur:ouvreur.id,pilier:pilier.id,demi:demi.id,aDefaut:aDefaut.id,demiFam:demi.fam});})()`));
  assert.equal(r.choisi, r.ouvreur, 'avec des arrières sur le terrain, le buteur est un arrière (pas le pilier, pas le demi de mêlée)');
  assert.equal(r.aDefaut, r.demi, 'sans arrière, le demi de mêlée passe avant les avants');
  // Sur les matchs joués : aucun pilier ou talonneur, et peu de demis de mêlée, parmi les tireurs au but.
  let tirs = 0, avants = 0; const exemples = [];
  for (const m of jouer()) for (const e of m.events) {
    if (e.type !== 'goal' && e.type !== 'miss') continue;
    tirs++;
    const p = m.joueurs[e.scene.actor];
    if (p && p.fam <= 3) { avants++; exemples.push(`match ${m.k} ${e.text}`); }
  }
  assert.ok(tirs >= 40, `assez de tirs au but observés (${tirs})`);
  assert.deepEqual(exemples.slice(0, 5), [], `${avants}/${tirs} tirs au but par un avant`);
});

test('Course arrêtée qui rend le ballon : on lit qui est arrêté', { timeout: 1800000 }, () => {
  let pertes = 0; const fautes = [];
  for (const m of jouer()) m.events.forEach((e, j) => {
    if (e.type !== 'turnover' || !/ après le plaquage pour /.test(e.text)) return;
    pertes++;
    if (!/ est arrêté /.test(e.text)) fautes.push(`match ${m.k} [${j}] ${e.text}`);
  });
  assert.ok(pertes >= 20, `assez de ballons rendus observés (${pertes})`);
  assert.deepEqual(fautes.slice(0, 5), [], `${fautes.length}/${pertes} récupérations sans la course racontée`);
});

test('Renvoi repris par l’équipe qui l’a botté : « renvoi court », pas une réception ordinaire', { timeout: 1800000 }, () => {
  let repris = 0, normaux = 0; const fautes = [];
  for (const m of jouer()) m.events.forEach((e, j) => {
    if (e.type !== 'play' || e.scene.kind !== 'reception') return;
    const p = avant(m.events, j, x => ['kickoff', 'drop22', 'goalLine'].includes(x.scene.kind));
    if (!p) return;
    if (p.scene.team === e.scene.team) { repris++; if (!/^Renvoi court/.test(e.text)) fautes.push(`match ${m.k} [${j}] ${e.text}`); }
    else { normaux++; if (/^Renvoi court/.test(e.text)) fautes.push(`match ${m.k} [${j}] réception adverse dite « renvoi court » : ${e.text}`); }
  });
  assert.ok(repris >= 5 && normaux >= 50, `assez de renvois observés (${repris} repris, ${normaux} normaux)`);
  assert.deepEqual(fautes.slice(0, 5), [], `${fautes.length} renvois mal racontés`);
});
