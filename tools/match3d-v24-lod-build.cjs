'use strict';
// Génération expérimentale : ne vaut PAS qualification visuelle ni intégration runtime.
const fs=require('node:fs'),path=require('node:path'),os=require('node:os'),{spawnSync}=require('node:child_process');
const {auditGLB}=require('./match3d-v24-glb-audit.cjs');
const dir='dist/match3d/assets/charactercreator-v24',out='dist/match3d/assets/rugby-v24/lod';
const names=['base_body_anim','clothing_tshirt','clothing_shorts','clothing_shoes'];
const limits=[30000,10000,3000],ratios=[[.65,.5,.3,.15,.05],[.20,.12,.06,.02,.005],[.06,.025,.01,.003,.001]];
const cli=process.env.GLTF_TRANSFORM_CLI;
if(!cli||!fs.existsSync(cli))throw Error('gltf-transform absent');
const sources=names.map(name=>{const file=path.join(dir,name+'.glb'),check=auditGLB(fs.readFileSync(file));if(check.joints!==53)throw Error('Rig invalide : '+name);return {name,file,check};});
const total=sources.reduce((n,s)=>n+s.check.triangles,0);
if(total!==42634)throw Error('Sources inattendues : '+total);
const temp=fs.mkdtempSync(path.join(os.tmpdir(),'cd-v24-'));
function run(args){const r=spawnSync(cli,args,{encoding:'utf8',timeout:180000,maxBuffer:8000000});if(r.error||r.status!==0)throw Error('gltf-transform '+args.join(' ')+' : '+(r.error?.message||r.stderr||r.stdout||'').slice(-1200));}
const report={schemaVersion:1,qualification:'geometrie seulement; animation rugby, peau/chaussures et rendu 30 joueurs NON qualifies',sourceTriangles:total,levels:[]};
try{
 fs.mkdirSync(out,{recursive:true});
 for(let lod=0;lod<3;lod++){
  let triangles=0;const entries=[];
  for(const s of sources){
   const budget=Math.max(3,Math.floor(limits[lod]*s.check.triangles/total));
   const welded=path.join(temp,s.name+'-weld.glb');
   if(!fs.existsSync(welded))run(['weld',s.file,welded]);
   let passed=null,ratioUsed=null;
   for(const ratio of ratios[lod]){
    const trial=path.join(temp,s.name+'-'+lod+'-'+ratio+'.glb');
    run(['simplify',welded,trial,'--ratio',String(ratio),'--error','1']);
    const a=auditGLB(fs.readFileSync(trial));
    if(a.joints!==53||a.animations.length!==s.check.animations.length)throw Error('Rig/clips altérés : '+s.name);
    if(a.triangles<=budget){passed=trial;ratioUsed=ratio;break;}
   }
   if(!passed)throw Error('Budget LOD'+lod+' impossible pour '+s.name+' : max '+budget);
   const output=path.join(out,s.name+'-lod'+lod+'.glb');
   fs.copyFileSync(passed,output);
   const a=auditGLB(fs.readFileSync(output),{maxTriangles:budget});
   triangles+=a.triangles;
   entries.push({file:path.basename(output),bytes:fs.statSync(output).size,triangles:a.triangles,joints:a.joints,clips:a.animations,ratioUsed});
  }
  if(triangles>limits[lod])throw Error('LOD'+lod+' depasse '+limits[lod]);
  report.levels.push({lod,cap:limits[lod],triangles,entries});
 }
 fs.writeFileSync(path.join(out,'report.json'),JSON.stringify(report,null,2)+'\n');
 console.log(JSON.stringify(report));
}finally{fs.rmSync(temp,{recursive:true,force:true});}
