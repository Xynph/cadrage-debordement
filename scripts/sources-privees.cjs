'use strict';
// Sources à identités réelles (registre des postes et contrats vérifiés, références du staff) :
// elles vivent dans le dépôt privé Xynph/rugby-reel-donnees, plus dans le dépôt public.
// Un compilateur les cherche dans le dépôt (copie du dépôt privé posée par-dessus), puis dans le
// dossier désigné par CD_SOURCES_PRIVEES (clone du dépôt privé, lu sans jamais y écrire).
// Sans elles, il ne recompile pas : il vérifie l'empreinte du fichier compilé publié
// (data/empreintes-compilees.json) et l'annonce. Aucun repli silencieux.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const ROOT=path.resolve(__dirname,'..'),LEDGER=path.join(ROOT,'data/empreintes-compilees.json');
const lf=buffer=>buffer.toString('utf8').replace(/\r\n/g,'\n');
const sha=text=>crypto.createHash('sha256').update(text).digest('hex');
const digestOf=file=>sha(lf(fs.readFileSync(file)));
const rel=file=>path.relative(ROOT,file).split(path.sep).join('/');

// Racines où chercher une source privée, dans l'ordre.
function roots(env=process.env){
 const list=[ROOT];
 if(env.CD_SOURCES_PRIVEES)list.push(path.resolve(env.CD_SOURCES_PRIVEES));
 return list;
}
// Chemin absolu de la source privée, ou null si aucune racine ne la porte.
function locate(relative,env=process.env){
 for(const base of roots(env)){const file=path.join(base,relative);if(fs.statSync(file,{throwIfNoEntry:false})?.isFile())return file;}
 return null;
}
// Toutes les sources présentes dans une même racine (jamais un mélange de deux copies), ou null.
function locateAll(relatives,env=process.env){
 for(const base of roots(env)){
  const files=relatives.map(r=>path.join(base,r));
  if(files.every(f=>fs.statSync(f,{throwIfNoEntry:false})?.isFile()))return Object.fromEntries(relatives.map((r,i)=>[r,files[i]]));
 }
 return null;
}
function readLedger(){return JSON.parse(fs.readFileSync(LEDGER,'utf8'));}
function absentMessage(target){return 'Sources privées absentes, recompilation non contrôlée : '+target+' vérifié par son empreinte publiée (data/empreintes-compilees.json).';}
function missingError(target){return Error('Sources privées absentes : impossible de recompiler '+target+'. Poser le dépôt privé rugby-reel-donnees par-dessus le dépôt, ou désigner son clone par CD_SOURCES_PRIVEES.');}
// Vérifie qu'un fichier compilé est exactement celui dont l'empreinte est publiée.
// file : autre copie à contrôler (tests) ; par défaut le fichier publié du dépôt.
function verifyCompiled(target,file=path.join(ROOT,target)){
 const entry=readLedger().compiled[target];
 if(!entry)throw Error('Empreinte publiée absente : '+target);
 const actual=digestOf(file);
 if(actual!==entry.sha256)throw Error('Fichier compilé modifié sans ses sources privées : '+target+' (empreinte '+actual.slice(0,12)+', attendue '+entry.sha256.slice(0,12)+').');
 return entry;
}
// Après une compilation avec les sources : l'empreinte publiée doit décrire le fichier et ses sources.
// En contrôle (--check), une empreinte périmée est une erreur ; sinon elle est réécrite.
function recordCompiled(target,sources,check){
 const ledger=readLedger(),entry={sha256:digestOf(path.join(ROOT,target)),sources:Object.fromEntries(Object.entries(sources).sort(([a],[b])=>a<b?-1:a>b?1:0).map(([r,f])=>[r,digestOf(f)]))};
 const before=JSON.stringify(ledger.compiled[target]);
 if(before===JSON.stringify(entry))return entry;
 if(check)throw Error('Empreinte publiée périmée : '+target+'. Relancer la compilation avec les sources privées.');
 ledger.compiled[target]=entry;
 ledger.compiled=Object.fromEntries(Object.entries(ledger.compiled).sort(([a],[b])=>a<b?-1:a>b?1:0));
 fs.writeFileSync(LEDGER,JSON.stringify(ledger,null,1)+'\n');
 return entry;
}
module.exports={ROOT,LEDGER,roots,locate,locateAll,readLedger,verifyCompiled,recordCompiled,absentMessage,missingError,digestOf,rel};
