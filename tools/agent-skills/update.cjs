'use strict';
// Kit de compétences des agents : copie épinglée de compétences tierces.
//
//   node tools/agent-skills/update.cjs --check
//       vérifie hors ligne que .claude/skills et .agents/skills correspondent
//       exactement au manifeste (empreintes SHA-256 de chaque fichier).
//   node tools/agent-skills/update.cjs --commit <sha40>
//       télécharge la source à ce commit précis, recopie les compétences
//       listées dans le manifeste et réécrit ses empreintes.
//   node tools/agent-skills/update.cjs --source <dossier> --commit <sha40>
//       même chose depuis un clone local déjà placé sur ce commit.
//
// Relire le diff avant de valider une mise à jour : une compétence est une
// consigne donnée aux agents. Aucun script tiers n'est exécuté ; seuls des
// fichiers .md sont acceptés.
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const crypto = require('node:crypto');
const { execFileSync } = require('node:child_process');

const ROOT = path.resolve(__dirname, '../..');
const MANIFEST = path.join(__dirname, 'manifest.json');
const TARGETS = ['.claude/skills', '.agents/skills'];
const LICENCE_DIR = '_licences';
const SHA = /^[0-9a-f]{40}$/;
const SAFE = /^(?:[A-Za-z0-9][A-Za-z0-9_-]*\/)*[A-Za-z0-9][A-Za-z0-9_-]*\.md$/;

const sha256 = buffer => crypto.createHash('sha256').update(buffer).digest('hex');
const readManifest = () => JSON.parse(fs.readFileSync(MANIFEST, 'utf8'));

function listFiles(directory, prefix = '') {
  return fs.readdirSync(directory, { withFileTypes: true }).flatMap(entry => {
    const relative = prefix ? prefix + '/' + entry.name : entry.name;
    if (entry.isSymbolicLink()) throw Error('Lien symbolique refusé : ' + relative);
    if (entry.isDirectory()) return listFiles(path.join(directory, entry.name), relative);
    return [relative];
  }).sort();
}

// Contenu attendu sous chaque dossier cible : { 'nom/fichier.md': sha256 }.
function expected(manifest) {
  const files = {};
  for (const source of manifest.sources) {
    for (const [name, hash] of Object.entries(source.licenceFiles))
      files[LICENCE_DIR + '/' + source.id + '/' + name] = hash;
    for (const skill of source.skills)
      for (const [file, hash] of Object.entries(skill.files)) files[skill.name + '/' + file] = hash;
  }
  return files;
}

function check(root = ROOT) {
  const manifest = readManifest(), wanted = expected(manifest), problems = [];
  for (const source of manifest.sources)
    if (!SHA.test(source.commit)) problems.push(source.id + ' : commit non épinglé');
  for (const target of TARGETS) {
    const directory = path.join(root, target);
    const present = fs.existsSync(directory) ? listFiles(directory) : [];
    for (const [file, hash] of Object.entries(wanted)) {
      const full = path.join(directory, file);
      if (!fs.existsSync(full)) problems.push(target + '/' + file + ' : absent');
      else if (sha256(fs.readFileSync(full)) !== hash) problems.push(target + '/' + file + ' : modifié depuis le manifeste');
    }
    // Une compétence locale reste permise ; un fichier en trop dans une
    // compétence épinglée ne l'est pas.
    const pinned = new Set(Object.keys(wanted).map(file => file.split('/')[0]));
    for (const file of present)
      if (pinned.has(file.split('/')[0]) && !(file in wanted)) problems.push(target + '/' + file + ' : fichier non déclaré');
  }
  return { manifest, problems, files: Object.keys(wanted).length };
}

function fetchSource(source, commit, local) {
  if (local) {
    const head = execFileSync('git', ['-C', local, 'rev-parse', 'HEAD'], { encoding: 'utf8' }).trim();
    if (head !== commit) throw Error('Le clone local est sur ' + head + ', pas sur ' + commit);
    return local;
  }
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'agent-skills-'));
  const git = (...args) => execFileSync('git', ['-C', directory, ...args], { stdio: ['ignore', 'pipe', 'inherit'] });
  git('init', '-q');
  git('fetch', '-q', '--depth', '1', source.repository + '.git', commit);
  git('-c', 'advice.detachedHead=false', 'checkout', '-q', 'FETCH_HEAD');
  return directory;
}

function update({ commit, local }) {
  if (!SHA.test(commit || '')) throw Error('--commit <sha de 40 caractères> requis : la source est épinglée par commit.');
  const manifest = readManifest();
  for (const source of manifest.sources) {
    const checkout = fetchSource(source, commit, local);
    source.commit = commit;
    source.retrieved = new Date().toISOString().slice(0, 10);
    const staged = [];
    for (const name of Object.keys(source.licenceFiles)) {
      const data = fs.readFileSync(path.join(checkout, name));
      source.licenceFiles[name] = sha256(data);
      staged.push([LICENCE_DIR + '/' + source.id + '/' + name, data]);
    }
    for (const skill of source.skills) {
      const origin = path.join(checkout, skill.path);
      skill.files = {};
      for (const file of listFiles(origin)) {
        if (!SAFE.test(file)) throw Error('Fichier refusé (seuls les .md sont acceptés) : ' + skill.path + '/' + file);
        const data = fs.readFileSync(path.join(origin, file));
        skill.files[file] = sha256(data);
        staged.push([skill.name + '/' + file, data]);
      }
      if (!skill.files['SKILL.md']) throw Error('SKILL.md absent : ' + skill.path);
    }
    for (const target of TARGETS) {
      for (const skill of source.skills) fs.rmSync(path.join(ROOT, target, skill.name), { recursive: true, force: true });
      for (const [file, data] of staged) {
        const full = path.join(ROOT, target, file);
        fs.mkdirSync(path.dirname(full), { recursive: true });
        fs.writeFileSync(full, data);
      }
    }
  }
  fs.writeFileSync(MANIFEST, JSON.stringify(manifest, null, 2) + '\n');
  return manifest;
}

if (require.main === module) {
  const args = process.argv.slice(2), value = flag => args.includes(flag) ? args[args.indexOf(flag) + 1] : undefined;
  try {
    if (!args.includes('--check')) {
      const manifest = update({ commit: value('--commit'), local: value('--source') });
      console.log('Kit mis à jour : ' + manifest.sources.map(s => s.id + '@' + s.commit.slice(0, 12)).join(', '));
    }
    const result = check();
    for (const problem of result.problems) console.error(problem);
    console.log(result.files + ' fichiers épinglés × ' + TARGETS.length + ' dossiers, ' + result.problems.length + ' écart(s).');
    process.exitCode = result.problems.length ? 1 : 0;
  } catch (error) { console.error(error.message); process.exitCode = 2; }
}
module.exports = { check, expected, TARGETS };
