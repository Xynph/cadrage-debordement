'use strict';
// Budget de transferts (docs/gdd/budget-transferts.md, décision de Léo du 19/11/2026). En début de saison, le conseil
// fixe une enveloppe : ce que le manager peut engager en indemnités de transfert (accords avec un autre club, enchère
// gagnée) et en primes à la signature des recrues libres. Les prolongations, les salaires et les renforts n'y entrent pas.
// Les ventes choisies en rendent la moitié ; les ventes imposées (président, prêt de l'actionnaire) ne rendent rien.
// Le disponible ne dépasse jamais ce que la caisse permet sans entamer le matelas du club.
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

// État enregistré : S.budgetTransferts = {version:1, saison, clubId, enveloppe, depense, reconstitue}.
const valide = e => !!e && typeof e === 'object' && !Array.isArray(e) && e.version === 1 && Number.isInteger(e.saison) && Number.isInteger(e.clubId) &&
  [e.enveloppe, e.depense, e.reconstitue].every(x => fini(x) && x >= 0);

const reste = e => Math.max(0, e.enveloppe + e.reconstitue - e.depense);
// disponible = max(0, min(enveloppe + reconstitué − dépensé, caisse − matelas)).
const disponible = (e, cash, mat) => Math.max(0, Math.min(reste(e), (fini(cash) ? cash : 0) - mat));

// Raison d'un refus (texte affiché tel quel), ou null si le montant passe.
function refus(e, montant, cash, mat) {
  if (!(montant > 0) || montant <= disponible(e, cash, mat)) return null;
  const caisse = Math.max(0, (fini(cash) ? cash : 0) - mat);
  if (caisse < reste(e)) return `La caisse ne permet plus de transfert : elle doit rester au-dessus de ${euros(mat)}.`;
  return `Hors budget de transferts : il reste ${euros(reste(e))} sur l’enveloppe de ${euros(e.enveloppe)} fixée par le conseil.`;
}

// Part d'une vente choisie rendue à l'enveloppe, plafonnée : enveloppe + reconstitué ≤ recettes × plafond.
function rendu(e, montant, recettes, R = REGLAGES) {
  if (!(montant > 0)) return 0;
  const place = Math.max(0, (fini(recettes) ? recettes : 0) * R.plafond - e.enveloppe - e.reconstitue);
  return Math.round(Math.max(0, Math.min(R.partVentes * montant, place)));
}

// Code exécuté dans le moteur (après club-budget.cjs, club-investments.cjs et president-reprise.cjs).
// Attend : budgetActif, budgetMonde, budgetLisible, budgetForces, budgetLigue, nativeClubBudget, nativeBudgetTransferts (ce module).
const BRANCHEMENT = `
const budgetTransfertsActif=()=>!!S&&typeof budgetActif==='function'&&budgetActif()&&budgetMonde();
// Entrées du calcul, sans rien écrire dans la carrière (lecture seule possible depuis la vue).
function budgetTransfertsEntrees(){
 const k=budgetLisible(S.clubBudget)&&S.clubBudget.saison===S.season?S.clubBudget.clubs[S.club]:null,forces=budgetForces();
 return {recettes:nativeClubBudget.recettes(forces).get(S.club)||0,division:budgetLigue(S.club),
  type:k?.type??nativeClubBudget.proprietaire(forces,S.club).type,confiance:S.trust,cash:club().cash,reserve:Number.isFinite(k?.reserve)&&k.reserve>0?k.reserve:null};
}
function budgetTransfertsNeuf(x=budgetTransfertsEntrees()){return {version:1,saison:S.season,clubId:S.club,enveloppe:nativeBudgetTransferts.enveloppe(x,nativeBudgetTransferts.REGLAGES),depense:0,reconstitue:0};}
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
let budgetTransfertsForcee=false;
function budgetTransfertsRecette(montant,choisie){
 if(!choisie||budgetTransfertsForcee||!(montant>0)||!budgetTransfertsActif())return 0;
 const e=budgetTransfertsEtat(true),x=budgetTransfertsEntrees(),r=nativeBudgetTransferts.rendu(e,montant,x.recettes,nativeBudgetTransferts.REGLAGES);
 e.reconstitue=Math.round(e.reconstitue+r);return r;
}
function budgetTransfertsImposee(fn){const avant=budgetTransfertsForcee;budgetTransfertsForcee=true;try{return fn();}finally{budgetTransfertsForcee=avant;}}
if(typeof acceptSale==='function'){
 const acceptSaleTransfertsV1=acceptSale;
 acceptSale=function(id){const o=S?.economy?.offers?.find(x=>x.id===id),fee=o?.fee;const r=acceptSaleTransfertsV1.apply(this,arguments);if(r===true&&fee>0)budgetTransfertsRecette(fee,true);return r;};
}
// Vue Finances / Recrutement (finance.transferBudget), en euros entiers ; lecture seule.
function budgetTransfertsVue(){
 const ctx=budgetTransfertsContexte();
 if(!ctx)return {actif:false,enveloppe:0,depense:0,reconstitue:0,disponible:0,matelas:0,saison:S?.season??null};
 const e=ctx.e;
 return {actif:true,enveloppe:e.enveloppe,depense:e.depense,reconstitue:e.reconstitue,disponible:Math.round(nativeBudgetTransferts.disponible(e,ctx.cash,ctx.matelas)),matelas:ctx.matelas,saison:e.saison};
}
`;

module.exports = Object.freeze({ REGLAGES, euros, matelas, enveloppe, valide, reste, disponible, refus, rendu, BRANCHEMENT });
