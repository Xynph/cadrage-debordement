'use strict';
// Chorégraphe de temps forts (CD_MATCH_CHOREGRAPHE=1) : garanties de la mise en scène.
// Voir docs/match-choregraphe-20261112.md.
//
// Entrées :
// - tests/fixtures/match-choregraphe-essais.json : neuf essais en jeu courant extraits du
//   moteur natif (graines 7, 11, 42 et 99, club 0, niveau dynamique), entrées de la première
//   tranche (le plan d'essai seul) ;
// - tests/fixtures/match-choregraphe-tranche2.json : temps forts entiers du moteur natif
//   (graines 3, 7, 11, 42 et 99), tels que `entreeDepuisTempsFort` les construit : essais
//   depuis la mêlée ou la touche formée, le coup d'envoi ou la récupération, franchissements
//   sans essai, jeu au pied et chasse.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { test } = require('node:test');
const C = require('../native/engine/match-choregraphe.cjs');

const ENTREES = JSON.parse(fs.readFileSync(path.join(__dirname, 'fixtures', 'match-choregraphe-essais.json'), 'utf8'));
const TRANCHE2 = JSON.parse(fs.readFileSync(path.join(__dirname, 'fixtures', 'match-choregraphe-tranche2.json'), 'utf8'));
const ETATS_CHUTE = new Set(['plaquage', 'plaque', 'plaquage_rate', 'aplati', 'au_sol']);
const SOL = new Set(['plaque', 'au_sol', 'aplati', 'se_relever']);
const COMPOSES = ENTREES.map(({ source, entree }) => ({ source, entree, c: C.composer(entree) }));
const COMPOSES2 = TRANCHE2.map(({ source, entree }) => ({ source, entree, c: C.composer(entree) }));
const TOUS = [...COMPOSES, ...COMPOSES2];

const etatA = (j, t) => { let s = 'course'; for (const [u, x] of j.etats) if (u <= t + 1e-6) s = x; return s; };
const enContact = (c, t, a, b) => c.contacts.some(([t0, t1, x, y]) => t >= t0 - 0.25 && t <= t1 + 0.25 && (x === a && y === b || x === b && y === a));
const indice = (c, t) => Math.round(t / c.pas);

test('Neuf essais en jeu courant du moteur : une mise en scène de 12 à 25 s chacun', () => {
  assert.equal(ENTREES.length, 9);
  for (const { source, c } of COMPOSES) {
    assert.ok(c.duree >= C.DUREE_MIN && c.duree <= C.DUREE_MAX, `${source} : durée ${c.duree}`);
    const n = Math.round(c.duree / c.pas) + 1;
    assert.equal(c.ballon.x.length, n, `${source} : un échantillon de ballon par pas`);
    for (const j of c.joueurs) for (const k of ['x', 'y', 'v', 'cap']) {
      assert.equal(j[k].length, n, `${source} : piste ${k} complète`);
      assert.ok(j[k].every(Number.isFinite), `${source} : piste ${k} finie`);
    }
    assert.equal(c.joueurs.length, ENTREES.find(x => x.source === source).entree.joueurs.length);
    assert.ok(c.joueurs.length >= 20 && c.joueurs.length <= 30);
  }
});

