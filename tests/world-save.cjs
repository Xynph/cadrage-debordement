'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict');
const {context}=require('./harness.cjs');
const clone=x=>JSON.parse(JSON.stringify(x));
function fixture(){
 const h=context();h.run('start(0)');const s=JSON.parse(h.run('JSON.stringify(S)'));
 for(const key of ['aiRoster','aiRosterVersion','worldManagement','worldVersion'])delete s[key];
 const original=clone(s.clubs);
 s.clubs=Array.from({length:58},(_,id)=>{const c=clone(original[id%14]);c.id=id;c.name='Club Monde '+id;c.abbr='M'+id;c.color='#123456';c.stadium='Stade '+id;c.form=[];c.players.forEach((p,n)=>{if(id>=14)p.id='foreign:'+id+':'+n;});return c;});
 s.clubs[40].players[0].age=15;
 const registry={id:'world-test-2026-v1',version:1,marker:{id:'world-test-2026-v1',version:1},clubs:clone(s.clubs)};
 s.commonDatabase=clone(registry.marker);
 s.schedule=Array.from({length:46},(_,week)=>week%3===1?[]:week%3===0?[[0,30]]:[[0,30],[14,40]]);
 s.worldMode={version:1,catalogue:registry.id,rules:'world-pro-2026-27-v1',startYear:2026,week:0,leagues:Object.fromEntries([['elite',14,0],['accession',16,14],['prem',10,30],['urc',16,40]].map(([id,n,start])=>[id,{members:Array.from({length:n},(_,i)=>start+i),phase:'league',champion:null,finalist:null}])),fixtures:[],yearbook:[],movement:null};
 s.history=[];s.phase='league';s.round=0;s.live=null;s.lastReport=null;
 h.ctx.CDWorldRegistry=registry;h.ctx.worldValidationCalls=0;
 h.run(`globalThis.CDWorldCareer={
 active(s){return !!s&&s.worldMode?.version===1&&s.worldMode.catalogue===CDWorldRegistry.id&&s.commonDatabase?.id===CDWorldRegistry.id&&s.commonDatabase.version===1&&Object.keys(s.commonDatabase).length===2;},
 sizing(){return {clubCount:58,maxRound:46,rounds:46};},
 leagueId(s,id=s.club){return id<14?'elite':id<30?'accession':id<40?'prem':'urc';},
 ranked(s,id){return s.worldMode.leagues[id].members.map(i=>s.clubs[i]);},
 validate(s){worldValidationCalls++;if(s.worldMode.rules!=='world-pro-2026-27-v1'||s.worldMode.week!==s.round||s.worldMode.fixtures.length>=1200||s.schedule.length!==46)throw Error('Monde incohérent');if(s.live?.worldContext?.fixtureId==='hostile'||s.live?.knockout?.period===9)throw Error('Contexte mondial invalide');for(const c of s.clubs)for(const p of c.players){const source=CDWorldRegistry.clubs.flatMap(c=>c.players).find(q=>q.id===p.id);if(p.worldProfile!==undefined&&JSON.stringify(p.worldProfile)!==JSON.stringify(source?.worldProfile))throw Error('Profil monde invalide');}}
 };`);
 return {h,s,registry};
}
function check(f,s=f.s){f.h.ctx.candidate=s;return f.h.run('validateCareer(candidate)');}
test('Monde : 58 clubs et calendrier variable répété délégués, export/import borné',()=>{
 const f=fixture();assert.doesNotThrow(()=>check(f));assert.ok(f.h.run('worldValidationCalls')>0);
 f.h.ctx.candidate=f.s;const text=f.h.run('JSON.stringify(createSaveDocument(candidate))');assert.ok(Buffer.byteLength(text)<8*1024*1024);f.h.ctx.savedText=text;assert.equal(f.h.run('parseSaveDocument(savedText).state.clubs.length'),58);
 const ended=clone(f.s);ended.round=46;ended.worldMode.week=46;ended.phase='ended';ended.ending='Saison terminée.';delete ended.playoff;assert.doesNotThrow(()=>check(f,ended));
});
test('Monde : marqueurs, identités, limites et doublons restent stricts',()=>{
 const f=fixture();assert.doesNotThrow(()=>check(f));
 const attacks=[s=>s.worldMode.version=2,s=>s.worldMode.catalogue='other',s=>s.commonDatabase.extra=true,s=>delete s.commonDatabase,s=>s.worldMode.rules='other',s=>s.franceMode={version:1},s=>s.lnrMode={version:1},s=>s.club=58,s=>s.round=47,s=>s.phase='final',s=>s.clubs.pop(),s=>s.clubs[40].name='Autre identité',s=>s.clubs[40].abbr='OTHER',s=>s.clubs[40].color='#000000',s=>s.clubs[40].form=['W'],s=>s.clubs[40].players[0].id=s.clubs[41].players[0].id,s=>s.clubs[40].players[1].age=15,s=>s.clubs[40].players[0].age=14,s=>s.worldMode.fixtures=Array(1200).fill(null),s=>s.history=Array(1201).fill({}),s=>s.extra=Array(2001).fill(null)];
 for(const mutate of attacks){const bad=clone(f.s);mutate(bad);assert.throws(()=>check(f,bad),String(mutate));}
});
test('Monde : historique européen et contexte live reconnus, validation spécialisée exigée',()=>{
 const f=fixture();f.h.run('beginMatch()');const live=JSON.parse(f.h.run('JSON.stringify(S.live)'));assert.ok(live);
 live.worldContext={fixtureId:'world-fixture:1',competitionId:'champions-cup',phase:'pool',week:0};live.knockout={period:1,regulationEnd:80,firstEnd:90};f.s.live=live;assert.doesNotThrow(()=>check(f));
 for(const mutate of [s=>s.live.worldContext.fixtureId='hostile',s=>s.live.knockout.period=9]){const bad=clone(f.s);mutate(bad);assert.throws(()=>check(f,bad));}
 f.s.live=null;const result={fixtureId:'world-fixture:1',competitionId:'champions-cup',phase:'pool',round:45,competitionRound:4,week:45,pair:[0,30],score:[25,20],tries:[3,2],stats:JSON.parse(f.h.run('JSON.stringify([makeStats(),makeStats()])'))};f.s.history=[result];assert.doesNotThrow(()=>check(f));
 f.s.history=Array.from({length:1200},(_,id)=>({...clone(result),fixtureId:'world-fixture:'+id}));assert.doesNotThrow(()=>check(f));
});
test('Monde : préparation et instantanés utilisent la borne mondiale de semaine',()=>{
 const f=fixture();f.h.ctx.candidate=f.s;assert.doesNotThrow(()=>f.h.run('validateCollectiveSnapshot({v:1,season:1,round:46,focus:[Object.keys(COLLECTIVE_FOCI)[0],Object.keys(COLLECTIVE_FOCI)[0]],power:[.8,.8]},candidate)'));
});
test('France : un contexte mondial injecté ne peut pas détourner la fin de match',()=>{
 const h=require('./france-harness.cjs').context();
 h.run("start(0,'france');S.live=createRugbyMatch(nextMatch());validateCareer(S)");
 assert.throws(()=>h.run("S.live.worldContext={fixtureId:'forged',phase:'final',competitionId:'champions',week:0};validateCareer(S)"),/Contexte de compétition incompatible/);
});
test('Monde : capacité de 1,5 million de nœuds isolée, tailles et anciennes VMs conservées',()=>{
 const f=fixture(),shape=total=>{const tree={worldMode:{version:1,catalogue:f.registry.id},commonDatabase:clone(f.s.commonDatabase),items:[]};let remaining=total-8;while(remaining>1001){tree.items.push(Array(1000).fill(false));remaining-=1001;}if(remaining)tree.items.push(Array(remaining-1).fill(false));return tree;};
 f.h.ctx.tree=shape(1499999);assert.doesNotThrow(()=>f.h.run('safeTree(tree)'));f.h.ctx.tree=shape(1500000);assert.throws(()=>f.h.run('safeTree(tree)'),/complexe/);
 f.h.ctx.savedText='é'.repeat(4*1024*1024+1);assert.throws(()=>f.h.run('parseSaveDocument(savedText)'),/volumineux/);
 const old=context();old.run('start(0);validateCareer(S)');old.ctx.candidate=f.s;assert.throws(()=>old.run('validateCareer(candidate)'));
});
test('Monde : import/export 16Mio réservé au marqueur mondial exact, anciennes limites 8Mio conservées',()=>{
 const f=fixture(),large=clone(f.s);large.saveLimitNotes=Array.from({length:1450},()=> 'n'.repeat(5999));f.h.ctx.candidate=large;
 const text=f.h.run('JSON.stringify(createSaveDocument(candidate))');assert.ok(Buffer.byteLength(text)>8*1024*1024&&Buffer.byteLength(text)<16*1024*1024);
 f.h.ctx.savedText=text;assert.doesNotThrow(()=>f.h.run('parseSaveDocument(savedText)'));
 const legacy=context();legacy.run('start(0)');const oldState=JSON.parse(legacy.run('JSON.stringify(S)'));oldState.saveLimitNotes=large.saveLimitNotes;legacy.ctx.candidate=oldState;legacy.ctx.savedText=legacy.run('JSON.stringify(createSaveDocument(candidate))');assert.throws(()=>legacy.run('parseSaveDocument(savedText)'),/volumineux/);
 const hostile=JSON.parse(text);hostile.state.commonDatabase.extra=true;f.h.ctx.savedText=JSON.stringify(hostile);assert.throws(()=>f.h.run('parseSaveDocument(savedText)'),/volumineux/);
 const huge=clone(f.s);huge.saveLimitNotes=[Array.from({length:1500},()=> 'n'.repeat(5999)),Array.from({length:1500},()=> 'n'.repeat(5999))];f.h.ctx.candidate=huge;assert.throws(()=>f.h.run('createSaveDocument(candidate)'),/volumineux/);
 f.h.ctx.savedText=' '.repeat(16*1024*1024+1);assert.throws(()=>f.h.run('parseSaveDocument(savedText)'),/volumineux/);
});
