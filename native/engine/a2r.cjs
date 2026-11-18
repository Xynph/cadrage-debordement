'use strict';
// Contrôle de gestion du rugby français (A2R, Autorité de régulation du rugby, ex-DNACG), demande de Léo du 18/11/2026.
//
// Chaque année en juin, l'A2R auditionne les clubs des trois divisions françaises dont les comptes sont dans le
// rouge et rend une décision par courrier, par ordre de gravité :
//   1. autorisé sous conditions : masse salariale encadrée (pas au-dessus de celle du jour de l'audition) ;
//   2. contrats des nouvelles recrues non homologués, tant que les comptes ne sont pas rétablis (Montauban 2024 :
//      neuf contrats non homologués) ;
//   3. apport demandé à l'actionnaire avant le 30 juin (Toulon : augmentation de capital exigée) ; sans apport ni
//      comptes rétablis à l'échéance, la mesure devient une interdiction de recruter ;
//   4. interdiction de recruter jusqu'au début de la saison suivante.
// Pas de relégation administrative (Bourgoin, Biarritz, Narbonne) pour l'instant : décision de Léo.
//
// Léger pour le joueur : une audition par an, un seul courrier pour le club joué (et seulement s'il est convoqué),
// des réponses possibles depuis le mail (apport, appel). Les clubs gérés suivent les mêmes règles en coulisses :
// leur masse autorisée (aiRosterWageLimit) est encadrée ou gelée, leur actionnaire décide seul de l'apport.
// Les mesures tombent au plus tard à la 3e semaine de la saison suivante (fin du mercato d'été).
//
// « Dans le rouge » : trou de fin de saison = caisse négative après le soutien promis du propriétaire, plus la dette.
// Au-dessous de 2 % des recettes, personne ne s'en émeut (même tolérance que le budget de saison). Quand l'étiquette
// de santé financière (chantier « économie façon FM ») sera dans main, le branchement la lira si elle est définie
// (santeFinanciere(id).dette / .tresorerieFin) ; en attendant, il calcule la même chose à partir des comptes.
// Mode Monde uniquement ; décisions déterministes (empreinte par club et saison, jamais le flux de hasard du moteur).

const { apportProprietaire } = require('./club-budget.cjs');

const DIVISIONS = Object.freeze(['elite', 'accession', 'nationale']);
// Parts des recettes de la saison : au-delà, le niveau de la mesure monte.
const SEUILS = Object.freeze({ tolerance: 0.02, homologation: 0.04, apport: 0.08, interdiction: 0.15 });
// Dates (mois-jour) : audition à partir du 10 juin, apport attendu au 30 juin ; fin des mesures : 3e semaine de la saison suivante.
const CALENDRIER = Object.freeze({ audition: '06-10', echeance: '06-30', finMercato: 3 });
const APPEL = Object.freeze({ frais: 15000, chance: 1 / 3 });
const NIVEAUX = Object.freeze({
  1: Object.freeze({ cle: 'conditions', libelle: 'autorisé sous conditions' }),
  2: Object.freeze({ cle: 'homologation', libelle: 'contrats des nouvelles recrues non homologués' }),
  3: Object.freeze({ cle: 'apport', libelle: 'apport demandé à l’actionnaire avant le 30 juin' }),
  4: Object.freeze({ cle: 'interdiction', libelle: 'interdiction de recruter' }),
});

const rond = x => Math.round(x);
const euros = n => new Intl.NumberFormat('fr-FR', { maximumFractionDigits: 0 }).format(Math.round(n)).replace(/[\u202f\u00a0]/g, ' ') + ' €';
// Empreinte FNV-1a ramenée à [0, 1).
function unite(texte) {
  let h = 2166136261;
  for (let i = 0; i < texte.length; i++) { h ^= texte.charCodeAt(i); h = Math.imul(h, 16777619) >>> 0; }
  // Brassage final (murmur3) : des clés voisines donnent des valeurs bien réparties.
  h ^= h >>> 16; h = Math.imul(h, 0x85ebca6b) >>> 0; h ^= h >>> 13; h = Math.imul(h, 0xc2b2ae35) >>> 0; h ^= h >>> 16;
  return (h >>> 0) / 4294967296;
}

