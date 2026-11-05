#!/usr/bin/env node
'use strict';
// R&D V25 — auditeur GLB glTF 2.0 en lecture seule, sans dépendance.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
function read(file) {
  const bytes = fs.readFileSync(file);
  if (bytes.length < 20 || bytes.toString('ascii',0,4) !== 'glTF' || bytes.readUInt32LE(4) !== 2 || bytes.readUInt32LE(8) !== bytes.length) throw Error('En-tête GLB invalide : ' + file);
  let pos=12,g=null,bin=0;
  while(pos < bytes.length) {
    if(pos+8>bytes.length)throw Error('Chunk tronqué');
    const len=bytes.readUInt32LE(pos),type=bytes.readUInt32LE(pos+4);pos+=8;
    if(len%4 || pos+len>bytes.length)throw Error('Longueur chunk invalide');
    if(type===0x4e4f534a){if(g)throw Error('JSON dupliqué');g=JSON.parse(bytes.toString('utf8',pos,pos+len).trim());}
    if(type===0x004e4942)bin+=len;
    pos+=len;
  }
  if(!g)throw Error('JSON absent');
  const nodes=g.nodes||[], parents=Array(nodes.length).fill(null);
  nodes.forEach((n,i)=>(n.children||[]).forEach(j=>{if(!nodes[j]||parents[j]!==null)throw Error('Hiérarchie invalide');parents[j]=i;}));
  const skins=(g.skins||[]).map(s=>(s.joints||[]).map(id=>{
    if(!nodes[id])throw Error('Joint introuvable');
    const n=nodes[id],p=parents[id];
    return {name:n.name||('#'+id),parent:p===null?null:(nodes[p].name||('#'+p))};
  }));
  let triangles=0,vertices=0,skinned=0;
  for(const m of g.meshes||[])for(const p of m.primitives||[]){
    const a=p.attributes||{},access=g.accessors||[],vertex=access[a.POSITION];
    if(!vertex)throw Error('POSITION manquante');
    vertices+=vertex.count;
    const count=p.indices===undefined?vertex.count:access[p.indices]?.count;
    if(!Number.isInteger(count))throw Error('Accessor index invalide');
    const mode=p.mode??4;
    if(mode===4)triangles+=count/3;else if(mode===5||mode===6)triangles+=Math.max(0,count-2);
    if(a.JOINTS_0!==undefined||a.WEIGHTS_0!==undefined){
      if(a.JOINTS_0===undefined||a.WEIGHTS_0===undefined||access[a.JOINTS_0]?.count!==vertex.count||access[a.WEIGHTS_0]?.count!==vertex.count)throw Error('Attributs peau invalides');
      skinned++;
    }
  }
  return {file:path.basename(file),bytes:bytes.length,sha256:crypto.createHash('sha256').update(bytes).digest('hex'),skins:skins.length,joints:skins.map(s=>s.length),skeletons:skins,meshes:(g.meshes||[]).length,vertices,triangles,skinnedPrimitives:skinned,binBytes:bin,clips:(g.animations||[]).map(a=>a.name||'?'),externalUris:[...(g.buffers||[]),...(g.images||[])].filter(x=>x.uri).map(x=>x.uri)};
}
function signature(a){return JSON.stringify((a.skeletons[0]||[]).map(j=>[j.name,j.parent]));}
function run(args){
  const refIndex=args.indexOf('--reference');let refFile=null;
  if(refIndex!==-1){if(!args[refIndex+1])throw Error('Référence manquante');refFile=args.splice(refIndex,2)[1];}
  if(!args.length)throw Error('Usage: node audit-glb.cjs [--reference reference.glb] fichier.glb ...');
  const results=args.map(read),reference=refFile?read(refFile):results[0],refSig=signature(reference);
  for(const r of results)r.sameJointNamesAndParents=signature(r)===refSig;
  const allMatch=results.every(r=>r.sameJointNamesAndParents);
  console.log(JSON.stringify({reference:reference.file,referenceJointCount:reference.joints[0]||0,allMatch,results},null,2));
  if(!allMatch)process.exitCode=1;
}
try{run(process.argv.slice(2));}catch(error){console.error(String(error.stack||error));process.exitCode=1;}
