'use strict';
// Fixed, offline normalization of the 378 individually observed LNR pages.
// This is not a new transport or collector; it never makes network calls.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const ROOT=path.resolve(__dirname,'..');
const RAW_SHA='df405275851f7fa24366c561e7c926862d4010e76d5073d43ce381215a844431';
const IDENTITY_SHA='79184e3ec813e867fc802b7c7233c055acb1b8497e145b7b87899051e1bf4287';
const BASELINE_JSON_SHA='654a3ce905735d6df5c2911a28fba9a7d6d5bb62406ef73225f1b841373bc26f';
const COMPLETED='2026-10-31T21:50:29.139Z';
const CLUBS=Object.freeze({
 'ASM Clermont':'clermont','Aviron Bayonnais':'bayonne','Castres Olympique':'castres','LOU Rugby':'lyon',
 'Montpellier Hérault Rugby':'montpellier','RC Toulon':'toulon','RC Vannes':'vannes','Racing 92':'racing-92',
 'Section Paloise':'pau','Stade Français Paris':'paris','Stade Rochelais':'la-rochelle','Stade Toulousain':'toulouse',
 'USA Perpignan':'perpignan','Union Bordeaux-Bègles':'bordeaux-begles','US Dax':'dax','Provence Rugby':'provence-rugby',
 'Colomiers Rugby':'colomiers','SU Agen':'agen','AS Béziers Hérault':'beziers','FC Grenoble Rugby':'grenoble',
 'US Montauban':'montauban','RC Narbonnais':'narbonne','Nissa Rugby':'nice','Stade Aurillacois':'aurillac',
 'Oyonnax Rugby':'oyonnax','Soyaux-Angoulême XV':'angouleme','Biarritz Olympique PB':'biarritz',
 'Valence Romans':'valence-romans','USON Nevers':'nevers','CA Brive':'brive'
});
const POSITIONS=new Set(['1ère ligne','2ème ligne','3ème ligne','Demi de mêlée',"Demi d'ouverture",'Ailier','Arrière','Centre']);
const sha=s=>crypto.createHash('sha256').update(s).digest('hex');
function parseRow(line){
 const [numericId,clubAsPublished,position,...fields]=line.split('|');
 if(!/^[1-9]\d*$/.test(numericId)||!Object.hasOwn(CLUBS,clubAsPublished)||!POSITIONS.has(position)||![2,4].includes(fields.length))throw Error('Invalid row');
 let heightCm=null,weightKg=null;
 if(fields.length===4){
  const h=/^([12])m(\d{2})$/.exec(fields.shift()),w=/^(\d{2,3}) kg$/.exec(fields.shift());
  if(!h||!w)throw Error('Invalid measures');
  heightCm=Number(h[1])*100+Number(h[2]);weightKg=Number(w[1]);
  if(heightCm<140||heightCm>230||weightKg<45||weightKg>180)throw Error('Invalid measurement range');
 }
 const age=/^(\d{2}) ans$/.exec(fields[0]),nationalityAsPublished=fields[1];
 if(!age||Number(age[1])<16||Number(age[1])>60||!nationalityAsPublished?.trim()||/\r|\n/.test(nationalityAsPublished))throw Error('Invalid age or nationality');
 return {id:'lnr:'+numericId,club:CLUBS[clubAsPublished],clubAsPublished,position,heightCm,weightKg,ageReported:Number(age[1]),nationalityAsPublished,rawProfileText:line.slice(numericId.length+1).replaceAll('|','\n')};
}
function loadInputs(root=ROOT){
 const read=file=>JSON.parse(fs.readFileSync(path.join(root,file),'utf8'));
 return {roster:read('modding/data06/all-players-2026-2027.json').players,
  baseline:read('modding/data06/itsrugby-browser-reconciliation-2026-10-31.json'),
  rawText:[1,2,3].map(n=>fs.readFileSync(path.join(root,'modding/data06/remaining-lnr-raw-0'+n+'.txt'),'utf8')).join('')};
}
function validateRows(rawText,roster,baseline){
 if(sha(rawText)!==RAW_SHA)throw Error('Raw browser transfer integrity mismatch');
 if(sha(JSON.stringify(baseline))!==BASELINE_JSON_SHA)throw Error('Baseline remaining coverage integrity mismatch');
 if(!Array.isArray(roster)||roster.length!==1592||new Set(roster.map(p=>p.id)).size!==1592)throw Error('Invalid roster identities');
 const known=new Map(roster.map(p=>[p.id,p])),previousIds=new Set(roster.filter(p=>p.profileEnriched).map(p=>p.id));
 for(const p of baseline.players){
  if(!known.has(p.id)||known.get(p.id).club!==p.club)throw Error('Invalid baseline identity');
  if(p.position||p.heightCm!==null||p.weightKg!==null||p.ageAsPublished!==null)previousIds.add(p.id);
 }
 const missing=roster.filter(p=>!previousIds.has(p.id)).map(p=>p.id),expected=new Set(baseline.remainingIds);
 if(previousIds.size!==1214||expected.size!==378||baseline.remainingIds.length!==378||missing.length!==378||missing.some(id=>!expected.has(id))||baseline.summary.totalCovered!==previousIds.size)throw Error('Invalid baseline remaining coverage');
 const rows=rawText.trimEnd().split('\n').map(parseRow),seen=new Set(),identities=[];
 for(const row of rows){
  if(seen.has(row.id))throw Error('Duplicate observation');
  seen.add(row.id);const p=known.get(row.id);
  if(!p||!expected.has(row.id)||p.club!==row.club)throw Error('Unknown remaining identity or club mismatch');
  const source=new URL(p.url),host=p.league==='top14'?'top14.lnr.fr':p.league==='prod2'?'prod2.lnr.fr':null;
  if(source.protocol!=='https:'||source.hostname!==host||source.search||source.hash||!source.pathname.startsWith('/joueur/'+p.id.slice(4)+'-'))throw Error('Invalid identity URL');
  // This exact tuple was hashed inside the browser for every observed page.
  identities.push({id:Number(p.id.slice(4)),url:p.url,name:p.name.toUpperCase(),club:source.origin+'/club/'+row.club});
 }
 if(rows.length!==378||seen.size!==378||[...expected].some(id=>!seen.has(id)))throw Error('Incomplete remaining coverage');
 const identitySha256=sha(JSON.stringify(identities.sort((a,b)=>a.id-b.id)));
 if(identitySha256!==IDENTITY_SHA)throw Error('Browser identity transfer integrity mismatch');
 return {rows,known,previousIds,integrity:{rawSha256:RAW_SHA,identitySha256,rawBytes:Buffer.byteLength(rawText)}};
}
function build(root=ROOT){
 const inputs=loadInputs(root),{rows,known,previousIds,integrity}=validateRows(inputs.rawText,inputs.roster,inputs.baseline);
 const players=rows.map(row=>{
  const ref=known.get(row.id);
  return {...row,name:ref.name,sourceName:ref.name.toUpperCase(),sourceUrl:ref.url,sourceType:'lnr-individual-snapshot',
   capturedAt:'2026-10-31',confidence:'exact-lnr-id-url-name-and-club-verified',birthDate:null,jiff:null,
   firstRowQualification:null,contractEnd:null,salary:null,clubBudget:null,actualPerformance:null,
   gameRatingEstimate:null,validAtCareerStart:null,
   qualityFlags:row.weightKg>145?['weight-above-145kg-review']:[]};
 }).sort((a,b)=>Number(a.id.slice(4))-Number(b.id.slice(4)));
 const total=new Set([...previousIds,...players.map(p=>p.id)]);
 return {schema:'data06-remaining-lnr-evidence-v1',season:'2026-2027',historicalJuly2026:false,
  collection:{method:'public-browser-rendered-dom',completedAt:COMPLETED,individualPages:378,discoveryClubPages:30,redirects:0,
   detail:'URLs, uppercased returned headings and club URLs independently hashed in the browser; compact raw text transferred with separate SHA256. No images, account login or paid service.'},
  integrity,baseline:{pr:155,head:'afab8680b23cd6087f415ad34291107ca075189d',reportSha256:sha(fs.readFileSync(path.join(root,'modding/data06/itsrugby-browser-reconciliation-2026-10-31.json')))},
  summary:{target:1592,clubs:new Set(players.map(p=>p.club)).size,previouslyCovered:previousIds.size,additionalProfiles:players.length,
   totalCovered:total.size,remainingIdentityProfiles:1592-total.size,
   withPosition:players.filter(p=>p.position).length,withAge:players.filter(p=>p.ageReported!==null).length,
   withNationalityAsPublished:players.filter(p=>p.nationalityAsPublished).length,
   withHeight:players.filter(p=>p.heightCm!==null).length,withWeight:players.filter(p=>p.weightKg!==null).length,
   measurementsMissing:players.filter(p=>p.heightCm===null||p.weightKg===null).length,
   measurementReview:players.filter(p=>p.qualityFlags.length).map(p=>p.id),completeBiographies:0},
  players};
}
if(require.main===module){
 const output=path.join(ROOT,'modding/data06/remaining-lnr-profiles-2026-10-31.json'),d=build();
 fs.writeFileSync(output,JSON.stringify(d,null,2)+'\n');console.log(JSON.stringify(d.summary,null,2));
}
module.exports={parseRow,loadInputs,validateRows,build};
