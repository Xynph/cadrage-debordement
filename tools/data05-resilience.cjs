'use strict';
function classify(err){
 const status=Number(err?.status||0);
 if(status===401||status===403)return {retry:false,stop:true,reason:'access-denied'};
 if(status===429)return {retry:false,stop:true,reason:'rate-limited'};
 if(status===402)return {retry:false,stop:true,reason:'billing'};
 if(status>=500&&status<=599)return {retry:true,stop:false,reason:'server-error'};
 if(['AbortError','TimeoutError'].includes(err?.name)||['ETIMEDOUT','ECONNRESET','EAI_AGAIN'].includes(err?.code))return {retry:true,stop:false,reason:'transient-network'};
 return {retry:false,stop:false,reason:'other'};
}
function validateCache(value,ref){
 if(!value||value.id!==ref.id||value.club!==ref.club||value.url!==ref.url||!value.name)throw Error('Cache identity mismatch '+ref.id);
 if(value.birthDate!==null||value.validAtJuly1!==false)throw Error('Historical claims must remain unverified');
 return true;
}
async function withRetries(task,{maxRetries=2,wait=async()=>{},onStop=()=>{}}={}){
 for(let i=0;;i++)try{return await task(i)}catch(e){const x=classify(e);if(x.stop){onStop(x);throw e}if(!x.retry||i>=maxRetries)throw e;await wait(Math.min(10000,250*2**i))}
}
function reserveBudget(counter,limit){if(!Number.isInteger(limit)||limit<0)throw Error('Invalid budget');if(counter.used>=limit)return false;counter.used++;return true}
module.exports={classify,validateCache,withRetries,reserveBudget};
