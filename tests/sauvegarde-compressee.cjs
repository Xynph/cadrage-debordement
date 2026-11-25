'use strict';
// Export compressé (exportVersion 4, dist/saves.js + native/engine/save-compression.cjs) : une carrière mondiale dont
// l'export, même réduit (v3), dépasse le plafond de son édition sort compressée (gzip + base64) dans une enveloppe JSON.
// Sans perte : la lecture retrouve exactement l'état, l'empreinte est vérifiée sur l'état reconstitué ; les anciens
// formats v1, v2, v3 se lisent tels quels ; un fichier retouché, piégé ou trop gros est refusé.
const assert=require('node:assert/strict');
const zlib=require('node:zlib');
const {context}=require('./harness.cjs');
const compression=require('../native/engine/save-compression.cjs');

function monde(installer=true){
 const h=context();
 if(installer)compression.install(h.ctx);
 return h;
}
const profile=id=>({position:{primary:'Pilier gauche',qualifications:['Pilier gauche'],basis:'estimated'},note:'profil '+id,history:[1,2,3]});
const ids=['world:elite:1','world:elite:2'];
const registry={worldProfiles:Object.fromEntries(ids.map(id=>[id,profile(id)])),compatibilityAliases:{}};
const player=(id,extra={})=>({id,name:'Joueur '+id,salary:2000,worldProfile:registry.worldProfiles[id],...extra});
const free={id:'free:1',name:'Libre',salary:900,bio:'é'.repeat(40)};
// Données variées (non répétitives) : le plafond du fichier se mesure sur un contenu proche d'une vraie carrière.
let graine=12345;const hasard=()=>(graine=(Math.imul(graine,1103515245)+12345)>>>0);
const historique=Array.from({length:4000},(_,i)=>({semaine:i%52,note:hasard()%100,texte:'Match '+(hasard()%997)+' · essai à la '+(hasard()%80)+'e'}));
const source={
 version:2,season:3,club:0,worldMode:{version:5},
 clubs:[{id:0,players:[player('world:elite:1'),player('world:elite:2',{salary:4000})]}],
 development:{academy:[]},aiRoster:{academies:[]},
 economy:{freeAgents:[free]},market:[{...free}],
 historique,
};
const etatTexte=JSON.stringify(source),etatOctets=Buffer.byteLength(etatTexte);
// Plafond de l'édition : la moitié de l'état. Ni l'export ordinaire ni l'export réduit n'y tiennent.
function preparer(h,cap){
 h.ctx.refRegistry=JSON.stringify(registry);h.ctx.refCap=cap;h.ctx.refFixture=etatTexte;
 h.run(`
  const refReg=JSON.parse(refRegistry);
  CDWorldCareer={active:s=>[4,5].includes(s?.worldMode?.version),edition:s=>({version:s.worldMode.version,limits:{saveBytes:refCap},registry:refReg}),sourcePlayer:()=>null};
  validateCareer=s=>saveCheck(Array.isArray(s.clubs));
 `);
}
const cap=Math.floor(etatOctets/2);
const h=monde();preparer(h,cap);
const encoded=h.run('JSON.stringify(createSaveDocument(JSON.parse(refFixture)))');
const env=JSON.parse(encoded);
assert.equal(env.exportVersion,4,'Export trop gros même réduit : enveloppe compressée.');
assert.equal(env.compression,'gzip');
assert.deepEqual(Object.keys(env),['format','exportVersion','exportedAt','checksum','compression','data'],'Enveloppe : en-tête lisible en clair, données compressées.');
assert.ok(Buffer.byteLength(encoded)<=cap,'Le fichier compressé respecte le plafond de l’édition.');
assert.ok(Buffer.byteLength(encoded)<etatOctets/3,'Gain de taille réel ('+Buffer.byteLength(encoded)+' octets pour '+etatOctets+').');
const interne=JSON.parse(zlib.gunzipSync(Buffer.from(env.data,'base64')).toString('utf8'));
assert.equal(interne.exportVersion,3,'Le contenu est le meilleur export sans perte (v3 : références au registre).');
assert.equal(interne.checksum,env.checksum,'Empreinte de l’enveloppe = empreinte du contenu.');
assert.equal(interne.state.clubs[0].players[0].worldProfile,true,'Champ de référence marqué dans le contenu.');

// Aller-retour exact : état identique (deepEqual et texte), empreinte vérifiée sur l'état reconstitué.
h.ctx.refText=encoded;
const relu=JSON.parse(h.run('JSON.stringify(parseSaveDocument(refText))'));
assert.deepStrictEqual(relu.state,source,'Un export compressé réimporté donne un état identique.');
assert.equal(JSON.stringify(relu.state),etatTexte);
assert.equal(relu.checksum,env.checksum);
assert.equal(h.run('confirmSaveImport.length>=0&&(pendingSave=parseSaveDocument(refText),saveChecksum(pendingSave.state)===pendingSave.checksum)'),true,'La confirmation retrouve la même empreinte.');
// Déterministe : le même document donne les mêmes octets compressés (en-tête gzip sans date).
assert.equal(compression.compress(JSON.stringify(interne)),env.data);

