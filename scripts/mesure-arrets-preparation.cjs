'use strict';
// Mesure : combien de fois « Continuer » s'arrête entre la création d'une carrière Monde (départ par défaut,
// « Reprise des premiers clubs », 13/07) et le jour du 1er match officiel, réglages d'arrêt par défaut du jeu.
// Chaque appui sur Continuer qui rend la main au joueur compte pour un arrêt (y compris les arrêts suivants du
// même jour). Les rendez-vous sont réglés au plus neutre ; les décisions de préparation sont prises (« équilibré »).
//
//   node scripts/mesure-arrets-preparation.cjs [club …]      (défaut : 0 Top 14, 88 Nationale, 102 Champ Rugby)
//   --json : sortie JSON seule (pour comparer avant / après).
const Monde = require('../tests/helpers/carriere-monde.cjs');
const { settleClubMeetings } = require('../tests/helpers/club-meetings.cjs');

const args = process.argv.slice(2), json = args.includes('--json');
const clubs = args.filter(a => /^\d+$/.test(a)).map(Number);
const LIGUES = { 0: 'Top 14', 88: 'Nationale', 102: 'Champ Rugby' };

function mesurer(club) {
  const jeu = Monde.ouvrir();
  try {
    // Décisions de la préparation prises par le manager (choix « équilibré ») : la préparation reste la sienne.
    const regler = m => { m = settleClubMeetings(m, jeu.call); for (const decision of m?.clubLife?.reprise?.due || []) m = jeu.call('reprise_decide', { decision, option: 'equilibre' }); return m; };
    let model = regler(jeu.call('new_career', { mode: 'world-champ', club, start: 'premiers-clubs' }));
    const nom = model.club?.name || String(club), arrets = [];
    for (let i = 0; i < 200; i++) {
      model = regler(model);
      const r = jeu.brut('advance_until_event', { fromDate: model.meta.calendarToday });
      if (!r.ok) { arrets.push({ date: model.meta.calendarToday, kind: 'refus', detail: r.error }); break; }
      model = r.model;
      const a = model.meta.advanceUntilEvent;
      arrets.push({ date: a.to || model.meta.calendarToday, kind: a.stop.kind, type: a.stop.type || null, detail: a.stop.detail });
      if (a.stop.kind === 'match') break;
      // Demande d'entretien d'un joueur : réponse la plus neutre, comme un joueur pressé.
      if (a.stop.kind === 'conversation') model = repondreEntretien(jeu, model);
    }
    const parType = {};
    for (const x of arrets) { const k = x.kind === 'info' ? 'info:' + x.type : x.kind; parType[k] = (parType[k] || 0) + 1; }
    return { club, nom, ligue: LIGUES[club] || '', total: arrets.filter(x => x.kind !== 'match').length, parType, arrets };
  } finally { jeu.fermer(); }
}

function repondreEntretien(jeu, model) {
  const scene = model.clubLife?.scenes?.active || model.clubLife?.sceneInvitations?.active;
  if (!scene) return model;
  const choix = scene.choices?.[0] || scene.options?.[0];
  if (!choix) return model;
  const r = jeu.brut('scene_answer', { sceneId: scene.id, choiceId: choix.id });
  return r.ok ? r.model : model;
}

const resultats = (clubs.length ? clubs : [0, 88, 102]).map(mesurer);
if (json) console.log(JSON.stringify(resultats.map(({ arrets, ...r }) => r)));
else for (const r of resultats) {
  console.log(`\n${r.nom} (${r.ligue}) : ${r.total} arrêts avant le 1er match`);
  console.log('  ' + Object.entries(r.parType).map(([k, n]) => k + ' ' + n).join(' · '));
  for (const a of r.arrets) console.log(`  ${a.date}  ${a.kind}${a.type ? ':' + a.type : ''}  ${String(a.detail).slice(0, 110)}`);
}
