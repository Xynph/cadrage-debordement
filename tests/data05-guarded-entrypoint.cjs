'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const {runGuarded,verifyProfiles,cliArgs}=require('../tools/data05-guarded-entrypoint.cjs');
const roster=Array.from({length:1592},(_,i)=>({id:'lnr-'+i,club:'club',url:'https://top14.lnr.fr/joueur/'+i+'-a'}));
const profiles=roster.slice(0,240).map(x=>({...x,name:'Player'}));
function dependencies(){let calls=0;return {calls:()=>calls,deps:{modules:{preflight:{checkCache:(p,r)=>{assert.equal(new Set(p.map(x=>x.id)).size,240);return{valid:240,remaining:1352}},validatePlan:({total,cached,limit,budget,confirmed,concurrency,delayMs})=>{assert.equal(total,1592);assert.equal(cached,240);if(budget>limit||limit>1352||concurrency>2||delayMs<1000||limit>0&&!confirmed)throw Error('Unsafe plan');return{cached,limit,budget}}},pipeline:{execute:async options=>{calls++;return{cached:240,newlyFetched:0,firecrawlCalls:0,remaining:Array(1352).fill('not-fetched'),transport:{firecrawlCalls:0}}}}},loadRoster:()=>roster,loadProfiles:()=>profiles}}}
test('validates full 240-profile cache and rejects duplicates / identity changes',()=>{const p={checkCache:(ps,rs)=>{const byId=new Map(rs.map(x=>[x.id,x]));for(const x of ps)assert.deepEqual([x.club,x.url],[byId.get(x.id)?.club,byId.get(x.id)?.url]);return{valid:240}}};assert.equal(verifyProfiles(profiles,roster,p).valid,240);assert.throws(()=>verifyProfiles([...profiles.slice(1),profiles[1]],roster,p),/Duplicate/);assert.throws(()=>verifyProfiles(profiles.slice(1),roster,p),/240/);assert.throws(()=>verifyProfiles(profiles.map((x,i)=>i?x:{...x,club:'wrong'}),roster,p));});
test('budget zero imports without network or paid calls',async()=>{const d=dependencies();const r=await runGuarded({},d.deps);assert.equal(d.calls(),1);assert.equal(r.result.cached,240);assert.equal(r.result.transport.firecrawlCalls,0);});
test('unsafe plans and unauthorized HTTP abort before executing pipeline',async()=>{for(const options of [{limit:1},{limit:1,confirmed:true},{limit:1,confirmed:true,authorizedHttp:true,budget:2},{limit:0,budget:1},{limit:0,budget:0,key:'secret'}]){const d=dependencies();await assert.rejects(runGuarded(options,d.deps));assert.equal(d.calls(),0)}});
test('injection cannot falsely claim paid-free run',async()=>{const d=dependencies();d.deps.execute=async()=>({cached:240,newlyFetched:0,firecrawlCalls:1,transport:{firecrawlCalls:1}});await assert.rejects(runGuarded({},d.deps),/Paid attempts/);});
test('CLI fails closed and never enables network accidentally',()=>{assert.deepEqual(cliArgs([]),{limit:0,budget:0,concurrency:1,delayMs:1200,confirmed:false,authorizedHttp:false});assert.throws(()=>cliArgs(['--limit']),/Missing/);assert.throws(()=>cliArgs(['--foo']),/Unexpected/);});

test('real 15-file 240-profile corpus and genuine unified importer are offline and idempotent',async()=>{
 const path=require('node:path'),fs=require('node:fs'),os=require('node:os');
 const unified=require('../tools/data05-unified.cjs');
 const {sourceProfiles}=require('../tools/data05-guarded-entrypoint.cjs');
 const root=path.resolve(__dirname,'..');
 const actualRoster=unified.loadRoster(root),actualProfiles=sourceProfiles(root);
 assert.equal(actualRoster.length,1592);assert.equal(actualProfiles.length,240);
 const map=new Map(actualRoster.map(x=>[x.id,x]));
 for(const p of actualProfiles){const r=map.get(p.id);assert.ok(r);assert.equal(p.url,r.url);assert.equal(p.club,r.club)}
 assert.equal(new Set(actualProfiles.map(x=>x.id)).size,240);
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'data05-zero-'));
 let http=0,firecrawl=0;
 try{
  const options={root,dir,list:actualRoster,limit:0,budget:0,key:null,http:async()=>{http++;throw Error('HTTP forbidden')},fallback:async()=>{firecrawl++;throw Error('Firecrawl forbidden')},delayMs:0};
  const first=await unified.run(options);
  const second=await unified.run(options);
  assert.equal(first.imported,240);assert.equal(first.cached,240);assert.equal(first.remaining.length,1352);
  assert.equal(second.imported,0);assert.equal(second.cached,240);
  assert.equal(first.firecrawlCalls,0);assert.equal(second.firecrawlCalls,0);
  assert.equal(http,0);assert.equal(firecrawl,0);
  assert.equal(JSON.parse(fs.readFileSync(path.join(dir,'players.json'),'utf8')).players.length,240);
 }finally{fs.rmSync(dir,{recursive:true,force:true})}
});
