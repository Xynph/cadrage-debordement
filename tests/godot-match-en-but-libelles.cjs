'use strict';
// Libellés Godot d'un fait d'en-but (écran intermédiaire 2D, ligne d'état de la 3D, bandeau de la liaison) : l'équipe
// qui attaque est nommée pour l'en-avant, le porteur tenu et le coup de pied aplati. Les faits viennent du VRAI moteur :
// matchs de la carrière du film (scripts/match-filme.ps1 : club 102), graines cherchées par le test, projection `live.direct` de
// native/engine/match-direct.cjs (plans des temps forts, déroulé 2D) et journal. Ignoré sans SDK Godot.
const fs = require('node:fs'), os = require('node:os'), path = require('node:path'), assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const godot = process.env.CD_GODOT_EXECUTABLE || process.env.CD_GODOT_EXE;
if (!godot || !fs.existsSync(godot)) { console.log('SKIP godot-match-en-but-libelles : SDK Godot absent (CD_GODOT_EXECUTABLE/CD_GODOT_EXE).'); process.exit(0); }
const { ouvrir, creer, jusquAuMatch } = require('./helpers/carriere-monde.cjs');
const { skipMatchTalk } = require('./helpers/scene-match-talks.cjs');

const CAUSES = ['held-up', 'ingoal-knock-on', 'attacking-kick-grounded'];
const faits = [];
// Carrière du film (scripts/match-filme.ps1 : club 102, cadence hebdomadaire) préparée une fois, arrêtée au coup d'envoi ; le
// match est rejoué avec des graines successives (import de la même carrière, aléas différents) par le vrai moteur, jusqu'à avoir
// assez de plans ET de déroulés 2D d'en-but réels (au moins 3 de chaque, au moins 2 causes différentes). Aucune graine n'est
// imposée. Borne de temps de 120 s pour cette partie, sinon échec listant les graines vues.
const debut = Date.now(), BORNE = 120000, MINUTES = 80;
const suffisant = () => faits.filter(f => f.source === 'plan').length >= 3 && faits.filter(f => f.source === 'deroule').length >= 3 && new Set(faits.map(f => f.fait.cause)).size >= 2;
const base = ouvrir({ seed: 1, hebdomadaire: true });
let texte;
try {
  let model = jusquAuMatch(base, creer(base, 102));
  if (!model.selection.valid) model = base.call('auto_lineup');
  if (!model.selection.valid) model = base.call('promote_cover', { confirmed: true });
  base.call('begin_match');
  texte = base.call('export').meta.exportText;
} finally { base.fermer(); }
const essais = [];
for (let graine = 11; !suffisant() && Date.now() - debut < BORNE; graine++) {
  const jeu = ouvrir({ seed: graine, hebdomadaire: true, leanModel: true, deferredCommits: true, journal: true, savePolicy: 'mois' });
  const avant = faits.length, vus = new Set();
  try {
    jeu.call('import', { text: texte });
    let model = skipMatchTalk(jeu.call('begin_match'), jeu.call);
    const lire = live => {
      const equipes = live.teams;
      for (const p of live.direct?.tempsFort?.plans || []) {
        const fait = live.events[p.index]?.scene;
        if (fait?.kind !== 'ingoal' || !CAUSES.includes(fait.cause) || vus.has('p' + p.index)) continue;
        vus.add('p' + p.index);
        faits.push({ source: 'plan', graine, index: p.index, equipes, plan: p, fait: { kind: fait.kind, cause: fait.cause, team: fait.team }, texte: live.events[p.index].text });
      }
      for (const d of live.direct?.deroule || []) {
        const fait = live.events[d.i]?.scene;
        if (fait?.kind !== 'ingoal' || !CAUSES.includes(fait.cause) || vus.has('d' + d.i)) continue;
        vus.add('d' + d.i);
        faits.push({ source: 'deroule', graine, index: d.i, equipes, item: d, fait: { kind: fait.kind, cause: fait.cause, team: fait.team }, texte: live.events[d.i].text });
      }
    };
    for (let ticks = 0; ticks < 120 && !model.live.finished && model.live.minute < MINUTES && !suffisant() && Date.now() - debut < BORNE; ticks++) {
      model = skipMatchTalk(model, jeu.call);
      if (model.live.paused) model = jeu.call('pause', { paused: false });
      model = jeu.call('tick', { minute: true, temps_forts: 'dynamique' });
      lire(model.live);
    }
  } finally { jeu.fermer(); }
  essais.push(`${graine} : ${faits.length - avant} fait(s)`);
}
assert.ok(suffisant(), `faits d'en-but réels insuffisants (${faits.filter(f => f.source === 'plan').length} plans, ${faits.filter(f => f.source === 'deroule').length} déroulés) ; graines vues : ${essais.join(' ; ')}`);
const dossier = fs.mkdtempSync(path.join(os.tmpdir(), 'cd-en-but-libelles-'));
fs.writeFileSync(path.join(dossier, 'faits.json'), JSON.stringify(faits));
const result = spawnSync(godot, ['--headless', '--audio-driver', 'Dummy', '--path', path.resolve(__dirname, '../native/godot'), '--script', path.resolve(__dirname, 'godot-match-en-but-libelles.gd')],
  { encoding: 'utf8', windowsHide: true, timeout: 300000, env: { ...process.env, CD_GODOT_SELF_TEST: '0', CD_EN_BUT_FAITS: path.join(dossier, 'faits.json') } });
const output = (result.stdout || '') + (result.stderr || ''); console.log(output);
fs.rmSync(dossier, { recursive: true, force: true });
if (result.error) throw result.error;
assert.equal(result.status, 0, output);
assert.doesNotMatch(output, /SCRIPT ERROR|Parse Error/);
assert.match(output, /EN_BUT_LIBELLES \d+ controles, 0 echec/);
