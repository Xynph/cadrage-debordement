'use strict';
// Rubrique facultative `boards` des packs d'identités : noms des présidents et
// des directeurs sportifs des clubs, par identifiant stable (pres-<club>,
// ds-<club>). Le jeu de base leur donne un nom inventé (générateur de noms du
// staff) ; la sauvegarde ne reçoit jamais les noms du pack : ils sont appliqués
// à l'affichage, comme ceux des joueurs, du staff, des clubs et de la presse.
// Les entraîneurs viennent du staff : leurs vrais noms passent par la rubrique
// `staff` existante (identifiants staff:<club>:<empreinte>).
// Les traits des directions restent ceux du jeu ; une version future de la
// rubrique pourra les préciser (champ refusé tant qu'il n'est pas défini).
const completion=require('./staff-completion.cjs');

const ID=/^(pres|ds)-(0|[1-9]\d{0,2})$/;
const MAX_NAME=80;
const object=v=>v!==null&&typeof v==='object'&&!Array.isArray(v);
function ensure(ok,message){if(!ok)throw Error('Pack refusé : '+message);}

// Texte brut : ni balise, ni balisage, ni adresse.
function label(value,what){
 ensure(typeof value==='string'&&value===value.trim()&&value.length>0&&value.length<=MAX_NAME
  &&!/[<>[\]{}\\\x00-\x1f\x7f]/u.test(value)&&!/[a-z][a-z0-9+.-]*:\/\/|www\./iu.test(value),'directions : '+what+' invalide.');
 return value.normalize('NFC');
}
function clubOf(id,database){
 const m=ID.exec(id);if(!m)return null;
 const clubId=Number(m[2]);return database.clubs.find(c=>c.id===clubId)||null;
}
// Nom inventé du jeu de base : même formule que le moteur (club-directions.cjs).
function baseName(id,database){
 const club=clubOf(id,database);if(!club)return null;
 return completion.profile('board:'+id,{function:'teamManager',country:club.country||'FR'}).name;
}
// Manifeste importé : `boards`, liste d'objets { id, name } (exactement ces deux champs).
function ingest(raw,database){
 ensure(Array.isArray(raw)&&raw.length>0&&raw.length<=2*database.clubs.length,'directions : liste invalide.');
 const out=Object.create(null);
 for(const item of raw){
  ensure(object(item)&&Object.keys(item).length===2&&Object.hasOwn(item,'id')&&Object.hasOwn(item,'name'),'directions : champ non autorisé.');
  ensure(typeof item.id==='string'&&!!clubOf(item.id,database)&&!Object.hasOwn(out,item.id),'directions : identifiant inconnu ou dupliqué.');
  out[item.id]={name:label(item.name,'nom')};
 }
 return {boards:{...out},counts:{boards:Object.keys(out).length}};
}
function validateInstalled(boards,database){
 ensure(object(boards)&&Object.keys(boards).length>0,'directions installées invalides.');
 for(const [id,item]of Object.entries(boards)){
  ensure(!!clubOf(id,database)&&object(item)&&Object.keys(item).length===1,'direction installée inconnue.');label(item.name,'nom installé');
 }
 return boards;
}
// Paires (nom de base, nom du pack) pour la projection d'affichage.
function replacements(boards,database){
 if(!boards)return [];
 return Object.entries(boards).map(([id,item])=>[baseName(id,database),item.name]).filter(([from])=>from);
}
module.exports={ingest,validateInstalled,replacements,baseName,ID,MAX_NAME};
