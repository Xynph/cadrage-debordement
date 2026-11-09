'use strict';
const {test}=require('node:test'),a=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const file=path.resolve(__dirname,'../native/engine/regen-scouting.cjs');
const domain=fs.existsSync(file)?require(file):{factory:()=>({})};
const {context}=require('./native-reference-harness.cjs');
const copy=x=>JSON.parse(JSON.stringify(x));
function office(){const h=context();h.run('CDCommonCareer.start(0);const regenScouting=('+domain.factory.toString()+')();');return {...h,project:f=>{h.ctx.filters=f;return JSON.parse(h.run('JSON.stringify(regenScouting.project(filters))'));},execute:p=>{h.ctx.payload=p;return h.run('regenScouting.execute("regen_shortlist",payload)');}};}
test('Le domaine ajoute seulement la shortlist et aucun nouveau moteur ou fichier de règles',()=>{a.deepEqual(domain.files,[]);a.deepEqual(domain.commands,['regen_shortlist']);a.equal(typeof domain.factory,'function');});
test('Projection réelle : origine honnête, besoins et filtres, sans révéler le talent non observé',()=>{
 const h=office(),before=h.run('JSON.stringify(S)'),rng=h.randomState(),m=h.project();
 a(m.candidates.length>0);a.equal(m.missionCommand,'scout_mission');a.equal(m.recruitCommand,'recruit');a.equal(m.missionCost,5000);
 const p=m.candidates[0];a.equal(p.origin.kind,'small-club');a.equal(p.origin.abstract,true);a.match(p.origin.label,/abstrait/);a.equal(p.evidence.seen,false);a.equal(p.evidence.potentialMin,null);a.equal(p.rating,undefined);a.equal(p.potential,undefined);a.equal(p.hiddenTraits,undefined);
 const filtered=h.project({minAge:p.age,maxAge:p.age,family:p.family});a(filtered.candidates.length);a(filtered.candidates.every(q=>q.age===p.age&&q.family===p.family));
 a(h.project({needsOnly:true}).candidates.every(q=>q.matchingSlots.length));
 a.throws(()=>h.project({minAge:17}),/filtre/);a.throws(()=>h.project({unknown:true}),/filtre/);
 a.equal(h.run('JSON.stringify(S)'),before);a.deepEqual(h.randomState(),rng);
 h.ctx.id=p.id;h.run('const target=S.economy.freeAgents.find(p=>p.id===id);target.rating=99;target.dev.potential=99;target.skills=Object.fromEntries(Object.keys(target.skills).map(k=>[k,99]));target.dev.hiddenTraits={secret:99};');
 a.deepEqual(h.project().candidates,m.candidates,'les talents non observés ne changent aucune ligne de détection');
});
test('Rapport existant et suivi partagé : intervalles datés, dédoublonnage et retrait devenu indisponible',()=>{
 const h=office(),p=h.project().candidates[0],ctx=h.project().context;
 const payload={playerId:p.id,watched:true,context:ctx};h.execute(payload);const once=h.run('JSON.stringify(S)');h.execute(payload);a.equal(h.run('JSON.stringify(S)'),once);a(h.project({watchedOnly:true}).candidates.some(q=>q.id===p.id));
 h.ctx.id=p.id;h.run('S.manager.reports.unshift({playerId:id,note:72,potential:81,season:S.season,week:S.economy.week});');
 let e=h.project().candidates.find(q=>q.id===p.id).evidence;a.equal(e.seen,true);a.equal(e.noteMin,70);a.equal(e.noteMax,74);a.equal(e.potentialMin,76);a.equal(e.potentialMax,86);
 h.run('S.economy.week+=14');e=h.project().candidates.find(q=>q.id===p.id).evidence;a.equal(e.stale,true);a.equal(e.noteMin,63);
 h.run('S.market=S.market.filter(p=>p.id!==id);S.economy.freeAgents=S.economy.freeAgents.filter(p=>p.id!==id);');
 a(h.project().shortlist.some(q=>q.id===p.id&&!q.available));h.execute({...payload,watched:false});a(!h.project().shortlist.some(q=>q.id===p.id));
});
test('Refus du suivi : mineur, origine inconnue, contexte périmé, match et liste pleine restent sans effet',()=>{
 const h=office(),p=h.project().candidates[0],ctx=h.project().context;
 const reject=payload=>{const before=h.run('JSON.stringify(S)'),rng=h.randomState();a.throws(()=>h.execute(payload));a.equal(h.run('JSON.stringify(S)'),before);a.deepEqual(h.randomState(),rng);};
 reject({playerId:p.id,watched:true,context:{...ctx,week:99}});reject({playerId:p.id,watched:true,context:ctx,secret:1});reject({playerId:p.id,watched:'true',context:ctx});
 h.ctx.id=p.id;h.run('S.economy.freeAgents.find(p=>p.id===id).age=17');a(!h.project().candidates.some(q=>q.id===p.id));reject({playerId:p.id,watched:true,context:ctx});
 h.run('S.economy.freeAgents.find(p=>p.id===id).age=20;delete S.economy.freeAgents.find(p=>p.id===id).population');reject({playerId:p.id,watched:true,context:ctx});
 const q=h.project().candidates[0];h.run('S.manager.watch=Array.from({length:30},(_,i)=>"old-"+i)');reject({playerId:q.id,watched:true,context:ctx});
 h.run('S.manager.watch=[];S.live={}');reject({playerId:q.id,watched:true,context:ctx});
});
test('Diplômé du vrai centre : provenance conservée ; une ancienne carrière sans provenance reste lisible',()=>{
 const h=office();
 h.run('const graduate=S.development.academy.shift();graduate.age=22;aiRosterGraduateAcademyPlayer(graduate,S.club);S.market=aiRosterMarketPool([]);');
 const p=h.project().candidates.find(p=>p.origin.kind==='academy');a(p);a.equal(p.origin.clubId,0);a.equal(p.origin.abstract,false);a(p.origin.label.includes(h.run('S.clubs[0].name')));a.equal(p.origin.season,1);
 const before=h.run('JSON.stringify(S)');h.project();a.equal(h.run('JSON.stringify(S)'),before);
 h.run('S.economy.freeAgents.forEach(p=>delete p.population)');const legacy=h.run('JSON.stringify(S)');a.deepEqual(h.project().candidates,[]);a.equal(h.run('JSON.stringify(S)'),legacy);
 h.run('S=null');a.equal(h.project().available,false);
});
test('Le diagnostic copie aussi le club : normaliser un profil hérité ne modifie pas la carrière',()=>{
 const h=office();h.run('S.clubs[S.club].players.forEach(p=>delete p.skills)');
 const before=h.run('JSON.stringify(S)'),rng=h.randomState();h.project();
 a.equal(h.run('JSON.stringify(S)'),before);a.deepEqual(h.randomState(),rng);
});

