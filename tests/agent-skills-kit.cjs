'use strict';
// Le kit de compétences des agents est épinglé : chaque fichier copié dans
// .claude/skills et .agents/skills correspond à l'empreinte du manifeste.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const kit = require('../tools/agent-skills/update.cjs');

const root = path.resolve(__dirname, '..');
const { manifest, problems, files } = kit.check();
assert.deepEqual(problems, [], 'Écart avec le manifeste : node tools/agent-skills/update.cjs --check');
assert.ok(files >= 16);

const wanted = ['godot-gdscript', 'godot-ui-control', 'godot-gdscript-headless-testing', 'godot-export',
  'godot-3d-essentials', 'godot-shaders', 'godot-audio', 'godot-animation', 'save-systems', 'game-ui-ux',
  'game-feel', 'game-ai', 'procedural-gen', 'performance-optimization'];
const [source] = manifest.sources;
assert.match(source.commit, /^[0-9a-f]{40}$/, 'La source doit être épinglée par commit');
assert.equal(source.licence, 'Apache-2.0');
assert.deepEqual(source.skills.map(skill => skill.name).sort(), [...wanted].sort());
for (const target of kit.TARGETS) {
  for (const name of wanted) {
    const text = fs.readFileSync(path.join(root, target, name, 'SKILL.md'), 'utf8');
    assert.match(text, new RegExp('^---\\r?\\nname: ' + name + '\\r?\\n'), target + '/' + name + ' : en-tête de compétence');
    // Garde-fou du projet : la note suit l'en-tête YAML, sans le casser.
    assert.ok(kit.hasNote(Buffer.from(text)), target + '/' + name + ' : note Rugby Legacy 27 absente');
    assert.ok(text.indexOf(kit.NOTE) > text.indexOf('\n---', 4), target + '/' + name + ' : note placée après l\'en-tête');
  }
  // Apache-2.0 : la licence et la notice accompagnent les copies.
  for (const notice of ['LICENSE', 'NOTICE'])
    assert.ok(fs.statSync(path.join(root, target, '_licences', source.id, notice)).size > 200, target + ' : ' + notice);
  // Seuls des fichiers Markdown sont distribués : aucune commande tierce à exécuter.
  for (const skill of source.skills)
    for (const file of Object.keys(skill.files)) assert.match(file, /\.md$/);
}
const registry = fs.readFileSync(path.join(root, 'docs/ressources-utiles.md'), 'utf8');
assert.ok(registry.includes(source.repository) && registry.includes(source.commit.slice(0, 12)),
  'La source et son commit doivent figurer dans docs/ressources-utiles.md');
console.log('agent-skills-kit : ' + wanted.length + ' compétences épinglées sur ' + source.commit.slice(0, 12) + '.');
