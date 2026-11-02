#!/usr/bin/env node
'use strict';
// Usage: node modding/tools/rugby-incremental-import.cjs --input imports.json [--db path] [--write]
// Default is read-only. No network/scraping. Only explicitly verified observations are accepted.
const fs=require('node:fs');
const path=require('node:path');
const DEFAULT_DB=path.resolve(__dirname,'../data06/rugby-master-2026-2027.json');
function fail(message){throw new Error(message);}
function assert(condition,message){if(!condition)fail(message);}
function norm(value){return String(value??'').normalize('NFD').replace(/[\u0300-\u036f]/g,'').trim().toLowerCase().replace(/\s+/g,' ');}
function observationIdentity(o){
  return JSON.stringify([o.competition,o.season,o.phase,o.type,o.entityId,o.category??null,o.indicator,o.unit??null,o.scope??null]);
}
function validateDb(db){
  assert(db&&Array.isArray(db.players)&&Array.isArray(db.rugbyDataObservations||[]),'Format BDD non reconnu');
  const ids=new Set();
  for(const p of db.players){assert(typeof p.id==='string'&&p.id&&!ids.has(p.id),'ID joueur dupliqué ou absent');ids.add(p.id);}
  return ids;
}
function validateObservation(o,players,clubs){
  assert(o&&typeof o==='object'&&!Array.isArray(o),'Observation invalide');
  for(const f of ['competition','season','phase','type','entityId','indicator','sourceUrl'])assert(typeof o[f]==='string'&&o[f].trim(), 'Observation: champ requis '+f);
  assert(/^20\d{2}-20\d{2}$/.test(o.season),'Saison invalide');
  assert(['Joueur','Club'].includes(o.type),'Type entité non reconnu');
  assert(o.type==='Joueur'?players.has(o.entityId):clubs.has(o.entityId),'Identité non rapprochée: '+o.entityId);
  assert(Number.isFinite(o.value)&&o.value>=0,'Valeur statistique invalide');
  assert(/^https:\/\//.test(o.sourceUrl),'URL de provenance HTTPS requise');
}
function resolvePlayer(update,db){
  assert(update&&typeof update==='object','Mise à jour joueur invalide');
  if(update.id){
    const p=db.players.find(x=>x.id===update.id);
    assert(p,'ID joueur absent: '+update.id);
    if(update.realName)assert(norm(update.realName)===norm(p.realName),'Nom incohérent pour '+update.id);
    if(update.club)assert(norm(update.club)===norm(p.club),'Club incohérent pour '+update.id);
    if(update.league)assert(norm(update.league)===norm(p.league),'Ligue incohérente pour '+update.id);
    return p;
  }
  assert(update.realName&&update.club&&update.league,'Sans ID: nom, club et ligue obligatoires');
  const matching=db.players.filter(p=>norm(p.realName)===norm(update.realName)&&norm(p.club)===norm(update.club)&&norm(p.league)===norm(update.league));
  assert(matching.length===1,'Identité absente ou ambiguë: '+update.realName);
  return matching[0];
}
function merge(original,batch){
  assert(batch&&batch.schema==='rugby-incremental-batch-v1','Schéma de lot invalide');
  const db=structuredClone(original),players=validateDb(db);
  const clubs=new Set(db.players.map(x=>x.club));
  const existing=db.rugbyDataObservations||[];
  const keys=new Map();
  for(const o of existing){
    const key=observationIdentity(o);
    if(keys.has(key))assert(JSON.stringify(keys.get(key))===JSON.stringify(o),'Doublon contradictoire dans la BDD');
    keys.set(key,o);
  }
  let inserted=0,unchanged=0,playersChanged=0;
  const seenBatch=new Set();
  for(const o of batch.observations||[]){
    validateObservation(o,players,clubs);
    const key=observationIdentity(o);
    assert(!seenBatch.has(key),'Observation répétée dans le lot: '+key);
    seenBatch.add(key);
    if(keys.has(key)){
      const prior=keys.get(key);
      assert(prior.value===o.value,'Correction de statistique interdite sans procédure dédiée: '+key);
      unchanged++;
    }else{
      const record={...o,observationKey:key};
      existing.push(record);keys.set(key,record);inserted++;
    }
  }
  db.rugbyDataObservations=existing;
  for(const u of batch.playerUpdates||[]){
    const p=resolvePlayer(u,db);
    const allowed=['id','realName','club','league','rating','potential','skills','attributesV2','reason'];
    assert(Object.keys(u).every(k=>allowed.includes(k)),'Champ de mise à jour interdit');
    assert(typeof u.reason==='string'&&u.reason.trim(),'Justification de recalibrage requise');
    const before=JSON.stringify(p);
    for(const key of ['rating','potential']){
      if(u[key]!==undefined){assert(Number.isInteger(u[key])&&u[key]>=20&&u[key]<=97,'Note hors limites: '+key);p[key]=u[key];}
    }
    for(const key of ['skills','attributesV2']){
      if(u[key]!==undefined){
        assert(u[key]&&typeof u[key]==='object'&&!Array.isArray(u[key]),'Attributs invalides');
        for(const [attr,value] of Object.entries(u[key])){
          assert(Object.hasOwn(p[key]||{},attr),'Clé de compétence inconnue: '+attr);
          assert(Number.isInteger(value)&&value>=20&&value<=97,'Valeur de compétence invalide');
          p[key][attr]=value;
        }
      }
    }
    assert(p.potential>=p.rating,'Potentiel inférieur au général: '+p.id);
    if(before!==JSON.stringify(p))playersChanged++;
  }
  validateDb(db);
  return {db,report:{players:db.players.length,observationsBefore:original.rugbyDataObservations?.length||0,observationsAfter:existing.length,inserted,unchanged,playersChanged}};
}
function run(argv){
  const val=f=>{const i=argv.indexOf(f);return i<0?null:argv[i+1];};
  const input=val('--input'),dbPath=path.resolve(val('--db')||DEFAULT_DB),write=argv.includes('--write');
  assert(input&&input!=='--write','--input chemin.json obligatoire');
  const original=JSON.parse(fs.readFileSync(dbPath,'utf8'));
  const batch=JSON.parse(fs.readFileSync(path.resolve(input),'utf8'));
  const {db,report}=merge(original,batch);
  if(write&&JSON.stringify(db)!==JSON.stringify(original)){
    const tmp=dbPath+'.tmp-'+process.pid;
    try{fs.writeFileSync(tmp,JSON.stringify(db)+'\n',{flag:'wx'});fs.renameSync(tmp,dbPath);}
    finally{if(fs.existsSync(tmp))fs.unlinkSync(tmp);}
  }
  console.log(JSON.stringify({...report,mode:write?'write':'dry-run'}));
}
if(require.main===module){try{run(process.argv.slice(2));}catch(e){console.error('IMPORT REFUSÉ: '+e.message);process.exitCode=1;}}
module.exports={merge,observationIdentity,resolvePlayer,validateDb};
