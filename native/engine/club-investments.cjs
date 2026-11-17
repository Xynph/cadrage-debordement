'use strict';
// Investissements des excédents (suite de #870, décision de Léo du 17/11/2026).
// #870 réinvestit pendant la saison la part de la trésorerie au-dessus de la réserve du club. Ce module
// rend cet argent visible : il est réparti entre trois chantiers qui avancent semaine après semaine,
// sans rien d'instantané ni de gratuit (le montant total et son rythme de dépense restent ceux de #870).
//   installations : la part s'accumule jusqu'au prix d'un niveau (même devis que l'achat du manager),
//                   puis les travaux s'achèvent ; l'entretien hebdomadaire monte avec le niveau ;
//   staff         : formations, adjoints mieux payés ; chaque tranche fait progresser d'un point le
//                   membre le plus faible des rôles qui comptent, au plus PAR_PERSONNE points par saison ;
//   accueil       : billetterie, buvettes, hospitalités ; un niveau de 0 à 5 qui relève le guichet et la
//                   boutique, et qui se dégrade d'un cran s'il n'est pas entretenu une saison.
// Mode Monde uniquement (le branchement ne s'active que sur une carrière Monde au budget réaliste).

const PARTS = Object.freeze(['installations', 'staff', 'accueil']);
// Répartition par défaut selon le propriétaire : un mécène bâtit, une association forme ses gens,
// une entreprise soigne l'expérience de ses clients.
const REPARTITION = Object.freeze({
  mecene: Object.freeze({ installations: 0.45, staff: 0.35, accueil: 0.2 }),
  association: Object.freeze({ installations: 0.4, staff: 0.4, accueil: 0.2 }),
  entreprise: Object.freeze({ installations: 0.35, staff: 0.3, accueil: 0.35 }),
});
// Orientations que le manager peut donner au président (courrier d'ouverture de saison).
const ORIENTATIONS = Object.freeze({
  equilibre: null,
  installations: Object.freeze({ installations: 0.6, staff: 0.25, accueil: 0.15 }),
  staff: Object.freeze({ installations: 0.25, staff: 0.6, accueil: 0.15 }),
  accueil: Object.freeze({ installations: 0.25, staff: 0.15, accueil: 0.6 }),
});
const LIBELLES = Object.freeze({ installations: 'installations', staff: 'staff', accueil: 'accueil et billetterie' });
const STAFF = Object.freeze({ coutPoint: 60000, parPersonne: 3, max: 85, roles: Object.freeze(['coach', 'assistant', 'formation', 'scout', 'analyst']) });
const ACCUEIL = Object.freeze({ max: 5, coutBase: 250000, effet: 0.025, entretien: 0.25 });
const NIVEAU_MAX_INSTALLATIONS = 10;

const rond = x => Math.round(x);
const euros = n => new Intl.NumberFormat('fr-FR', { maximumFractionDigits: 0 }).format(Math.round(n)).replace(/ | /g, ' ') + ' €';
// Prix d'un niveau d'installations : celui de worldFacilityQuote (dist/world-career.js).
const coutInstallations = niveau => 450000 + niveau * 150000;
const coutAccueil = niveau => ACCUEIL.coutBase * (niveau + 1);
const facteurAccueil = niveau => 1 + ACCUEIL.effet * Math.max(0, Math.min(ACCUEIL.max, Number.isInteger(niveau) ? niveau : 0));

// Parts d'un club : propriétaire, stratégie de la direction, orientation du manager ; parts inutilisables
// (installations au maximum, aucun staff) reportées sur les autres, total 1.
function repartition({ type, strategie = null, orientation = null, installations = 2, staffDisponible = true }) {
  const base = ORIENTATIONS[orientation] || REPARTITION[type] || REPARTITION.association;
  const p = { ...base };
  if (!ORIENTATIONS[orientation] && strategie === 'formateur') { p.installations += 0.1; p.accueil -= 0.1; }
  if (!ORIENTATIONS[orientation] && strategie === 'vedettes') { p.staff += 0.05; p.installations -= 0.05; }
  if (installations >= NIVEAU_MAX_INSTALLATIONS) p.installations = 0;
  if (!staffDisponible) p.staff = 0;
  const total = PARTS.reduce((s, k) => s + Math.max(0, p[k]), 0) || 1;
  const out = {};
  for (const k of PARTS) out[k] = Math.max(0, p[k]) / total;
  return out;
}

