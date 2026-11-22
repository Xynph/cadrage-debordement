'use strict';
// Rubrique « talents » des packs d'identités (pack-talents.cjs) : potentiels relevés et joueurs ajoutés, appliqués
// à la création d'une carrière Monde par identifiants seulement. Pack d'exemple fictif (aucune donnée réelle).
const {settleClubMeetings}=require('./helpers/club-meetings.cjs');
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),os=require('node:os');
const media=require('../native/engine/media-packs.cjs'),{createBridge}=require('../native/engine/worker.cjs');
const root=fs.mkdtempSync(path.join(process.env.CD_WORLD_TEST_ROOT||os.tmpdir(),'cd-pack-talents-'));let seq=0;
function archive(manifest){
 const items=[['pack.json',Buffer.from(JSON.stringify(manifest))]];let offset=0;const blocks=[],central=[];
 for(const [name,data]of items){const n=Buffer.from(name),l=Buffer.alloc(30),c=Buffer.alloc(46),crc=media.crc32(data);l.writeUInt32LE(0x04034b50);l.writeUInt16LE(20,4);l.writeUInt16LE(0x800,6);l.writeUInt32LE(crc,14);l.writeUInt32LE(data.length,18);l.writeUInt32LE(data.length,22);l.writeUInt16LE(n.length,26);c.writeUInt32LE(0x02014b50);c.writeUInt16LE(20,4);c.writeUInt16LE(20,6);c.writeUInt16LE(0x800,8);c.writeUInt32LE(crc,16);c.writeUInt32LE(data.length,20);c.writeUInt32LE(data.length,24);c.writeUInt16LE(n.length,28);c.writeUInt32LE(offset,42);blocks.push(l,n,data);central.push(c,n);offset+=30+n.length+data.length;}
 const cd=Buffer.concat(central),end=Buffer.alloc(22);end.writeUInt32LE(0x06054b50);end.writeUInt16LE(items.length,8);end.writeUInt16LE(items.length,10);end.writeUInt32LE(cd.length,12);end.writeUInt32LE(offset,16);
 const file=path.join(root,'pack-'+(++seq)+'.zip');fs.writeFileSync(file,Buffer.concat([...blocks,cd,end]));return file;
}
const mode='world-champ',CLUB=39,SEED=4823;
function session(dir){
 const b=createBridge({dataDir:path.join(root,dir),seed:SEED,now:1788134400000});
 const raw=(command,payload={})=>b.handle({id:++seq,command,payload});
 const good=(command,payload={})=>{const r=raw(command,payload);assert.equal(r.ok,true,command+' : '+r.error);return r.model;};
 const settle=m=>settleClubMeetings(m,(c,p)=>good(c,p));
 const state=()=>JSON.parse(good('export').meta.exportText).state;
 return {b,raw,good,settle,state};
}
const players=s=>new Map(s.clubs.flatMap(c=>c.players.map(p=>[p.id,{...p,clubId:c.id}])));

