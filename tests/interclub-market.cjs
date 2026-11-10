'use strict';
const {settleClubMeetings}=require('./helpers/club-meetings.cjs');
const {test}=require('node:test'),a=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const file=path.resolve(__dirname,'../native/engine/interclub-market.cjs');
const domain=fs.existsSync(file)?require(file):{factory:()=>({})};
const {context}=require('./native-reference-harness.cjs');
function office(){const h=context();h.run('CDCommonCareer.start(0);const interclub=('+domain.factory.toString()+')();');return {...h,project:()=>JSON.parse(h.run('JSON.stringify(interclub.project())')),execute:p=>{h.ctx.payload=p;return h.run('interclub.execute("interclub_transfer",payload)');}};}
function candidate(h){const p=h.project().candidates.find(p=>p.available);a(p,'au moins un joueur achetable');return p;}
function bid(h,p){return {playerId:p.id,sellerId:p.clubId,fee:p.fee,salary:p.salary,sourceSalary:p.sourceSalary,contractEnd:p.contractEnd,context:h.project().context,confirmed:true};}
test('lecture pure et devis fondé sur les engagements publics, sans révéler le potentiel',()=>{const h=office(),before=h.run('JSON.stringify(S)'),rng=h.randomState(),m=h.project();a.equal(m.available,true);a(m.candidates.length);a.equal(h.run('JSON.stringify(S)'),before);a.deepEqual(h.randomState(),rng);a(!('rating' in m.candidates[0]));a(!('potential' in m.candidates[0]));});
test('achat sous contrat: même identité, argent conservé, salaire et échéance contrôlés',()=>{const h=office(),p=candidate(h),payload=bid(h,p);h.ctx.id=p.id;const initial=JSON.parse(h.run('JSON.stringify(S)')),sum=initial.clubs.reduce((n,c)=>n+c.cash,0),source=initial.clubs[p.clubId].players.find(q=>q.id===p.id);h.execute(payload);const end=JSON.parse(h.run('JSON.stringify(S)')),target=end.clubs[0].players.find(q=>q.id===p.id);a(target);a.equal(end.clubs[p.clubId].players.some(q=>q.id===p.id),false);a.equal(target.contractEnd,source.contractEnd);a.equal(target.salary,p.salary);a.equal(target.id,source.id);a.deepEqual(target.skills,source.skills);a.equal(end.clubs[0].cash,initial.clubs[0].cash-p.fee);a.equal(end.clubs[p.clubId].cash,initial.clubs[p.clubId].cash+p.fee);a.equal(end.clubs.reduce((n,c)=>n+c.cash,0),sum);a.equal(h.run('validateCareer(S);true'),true);a.throws(()=>h.execute(payload));});
test('refus atomiques: devis périmé, argent, effectif, profondeur, prêt et match',()=>{const h=office(),p=candidate(h),payload=bid(h,p);const reject=x=>{const before=h.run('JSON.stringify(S)'),rng=h.randomState();a.throws(()=>h.execute(x));a.equal(h.run('JSON.stringify(S)'),before);a.deepEqual(h.randomState(),rng);};reject({...payload,context:{...payload.context,week:99}});reject({...payload,fee:0});reject({...payload,salary:1000});reject({...payload,sourceSalary:p.sourceSalary+1});reject({...payload,hidden:1});reject({...payload,confirmed:false});h.run('S.clubs[0].cash=0');reject(payload);h.run('S.clubs[0].cash=100000000;S.live={}');reject(payload);h.run('S.live=null');h.ctx.seller=p.clubId;h.run('S.clubs[seller].players=S.clubs[seller].players.slice(0,37)');reject(payload);});

