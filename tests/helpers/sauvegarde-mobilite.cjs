'use strict';
// Sauvegarde d'une carrière Monde (club 29, graine 13) arrivée en fin de saison : la fenêtre de mobilité du
// manager (phase 'ended') est ouverte. La produire coûte ~850 s de saison jouée et ~2 Go de tas ; elle pèse
// ~19 Mo (2,9 Mo compressée), trop pour être versionnée comme les autres fixtures (tests/fixtures ≤ 0,5 Mo).
// Elle est donc générée par scripts/generer-sauvegarde-mobilite.cjs puis mise en cache, sous une empreinte du
// moteur : un changement de dist/ ou de native/engine/ invalide le cache, la sauvegarde n'est jamais périmée.
//   CD_MOBILITE_DIR : dossier du cache (défaut : <tmp>/rl27-mobilite) ; en CI, cache GitHub sur ce dossier.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const zlib = require('node:zlib');
const { createHash } = require('node:crypto');
const { createBridge } = require('../../native/engine/worker.cjs');
const ROOT = path.join(__dirname, '..', '..');
const SOURCES = ['dist', 'native/engine', 'scripts/generer-sauvegarde-mobilite.cjs', 'tests/helpers/club-meetings.cjs'];

function fichiers(dir, out = []) {
  const abs = path.join(ROOT, dir);
  if (!fs.existsSync(abs)) return out;
  if (fs.statSync(abs).isFile()) { out.push(dir); return out; }
  for (const e of fs.readdirSync(abs, { withFileTypes: true }).sort((a, b) => (a.name < b.name ? -1 : 1))) {
    if (e.isDirectory()) fichiers(path.join(dir, e.name), out); else out.push(path.join(dir, e.name));
  }
  return out;
}
function empreinteMoteur() {
  const h = createHash('sha256');
  for (const s of SOURCES) for (const f of fichiers(s)) { h.update(f); h.update(fs.readFileSync(path.join(ROOT, f))); }
  return h.digest('hex').slice(0, 16);
}
const dossier = () => process.env.CD_MOBILITE_DIR || path.join(os.tmpdir(), 'rl27-mobilite');
const chemin = () => path.join(dossier(), 'fin-de-saison-' + empreinteMoteur() + '.json.gz');
function lire() {
  const f = chemin();
  if (!fs.existsSync(f)) throw new Error('Sauvegarde de fin de saison absente (' + f + ') : lancer « node scripts/generer-sauvegarde-mobilite.cjs » (~15 min, 2 Go).');
  return zlib.gunzipSync(fs.readFileSync(f)).toString('utf8');
}

// Banc de test sur vrai worker de production (mêmes commandes que le jeu).
function banc() {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'native-mobilite-'));
  let request = 0; const bridges = [];
  const open = name => { const b = createBridge({ dataDir: path.join(root, name), seed: 13, now: 1700000000000, testVm: true }); bridges.push(b); return b; };
  const good = (b, command, payload = {}) => { const r = b.handle({ id: ++request, command, payload }); assert.equal(r.ok, true, r.error); return r.model; };
  const raw = (b, command, payload = {}) => b.handle({ id: ++request, command, payload });
  const doc = b => JSON.parse(good(b, 'export').meta.exportText);
  const data = b => good(b, 'snapshot').clubLife.managerCareer;
  const act = (b, command, p = {}) => good(b, command, { context: data(b).context, ...p });
  // Carrière du club 29 à l'ouverture de la fenêtre de mobilité, importée dans un nouveau worker.
  function ouvrirFinDeSaison(name) { const b = open(name); good(b, 'import', { text: lire() }); assert.equal(data(b).window, true, 'fenêtre de mobilité ouverte à l’import'); return b; }
  // Offre Élite admissible : celle de la saison jouée si elle est acceptée, sinon la même fixture explicite que
  // l'ancien test (réputation 100 / club visé fragile), posée directement sur l'état chargé (vm de test du worker :
  // une sauvegarde Monde exportée est réduite en v3, donc non re-signable à la main), sans toucher aux règles de production.
  function cibleElite(b) {
    let target = data(b).opportunities.find(x => x.leagueId === 'elite' && x.accepted);
    if (!target) {
      const id = data(b).opportunities.find(x => x.leagueId === 'elite').clubId;
      b.vm.run('{const id=' + id + ';S.worldManagement.clubInfo[29].reputation=100;S.trust=100;Object.assign(S.worldManagement.clubInfo[id],{reputation:50,coachConfidence:0,consecutiveLosses:10,debt:0});S.clubs[id].cash=Math.max(100000,S.clubs[id].cash);}');
      // Les projections lues sont mises en cache jusqu'à la prochaine commande : la décision se lit dans le moteur.
      const decision = JSON.parse(b.vm.run('JSON.stringify(managerMobilityDecision(' + id + '))'));
      assert.equal(decision?.accepted, true, 'la fixture rend l’offre admissible');
      target = { clubId: id, accepted: true };
    }
    assert.ok(target, 'Fixture admissible Accession vers Élite');
    return target;
  }
  return { open, good, raw, doc, data, act, ouvrirFinDeSaison, cibleElite, fermer: () => { for (const b of bridges) b.close(); fs.rmSync(root, { recursive: true, force: true }); } };
}
module.exports = { empreinteMoteur, chemin, dossier, lire, banc };