// Découpe un montant en trois parts entières dont la somme est exacte.
function decouper(montant, parts) {
  const out = {}; let reste = rond(montant);
  PARTS.forEach((k, i) => { out[k] = i === PARTS.length - 1 ? reste : rond(montant * parts[k]); reste -= i === PARTS.length - 1 ? 0 : out[k]; });
  return out;
}

// Plan d'un club à l'ouverture d'une nouvelle saison. precedent : plan de la saison passée (cagnottes,
// niveau d'accueil) ; montant : investissement annuel décidé par #870.
function plan({ id, montant, type, strategie, installations, staffDisponible, precedent = null }) {
  const cagnotte = { installations: 0, staff: 0, accueil: 0, ...(precedent?.cagnotte || {}) };
  let accueil = Number.isInteger(precedent?.accueil) ? precedent.accueil : 0;
  const entretenu = (precedent?.depense?.accueil || 0) >= coutAccueil(Math.max(0, accueil - 1)) * ACCUEIL.entretien;
  const degrade = accueil > 0 && !entretenu;
  if (degrade) accueil--;
  const parts = repartition({ type, strategie, installations, staffDisponible });
  return { id, montant: rond(Math.max(0, montant || 0)), type, strategie: strategie || null, orientation: null, parts, cagnotte, accueil, degrade,
    depense: { installations: 0, staff: 0, accueil: 0 }, gains: {}, travaux: 0, points: 0, accueilGagne: 0 };
}

// Une semaine : ecriture = montant hebdomadaire réinvesti (positif). Les cagnottes avancent ; les chantiers
// aboutis sont rendus (le branchement applique les effets sur la carrière). Pur : modifie seulement p.
function semaine(p, montantSemaine, { installations, staff = [] }) {
  const tranche = decouper(montantSemaine, p.parts), faits = { travaux: 0, points: [], accueil: 0 };
  for (const k of PARTS) { p.cagnotte[k] += tranche[k]; p.depense[k] += tranche[k]; }
  let niveau = installations;
  while (niveau < NIVEAU_MAX_INSTALLATIONS && p.cagnotte.installations >= coutInstallations(niveau)) {
    p.cagnotte.installations -= coutInstallations(niveau); niveau++; faits.travaux++;
  }
  if (niveau >= NIVEAU_MAX_INSTALLATIONS && p.cagnotte.installations > 0) { p.cagnotte.staff += p.cagnotte.installations; p.cagnotte.installations = 0; }
  // Staff : un point par tranche, au plus faible des rôles qui comptent (ordre stable par identifiant).
  const candidats = staff.filter(x => STAFF.roles.includes(x.role) && x.level < STAFF.max).map(x => ({ id: x.id, level: x.level }));
  while (p.cagnotte.staff >= STAFF.coutPoint) {
    const libres = candidats.filter(x => (p.gains[x.id] || 0) < STAFF.parPersonne && x.level < STAFF.max).sort((a, b) => a.level - b.level || String(a.id).localeCompare(String(b.id)));
    // Tout le staff est au plus haut pour la saison : le reste va aux travaux, sinon à l'accueil (rien ne dort).
    if (!libres.length) { const k = niveau < NIVEAU_MAX_INSTALLATIONS ? 'installations' : 'accueil'; p.cagnotte[k] += p.cagnotte.staff; p.cagnotte.staff = 0; break; }
    const x = libres[0]; x.level++; p.gains[x.id] = (p.gains[x.id] || 0) + 1; p.cagnotte.staff -= STAFF.coutPoint; faits.points.push(x.id);
  }
  while (p.accueil < ACCUEIL.max && p.cagnotte.accueil >= coutAccueil(p.accueil)) {
    p.cagnotte.accueil -= coutAccueil(p.accueil); p.accueil++; faits.accueil++;
  }
  p.travaux += faits.travaux; p.points += faits.points.length; p.accueilGagne += faits.accueil;
  return { tranche, faits, installations: niveau };
}

// Le manager oriente la répartition : seules les semaines restantes en tiennent compte.
function orienter(p, orientation, { installations, staffDisponible }) {
  if (!Object.hasOwn(ORIENTATIONS, orientation)) throw Error('Orientation des investissements inconnue.');
  p.orientation = orientation;
  p.parts = repartition({ type: p.type, strategie: p.strategie, orientation, installations, staffDisponible });
  return p.parts;
}

