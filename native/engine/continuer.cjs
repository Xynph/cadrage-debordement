'use strict';
// « Continuer » façon Football Manager (friction n°1 de l'audit de consolidation, 14/11/2026) : la commande
// `advance_until_event` avance la carrière jour après jour, dans le moteur, jusqu'au prochain événement qui
// mérite l'attention du joueur, puis s'arrête et dit pourquoi.
//
// Chaque jour est EXACTEMENT un « Jour suivant » (`advance_day`) : mêmes gardes, même code, mêmes observations
// (presse, rendez-vous, connaissance, profondeur pro, attributs), même sérialisation et même validation stricte.
// Seuls la projection du modèle pour l'interface (0,5 à 1,3 s par jour mesurés) et l'écriture atomique du profil
// (0,2 à 0,4 s) sont faites une seule fois, à l'arrêt : c'est là que se trouvait l'essentiel du coût d'un jour
// sans événement. La projection d'un jour n'a qu'un effet d'état connu (courrier de changement de date d'une
// rencontre, calendar-mail) ; tout changement des rencontres du club est donc un arrêt obligatoire, et la
// projection finale l'observe comme l'aurait fait le dernier « Jour suivant ».
//
// Ce module ne contient que la lecture des signaux (dans la VM) et la règle d'arrêt (pure) ; la boucle et la
// sauvegarde sont dans worker.cjs (advanceUntilEvent).

// Liste des événements « arrêt ». `mandatory` : jamais désactivable (un match ou une décision obligatoire n'est
// jamais sauté ; le moteur refuserait de toute façon d'avancer). Les autres sont réglables par le joueur
// (préférences « Continuer s'arrête aussi sur »), sans surcharger : messages et étendue des blessures.
const STOPS = Object.freeze({
  match: { mandatory: true, label: 'Jour de match' },
  rendez_vous: { mandatory: true, label: 'Rendez-vous obligatoire' },
  // Conférence de presse : avec le réglage « Conférences ordinaires : envoyer l'adjoint », Gabi tient la conférence
  // ordinaire dans le moteur dès son ouverture (press.cjs autoDelegate, même commande que le jour avancé) : elle
  // n'arrête donc plus l'avance, et son compte rendu (« Conférence tenue par Gabi ») est un message de routine. Les
  // grands moments (arrivée, phase finale, bilan, derby, crise) restent un arrêt obligatoire.
  conference: { mandatory: true, label: 'Conférence de presse obligatoire' },
  conversation: { mandatory: true, label: 'Un joueur demande à vous parler' },
  calendrier: { mandatory: true, label: 'Calendrier modifié' },
  blocage: { mandatory: true, label: 'Avance impossible' },
  invitation: { mandatory: false, label: 'Invitation de presse' },
  international: { mandatory: false, label: 'Courrier international' },
  blessure: { mandatory: false, label: 'Blessure' },
  effectif: { mandatory: false, label: 'Mouvement dans l’effectif' },
  marche: { mandatory: false, label: 'Fenêtre des transferts' },
  fatigue: { mandatory: false, label: 'Gabi : titulaires fatigués' },
  reprise: { mandatory: false, label: 'Reprise de l’entraînement' },
  message: { mandatory: false, label: 'Nouveau message' },
  ouverture: { mandatory: false, label: 'Ouverture de la saison' },
  limite: { mandatory: true, label: 'Pause' },
  arret: { mandatory: true, label: 'Avance arrêtée' },
});
const MAX_DAYS = 120;
const MESSAGE_MODES = ['importants', 'tous', 'aucun'];
const INJURY_MODES = ['titulaires', 'effectif'];
// Messages de routine : ils restent dans la Réception mais n'arrêtent pas « Continuer » en mode « importants ».
const ROUTINE = [/^le point de la semaine/i, /^votre bureau est ouvert/i, /entra[iî]nement.*retenu/i, /^feuille pr[ée]par[ée]e/i,
  /^r[ée]sultats? de la journ[ée]e/i, /^journ[ée]e \d+/i, /^conf[ée]rence tenue par/i];

