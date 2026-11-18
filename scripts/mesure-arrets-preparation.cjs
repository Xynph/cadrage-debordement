'use strict';
// Mesure : combien de fois « Continuer » s'arrête entre la création d'une carrière Monde (départ par défaut,
// « Reprise des premiers clubs », 13/07) et le jour du 1er match officiel, réglages d'arrêt par défaut du jeu.
// Chaque appui sur Continuer qui rend la main au joueur compte pour un arrêt (y compris les arrêts suivants du
// même jour). Les rendez-vous sont réglés au plus neutre ; les décisions de préparation sont prises (« équilibré »).
//
//   node scripts/mesure-arrets-preparation.cjs [club …]      (défaut : 0 Top 14, 88 Nationale, 102 Champ Rugby)
//   --journees N : après le 1er match, continue jusqu'à N matchs officiels du club (match délégué, résultat confirmé,
//                  conférence d'après-match répondue = arrêt 'presse-apres-match'). Défaut 0 : s'arrête au 1er match.
//   --json : sortie JSON seule (pour comparer avant / après).
const Monde = require('../tests/helpers/carriere-monde.cjs');
const { settleClubMeetings } = require('../tests/helpers/club-meetings.cjs');

const args = process.argv.slice(2), json = args.includes('--json');
const iJ = args.indexOf('--journees'), JOURNEES = iJ >= 0 ? Number(args[iJ + 1]) || 0 : 0;
const clubs = args.filter((a, i) => /^\d+$/.test(a) && (iJ < 0 || i !== iJ + 1)).map(Number);
const estPresse = x => x.kind === 'presse-apres-match' || ((x.kind === 'conference' || x.kind === 'rendez_vous') && /presse|conf[ée]rence/i.test(String(x.detail)));
const LIGUES = { 0: 'Top 14', 88: 'Nationale', 102: 'Champ Rugby' };

function mesurer(club) {
  const jeu = Monde.ouvrir();
  try {
    // Décisions de la préparation prises par le manager (choix « équilibré ») : la préparation reste la sienne.
    const regler = m => { m = settleClubMeetings(m, jeu.call); for (const decision of m?.clubLife?.reprise?.due || []) m = jeu.call('reprise_decide', { decision, option: 'equilibre' }); return m; };
    let model = regler(jeu.call('new_career', { mode: 'world-champ', club, start: 'premiers-clubs' }));
    const nom = model.club?.name || String(club), arrets = [];
    let matchs = 0, presseAvant1erMatch = null;
    for (let i = 0; i < 200 + 400 * JOURNEES; i++) {
      model = regler(model);
      const r = jeu.brut('advance_until_event', { fromDate: model.meta.calendarToday });
      if (!r.ok) { arrets.push({ date: model.meta.calendarToday, kind: 'refus', detail: r.error }); break; }
      model = r.model;
      const a = model.meta.advanceUntilEvent;
      arrets.push({ date: a.to || model.meta.calendarToday, kind: a.stop.kind, type: a.stop.type || null, detail: a.stop.detail });
      if (a.stop.kind === 'match') {
        if (presseAvant1erMatch === null) presseAvant1erMatch = arrets.filter(estPresse).length;
        if (++matchs >= Math.max(JOURNEES, 1) || JOURNEES <= 0) break;
        // Joue le match du manager (délégué, résultat confirmé), puis répond à la conférence d'après-match si elle attend.
        try { model = Monde.jouerLeMatch(jeu, model); } catch (e) { arrets.push({ date: model.meta.calendarToday, kind: 'refus', detail: 'match : ' + e.message }); break; }
        const conf = model.clubLife?.press?.conference;
        if (conf?.available && conf.questions?.length) {
          const rp = jeu.brut('press_conference', { context: model.clubLife.press.context, answers: conf.questions.map(q => ({ questionId: q.id, answerId: q.answers[0].id })), ...(typeof conf.invitationId === 'string' ? { invitationId: conf.invitationId } : {}) });
          if (!rp.ok) { arrets.push({ date: model.meta.calendarToday, kind: 'refus', detail: rp.error }); break; }
          model = rp.model;
          arrets.push({ date: model.meta.calendarToday, kind: 'presse-apres-match', type: null, detail: 'Conférence d\'après-match répondue' });
        }
        continue;
      }
      // Demande d'entretien d'un joueur : réponse la plus neutre, comme un joueur pressé.
      if (a.stop.kind === 'conversation') model = repondreEntretien(jeu, model);
    }
    const parType = {};
    for (const x of arrets) { const k = x.kind === 'info' ? 'info:' + x.type : x.kind; parType[k] = (parType[k] || 0) + 1; }
    const presseSurNJournees = arrets.filter(estPresse).length;
    return { club, nom, ligue: LIGUES[club] || '', total: arrets.filter(x => x.kind !== 'match').length, presseAvant1erMatch: presseAvant1erMatch ?? presseSurNJournees, presseSurNJournees, parType, arrets };
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
  console.log(`\n${r.nom} (${r.ligue}) : ${r.total} arrêts ${JOURNEES > 0 ? 'sur ' + JOURNEES + ' journée(s)' : 'avant le 1er match'} · presse : ${r.presseAvant1erMatch} avant le 1er match` + (JOURNEES > 0 ? `, ${r.presseSurNJournees} au total` : ''));
  console.log('  ' + Object.entries(r.parType).map(([k, n]) => k + ' ' + n).join(' · '));
  for (const a of r.arrets) console.log(`  ${a.date}  ${a.kind}${a.type ? ':' + a.type : ''}  ${String(a.detail).slice(0, 110)}`);
}
