#!/usr/bin/env node
'use strict';
// Client du pont LOCAL : JSON-RPC/HTTP, réponses JSON ou SSE. Aucun modèle ni service payant.
const fs=require('node:fs'),path=require('node:path');

function decode(text){
 if(text.trimStart().startsWith('{'))return JSON.parse(text);
 const events=text.split(/\r?\n\r?\n/).map(block=>block.split(/\r?\n/).filter(line=>line.startsWith('data:')).map(line=>line.slice(5).trimStart()).join('\n')).filter(Boolean);
 const message=events.map(s=>JSON.parse(s)).find(x=>Object.hasOwn(x,'result')||Object.hasOwn(x,'error'));
 if(!message)throw Error('Le pont n’a renvoyé aucune réponse JSON-RPC.');
 return message;
}
async function request(method,params={},options={}){
 const endpoint=new URL(options.url||process.env.CD_GODOT_MCP_URL||'http://127.0.0.1:7878/mcp');
 if(endpoint.protocol!=='http:'||!['127.0.0.1','localhost','[::1]'].includes(endpoint.hostname)||endpoint.username||endpoint.password)throw Error('Le pont doit être une adresse HTTP locale sans identifiants.');
 const response=await fetch(endpoint,{method:'POST',headers:{'content-type':'application/json',accept:'application/json, text/event-stream'},body:JSON.stringify({jsonrpc:'2.0',id:1,method,params}),signal:AbortSignal.timeout(options.timeout??120000)});
 const body=await response.text();
 if(!response.ok)throw Error('Pont HTTP '+response.status+' : '+body.slice(0,1000));
 const message=decode(body);
 if(message.error)throw Error('Pont JSON-RPC : '+JSON.stringify(message.error));
 if(message.result?.isError)throw Error((message.result.content||[]).filter(c=>c.type==='text').map(c=>c.text).join('\n')||'Le contrôle Godot a échoué.');
 return message.result;
}
async function main(args){
 const [action,name]=args,at=args.indexOf('--input'),output=args.indexOf('--output');
 let result;
 if(action==='list'){
  const listed=await request('tools/list');
  result=name?listed.tools.find(t=>t.name===name):listed.tools.map(t=>({name:t.name,description:t.description}));
  if(!result)throw Error('Outil absent : '+name);
 }else if(action==='call'&&name){
  const input=at<0?{}:JSON.parse(fs.readFileSync(args[at+1],'utf8'));
  result=await request('tools/call',{name,arguments:input});
 }else throw Error('Usage : node tools/godot-agent/mcp.cjs list [outil] | call <outil> [--input paramètres.json] [--output réponse.json]');
 // Une image reste un fichier ; ne jamais imprimer son base64 dans les journaux.
 if(result?.content)result.content=result.content.map(c=>c.type==='image'?{type:c.type,mimeType:c.mimeType,bytes:Buffer.from(c.data,'base64').length}:c);
 const text=JSON.stringify(result,null,2)+'\n';
 if(output>=0){const target=path.resolve(args[output+1]);fs.mkdirSync(path.dirname(target),{recursive:true});fs.writeFileSync(target,text);console.log(target);}else process.stdout.write(text);
}
if(require.main===module)main(process.argv.slice(2)).catch(e=>{console.error(e.message);process.exitCode=1;});
module.exports={decode,request};
