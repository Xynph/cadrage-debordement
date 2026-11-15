'use strict';
// Règles du jeu du moteur de match (carrière Monde, moteur complet) : vraies quel que soit le tirage, donc vérifiées sur beaucoup de
// matchs de graines et de clubs quelconques, jamais sur un score exact (docs/tests-robustes-20261114.md, catégorie « règle »).
// Un recalibrage des taux (course, finition, pénalité, réussite au but) ne les touche pas ; un vrai défaut de règle (un essai qui ne
// rapporte plus ses 5 points, une transformation comptée deux fois, un joueur de trop sur le terrain) les fait échouer.
// Durée : 36 matchs complets (~25 s). CD_REGLES_MATCHS=n pour une série plus longue.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { context } = require('./monde-harness.cjs');

const N = Number(process.env.CD_REGLES_MATCHS) || 36;
const VM_SOURCE = String.raw`globalThis.__regles=function(o){
 const C=S.clubs.length,date=(S.worldMode.fixtures.find(f=>f.week===S.round)||S.worldMode.fixtures[0]).date,violations=[],bilan={matchs:0,essais:0,points:0};
 for(let i=0;i<o.n;i++){
  const x=(i*7+o.base)%C,y=(x+1+(i*13+o.base)%(C-1))%C,f={id:'regles-'+i,week:S.round,date,homeId:x,awayId:y,competitionId:'elite',phase:'league',round:1,neutral:false};
  const nom=m=>'match '+i+' ('+S.clubs[x].abbr+'-'+S.clubs[y].abbr+') : '+m,bad=m=>{if(violations.length<12)violations.push(nom(m))};
  S.worldMode.fixtures.push(f);let l;
  // À chaque pas du moteur (une minute de jeu), les points marqués sont ceux des essais, transformations et pénalités du pas : 5, 2 et 3.
  const lire=()=>[0,1].map(s=>({pts:l.score[s],tries:l.tries[s],conv:l.stats[s].conversions,goals:l.stats[s].goals,att:l.stats[s].conversionAttempts}));
  try{l=createRugbyMatch([x,y],null,true);let av=lire();
   for(let n=0;!l.finished&&n<700;n++){l.paused=false;advanceRugby(l);const ap=lire();
    for(const s of [0,1]){const dp=ap[s].pts-av[s].pts,dt=ap[s].tries-av[s].tries,dc=ap[s].conv-av[s].conv,dg=ap[s].goals-av[s].goals;
     if(dp!==5*dt+2*dc+3*dg)bad('camp '+s+' à la '+l.minute+'e minute : +'+dp+' points pour '+dt+' essai(s), '+dc+' transformation(s), '+dg+' pénalité(s)');
     if(dt<0||dc<0||dg<0||dp<0)bad('camp '+s+' : un compteur baisse à la '+l.minute+'e minute');
     if(dc>ap[s].att-av[s].att)bad('camp '+s+' : transformation sans tentative à la '+l.minute+'e minute');}
    av=ap;}}
  finally{S.worldMode.fixtures.splice(S.worldMode.fixtures.indexOf(f),1);}
  if(!l.finished)bad('le match ne se termine pas');
  if(l.minute<80)bad('fin avant la 80e minute : '+l.minute);
  for(const s of [0,1]){
   const st=l.stats[s],points=5*l.tries[s]+2*st.conversions+3*st.goals;
   if(l.score[s]!==points)bad('camp '+s+' : score '+l.score[s]+' ≠ 5 × '+l.tries[s]+' essais + 2 × '+st.conversions+' transformations + 3 × '+st.goals+' pénalités = '+points);
   if(st.conversionAttempts!==l.tries[s])bad('camp '+s+' : '+st.conversionAttempts+' transformations tentées pour '+l.tries[s]+' essais');
   if(st.conversions>st.conversionAttempts||st.goals>st.goalAttempts)bad('camp '+s+' : plus de réussites que de tentatives');
   const sh=l.sheets[s],en=sh.on.filter(id=>id!=null).length;
   if(en>15||en<13)bad('camp '+s+' : '+en+' joueurs sur le terrain');
   if(new Set(sh.on.filter(id=>id!=null)).size!==en)bad('camp '+s+' : joueur en double sur le terrain');
   if(new Set(sh.used).size!==sh.used.length)bad('camp '+s+' : joueur utilisé deux fois');
  }
  bilan.matchs++;bilan.essais+=l.tries[0]+l.tries[1];bilan.points+=l.score[0]+l.score[1];
 }
 return JSON.stringify({violations,bilan});
};`;

test('Règles du jeu : score, transformations, effectifs et journal cohérents sur ' + N + ' matchs complets', { timeout: 900000 }, () => {
  const h = context(4242, { club: 102, console: false });
  try {
    assert.equal(h.run('CDWorldEditions.forState(S).mode'), 'world-champ');
    h.run(VM_SOURCE);
    const { violations, bilan } = JSON.parse(h.run(`__regles(${JSON.stringify({ n: N, base: 5 })})`, 1800000));
    assert.equal(bilan.matchs, N);
    // Garde d'exercice : sans essais ni points, les règles ci-dessus ne vérifieraient rien (indépendant des taux : un match en a toujours).
    assert.ok(bilan.essais > 0 && bilan.points > 0, 'le moteur joue et marque');
    assert.deepEqual(violations, [], violations.join('\n'));
  } finally { h.close(); }
});
