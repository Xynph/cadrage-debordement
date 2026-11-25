'use strict';
// Export compressé (exportVersion 4) dans le vrai moteur, carrière Monde (world-champ) : plafond d'export abaissé à
// 8 Mio (essais, option saveBytes) pour que ni l'export ordinaire ni l'export réduit v3 n'y tiennent, comme une fin de
// saison 2 sous le plafond réel de 24 Mio. Export -> import dans un pont neuf : état identique ; l'export v3 non
// compressé du pont neuf se relit ; un export compressé retouché (même empreinte) est refusé, la carrière reste intacte.
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const zlib = require('node:zlib');
const { test } = require('node:test');
const M = require('./helpers/carriere-monde.cjs');

const sha = text => crypto.createHash('sha256').update(text, 'utf8').digest('hex');
const PLAFOND = 8 * 1024 * 1024;
const version = texte => Number(/"exportVersion":(\d+)/.exec(texte.slice(0, 300))[1]);

test('Monde : export compressé v4 -> import identique, ancien format relu, fichier retouché refusé', { timeout: 900000 }, () => {
  const jeu = M.ouvrir({ testVm: true, hebdomadaire: true, rapide: true, saveBytes: PLAFOND, seed: 7 });
  let neuf = null;
  try {
    jeu.regler(jeu.call('new_career', { mode: 'world-champ', club: 29 }));
    const etat = jeu.bridge.vm.run('JSON.stringify(S)');
    assert.ok(Buffer.byteLength(etat) > 2 * PLAFOND, 'carrière Monde bien plus grosse que le plafond abaissé');
    let t = Date.now();
    const exporte = jeu.call('export', { proof: true }).meta;
    const exportMs = Date.now() - t;
    const texte = exporte.exportText, octets = Buffer.byteLength(texte);
    assert.equal(version(texte), 4, 'export compressé attendu');
    assert.ok(octets <= PLAFOND, 'fichier compressé sous le plafond (' + octets + ' octets)');
    assert.equal(exporte.exportRoundTripSha256, sha(etat), 'l\'export porte exactement l\'état de la carrière');
    const enveloppe = JSON.parse(texte);
    assert.deepEqual(Object.keys(enveloppe), ['format', 'exportVersion', 'exportedAt', 'checksum', 'compression', 'data']);
    const interne = zlib.gunzipSync(Buffer.from(enveloppe.data, 'base64')).toString('utf8');
    assert.equal(version(interne), 3, 'contenu : export réduit v3 complet');

    // Import dans un pont neuf (plafond réel) : état identique au bit près, et deepEqual.
    neuf = M.ouvrir({ testVm: true, hebdomadaire: true, rapide: true, seed: 7 });
    t = Date.now();
    const recu = neuf.brut('import', { text: texte });
    const importMs = Date.now() - t;
    assert.equal(recu.ok, true, 'import : ' + recu.error);
    const relu = neuf.bridge.vm.run('JSON.stringify(S)');
    assert.equal(sha(relu), sha(etat), 'état importé identique (texte)');
    assert.deepStrictEqual(JSON.parse(relu), JSON.parse(etat), 'état importé identique (deepEqual)');
    assert.equal(neuf.call('export', { proof: true }).meta.exportRoundTripSha256, sha(etat), 'réexport : même état');

    // Ancien format non compressé : l'export (v1 à v3) du pont neuf (plafond 24 Mio) se relit dans le pont qui compresse.
    const ancien = neuf.call('export').meta.exportText;
    assert.ok(version(ancien) < 4, 'sous 24 Mio, l\'export reste non compressé (v' + version(ancien) + ')');
    assert.equal(jeu.brut('import', { text: ancien }).ok, true, 'export non compressé relu');
    assert.equal(sha(jeu.bridge.vm.run('JSON.stringify(S)')), sha(etat), 'export non compressé : état identique');

    // Export compressé retouché, empreinte inchangée : refusé par la signature, carrière ouverte intacte.
    const doc = JSON.parse(interne);
    const joueur = doc.state.clubs[doc.state.club].players[0];
    joueur.salary += 1000;
    const retouche = JSON.stringify({ ...enveloppe, data: zlib.gzipSync(Buffer.from(JSON.stringify(doc), 'utf8')).toString('base64') });
    const refus = jeu.brut('import', { text: retouche });
    assert.equal(refus.ok, false, 'fichier retouché accepté');
    assert.match(refus.error, /modifié ou endommagé/i);
    const abime = JSON.stringify({ ...enveloppe, data: enveloppe.data.slice(0, 1000) + (enveloppe.data[1000] === 'A' ? 'B' : 'A') + enveloppe.data.slice(1001) });
    assert.match(jeu.brut('import', { text: abime }).error, /modifié ou endommagé/i, 'octet compressé changé : refusé');
    assert.equal(sha(jeu.bridge.vm.run('JSON.stringify(S)')), sha(etat), 'après les refus, la carrière ouverte est intacte');
    console.log(JSON.stringify({ etatMio: +(Buffer.byteLength(etat) / 1048576).toFixed(2), exportMio: +(octets / 1048576).toFixed(2), exportMs, importMs }));
  } finally { jeu.fermer(); if (neuf) neuf.fermer(); }
});
