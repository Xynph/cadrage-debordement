'use strict';
// Courrier du club, façon Football Manager (décision de Léo, 16/11/2026) : chaque jour de la carrière Monde, des
// interlocuteurs du club (kiné, capitaine, adjoint, recruteur, agent, presse, président, commission…) écrivent au
// manager. Contenu en données (club-mail.json) : types, expéditeurs, formulations, réponses, effets, seuils, cadence.
//
// Règles :
//  - Recevoir un mail ne change rien au monde. La génération lit l'état et n'écrit que la boîte (S.clubMail) ; le
//    choix d'une formulation ou d'une variante vient d'une empreinte (date, club, type, sujet), jamais du flux de
//    hasard du moteur.
//  - Seule la réponse du manager a un effet : commande `club_mail_reply` {id, choice}, une décision comme les autres,
//    notée au journal d'actions (#762) et rejouée à l'identique. Les effets passent par les mécaniques existantes
//    (moral, confiance de la direction, relations presse, satisfaction, promesse de temps de jeu, charge physique,
//    séance collective, préparation collective, promotion d'un jeune, trésorerie) et restent mesurés.
//  - Cadence : plafond par jour, par catégorie et par semaine, intervalle par type, mémoire des sujets déjà écrits ;
//    les mails « arret » arrêtent « Continuer » (continuer.cjs, arrêt informatif « courrier »), les autres arrivent
//    dans la boîte sans arrêt.
const DATA = require('./club-mail.json');
const files = Object.freeze([]), commands = Object.freeze(['club_mail_reply']);
// Données injectées dans la VM avant les domaines (native-systems.cjs, bootstrap).
const prelude = 'const nativeClubMailData=JSON.parse(' + JSON.stringify(JSON.stringify(DATA)) + ');';

