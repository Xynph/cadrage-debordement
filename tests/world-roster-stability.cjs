'use strict';
// Carrière mondiale (58 clubs) sur trois saisons par l'API publique du worker :
// les effectifs des clubs gérés restent autour de leur cible, des transferts ont
// lieu entre clubs gérés dans des bornes raisonnables, et la carrière s'exporte et
// se réimporte à l'identique en fin de saison 3. Test long : voir CD_STABILITY_FULL ci-dessous.
const assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const {settleClubMeetings}=require('./helpers/club-meetings.cjs');
const {createBridge}=require('../native/engine/worker.cjs');
// Version CI (défaut) : carrière mondiale réduite (championnat de Nationale), jouée jusqu'à la semaine 14 de la
// saison 1, c'est-à-dire après la fenêtre de transferts de la semaine 13 (club-transfers.cjs) : mêmes contrôles
// (effectif moyen proche de la cible, plancher de 38, au plus 3 achats et 3 ventes, transferts entre clubs gérés,
// export borné puis réimport identique), sous ~150 s. Version complète, mesurée par
// .github/workflows/club-intelligence-measure.yml : CD_STABILITY_FULL=1 (58 clubs, 3 saisons de 46 semaines, avec
// passage de saison). CD_STABILITY_MODE, CD_STABILITY_SEASONS et CD_STABILITY_WEEKS restent prioritaires.
const FULL=process.env.CD_STABILITY_FULL==='1',MODE=process.env.CD_STABILITY_MODE||(FULL?'world':'world-nationale');
const WEEKS=Number(process.env.CD_STABILITY_WEEKS||(FULL?46:14)),SEASONS=Number(process.env.CD_STABILITY_SEASONS||(FULL?3:1)),COMPLETE=WEEKS>=46;
const dir=fs.mkdtempSync(path.join(os.tmpdir(),'cd-roster-stability-'));
let bridge=createBridge({dataDir:dir,seed:827381,now:1794178800000}),serial=0,model;
const go=(command,payload={})=>{const r=bridge.handle({id:++serial,command,payload});assert.ok(r.ok,command+': '+r.error);return model=r.model;};
const state=()=>JSON.parse(JSON.parse(fs.readFileSync(path.join(dir,'PrototypeGodot/donnees.json'),'utf8')).store['bdt-v1']);
try{
 settleClubMeetings(go('new_career',{mode:MODE,club:0}),go);
 const start=state(),sizes=new Map(start.clubs.map(c=>[c.id,c.players.length])),targets=new Map(start.clubs.map(c=>[c.id,Math.min(58,Math.max(40,c.players.length))]));
 const leagueOf=(s,id)=>Object.entries(s.worldMode?.leagues??{}).find(([,l])=>l.members.includes(id))?.[0]??'guest';
 const sales=[];let seen=new Set();
 const track=s=>{for(const e of s.aiRoster.events)if(e.kind==='sell'){const k=JSON.stringify(e);if(!seen.has(k)){seen.add(k);sales.push(e);}}};
 for(let season=1;season<=SEASONS;season++){
  for(let week=model.meta.week;week<WEEKS;week++){
   if(model.next){if(!model.selection.valid)go('auto_lineup');if(!model.selection.valid)go('promote_cover',{confirmed:true});go('begin_match');go('delegate');}
   settleClubMeetings(go('finish_round'),go);if(week%6===0)track(state());
  }
  if(COMPLETE)settleClubMeetings(go('next_season',{confirmed:true}),go);
  const s=state();track(s);
  const rows={};
  for(const c of s.clubs){if(c.id===s.club)continue;const l=leagueOf(s,c.id);(rows[l]??=[]).push([c.players.length,targets.get(c.id),sizes.get(c.id)]);}
  for(const [league,list] of Object.entries(rows)){
   const mean=list.reduce((n,[x])=>n+x,0)/list.length,goal=list.reduce((n,[,t])=>n+t,0)/list.length;
   // Parcours complet : retour à la cible en fin de saison. Parcours partiel (CI) : pas d'inflation depuis le départ.
   if(COMPLETE)assert.ok(Math.abs(mean-goal)<=4,`S${season} ${league} : effectif moyen ${mean.toFixed(1)} pour une cible de ${goal.toFixed(1)}`);
   else{const depart=list.reduce((n,[,,d])=>n+d,0)/list.length;assert.ok(mean<=depart+1&&mean>=Math.min(goal,depart)-4,`S${season} ${league} : effectif moyen ${mean.toFixed(1)} pour un départ de ${depart.toFixed(1)} et une cible de ${goal.toFixed(1)}`);}
   assert.ok(list.every(([x])=>x>=38),`S${season} ${league} : un club passe sous 38 professionnels`);
  }
  const reports=s.aiRoster.reports.filter(r=>r.season>=(COMPLETE?s.season-1:s.season));
  for(const r of reports)assert.ok((r.bought||0)<=3&&(r.sold||0)<=3,'Au plus trois achats et trois ventes par club et par saison.');
  console.log(JSON.stringify({season,leagues:Object.fromEntries(Object.entries(rows).map(([k,v])=>[k,+(v.reduce((n,[x])=>n+x,0)/v.length).toFixed(1)])),sales:sales.filter(e=>e.season===season).length}));
 }
 assert.ok(sales.length>0,'Des transferts ont lieu entre clubs gérés.');
 const text=go('export').meta.exportText,doc=JSON.parse(text);
 assert.ok(Buffer.byteLength(text)<=24*1024*1024,'Export possible en fin de parcours ('+SEASONS+' saison(s), '+WEEKS+' semaines).');
 bridge.close();fs.rmSync(dir,{recursive:true,force:true});fs.mkdirSync(dir);
 bridge=createBridge({dataDir:dir,seed:1,now:1794178800000});go('import',{text});
 assert.equal(JSON.parse(go('export').meta.exportText).checksum,doc.checksum,'Réimport identique.');
 console.log('PASS effectifs stables sur '+SEASONS+' saison(s) ('+MODE+(COMPLETE?'':', '+WEEKS+' semaines')+'), '+sales.length+' transferts entre clubs gérés, export v'+doc.exportVersion+' '+(Buffer.byteLength(text)/1048576).toFixed(1)+' Mio réimporté à l’identique');
}finally{bridge?.close();fs.rmSync(dir,{recursive:true,force:true});}
