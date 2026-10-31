'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),m=require('../dist/coach-career.js');
const report={name:'V58 coach careers',checks:[]};
function check(name,fn){fn();report.checks.push({name,status:'pass'});}
const setup=()=>({clubs:[{id:'a',budget:100,reputation:65,coachId:'c1'},{id:'b',budget:80,reputation:45,coachId:null},{id:'c',budget:30,reputation:30,coachId:null}],coaches:[m.profile({id:'c1',salary:45,reputation:67,experience:7}),m.profile({id:'c2',salary:50,reputation:49,experience:4}),m.profile({id:'c3',salary:25,reputation:33,experience:2})],events:[]});
check('profils et competences',()=>{let p=m.profile({id:'x',reputation:55,skills:{training:75}});assert.equal(p.skills.training,75);assert.throws(()=>m.profile({id:'',reputation:22}));});
check('postes vacants et offres',()=>{let s=setup();assert.equal(m.openings(s).length,2);assert.deepEqual(m.offers(s,'c2').map(x=>x.clubId),['b']);});
check('negociation acceptee et refusee',()=>{assert.equal(m.negotiate({salaryRequested:70,salaryCap:80,years:3}).accepted,true);assert.equal(m.negotiate({salaryRequested:90,salaryCap:80,years:2}).accepted,false);assert.throws(()=>m.negotiate({salaryRequested:10,salaryCap:12,years:0}));});
check('licenciement et poste vacant',()=>{const s=setup(),n=m.apply(s,{type:'dismiss',clubId:'a',season:2});assert.equal(n.state.clubs[0].coachId,null);assert.equal(n.event.coachId,'c1');assert.ok(s.clubs[0].coachId);});
check('signature et debit financier',()=>{const s=setup(),r=m.apply(s,{type:'hire',clubId:'b',coachId:'c2',season:3,years:3});assert.equal(r.state.clubs[1].budget,30);assert.equal(r.state.coaches[1].history[0].clubId,'b');assert.equal(s.clubs[1].coachId,null);});
check('transfert entraineur et historique',()=>{const s=setup(),r=m.apply(s,{type:'move',clubId:'b',coachId:'c1',season:3});assert.equal(r.state.clubs[0].coachId,null);assert.equal(r.state.clubs[1].coachId,'c1');assert.equal(r.event.from,'a');});
check('interdiction double emploi et insolvabilite',()=>{const s=setup();assert.throws(()=>m.apply(s,{type:'hire',clubId:'c',coachId:'c2',season:1}));assert.throws(()=>m.apply(s,{type:'hire',clubId:'b',coachId:'c1',season:1}));});
check('IA recrute plusieurs coachs sans doublon',()=>{const s=setup(),r=m.aiTurn(s,2);assert.equal(r.events.length,2);assert.equal(new Set(r.events.map(x=>x.coachId)).size,2);m.validate(r.state);});
check('determinisme et non-mutation 15 saisons',()=>{const run=()=>{let s=setup();for(let y=1;y<=15;y++){const r=m.aiTurn(s,y);s=r.state;if(y%3===0){const c=s.clubs.find(x=>x.coachId);if(c)s=m.apply(s,{type:'dismiss',clubId:c.id,season:y}).state;}}return s;};let a=run(),b=run();assert.deepEqual(a,b);});
check('reprise json et validation corruption',()=>{let s=m.aiTurn(setup(),2).state;const loaded=JSON.parse(JSON.stringify(s));m.validate(loaded);assert.deepEqual(loaded,s);loaded.clubs[0].coachId='unknown';assert.throws(()=>m.validate(loaded));});
report.passed=report.checks.length;
if(process.env.CD_V58_REPORT)fs.writeFileSync(process.env.CD_V58_REPORT,JSON.stringify(report,null,2)+'\n');
console.log('V58 COACH CAREER PASS '+JSON.stringify(report));
