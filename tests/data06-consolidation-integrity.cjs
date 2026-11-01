'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const root = path.resolve(__dirname, '..');
const read = p => JSON.parse(fs.readFileSync(path.join(root,p),'utf8'));
const consolidated = read('modding/data06/consolidated-birthyears-1592-2026-11-01.json');
const roster = ['top14-a','top14-b','prod2-a','prod2-b'].flatMap(name =>
  read('modding/data03/'+name+'.json').clubs.flatMap(club =>
    club.players.map(player => ({id:player.id, name:player.name, club:club.club}))));
const sandbox = {};
vm.runInNewContext(fs.readFileSync(path.join(root,'dist/lnr-birthyears-data.js'),'utf8')+
  '\n;globalThis.births=LNR_BIRTHYEARS_DATA;',sandbox);
const births = sandbox.births;
test('DATA-06: couverture exacte du catalogue historique par identifiant LNR',()=>{
  assert.equal(roster.length,1592);
  assert.equal(new Set(roster.map(p=>p.id)).size,1592);
  assert.equal(consolidated.players.length,1592);
  const sourceIds=new Set(roster.map(p=>p.id));
  const ids=consolidated.players.map(p=>p.id);
  assert.equal(new Set(ids).size,1592);
  assert.deepEqual([...ids].sort(),[...sourceIds].sort());
  assert.deepEqual(Object.keys(births.byId).sort(),[...sourceIds].sort());
  for(const p of consolidated.players){
    const source=roster.find(r=>r.id===p.id);
    assert.equal(p.name,source.name,p.id+' name');
    assert.equal(p.club,source.club,p.id+' club');
    const birth=births.byId[p.id];
    const year=typeof birth==='number'?birth:Number(birth.slice(0,4));
    assert.equal(year,p.birthYear,p.id+' birth year');
    assert(Number.isInteger(year)&&year>=1900&&year<=2010,p.id);
  }
});
test('DATA-06: 1442 preuves et 150 années utilisateur sans double comptage',()=>{
  assert.equal(consolidated.summary.sourceVerified,1442);
  assert.equal(consolidated.summary.userSupplied,150);
  assert.equal(consolidated.summary.years,1592);
  const counts=new Map();
  for(const p of consolidated.players)counts.set(p.provenance,(counts.get(p.provenance)||0)+1);
  assert.equal(counts.get('research-evidence'),1442);
  assert.equal(counts.get('user-supplied'),150);
});
test('DATA-06: dates utilisateur préservées sans inventer les 1589 autres',()=>{
  const known=new Map([['lnr:13725','2007-03-10'],['lnr:13497','2005-01-01'],['lnr:11779','2003-02-14']]);
  const exact=Object.entries(births.byId).filter(([,v])=>typeof v==='string');
  assert.equal(exact.length,3);
  for(const [id,date] of known)assert.equal(births.byId[id],date);
  for(const [id,value] of Object.entries(births.byId)){
    if(known.has(id))continue;
    assert(Number.isInteger(value),'date non prouvée pour '+id);
  }
});
