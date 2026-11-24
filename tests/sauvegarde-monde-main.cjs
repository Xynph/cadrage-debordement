'use strict';
// Une carrière Monde sauvegardée avec le moteur de main (690a7ced4, 24/11/2026 : world-champ, club 102, veille de
// saison) se recharge avec le moteur actuel et garde tout son staff. Garde-fou des registres du staff : un rôle changé
// dans les données casse le chargement (« Carrières du staff : référence ou visage incohérent »).
// Fixture régénérable : créer une carrière avec le moteur voulu (new_career world-champ 102, start veille), save, shutdown.
const assert = require('node:assert/strict');
const fs = require('node:fs'), os = require('node:os'), path = require('node:path'), zlib = require('node:zlib');
const { test } = require('node:test');
const { createBridge } = require('../native/engine/worker.cjs');

test('Sauvegarde Monde de main : se charge et garde tout son staff', () => {
  const racine = fs.mkdtempSync(path.join(os.tmpdir(), 'rl27-sauvegarde-main-'));
  try {
    const dossier = path.join(racine, 'PrototypeGodot');
    fs.mkdirSync(dossier, { recursive: true });
    const texte = zlib.gunzipSync(fs.readFileSync(path.join(__dirname, 'fixtures', 'monde-champ-102-main-690a7ced4.json.gz')));
    fs.writeFileSync(path.join(dossier, 'donnees.json'), texte);
    const bridge = createBridge({ dataDir: racine, seed: 4242, now: 1794315600000 });
    const r = bridge.handle({ id: 1, command: 'snapshot', payload: {} });
    assert.equal(r.ok, true, 'chargement : ' + r.error);
    const m = r.model;
    assert.equal(m.meta?.mode, 'world', 'carrière Monde rechargée');
    assert.equal(m.club?.id, 102, 'club de la sauvegarde');
    assert.equal(m.clubLife?.staffCareer?.active, true, 'carrières du staff actives');
    const equipe = (m.staff?.teams || []).find(t => t.id === 102);
    assert.equal(equipe?.members?.length, 18, 'tout le staff du club (18 à la sauvegarde)');
    // Un seul directeur sportif dans le jeu (celui de la direction du club) : aucun membre du staff affiché sous ce titre.
    assert.equal(equipe.members.filter(p => /^\s*directeur sportif\s*$/i.test(String(p.roleLabel ?? ''))).length, 0, 'aucun « Directeur sportif » parmi le staff affiché');
    assert.ok(equipe.members.some(p => p.roleLabel === 'Responsable du recrutement'), 'l’ancien titré affiché « Responsable du recrutement »');
    bridge.handle({ id: 2, command: 'shutdown', payload: {} });
  } finally { fs.rmSync(racine, { recursive: true, force: true }); }
});
