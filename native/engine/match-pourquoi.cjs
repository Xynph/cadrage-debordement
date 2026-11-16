'use strict';
// « Pourquoi » d'après-match (lot 2, 16 novembre 2026) : au coup de sifflet final, Gabi dit en trois
// raisons au plus pourquoi le match a tourné ainsi, chacune reliée à un levier du manager
// (composition, condition, tactique, discipline, préparation) et à l'écran où l'actionner.
//
// Lecture pure et DÉTERMINISTE des faits MESURÉS du match, ceux que l'écran de match affiche déjà :
// tableau de bord de fin de match (match-direct.cjs : possession, occupation, plaquages manqués,
// touches et mêlées, pénalités, cartons), notes des joueurs (match-notes.cjs) et énergie des deux XV
// au coup de sifflet final. Rien n'est inventé : sans écart net, aucune raison n'est donnée.
//
// Chaque fait candidat reçoit un poids en « points de match » (positif : il a coûté à notre équipe,
// négatif : il l'a servie). Défaite : les faits qui ont coûté d'abord ; victoire : ceux qui ont
// porté ; nul : par importance. Seuil SEUIL : en dessous, le fait ne dit rien du résultat.

// Levier → action proposée et écran du jeu (routes Godot : main.gd / shell.gd).
const LEVIERS = Object.freeze({
  composition: { label: 'Composition', action: 'Revoir la composition', route: 'Composition' },
  condition: { label: 'Condition', action: 'Voir la condition', route: 'Effectif' },
  tactique: { label: 'Tactique', action: 'Ajuster la tactique', route: 'Composition' },
  discipline: { label: 'Discipline', action: 'Travailler la discipline', route: 'Composition' },
  preparation: { label: 'Préparation', action: 'Préparer la semaine', route: 'Préparation' },
});
const MAX = 3;
const SEUIL = 2.5;
// Poids d'une unité de chaque fait (points de match équivalents, ordre de grandeur rugby).
const POIDS = Object.freeze({ penalite: 1.2, carton: 3.5, occupation: 0.25, possession: 0.15, plaquage: 0.45, conquete: 1.1, energie: 0.3, note: 1.6 });
const NOTE_FAIBLE = 5.5;

const pluriel = (n, mot, pl = mot + 's') => n + ' ' + (n > 1 ? pl : mot);
const virgule = x => String(Math.round(x * 10) / 10).replace('.', ',');

/**
 * Faits mesurés du match vus depuis notre camp, extraits de la projection de fin de match.
 * @param {Object} direct  Projection de l'entracte (match-direct.cjs) : camp, score, tableau, notes.
 * @param {Object} [extra] { energie:[nous, eux] (moyenne du XV sur le terrain, %), noms:{id:nom} }.
 * @returns {Object|null} null si le camp ou le tableau manquent.
 */
function faits(direct, extra = {}) {
  const camp = direct?.camp;
  if (camp !== 0 && camp !== 1 || !Array.isArray(direct.tableau)) return null;
  const eux = 1 - camp, rang = cle => direct.tableau.find(r => r && r.cle === cle && !r.vide);
  const paire = cle => { const r = rang(cle); return r && Array.isArray(r.valeurs) ? [Number(r.valeurs[camp]) || 0, Number(r.valeurs[eux]) || 0] : null; };
  const sur = cle => { const r = rang(cle); return r && Array.isArray(r.sur) ? [Number(r.sur[camp]) || 0, Number(r.sur[eux]) || 0] : null; };
  const score = Array.isArray(direct.score) ? [Number(direct.score[camp]) || 0, Number(direct.score[eux]) || 0] : [0, 0];
  const notes = Object.entries(direct.notes || {}).filter(([, n]) => n && Number.isFinite(n.note) && (n.faits ?? 1) > 0 && (n.cote === undefined || n.cote === camp))
    .map(([id, n]) => ({ id, note: n.note, nom: extra.noms?.[id] || n.nom || '' })).sort((a, b) => a.note - b.note || (a.id < b.id ? -1 : 1));
  return {
    score, possession: paire('possession'), occupation: paire('occupation'), penalites: paire('penalites'), cartons: paire('cartons'),
    manques: paire('plaquages_manques'), touches: paire('touches'), touchesSur: sur('touches'), melees: paire('melees'), meleesSur: sur('melees'),
    energie: Array.isArray(extra.energie) && extra.energie.every(Number.isFinite) ? extra.energie.map(Math.round) : null, notes,
  };
}