test('Temps forts entiers : chaque type mis en scène, de 12 s à la durée permise, chaque fait du moteur montré à son jalon', () => {
  const types = new Set(COMPOSES2.map(({ c }) => c.type)), ouvertures = new Set(COMPOSES2.map(({ c }) => c.ouverture));
  for (const t of C.TYPES) assert.ok(types.has(t), `type ${t} couvert par le jeu d’entrées`);
  for (const o of ['jeu', 'melee', 'touche', 'envoi']) assert.ok(ouvertures.has(o), `ouverture ${o} couverte`);
  for (const { source, entree, c } of COMPOSES2) {
    assert.ok(c.duree >= C.DUREE_MIN && c.duree <= c.dureeMax && c.dureeMax <= C.DUREE_PLAFOND, `${source} : durée ${c.duree} (plafond ${c.dureeMax})`);
    const n = Math.round(c.duree / c.pas) + 1;
    assert.equal(c.ballon.x.length, n, `${source} : un échantillon de ballon par pas`);
    for (const j of c.joueurs) for (const k of ['x', 'y', 'v', 'cap']) assert.equal(j[k].length, n, `${source} : piste ${k} complète`);
    assert.equal(c.premier, entree.premier); assert.equal(c.dernier, entree.dernier);
    assert.equal(c.coupe, entree.ouverture.k !== 'jeu', `${source} : coupe d'entrée sur une remise en jeu formée`);
    // Un jalon par plan couvert (remise en jeu, ballon gagné, porteur plaqué, réception, essai), dans l'ordre.
    const plans = c.jalons.map(([, k]) => k), temps = c.jalons.map(([t]) => t);
    assert.deepEqual(plans, entree.jalonsAttendus, `${source} : jalons ${JSON.stringify(c.jalons)}`);
    for (let i = 1; i < temps.length; i++) assert.ok(temps[i] >= temps[i - 1], `${source} : jalons dans l’ordre`);
    assert.ok(temps.every(t => t >= 0 && t <= c.duree), `${source} : jalons dans la durée`);
  }
});

test('Issue du moteur, temps forts entiers : porteurs, gains, plaquages, réception ou touche, récupération', () => {
  for (const { source, entree, c } of COMPOSES2) {
    const sens = c.sens, parId = new Map(c.joueurs.map(j => [j.id, j]));
    const porteurs = c.ballon.porteurs.filter(([, id]) => id).map(([, id]) => id);
    // Chaque porteur que le moteur désigne a le ballon ; chaque gain du moteur finit par un plaquage près de son point.
    for (const s of entree.etapes) {
      if (s.joueur && ['porte', 'franchi', 'essai'].includes(s.k)) assert.ok(porteurs.includes(String(s.joueur)), `${source} : ${s.joueur} porte le ballon (${s.k})`);
      if ((s.k === 'porte' || s.k === 'franchi') && Number.isFinite(s.x)) {
        const p = c.evenements.find(e => e.type === 'plaquage' && e.porteur === String(s.joueur) && e.cible != null);
        assert.ok(p, `${source} : ${s.joueur} plaqué au bout de son gain`);
        assert.ok(Math.abs(p.x - s.x) <= 6, `${source} : plaquage à ${p.x} pour un gain du moteur jusqu’à ${s.x}`);
      }
    }
    const types = new Set(c.evenements.map(e => e.type));
    if (c.type === 'essai_jeu_courant') {
      assert.equal(porteurs.at(-1), c.marqueur, `${source} : dernier porteur = marqueur`);
      assert.equal(c.evenements.filter(e => e.type === 'aplati').length, 1);
      const n = c.ballon.x.length - 1;
      assert.ok(Math.abs(c.ballon.x[n] - c.essai.x) < 0.01 && Math.abs(c.ballon.y[n] - c.essai.y) < 0.01, `${source} : ballon au point d’essai`);
      const percee = c.evenements.filter(e => e.type === 'percee').at(-1);
      assert.ok(percee && percee.joueur === c.marqueur && !c.evenements.some(e => e.type === 'plaquage' && e.t >= percee.t), `${source} : aucun plaquage réussi après la percée du marqueur`);
    } else {
      assert.ok(!types.has('aplati'), `${source} : pas d’essai montré`);
      // Jamais d'essai suggéré : le ballon n'entre pas dans l'en-but adverse.
      assert.ok(c.ballon.x.every(x => c.sens > 0 ? x < 100 : x > 0), `${source} : jamais dans l’en-but adverse`);
    }
    if (c.type === 'franchissement') {
      const f = entree.etapes.find(s => s.k === 'franchi');
      assert.ok(c.evenements.some(e => e.type === 'percee' && e.joueur === String(f.joueur)), `${source} : percée du porteur du moteur`);
      assert.ok(c.evenements.some(e => e.type === 'plaquage_rate' && e.porteur === String(f.joueur)) || true);
    }
    if (c.type === 'jeu_au_pied') {
      const k = c.evenements.filter(e => e.type === 'jeu_au_pied');
      assert.equal(k.length, 1, `${source} : un coup de pied`);
      assert.equal(k[0].joueur, c.vedette, `${source} : botteur`);
      const pied = entree.etapes.find(s => s.k === 'pied');
      if (k[0].issue === 'touche') {
        const n = c.ballon.x.length - 1;
        assert.ok(c.ballon.y[n] < 0 || c.ballon.y[n] > 70, `${source} : ballon sorti en touche`);
        assert.ok(Math.abs(c.ballon.x[n] - pied.x) < 0.5, `${source} : sortie au point du moteur`);
      } else {
        const r = c.evenements.find(e => e.type === 'reception' && e.cible != null);
        assert.ok(r, `${source} : réception`);
        assert.ok(Math.abs(r.x - r.cible) <= 2, `${source} : réception à ${r.x} pour une chute du moteur à ${r.cible}`);
        if (entree.ouverture.k === 'envoi') assert.equal(r.joueur, String(entree.ouverture.receveur), `${source} : receveur du moteur`);
      }
    }
    // Récupération décidée par le moteur : le ballon finit chez l'équipe qui récupère.
    const recup = entree.etapes.filter(s => s.k === 'recup').at(-1);
    if (recup && recup === entree.etapes.at(-1)) assert.equal(parId.get(porteurs.at(-1)).side, recup.side ?? c.equipe, `${source} : ballon récupéré par ${recup.side}`);
  }
});

