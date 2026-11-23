'use strict';
// Effectif › Planificateur (idée FM27 n° 11, choix de Léo du 23/11/2026) : terrain avec 3-4 noms par poste et leurs
// signes, clic sur un poste = liste complète du poste à côté, saisons actuelle / prochaine / suivante, note future
// estimée (âge, potentiel), titulaire à deux postes signalé, prolongation « en négociation ».
// Carrière Monde créée ici ; une vraie proposition de prolongation trop basse (contre-offre de l'agent) met en
// négociation un joueur en dernière année de contrat.
// CD_PLAN_CAPTURES=<dossier> (+ CD_PLAN_TAILLE=LxH) : captures du terrain et de la saison prochaine.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { test } = require('node:test');
const M = require('./helpers/carriere-monde.cjs');

function preparer(sortie) {
  const jeu = M.ouvrir({ testVm: true });
  try {
    M.creer(jeu, 102);
    // Vraie offre de prolongation au salaire plancher : le joueur le plus exigeant en fin de contrat fait une
    // contre-offre (renewal.negotiation.status « counter »).
    const info = JSON.parse(jeu.bridge.vm.run(`JSON.stringify({plancher:typeof budgetActif==='function'&&budgetActif()?budgetPlancherHebdo():1000,
      joueurs:S.clubs[S.club].players.filter(p=>p.contractEnd===S.season).map(p=>{const annees=Math.max(1,p.contractEnd-contractBase()+2);
        return {id:p.id,annees,demande:reservationWage(p,'renew',annees)};}).sort((a,b)=>b.demande-a.demande)})`));
    const cible = info.joueurs.find(j => j.demande > info.plancher);
    if (!cible) return '';
    const model = jeu.call('extend_contract', { playerId: cible.id, salary: info.plancher, years: cible.annees, confirmed: true });
    const nego = model.squad.find(p => p.id === cible.id)?.renewal?.negotiation?.status === 'counter' ? cible.id : '';
    fs.writeFileSync(sortie, jeu.call('export').meta.exportText);
    return nego;
  } finally { jeu.fermer(); }
}

test('Planificateur d’effectif (carrière Monde)', { skip: !process.env.CD_GODOT_EXECUTABLE && 'SDK Godot requis : CD_GODOT_EXECUTABLE absent' }, () => {
  const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'cd-planificateur-'));
  const exportPath = path.join(profile, 'carriere.json');
  const nego = preparer(exportPath);
  assert.ok(nego, 'un joueur en dernière année de contrat pour la négociation');
  const captures = process.env.CD_PLAN_CAPTURES;
  const result = spawnSync(process.env.CD_GODOT_EXECUTABLE, [
    ...(captures ? [] : ['--headless']), '--audio-driver', 'Dummy', '--max-fps', '120', '--path', path.resolve(__dirname, '../native/godot'),
    '--script', path.resolve(__dirname, 'godot-planificateur.gd'),
  ], {
    env: { ...process.env, CD_NODE_EXECUTABLE: process.env.CD_NODE_EXECUTABLE || process.execPath, CD_GODOT_SELF_TEST: '0', CD_GODOT_DATA_DIR: path.join(profile, 'donnees'), CD_PLAN_EXPORT: exportPath, CD_PLAN_NEGO: nego },
    encoding: 'utf8', windowsHide: true, timeout: 300000,
  });
  const output = (result.stdout || '') + (result.stderr || '');
  fs.writeFileSync(path.join(profile, 'godot.log'), output);
  console.log(output.trim().split('\n').filter(l => /PLANIFICATEUR|FAIL|ERROR/.test(l)).join('\n'));
  if (result.error) throw result.error;
  assert.equal(result.status, 0, output.slice(-6000));
  assert.match(output, /PLANIFICATEUR \d+ controles, 0 echec/);
  assert.doesNotMatch(output, /SCRIPT ERROR|Parse Error/);
});
