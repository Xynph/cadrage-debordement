'use strict';
// Extraction reproductible des seules illustrations approuvées ; jamais un écran aplati.
// node scripts/prepare-immersive08-art.cjs <direction-b> <module-sharp>
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const source=path.resolve(process.argv[2]||''),sharp=require(process.argv[3]||'sharp');
const target=path.resolve(__dirname,'../native/godot/art/immersive08');
const recipes=[
 ['brand','01-bureau.png',[5,4,220,96]],
 ['office-hero','01-bureau.png',[798,148,385,353]],
 ['forest','01-bureau.png',[0,795,230,146]],
 ['approved-club-crest','01-bureau.png',[48,119,145,169]],
 ['mail-staff','02-reception.png',[1320,148,340,178]],
 ['mail-trainer','02-reception.png',[489,214,57,58]],
 ['mail-medical','02-reception.png',[489,295,57,58]],
 ['squad-portrait','03-effectif.png',[1205,146,158,228]],
 ['player-hero','04-fiche-joueur.png',[260,50,315,288]],
 ['tactics-briefing','05-tactique.png',[250,188,602,125]],
 ['training-session','06-entrainement.png',[247,678,644,253]],
 ['training-coach','06-entrainement.png',[1279,724,55,52]],
 ['scouting','07-recrutement.png',[240,143,391,108]],
 ['recruit-profile','07-recrutement.png',[1155,249,183,161]],
 ['stadium','08-club.png',[248,200,584,216]],
 ['club-forest','08-club.png',[946,49,716,86]],
 ['hospitality','09-finances.png',[1264,50,406,132]],
 ['trophy','10-competitions.png',[1208,49,462,176]],
 ['academy-training','11-formation.png',[912,49,407,174]],
 ['academy-player','11-formation.png',[1143,275,183,240]],
];
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
(async()=>{
 if(!fs.existsSync(path.join(source,'01-bureau.png')))throw new Error('Dossier direction-b explicite requis');
 fs.mkdirSync(target,{recursive:true});
 const assets=[];
 for(const [id,filename,crop] of recipes){
  const input=fs.readFileSync(path.join(source,filename)),[left,top,width,height]=crop;
  const {data,info}=await sharp(input).extract({left,top,width,height}).png({compressionLevel:9}).toBuffer({resolveWithObject:true});
  fs.writeFileSync(path.join(target,id+'.png'),data);
  assets.push({id,file:id+'.png',source:filename,source_sha256:hash(input),crop,width:info.width,height:info.height,bytes:data.length,sha256:hash(data),synthetic:true});
 }
 fs.writeFileSync(path.join(target,'manifest.json'),JSON.stringify({schema:'oval-immersive-art-v1',direction:'B approuvée',usage:'Illustrations fictives générées par IA, distinctes des contrôles natifs et des photos de packs privés',assets},null,2)+'\n');
 fs.writeFileSync(path.join(target,'PROVENANCE.txt'),'OVAL LEGACY 27 — ILLUSTRATIONS IMMERSIVES\n\nIllustrations originales générées par IA et approuvées par le propriétaire dans le chat de conception.\nExtraction de photographies décoratives : aucun écran complet ne sert d’interface.\nLes personnes et lieux représentés sont fictifs. Les photos/noms de packs privés restent prioritaires.\nLe manifeste conserve pour chaque extrait le fichier source, son SHA-256, le rectangle et l’empreinte de sortie.\nLes sources de conception sont conservées dans CD/output/oval-legacy-27/direction-b.\n');
 console.log(assets.length+' illustrations extraites ; '+assets.reduce((n,a)=>n+a.bytes,0)+' octets.');
})().catch(e=>{console.error(e.message);process.exitCode=1;});
