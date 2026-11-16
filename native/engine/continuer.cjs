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
  // Décisions de la préparation (reprise.cjs) : le jour dû, « Continuer » s'arrête ; tant qu'elles ne sont pas
  // prises ou confiées à Gabi, il refuse de repartir (comme un rendez-vous). « Jour suivant » les confie au staff.
  decision: { mandatory: true, label: 'Décision attendue' },
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
  offre: { mandatory: false, label: 'Offre pour un joueur' },
  fatigue: { mandatory: false, label: 'Gabi : titulaires fatigués' },
  reprise: { mandatory: false, label: 'Reprise de l’entraînement' },
  // Éléments informatifs de la pré-saison (reprise.cjs, courrier en Réception) : arrêt sans réponse attendue ; un
  // nouvel appui sur Continuer repart. Tous les éléments du jour sont regroupés.
  a_noter: { mandatory: false, label: 'À noter' },
  // Moments de la saison sans décision (veille et lendemain de match, rapport médical, mi-saison, fin de phase,
  // marché, recruteur) : arrêts informatifs réglés par continuer-arrets.json, toujours actifs ; plusieurs le même jour
  // possibles (file du jour, voir arrets()). Libellé de l'arrêt : celui du type (« Veille de match »…).
  info: { mandatory: false, label: 'À savoir' },
  message: { mandatory: false, label: 'Nouveau message' },
  ouverture: { mandatory: false, label: 'Ouverture de la saison' },
  limite: { mandatory: true, label: 'Pause' },
  arret: { mandatory: true, label: 'Avance arrêtée' },
});
const MAX_DAYS = 120;
// Réglage des arrêts informatifs de la saison (types, priorité, seuils) : données, pas code.
const ARRETS = require('./continuer-arrets.json');
const MESSAGE_MODES = ['importants', 'tous', 'aucun'];
// Pas de niveaux (décision de Léo, 16/11/2026) : tous les éléments informatifs arrêtent l'avance ; le joueur ne
// choisit que les messages et les blessures. L'ancien réglage `stops.flux` est encore accepté, et ignoré.
const NOTE_LABELS = { retour: 'retour des internationaux', amical: 'compte rendu de match amical', stage: 'bilan du stage', recrutement: 'dernier point recrutement', veille: 'veille de la 1re journée' };
const INJURY_MODES = ['titulaires', 'effectif'];
// Messages de routine : ils restent dans la Réception mais n'arrêtent pas « Continuer » en mode « importants ».
const ROUTINE = [/^le point de la semaine/i, /^votre bureau est ouvert/i, /entra[iî]nement.*retenu/i, /^feuille pr[ée]par[ée]e/i,
  /^r[ée]sultats? de la journ[ée]e/i, /^journ[ée]e \d+/i, /^conf[ée]rence tenue par/i,
  // Éléments de pré-saison : ils ont leur propre arrêt « À noter ».
  /^(match amical|retour de tourn[ée]e|fin du stage|dernier point recrutement|veille de la 1re journ[ée]e)/i,
  // Rapport d'une mission de recrutement : arrêt informatif « Rapport de recruteur ».
  /^rapport de recrutement disponible/i];

