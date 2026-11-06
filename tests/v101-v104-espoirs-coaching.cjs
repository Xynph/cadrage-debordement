'use strict';
const assert=require('node:assert/strict');
const api=require('../dist/espoirs-coaching-v101-v104.js');
function fixture(){
 return {season:1,club:0,phase:'league',live:false,development:{academy:[
  {id:'junior1',name:'Joueur <A>',pos:'10',age:18,rating:56,condition:85,dev:{potential:78}},
  {id:'junior2',name:'Joueur B',pos:'9',age:20,rating:70,condition:90,dev:{potential:80}}
 ]},clubs:[{cash:100000,players:[{id:'senior1',name:'Senior',pos:'10',age:30}]}],
 v73Espoirs:{minutes:{junior1:100,junior2:650}},
 v82to85:{plans:[{id:'junior1'}],mentors:[{youthId:'junior1',seniorId:'senior1'}]},
 v95to100:{loads:[{id:'junior1',load:'equilibree'}],reputation:56},
 v77Promotions:{promotions:[{id:'graduate1'}]}}
}
let s=fixture();
assert.equal(api.ensure(s).version,1);
assert.equal(api.audit(s).ok,true,'V101 audits supported module references');
assert.equal(api.advice(s,'junior1').strategy,'minutes','V103 insufficient minutes');
assert.equal(api.advice(s,'junior2').strategy,'professionnel','V103 preparation for senior review');
assert.equal(api.path(s,'junior1','progression',()=>false),false,'V102 save failure rolls back');
assert.equal(api.ensure(s).paths.length,0);
assert.equal(api.path(s,'junior1','progression',()=>true),true);
assert.equal(api.path(s,'junior1','minutes',()=>true),true,'choice can be revised');
assert.equal(api.ensure(s).paths.length,1,'single choice per player');
assert.equal(api.path(s,'junior1','invalid',()=>true),false);
assert.equal(api.path(s,'unknown','minutes',()=>true),false);
s.live=true;assert.equal(api.path(s,'junior1','progression',()=>true),false,'no changes during match');
s.live=false;
const previous=JSON.stringify(s);
s.phase='ended';assert.equal(api.closeSeason(s,()=>false),false,'V104 failed save rollback');
assert.equal(s.v101to104.archive.length,0);
assert.equal(api.closeSeason(s,()=>true),true);
assert.equal(api.closeSeason(s,()=>true),false,'archive idempotence');
assert.equal(api.generations(s)[0].count,2);
assert.equal(api.generations(s)[0].graduates,1);
assert.equal(api.valid(JSON.parse(JSON.stringify(s)).v101to104),true,'portable serialization');
assert.ok(api.panel(s).includes('Joueur &lt;A&gt;'),'HTML escaping');
assert.ok(api.panel(s).includes('v102Path'),'interactive controls');
const recovered=JSON.parse(JSON.stringify(s));assert.equal(api.ensure(recovered).archive.length,1);
const legacy=fixture();delete legacy.v101to104;assert.ok(api.ensure(legacy),'old saves accepted');
const broken=fixture();broken.v101to104={version:500};
assert.equal(api.ensure(broken),null,'broken state rejected');
const auditState=fixture();auditState.v82to85.mentors.push({youthId:'missing',seniorId:'missing'});
assert.equal(api.audit(auditState).ok,false,'orphan checks');
const stopped=fixture();stopped.development.academy[0].rating=99;
assert.equal(api.audit(stopped).ok,false,'invalid progression flagged');
for(let season=2;season<=17;season++){
 s.season=season;s.phase='ended';
 assert.equal(api.closeSeason(s,()=>true),true,'year '+season);
 assert.equal(api.closeSeason(s,()=>true),false,'idempotence '+season);
 assert.equal(api.valid(JSON.parse(JSON.stringify(s)).v101to104),true);
}
assert.equal(api.generations(s).length,15,'bounded 15-season memory');
assert.equal(api.generations(s)[0].season,17);
assert.equal(api.generations(s)[14].season,3);
const ui={
 S:fixture(),start(){return true},advanceSeason(){this.S.season++;return true},
 render(){return true},save(){return true}
};
assert.equal(api.install(ui),true,'wrapper installed');
assert.equal(api.install(ui),true,'idempotent install');
assert.equal(ui.v102Path('junior1','minutes'),true,'UI action changes chosen path');
assert.equal(ui.S.v101to104.paths[0].strategy,'minutes');
ui.S.phase='ended';
assert.equal(ui.advanceSeason(),true,'wrapper archives before advancing');
assert.equal(ui.S.v101to104.archive[0].season,1);
console.log('V101-V104 PASS: audit, trajectories, advice, 17 seasons, UI wiring, save rollback, old saves');
