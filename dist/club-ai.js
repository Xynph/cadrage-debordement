'use strict';
// V46 : calculs de carrière fictifs ; aucun effet de bord.
(function(root,factory){const api=factory();if(typeof module==='object'&&module.exports)module.exports=api;if(root)root.CDClubAI=api})(typeof globalThis==='object'?globalThis:null,function(){const num=n=>typeof n==='number'&&Number.isFinite(n)&&n>=0;
function decideClub({cash,wageRoom,needs=[],candidates=[]}){if(![cash,wageRoom].every(num)||!Array.isArray(needs)||!Array.isArray(candidates))throw Error('Données invalides');const ranked=candidates.filter(p=>p&&typeof p.id==='string'&&num(p.fee)&&num(p.wage)&&num(p.rating)&&p.fee<=cash*.3&&p.wage<=wageRoom&&needs.includes(p.pos)).map(p=>({id:p.id,pos:p.pos,score:p.rating-p.fee/100000-p.wage/10000,fee:p.fee,wage:p.wage})).sort((a,b)=>b.score-a.score||a.id.localeCompare(b.id));return {action:ranked.length?'scout':'conserve',candidate:ranked[0]||null,maxFee:cash*.3};}
return Object.freeze({decideClub});});