function workerFixture(t,mode){
 const root=fs.mkdtempSync(path.join(os.tmpdir(),'cd-regen-scout-')),engine=path.join(root,'app/engine');fs.mkdirSync(engine,{recursive:true});
 for(const name of fs.readdirSync(path.resolve(__dirname,'../native/engine')))if(/\.(cjs|json)$/.test(name))fs.copyFileSync(path.resolve(__dirname,'../native/engine',name),path.join(engine,name));
 const system=path.join(engine,'native-systems.cjs');let source=fs.readFileSync(system,'utf8');source=source.replace('const domains={',"const domains={regenScouting:require('./regen-scouting.cjs'),");fs.writeFileSync(system,source);
 const {createBridge}=require(path.join(engine,'worker.cjs')),opts={dataDir:path.join(root,'profile'),distDir:path.resolve(__dirname,'../dist'),seed:827381,now:1794178800000};let b=createBridge(opts),n=0;
 const raw=(command,payload={})=>b.handle({id:++n,command,payload}),go=(command,payload={})=>{const r=raw(command,payload);a.equal(r.ok,true,command+': '+r.error);return r.model;};
 t.after(()=>{b.close();fs.rmSync(root,{recursive:true,force:true});});go('new_career',{mode,club:0});
 return {raw,go,model:()=>go('snapshot').clubLife.regenScouting,state:()=>JSON.parse(go('export').meta.exportText).state,export:()=>go('export').meta.exportText,disk:()=>fs.readFileSync(path.join(root,'profile/PrototypeGodot/donnees.json')),file:path.join(root,'profile/PrototypeGodot/donnees.json'),restart:()=>{b.close();b=createBridge({...opts,seed:1,now:1});}};
}
test('Vrai worker Monde : shortlist sans coût/RNG, rollback disque et réouverture exacte',t=>{
 const h=workerFixture(t,'world'),m=h.model(),p=m.candidates[0],before=h.export(),disk=h.disk(),state=h.state(),payload={playerId:p.id,watched:true,context:m.context};
 h.go('snapshot');a.equal(h.export(),before);a.deepEqual(h.disk(),disk);
 const backup=path.join(path.dirname(h.file),'donnees-precedentes.json');fs.mkdirSync(backup);a.equal(h.raw('regen_shortlist',payload).ok,false);a.equal(h.export(),before);a.deepEqual(h.disk(),disk);fs.rmdirSync(backup);
 h.go('regen_shortlist',payload);a(h.state().manager.watch.includes(p.id));a.equal(h.state().clubs[0].cash,state.clubs[0].cash);const saved=h.export();h.go('regen_shortlist',payload);a.equal(h.export(),saved);h.restart();a.equal(h.export(),saved);h.go('import',{text:saved});a.equal(h.export(),saved);
 const privateBefore=JSON.parse(disk),privateAfter=JSON.parse(h.disk());a.equal(privateAfter.seed,privateBefore.seed);a.equal(privateAfter.clock,privateBefore.clock);
});
test('Vrai worker commun : mission existante payée une fois, rapport après deux journées puis contrat réel',t=>{
 const h=workerFixture(t,'common'),initial=h.state(),p=h.model().candidates.find(p=>p.available);a(p);
 h.go('scout_mission',{family:p.family,maxAge:40,budget:10000000,maxWage:100000,confirmed:true});a.equal(initial.clubs[0].cash-h.state().clubs[0].cash,5000);a.equal(h.state().manager.missions.length,1);
 for(let i=0;i<2;i++){const m=h.go('snapshot');if(m.next){h.go('begin_match');h.go('delegate');}h.go('finish_round');}
 const m=h.model();a.equal(m.missions[0].status,'done');a(m.candidates.some(p=>p.evidence.seen));
 const candidate=m.candidates.find(p=>p.available),s=h.state();a(candidate);const result=h.go('recruit',{playerId:candidate.id,salary:candidate.salary,years:candidate.minYears,confirmed:true});a.equal(result.meta.negotiation.status,'signed');
 const end=h.state();a(end.clubs[0].players.some(q=>q.id===candidate.id));a.equal(s.clubs[0].cash-end.clubs[0].cash,candidate.fee);a(!end.economy.freeAgents.some(q=>q.id===candidate.id));a(!h.model().candidates.some(q=>q.id===candidate.id));
 const saved=h.export();h.restart();a.equal(h.export(),saved);
});
