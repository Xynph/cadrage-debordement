#!/usr/bin/env node
'use strict';
// Mesure des essais et du score du moteur de match complet sur une saison de carrière Monde
// (world-champ, 116 clubs, tous les championnats détaillés), par championnat : essais et points par
// match (les deux équipes), part des points (essais, transformations, pénalités), marqueurs par
// maillot, écart de score, bonus offensifs, entrées dans les 22 et leur conversion, choix sur
// pénalité ; hiérarchie (rang final contre niveau de l'effectif). Voir docs/essais-realistes-20261114.md.
// Usage : node --max-old-space-size=1100 scripts/mesure-essais-monde.cjs [graine=4242] [club=102] [--json fichier] [--semaines N] [--ancien] [--regler code]
// --regler "PENALITES_RULES=0;ESSAIS.finition=.47" : moteur d'avant les pénalités réalistes (docs/hierarchie-penalites-20261114.md).
// Hiérarchie détaillée et pénalités sifflées par phase ajoutées le 14/11 (favori par tranche d'écart, surprises, écart 1er-dernier).
// --ancien : coefficients d'avant (ESSAIS_RULES=0), pour le tableau avant/après sur la même graine.
// Une seule carrière en mémoire (~1,2 Go) : ne pas lancer deux mesures à la fois sur la machine partagée.
const fs = require('node:fs');
const { context } = require('../tests/monde-harness.cjs');

const args = process.argv.slice(2);
const opt = (nom, def) => { const i = args.indexOf(nom); return i >= 0 ? args[i + 1] : def; };
const libres = args.filter((a, i) => !a.startsWith('--') && !(i > 0 && args[i - 1].startsWith('--')));
const graine = Number(libres[0] ?? 4242), club = Number(libres[1] ?? 102);
const semaines = Number(opt('--semaines', 80)), sortie = opt('--json', null), ancien = args.includes('--ancien');

// Crochets en lecture seule : aucun tirage, aucun état de partie modifié (seulement des champs `__mesure`
// sur le match, jamais sauvegardé puisque les matchs IA ne sont pas conservés).
const CROCHETS = `globalThis.__mesure=[];(()=>{
 const zone=(side,t)=>side===0?t>78:t<22;
 const avance=advanceRugby;advanceRugby=function(l){
  const m=l.__mesure||(l.__mesure={entrees:[0,0],penalites:[[0,0,0,0],[0,0,0,0]],pas:[0,0]});
  const side=l.possession,dedans=zone(side,l.territory);m.pas[side]++;
  const r=avance.apply(this,arguments);
  if(!dedans&&l.possession===side&&zone(side,l.territory))m.entrees[side]++;
  return r;};
 const choix=executePenaltyChoice;executePenaltyChoice=function(l,side){
  const m=l.__mesure,avant=l.stats[side].goalAttempts,ev=l.events.length;
  const r=choix.apply(this,arguments);
  if(m){const k=l.stats[side].goalAttempts>avant?0:l.events.slice(ev).some(e=>/vite|rapide|à la main/i.test(e.text||''))?2:1;m.penalites[side][k]++;m.penalites[side][3]++;}
  return r;};
 // Automatisés : pas de scène ; le marqueur est retrouvé par son nom dans le texte de l'essai, parmi les joueurs en jeu.
 const essai=scoreTry;scoreTry=function(l,side,origin){
  const avant=l.tries[side],ev=l.events.length,enJeu=activePlayers(l,side);
  const r=essai.apply(this,arguments);
  if(l.__mesure&&l.tries[side]>avant){const e=l.events.slice(ev).find(e=>e.type==='try');const p=e&&enJeu.find(p=>e.text.includes('Essai de '+p.name));
   (l.__mesure.essais||(l.__mesure.essais=[])).push([side,p?l.sheets[side].on.indexOf(p.id):-1,p?p.fam:-1,origin]);}
  return r;};
 // Pénalités sifflées par phase (troisième argument d'awardPenalty, 'jeu' par défaut ; avantage compris).
 const sanction=awardPenalty;awardPenalty=function(l,side,phase){
  const m=l.__mesure;if(m){const k=(phase&&phase.phase)||'jeu';(m.phases||(m.phases={}))[k]=(m.phases[k]||0)+1;}
  return sanction.apply(this,arguments);};
 const fin=finishRugbyMatch;finishRugbyMatch=function(l){
  const r=fin.apply(this,arguments);
  if(l.finished&&!l.__lu&&l.__mesure){l.__lu=true;const c=l.worldContext||{};
   const essais=l.__mesure.essais||[];
   const xv=s=>{const ps=l.sheets[s].initial.map(id=>matchPlayer(l,s,id)).filter(Boolean);return Math.round(ps.reduce((a,p)=>a+fitScore(p),0)/Math.max(1,ps.length)*10)/10};
   __mesure.push({xv:[xv(0),xv(1)],comp:c.competitionId||'?',phase:c.phase||'?',pair:l.pair.slice(),score:l.score.slice(),tries:l.tries.slice(),
    goals:l.stats.map(s=>s.goals),goalAttempts:l.stats.map(s=>s.goalAttempts),conv:l.stats.map(s=>s.conversions),convAtt:l.stats.map(s=>s.conversionAttempts),
    pen:l.stats.map(s=>s.penalties),entrees:l.__mesure.entrees,choix:l.__mesure.penalites,pas:l.__mesure.pas,essais,
    pertes:[l.events.filter(e=>e.type==='turnover').length,0],phases:l.__mesure.phases||{},
    scrums:l.stats.map(s=>s.scrums),lineouts:l.stats.map(s=>s.lineouts)});}
  return r;};
})();`;

