'use strict';
// Export compressé des carrières (exportVersion 4, dist/saves.js) : le document d'export complet (v1, v2 ou v3), tel que
// le jeu l'écrirait sans plafond, est compressé en gzip puis codé en base64 dans une enveloppe JSON. Sans perte : la
// lecture retrouve exactement le même texte, puis le relit comme aujourd'hui (reconstruction, empreinte, validation).
// Le plafond du fichier (24 Mio pour le Champ) s'applique au fichier compressé ; le texte décompressé a son propre
// plafond (INFLATED_LIMIT_BYTES), vérifié pendant la décompression, contre les fichiers piégés (bombes de décompression).
const zlib = require('node:zlib');

// Niveau 6 (zlib par défaut). Mesure du 25/11/2026, export v3 de 14,8 Mio (carrière du Champ créée, graine 7) :
// niveau 1 → 3,92 Mio en 42 ms, 3 → 3,57 Mio en 56 ms, 6 → 2,96 Mio en 147 ms, 9 → 2,83 Mio en 170 ms (base64 compris) ;
// le niveau 9 ne gagne que 4 % et peut coûter bien plus sur des données moins régulières.
const LEVEL = 6;
const decoder = new TextDecoder('utf-8', { fatal: true });

function compress(text) {
  if (typeof text !== 'string') throw Error('Texte d’export requis.');
  return zlib.gzipSync(Buffer.from(text, 'utf8'), { level: LEVEL }).toString('base64');
}

// `limit` : taille maximale (octets UTF-8) du texte décompressé ; la décompression s'arrête dès qu'elle la dépasse.
function inflate(data, limit) {
  if (typeof data !== 'string' || data.length === 0) throw Error('Contenu compressé absent.');
  if (!Number.isSafeInteger(limit) || limit <= 0) throw Error('Plafond de décompression invalide.');
  const bytes = Buffer.from(data, 'base64');
  // Base64 canonique exigé : Buffer.from ignore les caractères étrangers, un fichier retouché serait sinon lu en partie.
  if (bytes.toString('base64') !== data) throw Error('Contenu compressé illisible.');
  let out;
  try { out = zlib.gunzipSync(bytes, { maxOutputLength: limit }); }
  catch (error) {
    if (error && error.code === 'ERR_BUFFER_TOO_LARGE') throw Error('Contenu décompressé trop volumineux (' + Math.round(limit / 1048576) + ' Mio maximum).');
    throw Error('Contenu compressé endommagé.');
  }
  try { return decoder.decode(out); } catch { throw Error('Contenu compressé endommagé.'); }
}

// Branche les deux fonctions dans le contexte du moteur (VM) : dist/saves.js les appelle s'il les trouve.
function install(ctx) {
  ctx.nativeSaveCompress = compress;
  ctx.nativeSaveInflate = inflate;
  return ctx;
}

module.exports = { compress, inflate, install, LEVEL };
