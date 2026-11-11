'use strict';
const assert=require('node:assert/strict');
const {test}=require('node:test');
const E=require('../native/engine/league-economy.cjs');
const M=require('../native/engine/starting-salaries.cjs');
const B=require('../native/engine/club-budget.cjs');
const noms=Object.keys(E.CHAMPIONNATS);
test('Table : dix championnats, la première division française en référence, parts de recettes à 100 %',()=>{
 assert.deepEqual(noms.slice().sort(),['accession','champ','elite','guest','jlo-d1','jlo-d2','nationale','prem','srp','urc']);
 for(const [nom,c] of Object.entries(E.CHAMPIONNATS)){
  assert.ok(Math.abs(c.partenaires+c.ligue+c.billetterie+c.boutique+c.divers-1)<1e-9,nom);
  assert.ok(c.reputation>=40&&c.reputation<=100&&c.masse>5e5&&c.recettes>c.masse*2.5&&c.bas<1&&c.haut>1&&typeof c.source==='string',nom);
  assert.ok(nom==='elite'||c.reputation<E.CHAMPIONNATS.elite.reputation,'aucun championnat n’est plus réputé que la référence : '+nom);
  assert.ok(Math.abs(c.masse/c.recettes-0.3)<0.03,'un club moyen reste près de l’équilibre : '+nom);
  if(c.plafond!==null)assert.ok(c.plafond>c.masse,'le plafond dépasse la masse moyenne : '+nom);
 }
 assert.ok(E.CHAMPIONNATS.elite.masse>E.CHAMPIONNATS.prem.masse&&E.CHAMPIONNATS.prem.masse>E.CHAMPIONNATS.urc.masse&&E.CHAMPIONNATS.accession.masse>E.CHAMPIONNATS.nationale.masse&&E.CHAMPIONNATS.nationale.masse>E.CHAMPIONNATS.champ.masse);
 assert.deepEqual(Object.keys(B.DIVISIONS).sort(),noms.slice().sort(),'le budget de club connaît chaque championnat');
});
// Un petit monde : quatre clubs par championnat, effectifs identiques d'un championnat à l'autre.
function monde(){
 const forces=noms.flatMap((division,d)=>Array.from({length:4},(_,i)=>({id:d*4+i,division,base:66+i*3})));
 const clubs=forces.map(f=>({id:f.id,players:Array.from({length:44},(_,j)=>({id:'j'+f.id+'-'+j,rating:58+(j*7+f.id)%28,fam:j%9,age:19+(j*5+f.id)%16,salary:5000}))}));
 return {forces,state:{season:1,round:0,live:null,clubs}};
}
const masse=c=>c.players.reduce((s,p)=>s+p.salary,0)*52,moyenne=l=>l.reduce((s,x)=>s+x,0)/l.length;
test('Salaires : la même règle partout, calée sur la masse moyenne de chaque championnat',()=>{
 const {forces,state}=monde();M.apply(state,forces,E);
 assert.equal(state.startingSalaries.version,3);assert.deepEqual(Object.keys(state.startingSalaries.calage).sort(),noms.filter(n=>!E.REFERENCES.includes(n)).sort());
 for(const nom of noms){
  const groupe=state.clubs.filter(c=>forces[c.id].division===nom),m=moyenne(groupe.map(masse));
  if(!E.REFERENCES.includes(nom))assert.ok(Math.abs(m-E.CHAMPIONNATS[nom].masse)/E.CHAMPIONNATS[nom].masse<0.05,nom+' : masse moyenne '+Math.round(m));
  const joueurs=groupe.flatMap(c=>c.players),ma=moyenne(joueurs.map(p=>p.salary)),mb=moyenne(joueurs.map(p=>p.rating));let ab=0,a=0,b=0;
  for(const p of joueurs){ab+=(p.salary-ma)*(p.rating-mb);a+=(p.salary-ma)**2;b+=(p.rating-mb)**2;}
  assert.ok(ab/Math.sqrt(a*b)>0.6,nom+' : le salaire suit le niveau');
  assert.ok(Math.max(...groupe.map(masse))>Math.min(...groupe.map(masse))*1.15,nom+' : les clubs ne paient pas tous pareil');
 }
 assert.ok(masse(state.clubs[noms.indexOf('elite')*4])>masse(state.clubs[noms.indexOf('champ')*4])*4,'un club de la référence paie bien plus qu’un club de deuxième division anglaise');
});
test('Salaires : sans table, les deux championnats de référence donnent exactement le résultat d’avant',()=>{
 const forces=[...Array.from({length:4},(_,i)=>({id:i,division:'elite',base:70+i*4})),...Array.from({length:4},(_,i)=>({id:4+i,division:'accession',base:62+i*3}))];
 const faire=economie=>{const state={season:1,round:0,live:null,clubs:forces.map(f=>({id:f.id,players:Array.from({length:40},(_,j)=>({id:'j'+f.id+'-'+j,rating:58+(j*7+f.id)%28,fam:j%9,age:19+(j*5)%16,salary:1}))}))};M.apply(state,forces,economie);return state;};
 assert.deepEqual(faire(E),faire(null));assert.deepEqual(faire(E).startingSalaries,{version:3,semaines:52});
});
test('Intersaison : les clubs gérés reviennent au niveau du marché, le club joué garde ses contrats',()=>{
 const {forces,state}=monde();M.apply(state,forces,E);
 for(const c of state.clubs)for(const p of c.players)p.salary=6000;
 M.recaler(state,forces,E,{saufClub:5});
 assert.ok(state.clubs[5].players.every(p=>p.salary===6000),'contrats du club joué intacts');
 for(const nom of noms){const groupe=state.clubs.filter(c=>forces[c.id].division===nom&&c.id!==5),m=moyenne(groupe.map(masse));
  assert.ok(Math.abs(m-E.CHAMPIONNATS[nom].masse)/E.CHAMPIONNATS[nom].masse<0.05,nom+' : masse moyenne revenue à la cible ('+Math.round(m)+')');}
 const sans={season:2,round:0,clubs:[{id:0,players:[{id:'a',rating:70,fam:1,age:25,salary:6000}]}]};M.recaler(sans,forces,E);assert.equal(sans.clubs[0].players[0].salary,6000,'carrière non marquée : rien ne bouge');
});
test('Intersaison : le niveau des joueurs monte, la masse du championnat reste à sa cible',()=>{
 const {forces,state}=monde();M.apply(state,forces,E);
 for(const c of state.clubs)for(const p of c.players){p.rating+=2;p.age+=1;}
 const sansEchelle=JSON.parse(JSON.stringify(state)),figee={...E,CHAMPIONNATS:{}};M.recaler(sansEchelle,forces,figee);M.recaler(state,forces,E);
 for(const nom of noms){const de=x=>moyenne(x.clubs.filter(c=>forces[c.id].division===nom).map(masse)),cible=E.CHAMPIONNATS[nom].masse;
  if(!E.REFERENCES.includes(nom))assert.ok(de(sansEchelle)>cible*1.15,nom+' : avec l’échelle de la création, la masse dérive ('+Math.round(de(sansEchelle))+')');
  assert.ok(Math.abs(de(state)-cible)/cible<0.05,nom+' : échelle recalculée, masse à la cible ('+Math.round(de(state))+')');}
 assert.ok(state.startingSalaries.calage.elite>0&&state.startingSalaries.calage.champ<sansEchelle.startingSalaries.calage.champ);
});
test('Montée et descente : clauses de contrat variées, jamais uniformes',()=>{
 const ids=Array.from({length:2000},(_,i)=>'j'+i),bas=ids.map(i=>M.clause(i,-1)),haut=ids.map(i=>M.clause(i,1));
 assert.ok(bas.every(x=>x<=1&&x>=0.75)&&haut.every(x=>x>=1&&x<=1.2));assert.ok(ids.every(i=>M.clause(i,0)===1));
 const part=(l,v)=>l.filter(x=>x===v).length/l.length;assert.ok(Math.abs(part(bas,1)-0.3)<0.04,'trois joueurs sur dix sans clause de descente');assert.ok(Math.abs(part(haut,1)-0.4)<0.04);
 assert.ok(new Set(bas).size>10&&new Set(haut).size>10);assert.ok(Math.abs(moyenne(bas)-0.885)<0.02&&Math.abs(moyenne(haut)-1.075)<0.02,'en moyenne −11 % à la descente, +7 % à la montée');
 const {forces,state}=monde();M.apply(state,forces,E);const elite=noms.indexOf('elite')*4,avant=masse(state.clubs[elite]);
 const r=M.clauses(state,elite,-1);assert.equal(r.avant,avant);assert.equal(r.apres,masse(state.clubs[elite]));assert.ok(r.apres<r.avant*0.93&&r.apres>r.avant*0.82&&r.touches>20);
 const h=M.clauses(state,elite+1,1);assert.ok(h.apres>h.avant*1.04&&h.apres<h.avant*1.12);
 assert.deepEqual(M.clauses({clubs:[{id:0,players:[{id:'a',salary:500}]}]},0,-1),{avant:0,apres:0,touches:0},'carrière non marquée : rien');
 // Club géré relégué : ses salaires de la saison portent la clause.
 const a=monde(),b=monde();M.apply(a.state,a.forces,E);M.apply(b.state,b.forces,E);M.recaler(a.state,a.forces,E,{});M.recaler(b.state,b.forces,E,{mouvements:new Map([[elite,-1]])});
 assert.ok(masse(b.state.clubs[elite])<masse(a.state.clubs[elite])*0.94);assert.equal(masse(b.state.clubs[elite+8]),masse(a.state.clubs[elite+8]),'les autres clubs ne sont pas touchés');
});
test('Limites : personne au-dessus à la création, marge propre à chaque club, dépassement voulu rare',()=>{
 const forces=noms.flatMap((division,d)=>Array.from({length:4},(_,i)=>({id:d*4+i,division,base:66+i*3}))),R=B.recettes(forces);
 const creation=B.limites(forces,1,{creation:true});assert.equal(creation.size,40);
 for(const [id,l] of creation){const c=E.CHAMPIONNATS[forces[id].division];assert.ok(l.tolerance>=0.93&&l.tolerance<1&&!l.audace);
  if(c.plafond!==null)assert.ok(l.limite<c.plafond,'sous le plafond : '+id);if(c.ratio)assert.ok(l.limite<R.get(id)*0.52);assert.ok(['plafond','recettes','budget'].includes(l.regle));}
 assert.ok(new Set([...creation.values()].map(l=>l.tolerance.toFixed(3))).size>25);
 let audaces=0,total=0;for(let saison=2;saison<40;saison++)for(const [id,l] of B.limites(forces,saison)){total++;if(l.audace){audaces++;assert.ok(l.tolerance>1&&l.tolerance<=1.05);assert.equal(B.proprietaire(forces,id).type,'mecene');}}
 assert.ok(audaces>0&&audaces/total<0.08,'dépassement voulu rare : '+audaces+' sur '+total);
 // À la création, un club que la règle placerait au-dessus est ramené juste sous sa limite.
 const {state}=monde(),riche=noms.indexOf('elite')*4+3;for(const p of state.clubs[riche].players)p.rating=88;
 M.apply(state,forces,E,creation);const m=masse(state.clubs[riche]);assert.ok(m<=creation.get(riche).limite*1.01&&m>creation.get(riche).limite*0.97,'club riche à '+Math.round(m)+' pour une limite de '+creation.get(riche).limite);
 assert.equal(M.plancherHebdo(state,'elite'),270);assert.equal(M.plancherHebdo(state,'champ'),150);
});
test('Demande salariale : selon le niveau et le championnat du club qui recrute',()=>{
 const {forces,state}=monde();M.apply(state,forces,E);const joueur={id:'recrue',rating:78,fam:3,age:27,salary:9000};
 const chez=nom=>M.demande(state,forces,noms.indexOf(nom)*4+2,joueur,E);
 assert.ok(chez('elite')>chez('accession')*0.9&&chez('elite')>chez('champ')*2&&chez('prem')>chez('nationale'));
 assert.equal(chez('elite'),chez('elite'));assert.ok(M.demande(state,forces,2,{...joueur,rating:60},E)<chez('elite')/3);
 assert.throws(()=>M.demande(state,forces,999,joueur,E),/club inconnu/);
});
const taux=(origine,destination,age=27,n=4000)=>moyenne(Array.from({length:n},(_,i)=>E.attrait({origine,destination,joueurId:'j'+i,age}).multiplicateur));
test('Attrait : monter coûte moins cher au club, descendre coûte une prime, effet modéré',()=>{
 const monter=taux('champ','elite'),descendre=taux('elite','champ'),voisin=taux('prem','urc'),meme=taux('elite','elite');
 assert.ok(monter<0.97&&monter>0.9,'vers la référence : '+monter);assert.ok(descendre>1.1&&descendre<1.25,'vers un championnat bien moins réputé : '+descendre);
 assert.ok(Math.abs(meme-1)<0.005&&voisin>1&&voisin<1.08);
 assert.ok(taux('accession','elite')<taux('accession','prem')&&taux('accession','prem')<taux('accession','nationale'),'plus le championnat est réputé, moins le joueur demande');
 for(const o of [...noms,null])for(const d of noms)for(let i=0;i<40;i++){const a=E.attrait({origine:o,destination:d,joueurId:'x'+i,age:20+i%18});assert.ok(a.multiplicateur>=0.85&&a.multiplicateur<=1.3);}
 assert.throws(()=>E.attrait({origine:'elite',destination:'inconnu',joueurId:'a',age:25}),/inconnu/);
});
test('Attrait : pas de règle uniforme — casaniers, voyageurs, fins de carrière au Japon',()=>{
 const tous=Array.from({length:3000},(_,i)=>E.attrait({origine:'accession',destination:'prem',joueurId:'j'+i,age:26}));
 const par=p=>moyenne(tous.filter(a=>a.profil===p).map(a=>a.multiplicateur));
 assert.ok(['casanier','voyageur','ambitieux','neutre'].every(p=>tous.filter(a=>a.profil===p).length>250));
 assert.ok(par('casanier')>par('neutre')+0.05&&par('voyageur')<par('neutre')-0.02&&par('ambitieux')<par('neutre'),'tempéraments : '+['casanier','voyageur','ambitieux','neutre'].map(par));
 assert.ok(tous.some(a=>a.multiplicateur>1)&&tous.some(a=>a.multiplicateur<0.95),'pour une même montée, certains demandent plus, d’autres moins');
 assert.ok(taux('elite','jlo-d1',33)<taux('elite','jlo-d1',26)-0.1,'le Japon attire les joueurs de 31 ans et plus');assert.ok(taux('elite','jlo-d1',33)<1&&taux('elite','jlo-d1',26)>1.05);
 assert.equal(E.temperament('abc'),E.temperament('abc'));
});
test('Attrait : rien ne dépend du niveau du joueur',()=>{
 assert.equal(E.attrait.length,1);assert.deepEqual(E.attrait({origine:'urc',destination:'elite',joueurId:'p1',age:25,rating:99,potential:99}),E.attrait({origine:'urc',destination:'elite',joueurId:'p1',age:25,rating:40,potential:40}));
 assert.ok(!/rating|potential|niveau du joueur =/.test(E.attrait.toString().replace(/\/\/.*$/gm,'')));
});
test('Origine d’un joueur du marché : dernier club connu, sinon identifiant de la base, sinon inconnue',()=>{
 const ligue=id=>id===3?'urc':null;
 assert.equal(E.origine({id:'x',population:{clubId:3}},ligue),'urc');assert.equal(E.origine({id:'world:srp:p-12'},ligue),'srp');assert.equal(E.origine({id:'world:jlo:ab'},ligue),'jlo-d1');
 assert.equal(E.origine({id:'small-1-0-0',population:{clubId:null}},ligue),null);assert.equal(E.origine({id:'world:zzz:1'},ligue),null);assert.equal(E.origine(null,ligue),null);
});
test('Budget : chaque championnat a ses recettes, son plafond s’il existe, et la règle des 52 % seulement en France',()=>{
 const forces=noms.flatMap((division,d)=>Array.from({length:4},(_,i)=>({id:d*4+i,division,base:66+i*3}))),R=B.recettes(forces);
 for(const [d,nom] of noms.entries()){
  assert.ok(Math.abs(moyenne([0,1,2,3].map(i=>R.get(d*4+i)))-E.CHAMPIONNATS[nom].recettes)<1,nom);
  const regle=B.regles({division:nom,masseAnnuelle:E.CHAMPIONNATS[nom].masse*3,recettes:E.CHAMPIONNATS[nom].recettes});
  assert.equal(regle.plafond,E.CHAMPIONNATS[nom].plafond);assert.equal(regle.limiteRecettes===null,!E.CHAMPIONNATS[nom].ratio,nom);
  assert.equal(regle.amende>0,E.CHAMPIONNATS[nom].plafond!==null||E.CHAMPIONNATS[nom].ratio,nom+' : amende seulement là où une règle existe');
  let total=0;for(let s=0;s<46;s++)total+=B.semaine({forces,clubId:d*4+1,masseHebdo:E.CHAMPIONNATS[nom].masse/52,semaines:46,receptions:9,domicile:s<18&&s%2===0,alea:0.5,libelle:'S'}).reduce((x,e)=>x+e.amount,0);
  total+=B.primeClassement(nom,2,4);assert.ok(Math.abs(total)<E.CHAMPIONNATS[nom].recettes*0.12,nom+' : saison type proche de l’équilibre ('+Math.round(total)+')');
 }
});
