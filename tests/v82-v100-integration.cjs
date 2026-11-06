'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const html = fs.readFileSync(path.join(__dirname,'../dist/index.html'),'utf8');
const scripts = ['espoirs-career-v82-v85.js','espoirs-followup-v86-v89.js','espoirs-dynamics-v90-v94.js','espoirs-strategy-v95-v100.js'];
let previous = -1;
for(const name of scripts) {
  const at = html.indexOf('<script src="'+name+'"></script>');
  assert.ok(at > previous, 'ordered script '+name);
  previous = at;
}
const player = (id, pos, age, rating) => ({id,name:id,pos,age,rating,condition:90,injury:0,dev:{potential:rating+15,xp:0,seasonStart:rating}});
const state = () => ({
  season:1,club:0,round:4,phase:'league',live:false,news:[],ledger:[],
  clubs:[{name:'Maison',cash:300000,players:[player('pro','10',27,77)]},{name:'Rival',cash:100000,players:[]}],
  development:{academy:[player('jeune','10',18,63),player('jeune2','9',19,64)]},
  v73Espoirs:{results:[],minutes:{jeune:400,jeune2:350}},
  v77Promotions:{promotions:[],history:[]},v78to81:{version:1,season:1,loans:[],history:[]}
});
const panels = [];
const ctx = {S:state(),view:'formation',console,
  document:{querySelector:()=>({insertAdjacentHTML:(where,markup)=>panels.push(markup)})},
  CDEspoirsPathwaysV78V81:{ensure:s=>s.v78to81},
  start(){return true},render(){return true},
  advanceSeason(){this.S.season++;this.S.phase='league';return true},
  save(){return true}
};
ctx.globalThis=ctx;
vm.createContext(ctx);
for(const name of scripts) vm.runInContext(fs.readFileSync(path.join(__dirname,'../dist',name),'utf8'),ctx,{filename:name});
assert.equal(typeof ctx.v82Plan,'function');
assert.equal(typeof ctx.v86Target,'function');
assert.equal(typeof ctx.v92Specialize,'function');
assert.equal(typeof ctx.v95Scout,'function');
ctx.start();
ctx.render();
assert.equal(panels.length,4,'four academy panels rendered');
for(const label of ['V82','V86','V90','V95']) assert.ok(panels.some(p=>p.includes(label)),label+' panel');
const json = JSON.stringify(ctx.S);
const imported = JSON.parse(json);
for(const key of ['v82to85','v86to89','v90to94','v95to100']) assert.ok(imported[key],key+' survives JSON export/import');
const old = state();
ctx.S=old;
ctx.start();
for(const key of ['v82to85','v86to89','v90to94','v95to100']) assert.ok(ctx.S[key],key+' accepts legacy save');
for(let year=1;year<=17;year++){
  ctx.S.phase='ended';
  assert.notEqual(ctx.advanceSeason(),false,'season '+year);
  assert.equal(ctx.S.season,year+1);
  ctx.render();
}
for(const [key,api] of [['v82to85','CDEspoirsCareerV82V85'],['v86to89','CDEspoirsFollowupV86V89'],['v90to94','CDEspoirsDynamicsV90V94'],['v95to100','CDEspoirsStrategyV95V100']]){
  assert.ok(ctx.S[key],key+' after 17 seasons');
  assert.equal(ctx[api].valid(ctx.S[key]),true,key+' valid');
}
console.log('V82-V100 INTEGRATION PASS: order, four panels, legacy JSON import/export, 17 seasons');
