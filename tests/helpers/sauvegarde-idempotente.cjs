'use strict';
// Outils de tests/sauvegarde-idempotente.cjs, tests/sauvegarde-idempotente-match.cjs et tests/sauvegarde-idempotente-reduit.cjs (suite unique coupée en trois le
// 16/11/2026 pour rester sous le délai de 180 s du lanceur CI) : lecture du profil enregistré et aller-retour
// export -> import -> export. Le profil Monde pèse ~24 Mio : on compare des empreintes et des sous-chaînes, sans garder
// d'arbres d'objets (machine de 8 Go, Node limité à 1300 Mo).
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const M = require('./carriere-monde.cjs');

const sha = text => crypto.createHash('sha256').update(text, 'utf8').digest('hex');
const fichier = dir => path.join(dir, 'PrototypeGodot', 'donnees.json');
const enregistre = dir => JSON.parse(fs.readFileSync(fichier(dir), 'utf8')).store['bdt-v1'];
// Plafond d'un export non réduit d'une carrière du Champ (édition v5, native/engine/world-editions.cjs : 24 Mio). L'état
// de la carrière du Champ pèse désormais plus que ce plafond dès la veille de la première rencontre (25,6 Mio, dont 0,65 Mio
// de relevés hebdomadaires des qualités, #1225) : l'export est alors réduit sans perte (exportVersion 3), comme le prévoit
// la sauvegarde ; le test déduit donc la version attendue de la taille, au lieu de supposer un export non réduit.
const PLAFOND_EXPORT = 24 * 1024 * 1024;
// Taille exacte de l'export non réduit (version 1) : enveloppe (tout ce qui précède l'état, de même longueur en version 1
// et 3), état du profil, accolade fermante. C'est la taille que le plafond de l'export compare à sa limite.
const tailleNonReduite = (texteExport, profil) => texteExport.indexOf('"state":') + '"state":'.length + Buffer.byteLength(profil, 'utf8') + 1;
const champ = (texte, nom) => { const m = new RegExp('"' + nom + '":("?)([^",}]+)').exec(texte.slice(0, 400)); return m && m[2]; };

// Faits utiles de l'état enregistré, lus dans son texte (sans arbre d'objets).
function faits(dir) {
  const t = enregistre(dir), notes = /"matchNotes":\{"version":(\d+),"saison":\d+,"joueurs":\{(")?/.exec(t), abonnes = /"v111to116":\{[^}]*?"subscribers":(\d+)/.exec(t);
  return { avantSaison: /"preseason":\{"version":1/.test(t), reprise: /"reprise":\{"version":1/.test(t),
    abonnes: abonnes ? Number(abonnes[1]) : null, notes: notes ? Number(notes[1]) : null, joueursNotes: Boolean(notes?.[2]) };
}

// Recharge le profil `dir` (nouveau pont), vérifie que le chargement ne change rien, puis l'aller-retour.
// `plafond` : plafond d'export abaissé (essais) pour exercer la réduction sans perte.
function rechargerEtVerifier(dir, etiquette, plafond) {
  const octets = fs.readFileSync(fichier(dir));
  const profil = enregistre(dir), empreinte = sha(profil);
  const jeu = M.ouvrir({ dataDir: dir, ...(plafond ? { saveBytes: plafond } : {}) });
  try {
    const premier = jeu.call('export', { proof: true });
    // 1. Le chargement ne modifie rien : l'état exporté est le texte exact du profil, les octets du profil sont intacts.
    assert.equal(premier.meta.exportRoundTripSha256, empreinte, etiquette + ' : l\'état chargé diffère de la sauvegarde');
    assert.ok(fs.readFileSync(fichier(dir)).equals(octets), etiquette + ' : le chargement et l\'export ont réécrit le profil');
    const version = Number(champ(premier.meta.exportText, 'exportVersion'));
    // Export réduit attendu quand l'export non réduit dépasse le plafond (celui de l'édition, ou le plafond abaissé).
    const reduit = tailleNonReduite(premier.meta.exportText, profil) > (plafond || PLAFOND_EXPORT);
    if (plafond) assert.ok(reduit, etiquette + ' : le plafond abaissé doit forcer la réduction');
    if (reduit) {
      // Cause de l'échec de la recette Windows : l'état littéral d'un export réduit n'est plus celui du profil.
      assert.ok(version > 1, etiquette + ' : export réduit attendu');
      assert.ok(!premier.meta.exportText.includes(profil), etiquette + ' : l\'export réduit garde l\'état littéral du profil');
    }
    else {
      assert.equal(version, 1);
      assert.ok(premier.meta.exportText.includes(profil), etiquette + ' : l\'état littéral de l\'export diffère du profil');
    }
    const taille = premier.meta.exportText.length, somme = champ(premier.meta.exportText, 'checksum');
    // 2. export -> import -> export identique (empreinte de l'état, version, intégrité, taille).
    jeu.call('import', { text: premier.meta.exportText });
    const second = jeu.call('export', { proof: true });
    assert.equal(second.meta.exportRoundTripSha256, empreinte, etiquette + ' : l\'import modifie l\'état');
    assert.equal(Number(champ(second.meta.exportText, 'exportVersion')), version);
    assert.equal(champ(second.meta.exportText, 'checksum'), somme, etiquette + ' : empreinte d\'intégrité');
    assert.equal(second.meta.exportText.length, taille, etiquette + ' : taille de l\'export après import');
    return taille;
  } finally { jeu.fermer(); }
}

// Carrière jouée (partagée par -match et -reduit) : ouverte la veille de la première rencontre (`start: 'veille'`, sans
// deux mois de calendrier : 77 s sur 143 dans la suite d'origine), un match, politique supporters (le socle d'abonnés
// est posé ou recalculé ici), sauvegarde. Un seul pont joue (la mémoire du moteur est le facteur limitant) ; les
// vérifications rechargent ensuite le profil dans un pont neuf. Rend la taille (octets) de l'export non réduit : le
// plafond abaissé de l'essai « réduit » s'en déduit (l'export réel est déjà réduit, il ne mesure plus cette taille).
function jouerUnMatch(dir) {
  const jeu = M.ouvrir({ dataDir: dir });
  try {
    let model = jeu.regler(jeu.call('new_career', { mode: 'world-champ', club: 102, start: 'veille' }));
    model = M.jouer(jeu, model, 1);
    jeu.call('club_fans_price', { context: model.clubLife.clubStrategy.context, key: 'accessible' });
    jeu.call('save');
    return tailleNonReduite(jeu.call('export', { proof: true }).meta.exportText, enregistre(dir));
  } finally { jeu.fermer(); }
}

module.exports = { M, jouerUnMatch, sha, fichier, enregistre, champ, faits, rechargerEtVerifier };