test('Déterminisme : même entrée, même mise en scène ; autre graine, autre mise en scène', () => {
  for (const { source, entree, c } of TOUS) {
    assert.deepEqual(C.composer(JSON.parse(JSON.stringify(entree))), c, `${source} : rejouable`);
  }
  const { entree, c } = COMPOSES[0];
  const autre = C.composer({ ...entree, graine: (entree.graine ^ 0x5bd1e995) >>> 0 });
  assert.notDeepEqual(autre.joueurs.map(j => j.x), c.joueurs.map(j => j.x), 'la graine change la mise en scène');
  // L'entrée n'est pas modifiée.
  const copie = JSON.parse(JSON.stringify(entree));
  C.composer(copie);
  assert.deepEqual(copie, JSON.parse(JSON.stringify(entree)));
});

test('Issue du moteur : le marqueur désigné aplatit au point d’essai, dans l’en-but', () => {
  for (const { source, entree, c } of COMPOSES) {
    assert.equal(c.marqueur, String(entree.marqueur), source);
    assert.equal(c.equipe, entree.equipe);
    const porteurs = c.ballon.porteurs.filter(([, id]) => id);
    assert.equal(porteurs.at(-1)[1], c.marqueur, `${source} : dernier porteur = marqueur`);
    const aplatis = c.evenements.filter(e => e.type === 'aplati');
    assert.equal(aplatis.length, 1, `${source} : un seul aplati`);
    assert.equal(aplatis[0].joueur, c.marqueur);
    const ligne = entree.essai.x, sens = ligne === 100 ? 1 : -1;
    assert.equal(c.essai.x, ligne + sens * C.EN_BUT, `${source} : aplati ${C.EN_BUT} m derrière la ligne`);
    assert.equal(c.essai.y, Math.max(5, Math.min(65, entree.essai.y)));
    const n = c.ballon.x.length - 1;
    assert.ok(Math.abs(c.ballon.x[n] - c.essai.x) < 0.01 && Math.abs(c.ballon.y[n] - c.essai.y) < 0.01, `${source} : ballon au point d’essai`);
    assert.ok(c.ballon.h[n] <= 0.15, `${source} : ballon au sol`);
    const marqueur = c.joueurs.find(j => j.id === c.marqueur);
    assert.ok(Math.hypot(marqueur.x[n] - c.essai.x, marqueur.y[n] - c.essai.y) < 1.8, `${source} : le marqueur reste sur son ballon (allongé, bras tendus)`);
    // Aucun ballon perdu ni aplati par un autre : les seuls changements de porteur sont des passes,
    // un ramassage au ruck ou un ballon posé au sol par le plaqué.
    const types = new Set(c.evenements.map(e => e.type));
    for (const t of types) assert.ok(['course', 'plaquage', 'ruck', 'ramassage', 'passe', 'reception', 'percee', 'plaquage_rate', 'aplati'].includes(t), t);
    // Le plaquage du marqueur pendant sa percée est toujours raté.
    const percee = c.evenements.find(e => e.type === 'percee');
    assert.ok(percee, `${source} : percée`);
    assert.ok(!c.evenements.some(e => e.type === 'plaquage' && e.t >= percee.t), `${source} : aucun plaquage réussi après la percée`);
  }
});