// Vars du courrier du président (club-mail.json, type « investissements »).
function courrier(p, { installations, saison, capaciteStaff = Infinity }) {
  const m = decouper(p.montant, p.parts), next = coutInstallations(installations);
  const reste = Math.max(0, next - p.cagnotte.installations), semainesTravaux = m.installations > 0 ? reste / m.installations : Infinity;
  const travaux = installations >= NIVEAU_MAX_INSTALLATIONS ? 'Les installations sont au plus haut niveau : rien à bâtir de plus.'
    : semainesTravaux <= 1 ? `Les travaux du niveau ${installations + 1}/10 devraient s'achever cette saison (devis ${euros(next)}).`
    : m.installations > 0 ? `Les travaux du niveau ${installations + 1}/10 (devis ${euros(next)}) avancent : ${Math.round(100 * Math.min(1, (p.cagnotte.installations + m.installations) / next))} % financés à la fin de la saison.`
    : 'Pas de travaux cette saison.';
  const accueilTxt = p.accueil >= ACCUEIL.max ? `L'accueil est au meilleur niveau (${p.accueil}/${ACCUEIL.max}) ; cette part sert à l'entretenir.`
    : `Accueil du stade au niveau ${p.accueil}/${ACCUEIL.max}${p.degrade ? ', en recul faute d’entretien la saison passée' : ''} ; le palier suivant coûte ${euros(coutAccueil(p.accueil))}.`;
  return { saison, montant: euros(p.montant), installations: euros(m.installations), staff: euros(m.staff), accueil: euros(m.accueil),
    travaux, accueil_etat: accueilTxt, staff_etat: m.staff > 0 ? `Environ ${Math.min(capaciteStaff, Math.floor((p.cagnotte.staff + m.staff) / STAFF.coutPoint))} points de progression pour le staff (formations, adjoints mieux payés).` : 'Rien pour le staff cette saison.' };
}

const PRESIDENT = Object.freeze({
  travaux: n => `Les travaux sont terminés : les installations du club passent au niveau ${n}/10. L'entretien hebdomadaire augmente en conséquence.`,
  staff: (noms) => `Les formations financées par le club portent leurs fruits : ${noms} progresse${noms.includes(',') ? 'nt' : ''} d'un cran.`,
  accueil: n => `Nouvelles hospitalités, buvettes refaites, billetterie modernisée : l'accueil du stade passe au niveau ${n}/${ACCUEIL.max}. Le guichet et la boutique devraient en profiter.`,
  degrade: n => `Faute d'entretien la saison passée, l'accueil du stade recule au niveau ${n}/${ACCUEIL.max}.`,
});

function valide(etat, nbClubs) {
  return !!etat && etat.version === 1 && Number.isInteger(etat.saison) && Array.isArray(etat.clubs) && etat.clubs.length === nbClubs &&
    etat.clubs.every((p, i) => !!p && p.id === i && Number.isFinite(p.montant) && p.montant >= 0 && !!p.parts && !!p.cagnotte && !!p.depense &&
      PARTS.every(k => Number.isFinite(p.parts[k]) && Number.isFinite(p.cagnotte[k]) && p.cagnotte[k] >= 0 && Number.isFinite(p.depense[k])) &&
      Number.isInteger(p.accueil) && p.accueil >= 0 && p.accueil <= ACCUEIL.max && !!p.gains && typeof p.gains === 'object');
}

