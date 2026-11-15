'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const {matchContext}=require('./harness.cjs');
const h=matchContext(30),run=h.run;
try{
 for(const file of ['lnr-rosters-base.js','lnr-career.js','lnr05-mesures.js','lnr05-evidence-center.js'])vm.runInContext(fs.readFileSync(__dirname+'/../dist/'+file,'utf8'),h.ctx);
 assert.equal(run('S.worldMode.version'),5);
 assert.equal(run('lnr05Enabled()'),true,'le calcul de rotation doit accepter la vraie carrière Monde');
 assert.equal(run('lnr05View()'),'','aucun ancien panneau dans le rendu Monde');
 run('club().players.forEach(p=>{p.injury=0;p.condition=S.lineup.includes(p.id)?5:100})');
 const before=run('JSON.stringify(S)'),stored=h.store['bdt-v1'],seed=h.seed();
 const options=run('lnr05AdviceCandidates(15).map(x=>({id:x.id,token:x.proposal.token,valid:x.proposal.valid}))');
 assert.ok(options.length>0,'conseils pour les identifiants étrangers, sans préfixe français');
 assert.ok(options.some(x=>!x.id.startsWith('lnr:')));
 assert.ok(options.every(x=>x.valid));
 assert.ok(run('JSON.stringify(S)')===before);assert.ok(h.store['bdt-v1']===stored);assert.equal(h.seed(),seed);
 const chosen=options[0],id=JSON.stringify(chosen.id),token=JSON.stringify(chosen.token);
 assert.equal(run('lnr05Apply('+id+','+token+')'),true);
 assert.equal(run('S.lineup.includes('+id+')'),true);assert.equal(run('sheetErrors().length'),0);
 assert.equal(run('lnr05Apply('+id+','+token+')'),false,'jeton périmé refusé');
 assert.ok(run('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'));
 run('S.live={finished:false}');assert.equal(run('lnr05AdviceCandidates().length'),0);
 assert.equal(run('lnr05Apply('+id+',lnr05Token())'),false,'match verrouillé');
 run('S.live=null');
 console.log('MONDE ROTATION PASS : club étranger, lecture sans mutation/RNG/écriture, confirmation, jeton périmé et verrou du direct');
}finally{h.close();}
