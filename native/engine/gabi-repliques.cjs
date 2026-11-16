'use strict';
// Gabi, adjoint de confiance (lot 3, demande de Léo, 15 novembre 2026) : choix de la réplique spontanée.
//
// Une réplique spontanée (bulle ouverte d'office, première visite d'un écran) commence toujours par une
// information utile tirée de l'état du jeu, avec un bouton d'action quand l'écran où agir existe :
// courrier important, feuille de match, condition ou blessure des titulaires, contrat urgent, prochain
// match. L'ambiance (« la cafetière peut attendre ») n'est qu'un complément, une fois sur quatre au plus.
//
// Fonction pure et déterministe sur le modèle projeté (ce que voit le manager) : mêmes données, même
// réplique, aucun tirage aléatoire. Le moteur l'attache à chaque instantané (`model.gabi`) ; l'interface
// Godot (coach_canvas.gd) ne fait que l'afficher.
const SEUIL_CONDITION = 70;
const JOURS_ALERTE = 3;
const AMBIANCE_UNE_SUR = 4;

const num = (v, d = 0) => (typeof v === 'number' && Number.isFinite(v) ? v : d);
const liste = v => (Array.isArray(v) ? v : []);
const obj = v => (v && typeof v === 'object' && !Array.isArray(v) ? v : {});

function fnv(texte) {
  let h = 0x811c9dc5;
  for (let i = 0; i < texte.length; i++) { h ^= texte.charCodeAt(i); h = Math.imul(h, 0x01000193) >>> 0; }
  return h;
}

function jourUnix(date) {
  if (typeof date !== 'string' || !/^\d{4}-\d{2}-\d{2}/.test(date)) return null;
  const t = Date.parse(date.slice(0, 10) + 'T12:00:00Z');
  return Number.isFinite(t) ? t : null;
}

// Jours entre aujourd'hui (calendrier du jeu) et la rencontre ; null si inconnu.
function joursAvant(model, fixture) {
  const a = jourUnix(model.meta?.calendarToday ?? model.calendarPlanning?.today), b = jourUnix(fixture?.date);
  return a === null || b === null ? null : Math.max(0, Math.round((b - a) / 86400000));
}

function prochainMatch(model) {
  if (obj(model.next).home) return model.next;
  const own = model.club?.id, week = num(model.meta?.week);
  let best = null;
  for (const f of liste(model.calendar)) {
    if (!f || f.played || (f.home?.id !== own && f.away?.id !== own) || num(f.week) < week) continue;
    if (!best || num(f.week) < num(best.week)) best = f;
  }
  return best;
}

const adversaire = (model, f) => f ? (f.home?.id === model.club?.id ? f.away?.name : f.home?.name) || '' : '';
const quand = j => j === null ? '' : j === 0 ? 'aujourd’hui' : j === 1 ? 'demain' : `dans ${j} jours`;
const prenomNom = p => String(p?.name ?? '') || 'un joueur';
const liste2 = noms => noms.length <= 1 ? (noms[0] || '') : noms.slice(0, -1).join(', ') + ' et ' + noms.at(-1);

