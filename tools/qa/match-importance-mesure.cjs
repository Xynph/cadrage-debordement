'use strict';
// Mesure avant / après du déclenchement des temps forts par l'importance
// (docs/match-importance-20261112.md, § 7). Matchs du harnais : graine k × 7919, club k mod 10.
//   node tools/qa/match-importance-mesure.cjs [nombre de matchs, défaut 200] [niveaux, défaut cles,etendus,dynamique]
// « Avant » : sélection rétrospective précédente (`retrospectif`). Entracte : minutes sautées
// × 1,5 s à l'horloge normale, sans pause minimale (décision de Léo, 12 novembre 2026) ;
// « enchaînés » : temps fort qui part à la minute qui suit le précédent (aucune minute en 2D).
const path=require('node:path');
const {context}=require(path.resolve(__dirname,'../../tests/harness.cjs'));
const H=require(path.resolve(__dirname,'../../native/engine/match-highlights.cjs'));
const nombre=Number(process.argv[2]||200),niveaux=(process.argv[3]||'cles,etendus,dynamique').split(',');
const matchs=[];
for(let k=0;k<nombre;k++){
 const {run}=context();
 run(`for (let i = 0; i < ${k*7919}; i++) Math.random(); start(${k%10}); beginMatch(); continueMatch();`);
 for(let i=0;i<800&&!run('S.live.finished');i++)run('if (S.live.paused) continueMatch(); presentationTick(S.live);');
 matchs.push({camp:run('S.live.userSide'),events:JSON.parse(run('JSON.stringify(S.live.events)'))});
}
const quant=(a,q)=>{a=[...a].sort((x,y)=>x-y);return a.length?a[Math.min(a.length-1,Math.floor(q*a.length))]:0};
const ENTRACTE=0,MINUTE=1.5,pc=(a,b)=>b?(100*a/b).toFixed(1)+' %':'—',moy=a=>(a.reduce((x,y)=>x+y,0)/Math.max(1,a.length)).toFixed(1);
console.log('matchs',matchs.length);
for(const niveau of niveaux)for(const retrospectif of [true,false]){
 let ep=0,points=0,essais=0,vus=0,ratt=0,essaisRatt=0,maxEp=0,avantIssue=0,declenches=0,dur=0,retenus=0;
 const quarts=[0,0,0,0],parMatch=[],gaps=[],ecarts=[];let consecutifs=0;
 for(const {camp,events} of matchs){
  const b=H.en_direct(events,{niveau,retrospectif,camp});
  essais+=events.filter(e=>e.scene?.kind==='try').length;dur+=b.dureeAction;
  let n=0,episode=0,dernier=null,finPrec=null;
  b.decisions.forEach((d,k)=>{
   if(!d.joue)return;
   const tf=d.tempsFort;vus+=tf.plans.filter(p=>p.kind==='try').length;
   episode=tf.suite?episode+tf.duree:tf.duree;maxEp=Math.max(maxEp,episode);
   if(!tf.suite){
    n++;ep++;
    if(tf.plans.some(p=>p.kind==='try'||p.kind==='goal'))points++;
    if(tf.rattrapage){ratt++;essaisRatt+=tf.plans.filter(p=>p.kind==='try').length}
    if(tf.declencheur!=null){declenches++;if(tf.declencheur<=tf.plans.filter(p=>p.kind!=='transformation').at(-1).i)avantIssue++}
    quarts[Math.min(3,Math.floor(tf.minuteDebut/20))]++;
    if(dernier!==null){const reel=(k-dernier-1)*MINUTE;gaps.push(Math.max(ENTRACTE,reel));if(reel===0)retenus++}
    // Écart de jeu entre deux temps forts (minutes de match, de la fin de l'un au début du suivant).
    if(finPrec!==null&&finPrec.periode===tf.periode){const e=tf.minuteDebut-finPrec.minute;ecarts.push(e);if(e<=1)consecutifs++}
   }
   dernier=k;finPrec={periode:tf.periode,minute:tf.minuteFin};
  });
  parMatch.push(n);
 }
 console.log(`${niveau.padEnd(9)} ${retrospectif?'avant':'après'} | temps forts/match ${moy(parMatch)} (min ${Math.min(...parMatch)}, méd. ${quant(parMatch,.5)}, max ${Math.max(...parMatch)}, p10–p90 ${quant(parMatch,.1)}–${quant(parMatch,.9)}) | écart entre temps forts (min de jeu) méd. ${quant(ecarts,.5)}, p10 ${quant(ecarts,.1)}, p90 ${quant(ecarts,.9)}, max ${Math.max(...ecarts)} | consécutifs (≤ 1 min) ${pc(consecutifs,ecarts.length)} | avec point ${pc(points,ep)} | sans point ${pc(ep-points,ep)} | quarts ${quarts.map(q=>Math.round(100*q/ep)).join('/')} % | action ${(dur/matchs.length).toFixed(1)} s/match | épisode max ${Math.round(maxEp)} s | entracte moyen ${moy(gaps)} s (médiane ${quant(gaps,.5)} s, p90 ${quant(gaps,.9)} s), enchaînés ${pc(retenus,gaps.length)} | essais ${vus}/${essais}`+
  (retrospectif?'':` | rattrapages ${pc(ratt,ep)} des temps forts, ${pc(essaisRatt,essais)} des essais | déclencheur avant l'issue ${pc(avantIssue,declenches)}`));
}
