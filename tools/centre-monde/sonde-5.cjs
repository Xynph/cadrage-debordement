'use strict';
// Identifiants des jeunes : un centre invité n° i fabrique des joueurs « youth-(100+i)-… » ; en Monde les clubs 100 à 115 existent.
const path=require('node:path');
const H=require(path.join(__dirname,'../../tests/helpers/carriere-monde.cjs'));
const club=Number(process.argv[2]||102);
const jeu=H.ouvrir({hebdomadaire:true,simulation:true,testVm:true});H.creer(jeu,club);
const lire=s=>JSON.parse(jeu.bridge.vm.run('JSON.stringify('+s+')'));
console.log(JSON.stringify(lire(`(()=>{const ids=new Set([...S.development.academy,...S.aiRoster.academies.flatMap(a=>a.players)].map(p=>p.id));const coll=[];for(let i=0;i<44;i++)for(let slot=0;slot<15;slot++){const p=academyPlayer(100+i,slot,S.season,slot);if(ids.has(p.id))coll.push(p.id)}return {exemplesCentre:S.development.academy.slice(0,2).map(p=>p.id),collisions:coll.length,premiers:coll.slice(0,5)}})()`)));
jeu.fermer();
