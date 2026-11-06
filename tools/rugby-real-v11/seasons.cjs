'use strict';
const fs=require('node:fs'),vm=require('node:vm');
const {context}=require('../../tests/harness.cjs');
const C=require('./calibration.cjs');
const proposal=require('../../docs/rugby-real-v11/save-proposal.json');
function applySaveProposal(g){const src=g.run('validateCareer.toString()');if(src.split(proposal.find).length!==2)throw Error('Save proposal precondition mismatch');g.run('validateCareer='+src.replace(proposal.find,proposal.replace));return g;}
function boot({saveProposal=false}={}){const g=context();for(const f of ['lnr-rosters-data.js','lnr-birthyears-data.js','lnr-career.js']){const file=__dirname+'/../../dist/'+f;if(fs.existsSync(file))vm.runInContext(fs.readFileSync(file,'utf8'),g.ctx);}g.run("start(0,'lnr')");return saveProposal?applySaveProposal(g):g;}
function run({years=3,saveProposal=false}={}){
 const g=boot({saveProposal}),records=[],ids=g.run('JSON.stringify(S.clubs.map(c=>c.name))');
 let matches=0;
 for(let y=0;y<years;y++){
  let rounds=0;
  while(g.run("S.phase!=='ended'")&&rounds<42){matches+=g.run('roundPairs().length');g.run('autoLineup();trainWeek();finishRound()');rounds++;}
  if(g.run("S.phase!=='ended'"))throw Error('Season did not terminate');
  let doc,parsed;try{doc=JSON.parse(g.run('JSON.stringify(createSaveDocument())'));g.ctx.__doc=JSON.stringify(doc);parsed=g.run('parseSaveDocument(__doc).checksum');}catch(e){return {passed:false,saveProposal,failedAtSeason:y+1,error:e.message,rounds:rounds+records.reduce((n,r)=>n+r.rounds,0),matches,records,diagnostic:JSON.parse(g.run('JSON.stringify(S.clubs.flatMap(c=>c.players).filter(p=>p.dev?.history.some(h=>h.age<16)).map(p=>({id:p.id,name:p.name,age:p.age,history:p.dev.history})))')),productionUntouched:true};}
  if(parsed!==doc.checksum)throw Error('Native save parse failed');
  const restored=boot({saveProposal});restored.ctx.__doc=JSON.stringify(doc);restored.run('pendingSave=parseSaveDocument(__doc)');
  if(!restored.run('confirmSaveImport()'))throw Error('Native save import failed');
  if(restored.run('JSON.stringify(S)')!==g.run('JSON.stringify(S)'))throw Error('Save import changed state');
  records.push(JSON.parse(g.run(`JSON.stringify({season:S.season,rounds:${rounds},clubs:S.clubs.length,managerWins:club().won,players:club().players.length,meanRating:mean(club().players.map(p=>p.rating)),meanCondition:mean(club().players.map(p=>p.condition)),injuries:club().players.filter(p=>p.injury).length,market:S.market.length})`)));
  if(y+1<years)g.run('advanceSeason()');
 }
 return {passed:true,saveProposal,kind:'Native LNR 14-club seasons, not senior TOP14/PROD2 promotion testing',years,rounds:records.reduce((n,r)=>n+r.rounds,0),matches,
  nativeSaveImportExport:records.length,clubNamesUnchanged:g.run('JSON.stringify(S.clubs.map(c=>c.name))')===ids,records,
  binding:{uses36AttributesInLnrGenerator:fs.readFileSync(__dirname+'/../../dist/lnr-career.js','utf8').includes('attributesV2'),seniorPromotionImplemented:false},
  limitations:['No senior two-division transition implementation: cannot claim maintenance/promotion odds','Generated LNR skill values are independent of master attributesV2','Native market/development run; candidate profiles were NOT injected into these saved careers']};
}
if(require.main===module){const r={current:run(),isolatedSaveProposal:run({saveProposal:true})};if(process.argv[2])fs.writeFileSync(process.argv[2],JSON.stringify(r,null,2)+'\n');console.log(JSON.stringify(r));}
module.exports={boot,run,applySaveProposal};
