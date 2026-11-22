'use strict';
// Sonde de carrière Monde : verrou « carrière mondiale » des parcours du Centre retiré dans le moteur (copie
// locale, rien n'est modifié dans le jeu), avec la topologie choisie, puis activation, commandes et saison.
// Usage : node sonde-4.cjs <club> <brut|france30|pays> [matchs]
const path=require('node:path');
const H=require(path.join(__dirname,'../../tests/helpers/carriere-monde.cjs'));
const academy=require(path.join(__dirname,'../../native/engine/academy.cjs'));
const club=Number(process.argv[2]||9),variante=process.argv[3]||'brut',matchs=Number(process.argv[4]||0);
const jeu=H.ouvrir({hebdomadaire:true,simulation:true,testVm:true});
let model=H.creer(jeu,club);
const run=s=>jeu.bridge.vm.run(s),lire=s=>JSON.parse(run('JSON.stringify('+s+')'));
let src=academy.factory.toString();
const avant="const centers=s.clubs.map(c=>({id:'club:'+c.id,clubId:c.id}));for(let i=0;i<44-s.clubs.length;i++)";
if(!src.includes(avant))throw Error('motif topologie introuvable');
if(variante==='france30')src=src.replace(avant,"const centers=s.clubs.filter(c=>c.id<30).map(c=>({id:'club:'+c.id,clubId:c.id}));for(let i=0;centers.length<44;i++)");
// « pays » : 30 clubs français si le club est français ; sinon le club du joueur + des centres invités (pas de vrais voisins).
if(variante==='pays')src=src.replace(avant,"const fr=s.club<30,centers=s.clubs.filter(c=>fr?c.id<30:c.id===s.club).map(c=>({id:'club:'+c.id,clubId:c.id}));for(let i=0;centers.length<44;i++)");
// Validation : mêmes bornes, comptées sur les clubs retenus (N) au lieu de tous les clubs du jeu.
if(variante!=='brut'){const a1="n.centers.filter(c=>c.clubId!==null).length===s.clubs.length",a2="n.centers.every((c,i)=>c.id===(i<s.clubs.length?'club:'+i:'guest:'+(i-s.clubs.length)))";if(!src.includes(a1)||!src.includes(a2))throw Error('motif validation introuvable');src=src.replace(a1,'true').replace(a2,"n.centers.every(c=>c.clubId===null?c.id.startsWith('guest:'):c.id==='club:'+c.clubId)");}
run(`(()=>{const CDWorldCareer={active:()=>false};Object.assign(nativeSystems.domain('academyPathways'),(${src})());})()`);
const res={club,variante,etapes:[]};
const essai=(label,command,payload)=>{const r=jeu.brut(command,payload);res.etapes.push({label,ok:r.ok,erreur:r.ok?undefined:r.error});if(r.ok)model=r.model;return r.ok;};
const ctx=()=>model.clubLife.academyPathways.context;
let ok=essai('activation','academy_activate',{...ctx(),confirmed:true});
if(ok){
 const ap=model.clubLife.academyPathways;
 res.centres={total:ap.centers?.length,division:ap.division,invites:ap.centers?.filter(c=>c.clubId===null).length,loanClubs:ap.loanClubs?.length,loanClubsHors30:ap.loanClubs?.filter(c=>c.id>=30).length,recruitBudget:ap.recruitBudget,cash:ap.cash};
 essai('detection (35 000)','academy_scout',{...ctx(),confirmed:true});
 const jeune=model.clubLife.academyPathways.players[0];
 essai('mentorat (8 000)','academy_mentor',{...ctx(),playerId:jeune.id,focus:'technique',confirmed:true});
 const autre=model.clubLife.academyPathways.centers.find(c=>!c.own);
 essai('detection centre (1 200)','academy_center_scout',{...ctx(),centerId:autre.id,confirmed:true});
 essai('installations','academy_upgrade',{...ctx(),kind:'facilities',confirmed:true});
 const promu=model.clubLife.academyPathways.players.find(p=>p.age<=21);if(promu)essai('promotion pro','academy_promote',{...ctx(),playerId:promu.id,years:2,confirmed:true});
 const senior=model.clubLife.academyPathways.seniors.find(p=>p.loanEligible);
 const loin=model.clubLife.academyPathways.loanClubs.find(c=>c.id>=30);
 if(senior&&loin)essai('pret vers club hors France (id '+loin.id+')','academy_loan',{...ctx(),playerId:senior.id,to:loin.id,confirmed:true});
 else res.etapes.push({label:'pret hors France',ok:null,erreur:senior?'aucun club >=30 propose':'aucun senior pretable'});
 try{for(let k=0;k<matchs;k++){model=H.jouer(jeu,model,1);}res.etapes.push({label:matchs+' matchs joues',saison:lire('S.season'),ok:true,round:lire('S.round'),espoirs:lire('S.v73Espoirs?.round'),accession:lire('S.v74Accession?.round')});}
 catch(e){res.etapes.push({label:'saison',ok:false,erreur:String(e.message).slice(0,300),round:lire('S.round')});}
}
console.log(JSON.stringify(res,null,1));
jeu.fermer();
