'use strict';
// Budget hebdomadaire d'un club pour les carrières créées avec les salaires
// de départ réalistes (state.startingSalaries). Les autres carrières gardent
// l'ancien calcul.
//
// Modèle : comptes cumulés des clubs professionnels, saison 2024-2025.
//   Recettes moyennes par club : 33 M€ en première division, 10,7 M€ en deuxième.
//   Première division : partenaires 45 %, ligue 19 %, billetterie 16 %,
//     boutique et buvettes 8 %, subventions et divers 12 %.
//   Deuxième division : partenaires 48 %, ligue 22 %, billetterie 8 %,
//     boutique 4 %, subventions et divers 18 %.
//   Charges : les joueurs pèsent environ 27 % ; les cotisations représentent
//     40 % des salaires ; le reste (staff, administratifs, achats, services,
//     amortissements) fait un peu moins de 60 % des recettes.
// Les salaires sont dus sur 52 semaines : chaque semaine de compétition en paie 52 / n.
//
// Ce qui fait vivre le club au-delà de ce socle :
//   - un quart du versement de la ligue dépend du classement final (prime de fin de saison) ;
//   - 40 % de la billetterie vient des abonnements, versés chaque semaine ; le reste
//     se gagne au guichet, selon les résultats récents ; les phases finales rapportent plus ;
//   - le propriétaire (mécène, entreprise, association) annonce en début de saison ce
//     qu'il comblera, et le comble en fin de saison ;
//   - la ligue plafonne les salaires des joueurs : 10,7 M€ en première division, et
//     52 % des recettes dans les deux divisions.
const ECONOMIE = require('./league-economy.cjs');
// Une entrée par championnat de la base ; les deux divisions françaises sont relevées, les autres en partie estimées.
const DIVISIONS = Object.freeze(Object.fromEntries(Object.entries(ECONOMIE.CHAMPIONNATS).map(([nom, c]) => [nom, Object.freeze({
  moyenne: c.recettes, bas: c.bas, haut: c.haut, partenaires: c.partenaires, ligue: c.ligue, billetterie: c.billetterie, boutique: c.boutique, divers: c.divers })])));
const COTISATIONS = 0.4;
const FONCTIONNEMENT = 0.58;

// forces : [{id, division, base}] ; renvoie les recettes annuelles visées par club.
function recettes(forces) {
  const resultat = new Map();
  for (const [division, regle] of Object.entries(DIVISIONS)) {
    const groupe = forces.filter(club => club.division === division);
    if (!groupe.length) continue;
    const min = Math.min(...groupe.map(club => club.base)), max = Math.max(...groupe.map(club => club.base));
    const brut = groupe.map(club => regle.bas + (regle.haut - regle.bas) * (max === min ? 0.5 : (club.base - min) / (max - min)));
    const correction = groupe.length / brut.reduce((somme, valeur) => somme + valeur, 0);
    groupe.forEach((club, i) => resultat.set(club.id, regle.moyenne * brut[i] * correction));
  }
  return resultat;
}

const PART_PRIME = 0.25;          // part du versement de la ligue liée au classement
const PART_ABONNEMENTS = 0.4;     // part de la billetterie vendue à l'année
const GUICHET_PHASE_FINALE = 1.5; // une phase finale à domicile remplit et se vend plus cher
const PART_TERRAIN_NEUTRE = 0.8;  // part de recette d'un match sur terrain neutre, en recette type de la division
const PLAFOND_SALARIAL = Object.freeze(Object.fromEntries(Object.entries(ECONOMIE.CHAMPIONNATS).filter(([, c]) => c.plafond !== null).map(([nom, c]) => [nom, c.plafond])));
const RATIO_SALAIRES = 0.52;
const TAUX_AMENDE = 0.5, AMENDE_MAX = 2e6;
const PROPRIETAIRES = Object.freeze({
  mecene: Object.freeze({ libelle: 'Mécène', part: 0.12 }),
  entreprise: Object.freeze({ libelle: 'Entreprise actionnaire', part: 0.06 }),
  association: Object.freeze({ libelle: 'Association', part: 0 }),
});
const TOLERANCE_DEFICIT = 0.02;   // en part des recettes : en dessous, personne ne s'en émeut