function workerFixture(t,mode="common"){
 const os=require('node:os'),root=fs.mkdtempSync(path.join(os.tmpdir(),'cd-interclub-')),engine=path.join(root,'app/engine');fs.mkdirSync(engine,{recursive:true});
 for(const name of fs.readdirSync(path.resolve(__dirname,'../native/engine')))if(/\.(cjs|json)$/.test(name))fs.copyFileSync(path.resolve(__dirname,'../native/engine',name),path.join(engine,name));
 const system=path.join(engine,'native-systems.cjs');fs.writeFileSync(system,fs.readFileSync(system,'utf8').replace('const domains={',"const domains={interclubMarket:require('./interclub-market.cjs'),"));
 const {createBridge}=require(path.join(engine,'worker.cjs')),opts={dataDir:path.join(root,'profile'),distDir:path.resolve(__dirname,'../dist'),seed:827381,now:1794178800000};let b=createBridge(opts),n=0;
 const raw=(command,payload={})=>b.handle({id:++n,command,payload}),go=(command,payload={})=>{const r=raw(command,payload);a.equal(r.ok,true,command+': '+r.error);return r.model;};
 t.after(()=>{b.close();fs.rmSync(root,{recursive:true,force:true});});settleClubMeetings(go('new_career',{mode,club:0}),(command,payload)=>go(command,payload));
 return {raw,go,model:()=>go('snapshot').clubLife.interclubMarket,state:()=>JSON.parse(go('export').meta.exportText).state,export:()=>go('export').meta.exportText,disk:()=>fs.readFileSync(path.join(root,'profile/PrototypeGodot/donnees.json')),file:path.join(root,'profile/PrototypeGodot/donnees.json'),restart:()=>{b.close();b=createBridge({...opts,seed:1,now:1});}};
}
test('vrai worker: refus disque atomique, achat persistant et import/reprise exacts',t=>{
 const h=workerFixture(t),m=h.model(),p=m.candidates.find(p=>p.available);a(p);const payload={playerId:p.id,sellerId:p.clubId,fee:p.fee,salary:p.salary,sourceSalary:p.sourceSalary,contractEnd:p.contractEnd,context:m.context,confirmed:true},before=h.export(),disk=h.disk();
 h.go('snapshot');a.equal(h.export(),before);a.deepEqual(h.disk(),disk);
 const backup=path.join(path.dirname(h.file),'donnees-precedentes.json');fs.mkdirSync(backup);a.equal(h.raw('interclub_transfer',payload).ok,false);a.equal(h.export(),before);a.deepEqual(h.disk(),disk);fs.rmdirSync(backup);
 h.go('interclub_transfer',payload);a(h.state().clubs[0].players.some(q=>q.id===p.id));const saved=h.export();h.restart();a.equal(h.export(),saved);h.go('import',{text:saved});a.equal(h.export(),saved);a(!h.model().candidates.some(q=>q.id===p.id));
});
test('prêt réel, famille réduite, places réservées et provision salariale bloquent sans effet',()=>{
 const h=office(),p=candidate(h),payload=bid(h,p);h.ctx.id=p.id;h.ctx.seller=p.clubId;
 const reject=()=>{const before=h.run('JSON.stringify(S)');a.throws(()=>h.execute(payload));a.equal(h.run('JSON.stringify(S)'),before);};
 h.run('S.v78to81={loans:[{id,season:S.season,from:seller,to:0}]}');reject();h.run('delete S.v78to81');
 h.run('const family=S.clubs[seller].players.find(p=>p.id===id).fam;S.clubs[seller].players.forEach(p=>{if(p.id!==id&&p.fam===family)p.fam=(family+1)%9;})');reject();
 const h2=office(),p2=candidate(h2),payload2=bid(h2,p2);h2.ctx.threshold=p2.fee+400000+p2.salary*8-1;h2.run('S.clubs[0].cash=threshold');a.throws(()=>h2.execute(payload2),/provisionner/);
 h2.run('S.clubs[0].cash=100000000;S.v78to81={loans:Array.from({length:100},(_,i)=>({id:"reserved-"+i,from:0,to:1,season:S.season}))}');a.throws(()=>h2.execute(payload2),/complet/);
});
test('deux achats consécutifs vérifient à nouveau fonds et unicité dans le même contexte',()=>{
 const h=office(),m=h.project(),p=m.candidates.find(p=>p.available);h.execute(bid(h,p));const q=candidate(h);h.execute(bid(h,q));const ids=JSON.parse(h.run('JSON.stringify(S.clubs.flatMap(c=>c.players.map(p=>p.id)))'));a.equal(new Set(ids).size,ids.length);a.equal(h.run('validateCareer(S);true'),true);
});

test('Monde: achat sous contrat reçu par le vrai worker',t=>{const h=workerFixture(t,'world'),m=h.model(),p=m.candidates.find(p=>p.available);a(p,'un achat doit être accessible');h.go('interclub_transfer',{playerId:p.id,sellerId:p.clubId,fee:p.fee,salary:p.salary,sourceSalary:p.sourceSalary,contractEnd:p.contractEnd,context:m.context,confirmed:true});const saved=h.export();h.restart();a.equal(h.export(),saved);});
test('un contrat source à salaire nul valide reçoit un devis au minimum de recrutement',()=>{
 const h=office(),p=candidate(h);h.ctx.id=p.id;h.ctx.seller=p.clubId;
 h.run('S.clubs[seller].players.find(p=>p.id===id).salary=0;validateCareer(S)');
 const quote=h.project().candidates.find(q=>q.id===p.id);a.equal(quote.available,true);a.equal(quote.salary,1000);h.execute(bid(h,quote));a.equal(h.run('S.clubs[0].players.find(p=>p.id===id).salary'),1000);a.equal(h.run('validateCareer(S);true'),true);
});
