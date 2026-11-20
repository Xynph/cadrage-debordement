'use strict';
// Textes générés (courrier, objectifs du conseil, libellés) : avec un pack qui renomme une compétition,
// le nom de base cité dans le texte est présenté avec le nom du pack ; la sauvegarde garde le texte de base.
// Pack et noms de compétitions entièrement inventés.
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),os=require('node:os');
const media=require('../native/engine/media-packs.cjs'),identities=require('../native/engine/competition-identities.cjs');
const {ouvrir,creer,jouer}=require('./helpers/carriere-monde.cjs');
const root=fs.mkdtempSync(path.join(os.tmpdir(),'cd-pack-competitions-'));

function archive(manifest){
 const items=[['pack.json',Buffer.from(JSON.stringify(manifest))]];let offset=0;const blocks=[],central=[];
 for(const [name,data]of items){const n=Buffer.from(name),l=Buffer.alloc(30),c=Buffer.alloc(46),crc=media.crc32(data);l.writeUInt32LE(0x04034b50);l.writeUInt16LE(20,4);l.writeUInt16LE(0x800,6);l.writeUInt32LE(crc,14);l.writeUInt32LE(data.length,18);l.writeUInt32LE(data.length,22);l.writeUInt16LE(n.length,26);c.writeUInt32LE(0x02014b50);c.writeUInt16LE(20,4);c.writeUInt16LE(20,6);c.writeUInt16LE(0x800,8);c.writeUInt32LE(crc,16);c.writeUInt32LE(data.length,20);c.writeUInt32LE(data.length,24);c.writeUInt16LE(n.length,28);c.writeUInt32LE(offset,42);blocks.push(l,n,data);central.push(c,n);offset+=30+n.length+data.length;}
 const cd=Buffer.concat(central),end=Buffer.alloc(22);end.writeUInt32LE(0x06054b50);end.writeUInt16LE(items.length,8);end.writeUInt16LE(items.length,10);end.writeUInt32LE(cd.length,12);end.writeUInt32LE(offset,16);
 const file=path.join(root,'pack.zip');fs.writeFileSync(file,Buffer.concat([...blocks,cd,end]));return file;
}

// 1. Table de remplacement : noms complets seulement, jamais les noms courts.
{
 const database={leagues:[{id:'champ',name:'Nom Registre Test'},{id:'elite',name:'Élite Registre Test'}]};
 const pairs=identities.replacements(database,{competitions:{champ:{name:'Ligue des Collines'},elite:{name:'Élite Registre Test'}}});
 const map=new Map(pairs);
 assert.equal(map.get('Nom Registre Test'),'Ligue des Collines','nom du registre remplacé');
 assert.ok(!map.has('Élite Registre Test'),'nom déjà identique : jamais remplacé par lui-même');
 assert.ok(![...map.keys()].some(k=>['Élite','Accession','Accession anglaise'].includes(k)),'noms courts jamais remplacés');
 assert.deepEqual(identities.replacements(database,null),[],'sans pack : aucun remplacement');
}

// 2. Parcours réel : carrière Monde, une rencontre jouée, pack appliqué à la carrière.
const jeu=ouvrir({dataDir:path.join(root,'profil'),seed:4242});
try{
 let m=creer(jeu,102);
 const leagueId=m.club.division||m.club.leagueId||'champ';
 m=jouer(jeu,m,1);
 const edition=m.meta.database?.id;assert.ok(edition,'édition de la carrière');
 const baseName=m.leagues.find(l=>l.id===leagueId)?.name;assert.ok(baseName,'nom de base de la compétition du club');
 const goalBefore=String(m.club.goal||m.calendar.find(x=>x.home?.id===m.club.id)?.home?.goal||'');
 const before=JSON.stringify(m);
 const packName='Ligue des Collines Test';
 const manifest={schema:'cd-identity-pack-v4',id:'competitions-test',name:'Compétitions de test',version:'1',databaseId:edition,rightsStatus:'test-local',clubs:[],players:[],staff:[],competitions:[{id:leagueId,name:packName}],assets:[]};
 const zip=archive(manifest),mode='world-champ';
 const preview=jeu.call('pack_inspect',{path:zip,mode}).packs.preview;
 jeu.call('pack_install',{path:zip,digest:preview.digest,mode});
 m=jeu.regler(jeu.call('pack_select',{id:preview.id,scope:'career',mode}));
 const shown=JSON.stringify({messages:m.messages,clubLife:m.clubLife,club:m.club,calendar:m.calendar,leagues:m.leagues});
 // Les noms de base cités avant le pack (registre de l'édition compris) ne s'affichent plus.
 assert.ok(before.includes(baseName),'avant le pack, le nom de base est bien cité');
 assert.ok(!shown.includes(baseName),'avec le pack, plus aucun texte ne cite le nom de base : '+baseName);
 assert.ok(shown.includes(packName),'le nom du pack est présenté');
 const goalAfter=String(m.club.goal||m.calendar.find(x=>x.home?.id===m.club.id)?.home?.goal||'');
 assert.ok(goalBefore&&goalBefore!==goalAfter&&goalAfter.includes(packName),'objectif du conseil avec le nom du pack : '+goalAfter);
 const quoting=(m.messages||[]).map(x=>typeof x==='string'?x:JSON.stringify(x)).filter(t=>String(t).includes(packName));
 assert.ok(quoting.length>0,'au moins un texte du courrier cite la compétition du pack');
 // La sauvegarde garde le texte de base : le pack ne s'écrit jamais dedans.
 assert.ok(!jeu.call('export').meta.exportText.includes(packName),'sauvegarde sans nom du pack');
 // Retour au jeu de base : les textes reprennent le nom de base.
 m=jeu.regler(jeu.call('pack_select',{id:'base',scope:'career',mode}));
 assert.ok(!JSON.stringify(m).includes(packName),'jeu de base : aucun nom du pack');
 console.log('Noms de compétitions du pack dans les textes générés PASS');
}finally{jeu.fermer();fs.rmSync(root,{recursive:true,force:true});}
