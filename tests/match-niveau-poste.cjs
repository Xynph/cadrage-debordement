'use strict';
// Niveau au poste (docs/niveau-au-poste-20261126.md) : un titulaire nettement plus faible que la norme de son poste se
// sent dans la phase de son poste (pilier → mêlée et pénalités de mêlée, talonneur → touche, ailier → essais,
// buteur → réussite au but), sans écraser le hasard, et une équipe ordinaire n'a aucun effet. Carrière Monde
// (world-champ), club 102, même affiche et mêmes graines pour la référence et chaque variante (écarts appariés).
// Le joueur affaibli perd 15 de note (ses qualités de match baissent d'autant) et 15 de Niveau du match.
const assert = require('node:assert/strict');
const { test } = require('node:test');
const { worldYouth } = require('./helpers/youth-world-harness.cjs');

const USER = 102;
const MATCHS = 400;
// L'ailier pèse peu par match (≈ −0,1 essai) et les remplacements au poste (K3) le font parfois sortir : il lui faut
// plus de matchs pour que l'écart apparié sorte du bruit (mesure sur 1 500 matchs : −0,08 avec K3, −0,13 sans).
const MATCHS_VARIANTE = { ailier: 1000 };
const t = worldYouth({ seed: 827381, club: USER });
t.toMatch();
const pair = JSON.parse(t.run('JSON.stringify(nextMatch())'));
t.ctx.__clubs = {};
for (const id of pair) t.ctx.__clubs[id] = t.run(`JSON.stringify(S.clubs[${id}])`);
const base = JSON.parse(t.run(`JSON.stringify(buildSheet(S.clubs[${USER}],S.lineup,S.reserves))`));
const kickerSlot = JSON.parse(t.run(`JSON.stringify((()=>{const lu=${JSON.stringify(base.lineup)};return lu.indexOf(chooseScorer(S.clubs[${USER}],lu).id)})())`));

// Remet les deux clubs dans leur état d'origine et applique les affaiblissements ; niveauMatch est enveloppé pour
// retirer l'écart (le Niveau du match lit les qualités détaillées, pas la note).
const PREPARER = `(cfg)=>{
 for(const id of __pair)S.clubs[id]=JSON.parse(__clubs[id]);
 S.club=${USER};S.lineup=[...cfg.base.lineup];S.reserves=[...cfg.base.bench];S.tactic='equilibre';S.defence='equilibre';
 const c=S.clubs[${USER}];
 for(const m of cfg.mod||[]){const p=c.players.find(p=>p.id===S.lineup[m.slot]);ensureSkills(p);if(m.goal)p.skills.goal-=m.d;else{p.rating-=m.d;p.__k2d=m.d}}
 if(!globalThis.__nmOrig)globalThis.__nmOrig=niveauMatch;niveauMatch=function(p){return __nmOrig(p)-((p&&p.__k2d)||0)};
}`;
const JOUER = `(seed,cfg)=>{
 (${PREPARER})(cfg);
 const pen=[0,0];if(!globalThis.__awOrig)globalThis.__awOrig=awardPenalty;
 awardPenalty=function(l,side,o={}){if(o.phase==='melee')pen[side===l.userSide?1:0]++;return __awOrig.apply(this,arguments)};
 __setSeed(seed);
 const l=createRugbyMatch(__pair,null,false,null);if(typeof initPilotage==='function')initPilotage(l);S.live=l;
 for(let k=0;!l.finished;k++){if(k>6000)throw Error('boucle');l.paused=false;advanceRugby(l)}
 S.live=null;awardPenalty=__awOrig;niveauMatch=__nmOrig;
 const u=l.userSide,o=1-u,st=l.stats;
 return JSON.stringify({pts:l.score[u],opp:l.score[o],tr:l.tries[u],sc:st[u].scrums,scW:st[u].scrumsWon,lo:st[u].lineouts,loW:st[u].lineoutsWon,
  gA:st[u].goalAttempts+st[u].conversionAttempts,gM:st[u].goals+st[u].conversions,penMelee:pen[0]-pen[1]})}`;
// Lecture directe des phases sur un match tout juste créé (aucun tirage du match joué).
const PHASES = `(cfg)=>{
 (${PREPARER})(cfg);
 const l=createRugbyMatch(__pair,null,false,null),u=l.userSide,c=S.clubs[${USER}],k=c.players.find(p=>p.id===S.lineup[${kickerSlot}]);
 const r={finition:edgePoste(l,u,'finition'),percee:edgePoste(l,u,'percee'),
  melee:uniteConquete(l,u,'scrum'),meleeMoy:unit(l,u,'scrum',p=>p.fam<=2),touche:uniteConquete(l,u,'lineout'),toucheMoy:unit(l,u,'lineout',p=>p.fam===1||p.fam===2),
  but:goalShotSuccess(l,k,{distance:30,angle:.3})};
 niveauMatch=__nmOrig;return JSON.stringify(r)}`;
t.ctx.__pair = pair;
t.ctx.__setSeed = s => t.setSeed(s);
const cfg = mod => ({ base, mod });
const phases = mod => { t.ctx.__cfg = cfg(mod); return JSON.parse(t.run(`(${PHASES})(__cfg)`)); };
const jouer = (i, mod) => { t.ctx.__cfg = cfg(mod); return JSON.parse(t.run(`(${JOUER})(${(i * 7919 + 13) >>> 0},__cfg)`)); };

