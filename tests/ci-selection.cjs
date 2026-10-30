const assert=require('node:assert/strict');
const {selectTests,allTests}=require('../ci/select-tests.cjs');
const equals=(changed,expected)=>assert.deepEqual(selectTests(changed),expected.sort());
assert.ok(allTests.length>=21,'La suite complète doit rester disponible');
assert.ok(allTests.includes('tests/saves.cjs'));
assert.ok(allTests.includes('tests/v21-numerical-advice.cjs'));
assert.ok(allTests.includes('tests/v22-tactical-comparison.cjs'));
assert.ok(allTests.includes('tests/v23-local-zones.cjs'));
assert.ok(allTests.includes('tests/v24-four-zones.cjs'));
assert.ok(allTests.includes('tests/v25-whatif.cjs'));
assert.ok(allTests.includes('tests/v26-dual-whatif.cjs'));
assert.ok(allTests.includes('tests/v27-physical-load.cjs'));
assert.ok(allTests.includes('tests/v28-collective-preparation.cjs'));
assert.ok(allTests.includes('tests/v29-focused-development.cjs'));
assert.ok(allTests.includes('tests/v30-recruitment-intelligence.cjs'));
assert.ok(allTests.includes('tests/v31-finance-forecasts.cjs'));
assert.ok(allTests.includes('tests/v32-succession-planning.cjs'));
assert.ok(!allTests.includes('tests/harness.cjs'));

// PR/main utilisent toujours la suite complète ; un diff manquant doit échouer en mode sûr.
equals([],allTests.slice());
equals(['tests/harness.cjs'],allTests.slice());
equals(['dist/new-engine.js'],allTests.slice());
equals(['src/unknown.cjs'],allTests.slice());
equals(['tests/missing-test.cjs'],allTests.slice());

// Le code de gameplay sélectionne les dépendances critiques (sauvegardes incluses).
equals(['dist/tactical-plans.js'],[
 'tests/tactical-plans.cjs','tests/v20-numerical-ai.cjs',
 'tests/v21-numerical-advice.cjs','tests/v22-tactical-comparison.cjs','tests/v23-local-zones.cjs','tests/v24-four-zones.cjs','tests/v25-whatif.cjs','tests/v26-dual-whatif.cjs','tests/saves.cjs'
]);
const rugby=selectTests(['dist/rugby.js']);
for(const test of ['tests/rugby.cjs','tests/frontrow.cjs','tests/discipline.cjs','tests/saves.cjs','tests/v21-numerical-advice.cjs']){
 assert.ok(rugby.includes(test),test);
}
equals(['dist/saves.js'],[
 'tests/saves.cjs','tests/v20-numerical-ai.cjs','tests/v21-numerical-advice.cjs','tests/v22-tactical-comparison.cjs','tests/v23-local-zones.cjs','tests/v24-four-zones.cjs','tests/v25-whatif.cjs','tests/v26-dual-whatif.cjs','tests/v27-physical-load.cjs','tests/v28-collective-preparation.cjs','tests/v29-focused-development.cjs','tests/v30-recruitment-intelligence.cjs','tests/v32-succession-planning.cjs',
 'tests/frontrow.cjs','tests/match-rules.cjs'
]);
equals(['tests/v21-numerical-advice.cjs'],['tests/v21-numerical-advice.cjs']);
equals(['tests/v22-tactical-comparison.cjs'],['tests/v22-tactical-comparison.cjs']);
equals(['tests/v23-local-zones.cjs'],['tests/v23-local-zones.cjs']);
equals(['tests/v24-four-zones.cjs'],['tests/v24-four-zones.cjs']);
equals(['tests/v25-whatif.cjs'],['tests/v25-whatif.cjs']);
equals(['tests/v26-dual-whatif.cjs'],['tests/v26-dual-whatif.cjs']);
equals(['tests/v27-physical-load.cjs'],['tests/v27-physical-load.cjs']);
equals(['tests/v28-collective-preparation.cjs'],['tests/v28-collective-preparation.cjs']);
equals(['tests/v29-focused-development.cjs'],['tests/v29-focused-development.cjs']);
equals(['tests/v30-recruitment-intelligence.cjs'],['tests/v30-recruitment-intelligence.cjs']);
equals(['tests/v31-finance-forecasts.cjs'],['tests/v31-finance-forecasts.cjs']);
equals(['tests/v32-succession-planning.cjs'],['tests/v32-succession-planning.cjs']);
equals(['ci/select-tests.cjs','.github/workflows/tests.yml'],['tests/ci-selection.cjs']);
assert.ok(selectTests(['dist/match-preparation.js']).includes('tests/v28-collective-preparation.cjs'));
assert.ok(selectTests(['dist/restarts.js']).includes('tests/v28-collective-preparation.cjs'));
assert.ok(selectTests(['dist/game.js']).includes('tests/v28-collective-preparation.cjs'));
assert.ok(selectTests(['dist/rugby.js']).includes('tests/v28-collective-preparation.cjs'));
assert.ok(selectTests(['dist/development.js']).includes('tests/v29-focused-development.cjs'));
assert.ok(selectTests(['dist/manager-squad.js']).includes('tests/v29-focused-development.cjs'));
assert.ok(selectTests(['dist/game.js']).includes('tests/v29-focused-development.cjs'));
assert.ok(selectTests(['dist/rugby.js']).includes('tests/v29-focused-development.cjs'));
for(const path of ['dist/manager.js','dist/economy.js','dist/rugby.js','dist/development.js','dist/saves.js','dist/game.js','dist/style.css'])assert.ok(selectTests([path]).includes('tests/v30-recruitment-intelligence.cjs'),path);
for(const path of ['dist/game.js','dist/economy.js','dist/style.css'])assert.ok(selectTests([path]).includes('tests/v31-finance-forecasts.cjs'),path);
for(const path of ['dist/manager.js','dist/manager-squad.js','dist/style.css','dist/economy.js','dist/development.js','dist/game.js','dist/rugby.js','dist/saves.js'])assert.ok(selectTests([path]).includes('tests/v32-succession-planning.cjs'),path);

equals(['dist/style.css','tests/v21-numerical-advice.cjs'],[
 'tests/match2d.cjs','tests/v21-numerical-advice.cjs','tests/v22-tactical-comparison.cjs','tests/v23-local-zones.cjs','tests/v24-four-zones.cjs','tests/v25-whatif.cjs','tests/v26-dual-whatif.cjs','tests/v27-physical-load.cjs','tests/v29-focused-development.cjs','tests/v30-recruitment-intelligence.cjs','tests/v31-finance-forecasts.cjs','tests/v32-succession-planning.cjs'
]);

// Une modification documentaire seule n'exécute pas les simulations, mais la PR les exécute toutes.
equals(['DEVELOPPEMENT.md','docs/rugby-rules-reference.md'],[]);
equals(['README.md'],[]);
console.log(JSON.stringify({passed:true,allTests:allTests.length,checks:[
 'fallback complet sur modification inconnue','dépendances gameplay',
 'compatibilité sauvegardes','tests dédiés','documentation seule',
 'configuration CI','sélection sans doublons'
]}));
