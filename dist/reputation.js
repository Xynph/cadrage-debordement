'use strict';
// V47 : calculs de carrière fictifs ; aucun effet de bord.
(function(root,factory){const api=factory();if(typeof module==='object'&&module.exports)module.exports=api;if(root)root.CDReputation=api})(typeof globalThis==='object'?globalThis:null,function(){const num=n=>typeof n==='number'&&Number.isFinite(n)&&n>=0;
function update({current,leagueFinish,leagueSize,champion=false,financeHealthy=true}){if(!num(current)||current>100||!Number.isInteger(leagueFinish)||!Number.isInteger(leagueSize)||leagueSize<2||leagueFinish<1||leagueFinish>leagueSize||typeof champion!=='boolean'||typeof financeHealthy!=='boolean')throw Error('Données invalides');const performance=(leagueSize-leagueFinish)/(leagueSize-1)*100;const target=Math.min(100,performance*.7+(champion?20:0)+(financeHealthy?10:0));const next=Math.max(0,Math.min(100,Math.round(current*.8+target*.2)));return {previous:current,next,delta:next-current,performance};}
return Object.freeze({update});});
