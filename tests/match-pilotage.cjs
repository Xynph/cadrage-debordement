'use strict';
// Pilotage du match (dist/match-pilotage.js) en carrière Monde : arbitre, consignes en direct, causeries à effet réel,
// staff qui décide quand le match lui est confié. Les effets se mesurent sur des moyennes d'échantillon (mêmes graines
// pour chaque réglage), jamais sur le résultat exact d'un match.
const assert = require('node:assert/strict');
const { ouvrir, creer, jusquAuMatch } = require('./helpers/carriere-monde.cjs');

const jeu = ouvrir({ hebdomadaire: true, testVm: true });
try {
  let m = jusquAuMatch(jeu, creer(jeu));
  if (m.selection?.errors?.length) m = jeu.call('auto_lineup');
  m = jeu.call('begin_match');
  const p = m.live.pilotage;
  assert.ok(p, 'pilotage projeté dans le match du joueur');
  assert.ok(p.arbitre.nom && p.arbitre.resume, 'arbitre nommé');
  for (const k of ['rucks', 'melee', 'horsJeu', 'cartons']) assert.ok(p.arbitre[k] >= 1 && p.arbitre[k] <= 5, k);
  assert.equal(p.axes.length, 14, '11 consignes en direct + 3 réglages du plan de jeu');
  assert.deepEqual(p.consignes, { piedJeu: 'normal', rythme: 'normal', relance: 'selon', finDeMatch: 'normal', rucks: 'normale', discipline: 'normale', touche: 'normale', maul: 'selon', melee: 'normale', coupsEnvoi: 'normaux', cible: 'aucune' });
  assert.deepEqual(p.adversaire.consignes, p.consignes, 'banc adverse : consignes neutres au coup d’envoi');

  // Causerie d'avant-match : six tons distincts, dont « Furieux » ; réaction visible et état pour le match.
  const scene = m.clubLife.matchTalks.scene;
  assert.equal(scene.phase, 'pre');
  assert.deepEqual(scene.options.map(o => o.tone).sort(), ['assertive', 'calm', 'demanding', 'furious', 'protective', 'warm']);
  const furieux = scene.options.find(o => o.tone === 'furious');
  assert.equal(furieux.toneLabel, 'Furieux');
  const ids = scene.participants.map(x => x.id);
  const vm = jeu.bridge.vm;
  // Vestiaire adverse : sa causerie d'avant-match est faite à l'ouverture de celle du manager ; chacun de ses joueurs
  // a un état, sans toucher la confiance de la carrière ni les états projetés du club joué.
  const adverse = JSON.parse(vm.run(`JSON.stringify((()=>{const l=S.live,o=1-l.userSide,sh=l.sheets[o],e=l.pilotage.etats;
    return {feuille:[...sh.initial,...sh.bench].length,etats:[...sh.initial,...sh.bench].filter(id=>e[id]?.adverse).length,
      confiance:Object.keys(S.pilotage?.confiance||{}).filter(id=>[...sh.initial,...sh.bench].includes(id)).length,journal:l.pilotage.journal.map(x=>x.texte)}})())`));
  assert.ok(adverse.feuille >= 22 && adverse.etats === adverse.feuille, 'chaque joueur adverse de la feuille a un état : ' + adverse.etats + '/' + adverse.feuille);
  assert.equal(adverse.confiance, 0, 'confiance de la carrière inchangée pour les joueurs adverses');
  assert.ok(adverse.journal.some(t => /^Vestiaire .+ : discours \S+ avant le match\.$/.test(t)), 'journal : causerie adverse ' + adverse.journal);
  assert.ok(m.live.pilotage.adversaire.causeries.pre?.label, 'ton adverse projeté');
  console.log('causerie adverse :', adverse.journal.join(' | '));
  m = jeu.call('match_talk_decide', { key: scene.key, phase: 'pre', choiceId: furieux.id, audience: 'group', playerIds: [] });
  const d = m.clubLife.matchTalks.scene.decision;
  assert.equal(d.reactions.length, ids.length);
  const etats = new Set(d.reactions.map(x => x.etat));
  assert.ok(etats.size >= 2, 'les joueurs ne réagissent pas tous pareil : ' + [...etats]);
  assert.ok(d.reactions.every(x => x.label && x.score >= -3 && x.score <= 3));
  assert.equal(Object.keys(m.live.pilotage.joueurs).length, ids.length, 'état de chaque joueur dans le match');
  m = jeu.call('match_talk_continue', { key: scene.key, phase: 'pre' });
  vm.run('globalThis.__base=JSON.stringify(S.live);');

  // Consignes sans pause, effet mesuré depuis le changement ; consigne inconnue refusée.
  assert.equal(jeu.brut('set_consignes', { axe: 'rucks', valeur: 'folle' }).ok, false);
  assert.equal(jeu.brut('set_consignes', { axe: 'tempo', valeur: 'rapide' }).ok, false);
  m = jeu.call('set_consignes', { axe: 'rucks', valeur: 'agressive' });
  assert.equal(m.live.pilotage.consignes.rucks, 'agressive');
  // 20 pas : le banc adverse revoit ses consignes dès la 5e minute ; 15 pas n'y suffisaient plus selon le tirage (4e minute).
  m = jeu.call('tick', { steps: 20 });
  const bilan = m.live.pilotage.bilans.find(b => b.axe === 'rucks');
  assert.ok(JSON.parse(vm.run('S.live.pilotage.adversaire.minute')) >= 5, 'le banc adverse revoit ses consignes pendant le direct (tick)');
  assert.ok(bilan && /^Rucks « Contester » depuis \d+′ : \d+ pénalités?, \d+ ballons? arrachés?\.$/.test(bilan.texte), bilan?.texte);

  // Plan de jeu dans la même commande que les consignes : seulement match en pause (comme avant).
  assert.ok(m.live.pilotage.axes.some(a => a.id === 'planAttaque' && a.groupe === 'attaque' && a.pause), 'plan de jeu dans l’onglet Consignes');
  assert.deepEqual(m.live.pilotage.groupes.map(g => g.id), ['attaque', 'defense', 'conquete', 'adversaire']);
  if (!m.live.paused) assert.equal(jeu.brut('set_consignes', { axe: 'planAttaque', valeur: 'large' }).ok, false, 'plan de jeu : pause requise');
  m = jeu.call('pause', { paused: true });
  m = jeu.call('set_consignes', { axe: 'planAttaque', valeur: 'large' });
  assert.equal(m.live.pilotage.axes.find(a => a.id === 'planAttaque').valeur, 'large');
  m = jeu.call('set_consignes', { axe: 'planAttaque', valeur: 'equilibre' });
  m = jeu.call('pause', { paused: false });
  // Cris de la touche : sans pause, effet sur les joueurs présents, usure si on répète ; projection pour la fenêtre Équipe.
  const pc = m.live.pilotage;
  assert.deepEqual(pc.cris.options.map(o => o.id), ['encourager', 'exiger', 'calmer', 'defense', 'toutDonner']);
  assert.equal(pc.cris.options.find(o => o.id === 'toutDonner').disponible, false, 'Tout donner : seulement en fin de match');
  assert.equal(jeu.brut('cri', { id: 'hurler' }).ok, false);
  assert.equal(jeu.brut('cri', { id: 'toutDonner' }).ok, false);
  assert.equal(pc.fatigue.length, 4);
  assert.ok(pc.fatigue.every(f => f.prevue <= f.condition && f.prevue >= 12), JSON.stringify(pc.fatigue));
  assert.ok(pc.conseilChangement === null || (pc.conseilChangement.outId && pc.conseilChangement.inId && pc.conseilChangement.texte), 'conseil de changement');
  assert.ok(m.live.lineup.every(p => Number.isFinite(p.rating)), 'niveau de chaque joueur pour la fenêtre Équipe');
  const vmc = jeu.bridge.vm;
  const plaquage = () => vmc.run('(()=>{const p=activePlayers(S.live,S.live.userSide).find(x=>!(S.live.pilotage.etats[x.id]||{}).etat||S.live.pilotage.etats[x.id].etat==="indifferent");return p?skill(p,"tackle"):null})()');
  const plaquageAvant = plaquage();
  m = jeu.call('cri', { id: 'defense' });
  assert.equal(m.live.pilotage.cris.actif.id, 'defense');
  assert.equal(plaquage() - plaquageAvant, 4, 'Serrer la défense : +4 au plaquage pendant 10 minutes');
  m = jeu.call('cri', { id: 'defense' });
  assert.equal(m.live.pilotage.cris.actif.force, .5, 'cri répété : moitié moins');
  assert.equal(plaquage() - plaquageAvant, 2);

  // Effets moyens : mêmes graines, un seul réglage change. Le match repart du coup d'envoi.
  vm.run('globalThis.__live=JSON.stringify(S.live);');
  const mesurer = (reglage, n = 160) => JSON.parse(vm.run(`(()=>{const acc={pen:0,jaunes:0,arraches:0,coups:0,touches:0,touchesG:0,ecart:0,maul:0,envois:0,repris:0,penMelee:0,metres:0,pertes:0,matchs:0};
    for(let i=0;i<${n};i++){S.live=JSON.parse(__base);const l=S.live;
      ${reglage}
      let k=0;while(!l.finished&&k++<400){l.paused=false;advanceRugby(l)}
      const u=l.userSide,o=1-u;acc.pen+=l.stats[u].penalties;acc.jaunes+=l.stats[u].yellows||0;acc.arraches+=l.tacticalStats?.[o]?.handErrors||0;
      acc.coups+=l.tacticalStats?.[u]?.kicks||0;acc.touches+=l.stats[u].lineouts;acc.touchesG+=l.stats[u].lineoutsWon;acc.ecart+=l.score[u]-l.score[o];
      acc.metres+=l.tacticalStats?.[u]?.metres||0;acc.pertes+=l.tacticalStats?.[u]?.handErrors||0;
      l.events.forEach((e,j)=>{const sc=e.scene||{};if(e.type==='try'&&sc.team===u&&sc.origin==='maul')acc.maul++;if(e.type==='penalty'&&sc.cause==='scrum')acc.penMelee++;
        if(e.type==='restart'&&sc.team===u){acc.envois++;const n=l.events[j+1]?.scene;if(n?.kind==='reception'&&n.team===u)acc.repris++}});acc.matchs++}
    for(const k of Object.keys(acc))if(k!=='matchs')acc[k]/=acc.matchs;return JSON.stringify(acc)})()`, 600000));
  // Mesures des consignes du manager : banc adverse figé (consignes absentes = règles d'avant), un seul réglage change.
  const figer = 'delete l.pilotage.consignesAdverses;delete l.pilotage.adversaire;';
  const neutre = figer + 'l.pilotage.consignes={piedJeu:"normal",rucks:"normale",discipline:"normale",rythme:"normal",touche:"normale"};l.pilotage.etats={};l.pilotage.arbitre={...l.pilotage.arbitre,rucks:3,melee:3,horsJeu:3,cartons:3};';
  const seed = s => `Math.random=(()=>{let x=${s};return()=>{x=(Math.imul(x,1664525)+1013904223)>>>0;return x/4294967296}})();`;
  // Une graine par match, identique d'un réglage à l'autre.
  const serie = (reglage, n) => mesurer(neutre + reglage + seed('(i*7919+17)>>>0'), n);
  const base = serie('');
  const agressif = serie('l.pilotage.consignes.rucks="agressive";');
  const prudent = serie('l.pilotage.consignes.rucks="prudente";');
  const strict = serie('l.pilotage.consignes.discipline="stricte";');
  const arbitreRucks = serie('l.pilotage.consignes.rucks="agressive";l.pilotage.arbitre.rucks=5;l.pilotage.arbitre.horsJeu=4;');
  const cartons = serie('l.pilotage.arbitre.cartons=5;');
  const pied = serie('l.pilotage.consignes.piedJeu="plus";');
  const garder = serie('l.pilotage.consignes.piedJeu="moins";');
  const toucheSure = serie('l.pilotage.consignes.touche="sure";');
  // 480 matchs : depuis le recalage des cartons (19/11/2026), l'écart galvanisés / vexés tombe de ~3,1 à ~2 points (plus de
  // cartons des deux côtés) ; sur 160 matchs l'erreur type (~1,5 point) le rendait illisible.
  const galvanises = serie('for(const id of l.sheets[l.userSide].initial)l.pilotage.etats[id]={etat:"galvanise",phase:"pre"};', 480);
  const vexes = serie('for(const id of l.sheets[l.userSide].initial)l.pilotage.etats[id]={etat:"vexe",phase:"pre"};', 480);
  // Banc adverse aux consignes neutres et immobile : exactement le match d'avant (mêmes graines, mêmes chiffres).
  const avant = mesurer(neutre + seed('(i*7919+17)>>>0'), 20);
  const neutresAdverses = mesurer(neutre + 'l.pilotage.consignesAdverses={piedJeu:"normal",rucks:"normale",discipline:"normale",rythme:"normal",touche:"normale"};' + seed('(i*7919+17)>>>0'), 20);
  assert.deepEqual(neutresAdverses, avant, 'consignes adverses neutres : comportement du club joué inchangé');
  // Banc adverse actif (petite série) : il change ses consignes en cours de match, sans effet absurde.
  const depart = 'l.pilotage.etats={};l.pilotage.consignes={piedJeu:"normal",rucks:"normale",discipline:"normale",rythme:"normal",touche:"normale"};';
  const fige = mesurer(figer + depart + seed('(i*7919+17)>>>0'), 60);
  const actif = JSON.parse(vm.run(`(()=>{let changes=0,matchs=0,ecart=0;for(let i=0;i<60;i++){S.live=JSON.parse(__base);const l=S.live;
    ${depart}${seed('(i*7919+17)>>>0')}let k=0;while(!l.finished&&k++<400){l.paused=false;advanceRugby(l)}
    changes+=l.pilotage.adversaire.derniers.length;ecart+=l.score[l.userSide]-l.score[1-l.userSide];matchs++}
    return JSON.stringify({changes:changes/matchs,ecart:ecart/matchs})})()`, 600000));
  const r = x => Math.round(x * 100) / 100;
  console.log('banc adverse actif (60 matchs) : changements de consigne par match', r(actif.changes), '· écart du club joué', r(actif.ecart), '(banc adverse figé :', r(fige.ecart) + ')');
  assert.ok(actif.changes > 0.5, 'le banc adverse ajuste ses consignes en cours de match');
  assert.ok(Math.abs(actif.ecart - fige.ecart) < 5, 'banc adverse actif : effet borné sur le score');
  console.log('pénalités concédées : base', r(base.pen), '· rucks agressifs', r(agressif.pen), '· prudents', r(prudent.pen), '· zéro faute', r(strict.pen), '· agressifs + arbitre pointilleux', r(arbitreRucks.pen), '· galvanisés', r(galvanises.pen), '· vexés', r(vexes.pen));
  console.log('ballons arrachés : base', r(base.arraches), '· agressifs', r(agressif.arraches), '· prudents', r(prudent.arraches));
  console.log('jaunes : base', r(base.jaunes), '· arbitre sévère', r(cartons.jaunes), '| coups de pied : base', r(base.coups), '· occuper', r(pied.coups), '· garder', r(garder.coups));
  console.log('touche gagnée : base', r(base.touchesG / base.touches), '· sûre', r(toucheSure.touchesG / toucheSure.touches), '| écart de score : base', r(base.ecart), '· galvanisés', r(galvanises.ecart), '· vexés', r(vexes.ecart));
  // Stats crédibles : un Top 14 se joue autour de 10 à 12 pénalités concédées par équipe (moteur actuel : ~13).
  assert.ok(base.pen > 7 && base.pen < 16, 'base crédible : ' + base.pen);
  // Seuil 1,08 (au lieu de 1,12) depuis les cartons réalistes (c0868aaf, 18/11) : moins de cartons, donc moins de joueurs
  // exclus qui faisaient boule de neige sur les fautes ; mesuré ×1,10 (14,45 contre 13,15), même chiffre sans le banc adverse.
  assert.ok(agressif.pen > base.pen * 1.08 && agressif.arraches > base.arraches, 'rucks agressifs : plus de fautes et de ballons arrachés');
  assert.ok(prudent.pen < base.pen, 'rucks prudents : moins de fautes');
  assert.ok(strict.pen < base.pen * .9, 'zéro faute : nettement moins de pénalités');
  assert.ok(arbitreRucks.pen > agressif.pen, 'un arbitre pointilleux punit davantage les rucks agressifs');
  assert.ok(arbitreRucks.pen < 20, 'pas de score de fautes absurde : ' + arbitreRucks.pen);
  assert.ok(cartons.jaunes > base.jaunes, 'arbitre sévère : plus de cartons');
  assert.ok(pied.coups > base.coups && garder.coups < base.coups, 'jeu au pied suivi');
  assert.ok(toucheSure.touchesG / toucheSure.touches > base.touchesG / base.touches, 'lancer court plus sûr');
  // Nouvelles consignes (attaque, conquête, adversaire), 100 matchs par réglage.
  // Relance : +1,2 à 2,2 % d'erreurs de main, soit ≈ 0,2 ballon par match, sous l'erreur type d'une série de 100 matchs : 400 matchs.
  const relancer = serie('l.pilotage.consignes.relance="relancer";', 400), degager = serie('l.pilotage.consignes.relance="degager";', 400);
  const courts = serie('l.pilotage.consignes.coupsEnvoi="courts";', 100), longs = serie('l.pilotage.consignes.coupsEnvoi="longs";', 100);
  const pousser = serie('l.pilotage.consignes.melee="pousser";', 100), maulSouvent = serie('l.pilotage.consignes.maul="souvent";', 100), maulJamais = serie('l.pilotage.consignes.maul="jamais";', 100);
  // Aile faible : effet de l'ordre de 0,3 point par match, sous l'erreur type d'une série de 100 matchs (≈ 1,5 point) :
  // 400 matchs, comme la relance (sur 100, l'écart s'inversait au moindre changement d'effectif, ex. postes réels du 19/11).
  const aile = serie('l.pilotage.consignes.cible="aile";l.pilotage.depuis.cible=0;', 400), base400 = serie('', 400), base100 = serie('', 100);
  console.log('relance : coups de pied', r(degager.coups), '/', r(relancer.coups), '· mètres', r(degager.metres), '/', r(relancer.metres), '· pertes', r(degager.pertes), '/', r(relancer.pertes));
  console.log('coups d’envoi repris : courts', r(courts.repris / courts.envois), '· base', r(base100.repris / base100.envois), '· longs', r(longs.repris / longs.envois));
  console.log('pénalités de mêlée : base', r(base100.penMelee), '· pousser', r(pousser.penMelee), '| essais sur ballon porté : jamais', r(maulJamais.maul), '· base', r(base100.maul), '· souvent', r(maulSouvent.maul), '| point faible aile : écart', r(aile.ecart), 'contre', r(base400.ecart));
  assert.ok(degager.coups > relancer.coups && relancer.pertes > degager.pertes, 'relance suivie');
  assert.ok(courts.repris / courts.envois > base100.repris / base100.envois && longs.repris / longs.envois < base100.repris / base100.envois, 'coups d’envoi courts plus souvent repris');
  assert.ok(pousser.penMelee > base100.penMelee * 1.2, 'pousser en mêlée fait siffler davantage');
  assert.ok(maulSouvent.maul > base100.maul && maulJamais.maul < base100.maul, 'ballon porté suivi');
  assert.ok(aile.ecart > base400.ecart, 'attaquer leur aile faible rapporte, au moins au début');
  assert.ok(galvanises.ecart > vexes.ecart + 1.5, 'l’état des joueurs pèse sur le match : ' + r(galvanises.ecart - vexes.ecart));
  assert.ok(vexes.pen > base.pen, 'des joueurs vexés concèdent plus de fautes');
  // Scénario construit : l'adversaire mené de 10 points à l'heure de jeu, staff vigilant → il accélère et garde le ballon.
  const poursuite = JSON.parse(vm.run(`(()=>{S.live=JSON.parse(__live);const l=S.live,o=1-l.userSide;l.pilotage.adversaire.niveau=85;
    l.score[l.userSide]=l.score[o]+10;for(let m=60;m<=80;m+=5){l.minute=m;pilotageAdversaire(l)}
    return JSON.stringify({consignes:l.pilotage.consignesAdverses,journal:l.pilotage.journal.filter(x=>x.auteur==='adversaire').map(x=>x.minute+'′ '+x.texte),projection:pilotageProjection(l).adversaire})})()`));
  console.log('adversaire mené :', poursuite.journal.join(' | '));
  assert.equal(poursuite.consignes.rythme, 'rapide');
  assert.equal(poursuite.consignes.piedJeu, 'moins');
  assert.ok(poursuite.journal.some(t => / accélère le rythme\.$/.test(t)), 'journal : changement visible de l’adversaire');
  assert.ok(poursuite.projection.derniers.some(x => x.axe === 'rythme' && x.valeur === 'rapide'), 'projection : derniers changements adverses');
  vm.run('S.live=JSON.parse(__live);delete globalThis.__base;delete globalThis.__live;');

  // Match confié au staff : il prend les causeries (mi-temps et après) et note ses changements de consignes.
  m = jeu.call('delegate');
  const recus = m.clubLife.matchTalks.receipts.slice(-3);
  assert.equal(m.live.finished, true);
  assert.ok(recus.some(x => x.status === 'delegated' && x.choiceId), 'le staff a prononcé une causerie');
  const journalComplet = JSON.parse(vm.run('JSON.stringify(S.live.pilotage.journal)'));
  assert.ok(journalComplet.some(x => x.auteur === 'adversaire' && /à la mi-temps\.$/.test(x.texte)), 'causerie adverse de mi-temps en délégation');
  console.log('journal du staff :', m.live.pilotage.journal.map(x => x.minute + '′ ' + x.texte).join(' | ') || '(aucun changement)');
  const confiance = JSON.parse(vm.run('JSON.stringify(S.pilotage)'));
  assert.equal(confiance.version, 1);
  assert.ok(Object.keys(confiance.confiance).length >= 15, 'confiance envers le manager conservée');
  console.log('match-pilotage : OK');
} finally { jeu.fermer(); }
