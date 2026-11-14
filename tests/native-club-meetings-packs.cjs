'use strict';
// Packs d'identités et rendez-vous du club : la gestion des packs reste possible pendant un rendez-vous
// obligatoire (réglage de présentation), sans toucher au rendez-vous ni à la carrière ; l'action sportive reste refusée.
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),os=require('node:os');
const media=require('../native/engine/media-packs.cjs'),{createBridge}=require('../native/engine/worker.cjs');
const root=fs.mkdtempSync(path.join(os.tmpdir(),'cd-meeting-packs-'));let seq=0,bridge,model;
function archive(manifest){
 const data=Buffer.from(JSON.stringify(manifest)),n=Buffer.from('pack.json'),l=Buffer.alloc(30),c=Buffer.alloc(46),crc=media.crc32(data);
 l.writeUInt32LE(0x04034b50);l.writeUInt16LE(20,4);l.writeUInt16LE(0x800,6);l.writeUInt32LE(crc,14);l.writeUInt32LE(data.length,18);l.writeUInt32LE(data.length,22);l.writeUInt16LE(n.length,26);
 c.writeUInt32LE(0x02014b50);c.writeUInt16LE(20,4);c.writeUInt16LE(20,6);c.writeUInt16LE(0x800,8);c.writeUInt32LE(crc,16);c.writeUInt32LE(data.length,20);c.writeUInt32LE(data.length,24);c.writeUInt16LE(n.length,28);
 const offset=30+n.length+data.length,end=Buffer.alloc(22);end.writeUInt32LE(0x06054b50);end.writeUInt16LE(1,8);end.writeUInt16LE(1,10);end.writeUInt32LE(46+n.length,12);end.writeUInt32LE(offset,16);
 const file=path.join(root,'pack-'+(++seq)+'.zip');fs.writeFileSync(file,Buffer.concat([l,n,data,c,n,end]));return file;
}
const call=(command,payload={})=>bridge.handle({id:++seq,command,payload});
function good(command,payload={}){const r=call(command,payload);assert.equal(r.ok,true,command+': '+r.error);model=r.model;return model;}
function bad(command,payload={}){const r=call(command,payload);assert.equal(r.ok,false,command+' doit être refusé');return r;}
const exported=()=>good('export').meta.exportText,state=()=>JSON.parse(exported()).state;
const withoutPack=s=>{const v=structuredClone(s);delete v.identityPack;return v;};
const room=()=>model.clubLife.clubMeetings.scene,meetings=()=>JSON.stringify(model.clubLife.clubMeetings);
const names=()=>model.squad.map(p=>p.name),questions=()=>model.clubLife.press.conference.questions.map(q=>({id:q.id,answers:q.answers.map(a=>a.id)}));
const refusal=/Rendez-vous du club : terminez le rendez-vous en attente, dans votre courrier, en Réception, avant de poursuivre\./;
try{
 bridge=createBridge({dataDir:path.join(root,'carriere'),seed:321,now:1700000000000});
 good('new_career',{mode:'world-champ',club:1});
 // Le rendez-vous en attente est la conférence de presse, ouverte dès la création de la carrière.
 assert.equal(room().kind,'press');assert.equal(room().completed,false);
 // Pack d'identités de l'édition Monde : base de données et références de joueurs lues dans la carrière Monde créée.
 const manifest={schema:'cd-identity-pack-v1',id:'rdv-test',name:'Rendez-vous test',version:'1',databaseId:model.meta.champDatabase.id,rightsStatus:'test-local',clubs:model.meta.champCatalogue.map(c=>({id:c.id,name:'Club témoin '+c.id,abbr:'T'+c.id})),players:model.squad.map((p,i)=>({id:p.id,name:'Joueur témoin '+i})),assets:[]};
 const before={meetings:meetings(),state:withoutPack(state()),names:names(),questions:questions(),roomId:room().id};
 const file=path.join(model.meta.dataDir,'donnees.json'),seedBefore=JSON.parse(fs.readFileSync(file)).seed;

 // 1. Toute la gestion des packs est acceptée pendant le rendez-vous.
 const zip=archive(manifest),preview=good('pack_inspect',{path:zip,mode:'world-champ'}).packs.preview;
 good('pack_install',{path:zip,digest:preview.digest,mode:'world-champ'});good('pack_select',{id:preview.id,scope:'creation',mode:'world-champ'});
 good('pack_select',{id:preview.id,scope:'career'});
 assert.equal(model.packs.career,preview.id);

 // 2. Le rendez-vous et la carrière sont intacts : seule la présentation change.
 assert.equal(meetings(),before.meetings,'Le rendez-vous en cours ne change pas');assert.equal(room().id,before.roomId);assert.equal(room().completed,false);
 assert.deepEqual(questions(),before.questions,'Mêmes questions et mêmes réponses de conférence');
 assert.deepEqual(withoutPack(state()),before.state,'Aucun effet sur la carrière enregistrée (effectif, finances, temps, rendez-vous)');
 assert.equal(JSON.parse(fs.readFileSync(file)).seed,seedBefore,'Le tirage aléatoire enregistré ne bouge pas');
 assert.notDeepEqual(names(),before.names);assert.ok(names().some(n=>n.startsWith('Joueur témoin')),'Les noms du pack sont affichés');

 // 3. L'action sportive reste refusée, avec la marche à suivre, et sans effet.
 const frozen=exported();
 for(const command of ['train','auto_lineup','begin_match','finish_round','next_season','set_tactics','recruit','advance_day']){const r=bad(command,{});assert.match(r.error,refusal,command);}
 assert.equal(exported(),frozen,'Les refus ne changent rien');

 // 4. Reprise : le rendez-vous et le pack survivent au redémarrage ; on repasse au pack de base pendant le rendez-vous.
 good('shutdown');bridge=createBridge({dataDir:path.join(root,'carriere')});good('snapshot');
 assert.equal(meetings(),before.meetings);assert.ok(names().some(n=>n.startsWith('Joueur témoin')));assert.equal(exported(),frozen);
 good('pack_select',{id:'base',scope:'career'});
 assert.deepEqual(names(),before.names,'Retour exact aux noms de base');assert.equal(meetings(),before.meetings);assert.deepEqual(withoutPack(state()),before.state);

 // 5. Conférence terminée mais pas encore refermée : le pack peut encore changer, la conférence enregistrée reste identique.
 good('pack_select',{id:preview.id,scope:'career'});const withPack=exported();
 const p=model.clubLife.press;
 good('press_conference',{context:p.context,answers:p.conference.questions.map(q=>({questionId:q.id,answerId:q.answers[0].id}))});
 assert.equal(room().completed,true);const done=meetings(),doneState=withoutPack(state());
 good('pack_select',{id:preview.id,scope:'career'});
 assert.equal(meetings(),done);assert.deepEqual(withoutPack(state()),doneState,'Conférence archivée : texte enregistré inchangé');
 bad('train',{});
 good('club_meeting_continue',{meetingId:room().id});

 // 6. Carrière reprise sans son pack : l'avertissement invite à gérer les packs, et le choix du pack de base est possible.
  good('shutdown');bridge=null;
 const other=createBridge({dataDir:path.join(root,'autre-poste')});
 try{
  const r=other.handle({id:++seq,command:'import',payload:{text:withPack}});assert.equal(r.ok,true,r.error);
  assert.equal(r.model.packs.missing.length,1,'Pack absent signalé');assert.equal(r.model.clubLife.clubMeetings.scene.kind,'press');
  const t=other.handle({id:++seq,command:'train',payload:{}});assert.equal(t.ok,false);assert.match(t.error,refusal);
  const s=other.handle({id:++seq,command:'pack_select',payload:{id:'base',scope:'career'}});assert.equal(s.ok,true,s.error);
  assert.equal(s.model.packs.missing.length,0,'Plus de pack absent après le retour au pack de base');
  assert.equal(s.model.clubLife.clubMeetings.scene.id,before.roomId,'Le rendez-vous attend toujours');
  assert.equal(other.handle({id:++seq,command:'train',payload:{}}).ok,false,'Le sportif reste refusé');
 }finally{other.close();}

 console.log('Packs pendant un rendez-vous du club : accès, application à l’affichage seule, rendez-vous intact, sportif refusé, reprise PASS.');
}finally{bridge?.close();fs.rmSync(root,{recursive:true,force:true});}