function niveau(h) {
  // Niveau de l'effectif au début de saison : moyenne des 23 meilleures notes au poste.
  return JSON.parse(h.run(`JSON.stringify(Object.fromEntries(S.clubs.map(c=>[c.id,(()=>{const n=c.players.filter(p=>!p.injury).map(p=>roleNote(p)).sort((a,b)=>b-a).slice(0,23);return n.reduce((a,b)=>a+b,0)/Math.max(1,n.length);})()])))`));
}

function mesurer({ graine = 4242, club = 102, semaines = 80, ancien = false, journal = false, reglage = '' } = {}) {
  const h = context(graine, { console: false });
  if (ancien) h.run('ESSAIS_RULES=0');
  if (reglage) h.run(reglage);
  h.start(club);
  const niveaux = niveau(h);
  const membres = JSON.parse(h.run('JSON.stringify(Object.fromEntries(Object.entries(S.worldMode.leagues).map(([k,v])=>[k,v.members])))'));
  const noms = JSON.parse(h.run('JSON.stringify(S.clubs.map(c=>c.abbr))'));
  h.run(CROCHETS);
  const t0 = Date.now();
  for (let w = 0; w < semaines && h.run("S.phase!=='ended'"); w++) {
    h.week(1, { validate: false });
    if (journal && w % 5 === 0) process.stderr.write(`semaine ${w + 1} : ${h.run('__mesure.length')} matchs, ${Math.round((Date.now() - t0) / 1000)} s\n`);
  }
  const matchs = JSON.parse(h.run('JSON.stringify(__mesure)'));
  const histoire = JSON.parse(h.run(`JSON.stringify(S.history.filter(r=>r.season===S.season).map(r=>({c:r.competitionId,ph:r.phase,pair:r.pair,score:r.score,tries:r.tries})))`));
  h.close();
  return { graine, club, ancien, niveaux, membres, noms, matchs, histoire };
}

const moy = a => a.length ? a.reduce((x, y) => x + y, 0) / a.length : NaN;
const r1 = x => Math.round(x * 10) / 10, r2 = x => Math.round(x * 100) / 100, pc = x => Math.round(x * 1000) / 10;

