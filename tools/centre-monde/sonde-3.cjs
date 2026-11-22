'use strict';
// Inventaire des clubs du Monde : championnat, pays, caisse, jouables, taille des centres des IA.
const path=require('node:path');const fs=require('node:fs');
const {ouvrir,creer}=require(path.join(__dirname,'../../tests/helpers/carriere-monde.cjs'));
const jeu=ouvrir({hebdomadaire:true,simulation:true,testVm:true});
creer(jeu,Number(process.argv[2]||102));
const lire=s=>JSON.parse(jeu.bridge.vm.run('JSON.stringify('+s+')'));
const r=lire(`(()=>{const e=CDWorldCareer.edition(S),reg=e.registry.clubs;return {playable:e.playable,leagueIds:e.leagueIds,limits:e.limits,
clubs:S.clubs.map((c,i)=>({id:c.id,name:c.name,cash:c.cash,league:reg[i]?.leagueId,division:reg[i]?.division,country:reg[i]?.country,players:c.players.length,academy:(c.id===S.club?S.development.academy:S.aiRoster.academies.find(a=>a.clubId===c.id)?.players||[]).length}))}})()`);
fs.writeFileSync(path.join(__dirname,'clubs-monde.json'),JSON.stringify(r,null,1));
const by={};for(const c of r.clubs){const k=c.league+' '+c.country;(by[k]=by[k]||[]).push(c.cash);}
for(const [k,v] of Object.entries(by))console.log(k.padEnd(22),String(v.length).padStart(3),'caisse min',Math.min(...v),'max',Math.max(...v));
console.log('playable',JSON.stringify(r.playable).slice(0,300));console.log('limits',JSON.stringify(r.limits).slice(0,300));
jeu.fermer();
