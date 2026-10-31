'use strict';
/**
 * Run from a network-connected Node 20+ host:
 *   node tools/data06-itsrugby-bulk.cjs --clubs clermont,toulouse,brive
 * Fetches entire published team roster pages, not individual profiles.
 * Does not publish any unverified identity joins.
 */
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const {setTimeout:delay}=require('node:timers/promises');
const BASE='https://itsrugby.fr';
const safeSlug=s=>/^[a-z0-9-]+$/.test(s);
const sleep=ms=>delay(ms);
// Explicit mappings checked on the two published standings, never array positions.
const CLUB_MAP=Object.freeze({'clermont':'clermont','stade-toulousain':'toulouse','union-bordeaux-begles':'bordeaux-begles','lou':'lyon','pau':'pau','bayonne':'bayonne','stade-francais':'paris','montpellier':'montpellier','la-rochelle':'la-rochelle','toulon':'toulon','usap':'perpignan','castres':'castres','racing-92':'racing-92','vannes':'vannes','oyonnax':'oyonnax','provence-rugby':'provence-rugby','grenoble':'grenoble','brive':'brive','montauban':'montauban','biarritz':'biarritz','soyaux-angouleme':'angouleme','aurillac':'aurillac','dax':'dax','agen':'agen','valence-romans-drome-rugby':'valence-romans','colomiers':'colomiers','nice':'nice','narbonne':'narbonne','beziers':'beziers','nevers':'nevers'});
async function collect({slugs,out='data06-itsrugby-capture',fetchFn=fetch,paceMs=1800}){
 if(!Array.isArray(slugs)||!slugs.length||slugs.some(s=>!safeSlug(s))) throw Error('Provide valid team slugs');
 fs.mkdirSync(out,{recursive:true});
 const results=[];let stopped=false;
 for(const [i,requestedSlug] of slugs.entries()){
   const slug=requestedSlug==='toulouse'?'stade-toulousain':requestedSlug;
   if(stopped){results.push({slug,ok:false,attempted:false,error:'Unattempted after access refusal or rate limit'});continue}
   if(i)await sleep(paceMs);
   const url=BASE+'/equipes/'+slug+'/?saison=2026-27';
   let status=null;
   try{
     const r=await fetchFn(url,{headers:{'User-Agent':'CadrageDebordement-DATA06/1.0 (authorized research; contact via repository)',Accept:'text/html'},signal:AbortSignal.timeout(20000)});
     status=r.status??null;
     if([401,403,429].includes(status))stopped=true;
     if(!r.ok)throw Error('HTTP '+r.status);
     const html=await r.text();
     if(html.length<1000 || !/id=["']effectif-list["']/i.test(html)|| !/\bfd-eff-row\b/.test(html))throw Error('No rendered player rows; browser Effectif section may be required');
     const file=slug+'.html';
     fs.writeFileSync(path.join(out,file),html);
     results.push({slug,url,status,ok:true,attempted:true,file,bytes:Buffer.byteLength(html),sha256:crypto.createHash('sha256').update(html).digest('hex')});
   }catch(e){results.push({slug,url,status,ok:false,attempted:true,error:String(e.message||e).slice(0,200)});}
 }
 const result={source:BASE,season:'2026-27',capturedAt:new Date().toISOString(),allowedUse:'User-confirmed site authorization 2026-10-31',stopped,results};
 fs.writeFileSync(path.join(out,'manifest.json'),JSON.stringify(result,null,2)+'\n');
 return result;
}
function nameKey(name){
 return name.replace(/&#(x[0-9a-f]+|\d+);/gi,(_,s)=>String.fromCodePoint(s[0].toLowerCase()==='x'?parseInt(s.slice(1),16):Number(s)))
 .replace(/&apos;|&rsquo;/g,"'").replace(/&amp;/g,'&').replace(/&quot;/g,'"')
 .normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase().replace(/[^a-z0-9]+/g,' ').trim();
}
function reconcileBrowserCapture(capture,roster,previous){
 if(capture.season!=='2026-27'||capture.historicalJuly2026!==false||!Array.isArray(capture.clubs)||!Array.isArray(roster)||!Array.isArray(previous))throw Error('Invalid collection period or inputs');
 const knownClubs=new Set(roster.map(p=>p.club)),names=new Map(),old=new Map(previous.map(p=>[p.id,p]));
 if(new Set(roster.map(p=>p.id)).size!==roster.length)throw Error('Duplicate LNR ID');
 const rosterIds=new Set(roster.map(p=>p.id));
 if(old.size!==previous.length||previous.some(p=>!rosterIds.has(p.id)))throw Error('Invalid existing profile IDs');
 for(const p of roster){const k=nameKey(p.name);if(!names.has(k))names.set(k,[]);names.get(k).push(p)}
 const rows=[];
 for(const club of capture.clubs){
  if(!knownClubs.has(club.lnrClub)||CLUB_MAP[club.slug]!==club.lnrClub||!Array.isArray(club.players))throw Error('Unknown club mapping');
  const source=new URL(club.sourceUrl);
  if(source.origin!==BASE||source.pathname!=='/equipes/'+club.slug+'/'||source.searchParams.get('saison')!=='2026-27'||!/^2026-10-31(?:$|T)/.test(club.capturedAt)||!Number.isFinite(Date.parse(club.capturedAt)))throw Error('Invalid source provenance');
  for(const p of club.players){
   if(typeof p.name!=='string'||!nameKey(p.name)||!/^\d+$/.test(p.sourceRecordId)||typeof p.position!=='string'||p.nationality!==null||p.dateOfBirth!==null)throw Error('Invalid identity or unpublished field');
   for(const [f,min,max] of [['heightCm',140,230],['weightKg',45,180],['ageAsPublished',16,60]])
    if(p[f]!==null&&(!Number.isInteger(p[f])||p[f]<min||p[f]>max))throw Error('Invalid '+f);
   rows.push({...p,club:club.lnrClub,sourceSlug:club.slug,sourceUrl:club.sourceUrl,capturedAt:club.capturedAt});
  }
 }
 const counts=new Map(),targetCounts=new Map();
 for(const p of rows){counts.set(p.sourceRecordId,(counts.get(p.sourceRecordId)||0)+1);const key=p.club+'|'+nameKey(p.name);targetCounts.set(key,(targetCounts.get(key)||0)+1)}
 const players=[],review=[],conflicts=[];
 for(const p of rows){
  const candidates=names.get(nameKey(p.name))||[],target=candidates.length===1?candidates[0]:null;
  let reason=candidates.length>1?'homonym':!target?'no-exact-name':target.club!==p.club?'club-mismatch':null;
  if(counts.get(p.sourceRecordId)>1)reason='source-listed-multiple-times';
  if(targetCounts.get(p.club+'|'+nameKey(p.name))>1)reason='target-listed-multiple-times';
  if(reason){review.push({sourceRecordId:p.sourceRecordId,name:p.name,club:p.club,reason,candidateIds:candidates.map(x=>x.id),sourceUrl:p.sourceUrl});continue}
  const item={id:target.id,club:target.club,name:target.name,sourceName:p.name,sourceRecordId:p.sourceRecordId,sourceUrl:p.sourceUrl,capturedAt:p.capturedAt,season:'2026-27',confidence:'exact-normalized-full-name-and-club-unique',position:p.position||null,heightCm:p.heightCm,weightKg:p.weightKg,ageAsPublished:p.ageAsPublished,nationality:null,dateOfBirth:null,validAtCareerStart:null};
  const existing=old.get(target.id);
  if(existing){for(const f of ['heightCm','weightKg'])if(existing[f]!=null&&item[f]!=null&&existing[f]!==item[f]){
    conflicts.push({id:target.id,field:f,previous:existing[f],observed:item[f],sourceUrl:p.sourceUrl});item[f]=null;
  }}
  players.push(item);
 }
 const covered=new Set([...old.keys(),...players.filter(p=>p.position||p.heightCm!==null||p.weightKg!==null||p.ageAsPublished!==null).map(p=>p.id)]);
 const remainingIds=roster.filter(p=>!covered.has(p.id)).map(p=>p.id);
 return {season:'2026-27',historicalJuly2026:false,summary:{target:roster.length,clubs: capture.clubs.length,observedRows:rows.length,uniqueSourcePlayers:counts.size,rowsWithMeasurements:rows.filter(p=>p.heightCm!==null||p.weightKg!==null).length,matched:players.length,matchedWithFields:players.filter(p=>p.position||p.heightCm!==null||p.weightKg!==null||p.ageAsPublished!==null).length,review:review.length,fieldConflicts:conflicts.length,previousProfiles:old.size,additionalProfiles:covered.size-old.size,totalCovered:covered.size,remaining:remainingIds.length},players,review,conflicts,remainingIds};
}
function buildBrowserReport(root,capture){
 const roster=['top14-a','top14-b','prod2-a','prod2-b'].flatMap(f=>JSON.parse(fs.readFileSync(path.join(root,'modding/data03',f+'.json'),'utf8')).clubs).flatMap(c=>c.players.map(p=>({...p,club:c.club})));
 const previous=[],existingSources=[];
 const {normal}=require('./data05-unified.cjs');
 for(const [dir,key] of [['data05-bulk','profiles'],['data05-bulk2','players'],['data05-bulk3','players']])for(let n=1;n<=5;n++){
  const file='modding/'+dir+'/profiles-'+String(n).padStart(2,'0')+'.json',bytes=fs.readFileSync(path.join(root,file));
  existingSources.push({file,sha256:crypto.createHash('sha256').update(bytes).digest('hex')});
  previous.push(...JSON.parse(bytes)[key].map(normal));
 }
 if(roster.length!==1592||new Set(previous.map(p=>p.id)).size!==240)throw Error('Unexpected baseline');
 return {...reconcileBrowserCapture(capture,roster,previous),existingSources,captureSha256:crypto.createHash('sha256').update(JSON.stringify(capture)).digest('hex')};
}
if(require.main===module){
 const argv=process.argv.slice(2),flag=argv.indexOf('--clubs');
 const browserFlag=argv.indexOf('--reconcile-browser');
 if(browserFlag>=0){
  const capture=JSON.parse(fs.readFileSync(argv[browserFlag+1],'utf8'));
  const report=buildBrowserReport(path.resolve(__dirname,'..'),capture);
  const outputFlag=argv.indexOf('--output');if(outputFlag<0)throw Error('--output required');
  fs.writeFileSync(argv[outputFlag+1],JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report.summary));
 }else{
 const slugs=flag>=0?(argv[flag+1]||'').split(',').filter(Boolean):[];
 const result=collect({slugs,out:process.env.DATA06_OUT||'data06-itsrugby-capture'});
 result.then(r=>{console.log(JSON.stringify({retrieved:r.results.filter(x=>x.ok).length,failed:r.results.filter(x=>!x.ok).length,total:r.results.length}));if(r.results.every(x=>!x.ok))process.exitCode=1}).catch(e=>{console.error(e);process.exitCode=1});
 }
}
module.exports={collect,safeSlug,CLUB_MAP,nameKey,reconcileBrowserCapture,buildBrowserReport};
