'use strict';
// Capture d'un match en temps forts dans la vraie interface, avec le vrai moteur.
// Outil manuel : sans CD_MATCH_TEMPS_FORTS_PROOF il ne fait rien (la CI le saute).
//
//   CD_GODOT_EXE                  exécutable Godot 4.7.2 (ou CD_GODOT_EXECUTABLE)
//   CD_MATCH_TEMPS_FORTS_PROOF    dossier absolu des images (tf-00001.jpg…) et de report.json — requis
//   CD_MATCH_TEMPS_FORTS_NIVEAU   aucun | resume | cles | etendus | dynamique (défaut) | integral
//   CD_MATCH_TEMPS_FORTS_HORLOGE  lente | normale (défaut) | rapide | eclair : horloge de l'écran intermédiaire
//   CD_MATCH_TEMPS_FORTS_VITESSE  vitesse des temps forts, 0.5 à 4 (défaut 1)
//   CD_MATCH_TEMPS_FORTS_SIZE     "1280x720" par défaut
//   CD_MATCH_TEMPS_FORTS_EVERY    une image enregistrée toutes les N images affichées à 30 images/s (défaut 5, soit 6 par seconde)
//   CD_MATCH_TEMPS_FORTS_MAX      nombre maximal d'images (défaut 2400)
//   CD_MATCH_TEMPS_FORTS_QUALITE  qualité JPEG de 30 à 95 (défaut 72)
//   CD_MATCH_TEMPS_FORTS_GEL      secondes sans progrès avant d'arrêter avec un diagnostic « fige » dans report.json (défaut 120)
//   CD_MATCH_TEMPS_FORTS_MINUTES  arrêt après cette minute de match (défaut 0 : match entier)
//   CD_MATCH_TEMPS_FORTS_CLUB     club dirigé dans le harnais (défaut 0)
//   CD_MATCH_TEMPS_FORTS_SEED     graine du moteur, entier (défaut 7) : même graine, même match
//   CD_MATCH_TEMPS_FORTS_GODOT_ARGS  arguments Godot supplémentaires, séparés par des espaces
//   CD_MATCH_GESTES=1             transmis tel quel à la vue 3D quand elle sait jouer les gestes
const fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const {spawnSync}=require('node:child_process');
const proof=process.env.CD_MATCH_TEMPS_FORTS_PROOF;
if(!proof){console.log('SKIP godot-match-temps-forts-capture : outil manuel (CD_MATCH_TEMPS_FORTS_PROOF absent).');process.exit(0);}
const godot=process.env.CD_GODOT_EXECUTABLE||process.env.CD_GODOT_EXE;
if(!godot||!fs.existsSync(godot)){console.error('CD_GODOT_EXE doit désigner l’exécutable Godot.');process.exit(2);}
if(!path.isAbsolute(proof)){console.error('CD_MATCH_TEMPS_FORTS_PROOF doit être un dossier absolu.');process.exit(2);}
fs.mkdirSync(proof,{recursive:true});
const size=/^\d+x\d+$/.test(process.env.CD_MATCH_TEMPS_FORTS_SIZE||'')?process.env.CD_MATCH_TEMPS_FORTS_SIZE:'1280x720';
const club=Number(process.env.CD_MATCH_TEMPS_FORTS_CLUB||0);
if(!Number.isInteger(club)||club<0){console.error('CD_MATCH_TEMPS_FORTS_CLUB invalide.');process.exit(2);}
const seed=process.env.CD_MATCH_TEMPS_FORTS_SEED||'7';
if(!/^(0|[1-9]\d*)$/.test(seed)){console.error('CD_MATCH_TEMPS_FORTS_SEED invalide.');process.exit(2);}
const work=fs.mkdtempSync(path.join(os.tmpdir(),'cd-temps-forts-capture-'));
const {context}=require('./harness.cjs');
const source=context();
source.run(`start(${club});beginMatch()`);
const save=path.join(work,'live.json');
fs.writeFileSync(save,source.run('JSON.stringify(createSaveDocument())'));
const extra=(process.env.CD_MATCH_TEMPS_FORTS_GODOT_ARGS||'').split(/\s+/).filter(Boolean);
const env={...process.env,CD_GODOT_SELF_TEST:'0',CD_NODE_EXECUTABLE:process.execPath,CD_GODOT_DATA_DIR:path.join(work,'PrototypeGodot'),
 CD_GODOT_SEED:seed,CD_MATCH_TEMPS_FORTS:'1',CD_MATCH_TEMPS_FORTS_NIVEAU:process.env.CD_MATCH_TEMPS_FORTS_NIVEAU||'dynamique',CD_MATCH_TEMPS_FORTS_SIZE:size,CD_MATCH_TEMPS_FORTS_SAVE:save};
const started=Date.now();
const result=spawnSync(godot,[...extra,'--windowed','--resolution',size,'--max-fps','30','--path',path.resolve(__dirname,'../native/godot'),'--script',path.resolve(__dirname,'godot-match-temps-forts-capture.gd')],{env,encoding:'utf8',windowsHide:false,timeout:3600000,maxBuffer:64*1024*1024});
const output=(result.stdout||'')+(result.stderr||'');
fs.writeFileSync(path.join(proof,'godot.log'),output);
fs.rmSync(work,{recursive:true,force:true});
if(result.error){console.error(output);throw result.error;}
const reportPath=path.join(proof,'report.json');
if(result.status!==0){
 console.error(output);
 if(result.status===3&&fs.existsSync(reportPath))console.error('Direct figé : '+JSON.stringify(JSON.parse(fs.readFileSync(reportPath,'utf8')).fige));
 console.error('Capture interrompue (code '+result.status+'). Journal : '+path.join(proof,'godot.log'));process.exit(result.status||1);
}
const report=JSON.parse(fs.readFileSync(reportPath,'utf8'));
console.log(`Capture terminée en ${Math.round((Date.now()-started)/1000)} s : ${report.images.length} images de ${report.image_size.join('×')} (${Math.round(report.octets_par_image/1024)} Ko en moyenne, ${Math.round(report.octets_image_la_plus_lourde/1024)} Ko au plus${report.resized?', redimensionnées':''}), ${report.temps_forts} temps forts, ${report.echeances} échéance(s), score ${report.score.join(' – ')}, dossier ${proof}`);
