'use strict';
// Écart entre le Niveau actuel (`rating`) et le Niveau calculé (native/engine/niveau-calcule.cjs) sur une carrière Monde
// exportée. Lecture seule. Usage :
//   node tools/notation/ecart-niveau.cjs <carriere.json> [--club <id>] [--caler] [--md]
const fs = require('node:fs');
const path = require('node:path');
const N = require(path.join(__dirname, '..', '..', 'native', 'engine', 'niveau-calcule.cjs'));

const args = process.argv.slice(2);
const fichier = args.find(a => !a.startsWith('--') && !/^\d+$/.test(a));
if (!fichier) { console.error('Usage : node tools/notation/ecart-niveau.cjs <carriere.json> [--club <id>] [--caler] [--md]'); process.exit(2); }
const option = nom => { const i = args.indexOf(nom); return i >= 0 ? args[i + 1] : null; };
const brut = JSON.parse(fs.readFileSync(fichier, 'utf8'));
const s = typeof brut.state === 'string' ? JSON.parse(brut.state) : (brut.state || brut);
const clubId = option('--club') !== null ? Number(option('--club')) : s.club;
const md = args.includes('--md');

const monde = s.clubs.flatMap(c => c.players || []);
const calage = args.includes('--caler') ? N.caler(monde) : N.CALAGE;
if (args.includes('--caler')) console.log(`Calage : A=${calage.A} B=${calage.B} (${calage.n} joueurs)`);

const lignes = monde.map(p => ({ p, n: N.niveauJoueur(p, { calage }) })).filter(x => x.n);
const ecarts = lignes.map(x => x.n.niveau - x.p.rating);
const moy = a => a.reduce((s, v) => s + v, 0) / (a.length || 1);
const absMoy = moy(ecarts.map(Math.abs));
const xs = lignes.map(x => x.n.niveau), ys = lignes.map(x => x.p.rating);
const mx = moy(xs), my = moy(ys);
const r = lignes.reduce((t, _, i) => t + (xs[i] - mx) * (ys[i] - my), 0) / Math.sqrt(xs.reduce((t, v) => t + (v - mx) ** 2, 0) * ys.reduce((t, v) => t + (v - my) ** 2, 0));
console.log(`Monde : ${lignes.length} joueurs · écart moyen absolu ${absMoy.toFixed(1)} · corrélation ${r.toFixed(3)} · |écart| ≥ 5 : ${ecarts.filter(e => Math.abs(e) >= 5).length}`);
const parFamille = {};
for (const x of lignes) (parFamille[x.n.famille] ||= []).push(x.n.niveau - x.p.rating);
console.log('Par famille (écart moyen, |écart| moyen) : ' + Object.entries(parFamille).map(([f, e]) => `${f} ${moy(e) >= 0 ? '+' : ''}${moy(e).toFixed(1)} / ${moy(e.map(Math.abs)).toFixed(1)}`).join(' · '));

const club = s.clubs[clubId];
const effectif = (club.players || []).map(p => ({ p, n: N.niveauJoueur(p, { calage }) })).filter(x => x.n)
  .sort((a, b) => b.n.niveau - a.n.niveau);
console.log(`\n${club.name} : ${effectif.length} joueurs`);
const sep = md ? ' | ' : '  ';
const entete = ['Joueur', 'Poste', 'Âge', 'Actuel', 'Calculé', 'Écart', 'Meilleur rôle', 'Autres rôles'];
if (md) { console.log('| ' + entete.join(' | ') + ' |'); console.log('|' + entete.map(() => ' --- ').join('|') + '|'); }
else console.log(entete.join(sep));
for (const { p, n } of effectif) {
  const e = n.niveau - p.rating;
  const autres = n.roles.slice(1).map(x => `${x.nom} ${x.niveau}`).join(', ');
  const cols = [p.name, p.gameplayPosition || p.pos, p.age, p.rating, n.niveau, (e > 0 ? '+' : '') + e, `${n.roleNom} ${n.niveau}`, autres];
  console.log(md ? '| ' + cols.join(' | ') + ' |' : cols.join(sep));
}
