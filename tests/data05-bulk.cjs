'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const path=require('node:path');
const load=p=>require(path.join(__dirname,'..',p));
const chosen=load('modding/data05-bulk/selection.json').clubs.flatMap(c=>c.players.map(p=>({...p,club:c.club})));
const entries=['01','02','03','04','05'].flatMap(n=>load('modding/data05-bulk/profiles-'+n+'.json').profiles);
test('90 ids LNR uniques et meme selection',()=>{
 assert.equal(chosen.length,90);assert.equal(entries.length,90);
 assert.equal(new Set(entries.map(p=>p.id)).size,90);
 assert.equal(new Set(entries.map(p=>p.club)).size,30);
 const lookup=new Map(chosen.map(p=>[p.id,p]));
 for(const p of entries){
   const source=lookup.get(p.id);assert.ok(source);assert.equal(source.club,p.club);assert.equal(source.url,p.sourceUrl);
   assert.equal(p.error,null);assert.match(p.sourceUrl,/^https:\/\/(top14|prod2)\.lnr\.fr\/joueur\/\d+-/);
   assert.ok(p.returnedName&&p.positionGroup&&p.nationality);
   assert.equal(p.birthDate,null);assert.equal(p.asOfJuly2026Verified,false);
   if(p.heightCm!==null)assert.ok(p.heightCm>=150&&p.heightCm<=225);
   if(p.weightKg!==null)assert.ok(p.weightKg>=65&&p.weightKg<=180);
 }
 assert.equal(entries.filter(p=>p.heightCm&&p.weightKg&&p.ageReported).length,88);
});
test('pas de faux staff ou faux transferts juillet 2026',()=>{
 const s=load('modding/data05-bulk/official-staff-evidence.json');
 const t=load('modding/data05-bulk/transfer-date-audit.json');
 assert.equal(s.staff.length,2);assert.equal(s.clubsWithoutStaffEvidence,28);
 assert.equal(s.futureStarts[0].effectiveFrom,'2027-07');
 assert.equal(t.transfers.length,30);
 assert.ok(t.transfers.every(x=>x.effectiveDate===null&&x.atCareerStart==='undetermined'));
});
