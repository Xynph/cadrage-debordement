'use strict';
const assert=require('node:assert/strict');
const {spawnSync}=require('node:child_process');
const path=require('node:path');
const {test}=require('node:test');
const M=require('../native/engine/starting-salaries.cjs');
const forces=[...Array.from({length:14},(_,i)=>({id:i,division:'elite',base:70+i})),...Array.from({length:16},(_,i)=>({id:14+i,division:'accession',base:60+i}))];
test('Référence : croît avec le niveau, bornée aux extrémités',()=>{
 for(let n=46;n<=99;n++)assert.ok(M.reference(n)>M.reference(n-1));
 assert.equal(M.reference(20),M.reference(45));assert.equal(M.reference(120),M.reference(99));
});
test('Politique des clubs : un club fort paie plus, chaque club a son tempérament',()=>{
 const p=M.politiques(forces);assert.ok(p.get(13)>p.get(0)&&p.get(29)>p.get(14));
 assert.ok([...p.values()].every(x=>x>0.75&&x<1.4));assert.ok(new Set([...p.values()].map(x=>x.toFixed(3))).size>20);
});
test('Variété : à niveau, poste, âge et club égaux, des joueurs sous-payés et surpayés',()=>{
 const annuels=Array.from({length:400},(_,i)=>M.detail({id:'j'+i,rating:75,fam:3,age:27},1).annuel).sort((a,b)=>a-b);
 assert.ok(annuels[399]>annuels[0]*2.2,'écart d’au moins 2,2 entre extrêmes');
 const ref=M.reference(75);assert.ok(annuels.filter(a=>a<ref*0.8).length>40&&annuels.filter(a=>a>ref*1.25).length>40);
 assert.ok(Math.abs(annuels[200]-ref*1.04)/ref<0.14,'la médiane reste proche de la référence');
 assert.deepEqual(M.detail({id:'x',rating:75,fam:3,age:27},1),M.detail({id:'x',rating:75,fam:3,age:27},1),'déterministe');
 assert.ok(M.detail({id:'star',rating:99,fam:2,age:31},1.3).annuel<=800000);
});
test('Application : une seule fois, à la création seulement',()=>{
 const etat={season:1,round:0,live:null,clubs:[{id:0,players:[{id:'a',rating:80,fam:5,age:27,salary:1},{id:'b',rating:62,fam:1,age:20,salary:1}]}]};
 M.apply(etat,forces);assert.ok(etat.clubs[0].players[0].salary>etat.clubs[0].players[1].salary*3);
 const avant=JSON.stringify(etat);M.apply(etat,forces);assert.equal(JSON.stringify(etat),avant);
 assert.throws(()=>M.apply({season:2,round:0,clubs:[]},forces),/création/);
});
const sonde=`const {createBridge}=require('./native/engine/worker.cjs');const fs=require('fs'),os=require('os'),path=require('path');
const b=createBridge({dataDir:fs.mkdtempSync(path.join(os.tmpdir(),'rl27-sal-')),seed:27,now:1794178800000,dailyCalendar:true});
const r=b.handle({id:1,command:'new_career',payload:{mode:'common',club:29}});if(!r.ok)throw Error(r.error);
const S=JSON.parse(b.handle({id:2,command:'export',payload:{}}).model.meta.exportText).state;b.close();
const t=S.clubs.flatMap(c=>c.players),n=t.length,ma=t.reduce((s,p)=>s+p.salary,0)/n,mb=t.reduce((s,p)=>s+p.rating,0)/n;let ab=0,a=0,c=0;for(const p of t){ab+=(p.salary-ma)*(p.rating-mb);a+=(p.salary-ma)**2;c+=(p.rating-mb)**2;}
const an=k=>k.players.reduce((s,p)=>s+p.salary,0)*52,m75=t.filter(p=>p.rating===75).map(p=>p.salary);
console.log(JSON.stringify({marque:S.startingSalaries??null,correlation:ab/Math.sqrt(a*c),elite:S.clubs.slice(0,14).reduce((s,k)=>s+an(k),0)/14,accession:S.clubs.slice(14).reduce((s,k)=>s+an(k),0)/16,ecart75:Math.max(...m75)/Math.min(...m75)}));`;
function creer(drapeau){
 const r=spawnSync(process.execPath,['-e',sonde],{cwd:path.resolve(__dirname,'..'),encoding:'utf8',timeout:120000,env:{...process.env,CD_SALAIRES_PAR_NIVEAU:drapeau}});
 assert.equal(r.status,0,r.stderr.slice(-800));return JSON.parse(r.stdout.trim().split('\n').pop());
}
test('Vrai moteur, drapeau éteint : rien ne change',()=>{const x=creer('0');assert.equal(x.marque,null);assert.ok(Math.abs(x.correlation)<0.1);});
test('Vrai moteur, drapeau allumé : salaires liés au niveau, variés, masses réalistes',()=>{
 const x=creer('1');assert.deepEqual(x.marque,{version:3,semaines:52});
 assert.ok(x.correlation>0.7&&x.correlation<0.95,'lié au niveau sans être mécanique : '+x.correlation);
 assert.ok(x.elite>8e6&&x.elite<11.5e6,'masse moyenne en première division : '+x.elite);
 assert.ok(x.accession>2.4e6&&x.accession<4e6,'masse moyenne en deuxième division : '+x.accession);
 assert.ok(x.ecart75>2.5,'à niveau 75, écart de salaire d’au moins 2,5 : '+x.ecart75);
});
test('Contrats espoirs : hors du noyau, un joueur de 22 ans ou moins a un salaire d’espoir',()=>{
 const joueurs=[...Array.from({length:M.NOYAU},(_,i)=>({id:'pro'+i,rating:85-i%10,fam:3,age:27})),{id:'jeune',rating:70,fam:3,age:20},{id:'ancien',rating:70,fam:3,age:29},{id:'pepite',rating:90,fam:5,age:20}];
 const s=M.club(joueurs,'elite',1);
 assert.equal(s.get('jeune').espoir,true);assert.ok(s.get('jeune').annuel<=60000);
 assert.equal(s.get('ancien').espoir,false,'un joueur installé hors du noyau reste professionnel');
 assert.equal(s.get('pepite').espoir,false,'un jeune dans les meilleurs du club est payé en professionnel');
 assert.ok(s.get('pepite').annuel>s.get('jeune').annuel*4);
});
