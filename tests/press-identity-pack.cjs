'use strict';
// Rubrique facultative `press` des packs d'identités : journalistes et
// rédactions par identifiant stable. Identités de test manifestement inventées.
const {settleClubMeetings}=require('./helpers/club-meetings.cjs');
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),os=require('node:os'),vm=require('node:vm');
const media=require('../native/engine/media-packs.cjs'),pressIds=require('../native/engine/press-identities.cjs');
const db=require('../dist/rugby-common-rosters.js'),staff=require('../native/engine/staff.cjs'),{createBridge,CORE_FILES}=require('../native/engine/worker.cjs');
const root=fs.mkdtempSync(path.join(os.tmpdir(),'cd-press-pack-'));let seq=0;

function archive(manifest){
 const items=[['pack.json',Buffer.from(JSON.stringify(manifest))]];let offset=0;const blocks=[],central=[];
 for(const [name,data]of items){const n=Buffer.from(name),l=Buffer.alloc(30),c=Buffer.alloc(46),crc=media.crc32(data);l.writeUInt32LE(0x04034b50);l.writeUInt16LE(20,4);l.writeUInt16LE(0x800,6);l.writeUInt32LE(crc,14);l.writeUInt32LE(data.length,18);l.writeUInt32LE(data.length,22);l.writeUInt16LE(n.length,26);c.writeUInt32LE(0x02014b50);c.writeUInt16LE(20,4);c.writeUInt16LE(20,6);c.writeUInt16LE(0x800,8);c.writeUInt32LE(crc,16);c.writeUInt32LE(data.length,20);c.writeUInt32LE(data.length,24);c.writeUInt16LE(n.length,28);c.writeUInt32LE(offset,42);blocks.push(l,n,data);central.push(c,n);offset+=30+n.length+data.length;}
 const cd=Buffer.concat(central),end=Buffer.alloc(22);end.writeUInt32LE(0x06054b50);end.writeUInt16LE(items.length,8);end.writeUInt16LE(items.length,10);end.writeUInt32LE(cd.length,12);end.writeUInt32LE(offset,16);
 const file=path.join(root,'pack-'+(++seq)+'.zip');fs.writeFileSync(file,Buffer.concat([...blocks,cd,end]));return file;
}

// 1. Catalogue de base : identifiants stables des journalistes et des rédactions.
const bank=pressIds.defaultCatalogue();
assert.equal(bank.journalists.size,78);assert.equal(bank.outlets.size,35);
for(let i=0;i<10;i++)assert.ok(bank.journalists.has('presse-'+i),'presse-'+i+' stable');
for(let i=0;i<10;i++)assert.ok(bank.outlets.has('redaction-'+i),'redaction-'+i+' stable');
const renamed=[...Array(10).keys()].map(i=>'presse-'+i),renamedOutlets=[...new Set(renamed.map(id=>bank.journalists.get(id).outletId))].sort();
assert.deepEqual(renamedOutlets,['redaction-0','redaction-1','redaction-2','redaction-3']);
// Le remplacement d'affichage se fait par nom : un nom de presse ne doit pas
// être aussi celui d'un club, d'un joueur ou d'un membre du staff de la base.
{const taken=new Set([...db.clubs.map(c=>c.name),...db.clubs.flatMap(c=>c.players.map(p=>p.name)),...staff.registry.clubs.flatMap(c=>c.members.map(p=>p.name))]);
 for(const j of bank.journalists.values())assert.ok(!taken.has(j.name),'nom de journaliste distinct');
 for(const o of bank.outlets.values())assert.ok(!taken.has(o),'nom de rédaction distinct');}

const pressRubric={
 journalists:renamed.map((id,i)=>({id,name:'Journaliste Test '+['Zéro','Un','Deux','Trois','Quatre','Cinq','Six','Sept','Huit','Neuf'][i]})),
 outlets:renamedOutlets.map((id,i)=>({id,name:'Rédaction Test '+(i+1)}))
};
const base={schema:'cd-identity-pack-v2',id:'presse-test',name:'Presse de réception',version:'1',databaseId:db.id,rightsStatus:'test-local',clubs:[],players:[],staff:[],assets:[]};
const withPress={...base,press:pressRubric};

