'use strict';
// Réponses différentielles du pont Godot : seules les parties du modèle qui ont
// changé depuis la dernière réponse reçue par l'interface sont transmises.
// Présentation seule : le modèle complet est calculé exactement comme avant, puis
// découpé ; l'interface reconstruit un modèle identique (mêmes clés, même ordre).
// L'interface annonce la révision qu'elle détient (`base`) ; sans révision
// concordante, la réponse redevient complète.
//
// Lot 19 (réactivité) :
// - `live` est découpé comme `clubLife` : en match, seules les parties du direct qui ont changé partent (même format,
//   déjà appliqué tel quel par engine_bridge.gd pour toute clé présente dans `sub`).
// - Textes joints (symbole TEXTS, posé par projection-sections.cjs) : le texte de chaque section est déjà connu du
//   moteur ; il n'est pas recalculé (les sections reprises d'une réponse à l'autre sont la même chaîne, comparée sans
//   la parcourir).
// - Réponse « inchangée » (symbole UNCHANGED, commande refusée sans effet) : un patch sans aucune section modifiée,
//   que l'interface applique comme les autres ; à défaut de révision concordante, le modèle complet est calculé par la
//   fonction jointe (symbole FALLBACK) et la réponse redevient complète.
const NESTED=new Set(['clubLife','meta','staff','decisions','live']);
const TEXTS=Symbol.for('cd.sectionTexts'),UNCHANGED=Symbol.for('cd.unchanged'),FALLBACK=Symbol.for('cd.fallbackModel');
const plain=value=>!!value&&typeof value==='object'&&!Array.isArray(value);
const verify=()=>process.env.CD_VERIFIER_PROJECTION==='1';

// Réponse complète d'une réponse « inchangée » (protocole sans révision, ou révision qui ne concorde pas).
function materialize(result){
 if(!result||!result[UNCHANGED])return result;
 const out={};for(const key of Object.keys(result))out[key]=result[key];
 out.model=typeof result[FALLBACK]==='function'?result[FALLBACK]():null;
 return out;
}
// Textes des sections d'un modèle, découpés comme l'encodeur : {keys, items: Map(clé → texte | {keys, texts})}.
function sectionTexts(model){
 const keys=[],items=new Map();
 for(const key of Object.keys(model)){
  const value=model[key];
  if(NESTED.has(key)&&plain(value)){
   const inner={keys:[],texts:new Map()};
   for(const name of Object.keys(value)){const text=JSON.stringify(value[name]);if(text===undefined)continue;inner.keys.push(name);inner.texts.set(name,text);}
   keys.push(key);items.set(key,inner);
  }else{const text=JSON.stringify(value);if(text===undefined)continue;keys.push(key);items.set(key,text);}
 }
 return {keys,items};
}
function checkTexts(model,joined){
 const fresh=sectionTexts(model),flat=s=>{const m=new Map([['/',s.keys.join('\u0000')]]);for(const key of s.keys){const item=s.items.get(key);if(typeof item==='string')m.set(key,item);else{m.set(key+'/',item.keys.join('\u0000'));for(const name of item.keys)m.set(key+'.'+name,item.texts.get(name));}}return m;};
 const a=flat(fresh),b=flat(joined);
 for(const key of new Set([...a.keys(),...b.keys()]))if(a.get(key)!==b.get(key))throw Error('Texte de section joint différent du modèle : '+key+'.');
}

function createEncoder(){
 let revision=0,sent=null;
 // Retourne la ligne JSON complète de la réponse (sans saut de ligne).
 function encode(result,base){
  if(result&&result[UNCHANGED]){
   if(sent!==null&&base===revision)return unchanged(result);
   result=materialize(result);
  }
  if(!plain(result)||!plain(result.model))return JSON.stringify(result);
  const model=result.model,joined=model[TEXTS];
  if(joined&&verify())checkTexts(model,joined);
  const sections=joined||sectionTexts(model);
  const next=new Map(),keys=[],set=[],sub=[];
  const incremental=sent!==null&&base===revision;
  for(const key of sections.keys){
   const item=sections.items.get(key);
   if(typeof item!=='string'){
    const previous=incremental&&sent.get(key) instanceof Map?sent.get(key):null;
    const inner=new Map(),innerSet=[];
    for(const name of item.keys){
     const text=item.texts.get(name);
     inner.set(name,text);
     if(!previous||previous.get(name)!==text)innerSet.push(JSON.stringify(name)+':'+text);
    }
    next.set(key,inner);keys.push(key);
    sub.push(JSON.stringify(key)+':{"keys":'+JSON.stringify(item.keys)+',"set":{'+innerSet.join(',')+'}}');
   }else{
    next.set(key,item);keys.push(key);
    const previous=incremental?sent.get(key):undefined;
    if(typeof previous!=='string'||previous!==item)set.push(JSON.stringify(key)+':'+item);
   }
  }
  revision++;sent=next;
  const head={};for(const key of Object.keys(result))if(key!=='model')head[key]=result[key];
  const patch='{"rev":'+revision+',"full":'+!incremental+',"keys":'+JSON.stringify(keys)+',"set":{'+set.join(',')+'},"sub":{'+sub.join(',')+'}}';
  const prefix=JSON.stringify(head);
  return prefix.slice(0,-1)+(prefix.length>2?',':'')+'"patch":'+patch+'}';
 }
 // Aucune section modifiée : mêmes clés, même ordre, rien dans `set`.
 function unchanged(result){
  revision++;
  const keys=[...sent.keys()],sub=[];
  for(const [key,value] of sent)if(value instanceof Map)sub.push(JSON.stringify(key)+':{"keys":'+JSON.stringify([...value.keys()])+',"set":{}}');
  const head={};for(const key of Object.keys(result))if(key!=='model')head[key]=result[key];
  const prefix=JSON.stringify(head);
  return prefix.slice(0,-1)+(prefix.length>2?',':'')+'"patch":{"rev":'+revision+',"full":false,"keys":'+JSON.stringify(keys)+',"set":{},"sub":{'+sub.join(',')+'}}}';
 }
 // Reconstruction de référence (tests) : même algorithme que le pont Godot.
 function apply(base,patch){
  const model={};
  for(const key of patch.keys){
   if(Object.hasOwn(patch.sub,key)){
    const part=patch.sub[key],before=!patch.full&&plain(base?.[key])?base[key]:{},inner={};
    for(const name of part.keys){if(!Object.hasOwn(part.set,name)&&!Object.hasOwn(before,name))throw Error('Patch incomplet : '+key+'.'+name+'.');inner[name]=Object.hasOwn(part.set,name)?part.set[name]:before[name];}
    model[key]=inner;
   }else{if(!Object.hasOwn(patch.set,key)&&(patch.full||!Object.hasOwn(base||{},key)))throw Error('Patch incomplet : '+key+'.');model[key]=Object.hasOwn(patch.set,key)?patch.set[key]:base[key];}
  }
  return model;
 }
 return {encode,apply,revision:()=>revision,reset(){sent=null;}};
}
module.exports={createEncoder,NESTED,TEXTS,UNCHANGED,FALLBACK,materialize,sectionTexts};
