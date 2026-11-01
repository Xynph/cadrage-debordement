const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const dataset = JSON.parse(fs.readFileSync(path.join(__dirname, '../modding/data06/user-birthyears-150-2026-11-01.json'), 'utf8'));
test('DATA-06 : 150 identifiants LNR distincts', () => { assert.equal(dataset.records.length,150); assert.equal(new Set(dataset.records.map(x=>x.lnrId)).size,150); });
test('DATA-06 : annees plausibles', () => { for(const r of dataset.records){assert(/^lnr:[0-9]+$/.test(r.lnrId));assert(Number.isInteger(r.birthYear));assert(r.birthYear>=1900&&r.birthYear<=2010);} });
test('DATA-06 : trois dates utilisateur conservees', () => { for(const [id,date] of [['lnr:13725','2007-03-10'],['lnr:13497','2005-01-01'],['lnr:11779','2003-02-14']]){const r=dataset.records.find(x=>x.lnrId===id);assert(r);assert.equal(r.userConfirmedBirthDate,date);assert.equal(r.birthYear,Number(date.slice(0,4)));assert.equal(r.historicalConflictRetained,true);} });
test('DATA-06 : provenance utilisateur explicite',()=>{assert.match(dataset.source,/user/);assert.match(dataset.status,/not-independent/);});
