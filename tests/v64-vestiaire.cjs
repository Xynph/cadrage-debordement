'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const V64=require('../dist/vestiaire-v64.js');

const person=(id,score=65,minutes=0)=>({
 id,name:'Joueur '+id,injury:0,dev:{minutes},
 satisfaction:{version:1,score,season:1,baseline:minutes,promise:null,history:[]}
});
test('V64 : un titulaire suivi recupere confiance, un joueur mecontent non utilise se crispe',()=>{
 const active=person('a',60,90),unused=person('b',45,0),injured=person('c',35,0);
 injured.injury=2;
 const before=V64.snapshot([active,unused,injured]);
 active.dev.minutes=135;
 const result=V64.roundImpact([active,unused,injured],before);
 assert.equal(active.satisfaction.score,61);
 assert.equal(unused.satisfaction.score,44);
 assert.equal(injured.satisfaction.score,35);
 assert.deepEqual(result.changes.map(x=>[x.id,x.delta]),[['a',1],['b',-1]]);
 assert.ok(result.moodDelta<0);
});
test('V64 : une promesse tenue renforce le collectif ; un echec le fragilise',()=>{
 const kept=person('a',66,20),broken=person('b',66,20);
 kept.satisfaction.promise={target:'rotation',season:1,round:1,completed:2,minutes:70};
 broken.satisfaction.promise={target:'titulaire',season:1,round:1,completed:2,minutes:20};
 const prior=V64.snapshot([kept,broken]);
 kept.satisfaction.promise=null;
 broken.satisfaction.promise=null;
 kept.satisfaction.history.push({status:'kept'});
 broken.satisfaction.history.push({status:'broken'});
 const result=V64.roundImpact([kept,broken],prior);
 assert.deepEqual(result.warnings.map(x=>x.type),['kept','broken']);
 assert.equal(result.moodDelta,-2);
 assert.equal(kept.satisfaction.score,66);
 assert.equal(broken.satisfaction.score,66);
});
test('V64 : entretiens distincts, un seul effet collectif par journee',()=>{
 assert.deepEqual(V64.meetingImpact('ecouter',true),{morale:0,trust:0});
 assert.deepEqual(V64.meetingImpact('rassurer',true),{morale:1,trust:0});
 assert.deepEqual(V64.meetingImpact('clarifier',true),{morale:0,trust:1});
 assert.deepEqual(V64.meetingImpact('rassurer',false),{morale:0,trust:0});
});
test('V64 : le panneau encode les noms et ne permet pas de parler en match',()=>{
 const p=person('p1',37);
 p.name='<Joueur & Co>';
 const s={satisfactionVersion:1,relationsVersion:1,morale:51,season:1,round:2,phase:'league',live:{},economy:{week:2,talks:{},relationLog:[]}};
 const html=V64.panel(s,[p]);
 assert.match(html,/&lt;Joueur &amp; Co&gt;/);
 assert.match(html,/En crise/);
 assert.doesNotMatch(html,/onclick="coachConversation/);
 assert.match(html,/moral collectif/i);
});
test('V64 : raccordement reel V36/V37, sauvegarde native sans nouvelle propriete',()=>{
 const p=person('p1',45,0),s={
 satisfactionVersion:1,relationsVersion:1,club:0,season:1,round:2,morale:70,trust:60,
 phase:'league',live:null,economy:{week:2,talks:{},relationLog:[]},
 clubs:[{players:[p]}]
 };
 let saved=0,rendered=0;
 const root={S:s,
  save(){saved++;},render(){rendered++;},
  managerMessage(){},
  managerTeamView(){return '<div>Équipe</div>';},
  recordSatisfactionRound(){return true;},
  coachConversation(id,choice){
   if(choice==='rassurer'){
    p.satisfaction.score++;
    s.economy.relationLog.unshift({kind:'coach',season:1,round:2,playerId:id,detail:choice});
    return true;
   }
   return false;
  }
 };
 assert.equal(V64.install(root),true);
 assert.equal(V64.install(root),true);
 assert.match(root.managerTeamView(),/Vestiaire/);
 assert.equal(root.coachConversation('p1','rassurer'),true);
 assert.equal(s.morale,71);
 assert.equal(root.coachConversation('p1','rassurer'),true);
 assert.equal(s.morale,71); // anti cumul des bonus collectifs
 assert.equal(root.recordSatisfactionRound({finished:true,pair:[0,1],userSide:0}),true);
 assert.equal(p.satisfaction.score,45); // zero minute et tension deja visible
 assert.ok(s.morale<71);
 assert.equal(saved,2);
 assert.equal(rendered,2);
 const json=JSON.parse(JSON.stringify(s));
 assert.equal(json.vestiaireV64,undefined);
 assert.equal(json.clubs[0].players[0].satisfaction.score,45);
});
