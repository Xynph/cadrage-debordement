'use strict';
// Budget de transferts (docs/gdd/budget-transferts.md, décision de Léo du 19/11/2026). En début de saison, le conseil
// fixe une enveloppe : ce que le manager peut engager en indemnités de transfert (accords avec un autre club, enchère
// gagnée) et en primes à la signature des recrues libres. Les prolongations, les salaires et les renforts n'y entrent pas.
// Les ventes choisies en rendent la moitié ; les ventes imposées (président, prêt de l'actionnaire) ne rendent rien.
// Le disponible ne dépasse jamais ce que la caisse permet sans entamer le matelas du club.
// Rallonge (R3 bis) : sur un refus d'enveloppe que la caisse permettrait, le manager demande le montant manquant au
// conseil ; réponse immédiate et déterministe (confiance, part de l'enveloppe, nombre de rallonges), coût en confiance.
// Report (R5) : une part du reste non dépensé de la saison qui se termine s'ajoute à l'enveloppe suivante (même club).
// Carrière Monde au budget de saison seulement (budgetActif) : ailleurs, règles inchangées.
// Réglages : budget-transferts.json (lu à chaque calcul : changer le fichier change l'enveloppe sans toucher au code).
const REGLAGES = require('./budget-transferts.json');

const fini = x => typeof x === 'number' && Number.isFinite(x);
const borne = (x, a, b) => Math.max(a, Math.min(b, x));
// Montants du club : espace des milliers, « € » (« 1 160 000 € »).
const euros = n => String(Math.round(Math.abs(n))).replace(/\B(?=(\d{3})+(?!\d))/g, ' ') + ' €';

// Matelas : la caisse ne descend jamais dessous par un transfert. Sans réserve lisible : matelas fixe.
function matelas(reserve, R = REGLAGES) {
  return Math.round(Math.max(R.matelas.fixe, fini(reserve) && reserve > 0 ? R.matelas.partReserve * reserve : 0));
}

// Enveloppe fixée par le conseil.
//   recettes : recettes annuelles du club ; division : championnat (clé de league-economy) ; type : propriétaire
//   (mecene / entreprise / association) ; confiance : 0 à 100 ; cash : caisse ; reserve : réserve du club (ou null).
function enveloppe({ recettes, division, type, confiance, cash, reserve }, R = REGLAGES) {
  const rec = fini(recettes) && recettes > 0 ? recettes : 0;
  const taux = fini(R.taux[division]) ? R.taux[division] : R.taux.defaut;
  const ambition = fini(R.ambition[type]) ? R.ambition[type] : 1;
  const t = borne(fini(confiance) ? confiance : 50, 0, 100);
  const facteurConfiance = R.confiance.min + (R.confiance.max - R.confiance.min) * t / 100;
  const base = fini(reserve) && reserve > 0 ? reserve : R.matelas.fixe;
  const facteurCaisse = borne((fini(cash) ? cash : 0) / base, R.tresorerie.min, R.tresorerie.max);
  const brut = rec * taux * ambition * facteurConfiance * facteurCaisse;
  const pas = fini(R.arrondi) && R.arrondi > 0 ? R.arrondi : 1;
  return Math.max(0, Math.round(borne(brut, rec * R.plancher, rec * R.plafond) / pas) * pas);
}

// État enregistré : S.budgetTransferts = {version:1, saison, clubId, enveloppe, depense, reconstitue, report, rallonge,
// demandes, rallongesAccordees}. enveloppe = montant fixé par le conseil en début de saison ; report = part reportée de la
// saison précédente ; rallonge = rallonges accordées en cours de saison. Les quatre derniers champs manquent dans les
// sauvegardes antérieures : lus comme 0. aNouvelleSaison (facultatif) = argent rendu pendant la bascule de saison (part des
// ventes exécutées au 1er juillet, indemnités d'achats tombés) : il ne compte pas dans le reste de la saison close et devient
// le reconstitué de départ de la nouvelle enveloppe (décision du 20/11/2026, `docs/gdd/budget-transferts.md` R4).
const n0 = x => fini(x) && x >= 0 ? x : 0;
const valide = e => !!e && typeof e === 'object' && !Array.isArray(e) && e.version === 1 && Number.isInteger(e.saison) && Number.isInteger(e.clubId) &&
  [e.enveloppe, e.depense, e.reconstitue].every(x => fini(x) && x >= 0) &&
  [e.report, e.rallonge, e.demandes, e.rallongesAccordees, e.aNouvelleSaison].every(x => x === undefined || fini(x) && x >= 0);