// Fichiers retouchés : toujours refusés par l'empreinte ou l'intégrité, jamais lus en partie.
function refuse(texte,motif,etiquette){h.ctx.refBad=texte;assert.throws(()=>h.run('parseSaveDocument(refBad)'),motif,etiquette);}
const recomprime=(change)=>{const d=JSON.parse(JSON.stringify(interne));change(d);return JSON.stringify({...env,data:zlib.gzipSync(Buffer.from(JSON.stringify(d),'utf8')).toString('base64')});};
refuse(recomprime(d=>{d.state.clubs[0].players[1].salary=99999;}),/modifié ou endommagé/i,'État modifié puis recompressé avec la même empreinte : refusé par la signature.');
refuse(recomprime(d=>{d.state.historique[17].note=101;}),/modifié ou endommagé/i,'Donnée loin dans le fichier modifiée : refusée.');
refuse(recomprime(d=>{d.checksum='00000000';}),/modifié ou endommagé/i,'Empreinte du contenu différente de l’enveloppe : refusée.');
refuse(JSON.stringify({...env,checksum:'00000000'}),/modifié ou endommagé/i,'Empreinte de l’enveloppe retouchée : refusée.');
{const i=Math.floor(env.data.length/2),c=env.data[i]==='A'?'B':'A';refuse(JSON.stringify({...env,data:env.data.slice(0,i)+c+env.data.slice(i+1)}),/modifié ou endommagé/i,'Un caractère du contenu compressé changé : refusé.');}
refuse(JSON.stringify({...env,data:env.data.slice(0,-40)}),/modifié ou endommagé/i,'Contenu tronqué : refusé.');
refuse(JSON.stringify({...env,data:env.data+'!'}),/modifié ou endommagé/i,'Base64 non canonique : refusé.');
refuse(JSON.stringify({...env,data:zlib.gzipSync(Buffer.from(JSON.stringify(env))).toString('base64')}),/version d.export/i,'Enveloppe dans l’enveloppe : refusée.');
refuse(JSON.stringify({...env,data:zlib.gzipSync(Buffer.from(JSON.stringify({...interne,state:{...interne.state,worldMode:{version:1}}}))).toString('base64')}),/version d.export/i,'Carrière non mondiale : pas de v4.');
refuse(JSON.stringify({...env,format:'autre'}),/pas un export/i);
refuse(JSON.stringify({...env,exportedAt:'hier'}),/incohérentes/i);
refuse(JSON.stringify({format:env.format,exportVersion:4,exportedAt:env.exportedAt,checksum:env.checksum}),/version d.export/i,'v4 sans contenu compressé : version refusée.');
// Le plafond de l'édition s'applique au fichier compressé.
refuse(JSON.stringify({...env,note:'x'.repeat(cap)}),/trop volumineux \(\d+(\.\d+)? Mio UTF-8 maximum pour cette édition\)/i,'Fichier compressé au-dessus du plafond de l’édition : refusé.');
// Bombe de décompression : la décompression s'arrête au plafond (96 Mio), sans lire le reste.
{
 const bombe=zlib.gzipSync(Buffer.alloc(96*1024*1024+1,32),{level:9}).toString('base64');
 assert.ok(bombe.length<200*1024,'La bombe pèse quelques centaines de Ko compressée.');
 refuse(JSON.stringify({...env,data:bombe}),/trop volumineux une fois décompressé \(96 Mio/i,'Bombe de décompression : refusée au plafond.');
 assert.throws(()=>compression.inflate(compression.compress('x'.repeat(2000)),1000),/trop volumineux/i);
 assert.equal(compression.inflate(compression.compress('é'.repeat(1000)),2000),'é'.repeat(1000),'Plafond exact : admis.');
 assert.throws(()=>compression.inflate(zlib.gzipSync(Buffer.from([0xff,0xfe,0x41])).toString('base64'),100),/endommagé/i,'UTF-8 invalide : refusé.');
}

// Formats antérieurs, non compressés : v1, v2, v3 se relisent tels quels (même pont, compression branchée).
{
 const g=monde();preparer(g,10*etatOctets);
 const v1=JSON.parse(g.run('JSON.stringify(createSaveDocument(JSON.parse(refFixture)))'));
 assert.equal(v1.exportVersion,1,'Carrière qui tient dans le plafond : export ordinaire, non compressé.');
 g.ctx.refV1=JSON.stringify(v1);
 assert.deepStrictEqual(JSON.parse(g.run('JSON.stringify(parseSaveDocument(refV1).state)')),source,'Export v1 relu.');
 const v2={...v1,exportVersion:2,state:{...v1.state,market:['free:1']}};g.ctx.refV2=JSON.stringify(v2);
 assert.deepStrictEqual(JSON.parse(g.run('JSON.stringify(parseSaveDocument(refV2).state)')),source,'Export v2 relu.');
 g.ctx.refV3=JSON.stringify(interne);
 assert.deepStrictEqual(JSON.parse(g.run('JSON.stringify(parseSaveDocument(refV3).state)')),source,'Export v3 relu.');
 // Plafond entre v3 et v1 : la réduction v3 suffit, pas de compression.
 const v3cap=Buffer.byteLength(JSON.stringify(interne))+64;g.ctx.refCap=v3cap;
 assert.equal(JSON.parse(g.run('JSON.stringify(createSaveDocument(JSON.parse(refFixture)))')).exportVersion,3,'Export v3 tant qu’il tient dans le plafond.');
}

// Sans le moteur natif (version web) : pas de compression, erreur de taille explicite ; un v4 n'est pas lu en partie.
{
 const w=monde(false);preparer(w,cap);
 assert.throws(()=>w.run('createSaveDocument(JSON.parse(refFixture))'),/trop volumineux/i);
 w.ctx.refText=encoded;
 assert.throws(()=>w.run('parseSaveDocument(refText)'),/jeu installé/i);
}
console.log('PASS export compressé v4 : aller-retour exact, signature vérifiée, plafonds (fichier et décompressé), v1 à v3 relus');
