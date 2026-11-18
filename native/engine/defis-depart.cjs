'use strict';
// Défis de départ (création d'une carrière Monde) : quelques situations de club calculées sur la vraie base
// (catalogue de création world-champ), pas des listes figées. Chaque défi propose jusqu'à 3 clubs, avec une
// difficulté (1 à 5) et l'objectif que le président fixera : la phrase d'objectif du club (`goal`) et un
// objectif chiffré de classement au conseil (feuille de route, board-calendar.js).
//   promu        : club monté à l'issue de la saison 2025-2026 (titre de l'étage inférieur cette année-là).
//   nationale    : clubs de Nationale (3e division) ; le champion monte, le finaliste joue un barrage.
//   petit-budget : trésorerie de départ dans le dernier tiers de sa division, effectif qui tient la route.
//   geant        : club au palmarès national lourd, aujourd'hui en bas de tableau ou à l'étage inférieur.
//   douceur      : départ confortable pour apprendre (milieu de tableau, trésorerie au-dessus de la médiane).
// Lecture seule et déterministe : même catalogue, mêmes défis. Les noms de clubs ne sont pas copiés (le jeu les
// lit dans le catalogue, packs compris).

const ANNEE_DEPART = 2026;
// Étage inférieur (d'où vient un promu) et taille, places de phase finale et dernière place sûre.
const DIVISIONS = Object.freeze({
  elite: { dessous: 'accession', finale: 6, sur: 12 },
  accession: { dessous: 'nationale', finale: 6, sur: 14 },
  nationale: { dessous: null, finale: 6, sur: 13 },
});
const PALMARES_ELITE = ['elite', 'prem', 'urc'];
const LIBELLES = ['', 'Accessible', 'Abordable', 'Exigeant', 'Difficile', 'Très difficile'];
const DEFIS = Object.freeze([
  { id: 'douceur', titre: 'Débuter en douceur', accroche: 'Un club sain, un effectif solide, du temps pour apprendre le métier.' },
  { id: 'promu', titre: 'Sauver un promu', accroche: 'Ils viennent de monter. Personne ne les voit rester. Toi, si.' },
  { id: 'nationale', titre: 'Faire monter un club de Nationale', accroche: 'Petits moyens, grande faim : un seul billet direct pour l’étage au-dessus.' },
  { id: 'petit-budget', titre: 'Gagner avec un petit budget', accroche: 'Moins d’argent que les autres, pas moins d’ambition.' },
  { id: 'geant', titre: 'Relancer un géant en crise', accroche: 'Un palmarès qui pèse lourd, un présent qui fait mal.' },
]);

const fini = x => typeof x === 'number' && Number.isFinite(x);
const note = c => fini(c?.startingRoster?.average) ? c.startingRoster.average : fini(c?.base) ? c.base : 0;
const clamp = (x, a, b) => Math.max(a, Math.min(b, x));
const ordinal = n => n === 1 ? '1er' : n + 'e';
// Difficulté : écart entre le rang de l'effectif dans sa division et le rang visé (négatif = marge).
const ecart = e => e <= -3 ? 1 : e <= -1 ? 2 : e <= 1 ? 3 : e <= 4 ? 4 : 5;

// Rang (1 = meilleur) de chaque club de la division selon une valeur, à égalité par identifiant.
function rangs(clubs, valeur) {
  const tri = clubs.slice().sort((a, b) => valeur(b) - valeur(a) || a.id - b.id);
  return new Map(tri.map((c, i) => [c.id, i + 1]));
}

function titres(c, competitions) {
  return (c.history?.results || []).filter(r => competitions.includes(r.competition)).reduce((n, r) => n + (Number.isInteger(r.titles) ? r.titles : 0), 0);
}

function promu(c) {
  const dessous = DIVISIONS[c.division]?.dessous;
  return !!dessous && (c.history?.results || []).some(r => r.competition === dessous && r.year === ANNEE_DEPART && Number.isInteger(r.titles) && r.titles > 0);
}

function objectifDu(c, n) {
  const goal = String(c.goal || '');
  const top = /Top (\d+)/.exec(goal);
  if (top) return { objectif: goal, rang: clamp(+top[1], 1, n) };
  if (/titre/i.test(goal)) return { objectif: goal, rang: 2 };
  if (/maintien/i.test(goal)) return { objectif: goal, rang: DIVISIONS[c.division]?.sur ?? n - 2 };
  return null;
}

