'use strict';
// Export v3 des carrières mondiales : les champs copiés des registres ne sont pas
// écrits et sont reconstruits à la lecture. Anciennes versions toujours lues.
const assert=require('node:assert/strict');
const {context}=require('./harness.cjs');

const {ctx,run}=context();
const profile=id=>({position:{primary:'Pilier gauche',qualifications:['Pilier gauche'],basis:'estimated'},note:'profil '+id,history:[1,2,3]});
const traits=id=>({professionalism:50+id.length,consistency:60,bigMatches:40,injuryResistance:70,ambition:55,adaptability:45});
const ids=['world:elite:1','world:elite:2','world:prem:3','alias:old'];
const registry={
 worldProfiles:Object.fromEntries(ids.slice(0,3).map(id=>[id,profile(id)])),
 compatibilityAliases:{'alias:old':{player:{id:'alias:old',hiddenTraitsV2:traits('alias:old')},worldProfile:profile('alias:old')}},
};
const sources=Object.fromEntries(ids.slice(0,3).map(id=>[id,{id,hiddenTraitsV2:traits(id)}]));
const player=(id,extra={})=>({id,name:'Joueur '+id,salary:2000,worldRatingsVersion:id.startsWith('world:')?1:undefined,
 worldProfile:registry.worldProfiles[id]??registry.compatibilityAliases[id]?.worldProfile,
 hiddenTraitsV2:sources[id]?.hiddenTraitsV2,...extra});
const free={id:'free:1',name:'Libre',salary:900,bio:'é'.repeat(40)};
const source={
 version:2,season:3,club:0,worldMode:{version:5},
 clubs:[{id:0,players:[player('world:elite:1'),player('world:elite:2',{hiddenTraitsV2:{...traits('x'),ambition:99}})]},
  {id:1,players:[player('world:prem:3'),player('alias:old',{worldProfile:{...profile('alias:old'),note:'modifié'}})]}],
 development:{academy:[{id:'youth:1',name:'Espoir',salary:300}]},
 aiRoster:{academies:[{clubId:1,players:[{id:'youth:2',name:'Espoir 2',salary:300}]}]},
 economy:{freeAgents:[free]},market:[{...free}],
 padding:'x'.repeat(2000),
};
ctx.refFixture=JSON.stringify(source);ctx.refRegistry=JSON.stringify(registry);ctx.refSources=JSON.stringify(sources);
ctx.refCap=Buffer.byteLength(JSON.stringify({state:source}))-300;
run(`
 const refReg=JSON.parse(refRegistry),refSrc=JSON.parse(refSources);
 const CDWorldCareer={
  active:s=>[4,5].includes(s?.worldMode?.version),
  edition:s=>({version:s.worldMode.version,limits:{saveBytes:refCap},registry:refReg}),
  sourcePlayer:(s,id)=>refSrc[id]||null,
 };
 const refState=JSON.parse(refFixture);
 validateCareer=s=>saveCheck(Array.isArray(s.clubs));
`);
const encoded=run('JSON.stringify(createSaveDocument(refState))');
const doc=JSON.parse(encoded);
assert.equal(doc.exportVersion,3,'Une carrière mondiale trop volumineuse passe au format réduit.');
assert.ok(Buffer.byteLength(encoded)<=ctx.refCap);
const players=doc.state.clubs.flatMap(c=>c.players);
assert.equal(players.find(p=>p.id==='world:elite:1').worldProfile,true,'Profil identique au registre : marqué, non écrit.');
assert.equal(players.find(p=>p.id==='world:elite:1').hiddenTraitsV2,true,'Traits identiques à la source : marqués, non écrits.');
assert.equal(players.find(p=>p.id==='world:elite:2').hiddenTraitsV2.ambition,99,'Traits différents : conservés.');
assert.equal(players.find(p=>p.id==='alias:old').worldProfile.note,'modifié','Profil différent : conservé.');
assert.deepEqual(doc.state.market,['free:1'],'Le marché Champ garde ses références au vivier.');
ctx.refText=encoded;
assert.equal(run('JSON.stringify(parseSaveDocument(refText).state)'),JSON.stringify(source),'La lecture reconstruit exactement l’état exporté.');
assert.equal(run('{const s=parseSaveDocument(refText).state;s.clubs[0].players[0].worldProfile!==JSON.parse(refRegistry).worldProfiles["world:elite:1"]}'),true);

// Un fichier modifié est refusé, y compris un champ de référence ajouté.
function refuses(change,message){const bad=JSON.parse(encoded);change(bad);ctx.refBad=JSON.stringify(bad);assert.throws(()=>run('parseSaveDocument(refBad)'),message);}
refuses(doc=>{doc.state.clubs[0].players[0].salary=99999;},/modifié ou endommagé/i);
refuses(doc=>{doc.state.clubs[0].players[1].hiddenTraitsV2.ambition=10;},/modifié ou endommagé/i);
refuses(doc=>{doc.state.worldMode.version=1;},/version d.export/i);
refuses(doc=>{doc.state.development.academy[0].worldProfile=true;},/référence de joueur absente/i);
refuses(doc=>{doc.exportVersion=4;},/version d.export/i);

// Formats antérieurs : v1 (ordinaire) et v2 (marché Champ) restent lus tels quels.
const small={...source,padding:'',clubs:source.clubs.map(c=>({...c,players:c.players.slice(0,1)}))};
ctx.refSmall=JSON.stringify(small);
const v1=JSON.parse(run('JSON.stringify(createSaveDocument(JSON.parse(refSmall)))'));
assert.equal(v1.exportVersion,1,'Une carrière qui tient dans la limite reste au format ordinaire.');
ctx.refV1=JSON.stringify(v1);
assert.equal(run('JSON.stringify(parseSaveDocument(refV1).state)'),JSON.stringify(small));
const v2={...v1,exportVersion:2,state:{...v1.state,market:['free:1']}};ctx.refV2=JSON.stringify(v2);
assert.equal(run('JSON.stringify(parseSaveDocument(refV2).state)'),JSON.stringify(small),'Un export v2 reste lisible.');

// Sans gain possible (aucun champ de référence), pas de v3 : l'erreur de taille reste explicite.
ctx.refNoGain=JSON.stringify({...source,clubs:[],padding:'x'.repeat(4000)});
assert.throws(()=>run('createSaveDocument(JSON.parse(refNoGain))'),/trop volumineux/i);
console.log('PASS export mondial v3 : champs de référence omis, reconstruction exacte, v1 et v2 lus, fichiers modifiés refusés');
