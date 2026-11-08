'use strict';
const fs = require('node:fs');
const path = require('node:path');

const messages = Object.freeze({
  INVALID_PATH: 'Chemins de remplacement invalides.',
  INVALID_SOURCE: 'Le temporaire doit être un fichier ordinaire.',
  INVALID_DESTINATION: 'La destination doit être un fichier ordinaire.',
  DIFFERENT_DIRECTORY: 'Le temporaire et la destination doivent partager le même dossier.',
  ENOENT: 'Fichier temporaire ou dossier introuvable.',
  EACCES: 'Accès au fichier refusé.',
  EPERM: 'Remplacement refusé : vérifier les droits et les fichiers ouverts.',
  EBUSY: 'Un fichier est utilisé par un autre programme.',
  ENOSPC: 'Espace disque insuffisant.',
  EIO: 'Erreur de lecture ou d’écriture du disque.',
  FAILED: 'Remplacement du fichier refusé.'
});
function refusal(code) {
  if (!Object.hasOwn(messages, code)) code = 'FAILED';
  return { ok: false, code, error: messages[code] };
}
function samePath(left, right) {
  return process.platform === 'win32' ? left.toLowerCase() === right.toLowerCase() : left === right;
}
function replaceStaged(temporary, destination) {
  try {
    if (![temporary, destination].every(value => typeof value === 'string' && !value.includes('\0') && path.isAbsolute(value))) return refusal('INVALID_PATH');
    temporary = path.resolve(temporary); destination = path.resolve(destination);
    if (samePath(temporary, destination)) return refusal('INVALID_PATH');
    // Same real directory also excludes cross-volume moves and alias bypasses.
    if (!samePath(fs.realpathSync(path.dirname(temporary)), fs.realpathSync(path.dirname(destination)))) return refusal('DIFFERENT_DIRECTORY');
    const source = fs.lstatSync(temporary);
    if (!source.isFile()) return refusal('INVALID_SOURCE');
    let target;
    try { target = fs.lstatSync(destination); } catch (error) { if (error.code !== 'ENOENT') throw error; }
    if (target && !target.isFile()) return refusal('INVALID_DESTINATION');
    if (target && target.dev === source.dev && target.ino === source.ino) return refusal('INVALID_PATH');
    const descriptor = fs.openSync(temporary, 'r+');
    try { fs.fsyncSync(descriptor); } finally { fs.closeSync(descriptor); }
    // libuv uses MoveFileExW(MOVEFILE_REPLACE_EXISTING) on Windows.
    // Never unlink the destination: refusal must leave the original in place.
    fs.renameSync(temporary, destination);
    return { ok: true };
  } catch (error) { return refusal(error.code); }
}
module.exports = { replaceStaged };
if (require.main === module) {
  const result = process.argv.length === 4 ? replaceStaged(process.argv[2], process.argv[3]) : refusal('INVALID_PATH');
  // Godot OS.execute may decode stdout with the Windows system code page.
  // ASCII JSON survives that boundary; JSON.parse restores identical Unicode.
  const json = JSON.stringify(result).replace(/[\u0080-\uffff]/g, character => '\\u' + character.charCodeAt(0).toString(16).padStart(4, '0'));
  process.stdout.write(json + '\n');
  process.exitCode = result.ok ? 0 : 1;
}
