'use strict';
// Contrats V46-V51 : sans copie des modules ni modification des sauvegardes.
// Tant que les PR ne sont pas fusionnées, ce test signale les dépendances absentes.
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const root=path.join(__dirname,'..','dist');
const modules=['club-ai','reputation','coach-market','facilities','rugby-world','world-simulation','financial-recovery','world-finance'];
const found=Object.fromEntries(modules.map(n=>[n,fs.existsSync(path.join(root,n+'.js'))]));
const missing=modules.filter(n=>!found[n]);
if(missing.length){
 console.log('CONTRATS NON EXECUTABLES : modules en PR distinctes : '+missing.join(', '));
 console.log('SKIP : vérifier après assemblage des branches V46-V51. Aucun test d\'interopérabilité revendiqué.');
}else{
 const ai=require('../dist/club-ai.js'),rep=require('../dist/reputation.js'),coach=require('../dist/coach-market.js'),fac=require('../dist/facilities.js'),world=require('../dist/rugby-world.js'),sim=require('../dist/world-simulation.js'),finance=require('../dist/financial-recovery.js'),bridge=require('../dist/world-finance.js');
 for(const [module,keys] of [[ai,['decideClub','planSeason','squadCoverage']],[rep,['update','reputationTier']],[coach,['dismissalRisk','jobOffers']],[fac,['investment']],[world,['awards']],[sim,['simulate']],[finance,['annual']],[bridge,['simulate']]])for(const key of keys)assert.equal(typeof module[key],'function');
 const clubs=Array.from({length:14},(_,i)=>({id:'c'+i,cash:i<5?400000:-20000,debt:i<5?0:20000,reputation:35+i*4,wageRoom:15000,facilities:3,coachConfidence:65}));
 const adapters={reputation:rep.update,coachRisk:coach.dismissalRisk,facility:fac.investment,recruitment:ai.decideClub,world:world.awards};
 const state=JSON.stringify(clubs);
 const options={clubs,seasons:15,seed:49,adapters};
 const a=bridge.simulate(options),b=bridge.simulate(options);
 assert.deepEqual(a,b,'simulations identiques');
 assert.equal(JSON.stringify(clubs),state,'aucune mutation des entrees');
 assert.equal(a.history.length,15);
 assert.equal(a.history.every(y=>y.standings.length===14),true);
 assert.equal(a.clubs.every(c=>Number.isFinite(c.cash)&&c.debt>=0&&c.facilities>=1&&c.facilities<=10),true);
 assert.ok(a.history.some(y=>y.standings.some(c=>c.restriction==='redressement')));
 console.log('PASS : contrats reels V46-V51, 14 clubs, 15 saisons');
}
