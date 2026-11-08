'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const root=path.resolve(__dirname,'..'),file=path.join(root,'native/engine/academy.cjs');
assert.ok(fs.existsSync(file),'Le contrôleur formation natif est requis');
const academy=require(file),worker=require('../native/engine/worker.cjs');
function make(club=29,mode="common"){let seed=13;const math=Object.create(Math);math.random=()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/4294967296};const store={};const ctx=vm.createContext({console,Intl,Math:math,Date,Set,JSON,CDNativeHeadless:true,document:{querySelector:()=>({})},window:{},localStorage:{getItem:k=>store[k],setItem:(k,v)=>store[k]=v,removeItem:k=>delete store[k]},setTimeout:()=>0,clearTimeout(){},setInterval:()=>0,clearInterval(){}});const run=x=>vm.runInContext(x,ctx,{timeout:15000});for(const name of [...new Set(worker.CORE_FILES.filter(x=>x!=='game.js').concat(academy.files,'game.js'))])run(fs.readFileSync(path.join(root,'dist',name),'utf8'));run(`render=()=>{};toast=()=>{};save=()=>{};const common=(${require('../native/engine/common-rosters.cjs').toString()})();const A=(${academy.factory.toString()})();A.installHooks();${mode==="common"?`common.start(${club})`:`start(${club},${JSON.stringify(mode)})`};`);return {run,ctx,seed:()=>seed};}
const t=make(),r=t.run;
let before=r('JSON.stringify(S)'),rng=t.seed();r('A.project();A.project()');assert.equal(r('JSON.stringify(S)'),before);assert.equal(t.seed(),rng);
r('A.execute("academy_activate",{season:S.season,week:S.franceMode.week,club:S.club,confirmed:true})');
assert.equal(r('S.nativeAcademy.version'),2);assert.equal(r('S.nativeAcademy.centers.length'),44);assert.equal(r('S.nativeAcademy.centers.filter(c=>c.clubId!==null).length'),30);
assert.equal(r('A.project().players.length'),15);assert.equal(r('A.project().centerId'),'club:29');r('A.validate(S)');
const cash=r('S.clubs[S.club].cash');r('A.execute("academy_scout",{season:S.season,week:S.franceMode.week,club:S.club,confirmed:true})');assert.equal(r('S.clubs[S.club].cash'),cash-35000);assert.throws(()=>r('A.execute("academy_scout",{season:S.season,week:S.franceMode.week,club:S.club,confirmed:true})'),/refus|déjà/i);
const player=r('S.development.academy[0].id');t.ctx.pid=player;
r('A.execute("academy_mentor",{season:S.season,week:S.franceMode.week,club:S.club,playerId:pid,focus:"technique",confirmed:true})');assert.equal(r('S.clubs[S.club].cash'),cash-43000);r('trainWeek()');assert.equal(r('S.v72Youth.mentors[0].done'),true);r('A.validate(S)');
before=r('JSON.stringify(S)');rng=t.seed();r('A.project();A.validate(S);A.project()');assert.equal(r('JSON.stringify(S)'),before);assert.equal(t.seed(),rng);
assert.throws(()=>r('A.execute("academy_path",{season:1,week:99,club:29,playerId:pid,strategy:"minutes"})'),/périm/i);
r('S.trained=false; A.execute("academy_path",{season:S.season,week:S.franceMode.week,club:S.club,playerId:pid,strategy:"minutes"})');assert.equal(r('S.v101to104.paths[0].strategy'),'minutes');
for(const mutation of ['S.nativeAcademy.version=999','S.nativeAcademy.extra=true','S.nativeAcademy.centers[0].id="club:29"','S.v73Espoirs.round=-1','S.v101to104.paths[0].extra=true']){t.ctx.original=r('JSON.stringify(S)');r(mutation);assert.throws(()=>r('A.validate(S)'),/formation|Espoir|centre/i);r('S=JSON.parse(original)');}
console.log('PASS académie : activation club29, lecture pure, coûts, refus, mentorat, parcours, validation hostile');
module.exports={make};
