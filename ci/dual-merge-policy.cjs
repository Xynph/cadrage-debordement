'use strict';
// Lecture des protections existantes : une erreur ou une ambiguite INTERDIT la fusion.
// Cet outil n'effectue jamais de fusion ni de mutation GitHub.
function verdict({repo,mainProtection,pr,run,validationJob,mainSha,enabled}={}){
 const no=reason=>({allowed:false,reason});
 if(repo!=='Xynph/cadrage-debordement')return no('Depot non autorise');
 if(enabled!==true)return no('Activation explicite absente');
 if(!mainProtection||mainProtection.required_status_checks?.strict!==true)return no('Main ne requiert pas une CI strictement a jour');
 const contexts=[...(mainProtection.required_status_checks.contexts||[]),...(mainProtection.required_status_checks.checks||[]).map(c=>c.context)];
 if(!contexts.some(c=>c==='Validation CI'||c==='Tests JavaScript / Validation CI'))return no('Validation CI non obligatoire en protection main');
 if(mainProtection.enforce_admins?.enabled!==true)return no('Protections non appliquees aux administrateurs');
 if(!pr||pr.state!=='open'||pr.draft!==false||pr.base?.ref!=='main'||pr.mergeable!==true||pr.mergeable_state!=='clean')return no('PR non fusionnable');
 if(!pr.head?.sha||pr.head.repo?.full_name!==repo)return no('Source ou SHA de PR incorrect');
 if(pr.base.sha!==mainSha)return no('Main a change depuis le calcul de fusion');
 if(!run||run.event!=='pull_request'||run.head_sha!==pr.head.sha||run.status!=='completed'||run.conclusion!=='success'||run.name!=='Tests JavaScript')return no('CI sur le SHA de PR manquante');
 if(!validationJob||validationJob.name!=='Validation CI'||validationJob.status!=='completed'||validationJob.conclusion!=='success')return no('Validation CI ne valide pas le dernier SHA');
 return {allowed:true,reason:'Preconditions satisfaites, GitHub doit encore controler les protections au moment de la fusion',headSha:pr.head.sha,mainSha};
}
module.exports={verdict};