// Lecture des signaux dans la VM : état seul, aucune écriture. Évaluée avant la boucle puis après chaque jour.
const SIGNAL_SOURCE = `(function(){
 const MEDICAL_WEEKS=${Number(ARRETS.types.medical.semainesMin) || 4};
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
 return {today,matchReady:!!d?.matchReady,canAdvance:d?d.canAdvance!==false:false,ended:s.phase==='ended',live:!!s.live&&!(d?.resultConfirmed===true),
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
  offers:(s.economy?.offers||[]).map(o=>({id:String(o.id),player:byId.get(o.playerId)?.name||''})),
  decisions:typeof CDReprise!=='undefined'?CDReprise.due(s):[],
  decisionNext:typeof CDReprise!=='undefined'?CDReprise.nextDecision(s):null,
  notes:typeof CDReprise!=='undefined'?CDReprise.notesSeen(s):[],
  notesNext:typeof CDReprise!=='undefined'?CDReprise.nextNotes(s):[],
  preseason:!!pre,
  courrier:(()=>{try{return nativeSystems.domain('clubMail').stops(s);}catch(e){return [];}})(),
  ...(world&&today?saison(s,today,fixtures,next,name,byId,players):{})};
 // Faits de la saison pour les arrêts informatifs (continuer-arrets.json) : lecture seule, calculés seulement les
 // jours où ils servent (veille, lendemain, mi-saison, fin de phase).
 function saison(s,today,fixtures,next,name,byId,players){
  const day=n=>new Date(Date.parse(today)+n*86400000).toISOString().slice(0,10),yesterday=day(-1),tomorrow=day(1);
  // Rencontre du club jouée : dans l'historique à la clôture de la semaine, dans S.live (terminée) avant.
  const hist=s.history||[],own=s.live&&s.live.finished&&Array.isArray(s.live.pair)?s.live:null;
  const resultOf=f=>hist.find(r=>r.fixtureId===f.id)||(own&&own.pair.includes(f.homeId)&&own.pair.includes(f.awayId)&&Array.isArray(own.score)?{pair:own.pair,score:own.score}:null);
  const lid=CDWorldCareer.leagueId(s);
  const standing=id=>{try{const r=CDWorldCareer.rows(s,id),i=r.findIndex(x=>x.clubId===s.club);return i<0?null:{rank:i+1,points:r[i].points,played:r[i].played,size:r.length};}catch(e){return null;}};
  const rankOf=(id,club)=>{try{const i=CDWorldCareer.rows(s,id).findIndex(x=>x.clubId===club);return i<0?null:i+1;}catch(e){return null;}};
  const form=club=>hist.filter(r=>Array.isArray(r.pair)&&r.pair.includes(club)).slice(-5).map(r=>{const i=r.pair.indexOf(club),a=r.score[i],b=r.score[1-i];return a>b?'V':a<b?'D':'N';}).join('');
  const out={round:s.round,season:s.season,leagueId:lid};
  const nf=next&&next.date===tomorrow?fixtures.find(f=>f.date===tomorrow):null;
  if(nf){
   const opp=nf.homeId===s.club?nf.awayId:nf.homeId,sheet=[...(s.lineup||[]),...(s.reserves||[])];
   out.veille={id:nf.id,opponent:name(opp),home:nf.homeId===s.club,competitionId:nf.competitionId,phase:nf.phase,
    sheet:sheet.length,sheetInjured:sheet.filter(id=>(byId.get(id)?.injury||0)>0).length,form:form(opp),
    rank:nf.phase==='league'?rankOf(nf.competitionId,opp):null,ownRank:nf.phase==='league'?rankOf(nf.competitionId,s.club):null};
  }
  const lf=fixtures.find(f=>f.date===yesterday),lr=lf?resultOf(lf):null;
  if(lr&&Array.isArray(lr.pair)){const i=lr.pair.indexOf(s.club);out.lendemain={id:lf.id,opponent:name(lr.pair[1-i]),home:i===0,us:lr.score[i],them:lr.score[1-i],injured:players.filter(p=>p.injury>0).length};}
  const league=fixtures.filter(f=>f.competitionId===lid&&f.phase==='league').sort((a,b)=>a.date<b.date?-1:a.date>b.date?1:0);
  const half=league.length>1?league[Math.ceil(league.length/2)-1]:null;
  if(half){out.halfDate=day(0)<=half.date?half.date:null;if(half.date===yesterday&&resultOf(half))out.miSaison={...(standing(lid)||{}),goal:s.clubs[s.club]?.goal||null,matches:league.length};}
  const phases={},w=s.worldMode;
  if(w.leagues?.[lid])phases[lid]={phase:w.leagues[lid].phase,champion:w.leagues[lid].champion!=null?name(w.leagues[lid].champion):null};
  for(const [id,cup]of Object.entries(w.europe||{}))if((cup.pools||[]).some(p=>p.includes(s.club)))phases[id]={phase:cup.phase,champion:cup.champion!=null?name(cup.champion):null};
  out.phases=phases;
  if(phases[lid]&&phases[lid].phase!=='league')out.standing=standing(lid);
  out.longInjured=players.filter(p=>p.injury>=MEDICAL_WEEKS).map(p=>p.id);
  out.injuryWeeks=Object.fromEntries(players.filter(p=>p.injury>=MEDICAL_WEEKS).map(p=>[p.id,p.injury]));
  const reports=s.manager?.reports||[];
  out.missions=(s.manager?.missions||[]).filter(m=>m.status==='done').map(m=>{const r=reports.filter(x=>x.mission===m.id);return {id:m.id,n:r.length,player:r[0]?.playerId!=null?String(r[0].playerId):null};});
  return out;
 }
})()`;

