'use strict';
// Réponses différentielles du pont Godot : seules les parties du modèle qui ont
// changé depuis la dernière réponse reçue par l'interface sont transmises.
// Présentation seule : le modèle complet est calculé exactement comme avant, puis
// découpé ; l'interface reconstruit un modèle identique (mêmes clés, même ordre).
// L'interface annonce la révision qu'elle détient (`base`) ; sans révision
// concordante, la réponse redevient complète.
const NESTED=new Set(['clubLife','meta','staff','decisions']);
const plain=value=>!!value&&typeof value==='object'&&!Array.isArray(value);

function createEncoder(){
 let revision=0,sent=null;
 // Retourne la ligne JSON complète de la réponse (sans saut de ligne).
 function encode(result,base){
  if(!plain(result)||!plain(result.model))return JSON.stringify(result);
  const model=result.model,next=new Map(),keys=[],set=[],sub=[];
  const incremental=sent!==null&&base===revision;
  for(const key of Object.keys(model)){
   const value=model[key];
   if(NESTED.has(key)&&plain(value)){
    const previous=incremental&&sent.get(key) instanceof Map?sent.get(key):null;
    const inner=new Map(),innerKeys=[],innerSet=[];
    for(const name of Object.keys(value)){
     const text=JSON.stringify(value[name]);
     if(text===undefined)continue;
     inner.set(name,text);innerKeys.push(name);
     if(!previous||previous.get(name)!==text)innerSet.push(JSON.stringify(name)+':'+text);
    }
    next.set(key,inner);keys.push(key);
    sub.push(JSON.stringify(key)+':{"keys":'+JSON.stringify(innerKeys)+',"set":{'+innerSet.join(',')+'}}');
   }else{
    const text=JSON.stringify(value);
    if(text===undefined)continue;
    next.set(key,text);keys.push(key);
    const previous=incremental?sent.get(key):undefined;
    if(typeof previous!=='string'||previous!==text)set.push(JSON.stringify(key)+':'+text);
   }
  }
  revision++;sent=next;
  const head={...result};delete head.model;
  const patch='{"rev":'+revision+',"full":'+!incremental+',"keys":'+JSON.stringify(keys)+',"set":{'+set.join(',')+'},"sub":{'+sub.join(',')+'}}';
  const prefix=JSON.stringify(head);
  return prefix.slice(0,-1)+(prefix.length>2?',':'')+'"patch":'+patch+'}';
 }
 // Reconstruction de référence (tests) : même algorithme que le pont Godot.
 function apply(base,patch){
  const model={};
  for(const key of patch.keys){
   if(Object.hasOwn(patch.sub,key)){
    const part=patch.sub[key],before=!patch.full&&plain(base?.[key])?base[key]:{},inner={};
    for(const name of part.keys)inner[name]=Object.hasOwn(part.set,name)?part.set[name]:before[name];
    model[key]=inner;
   }else model[key]=Object.hasOwn(patch.set,key)?patch.set[key]:base[key];
  }
  return model;
 }
 return {encode,apply,revision:()=>revision,reset(){sent=null;}};
}
module.exports={createEncoder,NESTED};
