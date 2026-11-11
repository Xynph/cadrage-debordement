'use strict';
const assert=require('node:assert/strict');
const {spawnSync}=require('node:child_process');
const fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const {test}=require('node:test');
const salaires=require('../native/engine/starting-salaries.cjs');
const forces=[...Array.from({length:14},(_,i)=>({id:i,division:'elite',base:70+i})),...Array.from({length:16},(_,i)=>({id:14+i,division:'accession',base:60+i}))];
const moyenne=liste=>liste.reduce((s,x)=>s+x,0)/liste.length;
test('Masses visées : moyenne exacte par division, écart borné, club fort mieux doté',()=>{
 const m=salaires.masses(forces),elite=forces.slice(0,14).map(c=>m.get(c.id)),accession=forces.slice(14).map(c=>m.get(c.id));
 assert.ok(Math.abs(moyenne(elite)-9.9e6)<1);assert.ok(Math.abs(moyenne(accession)-3.2e6)<1);
 assert.ok(Math.max(...elite)/Math.min(...elite)<2.3&&Math.max(...accession)/Math.min(...accession)<3.5);
 assert.ok(elite[13]>elite[0]&&accession[15]>accession[0]&&Math.min(...elite)>Math.max(...accession));
});
test('Répartition : le salaire suit le niveau, la masse du club est respectée, une seule application',()=>{
 const joueurs=Array.from({length:40},(_,i)=>({id:'j'+i,rating:55+i,salary:9999}));
 const etat={season:1,round:0,live:null,clubs:[{id:0,players:joueurs}]};
 salaires.apply(etat,forces,34);
 const masse=joueurs.reduce((s,j)=>s+j.salary,0)*34,cible=salaires.masses(forces).get(0);
 assert.ok(Math.abs(masse-cible)/cible<0.01,'masse à 1 % de la cible');
 assert.ok(joueurs[39].salary>joueurs[20].salary*1.5&&joueurs[20].salary>joueurs[0].salary,'le meilleur gagne nettement plus');
 assert.ok(joueurs.every(j=>j.salary>=250&&j.salary%10===0));
 const avant=JSON.stringify(etat);salaires.apply(etat,forces,34);assert.equal(JSON.stringify(etat),avant,'idempotent');
 assert.throws(()=>salaires.apply({season:2,round:0,clubs:[]},forces,34),/création/);
});
const sonde=`const {createBridge}=require('./native/engine/worker.cjs');const fs=require('fs'),os=require('os'),path=require('path');
const b=createBridge({dataDir:fs.mkdtempSync(path.join(os.tmpdir(),'rl27-sal-')),seed:27,now:1794178800000,dailyCalendar:true});
const r=b.handle({id:1,command:'new_career',payload:{mode:'common',club:29}});if(!r.ok)throw Error(r.error);
const S=JSON.parse(b.handle({id:2,command:'export',payload:{}}).model.meta.exportText).state;b.close();
const t=S.clubs.flatMap(c=>c.players),n=t.length,ma=t.reduce((s,p)=>s+p.salary,0)/n,mb=t.reduce((s,p)=>s+p.rating,0)/n;let ab=0,a=0,c=0;for(const p of t){ab+=(p.salary-ma)*(p.rating-mb);a+=(p.salary-ma)**2;c+=(p.rating-mb)**2;}
const an=k=>k.players.reduce((s,p)=>s+p.salary,0)*34;const top=[...S.clubs[0].players].sort((x,y)=>y.rating-x.rating);
console.log(JSON.stringify({marque:S.startingSalaries??null,correlation:ab/Math.sqrt(a*c),elite:S.clubs.slice(0,14).reduce((s,k)=>s+an(k),0)/14,accession:S.clubs.slice(14).reduce((s,k)=>s+an(k),0)/16,meilleur:top[0].salary,dernier:top[top.length-1].salary}));`;
function creer(drapeau){
 const r=spawnSync(process.execPath,['-e',sonde],{cwd:path.resolve(__dirname,'..'),encoding:'utf8',timeout:120000,env:{...process.env,CD_SALAIRES_PAR_NIVEAU:drapeau}});
 assert.equal(r.status,0,r.stderr.slice(-800));return JSON.parse(r.stdout.trim().split('\n').pop());
}
test('Vrai moteur, drapeau éteint : rien ne change',()=>{const x=creer('0');assert.equal(x.marque,null);assert.ok(Math.abs(x.correlation)<0.1);});
test('Vrai moteur, drapeau allumé : salaires liés au niveau et masses par division',()=>{
 const x=creer('1');assert.deepEqual(x.marque,{version:1,semainesPayees:34});
 assert.ok(x.correlation>0.8,'corrélation '+x.correlation);
 assert.ok(Math.abs(x.elite-9.9e6)/9.9e6<0.01&&Math.abs(x.accession-3.2e6)/3.2e6<0.01);
 assert.ok(x.meilleur>x.dernier*2,'le meilleur joueur du premier club gagne plus du double du moins bon');
});
