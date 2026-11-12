'use strict';
// Film de contrôle de l'entracte 2D, dans la vraie interface et avec le vrai moteur, à vitesse
// réelle (Godot --write-movie, 30 images/s, 1280×720). Outil manuel : sans CD_ENTRACTE_2D_FILM,
// il ne fait rien (la CI le saute). Sous Linux sans écran, lancer dans xvfb-run.
//
//   CD_GODOT_EXE           exécutable Godot 4.7.2 (ou CD_GODOT_EXECUTABLE)
//   CD_ENTRACTE_2D_FILM    fichier .avi absolu du film (MJPEG ; ffmpeg le convertit ensuite)
//   CD_ENTRACTE_2D_PNG     capture PNG au milieu du premier entracte (facultatif)
//   CD_ENTRACTE_2D_NOMBRE  entractes filmés (défaut 2)
//   CD_ENTRACTE_2D_SEED    graine du moteur (défaut 7)
const fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const {spawnSync}=require('node:child_process');
const film=process.env.CD_ENTRACTE_2D_FILM;
if(!film){console.log('SKIP godot-match-entracte-2d-capture : outil manuel (CD_ENTRACTE_2D_FILM absent).');process.exit(0);}
const godot=process.env.CD_GODOT_EXECUTABLE||process.env.CD_GODOT_EXE;
if(!godot||!fs.existsSync(godot)){console.error('CD_GODOT_EXE doit désigner l’exécutable Godot.');process.exit(2);}
if(!path.isAbsolute(film)){console.error('CD_ENTRACTE_2D_FILM doit être absolu.');process.exit(2);}
const seed=/^\d+$/.test(process.env.CD_ENTRACTE_2D_SEED||'')?process.env.CD_ENTRACTE_2D_SEED:'7';
const work=fs.mkdtempSync(path.join(os.tmpdir(),'cd-entracte-2d-'));
const {context}=require('./harness.cjs');
const source=context();
source.run('start(0);beginMatch()');
const save=path.join(work,'live.json');
fs.writeFileSync(save,source.run('JSON.stringify(createSaveDocument())'));
const env={...process.env,CD_GODOT_SELF_TEST:'0',CD_NODE_EXECUTABLE:process.execPath,CD_GODOT_DATA_DIR:path.join(work,'PrototypeGodot'),CD_GODOT_SEED:seed,CD_ENTRACTE_2D_SAVE:save};
for(const nom of ['CD_MATCH_TEMPS_FORTS','CD_MATCH_TEMPS_FORTS_NIVEAU','CD_MATCH_TEMPS_FORTS_HORLOGE','CD_MATCH_TEMPS_FORTS_VITESSE','CD_MATCH_TEMPS_FORTS_ENTRACTE'])delete env[nom];
const result=spawnSync(godot,['--rendering-method','gl_compatibility','--resolution','1280x720','--fixed-fps','30','--write-movie',film,'--path',path.resolve(__dirname,'../native/godot'),'--script',path.resolve(__dirname,'godot-match-entracte-2d-capture.gd')],{env,encoding:'utf8',timeout:3600000,maxBuffer:64*1024*1024});
const output=(result.stdout||'')+(result.stderr||'');
fs.rmSync(work,{recursive:true,force:true});
console.log(output.split('\n').filter(l=>/FILM|CAPTURE|ERROR|SCRIPT/.test(l)).join('\n'));
if(result.error)throw result.error;
process.exit(result.status||0);