const rond = montant => Math.round(montant / 100) * 100;
// Tirage stable dans [0;1[ à partir d'un texte : le même club a toujours le même propriétaire.
function unite(texte) {
  let h = 2166136261;
  for (let i = 0; i < texte.length; i++) { h ^= texte.charCodeAt(i); h = Math.imul(h, 16777619); }
  h ^= h >>> 15; h = Math.imul(h, 2246822507); h ^= h >>> 13;
  return (h >>> 0) / 4294967296;
}
function euros(montant) {
  const m = Math.abs(montant);
  if (m >= 1e6) return (Math.round(m / 1e4) / 100).toString().replace('.', ',') + ' M€';
  return String(Math.round(m)).replace(/\B(?=(\d{3})+(?!\d))/g, ' ') + ' €';
}
function regleDe(forces, clubId) {
  const force = forces.find(club => club.id === clubId), regle = force && DIVISIONS[force.division];
  if (!regle) throw Error('Budget de club : division inconnue.');
  return { force, regle, annuel: recettes(forces).get(clubId) };
}

// Le propriétaire d'un club et ce qu'il promet de combler cette saison.
function proprietaire(forces, clubId, typeConnu = null) {
  // Un grand club attire un mécène ou un groupe ; l'association se rencontre chez les plus modestes.
  const { force, annuel } = regleDe(forces, clubId), tirage = unite('proprietaire|' + clubId);
  const poids = Math.max(0, Math.min(1, (force.base - 64) / 22));
  // Le type ne change pas d'une saison à l'autre : celui de la saison passée est repris.
  const type = Object.hasOwn(PROPRIETAIRES, typeConnu ?? '') ? typeConnu : tirage < 0.3 + 0.15 * poids ? 'mecene' : tirage < 0.6 + 0.4 * poids ? 'entreprise' : 'association';
  const enveloppe = Math.round(annuel * PROPRIETAIRES[type].part * (0.8 + 0.4 * unite('enveloppe|' + clubId)) / 50000) * 50000;
  return { type, libelle: PROPRIETAIRES[type].libelle, enveloppe };
}

// Résultats récents ('V', 'N', 'D') -> forme dans [0;1] ; 0,5 sans match joué.
function forme(resultats) {
  const recents = (resultats ?? []).slice(-5);
  if (!recents.length) return 0.5;
  return recents.reduce((somme, r) => somme + (r === 'V' ? 1 : r === 'N' ? 0.5 : 0), 0) / recents.length;
}
// Affluence d'un match à domicile : 0,78 après cinq défaites, 1,22 après cinq victoires.
const affluence = (formeClub, alea) => 0.78 + 0.36 * formeClub + 0.08 * alea;

// Ce qu'un club géré par le jeu ajuste dans son fonctionnement, sur l'année : il réduit
// ses dépenses quand son déficit dépasse ce que le propriétaire comble, et il réinvestit
// l'essentiel de ses excédents. Positif = dépense en plus.
function ajustement(annuel, masseAnnuelle, enveloppe) {
  const resultat = annuel * (1 - FONCTIONNEMENT) - masseAnnuelle * (1 + COTISATIONS);
  if (resultat > 0) return 0.7 * resultat;
  const economies = Math.min(0.15 * annuel, 0.7 * Math.max(0, -resultat - enveloppe));
  return economies > 0 ? -economies : 0;
}