// Candidats : {levier, poids (+ : a coûté), texte}. Textes du point de vue du club (« on », « nous »).
function candidats(f) {
  const out = [];
  const add = (levier, poids, texte) => { if (Math.abs(poids) >= SEUIL) out.push({ levier, poids: Math.round(poids * 10) / 10, texte }); };
  if (f.penalites) {
    const [nous, eux] = f.penalites, [cn, ce] = f.cartons || [0, 0];
    const poids = (nous - eux) * POIDS.penalite + (cn - ce) * POIDS.carton;
    const cartons = cn ? ' et ' + pluriel(cn, 'carton') : '';
    add('discipline', poids, poids > 0
      ? 'On a concédé ' + pluriel(nous, 'pénalité') + cartons + ' (' + eux + ' pour eux) : trop de ballons et de points offerts.'
      : 'Discipline propre : ' + pluriel(nous, 'pénalité') + ' concédée' + (nous > 1 ? 's' : '') + ' contre ' + eux + ' en face' + (ce ? ', et ' + pluriel(ce, 'carton') + ' pour eux' : '') + '.');
  }
  if (f.occupation) {
    const occ = f.occupation[0], poids = (50 - occ) * POIDS.occupation;
    add('tactique', poids, poids > 0
      ? 'On a joué ' + (100 - occ) + ' % du match dans notre moitié : il fallait sortir de notre camp au pied.'
      : 'On a occupé leur moitié ' + occ + ' % du temps : la pression territoriale a payé.');
  }
  if (f.manques) {
    const [nous, eux] = f.manques, poids = (nous - eux) * POIDS.plaquage;
    add('tactique', poids, poids > 0
      ? pluriel(nous, 'plaquage manqué', 'plaquages manqués') + ' contre ' + eux + ' : notre défense a laissé trop d’espaces.'
      : 'Défense solide : ' + pluriel(nous, 'plaquage manqué', 'plaquages manqués') + ' seulement, contre ' + eux + ' pour eux.');
  }
  const conquete = (nom, gagnes, lances) => {
    if (!gagnes || !lances) return;
    const perdus = [lances[0] - gagnes[0], lances[1] - gagnes[1]], poids = (perdus[0] - perdus[1]) * POIDS.conquete;
    add('preparation', poids, poids > 0
      ? nom + ' : ' + gagnes[0] + ' gagnée' + (gagnes[0] > 1 ? 's' : '') + ' sur ' + lances[0] + ' introductions. Notre conquête nous a privés de ballons.'
      : nom + ' : ' + gagnes[0] + ' sur ' + lances[0] + ' pour nous, ' + gagnes[1] + ' sur ' + lances[1] + ' pour eux. La conquête a fait la différence.');
  };
  conquete('Touche', f.touches, f.touchesSur);
  conquete('Mêlée', f.melees, f.meleesSur);
  if (f.energie) {
    const [nous, eux] = f.energie, poids = (eux - nous) * POIDS.energie;
    add('condition', poids, poids > 0
      ? 'Notre XV a fini à ' + nous + ' % d’énergie contre ' + eux + ' % en face : on a manqué de jus en fin de match.'
      : 'Notre XV a fini plus frais (' + nous + ' % d’énergie contre ' + eux + ' %) : on a tenu la distance.');
  }
  if (f.notes?.length) {
    const faibles = f.notes.filter(n => n.note < NOTE_FAIBLE);
    if (faibles.length >= 2) {
      const noms = faibles.slice(0, 3).map(n => (n.nom || 'un joueur') + ' (' + virgule(n.note) + ')').join(', ');
      add('composition', faibles.length * POIDS.note, pluriel(faibles.length, 'joueur') + ' sous ' + virgule(NOTE_FAIBLE) + ' de note : ' + noms + '. À reconsidérer pour la feuille.');
    }
  }
  return out;
}

/**
 * Trois raisons au plus, classées, du résultat du match.
 * @param {Object} f Faits mesurés (voir `faits`).
 * @returns {{issue:'victoire'|'defaite'|'nul', raisons:Array<{rang:number,levier:string,levierLabel:string,sens:'positif'|'negatif',texte:string,action:string,route:string,poids:number}>}}
 */
function raisons(f) {
  if (!f) return { issue: null, raisons: [] };
  const [a, b] = f.score, issue = a > b ? 'victoire' : a < b ? 'defaite' : 'nul';
  const liste = candidats(f);
  // Un seul fait par levier : le plus lourd dans le sens du résultat.
  const cle = c => issue === 'defaite' ? -c.poids : issue === 'victoire' ? c.poids : -Math.abs(c.poids);
  liste.sort((x, y) => cle(x) - cle(y) || (x.levier < y.levier ? -1 : x.levier > y.levier ? 1 : 0));
  const vus = new Set(), choisis = [];
  for (const c of liste) {
    if (vus.has(c.levier)) continue;
    // Victoire : les faits qui ont porté d'abord ; un fait qui a coûté vient ensuite s'il pèse (« malgré »).
    vus.add(c.levier); choisis.push(c);
    if (choisis.length === MAX) break;
  }
  return {
    issue,
    raisons: choisis.map((c, i) => {
      const sens = c.poids > 0 ? 'negatif' : 'positif';
      // Fait à contre-courant du résultat : dit comme tel (« À surveiller » après une victoire).
      const prefixe = issue === 'victoire' && sens === 'negatif' ? 'À surveiller : ' : issue === 'defaite' && sens === 'positif' ? 'Point d’appui : ' : '';
      return { rang: i + 1, levier: c.levier, levierLabel: LEVIERS[c.levier].label, sens, texte: prefixe ? prefixe + c.texte[0].toLowerCase() + c.texte.slice(1) : c.texte, action: LEVIERS[c.levier].action, route: LEVIERS[c.levier].route, poids: c.poids };
    }),
  };
}

module.exports = Object.freeze({ LEVIERS, MAX, SEUIL, POIDS, NOTE_FAIBLE, faits, candidats, raisons });
