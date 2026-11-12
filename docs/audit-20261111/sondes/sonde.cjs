// Sonde en lecture seule : cherche ce qui, dans le modèle envoyé à l'interface,
// reste corrélé aux qualités cachées des joueurs non observés.
function analyze(model,S,log=console.log){
const console={log};
const isO=x=>x&&typeof x==='object'&&!Array.isArray(x);
// vérité
const truth=new Map();
(function walk(v){if(Array.isArray(v)){v.forEach(walk);return;}if(!isO(v))return;
 if(typeof v.id==='string'&&typeof v.rating==='number'&&typeof v.pos==='string'&&!truth.has(v.id))truth.set(v.id,{rating:v.rating,potential:v.dev?.potential??v.potential??null,name:v.name,salary:v.salary??null});
 for(const k in v)walk(v[k]);})(S);
const owned=new Set((S.clubs[S.club].players||[]).map(p=>p.id));
console.log('joueurs vérité:',truth.size,'du club:',owned.size);
// état de connaissance annoncé par le modèle
const stageOf=new Map();
(function walk(v){if(Array.isArray(v)){v.forEach(walk);return;}if(!isO(v))return;const pid=typeof v.playerId==='string'?v.playerId:v.id;if(typeof pid==='string'&&v.knowledge?.stage&&!stageOf.has(pid))stageOf.set(pid,v.knowledge.stage);for(const k in v)walk(v[k]);})(model);
const st={};for(const s of stageOf.values())st[s]=(st[s]||0)+1;console.log('stades:',JSON.stringify(st));
// collecte
const num=new Map(),str=new Map(),orders=[],idless=new Map();
const push=(m,k,row)=>{let a=m.get(k);if(!a)m.set(k,a=[]);a.push(row);};
function collect(v,pid,rel,depth){ // champs d'un joueur
 for(const k in v){const x=v[k],p=rel?rel+'.'+k:k;
  if(typeof x==='number')push(num,p,[x,pid]);
  else if(typeof x==='string'&&k!=='id'&&k!=='playerId'&&k!=='name')push(str,p,[x,pid]);
  else if(isO(x)&&depth<2&&!(typeof x.id==='string'&&truth.has(x.id))&&!(typeof x.playerId==='string'))collect(x,pid,p,depth+1);}
}
const LV=['rating','note','roleNote','overall','quality','level','currentAbility','potential','ovr','pot','stars','value'];
(function walk(v,p){
 if(Array.isArray(v)){
  const ids=v.map(e=>isO(e)?(typeof e.playerId==='string'?e.playerId:e.id):typeof e==='string'?e:null);
  const hid=ids.filter(i=>typeof i==='string'&&truth.has(i)&&!owned.has(i));
  if(hid.length>=10&&hid.length>=ids.length*0.8)orders.push([p,ids.filter(i=>truth.has(i))]);
  v.forEach(e=>walk(e,p+'[]'));return;}
 if(!isO(v))return;
 const pid=typeof v.playerId==='string'&&truth.has(v.playerId)?v.playerId:typeof v.id==='string'&&truth.has(v.id)?v.id:null;
 if(pid&&!owned.has(pid)&&(stageOf.get(pid)??'unobserved')==='unobserved')collect(v,pid,p.replace(/\[\]/g,'').split('.').slice(-2).join('.')+'>',0);
 if(!pid)for(const k of LV)if(typeof v[k]==='number'&&(typeof v.name==='string'||typeof v.pos==='string'))push(idless,p+'.'+k,[v[k],v.name,v.pos]);
 for(const k in v)walk(v[k],p+'.'+k);
})(model,'');
const pear=(a,b)=>{const n=a.length,ma=a.reduce((s,x)=>s+x,0)/n,mb=b.reduce((s,x)=>s+x,0)/n;let sab=0,sa=0,sb=0;for(let i=0;i<n;i++){sab+=(a[i]-ma)*(b[i]-mb);sa+=(a[i]-ma)**2;sb+=(b[i]-mb)**2;}return sa&&sb?sab/Math.sqrt(sa*sb):0;};
const rank=a=>{const o=a.map((x,i)=>[x,i]).sort((p,q)=>p[0]-q[0]),r=[];o.forEach(([,i],k)=>r[i]=k);return r;};
console.log('\n== Champs numériques des joueurs NON observés corrélés au niveau ou au potentiel réels (n>=30, |r|>=0.4) ==');
const out=[];for(const [k,rows] of num){if(rows.length<30)continue;const xs=rows.map(r=>r[0]),tr=rows.map(r=>truth.get(r[1]).rating),tp=rows.map(r=>truth.get(r[1]).potential??truth.get(r[1]).rating);if(new Set(xs).size<2)continue;const r1=pear(xs,tr),r2=pear(xs,tp),eq=rows.filter(r=>r[0]===truth.get(r[1]).rating).length/rows.length;if(Math.abs(r1)>=0.4||Math.abs(r2)>=0.4||eq>0.5)out.push([k,rows.length,r1,r2,eq]);}
out.sort((a,b)=>Math.abs(b[2])-Math.abs(a[2]));for(const o of out.slice(0,60))console.log(o[0].padEnd(64),'n='+String(o[1]).padEnd(6),'r_niveau='+o[2].toFixed(2),'r_potentiel='+o[3].toFixed(2),'égal='+(o[4]*100).toFixed(0)+'%');
console.log('\n== Champs texte catégoriels expliquant le niveau (n>=30, 2..15 valeurs, R²>=0.15) ==');
for(const [k,rows] of str){if(rows.length<30)continue;const g=new Map();for(const [x,pid] of rows)push(g,x,truth.get(pid).rating);if(g.size<2||g.size>15)continue;const all=rows.map(r=>truth.get(r[1]).rating),m=all.reduce((s,x)=>s+x,0)/all.length,tot=all.reduce((s,x)=>s+(x-m)**2,0);let bet=0;for(const a of g.values()){const mm=a.reduce((s,x)=>s+x,0)/a.length;bet+=a.length*(mm-m)**2;}const r2=tot?bet/tot:0;if(r2>=0.15)console.log(k.padEnd(64),'n='+rows.length,'R²='+r2.toFixed(2),JSON.stringify([...g].map(([x,a])=>[x.slice(0,28),a.length,+(a.reduce((s,y)=>s+y,0)/a.length).toFixed(1)]).slice(0,8)));}
console.log('\n== Textes libres contenant le niveau réel en chiffres (taux) ==');
for(const [k,rows] of str){if(rows.length<30)continue;const withDigits=rows.filter(r=>/\d/.test(r[0]));if(withDigits.length<10)continue;const hit=rows.filter(([x,pid])=>new RegExp('(^|\\D)'+Math.round(truth.get(pid).rating)+'(\\D|$)').test(x)).length;if(hit/rows.length>0.25)console.log(k.padEnd(64),'n='+rows.length,'contient le niveau='+(hit/rows.length*100).toFixed(0)+'%','ex:',JSON.stringify(rows[0][0]).slice(0,120));}
console.log('\n== Listes de joueurs extérieurs dont l\'ordre suit le niveau réel (|rho|>=0.5) ==');
for(const [p,ids] of orders){const r=pear(rank(ids.map((_,i)=>i)),rank(ids.map(i=>truth.get(i).rating)));const hidden=ids.filter(i=>!owned.has(i)&&(stageOf.get(i)??'unobserved')==='unobserved').length;if(Math.abs(r)>=0.5)console.log(p.slice(-90).padEnd(92),'n='+ids.length,'non observés='+hidden,'rho='+r.toFixed(2));}
console.log('\n== Objets sans identifiant de joueur qui gardent une note ==');
for(const [k,rows] of [...idless].sort((a,b)=>b[1].length-a[1].length).slice(0,40))console.log(k.slice(-100).padEnd(102),'n='+rows.length,'ex:',JSON.stringify(rows[0]));

return {truth,owned,stageOf,num,str};}
module.exports={analyze};
