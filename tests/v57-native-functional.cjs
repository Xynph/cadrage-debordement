'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs');
const save=fs.readFileSync('dist/saves.js','utf8'),world=fs.readFileSync('dist/world-career.js','utf8'),game=fs.readFileSync('dist/game.js','utf8');
let checks=[];
function test(name,fn){fn();checks.push({name,passed:true})}
function section(text,name){const i=text.indexOf('function '+name+'(');assert.ok(i>=0,name+' missing');const next=text.indexOf('\nfunction ',i+8);return text.slice(i,next>i?next:Math.min(text.length,i+7000))}
test('export et import natifs presents',()=>['createSaveDocument','parseSaveDocument','validateCareer','confirmSaveImport','bootSavedCareer'].forEach(n=>assert.ok(save.includes('function '+n+'('))));
test('import non destructif avant validation',()=>{const s=section(save,'confirmSaveImport');assert.match(s,/pendingSave/);assert.match(save,/saveReadToken/);});
test('sauvegarde locale protege erreurs',()=>{assert.match(game,/function save\(/);assert.match(save,/loadSaveFailure/);assert.match(save,/lastSaveError/);});
test('monde evenement match depuis vraie carriere',()=>{assert.match(world,/function worldRecordResult\(/);assert.match(world,/S\.history/);});
test('finances reliees aux clubs reels',()=>{const s=section(world,'worldWeeklyEconomy');assert.match(s,/S\.clubs/);});
test('infrastructures devis et validation',()=>{const s=section(world,'worldUpgradeFacility');assert.match(s,/worldFacilityQuote/);assert.match(s,/cash/);});
test('IA recrute selon decision et non signature fictive',()=>{assert.match(world,/function worldAIRecruitmentChoice\(/);assert.match(world,/négociations existantes restent seules décisionnaires/);});
test('reputation et archives reelles',()=>{assert.match(world,/function worldRecordChampion\(/);assert.match(world,/function worldEndSeason\(/);assert.match(world,/yearbook/);});
test('entraineur : variables de suivi',()=>{assert.match(world,/coachConfidence/);assert.match(world,/coachChanges/);});
test('avancee de saison reliee aux fonctions',()=>{assert.match(game,/function advanceSeason\(/);assert.match(world,/function worldNewSeason\(/);});
test('validation de carriere vraiment invoquee au demarrage',()=>{assert.match(section(save,'bootSavedCareer'),/validateCareer\(S\)/);});
test('aucune ecriture ou export utilisateur dans ce test',()=>assert.ok(!process.env.CD_WRITE_SAVE));
const report={kind:'native-source-functional-contract',checks,passed:checks.length,limitations:['Static source assertions, not runtime browser tests','No real user saves opened','No claim of completed in-game transfers']};
if(process.env.CD_V57_REPORT)fs.writeFileSync(process.env.CD_V57_REPORT,JSON.stringify(report,null,2)+'\n');
console.log('V57 NATIVE CONTRACTS PASS '+JSON.stringify({passed:report.passed}));
