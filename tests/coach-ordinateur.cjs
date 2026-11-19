'use strict';
// Coach de l'ordinateur (dist/match-pilotage.js, demande de LÃ©o du 19/11/2026) : dans un match entre deux clubs de
// l'ordinateur, chaque banc fait sa causerie d'avant-match et de mi-temps, revoit ses consignes selon le score et le
// temps, et fait ses changements selon la fatigue, avec les mÃªmes leviers que le manager. On mesure l'effet sur un lot
// de matchs (mÃªmes graines, coach absent puis prÃ©sent) : rÃ©sultats crÃ©dibles, aucun dÃ©sÃ©quilibre.
const assert = require('node:assert/strict');
const { ouvrir, creer } = require('./helpers/carriere-monde.cjs');

const N = Number(process.env.CD_COACH_MATCHS) || 600;
const jeu = ouvrir({ hebdomadaire: true, testVm: true });
try {
  creer(jeu);
  const vm = jeu.bridge.vm;
  // Rencontres de la journÃ©e entre clubs de l'ordinateur (le calendrier refuse toute autre affiche), rejouÃ©es avec une
  // graine par match ; forme et blessures des joueurs remises Ã  l'identique aprÃ¨s chaque match.
  vm.run(`globalThis.__fx=CDWorldCareer.fixtures(S).filter(f=>![f.homeId,f.awayId].includes(S.club));
    globalThis.__graine=s=>{let x=s>>>0;Math.random=()=>{x=(Math.imul(x,1664525)+1013904223)>>>0;return x/4294967296}};
    globalThis.__etat=ids=>{const ps=ids.flatMap(id=>S.clubs[id].players);const t=JSON.stringify(ps);return ()=>{const o=JSON.parse(t);ps.forEach((p,i)=>Object.assign(p,o[i]))}};`);
  assert.ok(JSON.parse(vm.run('__fx.length')) >= 4, 'assez de rencontres entre clubs de lâ€™ordinateur');

  const lot = coach => JSON.parse(vm.run(`(()=>{const acc={matchs:0,dom:0,nuls:0,points:0,essais:0,pen:0,jaunes:0,ecart:0,favori:0,favoris:0,changements:0,causeries:0,subs:0,condition:0,fin:{},etats:{}};
    const alea=Math.random,live=S.live;
    try{for(let i=0;i<${N};i++){const f=__fx[i%__fx.length],a=f.homeId,b=f.awayId;
      for(const id of [a,b])CDFranceCareer.ensureAISheet(S.clubs[id]);const remettre=__etat([a,b]);
      __graine(i*7919+17);const l=createRugbyMatch([a,b],null,true);
      ${coach ? "initPilotageIA(l,f);" : ''}
      const niv=[0,1].map(s=>teamLevel(activePlayers(l,s)));
      let k=0;while(!l.finished&&k++<600){l.paused=false;advanceRugby(l)}
      acc.matchs++;if(l.score[0]>l.score[1])acc.dom++;else if(l.score[0]===l.score[1])acc.nuls++;
      acc.points+=l.score[0]+l.score[1];acc.essais+=l.tries[0]+l.tries[1];acc.ecart+=Math.abs(l.score[0]-l.score[1]);
      acc.pen+=(l.stats[0].penalties+l.stats[1].penalties)/2;acc.jaunes+=((l.stats[0].yellows||0)+(l.stats[1].yellows||0))/2;
      if(Math.abs(niv[0]-niv[1])>=3){acc.favoris++;const f=niv[0]>niv[1]?0:1;if(l.score[f]>l.score[1-f])acc.favori++}
      acc.subs+=(l.sheets[0].subs+l.sheets[1].subs)/2;
      acc.condition+=[0,1].reduce((n,s)=>n+activePlayers(l,s).reduce((m,p)=>m+p.condition,0)/Math.max(1,activePlayers(l,s).length),0)/2;
      const p=l.pilotage;if(p&&p.cotes){for(const b of p.cotes){acc.changements+=b.changements/2;acc.causeries+=Object.keys(b.causeries).length/2;
        for(const [axe,v] of Object.entries(b.consignes))if(v!==CONSIGNES_NEUTRES[axe])acc.fin[axe+':'+v]=(acc.fin[axe+':'+v]||0)+1}
        for(const e of Object.values(p.etats))acc.etats[e.etat]=(acc.etats[e.etat]||0)+1}remettre()}}
    finally{Math.random=alea;S.live=live}
    for(const k of ['points','essais','pen','jaunes','ecart','changements','causeries','subs','condition'])acc[k]/=acc.matchs;
    acc.domicile=acc.dom/acc.matchs;acc.nul=acc.nuls/acc.matchs;acc.favoriGagne=acc.favori/Math.max(1,acc.favoris);
    return JSON.stringify(acc)})()`, 1200000));

  const sans = lot(false), avec = lot(true);
  const r = x => Math.round(x * 100) / 100;
  const ligne = (t, x) => console.log(t.padEnd(11), 'victoires Ã  domicile', r(x.domicile), 'Â· nuls', r(x.nul), 'Â· favori gagne', r(x.favoriGagne), '(' + x.favoris + ')',
    'Â· points', r(x.points), 'Â· essais', r(x.essais), 'Â· Ã©cart', r(x.ecart), 'Â· pÃ©nalitÃ©s/Ã©quipe', r(x.pen), 'Â· jaunes/Ã©quipe', r(x.jaunes),
    'Â· changements/Ã©quipe', r(x.subs), 'Â· forme finale', r(x.condition));
  ligne('sans coach', sans);
  ligne('avec coach', avec);
  console.log('coach : causeries par banc', r(avec.causeries), 'Â· changements de consigne par banc', r(avec.changements),
    'Â· consignes en fin de match', JSON.stringify(avec.fin), 'Â· Ã©tats', JSON.stringify(avec.etats));

  // Le coach agit : deux causeries par banc, des consignes revues en cours de match, des joueurs de chaque Ã©tat.
  assert.equal(avec.matchs, sans.matchs);
  assert.ok(avec.causeries > 1.95, 'causerie dâ€™avant-match et de mi-temps de chaque banc : ' + avec.causeries);
  assert.ok(avec.changements > 0.8 && avec.changements < 6, 'consignes revues selon le score et le temps : ' + avec.changements);
  assert.ok(Object.keys(avec.etats).length >= 4, 'rÃ©actions variÃ©es aux causeries : ' + Object.keys(avec.etats));
  assert.ok(avec.subs >= 4, 'changements selon la fatigue : ' + avec.subs);
  // RÃ©sultats crÃ©dibles et sans dÃ©sÃ©quilibre : le coach ne fait pas basculer les matchs, il les nuance.
  assert.ok(Math.abs(avec.domicile - sans.domicile) < 0.08, 'avantage du terrain inchangÃ© : ' + r(sans.domicile) + ' â†’ ' + r(avec.domicile));
  assert.ok(Math.abs(avec.favoriGagne - sans.favoriGagne) < 0.08, 'hiÃ©rarchie respectÃ©e : ' + r(sans.favoriGagne) + ' â†’ ' + r(avec.favoriGagne));
  assert.ok(avec.points > sans.points * 0.88 && avec.points < sans.points * 1.12, 'points par match : ' + r(sans.points) + ' â†’ ' + r(avec.points));
  assert.ok(avec.pen > 7 && avec.pen < 16, 'pÃ©nalitÃ©s par Ã©quipe crÃ©dibles : ' + r(avec.pen));
  assert.ok(Math.abs(avec.jaunes - sans.jaunes) < 0.35, 'cartons jaunes : ' + r(sans.jaunes) + ' â†’ ' + r(avec.jaunes));
  assert.ok(avec.nul < 0.08, 'peu de nuls : ' + r(avec.nul));

  // Un banc menÃ© Ã  l'heure de jeu accÃ©lÃ¨re et garde le ballon, puis tente le tout pour le tout ; l'autre gÃ¨re son avance.
  const scenario = JSON.parse(vm.run(`(()=>{const alea=Math.random;try{const {homeId:a,awayId:b}=__fx[0];__graine(99);const l=createRugbyMatch([a,b],null,true);
    initPilotageIA(l,{id:'scenario',competitionId:'champ'});for(const c of l.pilotage.cotes)c.niveau=85;l.score=[3,10];
    for(let m=60;m<=75;m+=5){l.minute=m;coachOrdinateur(l)}return JSON.stringify(l.pilotage.cotes.map(c=>c.consignes))}finally{Math.random=alea}})()`));
  assert.equal(scenario[0].rythme, 'rapide');
  assert.equal(scenario[0].piedJeu, 'moins');
  assert.equal(scenario[0].finDeMatch, 'tout');
  assert.equal(scenario[1].piedJeu, 'plus');
  assert.equal(scenario[1].finDeMatch, 'montre');

  // Un match du joueur n'est pas touchÃ© par l'initialisation des matchs de l'ordinateur ; un match de l'ordinateur ne
  // dÃ©borde pas sur le direct : chaque match lit les Ã©tats de ses propres joueurs.
  const isole = JSON.parse(vm.run(`(()=>{const alea=Math.random;try{const {homeId:a,awayId:b}=__fx[0];__graine(5);const l=createRugbyMatch([a,b],null,true);
    initPilotageIA(l,{id:'isole',competitionId:'champ'});const id=l.sheets[0].on[0],p=activePlayers(l,0).find(x=>x.id===id);
    l.pilotage.etats[id]={etat:'galvanise',phase:'pre'};const dehors=skill(p,'tackle');let dedans=null;
    pilotageMinute(l,x=>{dedans=skill(p,'tackle')});return JSON.stringify({dehors,dedans})}finally{Math.random=alea}})()`));
  assert.equal(isole.dedans - isole.dehors, 4, 'Ã©tat Â« GalvanisÃ© Â» appliquÃ© pendant la minute de son match seulement');
  console.log('coach-ordinateur : OK');
} finally { jeu.fermer(); }
