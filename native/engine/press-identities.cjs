'use strict';
// Rubrique facultative `press` des packs d'identités : noms des journalistes
// et de leurs rédactions, par identifiant stable de la banque de presse.
// La sauvegarde ne reçoit jamais ces noms : ils sont appliqués à l'affichage,
// comme ceux des joueurs, des staffs et des clubs.
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');

const JOURNALIST_ID=/^(presse|fiction)-\d{1,2}$/;
const OUTLET_ID=/^redaction-\d{1,2}$/;
const MAX_NAME=80;
const object=v=>v!==null&&typeof v==='object'&&!Array.isArray(v);
function ensure(ok,message){if(!ok)throw Error('Pack refusé : '+message);}
function only(value,allowed,message){ensure(object(value)&&Object.keys(value).every(k=>allowed.includes(k)),message);}

// Un nom de presse reste du texte brut : ni balise, ni balisage BBCode, ni
// adresse. Le même contrôle sert à l'import et à la relecture du pack installé.
function label(value,what){
 ensure(typeof value==='string'&&value===value.trim()&&value.length>0&&value.length<=MAX_NAME
  &&!/[<>[\]{}\\\x00-\x1f\x7f]/u.test(value)&&!/[a-z][a-z0-9+.-]*:\/\/|www\./iu.test(value),'presse : '+what+' invalide.');
 return value.normalize('NFC');
}

// Catalogue de base : identifiants stables, noms et rédaction de chaque journaliste.
function catalogue(journalists){
 ensure(Array.isArray(journalists)&&journalists.length>0,'presse : banque de journalistes absente.');
 const people=new Map(),outlets=new Map();
 for(const j of journalists){
  ensure(object(j)&&JOURNALIST_ID.test(j.id)&&!people.has(j.id)&&OUTLET_ID.test(j.outletId)&&typeof j.name==='string'&&typeof j.outlet==='string','presse : banque de journalistes incohérente.');
  ensure(!outlets.has(j.outletId)||outlets.get(j.outletId)===j.outlet,'presse : rédaction de base incohérente.');
  people.set(j.id,Object.freeze({name:j.name,outlet:j.outlet,outletId:j.outletId}));outlets.set(j.outletId,j.outlet);
 }
 ensure(new Set(outlets.values()).size===outlets.size,'presse : rédaction de base dupliquée.');
 return Object.freeze({journalists:people,outlets});
}

// La banque est un module du moteur ; elle est évaluée dans un contexte isolé
// pour ne rien installer dans le processus hôte.
function load(distDir){
 const dir=distDir?path.resolve(distDir):fs.existsSync(path.join(__dirname,'core'))?path.join(__dirname,'core'):path.resolve(__dirname,'../../dist');
 const file=path.join(dir,'press-question-bank.js'),sandbox={module:{exports:{}}};
 vm.runInNewContext(fs.readFileSync(file,'utf8'),sandbox,{filename:file});
 return catalogue(JSON.parse(JSON.stringify(sandbox.module.exports.journalists)));
}
let fallback=null;
function defaultCatalogue(){return fallback||(fallback=load());}

// Manifeste importé : `press.journalists` et `press.outlets`, chacun facultatif,
// au moins une entrée au total. Identifiants inconnus ou dupliqués refusés.
function ingest(raw,cat){
 only(raw,['journalists','outlets'],'presse : champ non autorisé.');
 const out={journalists:Object.create(null),outlets:Object.create(null)};
 const groups=[['journalists',cat.journalists,'journaliste'],['outlets',cat.outlets,'rédaction']];
 for(const [key,known,what]of groups){
  if(raw[key]===undefined)continue;
  ensure(Array.isArray(raw[key])&&raw[key].length<=known.size,'presse : liste '+key+' invalide.');
  for(const item of raw[key]){
   only(item,['id','name'],'presse : champ non autorisé.');
   ensure(typeof item.id==='string'&&known.has(item.id)&&!Object.hasOwn(out[key],item.id),'presse : '+what+' inconnu(e) ou dupliqué(e).');
   out[key][item.id]={name:label(item.name,'nom de '+what)};
  }
 }
 const counts={journalists:Object.keys(out.journalists).length,outlets:Object.keys(out.outlets).length};
 ensure(counts.journalists+counts.outlets>0,'presse : rubrique vide.');
 return {press:{journalists:{...out.journalists},outlets:{...out.outlets}},counts};
}

// Pack déjà installé : même contrôle, sur la forme normalisée.
function validateInstalled(press,cat){
 ensure(object(press)&&Object.keys(press).length===2&&object(press.journalists)&&object(press.outlets),'presse installée invalide.');
 for(const [key,known]of [['journalists',cat.journalists],['outlets',cat.outlets]])for(const [id,item]of Object.entries(press[key])){
  ensure(known.has(id)&&object(item)&&Object.keys(item).length===1,'presse installée inconnue.');label(item.name,'nom installé');
 }
 ensure(Object.keys(press.journalists).length+Object.keys(press.outlets).length>0,'presse installée vide.');
 return press;
}

// Paires (nom de base, nom du pack) pour la projection d'affichage.
function replacements(press,cat){
 if(!press)return [];
 const pairs=[];
 for(const [id,item]of Object.entries(press.journalists))if(cat.journalists.has(id))pairs.push([cat.journalists.get(id).name,item.name]);
 for(const [id,item]of Object.entries(press.outlets))if(cat.outlets.has(id))pairs.push([cat.outlets.get(id),item.name]);
 return pairs;
}

module.exports={catalogue,load,defaultCatalogue,ingest,validateInstalled,replacements,MAX_NAME};