// Situation de fin de saison d'un club : caisse après le soutien promis du propriétaire, et trou à combler.
//   tresorerie : caisse du jour ; depart : caisse d'ouverture de la saison ; compte : {enveloppe, reserve} ; dette.
function situation({ tresorerie, depart, compte, dette = 0 }) {
  const deficit = Math.max(0, depart - tresorerie);
  const { apport } = apportProprietaire(compte, deficit, tresorerie);
  const caisseFin = rond(tresorerie + apport);
  return { caisseFin, apportPrevu: rond(apport), dette: rond(Math.max(0, dette)), trou: rond(Math.max(0, -caisseFin) + Math.max(0, dette)) };
}

// Niveau de la décision (0 : pas convoqué). recidive : déjà sanctionné la saison passée (un cran plus sévère).
function examen({ trou, recettes, recidive = false }) {
  const part = Math.max(0, trou) / Math.max(1, recettes);
  if (!(part > SEUILS.tolerance)) return { niveau: 0, part };
  let niveau = part >= SEUILS.interdiction ? 4 : part >= SEUILS.apport ? 3 : part >= SEUILS.homologation ? 2 : 1;
  if (recidive && niveau < 4) niveau++;
  return { niveau, part };
}

// Réponse de l'actionnaire à l'apport demandé (club joué sur demande du manager, clubs gérés à l'échéance).
// Une association n'a pas d'actionnaire ; un mécène suit plus volontiers qu'un groupe, dans la limite de ses moyens.
function reponseActionnaire({ type, montant, enveloppe, recettes, cle }) {
  if (type === 'association') return { accepte: false, motif: 'association' };
  const capacite = type === 'mecene' ? Math.max(2 * enveloppe, 0.12 * recettes) : 1.5 * enveloppe + 0.05 * recettes;
  if (montant > capacite) return { accepte: false, motif: 'montant' };
  return unite(cle) < (type === 'mecene' ? 0.85 : 0.7) ? { accepte: true, motif: null } : { accepte: false, motif: 'refus' };
}
const REFUS = Object.freeze({
  association: 'Le club est une association : il n’a pas d’actionnaire à qui demander de l’argent. Il faudra vendre.',
  montant: 'Le propriétaire refuse : la somme dépasse ce qu’il est prêt à remettre dans le club. Il faudra vendre.',
  refus: 'Le propriétaire refuse de remettre au pot cette fois-ci. Il faudra vendre.',
});

// Raison pour laquelle une recrue n'est pas homologuée ('' : possible). masseHebdo : salaires actuels ; salaire : la recrue.
function refusRecrue(d, { masseHebdo, salaire }) {
  if (!d) return '';
  if (d.niveau === 1) return masseHebdo + salaire > d.encadrement
    ? `L’A2R encadre la masse salariale du club : pas au-delà de ${euros(d.encadrement * 52)} par an. Libère d’abord des salaires.` : '';
  if (d.niveau === 2) return 'L’A2R n’homologue pas les contrats des nouvelles recrues tant que les comptes du club ne sont pas rétablis.';
  if (d.niveau === 3) return `L’A2R n’homologuera aucune recrue sans l’apport de ${euros(d.montant)} demandé avant le 30 juin.`;
  return 'L’A2R a interdit au club de recruter jusqu’au début de la saison prochaine.';
}
// Masse hebdomadaire autorisée d'un club géré sous mesure : encadrée (niveau 1) ou gelée à son niveau du jour.
function limiteGeree(d, { limite, masseHebdo }) {
  if (!d) return limite;
  return Math.min(limite, d.niveau === 1 ? d.encadrement : masseHebdo);
}

