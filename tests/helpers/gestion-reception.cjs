'use strict';
// Diagnostic opt-in des vraies campagnes : aucun rejeu, état fabriqué ou
// changement de validation. Les points servent seulement à reproduire un rouge.
const fs=require('node:fs'),path=require('node:path');
function checkpoint(h,name,metadata={}){
 const dir=process.env.CD_GESTION_CHECKPOINT_DIR;if(!dir)return;
 if(!/^[a-z0-9-]+$/i.test(name))throw Error('Nom de checkpoint de réception invalide');
 const point=h.checkpoint();fs.mkdirSync(dir,{recursive:true});
 const file=path.join(dir,name+'.json'),temporary=file+'.tmp';
 fs.writeFileSync(temporary,JSON.stringify({kind:'actual-world-reception-checkpoint',...metadata,point}));fs.renameSync(temporary,file);
}
function traceValidation(h){
 if(process.env.CD_GESTION_VALIDATION_TRACE!=='1')return;
 const check=h.ctx.saveCheck;let reported=false;
 h.ctx.saveCheck=function(value,message){
  if(!value&&!reported){reported=true;console.error(JSON.stringify({validationFailure:true,message:message??null,stack:new Error('First actual validation refusal').stack.split('\n').slice(1,9)}));}
  return check.apply(this,arguments);
 };
}
module.exports={checkpoint,traceValidation};
