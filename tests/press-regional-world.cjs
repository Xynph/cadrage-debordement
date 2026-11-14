'use strict';
// Presse locale du mode Monde : chaque club est suivi par les journalistes et les
// rédactions de son pays. La presse française reste exactement celle d'avant pour
// les clubs français ; les autres championnats ont leurs propres rédactions.
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),os=require('node:os'),vm=require('node:vm');
const bank=require('../dist/press-question-bank.js'),pressIds=require('../native/engine/press-identities.cjs'),staff=require('../native/engine/staff.cjs');
const {createBridge}=require('../native/engine/worker.cjs'),privees=require('../scripts/sources-privees.cjs');
const ext=require('../native/engine/world-pacific-registry.cjs'),engine=path.join(__dirname,'../native/engine');
const json=f=>JSON.parse(fs.readFileSync(path.join(engine,f),'utf8'));
const champ=ext.extendChampRegistry(ext.extendNationaleRegistry(ext.extendJapanRegistry(ext.extendWorldRegistry(json('world-registry.json'),json('world-pacific-extension.json')),json('world-japan-extension.json')),json('world-nationale-extension.json')),json('world-champ-extension.json'));
const fold=t=>String(t).normalize('NFKD').replace(/[̀-ͯ]/g,'').toLowerCase().replace(/[^a-z0-9]+/g,' ').trim();

(function catalogue(){
 assert.equal(bank.validate(),true);
 const regions=Object.keys(bank.regions);
 assert.deepEqual(regions,['fr','en','ie','sco','wal','it','za','ge','nz','au','pac','jp']);
 // Identifiants stables, compris par la rubrique `press` des packs.
 const cat=pressIds.defaultCatalogue();
 assert.equal(cat.journalists.size,bank.journalists.length);
 for(let i=10;i<=51;i++)assert.ok(cat.journalists.has('presse-'+i),'presse-'+i);
 for(let i=10;i<=31;i++)assert.ok(cat.outlets.has('redaction-'+i),'redaction-'+i);
 // Les 30 journalistes français et leurs 10 rédactions, dans le même ordre qu'avant.
 assert.deepEqual(bank.journalistsFor('fr').map(j=>j.id),[...Array(10).keys()].map(i=>'presse-'+i).concat([...Array(20).keys()].map(i=>'fiction-'+i)));
 for(const region of regions){
  const list=bank.journalistsFor(region),outlets=new Set(list.map(j=>j.outletId));
  assert.ok(list.length>=3&&outlets.size>=2,region+' : au moins trois journalistes et deux rédactions');
  assert.equal(new Set(list.flatMap(j=>j.specialties)).size,25,region+' : tous les thèmes de conférence couverts');
  assert.ok(list.every(j=>j.region===region&&j.fictional===true&&j.source===undefined));
  for(const other of regions)if(other!==region)assert.ok(bank.journalistsFor(other).every(j=>!outlets.has(j.outletId)),region+' : rédaction propre');
 }
 assert.equal(bank.journalistsFor('inconnue'),bank.journalistsFor('fr'),'région inconnue : presse française');
 // Le remplacement d'affichage se fait par nom : aucun nom de presse n'est celui d'un club,
 // d'un joueur ou d'un membre du staff de l'édition Monde, ni d'une autre entrée de presse.
 const taken=new Set([...champ.clubs.map(c=>c.name),...champ.clubs.flatMap(c=>c.players.map(p=>p.name)),...staff.forDatabase(champ.id).registry.clubs.flatMap(c=>c.members.map(p=>p.name))]);
 const names=[...bank.journalists.map(j=>j.name),...cat.outlets.values()];
 assert.equal(new Set(names.map(fold)).size,names.length,'noms de presse distincts');
 for(const n of names)assert.ok(!taken.has(n),n+' : nom distinct des clubs et des personnes');
 // Contrôle d'écart avec la presse réelle du pack privé, quand le dépôt privé est présent.
 const real=privees.locate('pack/journalistes.json');
 if(real){
  const doc=JSON.parse(fs.readFileSync(real,'utf8')).press,realNames=new Set([...(doc.journalists||[]),...(doc.outlets||[])].map(x=>fold(x.name)));
  for(const n of names)assert.ok(!realNames.has(fold(n)),n+' : nom de la presse réelle');
  assert.ok(pressIds.ingest(doc,cat).counts.journalists>=10,'rubrique privée acceptée par le jeu');
 }else console.warn('Dépôt privé absent : écart avec la presse réelle non contrôlé.');
})();

(function clubs(){
 // Chaque club du Monde a une presse locale ; le championnat britannique est départagé par fédération.
 const count={};
 for(const club of champ.clubs){const r=bank.regionOf(club);count[r]=(count[r]||0)+1;}
 assert.deepEqual(count,{fr:44,en:24,ie:4,sco:2,wal:4,it:2,za:5,ge:1,nz:5,au:4,pac:1,jp:20});
 const bySlug=Object.fromEntries(champ.clubs.map(c=>[c.slug,bank.regionOf(c)]));
 assert.equal(bySlug['urc-ulster'],'ie');assert.equal(bySlug['urc-glasgow'],'sco');assert.equal(bySlug['urc-scarlets'],'wal');assert.equal(bySlug['prem-bath'],'en');
 for(const club of champ.clubs.filter(c=>['elite','accession','nationale'].includes(c.leagueId)))assert.equal(bank.regionOf(club),'fr',club.slug);
 for(const club of champ.clubs.filter(c=>['jlo-d1','jlo-d2'].includes(c.leagueId)))assert.equal(bank.regionOf(club),'jp',club.slug);
 for(const club of champ.clubs.filter(c=>c.leagueId==='champ'))assert.equal(bank.regionOf(club),'en',club.slug);
})();

