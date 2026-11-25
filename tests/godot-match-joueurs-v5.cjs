'use strict';
// Joueurs 3D v5 : gabarit par poste, taille du gabarit, carnations variées, une coupe au plus, tenue du club.
const {test}=require('node:test'),assert=require('node:assert/strict');
const {spawnSync}=require('node:child_process');
const path=require('node:path'),fs=require('node:fs');
const root=path.resolve(__dirname,'..');
test('Joueurs v5 : manifeste, gabarits et peaux présents (source)',()=>{
 const dossier=path.join(root,'dist/match3d/assets/joueurs');
 const manifeste=JSON.parse(fs.readFileSync(path.join(dossier,'joueurs.json'),'utf8'));
 assert.equal(Object.keys(manifeste.profils).length,10);
 for(const profil of Object.values(manifeste.profils))assert.ok(fs.existsSync(path.join(dossier,profil.fichier)),profil.fichier);
 assert.equal(manifeste.peaux.length,156);
 for(const peau of manifeste.peaux)assert.ok(fs.existsSync(path.join(dossier,'peaux',peau)),peau);
 assert.match(fs.readFileSync(path.join(dossier,'ATTRIBUTION-JOUEURS.md'),'utf8'),/CC0/);
 const gd=fs.readFileSync(path.join(root,'native/godot/match_joueur_v5.gd'),'utf8');
 for(const teinte of ['pale','claire','mate','olive','metisse','foncee','ebene'])assert.match(gd,new RegExp('"'+teinte+'"'));
 assert.match(fs.readFileSync(path.join(root,'scripts/build-godot-prototype.py'),'utf8'),/dist\/match3d\/assets\/joueurs/);
});
test('Joueurs v5 dans le match 3D',{skip:!process.env.CD_GODOT_EXE&&'Godot SDK required'},()=>{
 const project=process.env.CD_MATCH_PROJECT||path.join(root,'native/godot');
 const run=spawnSync(process.env.CD_GODOT_EXE,['--headless','--audio-driver','Dummy','--path',project,'--script',path.resolve(__dirname,'godot-match-joueurs-v5.gd')],{encoding:'utf8',windowsHide:true,timeout:120000});
 const output=(run.stdout||'')+(run.stderr||'');console.log(output);
 assert.equal(run.status,0,output);assert.doesNotMatch(output,/SCRIPT ERROR|Parse Error/);
 assert.match(output,/MATCH_JOUEURS_V5_CHECKS \d+ failures=0/);
});
