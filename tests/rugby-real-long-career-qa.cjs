'use strict';
/**
 * Read-only acceptance of the already-integrated V11/V12 Rugby Reel career.
 * No custom match model, calendar, transfer, roster or save implementation.
 */
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');
const {context}=require('./harness.cjs');

const DIST=path.resolve(__dirname,'../dist');
const MODULES=['lnr-v11-aging.js','lnr-ratings-v12.js','lnr-rosters-data.js','lnr-birthyears-data.js','lnr-career.js'];
function boot(saved){
  const g=context(saved);
  for(const file of MODULES) vm.runInContext(fs.readFileSync(path.join(DIST,file),'utf8'),g.ctx,{filename:file});
  return g;
}
function roundTrip(g){
  const document=JSON.parse(g.run('JSON.stringify(createSaveDocument())'));
  const next=boot();
  next.ctx.__qaDocument=document;
  next.run('S=parseSaveDocument(JSON.stringify(__qaDocument)).state');
  assert.equal(next.run('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'),true);
  return next;
}
function snapshot(g){
  return JSON.parse(g.run(`JSON.stringify({
    season:S.season,phase:S.phase,round:S.round,
    matches:S.clubs.reduce((total,c)=>total+c.played,0)/2,
    players:S.clubs.flatMap(c=>c.players).filter(p=>p.lnrRatingsVersion===1).length,
    broken:S.clubs.flatMap(c=>c.players).filter(p=>p.lnrRatingsVersion===1&&(
      !p.attributesV2||Object.keys(p.attributesV2).length!==36||
      !p.skills||Object.keys(p.skills).length!==11||
      p.rating!==p.skillBase||!Number.isFinite(p.rating)||
      !p.dev||!Number.isFinite(p.dev.potential)
    )).length,
    duplicateIds:(()=>{const ids=S.clubs.flatMap(c=>c.players).map(p=>p.id);return ids.length-new Set(ids).size})()
  })`));
}

test('Dix saisons TOP14 completes, finale native, V12/V11 et dix exports/imports', {timeout:240000},()=>{
  let g=boot();
  g.run("start(0,'lnr')");
  assert.equal(g.run('S.clubs.length'),14);
  assert.equal(g.run('sheetErrors().length'),0);
  assert.equal(g.run('Object.keys(LNR_V12_PLAYER_DATA.players).length'),1592);
  const rows=[];
  let regularMatches=0,finals=0;
  for(let year=1;year<=10;year++){
    assert.equal(g.run('S.season'),year);
    assert.equal(g.run('S.phase'),'league');
    for(let round=0;round<26;round++){
      assert.equal(g.run('S.round'),round);
      const count=g.run('roundPairs().length');
      assert.equal(count,7,'14 teams must produce seven matches');
      g.run('finishRound()');
      regularMatches+=count;
    }
    assert.equal(g.run('S.phase'),'barrage');
    let playoffGuard=0;
    while(g.run('S.phase')!=='ended'){
      assert.ok(++playoffGuard<=4,'playoffs must terminate');
      const games=g.run('roundPairs().length');
      assert.ok(games>=1&&games<=2);
      g.run('finishRound()');
      finals+=games;
    }
    assert.equal(g.run('S.clubs.every(c=>c.played===26)'),true);
    const result=snapshot(g);
    assert.equal(result.matches,91*2,'match accounting as two team appearances');
    assert.equal(result.broken,0,'V12 player state remains valid');
    assert.equal(result.duplicateIds,0,'player ID must be unique across the league');
    assert.ok(result.players>100,'V12 roster still present');
    rows.push({season:year,playoffs:playoffGuard,v12Players:result.players});
    g.run('advanceSeason()');
    assert.equal(g.run('S.season'),year+1);
    g=roundTrip(g);
    assert.equal(snapshot(g).broken,0);
  }
  assert.equal(regularMatches,1820);
  assert.ok(finals>=30&&finals<=60);
  console.log('RUGBY_REAL_LONG_CAREER_QA '+JSON.stringify({seasons:10,regularMatches,finals,imports:10,rows}));
});

test('Univers fictif et anciennes sauvegardes: aucune conversion V12 automatique',()=>{
  let g=boot();g.run('start(0)');
  assert.equal(g.run('S.lnrMode'),undefined);
  assert.equal(g.run('S.clubs.every(c=>c.players.every(p=>p.lnrRatingsVersion===undefined))'),true);
  const rating=g.run('S.clubs[0].players[0].rating');
  g=roundTrip(g);
  assert.equal(g.run('S.clubs[0].players[0].rating'),rating);
  assert.equal(g.run('S.clubs.every(c=>c.players.every(p=>p.lnrRatingsVersion===undefined))'),true);
  assert.equal(g.run('S.lnrMode'),undefined);
});
