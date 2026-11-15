'use strict';
// Mesure du poids des données d'une carrière Monde (world-champ, club 102) : taille de la sauvegarde par
// section, taille du modèle de l'interface par domaine, temps de projection par domaine, temps d'une décision,
// d'un jour et de next_season, et croissance d'une saison à l'autre.
// Usage : node --max-old-space-size=2000 scripts/mesure-poids-donnees.cjs [saisons=1] [sortie.json]
// CD_MESURE_REPRISE=fichier.json reprend une carrière déjà avancée (checkpoint {text,seed}) au lieu de la simuler.
const fs=require('node:fs');
const {context}=require('../tests/monde-harness.cjs');
const SAISONS=Math.max(1,Number(process.argv[2]||1));
const SORTIE=process.argv[3]||null;
const mo=n=>Math.round(n/1048576*100)/100;
const ms=t=>Math.round(t);
const len=v=>{const t=JSON.stringify(v);return t===undefined?0:Buffer.byteLength(t);};
const top=(obj,n=12)=>Object.entries(obj).sort((a,b)=>b[1]-a[1]).slice(0,n);

function sauvegarde(h){
 const s=JSON.parse(h.run('JSON.stringify(S)'));
 const sections={};for(const k of Object.keys(s))sections[k]=len(s[k]);
 // Sous-sections des plus grosses sections (ce qui grossit sans fin).
 const detail={};
 for(const [k] of top(sections,8)){const v=s[k];if(v&&typeof v==='object'&&!Array.isArray(v)){detail[k]={};for(const kk of Object.keys(v))detail[k][kk]=len(v[kk]);}else if(Array.isArray(v))detail[k]={'[n]':v.length};}
 // Joueurs : historiques et statistiques portés par chaque joueur.
 const joueurs=[...s.clubs.flatMap(c=>c.players||[])],champs={};
 for(const p of joueurs)for(const kk of Object.keys(p))champs[kk]=(champs[kk]||0)+len(p[kk]);
 const total=Buffer.byteLength(h.run('JSON.stringify(S)'));
 const fichier=Object.values(h.store).reduce((a,v)=>a+(typeof v==='string'?Buffer.byteLength(v):len(v)),0);
 return {total,fichier,sections,detail,joueurs:joueurs.length,champsJoueur:champs};
}

function modele(m){
 const domaines={};
 for(const k of Object.keys(m)){
  const v=m[k];
  if(['clubLife','meta','staff','decisions'].includes(k)&&v&&typeof v==='object'){for(const kk of Object.keys(v))domaines[k+'.'+kk]=len(v[kk]);}
  else domaines[k]=len(v);
 }
 return {total:len(m),domaines};
}

function projections(h){
 // Temps de chaque appel de projection (VM) et de la projection complète (snapshot).
 const t={};
 const time=(nom,src)=>{const a=performance.now();h.run(src);t[nom]=ms(performance.now()-a);};
 time('nativeModel','JSON.stringify(nativeModel()).length');
 time('nativeDecisions','JSON.stringify(nativeDecisions()).length');
 time('knowledge.reports','JSON.stringify(nativeKnowledge.reports(S)).length');
 time('knowledge.visibility','JSON.stringify(nativeKnowledge.visibility(S)).length');
 const ids=JSON.parse(h.run('JSON.stringify(Object.keys(nativeSystems.project()))'));
 for(const id of ids)time('systems.'+id,`JSON.stringify(nativeSystems.domain(${JSON.stringify(id)}).project()).length`);
 return t;
}

function commande(h,name,payload={}){
 const a=performance.now();const m=h.command(name,payload);const d=performance.now()-a;return {m,d:ms(d)};
}

function etape(h,etiquette){
 const out={etiquette,date:h.run('S.calendarToday||S.date||null'),saison:h.run('S.season')};
 out.sauvegarde=sauvegarde(h);
 const s=commande(h,'snapshot');out.snapshotMs=s.d;out.modele=modele(s.m);
 out.projections=projections(h);
 return out;
}

const h=context(Number(process.env.CD_MESURE_GRAINE||827381),{club:102});
const resultats={saisons:[]};
try{
 if(process.env.CD_MESURE_REPRISE){const cp=JSON.parse(fs.readFileSync(process.env.CD_MESURE_REPRISE,'utf8'));h.restore(cp);h.run('save()');}
 else resultats.saisons.push(etape(h,'création'));
 for(let i=0;i<SAISONS;i++){
  let saisonMs=null;
  if(h.run("S.phase!=='ended'")){const a=performance.now();h.season();saisonMs=ms(performance.now()-a);
   if(process.env.CD_MESURE_CHECKPOINT)fs.writeFileSync(process.env.CD_MESURE_CHECKPOINT+'-fin-s'+h.run('S.season')+'.json',JSON.stringify(h.checkpoint()));}
  const fin=etape(h,'fin de saison '+h.run('S.season'));fin.saisonMs=saisonMs;resultats.saisons.push(fin);
  h.run('delete S.clubMeetings');const ns=commande(h,'next_season',{confirmed:true});h.run('delete S.clubMeetings');
  // Quelques semaines dans la nouvelle saison : décisions, jour, modèle courant.
  h.week(3);h.toMatch();h.run('save()');
  const e=etape(h,'saison '+h.run('S.season')+' semaine 4');e.nextSeasonMs=ns.d;
  const d=commande(h,'auto_lineup');e.decisionMs=d.d;
  resultats.saisons.push(e);
  if(process.env.CD_MESURE_CHECKPOINT)fs.writeFileSync(process.env.CD_MESURE_CHECKPOINT+'-s'+h.run('S.season')+'.json',JSON.stringify(h.checkpoint()));
  console.error('saison',h.run('S.season'),'sauvegarde',mo(e.sauvegarde.total),'Mo modèle',mo(e.modele.total),'Mo');
 }
}finally{h.close();}
const lignes=[];
for(const e of resultats.saisons){
 lignes.push(`== ${e.etiquette} (${e.date}) : sauvegarde ${mo(e.sauvegarde.total)} Mo, modèle ${mo(e.modele.total)} Mo, snapshot ${e.snapshotMs} ms`+(e.nextSeasonMs?`, next_season ${e.nextSeasonMs} ms, décision ${e.decisionMs} ms`:''));
 lignes.push('  sauvegarde : '+top(e.sauvegarde.sections,14).map(([k,v])=>k+' '+mo(v)).join(', '));
 lignes.push('  joueurs ('+e.sauvegarde.joueurs+') : '+top(e.sauvegarde.champsJoueur,10).map(([k,v])=>k+' '+mo(v)).join(', '));
 for(const [k,v] of Object.entries(e.sauvegarde.detail))lignes.push('  '+k+' : '+top(v,8).map(([kk,vv])=>kk+' '+(kk==='[n]'?vv:mo(vv))).join(', '));
 lignes.push('  modèle : '+top(e.modele.domaines,16).map(([k,v])=>k+' '+mo(v)).join(', '));
 lignes.push('  projection (ms) : '+top(e.projections,16).map(([k,v])=>k+' '+v).join(', '));
}
console.log(lignes.join('\n'));
if(SORTIE)fs.writeFileSync(SORTIE,JSON.stringify(resultats,null,1));
