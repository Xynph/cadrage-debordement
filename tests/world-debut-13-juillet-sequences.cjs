'use strict';
// Début de carrière Monde au 13 juillet 2026 : finir la semaine depuis l'avant-saison donne exactement
// les mêmes séquences qu'une ouverture directe au 17 août (fichier séparé : deux carrières, mémoire).
const {test}=require('node:test'),assert=require('node:assert/strict');
const crypto=require('node:crypto'),fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const {createBridge}=require('../native/engine/worker.cjs');
const {settleClubMeetings}=require('./helpers/club-meetings.cjs');

function career(t,options={}){
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'cd-debut-'));
 const b=createBridge({dataDir:dir,seed:27,now:1794178800000,...options});let id=0;
 const send=(command,body={})=>b.handle({id:++id,command,payload:body});
 const go=(command,body={})=>{const r=send(command,body);assert.equal(r.ok,true,command+': '+r.error);return r.model;};
 let closed=false;const close=()=>{if(closed)return;closed=true;b.close();fs.rmSync(dir,{recursive:true,force:true});};
 t.after(close);
 return {close,send,go,state:()=>JSON.parse(go('export').meta.exportText).state,model:settleClubMeetings(go('new_career',{mode:'world-champ',club:0}),go)};
}

test('avancer le calendrier du moteur depuis l’avant-saison : mêmes séquences qu’une ouverture directe',t=>{
 // A : semaine terminée directement depuis le 13 juillet ; B : avant-saison avancée d'abord.
 // Une seule carrière en mémoire à la fois (machine partagée).
 const a=career(t);
 assert.equal(a.model.meta.calendarToday,'2026-07-13');
 const digest=c=>crypto.createHash('sha256').update(JSON.stringify(c.state())).digest('hex');
 const ma=settleClubMeetings(a.go('finish_round'),a.go),sa=digest(a);a.close();
 const b=career(t);
 settleClubMeetings(b.go('preseason_advance',{fromDate:'2026-07-13',until:'saison'}),b.go);
 const mb=settleClubMeetings(b.go('finish_round'),b.go),sb=digest(b);b.close();
 assert.equal(ma.meta.week,1);
 assert.equal(sa,sb,'l’avant-saison ne consomme aucun tirage et ne modifie rien');
 assert.equal(ma.meta.calendarToday,mb.meta.calendarToday);
});

