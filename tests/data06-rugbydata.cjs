'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const file=path.resolve(__dirname,'../tools/data06-rugbydata.cjs');
function api(){assert.ok(fs.existsSync(file),'Rugby Data normalizer missing');return require(file)}
const field=(label,value)=>({label,value});
const ref=(id,name,club='clermont',extra={})=>({id,name,club,birthDate:null,jiff:null,heightCm:null,weightKg:null,...extra});
const row=(name='Jean Exemple',id='10',fields=[])=>({sourceRecordId:id,sourceUrl:'https://www.rugbydata.fr/players/view/'+id,name,fields,nationalityAsPublished:'FRANCE'});
const capture=rows=>({source:'https://www.rugbydata.fr',season:'2026-2027',clubs:[{club:'clermont',sourceClubId:8,seasonAsPublished:'2026-2027',sourceUrl:'https://www.rugbydata.fr/club/effectif/panel/8/27',capturedAt:'2026-10-31T22:00:00+00:00',htmlSha256:'a'.repeat(64),players:rows}]});
const profile=(name='Jean EXEMPLE',id='10',fields=[])=>({sourceRecordId:id,sourceUrl:'https://www.rugbydata.fr/players/view/'+id,capturedAt:'2026-10-31T22:00:00+00:00',htmlSha256:'b'.repeat(64),name,fields,positionsAsPublished:['Pilier Gauche'],contractsAsPublished:[{clubAsPublished:'ASM Clermont',periodAndTypeAsPublished:'01/07/2026 - 30/06/2027 Contrat espoir'}]});
test('exact unique identity and club enrich birth, JIFF false, precise position, foot and training',()=>{
 const {reconcile}=api(),r=reconcile(capture([row()]),[ref('lnr:1','Jean EXEMPLE')],[profile(undefined,undefined,[field('Date de naissance :','29/02/2004'),field('JIFF :','Non'),field('Meilleur pied :','Gauche'),field('Clubs formateurs :','Club A, Club B')])]);
 assert.equal(r.players.length,1);const p=r.players[0];assert.equal(p.birthDate,'2004-02-29');assert.equal(p.jiff,false);assert.deepEqual(p.positionsAsPublished,['Pilier Gauche']);assert.equal(p.preferredFootAsPublished,'Gauche');assert.equal(p.trainingClubsAsPublished,'Club A, Club B');assert.equal(p.validAtCareerStart,null);assert.equal(p.firstRowQualification,null);assert.equal(p.salary,null);
});
test('homonyms, repeated source IDs and nonexact aliases stay in review',()=>{
 const {reconcile}=api();
 assert.equal(reconcile(capture([row()]),[ref('lnr:1','Jean EXEMPLE'),ref('lnr:2','Jean EXEMPLE')],[]).players.length,0);
 assert.equal(reconcile(capture([row(),row()]),[ref('lnr:1','Jean EXEMPLE')],[]).players.length,0);
 assert.equal(reconcile(capture([row('Johnny Exemple')]),[ref('lnr:1','Jean EXEMPLE')],[]).players.length,0);
 assert.equal(reconcile(capture([row()]),[ref('lnr:1','Jean EXEMPLE','pau')],[]).players.length,0);
});
test('profile name mismatch withholds individual fields but retains separately sourced roster facts',()=>{
 const {reconcile}=api(),r=reconcile(capture([row(undefined,undefined,[field('JIFF:','Oui')])]),[ref('lnr:1','Jean EXEMPLE')],[profile('Pierre Exemple',undefined,[field('Date de naissance :','01/01/2000')])]);
 assert.equal(r.players[0].birthDate,null);assert.equal(r.players[0].jiff,true);assert.ok(r.review.some(x=>x.reason==='profile-name-mismatch'));
});
test('invalid dates and unpublished fields remain unknown, no age-derived birthday',()=>{
 const {reconcile,isoDate}=api();assert.equal(isoDate('31/12/2026'),null);
 const r=reconcile(capture([row(undefined,undefined,[field('Âge:','23 ans')])]),[ref('lnr:1','Jean EXEMPLE')],[profile(undefined,undefined,[field('Date de naissance :','31/02/2003'),field('JIFF :','Inconnu')])]);
 assert.equal(r.players[0].birthDate,null);assert.equal(r.players[0].jiff,null);assert.ok(r.conflicts.some(x=>x.field==='birthDate'));
 assert.equal(r.players[0].ageAsPublished,23);assert.equal(r.players[0].contractEndYearAsPublished,null);
});
test('source differences and existing measurement differences are quarantined without overwriting',()=>{
 const {reconcile}=api(),input=[ref('lnr:1','Jean EXEMPLE','clermont',{weightKg:100})],before=JSON.stringify(input);
 const r=reconcile(capture([row(undefined,undefined,[field('Poids:','110 kg'),field('JIFF:','Oui')])]),input,[profile(undefined,undefined,[field('Poids :','110 kg'),field('JIFF :','Non')])]);
 assert.equal(r.players[0].weightKg,null);assert.equal(r.players[0].jiff,null);assert.equal(r.conflicts.length,2);assert.equal(JSON.stringify(input),before);
 const country=reconcile(capture([row()]),input,[profile(undefined,undefined,[field('Nationalité :','FIDJI')])]);
 assert.equal(country.players[0].nationalityAsPublished,null);assert.ok(country.conflicts.some(c=>c.field==='nationalityAsPublished'));
});
test('contract end year stays separate from annual dates and future timeline',()=>{
 const {reconcile}=api(),r=reconcile(capture([row(undefined,undefined,[field('Année de fin de contrat:','2029'),field('Début de contrat:','01/07/2026'),field('Fin de contrat:','30/06/2027')])]),[ref('lnr:1','Jean EXEMPLE')],[]);
 assert.equal(r.players[0].contractEndYearAsPublished,2029);assert.equal(r.players[0].seasonContractEndAsPublished,'30/06/2027');assert.equal(r.players[0].contractEnd,null);
});
test('foreign URLs, wrong seasons, unknown club mappings and duplicate profile IDs fail closed',()=>{
 const {reconcile}=api(),roster=[ref('lnr:1','Jean EXEMPLE')];
 const wrong=capture([row()]);wrong.clubs[0].sourceUrl='https://other.example/';assert.throws(()=>reconcile(wrong,roster,[]));
 const bad=capture([row()]);bad.season='2025-2026';assert.throws(()=>reconcile(bad,roster,[]));
 const club=capture([row()]);club.clubs[0].sourceClubId=999;assert.throws(()=>reconcile(club,roster,[]));
 const ext=capture([row()]);ext.clubs[0].players[0].sourceUrl='https://other.example/players/view/10';assert.throws(()=>reconcile(ext,roster,[]));
 assert.throws(()=>reconcile(capture([row()]),roster,[profile(),profile()]));
});
test('pending PR measurement observations remain prioritized without changing the identity catalogue',()=>{
 const {withMeasurements,reconcile}=api(),base=[ref('lnr:1','Jean EXEMPLE')],before=JSON.stringify(base);
 const old={players:[{id:'lnr:1',heightCm:193,weightKg:156,measurementSources:{heightCm:'https://top14.lnr.fr/joueur/1-jean-exemple',weightKg:'https://top14.lnr.fr/joueur/1-jean-exemple'}}]};
 const combined=withMeasurements(base,old);assert.equal(JSON.stringify(base),before);
 const result=reconcile(capture([row(undefined,undefined,[field('Poids:','149 kg')])]),combined,[]);
 assert.equal(result.players[0].weightKg,null);assert.equal(result.conflicts[0].previous,156);assert.equal(result.conflicts[0].previousSourceUrl,'https://top14.lnr.fr/joueur/1-jean-exemple');
 assert.throws(()=>withMeasurements(base,{players:[old.players[0],old.players[0]]}));
 assert.throws(()=>withMeasurements([ref('lnr:1','Jean EXEMPLE','clermont',{weightKg:100})],old));
});
test('published corpus is complete for its recorded source scope, deterministic and offline',()=>{
 const {build}=api(),previous=global.fetch;let calls=0;
 try{global.fetch=()=>{calls++;throw Error('Network forbidden')};const d=build();assert.equal(d.summary.target,1592);assert.equal(d.summary.sourceClubs,30);assert.equal(d.summary.sourceRows,1493);assert.equal(calls,0);
 assert.equal(new Set(d.players.map(p=>p.id)).size,d.players.length);
 assert.equal(d.summary.birthDates,d.players.filter(p=>p.birthDate!==null).length);
 assert.equal(d.summary.jiff,d.players.filter(p=>p.jiff!==null).length);
 for(const p of d.players){assert.equal(p.salary,null);assert.equal(p.contractEnd,null);assert.equal(p.validAtCareerStart,null);assert.ok(p.fieldSources&&p.rosterSourceUrl);}
 const saved=fs.readFileSync(path.resolve(__dirname,'../modding/data06/rugbydata-enrichment-2026-10-31.json'),'utf8');assert.equal(saved,JSON.stringify(d,null,2)+'\n');
 }finally{global.fetch=previous}
});
