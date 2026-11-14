'use strict';
// Passage à la saison suivante (next_season) d'une carrière Monde complète (world-champ, club 102) :
// borne de durée large et gardes d'égalité des chemins accélérés du passage de saison.
// La recette Windows du vrai EXE attend chaque réponse du moteur au plus 20 s ; le passage de saison
// en prenait 12 à 17 sur un poste de développement avant l'accélération (voir la PR « nouvelle saison
// rapide »). CD_NOUVELLE_SAISON_MAX_MS ajuste la borne (machine lente, mesure).
const assert=require('node:assert/strict');
const {context}=require('./monde-harness.cjs');

const LIMITE=Number(process.env.CD_NOUVELLE_SAISON_MAX_MS||20000);
const h=context(827381,{club:102});
try{
 const debut=Date.now();
 h.season();
 assert.equal(h.run("S.phase"),'ended','saison 1 terminée');
 const saison1=Date.now()-debut;

 // Gardes d'égalité sur l'état d'intersaison réel (tous les joueurs de la carrière) : chaque fonction
 // accélérée rend exactement ce que rendait sa forme d'origine, recopiée ici telle quelle.
 const gardes=JSON.parse(h.run(`JSON.stringify((()=>{
  const noteOrigine=(p,f=p?.fam)=>{if(!p)return 0;const w=ROLE_WEIGHTS[f]||ROLE_WEIGHTS[7];return Math.round(Object.entries(w).reduce((s,[k,v])=>s+skill(p,k)*v,0)/Object.values(w).reduce((s,v)=>s+v,0))};
  const viviersOrigine=()=>[...new Map([...S.market,...S.economy.freeAgents].filter(p=>!S.clubs.some(c=>c.players.some(x=>x.id===p.id))).map(p=>[p.id,p])).values()];
  const joueurs=[...S.clubs.flatMap(c=>c.players),...S.development.academy,...S.aiRoster.academies.flatMap(a=>a.players),...S.economy.freeAgents,...S.market];
  let notes=0,ecarts=[];
  for(const p of joueurs)for(const f of [undefined,0,1,2,3,4,5,6,7,8]){notes++;const a=roleNote(p,f),b=noteOrigine(p,f);if(!Object.is(a,b)&&ecarts.length<5)ecarts.push([p.id,f,a,b]);}
  const vivier=managerPool().map(p=>p.id),origine=viviersOrigine().map(p=>p.id);
  return {notes,ecarts,vivier:vivier.length,vivierEgal:JSON.stringify(vivier)===JSON.stringify(origine)};
 })())`));
 assert.ok(gardes.notes>10000,'notes comparées sur toute la carrière');
 assert.deepEqual(gardes.ecarts,[],'note de poste identique à la forme d’origine');
 assert.ok(gardes.vivier>0&&gardes.vivierEgal,'vivier du recrutement identique à la forme d’origine');

 // Le passage de saison complet par le worker (commande, validation, sauvegarde, projection du modèle).
 const avant=Date.now();
 const model=h.command('next_season',{confirmed:true});
 const duree=Date.now()-avant;
 assert.equal(model.meta.season,2,'saison 2 atteinte');
 assert.equal(h.run('S.phase'),'league');
 const relecture=Date.now();h.command('snapshot');const modele=Date.now()-relecture;
 console.log(JSON.stringify({saison1Ms:saison1,nextSeasonMs:duree,snapshotMs:modele,limiteMs:LIMITE,notes:gardes.notes,vivier:gardes.vivier}));
 assert.ok(duree<LIMITE,'next_season en '+duree+' ms (borne '+LIMITE+' ms)');
}finally{h.close();}
