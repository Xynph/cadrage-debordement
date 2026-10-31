'use strict';
/**
 * Run from a network-connected Node 20+ host:
 *   node tools/data06-itsrugby-bulk.cjs --clubs clermont,toulouse,brive
 * Fetches entire published team roster pages, not individual profiles.
 * Does not publish any unverified identity joins.
 */
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const {setTimeout:delay}=require('node:timers/promises');
const BASE='https://itsrugby.fr';
const safeSlug=s=>/^[a-z0-9-]+$/.test(s);
const sleep=ms=>delay(ms);
async function collect({slugs,out='data06-itsrugby-capture',fetchFn=fetch,paceMs=1800}){
 if(!Array.isArray(slugs)||!slugs.length||slugs.some(s=>!safeSlug(s))) throw Error('Provide valid team slugs');
 fs.mkdirSync(out,{recursive:true});
 const results=[];
 for(const [i,slug] of slugs.entries()){
   if(i)await sleep(paceMs);
   const url=BASE+'/equipes/'+slug+'/?saison=2026-27';
   try{
     const r=await fetchFn(url,{headers:{'User-Agent':'CadrageDebordement-DATA06/1.0 (authorized research; contact via repository)',Accept:'text/html'},signal:AbortSignal.timeout(20000)});
     if(!r.ok)throw Error('HTTP '+r.status);
     const html=await r.text();
     if(html.length<1000 || !/effectif/i.test(html)|| !/joueurs/i.test(html))throw Error('Unexpected roster page; no publishable extraction');
     const file=slug+'.html';
     fs.writeFileSync(path.join(out,file),html);
     results.push({slug,url,ok:true,file,bytes:Buffer.byteLength(html),sha256:crypto.createHash('sha256').update(html).digest('hex')});
   }catch(e){results.push({slug,url,ok:false,error:String(e.message||e).slice(0,200)});}
 }
 const result={source:BASE,season:'2026-27',capturedAt:new Date().toISOString(),allowedUse:'User-confirmed site authorization 2026-10-31',results};
 fs.writeFileSync(path.join(out,'manifest.json'),JSON.stringify(result,null,2)+'\n');
 return result;
}
if(require.main===module){
 const argv=process.argv.slice(2),flag=argv.indexOf('--clubs');
 const slugs=flag>=0?(argv[flag+1]||'').split(',').filter(Boolean):[];
 const result=collect({slugs,out:process.env.DATA06_OUT||'data06-itsrugby-capture'});
 result.then(r=>{console.log(JSON.stringify({retrieved:r.results.filter(x=>x.ok).length,failed:r.results.filter(x=>!x.ok).length,total:r.results.length}));if(r.results.every(x=>!x.ok))process.exitCode=1}).catch(e=>{console.error(e);process.exitCode=1});
}
module.exports={collect,safeSlug};