function options(payload = {}) {
  const stops = payload.stops ?? {};
  if (typeof stops !== 'object' || stops === null || Array.isArray(stops) || Object.keys(stops).some(k => !['messages', 'blessures', 'ignorer', 'flux'].includes(k)))
    throw Error('Réglages d’arrêt invalides.');
  const messages = stops.messages ?? 'importants', blessures = stops.blessures ?? 'titulaires';
  if (!MESSAGE_MODES.includes(messages) || !INJURY_MODES.includes(blessures) || (stops.flux !== undefined && typeof stops.flux !== 'string')) throw Error('Réglages d’arrêt invalides.');
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
// Décisions de la préparation attendues (clés de reprise.cjs) : motif d'arrêt ou de refus, vu du manager.
const DECISION_TEXT = { amicaux: 'le programme des matchs amicaux', stage: 'l’orientation du stage de préparation' };
function decisionText(keys) {
  const what = (keys || []).map(k => DECISION_TEXT[k] || 'une décision de préparation');
  if (!what.length) return '';
  return 'Gabi attend ' + what.join(' et ') + ' : choisissez dans « La reprise » ou confiez-' + (what.length > 1 ? 'les' : 'la') + '-lui.';
}
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
    ['decision', () => added(before.decisions || [], after.decisions || []).length && decisionText(after.decisions)],
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
    ['offre', () => { const known = new Set((before.offers || []).map(o => o.id)), fresh = (after.offers || []).filter(o => !known.has(o.id));
      return fresh.length && (fresh.length > 1 ? fresh.length + ' offres reçues pour vos joueurs.' : 'Offre reçue pour ' + (fresh[0].player || 'un de vos joueurs') + '.'); }],
    ['fatigue', () => {
      const tired = added(before.tired, after.tired);
      if (!tired.length || !after.next) return false;
      const days = Math.round((Date.parse(after.next.date) - Date.parse(after.today)) / 86400000);
      return days >= 0 && days <= 7 && (after.names[tired[0]] || 'Un titulaire') + ' est sous 70 % de condition avant le match du ' + shortDate(after.next.date) + '.';
    }],
    ['a_noter', () => {
      const fresh = added(before.notes || [], after.notes || []).map(id => id.split(':')[0]);
      if (!fresh.length) return false;
      // Tous les éléments arrivés ce jour-là sont cités (ils sont tous en Réception).
      const what = [...new Set(fresh)].map(k => NOTE_LABELS[k] || 'élément de préparation');
      return (fresh.length > 1 ? fresh.length + ' éléments en Réception : ' : 'En Réception : ') + what.join(', ') + '.';
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

// ------------------------------------------------------------------ arrêts informatifs de la saison
// Façon Football Manager : « Continuer » s'arrête aussi sur des moments sans décision, plusieurs fois le même jour
// si besoin. Tout vient de la lecture des signaux de la veille et du jour (aucune écriture : l'avance reste
// exactement N « Jour suivant ») ; chaque élément n'apparaît qu'au passage du jour où il se produit.
const TYPES = ARRETS.types;
const ordinal = n => n + (n === 1 ? 're' : 'e');
const phaseLabel = p => ARRETS.phases[p] || p;
const competitionLabel = (id, after) => ARRETS.competitions[id] || (id === after.leagueId ? 'Championnat' : id);
const pts = st => st && st.rank ? ordinal(st.rank) + (st.size ? ' sur ' + st.size : '') + ' (' + st.points + ' pts, ' + st.played + ' matchs)' : null;

// Éléments informatifs apparus entre `before` et `after` (tous les types, toujours actifs), triés par priorité :
// [{type, key, label, detail}]. Vide si l'arrêt « info » est ignoré.
function informatifs(before, after, settings = {}) {
  if (!before || !after || !after.today || before.today === after.today) return [];
  if ((settings.ignorer || []).includes('info')) return [];
  const allowed = new Set(Object.keys(TYPES)), out = [];
  const push = (type, key, detail, extra = {}) => { if (allowed.has(type) && detail) out.push({ type, key: type + ':' + key, label: TYPES[type].label, detail, ...extra }); };
  const v = after.veille;
  // Veille de la 1re journée déjà annoncée par la préparation (reprise.cjs, « À noter ») : pas en double.
  const preVeille = (after.notes || []).includes('veille:' + after.today);
  if (v && !preVeille && (!before.veille || before.veille.id !== v.id)) {
    const where = v.home ? 'réception de ' + v.opponent : 'déplacement à ' + v.opponent;
    const sheet = v.sheet >= 23 ? 'feuille de match complète (23)' : 'feuille de match à compléter (' + v.sheet + '/23)';
    const hurt = v.sheetInjured ? ', ' + v.sheetInjured + ' blessé' + (v.sheetInjured > 1 ? 's' : '') + ' à remplacer' : '';
    const rapport = [v.rank ? v.opponent + ' ' + ordinal(v.rank) + (v.ownRank ? ', nous ' + ordinal(v.ownRank) : '') : null, v.form ? 'forme ' + v.form.split('').join('-') : null].filter(Boolean).join(', ');
    push('veille', v.id, 'Demain, ' + where + ' : ' + sheet + hurt + '.' + (rapport ? ' Adversaire : ' + rapport + '.' : ''));
  }
  const l = after.lendemain;
  if (l && (!before.lendemain || before.lendemain.id !== l.id)) {
    const issue = l.us > l.them ? 'Victoire' : l.us < l.them ? 'Défaite' : 'Match nul';
    push('lendemain', l.id, issue + ' ' + l.us + '-' + l.them + (l.home ? ' contre ' : ' à ') + l.opponent + '. Infirmerie : ' + (l.injured ? l.injured + ' indisponible' + (l.injured > 1 ? 's' : '') : 'aucun indisponible') + '.');
  }
  const longs = added(before.longInjured || [], after.longInjured || []);
  if (longs.length) {
    const who = longs.map(id => (after.names?.[id] || 'Un joueur') + ' (' + (after.injuryWeeks?.[id] || '?') + ' sem.)');
    push('medical', longs.join(','), 'Absence longue : ' + who.slice(0, 3).join(', ') + (who.length > 3 ? ' et ' + (who.length - 3) + ' autres' : '') + '. Le staff médical détaille le protocole.');
  }
  for (const [id, now] of Object.entries(after.phases || {})) {
    const old = before.phases?.[id];
    if (!old || old.phase === now.phase) continue;
    const comp = competitionLabel(id, after);
    const own = id === after.leagueId && old.phase === 'league' ? pts(after.standing) : null;
    const suite = now.phase === 'ended' ? (now.champion ? now.champion + ' remporte le titre.' : 'Compétition terminée.') : 'Suite : ' + phaseLabel(now.phase) + '.';
    push('fin_phase', id + ':' + old.phase, comp + ' : fin de phase (' + phaseLabel(old.phase) + ')' + (own ? ', nous terminons ' + own : '') + '. ' + suite);
  }
  const m = after.miSaison;
  if (m && !before.miSaison) push('mi_saison', String(after.season), 'Mi-saison : ' + (pts(m) || 'classement en cours') + (m.goal ? '. Objectif de la direction : ' + m.goal.charAt(0).toLowerCase() + m.goal.slice(1) : '') + '.');
  const mercato = TYPES.mercato;
  if (mercato && after.round !== before.round && Number.isInteger(after.round)) {
    const ahead = mercato.semainesAvant ?? 1;
    if ((mercato.semaines || []).includes(after.round + ahead)) push('mercato', after.season + ':' + (after.round + ahead), 'Les clubs bougent sur le marché dans ' + (ahead > 1 ? ahead + ' semaines' : 'une semaine') + ' : derniers jours pour boucler vos dossiers dans Recrutement.');
  }
  const known = new Set((before.missions || []).map(x => x.id));
  for (const x of (after.missions || []).filter(x => !known.has(x.id)))
    push('recruteur', x.id, x.n ? x.n + ' profil' + (x.n > 1 ? 's' : '') + ' proposé' + (x.n > 1 ? 's' : '') + ' par votre recruteur, à comparer dans Recrutement.' : 'Mission terminée : aucun profil ne correspond à tous les critères.', x.player ? { joueur: x.player } : {});
  // Courrier du club qui attend une réponse ou compte (club-mail.cjs) : un arrêt par mail, l'écran s'ouvre sur lui.
  const lus = new Set((before.courrier || []).map(x => x.id));
  for (const c of (after.courrier || []).filter(x => !lus.has(x.id)))
    push('courrier', c.id, c.expediteur + ' : ' + c.sujet, { mail: c.id, ...(c.joueur ? { joueur: c.joueur } : {}) });
  return out.sort((a, b) => TYPES[a.type].priorite - TYPES[b.type].priorite || (a.key < b.key ? -1 : a.key > b.key ? 1 : 0));
}

// Écran utile ouvert par l'interface sur cet arrêt (continuer-arrets.json, « ecran ») ; mail ou joueur concerné.
const infoStop = item => ({ kind: 'info', label: item.label, detail: item.detail, type: item.type, ...(TYPES[item.type]?.ecran ? { ecran: TYPES[item.type].ecran } : {}),
  ...(item.mail ? { mail: item.mail } : {}), ...(item.joueur ? { joueur: item.joueur } : {}) });
// Arrêts du jour : l'arrêt principal (detect) puis les éléments informatifs, au plus `maxParJour` ; au-delà, le
// dernier arrêt regroupe le reste. Rend {stop, queue} : `queue` = arrêts suivants du même jour, montrés à chaque
// nouvel appui sur Continuer sans avancer (worker.cjs).
function arrets(before, after, settings, repriseDate = null) {
  const primary = detect(before, after, settings, repriseDate);
  if (primary && primary.kind === 'blocage' && !after) return { stop: primary, queue: [] };
  const items = informatifs(before, after, settings);
  const max = Math.max(1, ARRETS.maxParJour || 1), room = max - (primary ? 1 : 0);
  let infos = items.map(infoStop);
  if (infos.length > room) {
    if (room <= 0) infos = [];
    else {
      const rest = items.slice(room - 1);
      infos = [...infos.slice(0, room - 1), { kind: 'info', label: STOPS.info.label, detail: rest.map(i => i.label + ' : ' + i.detail).join(' · '), type: 'groupe', ecran: 'Réception' }];
    }
  }
  const all = primary ? [primary, ...infos] : infos;
  return { stop: all[0] || null, queue: all.slice(1) };
}

// Prochain arrêt PRÉVISIBLE depuis l'état du jour (pour le panneau « Continuer ») : le premier de la rencontre du
// club (jour de match), de la reprise de l'entraînement et d'un rendez-vous déjà en file (le jour suivant).
// Les arrêts imprévisibles (blessure, courrier, message) ne comptent pas : ils interrompent sans prévenir.
// Rend {kind, date, opponent|detail} ou null.
function plan(after, repriseDate = null, ignorer = []) {
  if (!after || !after.today) return null;
  const candidates = [], ign = Array.isArray(ignorer) ? ignorer : [];
  // Arrêts informatifs prévisibles de la saison : veille du prochain match, lendemain du match de mi-saison.
  if (!ign.includes('info')) {
    const types = new Set(Object.keys(TYPES)), shift = (iso, n) => new Date(Date.parse(iso) + n * 86400000).toISOString().slice(0, 10);
    const eve = after.next ? shift(after.next.date, -1) : null;
    const preVeille = (after.notesNext || []).some(n => n.kind === 'veille' && n.date === eve);
    if (types.has('veille') && eve && eve > after.today && !preVeille) candidates.push({ kind: 'info', date: eve, detail: 'veille du match contre ' + after.next.opponent });
    if (types.has('mi_saison') && after.halfDate) { const d = shift(after.halfDate, 1); if (d > after.today) candidates.push({ kind: 'info', date: d, detail: 'mi-saison' }); }
  }
  if (after.next && after.next.date >= after.today) candidates.push({ kind: 'match', date: after.next.date, opponent: after.next.opponent });
  // Une décision due le jour de la reprise passe avant elle (tri stable).
  if (after.decisionNext && after.decisionNext.date > after.today) candidates.push({ kind: 'decision', date: after.decisionNext.date, detail: after.decisionNext.detail });
  const note = ign.includes('a_noter') ? null : (after.notesNext || []).find(n => n.date > after.today);
  if (note) candidates.push({ kind: 'a_noter', date: note.date, detail: NOTE_LABELS[note.kind] || 'élément de préparation' });
  if (repriseDate && repriseDate > after.today) candidates.push({ kind: 'reprise', date: repriseDate });
  if (after.meeting && !after.meeting.completed) {
    const label = ({ press: 'Conférence de presse', medical: 'Point médical', board: 'Rendez-vous avec la direction' })[after.meeting.kind] || 'Rendez-vous du club';
    candidates.push({ kind: 'rendez_vous', date: new Date(Date.parse(after.today) + 86400000).toISOString().slice(0, 10), detail: label });
  }
  candidates.sort((a, b) => (a.date < b.date ? -1 : a.date > b.date ? 1 : 0));
  return candidates[0] || null;
}

module.exports = { plan, STOPS, MAX_DAYS, MESSAGE_MODES, INJURY_MODES, ARRETS, SIGNAL_SOURCE, validate, detect, informatifs, arrets, routine, decisionText };
