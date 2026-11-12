'use strict';
// Presentation transport only. Input is the final knowledge-safe model.
const object=x=>x!==null&&typeof x==='object'&&!Array.isArray(x);
function fields(model){
 const out=new Map();
 const walk=(value,p)=>{
  const entries=object(value)?Object.entries(value).filter(([,v])=>v!==undefined):[];
  if(object(value)&&p.length<2&&entries.length){for(const [key,v]of entries)walk(v,[...p,key]);}
  else out.set(JSON.stringify(p),{path:p,value,json:JSON.stringify(value)});
 };
 for(const [key,value]of Object.entries(model))if(value!==undefined)walk(value,[key]);return out;
}
function createTransport(){
 let revision=0,previous=null;
 return {encode(response,request){
  if(request?.version!==1||!object(response.model)){previous=null;return response;}
  const next=fields(response.model),base=revision,full=!previous||request.base!==base;
  revision++;
  const transport={version:1,revision,base:full?null:base,full};
  if(full){previous=next;return {...response,transport};}
  const set=[],remove=[],top=new Set([...next.values()].map(e=>e.path[0])),removed=new Set();
  for(const [key,entry]of previous)if(!next.has(key)){
   if(top.has(entry.path[0]))remove.push(entry.path);
   else if(!removed.has(entry.path[0])){removed.add(entry.path[0]);remove.push([entry.path[0]]);}
  }
  for(const [key,entry]of next)if(previous.get(key)?.json!==entry.json)set.push({path:entry.path,value:entry.value});
  previous=next;
  const {model,...rest}=response;return {...rest,transport,modelPatch:{set,remove}};
 }};
}
// Receiver reference used by the stdio tests. Godot has its own implementation.
function apply(model,revision,response){
 if(response.transport?.full)return structuredClone(response.model);
 if(response.transport?.base!==revision)throw Error('Mauvaise révision de modèle.');
 const result=structuredClone(model);
 for(const p of response.modelPatch.remove){let parent=result;for(const key of p.slice(0,-1))parent=parent?.[key];if(parent)delete parent[p.at(-1)];}
 for(const {path:p,value}of response.modelPatch.set){let parent=result;for(const key of p.slice(0,-1)){if(!object(parent[key]))parent[key]={};parent=parent[key];}parent[p.at(-1)]=structuredClone(value);}
 return result;
}
module.exports={createTransport,apply};
