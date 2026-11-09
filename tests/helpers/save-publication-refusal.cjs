'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

function refuseSavePublication(file, action) {
  const primary = path.resolve(file);
  const backup = path.join(path.dirname(primary), 'donnees-precedentes.json');
  const readBackup = () => fs.existsSync(backup) ? fs.readFileSync(backup) : null;
  const priorBackup = readBackup();
  const rename = fs.renameSync;
  let refused = 0;
  fs.renameSync = function(from, to) {
    if (typeof to === 'string' && path.resolve(to) === primary) {
      refused++;
      const error = new Error('Publication de la sauvegarde refusée par le test.');
      error.code = 'EACCES';
      throw error;
    }
    return rename.call(this, from, to);
  };
  try {
    const result = action();
    assert.equal(refused, 1, 'La commande doit atteindre le refus de publication injecté.');
    assert.deepEqual(readBackup(), priorBackup, 'Le fichier de secours doit être restauré à l’identique.');
    return result;
  } finally {
    fs.renameSync = rename;
  }
}

module.exports = {refuseSavePublication};
