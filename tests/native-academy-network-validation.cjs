'use strict';
const { assertLegacyProfessionals } = require('./helpers/assert-legacy-professionals.cjs');
const assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const {createBridge}=require('../native/engine/worker.cjs'),{make}=require('./native-academy.cjs');
const folder=fs.mkdtempSync(path.join(os.tmpdir(),'cd-academy-network-')),accepted=[];let seq=0,refusals=0;
function call(b,command,payload={}){return b.handle({id:++seq,command,payload});}
function good(b,command,payload={}){const x=call(b,command,payload);assert.equal(x.ok,true,command+': '+x.error);return x.model;}
const cases=[
 ['schooling texte',n=>n.players[0].schooling='broken'],
 ['offers objet',n=>n.players[0].offers={extra:true}],
 ['skill texte',n=>n.recruiters[0].skill='broken'],
 ['lastReport false',n=>n.players[0].lastReport=false],
 ['lastReport null',n=>n.players[0].lastReport=null],
 ...['schooling','family','ambition'].flatMap(k=>[
  [k+' négatif',n=>n.players[0][k]=-1],[k+' >100',n=>n.players[0][k]=101],
  [k+' fraction',n=>n.players[0][k]=50.5],[k+' false',n=>n.players[0][k]=false]]),
 ['offers négatif',n=>n.players[0].offers=-1],['offers fraction',n=>n.players[0].offers=.5],
 ['offers invraisemblable',n=>n.players[0].offers=1e9],
 ['homeClub inconnu',n=>n.players[0].homeClub='unknown'],
 ['homeClub étranger',n=>n.players[0].homeClub=n.feeders[1].id],
 ['identité prospect étrangère',n=>n.players[0].id='feeder-youth-1-season-1'],
 ['clubName incohérent',n=>n.players[0].clubName='wrong'],
 ['region incohérente',n=>n.players[0].region='Alpes'],
 ['union incohérente',n=>n.players[0].union='PT'],
 ['pos inconnu',n=>n.players[0].pos='broken'],
 ['originSeason future',n=>n.players[0].originSeason=99],
 ['originSeason null',n=>n.players[0].originSeason=null],
 ['clearanceRecorded null',n=>n.players[0].clearanceRecorded=null],
 ['clearanceRecorded texte',n=>n.players[0].clearanceRecorded='yes'],
 ['skill >100',n=>n.recruiters[0].skill=101],['skill négatif',n=>n.recruiters[0].skill=-1],
 ['skill fraction',n=>n.recruiters[0].skill=75.5],
 ['recruteur sans nom',n=>n.recruiters[0].name=''],
 ['recruteur zone inconnue',n=>n.recruiters[0].zone='unknown'],
 ['recruteur dupliqué',n=>n.recruiters[0].name=n.recruiters[1].name],
 ['rapport recruteur inconnu',n=>n.players[0].lastReport={season:1,recruiter:'unknown',reliability:80}],
 ['rapport recruteur false',n=>n.players[0].lastReport={season:1,recruiter:false,reliability:80}],
 ['rapport fiabilité >95',n=>n.players[0].lastReport={season:1,recruiter:n.recruiters[0].name,reliability:96}],
 ['rapport fiabilité fraction',n=>n.players[0].lastReport={season:1,recruiter:n.recruiters[0].name,reliability:.5}],
 ['club relation négative',n=>n.feeders[0].relationship=-1],
 ['club relation texte',n=>n.feeders[0].relationship='broken'],
 ['club région inconnue',n=>n.feeders[0].region='unknown'],
 ['club union inconnue',n=>n.feeders[0].union='unknown'],
 ['partenaire inconnu',n=>n.partners=['unknown']],
 ['historique action inconnue',n=>n.history.push({id:n.players[0].id,season:1,action:'unknown',club:n.feeders[0].id})],
 ['historique club inconnu',n=>n.history.push({id:n.players[0].id,season:1,action:'declined',club:'unknown'})],
 ['historique identité inconnue',n=>n.history.push({id:'unknown',season:1,action:'declined',club:n.feeders[0].id})],
 ['historique club incohérent',n=>n.history.push({id:n.players[0].id,season:1,action:'declined',club:n.feeders[1].id})],
 ['crédit kind inconnu',n=>n.credits.push({id:n.players[0].id,club:n.feeders[0].id,season:1,firstProfessionalSeason:1,kind:'unknown'})],
 ['crédit premier contrat futur',n=>n.credits.push({id:n.players[0].id,club:n.feeders[0].id,season:1,firstProfessionalSeason:2,kind:'RIF-descriptive'})],
 ['crédit club inconnu',n=>n.credits.push({id:n.players[0].id,club:'unknown',season:1,firstProfessionalSeason:1,kind:'RIF-descriptive'})],
 ['crédit identité inconnue',n=>n.credits.push({id:'unknown',club:n.feeders[0].id,season:1,firstProfessionalSeason:1,kind:'RIF-descriptive'})],
 ['lastSeason false',n=>n.lastSeason=false]
];
for(const mode of ['V1','V2']){
 const t=make(mode==='V1'?0:29,mode==='V1'?'fiction':'common'),r=t.run;
 const b=createBridge({dataDir:path.join(folder,mode),seed:13,now:1700000000000});
 const control=createBridge({dataDir:path.join(folder,mode+'-control'),seed:13,now:1700000000000});
 try{
  if(mode==='V1'){
   r('CDEspoirsV73.setup(S);CDEspoirsAccessionV74.setup(S);CDEspoirsMovementV75.ensure(S);for(const a of [CDEspoirsScoutingV76,CDEspoirsProV77,CDEspoirsPathwaysV78V81,CDEspoirsCareerV82V85,CDEspoirsFollowupV86V89,CDEspoirsDynamicsV90V94,CDEspoirsStrategyV95V100,CDEspoirsCoachingV101V104])a.ensure(S);');
   r('for(let i=0;i<3;i++){finishRound();CDEspoirsV73.advance(S);CDEspoirsAccessionV74.advance(S)}');
  }else r('A.execute("academy_activate",{season:S.season,week:S.franceMode.week,club:S.club,confirmed:true})');
  // Exercise the actual APIs: discovery may set scouted without a lastReport.
  r('CDEspoirsStrategyV95V100.discover(S,"Bretagne",()=>true);CDEspoirsStrategyV95V100.watch(S,"feeder-youth-0-0",()=>true);CDEspoirsStrategyV95V100.trial(S,"feeder-youth-0-0",()=>true);CDEspoirsStrategyV95V100.partner(S,"feeder-0",()=>true)');
  const pristine=r('JSON.stringify(S)'),rng=t.seed();r('A.validate(S);A.validate(S)');
  assert.equal(r('JSON.stringify(S)'),pristine,'validation pure '+mode);assert.equal(t.seed(),rng);
  const text=r('JSON.stringify(createSaveDocument())');good(b,'import',{text});good(control,'import',{text});
  const stable=good(b,'export').meta.exportText,file=path.join(good(b,'snapshot').meta.dataDir,'donnees.json'),disk=fs.readFileSync(file);
  for(const [name,mutate]of cases){
   const state=JSON.parse(pristine);mutate(state.v95to100.network);t.ctx.candidate=state;
   // Start with the production export; recalculate its real checksum after corruption.
   // In V2 createSaveDocument itself now refuses these invalid states before export.
   const invalidDoc=JSON.parse(text);invalidDoc.state=state;invalidDoc.checksum=r('saveChecksum(candidate)');const invalid=JSON.stringify(invalidDoc);
   assert.equal(JSON.parse(invalid).checksum,r('saveChecksum(candidate)'));
   const response=call(b,'import',{text:invalid});
   if(response.ok){accepted.push(mode+' '+name);good(b,'import',{text:stable});continue;}
   assert.match(response.error,/Formation/i);
   assert.ok(good(b,'export').meta.exportText===stable,mode+' conserve export après '+name);
   if(!accepted.length)assert.ok(fs.readFileSync(file).equals(disk),mode+' conserve profil/octet/RNG après '+name);refusals++;
  }
  for(const source of ['S.v95to100.network.players[0].schooling=NaN','S.v95to100.network.recruiters[0].skill=Infinity']){
   r(source);assert.throws(()=>r('A.validate(S)'),/Formation/i,'non JSON rejeté directement');
   assert.equal(t.seed(),rng);t.ctx.pristine=pristine;r('S=JSON.parse(pristine)');
  }
  // No successful reimport between baseline and this comparison: valid imports may consume RNG.
  if(!accepted.length){good(b,'train');good(control,'train');assert.ok(good(b,'export').meta.exportText===good(control,'export').meta.exportText,'RNG en mémoire préservé '+mode);}
  // Omitted report and clearance are original shapes. Explicit false clearance is a valid boolean.
  r('delete S.v95to100.network.players[0].lastReport;S.v95to100.network.players[0].clearanceRecorded=false');
  good(b,'import',{text:r('JSON.stringify(createSaveDocument())')});
  assertLegacyProfessionals(JSON.parse(good(b,'export').meta.exportText).state,JSON.parse(r('JSON.stringify(S)')));
  if(mode==='V2'){
   const context=good(b,'snapshot').clubLife.academyPathways.context;
   good(b,'academy_watch',{...context,playerId:'feeder-youth-0-0',confirmed:true});
   const report=JSON.parse(good(b,'export').meta.exportText).state.v95to100.network.players[0].lastReport;
   assert.equal(report.recruiter,'Recruteur Nord');assert.ok(Number.isFinite(report.reliability));
  }
 }finally{b.close();control.close();}
}
assert.deepEqual(accepted,[],'imports invalides acceptés avec checksum exact');
console.log('PASS réseau académie : '+refusals+' imports checksum exact refusés V1/V2, API historiques/jours réels, observations/essai/partenariat, options valides, pureté et profil/export/octet/RNG préservés. Profils : '+folder);
