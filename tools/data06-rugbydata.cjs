'use strict';
// Offline adapter for public Rugby Data observations; no transport, no game writes.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const ROOT=path.resolve(__dirname,'..'),BASE='https://www.rugbydata.fr';
const CLUB_MAP=Object.freeze({8:'clermont',5:'bayonne',9:'castres',10:'lyon',11:'montpellier',13:'toulon',19:'vannes',12:'racing-92',14:'pau',15:'paris',16:'la-rochelle',17:'toulouse',18:'perpignan',6:'bordeaux-begles',24:'dax',21:'provence-rugby',29:'colomiers',32:'agen',22:'beziers',23:'grenoble',34:'montauban',37:'narbonne',35:'nice',28:'aurillac',20:'oyonnax',31:'angouleme',33:'biarritz',30:'valence-romans',26:'nevers',25:'brive'});
function key(s){return String(s).normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase().replace(/[^a-z0-9]+/g,' ').trim()}
function fields(raw){
 if(!Array.isArray(raw))throw Error('Invalid fields');
 const out=new Map();
 for(const f of raw){
  if(typeof f.label!=='string'||typeof f.value!=='string')throw Error('Invalid field value');
  const k=key(f.label),v=f.value.trim();
  if(out.has(k)&&out.get(k)!==v)throw Error('Conflicting duplicate label');
  out.set(k,v);
 }
 return out;
}
function profileUrl(id,url){
 if(!/^\d+$/.test(id)||url!==BASE+'/players/view/'+id)throw Error('Invalid profile URL or ID');
}
function provenance(s){
 if(typeof s.capturedAt!=='string'||!/^2026-10-31T/.test(s.capturedAt)||!Number.isFinite(Date.parse(s.capturedAt))||!/^[a-f0-9]{64}$/.test(s.htmlSha256))throw Error('Invalid source provenance');
}
function isoDate(s){
 if(!s)return null;
 const m=/^(\d{2})\/(\d{2})\/(\d{4})$/.exec(s);if(!m)return null;
 const d=Number(m[1]),mo=Number(m[2]),y=Number(m[3]),date=new Date(Date.UTC(y,mo-1,d));
 return y>=1900&&date.getTime()<=Date.UTC(2026,9,31)&&date.getUTCFullYear()===y&&date.getUTCMonth()===mo-1&&date.getUTCDate()===d?m[3]+'-'+m[2]+'-'+m[1]:null;
}
function value(f,label,parse=x=>x||null){const s=f.get(key(label));return s===undefined?null:parse(s)}
const jiff=s=>key(s)==='oui'?true:key(s)==='non'?false:null;
const number=(s,unit,min,max)=>{const m=new RegExp('^(\\d{1,4})'+(unit?'\\s*'+unit:'')+'$').exec(s);return m&&Number(m[1])>=min&&Number(m[1])<=max?Number(m[1]):null};
function reconcile(capture,roster,profiles){
 if(capture.source!==BASE||capture.season!=='2026-2027'||!Array.isArray(capture.clubs)||!Array.isArray(roster)||!Array.isArray(profiles))throw Error('Invalid collection period or inputs');
 const ids=new Set(),names=new Map(),profileMap=new Map(),seenClubs=new Set(),rows=[];
 for(const p of roster){
  if(typeof p.id!=='string'||!/^lnr:\d+$/.test(p.id)||ids.has(p.id)||typeof p.name!=='string'||!p.name.trim())throw Error('Invalid LNR roster');
  ids.add(p.id);const k=key(p.name);if(!names.has(k))names.set(k,[]);names.get(k).push(p);
 }
 for(const p of profiles){
  profileUrl(p.sourceRecordId,p.sourceUrl);if(profileMap.has(p.sourceRecordId))throw Error('Duplicate source profile');
  if(!p.error){provenance(p);if(typeof p.name!=='string'||!p.name.trim()||!Array.isArray(p.positionsAsPublished)||p.positionsAsPublished.some(x=>typeof x!=='string'||!x.trim())||!Array.isArray(p.contractsAsPublished))throw Error('Invalid individual profile');fields(p.fields);}
  profileMap.set(p.sourceRecordId,p);
 }
 for(const club of capture.clubs){
  if(CLUB_MAP[club.sourceClubId]!==club.club||seenClubs.has(club.club)||club.seasonAsPublished!=='2026-2027'||club.sourceUrl!==BASE+'/club/effectif/panel/'+club.sourceClubId+'/27')throw Error('Invalid club mapping or season');
  seenClubs.add(club.club);provenance(club);
  if(!Array.isArray(club.players)||!club.players.length)throw Error('Missing roster rows');
  for(const p of club.players){profileUrl(p.sourceRecordId,p.sourceUrl);if(typeof p.name!=='string'||!p.name.trim())throw Error('Invalid source name');fields(p.fields);rows.push({...p,club:club.club,rosterSourceUrl:club.sourceUrl,rosterCapturedAt:club.capturedAt});}
 }
 const counts=new Map(),targetCounts=new Map();
 for(const p of rows){counts.set(p.sourceRecordId,(counts.get(p.sourceRecordId)||0)+1);const k=p.club+'|'+key(p.name);targetCounts.set(k,(targetCounts.get(k)||0)+1);}
 const players=[],review=[],conflicts=[],acceptedIds=new Set();
 for(const row of rows){
  const candidates=names.get(key(row.name))||[],ref=candidates.length===1?candidates[0]:null;
  const reason=counts.get(row.sourceRecordId)!==1?'source-listed-multiple-times':targetCounts.get(row.club+'|'+key(row.name))!==1?'target-listed-multiple-times':!ref?(candidates.length?'homonym':'no-exact-name'):ref.club!==row.club?'club-mismatch':null;
  if(reason){review.push({sourceRecordId:row.sourceRecordId,name:row.name,club:row.club,sourceUrl:row.rosterSourceUrl,reason,candidateIds:candidates.map(p=>p.id)});continue}
  if(acceptedIds.has(ref.id))throw Error('Duplicate target ID');acceptedIds.add(ref.id);
  let profile=profileMap.get(row.sourceRecordId)||null;
  if(profile?.error){review.push({id:ref.id,sourceRecordId:row.sourceRecordId,sourceUrl:row.sourceUrl,reason:profile.attempted===false?'profile-not-attempted':'profile-fetch-failed',error:profile.error});profile=null;}
  if(profile&&key(profile.name)!==key(ref.name)){review.push({id:ref.id,sourceRecordId:row.sourceRecordId,sourceUrl:row.sourceUrl,reason:'profile-name-mismatch',returnedName:profile.name});profile=null;}
  const rf=fields(row.fields),pf=profile?fields(profile.fields):new Map(),fieldSources={},qualityFlags=[];
  const conflict=(field,details)=>conflicts.push({id:ref.id,sourceRecordId:row.sourceRecordId,field,...details});
  function merge(field,label,parser=x=>x||null,profileLabel=label){
   const a=value(rf,label,parser),b=value(pf,profileLabel,parser),sources=[];
   if(a!==null)sources.push(row.rosterSourceUrl);if(b!==null)sources.push(row.sourceUrl);
   if(a!==null&&b!==null&&JSON.stringify(a)!==JSON.stringify(b)){conflict(field,{reason:'source-disagreement',roster:a,profile:b,sourceUrls:sources});return null;}
   const v=b??a;if(v!==null)fieldSources[field]=sources;return v;
  }
  const birthRaw=pf.get(key('Date de naissance'))||null,birthDate=isoDate(birthRaw);
  if(birthRaw&&!birthDate)conflict('birthDate',{reason:'invalid-published-date',raw:birthRaw,sourceUrls:[row.sourceUrl]});
  if(birthDate)fieldSources.birthDate=[row.sourceUrl];
  let heightCm=merge('heightCm','Taille',s=>number(s,'cm',140,230)),weightKg=merge('weightKg','Poids',s=>number(s,'kg',45,180));
  for(const [field,v] of [['heightCm',heightCm],['weightKg',weightKg]])if(ref[field]!=null&&v!=null&&ref[field]!==v){conflict(field,{reason:'existing-value-preserved',previous:ref[field],previousSourceUrl:ref.measurementSources?.[field]||ref.url||null,observed:v,sourceUrls:fieldSources[field]});if(field==='heightCm')heightCm=null;else weightKg=null;}
  const positionRaw=rf.get(key('Poste'))||null,positionsAsPublished=profile?.positionsAsPublished.length?profile.positionsAsPublished:(positionRaw?[positionRaw]:[]);
  if(positionsAsPublished.length)fieldSources.positionsAsPublished=[profile?.positionsAsPublished.length?row.sourceUrl:row.rosterSourceUrl];
  let country=profile?value(pf,'Nationalité')||row.nationalityAsPublished:row.nationalityAsPublished;
  if(profile&&value(pf,'Nationalité')&&row.nationalityAsPublished&&key(value(pf,'Nationalité'))!==key(row.nationalityAsPublished)){
   conflict('nationalityAsPublished',{reason:'source-disagreement',roster:row.nationalityAsPublished,profile:value(pf,'Nationalité'),sourceUrls:[row.rosterSourceUrl,row.sourceUrl]});country=null;
  }
  if(country)fieldSources.nationalityAsPublished=[profile&&value(pf,'Nationalité')?row.sourceUrl:row.rosterSourceUrl];
  if(weightKg>145)qualityFlags.push('weight-above-145kg-review');
  const preferredFootAsPublished=value(pf,'Meilleur pied'),trainingClubsAsPublished=value(pf,'Clubs formateurs');
  if(preferredFootAsPublished)fieldSources.preferredFootAsPublished=[row.sourceUrl];
  if(trainingClubsAsPublished)fieldSources.trainingClubsAsPublished=[row.sourceUrl];
  const item={id:ref.id,name:ref.name,club:ref.club,sourceRecordId:row.sourceRecordId,sourceName:row.name,profileSourceName:profile?.name||null,rosterSourceUrl:row.rosterSourceUrl,profileSourceUrl:profile?row.sourceUrl:null,capturedAt:profile?.capturedAt||row.rosterCapturedAt,
   confidence:'exact-normalized-full-name-and-club-unique',birthDate,jiff:merge('jiff','JIFF',jiff),positionsAsPublished,
   ageAsPublished:merge('ageAsPublished','Âge',s=>number(s,'ans',15,65)),nationalityAsPublished:country||null,heightCm,weightKg,
   preferredFootAsPublished,trainingClubsAsPublished,contractEndYearAsPublished:merge('contractEndYearAsPublished','Année de fin de contrat',s=>number(s,'',2026,2045),'Fin de contrat'),
   seasonContractStartAsPublished:value(rf,'Début de contrat'),seasonContractEndAsPublished:value(rf,'Fin de contrat'),seasonContractTypeAsPublished:value(rf,'Type de contrat'),
   contractsAsPublished:profile?.contractsAsPublished||[],contractEnd:null,firstRowQualification:null,salary:null,clubBudget:null,gameRatingEstimate:null,validAtCareerStart:null,fieldSources,qualityFlags};
  players.push(item);
 }
 players.sort((a,b)=>Number(a.id.slice(4))-Number(b.id.slice(4)));
 const count=f=>players.filter(p=>p[f]!==null&&(Array.isArray(p[f])?p[f].length>0:true)).length;
 return {schema:'data06-rugbydata-enrichment-v1',source:BASE,season:'2026-2027',historicalAsOfJuly1Verified:false,
  summary:{target:roster.length,sourceClubs:seenClubs.size,sourceRows:rows.length,sourceDistinctPlayers:counts.size,matchedPlayers:players.length,individualProfilesUsed:players.filter(p=>p.profileSourceUrl).length,
   birthDates:count('birthDate'),jiff:count('jiff'),positions:count('positionsAsPublished'),trainingClubs:count('trainingClubsAsPublished'),preferredFoot:count('preferredFootAsPublished'),contractEndYears:count('contractEndYearAsPublished'),
   heights:count('heightCm'),weights:count('weightKg'),conflicts:conflicts.length,reviewEntries:review.length,remainingWithoutThisSource:roster.length-players.length,
   profileFetchFailures:review.filter(p=>p.reason==='profile-fetch-failed').length,profilesNotAttempted:review.filter(p=>p.reason==='profile-not-attempted').length,remainingWithoutBirthDate:roster.length-count('birthDate')},
  players,review,conflicts,remainingIds:roster.filter(p=>!acceptedIds.has(p.id)).map(p=>p.id)};
}
function withMeasurements(roster,baseline){
 if(!Array.isArray(baseline.players)||baseline.players.length!==roster.length)throw Error('Invalid measurement baseline size');
 const map=new Map();
 for(const p of baseline.players){
  if(map.has(p.id))throw Error('Duplicate measurement baseline ID');
  for(const [field,min,max] of [['heightCm',140,230],['weightKg',45,180]])if(p[field]!==null){
   if(!Number.isInteger(p[field])||p[field]<min||p[field]>max)throw Error('Invalid prior measurement');
   const u=new URL(p.measurementSources?.[field]);
   if(u.protocol!=='https:'||!['top14.lnr.fr','prod2.lnr.fr','itsrugby.fr'].includes(u.hostname))throw Error('Invalid prior measurement source');
  }
  map.set(p.id,p);
 }
 return roster.map(p=>{
  const old=map.get(p.id);if(!old)throw Error('Unknown measurement baseline ID');
  for(const field of ['heightCm','weightKg'])if(p[field]!=null&&p[field]!==old[field])throw Error('Canonical measurement would be changed');
  return {...p,heightCm:old.heightCm,weightKg:old.weightKg,measurementSources:old.measurementSources};
 });
}
function build(root=ROOT){
 const read=p=>JSON.parse(fs.readFileSync(path.join(root,p),'utf8'));
 const capture=read('modding/data06/rugbydata-rosters-2026-10-31.json'),originalRoster=read('modding/data06/all-players-2026-2027.json').players;
 const roster=withMeasurements(originalRoster,read('modding/data06/rugbydata-comparison-baseline-2026-10-31.json'));
 if(roster.length!==1592||capture.clubs.length!==30)throw Error('Unexpected production scope');
 const batches=[1,2,3,4].map(n=>read('modding/data06/rugbydata-profiles-0'+n+'.json'));
 if(batches.some(b=>b.snapshotComplete!==true||!Array.isArray(b.results)))throw Error('Profile collection is incomplete');
 const profiles=batches.flatMap(b=>b.results);
 const expected=new Set(reconcile(capture,roster,[]).players.map(p=>p.sourceRecordId));
 if(profiles.length!==expected.size||new Set(profiles.map(p=>p.sourceRecordId)).size!==expected.size||profiles.some(p=>!expected.has(p.sourceRecordId)))throw Error('Incomplete individual profile accounting');
 const inputs=['modding/data06/all-players-2026-2027.json','modding/data06/rugbydata-comparison-baseline-2026-10-31.json','modding/data06/rugbydata-rosters-2026-10-31.json',...[1,2,3,4].map(n=>'modding/data06/rugbydata-profiles-0'+n+'.json')];
 return {...reconcile(capture,roster,profiles),inputIntegrity:inputs.map(file=>({file,sha256:crypto.createHash('sha256').update(fs.readFileSync(path.join(root,file))).digest('hex')}))};
}
if(require.main===module){const d=build();fs.writeFileSync(path.join(ROOT,'modding/data06/rugbydata-enrichment-2026-10-31.json'),JSON.stringify(d,null,2)+'\n');console.log(JSON.stringify(d.summary,null,2));}
module.exports={key,isoDate,reconcile,withMeasurements,build};