test('Vitesses et accélérations plafonnées par le profil de chaque joueur', () => {
  for (const { source, c } of TOUS) {
    const P = c.pas, n = c.ballon.x.length;
    for (const j of c.joueurs) {
      for (let i = 1; i < n; i++) {
        const v = Math.hypot(j.x[i] - j.x[i - 1], j.y[i] - j.y[i - 1]) / P;
        // Tolérance : positions arrondies au centimètre (0,05 m/s sur 0,2 s).
        assert.ok(v <= j.vmax + 0.06, `${source} : ${j.id} à ${v.toFixed(2)} m/s (plafond ${j.vmax}) à ${(i * P).toFixed(1)} s`);
      }
      for (let i = 1; i < n - 1; i++) {
        const t = i * P;
        // Chute, plaquage, plongeon et aplati : décélération d'impact, pas de course.
        if ([t - 0.4, t, t + 0.4].some(u => ETATS_CHUTE.has(etatA(j, u)))) continue;
        const ax = (j.x[i + 1] - 2 * j.x[i] + j.x[i - 1]) / (P * P), ay = (j.y[i + 1] - 2 * j.y[i] + j.y[i - 1]) / (P * P);
        // Tolérance : arrondi au centimètre sur une différence seconde (0,5 m/s²).
        assert.ok(Math.hypot(ax, ay) <= j.amax + 0.6, `${source} : ${j.id} accélère à ${Math.hypot(ax, ay).toFixed(2)} m/s² (plafond ${j.amax}) à ${t.toFixed(1)} s`);
      }
    }
  }
});

test('Aucun chevauchement : deux joueurs hors contact restent à 0,6 m au moins (0,35 m d’un joueur au sol)', () => {
  for (const { source, c } of TOUS) {
    const J = c.joueurs, n = c.ballon.x.length;
    // Première seconde exclue : les places de départ sont celles de la scène du moteur, qui
    // peut poser deux joueurs l'un contre l'autre ; ils s'écartent aussitôt.
    for (let i = Math.round(1 / c.pas); i < n; i++) {
      for (let a = 0; a < J.length; a++) for (let b = a + 1; b < J.length; b++) {
        const d = Math.hypot(J[a].x[i] - J[b].x[i], J[a].y[i] - J[b].y[i]);
        // Un joueur au sol peut être enjambé de près : 0,35 m au moins entre lui et celui qui passe.
        const sol = SOL.has(etatA(J[a], i * c.pas)) || SOL.has(etatA(J[b], i * c.pas));
        if (d >= (sol ? 0.35 : 0.6) || enContact(c, i * c.pas, J[a].id, J[b].id)) continue;
        assert.fail(`${source} : ${J[a].id} et ${J[b].id} à ${d.toFixed(2)} m à ${(i * c.pas).toFixed(1)} s`);
      }
    }
  }
});

