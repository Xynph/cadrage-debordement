'use strict';
// Mode unique « Monde » (décision de Léo, 13/11/2026) : création, import et reprise de profil
// n'acceptent que le Monde complet, sauf drapeau explicite de test legacyModes ; les anciennes
// carrières sont supprimées au lancement.
const assert=require('node:assert/strict'),test=require('node:test');
const fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const {createBridge}=require('../native/engine/worker.cjs');

function fixture(t,options={}){
 const directory=fs.mkdtempSync(path.join(os.tmpdir(),'oval-mode-monde-'));
 let bridge=null,serial=0;
 const open=(extra={})=>{bridge?.close();bridge=createBridge({dataDir:directory,seed:27,now:1794310000000,...options,...extra});};
 open();
 t.after(()=>{bridge?.close();bridge=null;fs.rmSync(directory,{recursive:true,force:true});});
 const send=(command,payload={})=>bridge.handle({id:++serial,command,payload});
 return {send,open,directory,close(){bridge?.close();bridge=null;}};
}
const REFUSAL='Seul le mode Monde est disponible pour une nouvelle carrière.';

test('le joueur ne crée plus que des carrières Monde : tout autre mode est refusé sans rien écrire',t=>{
 const f=fixture(t);
 for(const payload of [{club:0},{mode:'fiction',club:0},{mode:'common',club:0},{mode:'france',club:0},{mode:'custom',club:0},{mode:'world',club:0},{mode:'world-pacific',club:0},{mode:'world-japan',club:0},{mode:'world-nationale',club:0}]){
  const result=f.send('new_career',payload);
  assert.equal(result.ok,false,JSON.stringify(payload));
  assert.equal(result.error,REFUSAL);
  assert.equal(result.model.club??null,null,'aucune carrière créée');
 }
});

test('le drapeau de test est explicite et typé',()=>{
 const directory=fs.mkdtempSync(path.join(os.tmpdir(),'oval-mode-monde-flag-'));
 try{assert.throws(()=>createBridge({dataDir:directory,legacyModes:'1'}),/Drapeau des anciens modes invalide/);}
 finally{fs.rmSync(directory,{recursive:true,force:true});}
});

test('anciennes carrières (France 30) : supprimées sans rien demander au lancement, réglages conservés, import refusé',t=>{
 const f=fixture(t,{legacyModes:true});
 const profile=path.join(f.directory,'PrototypeGodot');
 const read=()=>JSON.parse(fs.readFileSync(path.join(profile,'donnees.json'),'utf8'));
 assert.equal(f.send('pack_select',{scope:'creation',mode:'world-champ',id:'base'}).ok,true,'réglage de pack du joueur');
 assert.equal(f.send('new_career',{mode:'common',club:0}).ok,true);
 const second=f.send('new_career',{mode:'common',club:29});
 assert.equal(second.ok,true,second.error);
 const text=f.send('export').model.meta.exportText;
 assert.ok(second.model.meta.profileSafety.entries.length>=1,'une copie de sécurité de l’ancien mode existe');
 assert.ok(fs.existsSync(path.join(profile,'donnees-precedentes.json')));
 // Le jeu (sans drapeau) reprend le profil : tout ce qui porte une ancienne carrière disparaît.
 f.open({legacyModes:false});
 const resumed=f.send('snapshot');
 assert.equal(resumed.ok,true,resumed.error);
 assert.equal(resumed.model.meta.recoveryRequired,false,'aucun écran de récupération');
 assert.equal(resumed.model.meta.profileError,'');
 assert.equal(resumed.model.club??null,null);
 assert.match(resumed.model.meta.legacyPurgeNotice,/anciens modes de jeu ont été retirées/);
 assert.deepEqual(resumed.model.meta.profileSafety.entries,[]);
 assert.equal(fs.existsSync(path.join(profile,'donnees-precedentes.json')),false);
 const stored=read().store;
 assert.equal(stored['bdt-v1'],undefined);
 assert.equal(stored['identity-pack-champ-creation'],'base','les réglages du joueur restent');
 assert.deepEqual(fs.readdirSync(profile).filter(name=>/endommagees|tmp-/.test(name)),[],'aucun fichier conservé ni temporaire');
 // Lancement suivant : plus d'information, rien à retirer.
 f.open({legacyModes:false});
 assert.equal(f.send('snapshot').model.meta.legacyPurgeNotice,'');
 // Import d'un ancien fichier : refus explicite, aucune carrière chargée.
 const imported=f.send('import',{text});
 assert.equal(imported.ok,false);
 assert.match(imported.error,/ancien mode de jeu.*seul le mode Monde/);
 assert.equal(imported.model.club??null,null);
});

test('une carrière Monde se crée, s’exporte, se réimporte et se reprend sans drapeau',t=>{
 const f=fixture(t);
 const created=f.send('new_career',{mode:'world-champ',club:0});
 assert.equal(created.ok,true,created.error);
 assert.equal(created.model.meta.edition,'world-champ');
 const text=f.send('export').model.meta.exportText;
 f.open();
 const resumed=f.send('snapshot');
 assert.equal(resumed.ok,true,resumed.error);
 assert.equal(resumed.model.meta.recoveryRequired,false);
 assert.equal(resumed.model.meta.edition,'world-champ');
 const imported=f.send('import',{text});
 assert.equal(imported.ok,true,imported.error);
});
