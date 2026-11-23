'use strict';
// Courrier du club, façon Football Manager (décision de Léo, 16/11/2026) : chaque jour de la carrière Monde, des
// interlocuteurs du club (kiné, capitaine, adjoint, recruteur, agent, presse, président, commission…) écrivent au
// manager. Contenu en données (club-mail.json) : types, expéditeurs, formulations, réponses, effets, seuils, cadence.
//
// Règles :
//  - Recevoir un mail ne change rien au monde. La génération lit l'état et n'écrit que la boîte (S.clubMail) ; le
//    choix d'une formulation ou d'une variante vient d'une empreinte (date, club, type, sujet), jamais du flux de
//    hasard du moteur.
//  - Seule la réponse du manager a un effet : commande `club_mail_reply` {id, choice}, une décision comme les autres
//    (choix « deleguer » : l'adjoint Gabi répond à sa place, voir adjoint()),
//    notée au journal d'actions (#762) et rejouée à l'identique. Les effets passent par les mécaniques existantes
//    (moral, confiance de la direction, relations presse, satisfaction, promesse de temps de jeu, charge physique,
//    séance collective, préparation collective, promotion d'un jeune, trésorerie) et restent mesurés.
//  - Cadence : plafond par jour, par catégorie et par semaine, intervalle par type, mémoire des sujets déjà écrits ;
//    chaque type a une nature (18/11/2026) : « action » (réponse attendue) arrête « Continuer » à lui seul ;
//    « info » est rangé dans l'arrêt d'info du jour (un seul par jour) ; « routine » n'arrête jamais à lui seul
//    (continuer.cjs). Rien ne disparaît : tout reste en Réception.
const DATA = require('./club-mail.json');
const files = Object.freeze([]), commands = Object.freeze(['club_mail_reply']);
// Données injectées dans la VM avant les domaines (native-systems.cjs, bootstrap).
const prelude = 'const nativeClubMailData=JSON.parse(' + JSON.stringify(JSON.stringify(DATA)) + ');';

