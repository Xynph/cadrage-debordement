'use strict';
const test=require('node:test'), assert=require('node:assert/strict');
const d=['01','02','03','04','05'].flatMap(n=>require('../modding/data05-bulk3/profiles-'+n+'.json').players);
const staff=require('../modding/data05-bulk3/official-staff.json');
test('90 profils distincts validés',()=>{assert.equal(d.length,90);assert.equal(new Set(d.map(x=>x.id)).size,90);assert.equal(new Set(d.map(x=>x.club)).size,18);for(const p of d){assert.match(p.id,/^lnr:\d+$/);assert.match(p.url,/^https:\/\/(top14|prod2)\.lnr\.fr\/joueur\//);assert.ok(p.name&&p.position&&p.nationality&&p.age);assert.equal(p.birthDate,null);assert.equal(p.verifiedAtStart,false);}assert.equal(d.filter(x=>x.height&&x.weightKg&&x.age).length,81)});
test('staff source officiel et temporalité conservées',()=>{assert.equal(staff.staff.length,26);assert.equal(new Set(staff.staff.map(x=>x.club)).size,2);for(const s of staff.staff){assert.ok(s.name&&s.role&&s.sourceUrl);assert.ok(['not-established','supported-from-before-start'].includes(s.historicalAtJuly1));}assert.equal(staff.staff.filter(s=>s.club==='paris').length,23);});