function spearman(x, y) {
  const rang = v => { const o = v.map((x, i) => [x, i]).sort((a, b) => a[0] - b[0]); const r = []; o.forEach(([, i], k) => { r[i] = k; }); return r; };
  const a = rang(x), b = rang(y), n = x.length, d = a.reduce((s, v, i) => s + (v - b[i]) ** 2, 0);
  return 1 - 6 * d / (n * (n * n - 1));
}

// Classement de saison régulière (4 / 2 / 0, bonus offensif selon le championnat, bonus défensif à 5 points)
// recalculé depuis l'historique : sert seulement à juger la hiérarchie, pas à reproduire chaque règlement.
function classement(histoire, comp, membres) {
  const t = new Map(membres.map(id => [id, { id, pts: 0, v: 0, j: 0, pp: 0, pc: 0 }]));
  for (const r of histoire) {
    if (r.c !== comp || r.ph !== 'league') continue;
    r.pair.forEach((id, s) => {
      const e = t.get(id); if (!e) return; const o = 1 - s, d = r.score[s] - r.score[o];
      e.j++; e.pp += r.score[s]; e.pc += r.score[o];
      if (d > 0) { e.v++; e.pts += 4; } else if (d === 0) e.pts += 2; else if (d >= -5) e.pts += 1;
      const bo = comp === 'elite' || comp === 'accession' || comp === 'nationale' ? d > 0 && r.tries[s] - r.tries[o] >= 3 : r.tries[s] >= 4;
      if (bo) e.pts++;
    });
  }
  return [...t.values()].filter(e => e.j).sort((a, b) => b.pts - a.pts || (b.pp - b.pc) - (a.pp - a.pc));
}