// 2. Lecture du manifeste : rubrique acceptée, absente, refusée.
{const meta=media.analyse(archive(withPress),db).meta;
 assert.equal(meta.counts.journalists,10);assert.equal(meta.counts.outlets,4);assert.equal(meta.pressIdentityVersion,1);
 const plain=media.analyse(archive({...base,players:[{id:db.clubs[0].players[0].id,name:'Joueur Test'}]}),db).meta;
 assert.ok(!('pressIdentityVersion' in plain)&&!('journalists' in plain.counts)&&!('outlets' in plain.counts),'pack sans rubrique : métadonnées inchangées');
 const v1={...withPress,schema:'cd-identity-pack-v1'};delete v1.staff;
 assert.equal(media.analyse(archive(v1),db).meta.counts.journalists,10,'rubrique facultative aussi en v1');
 const onlyOutlet=media.analyse(archive({...base,press:{outlets:[{id:'redaction-2',name:'Rédaction Test Seule'}]}}),db).meta;
 assert.equal(onlyOutlet.counts.journalists,0);assert.equal(onlyOutlet.counts.outlets,1);
}
const ext=require('../native/engine/world-pacific-registry.cjs'),engineDir=path.join(__dirname,'../native/engine'),readJson=f=>{const file=path.join(engineDir,f);return fs.existsSync(file)?JSON.parse(fs.readFileSync(file,'utf8')):null;};
const pacific=ext.extendWorldRegistry(require('../native/engine/world-registry.json'),readJson('world-pacific-extension.json'));
const champ=ext.extendChampRegistry(ext.extendNationaleRegistry(ext.extendJapanRegistry(pacific,readJson('world-japan-extension.json')),readJson('world-nationale-extension.json')),readJson('world-champ-extension.json'));
// Schéma v4 (édition Monde + Champ) : rubrique facultative, pack v4 existant inchangé.
{const engine=path.join(__dirname,'../native/engine'),json=f=>{const file=path.join(engine,f);return fs.existsSync(file)?JSON.parse(fs.readFileSync(file,'utf8')):null;};
 const taken=new Set([...champ.clubs.map(c=>c.name),...champ.clubs.flatMap(c=>c.players.map(p=>p.name)),...staff.forDatabase(champ.id).registry.clubs.flatMap(c=>c.members.map(p=>p.name))]);
 for(const n of [...[...bank.journalists.values()].map(j=>j.name),...bank.outlets.values()])assert.ok(!taken.has(n),'nom de presse distinct dans l’édition Monde');
 const v4={schema:'cd-identity-pack-v4',id:'ligue-presse',name:'Presse Monde',version:'1',databaseId:champ.id,rightsStatus:'test-local',clubs:[],players:[],staff:[],competitions:[{id:'prem',name:'Championnat Test'}],assets:[]};
 const without=media.analyse(archive(v4),champ).meta;assert.equal(without.competitionIdentityVersion,1);assert.ok(!('pressIdentityVersion' in without)&&!('journalists' in without.counts));
 const withRubric=media.analyse(archive({...v4,press:pressRubric}),champ).meta;assert.equal(withRubric.pressIdentityVersion,1);assert.equal(withRubric.counts.journalists,10);assert.equal(withRubric.counts.competitions,1);
}
const refusals=[
 ['identifiant inconnu',p=>p.journalists.push({id:'presse-99',name:'Journaliste Test Inconnu'})],
 ['identifiant prototype',p=>p.journalists.push({id:'__proto__',name:'Journaliste Test Proto'})],
 ['rédaction inconnue',p=>p.outlets.push({id:'redaction-42',name:'Rédaction Test Inconnue'})],
 ['identifiant de joueur',p=>p.journalists.push({id:db.clubs[0].players[0].id,name:'Journaliste Test Joueur'})],
 ['doublon',p=>p.journalists.push({...p.journalists[0]})],
 ['HTML',p=>p.journalists[0].name='<b>Journaliste Test</b>'],
 ['lien',p=>p.journalists[0].name='https://example.org/journaliste'],
 ['lien sans schéma',p=>p.outlets[0].name='www.example.org'],
 ['BBCode',p=>p.outlets[0].name='[url=x]Rédaction Test[/url]'],
 ['trop long',p=>p.journalists[0].name='Journaliste Test '+'x'.repeat(pressIds.MAX_NAME)],
 ['vide',p=>p.journalists[0].name=''],
 ['espaces',p=>p.journalists[0].name=' Journaliste Test '],
 ['contrôle',p=>p.journalists[0].name='Journaliste\u0007Test'],
 ['non texte',p=>p.journalists[0].name=42],
 ['champ en trop',p=>p.journalists[0].source='https://example.org'],
 ['rubrique inconnue',p=>p.medias=[]],
 ['liste invalide',p=>p.journalists={}],
];
for(const [label,mutate]of refusals){const press=structuredClone(pressRubric);mutate(press);assert.throws(()=>media.analyse(archive({...base,press}),db),/^Error: Pack refusé : /,label);}
for(const press of [[],{},null,'Rédaction Test',{journalists:[],outlets:[]}])assert.throws(()=>media.analyse(archive({...base,press}),db),/^Error: Pack refusé : /,'rubrique invalide ou vide');
assert.throws(()=>media.analyse(archive({...base,presse:pressRubric}),db),/champ non autorisé/,'clé racine inconnue toujours refusée');

