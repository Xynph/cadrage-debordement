#!/usr/bin/env node
'use strict';
// Compile le niveau réel des joueurs (données PRIVÉES du dépôt rugby-reel-donnees) en une table
// publique NON nominative : data/world/niveaux-v2.json. Elle ne contient que des identifiants du
// registre (déjà publics), une classe d'international, un statut en club, un indicateur U20 et une
// confiance ; et, par identifiant de club, son étage. Aucun nom, lien, date ni source n'y entre.
// Elle alimente le barème senior V2 (native/engine/senior-calibration.cjs) des nouvelles carrières Monde.
//
// Usage : node tools/compile-niveaux-v2.cjs <dépôt privé> [--niveaux <dossier>] [--check]
//   <dépôt privé>  : clone de rugby-reel-donnees (lu, jamais écrit) ;
//   --niveaux      : dossier des CSV de collecte (par défaut <dépôt privé>/niveaux) ;
//   --check        : vérifie que la table publiée est à jour, sans l'écrire.
// Entrées : niveaux-<championnat>.csv (id, intl_nation, intl_caps_24m, intl_caps_total, statut_club, u20,
// distinctions, etage_club, confiance…), clubs-<championnat>.csv (club_id, etage_club…), joueurs-<championnat>.csv
// (âge seulement) et, pour le Top 14 et la PRO D2, les minutes 2025-26 de data/scouting/review-v12
// (career-evidence.json, complété par les classements de season-evidence.json).
const fs = require('node:fs'), path = require('node:path');
const ROOT = path.resolve(__dirname, '..');
const TARGET = 'data/world/niveaux-v2.json';
const LEAGUES = ['elite', 'accession', 'prem', 'urc', 'srp', 'jlo-d1', 'jlo-d2', 'nationale', 'champ', 'guest'];
const ETAGES = ['cador', 'haut', 'milieu', 'bas', 'releguable'];
const STATUTS = ['titulaire', 'rotation', 'reserviste', 'jeune', 'inconnu'];

// Rang des nations (classement World Rugby fin 2026, arrondi par groupes) ; noms tels qu'écrits dans la collecte.
const NATIONS = {
  top5: ['france', 'eng', 'england', 'angleterre', 'irlande', 'ireland', 'afrique du sud', 'south africa', 'rsa', 'nouvelle zelande', 'new zealand', 'nzl'],
  top8: ['ecosse', 'sco', 'scotland', 'argentine', 'arg', 'argentina', 'australie', 'aus', 'australia'],
  top12: ['fidji', 'fij', 'fiji', 'italie', 'ita', 'italy', 'pays de galles', 'wal', 'wales', 'georgia', 'georgie', 'geo', 'japon', 'japan', 'jpn'],
};
const fold = s => String(s || '').normalize('NFKD').replace(/[̀-ͯ]/g, '').toLowerCase().replace(/[^a-z0-9]+/g, ' ').trim();
function tier(nation) {
  const n = fold(nation);
  if (!n) return 0;
  if (NATIONS.top5.includes(n)) return 5;
  if (NATIONS.top8.includes(n)) return 8;
  if (NATIONS.top12.includes(n)) return 12;
  return 20;
}
// Distinction de très haut niveau : joueur de l'année, MVP, équipe-type, Lions.
const STAR = /\b(mvp|joueur de l annee|player of the year|equipe type|dream team|team of the season|lions)\b/;

function csv(text) {
  const rows = []; let row = [], field = '', quoted = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (quoted) { if (c === '"') { if (text[i + 1] === '"') { field += '"'; i++; } else quoted = false; } else field += c; }
    else if (c === '"') quoted = true;
    else if (c === ',') { row.push(field); field = ''; }
    else if (c === '\n') { row.push(field); rows.push(row); row = []; field = ''; }
    else if (c !== '\r') field += c;
  }
  if (field || row.length) { row.push(field); rows.push(row); }
  const head = rows.shift() || [];
  return rows.filter(r => r.length > 1).map(r => Object.fromEntries(head.map((k, i) => [k.trim(), (r[i] ?? '').trim()])));
}
const int = v => /^\d+$/.test(String(v).trim()) ? Number(v) : null;