// Catalogue de création (meta.champCatalogue) → liste des défis, chacun avec ses clubs (meilleur choix d'abord).
function proposer(catalogue) {
  const jouables = (Array.isArray(catalogue) ? catalogue : []).filter(c => c && Number.isInteger(c.id) && c.playable !== false && DIVISIONS[c.division]);
  const parDivision = new Map();
  for (const c of jouables) { if (!parDivision.has(c.division)) parDivision.set(c.division, []); parDivision.get(c.division).push(c); }
  const info = new Map();
  for (const [division, clubs] of parDivision) {
    const effectif = rangs(clubs, note), argent = rangs(clubs, c => fini(c.cashMillions) ? c.cashMillions : 0);
    const tresoreries = clubs.map(c => c.cashMillions || 0).sort((a, b) => a - b);
    const mediane = tresoreries[Math.floor(tresoreries.length / 2)];
    for (const c of clubs) info.set(c.id, { n: clubs.length, effectif: effectif.get(c.id), argent: argent.get(c.id), mediane, regle: DIVISIONS[division] });
  }
  const club = (c, difficulte, objectif, rang, raison) => {
    const d = clamp(Math.round(difficulte), 1, 5);
    return { club: c.id, division: c.division, difficulte: d, niveau: LIBELLES[d], objectif, rang, raison };
  };
  const listes = {
    douceur: jouables.filter(c => { const i = info.get(c.id), o = objectifDu(c, i.n); return c.division !== 'nationale' && (c.cashMillions || 0) >= i.mediane && o && ecart(i.effectif - o.rang) <= 2; })
      .map(c => { const i = info.get(c.id), o = objectifDu(c, i.n);
        return club(c, ecart(i.effectif - o.rang), o.objectif, o.rang, `Effectif ${ordinal(i.effectif)} de sa division, trésorerie confortable.`); })
      .sort((a, b) => a.difficulte - b.difficulte || (a.division === 'elite' ? -1 : 0) - (b.division === 'elite' ? -1 : 0) || info.get(a.club).effectif - info.get(b.club).effectif),
    promu: jouables.filter(promu).map(c => { const i = info.get(c.id);
      return club(c, ecart(i.effectif - i.regle.sur) + (i.argent > i.n * 2 / 3 ? 1 : 0), 'Maintien', i.regle.sur, `Monté la saison passée, effectif ${ordinal(i.effectif)} sur ${i.n}.`); })
      .sort((a, b) => b.difficulte - a.difficulte),
    nationale: (parDivision.get('nationale') || []).map(c => { const i = info.get(c.id);
      return club(c, ecart(i.effectif - 2) + 1, 'Viser la montée', 2, `Effectif ${ordinal(i.effectif)} sur ${i.n} en 3e division ; seul le champion monte directement.`); })
      .sort((a, b) => a.difficulte - b.difficulte || info.get(a.club).effectif - info.get(b.club).effectif).slice(0, 3),
    'petit-budget': jouables.filter(c => { const i = info.get(c.id); return c.division !== 'nationale' && i.argent > i.n * 2 / 3 && i.effectif <= Math.ceil(i.n * 3 / 4) && !promu(c); })
      .map(c => { const i = info.get(c.id), r = i.regle.finale;
        return club(c, ecart(i.effectif - r) + 1, 'Phases finales', r, `Trésorerie ${ordinal(i.argent)} sur ${i.n}, effectif ${ordinal(i.effectif)}.`); })
      .sort((a, b) => a.difficulte - b.difficulte || info.get(a.club).argent - info.get(b.club).argent),
    geant: jouables.map(c => ({ c, t: titres(c, PALMARES_ELITE), i: info.get(c.id) }))
      .filter(({ c, t, i }) => t >= 3 && !promu(c) && (c.division !== 'elite' || i.effectif > Math.ceil(i.n / 2)))
      .map(({ c, t, i }) => {
        // Président réaliste : la montée seulement si l'effectif le permet, sinon d'abord les phases finales.
        const montee = c.division !== 'elite' && i.effectif <= 4, rang = montee ? 2 : i.regle.finale;
        return { t, offre: club(c, ecart(i.effectif - rang), montee ? 'Viser la montée' : 'Phases finales', rang,
          `${t} titres de champion au palmarès, effectif ${ordinal(i.effectif)} sur ${i.n}${c.division !== 'elite' ? ' à l’étage inférieur' : ''}.`) };
      })
      .sort((a, b) => b.t - a.t || a.offre.club - b.offre.club).map(x => x.offre),
  };
  return DEFIS.map(d => ({ ...d, clubs: listes[d.id].slice(0, 3) })).filter(d => d.clubs.length > 0);
}

function trouver(catalogue, id, clubId) {
  const defi = proposer(catalogue).find(d => d.id === id);
  const offre = defi?.clubs.find(c => c.club === clubId);
  return offre ? { id: defi.id, titre: defi.titre, ...offre } : null;
}

// Application dans la machine du moteur, juste après CDWorldCareer.start : `nativeDefi` = résultat de trouver().
// Objectif du président (phrase du club) et objectif de classement au conseil, à l'échéance de la saison régulière.
const VM_APPLIQUER = `(d=>{const c=S.clubs[S.club];c.goal=d.objectif;
 S.defiDepart={version:1,id:d.id,titre:d.titre,club:S.club,saison:S.season,difficulte:d.difficulte,objectif:d.objectif,rang:d.rang};
 const fin=CDWorldCareer.sizing(S).maxRound;let b=S.nativeBoardCalendar;if(!b)b=CDBoardCalendar.create('club-'+S.club,S.season);
 if(fin>b.week)S.nativeBoardCalendar=CDBoardCalendar.objective(b,{id:'defi:'+S.season+':'+S.club+':rank',type:'rank',target:d.rang,deadline:fin,weight:2});
})(nativeDefi)`;

function valider(defi) {
  if (defi === undefined) return;
  const ok = defi && typeof defi === 'object' && !Array.isArray(defi) && defi.version === 1 && DEFIS.some(d => d.id === defi.id && d.titre === defi.titre)
    && Number.isInteger(defi.club) && Number.isInteger(defi.saison) && defi.saison >= 1 && Number.isInteger(defi.difficulte) && defi.difficulte >= 1 && defi.difficulte <= 5
    && typeof defi.objectif === 'string' && defi.objectif.length <= 64 && Number.isInteger(defi.rang) && defi.rang >= 1 && defi.rang <= 64
    && Object.keys(defi).length === 8;
  if (!ok) throw Error('Défi de départ invalide.');
}

module.exports = { proposer, trouver, valider, VM_APPLIQUER, DEFIS, LIBELLES, ANNEE_DEPART };