// Lecture des signaux dans la VM : état seul, aucune écriture. Évaluée avant la boucle puis après chaque jour.
const SIGNAL_SOURCE = `(function(){
 const s=typeof S==='undefined'?null:S;if(!s)return null;
 const d=nativeDailyStatus(),pre=typeof CDPreseason!=='undefined'?CDPreseason.pending(s):null;
 const world=typeof CDWorldCareer!=='undefined'&&CDWorldCareer.active(s);
 const today=pre?pre.today:world&&s.worldMode?.day!==undefined?CDWorldCareer.calendarToday(s):null;
 const club=s.clubs?.[s.club],players=club?.players||[],byId=new Map(players.map(p=>[p.id,p]));
 const starters=(s.lineup||[]).slice(0,15).map(id=>byId.get(id)).filter(Boolean);
 const cm=s.clubMeetings,meeting=cm?.current||cm?.queue?.[0]||null;
 let press=false;try{press=!!nativeSystems.domain('press').requiresConference();}catch(e){press=false;}
 const fixtures=world?(s.worldMode.fixtures||[]).filter(f=>f.homeId===s.club||f.awayId===s.club):[];
 const next=fixtures.filter(f=>today&&f.date>=today).sort((a,b)=>a.date<b.date?-1:a.date>b.date?1:0)[0]||null;
 const name=id=>s.clubs?.[id]?.name||'';
 return {today,matchReady:!!d?.matchReady,canAdvance:d?d.canAdvance!==false:false,ended:s.phase==='ended',live:!!s.live,
  meeting:meeting&&!meeting.completed?{kind:meeting.kind,id:meeting.id}:meeting?{kind:meeting.kind,id:meeting.id,completed:true}:null,press,
  pressIds:(s.pressInvitations?.entries||[]).filter(e=>e.status==='pending').map(e=>e.id),
  pressDelegated:(()=>{const d=s.pressDelegation?.delegated||[],e=d[d.length-1];return e?e.season+':'+e.week+':'+e.club:null;})(),
  sceneActive:s.sceneInvitations?.activeId||null,
  sceneIds:(s.sceneInvitations?.invitations||[]).filter(e=>e.status==='pending').map(e=>e.id),
  serial:s.manager?.serial??0,
  inbox:(s.manager?.inbox||[]).slice(0,12).map(m=>({n:Number(String(m.id).slice(4))||0,title:String(m.title||''),kind:String(m.kind||'')})),
  national:(s.national?.mail||[]).map(m=>m.id),
  nationalTitles:Object.fromEntries((s.national?.mail||[]).slice(-12).map(m=>[m.id,String(m.title||'')])),
  fixtures:fixtures.map(f=>f.id+'@'+f.date).join('|'),
  next:next?{date:next.date,opponent:name(next.homeId===s.club?next.awayId:next.homeId)}:null,
  starters:starters.map(p=>p.id),
  injured:players.filter(p=>p.injury>0).map(p=>p.id),
  names:Object.fromEntries(players.filter(p=>p.injury>0||(p.condition??100)<70).map(p=>[p.id,p.name])),
  tired:starters.filter(p=>(p.condition??100)<70).map(p=>p.id),
  squad:players.map(p=>p.id).sort().join(','),
  window:s.economy?.aiRecruitmentWindow??null,
  preseason:!!pre};
})()`;

function options(payload = {}) {
  const stops = payload.stops ?? {};
  if (typeof stops !== 'object' || stops === null || Array.isArray(stops) || Object.keys(stops).some(k => !['messages', 'blessures', 'ignorer'].includes(k)))
    throw Error('Réglages d’arrêt invalides.');
  const messages = stops.messages ?? 'importants', blessures = stops.blessures ?? 'titulaires';
  if (!MESSAGE_MODES.includes(messages) || !INJURY_MODES.includes(blessures)) throw Error('Réglages d’arrêt invalides.');
  // Arrêts facultatifs ignorés (outils, essais, réglage avancé) : jamais un arrêt obligatoire.
  const ignorer = stops.ignorer ?? [];
  if (!Array.isArray(ignorer) || ignorer.length > 20 || ignorer.some(k => !STOPS[k] || STOPS[k].mandatory)) throw Error('Arrêt obligatoire ou inconnu : il ne peut pas être ignoré.');
  return { messages, blessures, ignorer: [...new Set(ignorer)] };
}

function validate(payload) {
  if (typeof payload !== 'object' || payload === null || Array.isArray(payload)) throw Error('Paramètres d’avance invalides.');
  const allowed = ['fromDate', 'maxDays', 'budgetMs', 'partial', 'stop', 'stops'];
  if (Object.keys(payload).some(k => !allowed.includes(k))) throw Error('Paramètres d’avance invalides.');
  if (typeof payload.fromDate !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(payload.fromDate)) throw Error('Date de départ invalide.');
  const maxDays = payload.maxDays ?? MAX_DAYS;
  if (!Number.isSafeInteger(maxDays) || maxDays < 1 || maxDays > MAX_DAYS) throw Error('Nombre de jours invalide (1 à ' + MAX_DAYS + ').');
  const budgetMs = payload.budgetMs ?? 0;
  if (!Number.isFinite(budgetMs) || budgetMs < 0 || budgetMs > 60000) throw Error('Budget de temps invalide.');
  for (const k of ['partial', 'stop']) if (payload[k] !== undefined && typeof payload[k] !== 'boolean') throw Error('Paramètres d’avance invalides.');
  return { fromDate: payload.fromDate, maxDays, budgetMs, partial: payload.partial === true, stop: payload.stop === true, ...options(payload) };
}

