'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),os=require('node:os'),crypto=require('node:crypto');
const {createBridge}=require('../native/engine/worker.cjs'),{context}=require('./france-harness.cjs');
const root=fs.mkdtempSync(path.join(process.env.CD_COMMON_TEST_ROOT||os.tmpdir(),'cd-common-'));let serial=0;const bridges=[];
function bridge(name){const b=createBridge({dataDir:path.join(root,name),seed:827381,now:1700000000000});bridges.push(b);return b;}
function call(b,command,payload={}){return b.handle({id:++serial,command,payload});}
function good(b,command,payload={}){const r=call(b,command,payload);assert.equal(r.ok,true,command+': '+r.error);return r.model;}
function document(b){return JSON.parse(good(b,'export').meta.exportText);}
const clone=x=>JSON.parse(JSON.stringify(x));
try{
 const b=bridge('common0'),m=good(b,'new_career',{mode:'common',club:0});assert.equal(m.meta.mode,'common');assert.equal(m.meta.database.active,true);assert.equal(m.meta.catalogue.length,30);assert.equal(m.selection.valid,true);
 const data=require('../dist/rugby-common-rosters.js'),doc=document(b),players=doc.state.clubs.flatMap(c=>c.players);
 assert.equal(players.length,1592);assert.equal(new Set(players.map(p=>p.id)).size,1592);assert.equal(new Set(players.map(p=>p.name)).size,1592);assert.equal(doc.state.clubs.length,30);
 const ref=context();for(const f of ['lnr-rosters-data.js','lnr-ratings-v12.js','lnr-birthyears-data.js','lnr-career.js'])ref.run(fs.readFileSync(path.join(__dirname,'../dist',f),'utf8'));
 ref.run('LNR_TOP14.splice(0,LNR_TOP14.length,...LNR_CATALOGUE.clubs)');
 const expected=JSON.parse(ref.run('JSON.stringify(CDFranceClubs.clubs.map(c=>({id:c.id,players:lnrGamePlayers(LNR_TOP14.findIndex(x=>x[0]===c.slug),c.base)})))'));
 const names=new Set(expected.flatMap(c=>c.players.map(p=>p.name.toLocaleLowerCase('fr'))));
 const compiled=fs.readFileSync(path.join(__dirname,'../dist/rugby-common-rosters.js'),'utf8');
 const corrections=Object.fromEntries(Object.entries(require('../data/roster-foundation/verified.json').positions).map(([id,p])=>[id,p.primary]));
 for(const club of expected){assert.deepEqual(doc.state.clubs[club.id].players.map(p=>p.id),club.players.map(p=>p.id));for(const source of club.players){const p=players.find(x=>x.id===source.id);assert.ok(!names.has(p.name.toLocaleLowerCase('fr')),p.id+' pseudonyme');assert.ok(!compiled.includes(JSON.stringify(source.name)),source.id+' nom source absent');const profile=p.rosterProfile;const corrected=Object.hasOwn(corrections,p.id);assert.equal(profile.position.basis==='official',corrected,p.id+' documented exception only');for(const key of ['rating','potential','skills','attributesV2','hiddenTraitsV2','gameplayPosition','lnrRatingsVersion','age','birthYear','birthDate','ageEstimated','pos','fam'])assert.deepEqual(p[key],corrected&&['pos','gameplayPosition'].includes(key)?corrections[p.id]:corrected&&key==='fam'?({"Pilier gauche":0,"Pilier droit":0,"Talonneur":1,"Deuxième ligne":2,"Troisième ligne":3,"Numéro 8":3,"Demi de mêlée":4,"Demi d’ouverture":5,"Centre":7,"Ailier":6,"Arrière":8}[corrections[p.id]]):source[key],p.id+' '+key);assert.equal(p.dev.potential,source.dev.potential);}}
 assert.equal(data.sourceEncoding,'utf8-lf');
 for(const [name,digest] of Object.entries(data.sources))assert.equal(crypto.createHash('sha256').update(fs.readFileSync(path.join(__dirname,'..',name),'utf8').replace(/\r\n/g,'\n')).digest('hex'),digest,name);
 const initial=good(b,'export').meta.exportText;for(let i=0;i<3;i++)good(b,'snapshot');assert.equal(good(b,'export').meta.exportText,initial);
 good(b,'import',{text:initial});assert.deepEqual(document(b).state,doc.state);
 const b29=bridge('common29');assert.equal(good(b29,'new_career',{mode:'common',club:29}).meta.leagueId,'accession');
 assert.equal(document(b29).state.clubs.flatMap(c=>c.players).length,1592);assert.equal(good(b29,'snapshot').selection.valid,true,'documented roles now cover the club29 sheet without generated reinforcements');assert.equal(call(b29,'promote_cover').ok,false);assert.equal(document(b29).state.clubs[29].players.filter(p=>!p.id.startsWith('lnr:')).length,0);
 for(const x of [b,b29]){good(x,'auto_lineup');good(x,'begin_match');good(x,'delegate');good(x,'finish_round');assert.equal(good(x,'snapshot').meta.week,1);}
 const saved=document(b);good(b,'shutdown');const restarted=bridge('common0');assert.deepEqual(document(restarted).state,saved.state);
 // Invalid markers and forged young generated players never widen legacy formats.
 const bad=clone(doc);bad.state.commonDatabase.version=99;assert.equal(call(restarted,'import',{text:JSON.stringify(bad)}).ok,false);
 const h=context();h.run('CDFranceCareer.start(0,{database:CDCommonRosters.marker,playersForClub:id=>JSON.parse(JSON.stringify(CDCommonRosters.clubs[id].players))})');
 h.run('validateCareer(S)');
 const whole=h.state();const badState=clone(whole);badState.development.academy[0].age=15;h.ctx.rejected=badState;assert.throws(()=>h.run('validateCareer(rejected)'));
 const missingProfile=clone(whole);delete missingProfile.clubs[0].players[0].attributesV2;h.ctx.rejected=missingProfile;assert.throws(()=>h.run('validateCareer(rejected)'),/Attributs/);
 const extraMetadata=clone(whole);extraMetadata.clubs[0].players[0].lnrUnexpected=true;h.ctx.rejected=extraMetadata;assert.throws(()=>h.run('validateCareer(rejected)'),/Métadonnées/);
 const unknown=clone(whole);unknown.clubs[0].players[0].id='lnr:000unknown';h.ctx.rejected=unknown;assert.throws(()=>h.run('validateCareer(rejected)'),/Identifiant/);
 const oldAge=clone(whole);delete oldAge.commonDatabase;h.ctx.rejected=oldAge;assert.throws(()=>h.run('validateCareer(rejected)'));
 const measure=s=>({bytes:Buffer.byteLength(JSON.stringify(s)),nodes:(function count(v){return 1+(Array.isArray(v)?v.reduce((n,x)=>n+count(x),0):v&&typeof v==='object'?Object.values(v).reduce((n,x)=>n+count(x),0):0)})(s)});const measures={initial:measure(whole)};
 for(let week=0;week<34;week++)h.run('finishRound();validateCareer(S)');assert.equal(h.state().phase,'ended');assert.equal(h.state().history.length,433);measures.endSeason=measure(h.state());
 h.run('advanceSeason();validateCareer(S);pendingSave=parseSaveDocument(JSON.stringify(createSaveDocument()));if(!confirmSaveImport())throw Error("import");');assert.equal(h.state().season,2);measures.nextSeason=measure(h.state());assert.ok(h.state().clubs.flatMap(c=>c.players).filter(p=>p.id.startsWith('lnr:')).some(p=>JSON.stringify(p.attributesV2)!==JSON.stringify(players.find(x=>x.id===p.id).attributesV2)),'active annual V11 evolution is exercised');
 // Real disk failure rolls back the state AND RNG; retry equals a copied profile.
 const fault=bridge('failure');const fm=good(fault,'new_career',{mode:'common',club:0}),file=path.join(fm.meta.dataDir,'donnees.json'),bytes=fs.readFileSync(file);const copyDir=path.join(root,'control','PrototypeGodot');fs.mkdirSync(copyDir,{recursive:true});fs.writeFileSync(path.join(copyDir,'donnees.json'),bytes);const control=bridge('control');
 fs.renameSync(file,file+'.held');fs.mkdirSync(file);const failed=call(fault,'train',{mode:'intense'});assert.equal(failed.ok,false);assert.match(failed.error,/sauvegarde/i);assert.deepEqual(document(fault).state,document(control).state);fs.rmdirSync(file);fs.renameSync(file+'.held',file);assert.deepEqual(fs.readFileSync(file),bytes);
 good(fault,'train',{mode:'intense'});good(control,'train',{mode:'intense'});assert.deepEqual(document(fault).state,document(control).state);assert.equal(JSON.parse(fs.readFileSync(file)).seed,JSON.parse(fs.readFileSync(path.join(copyDir,'donnees.json'))).seed);
 // The marked state has a bounded node budget; legacy thresholds remain unchanged.
 h.run('S.extra=Array.from({length:1000},()=>Array.from({length:1000},()=>0))');assert.throws(()=>h.run('validateCareer(S)'),/complexe/);
 for(const [mode,club,count] of [['fiction',13,14],['france',29,30]]){const legacy=bridge(mode);good(legacy,'new_career',{mode,club});const text=good(legacy,'export').meta.exportText;good(legacy,'import',{text});assert.equal(document(legacy).state.clubs.length,count);assert.equal(document(legacy).state.commonDatabase,undefined);const legacyState=document(legacy).state;legacyState.extra=Array.from({length:450},()=>Array.from({length:1000},()=>0));h.ctx.rejected=legacyState;assert.throws(()=>h.run('validateCareer(rejected)'),/complexe/);}
 console.log(JSON.stringify({passed:true,measures,profiles:1592,clubs:30,checks:['active V12 exact parity 36/11/rating/potential/traits; documented official role exceptions','source hashes','unique pseudonyms','both divisions native matches','34 weeks + interseason','export import restart','disk/state/RNG rollback','node budget','legacy fiction14/france30']}));
}finally{for(const b of bridges)b.close();fs.rmSync(root,{recursive:true,force:true});}
