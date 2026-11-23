'use strict';
// Moral individuel en match (dist/match-pilotage.js, revue FM27 de Léo du 22/11/2026) : départ = réaction à la causerie
// (50 sans causerie), variations lisibles et modérées selon les faits (essai, but, percée, plaquage battu, en-avant,
// grattage, carton, entrée en jeu, score et temps), retour doux vers le départ, effet sur le jeu borné à ±2 points.
const assert = require('node:assert/strict');
const { ouvrir, creer, jusquAuMatch } = require('./helpers/carriere-monde.cjs');

const jeu = ouvrir({ hebdomadaire: true, testVm: true });
try {
  let m = jusquAuMatch(jeu, creer(jeu));
  if (m.selection?.errors?.length) m = jeu.call('auto_lineup');
  m = jeu.call('begin_match');
  const vm = jeu.bridge.vm;
  const scene = m.clubLife.matchTalks.scene;
  m = jeu.call('match_talk_decide', { key: scene.key, phase: 'pre', choiceId: scene.options[0].id, audience: 'group', playerIds: [] });
  m = jeu.call('match_talk_continue', { key: scene.key, phase: 'pre' });
  m = jeu.call('tick', { steps: 2 });
  const projete = m.live.pilotage.moral;
  const depart = JSON.parse(vm.run('JSON.stringify(MORAL_DEPART)'));
  const etats = m.live.pilotage.joueurs;
  const titulaires = m.live.lineup.filter(Boolean).map(j => j.id);
  // Départ : la réaction de la causerie ; projection limitée aux joueurs du club joué.
  for (const id of titulaires) {
    assert.ok(projete[id], 'moral projeté pour ' + id);
    assert.equal(projete[id].depart, depart[etats[id]?.etat] ?? 50, 'départ = réaction à la causerie');
    assert.ok(['Gonflé à bloc', 'Confiant', 'Concentré', 'Inquiet', 'Abattu'].includes(projete[id].label), projete[id].label);
  }
  const adverses = JSON.parse(vm.run('JSON.stringify(S.live.sheets[1-S.live.userSide].on)'));
  assert.ok(adverses.every(id => !projete[id]), 'aucun joueur adverse dans la projection');

  // Faits isolés sur une copie du direct : chaque variation est celle annoncée.
  vm.run('globalThis.__base=JSON.stringify(S.live);');
  const essai = JSON.parse(vm.run(`(()=>{const l=S.live=JSON.parse(__base),u=l.userSide,o=1-u;pilotageMoral(l);
    const nous=activePlayers(l,u).map(p=>p.id),eux=activePlayers(l,o).map(p=>p.id),M=l.pilotage.moral.joueurs,v=id=>M[id].v;
    const avant={a:v(nous[3]),b:v(nous[5]),c:v(eux[2])};
    l.events.push({min:l.minute,text:'essai',type:'try',scene:{kind:'try',team:u,actor:nous[3],from:{x:50,y:35},to:{x:100,y:35}}});
    l.events.push({min:l.minute,text:'percée',type:'play',scene:{kind:'carry',team:u,actor:nous[5],tackler:eux[2],from:{x:40,y:30},to:{x:62,y:30}}});
    l.events.push({min:l.minute,text:'en-avant',type:'play',scene:{kind:'hand-fault',team:o,actor:eux[4],from:{x:50,y:35},to:{x:50,y:35}}});
    const e4=v(eux[4]);
    const k=l.sheets[o].yellowCounts=l.sheets[o].yellowCounts||{};k[eux[6]]=(k[eux[6]]||0)+1;const e6=v(eux[6]),e7=v(eux[7]);
    pilotageMoral(l);
    return JSON.stringify({a:[avant.a,v(nous[3])],b:[avant.b,v(nous[5])],c:[avant.c,v(eux[2])],d:[e4,v(eux[4])],carton:[e6,v(eux[6])],equipe:[e7,v(eux[7])]})})()`));
  const ecart = ([a, b]) => Math.round((b - a) * 10) / 10;
  assert.equal(ecart(essai.a), 8, 'marqueur : +8');
  assert.equal(ecart(essai.b), 3 + 3, 'percée (+3) et essai de l’équipe (+3)');
  assert.equal(ecart(essai.c), -3 - 3 - 2, 'plaquage battu (−3), essai encaissé (−3), carton d’un coéquipier (−2)');
  assert.equal(ecart(essai.d), -3 - 3 - 2, 'en-avant (−3), essai encaissé (−3), carton d’un coéquipier (−2)');
  assert.equal(ecart(essai.carton), -12 - 3, 'carton (−12) et essai encaissé (−3)');
  assert.equal(ecart(essai.equipe), -2 - 3, 'équipe du joueur averti (−2) et essai encaissé (−3)');
  // Retour vers le départ à la minute suivante, entrée en jeu, score en 2e mi-temps.
  const suite = JSON.parse(vm.run(`(()=>{const l=S.live=JSON.parse(__base),u=l.userSide,o=1-u;pilotageMoral(l);const M=l.pilotage.moral.joueurs;
    const id=activePlayers(l,u)[0].id;M[id].v=M[id].depart+20;l.minute=Math.floor(l.minute)+1;pilotageMoral(l);const retour=M[id].v-M[id].depart;
    const banc=l.sheets[u].bench.find(Boolean),slot=l.sheets[u].on.indexOf(activePlayers(l,u)[1].id);const avantEntree=M[banc]?.v??null;
    l.sheets[u].on[slot]=banc;pilotageMoral(l);const entree=M[banc].v-(avantEntree??M[banc].depart);
    l.minute=45;l.score[u]=20;l.score[o]=3;const t=activePlayers(l,u)[2].id,a=M[t].v;pilotageMoral(l);
    return JSON.stringify({retour,entree,mene:M[t].v-a*(1-.04)-M[t].depart*.04})})()`));
  assert.ok(Math.abs(suite.retour - 19.2) < 0.06, 'retour de 4 % de l’écart par minute : ' + suite.retour);
  assert.equal(Math.round(suite.entree), 4, 'remplaçant qui entre : +4');
  assert.ok(Math.abs(suite.mene - 1) < 0.11, 'à 45′, mené de 17 points chez l’adversaire : +1 pour notre équipe : ' + suite.mene);

  // Effet sur le jeu : ±1 point d'attribut par 10 points d'écart au départ, jamais plus de 2.
  const effets = JSON.parse(vm.run('JSON.stringify([moralEffet(100,50),moralEffet(50,50),moralEffet(56,50),moralEffet(66,50),moralEffet(0,50),moralEffet(42,50)])'));
  assert.deepEqual(effets, [2, 0, 1, 2, -2, -1]);
  const skill = JSON.parse(vm.run(`(()=>{const l=S.live=JSON.parse(__base),u=l.userSide;pilotageMoral(l);const p=activePlayers(l,u)[4],f=l.pilotage.moral.joueurs[p.id];
    PILOTAGE_CACHE={};const base=skill(p,'tackle');f.v=f.depart+30;const haut=skill(p,'tackle');f.v=f.depart-30;const bas=skill(p,'tackle');return JSON.stringify([haut-base,bas-base])})()`));
  assert.deepEqual(skill, [2, -2], 'plaquage : +2 / −2 points au plus');

  // Match complet : le moral bouge, reste dans 0-100, sans emballement.
  const match = JSON.parse(vm.run(`(()=>{const l=S.live=JSON.parse(__base);let k=0;const suivi=[];while(!l.finished&&k++<400){l.paused=false;advanceRugby(l);
      if(l.pilotage.moral)suivi.push(Object.values(l.pilotage.moral.joueurs).map(f=>f.v))}
    const M=l.pilotage.moral.joueurs,v=Object.values(M);
    return JSON.stringify({n:v.length,min:Math.min(...suivi.flat()),max:Math.max(...suivi.flat()),bouges:v.filter(f=>Math.abs(f.v-f.depart)>=1).length,
pics:Math.max(...v.map(f=>Math.abs(f.v-f.depart))),projection:Object.keys(pilotageMoralProjection(l)).length})})()`));
  assert.ok(match.n >= 30, 'les deux XV et les entrants ont un moral : ' + match.n);
  assert.ok(match.min >= 0 && match.max <= 100, 'moral borné : ' + match.min + '-' + match.max);
  assert.ok(match.projection >= 15, 'projection : nos joueurs (' + match.projection + ')');
  console.log('match complet :', JSON.stringify(match));
  vm.run('S.live=JSON.parse(__base);delete globalThis.__base;');
  console.log('match-moral : OK');
} finally {
  jeu.fermer?.();
}
