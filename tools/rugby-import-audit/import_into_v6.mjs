#!/usr/bin/env node
// Importeur conservateur pour les observations déjà normalisées par stage_exports.py.
// Lecture/écriture explicites : jamais de modification du JSON d'entrée.
import fs from 'node:fs';
import readline from 'node:readline';
import crypto from 'node:crypto';

const norm = v => String(v??'').normalize('NFKD').replace(/[\u0300-\u036f]/g,'').toUpperCase().replace(/[^A-Z0-9]/g,' ').trim().replace(/\s+/g,' ');
const hash = v => crypto.createHash('sha256').update(JSON.stringify(v)).digest('hex');
const numeric = v => {if(v===null||v===undefined||String(v).trim()==='')return null;const s=String(v).replace(/[\u00a0 ]/g,'').replace(',','.');if(!/^-?\d+(?:\.\d+)?$/.test(s))return null;const n=Number(s);return Number.isFinite(n)&&n>=0?n:null};
const league = v => v==='TOP 14'?'top14':v==='PRO D2'?'prod2':null;
const key = v => hash([v.competition,v.season,v.phase,v.type,v.entityId,v.indicator,v.unit??null,v.scope??null]);

export async function integrate(db, observations, mapping) {
 if(db.schema!=='rugby-master-sports-v6'||!Array.isArray(db.players))throw Error('Schéma BDD incompatible');
 if(!Array.isArray(mapping?.clubAliases)||!Array.isArray(mapping?.verifiedMembership))throw Error('Mapping obligatoire');
 const clubs=new Map();
 for(const a of mapping.clubAliases){if(!a.competition||!a.season||!a.source||!a.clubId||!a.evidenceUrl)throw Error('Alias non sourcé');const k=[a.competition,a.season,norm(a.source)].join('|');if(clubs.has(k)&&clubs.get(k)!==a.clubId)throw Error('Alias contradictoire');clubs.set(k,a.clubId)}
 const members=new Set(mapping.verifiedMembership.map(m=>{if(!m.playerId||!m.clubId||!m.season||!m.evidenceUrl)throw Error('Affiliation non sourcée');return [m.playerId,m.clubId,m.season].join('|')}));
 const playerNames=new Map();
 for(const p of db.players){const k=[p.league,norm(p.realName)].join('|');playerNames.set(k,[...(playerNames.get(k)||[]),p])}
 const out=structuredClone(db);out.rugbyDataObservations??=[];if(!Array.isArray(out.rugbyDataObservations))throw Error('Observations existantes mal formées');
 const facts=new Map();for(const o of out.rugbyDataObservations){const k=key(o);if(facts.has(k)&&facts.get(k).value!==o.value)throw Error('Conflit existant');facts.set(k,o)}
 const stats={read:0,added:0,already_present:0,duplicates:0,conflicts:0,pending:0,reasons:{},byCompetition:{'TOP 14':{added:0,pending:0},'PRO D2':{added:0,pending:0}}};
 const seen=new Set();const pendingSamples=[];const conflictSamples=[];
 function hold(r,reason){stats.pending++;stats.reasons[reason]=(stats.reasons[reason]||0)+1;if(stats.byCompetition[r.competition])stats.byCompetition[r.competition].pending++;if(pendingSamples.length<100)pendingSamples.push({competition:r.competition,season:r.season,subject:r.subject,indicator:r.indicator,reason,source_url:r.source_url})}
 for await(const r of observations){
  stats.read++;const l=league(r.competition);
  if(!l||!r.season||!r.phase||!r.indicator||!r.source_url){hold(r,'missing_scope_or_source');continue}
  if(r.category==='Aperçu général'){hold(r,'ambiguous_category');continue}
  const v=numeric(r.raw_value);if(v===null){hold(r,'missing_or_invalid_value');continue}
  let id;
  if(r.type==='Club')id=clubs.get([r.competition,r.season,norm(r.subject)].join('|'));
  else if(r.type==='Joueur'){
   const matches=playerNames.get([l,norm(r.subject)].join('|'))||[];
   if(matches.length!==1){hold(r,matches.length?'homonym':'player_unmatched');continue}
   const club=clubs.get([r.competition,r.season,norm(r.club)].join('|'));
   if(!club||!members.has([matches[0].id,club,r.season].join('|'))){hold(r,'historical_club_unverified');continue}
   id=matches[0].id;
  }else{hold(r,'unknown_type');continue}
  if(!id){hold(r,'club_unmatched');continue}
  const obs={competition:r.competition,season:r.season,phase:r.phase,type:r.type,entityId:id,indicator:r.indicator,unit:r.unit??null,scope:r.source_scope??null,value:v,sources:[r.source_url],sourceCategory:r.category};
  const k=key(obs),fingerprint=hash([k,v,r.source_url]);if(seen.has(fingerprint)){stats.duplicates++;continue}seen.add(fingerprint);
  const existing=facts.get(k);
  if(existing){if(existing.value!==v){stats.conflicts++;if(conflictSamples.length<100)conflictSamples.push({key:k,old:existing.value,new:v,source:r.source_url});continue}stats.already_present++;if(!existing.sources.includes(r.source_url))existing.sources.push(r.source_url);continue}
  obs.id=k;out.rugbyDataObservations.push(obs);facts.set(k,obs);stats.added++;stats.byCompetition[r.competition].added++;
 }
 return {db:out,report:{...stats,pendingSamples,conflictSamples}};
}
export async function* jsonLines(file){const rl=readline.createInterface({input:fs.createReadStream(file,{encoding:'utf8'}),crlfDelay:Infinity});for await(const s of rl)if(s.trim())yield JSON.parse(s)}
if(process.argv[1]?.endsWith('import_into_v6.mjs')){
 try{
  const a={};for(let i=2;i<process.argv.length;i+=2)a[process.argv[i].replace(/^--/,'')]=process.argv[i+1];
  for(const n of ['db','input','mapping','out','report'])if(!a[n])throw Error('Argument manquant --'+n);
  if(new Set([a.db,a.input,a.mapping,a.out,a.report]).size!==5)throw Error('Entrées et sorties doivent être distinctes');
  const {db,report}=await integrate(JSON.parse(fs.readFileSync(a.db)),jsonLines(a.input),JSON.parse(fs.readFileSync(a.mapping)));
  fs.writeFileSync(a.out,JSON.stringify(db));fs.writeFileSync(a.report,JSON.stringify(report,null,2));console.log(JSON.stringify(report));
 }catch(e){console.error(e);process.exitCode=1}
}
