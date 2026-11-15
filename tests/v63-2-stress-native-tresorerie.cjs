'use strict';
const {runScenario,finish}=require('./helpers/v63-2-scenarios.cjs');
finish('tresorerie-faible',runScenario('tresorerie-faible',{initialCash:100000,years:5,checkpoints:[1,3],invest:true}));