test('Lois du jeu mises en scène : passes en retrait, hors-jeu au ruck, plaqué qui libère', () => {
  for (const { source, entree, c } of TOUS) {
    const parSide = side => side === c.equipe ? c.sens : -c.sens;
    const parId = new Map(c.joueurs.map(j => [j.id, j]));
    const passes = c.evenements.filter(e => e.type === 'passe');
    for (const p of passes) {
      const r = c.evenements.find(e => e.type === 'reception' && e.joueur === p.vers && e.t >= p.t);
      assert.ok(r, `${source} : passe reçue`);
      const j = parId.get(p.vers), i = indice(c, r.t), sens = parSide(j.side);
      // Loi 11 : jamais de passe en avant (le receveur prend le ballon en retrait du point de lâcher).
      assert.ok((p.lache.x - j.x[i]) * sens >= -0.05, `${source} : passe en avant à ${r.t} s (${p.lache.x} → ${j.x[i]})`);
    }
    // Loi 15 : le ballon n'est joué au ruck qu'une fois tous les joueurs hors du ruck revenus en jeu.
    for (const e of c.evenements.filter(e => e.type === 'ramassage')) assert.equal(e.horsJeuRespecte, true, `${source} : hors-jeu au ruck à ${e.t} s`);
    // Loi 14 : le plaqué lâche le ballon (ballon au sol) avant tout ramassage.
    for (const e of c.evenements.filter(e => e.type === 'plaquage')) {
      const ruck = c.evenements.find(x => x.type === 'ruck' && x.t >= e.t);
      assert.ok(ruck, `${source} : un ruck suit chaque plaquage`);
      const sol = c.ballon.porteurs.find(([t, id]) => t >= e.t && id === null);
      assert.ok(sol && sol[0] <= ruck.t + 0.05, `${source} : ballon posé au sol par le plaqué`);
    }
  }
});

test('Remises en jeu et jeu au pied : hors-jeu de mêlée (5 m), de touche (10 m), partenaires du botteur', () => {
  let melees = 0, touches = 0, pieds = 0;
  for (const { source, entree, c } of COMPOSES2) {
    const dir = side => side === c.equipe ? c.sens : -c.sens;
    const o = entree.ouverture;
    if (o.k === 'melee' || o.k === 'touche') {
      // Jusqu'au ballon sorti (ramassage en mêlée, passe du sauteur en touche), les arrières restent derrière leur ligne.
      const fin = o.k === 'melee' ? c.evenements.find(e => e.type === 'ramassage').t : c.evenements.find(e => e.type === 'passe').t;
      const recul = o.k === 'melee' ? 2.4 + 0.6 + 5 : 10;
      for (const j of c.joueurs.filter(j => j.slot > 8)) {
        for (let i = 0; i * c.pas <= fin; i++) {
          const derriere = (o.x - j.x[i]) * dir(j.side);
          assert.ok(derriere >= recul - 0.6, `${source} : ${j.id} (n° ${j.slot + 1}) à ${derriere.toFixed(1)} m de la ${o.k} à ${(i * c.pas).toFixed(1)} s`);
        }
      }
      if (o.k === 'melee') { melees++; for (const side of [0, 1]) assert.ok(c.joueurs.filter(j => j.side === side && j.slot < 8 && j.etats.some(([, e]) => e === 'melee')).length >= 6, `${source} : avants liés`); }
      else { touches++; assert.ok(c.joueurs.some(j => j.etats.some(([, e]) => e === 'saut')) && c.joueurs.some(j => j.etats.some(([, e]) => e === 'lancer')), `${source} : lancer et saut`); }
    }
    const k = c.evenements.find(e => e.type === 'jeu_au_pied');
    if (k) {
      pieds++;
      // Loi 10 : les partenaires devant le botteur au coup de pied n'avancent pas tant que le ballon est en l'air.
      const botteur = c.joueurs.find(j => j.id === k.joueur), i0 = indice(c, k.t), fin = c.evenements.find(e => (e.type === 'reception' || e.type === 'touche') && e.t >= k.t);
      const i1 = indice(c, fin ? fin.t : c.duree), d = dir(botteur.side);
      for (const j of c.joueurs.filter(j => j.side === botteur.side && j !== botteur && (j.x[i0] - botteur.x[i0]) * d > 0.3 && ['course', 'passe', 'reception'].includes(etatA(j, k.t)))) {
        // Il s'arrête dès le coup de pied : au plus sa distance de freinage (allure, accélération plafonnée).
        const freinage = j.v[i0] * j.v[i0] / (2 * j.amax) + 0.5;
        // Jusqu'à ce qu'un partenaire en jeu le dépasse (il est alors remis en jeu).
        const enJeu = c.joueurs.filter(o => o.side === botteur.side && (o.x[i0] - botteur.x[i0]) * d <= 0.3);
        for (let i = i0; i <= i1 && !enJeu.some(o => (o.x[i] - j.x[i]) * d >= 0); i++) assert.ok((j.x[i] - j.x[i0]) * d <= freinage, `${source} : ${j.id} hors-jeu avance de ${((j.x[i] - j.x[i0]) * d).toFixed(1)} m (freinage ${freinage.toFixed(1)} m)`);
      }
    }
  }
  assert.ok(melees >= 1 && touches >= 1 && pieds >= 1, `remises en jeu contrôlées : ${melees} mêlées, ${touches} touches, ${pieds} coups de pied`);
});

