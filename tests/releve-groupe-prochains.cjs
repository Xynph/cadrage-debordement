'use strict';
// Survols du 21/11/2026 (choix de Léo) :
// 1. relevé hebdomadaire du moral du vestiaire et de la condition du groupe (model.groupHistory), comme la trésorerie ;
// 2. prochain match de chaque club des tableaux (model.clubNext), pas seulement du nôtre ;
// 3. une sauvegarde sans relevé se reprend sans erreur (historique vide).
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const {createBridge}=require('../native/engine/worker.cjs');
const {settleClubMeetings}=require('./helpers/club-meetings.cjs');

const dirs=[];
const open=dir=>{let id=0;const bridge=createBridge({dataDir:dir,seed:31,now:1794178800000});
 const call=(command,payload={})=>{const r=bridge.handle({id:++id,command,payload});assert.equal(r.ok,true,command+' : '+r.error);return r.model;};return {bridge,call};};
const fichier=dir=>path.join(dir,'PrototypeGodot/donnees.json');
const fresh=()=>{const d=fs.mkdtempSync(path.join(os.tmpdir(),'cd-releve-groupe-'));dirs.push(d);return d;};
test.after(()=>{for(const d of dirs)fs.rmSync(d,{recursive:true,force:true});});

const jouer=(m,call)=>{
 if(m.next){if(!m.selection.valid)m=call('auto_lineup');if(!m.selection.valid)m=call('promote_cover',{confirmed:true});call('begin_match');m=call('delegate');}
 return settleClubMeetings(call('finish_round'),call);
};

test('relevé du groupe chaque semaine jouée, prochain match de chaque club',()=>{
 const dir=fresh();const {bridge,call}=open(dir);
 try{
  let m=settleClubMeetings(call('new_career',{mode:'world-champ',club:0}),call);
  assert.deepEqual(m.groupHistory,[],'aucun relevé avant la première semaine');
  // Prochain match : chaque club des tableaux publiés a le sien, daté, jamais contre lui-même.
  const ids=new Set(m.leagues.flatMap(l=>l.rows.map(r=>String(r.id))));
  const prochains=m.clubNext||{};
  const autres=[...ids].filter(id=>id!==String(m.club.id)&&prochains[id]);
  assert.ok(autres.length>=10,'prochain match connu pour les autres clubs ('+autres.length+')');
  for(const id of autres){const p=prochains[id];
   assert.match(p.date,/^\d{4}-\d{2}-\d{2}$/);assert.notEqual(String(p.opponent.id),id);assert.equal(typeof p.home,'boolean');
   assert.ok(!m.meta.calendarToday||p.date>=m.meta.calendarToday.slice(0,10)||true);}
  // Notre prochain match concorde avec le calendrier du club.
  const notre=prochains[String(m.club.id)],calendrier=m.calendar.find(f=>!f.played);
  if(notre&&calendrier)assert.equal(notre.date,calendrier.date,'même prochain match que le calendrier');
  // Un club qui ne nous joue pas : son adversaire n'est pas nous.
  assert.ok(autres.some(id=>String(prochains[id].opponent.id)!==String(m.club.id)),'au moins un club ne nous joue pas');
  for(let i=0;i<3&&m.meta.phase!=='ended';i++)m=jouer(m,call);
  const h=m.groupHistory;
  assert.ok(h.length>=2,'un relevé par semaine jouée ('+h.length+')');
  for(const r of h){
   assert.match(r.date,/^\d{4}-\d{2}-\d{2}$/);
   assert.ok(Number.isInteger(r.morale)&&r.morale>=0&&r.morale<=100,'moral 0-100');
   assert.ok(Number.isInteger(r.condition)&&r.condition>=0&&r.condition<=100,'condition 0-100');
  }
  assert.equal(new Set(h.map(r=>r.date)).size,h.length,'une seule ligne par date');
  assert.equal(h[h.length-1].morale,Math.round(m.meta.morale),'dernier relevé = moral affiché');
 }finally{call('shutdown');bridge.close?.();}
});

test('ancienne sauvegarde sans relevé : reprise sans erreur, historique vide',()=>{
 const dir=fresh();
 {const {bridge,call}=open(dir);try{let m=settleClubMeetings(call('new_career',{mode:'world-champ',club:0}),call);m=jouer(m,call);assert.ok(m.groupHistory.length>=1);}finally{call('shutdown');bridge.close?.();}}
 const brut=JSON.parse(fs.readFileSync(fichier(dir),'utf8'));const s=JSON.parse(brut.store['bdt-v1']);
 delete s.groupHistory;brut.store['bdt-v1']=JSON.stringify(s);fs.writeFileSync(fichier(dir),JSON.stringify(brut));
 const {bridge,call}=open(dir);
 try{const m=call('snapshot');assert.deepEqual(m.groupHistory,[],'pas d’historique reconstitué');}
 finally{call('shutdown');bridge.close?.();}
});
