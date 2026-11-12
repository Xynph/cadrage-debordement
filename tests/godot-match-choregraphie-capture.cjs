'use strict';
// Capture de contrôle du chorégraphe (outil manuel ; sans CD_CHOREGRAPHIE_CAPTURE il ne fait rien).
// Joue dans la vue 3D, à vitesse réelle, un temps fort par type du jeu d'entrées
// (tests/fixtures/match-choregraphe-tranche2.json) et écrit une image par 1/30 s.
//
//   CD_GODOT_EXE                 exécutable Godot 4.7.2
//   CD_CHOREGRAPHIE_CAPTURE      dossier absolu des images (img-00001.jpg…) et de report.json — requis
//   CD_CHOREGRAPHIE_SOURCES      sources à jouer, séparées par « ; » (défaut : une par type et remise en jeu)
//   CD_MATCH_ANIMATIONS          bibliothèque Mixamo hors dépôt (facultative)
// Sous Linux sans écran : xvfb-run -a -s "-screen 0 1280x720x24" node tests/godot-match-choregraphie-capture.cjs
const fs=require('node:fs'),path=require('node:path'),os=require('node:os');
const {spawnSync}=require('node:child_process');
const C=require('../native/engine/match-choregraphe.cjs');
const dossier=process.env.CD_CHOREGRAPHIE_CAPTURE;
if(!dossier){console.log('SKIP godot-match-choregraphie-capture : outil manuel (CD_CHOREGRAPHIE_CAPTURE absent).');process.exit(0);}
const godot=process.env.CD_GODOT_EXE;
if(!godot||!fs.existsSync(godot)){console.error('CD_GODOT_EXE doit désigner l’exécutable Godot.');process.exit(2);}
fs.mkdirSync(dossier,{recursive:true});
const TITRES={essai_jeu_courant:'Essai',franchissement:'Franchissement plaqué',jeu_au_pied:'Jeu au pied et chasse',ballon_porte:'Ballon porté',
 penalite_au_but:'Pénalité au but',penalite_en_touche:'Pénaltouche',penalite_a_la_main:'Pénalité jouée à la main',faute_de_main:'Faute de main',contestation_au_sol:'Contestation au sol'};
const OUVERTURES={melee:'depuis la mêlée',touche:'depuis la touche',envoi:'depuis le coup d’envoi',jeu:'en jeu courant',penalite:'sur pénalité'};
// Sources : jeux d'entrées des tranches 2 à 4 (CD_CHOREGRAPHIE_SOURCES choisit parmi eux, dans l'ordre donné).
const toutes=['tranche2','tranche3','tranche4'].flatMap(n=>JSON.parse(fs.readFileSync(path.join(__dirname,'fixtures','match-choregraphe-'+n+'.json'),'utf8')));
const voulues=(process.env.CD_CHOREGRAPHIE_SOURCES||'').split(';').map(s=>s.trim()).filter(Boolean);
const vus=new Set(),cas=[];
for(const f of toutes){
 const cle=f.entree.type+'|'+f.entree.ouverture.k;
 if(voulues.length?!voulues.includes(f.source):vus.has(cle))continue;
 vus.add(cle);
 cas.push({titre:TITRES[f.entree.type]+' '+OUVERTURES[f.entree.ouverture.k],source:f.source,entree:f.entree,pistes:C.composer(f.entree)});
}
if(voulues.length)cas.sort((a,b)=>voulues.indexOf(a.source)-voulues.indexOf(b.source));
const travail=fs.mkdtempSync(path.join(os.tmpdir(),'cd-choregraphie-capture-'));
try{
 const fichier=path.join(travail,'pistes.json');
 fs.writeFileSync(fichier,JSON.stringify({cas}));
 const env={...process.env,CD_CHOREGRAPHIE_PISTES:fichier,CD_GODOT_SELF_TEST:'0'};
 const run=spawnSync(godot,['--fixed-fps','30','--windowed','--resolution','1280x720','--path',path.resolve(__dirname,'../native/godot'),'--script',path.resolve(__dirname,'godot-match-choregraphie-capture.gd')],{env,encoding:'utf8',timeout:7200000,maxBuffer:64*1024*1024});
 const sortie=(run.stdout||'')+(run.stderr||'');
 fs.writeFileSync(path.join(dossier,'godot.log'),sortie);
 if(run.status!==0){console.error(sortie.slice(-4000));process.exit(run.status||1);}
 const rapport=JSON.parse(fs.readFileSync(path.join(dossier,'report.json'),'utf8'));
 for(const s of rapport.sequences)console.log(`${s.titre} : images ${s.premiere} à ${s.derniere} (${s.duree} s de pistes)`);
}finally{fs.rmSync(travail,{recursive:true,force:true})}