// 3. Parcours réel du worker. Une banque de test ajoute un ancien identifiant
// fictif pour exercer la migration des sauvegardes sans citer d'ancien nom.
const fnv=t=>{let h=2166136261;for(const o of unescape(encodeURIComponent(String(t)))){h^=o.charCodeAt(0);h=Math.imul(h,16777619);}return (h>>>0).toString(16).padStart(8,'0');};
const legacyId='ancien-journaliste-test',distDir=path.join(root,'dist');fs.mkdirSync(distDir);
const sourceDist=path.join(__dirname,'../dist');
// Copie des seuls modules du moteur, comme l'exécutable : aucun lien symbolique (Windows).
for(const entry of CORE_FILES)if(entry!=='press-question-bank.js'){fs.mkdirSync(path.dirname(path.join(distDir,entry)),{recursive:true});fs.copyFileSync(path.join(sourceDist,entry),path.join(distDir,entry));}
let target;// identifiant réel de l'archive choisie, fixé après la première conférence
const writeBank=id=>{const src=fs.readFileSync(path.join(sourceDist,'press-question-bank.js'),'utf8'),marker='legacyJournalistIds:Object.freeze({';assert.equal(src.split(marker).length,2);fs.writeFileSync(path.join(distDir,'press-question-bank.js'),src.replace(marker,marker+JSON.stringify(fnv(legacyId))+':'+JSON.stringify(id)+','));};

