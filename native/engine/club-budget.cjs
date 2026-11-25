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
// Fonctionnement dégressif (choix de Léo du 23/11/2026 : « Staff et fonctionnement » énorme chez les gros budgets, 610 000 €
// par semaine au Stade toulousain du jeu) : 58 % sur les 20 premiers M€ de recettes, 45 % au-delà. Les frais d'un club
// (administration, déplacements, stade) ne grossissent pas au même rythme que ses recettes. Tous les calculs du budget
// (masse autorisée, train de vie, prévision, perte prévue) lisent ce même montant.
const SEUIL_FONCTIONNEMENT = 20e6, FONCTIONNEMENT_AU_DELA = 0.45;
const fonctionnementAnnuel = annuel => FONCTIONNEMENT * Math.min(annuel, SEUIL_FONCTIONNEMENT) + FONCTIONNEMENT_AU_DELA * Math.max(0, annuel - SEUIL_FONCTIONNEMENT);

// Salaires du staff (choix de Léo du 23/11/2026) : chaque membre est payé selon son rôle, son niveau et la division du club.
// Salaire annuel de référence en première division française, pour un niveau 54 ; repères publiés (entraîneur principal de
// Top 14 : 250 000 à 500 000 € ; kinésithérapeute de club pro : 40 000 à 60 000 €). Les autres divisions suivent le rapport de
// leur masse salariale à celle du Top 14, à la puissance 0,75 (un staff se paie un peu moins bas que les joueurs : Pro D2 × 0,43,
// Nationale × 0,23).
// Niveau : × 0,6 au niveau 40, × 1 au niveau 54, × 1,46 au niveau 70, × 1,89 au niveau 85 : un meilleur kiné coûte plus cher.
// Ces salaires sortent de l'enveloppe de fonctionnement : le reste (« Fonctionnement du club ») est l'enveloppe moins le staff
// d'un club de ce rang (niveau attendu, 21 + 0,6 × base, comme l'avis des dirigeants) ; un staff meilleur que le rang du club
// coûte donc vraiment plus, un staff plus faible moins.
const STAFF_REFERENCE = Object.freeze({ chef: 320000, coach: 130000, assistant: 100000, fitnessChef: 95000, fitness: 70000, medecin: 100000, medical: 55000, soigneur: 40000,
  analyst: 55000, scoutChef: 80000, scout: 60000, formation: 80000, intendant: 35000, support: 45000 });
const CHEF = /principal|en chef|head coach|director of rugby|directeur (du rugby|sportif)|manager g[ée]n[ée]ral|general manager|capo allenatore|manager sportif|^manager$/i;
const RESPONSABLE = /responsable|head|directeur|director|lead|chief/i;
function categorieStaff(p) {
  const role = p?.role, label = String(p?.roleLabel ?? p?.role ?? '');
  if (role === 'coach' || role === 'assistant') return CHEF.test(label) ? 'chef' : role;
  if (role === 'fitness') return RESPONSABLE.test(label) ? 'fitnessChef' : 'fitness';
  if (role === 'medical') return /m[ée]decin|doctor|medico|medical|médical/i.test(label) ? 'medecin' : /soigneur|masseur|massage/i.test(label) ? 'soigneur' : 'medical';
  if (role === 'scout') return RESPONSABLE.test(label) ? 'scoutChef' : 'scout';
  if (role === 'analyst' || role === 'formation') return role;
  return /intendan|kit|magasin|property|interpr/i.test(label) ? 'intendant' : 'support';
}
const echelleStaff = division => { const d = ECONOMIE.CHAMPIONNATS[division], ref = ECONOMIE.CHAMPIONNATS.elite; return d && ref ? (d.masse / ref.masse) ** 0.75 : 0.5; };
const facteurNiveauStaff = niveau => Math.max(0.5, Math.min(2, 0.6 + ((Number.isFinite(niveau) ? niveau : 54) - 40) / 35));
const niveauAttenduStaff = base => Math.max(45, Math.min(80, Math.round(21 + 0.6 * (Number.isFinite(base) ? base : 65))));
// Salaire annuel d'un membre du staff (euros, arrondi à la centaine).
function salaireStaff(p, division, niveau = p?.level) {
  return rond(STAFF_REFERENCE[categorieStaff(p)] * echelleStaff(division) * facteurNiveauStaff(niveau));
}
// Staff d'un club : {annuel : salaires réels, reference : mêmes postes au niveau attendu du club, membres}.
function masseStaff(membres, division, base) {
  const attendu = niveauAttenduStaff(base);
  let annuel = 0, reference = 0, n = 0;
  for (const p of membres ?? []) { if (!p) continue; annuel += salaireStaff(p, division); reference += salaireStaff(p, division, attendu); n++; }
  return { annuel, reference, membres: n };
}