(function chroniques(){
 // Fil d'actualité : chaque chronique d'un club est signée par la presse de son pays.
 const ctx=vm.createContext({CDNativeHeadless:true,console});
 ctx.CDWorldCareer={active:()=>true,edition:()=>({registry:{clubs:champ.clubs}})};
 for(const f of ['press-question-bank.js','media-world-v60.js','rugby-broadcast.js'])vm.runInContext(fs.readFileSync(path.join(__dirname,'../dist',f),'utf8'),ctx);
 const local=new Map(Object.keys(bank.regions).map(r=>[r,new Set(bank.journalistsFor(r).map(j=>j.name))]));
 let seen=0;
 for(let week=0;week<12;week++){
  const s={season:1,round:week,club:44,morale:60,clubs:champ.clubs.map(c=>({id:c.id,name:c.name}))};
  for(const a of ctx.CDMediaWorld.headlines(s)){assert.ok(local.get(bank.regionOf(champ.clubs[a.clubId])).has(a.byline.name),a.title);seen++;}
  for(const g of ctx.CDRugbyBroadcast.generate(s).segments)assert.ok(local.get('sco').has(g.journalist.name),'magazine : presse du club');
 }
 assert.ok(seen>=80);
})();

const root=fs.mkdtempSync(path.join(os.tmpdir(),'cd-presse-locale-'));
let b,seq=0;
const good=(command,payload={})=>{const r=b.handle({id:++seq,command,payload});assert.equal(r.ok,true,command+': '+r.error);return r.model;};
try{
 // Club français, anglais, écossais, irlandais (Ulster), japonais, fidjien.
 for(const [club,region] of [[3,'fr'],[30,'en'],[44,'sco'],[42,'ie'],[68,'jp'],[62,'pac'],[58,'nz'],[52,'za']]){
  b?.close();b=createBridge({dataDir:fs.mkdtempSync(path.join(root,'c')),seed:4242,now:1700000000000});
  const m=good('new_career',{mode:'world-champ',club}),press=m.clubLife.press,ids=new Set(bank.journalistsFor(region).map(j=>j.id));
  assert.equal(press.conference.available,true,club+' : conférence disponible');
  assert.ok(press.conference.questions.every(q=>ids.has(q.journalist.id)),club+' : questions de la presse '+region);
  assert.equal(new Set(press.conference.questions.map(q=>q.journalist.id)).size,press.conference.questions.length,club+' : un journaliste par question');
  assert.deepEqual(press.people.map(p=>p.id),[...ids],club+' : annuaire de la presse locale');
 }
 // Conférence tenue avec un club écossais, puis mémoire au-delà de trente contacts.
 b.close();b=createBridge({dataDir:fs.mkdtempSync(path.join(root,'c')),seed:4242,now:1700000000000});
 let m=good('new_career',{mode:'world-champ',club:44});
 m=good('press_conference',{context:m.clubLife.press.context,answers:m.clubLife.press.conference.questions.map(q=>({questionId:q.id,answerId:'r1'}))});
 const met=m.clubLife.press.people.filter(p=>p.encounters>0);assert.ok(met.length>=2&&met.every(p=>p.region==='sco'));
 assert.ok(m.clubLife.press.history.every(h=>bank.journalistsFor('sco').some(j=>j.id===h.journalist.id&&j.name===h.journalist.name&&j.outlet===h.journalist.outlet)));
 // Un coach qui a rencontré toute la presse du Monde garde une sauvegarde valide.
 const doc=JSON.parse(good('export').meta.exportText),s=doc.state;
 for(const j of bank.journalists)if(!s.pressPeople.contacts[j.id])s.pressPeople.contacts[j.id]={score:1,encounters:1,memory:[{season:1,week:0,club:44,questionId:'phase_finale-4-0',answerId:'r4',delta:1}]};
 {const text=JSON.stringify(s);let h=2166136261;for(let i=0;i<text.length;i++)h=Math.imul(h^text.charCodeAt(i),16777619);doc.checksum=(h>>>0).toString(16).padStart(8,'0');}
 m=good('import',{text:JSON.stringify(doc)});
 assert.equal(Object.keys(JSON.parse(good('export').meta.exportText).state.pressPeople.contacts).length,bank.journalists.length);
 // L'annuaire montre la presse locale et les journalistes déjà rencontrés ailleurs.
 assert.equal(m.clubLife.press.people.length,bank.journalists.length);
 console.log('Presse locale Monde : '+bank.journalists.length+' journalistes, '+Object.keys(bank.regions).length+' pays, conférences, chroniques, magazine, annuaire et mémoire PASS.');
}finally{b?.close();fs.rmSync(root,{recursive:true,force:true});}