// Classe d'international (proposition 3.1 A de l'étude du 14/11/2026), avec les seules données collectées :
// rang de la nation, sélections (24 mois si connues, sinon total), distinctions et âge.
function classe(row, age) {
  const t = tier(row.intl_nation);
  if (!t) return 'aucune';
  const caps24 = int(row.intl_caps_24m), caps = int(row.intl_caps_total);
  const dist = fold(row.distinctions);
  const uncapped = caps === 0 || /non cape/.test(dist);
  const experience = caps24 !== null ? caps24 * 3 : caps; // 24 mois réguliers ≈ 10+ sélections
  let rank; // 0 = S, 1 = A, 2 = B, 3 = C
  // Membre d'un groupe récent d'une nation du top 5, sélections inconnues : A (le groupe est l'élite du pays).
  if (t === 5) rank = uncapped ? 2 : experience === null ? 1 : experience >= 50 ? 0 : experience >= 15 ? 1 : 2;
  else if (t === 8) rank = uncapped ? 3 : experience !== null && experience >= 50 ? 1 : experience !== null && experience < 10 ? 3 : 2;
  else if (t === 12) rank = uncapped ? 3 : experience !== null && experience >= 30 ? 2 : 3;
  else rank = 3;
  if (STAR.test(dist) && t <= 8) rank = Math.max(0, rank - 1);
  // Ancien international de 33 ans et plus : un cran en dessous (déclin), jamais sous C.
  if (Number.isFinite(age) && age >= 33) rank = Math.min(3, rank + 1);
  return ['S', 'A', 'B', 'C'][rank];
}

// Statut LNR 2025-26 d'après les minutes (règle de la consigne niveaux/CONSIGNE.md) :
// titulaire = parmi les 23 plus utilisés du club et l'équivalent de 40 % des matchs comme titulaire ;
// rotation = joue régulièrement ; réserviste = peu ou pas de temps de jeu ; jeune = 22 ans ou moins peu utilisé.
const SEUIL = { elite: { titulaire: 900, rotation: 300 }, accession: { titulaire: 1000, rotation: 350 } };
function lnrMinutes(prive) {
  const dir = path.join(prive, 'data/scouting/review-v12'), minutes = new Map();
  const read = f => { const file = path.join(dir, f); return fs.existsSync(file) ? JSON.parse(fs.readFileSync(file, 'utf8')) : null; };
  const career = read('career-evidence.json'), season = read('season-evidence.json');
  const unknown = new Set();
  for (const r of Object.values(career?.records || {})) {
    if (r.status !== 'observed') { unknown.add(r.playerId); continue; }
    let min = 0, mp = 0, seen = false, previous = 0;
    for (const s of r.seasons || []) {
      if (!['TOP 14', 'PRO D2'].includes(s.competition)) continue;
      if (s.season === '2025-2026') { seen = true; min += s.stats?.minutesPlayed || 0; mp += s.stats?.matchesPlayed || 0; }
      if (s.season === '2024-2025') previous += s.stats?.minutesPlayed || 0;
    }
    minutes.set(r.playerId, { min, mp, seen, previous });
  }
  // Classements publiés de la saison 2025-26 (temps de jeu, réalisateurs…) : minutes des joueurs cités.
  for (const list of season?.lists || []) {
    if (list.season !== '2025-2026') continue;
    for (const row of list.ranking || []) {
      const id = 'lnr:' + row.lnrId, m = row.stats?.minutes;
      if (!row.lnrId || !Number.isFinite(m)) continue;
      const cur = minutes.get(id);
      if (!cur || !cur.seen || cur.min < m) minutes.set(id, { min: m, mp: row.stats.matches || 0, seen: true, previous: cur?.previous || 0 });
    }
  }
  for (const row of season?.careerSeasonRows || []) {
    const id = 'lnr:' + row.lnrId, m = row.stats?.minutesPlayed ?? row.stats?.minutes;
    if (!row.lnrId || !Number.isFinite(m) || minutes.get(id)?.seen) continue;
    minutes.set(id, { min: m, mp: row.stats.matches || 0, seen: true, previous: 0 });
  }
  return { minutes, unknown };
}

