#!/usr/bin/env node
'use strict';
const fs=require('node:fs'),path=require('node:path'),{spawn,execFileSync}=require('node:child_process');
const pin=require('./pin.json');
function serve(bridge,preview,godot,port='7878'){
 bridge=path.resolve(bridge);preview=path.resolve(preview);godot=path.resolve(godot);
 if(!/^\d+$/.test(port)||Number(port)<1024||Number(port)>65535)throw Error('Port local invalide.');
 const record=JSON.parse(fs.readFileSync(path.join(preview,'rugby-preview.json'),'utf8'));
 const head=execFileSync('git',['rev-parse','HEAD'],{cwd:bridge,encoding:'utf8'}).trim();
 if(head!==pin.commit)throw Error('Le pont installé ne correspond pas au pin.');
 const version=execFileSync(godot,['--headless','--version'],{encoding:'utf8'}).trim();
 if(!version.startsWith(pin.godot+'.'))throw Error('Godot '+pin.godot+' requis, reçu '+version);
 const project=path.join(preview,'native/godot');
 if(path.resolve(record.project)!==project||fs.realpathSync(project)===fs.realpathSync(path.join(record.source,'native/godot')))throw Error('La prévisualisation doit être une copie du projet.');
 const env={...process.env,GODOT_PROJECT_ROOT:project,GODOT_BIN:godot,GODOT_PATH:godot,GODOT_MCP_ADVANCED:'0',GODOT_MCP_CACHE_DIR:path.join(preview,'tool-cache'),CD_NODE_EXECUTABLE:process.execPath,CD_GODOT_DATA_DIR:record.profiles,CD_GODOT_SELF_TEST:'0'};
 console.error('Pont Godot local sur 127.0.0.1:'+port+' ; projet '+project+' ; '+version);
 const child=spawn(process.execPath,[path.join(bridge,'dist/index.js'),'--transport','http','--host','127.0.0.1','--port',port],{env,stdio:'inherit'});
 const stop=()=>child.kill('SIGTERM');process.once('SIGINT',stop);process.once('SIGTERM',stop);
 child.once('error',e=>{console.error(e.message);process.exitCode=1;});
 child.once('exit',(code,signal)=>{process.removeListener('SIGINT',stop);process.removeListener('SIGTERM',stop);process.exitCode=signal?1:code??1;});
}
if(require.main===module){try{if(process.argv.length<5)throw Error('Usage : node tools/godot-agent/serve.cjs <pont installé> <copie> <exécutable Godot> [port]');serve(...process.argv.slice(2));}catch(e){console.error(e.message);process.exitCode=1;}}
module.exports={serve};