// Écritures d'une semaine de compétition.
//   domicile : le club reçoit ; neutre : match sur terrain neutre ; phase : 'league' ou une phase finale ;
//   resultats : derniers résultats du club ('V', 'N', 'D') ; alea dans [0;1] (tiré du club et de la date par défaut) ;
//   receptions : matchs de saison régulière à domicile ; gere : club géré par le jeu.
function semaine({ forces, clubId, masseHebdo, semaines, domicile, alea, libelle, resultats, phase = 'league', neutre = false, receptions, gere = false, repere = '' }) {
  const { regle, annuel } = regleDe(forces, clubId);
  if (!Number.isInteger(semaines) || semaines < 1) throw Error('Budget de club : nombre de semaines invalide.');
  const salaires = rond(masseHebdo * 52 / semaines), matchs = Math.max(1, receptions ?? Math.round(semaines / 2));
  const hasard = Number.isFinite(alea) ? alea : unite('affluence|' + clubId + '|' + repere), public_ = affluence(forme(resultats), hasard);
  const billetterie = annuel * regle.billetterie, finale = phase !== 'league';
  const ecritures = [
    { title: libelle + ' · Partenaires', amount: rond(annuel * regle.partenaires / semaines) },
    { title: libelle + ' · Versement de la ligue', amount: rond(annuel * regle.ligue * (1 - PART_PRIME) / semaines) },
    { title: libelle + ' · Subventions et divers', amount: rond(annuel * regle.divers / semaines) },
    { title: libelle + ' · Abonnements', amount: rond(billetterie * PART_ABONNEMENTS / semaines) },
  ];
  if (domicile && !neutre) {
    ecritures.push(finale
      ? { title: libelle + ' · Billetterie de phase finale', amount: rond(billetterie / matchs * GUICHET_PHASE_FINALE * public_) }
      : { title: libelle + ' · Billetterie', amount: rond(billetterie * (1 - PART_ABONNEMENTS) / matchs * public_) });
    ecritures.push({ title: libelle + ' · Boutique et buvettes', amount: rond(annuel * regle.boutique / matchs * (finale ? GUICHET_PHASE_FINALE : 1) * (0.9 + 0.2 * hasard)) });
  } else if (neutre) {
    ecritures.push({ title: libelle + ' · Part de recette de phase finale', amount: rond(regle.moyenne * regle.billetterie / matchs * PART_TERRAIN_NEUTRE) });
  }
  const fonctionnement = annuel * FONCTIONNEMENT + (gere ? ajustement(annuel, masseHebdo * 52, proprietaire(forces, clubId).enveloppe) : 0);
  ecritures.push({ title: libelle + ' · Salaires des joueurs', amount: -salaires });
  ecritures.push({ title: libelle + ' · Cotisations', amount: -rond(salaires * COTISATIONS) });
  ecritures.push({ title: libelle + ' · Staff et fonctionnement', amount: -rond(fonctionnement / semaines) });
  return ecritures;
}

// Prime de classement versée par la ligue en fin de saison : le premier touche 1,8 part, le dernier 0,2.
function primeClassement(division, rang, taille) {
  const regle = DIVISIONS[division];
  if (!regle || !Number.isInteger(rang) || !Number.isInteger(taille) || taille < 2 || rang < 1 || rang > taille) throw Error('Prime de classement : rang invalide.');
  return rond(regle.moyenne * regle.ligue * PART_PRIME * (1.8 - 1.6 * (rang - 1) / (taille - 1)));
}

// Les règles de la ligue, pour une masse salariale annuelle et des recettes données :
// plafond salarial là où il existe, 52 % des recettes dans les championnats français.
function regles({ division, masseAnnuelle, recettes: recettesClub }) {
  if (!DIVISIONS[division]) throw Error('Règles de la ligue : division inconnue.');
  const plafond = PLAFOND_SALARIAL[division] ?? null, limiteRecettes = ECONOMIE.CHAMPIONNATS[division].ratio ? rond(recettesClub * RATIO_SALAIRES) : null;
  const depassementPlafond = plafond === null ? 0 : Math.max(0, masseAnnuelle - plafond), depassementRecettes = limiteRecettes === null ? 0 : Math.max(0, masseAnnuelle - limiteRecettes);
  const depassement = Math.max(depassementPlafond, depassementRecettes);
  return { plafond, limiteRecettes, margePlafond: plafond === null ? null : rond(plafond - masseAnnuelle), margeRecettes: limiteRecettes === null ? null : rond(limiteRecettes - masseAnnuelle),
    depassementPlafond: rond(depassementPlafond), depassementRecettes: rond(depassementRecettes), amende: rond(Math.min(AMENDE_MAX, depassement * TAUX_AMENDE)) };
}

