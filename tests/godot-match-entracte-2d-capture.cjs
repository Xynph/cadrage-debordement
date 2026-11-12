'use strict';
// Film de contrôle de l'entracte 2D, dans la vraie interface et avec le vrai moteur, à vitesse
// réelle (--fixed-fps 30, 1280×720). Outil manuel : sans CD_ENTRACTE_2D_FILM,
// il ne fait rien (la CI le saute). Sous Linux sans écran, lancer dans xvfb-run.
//
//   CD_GODOT_EXE           exécutable Godot 4.7.2 (ou CD_GODOT_EXECUTABLE)
//   CD_ENTRACTE_2D_FILM    fichier .mp4 absolu du film (images de la vue racine montées par ffmpeg)
//   CD_ENTRACTE_2D_PNG     capture PNG à 5 s du dernier entracte filmé (facultatif)
//   CD_ENTRACTE_2D_NOMBRE  entractes filmés (défaut 2)
//   CD_ENTRACTE_2D_SEED    graine du moteur (défaut 7)
//   CD_ENTRACTE_2D_VUES    mises en page enchaînées (« staff,mix,tele », une toutes les 4 s)
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
// Le projet s'ouvre en plein écran 1440×900 et --write-movie filme la fenêtre (image rognée) :
// on enregistre la vue racine image par image (1280×720), puis ffmpeg monte le film MP4.
const images=path.join(work,'images');fs.mkdirSync(images);env.CD_ENTRACTE_2D_IMAGES=images;
const result=spawnSync(godot,['--rendering-method','gl_compatibility','--windowed','--resolution','1280x720','--fixed-fps','30','--path',path.resolve(__dirname,'../native/godot'),'--script',path.resolve(__dirname,'godot-match-entracte-2d-capture.gd')],{env,encoding:'utf8',timeout:3600000,maxBuffer:64*1024*1024});
const output=(result.stdout||'')+(result.stderr||'');
if(result.status===0){const f=spawnSync('ffmpeg',['-y','-v','error','-framerate','30','-i',path.join(images,'%05d.jpg'),'-c:v','libx264','-crf','20','-preset','fast','-pix_fmt','yuv420p','-movflags','+faststart',film],{encoding:'utf8'});if(f.status!==0)console.error('ffmpeg : '+(f.stderr||f.error));}
fs.rmSync(work,{recursive:true,force:true});
console.log(output.split('\n').filter(l=>/FILM|CAPTURE|ERROR|SCRIPT/.test(l)).join('\n'));
if(result.error)throw result.error;
process.exit(result.status||0);
