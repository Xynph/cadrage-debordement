'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const domain=require('../native/engine/manager-career.cjs');
assert.deepEqual(domain.files,[]);assert.ok(domain.commands.includes('manager_career_accept'));
const root=fs.mkdtempSync(path.join(require('node:os').tmpdir(),'native-manager-career-')),engine=path.join(root,'app','engine');fs.mkdirSync(engine,{recursive:true});
for(const name of fs.readdirSync(path.resolve(__dirname,'../native/engine')))if(/\.(cjs|json)$/.test(name))fs.copyFileSync(path.resolve(__dirname,'../native/engine',name),path.join(engine,name));
const systemFile=path.join(engine,'native-systems.cjs');let source=fs.readFileSync(systemFile,'utf8');if(!source.includes("managerCareer:require('./manager-career.cjs')"))source=source.replace("const domains={","const domains={managerCareer:require('./manager-career.cjs'),");fs.writeFileSync(systemFile,source);
const {createBridge}=require(path.join(engine,'worker.cjs'));let id=0;const bridges=[];
const open=name=>{const b=createBridge({dataDir:path.join(root,name),distDir:path.resolve(__dirname,'../dist'),seed:13,now:1700000000000});bridges.push(b);return b};
const call=(b,command,payload={})=>b.handle({id:++id,command,payload});
const good=(b,c,p={})=>{const r=call(b,c,p);assert.equal(r.ok,true,r.error);return r.model};
const data=b=>good(b,'snapshot').clubLife.managerCareer;
const act=(b,c,p={})=>good(b,c,{context:data(b).context,...p});
const state=b=>JSON.parse(good(b,'export').meta.exportText).state;
const reject=(b,c,p={})=>{const before=good(b,'export').meta.exportText;assert.equal(call(b,c,p).ok,false);assert.equal(good(b,'export').meta.exportText,before)};
try{
 let b=open('main');good(b,'new_career',{mode:'common',club:0});const old=good(b,'export').meta.exportText;assert.equal(data(b).active,false);good(b,'snapshot');assert.equal(good(b,'export').meta.exportText,old,'consultation ancienne carrière pure');
 const s0=state(b),candidate=good(b,'snapshot').market[0];act(b,'manager_recruitment_watch',{playerId:candidate.id});assert.ok(state(b).manager.watch.includes(candidate.id));assert.deepEqual(state(b).clubs,s0.clubs);
 assert.equal(data(b).plan.length,3);assert.equal(data(b).plan[0].payments,34);assert.equal(data(b).plan[0].payroll,s0.clubs[0].players.reduce((n,p)=>n+p.salary,0)*34);
 act(b,'manager_career_activate');reject(b,'manager_career_apply',{context:data(b).context,clubId:29});reject(b,'manager_career_activate',{context:data(b).context});
 good(b,'academy_activate',{...good(b,'snapshot').clubLife.academyPathways.context,confirmed:true});
 // Administrative decisions must stay attached to the former club during the move.
 const cs=good(b,'snapshot').clubLife.clubStrategy.context;
 good(b,'club_board_objective',{context:cs,type:'wins',target:2,deadline:10});good(b,'club_board_project',{context:cs,kind:'video',confirmed:true});good(b,'club_fans_price',{context:cs,key:'accessible'});
 for(let i=0;i<34;i++){if(good(b,'snapshot').next){good(b,'begin_match');good(b,'delegate');}good(b,'finish_round');}assert.equal(state(b).phase,'ended');assert.equal(data(b).window,true);assert.equal(data(b).context.week,34);
 const target=data(b).opportunities.find(x=>x.clubId>=14&&x.accepted);assert.ok(target,'Offre Accession disponible');act(b,'manager_career_apply',{clubId:target.clubId});const offer='job-1-'+target.clubId;
 reject(b,'manager_career_apply',{context:data(b).context,clubId:target.clubId});reject(b,'manager_career_accept',{context:data(b).context,offerId:offer});reject(b,'manager_career_accept',{context:{...data(b).context,week:33},offerId:offer,confirmed:true});
 const before=good(b,'export').meta.exportText;const file=path.join(good(b,'snapshot').meta.dataDir,'donnees.json');fs.renameSync(file,file+'.held');fs.mkdirSync(file);
 const failed=call(b,'manager_career_accept',{context:data(b).context,offerId:offer,confirmed:true});assert.equal(failed.ok,false);assert.match(failed.error,/Écriture|sauvegarde/);assert.equal(good(b,'export').meta.exportText,before);fs.rmdirSync(file);fs.renameSync(file+'.held',file);
 act(b,'manager_career_accept',{offerId:offer,confirmed:true});assert.equal(state(b).club,0);assert.equal(data(b).pending.toClub,target.clubId);
 const pending=good(b,'export').meta.exportText;good(b,'import',{text:pending});assert.equal(good(b,'export').meta.exportText,pending);good(b,'shutdown');b=open('main');assert.equal(good(b,'snapshot').meta.recoveryRequired,false);assert.equal(good(b,'export').meta.exportText,pending);
 const hostile=JSON.parse(pending);hostile.state.managerMobility.version=999;reject(b,'import',{text:JSON.stringify(hostile)});
 const hidden=JSON.parse(pending);hidden.state.managerMobility.surprise=true;reject(b,'import',{text:JSON.stringify(hidden)});
 const control=open('control');good(control,'import',{text:pending});act(control,'manager_career_cancel');good(control,'next_season',{confirmed:true});
 good(b,'next_season',{confirmed:true});const moved=state(b),stayed=state(control);assert.equal(moved.club,target.clubId);assert.equal(moved.season,2);assert.equal(moved.managerMobility.pending,null);assert.equal(moved.managerMobility.history.length,1);
 assert.deepEqual(moved.clubs.map(c=>c.cash),stayed.clubs.map(c=>c.cash),'pas de transfert argent');assert.deepEqual(moved.clubs.map(c=>c.players.map(p=>p.id)),stayed.clubs.map(c=>c.players.map(p=>p.id)),'effectifs professionnels conservés');
 assert.deepEqual(moved.development.academy.map(p=>p.id),stayed.aiRoster.academies.find(a=>a.clubId===target.clubId).players.map(p=>p.id));assert.deepEqual(moved.aiRoster.academies.find(a=>a.clubId===0).players.map(p=>p.id),stayed.development.academy.map(p=>p.id));assert.equal(moved.nativeAcademy.club,target.clubId);assert.equal(moved.identityPack,stayed.identityPack);
 assert.ok(moved.managerMobility.archives.some(a=>a.clubId===0));if(moved.nativeBoardCalendar)assert.equal(moved.nativeBoardCalendar.clubId,'club-'+target.clubId);
 const exported=good(b,'export').meta.exportText;good(b,'snapshot');assert.equal(good(b,'export').meta.exportText,exported);good(b,'shutdown');b=open('main');assert.equal(good(b,'snapshot').meta.recoveryRequired,false);assert.equal(good(b,'export').meta.exportText,exported);
 console.log('PASS vrai worker manager : pureté, suivi, plan34 semaines, offres contexte/confirmation, refus, rollback disque, import/reprise, Élite→Accession, archives/formation/effectifs/comptes');
}finally{for(const b of bridges)b.close();}





