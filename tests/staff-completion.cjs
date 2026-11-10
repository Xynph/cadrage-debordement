'use strict';
const {test}=require('node:test'),a=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const target=require('node:path').join(__dirname,'../native/engine/staff-completion.cjs');
a.ok(fs.existsSync(target),'Staff completion must be a separate pure fictional policy');
const C=require(target),staff=require('../native/engine/staff.cjs'),portrait=require('../native/engine/portraits.cjs');
function world(){const e=require('../native/engine/world-pacific-registry.cjs');let r=require('../native/engine/world-registry.json');for(const [fn,file] of [['extendWorldRegistry','world-pacific-extension.json'],['extendJapanRegistry','world-japan-extension.json'],['extendNationaleRegistry','world-nationale-extension.json'],['extendChampRegistry','world-champ-extension.json']])r=e[fn](r,require('../native/engine/'+file));return r;}
const database='rugby-world-2026-11-09-champ-v5';
test('Normalisation spécialisée multilingue sans diplôme médical déduit d’un rôle générique',()=>{
 for(const [label,key] of [['Entraîneur adjoint','assistant'],['Forwards Coach','forwards'],['Scrum Coach','forwards'],['Coach touche','forwards'],['Backs Coach','backs'],['Responsable jeu au pied','backs'],['Defence Coach','defence'],['Head of Athletic Performance','fitnessLead'],['S&C Coach','conditioning'],['Réathlétisation','rehab'],['Sports Rehabilitator','rehab'],['Team Doctor','doctor'],['Médecin référent','doctor'],['Fisioterapista','physio'],['Kinésithérapeute','physio'],['Performance Analyst','analyst'],['Head of Recruitment','scout'],['Academy Manager','formation'],['Team Manager','teamManager'],['Kit Manager','equipment']])a.ok(C.capabilities(label).includes(key),label+' -> '+key);
 for(const label of ['Soigneur','Staff médical','Pôle médical','Encadrement du club','Entraîneur','Head of Medical']){a.ok(!C.capabilities(label).includes('doctor'),label+' is not a sourced medical degree');a.ok(!C.capabilities(label).includes('physio'),label+' is not a physio');}
 a.equal(C.role('Team Manager'),'support');a.equal(C.role('Assistant Strength & Conditioning Coach'),'fitness');
});
test('Appariement : une seule personne ne remplit pas deux postes minimum et les fiches historiques ne comptent pas',()=>{
 const members=[{id:'both',role:'Médecin et kinésithérapeute'},{id:'historical',role:'Kinésithérapeute',historical:true}];const c=C.coverage(members);a.equal(c.doctor+c.physio,1);a.equal(c.physio<2,true);
 const complete=C.completeClub({databaseId:'fixture',club:{id:0,base:50},members});a.equal(complete.before,1);a.equal(complete.after,15);a.equal(complete.members.length,16);for(const [key,n] of Object.entries(C.MINIMUM))a.ok(C.coverage(complete.members)[key]>=n,key);
});
test('Paliers 15/20/26, grand staff conservé et fonctions ajoutées malgré un effectif générique nombreux',()=>{
 for(const [base,target] of [[50,15],[71,15],[72,20],[81,20],[82,26],[95,26]])a.equal(C.target(base),target);
 const originals=Array.from({length:65},(_,i)=>({id:'coach:'+i,name:'Reference '+i,role:'Entraîneur'})),before=JSON.stringify(originals),r=C.completeClub({databaseId:'fixture',club:{id:1,base:82},members:originals});a.ok(r.after>65);a.equal(JSON.stringify(originals),before);a.deepEqual(r.members.slice(0,65),originals);for(const [key,n] of Object.entries(C.MINIMUM))a.ok(C.coverage(r.members)[key]>=n,key);
});
test('France30 et Monde116 : couverture complète, ajouts fictifs distincts, sources/pack IDs immuables et portrait banque2',()=>{
 const w=world();for(const [id,clubs,count] of [['rugby-common-2026-10-31-v1',w.clubs.slice(0,30),30],[database,w.clubs,116]]){
  const selected=staff.forDatabase(id),raw=selected.referenceRegistry||selected.registry,before=JSON.stringify(raw),referenceIds=new Set(raw.clubs.flatMap(c=>c.members.map(p=>p.id))),result=C.completeRegistry({databaseId:id,clubs,registry:raw}),repeat=C.completeRegistry({databaseId:id,clubs,registry:raw});a.deepEqual(result,repeat);a.equal(result.clubs.length,count);a.equal(JSON.stringify(raw),before);
  const allIds=new Set(),allNames=new Set();for(const c of result.clubs){const source=raw.clubs.find(x=>x.id===c.id),old=source.members.filter(p=>!p.historical);a.deepEqual(c.members.slice(0,source.members.length),source.members);a.ok(c.members.filter(p=>!p.historical).length>=Math.max(C.target(clubs[c.id].base),old.length));const coverage=C.coverage(c.members);for(const [key,n] of Object.entries(C.MINIMUM))a.ok(coverage[key]>=n,id+' club'+c.id+' '+key);
   for(const p of c.members){a.ok(!allIds.has(p.id),'unique '+p.id);allIds.add(p.id);if(p.sourceKind==='generated'){a.equal(p.identityStatus,'fictional');a.equal(p.portraitStatus,'synthetic');a.equal(p.appearanceBankVersion,2);a.equal(referenceIds.has(p.id),false);const n=p.name.normalize('NFKD').toLowerCase();a.ok(!allNames.has(n),p.name);allNames.add(n);a.match(p.name,/^[A-ZÀ-Ÿ][^\d]+ [A-ZÀ-Ÿ][^\d]+$/);a.doesNotMatch(p.name,/de carrière|de carriere|\d/);a.equal(p.ageEstimated,true);const face=portrait.describe({...p,portraitRole:'staff'});a.equal(face.bankVersion,2);a.equal(face.atlas,'staff');a.match(face.assetPath,/regen/);}}
  }
  const composed=staff.forDatabase(id);a.deepEqual(composed.registry,result);a.deepEqual(new Set(composed.ids),referenceIds,'fictional staff cannot become a pack reference');
 }
});
test('Projection common sans activation utilise la vue complétée sans modifier le modèle ni la référence',()=>{
 const model={meta:{mode:'common',database:{id:'rugby-common-2026-10-31-v1'},catalogue:[]},club:{id:0}},before=JSON.stringify(model),raw=JSON.stringify(staff.registry),p=staff.project(model);a.equal(JSON.stringify(model),before);a.equal(JSON.stringify(staff.registry),raw);a.ok(p.staff.teams.every(t=>t.members.filter(x=>!x.historical).length>=15));a.ok(p.staff.teams[0].members.some(x=>x.identityStatus==='fictional'));a.deepEqual(staff.project(model),p);
});
function careerHarness({source=null,S=null}={}){
 source=source||[{id:0,members:[{id:'ref:0',name:'Reference Zero',role:'Entraîneur principal',age:52}]},{id:1,members:[{id:'ref:1',name:'Reference One',role:'Médecin',age:50}]}];
 S=S||{season:1,round:0,phase:'league',club:0,commonDatabase:{id:'fixture'},clubs:[{id:0,name:'Zero',base:86,cash:100000,players:[]},{id:1,name:'One',base:65,cash:100000,players:[]}]};
 const box=vm.createContext({S,nativeStaffCareerSources:{[S.commonDatabase?.id||'fixture']:source},Math:Object.assign(Object.create(Math),{random(){throw Error('Staff may not consume RNG');}})});
 vm.runInContext('const d=('+require('../native/engine/staff-career.cjs').factory.toString()+')();',box);
 return {box,get s(){return box.S;},d:vm.runInContext('d',box),model(){return JSON.parse(vm.runInContext('JSON.stringify(d.project())',box));}};
}
test('Nouveau cycle : suppléments réellement GENERATED, identités/portraits fictifs cohérents et aucune dépense',()=>{
 const h=careerHarness(),before=h.s.clubs.map(c=>c.cash);h.d.initialize(h.s);a.equal(h.s.staffCareer.completionPolicy,C.POLICY);a.equal(h.d.validate(h.s),true);
 const m=h.model();for(const t of m.teams){a.ok(t.members.length>=15);for(const [key,n] of Object.entries(C.MINIMUM))a.ok(C.coverage(t.members)[key]>=n);for(const p of t.members.filter(p=>p.sourceKind==='generated')){a.equal(p.sourceStaffId,null);a.equal(p.identityStatus,'fictional');a.equal(p.identity.identityStatus,'fictional');a.equal(p.appearanceBankVersion,2);a.equal(p.portraitStatus,'synthetic');a.doesNotMatch(p.name,/de carrière|\d/);}}
 a.deepEqual(h.s.clubs.map(c=>c.cash),before);a.equal(m.financialPolicy,'descriptive-no-cost-v1');a.equal(m.costs.salary,0);
 const saved=JSON.stringify(h.s);h.d.project();h.d.validate(h.s);a.equal(h.d.initialize(h.s),false);a.equal(JSON.stringify(h.s),saved,'No refill/rewrite after initialization');
});
test('Vue Monde116 persistante : aucun complément fictif promu comme référence, visages stables à la source',()=>{
 const source=staff.forDatabase(database).registry.clubs,w=world(),S={season:1,round:0,phase:'league',club:0,commonDatabase:{id:database},clubs:w.clubs.map(c=>({id:c.id,name:c.name,base:c.base,country:c.country,cash:100000,players:[]}))},h=careerHarness({source,S});h.d.initialize(h.s);const people=h.model().teams.flatMap(t=>t.members),sources=new Map(source.flatMap(c=>c.members.map(p=>[p.id,p])));
 for(const p of people){if(p.sourceKind==='reference')a.notEqual(sources.get(p.sourceStaffId)?.sourceKind,'generated');if(p.generation?.sourceId){const src=sources.get(p.generation.sourceId);a.equal(src.sourceKind,'generated');a.equal(p.name,src.name);a.equal(p.appearanceId,src.appearanceId);a.deepEqual(portrait.describe({...p,portraitRole:'staff'}),portrait.describe({...src,portraitRole:'staff'}));}}
 a.equal(h.d.validate(h.s),true);a.ok(JSON.stringify(h.s.staffCareer).length<4000000);
});
test('Licenciement humain reste effectif après lecture/reprise ; recrutement IA annuel conserve les fonctions',()=>{
 const h=careerHarness({source:[{id:0,members:[{id:'ref:0',name:'Reference Zero',role:'Entraîneur principal',age:52}]},{id:1,members:[{id:'ref:1',name:'Reference One',role:'Médecin',age:76}]}]});h.d.initialize(h.s);const person=h.model().teams[0].members.find(p=>p.sourceKind==='generated'),context={season:1,week:0,club:0};h.d.execute('staff_release',{context,confirmed:true,staffId:person.id});const after=JSON.stringify(h.s),count=h.model().teams[0].members.length;h.box.S=JSON.parse(after);h.d.project();h.d.validate(h.s);a.equal(h.d.initialize(h.s),false);a.equal(h.model().teams[0].members.length,count);a.equal(JSON.stringify(h.s),after);
 const ai=h.s.staffCareer.people.flat().find(p=>p.clubId===1&&C.capabilities(p.roleLabel).includes('doctor'));a.equal(h.d.validate(h.s),true,'Retirement scenario starts from a valid sourced age');
 for(let season=2;season<=8;season++){h.s.season=season;h.d.advance(h.s,season-1);const team=h.model().teams[1];for(const [key,n] of Object.entries(C.MINIMUM))a.ok(C.coverage(team.members)[key]>=n,key+' season'+season);a.ok(!team.members.some(p=>p.id===ai.id),'Retired source identity cannot return');const stable=JSON.stringify(h.s);a.equal(h.d.advance(h.s,season-1),false);a.equal(JSON.stringify(h.s),stable);}
 a.ok(!h.model().teams[0].members.some(p=>p.id===person.id),'The user club is never silently restaffed');
});
function legacyState(){
 const roles=['coach','assistant','formation','scout','analyst','medical','fitness','support'],labels={coach:'Entraîneur',assistant:'Adjoint',formation:'Formation',scout:'Recruteur',analyst:'Analyste'},st={version:1,policy:'staff-career-v1',financialPolicy:'descriptive-no-cost-v1',activatedSeason:1,lastAdvancedSeason:0,serial:0,people:[[]],targets:[{clubId:0,roles:Object.fromEntries(roles.map(r=>[r,roles.slice(0,5).includes(r)?1:0]))}],history:[],captured:[]};
 for(const role of roles.slice(0,5)){const n=++st.serial,id='staff-career:generated:1:'+n,age=30+C.hash(id+':age')%20;st.people[0].push({id,name:labels[role]+' de carrière '+n,role,roleLabel:labels[role],sourceKind:'generated',sourceStaffId:null,sourcePlayerId:null,appearanceId:id,appearanceBankVersion:2,age,appearanceAge:age,ageAtEntry:age,entrySeason:1,ageSeason:1,ageBasis:'estimated',conversion:null,retireAge:68+C.hash(id+':retire')%13,level:45+C.hash(id+':level')%31,salary:0,clubId:0,contractEnd:2});}
 return {season:1,round:0,phase:'league',club:0,clubs:[{id:0,name:'Legacy',base:86,cash:100000,players:[]}],staffCareer:st};
}
test('Ancien cycle actif : schéma/cibles/provenances historiques conservés sans migration implicite',()=>{
 const h=careerHarness({source:[],S:legacyState()}),before=JSON.stringify(h.s);a.equal(h.d.validate(h.s),true);a.equal(h.d.initialize(h.s),false);h.d.project();a.equal(JSON.stringify(h.s),before);a.equal(h.s.staffCareer.completionPolicy,undefined);a.equal(h.model().teams[0].members.length,5);
 const invalid=JSON.parse(before);invalid.staffCareer.completionPolicy='unapproved';a.throws(()=>h.d.validate(invalid));
});
test('Allocation de jeu dans une famille compétente : génériques techniques, prépas et direction, jamais qualification médicale inventée',()=>{
 const coaches=Array.from({length:6},(_,i)=>({id:'c'+i,role:'Entraîneur adjoint'})),fitness=Array.from({length:3},(_,i)=>({id:'f'+i,role:'Préparateur physique'})),support=Array.from({length:2},(_,i)=>({id:'s'+i,role:'Direction et intendance'}));const c=C.coverage(coaches.concat(fitness,support));for(const key of ['assistant','forwards','backs','defence','fitnessLead','conditioning','rehab','teamManager','equipment'])a.equal(c[key],1,key);
 const medical=C.coverage(Array.from({length:8},(_,i)=>({id:'m'+i,role:'Soigneur'})));a.equal(medical.doctor,0);a.equal(medical.physio,0);
});
test('La puissance sportive courante peut franchir les seuils sans recréer les identités ou les cibles initiales',()=>{
 for(const [before,after] of [[71,72],[72,71],[81,82],[82,81]]){
  const S={season:1,round:0,phase:'league',club:0,commonDatabase:{id:'fixture'},clubs:[{id:0,name:'Human',base:65,cash:100000,players:[]},{id:1,name:'AI',base:before,cash:100000,players:[]}]},h=careerHarness({S,source:[]});h.d.initialize(h.s);const identities=JSON.stringify(h.s.staffCareer.people),targets=JSON.stringify(h.s.staffCareer.targets);h.s.clubs[1].base=after;
  a.equal(h.d.validate(h.s),true,before+' -> '+after);a.equal(JSON.stringify(h.s.staffCareer.people),identities);a.equal(JSON.stringify(h.s.staffCareer.targets),targets);
  h.box.S=JSON.parse(JSON.stringify(h.s));a.equal(h.d.validate(h.s),true,'Reopened policy retains creation anchors');h.s.season=2;h.d.advance(h.s,1);a.equal(h.d.validate(h.s),true);a.equal(JSON.stringify(h.s.staffCareer.targets),targets);
 }
});
test('Le marché des nouveaux cycles garde tous les rôles canoniques recrutables',()=>{const h=careerHarness();h.d.initialize(h.s);for(const role of ['coach','assistant','formation','scout','analyst','medical','fitness','support'])a.ok(h.model().candidates.some(p=>p.role===role),'Canonical role '+role);});
test('Les intitulés des références et reconversions restent fidèles à leur provenance sans qualification médicale forgée',()=>{
 const h=careerHarness({source:[{id:0,members:[{id:'ref:medical',name:'Reference Medical',role:'Soigneur',age:45}]},{id:1,members:[]}]});h.d.initialize(h.s);const p=h.s.staffCareer.people.flat().find(p=>p.sourceStaffId==='ref:medical');a.equal(p.roleLabel,'Soigneur');a.equal(h.d.validate(h.s),true);p.roleLabel='Médecin du club';a.throws(()=>h.d.validate(h.s),'A generic healer reference cannot be imported as a doctor');p.roleLabel='Soigneur';
 let retired=null;for(let i=0;i<100&&!retired;i++){const source={id:'source:retired:'+i,name:'Former Player',age:35,rating:80,fam:1,skills:{mental:75},dev:{careerMinutes:2000}};if(h.d.captureRetirement(h.s,source,0))retired=h.s.staffCareer.people.flat().find(p=>p.sourcePlayerId===source.id);}a.ok(retired);a.equal(h.d.validate(h.s),true);retired.roleLabel='Médecin du club';a.throws(()=>h.d.validate(h.s),'A former player cannot invent a clinical qualification through roleLabel');
});
test('Une provenance générée annuelle exige un sourceId null explicite, sans variante vide',()=>{const h=careerHarness();h.d.initialize(h.s);const p=h.s.staffCareer.people.flat().find(p=>p.generation?.sourceId===null);p.generation.sourceId='';a.throws(()=>h.d.validate(h.s));});
test('Le libellé S&C assaini pour la sauvegarde reste une préparation physique',()=>{a.equal(C.role('S et C Coach'),'fitness');a.ok(C.capabilities('S et C Coach').includes('conditioning'));a.equal(C.capabilities('S et C Coach').includes('defence'),false);});
test('Ancien cycle sans complétion : les libellés historiques restent compatibles',()=>{
 const S=legacyState(),ref={id:'reference:legacy',name:'Legacy Coach',role:'Entraîneur',age:50},p=S.staffCareer.people[0][0];S.commonDatabase={id:'fixture'};Object.assign(p,{id:'staff-career:reference:'+ref.id,name:ref.name,roleLabel:'Libellé hérité',sourceKind:'reference',sourceStaffId:ref.id,appearanceId:ref.id,age:50,appearanceAge:50,ageAtEntry:50,ageBasis:'published-derived',retireAge:68+C.hash('staff-career:reference:'+ref.id+':retire')%13,level:45+C.hash(ref.id+':level')%31});delete p.appearanceBankVersion;
 const h=careerHarness({S,source:[{id:0,members:[ref]}]}),before=JSON.stringify(S);a.equal(h.d.validate(S),true);h.d.project();a.equal(JSON.stringify(S),before);
});
test('Le relevé livré par club correspond exactement à la vue composée et distingue les fiches historiques',()=>{
 const report=require('../docs/staff-completion-20261110.json');a.equal(report.policy,C.POLICY);a.equal(report.financialPolicy,'descriptive-no-cost-v1');
 for(const edition of report.editions){const selected=staff.forDatabase(edition.id);a.equal(edition.clubs.length,selected.registry.clubs.length);for(const row of edition.clubs){const raw=selected.referenceRegistry.clubs[row.id],current=selected.registry.clubs[row.id],added=current.members.filter(p=>p.sourceKind==='generated'),functions={};for(const p of added)functions[p.completion.function]=(functions[p.completion.function]||0)+1;a.equal(row.before,raw.members.filter(p=>!p.historical).length);a.equal(row.historical,raw.members.filter(p=>p.historical).length);a.equal(row.after,current.members.filter(p=>!p.historical).length);a.equal(row.added,added.length);a.deepEqual(row.addedByFunction,functions);a.deepEqual(row.coverageAfter,C.coverage(current.members));}a.equal(edition.before,edition.clubs.reduce((n,c)=>n+c.before,0));a.equal(edition.after,edition.clubs.reduce((n,c)=>n+c.after,0));a.equal(edition.added,edition.after-edition.before);}
});