const routine = title => ROUTINE.some(r => r.test(title));
const added = (before, after) => after.filter(id => !before.includes(id));
const shortDate = iso => { const [y, m, d] = iso.split('-'); return d + '/' + m; };

// Règle d'arrêt après un jour : premier événement trouvé, dans l'ordre de priorité (obligatoires d'abord). Un arrêt
// facultatif listé dans `settings.ignorer` est sauté. `repriseDate` : jour de reprise de l'entraînement du club.
function detect(before, after, settings, repriseDate = null) {
  if (!after) return { kind: 'blocage', label: STOPS.blocage.label, detail: 'Aucune carrière.' };
  const ignored = new Set(settings.ignorer || []);
  const checks = [
    ['match', () => after.matchReady && (after.next ? 'Rencontre contre ' + after.next.opponent + ' aujourd’hui.' : 'Rencontre prévue aujourd’hui.')],
    ['rendez_vous', () => after.meeting && !after.meeting.completed && (({ press: 'Conférence de presse', medical: 'Point médical', board: 'Rendez-vous avec la direction' })[after.meeting.kind] || 'Rendez-vous du club')],
    ['conference', () => after.press && 'La presse vous attend avant de continuer.'],
    ['conversation', () => (after.sceneActive || added(before.sceneIds, after.sceneIds).length) && 'Une demande d’entretien vous attend en Réception.'],
    ['calendrier', () => after.fixtures !== before.fixtures && 'Une rencontre du club a été ajoutée ou déplacée.'],
    ['blocage', () => (after.ended || after.live || !after.canAdvance) && (after.ended ? 'La saison est terminée.' : 'Le moteur n’autorise pas le jour suivant.')],
    ['invitation', () => added(before.pressIds, after.pressIds).length && 'Une invitation de presse est arrivée en Réception.'],
    ['international', () => { const intl = added(before.national, after.national); return intl.length && (after.nationalTitles[intl[0]] || 'Un courrier international est arrivé.'); }],
    ['blessure', () => {
      const pool = settings.blessures === 'effectif' ? null : new Set(after.starters);
      const hurt = added(before.injured, after.injured).filter(id => !pool || pool.has(id));
      return hurt.length && (after.names[hurt[0]] || 'Un joueur') + (hurt.length > 1 ? ' et ' + (hurt.length - 1) + ' autre' + (hurt.length > 2 ? 's' : '') : '') + (hurt.length > 1 ? ' blessés' : ' blessé') + (pool ? ' (titulaire' + (hurt.length > 1 ? 's' : '') + ').' : '.');
    }],
    ['effectif', () => after.squad !== before.squad && 'Un joueur est arrivé ou a quitté le club.'],
    ['marche', () => after.window !== before.window && after.window !== null && 'Les clubs ont bougé sur le marché des transferts.'],
    ['fatigue', () => {
      const tired = added(before.tired, after.tired);
      if (!tired.length || !after.next) return false;
      const days = Math.round((Date.parse(after.next.date) - Date.parse(after.today)) / 86400000);
      return days >= 0 && days <= 7 && (after.names[tired[0]] || 'Un titulaire') + ' est sous 70 % de condition avant le match du ' + shortDate(after.next.date) + '.';
    }],
    ['reprise', () => repriseDate && after.today === repriseDate && before.today !== repriseDate && 'Le groupe reprend l’entraînement aujourd’hui.'],
    ['ouverture', () => before.preseason && !after.preseason && 'Le calendrier de la saison est ouvert.'],
    ['message', () => {
      if (settings.messages === 'aucun' || !(after.serial > before.serial)) return false;
      const fresh = after.inbox.filter(m => m.n > before.serial && (settings.messages === 'tous' || !routine(m.title)));
      return fresh.length && (fresh[fresh.length - 1].title || 'Nouveau message en Réception.');
    }],
  ];
  for (const [kind, check] of checks) {
    if (ignored.has(kind) && !STOPS[kind].mandatory) continue;
    const detail = check();
    if (detail) return { kind, label: STOPS[kind].label, detail, ...(kind === 'rendez_vous' ? { meeting: after.meeting.kind } : {}) };
  }
  return null;
}

module.exports = { STOPS, MAX_DAYS, MESSAGE_MODES, INJURY_MODES, SIGNAL_SOURCE, validate, detect, routine };
