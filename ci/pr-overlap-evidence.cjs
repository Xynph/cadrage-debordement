'use strict';
// Exception opt-in pour un ajout de script non destructif dans dist/index.html.
// Aucune exception implicite pour les PR anciennes, DRAFT ou "doublons".
const SHA=/^[a-f0-9]{40}$/;
const OWNER=350229047;
const PATH='dist/index.html';
const RELEASE=/^CD-RELEASE-OVERLAP v1 PR=([1-9][0-9]*) HEAD=([a-f0-9]{40}) CANDIDATE=([1-9][0-9]*) CANDIDATE_HEAD=([a-f0-9]{40}) MAIN=([a-f0-9]{40}) PATH=dist\/index\.html$/;
const SCRIPT=/<script src="([a-zA-Z0-9][a-zA-Z0-9/_-]*\.js)"><\/script>/g;
function assessAdditiveIndex(mainHtml,candidateHtml,changed) {
  if(typeof mainHtml!=='string'||typeof candidateHtml!=='string'||!mainHtml||!candidateHtml)return null;
  if(mainHtml===candidateHtml)return null; // Aucun ajout attestable
  const base=new Set([...mainHtml.matchAll(SCRIPT)].map(m=>m[1]));
  const possible=[...candidateHtml.matchAll(SCRIPT)].filter(m=>!base.has(m[1]));
  if(possible.length!==1)return null;
  const [tag,path]=[possible[0][0],possible[0][1]];
  if(!changed.includes('dist/'+path)||path.startsWith('match3d/'))return null;
  if((candidateHtml.match(new RegExp(tag.replace(/[.*+?^${}()|[\]\\]/g,'\\$&'),'g'))||[]).length!==1)return null;
  const index=candidateHtml.indexOf(tag);
  if(index<0||candidateHtml.slice(0,index)+candidateHtml.slice(index+tag.length)!==mainHtml)return null;
  // Le script doit rester dans la liste existante, avant la scène 3D si elle est présente.
  const match3d=candidateHtml.indexOf('<script src="match3d/');
  if(match3d>=0&&index>match3d)return null;
  return {path:'dist/'+path,tag};
}
function resolve({overlaps,comments,pr,expected,main,files,mainHtml,candidateHtml}) {
  const items=overlaps||[];
  if(!items.length)return {accepted:true,releases:[],additive:null};
  if(!pr||!Number.isSafeInteger(pr.number)||!SHA.test(expected||'')||!SHA.test(main||''))return {accepted:false,reason:'SHA ou PR non vérifiable'};
  if(items.some(x=>x.path!==PATH||!Number.isSafeInteger(x.pr)||!SHA.test(x.head||'')))return {accepted:false,reason:'Chevauchement non qualifiable'};
  const additive=assessAdditiveIndex(mainHtml,candidateHtml,files||[]);
  if(!additive)return {accepted:false,reason:'Index modifié autrement que par un seul include nouveau'};
  const releases=[];
  for(const x of items) {
    const matching=(comments||[]).filter(c=>{
      if(c?.user?.id!==OWNER||c?.user?.login!=='Xynph'||typeof c.body!=='string')return false;
      const body=c.body.trim(),m=body.match(RELEASE);
      return !!m&&m[0]===body&&Number(m[1])===x.pr&&m[2]===x.head&&Number(m[3])===pr.number&&m[4]===expected&&m[5]===main;
    });
    if(matching.length!==1||!Number.isSafeInteger(matching[0].id))return {accepted:false,reason:'Attestation propriétaire absente ou ambiguë pour PR #'+x.pr};
    releases.push({pr:x.pr,head:x.head,commentId:matching[0].id,path:PATH});
  }
  return {accepted:true,releases,additive};
}
module.exports={assessAdditiveIndex,resolve};