function compile(prive, niveauxDir) {
  const players = {}, clubs = {}, coverage = {};
  const { minutes } = lnrMinutes(prive);
  const sources = {};
  for (const f of ['career-evidence.json', 'season-evidence.json']) {
    const file = path.join(prive, 'data/scouting/review-v12', f);
    if (fs.existsSync(file)) sources['data/scouting/review-v12/' + f] = file;
  }
  for (const league of LEAGUES) {
    const files = ['niveaux', 'clubs', 'joueurs'].map(k => path.join(niveauxDir, `${k}-${league}.csv`));
    if (!files.every(f => fs.existsSync(f))) throw Error('Collecte incomplète pour ' + league + ' dans ' + niveauxDir);
    files.forEach(f => { sources['niveaux/' + path.basename(f)] = f; });
    const [rows, clubRows, roster] = files.map(f => csv(fs.readFileSync(f, 'utf8')));
    for (const c of clubRows) {
      const id = int(c.club_id), etage = fold(c.etage_club).replace(/ /g, '');
      if (id === null || !ETAGES.includes(etage)) throw Error(`Étage de club invalide (${league}) : ${c.club_id}`);
      clubs[id] = etage;
    }
    const info = new Map(roster.map(r => [r.id, { age: int(r.age), club: int(r.club_id) }]));
    // Rang du joueur dans son club, aux minutes 2025-26 (Top 14 et PRO D2).
    const rankInClub = new Map();
    if (SEUIL[league]) {
      const byClub = new Map();
      for (const r of roster) { const m = minutes.get(r.id); if (m?.seen) (byClub.get(r.club_id) || byClub.set(r.club_id, []).get(r.club_id)).push([r.id, m.min]); }
      for (const list of byClub.values()) list.sort((a, b) => b[1] - a[1] || (a[0] < b[0] ? -1 : 1)).forEach(([id], i) => rankInClub.set(id, i + 1));
    }
    const count = { joueurs: 0, statutConnu: 0, internationaux: 0 };
    for (const row of rows) {
      if (!row.id || !info.has(row.id)) continue;
      const { age } = info.get(row.id);
      let statut = fold(row.statut_club).replace(/ /g, '');
      if (statut === 'reservist') statut = 'reserviste';
      if (!STATUTS.includes(statut)) statut = 'inconnu';
      const m = minutes.get(row.id);
      if (statut === 'inconnu' && SEUIL[league] && m?.seen) {
        const s = SEUIL[league];
        statut = m.min >= s.titulaire && rankInClub.get(row.id) <= 23 ? 'titulaire'
          : m.min >= s.rotation || m.mp >= 8 ? 'rotation'
            : m.previous >= s.titulaire ? 'rotation'
              : Number.isFinite(age) && age <= 22 ? 'jeune' : 'reserviste';
      }
      const c = classe(row, age);
      const u20 = /^(oui|yes|1|true)$/i.test(row.u20) ? 1 : 0;
      const confiance = ['haute', 'moyenne', 'basse'].includes(fold(row.confiance)) ? fold(row.confiance) : 'basse';
      count.joueurs++;
      if (statut !== 'inconnu') count.statutConnu++;
      if (c !== 'aucune') count.internationaux++;
      if (c === 'aucune' && statut === 'inconnu' && !u20) continue; // rien de connu : absent de la table
      players[row.id] = [c, statut, u20, confiance];
    }
    coverage[league] = count;
  }
  const sorted = o => Object.fromEntries(Object.entries(o).sort(([a], [b]) => (a < b ? -1 : a > b ? 1 : 0)));
  const table = {
    schema: 'niveaux-v2',
    version: 1,
    note: 'Niveau réel compilé (identifiants seulement) pour le barème senior V2 des nouvelles carrières Monde. Joueur absent : classe aucune, statut inconnu, U20 0, confiance basse.',
    champs: ['classe', 'statut', 'u20', 'confiance'],
    classes: ['S', 'A', 'B', 'C', 'aucune'],
    statuts: STATUTS,
    etages: ETAGES,
    couverture: coverage,
    joueurs: sorted(players),
    clubs: Object.fromEntries(Object.entries(clubs).sort(([a], [b]) => Number(a) - Number(b))),
  };
  return { table, sources };
}

function serialize(table) {
  // Une ligne par joueur : lisible en revue et stable en différence.
  const head = { ...table }; delete head.joueurs; delete head.clubs;
  const lines = Object.entries(table.joueurs).map(([id, v]) => ` ${JSON.stringify(id)}:${JSON.stringify(v)}`);
  const body = JSON.stringify(head, null, 1).replace(/\n}$/, '');
  return body + ',\n "clubs": ' + JSON.stringify(table.clubs) + ',\n "joueurs": {\n' + lines.join(',\n') + '\n }\n}\n';
}

function main(argv) {
  const args = argv.slice(2), check = args.includes('--check');
  const at = args.indexOf('--niveaux');
  const prive = args.find((a, i) => !a.startsWith('--') && i !== at + 1);
  if (!prive) throw Error('Usage : node tools/compile-niveaux-v2.cjs <dépôt privé> [--niveaux <dossier>] [--check]');
  const niveauxDir = path.resolve(at >= 0 ? args[at + 1] : path.join(prive, 'niveaux'));
  const { table, sources } = compile(path.resolve(prive), niveauxDir);
  const text = serialize(table), file = path.join(ROOT, TARGET);
  if (check) {
    if (!fs.existsSync(file) || fs.readFileSync(file, 'utf8') !== text) throw Error(TARGET + ' périmé : relancer la compilation.');
  } else fs.writeFileSync(file, text);
  const privees = require('../scripts/sources-privees.cjs');
  privees.recordCompiled(TARGET, sources, check);
  const total = Object.values(table.couverture).reduce((a, c) => ({ joueurs: a.joueurs + c.joueurs, statutConnu: a.statutConnu + c.statutConnu, internationaux: a.internationaux + c.internationaux }), { joueurs: 0, statutConnu: 0, internationaux: 0 });
  const classes = Object.values(table.joueurs).reduce((o, v) => (o[v[0]] = (o[v[0]] || 0) + 1, o), {});
  console.log(JSON.stringify({ cible: TARGET, verifie: check, ...total, classes, clubs: Object.keys(table.clubs).length }));
}

if (require.main === module) {
  try { main(process.argv); } catch (error) { console.error(error.message); process.exit(1); }
}
module.exports = { compile, classe, tier, serialize, TARGET };
