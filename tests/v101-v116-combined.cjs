'use strict';
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');
const html=fs.readFileSync(path.join(__dirname,'../dist/index.html'),'utf8');
const scripts=['espoirs-career-v82-v85.js','espoirs-followup-v86-v89.js',
 'espoirs-dynamics-v90-v94.js','espoirs-strategy-v95-v100.js',
 'espoirs-coaching-v101-v104.js','sporting-director-v105-v110.js',
 'fan-experience-v111-v116.js'];
let previous=-1;
for(const name of scripts){
 const pos=html.indexOf('<script src="'+name+'"></script>');
 assert.ok(pos>previous,'ordered script '+name);
 previous=pos;
}
assert.ok(html.indexOf('fan-experience-v111-v116.js')<html.indexOf('office-career-press.js'));
function fixture(){
 const player=(id,pos,age,rating)=>({id,name:id,pos,age,rating,condition:90,injury:0,
  dev:{potential:rating+20,xp:0,seasonStart:rating}});
 return {season:1,club:0,round:3,phase:'league',live:false,news:[],ledger:[],
  clubs:[{name:'Union fictive',cash:300000,stadiumCapacity:11000,
   players:[player('pro','10',27,77),player('pro2','9',28,72)]},
   {name:'Rival fictif',cash:100000,players:[]}],
  development:{academy:[player('espoir','10',18,63),player('espoir2','9',19,64)]},
  v73Espoirs:{minutes:{espoir:420,espoir2:250},results:[]},
  v77Promotions:{promotions:[],history:[]},
  v82to85:{version:1,season:1,focus:'progression',goal:'formation',plans:[],mentors:[],reports:[],history:[]},
  v95to100:{version:1,season:1,region:'Atlantique',identity:'polyvalence',
   cohesion:55,reputation:45,scouts:0,meetings:0,candidates:[],recruits:[],loads:[],ambitions:[],history:[]}
 };
}
const inserted=[];
let saveCount=0;
const ctx={S:fixture(),view:'bureau',console,JSON,saveFailure:false,
 document:{querySelector:()=>({insertAdjacentHTML:(position,markup)=>inserted.push(markup)})},
 start(){this.S=fixture();return true;},
 advanceSeason(){this.S.season++;this.S.phase='league';return true;},
 render(){return true;},
 save(){saveCount++;return !this.saveFailure;}
};
ctx.globalThis=ctx;vm.createContext(ctx);
for(const name of scripts.slice(-3)){
 const code=fs.readFileSync(path.join(__dirname,'../dist',name),'utf8');
 vm.runInContext(code,ctx,{filename:name});
}
const modules=['CDEspoirsCoachingV101V104','CDSportingDirectorV105V110','CDFanExperienceV111V116'];
const keys=['v101to104','v105to110','v111to116'];
assert.equal(typeof ctx.v102Path,'function');
assert.equal(typeof ctx.v105Priority,'function');
assert.equal(typeof ctx.v112Price,'function');
assert.equal(typeof ctx.v111Record,'function');
ctx.start();
for(let i=0;i<3;i++)assert.ok(ctx.S[keys[i]],'initialized '+keys[i]);
ctx.view='formation';ctx.render();
assert.equal(inserted.length,1,'one formation panel from new modules');
assert.match(inserted[0],/V101.V104/);
assert.match(inserted[0],/v102Path/);
inserted.length=0;ctx.view='bureau';ctx.render();
assert.equal(inserted.length,2,'two distinct bureau panels');
assert.ok(inserted.some(x=>x.includes('V105')));
assert.ok(inserted.some(x=>x.includes('V111')));
function click(markup,pattern){
 const match=markup.match(pattern);assert.ok(match,'button exists '+pattern);
 return vm.runInContext(match[1],ctx);
}
assert.equal(click(inserted[0],/onclick="(v105Priority\('finances'\))"/),true,'V105 clickable');
assert.equal(click(inserted[0],/onclick="(v106Delegate\('sportif','analyse'\))"/),true,'V106 clickable');
assert.equal(click(inserted[0],/onclick="(v107Invest\('video'\))"/),true,'V107 clickable');
assert.equal(click(inserted[0],/onclick="(v108Mitigate\('fatigue','prevenir'\))"/),true,'V108 clickable');
assert.equal(click(inserted[1],/onclick="(v112Price\('accessible'\))"/),true,'V112 clickable');
assert.equal(click(inserted[1],/onclick="(v113Campaign\('locale'\))"/),true,'V113 clickable');
assert.equal(click(inserted[1],/onclick="(v114Community\('ecoles'\))"/),true,'V114 clickable');
assert.equal(click(inserted[1],/onclick="(v115Service\('confort'\))"/),true,'V115 clickable');
assert.equal(click(inserted[1],/onclick="(v111Record\(1,\d+\))"/),true,'V111 clickable');
assert.equal(ctx.S.v111to116.ledger.length,1);
ctx.view='formation';inserted.length=0;ctx.render();
assert.equal(click(inserted[0],/onclick="(v102Path\(&quot;espoir&quot;,'minutes'\))"/),true,'V102 clickable');
assert.equal(ctx.S.v101to104.paths[0].strategy,'minutes');
const fiscal=ctx.S.clubs[0].cash,serial=JSON.stringify(ctx.S),roundTrip=JSON.parse(serial);
for(let i=0;i<3;i++)assert.equal(ctx[modules[i]].valid(roundTrip[keys[i]]),true,'JSON '+keys[i]);
assert.ok(roundTrip.clubs[0].cash===fiscal,'club treasury persists');
ctx.S=roundTrip;
ctx.view='bureau';ctx.render();
assert.ok(ctx.S.v105to110.missions.length===1,'reload retains staff mission');
assert.ok(ctx.S.v111to116.ledger.length===1,'reload retains ticket revenue');
ctx.saveFailure=true;
assert.equal(ctx.v111Record(2,2000),false,'failed save rollback');
assert.equal(ctx.S.v111to116.ledger.length,1);
assert.equal(ctx.v102Path('espoir','progression'),false,'failed academy save rollback');
assert.equal(ctx.S.v101to104.paths[0].strategy,'minutes');
ctx.saveFailure=false;
const firstCash=ctx.S.clubs[0].cash;
for(let year=1;year<=17;year++){
 ctx.S.phase='ended';
 const result=ctx.advanceSeason();
 assert.notEqual(result,false,'advance season '+year);
 assert.equal(ctx.S.season,year+1);
 for(let i=0;i<3;i++)assert.equal(ctx[modules[i]].valid(ctx.S[keys[i]]),true,'valid state year '+year+' '+keys[i]);
 assert.equal(ctx.S.v101to104.archive.length,Math.min(year,15),'academy annual archive');
 assert.equal(ctx.S.v105to110.history.length,Math.min(year,12),'board annual archive');
 assert.equal(ctx.S.v111to116.history.length,Math.min(year,12),'fans annual archive');
 assert.equal(ctx.S.v105to110.missions.length,0,'staff missions reset annually');
 assert.equal(ctx.S.v111to116.ledger.length,0,'ticket slots reset annually');
 assert.notEqual(ctx.S.clubs[0].cash,undefined);
 ctx.view='bureau';ctx.render();
 assert.ok(ctx.v105Priority('stabilite'),'season planning usable after rollover');
}
assert.ok(ctx.S.clubs[0].cash>=0);
assert.equal(ctx.S.v101to104.archive[0].season,17);
assert.equal(ctx.S.v105to110.history[0].season,17);
assert.equal(ctx.S.v111to116.history[0].season,17);
const legacy=fixture();
delete legacy.v82to85;delete legacy.v95to100;
ctx.S=legacy;ctx.start();
for(const key of keys)assert.ok(ctx.S[key],'legacy start supports missing '+key);
assert.ok(saveCount>40,'real save callbacks exercised');
console.log('V101-V116 COMBINED PASS: 7 scripts ordered, 3 panel installs, 10 onclick actions, legacy JSON import/export, storage rollback, 17 linked seasons');