// forces : [{id, division, base, billetterie?}] ; renvoie les recettes annuelles visées par club.
// billetterie (carrière Monde, billetterie réelle) : recette annuelle de son stade (abonnements et guichet d'un match moyen,
// billetterieAnnuelle) ; elle remplace la part « billetterie » du modèle dans les recettes du club. Sans elle, le petit stade
// d'un club riche (un club du championnat celte de 8 700 places à 30 M€ de recettes) perdait 4 M€ par saison sur son budget
// voté, et le grand stade d'un club modeste en gagnait autant : la masse autorisée, le fonctionnement et la prévision suivent
// maintenant les vraies recettes de son stade.
function recettes(forces) {
  const resultat = new Map();
  for (const [division, regle] of Object.entries(DIVISIONS)) {
    const groupe = forces.filter(club => club.division === division);
    if (!groupe.length) continue;
    const min = Math.min(...groupe.map(club => club.base)), max = Math.max(...groupe.map(club => club.base));
    const brut = groupe.map(club => regle.bas + (regle.haut - regle.bas) * (max === min ? 0.5 : (club.base - min) / (max - min)));
    const correction = groupe.length / brut.reduce((somme, valeur) => somme + valeur, 0);
    groupe.forEach((club, i) => { const modele = regle.moyenne * brut[i] * correction; resultat.set(club.id, Number.isFinite(club.billetterie) && club.billetterie >= 0 ? modele * (1 - regle.billetterie) + club.billetterie : modele); });
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
// Réserve de trésorerie (suite de #869 : la trésorerie médiane doublait en trois saisons). Un vrai club
// garde une réserve de 10 à 20 % de ses recettes, propre à lui. Le propriétaire ne comble plus des pertes
// que la réserve peut absorber (fin de l'effet cliquet), et au-delà de la réserve, l'excédent ne dort pas :
// il est réinvesti dans le club la saison suivante, ou remonte en partie à l'actionnaire.
// Suite de #875 : la réserve est dégressive. Un club la compte sur ses 20 premiers M€ de recettes
// (10 à 20 %), puis 5 % au-delà : un coussin pensé pour payer les salaires et passer une mauvaise
// passe, pas pour thésauriser. Le Stade Toulousain réel (47 M€ de chiffre d'affaires, résultat net de
// 0,2 à 1,5 M€ par an) ou les clubs anglais (tous en perte) n'empilent pas des dizaines de M€.
const RESERVE = Object.freeze({ min: 0.1, ecart: 0.1, seuil: 20e6, auDela: 0.05 });
// Au-delà de la moitié de la réserve, l'excédent ne dort plus : il est engagé en entier la saison
// suivante (investissements et, pour un groupe actionnaire, dividende), dans les mêmes proportions.
const EXCEDENT_DORMANT = 0.5;
const EXCEDENTS = Object.freeze({
  mecene: Object.freeze({ investi: 0.6, dividende: 0 }),
  entreprise: Object.freeze({ investi: 0.35, dividende: 0.35 }),
  association: Object.freeze({ investi: 0.5, dividende: 0 }),
});
// Deuxième division française : réserve de 20 à 30 % des recettes (league-economy.cjs, reserve). Ses clubs démarrent avec
// 20 à 33 % de leurs recettes en caisse ; avec la réserve générale, cette trésorerie de départ était tout entière engagée
// en investissements dès la deuxième saison et toute la division finissait dans le rouge (14 à 16 clubs sur 16).
// Un club de Pro D2 garde un matelas plus large : une descente en troisième division coupe ses recettes de moitié,
// et le contrôle de gestion lui demande des garanties.
const reserveCible = (annuel, clubId, division = null) => {
  const propre = ECONOMIE.CHAMPIONNATS[division]?.reserve, regle = propre ? { ...RESERVE, ...propre } : RESERVE;
  return Math.round(((regle.min + regle.ecart * unite('reserve|' + clubId)) * Math.min(annuel, regle.seuil) +
    regle.auDela * Math.max(0, annuel - regle.seuil)) / 10000) * 10000;
};
// Part de l'excédent engagée à l'ouverture : la part propre au propriétaire, ou davantage pour qu'il
// ne reste pas plus d'une demi-réserve qui dort.
// plafond : engagement maximal de la saison (championnat encadré, engagementMax) : un bon élève de Pro D2 qui a dégagé
// +0,5 M€ ne les réinvestit plus tous la saison suivante (il repassait dans le rouge un an sur deux) ; il reconstitue
// ses fonds propres et engage le reste au fil des saisons.
function engagement(surplus, reserve, type, plafond = Infinity) {
  const regle = EXCEDENTS[type], part = regle.investi + regle.dividende;
  if (!(surplus > 0) || !(part > 0)) return { investissement: 0, dividende: 0 };
  const engage = Math.min(surplus, Math.max(surplus * part, surplus - EXCEDENT_DORMANT * reserve), Number.isFinite(plafond) && plafond >= 0 ? plafond : Infinity);
  return { investissement: rond(engage * regle.investi / part), dividende: rond(engage * regle.dividende / part) };
}
const cibleDe = compte => Number.isFinite(compte?.reserve) ? compte.reserve : Infinity;
// Ce que le propriétaire verse à la clôture : il comble les pertes, dans la limite promise, mais seulement
// ce qui fait passer la caisse sous la réserve du club. fin : caisse avant son versement.
function apportProprietaire(compte, deficit, fin) {
  const besoin = Math.min(deficit, Math.max(0, cibleDe(compte) - fin));
  const apport = Math.min(compte.enveloppe, besoin);
  return { apport, besoin, decouvert: besoin - apport, absorbe: deficit - besoin };
}

// Centre de formation (demande de Léo du 13 novembre : cohérent entre les pays).
// Le coût fait partie du fonctionnement : un centre de référence (30 Crabos, 30 Espoirs) coûte
// PART_FORMATION des recettes, ce qui est déjà dans les 58 % de fonctionnement. Ce montant est
// sorti de la ligne « Staff et fonctionnement » et montré à part ; un centre plus garni coûte plus,
// un centre réduit coûte moins. Un Espoir coûte plus qu'un Crabos (indemnité, hébergement, staff).
// Repères : Stade Toulousain, Cour des comptes 2024 (OCR2024-29) : environ 19 000 € par jeune et par
//   an facturés pour 35 jeunes, hors indemnités ; reversement LNR selon le classement des centres
//   (~180 000 à 260 000 €) et aide régionale de 100 000 €. Les autres pays sont estimés à partir de
//   leur organisation : académies anglaises cofinancées par la RFU, académies des fédérations
//   celtes, italienne, sud-africaine et du Pacifique financées surtout par la fédération, clubs
//   japonais d'entreprise sans aide publique.
const PART_FORMATION = 0.055;
const POIDS_CRABOS = 0.6, POIDS_ESPOIR = 1.4, REFERENCE_CRABOS = 30, REFERENCE_ESPOIRS = 30;
const FORMATION = Object.freeze({
  france: Object.freeze({ aide: 0.25, libelle: 'Aides LNR et région à la formation' }),
  angleterre: Object.freeze({ aide: 0.4, libelle: 'Fonds des académies de la fédération' }),
  celte: Object.freeze({ aide: 0.7, libelle: 'Prise en charge de l’académie par la fédération' }),
  pacifique: Object.freeze({ aide: 0.7, libelle: 'Prise en charge de l’académie par la fédération' }),
  japon: Object.freeze({ aide: 0, libelle: '' }),
  autre: Object.freeze({ aide: 0.3, libelle: 'Aides à la formation' }),
});
// Crédit académie du plafond salarial anglais : par joueur formé au club (arrivé avant 18 ans, moins
// de 24 ans, salaire annuel au-dessus de 50 000 £), au plus 6 joueurs. 100 000 £ ≈ 115 000 €.
const CREDIT_ACADEMIE = Object.freeze({ divisions: Object.freeze(['prem']), montant: 115000, seuil: 57500, maximum: 6, ageMax: 23 });
function reglesFormation(division) {
  return FORMATION[ECONOMIE.CHAMPIONNATS[division]?.pays] ?? FORMATION.autre;
}
// formation : {crabos, espoirs} présents au centre ; renvoie les montants annuels.
function centreFormation(annuel, division, formation) {
  const regle = reglesFormation(division);
  const reference = annuel * PART_FORMATION;
  const parPoids = reference / (REFERENCE_CRABOS * POIDS_CRABOS + REFERENCE_ESPOIRS * POIDS_ESPOIR);
  const crabos = Math.max(0, formation?.crabos ?? REFERENCE_CRABOS), espoirs = Math.max(0, formation?.espoirs ?? REFERENCE_ESPOIRS);
  const cout = parPoids * (crabos * POIDS_CRABOS + espoirs * POIDS_ESPOIR);
  return { reference, referenceNette: reference * (1 - regle.aide), cout, aide: cout * regle.aide, libelleAide: regle.libelle };
}
function creditAcademie(division, joueurs, clubId) {
  if (!CREDIT_ACADEMIE.divisions.includes(division)) return 0;
  const formes = (joueurs ?? []).filter(p => typeof p?.id === 'string' && p.id.startsWith('youth-' + clubId + '-') &&
    Number.isFinite(p.age) && p.age <= CREDIT_ACADEMIE.ageMax && Number.isFinite(p.salary) && p.salary * 52 > CREDIT_ACADEMIE.seuil).length;
  return Math.min(CREDIT_ACADEMIE.maximum, formes) * CREDIT_ACADEMIE.montant;
}

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
// modele : recettes du modèle de la division, sans la billetterie réelle (partenaires, ligue, subventions et boutique s'y lisent).
function regleDe(forces, clubId) {
  const force = forces.find(club => club.id === clubId), regle = force && DIVISIONS[force.division];
  if (!regle) throw Error('Budget de club : division inconnue.');
  const annuel = recettes(forces).get(clubId), reelle = Number.isFinite(force.billetterie) && force.billetterie >= 0;
  return { force, regle, annuel, modele: reelle ? (annuel - force.billetterie) / (1 - regle.billetterie) : annuel };
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
// Humeur des supporters (0-100, club du manager, club-strategy.cjs) : public multiplié par 0,90 (humeur 0) à 1,10
// (humeur 100), neutre à 50 ou inconnue (clubs gérés par le jeu). Choix de Léo du 23/11/2026 : effet réel et modeste.
const HUMEUR_PUBLIC = 0.10;
// Billetterie réelle (choix de Léo du 23/11/2026) : la recette d'un match à domicile = billets vendus au guichet × prix du
// billet, encaissée au match ; les abonnés paient leur place à l'année (Abonnements, chaque semaine, 30 % de remise). Le prix
// du billet suit la division (league-economy.cjs, billet) et la politique choisie par le manager ; il pèse sur l'affluence :
// sous le prix de la division, le public grossit peu (élasticité 0,4 : billet à 60 % → public × 1,23) ; au-dessus, il fond
// vite (élasticité 1,2 : billet × 1,5 → public × 0,61). L'affluence reste bornée par la vraie capacité du stade : pour une
// grosse affiche qui remplirait deux stades, monter le prix ne coûte presque aucun spectateur (prix ajusté par match).
// Préréglages (anciens boutons de la politique de prix) : accessible = billet × 0,6, premium = billet × 1,5.
const POLITIQUES_BILLET = Object.freeze({ accessible: Object.freeze({ prix: 0.6 }), equilibree: Object.freeze({ prix: 1 }), premium: Object.freeze({ prix: 1.5 }) });
const ELASTICITE_PRIX = Object.freeze({ bas: 0.4, haut: 1.2 });
// rapport : prix du billet / prix de la division ; facteur appliqué au public (0,05 à 1,35). Grosse affiche : le public tient
// mieux au match (élasticité 0,6 jusqu'à 1,5 fois le prix de la division, 1,6 au-delà) : la monter rapporte, jusqu'à un point.
function facteurPrix(rapport, affiche = false) {
  const r = Number.isFinite(rapport) && rapport > 0 ? rapport : 1;
  const f = r <= 1 ? r ** -ELASTICITE_PRIX.bas : !affiche ? r ** -ELASTICITE_PRIX.haut : r <= 1.5 ? r ** -0.6 : 1.5 ** -0.6 * (r / 1.5) ** -1.6;
  return Math.max(0.05, Math.min(1.35, f));
}
// Politique : préréglage (texte) ou rapport prix / prix de la division (nombre).
const rapportPrix = politique => Number.isFinite(politique) && politique > 0 ? politique : POLITIQUES_BILLET[politiqueBillet(politique)].prix;
// Estimation du staff (règle de Léo du 23/11/2026 : jamais d'effet chiffré exact avant d'agir) : la valeur vraie décalée de 1 à
// 3 % pour un très bon staff (niveau 80 et plus), jusqu'à 5 à 15 % pour un staff faible (niveau 45), dans un sens tiré du match.
function estimationStaff(valeur, niveau, cle, pas = 10) {
  const amplitude = Math.max(0.03, Math.min(0.15, 0.03 + (80 - (Number.isFinite(niveau) ? niveau : 55)) / 290));
  const u = unite('estimation|' + cle), signe = u < 0.5 ? -1 : 1, part = 0.35 + 0.65 * (u < 0.5 ? u : u - 0.5) * 2;
  return Math.max(0, Math.round((Number.isFinite(valeur) ? valeur : 0) * (1 + signe * amplitude * part) / pas) * pas);
}
// Conseil de prix d'un membre du staff (et prix appliqué quand le manager lui confie la billetterie) : le meilleur prix décalé
// de 25 à 100 % d'une amplitude de ±30 % au niveau 45 à ±5 % au niveau 85, jamais exact ; parfois mieux que le manager,
// parfois moins bien.
function conseilPrix(optimum, niveau, cle) {
  const amplitude = Math.max(0.05, Math.min(0.3, 0.3 - ((Number.isFinite(niveau) ? niveau : 55) - 45) * 0.00625));
  const u = unite('conseil|' + cle), signe = u < 0.5 ? -1 : 1, part = 0.25 + 0.75 * (u < 0.5 ? u : u - 0.5) * 2;
  const prix = Math.max(1, Math.round(optimum * (1 + signe * amplitude * part)));
  return prix === optimum ? prix + signe : Math.max(1, prix);
}
const REMISE_ABONNEMENT = 0.7;
const politiqueBillet = politique => Object.hasOwn(POLITIQUES_BILLET, politique ?? '') ? politique : 'equilibree';
function prixBillet(division, politique) {
  const reference = ECONOMIE.CHAMPIONNATS[division]?.billet;
  return Math.max(1, Math.round((Number.isFinite(reference) ? reference : 20) * POLITIQUES_BILLET[politiqueBillet(politique)].prix));
}
// Abonnés d'un club géré par le jeu : même règle que les abonnés de départ du club du manager (fan-experience-v111-v116.js,
// initialSubscribers) : 25 % de la capacité pour un petit club, 75 % pour un grand, ±3 points propres au club.
function abonnesEstimes(capacite, base, cle = '') {
  const places = Number.isInteger(capacite) && capacite >= 500 && capacite <= 100000 ? capacite : 12000, t = Math.max(0, Math.min(1, ((Number.isFinite(base) ? base : 70) - 60) / 26));
  let h = 2166136261; const k = String(cle);
  for (let i = 0; i < k.length; i++) { h ^= k.charCodeAt(i); h = Math.imul(h, 16777619) >>> 0; }
  return Math.max(0, Math.min(Math.round(places * Math.max(0.2, Math.min(0.78, 0.25 + 0.5 * t + ((h % 7) - 3) / 100))), places, 100000));
}
// Recette d'un match à domicile : {spectateurs, abonnes, payants, prix, recette}. finale : billet × 1,5 (phase finale).
// Abonnés présents : 85 % des abonnés (les autres places d'abonnés ne se revendent pas) ; le reste du public paie au guichet.
const PRESENCE_ABONNES = 0.85;
function guichet({ spectateurs: n, abonnes, prix, finale = false }) {
  const presents = Number.isFinite(n) ? Math.max(0, Math.round(n)) : 0, abo = Math.max(0, Math.round((Number.isFinite(abonnes) ? abonnes : 0) * PRESENCE_ABONNES));
  const payants = Math.max(0, presents - abo), tarif = finale ? Math.round(prix * GUICHET_PHASE_FINALE) : prix;
  return { spectateurs: presents, abonnes: Math.min(abo, presents), payants, prix: tarif, recette: payants * tarif };
}
// Billetterie d'une saison type (budget voté) : abonnements + guichet d'un match moyen (forme neutre, tirage médian,
// politique équilibrée) à chaque réception de saison régulière.
function billetterieAnnuelle({ capacite, abonnes, prix, receptions, demande = 1 }) {
  const n = spectateurs({ capacite, resultats: ['V', 'D'], alea: 0.5, abonnes, demande }), matchs = Math.max(0, receptions);
  return rond(Math.max(0, abonnes) * prix * REMISE_ABONNEMENT * matchs + guichet({ spectateurs: n, abonnes, prix }).recette * matchs);
}
// Abonnements de la saison, versés chaque semaine : abonnés × billet × 70 % × réceptions de saison régulière / semaines.
const abonnementsHebdo = ({ abonnes, prix, receptions, semaines }) => rond(Math.max(0, abonnes) * prix * REMISE_ABONNEMENT * Math.max(1, receptions) / Math.max(1, semaines));
const facteurHumeur = humeur => Number.isFinite(humeur) ? 1 + HUMEUR_PUBLIC * (Math.max(0, Math.min(100, humeur)) - 50) / 50 : 1;
// Spectateurs d'une rencontre (compte rendu du match, idée FM n°19) : la même affluence que la billetterie (forme du
// club qui reçoit, aléa, accueil du stade) ramenée à un remplissage de 50 % (cinq défaites) à 95 % (cinq victoires)
// en saison, 97 % en phase finale ; arrondi à la dizaine. Capacité inconnue : null. humeur : humeur des supporters du
// club qui reçoit s'il est celui du manager (facteurHumeur), sinon neutre.
// politique : préréglage de prix du club qui reçoit (accessible, equilibree, premium) ou rapport prix du billet / prix de la
// division (nombre) ; alea : tirage imposé (sinon tiré de cle).
// affiche : grosse affiche (derby, club plus fort) : 30 % de demande en plus, jusqu'au stade plein.
// abonnes : abonnés du club : les présents (85 %) occupent leurs places, le prix du billet ne joue que sur le reste du public,
// qui remplit les places restantes au même taux (0 : tout le stade est au guichet, comme avant).
// demande : appétit du public occasionnel du club (division et réputation, league-economy.cjs, public) : multiplie le
// remplissage des places hors abonnés (pas en phase finale, où le stade est plein).
function spectateurs({ capacite, resultats, cle = '', accueil = 1, phase = 'league', humeur = null, politique = null, alea = null, affiche = false, abonnes = 0, demande = 1 }) {
  if (!Number.isFinite(capacite) || capacite <= 0) return null;
  const a = affluence(forme(resultats), Number.isFinite(alea) ? alea : unite('affluence|' + cle)) * (Number.isFinite(accueil) && accueil > 0 ? accueil : 1);
  // L'humeur multiplie le public comme la billetterie (±10 % au plus), dans les mêmes bornes de remplissage ; le prix du
  // billet l'élargit ou le réduit ensuite, sans jamais dépasser la capacité. Phase finale : stade plein quel que soit le prix.
  const taux = phase !== 'league' && phase !== 'pool' ? 0.97 : Math.min(1, Math.min(affiche ? 1 : 0.95, Math.max(0.35, (0.5 + 0.45 * (a - 0.78) / 0.44) * facteurHumeur(humeur) * (affiche ? 1.3 : 1))) * facteurPrix(rapportPrix(politique), affiche));
  const presents = Math.min(capacite, Math.round(Math.max(0, Number.isFinite(abonnes) ? abonnes : 0) * PRESENCE_ABONNES));
  const part = phase !== 'league' && phase !== 'pool' ? taux : Math.min(1, taux * (Number.isFinite(demande) && demande > 0 ? demande : 1));
  return Math.round((presents + (capacite - presents) * part) / 10) * 10;
}

// Ce qu'un club géré par le jeu ajuste dans son fonctionnement, sur l'année : il réduit
// ses dépenses quand son déficit dépasse ce que le propriétaire comble, et il réinvestit
// l'essentiel de ses excédents. Positif = dépense en plus.
// marge : excédent que le budget voté vise (championnat encadré, cibleGestion) : ce n'est pas un surplus imprévu,
// le train de vie n'y touche pas ; seul ce qui le dépasse est réinvesti.
const TRAIN_DE_VIE = 0.7;
function ajustement(annuel, masseAnnuelle, enveloppe, marge = 0) {
  const resultat = annuel - fonctionnementAnnuel(annuel) - masseAnnuelle * (1 + COTISATIONS);
  if (resultat > 0) return TRAIN_DE_VIE * Math.max(0, resultat - Math.max(0, Number.isFinite(marge) ? marge : 0));
  const economies = Math.min(0.15 * annuel, 0.7 * Math.max(0, -resultat - enveloppe));
  return economies > 0 ? -economies : 0;
}

// Championnat encadré (deuxième division française) : résultat annuel que vise le budget voté d'un club, en euros
// (positif : excédent visé ; négatif : perte que le propriétaire comblera). Avant (#885), tous les clubs visaient la perte
// que leur propriétaire comble : à masse moyenne réelle (3,2 M€, 30 % des recettes, le point mort), presque toute la division
// finissait dans le rouge dès la troisième saison (12 à 14 clubs sur 16, réel : 14). Chaque club a maintenant sa propre
// gestion, stable d'une saison à l'autre : une association « bon élève » reconstitue ses fonds propres (+2 à +6 % des
// recettes, Aurillac +0,50 M€ en 2024-2025), une entreprise utilise 20 à 100 % de l'enveloppe de son actionnaire (Charente,
// Valence, Colomiers près de l'équilibre), un mécène 50 à 100 % (Brive, Oyonnax). 0 hors des championnats encadrés.
function cibleGestion(forces, clubId, typeConnu = null) {
  const championnat = ECONOMIE.CHAMPIONNATS[forces.find(club => club.id === clubId)?.division];
  if (!championnat?.encadrement || !championnat.gestion) return 0;
  const { annuel } = regleDe(forces, clubId), p = proprietaire(forces, clubId, typeConnu), regle = championnat.gestion[p.type], u = unite('gestion|' + clubId);
  if (!regle) return 0;
  return p.type === 'association' ? rond(annuel * (regle.min + regle.ecart * u)) : -rond(p.enveloppe * (regle.min + regle.ecart * u));
}

// Masse salariale annuelle qu'un club s'autorise : la plus basse de trois bornes — le plafond de la
// ligue, 52 % des recettes là où la règle existe, et ce que ses recettes et son propriétaire peuvent
// porter (économies de fonctionnement comprises). Chaque club garde une marge qui lui est propre ;
// de temps en temps, un club de mécène choisit de dépasser un peu la borne des recettes et de payer
// l'amende, jamais le plafond de la ligue.
// À la création, personne ne dépasse.
// remboursements : {id: remboursement annuel du prêt de l'actionnaire} (club-owner.cjs) : autant de moins pour les salaires.
function limites(forces, saison, { creation = false, types = null, credits = null, remboursements = null } = {}) {
  const annuels = recettes(forces), resultat = new Map();
  for (const force of forces) {
    const regle = ECONOMIE.CHAMPIONNATS[force.division];
    if (!regle) continue;
    const annuel = annuels.get(force.id), p = proprietaire(forces, force.id, types?.[force.id]);
    // Deuxième division française (encadrement) : la masse ne s'appuie que sur les recettes et ce que le propriétaire
    // comble. Sans cela, chaque club visait ~40 % de ses recettes en salaires (point mort : 30 %), comptait sur 15 % d'économies
    // que le train de vie ne rend qu'en partie, et la Pro D2 entière finissait dans le rouge, caisse vidée en trois saisons.
    // Repère réel (A2R/CCCP 2024-2025) : salaires des joueurs à 30 % des produits en moyenne ; 2 clubs sur 16 en bénéfice,
    // 5 ou 6 proches de l'équilibre (Charente -0,07 M€, Valence -0,13), les autres en perte, comblée par les actionnaires.
    // Marge de prudence (prudence, part des recettes, league-economy.cjs) : la saison réelle coûte plus que le budget voté
    // (recrues et jokers en cours de saison) ; un championnat encadré peut demander que la masse en tienne compte.
    // Suite (#885 → ici) : la borne suit la gestion propre du club (cibleGestion) au lieu de l'enveloppe entière du propriétaire.
    const economies = regle.encadrement ? 0 : 0.15 * annuel, prudence = (regle.prudence ?? 0) * annuel, aPerdre = regle.encadrement && regle.gestion ? -cibleGestion(forces, force.id, p.type) : p.enveloppe;
    const rembourse = Number.isFinite(remboursements?.[force.id]) ? Math.max(0, remboursements[force.id]) : 0;
    const bornes = [['budget', (annuel - fonctionnementAnnuel(annuel) - prudence + aPerdre + economies - rembourse) / (1 + COTISATIONS)]];
    const credit = credits?.[force.id] ?? 0;
    if (regle.plafond !== null) bornes.push(['plafond', regle.plafond + credit]);
    if (regle.ratio) bornes.push(['recettes', annuel * RATIO_SALAIRES]);
    bornes.sort((x, y) => x[1] - y[1]);
    const rigueur = unite('rigueur|' + force.id + '|' + saison), audace = !creation && p.type === 'mecene' && unite('audace|' + force.id + '|' + saison) < 0.12;
    const tolerance = audace ? 1.01 + 0.04 * rigueur : 0.93 + 0.065 * rigueur;
    // Le plafond salarial d'une ligue n'est jamais dépassé volontairement, même par un mécène
    // audacieux (décision de Léo du 12 novembre) : l'audace ne joue que sous les autres bornes.
    const limite = regle.plafond !== null ? Math.min(regle.plafond + credit, bornes[0][1] * tolerance) : bornes[0][1] * tolerance;
    resultat.set(force.id, { limite: rond(limite), regle: bornes[0][0], tolerance, audace });
  }
  return resultat;
}

// Écritures d'une semaine de compétition.
//   domicile : le club reçoit ; neutre : match sur terrain neutre ; phase : 'league' ou une phase finale ;
//   resultats : derniers résultats du club ('V', 'N', 'D') ; alea dans [0;1] (tiré du club et de la date par défaut) ;
//   receptions : matchs de saison régulière à domicile ; gere : club géré par le jeu.
//   marge : excédent visé par le budget voté (cibleGestion), épargné par le train de vie ; 0 pour le club joué.
//   humeur : humeur des supporters du club du manager (0-100) : relève ou baisse le public payant (facteurHumeur).
//   billets : billetterie réelle {prix, abonnes, spectateurs, abonnementsHebdo} (prix et spectateurs du match de la semaine à
//     domicile, sinon null) : Abonnements = abonnementsHebdo, Billetterie = guichet ; sans billets (anciens appels), l'ancienne part des recettes.
//   staff : {annuel, reference} (masseStaff) : Salaires du staff (cotisations comprises dans Cotisations) et fonctionnement
//     du club = enveloppe − staff de référence ; sans staff, une seule ligne « Staff et fonctionnement » comme avant.
function semaine({ forces, clubId, masseHebdo, semaines, domicile, alea, libelle, resultats, phase = 'league', neutre = false, receptions, gere = false, repere = '', formation = null, investissement = 0, accueil = 1, marge = 0, aideRelegation: aide = 0, remboursement = 0, humeur = null, billets = null, staff = null }) {
  const { force, regle, annuel, modele } = regleDe(forces, clubId);
  if (!Number.isInteger(semaines) || semaines < 1) throw Error('Budget de club : nombre de semaines invalide.');
  const salaires = rond(masseHebdo * 52 / semaines), matchs = Math.max(1, receptions ?? Math.round(semaines / 2));
  const hasard = Number.isFinite(alea) ? alea : unite('affluence|' + clubId + '|' + repere), public_ = affluence(forme(resultats), hasard) * (Number.isFinite(accueil) && accueil > 0 ? accueil : 1) * facteurHumeur(humeur);
  const billetterie = modele * regle.billetterie, finale = phase !== 'league';
  const reels = !!billets && Number.isFinite(billets.prix) && billets.prix > 0 && Number.isFinite(billets.abonnes);
  const ecritures = [
    { title: libelle + ' · Partenaires', amount: rond(modele * regle.partenaires / semaines) },
    { title: libelle + ' · Versement de la ligue', amount: rond(modele * regle.ligue * (1 - PART_PRIME) / semaines) },
    { title: libelle + ' · Subventions et divers', amount: rond(modele * regle.divers / semaines) },
    { title: libelle + ' · Abonnements', amount: reels ? (Number.isFinite(billets.abonnementsHebdo) ? billets.abonnementsHebdo : abonnementsHebdo({ abonnes: billets.abonnes, prix: billets.prix, receptions: matchs, semaines })) : rond(billetterie * PART_ABONNEMENTS / semaines) },
  ];
  if (Number.isFinite(aide) && aide > 0) ecritures.push({ title: libelle + ' · ' + LIBELLE_AIDE_RELEGATION, amount: rond(aide / semaines) });
  if (domicile && !neutre) {
    // Prix réel du match (billet de base ou des grosses affiches, phase finale comprise) : pas de majoration en plus.
    const recette = reels && Number.isFinite(billets.spectateurs) ? guichet({ spectateurs: billets.spectateurs, abonnes: billets.abonnes, prix: billets.prix }).recette : null;
    ecritures.push(finale
      ? { title: libelle + ' · Billetterie de phase finale', amount: recette ?? rond(billetterie / matchs * GUICHET_PHASE_FINALE * public_) }
      : { title: libelle + ' · Billetterie', amount: recette ?? rond(billetterie * (1 - PART_ABONNEMENTS) / matchs * public_) });
    ecritures.push({ title: libelle + ' · Boutique et buvettes', amount: rond(modele * regle.boutique / matchs * (finale ? GUICHET_PHASE_FINALE : 1) * (0.9 + 0.2 * hasard) * (Number.isFinite(accueil) && accueil > 0 ? accueil : 1)) });
  } else if (neutre) {
    ecritures.push({ title: libelle + ' · Part de recette de phase finale', amount: rond(regle.moyenne * regle.billetterie / matchs * PART_TERRAIN_NEUTRE) });
  }
  const train = gere ? ajustement(annuel, masseHebdo * 52, proprietaire(forces, clubId).enveloppe, marge) : 0;
  const centre = centreFormation(annuel, force.division, formation);
  ecritures.push({ title: libelle + ' · Salaires des joueurs', amount: -salaires });
  if (staff && Number.isFinite(staff.annuel) && Number.isFinite(staff.reference)) {
    // Staff payé sur les mêmes semaines que les joueurs ; le train de vie (excédent dépensé) a sa propre ligne, les
    // économies d'un club en déficit réduisent son fonctionnement.
    const paieStaff = rond(staff.annuel / semaines);
    ecritures.push({ title: libelle + ' · ' + LIBELLE_STAFF, amount: -paieStaff });
    ecritures.push({ title: libelle + ' · Cotisations', amount: -rond((salaires + paieStaff) * COTISATIONS) });
    const reste = fonctionnementAnnuel(annuel) - centre.referenceNette - staff.reference * (1 + COTISATIONS) + Math.min(0, train);
    ecritures.push({ title: libelle + ' · ' + LIBELLE_FONCTIONNEMENT, amount: -rond(Math.max(0, reste) / semaines) });
    if (train > 0) ecritures.push({ title: libelle + ' · ' + LIBELLE_TRAIN_DE_VIE, amount: -rond(train / semaines) });
  } else {
    ecritures.push({ title: libelle + ' · Cotisations', amount: -rond(salaires * COTISATIONS) });
    ecritures.push({ title: libelle + ' · Staff et fonctionnement', amount: -rond((fonctionnementAnnuel(annuel) + train - centre.referenceNette) / semaines) });
  }
  ecritures.push({ title: libelle + ' · Centre de formation', amount: -rond(centre.cout / semaines) });
  if (centre.aide > 0) ecritures.push({ title: libelle + ' · ' + centre.libelleAide, amount: rond(centre.aide / semaines) });
  if (Number.isFinite(investissement) && investissement > 0) ecritures.push({ title: libelle + ' · Investissements (excédents réinvestis)', amount: -rond(investissement / semaines) });
  // Prêt de l'actionnaire (club-owner.cjs) : remboursé au fil de la saison ; une sortie de caisse, pas une charge.
  if (Number.isFinite(remboursement) && remboursement > 0) ecritures.push({ title: libelle + ' · ' + LIBELLE_REMBOURSEMENT, amount: -rond(remboursement / semaines) });
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
// excedents : nouvelle saison (pas la création ni une réouverture) ; la part de la caisse au-dessus de la
// réserve est réinvestie pendant la saison (investissement, annuel) et, pour un groupe actionnaire, en
// partie remontée en dividende (dividende, à débiter une fois par l'appelant ; depart en tient compte).
// aides : {id: montant} aide de la ligue aux clubs relégués pour la saison (aideRelegation).
function ouverture({ forces, saison, clubs, types = null, excedents = false, aides = null }) {
  const tailles = new Map(), annuels = recettes(forces);
  for (const force of forces) tailles.set(force.division, (tailles.get(force.division) ?? 0) + 1);
  return { version: 1, saison, semaines: 0, alertes: {}, clubs: clubs.map(club => {
    const p = proprietaire(forces, club.id, types?.[club.id]), division = forces.find(force => force.id === club.id).division, taille = Math.max(2, tailles.get(division));
    const reserve = reserveCible(annuels.get(club.id), club.id, division), surplus = excedents ? Math.max(0, club.cash - reserve) : 0;
    const { dividende, investissement } = engagement(surplus, reserve, p.type, ECONOMIE.CHAMPIONNATS[division]?.engagementMax * annuels.get(club.id));
    return { type: p.type, enveloppe: p.enveloppe, depart: club.cash - dividende, recettes: 0, charges: 0, salaires: 0, masse: Math.round(club.masse), division, rang: Math.ceil(taille / 2), taille,
      reserve, investissement, dividende, aideRelegation: Number.isFinite(aides?.[club.id]) && aides[club.id] > 0 ? rond(aides[club.id]) : 0 };
  }) };
}
const annonceDividende = montant => `Le groupe actionnaire a fait remonter ${euros(montant)} de la trésorerie du club : la réserve reste intacte, le surplus lui revient.`;
// Aide de la ligue à un club relégué (league-economy.cjs, aideRelegue) : montant de la saison, selon le nombre de saisons
// passées depuis la descente (0 = première saison dans la division inférieure) ; 0 hors du dispositif.
function aideRelegation(division, depuis, saisonsDepuis) {
  const regle = ECONOMIE.CHAMPIONNATS[division]?.aideRelegue;
  if (!regle || regle.depuis !== depuis || !Number.isInteger(saisonsDepuis) || saisonsDepuis < 0) return 0;
  return regle.montants[saisonsDepuis] ?? 0;
}
const LIBELLE_AIDE_RELEGATION = 'Aide de la ligue aux clubs relégués';
const LIBELLE_STAFF = 'Salaires du staff', LIBELLE_FONCTIONNEMENT = 'Fonctionnement du club', LIBELLE_TRAIN_DE_VIE = 'Train de vie du club';
const LIBELLE_REMBOURSEMENT = 'Remboursement du prêt de l’actionnaire';
const annonceAideRelegation = (montant, premiere) => premiere
  ? `Descente : la ligue accompagne les clubs relégués. Le club touchera ${euros(montant)} de plus cette saison, versés avec la part de la ligue, puis une aide plus faible la saison prochaine.`
  : `Dernière saison de l’aide de la ligue aux relégués : ${euros(montant)}, versés avec la part de la ligue. Ensuite, le club vivra avec les seules recettes de sa division.`;
const annonceInvestissement = (montant, reserve) => `La trésorerie dépasse la réserve que le club se fixe (${euros(reserve)}). Les dirigeants réinvestiront ${euros(montant)} cette saison dans les installations, le staff et l’accueil : le président t’écrit pour en parler.`;
// Recettes de guichet imprévues (suite de #875). Le train de vie d'un club suit le budget voté : 70 % de
// l'excédent prévu y retourne (ajustement). Mais une série de victoires remplit le stade, une phase finale
// à domicile rapporte une recette entière en plus, et ces recettes-là tombaient intégralement en caisse :
// le meneur gagnait 4 à 5 M€ de plus par saison. Dans un vrai club, elles s'accompagnent de primes de
// victoire et de qualification, d'accueil, de sécurité et de déplacements : 70 % en repartent aussi.
// Écart de la semaine entre le guichet encaissé et le guichet attendu d'un match moyen (affluence 1, accueil
// du club compris) ; une phase finale n'est jamais attendue. Négatif après une série de défaites.
// billets : billetterie réelle ({attendu} : recette au guichet d'un match moyen de ce club, à forme neutre) : l'attendu est le
// plus bas des deux (sa recette moyenne, la part du budget) ; sans billets, la part des recettes du budget.
function recettesImprevues(ecritures, { forces, clubId, receptions, accueil = 1, billets = null }) {
  const { regle, modele: annuel } = regleDe(forces, clubId), matchs = Math.max(1, receptions ?? 13), facteur = Number.isFinite(accueil) && accueil > 0 ? accueil : 1;
  const titre = e => e.title.slice(e.title.lastIndexOf(' · ') + 3);
  const finale = ecritures.some(e => ['Billetterie de phase finale', 'Part de recette de phase finale'].includes(titre(e)));
  let ecart = 0;
  for (const e of ecritures) {
    const t = titre(e);
    if (t === 'Billetterie de phase finale' || t === 'Part de recette de phase finale') ecart += e.amount;
    // Billetterie réelle : un grand stade rapporte plus que la part « billetterie » du budget ; ce surplus de structure compte
    // comme imprévu (accueil, sécurité, primes : la moitié en repart), un petit stade n'est jugé que sur sa propre recette moyenne.
    else if (t === 'Billetterie') { const part = annuel * regle.billetterie * (1 - PART_ABONNEMENTS) / matchs * facteur; ecart += e.amount - (Number.isFinite(billets?.attendu) ? Math.min(billets.attendu, part) : part); }
    else if (t === 'Boutique et buvettes') ecart += e.amount - (finale ? 0 : annuel * regle.boutique / matchs * facteur);
  }
  return rond(ecart);
}
// Ce que coûtent ces recettes imprévues, cumulées sur la saison (une défaite à domicile compense une
// victoire) : 70 % du cumul positif, moins ce qui a déjà été payé. compte : compteur du club.
// Un club dont le budget voté est déjà dans le rouge s'en sert d'abord pour boucher ce trou (deficit :
// perte annuelle prévue, voir deficitPrevu) ; seul ce qui dépasse repart en primes et en frais.
function fraisDeMatch(compte, ecart, deficit = 0) {
  const imprevu = (Number.isFinite(compte?.imprevu) ? compte.imprevu : 0) + (Number.isFinite(ecart) ? ecart : 0);
  const base = imprevu - (Number.isFinite(deficit) && deficit > 0 ? deficit : 0);
  const deja = Number.isFinite(compte?.fraisMatch) ? compte.fraisMatch : 0, montant = Math.max(0, rond(PART_FRAIS_IMPREVUS * base - deja));
  return { montant, imprevu, fraisMatch: deja + montant };
}
// Perte annuelle que le budget voté d'un club prévoit avant le propriétaire (recettes moyennes, fonctionnement
// de base, salaires et cotisations) ; 0 si le budget est équilibré ou excédentaire.
function deficitPrevu(forces, clubId, masseAnnuelle) {
  const { annuel } = regleDe(forces, clubId);
  return Math.max(0, rond(masseAnnuelle * (1 + COTISATIONS) - (annuel - fonctionnementAnnuel(annuel))));
}
// Moitié seulement (décision de Léo du 17/11 : « il faut que ça reste un jeu ») : une belle saison doit se voir en caisse.
const PART_FRAIS_IMPREVUS = 0.5;
const LIBELLE_FRAIS_MATCH = 'Frais de match et primes de résultats';
// Ajoute les écritures d'une semaine au compteur d'un club ; classement : {division, rang, taille} du moment.
function compter(compte, ecritures, masseAnnuelle, classement = null) {
  for (const e of ecritures) {
    if (e.title.endsWith(LIBELLE_REMBOURSEMENT)) { compte.rembourse = (Number.isFinite(compte.rembourse) ? compte.rembourse : 0) - e.amount; continue; }
    if (e.amount > 0) compte.recettes += e.amount; else compte.charges -= e.amount;
    if (e.title.endsWith('Salaires des joueurs')) compte.salaires -= e.amount;
  }
  compte.masse = Math.round(masseAnnuelle);
  if (classement) { compte.division = classement.division; compte.rang = classement.rang; compte.taille = classement.taille; }
  return compte;
}

const ANNONCES = Object.freeze({
  mecene: e => `Le président finance le club sur sa fortune. Il te l’a dit en face : cette saison, il comblera jusqu’à ${euros(e)} de pertes. Au-delà, il te demandera des comptes.`,
  entreprise: e => `Le groupe actionnaire a voté son budget : il comblera jusqu’à ${euros(e)} de déficit cette saison, pas un euro de plus.`,
  association: () => 'Le club appartient à ses adhérents : personne ne comblera un déficit. Chaque euro dépensé cette saison devra être gagné.',
});
const annonce = compte => ANNONCES[compte.type](compte.enveloppe);
// Message au manager quand les clauses de montée ou de descente ont joué dans ses contrats.
const annonceClauses = (sens, avant, apres, touches) => sens < 0
  ? `Descente : ${touches} contrats prévoyaient une baisse de salaire en cas de relégation. La masse salariale passe de ${euros(avant)} à ${euros(apres)} par an.`
  : `Montée : ${touches} contrats prévoyaient une prime d’accession. La masse salariale passe de ${euros(avant)} à ${euros(apres)} par an.`;

// Prévision de la saison du club joué, mise à jour chaque semaine.
//   compte : compteur du club ; tresorerie : caisse actuelle ; reste : semaines restantes ;
//   receptionsRestantes : matchs de saison régulière à domicile encore à jouer ; rang, taille : classement actuel.
//   billets : billetterie réelle {abonnementsHebdo, attendu} (même calcul que les écritures de la semaine) ; staff : masseStaff.
function prevision({ forces, clubId, compte, tresorerie, masseHebdo, semaines, reste, receptions, receptionsRestantes, rang, taille, billets = null, staff = null }) {
  const { force, regle, annuel, modele } = regleDe(forces, clubId), division = force.division, masseAnnuelle = Math.round(masseHebdo * 52);
  const prime = primeClassement(division, rang, taille), reels = Number.isFinite(billets?.abonnementsHebdo) && Number.isFinite(billets?.attendu);
  const fixes = (modele * (regle.partenaires + regle.ligue * (1 - PART_PRIME) + regle.divers + (reels ? 0 : regle.billetterie * PART_ABONNEMENTS)) + (Number.isFinite(compte.aideRelegation) ? compte.aideRelegation : 0)) / semaines + (reels ? billets.abonnementsHebdo : 0);
  const guichetMatch = (reels ? billets.attendu : modele * regle.billetterie * (1 - PART_ABONNEMENTS) / Math.max(1, receptions)) + modele * regle.boutique / Math.max(1, receptions);
  const recettesPrevues = rond(compte.recettes + fixes * reste + guichetMatch * receptionsRestantes + prime);
  const ecartStaff = staff && Number.isFinite(staff.annuel) && Number.isFinite(staff.reference) ? (staff.annuel - staff.reference) * (1 + COTISATIONS) : 0;
  const fonctionnement = fonctionnementAnnuel(annuel) + ajustement(annuel, masseHebdo * 52, compte.enveloppe) + (Number.isFinite(compte.investissement) ? compte.investissement : 0) + ecartStaff;
  const chargesPrevues = rond(compte.charges + (masseHebdo * 52 / semaines * (1 + COTISATIONS) + fonctionnement / semaines) * reste);
  // Transferts, primes de signature, travaux : tout ce qui a bougé la caisse hors du budget courant.
  const rembourse = Number.isFinite(compte.rembourse) ? compte.rembourse : 0, aRembourser = Math.max(0, (Number.isFinite(compte.remboursement) ? compte.remboursement : 0) - rembourse);
  const horsBudget = rond(tresorerie - compte.depart - (compte.recettes - compte.charges) + rembourse);
  const ligue = regles({ division, masseAnnuelle, recettes: recettesPrevues });
  const resultatPrevu = rond(recettesPrevues - chargesPrevues + horsBudget - ligue.amende);
  const apportPrevu = apportProprietaire(compte, Math.max(0, -resultatPrevu), compte.depart + resultatPrevu).apport;
  const alertes = [];
  if (ligue.depassementPlafond > 0) alertes.push({ cle: 'plafond', message: `La ligue t’a écrit : la masse salariale (${euros(masseAnnuelle)} par an) dépasse le plafond de ${euros(ligue.plafond)}. Sans départs avant la dernière journée, le club paiera une amende.` });
  if (ligue.depassementRecettes > 0) alertes.push({ cle: 'recettes', message: `Le contrôleur de gestion de la ligue t’alerte : les salaires des joueurs (${euros(masseAnnuelle)} par an) dépassent 52 % des recettes attendues (${euros(ligue.limiteRecettes)}). Sans correction avant la dernière journée, le club sera sanctionné.` });
  if (apportProprietaire(compte, Math.max(0, -resultatPrevu), compte.depart + resultatPrevu).decouvert > annuel * TOLERANCE_DEFICIT) alertes.push({ cle: 'deficit', message: compte.enveloppe > 0
    ? `Le directeur financier tire la sonnette d’alarme : à ce rythme, la saison se terminera sur une perte de ${euros(resultatPrevu)}, bien plus que les ${euros(compte.enveloppe)} promis par le propriétaire.`
    : `Le trésorier tire la sonnette d’alarme : à ce rythme, la saison se terminera sur une perte de ${euros(resultatPrevu)}, et personne ne la comblera.` });
  return { alertes, prevision: {
    recettesPrevues, chargesPrevues, horsBudget, resultatPrevu,
    recettesEncaissees: rond(compte.recettes), chargesPayees: rond(compte.charges),
    primeClassementPrevue: prime, rang,
    proprietaire: { type: compte.type, libelle: PROPRIETAIRES[compte.type].libelle, enveloppe: compte.enveloppe }, apportPrevu: rond(apportPrevu),
    masseSalariale: masseAnnuelle, plafondSalarial: ligue.plafond, limiteRecettes: ligue.limiteRecettes, margePlafond: ligue.margePlafond, margeRecettes: ligue.margeRecettes, amendePrevue: ligue.amende,
    tresorerie: rond(tresorerie), tresoreriePrevue: rond(compte.depart + resultatPrevu + apportPrevu - rembourse - aRembourser), remboursementPret: rond(aRembourser + rembourse),
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
    if (joue) { confiance -= 6; messages.push(`La ligue sanctionne le club : ${euros(ligue.amende)} d’amende pour ${motif}. Tes dirigeants n’apprécient pas de voir le club épinglé.`); }
  }
  // Les remboursements du prêt de l'actionnaire (club-owner.cjs) sortent de la caisse sans être une perte.
  const resultat = rond(tresorerie + prime - ligue.amende - compte.depart + (Number.isFinite(compte.rembourse) ? compte.rembourse : 0)), deficit = Math.max(0, -resultat);
  // Le propriétaire ne comble que ce qui ferait passer la caisse sous la réserve du club.
  const { apport, decouvert, absorbe } = apportProprietaire(compte, deficit, tresorerie + prime - ligue.amende);
  if (apport > 0) ecritures.push({ title: 'Apport du propriétaire', amount: apport });
  if (joue) {
    const grave = decouvert > recettesSaison * TOLERANCE_DEFICIT;
    if (apport > 0 && !grave) messages.push(compte.type === 'mecene' ? `Le président a signé le chèque : ${euros(apport)} pour combler les pertes de la saison, comme promis.` : `Le groupe actionnaire a comblé les pertes de la saison : ${euros(apport)}, dans la limite annoncée.`);
    if (grave) {
      confiance -= Math.min(15, 5 + Math.round(decouvert / recettesSaison * 100));
      messages.push(compte.type === 'association'
        ? `Le club termine la saison avec ${euros(deficit)} de pertes et personne pour les combler. Le bureau de l’association t’en tient pour responsable.`
        : `Les pertes de la saison (${euros(deficit)}) dépassent de ${euros(decouvert)} ce que le propriétaire avait promis. Il a versé ${euros(apport)} et te l’a fait savoir : sa confiance en a pris un coup.`);
    } else if (deficit > 0 && absorbe > 0 && apport === 0) messages.push(`La saison se termine sur ${euros(deficit)} de pertes, prises sur la réserve du club : le propriétaire n’a rien eu à verser, la caisse reste au-dessus de ce qu’il exige.`);
    else if (deficit === 0) messages.push(`Le club termine la saison dans le vert : ${euros(resultat)} de mieux en caisse qu’au départ. Le propriétaire n’a rien eu à verser.`);
  }
  return { ecritures, messages, confiance, prime, amende: ligue.amende, resultat, apport, decouvert: rond(decouvert) };
}

// Leviers de redressement (reprise de l'étude économie V2, PR #352/#353) : ce que le manager peut
// réellement changer d'ici la fin de saison, et ce que chaque choix rapporte à la prévision. Purement
// consultatif : rien n'est débité, et rien n'est inventé — ni prêt, ni recette nouvelle, ni pénalité.
//   solde : marge prévue en fin de saison (négative = manque) ; objectif : 'tresorerie' (la caisse
//     doit rester positive) ou 'proprietaire' (les pertes ne doivent pas dépasser ce qu'il comble) ;
//   reste : semaines restantes ; formationHebdo : formation payée chaque semaine ; devis : prochaines
//     installations (null sans devis) ; masseHebdo : salaires des joueurs par semaine ;
//   coutSalaire : ce que coûte, sur une semaine restante, 1 € de salaire hebdomadaire (cotisations et
//     paie sur 52 semaines comprises) ; amende, depassement : amende de la ligue encourue et
//     dépassement annuel de la masse salariale qui la provoque.
const PART_MASSE_GRAVE = 0.25; // au-delà d'un quart des salaires à libérer, la saison ne se sauve plus
function leviers({ solde, objectif = 'tresorerie', reste, formationHebdo = 0, devis = null, masseHebdo = 0, coutSalaire = 1, amende = 0, depassement = 0 }) {
  if (![solde, reste, formationHebdo, masseHebdo, coutSalaire, amende, depassement].every(Number.isFinite) || reste < 0 || coutSalaire <= 0 || !['tresorerie', 'proprietaire'].includes(objectif)) throw Error('Leviers de redressement : entrées invalides.');
  const manque = rond(Math.max(0, -solde)), liste = [];
  let restant = manque;
  if (amende > 0) {
    liste.push({ cle: 'amende', titre: `Repasser sous la limite salariale de la ligue : ${euros(depassement)} de masse annuelle en moins`, effet: rond(amende),
      contrepartie: 'Un ou plusieurs départs avant la dernière journée ; l’amende tombe entièrement.' });
    restant = Math.max(0, restant - amende);
  }
  if (manque > 0 && formationHebdo > 0 && reste > 0) {
    const effet = rond(formationHebdo * reste);
    liste.push({ cle: 'formation', titre: `Suspendre la formation payée (${euros(formationHebdo)} par semaine)`, effet, commande: { command: 'club_academy_investment', amount: 0 },
      contrepartie: 'Les jeunes du centre progressent moins vite jusqu’à la reprise de l’investissement.' });
    restant = Math.max(0, restant - effet);
  }
  const travaux = Number.isFinite(devis) && devis > 0 && solde - devis < 0;
  if (travaux) liste.push({ cle: 'installations', titre: `Différer les travaux d’installations (${euros(devis)})`, effet: 0, risque: rond(devis),
    contrepartie: 'La prévision ne les compte pas : les engager maintenant creuserait d’autant le résultat de la saison.' });
  let salaires = 0;
  if (restant > 0 && reste > 0) {
    salaires = Math.ceil(restant / (reste * coutSalaire) / 100) * 100;
    liste.push({ cle: 'salaires', titre: `Libérer environ ${euros(salaires)} de salaires par semaine`, effet: rond(restant),
      contrepartie: 'Vente, prêt ou fin de contrat négociée : un effectif plus court pour finir la saison.' });
  }
  const etat = manque === 0 ? (travaux ? 'vigilance' : 'serein') : reste === 0 ? 'tard' : restant === 0 ? 'facultatif' : salaires > masseHebdo * PART_MASSE_GRAVE ? 'grave' : 'effectif';
  const cible = objectif === 'proprietaire' ? 'les pertes dépasseront de ' + euros(manque) + ' ce que le propriétaire comblera' : 'la caisse finira la saison à ' + euros(manque) + ' sous zéro';
  const conclusion = {
    serein: 'La saison est financée : aucun levier n’est nécessaire.',
    vigilance: 'La saison est financée, mais les travaux d’installations la feraient basculer dans le rouge.',
    facultatif: `À ce rythme, ${cible}. Renoncer aux dépenses facultatives suffit à redresser la barre.`,
    effectif: `À ce rythme, ${cible}. Les dépenses facultatives ne suffisent pas : il faudra alléger la masse salariale.`,
    grave: `À ce rythme, ${cible}. Il faudrait libérer plus d’un quart des salaires : la saison se terminera probablement sur une perte que le propriétaire te reprochera.`,
    tard: `La saison s’achève : ${cible}. Il est trop tard pour la redresser ; la prochaine se prépare dès l’intersaison.`,
  }[etat];
  return { etat, objectif, manque, solde: rond(solde), salairesALiberer: salaires, leviers: liste, conclusion };
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
// Mémoires du budget (budget…Memo) : de simples raccourcis. Une valeur retrouvée doit être celle qu'un calcul frais
// donnerait à cet instant, sinon les comptes dérivent pendant la partie et une sauvegarde rechargée (mémoires vides) ne
// redonne pas la même suite (règle de Léo du 24/11/2026 : couper le jeu ne relance pas les dés). Leur clé porte donc
// toutes leurs entrées. Vérification (tests/budget-rechargement.cjs) : budgetMemoVerifier=n recalcule une valeur retrouvée sur n
// et note tout écart dans budgetMemoEcarts.
// budgetMemoVerifier : nombre de valeurs retrouvées entre deux vérifications de la même mémoire (1 : toutes), false : aucune.
let budgetMemoVerifier=false;const budgetMemoEcarts=[],budgetMemoRetrouvees=new Map();
const budgetMemoTexte=x=>JSON.stringify(x,(k,v)=>v instanceof Map?{map:[...v]}:v);
function budgetMemoRetrouve(nom,valeur,calcul){
 if(budgetMemoVerifier){const n=(budgetMemoRetrouvees.get(nom)||0)+1;budgetMemoRetrouvees.set(nom,n);if((n-1)%budgetMemoVerifier)return valeur;const frais=calcul();if(budgetMemoTexte(frais)!==budgetMemoTexte(valeur)&&budgetMemoEcarts.length<200)budgetMemoEcarts.push({nom,saison:S.season,semaine:S.worldMode?.week??null});}
 return valeur;
}
const budgetLigue=id=>budgetFrance()?CDFranceCompetition.leagueId(S,id):CDWorldCareer.leagueId(S,id);
// Carrière Monde : chaque club porte la billetterie annuelle de son stade (budgetBilletterieClub), lue par ses recettes prévues.
const budgetForces=()=>budgetFrance()?CDFranceClubs.clubs.map(c=>({id:c.id,division:CDFranceCompetition.leagueId(S,c.id),base:c.base})):S.clubs.map(c=>{const b=budgetBilletterieClub(c);return Number.isFinite(b)?{id:c.id,division:CDWorldCareer.leagueId(S,c.id),base:c.base,billetterie:b}:{id:c.id,division:CDWorldCareer.leagueId(S,c.id),base:c.base};});
const budgetSemaineNo=()=>S.franceMode?S.franceMode.week:S.worldMode.week;
const budgetMasse=c=>c.players.reduce((s,p)=>s+p.salary,0);
// Source unique des masses salariales affichées (Finances, Club, Bureau) : trois mesures nommées, jamais confondues.
//   joueursHebdo : somme des salaires des contrats (base de 52 semaines, celle des tables de contrats) ;
//   verseHebdo : ce même salaire versé sur les semaines de gestion de la saison ; chargeHebdo : versé + cotisations.
const chiffresMasse=()=>{
 const joueurs=budgetMasse(club()),semaines=wageForecastWeeks(),rondCent=x=>Math.round(x/100)*100;
 if(!budgetActif())return {joueursHebdo:joueurs,verseHebdo:joueurs,chargeHebdo:joueurs,cotisationsHebdo:0,annuelle:joueurs*52,semainesDePaie:semaines,tauxCotisations:0};
 const verse=rondCent(joueurs*52/semaines),cotisations=rondCent(verse*nativeClubBudget.COTISATIONS);
 return {joueursHebdo:joueurs,verseHebdo:verse,chargeHebdo:verse+cotisations,cotisationsHebdo:cotisations,annuelle:joueurs*52,semainesDePaie:semaines,tauxCotisations:nativeClubBudget.COTISATIONS};
};
// Échéances de contrat du club joué : fin de la saison en cours, et horizon (cette saison ou la suivante).
const chiffresContrats=()=>{
 const c=club(),fin=c.players.filter(p=>p.contractEnd===S.season),horizon=c.players.filter(p=>Number.isFinite(p.contractEnd)&&p.contractEnd<=S.season+1);
 return {saison:S.season,horizonSaison:S.season+1,effectif:c.players.length,finDeSaison:fin,horizon};
};
// Effectif du centre d'un club : celui du club joué, sinon celui que l'ordinateur gère pour lui.
const budgetCentre=c=>{const jeunes=c.id===S.club?S.development?.academy:S.aiRoster?.academies?.find(a=>a.clubId===c.id)?.players;
 if(!Array.isArray(jeunes))return null;let crabos=0,espoirs=0;for(const p of jeunes)if(p.age<=17)crabos++;else espoirs++;return {crabos,espoirs};};
const budgetCredits=()=>{const credits={};for(const c of S.clubs){const v=nativeClubBudget.creditAcademie(budgetLigue(c.id),c.players,c.id);if(v)credits[c.id]=v;}return credits;};
const budgetTypes=()=>budgetLisible(S.clubBudget)?S.clubBudget.clubs.map(c=>c.type):null;
// Demandées à chaque joueur étudié par un club géré : gardées tant que la carrière, la saison et la force des clubs ne changent pas.
let budgetLimitesMemo=null;
// Limite de masse votée avec le budget de la saison (Monde, à partir de la saison 2) : le niveau de chaque club est celui
// noté à l'ouverture du budget (budgetOuvrir, juste après la remise à niveau des contrats). Le niveau qui bouge ensuite
// (arrivée des espoirs, aiRosterPopulationYouthIntake : ±2) ne recalcule plus la limite en cours de saison : les recettes
// étant réparties selon le rang de niveau dans la ligue, 2 points suffisaient à retirer 25 à 30 % de la limite d'un club
// de Championship ou de Nationale, juste après qu'il eut été recalé dessous (mesure du 20/11/2026). Sauvegarde sans niveau
// noté : niveau actuel, comme avant.
// La billetterie du club (budgetBilletterieClub : abonnés estimés et rang de réputation) est elle aussi lue avec ce niveau
// noté : lue avec le niveau actuel, elle faisait bouger la limite en cours de saison ; seule l'ancienne mémoire (clé : somme
// des niveaux notés) la figeait, à une valeur que la partie d'une traite et une sauvegarde rechargée ne notaient pas au même
// moment (mesure du 24/11/2026 : 88 limites sur 120 différentes en saison 2, graine 2026).
const budgetForcesLimites=creation=>{
 const f=budgetForces(),b=S.clubBudget;
 if(creation===true||S.season<=1||budgetFrance()||!budgetLisible(b)||b.saison!==S.season)return f;
 return f.map(x=>{
  const v=b.clubs[x.id]?.base;if(!Number.isFinite(v))return x;
  if(x.billetterie===undefined||v===x.base)return {...x,base:v};
  const c=S.clubs[x.id]?.id===x.id?S.clubs[x.id]:S.clubs.find(y=>y.id===x.id),billetterie=c?budgetBilletterieClub({...c,base:v}):null;
  return Number.isFinite(billetterie)?{...x,base:v,billetterie}:{...x,base:v};
 });
};
const budgetLimites=creation=>{
 const remboursementsCalcul=()=>{const r={};if(typeof nativeClubOwner!=='undefined')for(const [id,p] of Object.entries(S.pretsActionnaires||{}))r[id]=nativeClubOwner.remboursementSaison(p,S.season)||Math.min(p.restant||0,p.annuite||0);return r;};
 const entrees=()=>({forces:budgetForcesLimites(creation),types:budgetTypes(),credits:budgetCredits(),remboursements:remboursementsCalcul()});
 const calcul=(x=entrees())=>nativeClubBudget.limites(x.forces,S.season,{creation:creation===true,types:x.types,credits:x.credits,remboursements:x.remboursements});
 // Clé complète : forces (division, niveau, billetterie), types de propriétaires, crédits de formation (effectifs) et
 // remboursements. L'ancienne clé (somme des niveaux) gardait la limite d'avant un départ de jeune formé ou un prêt.
 // Carrière Monde : clé « brute », relevée sans calculer la billetterie des clubs (budgetBilletterieClub, jusqu'à deux fois
 // par club et par appel : next_season passait de 10-13 s à 16-17 s, au-delà des 15 s de garde de la VM, mesure du
 // 25/11/2026). Elle porte tout ce que lisent ces forces : divisions, niveaux actuels, niveaux et divisions notés au vote
 // (niveau des limites et éventail des réputations), stades, réceptions, nom du club (abonnés estimés), puis types,
 // crédits et remboursements. Vérifiée comme les autres mémoires (budgetMemoVerifier).
 const m=budgetLimitesMemo,types=budgetTypes(),credits=budgetCredits(),remboursements=remboursementsCalcul();
 let brute=null;
 if(!budgetFrance()){
  const b=S.clubBudget,ligues=S.worldMode.leagues;
  brute=S.season+'|'+(creation===true)+'|'+S.club+'|'+(S.worldMode.fixtures?.length||0)+'|'+JSON.stringify(types)+'|'+JSON.stringify(credits)+'|'+JSON.stringify(remboursements);
  for(const k of Object.keys(ligues))brute+='|'+k+':'+ligues[k].members.join(',');
  if(budgetLisible(b)&&b.saison===S.season)for(const k of b.clubs)brute+='|v'+k.division+':'+k.base;else brute+='|sans vote';
  for(const c of S.clubs)brute+='|'+c.id+':'+c.base+':'+budgetCapacite(c)+':'+budgetReceptions(c.id)+':'+String(c.abbr??c.name??c.id);
  if(m&&m.etat===S&&m.brute===brute)return budgetMemoRetrouve('limites',m.valeur,()=>calcul());
 }
 const x={forces:budgetForcesLimites(creation),types,credits,remboursements};
 let cle=S.season+'|'+(creation===true)+'|'+S.club+'|'+JSON.stringify(x.types)+'|'+JSON.stringify(x.credits)+'|'+JSON.stringify(x.remboursements);
 for(const f of x.forces)cle+='|'+f.id+':'+f.division+':'+f.base+':'+(f.billetterie??'');
 if(m&&m.etat===S&&m.cle===cle){m.brute=brute;return budgetMemoRetrouve('limites',m.valeur,()=>calcul());}
 budgetLimitesMemo={etat:S,cle,brute,valeur:calcul(x)};
 return budgetLimitesMemo.valeur;
};
const budgetPlancherHebdo=()=>nativeStartingSalaries.plancherHebdo(S,budgetLigue(S.club));
// Classement, réceptions de saison régulière et réceptions restantes de chaque club, à l'instant présent.
// Calculé à chaque appel (un tri par division, peu coûteux) puis passé aux clubs de la semaine (worldWeeklyEconomy) :
// l'ancienne mémoire de la semaine (clé saison, semaine, matchs du manager) gardait le classement d'avant les
// résultats d'une journée sans match du manager.
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
// Staff de chaque club (carrière Monde) : membres sous contrat avec le club, hors anciens membres historiques ; le club du
// manager ne repaie pas ceux que l'emploi rémunéré (staff-employment.cjs) paie déjà. Relu à chaque appel : l'ancienne mémoire
// de la semaine (clé : nombre de membres) gardait un membre parti ou oubliait une recrue arrivée en échange.
// Identifiants des membres du club du manager payés par Staff par service (projection services[].enPlus), sinon vide.
function budgetStaffPostesEnPlus(){
 try{const d=typeof nativeSystems!=='undefined'?nativeSystems.domain('staffServices'):null,v=d&&typeof d.project==='function'?d.project():null;
  return new Set((Array.isArray(v?.services)?v.services:[]).flatMap(x=>Array.isArray(x?.enPlus)?x.enPlus:[]));}catch(e){return new Set();}
}
function budgetStaff(c){
 if(budgetFrance()||!Array.isArray(S.staffCareer?.people))return null;
 let gens=[];for(const p of S.staffCareer.people.flat())if(p&&p.historical!==true&&p.clubId===c.id)gens.push(p);
 if(!gens.length)return null;
 if(c.id===S.club&&Array.isArray(S.staffEmployment?.contracts)){const payes=new Set(S.staffEmployment.contracts.filter(k=>k&&k.clubId===c.id&&k.endSeason>=S.season).map(k=>k.staffId));if(payes.size)gens=gens.filter(p=>!payes.has(p.id));}
 // Staff par service (PR #1192, postes en plus) : les membres tenant un poste en plus y sont payés au forfait du service
 // (« Salaires du staff · postes en plus ») ; ils ne sont pas payés une seconde fois ici. Lu sur sa projection publique.
 if(c.id===S.club&&S.staffServices){const ids=budgetStaffPostesEnPlus();if(ids.size)gens=gens.filter(p=>!ids.has(p.id));}
 const r=nativeClubBudget.masseStaff(gens,budgetLigue(c.id),Number.isFinite(S.clubBudget?.clubs?.[c.id]?.base)?S.clubBudget.clubs[c.id].base:c.base);
 return r.membres?{annuel:r.annuel,reference:r.reference}:null;
}
// Billetterie réelle (carrière Monde) : prix du billet (division et politique du club ; les clubs gérés restent à la politique
// équilibrée), abonnés (ceux du club du manager, sinon l'estimation par la capacité et le rang), capacité réelle du stade.
// Réceptions de saison régulière d'un club cette saison (calendrier), recomptées quand le calendrier change.
let budgetReceptionsMemo=null;
const budgetReceptionsCompte=()=>{const n=new Map();for(const f of S.worldMode?.fixtures||[]){if(f.phase!=='league'||f.neutral)continue;n.set(f.homeId,(n.get(f.homeId)||0)+1);}return n;};
function budgetReceptions(id){
 const fixtures=S.worldMode?.fixtures,m=budgetReceptionsMemo,cle=S.season+'|'+(fixtures?.length||0);
 if(m&&m.etat===S&&m.fixtures===fixtures&&m.cle===cle)return budgetMemoRetrouve('receptions',m.n,budgetReceptionsCompte).get(id)||0;
 budgetReceptionsMemo={etat:S,fixtures,cle,n:budgetReceptionsCompte()};
 return budgetReceptionsMemo.n.get(id)||0;
}
// Billetterie d'une saison type du club (budget voté) : stade, abonnés estimés, billet de la division au prix équilibré ;
// null pour un club sans réception de championnat (clubs invités) : il garde la part « billetterie » du modèle.
function budgetBilletterieClub(c){
 const division=CDWorldCareer.leagueId(S,c.id);if(!nativeClubBudget.DIVISIONS[division])return null;
 const receptions=budgetReceptions(c.id);if(!receptions)return null;
 const capacite=budgetCapacite(c);
 return nativeClubBudget.billetterieAnnuelle({capacite,abonnes:nativeClubBudget.abonnesEstimes(capacite,c.base,String(c.abbr??c.name??c.id)),prix:budgetPrixReference(c).base,receptions,demande:budgetDemande(c)});
}
const budgetPolitique=c=>c.id===S.club&&S.v111to116&&typeof S.v111to116.price==='string'?S.v111to116.price:'equilibree';
const budgetCapacite=c=>Number.isInteger(c.stadiumCapacity)&&c.stadiumCapacity>0?c.stadiumCapacity:typeof CDWorldStadiumCapacities!=='undefined'&&Number.isInteger(CDWorldStadiumCapacities[c.id])?CDWorldStadiumCapacities[c.id]:12000;
const budgetAccueil=id=>typeof investAccueil==='function'?nativeClubInvestments.facteurAccueil(investAccueil(id)):1;
// Prix de la saison du club du manager (choix de Léo du 23/11/2026) : S.billetterie = {version:1, saison, base, abonnement,
// affiche, delegue}. Trois prix fixés pour la saison : billet de base, abonnement saison, billet des grosses affiches (derby,
// club plus fort, phase finale) ; null = prix de la division (préréglage de la politique de prix pour le billet). delegue : les
// trois prix sont confiés au responsable de la billetterie (budgetResponsable), qui applique ses conseils.
const budgetBilletterieEtat=()=>{const b=S.billetterie;return b&&b.version===1?b:null;};
// Prix de référence de la division : billet, abonnement (billet × 70 % × réceptions), grosse affiche (billet × 1,5).
// Prix « juste » de chaque club (précision de Léo du 23/11/2026) : celui de sa division, surtout ajusté à sa réputation (rang de
// sa base dans la division, 0 à 1, budgetReputation : prix × 0,75 pour le plus modeste à × 1,3 pour le plus réputé). L'affluence réagit au prix autour de
// cette référence, le conseil du staff tend vers elle ; elle n'est jamais affichée.
// Éventail de la division : niveaux notés avec le budget de la saison (budgetOuvrir, S.clubBudget.clubs[].base et division),
// donc le même toute la saison et relu tel quel dans une sauvegarde. Le niveau du club, lui, est l'actuel. Sans budget de la
// saison (création, bascule), niveaux actuels. L'ancienne mémoire de saison gardait l'éventail du premier appel, que la
// partie d'une traite et une sauvegarde rechargée ne notaient pas au même moment (affluences et recettes divergentes).
let budgetReputationMemo=null;
function budgetEventailCalcul(b){
 if(budgetFrance()||!budgetLisible(b)||b.saison!==S.season||!b.clubs.every(k=>Number.isFinite(k.base)))return null;
 const parDivision=new Map();
 for(const k of b.clubs){const e=parDivision.get(k.division);if(e){e[0]=Math.min(e[0],k.base);e[1]=Math.max(e[1],k.base);}else parDivision.set(k.division,[k.base,k.base]);}
 return parDivision;
}
function budgetEventailVote(){
 const b=S.clubBudget,m=budgetReputationMemo;
 if(m&&m.etat===S&&m.budget===b&&m.saison===S.season)return budgetMemoRetrouve('eventail',m.parDivision,()=>budgetEventailCalcul(b));
 const parDivision=budgetEventailCalcul(b);
 if(parDivision)budgetReputationMemo={etat:S,budget:b,saison:S.season,parDivision};
 return parDivision;
}
function budgetReputation(c){
 const d=budgetLigue(c.id),vote=budgetEventailVote()?.get(d);
 let min,max;
 if(vote)[min,max]=vote;
 else{const bases=S.clubs.filter(x=>budgetLigue(x.id)===d).map(x=>x.base).filter(Number.isFinite);[min,max]=bases.length?[Math.min(...bases),Math.max(...bases)]:[c.base,c.base];}
 return max>min?Math.max(0,Math.min(1,(c.base-min)/(max-min))):0.5;
}
// Facteur de prix d'un club : × 0,75 (le plus modeste de sa division) à × 1,3 (le plus réputé).
const budgetFacteurReputation=c=>0.75+0.55*budgetReputation(c);
// Appétit du public occasionnel : celui de la division (league-economy.cjs, public), × 0,8 à × 1,2 selon la réputation.
const budgetDemande=c=>(nativeLeagueEconomy.CHAMPIONNATS[budgetLigue(c.id)]?.public??1)*(0.8+0.4*budgetReputation(c));
function budgetPrixReference(c){
 const billet=Math.max(1,Math.round(nativeClubBudget.prixBillet(budgetLigue(c.id),'equilibree')*budgetFacteurReputation(c)));
 return {base:billet,abonnement:Math.round(billet*nativeClubBudget.REMISE_ABONNEMENT*Math.max(1,budgetReceptions(c.id))),affiche:Math.round(billet*1.5)};
}
// Membre du staff qui tient la billetterie (le club n'a pas de directeur financier) : le meilleur de l'encadrement du club
// (team manager, direction et intendance), sinon le meilleur du staff.
function budgetResponsable(c){
 const gens=(S.staffCareer?.people||[]).flat().filter(p=>p&&p.clubId===c.id&&p.historical!==true);
 if(!gens.length)return null;
 const parNiveau=(x,y)=>(y.level||0)-(x.level||0)||(x.id<y.id?-1:1),encadrement=gens.filter(p=>p.role==='support').sort(parNiveau);
 const p=encadrement[0]||gens.sort(parNiveau)[0];
 // Fiche réduite pour le portrait de l'écran (mêmes champs que l'annuaire du staff).
 const fiche=Object.fromEntries(['id','name','role','roleLabel','age','appearanceId','appearanceAge','appearanceBankVersion','portraitStatus','identityStatus','sourceKind','level'].filter(k=>p[k]!==undefined).map(k=>[k,p[k]]));
 return {id:p.id,nom:p.name,niveau:Number.isFinite(p.level)?p.level:55,fiche};
}
// Grosse affiche : phase finale, derby, ou adversaire nettement plus fort (base + 5) ou parmi les grands (base 80 et plus).
function budgetAffiche(c,f){
 if(!f)return false;
 if(f.phase&&f.phase!=='league'&&f.phase!=='pool')return true;
 const autre=f.homeId===c.id?f.awayId:f.homeId,o=S.clubs[autre];
 if(typeof isDerby==='function'&&Number.isInteger(autre)&&isDerby(S,c.id,autre))return true;
 return !!o&&Number.isFinite(o.base)&&(o.base>=80||o.base>=(c.base||0)+5);
}
// Abonnés : ceux du club (campagnes comprises) ou l'estimation par le stade et le rang, puis le prix de l'abonnement :
// moins cher, il en attire plus (élasticité 0,5), plus cher, il en perd vite (2) ; au plus 90 % des places.
function budgetAbonnes(c,capacite=budgetCapacite(c),prixAbonnement=null){
 const socle=c.id===S.club&&Number.isInteger(S.v111to116?.subscribers)?Math.min(capacite,S.v111to116.subscribers):nativeClubBudget.abonnesEstimes(capacite,c.base,String(c.abbr??c.name??c.id));
 const ref=budgetPrixReference(c).abonnement,prix=prixAbonnement??budgetPrixSaison(c).abonnement,r=prix/ref;
 const facteur=Math.max(0.4,Math.min(1.3,r<=1?r**-0.5:r**-2));
 return Math.min(Math.round(capacite*0.9),Math.round(socle*facteur));
}
// Spectateurs d'une réception (affluence du compte rendu, world-career.cjs, et billetterie) : la demande du match au prix du
// billet (grosse affiche : plus de demande, prix des grosses affiches), jamais moins que les abonnés présents, au plus la capacité.
function budgetSpectateurs(c,f,{alea=null,resultats=null,prix=null,affiche=null,abonnes=null,saison=null,humeur}={}){
 const capacite=budgetCapacite(c),grosse=affiche??budgetAffiche(c,f),ref=budgetPrixReference(c).base;saison=saison??budgetPrixSaison(c);
 const n=nativeClubBudget.spectateurs({capacite,resultats:resultats??(Array.isArray(c.form)?c.form.slice(-5):[]),cle:c.id+'|'+S.season+'|'+(f?.id??f?.fixtureId??''),phase:f?.phase||'league',
  accueil:budgetAccueil(c.id),humeur:humeur!==undefined?humeur:c.id===S.club?budgetHumeur():null,politique:(prix??(grosse?saison.affiche:saison.base))/ref,alea,affiche:grosse,abonnes:abonnes??budgetAbonnes(c,capacite,saison.abonnement),demande:budgetDemande(c)});
 return n;
}
// Spectateurs de la rencontre f (world-career.cjs, affluenceMatch).
function budgetSpectateursMatch(c,f){return budgetSpectateurs(c,f);}
// Meilleurs prix de la saison (ce que vise le conseil du staff) : billet et grosse affiche maximisent la recette au guichet
// d'un match moyen ; l'abonnement maximise la recette des abonnements.
function budgetPrixOptimaux(c){
 const ref=budgetPrixReference(c),saison=budgetPrixSaison(c,true),capacite=budgetCapacite(c);
 const humeur=c.id===S.club?budgetHumeur():null,guichet=(prix,affiche,abonnes)=>nativeClubBudget.guichet({spectateurs:budgetSpectateurs(c,null,{alea:.5,resultats:['V','D'],prix,affiche,abonnes,saison,humeur}),abonnes,prix}).recette;
 const meilleur=(min,max,pas,valeur)=>{let m=min,v=-1;for(let p=min;p<=max;p+=pas){const x=valeur(p);if(x>v){v=x;m=p;}}return m;};
 const aboActuels=budgetAbonnes(c,capacite,saison.abonnement);
 const base=meilleur(Math.max(1,Math.round(ref.base*.5)),Math.round(ref.base*2.5),1,p=>guichet(p,false,aboActuels));
 const affiche=meilleur(Math.max(1,Math.round(ref.base*.5)),Math.round(ref.base*3.5),1,p=>guichet(p,true,aboActuels));
 const pas=Math.max(1,Math.round(ref.abonnement/100));
 const abonnement=meilleur(Math.max(1,Math.round(ref.abonnement*.3)),Math.round(ref.abonnement*1.6),pas,p=>budgetAbonnes(c,capacite,p)*p);
 return {base,abonnement,affiche};
}
// Conseils du responsable de la billetterie : le meilleur prix décalé selon son niveau (±30 % au niveau 45, ±5 % au niveau 85,
// jamais exact), un tirage par saison et par prix : parfois mieux que le manager, parfois moins bien.
let budgetConseilsMemo=null;
function budgetConseils(c){
 const r=budgetResponsable(c);if(!r)return null;
 // Clé : tout ce que lisent les meilleurs prix (budgetPrixOptimaux) et le conseil. L'ancienne clé (semaine, matchs du manager)
 // gardait des conseils calculés avec l'humeur, les abonnés ou l'accueil d'un autre jour de la semaine.
 const capacite=budgetCapacite(c),cle=JSON.stringify([S.season,c.id,c.base,r,budgetBilletterieEtat(),budgetPolitique(c),budgetPrixReference(c),capacite,
  c.id===S.club?budgetHumeur():null,budgetAccueil(c.id),budgetDemande(c),c.id===S.club?S.v111to116?.subscribers??null:null]);
 const calcul=()=>{const o=budgetPrixOptimaux(c);
  return {par:{name:r.nom,level:r.niveau,person:r.fiche},base:nativeClubBudget.conseilPrix(o.base,r.niveau,S.season+'|base|'+r.id),
   abonnement:nativeClubBudget.conseilPrix(o.abonnement,r.niveau,S.season+'|abonnement|'+r.id),affiche:nativeClubBudget.conseilPrix(o.affiche,r.niveau,S.season+'|affiche|'+r.id)};};
 const m=budgetConseilsMemo;
 if(m&&m.etat===S&&m.cle===cle)return budgetMemoRetrouve('conseils',m.valeur,calcul);
 budgetConseilsMemo={etat:S,cle,valeur:calcul()};
 return budgetConseilsMemo.valeur;
}
// Prix de la saison : ceux du manager, ceux du staff si la billetterie lui est confiée, sinon ceux de la division.
// sansDelegation : prix fixés à la main (le calcul des conseils ne se lit pas lui-même).
function budgetPrixSaison(c,sansDelegation=false){
 const ref=budgetPrixReference(c),b=c.id===S.club?budgetBilletterieEtat():null,prereglage=Math.max(1,Math.round(ref.base*nativeClubBudget.POLITIQUES_BILLET[budgetPolitique(c)].prix));
 // Clubs gérés : ils fixent eux-mêmes leurs prix autour de leur référence (±8 % propres au club et à la saison).
 if(c.id!==S.club){const v=1+0.16*(nativeLeagueEconomy.unite('prix|'+c.id+'|'+S.season)-0.5),k=x=>Math.max(1,Math.round(x*v));return {base:k(ref.base),abonnement:k(ref.abonnement),affiche:k(ref.affiche)};}
 if(!b)return {base:prereglage,abonnement:ref.abonnement,affiche:ref.affiche};
 if(b.delegue===true&&!sansDelegation){const k=budgetConseils(c);if(k)return {base:k.base,abonnement:k.abonnement,affiche:k.affiche};}
 return {base:Number.isInteger(b.base)?b.base:prereglage,abonnement:Number.isInteger(b.abonnement)?b.abonnement:ref.abonnement,affiche:Number.isInteger(b.affiche)?b.affiche:ref.affiche};
}
// {prix, abonnes, spectateurs, attendu, abonnementsHebdo} ; rencontre : réception de la semaine ({affluence} lue sur le résultat).
function budgetBillets(c,rencontre,repere){
 if(budgetFrance()||!budgetReceptions(c.id))return null;
 const capacite=budgetCapacite(c),saison=budgetPrixSaison(c),abonnes=budgetAbonnes(c,capacite,saison.abonnement);
 const chez=!!rencontre&&rencontre.pair[0]===c.id&&rencontre.neutral!==true,prix=chez&&budgetAffiche(c,rencontre)?saison.affiche:saison.base;
 const spectateurs=chez?(Number.isInteger(rencontre.affluence)?rencontre.affluence:budgetSpectateurs(c,rencontre)):null;
 // Match moyen de ce club : forme neutre, tirage médian, humeur, accueil et billet de base.
 const moyen=budgetSpectateurs(c,null,{alea:.5,resultats:['V','D'],prix:saison.base,affiche:false,abonnes}),attendu=nativeClubBudget.guichet({spectateurs:moyen,abonnes,prix:saison.base}).recette;
 // Abonnements de la saison, étalés sur les semaines comme les autres recettes de la saison.
 return {prix,abonnes,spectateurs,attendu,abonnementsHebdo:Math.round(abonnes*saison.abonnement/Math.max(1,wageForecastWeeks())/100)*100};
}
// Ce que l'écran Le public montre : les trois prix de la saison, les conseils du responsable de la billetterie, et SON ESTIMATION
// du prochain match à domicile et des abonnés (règle de Léo : jamais d'effet exact avant d'agir ; estimationStaff).
function budgetBilletterieVue(){
 if(!budgetActif()||budgetFrance()||!budgetReceptions(S.club))return null;
 const c=club(),capacite=budgetCapacite(c),b=budgetBilletterieEtat(),saison=budgetPrixSaison(c),ref=budgetPrixReference(c),abonnes=budgetAbonnes(c,capacite,saison.abonnement);
 const f=(S.worldMode?.fixtures||[]).filter(x=>x.homeId===c.id&&!x.neutral&&x.week>=S.worldMode.week&&!S.history.some(r=>r.fixtureId===x.id)).sort((x,y)=>x.week-y.week)[0]||null;
 const affiche=budgetAffiche(c,f),prix=affiche?saison.affiche:saison.base,g=nativeClubBudget.guichet({spectateurs:budgetSpectateurs(c,f),abonnes,prix});
 const r=budgetResponsable(c),niveau=r?r.niveau:45,cle=(f?.id??'saison')+'|'+[saison.base,saison.abonnement,saison.affiche].join('/')+'|'+(r?.id??'')+'|'+budgetSemaineNo();
 const spectateurs=Math.min(capacite,nativeClubBudget.estimationStaff(g.spectateurs,niveau,'public|'+cle)),recette=nativeClubBudget.estimationStaff(g.recette,niveau,'recette|'+cle,100);
 const aboEstimes=Math.min(capacite,nativeClubBudget.estimationStaff(abonnes,niveau,'abonnes|'+cle));
 const conseils=budgetConseils(c),adverse=f?S.clubs[f.homeId===c.id?f.awayId:f.homeId]:null;
 // Tendance de chaque prix, autour du prix juste du club (jamais affiché) : -2 à +2 sur le public (billet, grosse affiche)
 // ou sur les abonnés (abonnement) ; aucun chiffre.
 const tendance=f=>f>=1.12?2:f>=1.03?1:f>0.97?0:f>0.88?-1:-2,rAbo=saison.abonnement/ref.abonnement;
 const trends={base:tendance(nativeClubBudget.facteurPrix(saison.base/ref.base)),affiche:tendance(nativeClubBudget.facteurPrix(saison.affiche/ref.base,true)/nativeClubBudget.facteurPrix(ref.affiche/ref.base,true)),abonnement:tendance(Math.max(0.4,Math.min(1.3,rAbo<=1?rAbo**-0.5:rAbo**-2)))};
 // Pistes des curseurs : autour du prix de la division (pas du club), pour ne rien dévoiler du prix juste.
 const div=nativeClubBudget.prixBillet(budgetLigue(c.id),'equilibree'),aboDiv=Math.round(div*nativeClubBudget.REMISE_ABONNEMENT*Math.max(1,budgetReceptions(c.id)));
 const ranges={base:{min:Math.max(1,Math.round(div*.4)),max:Math.round(div*2.5),step:1},affiche:{min:Math.max(1,Math.round(div*.6)),max:Math.round(div*4),step:1},abonnement:{min:Math.max(5,Math.round(aboDiv*.4/5)*5),max:Math.round(aboDiv*2.5/5)*5,step:5}};
 const presents=Math.min(spectateurs,Math.round(aboEstimes*nativeClubBudget.PRESENCE_ABONNES));
 return {capacity:capacite,trends,ranges,subscribersPresent:presents,ticketsSold:Math.max(0,spectateurs-presents),price:prix,prices:{base:saison.base,abonnement:saison.abonnement,affiche:saison.affiche},
  advice:conseils?{base:conseils.base,abonnement:conseils.abonnement,affiche:conseils.affiche}:null,estimatedBy:conseils?conseils.par:null,delegated:b?.delegue===true,
  expectedAttendance:spectateurs,expectedTicketRevenue:recette,expectedSubscribers:aboEstimes,demand:Math.round(100*spectateurs/capacite),
  bigMatch:affiche,fixtureId:f?.id??null,opponent:adverse?adverse.name:null,fixtureWeek:f?.week??null};
}
// Commandes du manager (club-strategy.cjs) : un des trois prix de la saison (club_ticket_price {kind, prix}) ou la billetterie
// confiée au staff (club_ticket_delegate {delegue}). Fixer un prix à la main reprend la billetterie au staff.
function budgetBilletterieCommande(command,p){
 if(!budgetActif()||budgetFrance()||!budgetReceptions(S.club))throw Error('Billetterie indisponible.');
 const b=S.billetterie=budgetBilletterieEtat()||{version:1,saison:S.season,base:null,abonnement:null,affiche:null,delegue:false};
 b.saison=S.season;
 if(command==='club_ticket_price'){
  const max=p.kind==='abonnement'?20000:500;
  if(!['base','abonnement','affiche'].includes(p.kind)||!Number.isInteger(p.prix)||p.prix<1||p.prix>max)throw Error('Prix invalide.');
  b[p.kind]=p.prix;b.delegue=false;
  // Le billet de base règle aussi l'humeur des familles (profil des tribunes) : préréglage le plus proche.
  if(p.kind==='base'&&typeof CDFanExperienceV111V116!=='undefined'){const r=p.prix/budgetPrixReference(club()).base,st=CDFanExperienceV111V116.ensure(S);if(st)st.price=r<=.8?'accessible':r>=1.25?'premium':'equilibree';}
 }else if(command==='club_ticket_delegate'){
  if(typeof p.delegue!=='boolean')throw Error('Choix invalide.');
  b.delegue=p.delegue;
 }else throw Error('Commande de billetterie inconnue.');
 return true;
}
function budgetPrevoir(forces,repere){
 const b=S.clubBudget,c=club(),semaines=wageForecastWeeks(),k=repere.classement[c.id]||b.clubs[c.id];
 const r=budgetCopie(nativeClubBudget.prevision({forces,clubId:c.id,compte:b.clubs[c.id],tresorerie:c.cash,masseHebdo:budgetMasse(c),semaines,reste:Math.max(0,semaines-b.semaines),
  receptions:repere.receptions[c.id]||12,receptionsRestantes:repere.restantes[c.id]||0,rang:k.rang,taille:k.taille,billets:budgetBillets(c,null,repere),staff:budgetStaff(c)}));
 b.prevision=r.prevision;
 for(const a of r.alertes){const derniere=b.alertes[a.cle];if(derniere===undefined||b.semaines-derniere>=10){b.alertes[a.cle]=b.semaines;news(a.message);}}
}
// Une sauvegarde retouchée ne doit pas faire tomber la semaine : des comptes illisibles sont rouverts.
const budgetLisible=b=>!!b&&b.version===1&&Number.isInteger(b.saison)&&Number.isInteger(b.semaines)&&b.semaines>=0&&!!b.alertes&&typeof b.alertes==='object'&&!Array.isArray(b.alertes)&&Array.isArray(b.clubs)&&b.clubs.length===S.clubs.length&&
 b.clubs.every(c=>!!c&&Object.hasOwn(nativeClubBudget.PROPRIETAIRES,c.type)&&[c.enveloppe,c.depart,c.recettes,c.charges,c.salaires,c.masse].every(Number.isFinite)&&c.enveloppe>=0&&
  typeof c.division==='string'&&Object.hasOwn(nativeClubBudget.DIVISIONS,c.division)&&Number.isInteger(c.taille)&&c.taille>=2&&Number.isInteger(c.rang)&&c.rang>=1&&c.rang<=c.taille);
function budgetOuvrir(annoncer,nouvelleSaison=false){
 const forces=budgetForces(),types=budgetLisible(S.clubBudget)?S.clubBudget.clubs.map(c=>c.type):null;
 // Nouvelle saison seulement : l'excédent au-dessus de la réserve est réinvesti ou remonte à l'actionnaire.
 // Aide de la ligue aux relégués (S.aidesRelegation = {id:{depuis, saison}}, posée par worldNewSeason à la descente).
 const aides={};for(const [id,a] of Object.entries(S.aidesRelegation||{})){const v=nativeClubBudget.aideRelegation(budgetLigue(Number(id)),a?.depuis,S.season-a?.saison);if(v>0)aides[id]=v;}
 S.clubBudget=budgetCopie(nativeClubBudget.ouverture({forces,saison:S.season,types,excedents:nouvelleSaison===true,aides,clubs:S.clubs.map(c=>({id:c.id,cash:c.cash,masse:budgetMasse(c)*52}))}));
 // Niveau des clubs noté avec le budget : la limite de masse de la saison en dépend (budgetForcesLimites).
 if(!budgetFrance())for(const c of S.clubs){const k=S.clubBudget.clubs[c.id];if(k)k.base=c.base;}
 // Prêt de l'actionnaire (club-owner.cjs) : remboursé au fil de la saison qui suit le prêt.
 if(typeof nativeClubOwner!=='undefined')for(const [id,p] of Object.entries(S.pretsActionnaires||{})){const k=S.clubBudget.clubs[id];if(k)k.remboursement=nativeClubOwner.remboursementSaison(p,S.season);}
 for(const c of S.clubs){
  const compte=S.clubBudget.clubs[c.id];if(!(compte.dividende>0))continue;
  if(c.id===S.club)ledgerEntryV1('Dividende versé au groupe actionnaire',-compte.dividende);else c.cash-=compte.dividende;
 }
 if(annoncer){
  const compte=S.clubBudget.clubs[S.club];news(nativeClubBudget.annonce(compte));
  if(compte.dividende>0)news(nativeClubBudget.annonceDividende(compte.dividende));
  if(compte.investissement>0)news(nativeClubBudget.annonceInvestissement(compte.investissement,compte.reserve));
  if(compte.aideRelegation>0&&S.aidesRelegation?.[S.club])news(nativeClubBudget.annonceAideRelegation(compte.aideRelegation,S.season===S.aidesRelegation[S.club].saison));
 }
 budgetPrevoir(forces,budgetRepere());
}
function budgetEtat(){if(!budgetLisible(S.clubBudget)||S.clubBudget.saison!==S.season)budgetOuvrir(false);return S.clubBudget;}
// rencontre : {pair:[domicile,extérieur], neutral, phase, id, affluence} ou null. Une poule européenne compte comme une journée ordinaire.
function budgetSemaine(forces,repere,c,rencontre,libelle){
 const b=budgetEtat(),masse=budgetMasse(c),billets=budgetBillets(c,rencontre,repere);
 const ecritures=budgetCopie(nativeClubBudget.semaine({forces,clubId:c.id,masseHebdo:masse,semaines:wageForecastWeeks(),receptions:repere.receptions[c.id]||12,
  domicile:!!rencontre&&rencontre.pair[0]===c.id,neutre:!!rencontre&&rencontre.neutral===true,phase:!rencontre||rencontre.phase==='pool'?'league':rencontre.phase,resultats:c.form.slice(-5),
  // Même train de vie pour le club joué que pour les clubs gérés (décision de Léo du 12 novembre) :
  // l'excédent de l'exercice est réinvesti à 70 % dans le staff et le fonctionnement, un déficit
  // au-delà de l'enveloppe du propriétaire est réduit par des économies.
  repere:S.season+'|'+budgetSemaineNo(),gere:true,libelle,formation:budgetCentre(c),investissement:b.clubs[c.id].investissement||0,aideRelegation:b.clubs[c.id].aideRelegation||0,remboursement:b.clubs[c.id].remboursement||0,
  // Clubs gérés d'un championnat encadré : l'excédent que vise leur budget n'est pas dépensé (le club joué fait ses propres choix).
  marge:c.id===S.club?0:Math.max(0,nativeClubBudget.cibleGestion(forces,c.id,b.clubs[c.id].type)),
  // Accueil du stade relevé par les investissements des excédents (club-investments.cjs).
  accueil:typeof investAccueil==='function'?nativeClubInvestments.facteurAccueil(investAccueil(c.id)):1,
  // Humeur des supporters du club du manager (club-strategy.cjs) : public payant de ses réceptions.
  humeur:c.id===S.club?budgetHumeur():null,
  // Billetterie réelle (spectateurs × prix) et salaires du staff (choix de Léo du 23/11/2026), carrière Monde.
  billets,staff:budgetStaff(c)}));
 // Mode Monde : les recettes de guichet imprévues (série de victoires, phase finale) coûtent aussi des primes et des frais.
 if(!budgetFrance()){
  const compte=b.clubs[c.id],accueil=typeof investAccueil==='function'?nativeClubInvestments.facteurAccueil(investAccueil(c.id)):1;
  const frais=nativeClubBudget.fraisDeMatch(compte,nativeClubBudget.recettesImprevues(ecritures,{forces,clubId:c.id,receptions:repere.receptions[c.id]||12,accueil,billets}),
   nativeClubBudget.deficitPrevu(forces,c.id,masse*52));
  compte.imprevu=frais.imprevu;compte.fraisMatch=frais.fraisMatch;
  if(frais.montant>0)ecritures.push({title:libelle+' · '+nativeClubBudget.LIBELLE_FRAIS_MATCH,amount:-frais.montant});
 }
 nativeClubBudget.compter(b.clubs[c.id],ecritures,masse*52,repere.classement[c.id]||null);
 if(typeof pretRembourser==='function')for(const e of ecritures)if(e.title.endsWith(nativeClubBudget.LIBELLE_REMBOURSEMENT))pretRembourser(c.id,-e.amount);
 return ecritures;
}
// Humeur des supporters du club du manager (0-100) ou null (domaine clubStrategy absent, club non géré).
function budgetHumeur(){try{const d=typeof nativeSystems!=='undefined'?nativeSystems.domain('clubStrategy'):null;return d&&typeof d.humeur==='function'?d.humeur():null;}catch(e){return null;}}
financeWeek=function(m,won){
 if(!budgetActif())return financeWeekV1(m,won);
 const forces=budgetForces(),repere=budgetRepere(),f=budgetFrance()?CDFranceCompetition.userFixture(S):CDWorldCareer.userFixture(S);
 const joue=f&&!budgetFrance()?S.history.find(r=>r.fixtureId===f.id):null;
 const ecritures=budgetSemaine(forces,repere,club(),f?{pair:f.pair||[f.homeId,f.awayId],neutral:f.neutral,phase:f.phase,id:f.id,affluence:joue?.affluence}:null,label());
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
// Historique de trésorerie : un relevé du solde du club à chaque semaine jouée (date du calendrier), gardé 70 semaines.
// L'écran Finances en tire le solde de fin de mois ; rien n'est reconstitué avant le premier relevé.
function soldeReleve(){
 try{
  const date=typeof CDWorldCareer!=='undefined'&&S.worldMode?CDWorldCareer.calendarToday(S):null;
  if(!date||!Number.isFinite(club().cash))return;
  const h=S.cashHistory=Array.isArray(S.cashHistory)?S.cashHistory:[],cash=Math.round(club().cash),dernier=h[h.length-1];
  if(dernier&&dernier.date===date)dernier.cash=cash;else h.push({date,saison:S.season,cash});
  if(h.length>70)h.splice(0,h.length-70);
 }catch(e){}
}
// Relevé hebdomadaire du groupe : moral du vestiaire et condition moyenne de l'effectif à chaque semaine jouée
// (même cadence que la trésorerie), gardé 70 semaines ; la mini-courbe au survol de ces chiffres en est tirée.
function groupeReleve(){
 try{
  const date=typeof CDWorldCareer!=='undefined'&&S.worldMode?CDWorldCareer.calendarToday(S):null;
  const joueurs=club()?.players||[];
  if(!date||!Number.isFinite(S.morale)||!joueurs.length)return;
  const condition=Math.round(joueurs.reduce((n,p)=>n+(Number.isFinite(p.condition)?p.condition:0),0)/joueurs.length);
  const h=S.groupHistory=Array.isArray(S.groupHistory)?S.groupHistory:[],dernier=h[h.length-1],releve={date,saison:S.season,morale:Math.round(S.morale),condition};
  // Confiance des joueurs envers le manager (relationships.cjs, groupTrust), même relevé : sa courbe se lit ici aussi.
  const rel=typeof nativeSystems!=='undefined'?nativeSystems.domain('relationships'):null,confiance=rel&&typeof rel.groupTrust==='function'?rel.groupTrust(S):null;
  if(Number.isInteger(confiance))releve.confiance=confiance;
  if(dernier&&dernier.date===date)Object.assign(dernier,releve);else h.push(releve);
  if(h.length>70)h.splice(0,h.length-70);
 }catch(e){}
}
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
  // Propriétaire prêteur (club-owner.cjs) : l'apport devient un prêt, remboursé les saisons suivantes.
  if(r.apport>0&&typeof pretAccorder==='function')pretAccorder(c.id,compte,r.apport,b.saison);
  // Santé financière (club-finance-health.cjs) : résultat de la saison avant l'apport du propriétaire.
  if(typeof santeHistoriser==='function')santeHistoriser(c.id,r.resultat,b.saison);
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
// Aide de la ligue aux relégués : posée à la descente (division des comptes de la saison passée → division de la
// compétition), retirée quand le club quitte la division ou que l'aide est épuisée. S.aidesRelegation = {id:{depuis, saison}}.
function budgetPoserAidesRelegation(){
 if(!budgetLisible(S.clubBudget))return;
 const aides=S.aidesRelegation=S.aidesRelegation&&typeof S.aidesRelegation==='object'&&!Array.isArray(S.aidesRelegation)?S.aidesRelegation:{};
 for(const c of S.clubs){const avant=S.clubBudget.clubs[c.id].division,apres=budgetLigue(c.id);
  if(avant!==apres&&nativeClubBudget.aideRelegation(apres,avant,0)>0)aides[c.id]={depuis:avant,saison:S.season};
  else if(aides[c.id]&&nativeClubBudget.aideRelegation(apres,aides[c.id].depuis,S.season-aides[c.id].saison)<=0)delete aides[c.id];}
}
worldNewSeason=function(fundingAlreadyPaid){
 if(!budgetActif())return worldNewSeasonV1(fundingAlreadyPaid);
 const actif=worldActive();
 if(actif){
  const w=S.worldManagement;w.champion=null;w.lastFinance=null;
  for(const c of S.clubs){
   if(c.id===S.club)continue;
   const info=worldClub(c.id);
   if(c.cash<0){info.debt+=-c.cash;c.cash=0}
   // Le prêt de l'actionnaire (club-owner.cjs) a son propre échéancier, sans intérêts : seule la dette de crise passe ici.
   const pret=typeof pretRestant==='function'?Math.min(info.debt,pretRestant(c.id)):0,crise=info.debt-pret;
   const outcome=CDFinancialRecovery.annual({cash:c.cash,debt:crise,wageRoom:100000},{revenue:0,baseCosts:0,repayment:Math.min(250000,crise)});
   c.cash=outcome.cash;info.debt=outcome.debt+pret;
   if(info.facilities<7&&info.debt===0&&c.cash>4500000&&w.yearbook.at(-1)?.standings.find(x=>x.id===c.id)?.position<=7){
    const quote=worldFacilityQuote(c.id);
    if(quote?.affordable){c.cash-=quote.cost;info.facilities++;w.upgrades.push({season:S.season,id:c.id,level:info.facilities,cost:quote.cost});}
   }
  }
  w.upgrades=w.upgrades.slice(-30);
 }
 // Montées et descentes : la division de la saison passée est dans les comptes, la nouvelle dans la compétition.
 const mouvements=new Map(),E=nativeLeagueEconomy.CHAMPIONNATS;
 if(budgetLisible(S.clubBudget))for(const c of S.clubs){const avant=S.clubBudget.clubs[c.id].division,apres=budgetLigue(c.id);if(avant!==apres&&E[avant]&&E[apres]&&E[avant].reputation!==E[apres].reputation)mouvements.set(c.id,E[apres].reputation>E[avant].reputation?1:-1);}
 budgetPoserAidesRelegation();
 // Mécènes qui arrivent et qui partent (club-owner.cjs) : avant le recalage, qui suit le nouveau propriétaire.
 if(typeof proprietairesChanger==='function')proprietairesChanger();
 // Les clubs gérés remettent leurs contrats au niveau du marché, dans la limite de ce qu'ils s'autorisent.
 // Un club sous son effectif visé garde la place de ses recrues : sa masse recalée ne prend que la part
 // de sa limite qui correspond aux joueurs déjà sous contrat (sinon le recalage remplit toute la limite
 // et l'empêche de remplacer ses départs).
 const limitesRecalage=new Map();
 for(const [id,l] of budgetLimites(false)){
  const c=S.clubs.find(x=>x.id===id),cible=c&&id!==S.club&&typeof aiRosterTarget==='function'?aiRosterTarget(c):0;
  limitesRecalage.set(id,cible>c?.players.length?{...l,limite:Math.round(l.limite*c.players.length/cible)}:l);
 }
 nativeStartingSalaries.recaler(S,budgetForces(),nativeLeagueEconomy,{saufClub:S.club,mouvements,limites:limitesRecalage});
 const sens=mouvements.get(S.club)||0;
 if(sens){const r=nativeStartingSalaries.clauses(S,S.club,sens);if(r.touches)news(nativeClubBudget.annonceClauses(sens,r.avant,r.apres,r.touches));}
 budgetOuvrir(true,true);
 return actif;
};
// Forces des clubs pour les demandes salariales : une projection en interroge des centaines d'affilée (marché, contrats).
// Même tableau tant que la carrière, les divisions et les forces des clubs sont inchangées (lu seulement par demande()).
let budgetForcesDemandeMemo=null;
// Pendant une projection (worker.cjs, nativeProjectionActive : numéro de la projection en cours), la carrière n'est pas
// modifiée : la clé vérifiée une fois vaut pour toute la projection.
const budgetForcesDemande=()=>{
 if(budgetFrance())return budgetForces();
 const projection=typeof nativeProjectionActive==='function'?nativeProjectionActive():0,m=budgetForcesDemandeMemo;
 if(projection&&m&&m.etat===S&&m.projection===projection)return budgetMemoRetrouve('forcesDemande',m.forces,budgetForces);
 // Clé : divisions, niveaux et stades des clubs, saison, budget voté (éventail des réputations) et calendrier (réceptions) :
 // tout ce que lit la billetterie de chaque club (budgetBilletterieClub).
 const ligues=S.worldMode.leagues,fixtures=S.worldMode.fixtures;let cle=S.season+'|'+(fixtures?.length||0)+'|'+S.clubs.length;
 for(const k of Object.keys(ligues))cle+='|'+k+':'+ligues[k].members.join(',');
 for(const c of S.clubs)cle+='|'+c.id+':'+c.base+':'+budgetCapacite(c);
 if(m&&m.etat===S&&m.cle===cle&&m.budget===S.clubBudget&&m.fixtures===fixtures){m.projection=projection;return budgetMemoRetrouve('forcesDemande',m.forces,budgetForces);}
 budgetForcesDemandeMemo={etat:S,cle,budget:S.clubBudget,fixtures,forces:budgetForces(),projection};return budgetForcesDemandeMemo.forces;
};
// Salaire demandé au club joué : même règle que les salaires de départ, puis l'attrait du championnat pour une recrue.
salaryDemandBreakdown=function(p,kind='renew',s=S){
 const r=salaryDemandBreakdownV1(p,kind,s);
 if(s!==S||!budgetActif()||!p||typeof p.id!=='string')return r;
 const juste=nativeStartingSalaries.demande(S,budgetForcesDemande(),S.club,p,nativeLeagueEconomy);
 if(kind==='renew'){const base=Math.max(p.salary,juste);return {...r,base,asked:Math.max(p.salary,Math.round(base*(1+(r.modifier||0))/10)*10)};}
 const parNom=nom=>{const c=S.clubs.find(x=>x.name===nom);return c?budgetLigue(c.id):null;};
 const a=nativeLeagueEconomy.attrait({origine:nativeLeagueEconomy.origine(p,id=>S.clubs[id]?budgetLigue(id):null,parNom),destination:budgetLigue(S.club),joueurId:p.id,age:p.age,situation:nativeLeagueEconomy.situation(p,S.season,S.club,club().name)});
 return {...r,base:juste,asked:Math.max(10,Math.round(juste*a.multiplicateur/10)*10)};
};
// Plancher des offres de contrat : le moteur refuse tout salaire sous 1 000 € par semaine. Pour les
// carrières marquées, la même fonction est reprise avec le plancher de la règle des salaires.
// Si le texte attendu n'y est plus, l'ancien plancher reste en place (un test le signale).
const budgetReprise=(fonction,ancien,nouveau)=>{const source=fonction.toString();return source.split(ancien).length===2?(0,eval)('('+source.replace(ancien,nouveau)+')'):null;};
const negotiateContractV1=negotiateContract,negotiateContractV2=budgetReprise(negotiateContract,'wage<1000','wage<budgetPlancherHebdo()');
negotiateContract=function(id,kind,wage,years){return budgetActif()&&negotiateContractV2?negotiateContractV2(id,kind,wage,years):negotiateContractV1(id,kind,wage,years);};
const counterofferQuoteV1=counterofferQuote,counterofferQuoteV2=budgetReprise(counterofferQuote,'wage<1000','wage<budgetPlancherHebdo()');
counterofferQuote=function(s,request,horizon,priorityIndex){return s===S&&budgetActif()&&counterofferQuoteV2?counterofferQuoteV2(s,request,horizon,priorityIndex):counterofferQuoteV1(s,request,horizon,priorityIndex);};
// Clubs gérés : ce qu'ils s'autorisent en salaires suit les règles de la ligue et leurs moyens,
// plus l'ancienne fourchette fixe ; un joueur sans club vaut le salaire de son niveau.
const aiRosterWageLimitV1=aiRosterWageLimit,aiRosterPoolEntryV1=aiRosterPoolEntry,aiRosterSmallClubPlayerV1=aiRosterSmallClubPlayer;
aiRosterWageLimit=function(c){
 if(!budgetActif())return aiRosterWageLimitV1(c);
 const l=budgetLimites(S.season===1).get(c.id);
 return l?Math.round(l.limite/52):aiRosterWageLimitV1(c);
};
// Plafond de la ligue d'un club géré (crédit de formation compris, comme sa limite) et plancher de contrat :
// les arrivées, renouvellements et retours de prêt s'y arrêtent avant que la retenue forcée ne serve.
const budgetPlafondAnnuel=c=>{const l=budgetLigue(c.id),p=nativeClubBudget.PLAFOND_SALARIAL[l];return p?p+nativeClubBudget.creditAcademie(l,c.players,c.id):null;};
const aiRosterLeagueCapV1=aiRosterLeagueCap,aiRosterFloorWageV1=aiRosterFloorWage;
aiRosterLeagueCap=function(c){const p=budgetActif()&&c.id!==S.club?budgetPlafondAnnuel(c):null;return p?Math.floor(p/52):aiRosterLeagueCapV1(c);};
aiRosterFloorWage=function(c){return budgetActif()?nativeStartingSalaries.plancherHebdo(S,budgetLigue(c.id)):aiRosterFloorWageV1(c);};
// Arrivée chez un club géré (urgence : poste non couvert, espoir promu faute de titulaire ; ou promotion au mérite) : sans plafond de ligue,
// elle passait à n'importe quel salaire (aiRosterFitWage : « l'urgence passe comme avant »). À la bascule, un club dont la
// moitié du groupe s'achève (contrats de départ de 3 ans, caisse trop basse pour prolonger) promouvait ses espoirs à 2 000 €
// par semaine, après la remise à niveau des contrats : 7 clubs de Championship et de Nationale finissaient 5 à 80 % au-dessus de
// leur limite (mesure du 20/11/2026). Le contrat d'urgence se signe au plus à ce qui reste sous la limite du club, jamais sous le plancher.
const aiRosterFitWageV1=aiRosterFitWage;
aiRosterFitWage=function(c,p,urgent=false){
 const ok=aiRosterFitWageV1(c,p,urgent);
 if(!ok||!budgetActif()||c.id===S.club||!p||!Number.isFinite(p.salary))return ok;
 // Le club garde de quoi remplir son groupe minimal au plancher (effectif minimal de 40, professional-depth) : sans cela, les
 // premiers espoirs promus épuisaient la limite et les 20 à 30 joueurs de complément qui suivaient la dépassaient.
 const dedans=c.players.some(q=>q.id===p.id),plancher=aiRosterFloorWage(c),minimum=typeof nativeProfessionalDepth!=='undefined'?nativeProfessionalDepth.minimum:0;
 const payroll=aiRosterPayroll(c)-(dedans?p.salary:0),aRemplir=Math.max(0,minimum-c.players.length-(dedans?0:1)),reste=aiRosterWageLimit(c)-payroll-aRemplir*plancher;
 if(p.salary<=reste)return ok;
 // Hors urgence (promotion au mérite, besoin de profondeur) : pas de promotion qui prendrait la place du groupe minimal.
 if(!urgent)return false;
 const wage=Math.max(plancher,Math.floor(reste/10)*10);
 if(wage<p.salary){p.salary=wage;aiRosterCapTally('urgence-sous-limite',c);}
 return ok;
};
const budgetValeur=p=>{if(budgetActif()&&p&&typeof p.id==='string'&&Number.isFinite(p.rating)){p.salary=nativeStartingSalaries.marche(p);p.price=Math.max(0,Math.round(p.salary*2/1000)*1000);}return p;};
aiRosterSmallClubPlayer=function(slot,index){return budgetValeur(aiRosterSmallClubPlayerV1(slot,index));};
aiRosterPoolEntry=function(p,origin,clubId=null){if(budgetActif()&&origin!=='released')budgetValeur(p);return aiRosterPoolEntryV1(p,origin,clubId);};
// Un joueur libéré d'un club à échelle réduite (Nationale, Japon…) arrive sur le marché libre avec son salaire de club,
// parfois sous le plancher de la règle : libre, il redemande au moins ce plancher (14 000 € par an, 270 € par semaine).
const aiRosterTrimFreeAgentsV1=aiRosterTrimFreeAgents;
aiRosterTrimFreeAgents=function(){
 if(budgetActif()&&S.economy&&Array.isArray(S.economy.freeAgents)){
  const plancher=nativeStartingSalaries.plancherHebdo(S,null);
  for(const p of S.economy.freeAgents)if(p&&Number.isFinite(p.salary)&&p.salary<plancher){p.salary=plancher;p.price=Math.max(p.price||0,Math.round(p.salary*2/1000)*1000);}
 }
 return aiRosterTrimFreeAgentsV1();
};
// Renforts pour compléter la feuille de match du club joué (suite de #869 : des renforts au plancher, gardés
// plusieurs saisons, faisaient fondre la masse salariale de 7,4 à 0,35 M€ en trois saisons). Pour chaque place
// vide, le directeur sportif engage d'abord un joueur libre du poste, au salaire qu'il demande, si la masse
// que le club s'autorise le permet ; sinon un espoir monte, payé au salaire de son niveau. Dans les deux cas,
// un contrat de dépannage jusqu'à la fin de la saison : rien ne s'accumule au plancher d'une saison à l'autre.
const budgetJokerNiveau=c=>Math.max(55,c.base-12);
function budgetJoker(slot,exclus){
 const c=club(),l=budgetLimites(false).get(c.id),limite=l?l.limite:Infinity,masse=budgetMasse(c)*52,niveau=budgetJokerNiveau(c);
 let meilleur=null,salaire=0;
 for(const p of S.economy?.freeAgents||[]){
  if(!p||exclus.has(p.id)||p.injury>0||!(p.rating>=niveau)||!slotEligible(p,slot)||p.age>=(p.dev?.retireAge??40))continue;
  if(meilleur&&p.rating<=meilleur.rating)continue;
  const demande=salaryDemandBreakdown(p,'recruit').asked;
  if(!Number.isFinite(demande)||masse+demande*52>limite)continue;
  meilleur=p;salaire=demande;
 }
 return meilleur?{p:meilleur,salaire}:null;
}
const promoteCoverV1=promoteCover;
promoteCover=function(){
 if(!budgetActif())return promoteCoverV1();
 // Carrières France marquées : ancien renfort, au plancher de la règle.
 if(!budgetMonde()){const avant=new Set(club().players.map(p=>p.id)),r=promoteCoverV1(),salaire=budgetPlancherHebdo();for(const p of club().players)if(!avant.has(p.id))p.salary=salaire;return r;}
 if(S.live)return;
 repairSheet();
 const vides=[...S.lineup,...S.reserves].filter(id=>!id).length;
 if(vides>professionalPlaces())return false;
 const c=club(),avant=new Set(c.players.map(p=>p.id)),exclus=new Set(),jokers=[];
 for(let i=0;i<23;i++){
  const banc=i>=15,j=banc?i-15:i,liste=banc?S.reserves:S.lineup;
  if(liste[j])continue;
  const slot=banc?[1,0,2,3,5,8,9,10][j]:j,choix=budgetJoker(slot,exclus);
  if(!choix)continue;
  const p=choix.p;exclus.add(p.id);
  p.salary=choix.salaire;p.contractEnd=S.season;p.joinedSeason=S.season;p.joinedRound=S.round;p.condition=100;
  S.economy.freeAgents=S.economy.freeAgents.filter(x=>x.id!==p.id);S.market=(S.market||[]).filter(x=>x.id!==p.id);
  if(typeof satisfactionActive==='function'&&satisfactionActive())ensureSatisfaction(p);
  c.players.push(p);liste[j]=p.id;jokers.push(p);
  transferEvent(p.name+' rejoint le club comme joker jusqu’à la fin de la saison, à '+money(p.salary)+' par semaine.');
 }
 if(jokers.length)news('Le directeur sportif a engagé '+jokers.length+' joueur'+(jokers.length>1?'s':'')+' libre'+(jokers.length>1?'s':'')+' jusqu’à la fin de la saison pour compléter la feuille de match.');
 const resultat=[...S.lineup,...S.reserves].some(id=>!id)?promoteCoverV1():(save(),render(),true);
 const plancher=budgetPlancherHebdo();
 for(const p of c.players)if(!avant.has(p.id)&&!exclus.has(p.id)){p.salary=Math.max(plancher,nativeStartingSalaries.marche(p));p.contractEnd=S.season;}
 return resultat;
};
// Joueurs ajoutés pour garder 40 professionnels par club : ils signaient à 1 400–2 200 € par semaine quel que soit
// le club. Pour les carrières marquées, ils signent au salaire de la règle dans leur club.
// Filet de sécurité, après chaque commande : un club géré d'une ligue plafonnée qui dépasse le
// plafond (renfort d'urgence promu, prolongation indispensable) ramène ses contrats sous le
// plafond, comme à l'intersaison (même retenue proportionnelle, jamais sous le plancher).
function budgetConformite(){
 let touche=false;
 for(const c of S.clubs){
  if(c.id===S.club)continue;
  const plafond=budgetPlafondAnnuel(c);
  if(!plafond)continue;
  const masse=budgetMasse(c)*52;
  if(masse<=plafond)continue;
  const plancher=nativeStartingSalaries.plancherHebdo(S,budgetLigue(c.id));
  // Retenue calculée sur la part au-dessus du plancher, arrondie vers le bas.
  const libre=c.players.reduce((n,p)=>n+Math.max(0,p.salary-plancher),0)*52,retenue=libre>0?Math.max(0,1-(masse-plafond)/libre):0;
  for(const p of c.players)if(p.salary>plancher)p.salary=Math.max(plancher,Math.floor((plancher+(p.salary-plancher)*retenue)/10)*10);
  // Filet de dernier recours : chaque passage est compté (mesure), il ne doit presque jamais servir.
  if(typeof nativeClubDirections!=='undefined')nativeClubDirections.tally('plafond:retenue-forcee',c.id);
  touche=true;
 }
 return touche;
}
// Le moteur appelle budgetAvantProfondeur(), puis nativeProfessionalDepth.fill(S) tel quel, puis budgetProfondeur() :
// hors carrières marquées, ces deux appels ne font rien et le remplissage reste celui d'origine, à l'identique.
let budgetTaillesAvant=null;
function budgetAvantProfondeur(){budgetTaillesAvant=budgetActif()&&!S.live?S.clubs.map(c=>c.players.length):null;}
function budgetProfondeur(){
 const tailles=budgetTaillesAvant;budgetTaillesAvant=null;
 if(!tailles||!budgetActif()||S.live||tailles.length!==S.clubs.length)return;
 let forces=null;
 S.clubs.forEach((c,i)=>{
  if(c.players.length<=tailles[i])return;
  forces=forces||budgetForces();
  const nouveaux=c.players.slice(tailles[i]);
  for(const p of nouveaux)p.salary=nativeStartingSalaries.demande(S,forces,c.id,p,nativeLeagueEconomy);
  // Un club géré ne franchit pas sa masse autorisée (au plus le plafond de la ligue) pour un joueur de
  // complément : il le signe sous le salaire de la règle, jamais sous le plancher.
  if(c.id!==S.club){
   const limite=aiRosterWageLimit(c),autres=budgetMasse(c)-nouveaux.reduce((n,p)=>n+p.salary,0);
   if(autres+nouveaux.reduce((n,p)=>n+p.salary,0)>limite){
    const plancher=nativeStartingSalaries.plancherHebdo(S,budgetLigue(c.id)),part=Math.floor((limite-autres)/nouveaux.length/10)*10;
    for(const p of nouveaux)p.salary=Math.max(plancher,Math.min(p.salary,part));
   }
   // Même au plancher, le complément ferait franchir le plafond : le club libère un joueur cher et non
   // indispensable, remplacé par un complément au plancher (au plus trois fois).
   const plafond=aiRosterLeagueCap(c),plancher=aiRosterFloorWage(c);
   for(let n=0;n<3&&budgetMasse(c)>plafond&&typeof nativeProfessionalDepth!=='undefined';n++){
    if(!aiRosterMakeRoom(c,budgetMasse(c)-plafond,new Set(nouveaux.map(p=>p.id)),plancher))break;
    const occupes=new Set([...S.clubs.flatMap(x=>x.players),...S.market,...S.economy.freeAgents,...(S.development?.academy??[]),...(S.development?.retired??[]),...(S.aiRoster?.academies??[]).flatMap(a=>a.players)].map(p=>p.id));
    for(const p of nativeProfessionalDepth.additions(c.id,c.players,S.season,occupes)){
     p.salary=plancher;p.joinedSeason=S.season;p.joinedRound=S.round;if(S.phase==='ended')p.contractEnd=S.season+1;
     c.players.push(p);nouveaux.push(p);
    }
    if(typeof nativeClubDirections!=='undefined')nativeClubDirections.tally('plafond:complement-remplace',c.id);
   }
  }
 });
 if(budgetConformite())forces=forces||budgetForces();
 // La prévision du club joué suit son effectif complété.
 if(forces&&budgetLisible(S.clubBudget)&&S.clubBudget.saison===S.season){S.clubBudget.clubs.forEach((k,i)=>{k.masse=Math.round(budgetMasse(S.clubs[i])*52);});budgetPrevoir(forces,budgetRepere());}
}
// Ce que l'écran Finances lit : mêmes champs qu'avant, remplis par le budget de la saison.
function budgetFinance(hebdoFormation,hebdoPartenaire,entretien){
 const b=S.clubBudget;
 if(!budgetActif()||!budgetLisible(b)||b.saison!==S.season||!b.prevision)return null;
 const forces=budgetForces(),c=club(),masse=budgetMasse(c),semaines=wageForecastWeeks();
 const staff=budgetStaff(c),type=budgetCopie(nativeClubBudget.semaine({forces,clubId:c.id,masseHebdo:masse,semaines,domicile:false,alea:0.5,libelle:'',gere:true,formation:budgetCentre(c),billets:budgetBillets(c,null,budgetRepere()),staff})),somme=f=>type.filter(f).reduce((s,e)=>s+e.amount,0);
 // Charges hors joueurs : tout ce que la semaine type débite, moins les salaires des joueurs et leurs cotisations.
 const salaires=chiffresMasse().chargeHebdo,fonctionnement=Math.max(0,-somme(e=>e.amount<0)-salaires),centre=-somme(e=>/Centre de formation/.test(e.title)),recettes=somme(e=>e.amount>0)+hebdoPartenaire;
 const staffHebdo=-somme(e=>e.title.endsWith(nativeClubBudget.LIBELLE_STAFF)),staffCharge=Math.round(staffHebdo*(1+nativeClubBudget.COTISATIONS)/100)*100;
 return {weeklyWages:salaires,weeklyIncome:recettes,weeklyCosts:salaires+fonctionnement+hebdoFormation+entretien,baseForecast:b.prevision.tresoreriePrevue,
  notice:'Prévision de fin de saison : recettes, charges, prime de classement et soutien du propriétaire compris ; transferts à venir non comptés.',
  budget:{...budgetCopie(b.prevision),fonctionnementHebdo:fonctionnement,centreFormationHebdo:centre,staffHebdo:staffCharge,semainesDePaie:semaines,plancherSalaire:budgetPlancherHebdo()}};
}
`;

// À exécuter dans le moteur avant tout autre habillage de validateCareer : la sauvegarde refuse une
// discussion de contrat sous 1 000 € par semaine. Pour les carrières marquées seulement, la même
// validation est reprise avec le plancher technique des salaires (10 €). Les autres carrières
// gardent la fonction d'origine, à l'identique.
const VALIDATION = `{
 const source=validateCareer.toString(),ancien='saveInt(t.salary,1000,100000)&&saveInt(t.acceptedSalary,1000,100000)';
 if(source.split(ancien).length===2){
  const origine=validateCareer,souple=(0,eval)('('+source.replace(ancien,'saveInt(t.salary,10,100000)&&saveInt(t.acceptedSalary,10,100000)')+')');
  validateCareer=function(s){return s!==null&&typeof s==='object'&&s.startingSalaries!==undefined?souple(s):origine(s);};
 }
}`;

module.exports = Object.freeze({ fonctionnementAnnuel, SEUIL_FONCTIONNEMENT, FONCTIONNEMENT_AU_DELA, STAFF_REFERENCE, categorieStaff, echelleStaff, facteurNiveauStaff, niveauAttenduStaff, salaireStaff, masseStaff,
  POLITIQUES_BILLET, ELASTICITE_PRIX, facteurPrix, rapportPrix, estimationStaff, conseilPrix, REMISE_ABONNEMENT, PRESENCE_ABONNES, billetterieAnnuelle, politiqueBillet, prixBillet, abonnesEstimes, guichet, abonnementsHebdo, LIBELLE_STAFF, LIBELLE_FONCTIONNEMENT, LIBELLE_TRAIN_DE_VIE,
  PART_FORMATION, FORMATION, CREDIT_ACADEMIE, centreFormation, creditAcademie, ECONOMIE, DIVISIONS, COTISATIONS, FONCTIONNEMENT, PART_PRIME, PART_ABONNEMENTS, PLAFOND_SALARIAL, RATIO_SALAIRES, PROPRIETAIRES, BRANCHEMENT, VALIDATION,
  aideRelegation, annonceAideRelegation, LIBELLE_AIDE_RELEGATION, LIBELLE_REMBOURSEMENT,
  RESERVE, EXCEDENTS, EXCEDENT_DORMANT, TRAIN_DE_VIE, reserveCible, engagement, apportProprietaire, annonceDividende, annonceInvestissement,
  recettesImprevues, fraisDeMatch, PART_FRAIS_IMPREVUS, deficitPrevu, LIBELLE_FRAIS_MATCH,
  recettes, semaine, proprietaire, cibleGestion, limites, annonceClauses, forme, affluence, spectateurs, ajustement, primeClassement, regles, ouverture, compter, annonce, prevision, cloture, leviers, euros, facteurHumeur, HUMEUR_PUBLIC });
