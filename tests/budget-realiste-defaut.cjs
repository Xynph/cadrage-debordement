'use strict';
// Budget de saison réaliste activé par défaut (décision de Léo du 13 novembre 2026), mode Monde.
// 1. Sans variable : une carrière world-champ neuve est marquée (salaires par niveau, budget du club,
//    centre de formation) ; masses sous le plafond, aucune amende ni avertissement de la ligue au départ.
// 2. CD_SALAIRES_PAR_NIVEAU=0 : l'ancienne économie reste disponible pour les tests et les comparaisons.
// 3. Carrière déjà commencée sans la marque : la reprise, une semaine jouée et l'export ne la marquent pas
//    (aucun choc à la reprise : les contrats signés ne sont pas réécrits).
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const {createBridge}=require('../native/engine/worker.cjs');
const {settleClubMeetings}=require('./helpers/club-meetings.cjs');
const LE=require('../native/engine/league-economy.cjs');

(()=>{
 const dirs=[];
 const open=(dir)=>{let id=0;const bridge=createBridge({dataDir:dir,seed:27,now:1794178800000});
  const call=(command,payload={})=>{const r=bridge.handle({id:++id,command,payload});assert.equal(r.ok,true,command+' : '+r.error);return r.model;};return {bridge,call};};
 const state=dir=>JSON.parse(JSON.parse(fs.readFileSync(path.join(dir,'PrototypeGodot/donnees.json'),'utf8')).store['bdt-v1']);
 const fresh=()=>{const d=fs.mkdtempSync(path.join(os.tmpdir(),'cd-budget-defaut-'));dirs.push(d);return d;};
 const withFlag=(value,fn)=>{const before=process.env.CD_SALAIRES_PAR_NIVEAU;if(value===undefined)delete process.env.CD_SALAIRES_PAR_NIVEAU;else process.env.CD_SALAIRES_PAR_NIVEAU=value;
  try{return fn();}finally{if(before===undefined)delete process.env.CD_SALAIRES_PAR_NIVEAU;else process.env.CD_SALAIRES_PAR_NIVEAU=before;}};
 const leagueOf=(s,id)=>{for(const [k,l] of Object.entries(s.worldMode.leagues))if(l.members.includes(id))return k;return 'guest';};
 test.after(()=>{for(const d of dirs)fs.rmSync(d,{recursive:true,force:true});});

 test('sans variable, une carrière Monde neuve a le budget réaliste',()=>{
  const dir=fresh();
  withFlag(undefined,()=>{const {bridge,call}=open(dir);try{const m=call('new_career',{mode:'world-champ',club:0});
   assert.ok(Number.isFinite(m.finance.salaryFloor)&&m.finance.salaryFloor>0,'plancher salarial de la règle');
   const s=state(dir);
   assert.equal(s.startingSalaries?.semaines,52,'carrière marquée');
   assert.equal(s.clubBudget?.version,1,'comptes de saison ouverts');
   assert.equal(s.clubBudget.clubs.length,s.clubs.length);
   for(const c of s.clubs){const cap=LE.CHAMPIONNATS[leagueOf(s,c.id)]?.plafond;const masse=c.players.reduce((n,p)=>n+p.salary,0)*52;
    if(cap)assert.ok(masse<=cap,c.name+' sous le plafond à la création');}
   assert.ok(!(s.ledger||[]).some(e=>/Amende/.test(e.title)),'aucune amende au départ');
   assert.ok(!(s.news||[]).some(t=>/plafond salarial|52 %/.test(t)&&/ligue/i.test(t)),'aucun avertissement de la ligue au départ');
   assert.ok(s.clubs.every(c=>c.players.length>=30),'effectifs complets');
  }finally{call('shutdown');bridge.close?.();}});
 });

 test('CD_SALAIRES_PAR_NIVEAU=0 garde l’ancienne économie',()=>{
  const dir=fresh();
  withFlag('0',()=>{const {bridge,call}=open(dir);try{call('new_career',{mode:'world-champ',club:0});
   const s=state(dir);assert.equal(s.startingSalaries,undefined);assert.equal(s.clubBudget,undefined);
  }finally{call('shutdown');bridge.close?.();}});
 });

 test('une carrière commencée sans la marque n’est pas convertie à la reprise',()=>{
  const dir=fresh();
  withFlag('0',()=>{const {bridge,call}=open(dir);try{settleClubMeetings(call('new_career',{mode:'world-champ',club:29}),call);}finally{call('shutdown');bridge.close?.();}});
  const salaires=state(dir).clubs[29].players.map(p=>p.salary);
  withFlag(undefined,()=>{const {bridge,call}=open(dir);try{
   let m=settleClubMeetings(call('snapshot'),call);
   assert.equal(state(dir).startingSalaries,undefined,'reprise : pas de marque');
   for(let i=0;i<2&&m.meta.phase!=='ended';i++){
    if(m.next){if(!m.selection.valid)m=call('auto_lineup');if(!m.selection.valid)m=call('promote_cover',{confirmed:true});call('begin_match');m=call('delegate');}
    m=settleClubMeetings(call('finish_round'),call);
   }
   const s=state(dir);
   assert.equal(s.startingSalaries,undefined,'semaines jouées : pas de marque');
   assert.equal(s.clubBudget,undefined,'semaines jouées : ancien budget');
   assert.ok(salaires.length>=30&&s.clubs[29].players.every(p=>p.salary>=1000),'contrats de l’ancien barème conservés (plancher de 1 000 € par semaine)');
   const text=call('export').meta.exportText;assert.ok(!/"startingSalaries"/.test(text),'export sans marque');
  }finally{call('shutdown');bridge.close?.();}});
 });
})();
