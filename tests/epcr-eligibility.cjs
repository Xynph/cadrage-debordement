'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const E=require('../native/engine/epcr-eligibility.cjs');
const options={season:'2026/27',competitionId:'champions'};
const p=(id,frontRow=[])=>({id:String(id),frontRow});
const roster=()=>Array.from({length:42},(_,i)=>p(i,i<12?[['LH','HK','TH'][i%3]]:[]));
const sheet=r=>[r.slice(0,3).concat(r.slice(12,24)),r.slice(3,6).concat(r.slice(24,29))];
const codes=r=>r.violations.map(x=>x.code);
function frozen(x){if(x&&typeof x==='object'){Object.values(x).forEach(frozen);Object.freeze(x);}return x;}
test('profile explicitly covers only EPCR 2026/27 in both tournaments',()=>{
 for(const competitionId of ['champions','challenge'])assert.equal(E.profile({...options,competitionId}).covered,true);
 for(const value of [null,{}, {...options,season:'2025/26'}, {...options,season:2026},{...options,season:'2027/28'},{...options,competitionId:'urc'}])assert.equal(E.registration(roster(),value).status,'invalid');
 assert.equal(E.profile(options).sourceScope,'official-summary');
});
test('registration limits 41/42/43 and nine/ten qualified players',()=>{
 for(const length of [41,42])assert.equal(E.registration(roster().slice(0,length),options).valid,true);
 assert.ok(codes(E.registration([...roster(),p(42)],options)).includes('registration-size'));
 for(const length of [9,10]){const r=roster();r.forEach((x,i)=>{if(i>=length)x.frontRow=[];});assert.equal(E.registration(r,options).valid,length===10);}
});
test('unknown evidence never silently becomes a qualification or certain refusal',()=>{
 const r=roster();r.forEach((x,i)=>{if(i>=9)x.frontRow=[];});r[9].frontRow=null;
 const a=E.registration(r,options);assert.equal(a.status,'unknown');assert.deepEqual(a.unknowns[0].playerIds,['9']);assert.equal(a.violations.length,0);
 r[9].frontRow=[];assert.equal(E.registration(r,options).status,'invalid');
 const t=roster(),[a1,b1]=sheet(t);delete t[0].frontRow;assert.equal(E.teamSheet(a1,b1,t,options).status,'unknown');
});
test('real ordered XV and match sheet boundaries 18/19/23/24',()=>{
 const r=roster(),[a,b]=sheet(r);
 for(const total of [18,19,23,24]){const result=E.teamSheet(a,b.slice(0,total-15).concat(total===24?[r[30]]:[]),r,options);assert.equal(result.valid,total===19||total===23,String(total));}
 assert.ok(codes(E.teamSheet(a.slice(1),b,r,options)).includes('sheet-size'));
});
test('qualifications cover starters and three distinct first replacements',()=>{
 const r=roster(),[a,b]=sheet(r);assert.equal(E.teamSheet(a,b,r,options).valid,true);
 assert.ok(codes(E.teamSheet([a[1],a[0],...a.slice(2)],b,r,options)).includes('starter-front-row-LH'));
 const s=roster(),[c,d]=sheet(s);s[3].frontRow=['LH','HK','TH'];s[4].frontRow=[];s[5].frontRow=[];
 // Six total front-row-qualified players but only one qualified reserve.
 s[12].frontRow=['LH'];s[13].frontRow=['HK'];
 const result=E.teamSheet(c,d,s,options);assert.ok(codes(result).includes('replacement-front-row'));
 const unknown=roster(),[e,f]=sheet(unknown);unknown[3].frontRow=null;assert.equal(E.teamSheet(e,f,unknown,options).status,'unknown');
});
test('registered evidence is authoritative; extra sheet role cannot be forged',()=>{
 const r=roster(),[a,b]=sheet(r),fake=a.map(x=>({...x,frontRow:x.frontRow.slice()}));fake[0].frontRow.push('HK');
 assert.ok(codes(E.teamSheet(fake,b,r,options)).includes('sheet-qualification-mismatch'));
 const noProof=roster(),[c,d]=sheet(noProof);const cached=c.map(x=>({...x,frontRow:x.frontRow.slice()}));noProof[0].frontRow=null;
 assert.equal(E.teamSheet(cached,d,noProof,options).status,'unknown');
 const oversized=[...r,p(42)];assert.ok(codes(E.teamSheet(a,b,oversized,options)).includes('registration-size'));
});
test('malformed input and duplicates are rejected without throwing',()=>{
 for(const bad of [null,{},'players',[null],[p('')],[{id:3,frontRow:[]}],[p('a',['prop'])],[p('a',['LH','LH'])],[p('a','LH')]])assert.equal(E.registration(bad,options).status,'invalid');
 assert.ok(codes(E.registration([...roster(),p('0')],options)).includes('registration-duplicate-player'));
 const r=roster(),[a,b]=sheet(r);b[7]=a[0];assert.ok(codes(E.teamSheet(a,b,r,options)).includes('sheet-duplicate-player'));
 b[7]=p('not-registered');assert.ok(codes(E.teamSheet(a,b,r,options)).includes('sheet-unregistered-player'));
 for(const bad of [null,{},'sheet'])assert.equal(E.teamSheet(bad,b,r,options).status,'invalid');
});
test('diagnostic preserves frozen input and factory is VM-independent',()=>{
 const r=frozen(roster()),[a,b]=sheet(r),o=frozen({...options}),before=JSON.stringify(r);
 assert.equal(E.registration(r,o).valid,true);assert.equal(E.teamSheet(frozen(a),frozen(b),r,o).valid,true);assert.equal(JSON.stringify(r),before);
 const vm=require('node:vm'),isolated=vm.runInNewContext('('+E.factory.toString()+')()');
 assert.equal(JSON.stringify(isolated.teamSheet(a,b,r,o)),JSON.stringify(E.teamSheet(a,b,r,o)));
 const profile=E.profile(o);profile.sections.push('mutated');assert.deepEqual(E.profile(o).sections,['3.1','3.2','3.3']);
});
