'use strict';
const assert=require('node:assert/strict');
const {context}=require('./harness.cjs');
const ui=require('../dist/ui04-academy-data.js');

function makeSource(g){
 return JSON.parse(g.run('JSON.stringify({academy:S.development.academy,professionals:club().players,retired:S.development.retired,season:S.season,clubName:club().name,locked:economyLocked()})'));
}
function deps(g){
 return {
  roleNote:g.run('roleNote'),potentialAtRole:g.run('potentialAtRole'),
  developmentBadge:g.run('developmentBadge'),
  developmentFocusOptions:g.run('developmentFocusOptions'),
  developmentFocusValue:g.run('developmentFocusValue'),
  retirementSeason:g.run('retirementSeason')
 };
}

const g=context();g.run('start(0)');
const before=g.run('JSON.stringify(S)'),beforeStorage=g.store['bdt-v1'];
const source=makeSource(g),native=deps(g);
assert.equal(source.academy.length,4);
assert.equal(source.professionals.length>=23,true);
const inputCopy=JSON.stringify(source);
const model=ui.buildCenter(source,native);
assert.equal(model.version,1);
assert.equal(model.totals.academy,4);
assert.equal(model.academy.length,source.academy.length);
assert.equal(model.totals.young,source.professionals.filter(x=>x.age<=23).length);
assert.equal(model.totals.youngMinutes,source.professionals.filter(x=>x.age<=23).reduce((s,p)=>s+(p.dev?.minutes||0),0));
assert.equal(model.totals.promotionSlots,42-source.professionals.length);
assert.ok(model.academy.every(p=>p.canPromote));
assert.ok(model.academy.every(p=>p.history.length===source.academy.find(x=>x.id===p.id).dev.history.length));
assert.equal(model.academy[0].note,g.run('roleNote(S.development.academy[0])'));
assert.equal(model.academy[0].potential,g.run('potentialAtRole(S.development.academy[0])'));
assert.equal(model.academy[0].focus,g.run('developmentFocusValue(S.development.academy[0])'));
assert.deepEqual(model.academy[0].focusOptions,Array.from(g.run('developmentFocusOptions(S.development.academy[0])')));
assert.equal(model.academy[0].retirementSeason,g.run('retirementSeason(S.development.academy[0])'));
assert.equal(model.academy[0].kind,'academy');
assert.equal(model.young.every(p=>p.kind==='professional'&&p.contractEnd!==undefined),true);
assert.equal(JSON.stringify(source),inputCopy,'source mutated by native calculator');
assert.equal(g.run('JSON.stringify(S)'),before,'career mutated by projection');
assert.equal(g.store['bdt-v1'],beforeStorage,'projection saved a career');
assert.ok(!JSON.stringify(model).includes('undefined'));

const table=ui.table(model);
assert.equal(table.kind,'academy');
assert.equal(table.total,4);
assert.equal(ui.table(model,{kind:'young'}).total,model.totals.young);
const sample=model.academy[0];
assert.ok(ui.table(model,{search:sample.name.toLocaleUpperCase('fr')}).rows.some(p=>p.id===sample.id));
assert.ok(ui.table(model,{family:sample.family}).rows.every(p=>p.family===sample.family));
assert.ok(ui.table(model,{maxAge:sample.age}).rows.every(p=>p.age<=sample.age));
assert.ok(ui.table(model,{canPromoteOnly:true}).rows.every(p=>p.canPromote));
for(const kind of ['academy','young']){
 for(const sortBy of ui.SORTS){
  const ascending=ui.table(model,{kind,sortBy,direction:'asc'});
  const descending=ui.table(model,{kind,sortBy,direction:'desc'});
  assert.equal(ascending.total,descending.total);
 }
}
assert.throws(()=>ui.table(model,{kind:'staff'}),/Origine/);
assert.throws(()=>ui.table(model,{sortBy:'secret'}),/Tri/);
assert.throws(()=>ui.table(model,{direction:'sideways'}),/Tri/);
assert.throws(()=>ui.table(model,{family:20}),/Famille/);
assert.throws(()=>ui.table(model,{maxAge:70}),/Âge/);

// Le verrou d'économie natif et la limite 42 sont uniquement reflétés ; aucun contournement.
const locked=ui.buildCenter({...source,locked:true},native);
assert.ok(locked.academy.every(p=>!p.canPromote));
assert.ok(locked.academy.every(p=>p.promotionBlockedReason.includes('indisponibles')));
const full=ui.buildCenter({...source,professionals:Array.from({length:42},(_,i)=>({...source.professionals[i%source.professionals.length],id:'full'+i}))},native);
assert.equal(full.totals.promotionSlots,0);
assert.ok(full.academy.every(p=>!p.canPromote));

// Un ancien document joueur incomplet peut être consulté sans être initialisé sur place.
const legacy=JSON.parse(JSON.stringify(source.academy[0]));
delete legacy.dev;delete legacy.skills;
const originalLegacy=JSON.stringify(legacy);
const projectedLegacy=ui.playerView(legacy,'academy',native,{locked:false,professionalCount:25});
assert.ok(Number.isFinite(projectedLegacy.note));
assert.ok(Number.isFinite(projectedLegacy.potential));
assert.equal(JSON.stringify(legacy),originalLegacy);

// Le moteur conserve la promotion unique, les 42 places et les contrats.
const career=context();career.run('start(0)');
const firstId=career.run('S.development.academy[0].id');
const count=career.run('club().players.length');
assert.equal(career.run('promoteYouth('+JSON.stringify(firstId)+')'),true);
assert.equal(career.run('club().players.length'),count+1);
assert.equal(career.run('S.development.academy.some(p=>p.id==='+JSON.stringify(firstId)+')'),false);
assert.equal(career.run('promoteYouth('+JSON.stringify(firstId)+')'),false);
const after=ui.buildCenter(makeSource(career),deps(career));
assert.equal(after.totals.academy,3);
assert.equal(after.totals.professionalCount,count+1);
assert.equal(career.run('club().players.find(p=>p.id==='+JSON.stringify(firstId)+').academy'),false);
assert.ok(career.run('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'));

// Les archives sont limitées au club actuel sans fabriquer de saison.
const archive=ui.buildCenter({...source,retired:[
 {name:'Mathieu Retraité',id:'r1',age:36,season:2,club:source.clubName,minutes:1080},
 {name:'Autre Club',id:'r2',age:38,season:2,club:'Un autre club',minutes:2000}
]},native);
assert.equal(archive.retired.length,1);
assert.equal(archive.retired[0].careerMinutes,1080);
assert.equal(g.run('JSON.stringify(S)'),before);
console.log(JSON.stringify({passed:true,checks:[
 'vrais espoirs et jeunes professionnels','notes de poste et potentiels natifs','historiques et focus individuels',
 'tri et filtres déterministes','aucune mutation ni sauvegarde par lecture','anciens joueurs incomplets',
 'verrous et effectif plein','promotion native unique et contrat','sauvegarde native valide','archives du seul club'
]}));