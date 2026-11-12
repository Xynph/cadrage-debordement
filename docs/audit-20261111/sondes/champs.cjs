const dir=process.argv[2],m=require(dir+'/model.json'),S=require(dir+'/state.json');
const {analyze}=require('./sonde.cjs');const r=analyze(m,S,()=>{});
const pear=(a,b)=>{const n=a.length,ma=a.reduce((s,x)=>s+x,0)/n,mb=b.reduce((s,x)=>s+x,0)/n;let sab=0,sa=0,sb=0;for(let i=0;i<n;i++){sab+=(a[i]-ma)*(b[i]-mb);sa+=(a[i]-ma)**2;sb+=(b[i]-mb)**2;}return sa&&sb?sab/Math.sqrt(sa*sb):0;};
for(const [k,rows] of [...r.num].sort((a,b)=>b[1].length-a[1].length).slice(0,45)){const xs=rows.map(x=>x[0]),tr=rows.map(x=>r.truth.get(x[1]).rating);console.log(k.padEnd(60),'n='+String(rows.length).padEnd(6),'distinct='+String(new Set(xs).size).padEnd(5),'r='+(new Set(xs).size>1?pear(xs,tr).toFixed(2):'—'));}
console.log('--- texte');for(const [k,rows] of [...r.str].sort((a,b)=>b[1].length-a[1].length).slice(0,30))console.log(k.padEnd(60),'n='+String(rows.length).padEnd(6),'distinct='+new Set(rows.map(x=>x[0])).size,'ex:',JSON.stringify(rows[0][0]).slice(0,70));
