'use strict';
// Rendez-vous du club obligatoires (carrière Monde, world-champ) : un refus dit QUEL rendez-vous attend et OÙ le trouver.
// Recette native du 16/11/2026 : en début de carrière, toutes les décisions (et l'ouverture des invitations) étaient
// refusées par « terminez le rendez-vous en attente » sans nommer la conférence de presse d'arrivée.
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),os=require('node:os');
const {createBridge}=require('../native/engine/worker.cjs');
const root=fs.mkdtempSync(path.join(os.tmpdir(),'cd-meeting-refus-'));let seq=0,bridge,model;
const call=(command,payload={})=>bridge.handle({id:++seq,command,payload});
function good(command,payload={}){const r=call(command,payload);assert.equal(r.ok,true,command+': '+r.error);model=r.model;return model;}
function refused(command,payload={}){const r=call(command,payload);assert.equal(r.ok,false,command+' doit être refusé');return r.error;}
const room=()=>model.clubLife.clubMeetings.scene;
try{
 bridge=createBridge({dataDir:path.join(root,'carriere'),seed:321,now:1700000000000});
 good('new_career',{mode:'world-champ',club:1});
 assert.equal(room().kind,'press','Le premier rendez-vous est la conférence de presse d’arrivée');

 // 1. Conférence de presse en attente : le refus la nomme et indique le bouton « Conf. de presse ».
 const tactics=model.tactics,invitation=(model.clubLife.sceneInvitations?.invitations||[]).find(e=>e.status==='pending');
 const press=refused('set_tactics',{attack:tactics.attacks[1]?.id||tactics.attack,defense:tactics.defense});
 assert.match(press,/^Rendez-vous du club : /,press);
 assert.match(press,/conférence de presse/i,'Le refus nomme la conférence de presse : '+press);
 assert.match(press,/« Conf\. de presse »/,'Le refus indique le bouton qui l’ouvre : '+press);
 assert.doesNotMatch(press,/termine le rendez-vous en attente/,'Plus de message générique');
 if(invitation){
  const open=refused('scene_invitation_open',{id:invitation.id});
  assert.match(open,/conférence de presse/i,'Ouvrir une invitation est refusé avec le même rendez-vous nommé : '+open);
 }

 // 2. Conférence tenue mais salle pas refermée : le refus demande « Continuer ».
 const p=model.clubLife.press;
 good('press_conference',{context:p.context,answers:p.conference.questions.map(q=>({questionId:q.id,answerId:q.answers[0].id}))});
 assert.equal(room().completed,true);
 const pending=refused('auto_lineup');
 assert.match(pending,/Continuer/,'Rendez-vous terminé : le refus demande de cliquer sur « Continuer » : '+pending);
 good('club_meeting_continue',{meetingId:room().id});

 // 3. Rendez-vous suivant (direction) : le refus le nomme.
 assert.equal(room()?.kind,'board','Puis le point avec la direction');
 const board=refused('auto_lineup');
 assert.match(board,/direction/i,'Le refus nomme le rendez-vous avec la direction : '+board);

 console.log('Refus des rendez-vous du club : presse, « Continuer » et direction nommés PASS.');
}finally{bridge?.close();fs.rmSync(root,{recursive:true,force:true});}