function factory() {
  const D = typeof nativeClubMailData !== 'undefined' ? nativeClubMailData : { types: {}, cadence: {}, categories: {} };
  const C = D.cadence || {}, TYPES = D.types || {}, BL = D.blessures || {};
  const DAY = 86400000;
  const copy = x => JSON.parse(JSON.stringify(x)), obj = x => !!x && typeof x === 'object' && !Array.isArray(x);
  const int = (x, a, b) => Number.isSafeInteger(x) && x >= a && x <= b;
  const date = x => typeof x === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(x);
  const text = (x, max = 200) => typeof x === 'string' && x.length <= max && !/[\u0000-\u001f]/.test(x);
  const check = (ok, message) => { if (!ok) throw Error('Courrier du club : ' + message + '.'); };
  const clampN = (n, a, b) => Math.max(a, Math.min(b, n));
  const shift = (iso, n) => new Date(Date.parse(iso + 'T00:00:00Z') + n * DAY).toISOString().slice(0, 10);
  const dow = iso => (new Date(iso + 'T00:00:00Z').getUTCDay() + 6) % 7; // 0 = lundi
  const monday = iso => shift(iso, -dow(iso));
  const dayNumber = iso => Math.floor(Date.parse(iso + 'T00:00:00Z') / DAY);
  const daysBetweenIso = (a, b) => dayNumber(b) - dayNumber(a);
  // Protocole commotion (club-support.cjs) : disponibilités, antécédents, avis du spécialiste.
  const commotionApi = () => typeof nativeSystems !== 'undefined' ? nativeSystems.domain('clubSupport')?.commotion || null : null;
  const shortDate = iso => iso.slice(8, 10) + '/' + iso.slice(5, 7);
  const euros = n => Math.round(n).toLocaleString('fr-FR').replace(/ | /g, ' ');
  const ordinal = n => n + (n === 1 ? 'er' : 'e');
  // Empreinte FNV-1a : formulations et variantes, sans toucher au flux de hasard du moteur.
  const hash = str => { let h = 2166136261; for (let i = 0; i < str.length; i++) { h ^= str.charCodeAt(i); h = Math.imul(h, 16777619) >>> 0; } return h >>> 0; };
  const pick = (list, seed) => Array.isArray(list) && list.length ? list[hash(seed) % list.length] : '';
  const world = s => !!s && typeof CDWorldCareer !== 'undefined' && CDWorldCareer.active(s) && s.worldMode?.day !== undefined;
  const pending = s => typeof CDPreseason !== 'undefined' && !!CDPreseason.pending(s);
  const todayOf = s => { try { return CDWorldCareer.calendarToday(s); } catch { return null; } };
  const STATUS = ['nouveau', 'repondu', 'classe', 'info'];
  const CAUSES = ['match', 'entrainement', 'rechute'];
  const fold = x => String(x || '').toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '');
  // Type de blessure (données « blessures ») : parmi ceux dont la durée couvre l'indisponibilité, au poids de la ligne,
  // par empreinte stable du joueur et du jour (aucun tirage dans le flux de hasard du moteur).
  function injuryKind(p, s, d) {
    const weeks = Number(p.injury) || 0, types = BL.types || {};
    const line = (BL.avants || []).some(w => fold(p.pos).includes(w)) ? 'avants' : 'arrieres';
    let pool = Object.entries(types).filter(([, t]) => weeks >= t.semaines[0] && weeks <= t.semaines[1] && (t.poids?.[line] ?? 1) > 0);
    if (!pool.length) pool = Object.entries(types).filter(([, t]) => (t.poids?.[line] ?? 1) > 0).sort((a, b) => Math.abs(a[1].semaines[1] - weeks) - Math.abs(b[1].semaines[1] - weeks)).slice(0, 1);
    if (!pool.length) return null;
    const total = pool.reduce((a, [, t]) => a + (t.poids?.[line] ?? 1), 0);
    let roll = hash('blessure:' + p.id + ':' + (s.season ?? 0) + ':' + d) % total;
    for (const [key, t] of pool) { roll -= t.poids?.[line] ?? 1; if (roll < 0) return key; }
    return pool[0][0];
  }
  // Après chaque commande et à chaque réception : type, cause et date des blessures nouvelles ; effacés à la guérison.
  function typeInjuries(s, d) {
    if (!s || !s.clubs || !date(d)) return;
    const own = s.clubs[s.club], news = Array.isArray(s.news) ? s.news.slice(0, 12).map(String) : [];
    for (const club of Object.values(s.clubs)) for (const p of club?.players || []) {
      if (!(p.injury > 0)) {
        // Guérison d'un joueur suivi par le médecin (réponse au bulletin) : tirage de rechute par empreinte stable,
        // au risque fixé par les réponses (données « blessures.rechute »).
        if (club === own && p.injuryRelapse !== undefined && relapses(p, s, d)) { p.injury = Math.max(1, Number(BL.rechute?.semaines) || 2); p.injuryCause = 'rechute'; p.injuryOrigin = { type: 'rechute', season: s.season ?? null, round: s.round ?? null }; p.injuryDate = d; delete p.injuryRelapse; continue; }
        if (p.injuryType !== undefined || p.injuryCause !== undefined || p.injuryOrigin !== undefined || p.injuryDate !== undefined || p.injuryRelapse !== undefined) { delete p.injuryType; delete p.injuryCause; delete p.injuryOrigin; delete p.injuryDate; delete p.injuryRelapse; }
        continue;
      }
      if (p.injuryType !== undefined) continue;
      const kind = injuryKind(p, s, d);
      if (!kind) continue;
      p.injuryType = kind; p.injuryDate = d;
      if (club === own) {
        // L'origine a été enregistrée sur la blessure quand elle est survenue (installHooks : match, entraînement,
        // reprise) ; le journal ne sert plus qu'aux blessures d'une ancienne sauvegarde, sans origine enregistrée.
        const origin = p.injuryOrigin;
        if (obj(origin) && CAUSES.includes(origin.type)) p.injuryCause = origin.type;
        else if (p.medicalV68?.stage === 'termine') p.injuryCause = 'rechute';
        else {
          const line = news.find(n => n.includes(String(p.name)) && /bless/i.test(n));
          if (line) p.injuryCause = /entra[iî]nement/i.test(line) ? 'entrainement' : 'match';
        }
      }
    }
  }
  // Risque de rechute (en %) d'un blessé : base des données tant qu'aucune réponse ne l'a modifié.
  const relapseRisk = p => clampN(Number.isFinite(p?.injuryRelapse) ? p.injuryRelapse : (Number(BL.rechute?.base) || 0), 0, 100);
  // Fragilité du joueur (fragilite.cjs) : le risque de rechute est modulé comme les autres risques de blessure.
  const relapseChance = p => clampN(Math.round(relapseRisk(p) * (typeof facteurFragilite === 'function' ? facteurFragilite(p) : 1)), 0, 100);
  const relapses = (p, s, d) => hash('rechute:' + p.id + ':' + (s.season ?? 0) + ':' + d) % 100 < relapseChance(p);
  // Effets médicaux réellement applicables à ce joueur (rechute, date de retour) : la même source sert au texte
  // affiché et à l'application, pour qu'aucune conséquence affichée ne soit détachée de ce qui se passe.
  function medicalEffects(e, p) {
    const out = {};
    if (!p || !(p.injury > 0)) return out;
    if (Number.isFinite(e.rechute) && e.rechute) { const before = relapseRisk(p), after = clampN(before + e.rechute, 0, 100); if (after !== before) out.rechute = { before, after }; }
    if (Number.isFinite(e.retour) && e.retour) { const weeks = Math.max(1, p.injury + e.retour); if (weeks !== p.injury) out.retour = { weeks, delta: weeks - p.injury }; }
    return out;
  }
  // Origine de la blessure dans le bulletin : entraînement, rechute, ou rencontre (adversaire nommé, domicile ou
  // extérieur, notre score d'abord) ; la rencontre est la dernière jouée au plus tard le jour de la blessure.
  function causeText(p, results, name, d) {
    const origin = obj(p.injuryOrigin) && CAUSES.includes(p.injuryOrigin.type) ? p.injuryOrigin : null;
    if (origin?.type === 'match') return matchCause(origin, results, name);
    if (origin && !p.injuryCause) p = { ...p, injuryCause: origin.type };
    if (p.injuryCause === 'entrainement') return "Il s'est blessé à l'entraînement, le " + shortDate(p.injuryDate) + '.';
    if (p.injuryCause === 'rechute') return "Il a rechuté à l'entraînement, le " + shortDate(p.injuryDate) + ', à son retour de blessure.';
    if (p.injuryCause !== 'match') return '';
    const r = [...results].filter(x => !x.date || x.date <= (p.injuryDate || d)).pop();
    if (!r) return 'Il est sorti touché lors du dernier match.';
    const opp = name(r.opp) || "l'adversaire";
    return 'Il est sorti touché ' + (r.home ? 'à domicile contre ' + opp : 'sur le terrain de ' + opp) + ' (' + r.us + '-' + r.them + (r.date ? ', le ' + shortDate(r.date) : '') + ').';
  }
  // Rencontre enregistrée sur la blessure (id de la rencontre, adversaire, lieu, score) : l'adversaire se nomme par
  // son identifiant dans la base du monde, puis par le nom gardé à la blessure (club hors base du championnat,
  // rencontre de coupe d'Europe ou amicale), puis par le résultat archivé de la même rencontre.
  function matchCause(o, results, name) {
    const archived = o.fixtureId ? results.find(x => x.fixtureId === o.fixtureId) : null;
    const opp = (o.opp !== undefined && o.opp !== null && name(o.opp)) || (typeof o.oppName === 'string' && o.oppName) || (archived && name(archived.opp)) || "l'adversaire";
    const home = typeof o.home === 'boolean' ? o.home : archived?.home;
    const us = Number.isFinite(o.us) ? o.us : archived?.us, them = Number.isFinite(o.them) ? o.them : archived?.them;
    const when = o.date || archived?.date;
    const where = home === undefined || o.neutral === true ? 'contre ' + opp : home ? 'à domicile contre ' + opp : 'sur le terrain de ' + opp;
    return 'Il est sorti touché ' + where + (Number.isFinite(us) && Number.isFinite(them) ? ' (' + us + '-' + them + (when ? ', le ' + shortDate(when) : '') + ')' : '') + '.';
  }
  const injuryLabel = key => BL.types?.[key]?.libelle || 'Blessure';
  const EFFECTS = ['moral', 'confiance', 'supporters', 'medias', 'pression', 'satisfaction', 'fatigue', 'condition', 'plan', 'entrainement', 'focus', 'promesse', 'promouvoir', 'caisse', 'suite', 'appel', 'contratDS', 'pret', 'consigneDS', 'orientation', 'a2r', 'reprise', 'rechute', 'retour', 'doublon', 'repos_liste', 'specialiste'];
  const ORIENTATION_LABELS = { equilibre: 'répartition proposée', installations: 'priorité aux installations', staff: 'priorité au staff', accueil: 'priorité à l’accueil' };
  const PLAN_LABELS = { repos: 'repos', normal: 'charge allégée', intense: 'charge intense', collective: 'séance collective' };
  const MODE_LABELS = { repos: 'récupération', normal: 'normal', intense: 'intense' };
  const FOCUS_LABELS = { aucune: 'aucune', conquete: 'conquête', defence: 'défense', pied: 'jeu au pied' };

  function blank() { return { version: 1, seq: 0, last: null, mails: [], sent: {}, suites: [], memo: { injured: [], squad: [], arrivals: {}, apps: {}, missions: [], pools: [], calendar: [], lastF: {}, lastType: {}, cartons: 0 } }; }
  function ensure(s) { if (!obj(s.clubMail)) s.clubMail = blank(); return s.clubMail; }

  // ------------------------------------------------------------------ faits du jour (lecture seule)
  function facts(s, d) {
    const club = s.clubs[s.club], players = club?.players || [], byId = new Map(players.map(p => [p.id, p]));
    const name = id => s.clubs?.[id]?.name || '';
    const own = (s.worldMode.fixtures || []).filter(f => f.homeId === s.club || f.awayId === s.club).sort((a, b) => a.date < b.date ? -1 : a.date > b.date ? 1 : 0);
    const hist = (s.history || []).filter(r => Array.isArray(r.pair) && Array.isArray(r.score));
    const mine = hist.filter(r => r.pair.includes(s.club));
    const results = mine.map(r => { const i = r.pair.indexOf(s.club); return { date: r.date || null, fixtureId: r.fixtureId || null, opp: r.pair[1 - i], home: i === 0, us: r.score[i], them: r.score[1 - i], stats: r.stats?.[i] || null, other: r.stats?.[1 - i] || null, phase: r.phase || null, season: r.season ?? s.season }; });
    // Rencontre jouée mais pas encore archivée (clôture de la semaine) : le direct terminé.
    const live = s.live && s.live.finished && Array.isArray(s.live.pair) && s.live.pair.includes(s.club) && Array.isArray(s.live.score) ? s.live : null;
    const resultFor = f => {
      const r = results.find(x => x.fixtureId === f.id);
      if (r) return r;
      if (live && live.pair.includes(f.homeId) && live.pair.includes(f.awayId)) { const i = live.pair.indexOf(s.club); return { date: f.date, fixtureId: f.id, opp: live.pair[1 - i], home: i === 0, us: live.score[i], them: live.score[1 - i], stats: live.stats?.[i] || null, other: live.stats?.[1 - i] || null, phase: f.phase, season: s.season }; }
      return null;
    };
    // Le résultat du direct terminé compte avant même la clôture de la semaine.
    if (live) { const f = own.filter(x => x.date <= d && live.pair.includes(x.homeId) && live.pair.includes(x.awayId) && !results.some(r => r.fixtureId === x.id)).pop(); if (f) results.push(resultFor(f)); }
    const outcome = r => r.us > r.them ? 'V' : r.us < r.them ? 'D' : 'N';
    const season = results.filter(r => r.season === s.season);
    const streak = kind => { let n = 0; for (let i = season.length - 1; i >= 0 && outcome(season[i]) === kind; i--) n++; return n; };
    const yesterday = shift(d, -1);
    const playedOn = day => { const f = own.find(x => x.date === day); const r = f ? resultFor(f) : null; return f && r ? { fixture: f, result: r } : null; };
    const next = own.find(f => f.date >= d && !resultFor(f)) || null;
    const lineup = (s.lineup || []).slice(0, 15).map(id => byId.get(id)).filter(Boolean);
    const sheet = new Set([...(s.lineup || []), ...(s.reserves || [])]);
    const opponent = f => f ? (f.homeId === s.club ? f.awayId : f.homeId) : null;
    const form = id => hist.filter(r => r.pair.includes(id)).slice(-5).map(r => { const i = r.pair.indexOf(id); return r.score[i] > r.score[1 - i] ? 'V' : r.score[i] < r.score[1 - i] ? 'D' : 'N'; }).join('-');
    const derby = id => {
      if (id === null || id === undefined) return false;
      if (typeof isDerby === 'function') return isDerby(s, s.clubs?.[s.club]?.id ?? s.club, s.clubs?.[id]?.id ?? id);
      const a = s.clubs?.[s.club]?.id ?? s.club, b = s.clubs?.[id]?.id ?? id, pair = [a, b].sort((x, y) => x < y ? -1 : x > y ? 1 : 0);
      const t = s.interclubWorld?.pairs?.[pair[0] + ':' + pair[1]]?.tension;
      return Number.isFinite(t) && t >= (D.seuilDerby ?? 60);
    };
    const lid = (() => { try { return CDWorldCareer.leagueId(s); } catch { return null; } })();
    const rows = () => { try { return CDWorldCareer.rows(s, lid) || []; } catch { return []; } };
    const mean = list => list.length ? list.reduce((a, b) => a + b, 0) / list.length : 0;
    return { s, d, club, players, byId, name, own, results, season, outcome, streak, yesterday, playedOn, next, lineup, sheet, opponent, form, derby, lid, rows, mean, dow: dow(d), hist };
  }

  const fatigueOf = p => Number(p.physicalLoad?.fatigue) || 0;
  const conditionOf = p => Math.round(Number(p.condition ?? 100));
  const captain = F => {
    let lead = null; try { lead = typeof CDRelationsV70 !== 'undefined' ? CDRelationsV70.leader(F.s) : null; } catch { lead = null; }
    if (!lead) lead = [...F.players].filter(p => !p.injury).sort((a, b) => (b.attributesV2?.leadership ?? 0) - (a.attributesV2?.leadership ?? 0) || String(a.id).localeCompare(String(b.id)))[0] || null;
    return lead;
  };
  const playerVars = p => ({ joueur: String(p.name || ''), poste: String(p.pos || ''), age: Number(p.age) || 0, note: Number(p.rating) || 0, matchs: Number(p.dev?.appearances) || 0, minutes: Number(p.dev?.minutes) || 0, parcours: parcours(Number(p.dev?.appearances) || 0) });
  const careerApps = p => (Array.isArray(p.dev?.history) ? p.dev.history.reduce((a, h) => a + (Number(h?.appearances) || 0), 0) : 0) + (Number(p.dev?.appearances) || 0);
  // Total jamais inférieur à celui déjà vu : l'historique de développement est tronqué à 12 saisons.
  const careerTotal = (p, seen) => Math.max(careerApps(p), Number(seen?.[p.id]) || 0);
  const parcours = n => n > 1 ? n + ' matchs disputés cette saison' : n === 1 ? 'un seul match disputé cette saison' : 'pas encore de match officiel cette saison';
  // Contexte du club joint à chaque courrier (textes plus riches) : classement, forme récente, prochain adversaire.
  const clubVars = F => {
    let classement = 'encore sans classement';
    try { const rows = F.rows(), i = rows.findIndex(r => r.clubId === F.s.club); if (i >= 0 && F.season.length) classement = ordinal(i + 1) + ' sur ' + rows.length + ' au classement'; } catch { /* classement indisponible */ }
    const forme = F.season.slice(-5).map(F.outcome).join('-') || 'aucun match joué';
    return { classement, forme, prochain: F.next ? F.name(F.opponent(F.next)) : 'notre prochain adversaire' };
  };

  // Bilan de la saison précédente du club du manager (s.jiff.results) -> variables du courrier de la ligue.
  // ------------------------------------------------------------------ mercato (docs/gdd/calendrier-mutations.md § 3 ter)
  // Période des mutations (vente-joueurs.json, `fenetres`) lue sur la date seule ; échos hors période, point hebdomadaire,
  // ouverture et dernière semaine pendant. Les accords prennent tous effet à la bascule de saison (lendemain de la fin
  // de période). Ce qui a déjà été annoncé est noté (memo.mercatoVus, ids préfixés par la saison) : ni répété d'un
  // courrier à l'autre, ni redonné en courrier individuel après la période.
  const MK = D.mercato || {};
  const VJ = () => typeof nativeVenteJoueurs !== 'undefined' && nativeVenteJoueurs && typeof nativeVenteJoueurs.fenetre === 'function' ? nativeVenteJoueurs : null;
  const dansPeriode = (md, p) => p.debut <= p.fin ? md >= p.debut && md <= p.fin : md >= p.debut || md <= p.fin;
  const periodesMutations = () => (VJ()?.REGLAGES?.fenetres?.periodes || []).filter(p => obj(p) && /^\d{2}-\d{2}$/.test(p.debut) && /^\d{2}-\d{2}$/.test(p.fin));
  // 'ouverte' {debut, fin} | 'fermee' {fin : prochaine fin de période} | null (pas de calendrier des mutations).
  function mercato(d) {
    const V = VJ(); if (!V || !date(d)) return null;
    const f = V.fenetre(d, V.REGLAGES); if (f.mode !== 'fenetres') return null;
    const md = d.slice(5), an = Number(d.slice(0, 4)), list = periodesMutations();
    if (!list.length) return null;
    const p = f.ouverte ? list.find(x => dansPeriode(md, x)) : null;
    if (p) return { ouverte: true, debut: (p.debut <= md ? an : an - 1) + '-' + p.debut, fin: (p.fin >= md ? an : an + 1) + '-' + p.fin };
    const fin = list.map(x => { const iso = an + '-' + x.fin; return iso >= d ? iso : (an + 1) + '-' + x.fin; }).sort()[0];
    return { ouverte: false, fin };
  }
  const dateLongue = iso => VJ()?.dateFr ? VJ().dateFr(iso) : shortDate(iso);
  const montant = n => VJ()?.euros ? VJ().euros(n) : euros(n) + ' €';
  const semaineMonde = s => Number.isInteger(s.worldMode?.week) ? s.worldMode.week : Number(s.round) || 0;
  const vuId = (s, id) => (s.season ?? 0) + ':' + id;
  const dejaVu = (st, s, id) => (st.memo.mercatoVus || []).includes(vuId(s, id));
  function voir(st, s, ids) {
    const vus = Array.isArray(st.memo.mercatoVus) ? st.memo.mercatoVus : [];
    for (const id of ids) { const k = vuId(s, id); if (!vus.includes(k)) vus.push(k); }
    st.memo.mercatoVus = vus.slice(-(MK.memoire ?? 600));
  }
  // Faits du mercato écrits par le moteur (calendrier-mutations.cjs : S.calendrierMutations.mercato.semaines) ;
  // absents ou d'une autre saison : rien.
  function faitsMercato(s, types) {
    const m = s.calendrierMutations?.mercato;
    if (!obj(m) || (m.saison !== undefined && m.saison !== s.season) || !obj(m.semaines)) return [];
    const wk = semaineMonde(s), out = [];
    for (const k of Object.keys(m.semaines).map(Number).filter(Number.isInteger).sort((a, b) => a - b)) {
      if (k > wk || !Array.isArray(m.semaines[k])) continue;
      // La date d'arrivée est dite une fois en fin de courrier : retirée de chaque ligne d'accord.
      m.semaines[k].forEach(x => { if (obj(x) && types.includes(x.type) && text(x.texte, 300) && x.texte) out.push({ id: 'm:' + k + ':' + hash(x.type + ':' + x.texte), texte: x.texte.replace(/\s*:\s*il arrivera le 1er juillet\.?$/, '.'), type: x.type, montant: Number(x.montant) || 0, semaine: k }); });
    }
    return out;
  }
  const parMontant = list => [...list].sort((a, b) => b.montant - a.montant || a.semaine - b.semaine || a.id.localeCompare(b.id));
  // Offres en cours pour les joueurs du club (mêmes offres que les courriers « offre_transfert »).
  function offresClub(s) {
    const e = s.economy, own = s.clubs?.[s.club]; if (!e || !own || !Array.isArray(e.offers)) return [];
    return e.offers.filter(o => o.expires >= e.week).map(o => {
      const p = own.players.find(x => x.id === o.playerId), b = s.clubs[o.buyer];
      return p && b ? { id: 'o:' + o.id, texte: b.name + ' propose ' + montant(o.fee) + ' pour ' + p.name + ' (' + p.pos + ')' } : null;
    }).filter(Boolean);
  }
  // Accords conclus par le club (ventes et achats), qui prennent effet à la bascule de saison.
  function accordsClub(s) {
    const list = Array.isArray(s.venteJoueurs?.accords) ? s.venteJoueurs.accords : [];
    return list.filter(a => obj(a) && a.clubId === s.club && text(a.id, 60)).map(a => ({ id: 'a:' + a.id,
      texte: a.sens === 'achat' ? String(a.joueur || 'Un joueur') + ' arrive de ' + String(s.clubs?.[a.seller]?.name || a.vendeur || 'un autre club') + ' pour ' + montant(a.fee || 0)
        : String(a.joueur || 'Un joueur') + ' part à ' + String(s.clubs?.[a.buyer]?.name || a.acheteur || 'un autre club') + ' pour ' + montant(a.fee || 0) + (a.imposee ? ' (décision du président)' : '') }));
  }
  // Section de liste d'un courrier : titre (vide s'il n'y a rien), lignes nom_a…, « et N autres ».
  function section(vars, nom, titre, items, max) {
    vars[nom] = items.length ? titre : '';
    'abcdef'.slice(0, max).split('').forEach((l, i) => { vars[nom + '_' + l] = items[i]?.texte || ''; });
    const n = items.length - max;
    vars[nom + '_plus'] = n > 0 ? 'et ' + n + ' autre' + (n > 1 ? 's' : '') : '';
  }
  const titre = (k, vars) => fill(MK.titres?.[k] || '', vars);
  const mercatoVars = (P, d) => ({ fin: dateLongue(P.fin), arrivee: dateLongue(shift(P.fin, 1)), semaine: shortDate(monday(d)) });

  const quotaLigue = (F, keep) => {
    const r = (F.s.jiff?.results || []).find(x => x.clubId === F.s.club && x.season === F.s.season - 1);
    if (!r || !keep(r)) return [];
    const ligue = { elite: 'le Top 14', accession: 'la Pro D2', prem: 'la Premiership' }[r.league] || 'ton championnat';
    const eqp = r.league === 'prem';
    return [{ key: 'quota:' + r.season, vars: { ligue, regle: eqp ? 'EQP' : 'JIFF', moyenne: String(r.average).replace('.', ','), objectif: eqp ? 15 : 16, points: r.deduction, montant: euros(r.fine || 0), prime: euros(r.bonus || 0), feuilles: r.sheets } }];
  };

  // ------------------------------------------------------------------ déclencheurs : [{key, vars, player?}]
  const T = {
    bilan_kine(F) {
      if (F.dow !== 0) return [];
      const hurt = F.players.filter(p => p.injury > 0).sort((a, b) => b.injury - a.injury);
      if (!hurt.length) return [];
      return [{ key: F.d, vars: { n: hurt.length, liste: hurt.slice(0, 4).map(p => p.name + ' (' + p.injury + ' sem.)').join(', ') + (hurt.length > 4 ? ' et ' + (hurt.length - 4) + ' autre(s)' : '') } }];
    },
    // Bulletin du médecin sur une blessure nouvelle : type, cause (rencontre ou entraînement), pronostic, conseil,
    // effet sur la prochaine rencontre et état de l'infirmerie.
    blessure(F) {
      const fresh = F.players.filter(p => p.injury > 0 && p.injuryType && date(p.injuryDate) && p.injuryDate >= F.yesterday).sort((a, b) => b.injury - a.injury || String(a.id).localeCompare(String(b.id)));
      const hurt = F.players.filter(p => p.injury > 0).sort((a, b) => b.injury - a.injury);
      return fresh.map(p => {
        const label = injuryLabel(p.injuryType), weeks = Number(p.injury) || 1;
        const cause = causeText(p, F.results, F.name, F.d);
        let impact = '';
        if (F.next) {
          const days = dayNumber(F.next.date) - dayNumber(F.d), opp = F.name(F.opponent(F.next));
          impact = weeks * 7 > days ? 'Il manquera le prochain match contre ' + opp + ' (' + shortDate(F.next.date) + ') : prévois son remplaçant dans la composition.' : 'Il devrait être rétabli pour le prochain match contre ' + opp + ' (' + shortDate(F.next.date) + ').';
        }
        const list = hurt.slice(0, 5).map(x => x.name + ' (' + injuryLabel(x.injuryType).toLowerCase() + ', ' + x.injury + ' sem.)').join(', ') + (hurt.length > 5 ? ' et ' + (hurt.length - 5) + ' autre(s)' : '');
        return { key: p.id + ':' + p.injuryDate, player: p.id, vars: { ...playerVars(p), blessure: label, blessure_bas: label.charAt(0).toLowerCase() + label.slice(1), cause, duree: weeks > 1 ? weeks + ' semaines' : 'une semaine', retour: shortDate(shift(F.d, weeks * 7)), conseil: BL.types?.[p.injuryType]?.conseil || 'Reprise progressive conseillée.', impact, infirmerie: list || p.name } };
      });
    },
    retour_blesse(F, t, st) {
      const back = (st.memo.injured || []).map(id => F.byId.get(id)).filter(p => p && !(p.injury > 0));
      return back.slice(0, 1).map(p => ({ key: p.id + ':' + F.d, player: p.id, vars: playerVars(p) }));
    },
    surcharge(F, t) {
      const sx = t.seuils || {};
      const list = F.lineup.filter(p => !(p.injury > 0) && fatigueOf(p) >= (sx.fatigue ?? 25) && conditionOf(p) <= (sx.condition ?? 62)).sort((a, b) => fatigueOf(b) - fatigueOf(a) || String(a.id).localeCompare(String(b.id)));
      const p = list[0]; if (!p) return [];
      return [{ key: p.id + ':' + Math.floor(dayNumber(F.d) / 14), player: p.id, vars: { ...playerVars(p), fatigue: Math.round(fatigueOf(p)), condition: conditionOf(p), minutes: Number(p.dev?.minutes) || 0 } }];
    },
    gene(F, t) {
      if (!F.next || F.next.date !== shift(F.d, 1)) return [];
      const list = F.lineup.filter(p => !(p.injury > 0) && conditionOf(p) < (t.seuils?.condition ?? 72) && conditionOf(p) >= (t.seuils?.conditionMin ?? 45)).sort((a, b) => conditionOf(a) - conditionOf(b) || String(a.id).localeCompare(String(b.id)));
      const p = list[0]; if (!p) return [];
      return [{ key: F.next.id, player: p.id, club: F.opponent(F.next), vars: { ...playerVars(p), condition: conditionOf(p), adversaire: F.name(F.opponent(F.next)) } }];
    },
    moral_groupe(F) {
      if (F.dow !== 2) return [];
      const cap = captain(F); if (!cap) return [];
      const m = Math.round(F.s.morale ?? 70), band = m >= 75 ? 'haut' : m >= 55 ? 'moyen' : 'bas';
      return [{ key: F.d, player: cap.id, vars: { capitaine: cap.name, moral: m, humeur: pick(D.humeurs?.[band], F.d + band) } }];
    },
    temps_de_jeu(F) {
      if (!(F.s.round >= 3) || F.dow === 5) return [];
      const ratings = F.players.map(p => p.rating).sort((a, b) => a - b), median = ratings[Math.floor(ratings.length / 2)] || 0;
      const played = F.season.length;
      // Matchs manqués en protocole commotion : une absence médicale n'est pas un manque de temps de jeu.
      const missed = p => { const c = commotionApi(); return c ? c.missedMatches(F.s, p, F.season) : 0; };
      // Sans absence médicale : règle d'origine ; avec, on juge sur au moins trois matchs où il était disponible.
      const deficit = p => { const m = missed(p), dispo = played - m; return (m === 0 || dispo >= 3) && (Number(p.dev?.appearances) || 0) <= Math.floor(dispo / 3); };
      const list = F.players.filter(p => !F.sheet.has(p.id) && !(p.injury > 0) && (p.age || 0) >= 20 && p.rating >= median - 2 && !p.satisfaction?.promise && deficit(p))
        .sort((a, b) => b.rating - a.rating || String(a.id).localeCompare(String(b.id)));
      const p = list[0]; if (!p) return [];
      return [{ key: p.id + ':' + F.s.season + ':' + Math.floor(dayNumber(F.d) / 30), player: p.id, vars: { ...playerVars(p), minutes: Number(p.dev?.minutes) || 0 } }];
    },
    promesse_tenue(F) { return promiseOutcome(F, 'kept'); },
    promesse_rompue(F) { return promiseOutcome(F, 'broken'); },
    cadre_rdv(F) {
      const last = F.season[F.season.length - 1], n = F.streak('D');
      if (!last || n < 2 || (last.date !== F.yesterday && last.date !== shift(F.d, -2))) return [];
      const p = [...F.players].filter(x => !(x.injury > 0) && (x.age || 0) >= 28).sort((a, b) => (b.attributesV2?.leadership ?? 0) - (a.attributesV2?.leadership ?? 0) || String(a.id).localeCompare(String(b.id)))[0];
      if (!p) return [];
      // Une seule demande par série : clé = première défaite de la série.
      const start = F.season[F.season.length - n];
      return [{ key: 'serie:' + (start.fixtureId || start.date), player: p.id, vars: { ...playerVars(p), defaites: n } }];
    },
    recrue(F, t, st) {
      const arrivals = st.memo.arrivals || {};
      const p = F.players.filter(x => arrivals[x.id] && F.d >= shift(arrivals[x.id], 21) && F.d <= shift(arrivals[x.id], 35)).sort((a, b) => String(a.id).localeCompare(String(b.id)))[0];
      if (!p) return [];
      const cap = captain(F), bien = (p.satisfaction?.score ?? 65) >= 64 && (Number(p.dev?.appearances) || 0) >= 1;
      return [{ key: p.id, player: p.id, vars: { ...playerVars(p), capitaine: cap?.name || 'Le capitaine', integration: pick(t.variantes?.[bien ? 'bien' : 'mal'], p.id) } }];
    },
    seance_adjoint(F) {
      if (F.dow !== 1 || F.s.trained) return [];
      return [{ key: F.d, vars: { mode: MODE_LABELS[F.s.training] || String(F.s.training || 'normal'), condition: Math.round(F.mean(F.players.filter(p => !(p.injury > 0)).map(conditionOf))) } }];
    },
    // Lendemain d'un match du club : trois enseignements tirés des vraies statistiques, axe de semaine proposé.
    bilan_match(F) {
      const last = F.season[F.season.length - 1];
      // Après la clôture du match (réponse possible), au plus trois jours après la rencontre.
      if (F.s.live || !last?.stats || !last.date || last.date < shift(F.d, -3) || last.date >= F.d) return [];
      const x = last.stats, o = last.other || {}, pct = (a, b) => b > 0 ? Math.round(a / b * 100) : null;
      const notes = [];
      const melee = pct(x.scrumsWon, x.scrums), touche = pct(x.lineoutsWon, x.lineouts), pied = pct(x.goals, x.goalAttempts);
      if (melee !== null) notes.push({ poids: (85 - melee) * 1.2, axe: 'conquete', texte: melee < 80 ? 'mêlée en difficulté, ' + x.scrumsWon + ' sur ' + x.scrums + ' conservées' : 'mêlée solide, ' + x.scrumsWon + ' sur ' + x.scrums });
      if (touche !== null) notes.push({ poids: (90 - touche) * 1.2, axe: 'conquete', texte: touche < 85 ? 'touche fragile, ' + x.lineoutsWon + ' sur ' + x.lineouts + ' gagnées' : 'touche propre, ' + x.lineoutsWon + ' sur ' + x.lineouts });
      if (Number.isFinite(x.penalties)) notes.push({ poids: (x.penalties - 9) * 4 + (Number(x.yellows) || 0) * 12, axe: 'defence', texte: x.penalties >= 10 || x.yellows > 0 ? x.penalties + ' pénalités concédées' + (x.yellows > 0 ? ' et ' + x.yellows + ' carton' + (x.yellows > 1 ? 's' : '') + ' jaune' + (x.yellows > 1 ? 's' : '') : '') + ', trop de cadeaux' : 'discipline tenue, ' + x.penalties + ' pénalités seulement' });
      if (pied !== null) notes.push({ poids: (75 - pied) * 0.8, axe: 'pied', texte: pied < 70 ? 'buteur en délicatesse, ' + x.goals + ' sur ' + x.goalAttempts + ' face aux perches' : 'buteur précis, ' + x.goals + ' sur ' + x.goalAttempts });
      const tot = (Number(x.territory) || 0) + (Number(o.territory) || 0);
      if (tot > 0) { const t = Math.round(x.territory / tot * 100); notes.push({ poids: (50 - t) * 1.5, axe: 'pied', texte: t < 50 ? 'on a joué dans notre camp, ' + t + ' % de territoire' : 'on a occupé le terrain, ' + t + ' % de territoire' }); }
      if (notes.length < 3) return [];
      notes.sort((a, b) => b.poids - a.poids || a.axe.localeCompare(b.axe));
      const top = notes.slice(0, 3), axe = top[0].poids > 0 ? top[0].axe : null;
      const AXES = { conquete: 'la conquête', defence: 'la défense et la discipline', pied: 'le jeu au pied' };
      const res = last.us > last.them ? 'la victoire' : last.us < last.them ? 'la défaite' : 'le nul';
      return [{ key: last.fixtureId || last.date, club: last.opp, vars: { adversaire: F.name(last.opp), score: last.us + '-' + last.them, resultat: res, un: top[0].texte, deux: top[1].texte, trois: top[2].texte, axe: axe ? AXES[axe] : 'notre plan de jeu' } }];
    },
    // Lundi : le tour du championnat du club (résultats marquants de la semaine passée, série en cours, leader).
    // Un lundi déjà plein (trois mails par jour au plus, souvent le bilan du match et un mail plus prioritaire) le
    // repousse au mardi ou au mercredi : clé de la semaine, la semaine passée reste celle d'avant le lundi.
    tour_championnats(F) {
      if (F.dow > 2) return [];
      const lundi = shift(F.d, -F.dow);
      const from = shift(lundi, -7), week = F.hist.filter(r => r.date && r.date >= from && r.date < lundi && !r.pair.includes(F.s.club));
      const members = new Set((F.s.worldMode?.leagues?.[F.lid]?.members || []).map(String));
      const inLeague = r => !members.size || (members.has(String(r.pair[0])) && members.has(String(r.pair[1])));
      const games = week.filter(inLeague);
      if (games.length < 2) return [];
      const big = [...games].sort((a, b) => Math.abs(b.score[0] - b.score[1]) - Math.abs(a.score[0] - a.score[1]) || String(a.date).localeCompare(String(b.date)))[0];
      const w = big.score[0] >= big.score[1] ? 0 : 1;
      const carton = F.name(big.pair[w]) + ' ' + big.score[w] + '-' + big.score[1 - w] + ' face à ' + F.name(big.pair[1 - w]);
      const rows = F.rows(), rank = id => rows.findIndex(r => String(r.clubId) === String(id));
      let surprise = 'la hiérarchie a été respectée';
      const ups = games.filter(r => r.score[0] !== r.score[1]).map(r => { const win = r.score[0] > r.score[1] ? 0 : 1, a = rank(r.pair[win]), b = rank(r.pair[1 - win]); return { r, win, ecart: a >= 0 && b >= 0 ? a - b : 0 }; }).filter(u => u.ecart >= 4).sort((a, b) => b.ecart - a.ecart);
      if (ups[0]) surprise = F.name(ups[0].r.pair[ups[0].win]) + ' a fait tomber ' + F.name(ups[0].r.pair[1 - ups[0].win]);
      const leader = rows[0] ? F.name(rows[0].clubId) + ' (' + (rows[0].points ?? 0) + ' pts)' : null;
      if (!leader) return [];
      const runs = [...members].map(id => { let n = 0; const mine = F.hist.filter(r => r.pair.map(String).includes(id)); for (let i = mine.length - 1; i >= 0; i--) { const k = mine[i].pair.map(String).indexOf(id); if (mine[i].score[k] > mine[i].score[1 - k]) n++; else break; } return { id, n }; }).filter(x => x.n >= 3 && String(x.id) !== String(F.s.club)).sort((a, b) => b.n - a.n || a.id.localeCompare(b.id));
      const serie = runs[0] ? F.name(Number.isNaN(Number(runs[0].id)) ? runs[0].id : Number(runs[0].id)) || F.name(runs[0].id) : '';
      return [{ key: lundi, vars: { carton, surprise, leader, serie: serie ? serie + ' enchaîne ' + runs[0].n + ' victoires de suite' : 'aucune équipe ne s’envole' } }];
    },
    analyste(F) {
      if (!F.next || F.next.date !== shift(F.d, 2)) return [];
      const opp = F.opponent(F.next), recent = F.hist.filter(r => r.pair.includes(opp)).slice(-3).map(r => r.stats?.[r.pair.indexOf(opp)]).filter(Boolean);
      const sum = k => recent.reduce((a, x) => a + (Number(x[k]) || 0), 0);
      const scrum = sum('scrums') ? sum('scrumsWon') / sum('scrums') : 1, touche = sum('lineouts') ? sum('lineoutsWon') / sum('lineouts') : 1, pens = recent.length ? sum('penalties') / recent.length : 0;
      const faiblesse = scrum < 0.7 ? 'leur mêlée, qui recule sous la pression' : touche < 0.8 ? 'leur alignement en touche' : pens >= 10 ? 'leur discipline, ils concèdent beaucoup de pénalités' : 'leur défense sur les extérieurs';
      return [{ key: F.next.id, club: opp, vars: { adversaire: F.name(opp), forme: F.form(opp) || 'inconnue', faiblesse } }];
    },
    tests_physiques(F) {
      if (F.dow !== 0 || Number(F.d.slice(8)) > 7) return [];
      const fit = F.players.filter(p => !(p.injury > 0));
      return [{ key: F.d.slice(0, 7), vars: { condition: Math.round(F.mean(fit.map(conditionOf))), 'chargés': fit.filter(p => fatigueOf(p) >= 20).length } }];
    },
    entraineur_avants(F) {
      if (F.dow !== 3) return [];
      const last = F.season[F.season.length - 1];
      if (!last?.stats || !(last.date >= shift(F.d, -5))) return [];
      const x = last.stats;
      if (!(x.scrums > 0 && x.lineouts > 0)) return [];
      if (x.scrumsWon / x.scrums >= 0.85 && x.lineoutsWon / x.lineouts >= 0.9) return [];
      return [{ key: last.fixtureId || last.date, vars: { melees: x.scrumsWon, melees_total: x.scrums, touches: x.lineoutsWon, touches_total: x.lineouts } }];
    },
    entraineur_arrieres(F) {
      if (F.dow !== 3) return [];
      const last = F.season[F.season.length - 1];
      if (!last?.stats || !last.other || !(last.date >= shift(F.d, -5)) || !(Number(last.stats.territory) < Number(last.other.territory))) return [];
      return [{ key: last.fixtureId || last.date, vars: {} }];
    },
    recruteur(F, t, st) {
      const seen = new Set(st.memo.missions || []), reports = F.s.manager?.reports || [];
      const done = (F.s.manager?.missions || []).filter(m => m.status === 'done' && !seen.has(m.id));
      return done.slice(0, 1).flatMap(m => {
        const list = reports.filter(r => r.mission === m.id), best = list[0];
        if (!best) return [];
        return [{ key: m.id, player: String(best.playerId || ''), vars: { n: list.length, joueur: String(best.name || ''), poste: String(best.pos || ''), age: Number(best.age) || 0, note: Number(best.note) || 0 } }];
      });
    },
    agent(F) {
      if (F.dow !== 2 || !(F.s.round >= 2) || typeof managerPool !== 'function') return [];
      let pool = []; try { pool = managerPool(); } catch { pool = []; }
      const top = pool.filter(p => (p.age || 0) >= 21 && (p.age || 0) <= 31 && !(p.injury > 0)).sort((a, b) => b.rating - a.rating || String(a.id).localeCompare(String(b.id))).slice(0, 12);
      const p = top.length ? top[hash(F.d + ':' + F.s.club) % top.length] : null;
      if (!p) return [];
      return [{ key: String(p.id), player: String(p.id), vars: { ...playerVars(p), salaire: euros(Number(p.salary) || 0) } }];
    },
    // Décisions du directeur sportif sur les fins de contrat (prolongations-staff.cjs) : une par mail.
    ds_contrats(F, t) {
      const desk = F.s.manager?.contractDesk;
      if (!desk || desk.season !== F.s.season || !Array.isArray(desk.decisions)) return [];
      const d = F.s.clubDirections?.clubs?.[F.s.club]?.director, signature = d && typeof d.name === 'string' && d.name ? d.name + ', directeur sportif' : 'Le directeur sportif';
      const raisons = typeof nativeProlongations !== 'undefined' ? nativeProlongations.RAISONS : {};
      return desk.decisions.filter(x => x.d === t.decision && !x.final && x.etat === 'actif' && x.date && x.date <= F.d).map(x => {
        const p = F.byId.get(x.id) || null;
        return { key: x.id + ':' + desk.season + ':' + x.d, player: x.id, vars: { ...(p ? playerVars(p) : { joueur: x.name, poste: x.pos, age: x.age }), signature, raison: raisons[x.raison] || '', salaire: euros(x.salary * 52), fin: typeof libelleSaison === 'function' ? libelleSaison(x.end) : String(x.end), ancien: euros(x.oldSalary * 52) } };
      });
    },
    // Staff renouvelé par le directeur sportif (staff-renouvellement.cjs) : un courrier par série de décisions.
    ds_staff(F) {
      const desk = F.s.manager?.staffDesk;
      if (!desk || !Array.isArray(desk.lots)) return [];
      const d = F.s.clubDirections?.clubs?.[F.s.club]?.director, signature = d && typeof d.name === 'string' && d.name ? d.name + ', directeur sportif' : 'Le directeur sportif';
      const raisons = typeof nativeStaffRenouvellement !== 'undefined' ? nativeStaffRenouvellement.RAISONS : {};
      const saison = x => typeof libelleSaison === 'function' ? libelleSaison(x + 1) : String(x + 1);
      return desk.lots.filter(l => l.date && l.date <= F.d && l.date >= shift(F.d, -14)).map(l => {
        const lignes = [];
        if (l.prolonges.length) lignes.push('Prolongés : ' + l.prolonges.map(x => x.name + ' (' + x.role + ', jusqu’à la fin de la saison ' + saison(x.fin) + ')').join(', ') + '.');
        if (l.departs.length) lignes.push('Je laisse partir en fin de saison : ' + l.departs.map(x => x.name + ' (' + x.role + ' : ' + (raisons[x.raison] || '') + ')').join(', ') + '.');
        if (l.recrues.length) lignes.push('Arrivés au club : ' + l.recrues.map(x => x.name + ' (' + x.role + ')').join(', ') + '.');
        if (l.refus) lignes.push(l.refus + ' signature' + (l.refus > 1 ? 's' : '') + ' n’ont pas pu se faire, faute de moyens.');
        return { key: l.id, vars: { signature, resume: lignes.join('\n\n'), n: l.prolonges.length + l.departs.length + l.recrues.length } };
      });
    },
    contrats(F) {
      if (F.dow !== 4 || !(F.s.round >= 6)) return [];
      const list = F.players.filter(p => p.contractEnd === F.s.season).sort((a, b) => b.rating - a.rating);
      if (!list.length) return [];
      const relais = typeof dsContratsActif === 'function' && dsContratsActif() ? ' Comme convenu, ceux que tu n’auras pas réglés d’ici mars, je les trancherai moi-même et je te tiendrai au courant.' : '';
      return [{ key: F.d.slice(0, 7), vars: { relais, n: list.length, liste: list.slice(0, 5).map(p => p.name + ' (' + p.pos + ')').join(', ') + (list.length > 5 ? ' et ' + (list.length - 5) + ' autre(s)' : '') } }];
    },
    prolongation(F) {
      if (!(F.s.round >= 8) || F.dow !== 1) return [];
      const top = [...F.players].sort((a, b) => b.rating - a.rating).slice(0, 10).filter(p => p.contractEnd === F.s.season && (p.satisfaction?.score ?? 65) >= 55);
      const p = top[0]; if (!p) return [];
      return [{ key: p.id + ':' + F.s.season, player: p.id, vars: playerVars(p) }];
    },
    article(F, t) {
      const g = F.playedOn(F.yesterday); if (!g) return [];
      const r = g.result, o = F.outcome(r), band = o === 'V' ? 'victoire' : o === 'D' ? 'defaite' : 'nul';
      return [{ key: g.fixture.id, club: r.opp, vars: { adversaire: F.name(r.opp), score: r.us + '-' + r.them, titre: pick(t.variantes?.[band], g.fixture.id) } }];
    },
    rumeur(F) {
      if (F.dow !== 5 || !(F.s.round >= 4)) return [];
      const p = [...F.players].sort((a, b) => b.rating - a.rating).slice(0, 8).find(x => x.contractEnd === F.s.season);
      if (!p) return [];
      return [{ key: p.id + ':' + F.s.season, player: p.id, vars: playerVars(p) }];
    },
    critique(F) {
      const last = F.season[F.season.length - 1], n = F.streak('D');
      if (!last || n < 3 || last.date !== F.yesterday) return [];
      return [{ key: 'crit:' + (last.fixtureId || last.date), vars: { defaites: n } }];
    },
    une_derby(F) {
      if (!F.next || F.next.date !== shift(F.d, 4) || !F.derby(F.opponent(F.next))) return [];
      return [{ key: F.next.id, club: F.opponent(F.next), vars: { adversaire: F.name(F.opponent(F.next)) } }];
    },
    affluence(F, t) {
      const g = F.playedOn(F.yesterday); if (!g || !g.result.home) return [];
      // Tribunes décrites d'après le public réel du match (affluence / capacité) ; sans chiffre, l'humeur des supporters.
      const cap = Number(F.club.stadiumCapacity) || 0, vu = (F.hist || []).find(r => r.fixtureId === g.fixture.id)?.affluence;
      let band;
      if (Number.isFinite(vu) && cap > 0) band = vu / cap >= 0.85 ? 'plein' : vu / cap >= 0.6 ? 'moyen' : 'faible';
      else { let h = null; try { h = nativeSystems.domain('clubStrategy').humeur(); } catch (e) { h = null; } const fans = Number.isFinite(h) ? h : 50; band = fans >= 60 ? 'plein' : fans >= 40 ? 'moyen' : 'faible'; }
      return [{ key: g.fixture.id, club: g.result.opp, vars: { adversaire: F.name(g.result.opp), capacite: euros(Number(F.club.stadiumCapacity) || 0), ambiance: pick(t.variantes?.[band], g.fixture.id) } }];
    },
    sponsor(F) {
      if (F.dow !== 4 || F.season.length < 3) return [];
      const last = F.season.slice(-5), wins = last.filter(r => F.outcome(r) === 'V').length;
      return [{ key: F.d, vars: { etat: wins * 2 >= last.length ? 'satisfait' : 'inquiet', bilan: wins + ' victoire(s) sur les ' + last.length + ' derniers matchs' } }];
    },
    president(F, t) {
      if (F.dow !== 0 || !(F.s.round >= 3)) return [];
      const c = Math.round(F.s.trust ?? 50), band = c >= 70 ? 'haute' : c >= 45 ? 'moyenne' : 'basse';
      return [{ key: F.d, vars: { confiance: c, niveau: { haute: 'solide', moyenne: 'réelle mais conditionnelle', basse: 'entamée' }[band], message: pick(t.variantes?.[band], F.d) } }];
    },
    // Décision de l'A2R (a2r.cjs) : un courrier par audition, du type qui correspond au niveau décidé.
    a2r(F, t) {
      const v = typeof a2rCourrier === 'function' ? a2rCourrier(t.niveau) : null;
      return v ? [{ key: v.cle, vars: v.vars }] : [];
    },
    // Le président reprend la main après des achats (president-reprise.cjs) : un seul courrier par intervention.
    reprise_president() {
      const v = typeof repriseCourrier === 'function' ? repriseCourrier() : null;
      return v ? [{ key: v.cle, vars: v.vars }] : [];
    },
    // Vente de joueurs (vente-joueurs.cjs) : une offre reçue = un courrier ; accord exécuté ou tombé = un courrier.
    // Pendant la période des mutations, les offres sont regroupées dans le « Point mercato » ; une offre déjà annoncée
    // là n'est pas redonnée seule après la période.
    offre_transfert(F, t, st) {
      if (typeof venteCourriers !== 'function' || mercato(F.d)?.ouverte) return [];
      return venteCourriers(F.s).filter(c => !dejaVu(st, F.s, 'o:' + c.key));
    },
    // Échos du mercato (hors période) : accords entre clubs gérés, pré-contrats et rumeurs de la semaine, en liste courte.
    echos_mercato(F, t, st) {
      const P = mercato(F.d); if (!P || P.ouverte) return [];
      const items = faitsMercato(F.s, MK.echos?.types || ['achat', 'accord', 'precontrat', 'rumeur']).filter(x => !dejaVu(st, F.s, x.id));
      if (!items.length) return [];
      const vars = { arrivee: dateLongue(shift(P.fin, 1)) };
      section(vars, 'echo', '', items, MK.echos?.lignes ?? 6);
      return [{ key: F.s.season + ':' + semaineMonde(F.s), vars, vus: items.map(x => x.id) }];
    },
    // Point mercato (période, hors première et dernière semaine) : offres reçues, accords du club, principaux accords du Monde.
    point_mercato(F, t, st) {
      const P = mercato(F.d); if (!P || !P.ouverte || F.d <= shift(P.debut, 6) || shift(F.d, 7) > P.fin) return [];
      const L = MK.point || {}, vars = mercatoVars(P, F.d), nouveau = x => !dejaVu(st, F.s, x.id);
      const offres = offresClub(F.s).filter(nouveau), accords = accordsClub(F.s).filter(nouveau);
      const monde = faitsMercato(F.s, MK.monde?.types || ['achat', 'accord']).filter(nouveau);
      if (!offres.length && !accords.length && !monde.length) return [];
      section(vars, 'offres', titre('offres', vars), offres, L.offres ?? 4);
      section(vars, 'accords', titre('accords', vars), accords, L.accords ?? 3);
      section(vars, 'monde', titre('monde', vars), parMontant(monde).slice(0, L.monde ?? 3), L.monde ?? 3);
      return [{ key: F.s.season + ':' + semaineMonde(F.s), vars, vus: [...offres, ...accords, ...monde].map(x => x.id) }];
    },
    // Ouverture (première semaine de la période), une fois par saison : accords déjà conclus, offres nouvelles.
    mercato_ouverture(F, t, st) {
      const P = mercato(F.d); if (!P || !P.ouverte || F.d > shift(P.debut, 6)) return [];
      const vars = mercatoVars(P, F.d), offres = offresClub(F.s).filter(x => !dejaVu(st, F.s, x.id)), accords = accordsClub(F.s);
      section(vars, 'accords', titre('accords_conclus', vars), accords, MK.point?.accords ?? 3);
      section(vars, 'offres', titre('offres', vars), offres, MK.point?.offres ?? 4);
      vars.rien = offres.length || accords.length ? '' : titre('rien', vars);
      return [{ key: P.fin.slice(0, 4), vars, vus: [...offres, ...accords].map(x => x.id) }];
    },
    // Dernière semaine (date + 7 jours après la fin de période), une fois par saison : offres en attente, plus gros accords.
    mercato_derniere(F, t, st) {
      const P = mercato(F.d); if (!P || !P.ouverte || shift(F.d, 7) <= P.fin) return [];
      const vars = mercatoVars(P, F.d), offres = offresClub(F.s), accords = accordsClub(F.s).filter(x => !dejaVu(st, F.s, x.id));
      const monde = faitsMercato(F.s, MK.monde?.types || ['achat', 'accord']);
      section(vars, 'offres', titre('offres_attente', vars), offres, MK.point?.offres ?? 4);
      section(vars, 'accords', titre('accords', vars), accords, MK.point?.accords ?? 3);
      section(vars, 'monde', titre('monde_saison', vars), parMontant(monde).slice(0, MK.point?.monde ?? 3), MK.point?.monde ?? 3);
      return [{ key: P.fin.slice(0, 4), vars, vus: [...offres, ...accords, ...monde].map(x => x.id) }];
    },
    vente_executee(F) { return typeof venteCourriersAccords === 'function' ? venteCourriersAccords(F.s, 'executee', F.d) : []; },
    vente_annulee(F) { return typeof venteCourriersAccords === 'function' ? venteCourriersAccords(F.s, 'annulee', F.d) : []; },
    // Pré-contrats (calendrier-mutations.cjs) : un autre club approche un joueur en fin de contrat, puis il signe ailleurs.
    precontrat_approche(F) { return typeof calCourriers === 'function' ? calCourriers(F.s, 'approche') : []; },
    precontrat_signe(F) { return typeof calCourriers === 'function' ? calCourriers(F.s, 'signe') : []; },
    // Investissements des excédents (club-investments.cjs) : une fois par saison, tant que le manager n'a pas orienté.
    investissements(F) {
      const v = typeof investCourrier === 'function' ? investCourrier() : null;
      return v ? [{ key: 'investissements:' + F.s.season, vars: v }] : [];
    },
    // L'argent du propriétaire (club-owner.cjs) : prêt de l'actionnaire, changement de propriétaire du club joué.
    pret_actionnaire(F) {
      const v = typeof pretCourrier === 'function' ? pretCourrier() : null;
      return v ? [{ key: 'pret:' + F.s.season, vars: v }] : [];
    },
    proprietaire_arrivee(F) {
      const v = typeof proprietaireCourrier === 'function' ? proprietaireCourrier() : null;
      return v && v.arrivee === 'oui' ? [{ key: 'arrivee:' + F.s.season, vars: v }] : [];
    },
    // Bilan du quota de joueurs formés localement (jiff.cjs) : courrier de la ligue au début de la saison suivante, quand la
    // saison finie a coûté des points (JIFF), une amende (EQP) ou rapporté la prime du fonds JIFF. Rien si le quota est tenu.
    quota_retrait(F) { return quotaLigue(F, r => r.deduction > 0); },
    quota_amende(F) { return quotaLigue(F, r => r.fine > 0); },
    quota_prime(F) { return quotaLigue(F, r => r.bonus > 0 && !(r.deduction > 0)); },
    proprietaire_depart(F) {
      const v = typeof proprietaireCourrier === 'function' ? proprietaireCourrier() : null;
      return v && v.arrivee === 'non' ? [{ key: 'depart:' + F.s.season, vars: v }] : [];
    },
    supporters_derby(F, t) {
      const g = F.playedOn(F.yesterday); if (!g || !F.derby(g.result.opp)) return [];
      const o = F.outcome(g.result), band = o === 'V' ? 'victoire' : o === 'D' ? 'defaite' : 'nul';
      return [{ key: g.fixture.id, club: g.result.opp, vars: { adversaire: F.name(g.result.opp), reaction: pick(t.variantes?.[band], g.fixture.id) } }];
    },
    // La veille du match (comme la météo) : l'arbitre réellement désigné (match-pilotage.js, même fixtureId et même
    // competitionId que le direct : `worldContext.id` / `worldContext.competitionId`), sinon le profil d'ambiance.
    arbitre(F) {
      if (!F.next || F.next.date !== shift(F.d, 1)) return [];
      const adversaire = F.name(F.opponent(F.next));
      const a = typeof arbitreDuMatch === 'function' ? arbitreDuMatch(F.next.id, F.next.competitionId) : null;
      if (!a) return [{ key: F.next.id, club: F.opponent(F.next), vars: { adversaire, arbitre: 'l’arbitre désigné', tendances: 'non communiquées', resume: 'Profil : ' + pick(D.profilsArbitre, F.next.id) + '.', conseil: 'À intégrer dans tes consignes.', profil: pick(D.profilsArbitre, F.next.id) } }];
      const mots = {
        rucks: ['très pointilleux sur les rucks', 'plutôt strict sur les rucks', 'sans manie sur les rucks', 'plutôt tolérant sur les rucks', 'laisse vivre les rucks'],
        melee: ['très pointilleux en mêlée', 'plutôt strict en mêlée', 'sans manie en mêlée', 'plutôt tolérant en mêlée', 'laisse vivre la mêlée'],
        horsJeu: ['très pointilleux sur le hors-jeu', 'plutôt strict sur le hors-jeu', 'sans manie sur le hors-jeu', 'plutôt tolérant sur le hors-jeu', 'laisse vivre le hors-jeu'],
        cartons: ['sort vite les cartons', 'plutôt prompt à sortir les cartons', 'carton à dose normale', 'plutôt patient avant le carton', 'très patient avant le carton']
      };
      const accord = t => a.f ? t.replace(/pointilleux/g, 'pointilleuse').replace(/tolérant/g, 'tolérante').replace(/prompt/g, 'prompte') : t;
      const mot = k => accord(mots[k][5 - Math.min(5, Math.max(1, Math.round(Number(a[k]) || 3)))]) + ' (' + (Math.round(Number(a[k]) || 3)) + '/5)';
      const tendances = ['rucks', 'melee', 'horsJeu', 'cartons'].map(mot).join(' ; ');
      const sev = [['rucks', 'ne conteste pas chaque ruck'], ['melee', 'soigne la première poussée en mêlée'], ['horsJeu', 'garde la ligne défensive bien alignée'], ['cartons', 'évite les fautes gratuites']].filter(([k]) => a[k] >= 4);
      const conseil = sev.length ? 'À intégrer dans les consignes : ' + sev.map(x => x[1]).join(', ') + '.' : 'Rien de marquant : joue ton match, les consignes en direct feront le reste.';
      return [{ key: F.next.id, club: F.opponent(F.next), vars: { adversaire, arbitre: a.nom + ' (' + a.pays + ')', tendances, resume: a.resume, conseil, profil: a.resume } }];
    },
    // Veille du match (avec la météo, dont il dépend) : plan de jeu probable de l'adversaire lu par notre staff
    // (avant-match.cjs planAdverse : même calcul que le choix de l'IA au coup d'envoi, lecture faillible).
    plan_adverse(F) {
      const f = F.next;
      if (!f || (f.date !== F.d && f.date !== shift(F.d, 1)) || F.s.worldMode?.day === undefined || typeof CDWorldCareer === 'undefined' || typeof CDWorldCareer.meteoPrevue !== 'function') return [];
      const kept = F.s.worldMode.meteo, m = kept && kept.fixtureId === f.id ? kept : CDWorldCareer.meteoPrevue(F.s, f);
      let plan = null;
      try { plan = nativeSystems.domain('avantMatch').planAdverse(F.s, f, m.weather); } catch (e) { plan = null; }
      if (!plan) return [];
      const l = plan.lecteur || {}, lecteur = l.nom ? l.nom + ', notre ' + l.role + ',' : 'le staff';
      const confiance = { sure: 'La lecture est nette.', probable: 'C’est le scénario le plus probable.', incertaine: 'La lecture reste incertaine : ne mets pas tout sur cette carte.' }[plan.confiance] || '';
      const bas = plan.titre.charAt(0).toLowerCase() + plan.titre.slice(1);
      return [{ key: f.id, club: F.opponent(f), vars: { adversaire: F.name(F.opponent(f)), quand: f.date === F.d ? 'aujourd’hui' : 'demain', lecteur, titre_bas: bas, raison: plan.raison, confiance, conseil: plan.conseil, style: plan.style } }];
    },
    rivaux(F) {
      const g = F.playedOn(shift(F.d, -2)); if (!g || g.fixture.competitionId !== F.lid) return [];
      const rows = F.rows(), i = rows.findIndex(r => r.clubId === F.s.club);
      if (i < 0) return [];
      const near = rows.slice(Math.max(0, i - 2), i + 3).filter(r => r.clubId !== F.s.club).map(r => r.clubId);
      const lines = near.map(id => { const r = [...F.hist].reverse().find(x => x.pair.includes(id) && x.date && x.date >= shift(F.d, -4)); if (!r) return null; const k = r.pair.indexOf(id); return F.name(id) + ' ' + r.score[k] + '-' + r.score[1 - k] + ' contre ' + F.name(r.pair[1 - k]); }).filter(Boolean);
      if (!lines.length) return [];
      return [{ key: g.fixture.id, vars: { liste: lines.join(' ; '), rang: ordinal(i + 1) + ' sur ' + rows.length } }];
    },
    tirage(F, t, st) {
      const seen = new Set(st.memo.pools || []), out = [];
      for (const [id, cup] of Object.entries(F.s.worldMode.europe || {})) {
        const pool = (cup.pools || []).find(p => Array.isArray(p) && p.includes(F.s.club));
        if (!pool || seen.has(id + ':' + F.s.season)) continue;
        out.push({ key: id + ':' + F.s.season, vars: { competition: ({ champions: 'Coupe des champions', challenge: 'Challenge européen' })[id] || id, liste: pool.filter(c => c !== F.s.club).map(F.name).join(', ') } });
      }
      return out.slice(0, 1);
    },
    tele(F, t, st) {
      const seen = new Set(st.memo.calendar || []);
      const m = (F.s.calendarMail?.messages || []).find(x => x.status === 'pending' && !seen.has(x.id));
      return m ? [{ key: m.id, vars: { adversaire: String(m.opponent || ''), date: shortDate(m.toDate) } }] : [];
    },
    discipline(F, t, st) {
      const sx = t.seuils || {}, cards = F.season.reduce((a, r) => a + (Number(r.stats?.yellows) || 0), 0), step = sx.cartons || 6;
      const level = Math.floor(cards / step);
      if (level <= (st.memo.cartons || 0)) return [];
      return [{ key: F.s.season + ':' + level, vars: { cartons: cards, amende: euros(sx.amende || 5000), frais: euros(sx.frais || 1500) } }];
    },
    pepite(F, t) {
      if (!(F.s.round >= 4)) return [];
      const sx = t.seuils || {}, academy = F.s.development?.academy || [];
      const p = academy.filter(x => (x.age || 0) >= (sx.age ?? 18) && (Number(x.dev?.potential) || 0) >= (sx.potentiel ?? 68) && x.rating >= (sx.note ?? 58) && !(x.injury > 0))
        .sort((a, b) => (b.dev?.potential || 0) - (a.dev?.potential || 0) || String(a.id).localeCompare(String(b.id)))[0];
      if (!p) return [];
      return [{ key: p.id + ':' + F.s.season, player: p.id, vars: { ...playerVars(p), note: p.rating, potentiel: Number(p.dev?.potential) || 0 } }];
    },
    rapport_centre(F) {
      if (F.dow !== 4) return [];
      const academy = F.s.development?.academy || [];
      if (!academy.length) return [];
      const best = [...academy].sort((a, b) => (b.dev?.potential || 0) - (a.dev?.potential || 0) || String(a.id).localeCompare(String(b.id))).slice(0, 3);
      return [{ key: F.d.slice(0, 7), vars: { n: academy.length, note: Math.round(F.mean(academy.map(p => p.rating))), liste: best.map(p => p.name + ' (' + p.pos + ', ' + p.age + ' ans)').join(', ') } }];
    },
    selection_jeune(F, t, st) {
      const played = F.s.youthNational?.played?.[String(F.s.season)];
      if (!played || !Object.keys(played).length || (st.memo.youth || 0) === F.s.season) return [];
      return [{ key: 'jeunes:' + F.s.season, vars: { competition: 'compétitions internationales de jeunes' } }];
    },
    anniversaire(F) {
      const md = F.d.slice(5);
      const p = F.players.filter(x => { const day = hash(String(x.id)) % 365; return new Date(Date.UTC(2001, 0, 1 + day)).toISOString().slice(5, 10) === md; }).sort((a, b) => String(a.id).localeCompare(String(b.id)))[0];
      return p ? [{ key: p.id + ':' + F.s.season, player: p.id, vars: playerVars(p) }] : [];
    },
    jalon(F, t, st) {
      const apps = st.memo.apps || {}, marks = [10, 20, 30];
      for (const p of F.players) {
        const now = Number(p.dev?.appearances) || 0, before = apps[p.id] ?? now;
        const m = marks.find(x => before < x && now >= x);
        if (m) return [{ key: p.id + ':' + F.s.season + ':' + m, player: p.id, vars: { ...playerVars(p), n: m } }];
      }
      return [];
    },
    // Cap de carrière d'un joueur de l'effectif (50e, 100e, 150e… match en carrière, tous clubs confondus) : matchs des
    // saisons closes (historique de développement) + saison en cours. La mémoire garde le total vu la veille ; un joueur
    // arrivé en cours de route ou une première réception n'écrit rien.
    jalon_carriere(F, t, st) {
      const seen = st.memo.careerApps || {}, marks = t.seuils?.caps || [50, 100, 150, 200, 250, 300], out = [];
      for (const p of F.players) {
        const now = careerTotal(p, seen), before = seen[p.id] ?? now;
        const m = marks.slice().reverse().find(x => before < x && now >= x);
        if (m) out.push({ key: p.id + ':' + m, player: p.id, vars: { ...playerVars(p), n: m, carriere: now } });
      }
      return out;
    },
    serie(F) {
      const last = F.season[F.season.length - 1], n = F.streak('V');
      if (!last || last.date !== F.yesterday || ![4, 6, 8, 10].includes(n)) return [];
      return [{ key: F.s.season + ':' + n, vars: { n } }];
    },
    // Bulletin météo de la veille (world-career.cjs, météo fixée la veille et reprise au coup d'envoi) : une fois par
    // match, le jour où l'annonce tombe (la veille ; le jour même si la carrière n'est arrivée qu'alors).
    meteo(F) {
      const m = annonceMeteo(F);
      if (!m) return [];
      const camp = id => F.name(id) || 'l’adversaire';
      const nous = F.next.homeId === F.s.club ? 0 : 1, pair = [F.next.homeId, F.next.awayId];
      const ciel = String(m.libelle || '').trim();
      const vent = m.ventDos ? ' Le vent soufflera dans le dos de ' + camp(pair[m.ventDos[0]]) + ' en première période' + (m.ventDos[0] === nous ? ' : à nous d’en profiter avant la pause.' : ', puis dans le nôtre après la pause.') : '';
      return [{ key: F.next.id, club: F.opponent(F.next), vars: { adversaire: F.name(F.opponent(F.next)), quand: F.next.date === F.d ? 'aujourd’hui' : 'demain', ciel: ciel.charAt(0).toUpperCase() + ciel.slice(1), ciel_bas: ciel, vent, conseil: m.conseil || '' } }];
    },
    // Doublon (doublons.cjs) : le prochain match de championnat du club tombe dans une fenêtre internationale. Un seul
    // courrier par rencontre, une semaine avant au plus (dès que les convocations sont connues), jamais le jour même.
    doublon(F, t) {
      const f = F.next;
      if (!f || f.phase !== 'league' || f.competitionId !== F.lid || F.d < shift(f.date, -7) || F.d >= f.date || typeof nativeSystems === 'undefined') return [];
      const v = nativeSystems.domain('doublons').impact(F.s, f, t.seuils || {});
      return v ? [{ key: f.id, vars: v }] : [];
    },
    // Protocole des Bleus (liste de 33) : un courrier de la cellule FFR-LNR par match, pour le joueur le mieux noté qui doit souffler.
    cellule(F) {
      const f = F.next;
      if (!f || typeof nativeSystems === 'undefined' || F.d >= f.date || F.d < shift(f.date, -5) || F.d < monday(f.date)) return [];
      const v = nativeSystems.domain('doublons').aMenager(F.s, f);
      if (!v) return [];
      return [{ key: f.id, player: v.player.id, vars: { ...playerVars(v.player), matchs: v.matchs, repos: v.repos, adversaire: v.opponent, jour: v.jour, rencontre: f.id } }];
    },
    // Médecin du club : commotion confirmée (protocole World Rugby, club-support.cjs), une fois par commotion, dans les
    // jours qui suivent le match. `seuils.exception` : courrier où l'exception à 7 jours peut être demandée.
    commotion(F, t) {
      const c = commotionApi(); if (!c) return [];
      const wanted = !!t.seuils?.exception;
      return F.players.filter(p => { const prot = c.protocol(p); return prot && prot.date < F.d && F.d <= shift(prot.date, 6) && F.d < prot.retour && (prot.exception === 'possible') === wanted; })
        .sort((a, b) => String(a.id).localeCompare(String(b.id))).slice(0, 2).map(p => {
          const prot = c.protocol(p), n = p.commotion.n;
          const antecedents = prot.antecedent ? 'Il a des antécédents (' + n + ' commotion' + (n > 1 ? 's' : '') + ' en carrière, dont une récente) : 12 jours au minimum, sans exception possible.' : n > 1 ? 'C’est sa ' + n + 'e commotion en carrière.' : 'C’est sa première commotion.';
          return { key: p.id + ':' + prot.date, player: p.id, vars: { ...playerVars(p), match: shortDate(prot.date), retour: shortDate(prot.retour), jours: daysBetweenIso(prot.date, prot.retour), motif: c.MOTIFS[prot.critere], antecedents, septieme: shortDate(c.shiftDate(prot.date, c.RULES.exception)) } };
        });
    },
    pelouse(F) {
      if (!F.next || F.next.date !== shift(F.d, 1) || F.next.homeId !== F.s.club) return [];
      // Pelouse cohérente avec la météo annoncée : pluie (glissante), forte pluie (lourde), sinon la saison.
      const mt = annonceMeteo(F), month = Number(F.d.slice(5, 7)), season = month >= 6 && month <= 8 ? 'ete' : month >= 9 && month <= 11 ? 'automne' : month === 12 || month <= 2 ? 'hiver' : 'printemps';
      const band = mt && mt.pluie === 2 ? 'deluge' : mt && mt.pluie ? 'pluie' : mt && mt.chaleur ? 'ete' : season;
      return [{ key: F.next.id, club: F.opponent(F.next), vars: { adversaire: F.name(F.opponent(F.next)), pelouse: pick(D.pelouses?.[band], F.next.id) } }];
    },
  };
  function promiseOutcome(F, status) {
    for (const p of F.players) {
      const h = (p.satisfaction?.history || []).filter(x => x.status === status && x.season === F.s.season && x.round >= F.s.round - 1).pop();
      if (h) return [{ key: p.id + ':' + h.season + ':' + h.round, player: p.id, vars: playerVars(p) }];
    }
    return [];
  }

  // ------------------------------------------------------------------ réception (la boîte seule est écrite)
  function remember(s, st, F) {
    const m = st.memo;
    m.injured = F.players.filter(p => p.injury > 0).map(p => p.id).slice(0, 80);
    const before = new Set(m.squad || []), first = !(m.squad || []).length;
    const arrivals = {};
    for (const p of F.players) {
      if (m.arrivals?.[p.id]) arrivals[p.id] = m.arrivals[p.id];
      else if (!first && !before.has(p.id)) arrivals[p.id] = F.d;
    }
    for (const [id, d] of Object.entries(arrivals)) if (d < shift(F.d, -40)) delete arrivals[id];
    m.arrivals = arrivals;
    m.squad = F.players.map(p => p.id).slice(0, 120);
    m.apps = Object.fromEntries(F.players.map(p => [p.id, Number(p.dev?.appearances) || 0]));
    // Un cap franchi mais pas encore écrit (plafond du jour ou de la semaine atteint) reste « à venir » : la mémoire n'avance pas.
    const caps = TYPES.jalon_carriere?.seuils?.caps || [50, 100, 150, 200, 250, 300], seenApps = m.careerApps || {};
    m.careerApps = Object.fromEntries(F.players.map(p => {
      const now = careerTotal(p, seenApps), before = seenApps[p.id] ?? now;
      const pendant = caps.some(x => before < x && now >= x && !st.sent['jalon_carriere:' + p.id + ':' + x]);
      return [p.id, pendant ? before : now];
    }));
    m.missions = (s.manager?.missions || []).filter(x => x.status === 'done').map(x => String(x.id)).slice(-30);
    m.pools = Object.entries(s.worldMode.europe || {}).filter(([, c]) => (c.pools || []).some(p => Array.isArray(p) && p.includes(s.club))).map(([id]) => id + ':' + s.season);
    m.calendar = (s.calendarMail?.messages || []).map(x => x.id).slice(-40);
    const t = TYPES.discipline?.seuils?.cartons || 6, cards = F.season.reduce((a, r) => a + (Number(r.stats?.yellows) || 0), 0);
    m.cartons = Math.max(m.cartons || 0, Math.floor(cards / t));
    if (s.youthNational?.played?.[String(s.season)] && Object.keys(s.youthNational.played[String(s.season)]).length) m.youth = s.season;
  }

  // Météo annoncée du prochain match (format du modèle natif : libellé, conseil, ventDos, pluie…), ou null. Celle
  // gardée dans la carrière, sinon la même prévision recalculée (la réception peut précéder l'enregistrement).
  function annonceMeteo(F) {
    const f = F.next;
    if (!f || (f.date !== F.d && f.date !== shift(F.d, 1)) || typeof CDWorldCareer === 'undefined' || typeof CDWorldCareer.meteoPrevue !== 'function' || F.s.worldMode?.day === undefined || typeof meteoLibelle !== 'function') return null;
    const kept = F.s.worldMode.meteo, m = kept && kept.fixtureId === f.id ? kept : CDWorldCareer.meteoPrevue(F.s, f);
    const l = { pair: [f.homeId, f.awayId], weather: m.weather, weatherVersion: 1, windVersion: typeof WIND_DIRECTION_RULES !== 'undefined' && WIND_DIRECTION_RULES ? 1 : undefined, meteo: { pluie: m.pluie, vent: m.vent, chaleur: m.chaleur, terrain: m.terrain, sens: m.sens } };
    return { libelle: meteoLibelle(l), conseil: meteoConseilBase(l, l.meteo), ventDos: ventSensActif(l) ? [m.sens, 1 - m.sens] : null, pluie: m.pluie, chaleur: m.chaleur };
  }
  function receive(s, d) {
    typeInjuries(s, d);
    const st = ensure(s), F = facts(s, d);
    // Première réception (nouvelle carrière, ancienne sauvegarde) : mémoire seule, aucun mail.
    const first = st.last === null;
    for (const m of st.mails) if (m.status === 'nouveau' && d > shift(m.date, C.delaiReponse ?? 7)) m.status = 'classe';
    const candidates = [];
    if (!first) {
      const context = clubVars(F);
      for (const su of st.suites) if (su.date <= d) candidates.push({ type: su.type, key: su.key, vars: { ...su.vars, ...context }, player: su.player, suite: true });
      st.suites = st.suites.filter(su => su.date > d);
      for (const [type, t] of Object.entries(TYPES)) {
        const trigger = T[t.declencheur];
        if (!trigger || t.declencheur === 'suite') continue;
        let list = [];
        try { list = trigger(F, t, st) || []; } catch (e) { list = []; }
        for (const c of list) candidates.push({ type, ...c, vars: { ...context, ...(c.vars || {}) } });
      }
    }
    // Décisions du directeur sportif (prolongations, départs) : en alternance, à priorité égale, pour que le quota
    // hebdomadaire des contrats ne soit pas pris tout entier par un seul type (18/11/2026).
    const rang = {}, alterne = c => TYPES[c.type]?.declencheur === 'ds_contrats';
    for (const c of candidates) if (alterne(c)) c.rang = rang[c.type] = (rang[c.type] ?? -1) + 1;
    candidates.sort((a, b) => (TYPES[a.type]?.priorite ?? 99) - (TYPES[b.type]?.priorite ?? 99) || (a.rang ?? 0) - (b.rang ?? 0) || (a.type < b.type ? -1 : a.type > b.type ? 1 : 0));
    const week = monday(d), counts = {};
    for (const m of st.mails) if (m.date >= week) { const c = TYPES[m.type]?.categorie; counts[c] = (counts[c] || 0) + 1; }
    let received = 0;
    const players = new Set();
    for (const c of candidates) {
      if (received >= (C.maxParJour ?? 3)) break;
      const t = TYPES[c.type]; if (!t) continue;
      const key = c.type + ':' + c.key, cat = t.categorie;
      if (!c.suite && st.sent[key]) continue;
      if (!c.suite && t.intervalle && st.memo.lastType?.[c.type] && d < shift(st.memo.lastType[c.type], t.intervalle)) continue;
      if (!c.suite && (counts[cat] || 0) >= (C.semaine?.[cat] ?? 2)) continue;
      // Un même joueur n'écrit (ou n'est cité) qu'une fois par jour.
      if (c.player && players.has(c.player)) continue;
      const n = (t.formulations || []).length || 1;
      let f = hash(d + '|' + s.club + '|' + key) % n;
      if (n > 1 && st.memo.lastF[c.type] === f) f = (f + 1) % n;
      st.memo.lastF[c.type] = f;
      st.memo.lastType[c.type] = d;
      st.sent[key] = d;
      counts[cat] = (counts[cat] || 0) + 1;
      if (c.player) players.add(c.player);
      received++;
      st.mails.push({ id: 'mail-' + (++st.seq), type: c.type, date: d, f, vars: sanitize(c.vars || {}), player: c.player ? String(c.player) : null, ...(c.club != null && c.club !== '' ? { club: c.club } : {}), status: (t.reponses || []).length ? 'nouveau' : 'info', choice: null });
      // Mercato : faits annoncés dans ce courrier, ni répétés au suivant ni redonnés seuls.
      if (Array.isArray(c.vus) && c.vus.length) voir(st, s, c.vus);
    }
    remember(s, st, F);
    st.memo.season = s.season;
    // Mémoire bornée : sujets récents, boîte plafonnée (les demandes en attente restent).
    const horizon = shift(d, -(C.memoire ?? 150));
    for (const [k, v] of Object.entries(st.sent)) if (v < horizon) delete st.sent[k];
    const max = C.boite ?? 160;
    while (st.mails.length > max) { const i = st.mails.findIndex(m => m.status !== 'nouveau'); st.mails.splice(i < 0 ? 0 : i, 1); }
    st.last = d;
  }
  function sanitize(vars) {
    const out = {};
    for (const [k, v] of Object.entries(vars)) if (/^[a-zé_]{1,24}$/i.test(k)) out[k] = typeof v === 'number' && Number.isFinite(v) ? v : String(v ?? '').slice(0, 400);
    return out;
  }

  // ------------------------------------------------------------------ affichage
  const fill = (template, vars) => String(template || '').replace(/\{([^}]+)\}/g, (_, k) => vars[k] === undefined ? '' : String(vars[k]));
  function render(m) {
    const t = TYPES[m.type] || {}, form = (t.formulations || [])[m.f] || (t.formulations || [])[0] || {};
    let corps = fill(form.corps, m.vars);
    // Courrier en liste (mercato) : puces et titres vides retirés.
    // « 1er juillet » ne se coupe pas en fin de ligne (espace insécable).
    if (t.liste) corps = corps.split('\n').filter(l => l.trim() !== '•').join('\n').replace(/\n{3,}/g, '\n\n').trim().replace(/\b1er (?=\p{L})/gu, '1er ');
    return { sujet: fill(form.sujet, m.vars), corps, expediteur: fill(t.expediteur, m.vars) };
  }
  const SIGN = n => (n > 0 ? '+' : '−') + Math.abs(n);
  function effectText(e, p = null, d = null) {
    const out = [], med = medicalEffects(e, p);
    if (med.rechute) out.push('Risque de rechute ' + SIGN(med.rechute.after - med.rechute.before) + ' (' + med.rechute.after + ' %)');
    if (med.retour) { const n = Math.abs(med.retour.delta); out.push('Retour ' + (med.retour.delta < 0 ? 'avancé' : 'retardé') + (date(d) ? ' au ' + shortDate(shift(d, med.retour.weeks * 7)) : n > 1 ? ' de ' + n + ' semaines' : " d'une semaine")); }
    const gauge = { moral: 'Moral', confiance: 'Confiance de la direction', supporters: 'Supporters', medias: 'Médias', pression: 'Pression', satisfaction: 'Satisfaction', fatigue: 'Charge', condition: 'Condition' };
    for (const [k, l] of Object.entries(gauge)) if (Number.isFinite(e[k]) && e[k]) out.push(l + ' ' + SIGN(e[k]));
    if (e.plan) out.push('Charge individuelle : ' + (PLAN_LABELS[e.plan] || e.plan));
    if (e.entrainement) out.push('Séance : ' + (MODE_LABELS[e.entrainement] || e.entrainement));
    if (e.focus) out.push('Préparation : ' + (FOCUS_LABELS[e.focus] || e.focus));
    if (e.promesse) out.push('Promesse de temps de jeu (3 rencontres)');
    if (e.promouvoir) out.push('Premier contrat professionnel');
    if (Number.isFinite(e.caisse) && e.caisse) out.push((e.caisse > 0 ? 'Recette ' : 'Coût ') + euros(Math.abs(e.caisse)) + ' €');
    if (e.appel) { const sx = TYPES.discipline?.seuils || {}; out.push('Frais ' + euros(sx.frais || 1500) + ' € ; amende annulée ou portée à ' + euros(sx.alourdie || 7500) + ' €'); }
    if (e.doublon) out.push({ rotation: 'Cadres fatigués en récupération jusqu’au match', forte: 'Meilleure feuille possible', jeunes: 'Jeunes du centre : premier contrat professionnel' }[e.doublon] || e.doublon);
    if (e.repos_liste) out.push({ reposer: 'Il sort de la feuille', amenagement: 'Accord possible, pas garanti', ignorer: 'Relation avec la fédération −3' }[e.repos_liste] || e.repos_liste);
    if (e.orientation) out.push('Investissements : ' + (ORIENTATION_LABELS[e.orientation] || e.orientation));
    if (e.pret === 'vendre') out.push('Vente immédiate, prix affecté au remboursement');
    if (e.pret === 'accepter') out.push('Remboursement sur plusieurs saisons');
    if (e.a2r === 'apport') out.push('Demande d’apport au propriétaire');
    if (e.a2r === 'appel') out.push('Frais ' + euros(typeof nativeA2R !== 'undefined' ? nativeA2R.APPEL.frais : 15000) + ' € ; mesure allégée si l’appel est gagné');
    if (e.reprise === 'lister') out.push('Joueurs désignés proposés aux autres clubs');
    if (e.reprise === 'confier') out.push('Le président vend sans attendre');
    if (e.reprise === 'delai') out.push('Deux semaines de plus');
    if (e.suite) out.push('Suite dans ' + e.suite.jours + ' jours');
    if (e.specialiste) out.push('Retour possible au 7e jour, sans garantie');
    if (e.contratDS === 'annuler') out.push('Il partira à la fin de son contrat ; prime remboursée');
    if (e.contratDS === 'forcer') out.push('Prolongation au salaire demandé');
    if (e.consigneDS) out.push('Consigne : ' + ({ econome: 'économe', jeunes: 'miser sur les jeunes', equilibre: 'équilibre' }[e.consigneDS] || e.consigneDS));
    return out.join(' · ');
  }
  // Raison pour laquelle une réponse n'est pas possible aujourd'hui ('' : possible).
  function unavailable(s, m, r) {
    // Match terminé et résultat confirmé (calendrier journalier : S.live reste jusqu'à la clôture de la semaine) : on répond.
    if (!s || (s.live && !(s.live.finished && s.worldMode?.resultConfirmed)) || s.phase === 'ended') return 'Indisponible pendant un match ou après la saison.';
    const e = r.effets || {}, club = s.clubs[s.club], p = m.player ? club.players.find(x => x.id === m.player) : null;
    const playerEffects = ['satisfaction', 'fatigue', 'condition', 'plan', 'promesse', 'rechute', 'retour', 'specialiste'].some(k => e[k] !== undefined);
    if (playerEffects && !p) return 'Ce joueur ne fait plus partie de l’effectif.';
    if ((e.entrainement || e.focus) && s.trained) return 'La séance de la semaine est déjà faite.';
    if (e.focus && s.collectivePrepVersion !== 1) return 'Préparation collective indisponible.';
    if (Number.isFinite(e.caisse) && e.caisse < 0 && (club.cash ?? 0) < -e.caisse) return 'Trésorerie insuffisante.';
    if (e.doublon || e.repos_liste) {
      if (typeof nativeSystems === 'undefined') return 'Indisponible.';
      const raison = nativeSystems.domain('doublons').refus(s, m, e.doublon || e.repos_liste);
      if (raison) return raison;
    }
    if (e.orientation && !(typeof investCourrier === 'function' && investCourrier())) return 'La répartition de cette saison est déjà arrêtée.';
    if (e.pret === 'vendre') { const raison = typeof pretVenteRefus === 'function' ? pretVenteRefus() : 'Vente impossible.'; if (raison) return raison; }
    if (e.pret === 'accepter' && !(typeof pretCourrier === 'function' && pretCourrier())) return 'Le président a déjà tranché.';
    if (e.a2r) { if (typeof a2rRefus !== 'function') return 'Décision de l’A2R indisponible.'; const raison = a2rRefus(e.a2r); if (raison) return raison; }
    if (e.reprise) { if (typeof repriseRefus !== 'function') return 'Le président a déjà tranché.'; const raison = repriseRefus(e.reprise); if (raison) return raison; }
    if (e.appel) { const sx = TYPES.discipline?.seuils || {}; if ((club.cash ?? 0) < (sx.frais || 1500) + (sx.alourdie || 7500)) return 'Trésorerie insuffisante pour un appel.'; }
    // Promesse : makePlayingPromise la refuse tant que le match de la semaine n'est pas clos (S.live), même confirmé.
    if (e.promesse) {
      // makePlayingPromise refuse tant que le match reste ouvert (résultat confirmé, journée pas encore close).
      if (s.live) return 'Promesse possible une fois la journée close.';
      if (typeof satisfactionActive !== 'function' || !satisfactionActive() || s.phase !== 'league' || s.round > 23 || Object.keys(s.economy?.talks || {}).length || p.injury || p.satisfaction?.promise) return 'Promesse impossible : phase régulière, joueur apte et sans promesse en cours.';
    }
    if (e.contratDS || e.consigneDS) {
      if (typeof dsContratsRefus !== 'function') return 'Le directeur sportif ne gère pas les contrats.';
      const raison = dsContratsRefus(e.contratDS || e.consigneDS, m.player);
      if (raison) return raison;
    }
    if (e.specialiste) {
      const prot = p ? commotionApi()?.protocol(p) : null;
      if (!prot) return 'Il a terminé son protocole commotion.';
      if (prot.exception !== 'possible') return prot.exception === 'non' ? 'L’exception à 7 jours n’est pas ouverte : 12 jours de repos.' : 'Le spécialiste a déjà rendu son avis.';
    }
    if (e.promouvoir) {
      const y = (s.development?.academy || []).find(x => x.id === m.player);
      if (!y) return 'Ce jeune n’est plus au centre.';
      if (typeof professionalPlaces === 'function' && professionalPlaces() <= 0) return 'Effectif professionnel complet.';
    }
    return '';
  }

  // Nature d'un type de courrier (club-mail.json) et rang d'importance dans la journée : réponse attendue d'abord,
  // puis information, puis routine ; à nature égale, la priorité du type (plus petite = plus importante).
  // Repli pour un type encore écrit avec l'ancien drapeau `arret` (branche antérieure) : arret → action, sinon routine.
  function nature(type) { const t = TYPES[type] || {}, n = t.nature; return n === 'action' || n === 'info' || n === 'routine' ? n : t.arret ? 'action' : 'routine'; }
  function rang(type) { return ({ action: 3, info: 2, routine: 1 })[nature(type)] * 1000 - Math.min(999, TYPES[type]?.priorite ?? 99); }

  // ------------------------------------------------------------------ délégation à l'adjoint (Léo, 23/11/2026)
  // « Déléguer » (choix `deleguer` de `club_mail_reply`) : Gabi répond à la place du manager avec une des réponses du
  // mail. Choix déterministe (aucun tirage, rejoué à l'identique par le journal) parmi les réponses possibles
  // aujourd'hui qui n'ouvrent pas un écran : chaque réponse est notée selon ses effets et le contexte (moral du groupe,
  // confiance de la direction, trésorerie, charge, satisfaction et rechute du joueur, fatigue de l'effectif). Gabi est
  // prudent : pas de dépense qui pèse sur la caisse, pas de promesse ni de décision de structure (vente, appel, A2R,
  // contrats, promotion, consignes) quand une réponse plus sage existe. À égalité, la première réponse du type.
  // Aucune réponse possible hors écran (commotion : l'infirmerie décide) : pas de délégation.
  const DELEGUER = 'deleguer';
  const fatigueJoueur = p => Number(p?.physicalLoad?.fatigue) || 0;
  function contexteAdjoint(s, m) {
    const club = s.clubs[s.club], p = m.player ? club.players.find(x => x.id === m.player) || null : null;
    const charges = club.players.map(fatigueJoueur);
    return { p, moral: s.morale ?? 70, confiance: s.trust ?? 50, caisse: Math.max(0, club.cash ?? 0),
      fatigue: p ? fatigueJoueur(p) : 0, effectif: charges.length ? charges.reduce((a, b) => a + b, 0) / charges.length : 0,
      satisfaction: p?.satisfaction?.score ?? 65, focus: s.collectiveFocus ?? null };
  }
  // Note d'une réponse pour l'adjoint (plus haute = préférée).
  function noteAdjoint(x, r) {
    const e = r.effets || {};
    let n = 0;
    const cout = euros => euros / 4000 + 30 * euros / Math.max(x.caisse, 1000);
    if (Number.isFinite(e.moral)) n += e.moral * (x.moral < 55 ? 4.5 : 3);
    if (Number.isFinite(e.confiance)) n += e.confiance * (x.confiance < 40 ? 4 : 2);
    if (Number.isFinite(e.supporters)) n += e.supporters * 1.5;
    if (Number.isFinite(e.medias)) n += e.medias;
    if (Number.isFinite(e.pression)) n -= e.pression * 1.5;
    if (Number.isFinite(e.satisfaction)) n += e.satisfaction * (x.satisfaction < 50 ? 1.5 : 1);
    if (Number.isFinite(e.fatigue)) n -= e.fatigue * (x.fatigue >= 60 ? 0.6 : 0.25);
    if (Number.isFinite(e.condition)) n += e.condition * 0.3;
    const med = medicalEffects(e, x.p);
    if (med.rechute) n -= (med.rechute.after - med.rechute.before) * 0.5;
    if (med.retour) n -= med.retour.delta * 2;
    // Charge individuelle : besoin de repos selon la fatigue du joueur ; jamais de pleine charge pour un joueur qui
    // relève de blessure (risque de rechute en cours).
    const besoin = (x.fatigue - 45) / 10;
    if (e.plan === 'repos') n += 2 * besoin - 0.5;
    if (e.plan === 'normal') n += Math.max(0.5, 0.5 + besoin * 0.5);
    if (e.plan === 'collective' || e.plan === 'intense') n -= 2 + Math.max(0, besoin) + (Number(x.p?.injuryRelapse) > 0 ? 2 : 0);
    // Séance collective selon la fatigue moyenne de l'effectif.
    if (e.entrainement === 'repos') n += (x.effectif - 35) / 5;
    if (e.entrainement === 'intense') n += (25 - x.effectif) / 5 - 1;
    if (e.focus) n += e.focus === x.focus ? 0 : 0.5;
    if (Number.isFinite(e.caisse) && e.caisse < 0) n -= cout(-e.caisse);
    if (Number.isFinite(e.caisse) && e.caisse > 0) n += e.caisse / 4000 * (x.caisse < 200000 ? 2 : 1);
    if (e.appel) { const sx = TYPES.discipline?.seuils || {}; n -= cout((sx.frais || 1500) + (sx.alourdie || 7500) / 2); }
    if (e.suite && !e.appel) n += 1;
    if (e.promesse) n += x.satisfaction < 45 ? 2 : -2;
    if (e.promouvoir) n -= 1;
    if (e.pret === 'vendre') n -= 6;
    if (e.contratDS) n -= 3;
    if (e.consigneDS) n -= 3;
    if (e.a2r === 'appel') n -= 3;
    if (e.repos_liste === 'ignorer') n -= 3;
    return Math.round(n * 1000);
  }
  // Réponse que Gabi donnerait aujourd'hui (objet de club-mail.json) ou null ; `dispo(r)` : vrai si possible.
  function adjoint(s, m, dispo = r => !unavailable(s, m, r)) {
    if (!s || !m || m.status !== 'nouveau') return null;
    const options = (TYPES[m.type]?.reponses || []).filter(r => !r.ouvrir && dispo(r));
    if (!options.length) return null;
    const x = contexteAdjoint(s, m);
    let best = null, top = -Infinity;
    for (const r of options) { const n = noteAdjoint(x, r); if (n > top) { top = n; best = r; } }
    return best;
  }
  // Famille d'une réponse pour l'interface (couleur et pictogramme) : effet favorable dominant, sinon coût, attente,
  // refus ou rien. Ordre : écran, soin, effort, jeu, promesse, direction, compétition, argent, presse, groupe.
  function genre(r) {
    const e = r.effets || {}, pos = k => Number.isFinite(e[k]) && e[k] > 0;
    if (r.ouvrir) return 'ecran';
    if (e.specialiste || e.plan === 'repos' || e.plan === 'normal' || e.entrainement === 'repos' || (Number.isFinite(e.fatigue) && e.fatigue < 0) || (Number.isFinite(e.rechute) && e.rechute < 0)) return 'soin';
    if (e.entrainement === 'intense' || e.plan === 'collective' || e.plan === 'intense' || pos('fatigue') || pos('rechute')) return 'effort';
    if (e.focus) return 'jeu';
    if (e.promesse) return 'promesse';
    if (e.orientation || e.a2r || e.reprise || e.pret || e.contratDS || e.consigneDS || e.promouvoir || pos('confiance') || (Number.isFinite(e.pression) && e.pression < 0)) return 'direction';
    if (e.doublon || e.repos_liste) return 'competition';
    if (pos('caisse')) return 'argent';
    if (pos('medias') || pos('supporters')) return 'presse';
    if (pos('moral') || pos('satisfaction') || pos('condition')) return 'groupe';
    if ((Number.isFinite(e.caisse) && e.caisse < 0) || e.appel) return 'argent';
    if (e.suite) return 'attente';
    if (['moral', 'satisfaction', 'medias', 'supporters', 'confiance'].some(k => Number.isFinite(e[k]) && e[k] < 0)) return 'refus';
    return 'neutre';
  }

  function project() {
    if (typeof S === 'undefined' || !S || !obj(S.clubMail)) return { mails: [], reponses: {}, delegues: {}, attente: 0, blessures: Object.fromEntries(Object.entries(BL.types || {}).map(([k, t]) => [k, t.libelle])) };
    const st = S.clubMail, list = st.mails.slice(-(C.projection ?? 80)).reverse();
    const reponses = {};
    for (const m of st.mails) if (m.choice) reponses[m.id] = m.choice;
    return {
      mails: list.map(m => {
        const t = TYPES[m.type] || {}, r = render(m), cat = D.categories?.[t.categorie] || {};
        const chosen = (t.reponses || []).find(x => x.id === m.choice);
        const mail = { id: m.id, type: m.type, date: m.date, categorie: t.categorie || 'moments', categorieLabel: cat.label || 'Club', expediteur: r.expediteur, sujet: r.sujet, corps: r.corps,
          arret: nature(m.type) === 'action', nature: nature(m.type), importance: rang(m.type), ecran: t.ecran || cat.ecran || 'Bureau', joueur: m.player, club: m.club ?? null, status: m.status, choice: m.choice, resultat: chosen ? (m.verdict ? chosen.resultat + ' ' + m.verdict : chosen.resultat) : null,
          reponses: [], delegue: m.delegue === true, reponse: chosen ? { id: chosen.id, libelle: chosen.libelle, genre: genre(chosen) } : null };
        if (m.status !== 'nouveau') return mail;
        const raisons = {};
        mail.reponses = (t.reponses || []).map(x => { const raison = raisons[x.id] = unavailable(S, m, x); return { id: x.id, libelle: x.libelle, effets: effectText(x.effets || {}, m.player ? S.clubs[S.club]?.players?.find(y => y.id === m.player) : null, todayOf(S) || m.date), disponible: !raison, raison, ouvrir: !!x.ouvrir, genre: genre(x) }; });
        // Réponse que Gabi donnerait s'il recevait la délégation (null : pas de délégation possible).
        mail.adjoint = adjoint(S, m, x => !raisons[x.id])?.id ?? null;
        return mail;
      }),
      reponses, attente: st.mails.filter(m => m.status === 'nouveau').length,
      // Mails auxquels Gabi a répondu (délégation) : affichage « Gabi a répondu », retouché dès le clic par l'interface.
      delegues: Object.fromEntries(st.mails.filter(m => m.delegue === true).map(m => [m.id, true])),
      blessures: Object.fromEntries(Object.entries(BL.types || {}).map(([k, t]) => [k, t.libelle])),
    };
  }

  // Courrier du jour vu par « Continuer » (continuer.cjs), le plus important d'abord, avec sa nature (décision de
  // Léo, 18/11/2026) : « action » arrête l'avance à lui seul, « info » est rangé dans l'arrêt d'info du jour,
  // « routine » n'arrête jamais à lui seul. Tous restent en Réception, lisibles et avec leurs réponses.
  function stops(s) {
    if (!s || !obj(s.clubMail) || !world(s)) return [];
    const d = todayOf(s);
    return s.clubMail.mails.filter(m => m.date === d && TYPES[m.type] && m.status === 'nouveau')
      .sort((a, b) => rang(b.type) - rang(a.type) || (a.id < b.id ? -1 : a.id > b.id ? 1 : 0))
      .map(m => { const r = render(m); return { id: m.id, type: m.type, nature: nature(m.type), priorite: TYPES[m.type].priorite ?? 99, sujet: r.sujet, expediteur: r.expediteur, ecran: TYPES[m.type].ecran || 'Bureau', joueur: m.player }; });
  }

  // ------------------------------------------------------------------ réponse du manager (seul effet sur le monde)
  function apply(s, m, r) {
    const e = r.effets || {}, club = s.clubs[s.club], p = m.player ? club.players.find(x => x.id === m.player) : null, d = todayOf(s) || m.date;
    if (Number.isFinite(e.moral)) s.morale = clampN((s.morale ?? 70) + e.moral, 25, 98);
    if (Number.isFinite(e.confiance)) s.trust = clampN((s.trust ?? 50) + e.confiance, 0, 100);
    const pr = s.pressRelations;
    for (const [k, f] of [['supporters', 'fanTrust'], ['medias', 'mediaTrust'], ['pression', 'boardPressure']]) if (Number.isFinite(e[k]) && pr && Number.isFinite(pr[f])) pr[f] = clampN(pr[f] + e[k], 0, 100);
    if (p && Number.isFinite(e.satisfaction) && typeof ensureSatisfaction === 'function') { const st = ensureSatisfaction(p); if (st) st.score = clampN(st.score + e.satisfaction, 20, 95); }
    if (p && Number.isFinite(e.fatigue) && typeof ensurePhysicalLoad === 'function') { const l = ensurePhysicalLoad(p); l.fatigue = clampN(Math.round(l.fatigue + e.fatigue), 0, 100); }
    if (p && Number.isFinite(e.condition)) p.condition = clampN(p.condition + e.condition, 0, 100);
    if (p && e.plan && typeof ensurePhysicalLoad === 'function') ensurePhysicalLoad(p).plan = e.plan;
    const med = medicalEffects(e, p);
    if (med.rechute) p.injuryRelapse = med.rechute.after;
    if (med.retour) p.injury = med.retour.weeks;
    if (e.entrainement) s.training = e.entrainement;
    if (e.focus) s.collectiveFocus = e.focus;
    if (e.promesse) check(makePlayingPromise(p.id, e.promesse) === true, 'promesse refusée');
    if (e.promouvoir) check(promoteYouth(m.player) === true, 'promotion refusée');
    if (e.contratDS) check(dsContratsAction(e.contratDS, m.player) === true, 'décision refusée');
    if (e.consigneDS) check(dsContratsAction(e.consigneDS, m.player) === true, 'consigne refusée');
    if (e.doublon || e.repos_liste) m.verdict = String(nativeSystems.domain('doublons').agir(s, m, e.doublon || e.repos_liste)).slice(0, 190);
    if (e.orientation) check(investOrienter(e.orientation) === true, 'répartition refusée');
    if (e.pret) check(pretRepondre(e.pret) === true, 'réponse au prêt refusée');
    if (e.a2r) { const r = a2rAction(e.a2r); check(!!r && r.ok, r?.raison || 'réponse refusée'); if (r.verdict) m.verdict = r.verdict; }
    if (e.reprise) { const r = repriseAction(e.reprise); check(!!r && r.ok, r?.raison || 'réponse refusée'); if (r.verdict) m.verdict = r.verdict; }
    if (e.specialiste) {
      const avis = commotionApi()?.specialistReview(s, p);
      check(!!avis, 'avis du spécialiste indisponible');
      m.verdict = avis.favorable ? 'Avis favorable du spécialiste indépendant : il pourra rejouer dès le ' + shortDate(avis.retour) + ' (7e jour).' : 'Avis défavorable du spécialiste indépendant : il observera les 12 jours, retour possible le ' + shortDate(avis.retour) + '.';
    }
    if (Number.isFinite(e.caisse) && e.caisse) ledgerEntry('Courrier · ' + render(m).sujet.slice(0, 60), e.caisse);
    if (e.appel) {
      const sx = TYPES.discipline?.seuils || {}, favorable = hash(m.id + ':' + s.club + ':appel') % 2 === 0;
      ledgerEntry('Commission de discipline · frais d’appel', -(sx.frais || 1500));
      if (!favorable) ledgerEntry('Commission de discipline · amende', -(sx.alourdie || 7500));
      m.verdict = favorable ? 'Appel gagné : l’amende est annulée.' : 'Appel rejeté : l’amende est portée à ' + euros(sx.alourdie || 7500) + ' €.';
    }
    if (e.suite && TYPES[e.suite.type]) {
      const vars = { ...m.vars };
      if (e.suite.type === 'rapport_agent') {
        let q = null; try { q = managerPool().find(x => String(x.id) === m.player) || null; } catch { q = null; }
        const ratings = club.players.map(x => x.rating).sort((a, b) => a - b), median = ratings[Math.floor(ratings.length / 2)] || 0;
        vars.note = q ? q.rating : '?';
        vars.potentiel = q ? Math.round((Number(q.dev?.potential) || q.rating) / 5) * 5 : '?';
        vars.avis = !q ? 'Il n’est plus disponible sur le marché.' : q.rating >= median + 3 ? 'Il serait un vrai renfort pour nous.' : q.rating >= median - 2 ? 'Un joueur de rotation correct, sans plus.' : 'Pas au niveau de notre effectif, à mon avis.';
      }
      if (e.suite.type === 'verdict_appel') vars.verdict = m.verdict || '';
      s.clubMail.suites.push({ type: e.suite.type, key: m.id, date: shift(d, e.suite.jours), player: m.player, vars: sanitize(vars) });
      s.clubMail.suites = s.clubMail.suites.slice(-20);
    }
  }

  function execute(command, payload) {
    check(typeof S !== 'undefined' && !!S, 'aucune carrière');
    check(command === 'club_mail_reply', 'commande inconnue');
    check(obj(payload) && Object.keys(payload).every(k => ['id', 'choice'].includes(k)) && text(payload.id, 40) && text(payload.choice, 40), 'paramètres invalides');
    const st = S.clubMail, m = obj(st) ? st.mails.find(x => x.id === payload.id) : null;
    check(!!m, 'ce mail n’existe plus');
    check(m.status === 'nouveau', m.status === 'repondu' ? 'tu as déjà répondu à ce mail' : 'ce mail n’appelle plus de réponse');
    // « deleguer » : Gabi choisit à la place du manager (adjoint) ; jamais une réponse qui ouvre un écran.
    const delegue = payload.choice === DELEGUER;
    const r = delegue ? adjoint(S, m) : (TYPES[m.type]?.reponses || []).find(x => x.id === payload.choice);
    check(!!r, delegue ? 'Gabi ne peut pas répondre à ta place à ce mail' : 'réponse inconnue');
    const reason = unavailable(S, m, r);
    check(!reason, reason.replace(/\.$/, ''));
    apply(S, m, r);
    m.status = 'repondu';
    m.choice = r.id;
    if (delegue) m.delegue = true;
    validate(S);
    return { clubMailReply: { id: m.id, choice: r.id, delegue, resultat: m.verdict ? r.resultat + ' ' + m.verdict : r.resultat, ouvrir: !delegue && !!r.ouvrir, ecran: r.ecran || TYPES[m.type].ecran || null, joueur: m.player } };
  }

  // Après chaque commande : une réception par jour de calendrier (carrière Monde journalière, saison ouverte).
  function observe() {
    if (typeof S === 'undefined' || !S || !world(S) || pending(S) || S.phase === 'ended') return false;
    const d = todayOf(S);
    typeInjuries(S, d);
    if (!date(d) || S.clubMail?.last === d) return false;
    // Nouveau jour : le médecin recale d'abord les disponibilités des joueurs en protocole commotion (tous les clubs),
    // puis le courrier du jour est reçu (la réception elle-même n'écrit que la boîte).
    if (!(S.live && !S.live.finished)) commotionApi()?.syncAt(S, d);
    receive(S, d);
    return true;
  }

  function validate(s) {
    if (!s || s.clubMail === undefined) return true;
    const st = s.clubMail;
    check(obj(st) && st.version === 1 && int(st.seq, 0, 1e9) && (st.last === null || date(st.last)) && Array.isArray(st.mails) && st.mails.length <= (C.boite ?? 160) && obj(st.sent) && Array.isArray(st.suites) && st.suites.length <= 20 && obj(st.memo), 'boîte invalide');
    const ids = new Set();
    for (const m of st.mails) {
      check(obj(m) && /^mail-\d{1,9}$/.test(m.id) && !ids.has(m.id) && Number(m.id.slice(5)) <= st.seq && TYPES[m.type] !== undefined && date(m.date) && int(m.f, 0, 20) && obj(m.vars) && (m.player === null || text(m.player, 180)) && STATUS.includes(m.status), 'mail invalide');
      check(m.status === 'repondu' ? (TYPES[m.type].reponses || []).some(x => x.id === m.choice) : m.choice === null, 'réponse enregistrée invalide');
      check(m.verdict === undefined || text(m.verdict, 200), 'verdict invalide');
      check(m.delegue === undefined || (m.delegue === true && m.status === 'repondu'), 'délégation invalide');
      check(m.club === undefined || int(m.club, 0, 1e9) || text(m.club, 40), 'club du mail invalide');
      for (const v of Object.values(m.vars)) check(typeof v === 'number' ? Number.isFinite(v) : text(v, 400), 'variable invalide');
      ids.add(m.id);
    }
    for (const club of Object.values(s.clubs || {})) for (const p of club?.players || []) {
      check(p.injuryType === undefined || (text(p.injuryType, 40) && BL.types?.[p.injuryType] !== undefined), 'type de blessure invalide');
      check(p.injuryCause === undefined || CAUSES.includes(p.injuryCause), 'cause de blessure invalide');
      check(p.injuryOrigin === undefined || (obj(p.injuryOrigin) && CAUSES.includes(p.injuryOrigin.type) && (p.injuryOrigin.fixtureId === undefined || p.injuryOrigin.fixtureId === null || text(String(p.injuryOrigin.fixtureId), 120)) && (p.injuryOrigin.oppName === undefined || p.injuryOrigin.oppName === null || text(p.injuryOrigin.oppName, 120))), 'origine de blessure invalide');
      check(p.injuryDate === undefined || date(p.injuryDate), 'date de blessure invalide');
      check(p.injuryRelapse === undefined || int(p.injuryRelapse, 0, 100), 'risque de rechute invalide');
    }
    for (const su of st.suites) check(obj(su) && TYPES[su.type] !== undefined && date(su.date) && text(su.key, 200) && (su.player === null || su.player === undefined || text(su.player, 180)) && obj(su.vars), 'suite invalide');
    for (const [k, v] of Object.entries(st.sent)) check(text(k, 300) && date(v), 'mémoire invalide');
    return true;
  }

  // `recevoir(s, d)` : réception sur un état donné (tests : une réception n'écrit que la boîte).
  // Origine de la blessure, enregistrée sur le joueur AU MOMENT où elle survient (demande de Léo, 18/11/2026) :
  // le bulletin la lit là (causeText), sans dépendre du journal du club. Entraînement hebdomadaire (trainWeek) et
  // rencontre jouée (applyMatchInjuries : id de la rencontre, adversaire, lieu, score) ; la rechute se pose dans
  // typeInjuries. Seul le club géré est suivi ; les moteurs de match et d'entraînement ne sont pas modifiés.
  function matchOrigin(st, l, side) {
    const opp = l.pair[1 - side];
    const fx = (st.worldMode?.fixtures || []).find(f => f.homeId === l.pair[0] && f.awayId === l.pair[1] && f.week === st.round) || null;
    const named = st.clubs?.[opp]?.name || fx?.[side === 0 ? 'awayName' : 'homeName'] || null;
    return { type: 'match', fixtureId: fx?.id ?? null, opp, oppName: named, home: side === 0, neutral: !!fx?.neutral, us: Number(l.score?.[side]) || 0, them: Number(l.score?.[1 - side]) || 0, date: date(fx?.date) ? fx.date : null, season: st.season ?? null, round: st.round ?? null };
  }
  function installHooks() {
    const ownState = () => { const st = typeof S === 'undefined' ? null : S; return st && st.clubs?.[st.club]?.players ? st : null; };
    const healthy = st => new Map(st.clubs[st.club].players.map(p => [p.id, !(Number(p.injury) > 0)]));
    const recordNew = (st, before, origin) => { for (const p of st.clubs[st.club].players) if (Number(p.injury) > 0 && before.get(p.id) === true) p.injuryOrigin = { ...origin }; };
    if (typeof trainWeek === 'function' && !trainWeek.__injuryOrigin) {
      const prior = trainWeek, wrapped = function () {
        const st = ownState(), before = st && !st.trained ? healthy(st) : null;
        const result = prior.apply(this, arguments);
        if (before && st === ownState()) recordNew(st, before, { type: 'entrainement', season: st.season ?? null, round: st.round ?? null });
        return result;
      };
      Object.assign(wrapped, prior); wrapped.__injuryOrigin = true; trainWeek = wrapped;
    }
    if (typeof applyMatchInjuries === 'function' && !applyMatchInjuries.__injuryOrigin) {
      const prior = applyMatchInjuries, wrapped = function (l) {
        const st = ownState(), side = st && l && Array.isArray(l.pair) && !l.injuriesApplied ? l.pair.indexOf(st.club) : -1;
        const before = side >= 0 ? healthy(st) : null;
        const result = prior.apply(this, arguments);
        if (before && st === ownState()) recordNew(st, before, matchOrigin(st, l, side));
        return result;
      };
      Object.assign(wrapped, prior); wrapped.__injuryOrigin = true; applyMatchInjuries = wrapped;
    }
    return true;
  }
  return { project, validate, execute, observe, stops, installHooks, recevoir: (s, d) => receive(s, d), adjoint: (s, id) => adjoint(s, s?.clubMail?.mails?.find(m => m.id === id))?.id ?? null, genre, blessures: { typer: typeInjuries, type: injuryKind, risque: relapseRisk, rechute: relapseChance, effets: effectText, cause: causeText } };
}

module.exports = { files, commands, factory, prelude, DATA };
