'use strict';
// Mesure des effets de la date de reprise (docs/reprise-choisie-20261113.md).
// Usage : node --max-old-space-size=1300 tools/reprise-mesure.cjs <date AAAA-MM-JJ|habitual> [club=0] [graine=27] [sortie.json]
// Carrière Monde (world-champ), départ « Reprise des premiers clubs », une saison entière simulée
// (matchs du club délégués). Relevés hebdomadaires du club : condition moyenne des 23 meilleurs,
// nouvelles blessures, résultats, moral ; et minutes des jeunes en préparation.
const fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const {createBridge}=require('../native/engine/worker.cjs');
const {settleClubMeetings}=require('../tests/helpers/club-meetings.cjs');
const [choice='habitual',clubArg='0',seedArg='27',out]=process.argv.slice(2);
const club=Number(clubArg),seed=Number(seedArg);
const dir=fs.mkdtempSync(path.join(os.tmpdir(),'cd-reprise-mesure-'));
const b=createBridge({dataDir:dir,seed,now:1794178800000});let id=0;
const go=(command,payload={})=>{const r=b.handle({id:++id,command,payload});if(!r.ok)throw Error(command+': '+r.error);return r.model;};
const state=()=>JSON.parse(go('export').meta.exportText).state;
try{
 let m=settleClubMeetings(go('new_career',{mode:'world-champ',club,start:'premiers-clubs'}),go);
 m=go('reprise_choose',choice==='habitual'?{habitual:true}:{date:choice});
 const plan=m.clubLife.reprise;
 m=settleClubMeetings(go('reprise_advance',{fromDate:m.meta.calendarToday,until:'saison'}),go);
 let s=state();const fmWeek=s.reprise.plan.clubs.find(r=>r[0]===club)[2];
 const rows=[];let prior=new Map(s.clubs[club].players.map(p=>[p.id,p.injury]));
 for(let w=0;w<46&&s.phase!=='ended';w++){
  const played=!!m.next;
  if(played){go('begin_match');go('delegate');}
  m=settleClubMeetings(go('finish_round'),go);s=state();
  const players=s.clubs[club].players,top=[...players].sort((a,b)=>b.rating-a.rating).slice(0,23);
  const injuries=players.filter(p=>p.injury>(prior.get(p.id)??0)).length;prior=new Map(players.map(p=>[p.id,p.injury]));
  const result=played?s.history.filter(r=>r.pair.includes(club)).at(-1):null;
  const side=result?result.pair.indexOf(club):-1;
  rows.push({week:s.round-1,k:s.round-1-fmWeek,played,condition:Math.round(top.reduce((n,p)=>n+p.condition,0)/top.length*10)/10,
   injured:players.filter(p=>p.injury>0).length,injuries,morale:s.morale,
   result:result?(result.score[side]>result.score[1-side]?'V':result.score[side]<result.score[1-side]?'D':'N'):null,
   diff:result?result.score[side]-result.score[1-side]:null});
 }
 const report={choice,club,seed,plan:{date:plan.club.date,weeks:plan.club.weeks,effects:plan.club.effects,internationals:plan.internationals.length},
  youth:s.reprise.report?.youth??[],fmWeek,rows};
 const text=JSON.stringify(report,null,1);
 if(out)fs.writeFileSync(out,text);else process.stdout.write(text+'\n');
}finally{b.close();fs.rmSync(dir,{recursive:true,force:true});}
