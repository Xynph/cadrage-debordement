'use strict';
// Sauvegarde et validation par sections (chantier sauvegarde incrémentale, lot 3, 13/11/2026).
// 1. safeTree : une section reprise de la mémoire de validation donne le même verdict qu'un parcours
//    complet ; toute section au texte changé est reparcourue ; les plafonds de nœuds restent globaux.
// 2. Carrière Monde réelle (vérification interne activée) : textes par section identiques au texte
//    complet, profil identique à JSON.stringify, refus d'import trafiqué, reprise exacte.
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path'),vm=require('node:vm');

function treeContext(maxNodes){
 const ctx=vm.createContext({JSON,Math:Object.create(Math)});
 vm.runInContext(fs.readFileSync(path.join(__dirname,'../dist/saves.js'),'utf8'),ctx,{timeout:10000});
 ctx.CDWorldCareer={active:()=>true,edition:()=>({limits:{maxSaveNodes:maxNodes}}),sizing:()=>({clubCount:116,maxRound:30,rounds:26})};
 vm.runInContext('var armed=null,cache=new Map(),texts=null;function nativeSafeTreeSections(root){return root===armed?{texts,cache}:null;}',ctx);
 return {
  ctx,
  // Parcours « juste après une sauvegarde » : textes des sections calculés depuis l'état.
  saved(state){ctx.candidate=state;vm.runInContext('armed=candidate;texts=new Map(Object.entries(candidate).map(([k,v])=>[k,JSON.stringify(v)]).filter(([,t])=>t!==undefined));',ctx);try{return vm.runInContext('safeTree(candidate)',ctx);}finally{vm.runInContext('armed=null',ctx);}},
  full(state){ctx.candidate=state;return vm.runInContext('safeTree(candidate)',ctx);},
  cached(){return JSON.parse(vm.runInContext('JSON.stringify([...cache.keys()])',ctx));}
 };
}
const big=n=>Array.from({length:n},(_,i)=>({id:'p'+i,v:i}));

test('safeTree : sections reprises, reparcourues si leur texte change, plafond global conservé',()=>{
 const t=treeContext(1000);
 const state={club:0,a:{rows:big(100)},b:{rows:big(100)},interclubWorld:{pairs:{}}};
 t.saved(state);assert.deepEqual(t.cached().sort(),['a','b','club','interclubWorld']);
 // Section changée avec un texte interdit : refusée même si les autres sont reprises.
 state.b.rows[3].v='<script>';assert.throws(()=>t.saved(state),/texte non autorisé/);
 state.b.rows[3].v=3;t.saved(state);
 // Plafond de nœuds : les sections reprises comptent toujours (≈ 300 nœuds chacune).
 state.c={rows:big(150)};assert.throws(()=>t.saved(state),/trop complexe/,'le total dépasse 1 000 nœuds');
 assert.throws(()=>t.full(state),/trop complexe/,'même verdict que le parcours complet');
 delete state.c;t.saved(state);
 // Contexte différent (autre plafond) : rien n'est repris, les sections sont reparcourues.
 const small=treeContext(1000);small.saved(state);
 small.ctx.CDWorldCareer.edition=()=>({limits:{maxSaveNodes:500}});assert.throws(()=>small.saved(state),/trop complexe/);
 // Clé interdite au premier niveau : refusée même quand la section est déjà connue.
 const hostile=JSON.parse('{"club":0,"__proto__":{"x":1}}');assert.throws(()=>t.saved(hostile),/structure non autorisée/);
 // Hors sauvegarde (import, chargement), le parcours reste complet et n'utilise pas la mémoire.
 assert.doesNotThrow(()=>t.full(state));
});

test('carrière Monde : sections identiques au texte complet, import trafiqué refusé, reprise exacte',()=>{
 const {createBridge}=require('../native/engine/worker.cjs'),{settleClubMeetings}=require('./helpers/club-meetings.cjs');
 const root=fs.mkdtempSync(path.join(os.tmpdir(),'cd-inc-sections-'));let b,n=0;
 const open=()=>createBridge({dataDir:root,seed:43,now:1794178800000,verifyCleanCopy:true});
 const raw=(command,payload={})=>b.handle({id:++n,command,payload});
 const good=(command,payload={})=>{const r=raw(command,payload);assert.equal(r.ok,true,command+': '+r.error);return r.model;};
 try{
  b=open();let m=settleClubMeetings(good('new_career',{mode:'world-champ',club:0}),good);
  const file=path.join(m.meta.dataDir,'donnees.json'),tactics=m.tactics.attacks.map(t=>t.id);
  for(let i=0;i<3;i++)m=good('set_tactics',{attack:tactics[(i+1)%tactics.length],defense:m.tactics.defense});
  const text=fs.readFileSync(file,'utf8'),parsed=JSON.parse(text);
  assert.equal(text,JSON.stringify({protocol:1,seed:parsed.seed,clock:parsed.clock,store:parsed.store}));
  if(m.next){if(!m.selection.valid){good('auto_lineup');if(!good('snapshot').selection.valid)good('promote_cover',{confirmed:true});}good('begin_match');good('delegate');}
  m=settleClubMeetings(good('finish_round'),good);
  m=good('set_tactics',{attack:tactics[0],defense:m.tactics.defense});
  const saved=good('export').meta.exportText;
  // Import trafiqué : refusé, carrière ouverte intacte.
  const doc=JSON.parse(saved);doc.state.clubs[3].players[0].name='<b>';
  const refused=raw('import',{text:JSON.stringify(doc)});assert.equal(refused.ok,false);
  assert.equal(good('export').meta.exportText,saved);
  b.close();b=open();assert.equal(good('export').meta.exportText,saved,'reprise exacte après redémarrage');
  good('import',{text:saved});assert.equal(good('export').meta.exportText,saved);
 }finally{b?.close();fs.rmSync(root,{recursive:true,force:true});}
});