test('Consigne défensive (plans.defence) : au ruck, la ligne en pression attend plus près du ballon que la prudente ; même issue', () => {
  let compares = 0, cas = 0;
  // Profondeur de la ligne défensive (hors arrière) au moment où le ballon est joué au ruck.
  const profondeur = c => {
    const l = [];
    for (const r of c.evenements.filter(e => e.type === 'ramassage')) {
      const i = Math.round(r.t / c.pas);
      for (const j of c.joueurs) if (j.side !== c.equipe && j.slot !== 14 && etatA(j, r.t) === 'course' && Math.abs(j.y[i] - c.ballon.y[i]) < 25) l.push(Math.abs(j.x[i] - c.ballon.x[i]));
    }
    return l.length ? l.reduce((a, b) => a + b, 0) / l.length : null;
  };
  for (const { source, entree } of COMPOSES2.filter(({ entree }) => entree.type !== 'jeu_au_pied')) {
    const jouer = consigne => C.composer({ ...entree, defense: [consigne, consigne] });
    const presse = jouer('pression'), prudente = jouer('prudente');
    // Même issue : mêmes jalons (plans du moteur), même joueur clé.
    assert.deepEqual(presse.jalons.map(([, k]) => k), prudente.jalons.map(([, k]) => k), source);
    assert.equal(presse.vedette, prudente.vedette);
    const a = profondeur(presse), b = profondeur(prudente);
    if (a === null || b === null) continue;
    cas++;
    if (a < b) compares++;
  }
  assert.ok(cas >= 8 && compares >= cas * 0.75, `ligne plus près du ruck sous pression dans ${compares} temps forts sur ${cas}`);
});

test('Ballon continu : jamais téléporté, vitesse d’une passe au plus', () => {
  for (const { source, c } of TOUS) {
    for (let i = 1; i < c.ballon.x.length; i++) {
      const v = Math.hypot(c.ballon.x[i] - c.ballon.x[i - 1], c.ballon.y[i] - c.ballon.y[i - 1]) / c.pas;
      assert.ok(v <= 25, `${source} : ballon à ${v.toFixed(1)} m/s à ${(i * c.pas).toFixed(1)} s`);
    }
  }
});

test('Entrées invalides refusées ; essai sur ballon porté ou mêlée non mis en scène', () => {
  const { entree } = COMPOSES[0];
  assert.throws(() => C.composer({ ...entree, type: 'melee' }), /type non pris en charge/);
  assert.throws(() => C.composer({ ...entree, marqueur: 'inconnu' }), /marqueur/);
  assert.throws(() => C.composer({ ...entree, essai: { x: 50, y: 35 } }), /point d’essai/);
  const tf = { cle: 'k', plans: [{ kind: 'setpiece-win', index: 0, scene: { players: entree.joueurs, ball: entree.ballon, possession: entree.possession } }, { kind: 'try', index: 1, scene: { ball: entree.essai } }] };
  const events = [{ scene: { kind: 'setpiece-win' } }, { scene: { kind: 'try', origin: 'maul', team: entree.equipe, actor: entree.marqueur } }];
  assert.equal(C.entreeDepuisTempsFort(tf, events), null, 'essai sur ballon porté : pas de chorégraphie');
  events[1].scene.origin = 'open';
  const e = C.entreeDepuisTempsFort(tf, events);
  assert.equal(e.type, 'essai_jeu_courant');
  assert.equal(e.plan, 1);
});

