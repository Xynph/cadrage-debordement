'use strict';
// Durable checkpoints are distinct from the rotating previous-save file.
const fs = require('node:fs');
const path = require('node:path');
const { createHash, randomUUID } = require('node:crypto');
const LIMITS = Object.freeze({ entries: 8, bytes: 256 * 1024 * 1024, profile: 64 * 1024 * 1024, save: 24 * 1024 * 1024 + 512, manifest: 4096 });
const ID = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
const validId = value => typeof value === 'string' && (ID.test(value) || value.startsWith('.preparation-') && ID.test(value.slice(13)));
const FILES = ['profil.json', 'carriere.json', 'copie.json'];
const digest = bytes => createHash('sha256').update(bytes).digest('hex');
const refusal = message => { throw Error('Copie de sécurité : ' + message); };

function createStore(dataDir) {
  const root = path.join(dataDir, 'Copies-securite');
  function directory(location) {
    const stat = fs.lstatSync(location);
    if (!stat.isDirectory() || stat.isSymbolicLink()) refusal('dossier non ordinaire ; opération refusée.');
    return stat;
  }
  function ensure(create = false) {
    directory(dataDir);
    if (!fs.existsSync(root)) {
      if (!create) return false;
      fs.mkdirSync(root);
    }
    directory(root);
    if (path.dirname(fs.realpathSync(root)) !== fs.realpathSync(dataDir)) refusal('dossier hors du profil.');
    return true;
  }
  function location(id) {
    if (!validId(id)) refusal('identifiant invalide.');
    if (!ensure()) refusal('copie introuvable.');
    const target = path.join(root, id);
    directory(target);
    return target;
  }
  function read(file, max) {
    const initial = fs.lstatSync(file);
    if (!initial.isFile() || initial.isSymbolicLink() || initial.size > max) refusal('fichier non ordinaire ou trop volumineux.');
    const fd = fs.openSync(file, fs.constants.O_RDONLY | (fs.constants.O_NOFOLLOW || 0));
    try {
      const actual = fs.fstatSync(fd);
      if (!actual.isFile() || actual.size > max || actual.dev !== initial.dev || actual.ino !== initial.ino) refusal('fichier remplacé pendant sa lecture.');
      return fs.readFileSync(fd);
    } finally { fs.closeSync(fd); }
  }
  function scan() {
    if (!ensure()) return { entries: [], usedBytes: 0 };
    const names = fs.readdirSync(root);
    if (names.length > 32) refusal('trop de dossiers dans les copies de sécurité.');
    const entries = []; let usedBytes = 0;
    for (const id of names) {
      if (!validId(id)) refusal('dossier inattendu ; vérifiez les copies avant de continuer.');
      const target = location(id);
      const files = fs.readdirSync(target);
      if (files.some(name => !FILES.includes(name))) refusal('fichier inattendu dans une copie.');
      let bytes = 0;
      for (const name of files) {
        const stat = fs.lstatSync(path.join(target, name));
        if (!stat.isFile() || stat.isSymbolicLink()) refusal('fichier non ordinaire dans une copie.');
        bytes += stat.size;
      }
      usedBytes += bytes;
      if(id.startsWith('.preparation-')) { entries.push({id,bytes,available:false,interrupted:true,createdAt:new Date(fs.statSync(target).birthtimeMs).toISOString(),error:'Préparation interrompue : copie non publiée. Vous pouvez la supprimer explicitement.'}); continue; }
      try {
        const meta = JSON.parse(read(path.join(target, 'copie.json'), LIMITS.manifest));
        if (meta.version !== 1 || meta.id !== id || !Number.isFinite(Date.parse(meta.createdAt)) ||
            !['import', 'nouvelle-carriere', 'restauration', 'adaptation-reprise'].includes(meta.reason) ||
            !Number.isInteger(meta.seed) || !Number.isFinite(meta.clock) ||
            typeof meta.club !== 'string' || meta.club.length > 160 ||
            !Number.isInteger(meta.season) || !Number.isInteger(meta.round) ||
            !/^[a-f0-9]{64}$/.test(meta.profileHash) || !/^[a-f0-9]{64}$/.test(meta.saveHash) ||
            !FILES.every(name => files.includes(name))) refusal('descriptif incomplet ou incompatible.');
        entries.push({ ...meta, bytes, available: true, error: '' });
      } catch (error) { entries.push({ id, bytes, available: false, error: 'Descriptif illisible ou incompatible.' }); }
    }
    entries.sort((a, b) => String(b.createdAt || '').localeCompare(String(a.createdAt || '')) || a.id.localeCompare(b.id));
    return { entries, usedBytes };
  }
  function project() {
    try { return { ...scan(), maxEntries: LIMITS.entries, maxBytes: LIMITS.bytes, error: '' }; }
    catch (error) { return { entries: [], usedBytes: 0, maxEntries: LIMITS.entries, maxBytes: LIMITS.bytes, error: error.message }; }
  }
  function load(id) {
    const entry = scan().entries.find(item => item.id === id);
    if (!entry || !entry.available) refusal('copie indisponible ; le profil actuel est conservé.');
    const target = location(id);
    const profile = read(path.join(target, 'profil.json'), LIMITS.profile);
    const save = read(path.join(target, 'carriere.json'), LIMITS.save);
    if (digest(profile) !== entry.profileHash || digest(save) !== entry.saveHash) refusal('empreinte différente : copie endommagée, profil actuel conservé.');
    const parsed = JSON.parse(profile);
    if (parsed.protocol !== 1 || !Number.isInteger(parsed.seed) || !Number.isFinite(parsed.clock)) refusal('profil de copie incompatible.');
    const document=JSON.parse(save.toString('utf8'));
    if(document.nativeReplay?.seed!==entry.seed||document.nativeReplay?.clock!==entry.clock)refusal('état de reprise incompatible.');
    delete document.nativeReplay;
    return { ...entry, text: JSON.stringify(document) };
  }
  function checkpoint({ profile, text, reason, club, season, round, replaySeed, replayClock }) {
    if (!Buffer.isBuffer(profile)) refusal('profil original requis.');
    if (profile.length > LIMITS.profile || Buffer.byteLength(text,'utf8') > LIMITS.save-512) refusal('la copie dépasserait sa taille maximale ; remplacement annulé.');
    const parsed = JSON.parse(profile);
    if (parsed.protocol !== 1 || !Number.isInteger(parsed.seed) || !Number.isFinite(parsed.clock)) refusal('profil original incompatible.');
    const seed=replaySeed??parsed.seed, clock=replayClock??parsed.clock;
    if(!Number.isInteger(seed)||!Number.isFinite(clock))refusal('horloge ou aléatoire de reprise invalide.');
    const document=JSON.parse(text);if(Object.hasOwn(document,'exportedAt'))document.exportedAt=new Date(clock).toISOString();document.nativeReplay={seed,clock};
    const save=Buffer.from(JSON.stringify(document),'utf8');
    if(save.length>LIMITS.save)refusal('état de reprise trop volumineux.');
    const profileHash = digest(profile), saveHash = digest(save);
    const state = scan();
    // A failed replacement can be retried without accumulating the same backup.
    const existing = state.entries.find(entry => entry.available && entry.profileHash === profileHash && entry.saveHash === saveHash && entry.reason === reason);
    if (existing) { load(existing.id); return existing; }
    const id = randomUUID();
    const meta = { version: 1, id, createdAt: new Date().toISOString(), reason, club, season, round,
      seed, clock, profileHash, saveHash };
    const manifest = Buffer.from(JSON.stringify(meta), 'utf8');
    const bytes = profile.length + save.length + manifest.length;
    if (state.entries.length >= LIMITS.entries || state.usedBytes + bytes > LIMITS.bytes)
      refusal('limite atteinte (8 copies ou 256 Mio). Supprimez explicitement une copie dans « Copies de sécurité », puis réessayez.');
    if (manifest.length > LIMITS.manifest) refusal('descriptif trop volumineux.');
    ensure(true);
    const temporary = path.join(root, '.preparation-' + id), target = path.join(root, id);
    fs.mkdirSync(temporary);
    try {
      for (const [name, content] of [['profil.json', profile], ['carriere.json', save], ['copie.json', manifest]]) {
        const fd = fs.openSync(path.join(temporary, name), 'wx');
        try { fs.writeFileSync(fd, content); fs.fsyncSync(fd); } finally { fs.closeSync(fd); }
      }
      fs.renameSync(temporary, target);
    } catch (error) {
      try { fs.rmSync(temporary, { recursive: true, force: true }); } catch {}
      refusal('écriture impossible ; remplacement annulé. ' + error.message);
    }
    return { ...meta, bytes, available: true, error: '' };
  }
  function remove(id, confirmed) {
    if (confirmed !== true) refusal('confirmation explicite requise pour supprimer une copie.');
    const target = location(id);
    const names = fs.readdirSync(target);
    if (names.some(name => !FILES.includes(name))) refusal('contenu inattendu ; suppression automatique refusée.');
    for (const name of names) {
      const stat = fs.lstatSync(path.join(target, name));
      if (!stat.isFile() || stat.isSymbolicLink()) refusal('fichier non ordinaire ; suppression refusée.');
    }
    // Retire only the explicitly selected UUID, never a client-supplied path.
    fs.rmSync(target, { recursive: true });
    return { command: 'remove_checkpoint', id };
  }
  return { project, load, checkpoint, remove, readProfile: file => read(file, LIMITS.profile) };
}
module.exports = { createStore, LIMITS };
