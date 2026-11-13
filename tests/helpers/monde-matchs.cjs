'use strict';
const {settleClubMeetings}=require('./club-meetings.cjs');
const assert=require('node:assert/strict');

// Carrière Monde (world-champ) : les premières semaines sont des semaines de préparation sans match
// du club ; chaque semaine ouvre des rendez-vous du club à traiter avant de poursuivre. Ces aides
// n'utilisent que les commandes publiques du worker (finish_round, begin_match, delegate).

// Fait avancer la carrière, semaine après semaine, jusqu'à ce qu'un match du club soit disponible.
function advanceToNextMatch(model,send,{maxWeeks=60}={}){
 model=settleClubMeetings(model,send);
 for(let week=0;!model.next&&week<maxWeeks;week++)model=settleClubMeetings(send('finish_round'),send);
 assert.ok(model.next,'Un match du club doit finir par être disponible');
 return model;
}

// Joue (délégué) le prochain match du club puis clôt la journée ; retourne le modèle après les rendez-vous.
function playNextMatch(model,send,options){
 model=advanceToNextMatch(model,send,options);
 send('begin_match');send('delegate');
 return settleClubMeetings(send('finish_round'),send);
}

module.exports={advanceToNextMatch,playNextMatch};