// Variables du courrier de décision (club-mail.json, types a2r_*).
function courrier(d, { saison }) {
  const pct = Math.max(1, Math.round(d.part * 100));
  const constat = `Les comptes présentés font apparaître un trou de ${euros(d.montant)} à la fin de la saison${d.dette > 0 ? ' (dette comprise)' : ''}, soit ${pct} % des recettes.`;
  const recidive = d.recidive ? ' Le club avait déjà été épinglé la saison dernière : la commission s’est montrée plus sévère.' : '';
  return { saison, montant: euros(d.montant), constat: constat + recidive, masse: euros(d.encadrement * 52), echeance: '30 juin', frais: euros(APPEL.frais) };
}
// Verdict d'un appel (déterministe par club et saison) : la mesure est ramenée à « autorisé sous conditions ».
function appel(cle) { return unite('appel|' + cle) < APPEL.chance; }

function valide(e) {
  return !!e && typeof e === 'object' && e.version === 1 && (e.saison === null || Number.isInteger(e.saison)) && !!e.decisions && typeof e.decisions === 'object' &&
    !!e.historique && typeof e.historique === 'object' && Object.values(e.decisions).every(d => !!d && Number.isInteger(d.niveau) && d.niveau >= 1 && d.niveau <= 4 &&
      Number.isFinite(d.montant) && Number.isFinite(d.encadrement) && Number.isInteger(d.saison) && ['actif', 'leve'].includes(d.etat));
}

