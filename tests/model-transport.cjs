'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const source=path.join(__dirname,'../native/engine/model-transport.cjs');
test('le transport différentiel doit être disponible',()=>assert.ok(fs.existsSync(source)));
if(fs.existsSync(source)){
 const {createTransport,apply}=require(source);
 test('reconstruction exacte, suppressions et petites réponses après le premier modèle',()=>{
  const t=createTransport(),large=Array.from({length:3000},(_,id)=>({id,name:'Joueur '+id}));
  const one={protocol:1,meta:{exportText:'transitoire',week:1},clubLife:{market:{players:large},press:{required:true}},live:{minute:3}};
  const full=t.encode({id:1,ok:true,model:one},{version:1,base:0});assert.equal(full.transport.full,true);
  const two=structuredClone(one);delete two.meta.exportText;two.clubLife.press.required=false;two.live.minute=4;
  const patch=t.encode({id:2,ok:false,error:'Refus',model:two},{version:1,base:full.transport.revision});
  assert.equal(patch.transport.full,false);assert.equal(patch.error,'Refus');assert.ok(JSON.stringify(patch).length<1000);
  const restored=apply(one,full.transport.revision,patch);assert.deepEqual(restored,two);assert.equal(one.meta.exportText,'transitoire');
  const unchanged=t.encode({id:3,ok:true,model:two},{version:1,base:patch.transport.revision});assert.deepEqual(unchanged.modelPatch,{set:[],remove:[]});
 });
 test('une révision absente ou perdue reprend le modèle entier ; client historique intact',()=>{
  const t=createTransport(),r={id:1,ok:true,model:{meta:{week:1}}};assert.deepEqual(t.encode(r),r);
  const a=t.encode(r,{version:1,base:0}),b=t.encode(r,{version:1,base:a.transport.revision+8});assert.equal(b.transport.full,true);
  const c=t.encode(r,{version:1,base:b.transport.revision});assert.throws(()=>apply({},0,c),/révision/);
  assert.deepEqual(t.encode({id:4,ok:false,model:null},{version:1,base:c.transport.revision}),{id:4,ok:false,model:null});
 });
 test('les branches disparues, les valeurs null et les dictionnaires vides ne gardent rien de la carrière précédente',()=>{
  const t=createTransport(),a={id:1,ok:true,model:{clubLife:{old:{id:1}},live:{minute:2},meta:{receipt:{id:1}}}};
  const full=t.encode(a,{version:1,base:0}),b={clubLife:{},live:null,meta:{}};
  const patch=t.encode({id:2,ok:true,model:b},{version:1,base:full.transport.revision});assert.deepEqual(apply(a.model,full.transport.revision,patch),b);
 });
 test('une branche top-level supprimée ne laisse pas de dictionnaire vide résiduel',()=>{
  const t=createTransport(),one={receipt:{command:'saved'},meta:{week:1}},two={meta:{week:1}};
  const a=t.encode({id:1,ok:true,model:one},{version:1,base:0}),b=t.encode({id:2,ok:true,model:two},{version:1,base:a.transport.revision});assert.deepEqual(apply(one,a.transport.revision,b),two);
 });
}
