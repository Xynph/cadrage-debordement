'use strict';
// Plusieurs carrières enregistrées (19/11/2026).
// La carrière ouverte reste dans `donnees.json` (inchangé pour tout le reste du moteur, des outils et des tests) :
// une ancienne sauvegarde unique devient donc d'elle-même la première carrière, sans aucune conversion.
// Les autres carrières sont rangées, moteur fermé, dans `Carrieres/<uuid>/` :
//   carriere.json   {version:1, id, seed, clock, store:{clés de carrière}}  (aléatoire et horloge de cette carrière)
//   resume.json     {version:1, id, club, season, round, savedAt}           (liste sans relire la carrière)
//   donnees-precedentes.json, journal-*.jsonl                              (secours de cette carrière, s'il y en a)
// La reprise avant le match suit la carrière : le moteur enregistre d'abord (pendant un match, l'état d'avant le coup
// d'envoi), puis la carrière part avec ses propres clés (dont `bdt-matchday-pending`).
// Exemple : `stash(dir)` range la carrière ouverte, `restore(dir, id)` la rouvre, `list(dir)` les décrit.
const fs = require('node:fs');
const path = require('node:path');
const { randomUUID } = require('node:crypto');

const CAREER_KEYS = ['bdt-v1', 'bdt-backup-v1', 'bdt-before-import', 'bdt-recovery-invalid', 'bdt-backup-development', 'bdt-backup-economy', 'bdt-matchday-pending', 'bdt-exported-at'];
const ID = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
const SIDE_FILE = name => name === 'donnees-precedentes.json' || /^journal-.*\.jsonl$/.test(name);
const refusal = message => { throw Error('Carrières : ' + message); };

