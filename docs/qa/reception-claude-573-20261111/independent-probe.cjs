'use strict';
const fs=require('node:fs'),path=require('node:path'),os=require('node:os'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const base='/tmp/rg27-review-573-base',candidate='/tmp/rg27-review-573-source',proof=__dirname;
const {settleClubMeetings}=require(candidate+'/tests/helpers/club-meetings.cjs');
const oldFactory=require(base+'/native/engine/worker.cjs').createBridge,newFactory=require(candidate+'/native/engine/worker.cjs').createBridge;
const root=fs.mkdtempSync(path.join(os.tmpdir(),'review573-probe-'));let id=0;const bridges=[];const started=Date.now();let assertions=0;
function equal(a,b,label){assert.deepEqual(a,b,label);assertions++;}
function good(b,c,p={}){const r=b.handle({id:++id,command:c,payload:p});assert.equal(r.ok,true,c+': '+r.error);assertions++;return r.model;}
function settled(b,m){return settleClubMeetings(m,(c,p)=>good(b,c,p));}
function open(factory,name){const b=factory({dataDir:path.join(root,name),seed:827381,now:1700000000000});bridges.push(b);return b;}
function disk(name){return path.join(root,name,'PrototypeGodot','donnees.json');}
function exported(b){return JSON.parse(good(b,'export').meta.exportText);}
function checksum(state){let h=2166136261;for(const c of JSON.stringify(state)){h^=c.charCodeAt(0);h=Math.imul(h,16777619);}return(h>>>0).toString(16).padStart(8,'0');}
try{
 const old=open(oldFactory,'old');settled(old,good(old,'new_career',{club:29,mode:'france'}));
 good(old,'begin_match');good(old,'delegate');settled(old,good(old,'finish_round'));
 const document=exported(old),bytes=fs.readFileSync(disk('old'));assert(document.state.history.length>0);assertions++;
 const history=structuredClone(document.state.history);old.close();
 for(const name of ['resume','import']){fs.mkdirSync(path.dirname(disk(name)),{recursive:true});fs.writeFileSync(disk(name),bytes);}
 const a=open(newFactory,'resume');good(a,'snapshot');equal(exported(a).state,document.state,'old checkpoint state preserved on new worker resume');equal(fs.readFileSync(disk('resume')),bytes,'read-only resume/export preserves original disk bytes');
 const b=open(newFactory,'import');const initialEnvelope=JSON.parse(fs.readFileSync(disk('import')));good(b,'import',{text:JSON.stringify(document)});
 equal(exported(b).state,document.state,'legacy import preserves full original state including scores');equal(JSON.parse(fs.readFileSync(disk('import'))).seed,initialEnvelope.seed,'legacy validation/import does not consume RNG');
 for(const worker of [a,b])settled(worker,good(worker,'train'));
 const resumed=exported(a),imported=exported(b);equal(resumed.state,imported.state,'same subsequent real training after resume/import is deterministic');equal(JSON.parse(fs.readFileSync(disk('resume'))).seed,JSON.parse(fs.readFileSync(disk('import'))).seed,'RNG remains identical after next random command');equal(resumed.state.history,history,'recorded sporting results preserved');
 const before=fs.readFileSync(disk('resume')),beforeState=exported(a).state,bad=structuredClone(resumed);bad.state.franceMode.leagues.elite.schedule[3][0].reverse();bad.checksum=checksum(bad.state);const refusal=a.handle({id:++id,command:'import',payload:{text:JSON.stringify(bad)}});equal(refusal.ok,false,'arbitrary altered calendar with valid checksum refused');equal(exported(a).state,beforeState,'refusal retains complete state');equal(fs.readFileSync(disk('resume')),before,'refusal retains profile bytes and RNG');
 const oldCommon=require(base+'/dist/rugby-common-rosters.js'),newCommon=require(candidate+'/dist/rugby-common-rosters.js');equal(newCommon.clubs,oldCommon.clubs,'regenerated common roster preserves all sporting player data');
 const result={passed:true,head:'d88dc4db7a87a165a1bbfc25ed269f4008a47d6b',base:'96f537040bf9f2e37bf10b0a9b09518b732244a2',assertions,oldSeason:document.state.season,oldRound:document.state.round,recordedResults:history.length,legacyScheduleSha256:crypto.createHash('sha256').update(JSON.stringify(document.state.franceMode.leagues.accession.schedule)).digest('hex'),seconds:(Date.now()-started)/1000,limits:['No Godot or Windows','No full-season migration independently simulated','Old world/academy checkpoint compatibility not independently executed']};fs.writeFileSync(path.join(proof,'independent-probe-result.json'),JSON.stringify(result,null,2)+'\n');console.log(JSON.stringify(result));
}catch(error){fs.writeFileSync(path.join(proof,'independent-probe-result.json'),JSON.stringify({passed:false,head:'d88dc4db7a87a165a1bbfc25ed269f4008a47d6b',assertions,error:error.stack,seconds:(Date.now()-started)/1000},null,2)+'\n');throw error;}
finally{for(const b of bridges)b.close();}
