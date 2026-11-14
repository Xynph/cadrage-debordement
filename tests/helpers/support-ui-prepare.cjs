'use strict';
// Préparation de tests/native-club-support-ui.cjs, dans un processus à part : la sauvegarde Monde fait ~50 Mo et son
// moteur Node pèse plus d'1,3 Go ; une fois la sauvegarde écrite, ce processus se termine et rend sa mémoire avant
// qu'on lance Godot (dont le propre moteur recharge la sauvegarde). Sur une machine à 8 Go, garder les deux en vie
// faisait tuer l'un des processus par le système (« Réponse du moteur local illisible », « Le moteur est fermé »).
// Usage : node support-ui-prepare.cjs <dossier>   (le dossier reçoit PrototypeGodot/donnees.json)
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {createBridge}=require('../../native/engine/worker.cjs');
const {settleClubMeetings}=require('./club-meetings.cjs');
const {jusquAuMatch}=require('./carriere-monde.cjs');
const root=process.argv[2];assert.ok(root,'dossier de données requis');fs.mkdirSync(root,{recursive:true});
// Mêmes options que le vrai jeu : calendrier journalier, presse obligatoire, carrière internationale.
const b=createBridge({dataDir:root,seed:410,now:1700000000000,dailyCalendar:true,mandatoryPress:true,internationalCareer:true,matchHighlights:'dynamique'});
let n=0;const req=(command,payload={})=>{const r=b.handle({id:++n,command,payload});assert.equal(r.ok,true,command+' : '+r.error);return r.model;};
try{
 const jeu={call:req,regler:model=>settleClubMeetings(model,req)};
 // Carrière Monde au jour du premier match : c'est là que le briefing ciblé existe (il n'y a pas de rencontre à préparer en pré-saison).
 let model=jusquAuMatch(jeu,jeu.regler(req('new_career',{mode:'world-champ',club:29})));
 assert.ok(model.next&&model.meta.calendarCadence?.matchReady,'La préparation doit s\'arrêter un jour de match');
 // Un blessé écrit hors moteur (le moteur n'a pas de commande pour blesser), avec la somme de contrôle recalculée.
 const doc=JSON.parse(req('export').meta.exportText),p=doc.state.clubs[29].players[25];p.injury=2;
 let h=2166136261;for(const c of JSON.stringify(doc.state))h=Math.imul(h^c.charCodeAt(0),16777619);doc.checksum=(h>>>0).toString(16).padStart(8,'0');
 model=req('import',{text:JSON.stringify(doc)});
 // Le rendez-vous médical d'une blessure n'existe qu'à la prochaine commande acceptée (le moteur n'observe pas les imports) :
 // on la provoque ici par une vraie décision sur le blessé, puis on règle le rendez-vous. La sauvegarde remise à Godot n'a
 // ainsi aucun rendez-vous caché qui s'ouvrirait en pleine réunion de soutien et refuserait toutes les commandes suivantes.
 const hurt=model.clubLife.clubSupport.medical.players.find(x=>x.injury>0);assert.ok(hurt,'Le blessé injecté doit apparaître au suivi médical');
 model=req('medical_protocol',{context:model.clubLife.clubSupport.context,id:hurt.id,protocol:'standard'});
 settleClubMeetings(model,req);
 assert.equal(req('snapshot').clubLife.clubMeetings.scene,null,'Aucun rendez-vous en attente avant de lancer Godot');
}finally{b.close();}