// Comptes d'une nouvelle saison : un compteur par club. clubs : [{id, cash, masse}] ; types : propriétaires déjà connus.
function ouverture({ forces, saison, clubs, types = null }) {
  const tailles = new Map();
  for (const force of forces) tailles.set(force.division, (tailles.get(force.division) ?? 0) + 1);
  return { version: 1, saison, semaines: 0, alertes: {}, clubs: clubs.map(club => {
    const p = proprietaire(forces, club.id, types?.[club.id]), division = forces.find(force => force.id === club.id).division, taille = Math.max(2, tailles.get(division));
    return { type: p.type, enveloppe: p.enveloppe, depart: club.cash, recettes: 0, charges: 0, salaires: 0, masse: Math.round(club.masse), division, rang: Math.ceil(taille / 2), taille };
  }) };
}
// Ajoute les écritures d'une semaine au compteur d'un club ; classement : {division, rang, taille} du moment.
function compter(compte, ecritures, masseAnnuelle, classement = null) {
  for (const e of ecritures) {
    if (e.amount > 0) compte.recettes += e.amount; else compte.charges -= e.amount;
    if (e.title.endsWith('Salaires des joueurs')) compte.salaires -= e.amount;
  }
  compte.masse = Math.round(masseAnnuelle);
  if (classement) { compte.division = classement.division; compte.rang = classement.rang; compte.taille = classement.taille; }
  return compte;
}

const ANNONCES = Object.freeze({
  mecene: e => `Le président finance le club sur sa fortune. Il vous l’a dit en face : cette saison, il comblera jusqu’à ${euros(e)} de pertes. Au-delà, il vous demandera des comptes.`,
  entreprise: e => `Le groupe actionnaire a voté son budget : il comblera jusqu’à ${euros(e)} de déficit cette saison, pas un euro de plus.`,
  association: () => 'Le club appartient à ses adhérents : personne ne comblera un déficit. Chaque euro dépensé cette saison devra être gagné.',
});
const annonce = compte => ANNONCES[compte.type](compte.enveloppe);

// Prévision de la saison du club joué, mise à jour chaque semaine.
//   compte : compteur du club ; tresorerie : caisse actuelle ; reste : semaines restantes ;
//   receptionsRestantes : matchs de saison régulière à domicile encore à jouer ; rang, taille : classement actuel.
function prevision({ forces, clubId, compte, tresorerie, masseHebdo, semaines, reste, receptions, receptionsRestantes, rang, taille }) {
  const { force, regle, annuel } = regleDe(forces, clubId), division = force.division, masseAnnuelle = Math.round(masseHebdo * 52);
  const prime = primeClassement(division, rang, taille);
  const fixes = annuel * (regle.partenaires + regle.ligue * (1 - PART_PRIME) + regle.divers + regle.billetterie * PART_ABONNEMENTS) / semaines;
  const guichet = annuel * (regle.billetterie * (1 - PART_ABONNEMENTS) + regle.boutique) / Math.max(1, receptions);
  const recettesPrevues = rond(compte.recettes + fixes * reste + guichet * receptionsRestantes + prime);
  const chargesPrevues = rond(compte.charges + (masseHebdo * 52 / semaines * (1 + COTISATIONS) + annuel * FONCTIONNEMENT / semaines) * reste);
  // Transferts, primes de signature, travaux : tout ce qui a bougé la caisse hors du budget courant.
  const horsBudget = rond(tresorerie - compte.depart - (compte.recettes - compte.charges));
  const ligue = regles({ division, masseAnnuelle, recettes: recettesPrevues });
  const resultatPrevu = rond(recettesPrevues - chargesPrevues + horsBudget - ligue.amende);
  const apportPrevu = Math.min(compte.enveloppe, Math.max(0, -resultatPrevu));
  const alertes = [];
  if (ligue.depassementPlafond > 0) alertes.push({ cle: 'plafond', message: `La ligue vous a écrit : la masse salariale (${euros(masseAnnuelle)} par an) dépasse le plafond de ${euros(ligue.plafond)}. Sans départs avant la dernière journée, le club paiera une amende.` });
  if (ligue.depassementRecettes > 0) alertes.push({ cle: 'recettes', message: `Le contrôleur de gestion de la ligue vous alerte : les salaires des joueurs (${euros(masseAnnuelle)} par an) dépassent 52 % des recettes attendues (${euros(ligue.limiteRecettes)}). Sans correction avant la dernière journée, le club sera sanctionné.` });
  if (-resultatPrevu - compte.enveloppe > annuel * TOLERANCE_DEFICIT) alertes.push({ cle: 'deficit', message: compte.enveloppe > 0
    ? `Le directeur financier tire la sonnette d’alarme : à ce rythme, la saison se terminera sur une perte de ${euros(resultatPrevu)}, bien plus que les ${euros(compte.enveloppe)} promis par le propriétaire.`
    : `Le trésorier tire la sonnette d’alarme : à ce rythme, la saison se terminera sur une perte de ${euros(resultatPrevu)}, et personne ne la comblera.` });
  return { alertes, prevision: {
    recettesPrevues, chargesPrevues, horsBudget, resultatPrevu,
    recettesEncaissees: rond(compte.recettes), chargesPayees: rond(compte.charges),
    primeClassementPrevue: prime, rang,
    proprietaire: { type: compte.type, libelle: PROPRIETAIRES[compte.type].libelle, enveloppe: compte.enveloppe }, apportPrevu: rond(apportPrevu),
    masseSalariale: masseAnnuelle, plafondSalarial: ligue.plafond, limiteRecettes: ligue.limiteRecettes, margePlafond: ligue.margePlafond, margeRecettes: ligue.margeRecettes, amendePrevue: ligue.amende,
    tresorerie: rond(tresorerie), tresoreriePrevue: rond(compte.depart + resultatPrevu + apportPrevu),
  } };
}

