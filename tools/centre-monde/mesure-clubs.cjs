'use strict';
// Mesure : pour chaque club jouable du Monde, nouvelle carrière puis lecture du Centre (parcours ouverts ou non, motif).
// Sortie JSON : temp/resultats-8e/centre/mesure-clubs.json (chemin passé en argument).
const path=require('node:path'),fs=require('node:fs');
const H=require(path.join(__dirname,'../../tests/helpers/carriere-monde.cjs'));
const sortie=process.argv[2];const ref=require('./clubs-monde.json');
const lignes=[];
for(const id of ref.playable){
 const jeu=H.ouvrir({hebdomadaire:true,simulation:true,testVm:true});
 try{const m=H.creer(jeu,id),ap=m.clubLife.academyPathways,c=ref.clubs[id];
  lignes.push({id,nom:c.name,championnat:c.league,pays:c.country,caisse:ap.cash,jeunes:ap.players.length,places:ap.places,ouverts:ap.available,activation:ap.activationAvailable,motif:ap.reason||null});}
 catch(e){lignes.push({id,erreur:String(e.message).slice(0,200)});}
 finally{jeu.fermer();}
}
fs.writeFileSync(sortie,JSON.stringify(lignes,null,1));
const fermes=lignes.filter(l=>l.ouverts===false).length;
console.log('clubs jouables',lignes.length,'parcours fermés',fermes,'ouverts',lignes.filter(l=>l.ouverts===true).length,'erreurs',lignes.filter(l=>l.erreur).length);
