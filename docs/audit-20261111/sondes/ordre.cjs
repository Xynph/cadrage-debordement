const dir=process.argv[2],m=require(dir+'/model.json'),S=require(dir+'/state.json');
const isO=x=>x&&typeof x==='object'&&!Array.isArray(x);
const truth=new Map();(function w(v){if(Array.isArray(v)){v.forEach(w);return;}if(!isO(v))return;if(typeof v.id==='string'&&typeof v.rating==='number'&&typeof v.pos==='string'&&!truth.has(v.id))truth.set(v.id,v);for(const k in v)w(v[k]);})(S);
const clubOf=new Map();S.clubs.forEach(c=>(c.players||[]).forEach(p=>clubOf.set(p.id,c.id)));
const pear=(a,b)=>{const n=a.length,ma=a.reduce((s,x)=>s+x,0)/n,mb=b.reduce((s,x)=>s+x,0)/n;let sab=0,sa=0,sb=0;for(let i=0;i<n;i++){sab+=(a[i]-ma)*(b[i]-mb);sa+=(a[i]-ma)**2;sb+=(b[i]-mb)**2;}return sa&&sb?sab/Math.sqrt(sa*sb):0;};
const rank=a=>{const o=a.map((x,i)=>[x,i]).sort((p,q)=>p[0]-q[0]),r=[];o.forEach(([,i],k)=>r[i]=k);return r;};
for(const [name,list] of [['interclubMarket.candidates',m.clubLife.interclubMarket.candidates],['coachNotebook.targets',m.clubLife.coachNotebook.targets]]){
 const ids=list.map(e=>e.playerId??e.id).filter(i=>truth.has(i));
 const groups=new Map();ids.forEach((i,k)=>{const c=clubOf.get(i)??'hors club';if(!groups.has(c))groups.set(c,[]);groups.get(c).push([k,truth.get(i).rating]);});
 const rs=[];for(const g of groups.values())if(g.length>=8)rs.push(pear(rank(g.map(x=>x[0])),rank(g.map(x=>x[1]))));
 console.log(name,'n='+ids.length,'groupes='+rs.length,'rho intra-club moyen='+(rs.reduce((s,x)=>s+x,0)/rs.length).toFixed(2),'min='+Math.min(...rs).toFixed(2),'max='+Math.max(...rs).toFixed(2));
 console.log(' premier élément:',JSON.stringify(list[0]).slice(0,700));
 console.log(' clés:',[...new Set(list.flatMap(e=>Object.keys(e)))].join(' '));
}
// observés : de quel club ?
const obs=[];(function w(v){if(Array.isArray(v)){v.forEach(w);return;}if(!isO(v))return;const pid=v.playerId??v.id;if(typeof pid==='string'&&v.knowledge?.stage==='observed')obs.push(pid);for(const k in v)w(v[k]);})(m);
const byClub={};for(const i of new Set(obs))byClub[clubOf.get(i)]=(byClub[clubOf.get(i)]||0)+1;console.log('observés par club:',JSON.stringify(byClub),'calendrier joué:',JSON.stringify(m.calendar.filter(f=>f.played).map(f=>[f.week,f.home??f.h,f.away??f.a,f.opponent?.id??f.opp])).slice(0,300));
console.log('playerKnowledge records:',(S.playerKnowledge?.records||[]).flat().map(r=>[r[0],r[1],r[2],r[3],r[4]]).slice(0,3).map(x=>JSON.stringify(x)).join(' '),'total',(S.playerKnowledge?.records||[]).flat().length);
console.log('live:',S.live?JSON.stringify({finished:S.live.finished,pair:S.live.pair}):null,'semaine',S.franceMode?.week,S.round);