// Code branché dans la carrière (même contexte que club-budget.cjs BRANCHEMENT, exécuté après lui et après les
// investissements). Attend : budgetActif, budgetMonde, budgetLigue, budgetMasse, worldClub, nativeA2R (ce module).
const BRANCHEMENT = `
const a2rActif=()=>budgetActif()&&budgetMonde()&&typeof worldActive==='function'&&worldActive();
const a2rAujourdhui=()=>{try{return CDWorldCareer.calendarToday(S);}catch(e){return null;}};
const a2rEtat=()=>{if(!nativeA2R.valide(S.a2r))S.a2r={version:1,saison:null,date:null,decisions:{},historique:{}};return S.a2r;};
const a2rTally=(k,id)=>{if(typeof nativeClubDirections!=='undefined')nativeClubDirections.tally(k,id);};
// Décision en vigueur pour un club (null : aucune) : de l'audition jusqu'à la 3e semaine de la saison suivante.
function a2rDecision(id){
 const e=S.a2r;if(!e||!e.decisions||!a2rActif())return null;
 const d=e.decisions[id];if(!d||d.etat!=='actif')return null;
 if(d.saison===S.season)return d;
 return d.saison===S.season-1&&(S.worldMode?.week??99)<nativeA2R.CALENDRIER.finMercato?d:null;
}
// Situation de fin de saison : l'étiquette de santé financière si elle existe, sinon les comptes de la saison.
function a2rSituation(c){
 const b=S.clubBudget,compte=b?.clubs?.[c.id],info=worldClub(c.id);
 // Dette de crise (club-owner.cjs) : le prêt de l'actionnaire, remboursé selon un échéancier, n'en fait pas partie.
 const dette=typeof detteDeCrise==='function'?detteDeCrise(c.id):info?.debt||0;
 if(!compte)return null;
 // Saison déjà clôturée (passage de saison) : le soutien du propriétaire est déjà dans la caisse.
 const s=nativeA2R.situation({tresorerie:c.cash,depart:compte.depart,compte:compte.clos===true?{...compte,enveloppe:0}:compte,dette});
 if(typeof santeFinanciere==='function'){try{const x=santeFinanciere(c.id);if(x&&Number.isFinite(x.tresorerieFin)&&Number.isFinite(x.dette))return {...s,caisseFin:x.tresorerieFin,dette:x.dette,trou:Math.max(0,-x.tresorerieFin)+Math.max(0,x.dette)};}catch(e){}}
 return s;
}
const a2rRecettes=c=>Math.max(1,S.clubBudget?.clubs?.[c.id]?.recettes||0);
function a2rAudition(date){
 const e=a2rEtat();e.saison=S.season;e.date=date;e.decisions={};
 for(const c of S.clubs){
  if(!nativeA2R.DIVISIONS.includes(budgetLigue(c.id)))continue;
  const s=a2rSituation(c);if(!s)continue;
  const recidive=e.historique[c.id]===S.season-1,ex=nativeA2R.examen({trou:s.trou,recettes:a2rRecettes(c),recidive});
  if(!ex.niveau){if(c.id===S.club)news('L’A2R a examiné les comptes du club : aucune mesure, le club recrutera librement cet été.');continue;}
  e.decisions[c.id]={niveau:ex.niveau,initial:ex.niveau,montant:Math.max(10000,Math.round(s.trou/10000)*10000),part:Math.round(ex.part*1000)/1000,dette:s.dette,
   date,echeance:date.slice(0,4)+'-'+nativeA2R.CALENDRIER.echeance,encadrement:budgetMasse(c),saison:S.season,etat:'actif',recidive,apport:null,appel:null};
  e.historique[c.id]=S.season;
  a2rTally('a2r:'+nativeA2R.NIVEAUX[ex.niveau].cle,c.id);
 }
 // Historique borné aux deux dernières saisons (récidive).
 for(const [id,s] of Object.entries(e.historique))if(s<S.season-1)delete e.historique[id];
}
// Comptes rétablis : le trou est repassé sous la tolérance.
const a2rRetablis=c=>{const s=a2rSituation(c);return !!s&&s.trou<=a2rRecettes(c)*nativeA2R.SEUILS.tolerance;};
// Échéance du 30 juin : apport de l'actionnaire (clubs gérés), comptes rétablis, sinon interdiction de recruter.
function a2rEcheances(date,force){
 const e=S.a2r;if(!e||!e.decisions)return;
 for(const [id,d] of Object.entries(e.decisions)){
  if(d.etat!=='actif'||d.niveau!==3||d.saison!==S.season&&!force)continue;
  if(!force&&!(date>=d.echeance))continue;
  const c=S.clubs[Number(id)],joue=c.id===S.club,compte=S.clubBudget?.clubs?.[c.id];
  if(a2rRetablis(c)){d.niveau=1;a2rTally('a2r:retabli',c.id);if(joue)news('L’A2R prend acte : les comptes du club sont rétablis. La masse salariale reste encadrée jusqu’à la fin du mercato d’été.');continue;}
  if(!joue&&compte){
   const r=nativeA2R.reponseActionnaire({type:compte.type,montant:d.montant,enveloppe:compte.enveloppe,recettes:a2rRecettes(c),cle:'apport|'+S.season+'|'+c.id});
   if(r.accepte){c.cash+=d.montant;d.apport='verse';d.niveau=1;a2rTally('a2r:apport-verse',c.id);continue;}
   d.apport='refuse';
  }
  d.niveau=4;a2rTally('a2r:aggrave',c.id);
  if(joue)news('Faute d’apport avant le 30 juin, l’A2R interdit au club de recruter jusqu’au début de la saison prochaine.');
 }
}
// Chaque semaine : audition en juin, échéance du 30 juin, levée des mesures (comptes rétablis, fin du mercato d'été).
function a2rSemaine(){
 if(!a2rActif())return;
 const date=a2rAujourdhui();if(!date)return;
 const e=a2rEtat(),md=date.slice(5);
 if(md>=nativeA2R.CALENDRIER.audition&&md<'08-01'&&e.saison!==S.season)a2rAudition(date);
 a2rEcheances(date,false);
 for(const [id,d] of Object.entries(e.decisions)){
  if(d.etat!=='actif')continue;
  if(!a2rDecision(Number(id))){d.etat='leve';continue;}
  const c=S.clubs[Number(id)];
  if(d.niveau===2&&a2rRetablis(c)){d.niveau=1;a2rTally('a2r:retabli',c.id);if(c.id===S.club)news('L’A2R homologue de nouveau les contrats du club : les comptes sont rétablis. La masse salariale reste encadrée jusqu’à la fin du mercato d’été.');}
 }
}
// Recrue du club joué : '' si l'A2R l'homologue, sinon la raison (commande recruit, marché entre clubs).
function a2rRefusRecrue(salaire){
 const d=a2rDecision(S.club);
 return d?nativeA2R.refusRecrue(d,{masseHebdo:budgetMasse(club()),salaire:Number.isFinite(salaire)?salaire:0}):'';
}
// Clubs gérés : même règle, en coulisses, par leur masse autorisée.
const aiRosterWageLimitA2RV1=aiRosterWageLimit;
aiRosterWageLimit=function(c){
 const limite=aiRosterWageLimitA2RV1(c);
 if(!c||c.id===S.club)return limite;
 const d=a2rDecision(c.id);
 return d?nativeA2R.limiteGeree(d,{limite,masseHebdo:budgetMasse(c)}):limite;
};
const worldWeeklyEconomyA2RV1=worldWeeklyEconomy;
worldWeeklyEconomy=function(results){const r=worldWeeklyEconomyA2RV1(results);if(r!==false)a2rSemaine();return r;};
// Filet : une saison terminée avant le 30 juin du calendrier tranche les apports attendus au passage de saison.
const worldNewSeasonA2RV1=worldNewSeason;
worldNewSeason=function(fundingAlreadyPaid){if(a2rActif())a2rEcheances(null,true);return worldNewSeasonA2RV1(fundingAlreadyPaid);};
// Courrier de décision du club joué (club-mail.cjs, déclencheur « a2r ») : vars, ou null.
function a2rCourrier(niveau){
 const d=a2rDecision(S.club);
 if(!d||d.saison!==S.season||d.initial!==niveau)return null;
 return {cle:S.season+':'+niveau,vars:nativeA2R.courrier(d,{saison:typeof libelleSaison==='function'?libelleSaison(S.season+1):String(S.season+1)})};
}
// Réponses au courrier : raison d'indisponibilité ('' : possible), puis action.
function a2rRefus(action){
 const d=a2rDecision(S.club);
 if(action==='acte')return '';
 if(!d)return 'La décision de l’A2R n’est plus en vigueur.';
 if(action==='apport'){if(d.niveau!==3)return 'L’apport n’est plus attendu.';if(d.apport)return 'L’apport a déjà été demandé.';return '';}
 if(action==='appel'){if(d.appel)return 'Le club a déjà fait appel.';if(d.niveau<2)return 'La mesure est déjà la plus légère.';return '';}
 return 'Réponse inconnue.';
}
function a2rAction(action){
 const raison=a2rRefus(action);if(raison)return {ok:false,raison};
 if(action==='acte')return {ok:true};
 const d=a2rDecision(S.club),compte=S.clubBudget.clubs[S.club];
 if(action==='apport'){
  const r=nativeA2R.reponseActionnaire({type:compte.type,montant:d.montant,enveloppe:compte.enveloppe,recettes:a2rRecettes(club()),cle:'apport|'+S.season+'|'+S.club});
  if(!r.accepte){d.apport='refuse';return {ok:true,verdict:nativeA2R.REFUS[r.motif]};}
  d.apport='verse';d.niveau=1;ledgerEntry('Apport de l’actionnaire demandé par l’A2R',d.montant);S.trust=clamp(S.trust-3,0,100);a2rTally('a2r:apport-verse',S.club);
  return {ok:true,verdict:'Le propriétaire a versé '+nativeA2R.euros(d.montant)+' : l’A2R lève la menace, la masse salariale reste encadrée. Il te le rappellera.'};
 }
 ledgerEntry('A2R · frais d’appel',-nativeA2R.APPEL.frais);
 const gagne=nativeA2R.appel(S.season+'|'+S.club);d.appel=gagne?'gagne':'perdu';
 if(gagne){d.niveau=1;a2rTally('a2r:appel-gagne',S.club);return {ok:true,verdict:'Appel gagné : la mesure est ramenée à « autorisé sous conditions », masse salariale encadrée.'};}
 return {ok:true,verdict:'Appel rejeté : la décision de l’A2R est confirmée.'};
}
// État pour l'écran Finances (null : aucune mesure).
function a2rResume(){const d=a2rDecision(S.club);return d?{niveau:d.niveau,libelle:nativeA2R.NIVEAUX[d.niveau].libelle,montant:d.montant,encadrement:d.encadrement*52,echeance:d.echeance}:null;}
`;

module.exports = Object.freeze({ DIVISIONS, SEUILS, CALENDRIER, APPEL, NIVEAUX, REFUS, BRANCHEMENT,
  unite, euros, situation, examen, reponseActionnaire, refusRecrue, limiteGeree, courrier, appel, valide });