// Clôture de la saison d'un club : prime de classement, sanction de la ligue, apport du propriétaire.
//   tresorerie : caisse avant clôture ; joue : club du manager (messages et confiance).
function cloture({ division, compte, tresorerie, rang, taille, joue = false }) {
  const prime = primeClassement(division, rang, taille), recettesSaison = compte.recettes + prime;
  const ligue = regles({ division, masseAnnuelle: compte.masse, recettes: recettesSaison });
  const ecritures = [{ title: `Prime de classement de la ligue (${rang}${rang === 1 ? 'er' : 'e'} sur ${taille})`, amount: prime }], messages = [];
  let confiance = 0;
  if (joue) messages.push(`La ligue verse ${euros(prime)} au club pour sa ${rang}${rang === 1 ? 're' : 'e'} place.`);
  if (ligue.amende > 0) {
    const motif = ligue.depassementPlafond >= ligue.depassementRecettes ? 'dépassement du plafond salarial' : 'salaires des joueurs au-dessus de 52 % des recettes';
    ecritures.push({ title: 'Amende de la ligue (' + motif + ')', amount: -ligue.amende });
    if (joue) { confiance -= 6; messages.push(`La ligue sanctionne le club : ${euros(ligue.amende)} d’amende pour ${motif}. Vos dirigeants n’apprécient pas de voir le club épinglé.`); }
  }
  const resultat = rond(tresorerie + prime - ligue.amende - compte.depart), deficit = Math.max(0, -resultat);
  const apport = Math.min(compte.enveloppe, deficit), decouvert = deficit - apport;
  if (apport > 0) ecritures.push({ title: 'Apport du propriétaire', amount: apport });
  if (joue) {
    const grave = decouvert > recettesSaison * TOLERANCE_DEFICIT;
    if (apport > 0 && !grave) messages.push(compte.type === 'mecene' ? `Le président a signé le chèque : ${euros(apport)} pour combler les pertes de la saison, comme promis.` : `Le groupe actionnaire a comblé les pertes de la saison : ${euros(apport)}, dans la limite annoncée.`);
    if (grave) {
      confiance -= Math.min(15, 5 + Math.round(decouvert / recettesSaison * 100));
      messages.push(compte.type === 'association'
        ? `Le club termine la saison avec ${euros(deficit)} de pertes et personne pour les combler. Le bureau de l’association vous en tient pour responsable.`
        : `Les pertes de la saison (${euros(deficit)}) dépassent de ${euros(decouvert)} ce que le propriétaire avait promis. Il a versé ${euros(apport)} et vous l’a fait savoir : sa confiance en a pris un coup.`);
    } else if (deficit === 0) messages.push(`Le club termine la saison dans le vert : ${euros(resultat)} de mieux en caisse qu’au départ. Le propriétaire n’a rien eu à verser.`);
  }
  return { ecritures, messages, confiance, prime, amende: ligue.amende, resultat, apport, decouvert: rond(decouvert) };
}