// Code branché dans la carrière (même contexte que club-budget.cjs BRANCHEMENT, exécuté juste après lui).
const BRANCHEMENT = `
const investActif=()=>budgetActif()&&budgetMonde()&&typeof worldActive==='function'&&worldActive();
const investStaff=id=>S.staffCareer?.version===1&&Array.isArray(S.staffCareer.people)?S.staffCareer.people.flat().filter(p=>p&&p.clubId===id):[];
const investStrategie=id=>S.clubDirections?.clubs?.[id]?.strategy||null;
const investEtat=()=>nativeClubInvestments.valide(S.clubInvest,S.clubs.length)?S.clubInvest:null;
// Accueil d'un club (0 à 5) : relève le guichet et la boutique dans nativeClubBudget.semaine.
const investAccueil=id=>{const e=investActif()?investEtat():null;return e?e.clubs[id].accueil:0;};
function investOuvrir(){
 const b=S.clubBudget,avant=investEtat();
 if(avant&&avant.saison===S.season)return;
 S.clubInvest={version:1,saison:S.season,clubs:S.clubs.map(c=>{
  const compte=b.clubs[c.id],info=worldClub(c.id);
  return nativeClubInvestments.plan({id:c.id,montant:compte.investissement||0,type:compte.type,strategie:investStrategie(c.id),
   installations:info?.facilities??2,staffDisponible:investStaff(c.id).some(p=>nativeClubInvestments.STAFF.roles.includes(p.role)),precedent:avant?.clubs[c.id]||null});
 })};
 const p=S.clubInvest.clubs[S.club];
 if(p.degrade)news(nativeClubInvestments.PRESIDENT.degrade(p.accueil));
}
const budgetOuvrirInvestV1=budgetOuvrir;
budgetOuvrir=function(annoncer,nouvelleSaison=false){
 budgetOuvrirInvestV1(annoncer,nouvelleSaison);
 if(investActif()&&(nouvelleSaison===true||investEtat()?.saison!==S.season))investOuvrir();
};
const budgetSemaineInvestV1=budgetSemaine;
budgetSemaine=function(forces,repere,c,rencontre,libelle){
 const ecritures=budgetSemaineInvestV1(forces,repere,c,rencontre,libelle),e=investActif()?investEtat():null;
 if(!e||e.saison!==S.season)return ecritures;
 const i=ecritures.findIndex(x=>/Investissements \\(excédents réinvestis\\)$/.test(x.title));
 if(i<0)return ecritures;
 const p=e.clubs[c.id],info=worldClub(c.id),staff=investStaff(c.id),montant=-ecritures[i].amount;
 const r=nativeClubInvestments.semaine(p,montant,{installations:info.facilities,staff:staff.map(x=>({id:x.id,role:x.role,level:x.level}))});
 // Trois lignes au lieu d'une, même total : le grand livre montre où va l'argent.
 const lignes=nativeClubInvestments.PARTS.filter(k=>r.tranche[k]>0).map(k=>({title:libelle+' · Investissements : '+nativeClubInvestments.LIBELLES[k],amount:-r.tranche[k]}));
 ecritures.splice(i,1,...lignes);
 // Pas d'entrée dans worldManagement.upgrades : elle bloquerait l'achat du manager (une fois par saison) et, bornée à 30, pourrait évincer sa trace.
 if(r.faits.travaux)info.facilities=r.installations;
 const noms=[];
 for(const id of r.faits.points){const x=staff.find(y=>y.id===id);if(x){x.level=Math.min(nativeClubInvestments.STAFF.max,x.level+1);noms.push(x.name);}}
 if(c.id===S.club){
  if(r.faits.travaux)news(nativeClubInvestments.PRESIDENT.travaux(info.facilities));
  if(noms.length)news(nativeClubInvestments.PRESIDENT.staff([...new Set(noms)].slice(0,3).join(', ')));
  if(r.faits.accueil)news(nativeClubInvestments.PRESIDENT.accueil(p.accueil));
 }
 if(typeof nativeClubDirections!=='undefined'){if(r.faits.travaux)nativeClubDirections.tally('investissements:travaux',c.id);if(r.faits.points.length)nativeClubDirections.tally('investissements:staff',c.id);}
 return ecritures;
};
// Réponse au courrier du président (club-mail.cjs, effet « orientation »).
function investOrienter(orientation){
 const e=investActif()?investEtat():null;
 if(!e||e.saison!==S.season||!(e.clubs[S.club].montant>0))return false;
 const c=club();
 nativeClubInvestments.orienter(e.clubs[S.club],orientation,{installations:worldClub(c.id).facilities,staffDisponible:investStaff(c.id).some(p=>nativeClubInvestments.STAFF.roles.includes(p.role))});
 return true;
}
function investCourrier(){
 const e=investActif()?investEtat():null;
 if(!e||e.saison!==S.season)return null;
 const p=e.clubs[S.club];if(!(p.montant>0)||p.orientation)return null;
 const capaciteStaff=investStaff(S.club).filter(x=>nativeClubInvestments.STAFF.roles.includes(x.role)).reduce((n,x)=>n+Math.max(0,Math.min(nativeClubInvestments.STAFF.parPersonne-(p.gains[x.id]||0),nativeClubInvestments.STAFF.max-x.level)),0);
 return nativeClubInvestments.courrier(p,{installations:worldClub(S.club).facilities,saison:S.season,capaciteStaff});
}
`;

module.exports = Object.freeze({ PARTS, REPARTITION, ORIENTATIONS, LIBELLES, STAFF, ACCUEIL, PRESIDENT, BRANCHEMENT,
  coutInstallations, coutAccueil, facteurAccueil, repartition, decouper, plan, semaine, orienter, courrier, valide, euros });
