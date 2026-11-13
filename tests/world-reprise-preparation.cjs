'use strict';
// Reprise de l'entraînement (reprise.cjs) : départ de la partie, date de reprise du club,
// internationaux en congés, jeunes en préparation, effets bornés et clubs de l'ordinateur.
// Carrières Monde (world-champ) uniquement. Départs « club » et « veille » (fichier séparé : mémoire).
const {test}=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const {createBridge}=require('../native/engine/worker.cjs');
const {settleClubMeetings}=require('./helpers/club-meetings.cjs');

function career(t,payload){
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'cd-reprise-'));
 const b=createBridge({dataDir:dir,seed:27,now:1794178800000});let id=0;
 const send=(command,body={})=>b.handle({id:++id,command,payload:body});
 const go=(command,body={})=>{const r=send(command,body);assert.equal(r.ok,true,command+': '+r.error);return r.model;};
 let closed=false;const close=()=>{if(closed)return;closed=true;b.close();fs.rmSync(dir,{recursive:true,force:true});};
 t.after(close);
 const state=()=>JSON.parse(go('export').meta.exportText).state;
 return {close,send,go,state,model:settleClubMeetings(go('new_career',{mode:'world-champ',club:0,...payload}),go)};
}

test('départ « Reprise de ton club » puis préparation jouée : effets, jeunes et sauvegarde',t=>{
 const {go,send,state,model}=career(t,{start:'club'});
 let m=model;
 assert.equal(m.meta.calendarToday,'2026-07-27');
 assert.equal(m.clubLife.reprise.start,'club');
 const youth=m.clubLife.reprise.youth.suggested.slice(0,3);
 m=go('reprise_youth',{playerIds:youth});
 const before=state(),dev=Object.fromEntries(before.development.academy.filter(p=>youth.includes(p.id)).map(p=>[p.id,p.dev.minutes]));
 m=settleClubMeetings(go('reprise_advance',{fromDate:'2026-07-27',until:'saison'}),go);
 for(let i=0;i<4&&!m.next;i++)m=settleClubMeetings(go('finish_round'),go);
 assert.ok(m.next,'première journée');
 const s=state(),r=m.clubLife.reprise;
 assert.ok(r.report&&r.report.season===1&&r.report.friendlies>=1,'bilan de préparation');
 assert.deepEqual(r.report.youth.map(y=>y.id),youth);
 for(const y of r.report.youth){
  assert.ok(y.minutes>=25*r.report.friendlies&&y.minutes<=55*r.report.friendlies,'temps de jeu en amical');
  assert.ok(s.development.academy.find(p=>p.id===y.id).dev.minutes>=dev[y.id]+y.minutes,'minutes d’amical versées (plus les matchs de jeunes)');
 }
 // Retard de condition de la reprise du 27/07 (1 semaine plus tard que la référence) : borné.
 const own=s.reprise.plan.clubs.find(x=>x[0]===0);
 assert.equal(own[4],1,'effets de début de saison appliqués');
 const fx=r.club.effects;
 assert.ok(fx.conditionGap<=12&&fx.fatigue<=15&&Math.abs(fx.morale)<=6&&fx.injuryRisk<=1.6&&fx.automatismes>=-22&&fx.automatismes<=6);
 for(const p of s.clubs[0].players){const gap=s.reprise.plan.players[p.id]?.[1]??fx.conditionGap;assert.ok(p.condition<=100-gap,'condition plafonnée');}
 // Clubs de l'ordinateur : mêmes effets, appliqués à leur semaine de 1re rencontre.
 assert.ok(s.reprise.plan.clubs.filter(x=>x[0]!==0&&x[4]===1).length>=13);
 // Sauvegarde : export/import strict.
 const text=go('export').meta.exportText;
 assert.equal(send('import',{text}).ok,true);
 const broken=JSON.parse(text);broken.state.reprise.plan.clubs[0][2]=999;
 assert.equal(send('import',{text:JSON.stringify(broken)}).ok,false,'plan corrompu refusé');
});

test('départ « Veille de la 1re journée » : préparation gérée par le staff, déterministe',t=>{
 const a=career(t,{start:'veille'});
 const r=a.model.clubLife.reprise,first=JSON.stringify(a.state().reprise);
 assert.equal(r.auto,true);
 assert.equal(r.editable,false);
 assert.ok(a.model.next,'la première rencontre est la prochaine');
 assert.ok(r.report?.auto&&r.report.youth.length>=2,'le staff a convoqué des jeunes');
 assert.equal(r.club.date,'2026-07-27','le staff reprend à la date habituelle du club');
 assert.equal(a.send('new_career',{mode:'world-champ',club:0,start:'janvier'}).ok,false);
 a.close();
 const b=career(t,{start:'veille'});
 assert.equal(JSON.stringify(b.state().reprise),first,'même graine, même préparation');
});

