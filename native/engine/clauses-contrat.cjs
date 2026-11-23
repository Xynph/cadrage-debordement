'use strict';
// Offre guidée (revue FM27, idée 17 ; décision de Léo du 23/11/2026) : ce que le contrat peut porter en plus du salaire et de
// la durée, au plus près du rugby professionnel mais jouable. Ni paiement en plusieurs versements ni pourcentage à la revente.
//  - Prime à la signature négociable : la prime de base (contractFee de dist/economy.js) peut être augmentée par crans ;
//    chaque euro de prime en plus remplace un euro de salaire sur la durée du contrat (salaire minimum accepté abaissé de
//    prime en plus / (semaines payées × saisons), au plus 15 %). La prime passe par le budget de transferts (comme avant),
//    le salaire par la masse salariale et le plafond de la ligue.
//  - Clause libératoire : montant fixé à la signature (sans clause, haute, moyenne, basse), multiple de la valeur du joueur
//    (transferValue) à la signature, arrondi à 10 000 €. Plus elle est basse, plus le joueur baisse sa demande (2, 4, 7 %),
//    mais un club géré peut la payer pendant la période des mutations : le joueur part au changement de saison, l'argent est
//    encaissé tout de suite (accord « bascule » de vente-joueurs.cjs). Rare : une semaine de la période sur 33 au plus est
//    tirée (graine + saison + semaine), une seule clause payée par saison, jamais la saison de la signature, seulement si la
//    clause vaut au plus 1,3 fois la valeur actuelle du joueur et qu'il est dans la meilleure moitié de l'effectif, et
//    seulement si un club géré en a besoin et les moyens.
//    Enregistrée sur le joueur : p.clauseLiberatoire = {niveau, montant, saison, fin, club}, rattachée à CE contrat (fin, club).
//  - Joueurs des clubs gérés (marché entre clubs) : un sur trois a une clause, dérivée sans état de son salaire (2,5 à 4,5
//    saisons de salaire, tirage déterministe sur l'identifiant et la fin de contrat). La payer oblige le vendeur à le laisser
//    partir, même s'il refusait (effectif minimum, famille de poste) ; le joueur doit encore accepter son salaire.
//  - Prix d'ouverture : le vendeur accepte une indemnité un peu sous sa demande (90 à 95 %, tirage sur le joueur et la
//    saison) et contre-propose ce minimum sinon (interclub-market.cjs).
// Signer à l'avance (dernière année de contrat, sans indemnité) : déjà le pré-contrat de calendrier-mutations.cjs.
// Plafond salarial : déjà dans club-budget.cjs (finance.budget.plafondSalarial / margePlafond), affiché sur l'offre.
// Fonctions globales de la VM : clausesOffre(p, kind), clausesPreparer(p, kind, payload), clausesFin(), clausesPoser(p,
// extras), clauseIA(p), clauseVendeurMinimum(p, fee), clauseJoueur(p).
const files=Object.freeze([]),commands=Object.freeze([]);
function factory(){
 const NIVEAUX=Object.freeze(['sans','haute','moyenne','basse']);
 const REGLES=Object.freeze({
  clauses:Object.freeze({haute:Object.freeze({fois:2.5,remise:.02}),moyenne:Object.freeze({fois:1.6,remise:.04}),basse:Object.freeze({fois:1,remise:.07})}),
  arrondiClause:10000,clauseMin:20000,
  prime:Object.freeze({part:.15,crans:3,arrondi:1000}),
  ia:Object.freeze({partAvecClause:35,saisonsMin:2.5,saisonsPas:.5,saisonsCrans:5,seuilValeur:1.3,chanceSemaine:30,besoinMin:20,reserveAcheteur:350000,activationsParSaison:1}),
  vendeur:Object.freeze({ouverture:.9,ecart:6,arrondi:1000}),
 });
 // FNV-1a 32 bits, comme seedHash (dist/rugby.js).
 function hash(text){let h=2166136261;for(const ch of String(text)){h^=ch.charCodeAt(0);h=Math.imul(h,16777619);}return h>>>0;}
 const entier=x=>Number.isSafeInteger(x);
 const arrondiHaut=(x,pas)=>Math.ceil(x/pas)*pas;
 // Montants des trois clauses pour une valeur de joueur.
 function niveaux(valeur){
  const v=Math.max(0,Number(valeur)||0);
  return [{niveau:'sans',montant:0,remise:0},...['haute','moyenne','basse'].map(n=>({niveau:n,montant:Math.max(REGLES.clauseMin,arrondiHaut(v*REGLES.clauses[n].fois,REGLES.arrondiClause)),remise:REGLES.clauses[n].remise}))];
 }
 const remise=niveau=>REGLES.clauses[niveau]?.remise||0;
 // Crans de prime en plus de la prime de base pour une durée : 0, puis 1/3, 2/3 et 3/3 de 15 % des salaires demandés.
 function crans(demande,semaines,annees){
  const max=REGLES.prime.part*Math.max(0,demande)*Math.max(1,semaines)*Math.max(1,annees),r=REGLES.prime.arrondi;
  const out=[0];for(let k=1;k<=REGLES.prime.crans;k++)out.push(Math.max(r,arrondiHaut(max*k/REGLES.prime.crans,r)));
  return [...new Set(out)];
 }
 // Salaire minimum accepté (non arrondi) une fois la clause et la prime en plus comptées ; arrondi à la centaine supérieure.
 function minimum(brut,{niveau='sans',extra=0,semaines=46,annees=1}={}){
  const apresClause=brut*(1-remise(niveau));
  const baisse=Math.min(Math.max(0,extra)/(Math.max(1,semaines)*Math.max(1,annees)),REGLES.prime.part*brut);
  return Math.ceil(Math.max(0,apresClause-baisse)/100)*100;
 }
 // Clause d'un joueur d'un club géré : un sur trois environ, 2,5 à 4,5 saisons de salaire ; null sinon.
 function clauseIA(id,salaire,fin){
  const I=REGLES.ia,h=hash('clause|'+id+'|'+fin);
  if(!entier(salaire)||salaire<=0||h%100>=I.partAvecClause)return null;
  const saisons=I.saisonsMin+((h>>>8)%I.saisonsCrans)*I.saisonsPas;
  return Math.max(REGLES.clauseMin,arrondiHaut(salaire*52*saisons,REGLES.arrondiClause));
 }
 // Indemnité minimale que le vendeur accepte (90 à 95 % de sa demande, au millier supérieur, jamais au-dessus de la demande).
 function vendeurMinimum(id,saison,demande){
  const V=REGLES.vendeur,part=V.ouverture+(hash('vendeur|'+id+'|'+saison)%V.ecart)/100;
  return Math.min(demande,arrondiHaut(demande*part,V.arrondi));
 }
 const valide=c=>!!c&&typeof c==='object'&&['haute','moyenne','basse'].includes(c.niveau)&&entier(c.montant)&&c.montant>0&&entier(c.saison)&&entier(c.fin)&&entier(c.club);
 const etatValide=e=>!!e&&typeof e==='object'&&e.version===1&&(e.semaine===null||typeof e.semaine==='string')&&Array.isArray(e.activations)&&e.activations.every(a=>a&&entier(a.saison)&&typeof a.playerId==='string'&&entier(a.clubId)&&entier(a.montant));
 // Semaine tirée pour une activation (graine, saison, semaine) : 30 chances sur 1 000.
 const semaineTiree=(graine,saison,semaine)=>hash(graine+':'+saison+':'+semaine+':clause')%1000<REGLES.ia.chanceSemaine;
 let actif=null;
 const vm=()=>typeof S==='undefined'?null:S;
 const semaines=()=>typeof wageForecastWeeks==='function'?wageForecastWeeks():46;
 const valeur=p=>typeof transferValue==='function'?transferValue(JSON.parse(JSON.stringify(p))):0;
 // Ce que l'écran d'offre lit (model.cjs) : prime de base, crans par durée, clauses avec leur montant et leur effet.
 function offre(p,kind){
  const demande=askingWage(p,kind),w=semaines();
  return {semaines:w,primeBase:contractFee(p,kind),crans:{1:crans(demande,w,1),2:crans(demande,w,2),3:crans(demande,w,3)},partPrime:REGLES.prime.part,clauses:niveaux(valeur(p))};
 }
 // Avant negotiateContract (gestion.cjs) : vérifie prime et clause, puis les rend actives pour ce joueur pendant la commande.
 function preparer(p,kind,payload){
  const niveau=payload.clause===undefined?'sans':payload.clause;
  if(!NIVEAUX.includes(niveau))throw Error('Offre invalide.');
  const base=contractFee(p,kind),prime=payload.prime===undefined?base:payload.prime;
  if(!entier(prime)||prime<base)throw Error('Prime invalide : au moins '+base+' €.');
  const extra=prime-base,max=crans(askingWage(p,kind),semaines(),3).at(-1);
  if(extra>max||extra%REGLES.prime.arrondi!==0)throw Error('Prime invalide : au plus '+(base+max)+' €, par milliers.');
  const clause=niveaux(valeur(p)).find(x=>x.niveau===niveau);
  actif={id:p.id,kind,niveau,montant:clause.montant,extra,annees:payload.years};
  return {...actif};
 }
 function fin(){actif=null;}
 function poser(p,extras,s=vm()){
  if(!p||!s)return false;
  if(!extras||extras.niveau==='sans'){delete p.clauseLiberatoire;return true;}
  p.clauseLiberatoire={niveau:extras.niveau,montant:extras.montant,saison:s.season,fin:p.contractEnd,club:s.club};
  return true;
 }
 // Clause en vigueur d'un joueur : la sienne si elle tient à son contrat et à son club, sinon celle dérivée d'un club géré.
 function joueur(p,clubId,s=vm()){
  if(!p||!s)return null;
  const c=p.clauseLiberatoire;
  if(valide(c)&&c.fin===p.contractEnd&&c.club===clubId)return {niveau:c.niveau,montant:c.montant,saison:c.saison};
  if(clubId===s.club)return null;
  const m=clauseIA(p.id,p.salary,p.contractEnd);return m?{niveau:'ia',montant:m,saison:null}:null;
 }
 function etat(ecrire){
  const s=vm();if(etatValide(s?.clausesContrat))return s.clausesContrat;
  const neuf={version:1,semaine:null,activations:[]};if(ecrire&&s)s.clausesContrat=neuf;return neuf;
 }
 // Un club géré paie la clause d'un joueur du club joué (période des mutations, au plus une par saison).
 // force : tests (ni période ni tirage).
 function activer({force=false}={}){
  const s=vm();if(!s||s.live||!s.clubs?.[s.club]||typeof venteNouvelAccord!=='function'||typeof calFenetreAccords!=='function')return null;
  const acc=calFenetreAccords();if(!acc||!acc.reouverture)return null;
  const jour=typeof venteJour==='function'?venteJour():null;
  if(!force){
   if(!jour||!nativeVenteJoueurs.fenetre(jour,nativeVenteJoueurs.REGLAGES).ouverte)return null;
   const cle=s.season+':'+(s.economy?.week??s.round),st=etat(true);if(st.semaine===cle)return null;st.semaine=cle;
   if(!semaineTiree(typeof venteGraine==='function'?venteGraine():0,s.season,s.economy?.week??s.round))return null;
  }
  const I=REGLES.ia,st=etat(true);
  if(st.activations.filter(a=>a.saison===s.season).length>=I.activationsParSaison)return null;
  const c=s.clubs[s.club],notes=c.players.map(p=>roleNote(p)).sort((a,b)=>b-a),mediane=notes[Math.floor(notes.length/2)]??0;
  const cands=c.players.map(p=>({p,cl:joueur(p,s.club)})).filter(({p,cl})=>cl&&cl.saison<s.season&&roleNote(p)>=mediane&&
   !(typeof venteRaisonListe==='function'&&venteRaisonListe(p))&&!(typeof venteGarde==='function'&&venteGarde(p))&&cl.montant<=valeur(p)*I.seuilValeur)
   .map(x=>({...x,attrait:valeur(x.p)/x.cl.montant})).sort((a,b)=>b.attrait-a.attrait||(a.p.id<b.p.id?-1:1));
  for(const {p,cl} of cands){
   const acheteurs=s.clubs.filter(b=>b.id!==s.club&&b.cash>=cl.montant+I.reserveAcheteur&&(typeof calIAPeutAcheter!=='function'||calIAPeutAcheter(b,p.salary)))
    .map(b=>({b,besoin:typeof venteBesoin==='function'?venteBesoin(b,p):0})).filter(x=>x.besoin>=I.besoinMin).sort((x,y)=>y.besoin-x.besoin||x.b.id-y.b.id);
   if(!acheteurs.length)continue;
   const b=acheteurs[0].b;
   const a=venteNouvelAccord({playerId:p.id,joueur:p.name,buyer:b.id,acheteur:b.name,fee:cl.montant,date:acc.reouverture,saison:s.season,clause:true});
   const quand=typeof calJourMois==='function'?calJourMois(a.date):nativeVenteJoueurs.dateFr(a.date);
   transferEvent(b.name+' paie la clause libératoire de '+p.name+' ('+nativeVenteJoueurs.euros(cl.montant)+') : il partira le '+quand+'.');
   const act={saison:s.season,playerId:p.id,joueur:p.name,clubId:b.id,club:b.name,montant:cl.montant,date:a.date};
   st.activations.push(act);st.activations=st.activations.slice(-20);
   return act;
  }
  return null;
 }
 function validate(s){
  for(const c of Array.isArray(s?.clubs)?s.clubs:[])for(const p of c?.players||[])
   if(p&&p.clauseLiberatoire!==undefined&&!valide(p.clauseLiberatoire))throw Error('Clause libératoire invalide.');
  if(s&&s.clausesContrat!==undefined&&!etatValide(s.clausesContrat))throw Error('État des clauses libératoires invalide.');
  return true;
 }
 function installHooks(){
  globalThis.clausesOffre=(p,kind)=>offre(p,kind);
  globalThis.clausesPreparer=(p,kind,payload)=>preparer(p,kind,payload);
  globalThis.clausesFin=()=>fin();
  globalThis.clausesPoser=(p,extras)=>poser(p,extras);
  globalThis.clauseIA=p=>p?clauseIA(p.id,p.salary,p.contractEnd):null;
  globalThis.clauseJoueur=(p,clubId)=>joueur(p,clubId);
  globalThis.clauseVendeurMinimum=(p,demande)=>vendeurMinimum(p.id,vm()?.season,demande);
  // Prime et clause actives (commande recruit / extend_contract en cours) : salaire minimum abaissé, prime augmentée.
  if(typeof reservationWage==='function'&&!reservationWage.__clauses){
   const original=reservationWage,wrapped=function(p,kind,years){
    if(!actif||!p||p.id!==actif.id||kind!==actif.kind)return original.apply(this,arguments);
    const age=p.age>=31&&years===3?1.12:years===1?1.08:years===3?.96:1;
    const brut=askingWage(p,kind)*(.86+(seedHash(p.id)%8)/100)*age*(1+satisfactionWageRate(p,kind));
    return Math.min(original.apply(this,arguments),minimum(brut,{niveau:actif.niveau,extra:actif.extra,semaines:semaines(),annees:years}));
   };
   Object.assign(wrapped,original);wrapped.__clauses=true;reservationWage=wrapped;
  }
  if(typeof contractFee==='function'&&!contractFee.__clauses){
   const original=contractFee,wrapped=function(p,kind){const fee=original.apply(this,arguments);return actif&&p&&p.id===actif.id&&kind===actif.kind&&Number.isFinite(fee)?fee+actif.extra:fee;};
   Object.assign(wrapped,original);wrapped.__clauses=true;contractFee=wrapped;
  }
  return true;
 }
 return {project(){return null;},validate,execute(){throw Error('Aucune commande de clause.');},installHooks,observe:()=>activer(),activer,clearTransient(){actif=null;},offre,joueur,etat,
  REGLES,NIVEAUX,niveaux,remise,crans,minimum,clauseIA,vendeurMinimum,semaineTiree,hash};
}
// Fonctions pures (tests) : mêmes définitions que dans la VM.
const pur=factory();
module.exports={files,commands,factory,REGLES:pur.REGLES,NIVEAUX:pur.NIVEAUX,niveaux:pur.niveaux,remise:pur.remise,crans:pur.crans,minimum:pur.minimum,clauseIA:pur.clauseIA,vendeurMinimum:pur.vendeurMinimum,semaineTiree:pur.semaineTiree,hash:pur.hash};