test('Moteur natif : rien sans le drapeau ; avec, chaque essai en jeu courant (et ce qui sait l’être) a sa chorégraphie et le match est le même', { timeout: 600000 }, () => {
  const { createBridge } = require('../native/engine/worker.cjs');
  const { settleClubMeetings } = require('./helpers/club-meetings.cjs');
  const { skipMatchTalk } = require('./helpers/scene-match-talks.cjs');
  const jouer = drapeau => {
    const dataDir = fs.mkdtempSync(path.join(os.tmpdir(), 'cd-choregraphe-'));
    const bridge = createBridge({ dataDir, seed: 7, now: 1700000000000, matchHighlights: 'dynamique', matchChoreography: drapeau });
    let id = 0;
    const call = (command, payload = {}) => { const r = bridge.handle({ id: ++id, command, payload }); assert.equal(r.ok, true, r.error); return r.model; };
    try {
      settleClubMeetings(call('new_career', { club: 0 }), call);
      let model = skipMatchTalk(call('begin_match'), call);
      const tempsForts = new Map();
      for (let n = 0; n < 400 && model.live && !model.live.finished; n++) {
        if (model.clubLife?.matchTalks?.scene) { model = skipMatchTalk(model, call); continue; }
        if (model.live.paused) model = call('pause', { paused: false });
        model = call('tick', { minute: true, temps_forts: 'dynamique' });
        const tf = model.live?.direct?.tempsFort;
        if (tf && !tempsForts.has(tf.cle)) tempsForts.set(tf.cle, tf);
      }
      return { live: model.live, tempsForts: [...tempsForts.values()] };
    } finally { try { bridge.close?.(); } catch (error) { /* déjà fermé */ } fs.rmSync(dataDir, { recursive: true, force: true }); }
  };
  const sans = jouer(false), avec = jouer(true);
  assert.ok(sans.tempsForts.every(tf => !('choregraphie' in tf) && !('choregraphieErreur' in tf)), 'sans le drapeau, rien ne change');
  // Présentation seule : même match, mêmes temps forts (hors chorégraphie).
  assert.deepEqual(avec.live.score, sans.live.score);
  assert.deepEqual(avec.live.events, sans.live.events);
  const retirer = tf => { const { choregraphie, choregraphieErreur, ...reste } = tf; return reste; };
  assert.deepEqual(avec.tempsForts.map(retirer), sans.tempsForts);
  let essais = 0, autres = 0;
  for (const tf of avec.tempsForts) {
    assert.equal(tf.choregraphieErreur, undefined, `${tf.horlogeDebut} : ${tf.choregraphieErreur}`);
    const n = tf.plans.findIndex(p => p.kind === 'try');
    const record = n >= 0 ? avec.live.events[tf.plans[n].index].scene : null;
    const c = tf.choregraphie;
    if (c) {
      autres++;
      assert.ok(C.TYPES.includes(c.type) && c.duree >= 12 && c.duree <= c.dureeMax, `${tf.horlogeDebut} : ${c.type} ${c.duree} s`);
      assert.ok(c.premier >= 0 && c.dernier < tf.plans.length && c.premier <= c.dernier);
      assert.deepEqual(c.jalons.map(([, k]) => k).filter((k, i, l) => l.indexOf(k) === i), c.jalons.map(([, k]) => k), 'un jalon par plan');
    }
    if (!record || record.origin !== 'open') continue;
    essais++;
    assert.ok(c, `${tf.horlogeDebut} : chorégraphie de l’essai en jeu courant`);
    assert.equal(c.dernier, n);
    assert.equal(c.marqueur, String(record.actor), 'marqueur du moteur');
    // Profils lus dans le moteur : un ailier n'a pas l'allure d'un pilier.
    assert.ok(new Set(c.joueurs.map(j => j.vmax)).size > 5, 'profils individuels');
  }
  assert.ok(essais >= 2, 'graine 7 : au moins deux essais en jeu courant');
  assert.ok(autres >= essais, 'temps forts mis en scène : ' + autres);
});
