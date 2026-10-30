const assert=require('node:assert/strict');
const {context}=require('./harness.cjs');

function fixture(level='expert'){
 const t=context(),run=t.run;
 run(`start(0);S.difficulty=${JSON.stringify(level)};beginMatch();pauseMatch();var l=S.live;l.minute=10;l.weather='Sec';l.tactics=['equilibre','equilibre'];l.defences=['equilibre','equilibre']`);
 return {t,run};
}
function incident(run,side,kind='yellow',index=4){
 run(`giveMatchCard(l,${side},activePlayers(l,${side})[${index}].id,${JSON.stringify(kind)})`);
}

let {run}=fixture();
assert.equal(run('l.numericalAiVersion'),1);
assert.equal(run('activePlayers(l,0).length'),15);
assert.equal(run('activePlayers(l,1).length'),15);
const initialEvents=run('l.events.length');
run('adaptManager(l,1)');
assert.equal(run('l.tactics[1]'),'equilibre');
assert.equal(run('l.defences[1]'),'equilibre');
assert.equal(run('l.events.length'),initialEvents);

// One yellow: protect the 14-player defence and narrow the attack.
incident(run,1);
assert.equal(run('activePlayers(l,1).length'),14);
run('l.minute=11;adaptManager(l,1)');
assert.equal(run('l.tactics[1]'),'conquete');
assert.equal(run('l.defences[1]'),'prudente');
assert.equal(run('l.managerMemory[1].lastCardDiff'),-1);
assert.equal(run('l.managerMemory[1].cardBase.attack'),'equilibre');
assert.equal(run('l.managerMemory[1].cardBase.defence'),'equilibre');
let events=run('l.events.length');
run('adaptManager(l,1)');
assert.equal(run('l.events.length'),events,'No repeated tactical event without a changed player count');
assert.equal(run('l.tactics[0]'),'equilibre','The user tactics stay under user control');

// Two yellows: double deficit changes attack to territory.
run('l.minute=12');
incident(run,1);
assert.equal(run('activePlayers(l,1).length'),13);
run('adaptManager(l,1)');
assert.equal(run('l.tactics[1]'),'occupation');
assert.equal(run('l.defences[1]'),'prudente');
assert.equal(run('l.managerMemory[1].lastCardDiff'),-2);
// The first yellow expires at 20, the second at 22.
run('l.minute=20;adaptManager(l,1)');
assert.equal(run('activePlayers(l,1).length'),14);
assert.equal(run('l.tactics[1]'),'conquete');
run('l.minute=22;adaptManager(l,1)');
assert.equal(run('activePlayers(l,1).length'),15);
assert.equal(run('l.tactics[1]'),'equilibre');
assert.equal(run('l.defences[1]'),'equilibre');
assert.equal(run('l.managerMemory[1].cardBase'),null);
assert.equal(run('l.managerMemory[1].lastCardDiff'),0);

// The AI can also exploit a short-handed opponent.
({run}=fixture());
incident(run,0);
run('l.minute=11;adaptManager(l,1)');
assert.equal(run('activePlayers(l,0).length'),14);
assert.equal(run('l.tactics[1]'),'large');
assert.equal(run('l.defences[1]'),'equilibre');
run('l.minute=12');
incident(run,0);
run('adaptManager(l,1)');
assert.equal(run('activePlayers(l,0).length'),13);
assert.equal(run('l.tactics[1]'),'large');
assert.equal(run('l.defences[1]'),'pression');
run('l.minute=22;adaptManager(l,1)');
assert.equal(run('l.tactics[1]'),'equilibre');
assert.equal(run('l.defences[1]'),'equilibre');

// A permanent red must not lead to a fictitious return.
({run}=fixture());
incident(run,1,'red');
run('l.minute=11;adaptManager(l,1)');
assert.equal(run('l.tactics[1]'),'conquete');
run('l.minute=50;adaptManager(l,1)');
assert.equal(run('activePlayers(l,1).length'),14);
assert.equal(run('l.tactics[1]'),'conquete');

// A 20-minute red gives access to an eligible replacement, never a player return.
({run}=fixture());
incident(run,1,'red20');
run('l.minute=11;adaptManager(l,1)');
assert.equal(run('l.tactics[1]'),'conquete');
run('l.minute=30;restoreRedReplacements(l,1);adaptManager(l,1)');
assert.equal(run('activePlayers(l,1).length'),15);
assert.equal(run('l.sheets[1].sentOff.length'),1);
assert.equal(run('l.tactics[1]'),'equilibre');

// Portable save / import retains mid-exclusion memory, and then restores the plan.
let instance=fixture();run=instance.run;
incident(run,1);
run('l.minute=11;adaptManager(l,1)');
const serialized=run('JSON.stringify(createSaveDocument())');
let loaded=context();
loaded.run(`pendingSave=parseSaveDocument(${JSON.stringify(serialized)});confirmSaveImport();var l=S.live`);
assert.equal(loaded.run('l.paused'),true);
assert.equal(loaded.run('l.numericalAiVersion'),1);
assert.equal(loaded.run('l.managerMemory[1].lastCardDiff'),-1);
assert.equal(loaded.run('l.managerMemory[1].cardBase.attack'),'equilibre');
loaded.run('l.minute=21;adaptManager(l,1)');
assert.equal(loaded.run('l.tactics[1]'),'equilibre');
assert.equal(loaded.run('!!createSaveDocument()'),true);

// Pre-V20 games never opt in silently, even with a card and an old manager memory.
const legacy=run('JSON.parse(JSON.stringify(S))');
delete legacy.live.numericalAiVersion;
legacy.live.managerMemory.forEach(m=>{delete m.lastCardDiff;delete m.cardBase});
const old=context(legacy);
old.run('var l=S.live;l.minute=12;l.tactics[1]="equilibre";l.defences[1]="equilibre";adaptManager(l,1)');
assert.equal(old.run('l.tactics[1]'),'equilibre');
assert.equal(old.run('l.defences[1]'),'equilibre');
assert.equal(old.run('!!createSaveDocument()'),true);

// Invalid new saved-state markers and plans must be rejected.
for(const change of [
 'bad.live.numericalAiVersion=5',
 'bad.live.managerMemory[1].lastCardDiff=99',
 'bad.live.managerMemory[1].cardBase.attack="invalid"'
]){
 run('var bad=JSON.parse(JSON.stringify(S))');
 if(change.includes('cardBase.attack')){
  run('bad.live.managerMemory[1].cardBase={attack:"equilibre",defence:"equilibre"}');
 }
 assert.throws(()=>run(change+';validateCareer(bad)'));
}

// The discovery difficulty retains its documented stable-plan behaviour.
({run}=fixture('decouverte'));
incident(run,1);
run('l.minute=11;adaptManager(l,1)');
assert.equal(run('l.tactics[1]'),'equilibre');
assert.equal(run('l.defences[1]'),'equilibre');

console.log('V20: 15v15, 15v14, 15v13, yellow expiry, red, red20, portable and legacy saves passed');