function analyser(d) {
  const parComp = new Map();
  for (const m of d.matchs) { if (!parComp.has(m.comp)) parComp.set(m.comp, []); parComp.get(m.comp).push(m); }
  const lignes = [];
  const toutes = [...parComp.entries()].sort((a, b) => b[1].length - a[1].length);
  toutes.push(['TOUS', d.matchs]);
  for (const [comp, ms] of toutes) {
    const pts = ms.map(m => m.score[0] + m.score[1]), essais = ms.map(m => m.tries[0] + m.tries[1]);
    const sum = f => ms.reduce((a, m) => a + f(m), 0);
    const ptsEssais = sum(m => 5 * (m.tries[0] + m.tries[1])), ptsTransfo = sum(m => 2 * (m.conv[0] + m.conv[1])), ptsPen = sum(m => 3 * (m.goals[0] + m.goals[1]));
    const total = sum(m => m.score[0] + m.score[1]);
    const ecart = ms.map(m => Math.abs(m.score[0] - m.score[1]));
    const bo4 = sum(m => (m.tries[0] >= 4) + (m.tries[1] >= 4)), bo3 = sum(m => [0, 1].filter(s => m.score[s] > m.score[1 - s] && m.tries[s] - m.tries[1 - s] >= 3).length);
    const entrees = sum(m => m.entrees[0] + m.entrees[1]);
    const choix = [0, 1, 2, 3].map(k => sum(m => m.choix[0][k] + m.choix[1][k]));
    lignes.push({ comp, matchs: ms.length, essais: r2(moy(essais)), points: r1(moy(pts)), partEssais: pc(ptsEssais / total), partTransfo: pc(ptsTransfo / total), partPen: pc(ptsPen / total),
      ecart: r1(moy(ecart)), ecart15: pc(ecart.filter(x => x > 15).length / ms.length), ecart7: pc(ecart.filter(x => x <= 7).length / ms.length),
      bonus4: pc(bo4 / (2 * ms.length)), bonus3: pc(bo3 / (2 * ms.length)), zeroEssai: pc(sum(m => (m.tries[0] === 0) + (m.tries[1] === 0)) / (2 * ms.length)),
      entrees22: r1(entrees / ms.length), essaisParEntree: r2(sum(m => m.tries[0] + m.tries[1]) / Math.max(1, entrees)),
      penalites: r1(choix[3] / ms.length), auxPoteaux: pc(choix[0] / Math.max(1, choix[3])), touche: pc(choix[1] / Math.max(1, choix[3])), aLaMain: pc(choix[2] / Math.max(1, choix[3])),
      reussiteButs: pc(sum(m => m.goals[0] + m.goals[1]) / Math.max(1, sum(m => m.goalAttempts[0] + m.goalAttempts[1]))),
      transfo: pc(sum(m => m.conv[0] + m.conv[1]) / Math.max(1, sum(m => m.convAtt[0] + m.convAtt[1]))),
      pertes: r1(sum(m => m.pertes[0] + m.pertes[1]) / ms.length),
      sifflees: r1(sum(m => m.pen[0] + m.pen[1]) / ms.length), ptsPenMatch: r1(ptsPen / ms.length),
      melees: r1(sum(m => (m.scrums ? m.scrums[0] + m.scrums[1] : 0)) / ms.length),
      parPhase: (() => { const t = {}; for (const m of ms) for (const [k, v] of Object.entries(m.phases || {})) t[k] = (t[k] || 0) + v; return Object.entries(t).map(([k, v]) => k + ' ' + r1(v / ms.length)).join(', '); })() });
  }
  // Marqueurs par maillot (1 à 15), toutes compétitions.
  const maillots = new Array(15).fill(0); let inconnus = 0, totalEssais = 0;
  for (const m of d.matchs) for (const [, n] of m.essais) { totalEssais++; if (n >= 0 && n < 15) maillots[n]++; else inconnus++; }
  const parMaillot = maillots.map((x, i) => ({ maillot: i + 1, part: pc(x / Math.max(1, totalEssais)), parMatch: r2(x / d.matchs.length / 2) }));
  const groupes = { avants: [0, 1, 2, 3, 4, 5, 6, 7], premiereLigne: [0, 1, 2], troisiemeLigne: [5, 6, 7], charniere: [8, 9], centres: [11, 12], ailiers: [10, 13], arriere: [14] };
  const parGroupe = Object.fromEntries(Object.entries(groupes).map(([g, k]) => [g, pc(k.reduce((a, i) => a + maillots[i], 0) / Math.max(1, totalEssais))]));
  const origines = {}; for (const m of d.matchs) for (const e of m.essais) origines[e[3] || '?'] = (origines[e[3] || '?'] || 0) + 1;
  // Hiérarchie : rang de saison régulière contre niveau de l'effectif ; part des victoires du mieux armé.
  const hierarchie = [];
  const xvMoyen = {};
  for (const m of d.matchs) if (m.xv) m.pair.forEach((id, s) => { (xvMoyen[id] = xvMoyen[id] || []).push(m.xv[s]); });
  const niveauClub = id => xvMoyen[id] ? moy(xvMoyen[id]) : d.niveaux[id];
  for (const [comp, membres] of Object.entries(d.membres)) {
    const t = classement(d.histoire, comp, membres); if (t.length < 4) continue;
    const rho = spearman(t.map(e => -niveauClub(e.id)), t.map((e, i) => i));
    const ms = d.matchs.filter(m => m.comp === comp && m.phase === 'league');
    const fav = seuil => { const f = ms.filter(m => m.xv && Math.abs(m.xv[0] - m.xv[1]) >= seuil); return f.length ? pc(f.filter(m => { const k = m.xv[0] > m.xv[1] ? 0 : 1; return m.score[k] > m.score[1 - k]; }).length / f.length) + ' (' + f.length + ')' : '-'; };
    const meilleur = [...membres].sort((a, b) => niveauClub(b) - niveauClub(a))[0];
    hierarchie.push({ comp, spearman: r2(rho), effectif1: '-', effectif3: '-', favori2: fav(2), favori5: fav(5), domicile: pc(ms.filter(m => m.score[0] > m.score[1]).length / Math.max(1, ms.length)), meilleurRang: t.findIndex(e => e.id === meilleur) + 1,
      tete: t.slice(0, 3).map(e => `${d.noms[e.id]} ${e.pts} (${r1(niveauClub(e.id))})`).join(', '),
      victoiresTete: t[0].v + '/' + t[0].j, victoiresDernier: t.at(-1).v + '/' + t.at(-1).j });
  }
  // Favori selon l'effectif (moyenne des 23 meilleures notes au poste au début de saison) : le XV aligné
  // dépend aussi de la rotation (un club fort fait souffler ses titulaires contre plus faible).
  const parEffectif = seuil => { const f = d.matchs.filter(m => m.phase === 'league' && Math.abs(d.niveaux[m.pair[0]] - d.niveaux[m.pair[1]]) >= seuil); return pc(f.filter(m => { const k = d.niveaux[m.pair[0]] > d.niveaux[m.pair[1]] ? 0 : 1; return m.score[k] > m.score[1 - k]; }).length / Math.max(1, f.length)) + ' (' + f.length + ')'; };
  const rhoEffectif = []; for (const [comp, membres] of Object.entries(d.membres)) { const t = classement(d.histoire, comp, membres); if (t.length >= 8) rhoEffectif.push(spearman(t.map(e => -d.niveaux[e.id]), t.map((e, i) => i))); }
  const tousFav = seuil => { const f = d.matchs.filter(m => m.xv && Math.abs(m.xv[0] - m.xv[1]) >= seuil); return pc(f.filter(m => { const k = m.xv[0] > m.xv[1] ? 0 : 1; return m.score[k] > m.score[1 - k]; }).length / Math.max(1, f.length)) + ' (' + f.length + ')'; };
  hierarchie.push({ comp: 'TOUS', spearman: r2(moy(rhoEffectif)) + ' (effectif)', effectif1: parEffectif(1), effectif3: parEffectif(3), favori2: tousFav(2), favori5: tousFav(5), domicile: pc(d.matchs.filter(m => m.score[0] > m.score[1]).length / d.matchs.length), meilleurRang: '-', tete: '-', victoiresTete: '-', victoiresDernier: '-' });
  // Hiérarchie détaillée (saison régulière des championnats) : favori selon l'effectif par tranche d'écart,
  // à domicile et à l'extérieur, surprises, écart de points entre premier et dernier, rang du mieux armé.
  const ligue = d.matchs.filter(m => m.phase === 'league');
  const tranches = [[0, 1], [1, 2], [2, 3], [3, 5], [5, 99]].map(([a, b]) => {
    const f = ligue.filter(m => { const e = Math.abs(d.niveaux[m.pair[0]] - d.niveaux[m.pair[1]]); return e >= a && e < b; });
    const gagne = m => { const k = d.niveaux[m.pair[0]] > d.niveaux[m.pair[1]] ? 0 : 1; return m.score[k] > m.score[1 - k] ? 1 : m.score[k] === m.score[1 - k] ? .5 : 0; };
    const dom = f.filter(m => d.niveaux[m.pair[0]] > d.niveaux[m.pair[1]]), ext = f.filter(m => d.niveaux[m.pair[0]] < d.niveaux[m.pair[1]]);
    return { tranche: a + '-' + (b > 50 ? '+' : b), matchs: f.length, favori: pc(moy(f.map(gagne))), favoriDomicile: pc(moy(dom.map(gagne))), favoriExterieur: pc(moy(ext.map(gagne))) };
  });
  const tableaux = [];
  for (const [comp, membres] of Object.entries(d.membres)) {
    const t = classement(d.histoire, comp, membres); if (t.length < 8) continue;
    const ordre = [...membres].sort((a, b) => d.niveaux[b] - d.niveaux[a]);
    tableaux.push({ comp, clubs: t.length, premier: t[0].pts, dernier: t.at(-1).pts, ecartPoints: t[0].pts - t.at(-1).pts,
      rangMieuxArme: t.findIndex(e => e.id === ordre[0]) + 1, rang2: t.findIndex(e => e.id === ordre[1]) + 1,
      spearmanEffectif: r2(spearman(t.map(e => -d.niveaux[e.id]), t.map((e, i) => i))),
      champion: d.noms[t[0].id] + ' (n° ' + (ordre.indexOf(t[0].id) + 1) + ' effectif)' });
  }
  const surprises = ligue.filter(m => Math.abs(d.niveaux[m.pair[0]] - d.niveaux[m.pair[1]]) >= 3).filter(m => { const k = d.niveaux[m.pair[0]] > d.niveaux[m.pair[1]] ? 0 : 1; return m.score[k] < m.score[1 - k]; }).length;
  const detail = { tranches, tableaux, surprises3: surprises, matchsLigue: ligue.length,
    favoriGlobal: pc(moy(ligue.filter(m => d.niveaux[m.pair[0]] !== d.niveaux[m.pair[1]]).map(m => { const k = d.niveaux[m.pair[0]] > d.niveaux[m.pair[1]] ? 0 : 1; return m.score[k] > m.score[1 - k] ? 1 : m.score[k] === m.score[1 - k] ? .5 : 0; }))) };
  // Ailier titulaire : essais par match des maillots 11 et 14.
  const ailier = r2((maillots[10] + maillots[13]) / d.matchs.length / 4);
  return { graine: d.graine, club: d.club, matchs: d.matchs.length, lignes, parMaillot, parGroupe, origines, inconnus, ailierParMatch: ailier, hierarchie, detail };
}

