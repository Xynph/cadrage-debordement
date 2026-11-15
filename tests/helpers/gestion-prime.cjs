'use strict';
// Contrat public de versement sur données financières : aucune carrière créée.
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
function prizeContract(){
 const source=fs.readFileSync(path.join(__dirname,'../../dist/game.js'),'utf8');
 for(const name of ['validateChampionPrize','awardChampionPrize'])assert.match(source,new RegExp('function '+name+'\\('),'API publique absente : '+name);
 const start=source.indexOf('// Prime du Bouclier'),end=source.indexOf('function finishRound(){',start);
 assert.ok(start>=0&&end>start,'bloc public de données de la prime');
 const definitions=source.slice(start,end);
 const refused=()=>{throw Error('Le versement de données ne peut appeler moteur ou IO');};
 const box=vm.createContext({save:refused,render:refused,finishRound:refused,advanceSeason:refused,createRugbyMatch:refused,rugbySimulate:refused});
 vm.runInContext(definitions,box);
 const fixture=()=>({season:1,club:0,phase:'ended',clubs:[{id:0,cash:5000000},{id:1,cash:7000000}],ledger:Array.from({length:100},(_,i)=>({title:'History '+i,amount:0}))});
 const pay=(s,id=0,competition='elite')=>box.awardChampionPrize(s,id,competition);
 const wrong=fixture();wrong.worldManagement={champion:1};const notChampion=JSON.stringify(wrong);assert.equal(pay(wrong),false);assert.equal(JSON.stringify(wrong),notChampion);
 const s=fixture(),before=JSON.stringify(s);
 assert.equal(pay(s,1),false);assert.equal(pay(s,0,'prem'),false);assert.equal(JSON.stringify(s),before);
 assert.equal(pay(s),true);assert.equal(s.clubs[0].cash,6000000);assert.equal(s.clubs[1].cash,7000000);assert.equal(s.ledger.length,100);assert.equal(s.ledger.filter(e=>e.title==='Prime de champion').length,1);assert.equal(s.ledger[0].amount,1000000);assert.equal(box.validateChampionPrize(s),true);
 const paid=JSON.stringify(s);assert.equal(pay(s),false);assert.equal(JSON.stringify(s),paid);
 const restored=JSON.parse(paid);assert.equal(pay(restored),false);assert.equal(JSON.stringify(restored),paid);
 // Le reçu persiste quand le journal borné a perdu l’écriture.
 restored.ledger=[];const cash=restored.clubs[0].cash;assert.equal(pay(restored),false);assert.equal(restored.clubs[0].cash,cash);
 restored.season++;restored.phase='league';const ongoing=JSON.stringify(restored);assert.equal(pay(restored),false);assert.equal(JSON.stringify(restored),ongoing);
 restored.phase='ended';assert.equal(pay(restored),true);assert.equal(restored.clubs[0].cash,7000000);
 const actual=fixture();actual.worldMode={leagues:{elite:{phase:'ended',champion:1}}};assert.equal(pay(actual),false);actual.worldMode.leagues.elite.champion=0;assert.equal(pay(actual),true);
 const moved=JSON.parse(JSON.stringify(actual));moved.club=1;assert.equal(box.validateChampionPrize(moved),true);const movedBefore=JSON.stringify(moved);assert.equal(pay(moved,1),false);assert.equal(pay(moved,0),false);assert.equal(JSON.stringify(moved),movedBefore);moved.season=2;moved.phase='league';moved.worldMode={leagues:{elite:{phase:'league',champion:null}},yearbook:[{season:1,champions:{elite:0}}]};assert.equal(box.validateChampionPrize(moved),true);moved.worldMode.yearbook=[];assert.equal(box.validateChampionPrize(moved),true,'le reçu survit à la troncature des archives');const missingClubs=JSON.parse(JSON.stringify(moved));delete missingClubs.clubs;assert.throws(()=>box.validateChampionPrize(missingClubs),/Reçu de prime de champion invalide/);
 const early=fixture();early.phase='league';early.worldMode={leagues:{elite:{phase:'ended',champion:0}}};assert.equal(pay(early),true,'la finale élite ne dépend pas de la clôture globale World');assert.equal(box.validateChampionPrize(early),true);
 for(const change of [x=>x.championPrize.version=2,x=>x.championPrize.season=2,x=>x.championPrize.clubId=2,x=>x.championPrize.competitionId='prem',x=>x.championPrize.amount=999999,x=>x.championPrize.extra=true,x=>x.worldMode.leagues.elite.phase='league',x=>x.worldMode.leagues.elite.champion=1]){const bad=JSON.parse(JSON.stringify(actual));change(bad);assert.throws(()=>box.validateChampionPrize(bad));}
 return {passed:true,amount:1000000,checks:['pure data API','human elite champion only','bounded ledger100','once per season','receipt survives JSON and ledger truncation','new season','no foreign prize','strict malformed receipt rejection']};
}
function worldPrizeContract(g){
 assert.equal(g.run('S.worldMode.version'),5);assert.equal(g.run('S.worldMode.leagues.elite.phase'),'ended');
 assert.equal(g.run('S.championPrize.clubId'),g.run('S.worldMode.leagues.elite.champion'));
 assert.equal(g.run('S.championPrize.amount'),1000000);assert.equal(g.run('S.championPrize.season'),g.run('S.season'));
 const stored=g.store['bdt-v1'],before=g.run('JSON.stringify(S)');
 assert.equal(g.run('awardChampionPrize(S,S.worldMode.leagues.elite.champion)'),false);
 assert.ok(g.run('JSON.stringify(S)')===before);assert.equal(g.store['bdt-v1'],stored);
 const doc=JSON.parse(g.run('JSON.stringify(createSaveDocument())')),badState=JSON.parse(before);
 badState.championPrize.amount=999999;doc.state.championPrize.amount=999999;
 g.ctx.__badPrizeState=badState;
 try{doc.checksum=g.run('saveChecksum(__badPrizeState)');}finally{delete g.ctx.__badPrizeState;}
 g.ctx.__badPrizeDocument=JSON.stringify(doc);
 try{assert.throws(()=>g.run('parseSaveDocument(__badPrizeDocument)'),/Reçu de prime de champion invalide/,'reçu corrompu refusé après vrai décodage et checksum correct');}
 finally{delete g.ctx.__badPrizeDocument;}
 assert.ok(g.run('JSON.stringify(S)')===before);assert.equal(g.store['bdt-v1'],stored);
 return {passed:true,world:true,amount:1000000};
}
module.exports={prizeContract,worldPrizeContract};if(require.main===module)console.log(JSON.stringify(prizeContract()));