test('Rubrique talents : potentiels relevés et joueurs ajoutés à la création, la note ne bouge pas',()=>{
 // Carrière de référence, sans pack (même graine).
 const base=session('base');let baseState;
 try{base.settle(base.good('new_career',{mode,club:CLUB}));baseState=base.state();}finally{base.b.close();}
 const before=players(baseState);
 // Trois jeunes du club joué et un jeune d'un autre club : identifiants publics, hausses fictives.
 const pick=club=>[...before.values()].filter(p=>p.clubId===club&&p.age<=22&&p.dev.potential<=84&&!/^depth-/.test(p.id)).sort((a,b)=>a.id<b.id?-1:1);
 const young=pick(CLUB).slice(0,3),other=pick(0)[0];
 assert.equal(young.length,3);assert.ok(other);
 const potentials={[young[0].id]:[6,99],[young[1].id]:[4,40],[young[2].id]:[0,99],[other.id]:[8,99]};
 const added=[
  {id:'pack:temoin-1',clubId:CLUB,position:'Ailier',birthYear:2006,nation:'FIJ',statut:'jeune',u20:1,potential:[5,99]},
  {id:'pack:temoin-2',clubId:0,position:'Demi d’ouverture',birthYear:2008,statut:'rotation',u20:0},
 ];
 const s=session('pack');
 try{
  let m=s.settle(s.good('new_career',{mode,club:CLUB}));
  const databaseId=m.meta.champDatabase.id;
  const manifest={schema:'cd-identity-pack-v2',id:'temoin-talents',name:'Témoin talents',version:'1',databaseId,rightsStatus:'test-local',clubs:[],
   players:[{id:'pack:temoin-1',name:'Ailier Témoin'},{id:'pack:temoin-2',name:'Ouvreur Témoin'}],staff:[],assets:[],talents:{potentials,added}};
  // Refus : joueur inconnu, poste inconnu, identifiant hors format, hausse trop forte, nom sans joueur ajouté.
  for(const bad of [
   {...manifest,talents:{potentials:{'world:inconnu':[2,90]},added}},
   {...manifest,talents:{added:[{...added[0],position:'Pilier'},added[1]]}},
   {...manifest,talents:{added:[{...added[0],id:'world:prem:1'},added[1]]}},
   {...manifest,talents:{potentials:{[young[0].id]:[11,99]},added}},
   {...manifest,talents:{potentials}},
  ])assert.equal(s.raw('pack_inspect',{path:archive(bad),mode}).ok,false,JSON.stringify(bad.talents).slice(0,80));
  const zip=archive(manifest),preview=s.good('pack_inspect',{path:zip,mode}).packs.preview;
  assert.equal(preview.counts.talentPotentials,4);assert.equal(preview.counts.talentAdditions,2);
  s.good('pack_install',{path:zip,digest:preview.digest,mode});
  s.settle(s.good('pack_select',{scope:'creation',id:preview.id,mode}));
  m=s.settle(s.good('new_career',{mode,club:CLUB}));
  const st=s.state(),after=players(st);
  assert.equal(st.identityPack.id,preview.id);
  // Les joueurs de la base gardent leur note ; seuls les potentiels listés montent, sans baisse.
  for(const [id,p]of before){
   const q=after.get(id);if(/^depth-/.test(id)&&!q)continue;
   assert.ok(q,id);assert.equal(q.rating,p.rating,'note de '+id);
   if(!potentials[id])assert.equal(q.dev.potential,p.dev.potential,'potentiel de '+id);
  }
  assert.equal(after.get(young[0].id).dev.potential,Math.min(99,young[0].dev.potential+6));
  assert.equal(after.get(young[1].id).dev.potential,young[1].dev.potential,'plafond sous le potentiel : aucune baisse');
  assert.equal(after.get(young[2].id).dev.potential,young[2].dev.potential);
  assert.equal(after.get(other.id).dev.potential,Math.min(99,other.dev.potential+8));
  // Joueurs ajoutés : dans leur club, poste et âge du pack, nom inventé dans la sauvegarde, nom du pack à l'écran.
  const a1=after.get('pack:temoin-1'),a2=after.get('pack:temoin-2');
  assert.equal(a1.clubId,CLUB);assert.equal(a2.clubId,0);
  assert.equal(a1.pos,'Ailier');assert.equal(a1.age,20);assert.equal(a2.pos,'Demi d’ouverture');assert.equal(a2.age,18);
  assert.notEqual(a1.name,'Ailier Témoin');
  assert.ok(a1.rating>=40&&a1.rating<a1.dev.potential&&a1.dev.potential<=99,JSON.stringify([a1.rating,a1.dev.potential]));
  const row=m.squad.find(p=>p.id==='pack:temoin-1');
  assert.ok(row,'joueur ajouté dans l’effectif');
  assert.equal(row.name,'Ailier Témoin');assert.equal(row.playerFacts.nationality,'Fidji');
  // La carrière se sauvegarde, se relit et avance.
  const text=s.good('export').meta.exportText;
  m=s.settle(s.good('import',{text}));
  for(let i=0;i<3;i++)m=s.settle(s.good('advance_day',{fromDate:m.meta.calendarToday}));
  assert.ok(players(s.state()).has('pack:temoin-1'));
 }finally{s.b.close();}
});

test('Pack sans rubrique talents : effectifs identiques au jeu de base',()=>{
 const s=session('sans');
 try{
  let m=s.settle(s.good('new_career',{mode,club:CLUB}));const before=s.state();
  const manifest={schema:'cd-identity-pack-v2',id:'temoin-sans',name:'Témoin sans talents',version:'1',databaseId:m.meta.champDatabase.id,rightsStatus:'test-local',clubs:[],players:[],staff:[],assets:[]};
  const zip=archive(manifest),preview=s.good('pack_inspect',{path:zip,mode}).packs.preview;
  assert.equal(preview.counts.talentPotentials,undefined);
  s.good('pack_install',{path:zip,digest:preview.digest,mode});
  s.settle(s.good('pack_select',{scope:'creation',id:preview.id,mode}));
  m=s.settle(s.good('new_career',{mode,club:CLUB}));
  assert.deepEqual(s.state().clubs,before.clubs);
 }finally{s.b.close();fs.rmSync(root,{recursive:true,force:true});}
});