// Enveloppe de la saison : fixée + report + rallonges (le reconstitué s'y ajoute à part).
const total = e => e.enveloppe + n0(e.report) + n0(e.rallonge);
const reste = e => Math.max(0, total(e) + e.reconstitue - e.depense);
const libre = (cash, mat) => Math.max(0, (fini(cash) ? cash : 0) - mat);
// disponible = max(0, min(enveloppe + reconstitué − dépensé, caisse − matelas)).
const disponible = (e, cash, mat) => Math.max(0, Math.min(reste(e), (fini(cash) ? cash : 0) - mat));

// Raison d'un refus (texte affiché tel quel), ou null si le montant passe.
function refus(e, montant, cash, mat) {
  if (!(montant > 0) || montant <= disponible(e, cash, mat)) return null;
  const caisse = libre(cash, mat);
  if (caisse < reste(e)) return `La caisse ne permet plus de transfert : elle doit rester au-dessus de ${euros(mat)}.`;
  const texte = `Hors budget de transferts : il reste ${euros(reste(e))} sur l’enveloppe de ${euros(total(e))} fixée par le conseil.`;
  // Une rallonge ne servirait à rien : c'est la caisse qui limite au-delà du reste.
  return montant > caisse ? texte + ` Une rallonge du conseil ne suffirait pas : la caisse doit rester au-dessus de ${euros(mat)}.` : texte;
}

// Rallonge à demander pour un montant refusé par l'enveloppe (0 si le montant passe, ou si la caisse limite) :
// montant − reste, arrondi au millier supérieur (rallonge.arrondi). Possible seulement si reste < montant ≤ caisse − matelas.
function demandeRallonge(e, montant, cash, mat, R = REGLAGES) {
  const r = reste(e);
  if (!(montant > r) || montant > libre(cash, mat)) return 0;
  const pas = fini(R.rallonge.arrondi) && R.rallonge.arrondi > 0 ? R.rallonge.arrondi : 1;
  return Math.ceil((montant - r) / pas) * pas;
}

// Réponse du président à une demande de rallonge : null = accordée, sinon la raison COURTE du refus (aucun chiffre :
// décision de Léo du 25/11/2026, comme Football Manager ; le moteur garde ses seuils en interne). Déterministe.
//   accordée si rallonges déjà accordées < maxParSaison, confiance ≥ confianceMin, montant ≤ partEnveloppe × enveloppe fixée.
function decisionRallonge(e, montant, confiance, R = REGLAGES) {
  const Q = R.rallonge, t = Math.round(borne(fini(confiance) ? confiance : 50, 0, 100));
  if (n0(e.rallongesAccordees) >= Q.maxParSaison) return 'Assez de rallonges cette saison';
  if (t < Q.confianceMin) return 'Résultats d’abord';
  const plafond = Math.floor(Q.partEnveloppe * e.enveloppe);
  if (montant > plafond) return 'Finances serrées';
  return null;
}

// Après un refus, le conseil ne veut plus en entendre parler pendant quelques mois (rallonge.moisSilence) : date ISO.
function plusMois(iso, mois) {
  const m = /^([0-9]{4})-([0-9]{2})-([0-9]{2})$/.exec(String(iso));
  if (!m) return null;
  return new Date(Date.UTC(+m[1], +m[2] - 1 + mois, +m[3])).toISOString().slice(0, 10);
}
// La demande est fermée tant que la date du jour est avant bloqueJusqu (ISO). Sans date de jeu : jamais fermée.
const rallongeFermee = (e, jour) => !!e && typeof e.bloqueJusqu === 'string' && typeof jour === 'string' && jour < e.bloqueJusqu;