function candidats(model) {
  const sorties = [];
  const fixture = prochainMatch(model), jours = fixture ? joursAvant(model, fixture) : null;
  const adv = adversaire(model, fixture);
  const squad = liste(model.squad), parId = new Map(squad.map(p => [p.id, p]));
  const proche = jours !== null && jours <= JOURS_ALERTE;

  // 1. Courrier important : changement de date en attente, conférence de presse en attente.
  const courrier = liste(model.calendarMail).filter(m => m?.status === 'pending');
  if (courrier.length) {
    const m = courrier[courrier.length - 1];
    sorties.push({ cle: 'courrier:' + m.id, genre: 'courrier', priorite: 100, route: 'Réception', libelle: 'Ouvrir le courrier',
      texte: `Un courrier t’attend : la date de ${m.opponent ? 'ton match contre ' + m.opponent : 'ton prochain match'} a changé. Dis-moi si on recale la préparation.` });
  }
  const invitations = liste(model.clubLife?.press?.invitations).filter(i => i?.status === 'pending');
  if (invitations.length) {
    sorties.push({ cle: 'presse:' + invitations[0].id, genre: 'courrier', priorite: 70, route: 'Réception', libelle: 'Ouvrir le courrier',
      texte: `La presse t’attend : ${invitations.length > 1 ? invitations.length + ' invitations' : 'une invitation'} en attente dans ton courrier.` });
  }

  // 2. Feuille de match incomplète à l'approche du match.
  if (fixture && jours !== null && jours <= 2 && obj(model.selection).valid === false) {
    sorties.push({ cle: 'feuille:' + fixture.id, genre: 'feuille', priorite: 90, route: 'Composition', libelle: 'Ouvrir la composition',
      texte: `La feuille de match n’est pas complète, et c’est ${quand(jours)}${adv ? ' contre ' + adv : ''}. On la termine ensemble ?` });
  }

  // 3. Titulaires blessés ou fatigués sur la feuille du prochain match.
  if (fixture && proche) {
    const titulaires = liste(obj(model.selection).slots).map(s => parId.get(s?.playerId)).filter(Boolean);
    const blesses = titulaires.filter(p => num(p.injury) > 0);
    const fatigues = titulaires.filter(p => !(num(p.injury) > 0) && num(p.condition, 100) < SEUIL_CONDITION)
      .sort((a, b) => num(a.condition, 100) - num(b.condition, 100) || String(a.id).localeCompare(String(b.id)));
    if (blesses.length) {
      sorties.push({ cle: 'blesses:' + fixture.id + ':' + blesses.map(p => p.id).sort().join(','), genre: 'blesses', priorite: 85, route: 'Composition', libelle: 'Ouvrir la composition',
        texte: `${liste2(blesses.slice(0, 2).map(prenomNom))} ${blesses.length > 1 ? 'sont blessés et figurent' : 'est blessé et figure'} sur ta feuille ${quand(jours)}. Il faut les remplacer.` });
    }
    if (fatigues.length) {
      const detail = liste2(fatigues.slice(0, 2).map(p => `${prenomNom(p)} (${Math.round(num(p.condition))} %)`));
      sorties.push({ cle: 'condition:' + fixture.id + ':' + fatigues.map(p => p.id).sort().join(','), genre: 'condition', priorite: 80, route: 'Composition', libelle: 'Suivre le conseil',
        texte: `${fatigues.length} titulaire${fatigues.length > 1 ? 's' : ''} sous ${SEUIL_CONDITION} % de condition ${quand(jours)} : ${detail}${fatigues.length > 2 ? ' et ' + (fatigues.length - 2) + ' autre' + (fatigues.length > 3 ? 's' : '') : ''}. À ménager.` });
    }
  }

  // 4. Contrat urgent : les meilleurs joueurs dont le contrat s'arrête à la fin de cette saison.
  const saison = num(model.meta?.season, 1);
  const expirants = squad.filter(p => p.contractEnd !== null && p.contractEnd !== undefined && num(p.contractEnd, 99) <= saison)
    .sort((a, b) => num(b.rating) - num(a.rating) || String(a.id).localeCompare(String(b.id)));
  if (expirants.length) {
    const tete = expirants.slice(0, 2);
    sorties.push({ cle: 'contrat:' + saison + ':' + tete.map(p => p.id).join(','), genre: 'contrat', priorite: 60, route: 'Effectif', libelle: 'Ouvrir l’effectif',
      texte: `${liste2(tete.map(p => `${prenomNom(p)} (${Math.round(num(p.rating))})`))} ${tete.length > 1 ? 's’arrêtent' : 's’arrête'} en fin de saison${expirants.length > 2 ? ', avec ' + (expirants.length - 2) + ' autre' + (expirants.length > 3 ? 's' : '') + ' contrats' : ''}. Prolonge avant qu’ils n’écoutent ailleurs.` });
  }

  // 5. Prochain match : toujours disponible quand il existe.
  if (fixture) {
    sorties.push({ cle: 'match:' + (fixture.id ?? fixture.date), genre: 'match', priorite: 40, route: jours === 0 ? 'Composition' : 'Préparation', libelle: jours === 0 ? 'Ouvrir la composition' : 'Ouvrir la préparation',
      texte: `Prochain match ${quand(jours) || 'au calendrier'}${adv ? ' contre ' + adv : ''}. ${jours !== null && jours <= 1 ? 'Séance légère, feuille vérifiée.' : 'On prépare dans l’ordre : effectif, composition, plan de jeu.'}` });
  }
  return sorties.sort((a, b) => b.priorite - a.priorite || a.cle.localeCompare(b.cle));
}

// Retour : { replique: {cle, genre, priorite, texte, route, libelle, action}|null, autres: [cle], ambiance: bool }.
// `ambiance` : autorise le complément d'ambiance (une fois sur quatre, déterministe selon le jour et la réplique).
function choisir(model) {
  if (!obj(model).club || !obj(model.meta).hasCareer) return { replique: null, autres: [], ambiance: false };
  const liste_ = candidats(model), premier = liste_[0] || null;
  const jour = String(model.meta?.calendarToday ?? '') + '|' + String(model.club.id);
  const ambiance = fnv(jour + '|' + (premier ? premier.cle : 'rien')) % AMBIANCE_UNE_SUR === 0;
  return {
    replique: premier ? { ...premier, action: { type: 'ecran', route: premier.route, libelle: premier.libelle, detail: 'Ouvrir l’écran concerné' } } : null,
    autres: liste_.slice(1, 4).map(c => c.cle),
    ambiance,
  };
}

module.exports = { choisir, candidats, joursAvant, prochainMatch, SEUIL_CONDITION, AMBIANCE_UNE_SUR };
