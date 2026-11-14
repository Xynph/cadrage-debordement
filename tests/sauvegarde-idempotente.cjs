'use strict';
// Sauvegarde idempotente (carrière Monde `world-champ`) : charger un profil ne modifie rien, et
// export -> import -> export redonne exactement le même état (avant-saison, reprise, notes de match v2, abonnés).
//
// Un grand export Monde est réduit sans perte (exportVersion 2/3 : références de joueurs, marché) : son état
// littéral n'est plus celui de la sauvegarde. L'export `{proof:true}` livre donc l'empreinte SHA-256 du texte de
// l'état exporté avant réduction ; elle doit être celle du texte exact du profil (c'est ce que contrôle la recette
// Windows). Le profil Monde pèse ~24 Mio : on compare des empreintes et des sous-chaînes, sans garder d'arbres
// d'objets (machine de 8 Go, Node limité à 1300 Mo).
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { test } = require('node:test');
const M = require('./helpers/carriere-monde.cjs');

const sha = text => crypto.createHash('sha256').update(text, 'utf8').digest('hex');
const fichier = dir => path.join(dir, 'PrototypeGodot', 'donnees.json');
const enregistre = dir => JSON.parse(fs.readFileSync(fichier(dir), 'utf8')).store['bdt-v1'];
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
    if (plafond) {
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

test('Monde : export -> import -> export identique (avant-saison, reprise, notes de match, abonnés), export réduit compris', { timeout: 1500000 }, () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'rl27-sauvegarde-')), creation = dir + '-creation';
  try {
    // Un seul pont joue (la mémoire du moteur est le facteur limitant) : départ « club », copie du profil à la création,
    // puis un match et la politique supporters ; les vérifications rechargent chaque profil dans un pont neuf, ensuite.
    const jeu = M.ouvrir({ dataDir: dir });
    try {
      // Départ « club » : avant-saison du 13 juillet (S.preseason) et choix de reprise (S.reprise).
      let model = jeu.regler(jeu.call('new_career', { mode: 'world-champ', club: 102, start: 'club' }));
      jeu.call('save');
      fs.cpSync(dir, creation, { recursive: true });
      fs.rmSync(path.join(creation, 'PrototypeGodot', 'profil.lock'), { force: true });
      // Après un match : notes de match v2 ; politique supporters : le socle d'abonnés est posé (ou recalculé) ici.
      model = M.jouer(jeu, model, 1);
      jeu.call('club_fans_price', { context: model.clubLife.clubStrategy.context, key: 'accessible' });
      jeu.call('save');
    } finally { jeu.fermer(); }

    const depart = faits(creation);
    assert.equal(depart.avantSaison, true, 'avant-saison présente à la création');
    assert.equal(depart.reprise, true, 'reprise présente à la création');
    rechargerEtVerifier(creation, 'création');
    fs.rmSync(creation, { recursive: true, force: true }); // disque : un profil Monde pèse plus de 100 Mio avec ses copies de sécurité

    const jouee = faits(dir);
    assert.equal(jouee.notes, 2, 'notes de match v2');
    assert.ok(jouee.joueursNotes, 'notes de match enregistrées');
    assert.ok(Number.isInteger(jouee.abonnes) && jouee.abonnes > 0, 'abonnés présents');
    const taille = rechargerEtVerifier(dir, 'après un match');

    // Export réduit (plafond abaissé de 10 %) : l'état littéral diffère, l'aller-retour reste exact.
    rechargerEtVerifier(dir, 'export réduit', Math.floor(taille * 0.9));
  } finally { fs.rmSync(dir, { recursive: true, force: true }); fs.rmSync(creation, { recursive: true, force: true }); }
});
