'use strict';
// Mode unique « Monde » (décision de Léo, 13/11/2026) : création, import et reprise de profil
// n'acceptent que le Monde complet, sauf drapeau explicite de test legacyModes.
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
 return {send,open,close(){bridge?.close();bridge=null;}};
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

test('une ancienne carrière (France 30) : import refusé et profil repris avec un message clair, sans plantage',t=>{
 const f=fixture(t,{legacyModes:true});
 const created=f.send('new_career',{mode:'common',club:0});
 assert.equal(created.ok,true,created.error);
 const text=f.send('export').model.meta.exportText;
 // Reprise du même profil par le jeu (sans drapeau) : message clair, récupération proposée.
 f.open({legacyModes:false});
 const resumed=f.send('snapshot');
 assert.equal(resumed.ok,true,resumed.error);
 assert.equal(resumed.model.meta.recoveryRequired,true);
 assert.match(resumed.model.meta.profileError,/ancien mode de jeu.*seul le mode Monde est disponible/);
 assert.doesNotMatch(resumed.model.meta.profileError,/illisible/);
 const recovered=f.send('recover_profile',{confirmed:true});
 assert.equal(recovered.ok,true,recovered.error);
 assert.equal(recovered.model.meta.recoveryRequired,false);
 assert.ok(fs.existsSync(recovered.model.meta.recoveryBackup),'le fichier de l’ancienne carrière est conservé');
 // Import du même document : refus explicite, aucune carrière chargée.
 const imported=f.send('import',{text});
 assert.equal(imported.ok,false);
 assert.match(imported.error,/ancien mode de jeu/);
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
