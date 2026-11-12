'use strict';
// Golden states measured against 9044998e with seed/clock fixed. This runs in shallow CI checkouts.
// Hashes re-measured for the alternating home/away schedule (PR #573): with the previous schedule()
// put back, every stage, RNG and export hash equals the 9044998e capture.
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const {context}=require('./france-harness.cjs'),baseline=require('./france-legacy-parity.json');const hash=s=>crypto.createHash('sha256').update(s).digest('hex');
const {freezeFranceBirths}=require('./helpers/frozen-france-births.cjs');
for(const mode of ['fiction','lnr']){
 const after=context(baseline.seed);
 // This golden proves compatibility of the historical population-v1 path.
 // New-career v2 intake/pool assertions belong to their own current-policy tests.
 after.run('var populationV2Setup=aiRosterSetup;aiRosterSetup=function(){var result=populationV2Setup();S.aiRosterVersion=1;S.aiRoster.version=1;delete S.aiRoster.population;return result}');
 freezeFranceBirths(after);
 if(mode==='lnr')for(const f of ['lnr-rosters-data.js','lnr-career.js'])after.run(fs.readFileSync(path.join(__dirname,'../dist',f),'utf8'));
 after.run("start(0,'"+mode+"')");
 const same=stage=>{assert.equal(hash(after.run('JSON.stringify(S)')),baseline.captures[mode][stage].hash,mode+' '+stage+' sérialisation identique');assert.equal(after.seed(),baseline.captures[mode][stage].seed,mode+' '+stage+' RNG identique');};same('création');
 after.run('beginMatch();for(let i=0;!S.live.finished;i++){if(i>5000)throw Error("limite");if(S.live.paused)continueMatch();else tick();}finishRound();validateCareer(S)');same('match délégué');
 after.run("while(S.phase!=='ended'){trainWeek();finishRound();}validateCareer(S)");same('saison');
 after.run('advanceSeason();validateCareer(S)');same('intersaison');
 assert.equal(hash(after.run('JSON.stringify(createSaveDocument())')),baseline.captures[mode].export.hash,mode+' export identique');console.log(mode+': création/match/saison/intersaison/export/RNG identiques au BASE '+baseline.base.slice(0,8));
}
