'use strict';
// Mesure avant / après du déclenchement des temps forts par l'importance
// (docs/match-importance-20261112.md, § 7). Matchs du harnais : graine k × 7919, club k mod 10.
//   node tools/qa/match-importance-mesure.cjs [nombre de matchs, défaut 200] [niveaux, défaut cles,etendus,dynamique]
// « Avant » : sélection rétrospective précédente (`retrospectif`). Entracte : max(8 s, minutes
// sautées × 1,5 s) à l'horloge normale ; « retenus » : temps forts arrivés avant les 8 s.
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
const ENTRACTE=8,MINUTE=1.5,pc=(a,b)=>b?(100*a/b).toFixed(1)+' %':'—',moy=a=>(a.reduce((x,y)=>x+y,0)/Math.max(1,a.length)).toFixed(1);
console.log('matchs',matchs.length);
for(const niveau of niveaux)for(const retrospectif of [true,false]){
 let ep=0,points=0,essais=0,vus=0,ratt=0,essaisRatt=0,maxEp=0,avantIssue=0,declenches=0,dur=0,retenus=0;
 const quarts=[0,0,0,0],parMatch=[],gaps=[];
 for(const {camp,events} of matchs){
  const b=H.en_direct(events,{niveau,retrospectif,camp});
  essais+=events.filter(e=>e.scene?.kind==='try').length;dur+=b.dureeAction;
  let n=0,episode=0,dernier=null;
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
    if(dernier!==null){const reel=(k-dernier-1)*MINUTE;gaps.push(Math.max(ENTRACTE,reel));if(reel<ENTRACTE)retenus++}
   }
   dernier=k;
  });
  parMatch.push(n);
 }
 console.log(`${niveau.padEnd(9)} ${retrospectif?'avant':'après'} | temps forts/match ${moy(parMatch)} (${Math.min(...parMatch)}–${Math.max(...parMatch)}) | avec point ${pc(points,ep)} | sans point ${pc(ep-points,ep)} | quarts ${quarts.map(q=>Math.round(100*q/ep)).join('/')} % | action ${(dur/matchs.length).toFixed(1)} s/match | épisode max ${Math.round(maxEp)} s | entracte moyen ${moy(gaps)} s, retenus ${pc(retenus,gaps.length)} | essais ${vus}/${essais}`+
  (retrospectif?'':` | rattrapages ${pc(ratt,ep)} des temps forts, ${pc(essaisRatt,essais)} des essais | déclencheur avant l'issue ${pc(avantIssue,declenches)}`));
}