function factory() {
  const D = typeof nativeClubMailData !== 'undefined' ? nativeClubMailData : { types: {}, cadence: {}, categories: {} };
  const C = D.cadence || {}, TYPES = D.types || {};
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
  const EFFECTS = ['moral', 'confiance', 'supporters', 'medias', 'pression', 'satisfaction', 'fatigue', 'condition', 'plan', 'entrainement', 'focus', 'promesse', 'promouvoir', 'caisse', 'suite', 'appel', 'orientation'];
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

  // ------------------------------------------------------------------ déclencheurs : [{key, vars, player?}]
  const T = {
    bilan_kine(F) {
      if (F.dow !== 0) return [];
      const hurt = F.players.filter(p => p.injury > 0).sort((a, b) => b.injury - a.injury);
      if (!hurt.length) return [];
      return [{ key: F.d, vars: { n: hurt.length, liste: hurt.slice(0, 4).map(p => p.name + ' (' + p.injury + ' sem.)').join(', ') + (hurt.length > 4 ? ' et ' + (hurt.length - 4) + ' autre(s)' : '') } }];
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
      return [{ key: F.next.id, player: p.id, vars: { ...playerVars(p), condition: conditionOf(p), adversaire: F.name(F.opponent(F.next)) } }];
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
      const list = F.players.filter(p => !F.sheet.has(p.id) && !(p.injury > 0) && (p.age || 0) >= 20 && p.rating >= median - 2 && !p.satisfaction?.promise && (Number(p.dev?.appearances) || 0) <= Math.floor(played / 3))
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
      return [{ key: last.fixtureId || last.date, vars: { adversaire: F.name(last.opp), score: last.us + '-' + last.them, resultat: res, un: top[0].texte, deux: top[1].texte, trois: top[2].texte, axe: axe ? AXES[axe] : 'notre plan de jeu' } }];
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
      return [{ key: F.next.id, vars: { adversaire: F.name(opp), forme: F.form(opp) || 'inconnue', faiblesse } }];
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
    contrats(F) {
      if (F.dow !== 4 || !(F.s.round >= 6)) return [];
      const list = F.players.filter(p => p.contractEnd === F.s.season).sort((a, b) => b.rating - a.rating);
      if (!list.length) return [];
      return [{ key: F.d.slice(0, 7), vars: { n: list.length, liste: list.slice(0, 5).map(p => p.name + ' (' + p.pos + ')').join(', ') + (list.length > 5 ? ' et ' + (list.length - 5) + ' autre(s)' : '') } }];
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
      return [{ key: g.fixture.id, vars: { adversaire: F.name(r.opp), score: r.us + '-' + r.them, titre: pick(t.variantes?.[band], g.fixture.id) } }];
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
      return [{ key: F.next.id, vars: { adversaire: F.name(F.opponent(F.next)) } }];
    },
    affluence(F, t) {
      const g = F.playedOn(F.yesterday); if (!g || !g.result.home) return [];
      const fans = F.s.pressRelations?.fanTrust ?? 50, band = fans >= 60 ? 'plein' : fans >= 40 ? 'moyen' : 'faible';
      return [{ key: g.fixture.id, vars: { adversaire: F.name(g.result.opp), capacite: euros(Number(F.club.stadiumCapacity) || 0), ambiance: pick(t.variantes?.[band], g.fixture.id) } }];
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
    // Investissements des excédents (club-investments.cjs) : une fois par saison, tant que le manager n'a pas orienté.
    investissements(F) {
      const v = typeof investCourrier === 'function' ? investCourrier() : null;
      return v ? [{ key: 'investissements:' + F.s.season, vars: v }] : [];
    },
    supporters_derby(F, t) {
      const g = F.playedOn(F.yesterday); if (!g || !F.derby(g.result.opp)) return [];
      const o = F.outcome(g.result), band = o === 'V' ? 'victoire' : o === 'D' ? 'defaite' : 'nul';
      return [{ key: g.fixture.id, vars: { adversaire: F.name(g.result.opp), reaction: pick(t.variantes?.[band], g.fixture.id) } }];
    },
    arbitre(F) {
      if (!F.next || F.next.date !== shift(F.d, 3)) return [];
      return [{ key: F.next.id, vars: { adversaire: F.name(F.opponent(F.next)), profil: pick(D.profilsArbitre, F.next.id) } }];
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
      return [{ key: F.next.id, vars: { adversaire: F.name(F.opponent(F.next)), quand: F.next.date === F.d ? 'aujourd’hui' : 'demain', ciel: ciel.charAt(0).toUpperCase() + ciel.slice(1), ciel_bas: ciel, vent, conseil: m.conseil || '' } }];
    },
    pelouse(F) {
      if (!F.next || F.next.date !== shift(F.d, 1) || F.next.homeId !== F.s.club) return [];
      // Pelouse cohérente avec la météo annoncée : pluie (glissante), forte pluie (lourde), sinon la saison.
      const mt = annonceMeteo(F), month = Number(F.d.slice(5, 7)), season = month >= 6 && month <= 8 ? 'ete' : month >= 9 && month <= 11 ? 'automne' : month === 12 || month <= 2 ? 'hiver' : 'printemps';
      const band = mt && mt.pluie === 2 ? 'deluge' : mt && mt.pluie ? 'pluie' : mt && mt.chaleur ? 'ete' : season;
      return [{ key: F.next.id, vars: { adversaire: F.name(F.opponent(F.next)), pelouse: pick(D.pelouses?.[band], F.next.id) } }];
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
    candidates.sort((a, b) => (TYPES[a.type]?.priorite ?? 99) - (TYPES[b.type]?.priorite ?? 99) || (a.type < b.type ? -1 : a.type > b.type ? 1 : 0));
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
      st.mails.push({ id: 'mail-' + (++st.seq), type: c.type, date: d, f, vars: sanitize(c.vars || {}), player: c.player ? String(c.player) : null, status: (t.reponses || []).length ? 'nouveau' : 'info', choice: null });
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
    return { sujet: fill(form.sujet, m.vars), corps: fill(form.corps, m.vars), expediteur: fill(t.expediteur, m.vars) };
  }
  const SIGN = n => (n > 0 ? '+' : '−') + Math.abs(n);
  function effectText(e) {
    const out = [];
    const gauge = { moral: 'Moral', confiance: 'Confiance de la direction', supporters: 'Supporters', medias: 'Médias', pression: 'Pression', satisfaction: 'Satisfaction', fatigue: 'Charge', condition: 'Condition' };
    for (const [k, l] of Object.entries(gauge)) if (Number.isFinite(e[k]) && e[k]) out.push(l + ' ' + SIGN(e[k]));
    if (e.plan) out.push('Charge individuelle : ' + (PLAN_LABELS[e.plan] || e.plan));
    if (e.entrainement) out.push('Séance : ' + (MODE_LABELS[e.entrainement] || e.entrainement));
    if (e.focus) out.push('Préparation : ' + (FOCUS_LABELS[e.focus] || e.focus));
    if (e.promesse) out.push('Promesse de temps de jeu (3 rencontres)');
    if (e.promouvoir) out.push('Premier contrat professionnel');
    if (Number.isFinite(e.caisse) && e.caisse) out.push((e.caisse > 0 ? 'Recette ' : 'Coût ') + euros(Math.abs(e.caisse)) + ' €');
    if (e.appel) { const sx = TYPES.discipline?.seuils || {}; out.push('Frais ' + euros(sx.frais || 1500) + ' € ; amende annulée ou portée à ' + euros(sx.alourdie || 7500) + ' €'); }
    if (e.orientation) out.push('Investissements : ' + (ORIENTATION_LABELS[e.orientation] || e.orientation));
    if (e.suite) out.push('Suite dans ' + e.suite.jours + ' jours');
    return out.join(' · ');
  }
  // Raison pour laquelle une réponse n'est pas possible aujourd'hui ('' : possible).
  function unavailable(s, m, r) {
    if (!s || s.live || s.phase === 'ended') return 'Indisponible pendant un match ou après la saison.';
    const e = r.effets || {}, club = s.clubs[s.club], p = m.player ? club.players.find(x => x.id === m.player) : null;
    const playerEffects = ['satisfaction', 'fatigue', 'condition', 'plan', 'promesse'].some(k => e[k] !== undefined);
    if (playerEffects && !p) return 'Ce joueur ne fait plus partie de l’effectif.';
    if ((e.entrainement || e.focus) && s.trained) return 'La séance de la semaine est déjà faite.';
    if (e.focus && s.collectivePrepVersion !== 1) return 'Préparation collective indisponible.';
    if (Number.isFinite(e.caisse) && e.caisse < 0 && (club.cash ?? 0) < -e.caisse) return 'Trésorerie insuffisante.';
    if (e.orientation && !(typeof investCourrier === 'function' && investCourrier())) return 'La répartition de cette saison est déjà arrêtée.';
    if (e.appel) { const sx = TYPES.discipline?.seuils || {}; if ((club.cash ?? 0) < (sx.frais || 1500) + (sx.alourdie || 7500)) return 'Trésorerie insuffisante pour un appel.'; }
    if (e.promesse) {
      if (typeof satisfactionActive !== 'function' || !satisfactionActive() || s.phase !== 'league' || s.round > 23 || Object.keys(s.economy?.talks || {}).length || p.injury || p.satisfaction?.promise) return 'Promesse impossible : phase régulière, joueur apte et sans promesse en cours.';
    }
    if (e.promouvoir) {
      const y = (s.development?.academy || []).find(x => x.id === m.player);
      if (!y) return 'Ce jeune n’est plus au centre.';
      if (typeof professionalPlaces === 'function' && professionalPlaces() <= 0) return 'Effectif professionnel complet.';
    }
    return '';
  }

  function project() {
    if (typeof S === 'undefined' || !S || !obj(S.clubMail)) return { mails: [], reponses: {}, attente: 0 };
    const st = S.clubMail, list = st.mails.slice(-(C.projection ?? 80)).reverse();
    const reponses = {};
    for (const m of st.mails) if (m.choice) reponses[m.id] = m.choice;
    return {
      mails: list.map(m => {
        const t = TYPES[m.type] || {}, r = render(m), cat = D.categories?.[t.categorie] || {};
        const chosen = (t.reponses || []).find(x => x.id === m.choice);
        return { id: m.id, type: m.type, date: m.date, categorie: t.categorie || 'moments', categorieLabel: cat.label || 'Club', expediteur: r.expediteur, sujet: r.sujet, corps: r.corps,
          arret: !!t.arret, ecran: t.ecran || cat.ecran || 'Bureau', joueur: m.player, status: m.status, choice: m.choice, resultat: chosen ? (m.verdict ? chosen.resultat + ' ' + m.verdict : chosen.resultat) : null,
          reponses: m.status === 'nouveau' ? (t.reponses || []).map(x => { const raison = unavailable(S, m, x); return { id: x.id, libelle: x.libelle, effets: effectText(x.effets || {}), disponible: !raison, raison, ouvrir: !!x.ouvrir }; }) : [] };
      }),
      reponses, attente: st.mails.filter(m => m.status === 'nouveau').length,
    };
  }

  // Mails du jour qui arrêtent « Continuer » (continuer.cjs) : au plus `arretsParJour`, par priorité.
  function stops(s) {
    if (!s || !obj(s.clubMail) || !world(s)) return [];
    const d = todayOf(s);
    return s.clubMail.mails.filter(m => m.date === d && TYPES[m.type]?.arret && m.status === 'nouveau')
      .sort((a, b) => (TYPES[a.type].priorite ?? 99) - (TYPES[b.type].priorite ?? 99))
      .slice(0, C.arretsParJour ?? 2)
      .map(m => { const r = render(m); return { id: m.id, type: m.type, sujet: r.sujet, expediteur: r.expediteur, ecran: TYPES[m.type].ecran || 'Bureau', joueur: m.player }; });
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
    if (e.entrainement) s.training = e.entrainement;
    if (e.focus) s.collectiveFocus = e.focus;
    if (e.promesse) check(makePlayingPromise(p.id, e.promesse) === true, 'promesse refusée');
    if (e.promouvoir) check(promoteYouth(m.player) === true, 'promotion refusée');
    if (e.orientation) check(investOrienter(e.orientation) === true, 'répartition refusée');
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
    const r = (TYPES[m.type]?.reponses || []).find(x => x.id === payload.choice);
    check(!!r, 'réponse inconnue');
    const reason = unavailable(S, m, r);
    check(!reason, reason.replace(/\.$/, ''));
    apply(S, m, r);
    m.status = 'repondu';
    m.choice = r.id;
    validate(S);
    return { clubMailReply: { id: m.id, choice: r.id, resultat: m.verdict ? r.resultat + ' ' + m.verdict : r.resultat, ouvrir: !!r.ouvrir, ecran: TYPES[m.type].ecran || null, joueur: m.player } };
  }

  // Après chaque commande : une réception par jour de calendrier (carrière Monde journalière, saison ouverte).
  function observe() {
    if (typeof S === 'undefined' || !S || !world(S) || pending(S) || S.phase === 'ended') return false;
    const d = todayOf(S);
    if (!date(d) || S.clubMail?.last === d) return false;
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
      for (const v of Object.values(m.vars)) check(typeof v === 'number' ? Number.isFinite(v) : text(v, 400), 'variable invalide');
      ids.add(m.id);
    }
    for (const su of st.suites) check(obj(su) && TYPES[su.type] !== undefined && date(su.date) && text(su.key, 200) && (su.player === null || su.player === undefined || text(su.player, 180)) && obj(su.vars), 'suite invalide');
    for (const [k, v] of Object.entries(st.sent)) check(text(k, 300) && date(v), 'mémoire invalide');
    return true;
  }

  // `recevoir(s, d)` : réception sur un état donné (tests : une réception n'écrit que la boîte).
  return { project, validate, execute, observe, stops, installHooks() { return true; }, recevoir: (s, d) => receive(s, d) };
}

module.exports = { files, commands, factory, prelude, DATA };
