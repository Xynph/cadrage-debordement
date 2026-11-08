'use strict';
const assert=require('node:assert/strict'),vm=require('node:vm'),fs=require('node:fs'),path=require('node:path');
const locker=require('../dist/living-locker-room-v117-v123.js'),vestiaire=require('../dist/vestiaire-v64.js'),duos=require('../dist/relations-duos-v70.js');
const make=()=>({season:1,club:0,phase:'league',morale:75,trust:70,economy:{week:27},manager:{inbox:[]},clubs:[{players:[{id:'a',age:22,condition:90,injury:0,rating:70,dev:{minutes:20},satisfaction:{score:60}},{id:'b',age:28,condition:90,injury:0,rating:75,dev:{minutes:100},satisfaction:{score:70}}]}]});
for(const outcome of ['honored','broken','injured','missing','departed']){
 const s=make();assert.equal(locker.apply(s,'responsabiliser',{save:()=>true}),true);const c=s.livingLockerRoom.commitments[0],p=s.clubs[0].players.find(p=>p.id===c.playerId),before=p.satisfaction.score,morale=s.morale;
 s.economy.week=c.dueWeek;s.phase='final';
 if(outcome==='honored')p.dev.minutes+=60;if(outcome==='injured')p.injury=1;if(outcome==='missing')delete p.dev.minutes;if(outcome==='departed')s.clubs[0].players=s.clubs[0].players.filter(x=>x!==p);
 locker.settle(s);
 assert.equal(c.status,['missing','departed'].includes(outcome)?'expired':outcome==='injured'?'honored':outcome);
 assert.equal(p.satisfaction.score,before+(c.status==='honored'?3:c.status==='broken'?-6:0));assert.equal(s.morale,morale+(c.status==='honored'?1:c.status==='broken'?-2:0));
 const exact=JSON.stringify(s);locker.settle(s);assert.equal(JSON.stringify(s),exact,'Une échéance ne doit pas être appliquée deux fois.');
}
{
 const s=make();locker.apply(s,'responsabiliser',{save:()=>true});s.season=2;const before=s.morale;locker.settle(s);assert.equal(s.livingLockerRoom.commitments[0].status,'expired');assert.equal(s.morale,before,'Une ancienne saison ne pénalise pas la nouvelle.');
}
{
 const s=make(),p=s.clubs[0].players[0];delete p.dev;const before=vestiaire.snapshot([p]);vestiaire.roundImpact([p],before);assert.equal(p.satisfaction.score,60,'Une mesure absente ne prouve pas une absence de temps de jeu.');
 p.satisfaction.baseline=20;p.dev={minutes:70};const prior=vestiaire.snapshot([p]);vestiaire.roundImpact([p],prior);assert.equal(p.satisfaction.score,61,'Les minutes déjà enregistrées avant le bilan sont prises en compte.');
}
{
 const s=make();s.v70Relations={version:1,last:'1:27',pairs:[{key:'a|b',a:'a',b:'b',score:60,season:1,week:27}]};
 const m={userSide:0,pair:[0,1],sheets:[{initial:['a','b'],on:['a','b']},{}],finished:false};m.v70Relations=duos.matchSnapshot(s,m);assert.equal(duos.matchBonus(m,0,'attack'),.009);
 m.sheets[0].on=['a',null];assert.equal(duos.matchBonus(m,0,'attack'),0,'Les deux partenaires doivent être sur le terrain.');
 s.clubs[0].players[1].injury=1;assert.equal(duos.matchSnapshot(s,m),null,'Un partenaire blessé n’active pas le lien.');
}
{
 const ctx=vm.createContext({});for(const name of ['living-locker-room-v117-v123.js','relations-duos-v70.js','vestiaire-v64.js'])vm.runInContext(fs.readFileSync(path.join(__dirname,'../dist',name),'utf8'),ctx);
 vm.runInContext('var controller=('+require('../native/engine/relationships.cjs').factory.toString()+')()',ctx);
 const s=make();ctx.state=s;vm.runInContext('controller.validate(state)',ctx);assert.equal(s.livingLockerRoom,undefined);
}
console.log('Effets du vestiaire : échéances finales, blessure, métrique absente, départ, intersaison et partenaires actifs PASS.');
