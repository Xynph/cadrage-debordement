'use strict';
const {runScenario,finish}=require('./helpers/v63-2-scenarios.cjs');
finish('club-en-deficit',runScenario('club-en-deficit',{initialCash:-250000,years:5,checkpoints:[2,4]}));
