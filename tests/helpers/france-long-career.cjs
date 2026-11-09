'use strict';
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const {createHash}=require('node:crypto');
const {gunzipSync}=require('node:zlib');
const {context}=require('../france-harness.cjs');
const SCENARIO={initialSeed:827381,club:29,mode:'france',roundCalls:34,splitSeason:6,totalSeasons:10};
const FIXTURE=path.join(__dirname,'../fixtures/france-long-career-s6.json.gz');
const digest=value=>createHash('sha256').update(JSON.stringify(value)).digest('hex');
function seal(payload){return {...payload,integrity:digest(payload)};}
function validateFixture(fixture){
 assert.equal(fixture.format,'france-long-career-checkpoint','format du checkpoint');
 assert.equal(fixture.version,1,'version du checkpoint');
 const {integrity,...payload}=fixture;
 assert.equal(integrity,digest(payload),'intégrité du checkpoint et du curseur RNG');
 assert.deepEqual(fixture.scenario,SCENARIO,'scénario ou graine initiale périmés');
 assert.equal(fixture.checkpoint.save.state.season,6,'checkpoint périmé : entrée S6 attendue');
 assert.equal(fixture.checkpoint.save.state.round,0,'checkpoint hors entrée de saison');
 assert.equal(fixture.checkpoint.save.state.club,29,'club du checkpoint');
 assert.equal(fixture.checkpoint.save.state.history.length,0,'historique déjà joué au checkpoint');
 assert.equal(fixture.final.season,11,'référence finale périmée : S11 attendue');
 assert.match(fixture.final.stateSha256,/^[a-f0-9]{64}$/,'empreinte finale');
 for(const rng of [fixture.checkpoint.rng,fixture.final.rng])assert.ok(Number.isInteger(rng)&&rng>=0&&rng<=0xffffffff,'curseur RNG uint32');
 return fixture;
}
function readFixture(){return validateFixture(JSON.parse(gunzipSync(fs.readFileSync(FIXTURE))));}
function resumeCheckpoint(fixture){
 validateFixture(fixture);
 const h=context(fixture.checkpoint.rng);
 assert.equal(h.seed(),fixture.checkpoint.rng,'chargement du moteur sans consommation RNG');
 h.ctx.checkpointText=JSON.stringify(fixture.checkpoint.save);
 h.run('pendingSave=parseSaveDocument(checkpointText);if(!confirmSaveImport())throw Error("import checkpoint");validateCareer(S);');
 delete h.ctx.checkpointText;
 assert.deepEqual(h.state(),fixture.checkpoint.save.state,'import natif fidèle du checkpoint S6');
 assert.equal(h.seed(),fixture.checkpoint.rng,'import natif sans consommation RNG');
 return h;
}
function assertFixtureGuards(fixture){
 const copy=()=>JSON.parse(JSON.stringify(fixture));
 const reseal=f=>{const {integrity,...payload}=f;return seal(payload);};
 let bad=copy();bad.version=0;
 assert.throws(()=>validateFixture(bad),/version du checkpoint/);
 bad=copy();bad.checkpoint.rng=(bad.checkpoint.rng+1)>>>0;
 assert.throws(()=>validateFixture(bad),/intégrité du checkpoint/);
 bad=copy();bad.scenario.initialSeed++;
 assert.throws(()=>validateFixture(reseal(bad)),/scénario ou graine initiale/);
 bad=copy();bad.checkpoint.save.state.season=5;
 assert.throws(()=>validateFixture(reseal(bad)),/checkpoint périmé/);
 bad=copy();bad.checkpoint.save.state.clubs[29].cash++;
 assert.throws(()=>resumeCheckpoint(reseal(bad)),/modifié ou endommagé/);
 console.log('Checkpoint : version, intégrité RNG, graine, saison périmée et checksum natif protégés');
}
function count(v){return 1+(Array.isArray(v)?v.reduce((n,x)=>n+count(x),0):v&&typeof v==='object'?Object.values(v).reduce((n,x)=>n+count(x),0):0);}
function runSeasons(h,first,last){
 const measures=[];
 // Même parcours historique : 34 appels, 433 résultats, deux cycles natifs
 // validation/export/parse/import et advanceSeason à chaque saison, y compris S10.
 for(let season=first;season<=last;season++){
  for(let w=0;w<34;w++)h.run('finishRound()');
  const s=h.state();assert.equal(s.history.length,433);assert.equal(s.season,season);const text=JSON.stringify(s);measures.push({season,phase:s.phase,bytes:Buffer.byteLength(text),nodes:count(s),players:s.clubs.reduce((n,c)=>n+c.players.length,0),academy:s.aiRoster.academies.reduce((n,a)=>n+a.players.length,0)});
  let validation='OK';try{h.run('validateCareer(S);pendingSave=parseSaveDocument(JSON.stringify(createSaveDocument()));if(!confirmSaveImport())throw Error("import");');}catch(e){validation=e.message;if(!process.argv.includes('--measure'))throw e;}
  console.log(JSON.stringify({...measures.at(-1),validation}));h.run('advanceSeason()');
  try{h.run('validateCareer(S);pendingSave=parseSaveDocument(JSON.stringify(createSaveDocument()));if(!confirmSaveImport())throw Error("import");');}catch(e){if(!process.argv.includes('--measure'))throw e;}
 }
 console.log('MAX',JSON.stringify({bytes:Math.max(...measures.map(m=>m.bytes)),nodes:Math.max(...measures.map(m=>m.nodes))}));
 return measures;
}
function assertCheckpoint(h,fixture){
 const actual=JSON.parse(h.run('JSON.stringify(createSaveDocument())'));
 // Fail with bounded hashes before formatting a potentially huge object diff.
 // The full-state equality and independent RNG assertion remain mandatory.
 assert.equal(digest(actual),digest(fixture.checkpoint.save),'Empreinte SHA256 du checkpoint S6 différente');
 assert.deepEqual(actual,fixture.checkpoint.save,'S6 exactement égale au checkpoint de la campagne continue');
 assert.equal(h.seed(),fixture.checkpoint.rng,'curseur RNG S6 de la campagne continue');
}
function assertFinal(h,fixture){
 assert.equal(h.state().season,11);
 assert.equal(digest(h.state()),fixture.final.stateSha256,'S11 identique à la campagne continue de dix saisons');
 assert.equal(h.seed(),fixture.final.rng,'curseur RNG S11 identique à la campagne continue');
}
module.exports={SCENARIO,digest,seal,validateFixture,readFixture,resumeCheckpoint,assertFixtureGuards,runSeasons,assertCheckpoint,assertFinal};