// Code exécuté dans le moteur du jeu : il branche ce budget sur les carrières marquées
// (state.startingSalaries), en France comme dans les carrières mondiales, et laisse les autres intactes.
// Attend dans le moteur : nativeClubBudget (ce module), nativeStartingSalaries, nativeLeagueEconomy.
const BRANCHEMENT = `
const financeWeekV1=financeWeek,worldWeeklyEconomyV1=worldWeeklyEconomy,ledgerEntryV1=ledgerEntry,worldNewSeasonV1=worldNewSeason,worldPrepareRenewalLiquidityV1=worldPrepareRenewalLiquidity,salaryDemandBreakdownV1=salaryDemandBreakdown;
const budgetFrance=()=>!!S.franceMode&&typeof CDFranceClubs!=='undefined'&&typeof CDFranceCompetition!=='undefined'&&CDFranceCompetition.active(S);
const budgetMonde=()=>!S.franceMode&&typeof CDWorldCareer!=='undefined'&&CDWorldCareer.active(S);
const budgetActif=()=>!!S&&S.startingSalaries!==undefined&&(budgetFrance()||budgetMonde());
const budgetCopie=x=>JSON.parse(JSON.stringify(x));
const budgetLigue=id=>budgetFrance()?CDFranceCompetition.leagueId(S,id):CDWorldCareer.leagueId(S,id);
const budgetForces=()=>budgetFrance()?CDFranceClubs.clubs.map(c=>({id:c.id,division:CDFranceCompetition.leagueId(S,c.id),base:c.base})):S.clubs.map(c=>({id:c.id,division:CDWorldCareer.leagueId(S,c.id),base:c.base}));
const budgetSemaineNo=()=>S.franceMode?S.franceMode.week:S.worldMode.week;
const budgetMasse=c=>c.players.reduce((s,p)=>s+p.salary,0);
// Classement, réceptions de saison régulière et réceptions restantes de chaque club, à l'instant présent.
function budgetRepere(){
 const classement={},receptions={},restantes={};
 if(budgetFrance()){
  for(const division of ['elite','accession']){
   const ordre=CDFranceCompetition.ranked(S,division),l=S.franceMode.leagues[division];
   ordre.forEach((c,i)=>{classement[c.id]={division,rang:c.played?i+1:Math.ceil(ordre.length/2),taille:ordre.length};receptions[c.id]=CDFranceCompetition.regularRounds(S,division)/2;
    restantes[c.id]=l.schedule.slice(l.round).filter(j=>j.some(p=>p[0]===c.id)).length;});
  }
 }else{
  for(const division of [...Object.keys(S.worldMode.leagues),'guest']){
   const ordre=CDWorldCareer.ranked(S,division);
   ordre.forEach((c,i)=>{classement[c.id]={division,rang:c.played?i+1:Math.ceil(ordre.length/2),taille:Math.max(2,ordre.length)};});
  }
  for(const f of S.worldMode.fixtures){
   if(f.phase!=='league'||f.neutral)continue;
   receptions[f.homeId]=(receptions[f.homeId]||0)+1;if(f.week>=S.worldMode.week)restantes[f.homeId]=(restantes[f.homeId]||0)+1;
  }
 }
 return {classement,receptions,restantes};
}
function budgetPrevoir(forces,repere){
 const b=S.clubBudget,c=club(),semaines=wageForecastWeeks(),k=repere.classement[c.id]||b.clubs[c.id];
 const r=budgetCopie(nativeClubBudget.prevision({forces,clubId:c.id,compte:b.clubs[c.id],tresorerie:c.cash,masseHebdo:budgetMasse(c),semaines,reste:Math.max(0,semaines-b.semaines),
  receptions:repere.receptions[c.id]||12,receptionsRestantes:repere.restantes[c.id]||0,rang:k.rang,taille:k.taille}));
 b.prevision=r.prevision;
 for(const a of r.alertes){const derniere=b.alertes[a.cle];if(derniere===undefined||b.semaines-derniere>=10){b.alertes[a.cle]=b.semaines;news(a.message);}}
}
// Une sauvegarde retouchée ne doit pas faire tomber la semaine : des comptes illisibles sont rouverts.
const budgetLisible=b=>!!b&&b.version===1&&Number.isInteger(b.saison)&&Number.isInteger(b.semaines)&&b.semaines>=0&&!!b.alertes&&typeof b.alertes==='object'&&!Array.isArray(b.alertes)&&Array.isArray(b.clubs)&&b.clubs.length===S.clubs.length&&
 b.clubs.every(c=>!!c&&Object.hasOwn(nativeClubBudget.PROPRIETAIRES,c.type)&&[c.enveloppe,c.depart,c.recettes,c.charges,c.salaires,c.masse].every(Number.isFinite)&&c.enveloppe>=0&&
  typeof c.division==='string'&&Object.hasOwn(nativeClubBudget.DIVISIONS,c.division)&&Number.isInteger(c.taille)&&c.taille>=2&&Number.isInteger(c.rang)&&c.rang>=1&&c.rang<=c.taille);
function budgetOuvrir(annoncer){
 const forces=budgetForces(),types=budgetLisible(S.clubBudget)?S.clubBudget.clubs.map(c=>c.type):null;
 S.clubBudget=budgetCopie(nativeClubBudget.ouverture({forces,saison:S.season,types,clubs:S.clubs.map(c=>({id:c.id,cash:c.cash,masse:budgetMasse(c)*52}))}));
 if(annoncer)news(nativeClubBudget.annonce(S.clubBudget.clubs[S.club]));
 budgetPrevoir(forces,budgetRepere());
}
function budgetEtat(){if(!budgetLisible(S.clubBudget)||S.clubBudget.saison!==S.season)budgetOuvrir(false);return S.clubBudget;}
// rencontre : {pair:[domicile,extérieur], neutral, phase} ou null. Une poule européenne compte comme une journée ordinaire.
function budgetSemaine(forces,repere,c,rencontre,libelle){
 const b=budgetEtat(),masse=budgetMasse(c);
 const ecritures=budgetCopie(nativeClubBudget.semaine({forces,clubId:c.id,masseHebdo:masse,semaines:wageForecastWeeks(),receptions:repere.receptions[c.id]||12,
  domicile:!!rencontre&&rencontre.pair[0]===c.id,neutre:!!rencontre&&rencontre.neutral===true,phase:!rencontre||rencontre.phase==='pool'?'league':rencontre.phase,resultats:c.form.slice(-5),
  repere:S.season+'|'+budgetSemaineNo(),gere:c.id!==S.club,libelle}));
 nativeClubBudget.compter(b.clubs[c.id],ecritures,masse*52,repere.classement[c.id]||null);
 return ecritures;
}
financeWeek=function(m,won){
 if(!budgetActif())return financeWeekV1(m,won);
 const forces=budgetForces(),repere=budgetRepere(),f=budgetFrance()?CDFranceCompetition.userFixture(S):CDWorldCareer.userFixture(S);
 const ecritures=budgetSemaine(forces,repere,club(),f?{pair:f.pair||[f.homeId,f.awayId],neutral:f.neutral,phase:f.phase}:null,label());
 ecritures.forEach(e=>club().cash+=e.amount);S.ledger.unshift(...ecritures);S.ledger=S.ledger.slice(0,100);careerSponsorWeek(won);
 S.clubBudget.semaines++;budgetPrevoir(forces,repere);
 if(club().cash<0){S.trust=clamp(S.trust-5,0,100);news('La trésorerie est négative. Le président demande de réduire les dépenses.')}
};
worldWeeklyEconomy=function(results){
 if(!budgetActif())return worldWeeklyEconomyV1(results);
 const avant=S.clubs.map(c=>c.cash);
 if(!worldWeeklyEconomyV1(results))return false;
 const forces=budgetForces(),repere=budgetRepere();
 for(const c of S.clubs){
  if(c.id===S.club)continue;
  const rencontre=results.find(r=>r.pair.includes(c.id))||null;
  c.cash=avant[c.id]-worldUpkeep(worldClub(c.id).facilities)+budgetSemaine(forces,repere,c,rencontre,'').reduce((s,e)=>s+e.amount,0);
 }
 return true;
};
// Fin de saison : la prime de classement, la sanction éventuelle et l'apport du
// propriétaire remplacent le versement identique pour tous. Chaque club n'est clôturé qu'une fois.
function budgetCloturer(seulementGeres){
 const b=S.clubBudget;
 if(!budgetLisible(b)||(b.saison!==S.season&&b.saison!==S.season-1))return;
 for(const c of S.clubs){
  const compte=b.clubs[c.id],joue=c.id===S.club;
  if(compte.clos===true||(joue&&seulementGeres))continue;
  const r=budgetCopie(nativeClubBudget.cloture({division:compte.division,compte,tresorerie:c.cash,rang:compte.rang,taille:compte.taille,joue}));
  compte.clos=true;
  if(joue){r.ecritures.forEach(e=>ledgerEntryV1(e.title,e.amount));if(r.confiance)S.trust=clamp(S.trust+r.confiance,0,100);r.messages.forEach(m=>news(m));}
  else c.cash+=r.ecritures.reduce((s,e)=>s+e.amount,0);
 }
}
ledgerEntry=function(title,amount){
 if(budgetActif()&&title==='Financement de début de saison'&&amount===2500000)return budgetCloturer(false);
 return ledgerEntryV1(title,amount);
};
// Carrières mondiales : les clubs gérés sont clôturés avant les prolongations, à la place de leurs 2,5 M€.
worldPrepareRenewalLiquidity=function(){
 if(!budgetActif())return worldPrepareRenewalLiquidityV1();
 if(!budgetMonde()||S.phase!=='ended')throw Error('Financement international hors intersaison.');
 budgetCloturer(true);
 for(const c of S.clubs){if(c.id===S.club)continue;const info=worldClub(c.id);if(c.cash<0){info.debt+=-c.cash;c.cash=0;}}
};
worldNewSeason=function(fundingAlreadyPaid){
 if(!budgetActif())return worldNewSeasonV1(fundingAlreadyPaid);
 const actif=worldActive();
 if(actif){
  const w=S.worldManagement;w.champion=null;w.lastFinance=null;
  for(const c of S.clubs){
   if(c.id===S.club)continue;
   const info=worldClub(c.id);
   if(c.cash<0){info.debt+=-c.cash;c.cash=0}
   const outcome=CDFinancialRecovery.annual({cash:c.cash,debt:info.debt,wageRoom:100000},{revenue:0,baseCosts:0,repayment:Math.min(250000,info.debt)});
   c.cash=outcome.cash;info.debt=outcome.debt;
   if(info.facilities<7&&info.debt===0&&c.cash>4500000&&w.yearbook.at(-1)?.standings.find(x=>x.id===c.id)?.position<=7){
    const quote=worldFacilityQuote(c.id);
    if(quote?.affordable){c.cash-=quote.cost;info.facilities++;w.upgrades.push({season:S.season,id:c.id,level:info.facilities,cost:quote.cost});}
   }
  }
  w.upgrades=w.upgrades.slice(-30);
 }
 // Les clubs gérés remettent leurs contrats au niveau du marché : sans cela leurs prolongations reviennent à l'ancien barème.
 nativeStartingSalaries.recaler(S,budgetForces(),nativeLeagueEconomy,S.club);
 budgetOuvrir(true);
 return actif;
};
// Salaire demandé au club joué : même règle que les salaires de départ, puis l'attrait du championnat pour une recrue.
salaryDemandBreakdown=function(p,kind='renew',s=S){
 const r=salaryDemandBreakdownV1(p,kind,s);
 if(s!==S||!budgetActif()||!p||typeof p.id!=='string')return r;
 const juste=nativeStartingSalaries.demande(S,budgetForces(),S.club,p,nativeLeagueEconomy);
 if(kind==='renew'){const base=Math.max(p.salary,juste);return {...r,base,asked:Math.max(p.salary,Math.round(base*(1+(r.modifier||0))/10)*10)};}
 const a=nativeLeagueEconomy.attrait({origine:nativeLeagueEconomy.origine(p,id=>S.clubs[id]?budgetLigue(id):null),destination:budgetLigue(S.club),joueurId:p.id,age:p.age});
 return {...r,base:juste,asked:Math.max(10,Math.round(juste*a.multiplicateur/10)*10)};
};
`;

module.exports = Object.freeze({ ECONOMIE, DIVISIONS, COTISATIONS, FONCTIONNEMENT, PART_PRIME, PART_ABONNEMENTS, PLAFOND_SALARIAL, RATIO_SALAIRES, PROPRIETAIRES, BRANCHEMENT,
  recettes, semaine, proprietaire, forme, affluence, ajustement, primeClassement, regles, ouverture, compter, annonce, prevision, cloture, euros });
