'use strict';
// Le rôle compte-t-il ? Mesure du Niveau au rôle (native/engine/niveau-calcule.cjs) sur tout le Monde. Lecture seule.
// Usage :
//   node tools/notation/ecart-roles.cjs [<monde.json | sauvegarde.json(.gz)>] [--module <niveau-calcule.cjs>] [--caler] [--json]
// --caler : recalcule CENTRE_ROLE et A, B sur ce Monde (valeurs à reporter dans le module) et mesure avec eux.
// Sans fichier : la sauvegarde Monde des tests (tests/fixtures/monde-champ-102-main-690a7ced4.json.gz).
// Mesures par famille de poste : écart entre le meilleur et le moins bon rôle (moyen, max), répartition des meilleurs
// rôles, % de joueurs dont la LETTRE change selon le rôle (lettre = échelle de l'écran : référence B = moyenne des 15
// meilleurs du club, 2 points par cran), Niveau moyen ; répartition des lettres (meilleur rôle) sur tout le Monde.
const fs = require('node:fs');
const path = require('node:path');
const zlib = require('node:zlib');

const racine = path.join(__dirname, '..', '..');
const args = process.argv.slice(2);
const option = nom => { const i = args.indexOf(nom); return i >= 0 ? args[i + 1] : null; };
const valeurs = new Set([option('--module')].filter(Boolean));
const fichier = args.find(a => !a.startsWith('--') && !valeurs.has(a))
  || path.join(racine, 'tests', 'fixtures', 'monde-champ-102-main-690a7ced4.json.gz');
const N = require(path.resolve(option('--module') || path.join(racine, 'native', 'engine', 'niveau-calcule.cjs')));

function etat(f) {
  let texte = fs.readFileSync(f);
  if (/\.gz$/.test(f)) texte = zlib.gunzipSync(texte);
  let s = JSON.parse(texte.toString('utf8'));
  if (s.store?.['bdt-v1']) s = s.store['bdt-v1'];
  if (typeof s === 'string') s = JSON.parse(s);
  if (s.state) s = typeof s.state === 'string' ? JSON.parse(s.state) : s.state;
  return s;
}

const LETTRES = ['E-', 'E', 'E+', 'D-', 'D', 'D+', 'C-', 'C', 'C+', 'B-', 'B', 'B+', 'A-', 'A', 'A+', 'S-', 'S', 'S+'];
const indice = (v, ref) => Math.max(0, Math.min(17, 10 + Math.round((v - ref) / 2)));
const moy = a => a.reduce((s, v) => s + v, 0) / (a.length || 1);
const ecartType = a => { const m = moy(a); return Math.sqrt(moy(a.map(v => (v - m) ** 2))); };

let reglage = {};
function mesurer(s) {
  const familles = {};
  const lettres = Object.fromEntries(LETTRES.map(l => [l, 0]));
  for (const club of s.clubs || []) {
    const lignes = (club.players || []).map(p => ({ p, n: N.niveauJoueur(p, reglage) })).filter(x => x.n);
    const top = lignes.map(x => x.n.niveau).sort((a, b) => b - a).slice(0, 15);
    const ref = moy(top);
    for (const { p, n } of lignes) {
      lettres[LETTRES[indice(n.niveau, ref)]]++;
      const f = (familles[n.famille] ||= { n: 0, ecarts: [], meilleurs: {}, change: 0, niveaux: [], ratings: [], paires: {} });
      f.n++;
      const niv = n.roles.map(r => r.niveau);
      f.ecarts.push(Math.max(...niv) - Math.min(...niv));
      f.meilleurs[n.roleNom] = (f.meilleurs[n.roleNom] || 0) + 1;
      if (new Set(niv.map(v => indice(v, ref))).size > 1) f.change++;
      f.niveaux.push(n.niveau);
      if (typeof p.rating === 'number') f.ratings.push(p.rating);
      for (const a of n.roles) for (const b of n.roles) if (a.id < b.id) {
        const cle = `${a.nom}/${b.nom}`;
        (f.paires[cle] ||= []).push(Math.abs(a.niveau - b.niveau));
      }
    }
  }
  const total = Object.values(lettres).reduce((a, b) => a + b, 0);
  const sortie = { joueurs: total, familles: {}, lettres };
  for (const [nom, f] of Object.entries(familles)) {
    sortie.familles[nom] = {
      n: f.n,
      ecartMoyen: +moy(f.ecarts).toFixed(2), ecartMax: Math.max(...f.ecarts),
      meilleurs: Object.fromEntries(Object.entries(f.meilleurs).sort((a, b) => b[1] - a[1]).map(([k, v]) => [k, Math.round(100 * v / f.n)])),
      lettreChange: Math.round(100 * f.change / f.n),
      niveauMoyen: +moy(f.niveaux).toFixed(1), niveauEcartType: +ecartType(f.niveaux).toFixed(1),
      ratingMoyen: +moy(f.ratings).toFixed(1),
      paires: Object.fromEntries(Object.entries(f.paires).map(([k, v]) => [k, { moyen: +moy(v).toFixed(2), max: Math.max(...v) }]))
    };
  }
  const tous = Object.values(familles);
  sortie.ecartMoyen = +moy(tous.flatMap(f => f.ecarts)).toFixed(2);
  sortie.ecartMax = Math.max(...tous.flatMap(f => f.ecarts));
  sortie.lettreChange = Math.round(100 * tous.reduce((t, f) => t + f.change, 0) / total);
  return sortie;
}

const monde = etat(fichier);
if (args.includes('--caler')) {
  const c = N.caler((monde.clubs || []).flatMap(club => club.players || []));
  reglage = { calage: { A: c.A, B: c.B }, centres: c.centres };
  console.log(`Calage : A=${c.A} B=${c.B} (${c.n} joueurs)
CENTRE_ROLE = ${JSON.stringify(c.centres)}`);
}
const r = mesurer(monde);
if (args.includes('--json')) { console.log(JSON.stringify(r, null, 1)); process.exit(0); }
console.log(`Monde : ${r.joueurs} joueurs · écart entre rôles moyen ${r.ecartMoyen} · max ${r.ecartMax} · lettre qui change selon le rôle ${r.lettreChange} %`);
for (const [nom, f] of Object.entries(r.familles)) {
  console.log(`${nom.padEnd(9)} ${String(f.n).padStart(4)} · écart moy ${f.ecartMoyen} max ${f.ecartMax} · lettre change ${f.lettreChange} % · Niveau ${f.niveauMoyen} (σ ${f.niveauEcartType}, rating ${f.ratingMoyen}) · meilleurs ${Object.entries(f.meilleurs).map(([k, v]) => `${k} ${v} %`).join(', ')}`);
  console.log('          paires : ' + Object.entries(f.paires).map(([k, v]) => `${k} ${v.moyen}/${v.max}`).join(' · '));
}
console.log('Lettres (meilleur rôle, réf. B = 15 meilleurs du club) : ' + LETTRES.map(l => `${l} ${(100 * r.lettres[l] / r.joueurs).toFixed(1)}`).join(' · '));
