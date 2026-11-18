'use strict';
// Santé financière des clubs, façon Football Manager (demande de Léo du 18/11/2026 : « ça doit rester léger pour le
// joueur, ce n'est pas un jeu de comptabilité »). Trois choses visibles, aucun chiffre de plus :
//   - une étiquette : Fragile, Correcte, Saine, Riche ;
//   - le type de propriétaire : association, groupe actionnaire, mécène ;
//   - une mini-courbe des résultats des trois dernières saisons (résultat avant l'apport du propriétaire).
//
// Étiquette : caisse nette (trésorerie moins la dette) rapportée à la réserve que le club se fixe (club-budget.cjs,
// reserveCible : 10 à 20 % des recettes, 20 à 30 % en Pro D2, 30 à 45 % en Nationale). La caisse retenue est la plus
// basse entre le départ de la saison et aujourd'hui : l'étiquette ne clignote pas d'une semaine à l'autre, mais une
// saison qui tourne mal se voit. Un club en dette ou à découvert est fragile.
//   Fragile  : moins de la moitié de sa réserve, ou endetté ;
//   Correcte : entre la moitié et la réserve entière ;
//   Saine    : réserve couverte ;
//   Riche    : une fois et demie la réserve (au-delà, l'excédent est normalement réinvesti : il faut le vouloir).
const ETIQUETTES = Object.freeze({ fragile: 'Fragile', correcte: 'Correcte', saine: 'Saine', riche: 'Riche' });
const SEUILS = Object.freeze({ correcte: 0.5, saine: 1, riche: 1.5 });
// Une dette sous 10 % de la réserve (reliquat d'un découvert remboursé) ne suffit pas à rendre un club fragile.
const DETTE_TOLEREE = 0.1;
const PROPRIETAIRES = Object.freeze({ association: 'Association', entreprise: 'Groupe actionnaire', mecene: 'Mécène' });
const HISTORIQUE = 3;

const fini = x => typeof x === 'number' && Number.isFinite(x);

// pret : part de la dette due à l'actionnaire (club-owner.cjs) : elle pèse sur la caisse nette, sans rendre fragile à elle seule.
function etiquette({ tresorerie, depart = tresorerie, reserve, dette = 0, pret = 0 }) {
  if (!fini(tresorerie)) return null;
  const caisse = Math.min(tresorerie, fini(depart) ? depart : tresorerie), d = fini(dette) && dette > 0 ? dette : 0;
  if (tresorerie < 0) return 'fragile';
  if (!(fini(reserve) && reserve > 0)) return caisse - d > 0 ? 'correcte' : 'fragile';
  if (d - (fini(pret) && pret > 0 ? Math.min(pret, d) : 0) > DETTE_TOLEREE * reserve) return 'fragile';
  const r = (caisse - d) / reserve;
  return r >= SEUILS.riche ? 'riche' : r >= SEUILS.saine ? 'saine' : r >= SEUILS.correcte ? 'correcte' : 'fragile';
}

// Historique compact d'un club : [[saison, résultat en milliers d'euros], …], trois saisons au plus, une par saison.
function historiser(liste, saison, resultat) {
  const propre = (Array.isArray(liste) ? liste : []).filter(x => Array.isArray(x) && Number.isInteger(x[0]) && fini(x[1]) && x[0] !== saison);
  propre.push([saison, Math.round(resultat / 1000)]);
  return propre.sort((a, b) => a[0] - b[0]).slice(-HISTORIQUE);
}

// Fiche d'un club pour l'interface : rien d'autre que l'étiquette, le propriétaire et la courbe.
function fiche({ tresorerie, depart, reserve, dette, pret, type, historique }) {
  const e = etiquette({ tresorerie, depart, reserve, dette, pret });
  return {
    etiquette: e, libelle: e ? ETIQUETTES[e] : null,
    proprietaire: Object.hasOwn(PROPRIETAIRES, type ?? '') ? { type, libelle: PROPRIETAIRES[type] } : null,
    courbe: (Array.isArray(historique) ? historique : []).map(([saison, k]) => ({ saison, resultat: k * 1000 })),
  };
}
// Ordre du classement financier : de la plus solide à la plus fragile (caisse nette sur réserve).
function solidite({ tresorerie, depart = tresorerie, reserve, dette = 0 }) {
  if (!fini(tresorerie)) return -Infinity;
  const caisse = Math.min(tresorerie, fini(depart) ? depart : tresorerie) - (fini(dette) ? dette : 0);
  return fini(reserve) && reserve > 0 ? caisse / reserve : caisse / 1e6;
}

// Code exécuté dans le moteur (après club-budget.cjs) : historique tenu à la clôture de chaque club (budgetCloturer),
// fiche d'un club et classement financier d'un championnat. Attend : nativeClubHealth (ce module).
//   S.clubFinances = {version:1, clubs:{"<id>":[[saison, k€], …]}}
const BRANCHEMENT = `
const santeEtat=()=>{const f=S.clubFinances;if(!f||f.version!==1||!f.clubs||typeof f.clubs!=='object'||Array.isArray(f.clubs))S.clubFinances={version:1,clubs:{}};return S.clubFinances;};
function santeHistoriser(id,resultat,saison=S.season){if(!Number.isFinite(resultat))return;const f=santeEtat();f.clubs[id]=nativeClubHealth.historiser(f.clubs[id],saison,resultat);}
function santeEntrees(id){
 const c=S.clubs[id],b=typeof budgetLisible==='function'&&budgetLisible(S.clubBudget)?S.clubBudget.clubs[id]:null;
 const info=typeof worldClub==='function'?worldClub(id):null;
 return {tresorerie:c?.cash,depart:b?.depart,reserve:b?.reserve,dette:info?.debt||0,pret:typeof pretRestant==='function'?pretRestant(id):0,type:b?.type,historique:S.clubFinances?.clubs?.[id]||[]};
}
function santeFiche(id){return S&&S.clubs[id]?nativeClubHealth.fiche(santeEntrees(id)):null;}
// Classement financier du championnat d'un club : du plus solide au plus fragile.
function santeClassement(id){
 if(!S||typeof budgetLigue!=='function')return [];
 const lg=budgetLigue(id);
 return S.clubs.filter(c=>budgetLigue(c.id)===lg).map(c=>{const e=santeEntrees(c.id);return {id:c.id,name:c.name,abbr:c.abbr,color:c.color,own:c.id===S.club,solidite:nativeClubHealth.solidite(e),...nativeClubHealth.fiche(e)};})
  .sort((a,b)=>b.solidite-a.solidite||a.id-b.id).map(({solidite,...x})=>x);
}
`;

module.exports = Object.freeze({ ETIQUETTES, SEUILS, DETTE_TOLEREE, PROPRIETAIRES, HISTORIQUE, etiquette, historiser, fiche, solidite, BRANCHEMENT });
