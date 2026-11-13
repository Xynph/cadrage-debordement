'use strict';
process.env.CD_MODES_HERITES='1'; // Anciens modes de carrière (non-Monde) : test à migrer vers le mode Monde.
const assert=require('node:assert/strict');
const {make}=require('./native-academy.cjs');

// Une charnière de faible niveau couvre le banc 6 avant la promotion. Le nouvel
// ailier prend le XV ; l'ancien ailier prend ensuite le banc 6 et laisse le 7 vide.
// Une seule visite de chaque case ne suffit donc pas à réparer cette feuille.
function redistributionFixture(){
 const t=make(),r=t.run;
 r(`
  S.season=7;
  const coverClub=S.clubs[21];
  const coverPlayer=(slot,serial,rating)=>{
   const p=academyPlayer(21,slot,7,serial);
   p.age=19;p.rating=rating;p.skillBase=rating;
   for(const k of Object.keys(p.skills))p.skills[k]=rating;
   p.academy=false;p.contractEnd=9;return p;
  };
  coverClub.players=[...Array.from({length:15},(_,slot)=>coverPlayer(slot,slot,60)),
   ...[1,0,2,3,5,8].map((slot,i)=>coverPlayer(slot,100+i,60)),
   coverPlayer(8,200,20)];
  const coverAcademy=aiRosterAcademy(coverClub);
  coverAcademy.players=[coverPlayer(10,303,90)];
  coverAcademy.players[0].academy=true;
 `);
 return t;
}

{
 const t=redistributionFixture(),r=t.run;
 assert.equal(r('[...buildSheet(coverClub).lineup,...buildSheet(coverClub).bench].filter(Boolean).length'),22);
 assert.equal(r('buildSheet(coverClub).bench[7]'),null);
 const original=r('JSON.stringify(S)');
 r('aiRosterPromote(coverClub,10,true)');
 assert.equal(r('buildSheet(coverClub).lineup[10]'),'youth-21-7-303');
 assert.ok(r('buildSheet(coverClub).bench[6]'));
 assert.equal(r('buildSheet(coverClub).bench[7]'),null,'La première promotion redistribue le XV sans combler le dernier banc');
 t.ctx.coverOriginal=original;
 // Conserver la référence de club, comme dans les appels réels de la carrière.
 r('Object.assign(S,JSON.parse(coverOriginal));Object.assign(coverClub,S.clubs[21]);S.clubs[21]=coverClub');
 assert.doesNotThrow(()=>r('CDFranceCareer.ensureAISheet(coverClub)'),
  'La réparation doit revérifier le dernier banc après redistribution');
 assert.equal(r('[...buildSheet(coverClub).lineup,...buildSheet(coverClub).bench].filter(Boolean).length'),23);
 assert.equal(r('new Set([...buildSheet(coverClub).lineup,...buildSheet(coverClub).bench]).size'),23);
 assert.equal(r('coverClub.players.length'),24,'Une promotion puis un renfort suffisent, sans autre recrutement');
 assert.equal(r('buildSheet(coverClub).lineup.every((id,i)=>slotEligible(coverClub.players.find(p=>p.id===id),i))'),true);
 assert.equal(r('buildSheet(coverClub).bench.every((id,i)=>benchEligible(coverClub.players.find(p=>p.id===id),i))'),true);
 const before=r('JSON.stringify(S)'),seed=t.seed();
 r('CDFranceCareer.ensureAISheet(coverClub)');
 assert.equal(r('JSON.stringify(S)'),before,'Une feuille valide ne modifie aucune donnée');
 assert.equal(t.seed(),seed,'Une feuille valide ne consomme pas de tirage aléatoire');
 t.ctx.coverSaved=before;
 r('S=JSON.parse(coverSaved)');
 assert.equal(r('JSON.stringify(S)'),before,'La réparation conserve un état sérialisable sans migration');
}

{
 const t=redistributionFixture(),r=t.run;
 r('while(coverClub.players.length<100){const p=coverPlayer(8,1000+coverClub.players.length,60);p.injury=1;coverClub.players.push(p)}');
 assert.throws(()=>r('CDFranceCareer.ensureAISheet(coverClub)'),/plafond de 100/);
 assert.equal(r('coverClub.players.length'),100);
}

{
 const t=redistributionFixture(),r=t.run;
 // Injection d'une promotion incohérente pour vérifier l'arrêt sans progrès.
 r('aiRosterPromote=()=>true');
 assert.throws(()=>r('CDFranceCareer.ensureAISheet(coverClub)'),/aucun renfort qualifié|sans progression/);
 assert.equal(r('coverClub.players.length'),22);
}
console.log('PASS renfort IA : redistribution, 23 qualifiés uniques, idempotence/RNG, sérialisation, plafond et absence de progrès');

// Réception facultative : profil local lu uniquement, progression et reprise sur
// une copie jetable ; aucune sauvegarde personnelle n'est nécessaire à la CI.
for(const original of process.argv.slice(2)){
 const fs=require('node:fs'),path=require('node:path'),os=require('node:os'),crypto=require('node:crypto');
 const {createBridge}=require('../native/engine/worker.cjs');
 const bytes=fs.readFileSync(original),profile=JSON.parse(bytes),dir=fs.mkdtempSync(path.join(os.tmpdir(),'cd-native-ai-cover-'));
 fs.mkdirSync(path.join(dir,'PrototypeGodot'));
 fs.writeFileSync(path.join(dir,'PrototypeGodot','donnees.json'),bytes);
 let b=createBridge({dataDir:dir,now:profile.clock}),id=0;
 const good=(command,payload={})=>{const result=b.handle({id:++id,command,payload});assert.equal(result.ok,true,result.error);return result.model;};
 try{
  const prior=good('snapshot');
  if(!good('auto_lineup').selection.valid)good('promote_cover',{confirmed:true});
  good('begin_match');good('delegate');
  const next=good('finish_round');
  assert.equal(next.meta.week,prior.meta.week+1);
  good('save');
  const exported=good('export').meta.exportText;
  good('import',{text:exported});
  assert.equal(good('export').meta.exportText,exported,'Import/export exact après la journée réparée');
  b.close();b=createBridge({dataDir:dir,now:profile.clock});
  assert.equal(good('snapshot').meta.week,next.meta.week);
  assert.equal(good('export').meta.exportText,exported,'Reprise exacte après la journée réparée');
  assert.deepEqual(fs.readFileSync(original),bytes,'Le profil original reste strictement inchangé');
  console.log(JSON.stringify({test:'profil exact renfort IA',sha256:crypto.createHash('sha256').update(bytes).digest('hex'),priorWeek:prior.meta.week,nextWeek:next.meta.week,saveImportRestart:true,originalPreserved:true}));
 }finally{b.close();}
}
