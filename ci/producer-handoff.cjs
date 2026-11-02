'use strict';
const fs=require('node:fs');
const REPO='Xynph/cadrage-debordement';
const JOBS=['classification','Suites 1/5','Suites 2/5','Suites 3/5','Suites 4/5','Suites 5/5','Validation CI'];
const MARK='CD-AUTO-HANDOFF';
const marker=(pr,sha)=>'<!-- '+MARK+' pr='+pr+' head='+sha+' -->';
function assess(pr,runs,jobs){
 if(!pr||pr.state!=='open'||pr.draft||pr.merged||pr.base?.ref!=='main'||
    pr.head?.repo?.full_name!==REPO||!/^[a-f0-9]{40}$/.test(pr.head?.sha||'')||
    pr.mergeable_state!=='clean')return {ready:false};
 const selected=new Map();
 for(const r of runs.filter(r=>r.event==='pull_request'&&r.head_sha===pr.head.sha)
    .sort((a,b)=>b.id-a.id))if(!selected.has(r.name))selected.set(r.name,r);
 const js=selected.get('Tests JavaScript');
 if(!js||js.status!=='completed'||js.conclusion!=='success')return {ready:false};
 if(!Array.isArray(jobs)||jobs.length!==7||!JOBS.every(name=>
    jobs.filter(j=>j.name===name&&j.status==='completed'&&j.conclusion==='success').length===1))
    return {ready:false};
 if([...selected.values()].some(r=>r.status!=='completed'||r.conclusion!=='success'))
    return {ready:false};
 return {ready:true,runs:[...selected.values()]};
}
function candidates(event){
 if(event.pull_request)return [event.pull_request.number];
 return [...new Set((event.workflow_run?.pull_requests||[]).map(p=>p.number).filter(Number.isSafeInteger))];
}
async function handle(event,api){
 if(!event?.pull_request&&!event?.workflow_run)return [];
 if(event.workflow_run&&event.workflow_run.event!=='pull_request')return [];
 let numbers=candidates(event);
 // workflow_run.pull_requests peut être vide selon GitHub ; retrouver les PR par HEAD exact.
 if(numbers.length===0&&event.workflow_run?.event==='pull_request'){
  const linked=await api('commits/'+event.workflow_run.head_sha+'/pulls?per_page=100');
  if(!Array.isArray(linked))throw Error('Association HEAD vers PR indisponible');
  numbers=[...new Set(linked.filter(p=>p.head?.sha===event.workflow_run.head_sha)
    .map(p=>p.number).filter(Number.isSafeInteger))];
 }
 const sent=[];
 for(const number of numbers){
  const pr=await api('pulls/'+number);
  if(pr.head?.sha!==(event.workflow_run?.head_sha||event.pull_request?.head?.sha)||
     pr.head?.repo?.full_name!==REPO)continue;
  const listing=await api('actions/runs?head_sha='+pr.head.sha+'&per_page=100');
  const runs=listing.workflow_runs||[];
  const latest=runs.filter(r=>r.name==='Tests JavaScript'&&r.event==='pull_request'&&
    r.head_sha===pr.head.sha).sort((a,b)=>b.id-a.id)[0];
  if(!latest)continue;
  const jobList=await api('actions/runs/'+latest.id+'/jobs?per_page=100');
  const state=assess(pr,runs,jobList.jobs);
  if(!state.ready)continue;
  const key=marker(number,pr.head.sha);
  let seen=false,complete=false;
  for(let page=1;page<=50;page++){
   const comments=await api('issues/73/comments?per_page=100&page='+page);
   if(!Array.isArray(comments))throw Error('Page commentaires invalide');
   if(comments.some(c=>typeof c.body==='string'&&c.body.includes(key))){seen=true;break;}
   if(comments.length<100){complete=true;break;}
  }
  if(seen||!complete)continue;
  const evidence=state.runs.map(r=>'- '+r.name.replace(/[\r\n]/g,' ').slice(0,90)+
     ' : SUCCESS — https://github.com/'+REPO+'/actions/runs/'+r.id).join('\n');
  const body=[key,'### PASSATION AUTOMATIQUE PRODUCTEUR → INTÉGRATEUR',
   '@Xynph — PR #'+number+' prête pour réception : https://github.com/'+REPO+'/pull/'+number,
   'HEAD exact : '+pr.head.sha,'Tests JavaScript : sept jobs SUCCESS. Autres workflows observés :',
   evidence,'','INTÉGRATEUR : revalider main, réservations, dépendances et gate officiel.',
   '**Aucune fusion autorisée par cette notification.**',
   'GitHub notifie les abonnés ; cette action ne réveille pas un compte ChatGPT.'].join('\n');
  await api('issues/73/comments','POST',{body});
  sent.push({pr:number,sha:pr.head.sha});
 }
 return sent;
}
async function github(path,method='GET',payload){
 if(!process.env.GH_TOKEN)throw Error('GH_TOKEN absent');
 const res=await fetch('https://api.github.com/repos/'+REPO+'/'+path,{
  method,headers:{authorization:'Bearer '+process.env.GH_TOKEN,
   accept:'application/vnd.github+json','x-github-api-version':'2022-11-28',
   'user-agent':'cd-producer-handoff'},
  ...(payload?{body:JSON.stringify(payload)}:{})
 });
 if(!res.ok)throw Error('GitHub HTTP '+res.status+' '+path);
 if(res.status===204)return null;
 return res.json();
}
if(require.main===module){
 const event=JSON.parse(fs.readFileSync(process.env.GITHUB_EVENT_PATH,'utf8'));
 handle(event,github).then(x=>console.log('Passations : '+JSON.stringify(x)),e=>{
  console.error(e.message);process.exitCode=1;
 });
}
module.exports={JOBS,marker,assess,candidates,handle};
