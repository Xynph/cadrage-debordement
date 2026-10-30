const assert=require('node:assert/strict');
const {selectTests,allTests}=require('../ci/select-tests.cjs');
const equals=(changed,expected)=>assert.deepEqual(selectTests(changed),expected.sort());
assert.ok(allTests.length>=21,'La suite complète doit rester disponible');
assert.ok(allTests.includes('tests/saves.cjs'));
assert.ok(allTests.includes('tests/v21-numerical-advice.cjs'));
assert.ok(allTests.includes('tests/v22-tactical-comparison.cjs'));
assert.ok(allTests.includes('tests/v23-local-zones.cjs'));
assert.ok(allTests.includes('tests/v24-four-zones.cjs'));
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
 'tests/v21-numerical-advice.cjs','tests/v22-tactical-comparison.cjs','tests/v23-local-zones.cjs','tests/v24-four-zones.cjs','tests/v24-four-zones.cjs','tests/saves.cjs'
]);
const rugby=selectTests(['dist/rugby.js']);
for(const test of ['tests/rugby.cjs','tests/frontrow.cjs','tests/discipline.cjs','tests/saves.cjs','tests/v21-numerical-advice.cjs']){
 assert.ok(rugby.includes(test),test);
}
equals(['dist/saves.js'],[
 'tests/saves.cjs','tests/v20-numerical-ai.cjs','tests/v21-numerical-advice.cjs','tests/v22-tactical-comparison.cjs','tests/v23-local-zones.cjs',
 'tests/frontrow.cjs','tests/match-rules.cjs'
]);
equals(['tests/v21-numerical-advice.cjs'],['tests/v21-numerical-advice.cjs']);
equals(['tests/v22-tactical-comparison.cjs'],['tests/v22-tactical-comparison.cjs']);
equals(['tests/v23-local-zones.cjs'],['tests/v23-local-zones.cjs']);
equals(['tests/v24-four-zones.cjs'],['tests/v24-four-zones.cjs']);
equals(['ci/select-tests.cjs','.github/workflows/tests.yml'],['tests/ci-selection.cjs']);
equals(['dist/style.css','tests/v21-numerical-advice.cjs'],[
 'tests/match2d.cjs','tests/v21-numerical-advice.cjs','tests/v22-tactical-comparison.cjs','tests/v23-local-zones.cjs'
]);

// Une modification documentaire seule n'exécute pas les simulations, mais la PR les exécute toutes.
equals(['DEVELOPPEMENT.md','docs/rugby-rules-reference.md'],[]);
equals(['README.md'],[]);
console.log(JSON.stringify({passed:true,allTests:allTests.length,checks:[
 'fallback complet sur modification inconnue','dépendances gameplay',
 'compatibilité sauvegardes','tests dédiés','documentation seule',
 'configuration CI','sélection sans doublons'
]}));