function tableau(rows, cols) {
  return ['| ' + cols.join(' | ') + ' |', '|' + cols.map(() => '---').join('|') + '|', ...rows.map(r => '| ' + cols.map(c => String(r[c])).join(' | ') + ' |')].join('\n');
}

if (require.main === module) {
  const relire = opt('--analyser', null);
  const d = relire ? JSON.parse(fs.readFileSync(relire, 'utf8')).brut : mesurer({ graine, club, semaines, ancien, journal: true, reglage: opt('--regler', '') });
  const a = analyser(d);
  if (sortie && !relire) fs.writeFileSync(sortie, JSON.stringify({ analyse: a, brut: d }));
  console.log(`Graine ${a.graine}, club ${a.club}${d.ancien ? ' (coefficients d’avant)' : ''} : ${a.matchs} matchs au moteur complet.`);
  console.log(tableau(a.lignes, ['comp', 'matchs', 'essais', 'points', 'partEssais', 'partTransfo', 'partPen', 'ecart', 'ecart7', 'ecart15', 'bonus4', 'bonus3', 'zeroEssai']));
  console.log(tableau(a.lignes, ['comp', 'entrees22', 'essaisParEntree', 'penalites', 'auxPoteaux', 'touche', 'aLaMain', 'reussiteButs', 'transfo', 'pertes']));
  console.log('Marqueurs par maillot (% des essais) : ' + a.parMaillot.map(x => x.maillot + ':' + x.part).join(' '));
  console.log('Groupes : ' + JSON.stringify(a.parGroupe) + ' · origines : ' + JSON.stringify(a.origines) + ' · inconnus : ' + a.inconnus);
  console.log('Ailier titulaire : ' + a.ailierParMatch + ' essai par match');
  console.log(tableau(a.lignes, ['comp', 'sifflees', 'parPhase', 'melees', 'ptsPenMatch']));
  console.log(tableau(a.detail.tranches, ['tranche', 'matchs', 'favori', 'favoriDomicile', 'favoriExterieur']));
  console.log(`Favori (effectif) toutes tranches : ${a.detail.favoriGlobal} % ; surprises (écart ≥ 3 perdu) : ${a.detail.surprises3} sur ${a.detail.matchsLigue} matchs de championnat`);
  console.log(tableau(a.detail.tableaux, ['comp', 'clubs', 'premier', 'dernier', 'ecartPoints', 'rangMieuxArme', 'rang2', 'spearmanEffectif', 'champion']));
  console.log(tableau(a.hierarchie, ['comp', 'spearman', 'favori2', 'favori5', 'effectif1', 'effectif3', 'domicile', 'meilleurRang', 'victoiresTete', 'victoiresDernier', 'tete']));
}
module.exports = { mesurer, analyser, classement };
