'use strict';
// V17: vue dans le bureau existant, donnees natives strictement en lecture seule.
(function(root){
 function available(){return !!(root.S&&typeof root.club==='function'&&root.CDV17V10&&root.CDV17UnifiedPC);}
 function snapshot(){
  if(!available())return null;
  const s=root.S,team=root.club(),players=Array.isArray(team?.players)?team.players:[];
  const fixtures=[];
  if(Array.isArray(s.schedule))for(let round=Number(s.round)||0;round<Math.min(s.schedule.length,(Number(s.round)||0)+8);round++){
   const pairs=s.schedule[round];
   if(!Array.isArray(pairs))continue;
   const pair=pairs.find(p=>Array.isArray(p)&&p.includes(s.club));
   if(!pair)continue;
   const opp=pair.find(id=>id!==s.club);
   fixtures.push({id:'round-'+round,round:round+1,opponent:s.clubs?.[opp]?.name||'Adversaire inconnu',date:null,played:false});
  }
  const safePlayers=players.map(p=>({id:p.id,name:p.name,age:p.age,condition:p.condition,injury:p.injury,minutes:p.dev?.minutes??null,fatigue:typeof root.physicalLoadValue==='function'?root.physicalLoadValue(p):null,dev:{minutes:p.dev?.minutes??null}}));
  return {players:safePlayers,fixtures,matches:[],lineup:Array.isArray(s.lineup)?s.lineup.slice():[],reserves:Array.isArray(s.reserves)?s.reserves.slice():[],allowedAttacks:typeof root.ATTACKS==='object'?Object.keys(root.ATTACKS):[],today:null,round:s.round,season:s.season};
 }
 let dashboard=null;
 function create(){
  if(!available())return null;
  return root.CDV17UnifiedPC.create({engine:root.CDV17V10,snapshot,slotEligible:typeof root.slotEligible==='function'?root.slotEligible:null,scenarios:()=>{const s=root.S;return s?[{name:'Composition actuelle',lineup:[...(s.lineup||[]),...(s.reserves||[])],attack:s.tactic}]:[];}});
 }
 function section(){if(!available())return '';try{dashboard=create();return '<div id="v17-manager-office">'+dashboard.render()+'</div>';}catch(e){return '<section class="card">Centre V17 indisponible : donnees natives incompletes.</section>';}}
 function install(){if(typeof root.managerOffice!=='function')return false;if(root.managerOffice.__v17Wrapped)return true;const original=root.managerOffice;function wrapped(){return original()+'<section class="card v17-office-integration" aria-label="Centre de commandement V17">'+section()+'</section>';}wrapped.__v17Wrapped=true;root.managerOffice=wrapped;return true;}
 if(typeof document!=='undefined')document.addEventListener('change',function(e){if(!e.target?.matches?.('#v17-manager-office [data-v17-panel]'))return;const host=document.getElementById('v17-manager-office');if(!host||!dashboard)return;const selected=Array.from(host.querySelectorAll('[data-v17-panel]:checked')).map(x=>x.getAttribute('data-v17-panel'));dashboard.setPreferences({enabled:selected,density:dashboard.getPreferences().density});host.innerHTML=dashboard.render();});
 if(typeof document!=='undefined')document.addEventListener('click',function(e){if(!e.target?.matches?.('#v17-manager-office [data-v17-density]'))return;const host=document.getElementById('v17-manager-office');if(!host||!dashboard)return;const opts=dashboard.getPreferences();dashboard.setPreferences({enabled:opts.enabled,density:opts.density==='compact'?'comfortable':'compact'});host.innerHTML=dashboard.render();});
 root.CDV17Native=Object.freeze({snapshot,install,section});
 if(typeof root.managerOffice==='function')install();
})(typeof globalThis==='object'?globalThis:window);