const root = dataDir => path.join(dataDir, 'Carrieres');
function writeAtomic(target, text) {
  const temp = target + '.tmp-' + randomUUID();
  const fd = fs.openSync(temp, 'wx');
  try { fs.writeFileSync(fd, text); fs.fsyncSync(fd); } finally { fs.closeSync(fd); }
  fs.renameSync(temp, target);
}
function readProfile(dataDir) {
  const file = path.join(dataDir, 'donnees.json');
  if (!fs.existsSync(file)) return null;
  const saved = JSON.parse(fs.readFileSync(file, 'utf8'));
  if (saved.protocol !== 1 || !saved.store || typeof saved.store !== 'object' || Array.isArray(saved.store)) refusal('profil illisible ; rien n’a été déplacé.');
  return saved;
}
// Résumé lisible d'une carrière (club, saison, journée) depuis son texte enregistré.
function summarize(text) {
  try {
    let state = JSON.parse(text);
    if (state && state.state && typeof state.state === 'object') state = state.state;
    const club = state?.clubs?.[state.club]?.name;
    return { club: typeof club === 'string' ? club.slice(0, 160) : 'Carrière', season: Number.isInteger(state?.season) ? state.season : null, round: Number.isInteger(state?.round) ? state.round : null };
  } catch { return { club: 'Carrière', season: null, round: null }; }
}
function slotDir(dataDir, id) {
  if (typeof id !== 'string' || !ID.test(id)) refusal('identifiant invalide.');
  const target = path.join(root(dataDir), id);
  const stat = fs.existsSync(target) ? fs.lstatSync(target) : null;
  if (!stat || !stat.isDirectory() || stat.isSymbolicLink()) refusal('carrière introuvable.');
  return target;
}
function hasActive(dataDir) {
  const saved = readProfile(dataDir);
  return !!saved && typeof saved.store['bdt-v1'] === 'string';
}
// Carrière ouverte décrite comme une carrière rangée (null s'il n'y en a pas).
function active(dataDir) {
  const saved = readProfile(dataDir);
  if (!saved || typeof saved.store['bdt-v1'] !== 'string') return null;
  return { ...summarize(saved.store['bdt-v1']), savedAt: fs.statSync(path.join(dataDir, 'donnees.json')).mtime.toISOString() };
}
function list(dataDir) {
  if (!fs.existsSync(root(dataDir))) return [];
  const entries = [];
  for (const id of fs.readdirSync(root(dataDir))) {
    if (!ID.test(id)) continue;
    try {
      const meta = JSON.parse(fs.readFileSync(path.join(root(dataDir), id, 'resume.json'), 'utf8'));
      if (meta.version !== 1 || meta.id !== id) continue;
      entries.push({ id, club: String(meta.club), season: meta.season, round: meta.round, savedAt: String(meta.savedAt) });
    } catch { /* rangement interrompu : ignoré, jamais effacé */ }
  }
  return entries.sort((a, b) => b.savedAt.localeCompare(a.savedAt) || a.id.localeCompare(b.id));
}
// Range la carrière ouverte ; le profil garde réglages, packs et préférences. Renvoie l'identifiant (null : rien à ranger).
function stash(dataDir) {
  const saved = readProfile(dataDir);
  if (!saved || typeof saved.store['bdt-v1'] !== 'string') return null;
  const id = randomUUID(), career = {};
  for (const key of CAREER_KEYS) if (Object.hasOwn(saved.store, key)) career[key] = saved.store[key];
  fs.mkdirSync(root(dataDir), { recursive: true });
  const temporary = path.join(root(dataDir), '.preparation-' + id), target = path.join(root(dataDir), id);
  fs.mkdirSync(temporary);
  try {
    writeAtomic(path.join(temporary, 'carriere.json'), JSON.stringify({ version: 1, id, seed: saved.seed, clock: saved.clock, store: career }));
    writeAtomic(path.join(temporary, 'resume.json'), JSON.stringify({ version: 1, id, ...summarize(career['bdt-v1']), savedAt: fs.statSync(path.join(dataDir, 'donnees.json')).mtime.toISOString() }));
    fs.renameSync(temporary, target);
  } catch (error) {
    try { fs.rmSync(temporary, { recursive: true, force: true }); } catch {}
    refusal('rangement impossible ; la carrière ouverte est conservée. ' + error.message);
  }
  const store = { ...saved.store };
  for (const key of CAREER_KEYS) delete store[key];
  writeAtomic(path.join(dataDir, 'donnees.json'), JSON.stringify({ ...saved, store }));
  for (const name of fs.readdirSync(dataDir)) if (SIDE_FILE(name)) fs.renameSync(path.join(dataDir, name), path.join(target, name));
  return id;
}
// Rouvre une carrière rangée ; la carrière ouverte doit avoir été rangée avant.
function restore(dataDir, id) {
  const source = slotDir(dataDir, id);
  if (hasActive(dataDir)) refusal('une carrière est déjà ouverte.');
  const slot = JSON.parse(fs.readFileSync(path.join(source, 'carriere.json'), 'utf8'));
  if (slot.version !== 1 || slot.id !== id || typeof slot.store?.['bdt-v1'] !== 'string') refusal('carrière rangée illisible ; elle est conservée.');
  const saved = readProfile(dataDir) || { protocol: 1, seed: slot.seed, clock: slot.clock, store: {} };
  for (const name of fs.readdirSync(dataDir)) if (SIDE_FILE(name)) fs.unlinkSync(path.join(dataDir, name));
  writeAtomic(path.join(dataDir, 'donnees.json'), JSON.stringify({ ...saved, seed: slot.seed, clock: slot.clock, store: { ...saved.store, ...slot.store } }));
  for (const name of fs.readdirSync(source)) if (SIDE_FILE(name)) fs.renameSync(path.join(source, name), path.join(dataDir, name));
  fs.rmSync(source, { recursive: true });
  return id;
}
function remove(dataDir, id, confirmed) {
  if (confirmed !== true) refusal('confirmation requise pour supprimer une carrière.');
  const target = slotDir(dataDir, id);
  fs.rmSync(target, { recursive: true });
  return id;
}
// Commande `career_slots` du moteur (worker.cjs, mode stdio) : {action:'list'|'new'|'open'|'delete', id?, confirmed?}.
// `new` et `open` enregistrent la carrière ouverte, ferment le moteur, déplacent les carrières puis relancent le moteur ;
// la réponse porte alors le modèle complet de la carrière ouverte. Toutes les réponses portent `careerSlots`.
function command(request, host) {
  const id = request.id ?? null, payload = request.payload || {}, action = payload.action;
  const base = host.options.dataDir;
  const dataDir = path.resolve(base, path.basename(base) === 'PrototypeGodot' ? '' : 'PrototypeGodot');
  const describe = () => ({ active: active(dataDir), saved: list(dataDir) });
  // Modèle joint à chaque réponse : l'interface attend un modèle pour terminer la commande.
  const current = () => ({ ...host.bridge.handle({ id, command: 'snapshot', payload: {} }), careerSlots: describe() });
  try {
    if (action === 'list') return current();
    if (action === 'delete') { remove(dataDir, payload.id, payload.confirmed); return current(); }
    if (action !== 'new' && action !== 'open') refusal('action inconnue.');
    if (action === 'open') slotDir(dataDir, payload.id);
    const saved = host.bridge.handle({ id, command: 'save', payload: {} });
    if (!saved.ok && hasActive(dataDir)) refusal('enregistrement impossible avant de changer de carrière : ' + (saved.error || 'erreur inconnue') + '.');
    host.bridge.close();
    let stashed = null;
    try {
      stashed = stash(dataDir);
      if (action === 'open') restore(dataDir, payload.id);
    } catch (error) {
      if (stashed && !hasActive(dataDir)) { try { restore(dataDir, stashed); } catch {} }
      host.bridge = host.create(host.options);
      throw error;
    }
    host.bridge = host.create(host.options);
    return { ...current(), reopened: true };
  } catch (error) {
    return { id, ok: false, model: null, error: error.message, careerSlots: (() => { try { return describe(); } catch { return { active: null, saved: [] }; } })() };
  }
}
module.exports = { CAREER_KEYS, list, active, stash, restore, remove, summarize, command };
