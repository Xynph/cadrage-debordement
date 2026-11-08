'use strict';
const assert=require('node:assert/strict'),vm=require('node:vm'),domain=require('../native/engine/coach-notes.cjs');
const ctx=vm.createContext({Math:Object.assign(Object.create(Math),{random(){throw Error('RNG interdit');}}),Date:class {static now(){throw Error('Horloge interdite');}}});
const run=s=>vm.runInContext(s,ctx),read=s=>JSON.parse(run('JSON.stringify('+s+')'));
run(`S={club:0,season:2,round:3,clubs:[{id:0,players:[{id:'p:échec'.replace('échec','001'),name:'Émile',pos:'Pilier',rating:91,hidden:99}]},{id:1,players:[{id:'p:002',name:'Zoé',pos:'Centre'}]}],market:[],economy:{freeAgents:[]},development:{academy:[]},aiRoster:{academies:[]}};const notes=(${domain.factory.toString()})();`);
const before=run('JSON.stringify(S)'),p=read('notes.project()');assert.equal(p.entries.length,0);assert.equal(run('JSON.stringify(S)'),before);assert.equal(read('S').coachNotebook,undefined);
const context=p.context,save=(target,text)=>{ctx.payload={context,target,text};return read("notes.execute('coach_note_save',payload)");};
const text='  Émile & Zoé : « garder le cap » <3 "projet" `calme` 😀\n\tÀ revoir.  ';
const receipt=save('p:001',text);assert.deepEqual(receipt.coachNote,{command:'coach_note_save',target:'p:001',context});
assert.equal(read('notes.project().entries[0]').text,text);assert.ok(Array.isArray(read('S.coachNotebook.entries[0]').textCodes));assert.ok(!Object.hasOwn(read('S.coachNotebook.entries[0]'),'text'));
assert.ok(!JSON.stringify(read('notes.project()')).includes('rating'));assert.ok(!JSON.stringify(read('notes.project()')).includes('hidden'));
const saved=run('JSON.stringify(S)');for(let i=0;i<4;i++)notesRead();function notesRead(){read('notes.project()');assert.equal(run('JSON.stringify(S)'),saved);}
for(const value of ['', ' \n\t ', 'a'.repeat(2001),'x\rY','x\u007f','x\u0085','x\u0000','\ud800','\udfff']){assert.throws(()=>save('career',value),/texte|Unicode|caract|vide/i);assert.equal(run('JSON.stringify(S)'),saved);}
save('career','😀'.repeat(2000));assert.equal(read('S.coachNotebook.entries').find(e=>e.target==='career').textCodes.length,2000);
run('S='+saved);assert.throws(()=>save('absent','Nouveau dossier'),/cible|dossier|joueur/i);
ctx.payload={context:{...context,week:99},target:'p:001',text:'Périmé'};assert.throws(()=>run("notes.execute('coach_note_save',payload)"),/périm|contexte/i);
ctx.payload={context,target:'p:001',text:'Inconnu',extra:true};assert.throws(()=>run("notes.execute('coach_note_save',payload)"),/param|champ/i);
for(const change of ["S.coachNotebook.extra=1","S.coachNotebook.version=2","S.coachNotebook.entries.push({...S.coachNotebook.entries[0]})","S.coachNotebook.entries[0].textCodes=[0xd800]","S.coachNotebook.entries[0].textCodes=[0x110000]","S.coachNotebook.entries[0].textCodes=[1.5]","S.coachNotebook.entries[0].week=4","S.coachNotebook.entries[0].season=3","S.coachNotebook.entries[0].club=2","S.coachNotebook.entries[0].text='Pas le contrat'","S.coachNotebook.entries[0].target='pas valide'"]){run('S='+saved);run(change);assert.throws(()=>run('notes.validate(S)'),/carnet|note|Unicode/i,change);}
run('S='+saved);run("S.clubs[0].players=[];S.club=1");let absent=read('notes.project().entries[0]');assert.equal(absent.available,false);assert.equal(absent.name,null);assert.equal(absent.id,null);assert.equal(absent.text,text);
ctx.payload={context:read('notes.project().context'),target:'p:001',text:'Archive toujours éditable'};run("notes.execute('coach_note_save',payload)");assert.equal(read('notes.project().entries[0]').text,'Archive toujours éditable');
ctx.payload={context:read('notes.project().context'),target:'p:001',confirmed:false};assert.throws(()=>run("notes.execute('coach_note_remove',payload)"),/confirm/i);ctx.payload.confirmed=true;run("notes.execute('coach_note_remove',payload)");assert.equal(read('notes.project().entries').length,0);
run(`S=${before};S.clubs[0].players=Array.from({length:101},(_,i)=>({id:'test-'+i,name:'Joueur '+i,pos:'Centre'}));`);
for(let i=0;i<100;i++)save('test-'+i,'Note '+i);assert.throws(()=>save('test-100','Excédent'),/100|plein|limite/i);save('test-0','Modifiée au plafond');assert.equal(read('notes.project().entries').length,100);
console.log('Carnet06 domaine PASS : Unicode littéral/2000points, lecture pure, schéma fermé, contexte/stamps,100notes, cible absente après mobilité, édition/suppression et attributs non exposés.');
