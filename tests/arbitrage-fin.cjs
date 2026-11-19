'use strict';
// Arbitrage fin (dist/arbitrage.js, docs/rugby-rules-reference.md § « Arbitrage fin ») en carrière Monde : chaque
// pénalité reçoit une cause détaillée (touche, mêlée, ruck, maul, jeu courant) et une touche perdue sur cinq environ
// est un lancer pas droit. Le match du club est rejoué 80 fois depuis le coup d'envoi (mêmes graines que
// cartons-realistes.cjs) avec le marqueur, puis sans : aucun tirage ajouté, donc mêmes scores, pénalités et cartons.
const assert = require('node:assert/strict');
const { ouvrir, creer, jusquAuMatch } = require('./helpers/carriere-monde.cjs');
const { skipMatchTalk } = require('./helpers/scene-match-talks.cjs');

const CAUSES = ['ruck-offside', 'offside', 'ruck-side-entry', 'ruck-hands', 'holding', 'not-release', 'sealing', 'obstruction', 'dangerous', 'scrum', 'lineout-obstruction', 'maul-collapse', 'maul-entry'];
const jeu = ouvrir({ hebdomadaire: true, testVm: true });
try {
  let m = jusquAuMatch(jeu, creer(jeu));
  if (m.selection?.errors?.length) m = jeu.call('auto_lineup');
  jeu.call('begin_match');
  const vm = jeu.bridge.vm;
  assert.equal(vm.run('S.live.arbitrageVersion'), 1, 'match du club créé avec l’arbitrage fin');
  assert.equal(vm.run('JSON.stringify(S.live.stats[0].penaltyFamilies)'), JSON.stringify({ touche: 0, melee: 0, ruck: 0, maul: 0, jeu: 0 }));
  vm.run('globalThis.__base=JSON.stringify(S.live);');
  const r = JSON.parse(vm.run(`(()=>{
    const graine=i=>{let x=(i*7919+17)>>>0;return()=>{x=(Math.imul(x,1664525)+1013904223)>>>0;return x/4294967296}};
    // Le match use les joueurs du club (condition…). Première série : rejeux enchaînés, exactement comme cartons-realistes.cjs
    // (mêmes graines, donc mêmes fréquences). Seconde série : joueurs remis à l'état du coup d'envoi avant chaque rejeu, pour
    // comparer à graine égale un match avec et sans marqueur.
    const etat=JSON.stringify(S.live.pair.map(ci=>S.clubs[ci].players));
    const remettre=()=>{const v=JSON.parse(etat);S.live.pair.forEach((ci,s)=>S.clubs[ci].players.forEach((p,k)=>{for(const key of Object.keys(p))delete p[key];Object.assign(p,v[s][k])}))};
    const jouer=(i,marque,neuf)=>{S.live=JSON.parse(__base);if(neuf)remettre();const l=S.live;if(!marque){delete l.arbitrageVersion;for(const st of l.stats){delete st.penaltyFamilies;delete st.penaltyCauses;delete st.lineoutNotStraight}}
     Math.random=graine(i);let k=0;while(!l.finished&&k++<400){l.paused=false;advanceRugby(l)}return l};
    const out={jaunes:0,exclusions:0,penalites:0,n:0,causes:{},familles:{touche:0,melee:0,ruck:0,maul:0,jeu:0},textes:{},sommes:true,scenes:true,
     pasDroits:0,touchesPerdues:0,identiques:true,anciensTextes:true,sansDetail:true,compares:0};
    for(let i=0;i<80;i++){
     const l=jouer(i,true);
     for(const s of [0,1]){const st=l.stats[s];out.jaunes+=st.yellows;out.exclusions+=l.sheets[s].sentOff.length;out.penalites+=st.penalties;out.n++;
      const f=Object.values(st.penaltyFamilies).reduce((a,b)=>a+b,0),c=Object.values(st.penaltyCauses).reduce((a,b)=>a+b,0);
      if(f!==st.penalties||c!==st.penalties)out.sommes=false;
      for(const [k,v] of Object.entries(st.penaltyFamilies))out.familles[k]+=v;
      for(const [k,v] of Object.entries(st.penaltyCauses))out.causes[k]=(out.causes[k]||0)+v;
      out.pasDroits+=st.lineoutNotStraight;out.touchesPerdues+=st.lineouts-st.lineoutsWon}
     for(const e of l.events){if(e.type!=='penalty'&&e.scene?.detail!=='not-straight')continue;
      if(e.type==='penalty'&&!e.scene?.detail){out.scenes=false;continue}
      const d=e.scene.detail;(out.textes[d]||(out.textes[d]=[])).length<3&&!out.textes[d].includes(e.text)&&out.textes[d].push(e.text)}
    }
    for(let i=0;i<20;i++){
     // Même graine sans marqueur : ancien comportement, mêmes tirages.
     const a=jouer(i,true,true),b=jouer(i,false,true);
     const cle=x=>JSON.stringify([x.score,x.tries,x.minute,x.stats.map(s=>[s.penalties,s.yellows,s.lineouts,s.lineoutsWon,s.scrums,s.scrumsWon,s.goals,s.goalAttempts]),x.sheets.map(s=>s.sentOff.length),x.events.length]);
     if(cle(a)!==cle(b))out.identiques=false;out.compares++;
     for(const e of b.events){if(e.scene?.detail!==undefined)out.sansDetail=false;if(e.type==='penalty'&&!/ sanctionné/.test(e.text))out.anciensTextes=false}
     if(b.stats.some(st=>st.penaltyFamilies||st.lineoutNotStraight!==undefined))out.sansDetail=false;
    }
    S.live=JSON.parse(__base);remettre();delete globalThis.__base;return JSON.stringify(out)})()`, 900000));
  const parEquipe = { jaunes: r.jaunes / r.n, exclusions: r.exclusions / r.n, penalites: r.penalites / r.n };
  console.log('par équipe et par match :', JSON.stringify(parEquipe));
  console.log('familles :', JSON.stringify(r.familles), '· lancers pas droits :', r.pasDroits, 'sur', r.touchesPerdues, 'touches perdues');
  console.log('causes :', JSON.stringify(r.causes));
  for (const [cause, textes] of Object.entries(r.textes)) console.log(' ', cause, '→', textes[0]);
  assert.ok(r.sommes, 'familles et causes somment au total des pénalités de chaque équipe');
  assert.ok(r.scenes, 'chaque pénalité du match du club porte sa cause détaillée');
  for (const cause of CAUSES) {
    assert.ok(r.causes[cause] > 0, 'cause présente : ' + cause);
    assert.ok(r.textes[cause]?.length, 'commentaire présent : ' + cause);
  }
  assert.ok(Object.values(r.familles).every(n => n > 0), 'cinq familles présentes');
  assert.ok(r.familles.ruck > r.familles.touche && r.familles.ruck > r.familles.maul, 'le ruck reste la première source de pénalités');
  assert.ok(r.pasDroits > 0 && r.pasDroits < r.touchesPerdues * 0.4, `lancers pas droits : une partie des touches perdues (${r.pasDroits}/${r.touchesPerdues})`);
  assert.ok(r.textes['not-straight']?.some(t => /Lancer pas droit|n’est pas droit/.test(t)), 'commentaire du lancer pas droit');
  assert.ok(r.identiques && r.compares === 20,'mêmes tirages avec et sans arbitrage fin : scores, pénalités, cartons et touches identiques');
  assert.ok(r.anciensTextes && r.sansDetail, 'match sans marqueur : anciens textes, aucun détail ni compteur');
  // Bornes de cartons-realistes.cjs (fréquences inchangées).
  assert.ok(parEquipe.jaunes > 0.5 && parEquipe.jaunes < 1.4, 'jaunes crédibles : ' + parEquipe.jaunes);
  assert.ok(parEquipe.exclusions > 0.005 && parEquipe.exclusions < 0.12, 'rouges rares mais présents : ' + parEquipe.exclusions);
  assert.ok(parEquipe.penalites > 8 && parEquipe.penalites < 16, 'pénalités inchangées en ordre de grandeur : ' + parEquipe.penalites);
  // Écran de statistiques : la ligne des pénalités porte le détail par famille de chaque équipe.
  // Le vrai match, délégué jusqu'au bout : écran de statistiques puis sauvegarde.
  const fini = skipMatchTalk(jeu.call('delegate'), jeu.call);
  const rangs = (fini.live?.statsRows || []).filter(x => x.detail);
  const pen = rangs.find(x => x.label === 'Pénalités concédées');
  assert.ok(Array.isArray(pen?.detail) && pen.detail.length === 2 && pen.detail.every(t => /^\S+ · (\d+ (touche|mêlée|ruck|maul|jeu courant)( · )?)+$|^\S+ · aucune$/.test(t)), 'détail par famille sous les pénalités : ' + JSON.stringify(pen));
  console.log('écran :', JSON.stringify(rangs.map(x => [x.label, x.detail])));
  if (fini.meta.calendarCadence && fini.live) skipMatchTalk(jeu.call('finish_round'), jeu.call); else jeu.call('finish_round');
  // Sauvegarde : compteurs du match enregistrés et validés ; une somme faussée ou une cause inconnue sont refusées.
  const s = JSON.parse(vm.run(`(()=>{const out={valide:true,refus:0,enregistre:false};
    const r=[...S.history].reverse().find(h=>h.pair.includes(S.club)&&h.stats?.[0]?.penaltyFamilies);out.enregistre=!!r;
    try{validateCareer(S);parseSaveDocument(JSON.stringify(createSaveDocument()))}catch(err){out.valide=String(err&&err.message||err)}
    if(r){r.stats[0].penaltyFamilies.ruck++;try{validateCareer(S)}catch(err){out.refus++}r.stats[0].penaltyFamilies.ruck--;
     r.stats[1].penaltyCauses.inconnue=1;try{validateCareer(S)}catch(err){out.refus++}delete r.stats[1].penaltyCauses.inconnue;
     validateCareer(S)}
    return JSON.stringify(out)})()`, 600000));
  assert.ok(s.enregistre, 'compteurs d’arbitrage enregistrés dans l’historique du club');
  assert.equal(s.valide, true, 'sauvegarde valide : ' + s.valide);
  assert.equal(s.refus, 2, 'compteurs d’arbitrage incohérents refusés');
  console.log('arbitrage-fin : OK');
} finally { jeu.fermer(); }
