'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const {createBridge}=require('../native/engine/worker.cjs');
const root=fs.mkdtempSync(path.join(require('node:os').tmpdir(),'native-manager-career-reverse-'));let request=0;const bridges=[];
function open(name){const b=createBridge({dataDir:path.join(root,name),seed:13,now:1700000000000});bridges.push(b);return b;}
const good=(b,command,payload={})=>{const r=b.handle({id:++request,command,payload});assert.equal(r.ok,true,r.error);return r.model;};
const doc=b=>JSON.parse(good(b,'export').meta.exportText),data=b=>good(b,'snapshot').clubLife.managerCareer;
function act(b,command,p={}){return good(b,command,{context:data(b).context,...p});}
function signed(state){const s={format:'cadrage-debordement-save',exportVersion:1,exportedAt:'2026-11-08T12:00:00.000Z',state};let h=2166136261;for(const ch of JSON.stringify(state)){h^=ch.charCodeAt(0);h=Math.imul(h,16777619);}s.checksum=(h>>>0).toString(16).padStart(8,'0');return s;}
try{
 const b=open('accession');good(b,'new_career',{mode:'common',club:29});act(b,'manager_career_activate');
 if(process.env.CD_MANAGER_REVERSE_PROFILE){const profile=JSON.parse(fs.readFileSync(process.env.CD_MANAGER_REVERSE_PROFILE,'utf8')),state=JSON.parse(profile.store['bdt-v1']),carrier=doc(b),fixture=signed(state);fixture.format=carrier.format;good(b,'import',{text:JSON.stringify(fixture)});}
 else for(let i=0;i<34;i++){if(good(b,'snapshot').next){good(b,'begin_match');good(b,'delegate');}good(b,'finish_round');}
 let target=data(b).opportunities.find(x=>x.leagueId==='elite'&&x.accepted);
 if(!target){
  // Actual club29's first season can correctly receive only refusals. Qualify
  // the inverse transition with an explicit suitable career fixture, without
  // weakening the production offer rules or asserting an automatic promotion.
  const carrier=doc(b),state=carrier.state,id=data(b).opportunities.find(x=>x.leagueId==='elite').clubId;
  state.worldManagement.clubInfo[29].reputation=100;state.trust=100;
  Object.assign(state.worldManagement.clubInfo[id],{reputation:50,coachConfidence:0,consecutiveLosses:10,debt:0});state.clubs[id].cash=Math.max(100000,state.clubs[id].cash);
  const fixture=signed(state);fixture.format=carrier.format;good(b,'import',{text:JSON.stringify(fixture)});target=data(b).opportunities.find(x=>x.clubId===id&&x.accepted);
 }
 assert.ok(target,'Fixture admissible Accession vers Élite');
 act(b,'manager_career_apply',{clubId:target.clubId});const offerId='job-1-'+target.clubId;
 const current=good(b,'export').meta.exportText,declined=open('declined');good(declined,'import',{text:current});act(declined,'manager_career_decline',{offerId});assert.equal(data(declined).applications.find(a=>a.id===offerId).status,'declined');assert.equal(declined.handle({id:++request,command:'manager_career_accept',payload:{context:data(declined).context,offerId,confirmed:true}}).ok,false);
 act(b,'manager_career_accept',{offerId,confirmed:true});const control=open('control');good(control,'import',{text:good(b,'export').meta.exportText});act(control,'manager_career_cancel');good(control,'next_season',{confirmed:true});good(b,'next_season',{confirmed:true});
 const a=doc(b).state,z=doc(control).state;assert.equal(a.club,target.clubId);assert.equal(a.managerMobility.history[0].fromClub,29);assert.deepEqual(a.clubs.map(c=>c.cash),z.clubs.map(c=>c.cash));assert.deepEqual(a.clubs.map(c=>c.players.map(p=>p.id)),z.clubs.map(c=>c.players.map(p=>p.id)));assert.deepEqual(a.development.academy.map(p=>p.id),z.aiRoster.academies.find(c=>c.clubId===target.clubId).players.map(p=>p.id));
 const saved=good(b,'export').meta.exportText,file=path.join(good(b,'snapshot').meta.dataDir,'donnees.json'),bytes=fs.readFileSync(file);for(let i=0;i<3;i++)good(b,'snapshot');assert.deepEqual(fs.readFileSync(file),bytes);assert.equal(good(b,'export').meta.exportText,saved);good(b,'shutdown');const resumed=open('accession');assert.equal(good(resumed,'snapshot').meta.recoveryRequired,false);assert.equal(good(resumed,'export').meta.exportText,saved);
 console.log('PASS vrai worker production manager : Accession29→Élite, refus, annulation témoin, comptes/effectifs/centre conservés, pureté octets, reprise exacte');
}finally{for(const b of bridges)b.close();}
