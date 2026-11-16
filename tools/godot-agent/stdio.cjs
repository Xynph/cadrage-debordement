#!/usr/bin/env node
'use strict';
// Entrée MCP portable pour Codex/Claude. Tous les fichiers générés restent dans le dossier temporaire.
const fs=require('node:fs'),path=require('node:path'),os=require('node:os'),crypto=require('node:crypto'),{spawn,execFileSync}=require('node:child_process');
const pin=require('./pin.json'),sdk=require('../../ci/godot-sdk.json');
const repo=path.resolve(__dirname,'../..');
async function start(){
 const root=process.env.CD_GODOT_AGENT_WORKDIR||path.join(os.tmpdir(),'rugby-godot-agent-'+crypto.createHash('sha256').update(repo).digest('hex').slice(0,10));
 fs.mkdirSync(root,{recursive:true});
 const bridge=process.env.CD_GODOT_MCP_INSTALL||path.join(root,'bridge');
 if(!fs.existsSync(path.join(bridge,'dist/index.js')))execFileSync(process.execPath,[path.join(__dirname,'install.cjs'),bridge],{stdio:['ignore',2,2]});
 const head=execFileSync('git',['rev-parse','HEAD'],{cwd:bridge,encoding:'utf8'}).trim();
 if(head!==pin.commit)throw Error('Le pont installé ne correspond pas à pin.json. Relancer install.cjs après revue des changements locaux.');
 let godot=process.env.CD_GODOT_EXE||process.env.CD_GODOT_EXECUTABLE;
 if(!godot){
  if(process.platform!=='linux'||process.arch!=='x64')throw Error('Définir CD_GODOT_EXE vers Godot '+pin.godot+' sur cette plateforme.');
  const dir=path.join(root,'sdk');fs.mkdirSync(dir,{recursive:true});godot=path.join(dir,sdk.executable);
  if(!fs.existsSync(godot)){
   const response=await fetch(sdk.url);if(!response.ok)throw Error('Téléchargement Godot : HTTP '+response.status);
   const bytes=Buffer.from(await response.arrayBuffer());
   if(crypto.createHash('sha256').update(bytes).digest('hex')!==sdk.sha256)throw Error('SHA-256 de l’archive Godot incorrect.');
   const {unzipSync}=require(path.join(bridge,'node_modules/fflate'));
   const files=unzipSync(bytes),binary=files[sdk.executable];if(!binary)throw Error('Exécutable absent de l’archive Godot.');
   fs.writeFileSync(godot,binary,{mode:0o755});
  }
 }
 const version=execFileSync(godot,['--headless','--version'],{encoding:'utf8'}).trim();
 if(!version.startsWith(pin.godot+'.'))throw Error('Godot '+pin.godot+' requis, reçu '+version);
 const preview=path.join(root,'preview');
 execFileSync(process.execPath,[path.join(__dirname,'preview.cjs'),preview],{stdio:['ignore',2,2]});
 const project=path.join(preview,'native/godot');
 execFileSync(godot,['--headless','--editor','--path',project,'--import','--quit'],{stdio:['ignore',2,2],timeout:180000});
 const env={...process.env,GODOT_PROJECT_ROOT:project,GODOT_BIN:godot,GODOT_PATH:godot,GODOT_MCP_ADVANCED:'0',GODOT_MCP_CACHE_DIR:path.join(root,'tool-cache'),CD_NODE_EXECUTABLE:process.execPath,CD_GODOT_DATA_DIR:path.join(preview,'donnees'),CD_GODOT_SELF_TEST:'0'};
 const child=spawn(process.execPath,[path.join(bridge,'dist/index.js')],{env,stdio:'inherit'});
 const stop=()=>child.kill('SIGTERM');process.once('SIGINT',stop);process.once('SIGTERM',stop);
 child.once('exit',(code,signal)=>{process.removeListener('SIGINT',stop);process.removeListener('SIGTERM',stop);process.exitCode=signal?1:code??1;});
 child.once('error',e=>{console.error(e.message);process.exitCode=1;});
}
if(require.main===module)start().catch(e=>{console.error(e.message);process.exitCode=1;});