// Report d'une saison sur la suivante (même club) : partReport × reste non dépensé de la saison précédente, arrondi au
// millier inférieur, plafonné pour que enveloppe neuve + report ≤ recettes × plafond.
function report(precedent, enveloppeNeuve, recettes, R = REGLAGES) {
  const pas = fini(R.rallonge.arrondi) && R.rallonge.arrondi > 0 ? R.rallonge.arrondi : 1;
  const place = Math.max(0, (fini(recettes) ? recettes : 0) * R.plafond - enveloppeNeuve);
  return Math.max(0, Math.floor(Math.min(R.partReport * reste(precedent), place) / pas) * pas);
}

// Part d'une vente choisie rendue à l'enveloppe (décision de Léo du 19/11/2026) : partVentes × montant, sans plafond
// d'enveloppe ; seule la caisse limite ensuite le disponible (min(reste, caisse − matelas)). `recettes` est gardé pour
// la compatibilité des appels.
function rendu(e, montant, recettes, R = REGLAGES) {
  if (!(montant > 0)) return 0;
  return Math.round(Math.max(0, R.partVentes * montant));
}

// Code exécuté dans le moteur (après club-budget.cjs, club-investments.cjs et president-reprise.cjs).
// Attend : budgetActif, budgetMonde, budgetLisible, budgetForces, budgetLigue, nativeClubBudget, nativeBudgetTransferts (ce module).
const BRANCHEMENT = `
// Date du jeu (ISO) pour la fermeture du conseil après un refus ; null sans calendrier.
const budgetTransfertsJour=()=>{try{const j=CDWorldCareer.calendarToday(S);return typeof j==='string'?j:null;}catch(e){return null;}};
const budgetTransfertsActif=()=>!!S&&typeof budgetActif==='function'&&budgetActif()&&budgetMonde();
// Entrées du calcul, sans rien écrire dans la carrière (lecture seule possible depuis la vue).
function budgetTransfertsEntrees(){
 const k=budgetLisible(S.clubBudget)&&S.clubBudget.saison===S.season?S.clubBudget.clubs[S.club]:null,forces=budgetForces();
 return {recettes:nativeClubBudget.recettes(forces).get(S.club)||0,division:budgetLigue(S.club),
  type:k?.type??nativeClubBudget.proprietaire(forces,S.club).type,confiance:S.trust,cash:club().cash,reserve:Number.isFinite(k?.reserve)&&k.reserve>0?k.reserve:null};
}
// Report (R5) : seulement depuis l'enveloppe de la saison précédente du même club ; refixée dans la saison, le report est gardé.
function budgetTransfertsNeuf(x=budgetTransfertsEntrees()){
 const T=nativeBudgetTransferts,R=T.REGLAGES,enveloppe=T.enveloppe(x,R),p=S.budgetTransferts,meme=T.valide(p)&&p.clubId===S.club;
 const report=meme&&p.saison===S.season-1?T.report(p,enveloppe,x.recettes,R):meme&&p.saison===S.season?Math.round(p.report||0):0;
 // Argent rendu pendant la bascule (ventes du 1er juillet, achats tombés) : entièrement à la nouvelle saison.
 const reconstitue=meme&&p.saison===S.season-1?Math.round(p.aNouvelleSaison||0):0;
 return {version:1,saison:S.season,clubId:S.club,enveloppe,depense:0,reconstitue,report,rallonge:0,demandes:0,rallongesAccordees:0};
}
// Enveloppe de la saison et du club en cours ; recalculée à la volée sinon (carrière antérieure, autre saison, autre club).
function budgetTransfertsEtat(ecrire=true){
 if(!budgetTransfertsActif())return null;
 const e=S.budgetTransferts;if(nativeBudgetTransferts.valide(e)&&e.saison===S.season&&e.clubId===S.club)return e;
 const neuf=budgetTransfertsNeuf();if(ecrire)S.budgetTransferts=neuf;return neuf;
}
// Fixée une fois par saison, juste après l'ouverture des comptes (création de carrière, passage de saison).
function budgetTransfertsFixer(){if(budgetTransfertsActif())S.budgetTransferts=budgetTransfertsNeuf();}
const budgetOuvrirTransfertsV1=budgetOuvrir;
budgetOuvrir=function(annoncer){const r=budgetOuvrirTransfertsV1.apply(this,arguments);if(annoncer===true)budgetTransfertsFixer();return r;};
// Contexte d'un calcul (à réutiliser pour une liste de devis).
function budgetTransfertsContexte(){
 if(!budgetTransfertsActif())return null;
 const x=budgetTransfertsEntrees(),e=budgetTransfertsEtat(false);
 return {e,cash:x.cash,matelas:nativeBudgetTransferts.matelas(x.reserve,nativeBudgetTransferts.REGLAGES),recettes:x.recettes};
}
// Raison du refus d'une prime ou d'une indemnité, ou null (hors budget de saison : toujours null).
function budgetTransfertsRefus(montant,ctx=budgetTransfertsContexte()){return ctx?nativeBudgetTransferts.refus(ctx.e,montant,ctx.cash,ctx.matelas):null;}
// Un achat du club joué dans l'enveloppe : le président ne reprend pas la main (le conseil ne sanctionne pas ce qu'il a validé).
const budgetTransfertsExempte=()=>budgetTransfertsActif();
function budgetTransfertsDepenser(montant){const e=budgetTransfertsEtat(true);if(e&&montant>0)e.depense=Math.round(e.depense+montant);}
// Vente : choisie (offre acceptée, indemnité de formation reçue) → une part revient à l'enveloppe ; imposée → rien.
let budgetTransfertsForcee=false,budgetTransfertsBascule=false;
function budgetTransfertsRecette(montant,choisie){
 if(!choisie||budgetTransfertsForcee||!(montant>0)||!budgetTransfertsActif())return 0;
 const e=budgetTransfertsEtat(true),x=budgetTransfertsEntrees(),r=nativeBudgetTransferts.rendu(e,montant,x.recettes,nativeBudgetTransferts.REGLAGES);
 budgetTransfertsRendre(e,r);return r;
}
// Rend de l'argent à l'enveloppe : au reconstitué de la saison, ou, pendant la bascule, à la saison qui commence.
function budgetTransfertsRendre(e,r){
 if(!e||!(r>0))return;
 if(budgetTransfertsBascule)e.aNouvelleSaison=Math.round((e.aNouvelleSaison||0)+r);else e.reconstitue=Math.round(e.reconstitue+r);
}
function budgetTransfertsImposee(fn){const avant=budgetTransfertsForcee;budgetTransfertsForcee=true;try{return fn();}finally{budgetTransfertsForcee=avant;}}
// Exécutions de la bascule de saison (settleContracts, calendrier-mutations.cjs) : l'argent rendu va à la nouvelle saison.
function budgetTransfertsPendantBascule(fn){const avant=budgetTransfertsBascule;budgetTransfertsBascule=true;try{return fn();}finally{budgetTransfertsBascule=avant;}}
if(typeof acceptSale==='function'){
 const acceptSaleTransfertsV1=acceptSale;
 acceptSale=function(id){const o=S?.economy?.offers?.find(x=>x.id===id),fee=o?.fee;const r=acceptSaleTransfertsV1.apply(this,arguments);if(r===true&&fee>0)budgetTransfertsRecette(fee,true);return r;};
}
// Rallonge demandée au conseil (commande transfer_budget_extension {amount, confirmed:true}). Montant invalide, match en
// cours ou caisse déjà limitante : erreur, rien n'est écrit. Sinon réponse immédiate et déterministe, enregistrée
// (demandes, rallongesAccordees, rallonge), coût en confiance, ligne dans les nouvelles du club.
function budgetTransfertsRallonge(p){
 const T=nativeBudgetTransferts,R=T.REGLAGES,Q=R.rallonge,non=m=>{throw Error(m);};
 if(!budgetTransfertsActif())non('Budget de transferts indisponible dans cette carrière.');
 if(p?.confirmed!==true)non('Confirme la demande de rallonge au conseil.');
 if(!Number.isInteger(p.amount)||p.amount<Q.arrondi||p.amount%Q.arrondi!==0||p.amount>1e9)non('Montant de rallonge invalide.');
 if(S.live)non('Le conseil ne se réunit pas pendant un match.');
 const jour=budgetTransfertsJour();
 if(T.rallongeFermee(budgetTransfertsEtat(false),jour))non('Le conseil ne veut plus en entendre parler pour le moment.');
 const ctx=budgetTransfertsContexte();
 if(T.reste(ctx.e)>=Math.max(0,ctx.cash-ctx.matelas))non('Pas de rallonge possible : c’est la caisse qui limite les transferts ; elle doit rester au-dessus de '+T.euros(ctx.matelas)+'.');
 const e=budgetTransfertsEtat(true),raison=T.decisionRallonge(e,p.amount,S.trust,R),accordee=!raison,cout=accordee?Q.coutAccordee:Q.coutRefusee;
 e.demandes=(e.demandes||0)+1;
 const jusqu=!accordee&&jour?T.plusMois(jour,Q.moisSilence):null;
 if(jusqu)e.bloqueJusqu=jusqu;
 if(accordee){e.rallonge=Math.round((e.rallonge||0)+p.amount);e.rallongesAccordees=(e.rallongesAccordees||0)+1;}
 S.trust=Math.max(0,Math.min(100,(Number.isFinite(S.trust)?S.trust:50)-cout));
 const quand=jusqu?(typeof calJourMois==='function'?calJourMois(jusqu):nativeVenteJoueurs.dateFr(jusqu)):null;
 const message=accordee?'Le conseil accorde une rallonge de '+T.euros(p.amount)+' au budget de transferts.':'Refusé : '+raison.toLowerCase()+(quand?' · plus de demande avant le '+quand:'');
 if(typeof news==='function')news('Budget de transferts : '+(accordee?'le conseil accorde une rallonge de '+T.euros(p.amount)+'.':'demande de rallonge de '+T.euros(p.amount)+' refusée : '+raison.toLowerCase()+'.'));
 return {accordee,montant:p.amount,message,raison:accordee?null:raison,bloqueJusqu:jusqu,bloqueLabel:quand};
}
// Vue Finances / Recrutement (finance.transferBudget), en euros entiers ; lecture seule.
//   enveloppe : fixée par le conseil ; report : part reportée de la saison passée ; rallonge : rallonges accordées ;
//   reste : enveloppe + report + rallonge + reconstitué − dépensé ; caisseLibre : caisse − matelas ;
//   disponible : min(reste, caisseLibre). Rallonge possible pour un montant m si reste < m ≤ caisseLibre ; elle vaut
//   m − reste arrondi au millier supérieur (rallongeArrondi) — calcul repris par ui/transfer_budget.gd.
function budgetTransfertsVue(){
 const ctx=budgetTransfertsContexte(),Q=nativeBudgetTransferts.REGLAGES.rallonge;
 const jour=budgetTransfertsJour(),ee=budgetTransfertsEtat(false),ferme=nativeBudgetTransferts.rallongeFermee(ee,jour);
 // Aucun coût ni seuil vers l'écran : seulement la date de réouverture après un refus.
 const regles={rallongeMax:Q.maxParSaison,rallongeArrondi:Q.arrondi,rallongeBloqueJusqu:ferme?ee.bloqueJusqu:null,rallongeBloqueLabel:ferme?(typeof calJourMois==='function'?calJourMois(ee.bloqueJusqu):nativeVenteJoueurs.dateFr(ee.bloqueJusqu)):null};
 if(!ctx)return {actif:false,enveloppe:0,report:0,rallonge:0,depense:0,reconstitue:0,reste:0,caisseLibre:0,disponible:0,matelas:0,demandes:0,rallongesAccordees:0,...regles,saison:S?.season??null};
 const e=ctx.e,T=nativeBudgetTransferts;
 return {actif:true,enveloppe:e.enveloppe,report:Math.round(e.report||0),rallonge:Math.round(e.rallonge||0),depense:e.depense,reconstitue:e.reconstitue,
  reste:Math.round(T.reste(e)),caisseLibre:Math.round(Math.max(0,ctx.cash-ctx.matelas)),disponible:Math.round(T.disponible(e,ctx.cash,ctx.matelas)),matelas:ctx.matelas,
  demandes:e.demandes||0,rallongesAccordees:e.rallongesAccordees||0,...regles,saison:e.saison};
}
`;

module.exports = Object.freeze({ REGLAGES, euros, matelas, enveloppe, valide, total, reste, disponible, refus, demandeRallonge, decisionRallonge, plusMois, rallongeFermee, report, rendu, BRANCHEMENT });
