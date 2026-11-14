'use strict';
// Régénération officielle des « valeurs figées » France.
//
// Usage :
//   node scripts/regenerer-donnees-figees.cjs            # recalcule et écrit les deux fichiers
//   node scripts/regenerer-donnees-figees.cjs --parity   # parité seule : tests/france-legacy-parity.json
//   node scripts/regenerer-donnees-figees.cjs --s6       # checkpoint S6/S11 seul : tests/fixtures/france-long-career-s6.json.gz
//   node scripts/regenerer-donnees-figees.cjs --check    # recalcule sans écrire ; code 1 si un fichier diffère
//   (--check se combine avec --parity / --s6)
//
// Le parcours est celui des suites (tests/france-parity.cjs, tests/france-long-career.cjs et
// tests/france-long-career-late.cjs) en réutilisant france-harness et les helpers de tests/.
// Si une suite change de parcours, ce script doit changer avec elle.
// En cas de conflit Git sur ces fichiers : prendre la version de main, puis relancer ce script.
// Variable de contrôle QT_OFF=1 : met QUICK_TAP_RULES=0 dans le moteur (rien n'est écrit dans ce cas).
const fs = require('node:fs'), path = require('node:path'), crypto = require('node:crypto'), zlib = require('node:zlib');
const TESTS = path.join(__dirname, '..', 'tests');
const DIST = path.join(__dirname, '..', 'dist');
const PARITE = path.join(TESTS, 'france-legacy-parity.json');
const S6 = path.join(TESTS, 'fixtures', 'france-long-career-s6.json.gz');
const { context } = require(path.join(TESTS, 'france-harness.cjs'));
const H = require(path.join(TESTS, 'helpers', 'france-long-career.cjs'));
const { freezeFranceBirths } = require(path.join(TESTS, 'helpers', 'frozen-france-births.cjs'));

const args = process.argv.slice(2);
const check = args.includes('--check');
const qtOff = !!process.env.QT_OFF;
const veutParite = args.includes('--parity') || !args.includes('--s6');
const veutS6 = args.includes('--s6') || !args.includes('--parity');
const hash = s => crypto.createHash('sha256').update(s).digest('hex');

// Parité France (fiction + lnr) : même parcours que tests/france-parity.cjs, mais on enregistre au lieu de comparer.
function calculerParite() {
  const baseline = JSON.parse(fs.readFileSync(PARITE, 'utf8'));
  for (const mode of ['fiction', 'lnr']) {
    const after = context(baseline.seed);
    if (qtOff) after.run('QUICK_TAP_RULES=0');
    after.run('var populationV2Setup=aiRosterSetup;aiRosterSetup=function(){var result=populationV2Setup();S.aiRosterVersion=1;S.aiRoster.version=1;delete S.aiRoster.population;return result}');
    freezeFranceBirths(after);
    if (mode === 'lnr') for (const f of ['lnr-rosters-base.js', 'lnr-career.js']) after.run(fs.readFileSync(path.join(DIST, f), 'utf8'));
    after.run("start(0,'" + mode + "')");
    const same = stage => { baseline.captures[mode][stage] = { hash: hash(after.run('JSON.stringify(S)')), seed: after.seed() }; };
    same('création');
    after.run('beginMatch();for(let i=0;!S.live.finished;i++){if(i>5000)throw Error("limite");if(S.live.paused)continueMatch();else tick();}finishRound();validateCareer(S)'); same('match délégué');
    after.run("while(S.phase!=='ended'){trainWeek();finishRound();}validateCareer(S)"); same('saison');
    after.run('advanceSeason();validateCareer(S)'); same('intersaison');
    baseline.captures[mode].export = { ...baseline.captures[mode].export, hash: hash(after.run('JSON.stringify(createSaveDocument())')) };
  }
  return JSON.stringify(baseline, null, 2) + '\n';
}

// Checkpoint S6 + empreinte S11 : mêmes parcours que france-long-career.cjs (S1–S5) puis france-long-career-late.cjs (S6–S10).
function calculerS6() {
  const old = JSON.parse(zlib.gunzipSync(fs.readFileSync(S6)));
  const h = context();
  if (qtOff) h.run('QUICK_TAP_RULES=0');
  h.run('var setupPopulationV2=aiRosterSetup;aiRosterSetup=function(){var result=setupPopulationV2();S.aiRosterVersion=1;S.aiRoster.version=1;delete S.aiRoster.population;return result};');
  freezeFranceBirths(h);
  h.run("start(29,'france')");
  H.runSeasons(h, 1, 5);
  const save = JSON.parse(h.run('JSON.stringify(createSaveDocument())')), rng = h.seed();
  const fx = { ...old, checkpoint: { ...old.checkpoint, save, rng } };
  delete fx.integrity;
  // Final : reprise du checkpoint tel que le fait france-long-career-late.
  const h2 = H.resumeCheckpoint(H.seal({ ...fx, final: old.final }));
  if (qtOff) h2.run('QUICK_TAP_RULES=0');
  freezeFranceBirths(h2);
  H.runSeasons(h2, 6, 10);
  fx.final = { ...old.final, season: h2.state().season, stateSha256: H.digest(h2.state()), rng: h2.seed() };
  return { texte: JSON.stringify(H.seal(fx)), ancien: JSON.stringify(old) };
}

let differe = false;
if (veutParite) {
  const texte = calculerParite();
  const identique = texte === fs.readFileSync(PARITE, 'utf8');
  console.log('parité France :', identique ? 'identique' : 'DIFFÉRENTE');
  if (!identique) differe = true;
  if (!check && !qtOff && !identique) { fs.writeFileSync(PARITE, texte); console.log('écrit', path.relative(process.cwd(), PARITE)); }
}
if (veutS6) {
  const { texte, ancien } = calculerS6();
  const identique = texte === ancien;
  console.log('checkpoint S6/S11 :', identique ? 'identique' : 'DIFFÉRENT');
  if (!identique) differe = true;
  if (!check && !qtOff && !identique) { fs.writeFileSync(S6, zlib.gzipSync(texte, { level: 9 })); console.log('écrit', path.relative(process.cwd(), S6)); }
}
if (qtOff && !check) console.log('QT_OFF : contrôle uniquement, rien écrit');
if (check && differe) { console.error('Valeurs figées obsolètes : lancer node scripts/regenerer-donnees-figees.cjs'); process.exit(1); }