const faible = slots => slots.map(slot => ({ slot, d: 15 }));
const VARIANTES = { pilier: faible([0]), talonneur: faible([1]), ailier: faible([10]), buteur: [{ slot: kickerSlot, goal: true, d: 20 }] };

test('Phases du poste : une équipe ordinaire sans effet, un titulaire faible pèse dans sa phase', () => {
  const ref = phases(null);
  console.log('référence', JSON.stringify(ref));
  assert.ok(Math.abs(ref.finition) <= .04 && Math.abs(ref.percee) <= .04, `équipe ordinaire : finition ${ref.finition.toFixed(3)}, percée ${ref.percee.toFixed(3)}`);
  const ail = phases(VARIANTES.ailier);
  assert.ok(ref.finition - ail.finition >= .015 && ref.finition - ail.finition <= .12, `ailier faible : finition ${ref.finition.toFixed(3)} → ${ail.finition.toFixed(3)}`);
  assert.ok(ref.finition - ail.finition > ref.percee - ail.percee, 'les ailiers pèsent plus en finition qu’en percée');
  const pil = phases(VARIANTES.pilier);
  const dMelee = ref.melee - pil.melee, dMoy = ref.meleeMoy - pil.meleeMoy;
  assert.ok(dMelee >= 1.5 * dMoy, `piliers faibles : mêlée −${dMelee.toFixed(1)} contre −${dMoy.toFixed(1)} en moyenne simple`);
  const tal = phases(VARIANTES.talonneur);
  assert.ok(ref.touche - tal.touche > 1.2 * (ref.toucheMoy - tal.toucheMoy), `talonneur faible : touche −${(ref.touche - tal.touche).toFixed(1)} contre −${(ref.toucheMoy - tal.toucheMoy).toFixed(1)}`);
  const but = phases(VARIANTES.buteur);
  assert.ok(ref.but - but.but >= .05, `buteur faible : réussite ${ref.but.toFixed(3)} → ${but.but.toFixed(3)}`);
});

test('Matchs joués : effet visible au poste, borné, le hasard garde sa place', () => {
  const R = { ref: [] };
  const nMax = Math.max(MATCHS, ...Object.values(MATCHS_VARIANTE));
  for (let i = 0; i < nMax; i++) R.ref.push(jouer(i, null));
  for (const [nom, mod] of Object.entries(VARIANTES)) { R[nom] = []; const n = MATCHS_VARIANTE[nom] || MATCHS; for (let i = 0; i < n; i++) R[nom].push(jouer(i, mod)); }
  const refDe = nom => R.ref.slice(0, R[nom].length);
  const m = a => a.reduce((s, x) => s + x, 0) / a.length;
  const taux = (rs, n, d) => 100 * rs.reduce((s, r) => s + n(r), 0) / rs.reduce((s, r) => s + d(r), 0);
  const ecart = (nom, f) => m(R[nom].map((r, i) => f(r) - f(R.ref[i])));
  const vict = rs => 100 * m(rs.map(r => r.pts > r.opp ? 1 : r.pts === r.opp ? .5 : 0));
  const bilan = {};
  for (const nom of Object.keys(VARIANTES)) bilan[nom] = {
    marge: +ecart(nom, r => r.pts - r.opp).toFixed(2), victoires: +(vict(R[nom]) - vict(refDe(nom))).toFixed(1), essais: +ecart(nom, r => r.tr).toFixed(2),
    penMelee: +ecart(nom, r => r.penMelee).toFixed(2), melee: +(taux(R[nom], r => r.scW, r => r.sc) - taux(refDe(nom), r => r.scW, r => r.sc)).toFixed(1),
    touche: +(taux(R[nom], r => r.loW, r => r.lo) - taux(refDe(nom), r => r.loW, r => r.lo)).toFixed(1), buts: +(taux(R[nom], r => r.gM, r => r.gA) - taux(refDe(nom), r => r.gM, r => r.gA)).toFixed(1),
  };
  console.log('écarts appariés (%d matchs, ailier %d) : %s', MATCHS, MATCHS_VARIANTE.ailier, JSON.stringify(bilan));
  assert.ok(bilan.pilier.penMelee >= .3, `pilier faible : pénalités de mêlée concédées en plus ${bilan.pilier.penMelee}`);
  assert.ok(bilan.pilier.melee <= -1.5, `pilier faible : mêlées gardées ${bilan.pilier.melee} points`);
  assert.ok(bilan.talonneur.touche <= -3, `talonneur faible : touches gardées ${bilan.talonneur.touche} points`);
  assert.ok(bilan.ailier.essais <= -.05, `ailier faible : essais ${bilan.ailier.essais}`);
  assert.ok(bilan.buteur.buts <= -1, `buteur faible : réussite ${bilan.buteur.buts} points`);
  // Borné : un titulaire faible coûte quelques points, jamais un match joué d'avance.
  for (const [nom, b] of Object.entries(bilan)) {
    assert.ok(b.marge <= .5 && b.marge >= -7, `${nom} : marge ${b.marge}`);
    assert.ok(b.victoires >= -20, `${nom} : victoires ${b.victoires} points`);
  }
});
