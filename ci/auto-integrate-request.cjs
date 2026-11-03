'use strict';
// Étape non privilégiée pour la fusion : vérifier le label puis déclencher un
// workflow_dispatch distinct, exécuté sur main après la fin du job d'étiquette.
const fs=require('node:fs'),{execFileSync}=require('node:child_process');
const {validateEvent,verify}=require('./auto-integrate.cjs');
const REPO='Xynph/cadrage-debordement';
function need(condition,message){if(!condition)throw Error(message);}
function api(endpoint,method='GET',body){
 const args=['api','--method',method,'-H','X-GitHub-Api-Version: 2026-03-10','repos/'+REPO+'/'+endpoint];
 if(body)args.push('--input','-');
 const raw=execFileSync('gh',args,{encoding:'utf8',input:body?JSON.stringify(body):undefined,timeout:30000});
 return raw.trim()?JSON.parse(raw):null;
}
function validateRequest(e,env,transport){
 const cmd=validateEvent(e,env);
 need(/^[1-9][0-9]*$/.test(env.GITHUB_RUN_ID||''),'Identifiant de run absent');
 need(transport('git/ref/heads/main').object.sha===cmd.base,'main a avancé depuis le label');
 verify(cmd,transport);
 return {pr:String(cmd.pr),sha:cmd.expected,source_run:env.GITHUB_RUN_ID};
}
function main(){
 const e=JSON.parse(fs.readFileSync(process.env.GITHUB_EVENT_PATH,'utf8'));
 const inputs=validateRequest(e,process.env,api);
 api('actions/workflows/auto-integrate.yml/dispatches','POST',{ref:'main',inputs});
 console.log('Sélection vérifiée, dispatch demandé pour PR #'+inputs.pr+
   ' SHA '+inputs.sha+' ; aucune fusion effectuée dans ce job.');
}
if(require.main===module){try{main();}catch(e){console.error(e.message);process.exitCode=1;}}
module.exports={validateRequest};
