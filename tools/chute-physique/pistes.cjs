'use strict';
// Chute physique au plaquage (outil manuel) : écrit les pistes d'un temps fort du jeu d'entrées du
// chorégraphe pour tools/chute-physique/capture.gd.
// Usage : node tools/chute-physique/pistes.cjs <pistes.json> [source]
// (source par défaut : « graine 11, club 0, 40′ », franchissement depuis l'envoi, plaquage à 13,3 s).
const fs=require('node:fs'),path=require('node:path');
const C=require('../../native/engine/match-choregraphe.cjs');
const sortie=process.argv[2];
if(!sortie){console.error('chemin de sortie requis');process.exit(2);}
const source=process.argv[3]||'graine 11, club 0, 40′';
const toutes=['tranche2','tranche3','tranche4'].flatMap(n=>JSON.parse(fs.readFileSync(path.join(__dirname,'../../tests/fixtures/match-choregraphe-'+n+'.json'),'utf8')));
const f=toutes.find(x=>x.source===source);
if(!f){console.error('source introuvable : '+source);process.exit(1);}
fs.writeFileSync(sortie,JSON.stringify({cas:[{titre:source,entree:f.entree,pistes:C.composer(f.entree)}]}));
console.log('pistes écrites : '+sortie);
