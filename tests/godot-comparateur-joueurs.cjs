'use strict';
const assert=require('node:assert/strict');
const {spawnSync}=require('node:child_process');
const fs=require('node:fs');
const os=require('node:os');
const path=require('node:path');
const {test}=require('node:test');
const godot=process.env.CD_GODOT_EXECUTABLE;
test('Comparateur de joueurs : second choix par défaut, mémoire A/B et écarts sans nouvelle règle',{skip:!godot&&'SDK Godot requis'},()=>{
 const result=spawnSync(godot,['--headless','--path','native/godot','--script',path.resolve(__dirname,'godot-comparateur-joueurs.gd')],{cwd:path.resolve(__dirname,'..'),encoding:'utf8',timeout:30000});
 const output=(result.stdout||'')+(result.stderr||'');console.log(output.trim());if(result.error)throw result.error;
 assert.equal(result.status,0,output);assert.doesNotMatch(output,/SCRIPT ERROR|Parse Error|ERROR:/);
});
// Captures (rendu graphique, carrière Monde) : CD_COMPARATEUR_CAPTURE=<dossier> ; sans cette variable, rien n'est lancé.
// Comparateur ouvert depuis l'Effectif, depuis la fiche joueur, puis joueur du marché contre mon joueur (noms longs), en 1440p et 720p.
const dossier=process.env.CD_COMPARATEUR_CAPTURE;
test('Comparateur de joueurs : captures des écrans (CD_COMPARATEUR_CAPTURE)',{skip:(!godot&&'SDK Godot requis')||(!dossier&&'CD_COMPARATEUR_CAPTURE absent')},()=>{
 const Monde=require('./helpers/carriere-monde.cjs');
 const racine=fs.mkdtempSync(path.join(os.tmpdir(),'cd-comparateur-'));
 const sauvegarde=path.join(racine,'comparateur.json');
 const jeu=Monde.ouvrir({testVm:true});
 try{Monde.creer(jeu,102);fs.writeFileSync(sauvegarde,jeu.call('export').meta.exportText);}finally{jeu.fermer();}
 fs.mkdirSync(dossier,{recursive:true});
 const run=spawnSync(godot,['--display-driver','x11','--rendering-method','gl_compatibility','--windowed','--resolution','1920x1080','--max-fps','120','--audio-driver','Dummy','--path',path.resolve(__dirname,'../native/godot'),'--script',path.resolve(__dirname,'godot-comparateur-joueurs.gd')],{
  windowsHide:true,encoding:'utf8',timeout:900000,
  env:{...process.env,CD_GODOT_SELF_TEST:'0',CD_NODE_EXECUTABLE:process.execPath,CD_GODOT_DATA_DIR:path.join(racine,'PrototypeGodot'),CD_COMPARATEUR_SAUVEGARDE:sauvegarde,CD_COMPARATEUR_CAPTURE:path.resolve(dossier)},
 });
 const log=(run.stdout||'')+(run.stderr||'');fs.writeFileSync(path.join(racine,'godot.log'),log);console.log(log);
 fs.rmSync(sauvegarde,{force:true});
 if(run.error)throw run.error;
 assert.equal(run.status,0,'Godot : '+log.slice(-1500));
 assert.match(log,/COMPARATEUR CAPTURES\s*:\s*\d+ contrôles ; 0 échecs\b/);
 assert.doesNotMatch(log,/SCRIPT ERROR|Parse Error/);
 assert.ok(fs.readdirSync(dossier).filter(f=>f.endsWith('.jpg')).length>=6,'6 captures PNG attendues');
});