let b;const profile=path.join(root,'career');
const handle=(command,payload={})=>b.handle({id:++seq,command,payload});
const good=(command,payload={})=>{const r=handle(command,payload);assert.equal(r.ok,true,command+': '+r.error);return r.model;};
const settle=m=>settleClubMeetings(m,(command,payload)=>good(command,payload));
const state=()=>JSON.parse(good('export').meta.exportText).state,withoutPack=s=>{const v=structuredClone(s);delete v.identityPack;return v;};
const baseNames=[...renamed.map(id=>bank.journalists.get(id).name),...renamedOutlets.map(id=>bank.outlets.get(id))];
const packNames=[...pressRubric.journalists.map(j=>j.name),...pressRubric.outlets.map(o=>o.name)];
const pressText=m=>JSON.stringify(m.clubLife.press);
const person=(m,id)=>m.clubLife.press.people.find(p=>p.id===id);
const expectBase=(m,why)=>{const t=JSON.stringify(m);assert.ok(packNames.every(n=>!t.includes(n)),why+' : aucun nom du pack');assert.equal(person(m,'presse-0').name,bank.journalists.get('presse-0').name,why);assert.equal(person(m,'presse-0').outlet,bank.outlets.get('redaction-0'),why);};
const expectPack=(m,why)=>{const t=JSON.stringify(m);assert.ok(baseNames.every(n=>!t.includes(n)),why+' : plus aucun nom de base remplacé');assert.equal(person(m,'presse-0').name,'Journaliste Test Zéro',why);assert.equal(person(m,'presse-0').outlet,'Rédaction Test 1',why);for(const id of renamed)assert.equal(person(m,id).name,pressRubric.journalists.find(j=>j.id===id).name,why);};
try{
 writeBank('presse-0');
 b=createBridge({dataDir:profile,seed:4242,now:1700000000000,distDir});
 let m=good('new_career',{mode:'world-champ',club:3});
 if(m.clubLife.press.conference.available)m=good('press_conference',{context:m.clubLife.press.context,answers:m.clubLife.press.conference.questions.map(q=>({questionId:q.id,answerId:'r0'}))});
 m=settle(m);assert.ok(m.clubLife.press.history.length>0,'au moins une conférence archivée');
 expectBase(m,'jeu de base');
 const before=state();assert.ok(!JSON.stringify(before).includes('Journaliste Test'));

 // Pack sans rubrique : la presse reste celle de la base.
 const worldBase={...base,databaseId:champ.id},worldPress={...worldBase,press:pressRubric},mode='world-champ';
 const plainZip=archive({...worldBase,id:'sans-presse',players:[{id:champ.clubs[3].players[0].id,name:'Joueur Test'}]}),plain=good('pack_inspect',{path:plainZip,mode}).packs.preview;
 good('pack_install',{path:plainZip,digest:plain.digest,mode});m=settle(good('pack_select',{id:plain.id,scope:'career',mode}));
 expectBase(m,'pack sans rubrique');assert.equal(m.squad.find(p=>p.id===champ.clubs[3].players[0].id).name,'Joueur Test');

 // Pack avec rubrique : journalistes, rédactions, questions et archives.
 const zip=archive(worldPress),preview=good('pack_inspect',{path:zip,mode}).packs.preview;assert.equal(preview.counts.journalists,10);
 good('pack_install',{path:zip,digest:preview.digest,mode});m=settle(good('pack_select',{id:preview.id,scope:'career',mode}));
 expectPack(m,'pack actif');
 for(const q of m.clubLife.press.conference.questions)if(renamed.includes(q.journalist.id))assert.equal(q.journalist.name,pressRubric.journalists.find(j=>j.id===q.journalist.id).name,'question signée');
 for(const h of m.clubLife.press.history)if(renamed.includes(h.journalist?.id))assert.ok(h.journalist.name.startsWith('Journaliste Test '),'archive présentée avec le pack');
 const packed=state();assert.deepEqual(withoutPack(packed),withoutPack(before),'la sauvegarde ne reçoit aucun nom du pack');assert.ok(!JSON.stringify(packed).includes('Journaliste Test'));
 // Une conférence tenue sous le pack archive la signature de base.
 m=settle(good('snapshot'));
 if(m.clubLife.press.conference.available){m=good('press_conference',{context:m.clubLife.press.context,answers:m.clubLife.press.conference.questions.map(q=>({questionId:q.id,answerId:'r1'}))});expectPack(m,'après conférence sous pack');assert.ok(!good('export').meta.exportText.includes('Journaliste Test'));}

 // Bascule pack → base → pack, puis reprise du worker.
 m=settle(good('pack_select',{id:'base',scope:'career',mode}));expectBase(m,'retour à la base');
 m=settle(good('pack_select',{id:preview.id,scope:'career',mode}));expectPack(m,'pack rétabli');
 good('shutdown');b=createBridge({dataDir:profile,now:1700000000000,distDir});m=settle(good('snapshot'));expectPack(m,'reprise avec pack');
 // Manifeste installé altéré : le pack devient indisponible, la base s'affiche.
 {const installed=path.join(fs.realpathSync(m.meta.dataDir),'packs',preview.id,'manifest.json'),original=fs.readFileSync(installed);
  for(const alter of [x=>x.press.journalists['presse-0'].name='<i>Journaliste Test</i>',x=>x.press.journalists['presse-99']={name:'Journaliste Test'},x=>delete x.meta.pressIdentityVersion,x=>{delete x.press;}]){
   const doc=JSON.parse(original);alter(doc);fs.writeFileSync(installed,JSON.stringify(doc));
   m=good('snapshot');assert.ok(m.packs.missing.some(x=>x.startsWith('Pack de carrière absent')),'pack altéré refusé');expectBase(m,'pack altéré');
  }
  fs.writeFileSync(installed,original);m=good('snapshot');expectPack(m,'pack restauré');}

 // Ancienne sauvegarde : identifiant de journaliste d'avant le renommage,
 // signature d'époque dans l'archive. Elle est acceptée et migrée.
 const doc=JSON.parse(good('export').meta.exportText),old=doc.state,entry=old.pressConference.history.find(h=>h.journalist);
 target=entry.journalist.id;writeBank(target);good('shutdown');b=createBridge({dataDir:profile,now:1700000000000,distDir});
 for(const h of old.pressConference.history)if(h.journalist?.id===target)Object.assign(h.journalist,{id:legacyId,name:'Signature Test Ancienne',outlet:'Rédaction Test Ancienne'});
 for(const e of old.pressConference.lastOutcome?.exchanges||[])if(e.journalistId===target)e.journalistId=legacyId;
 const contacts=old.pressPeople.contacts;if(contacts[target]){contacts[legacyId]=contacts[target];delete contacts[target];}
 {const text=JSON.stringify(old);let h=2166136261;for(let i=0;i<text.length;i++)h=Math.imul(h^text.charCodeAt(i),16777619);doc.checksum=(h>>>0).toString(16).padStart(8,'0');}// somme de contrôle des sauvegardes
 m=settle(good('import',{text:JSON.stringify(doc)}));
 const migrated=state(),archived=migrated.pressConference.history.filter(h=>h.journalist?.name==='Signature Test Ancienne');
 assert.ok(archived.length>0&&archived.every(h=>h.journalist.id===target),'identifiant migré, signature d’époque conservée dans la sauvegarde');
 assert.ok(migrated.pressPeople.contacts[target]&&!migrated.pressPeople.contacts[legacyId],'relation migrée');
 const shown=(model)=>model.clubLife.press.history.filter(h=>h.journalist?.id===target);
 const expected=pressRubric.journalists.find(j=>j.id===target)?.name;
 assert.ok(shown(m).length>0&&shown(m).every(h=>h.journalist.name===(expected||bank.journalists.get(target).name)),'archive présentée avec l’identité actuelle du journaliste');
 m=settle(good('pack_select',{id:'base',scope:'career',mode}));
 assert.ok(shown(m).every(h=>h.journalist.name===bank.journalists.get(target).name&&h.journalist.outlet===bank.journalists.get(target).outlet),'base : identité de base, sans signature d’époque');
 assert.ok(!pressText(m).includes('Signature Test Ancienne'),'aucune ancienne signature à l’écran');
 console.log('Presse et packs : rubrique facultative, refus stricts, projection, bascule pack/base/pack, reprise et ancienne sauvegarde PASS.');
}finally{b?.close();fs.rmSync(root,{recursive:true,force:true});}
