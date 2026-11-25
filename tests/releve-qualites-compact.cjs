'use strict';
// Relevé hebdomadaire ancré (native/engine/releve-qualites.cjs, 25/11/2026) : sauvegardes allégées SANS PERTE.
// La base absolue du relevé hebdomadaire (p.rh) est remplacée par l'index du point qui vaut les dernières valeurs du
// relevé mensuel (p.rq). Non-régression : mêmes textes d'origine au caractère près, mêmes flèches, même courbe, même
// suite de carrière ; anciennes sauvegardes (écrites par main avant l'ancrage) relues et converties. Carrière Monde.
const test = require('node:test'), assert = require('node:assert/strict');
const fs = require('node:fs'), path = require('node:path');
const { context } = require('./monde-harness.cjs');
const domaine = require('../native/engine/releve-qualites.cjs');

// Relevés écrits par le code de main (e20a9c469, avant l'ancrage) : carrière Monde (graine 7, fin de saison 1) et cas
// fabriqués (semaines et mois manqués, base repliée non relevée), avec les flèches et la suite calculées par main.
const fixture = JSON.parse(fs.readFileSync(path.join(__dirname, 'fixtures', 'releve-qualites-main.json'), 'utf8'));

test('relevés écrits par main : ancrés sans perte, mêmes flèches, même courbe, même suite au caractère près', () => {
  const R = domaine.factory(), T = R._tests;
  let ancres = 0;
  for (const j of fixture.joueurs) {
    const p = structuredClone(j); delete p.attendu;
    assert.equal(R.texteHebdo(p), j.rh, 'format d’origine lu tel quel : ' + j.id);
    assert.deepEqual(R.fleches(p), j.attendu.fleches, 'flèches de l’ancien format : ' + j.id);
    if (T.ancrer(p)) ancres++;
    assert.equal(p.rq, j.rq, 'relevé mensuel (courbe) jamais modifié : ' + j.id);
    assert.ok(p.rh.length <= j.rh.length, 'jamais plus long : ' + j.id);
    assert.equal(R.texteHebdo(p), j.rh, 'texte d’origine redonné au caractère près : ' + j.id);
    assert.deepEqual(R.fleches(p), j.attendu.fleches, 'mêmes flèches une fois ancré : ' + j.id);
    assert.deepEqual(R.lire(p.rq), R.lire(j.rq), 'même courbe : ' + j.id);
    // Une semaine et un mois de plus : mêmes textes que main.
    const s = j.attendu.suite;
    p.attributesV2 = { ...s.attributesV2 };
    T.relever(p, s.mois); T.relever(p, s.lundi, T.SEMAINE);
    assert.equal(p.rq, s.rq, 'relevé mensuel suivant identique à main : ' + j.id);
    assert.equal(R.texteHebdo(p), s.rh, 'relevé hebdomadaire suivant identique à main : ' + j.id);
    assert.deepEqual(R.fleches(p), s.fleches, 'flèches suivantes identiques à main : ' + j.id);
  }
  assert.ok(ancres >= fixture.joueurs.length - 4, 'presque tous les relevés ancrés : ' + ancres + ' / ' + fixture.joueurs.length);
});

test('ancre fausse ou illisible : refusée par la validation, jamais une valeur inventée', () => {
  const R = domaine.factory(), T = R._tests;
  const p = structuredClone(fixture.joueurs[0]); delete p.attendu;
  assert.ok(T.ancrer(p) && T.FORME_A.test(p.rh));
  assert.equal(R.texteHebdo({ ...p, rq: undefined }), null, 'sans relevé mensuel : illisible');
  assert.equal(R.texteHebdo({ ...p, rh: p.rh.replace(/@\d/, '@9') }), null, 'index hors de la chaîne : illisible');
  const s = { releveQualites: { m: '2027-06', s: '2027-06-28', f: 2 }, clubs: [{ players: [{ ...p, rq: undefined }] }] };
  assert.throws(() => R.validate(s), /Relevé hebdomadaire/);
  s.clubs[0].players[0] = p;
  assert.equal(R.validate(s), true);
});

// Carrière Monde jouée : flèches, courbe et modèle de l'interface identiques avec le relevé ancré et le relevé d'origine.
const h = context(827381, { club: 102, console: false });
const run = src => h.run(src);
const json = src => JSON.parse(run('JSON.stringify(' + src + ')'));
test.after(() => h.close());
// Joueurs relevés (clubs, agents libres, centre, marché) ; les copies du marché (objets distincts après un import)
// sont lues à part dans LECTURES_MARCHE.
const JOUEURS = `(()=>{const v=new Set(),o=[];for(const p of [...S.clubs.flatMap(c=>c.players),...S.economy.freeAgents,...(S.development?.academy||[]),...(Array.isArray(S.market)?S.market:[])])if(p&&!v.has(p.id)){v.add(p.id);o.push(p);}return o;})()`;
const TOUS = `(()=>{const v=new Set(),o=[];for(const p of [...S.clubs.flatMap(c=>c.players),...S.economy.freeAgents,...(S.development?.academy||[]),...(Array.isArray(S.market)?S.market:[])])if(p&&!v.has(p)){v.add(p);o.push(p);}return o;})()`;
const LECTURES_MARCHE = `(Array.isArray(S.market)?S.market:[]).map(p=>({id:p.id,fleches:CDReleveQualites.fleches(p),texte:CDReleveQualites.texteHebdo(p)??null}))`;
const LECTURES = `${JOUEURS}.map(p=>({id:p.id,fleches:CDReleveQualites.fleches(p),courbe:typeof p.rq==='string'?CDReleveQualites.lire(p.rq):null,texte:CDReleveQualites.texteHebdo(p)??null}))`;
// Relevés remis au format de main (base absolue, sans marque f) : ce qu'écrivait une sauvegarde d'avant l'ancrage.
const DEPLIER = `{for(const p of ${TOUS})if(typeof p.rh==='string')p.rh=CDReleveQualites.texteHebdo(p);delete S.releveQualites.f;}`;
const ecran = m => ({ squad: (m.squad || []).map(p => ({ id: p.id, releve: p.releve, fleches: p.fleches })) });

test('carrière jouée : relevés ancrés, mêmes lectures et même modèle qu’au format d’origine, même suite', () => {
  h.week(6);
  run('delete S.clubMeetings');
  const etat = json(`{f:S.releveQualites.f,n:${TOUS}.filter(p=>typeof p.rh==='string').length,ancres:${TOUS}.filter(p=>typeof p.rh==='string'&&p.rh.includes('@')).length}`);
  assert.equal(etat.f, 2, 'carrière au nouveau format');
  assert.ok(etat.ancres >= etat.n * .95, 'relevés hebdomadaires ancrés : ' + etat.ancres + ' / ' + etat.n);
  const lectures = json(LECTURES), modele = ecran(h.command('snapshot'));
  assert.ok(lectures.filter(l => l.fleches && Object.keys(l.fleches.q).length).length > 100, 'flèches présentes');
  const depart = h.checkpoint();
  // Même carrière au format d'origine : mêmes lectures, même modèle ; une semaine plus tard, état identique au caractère
  // près à la carrière restée ancrée (relevés compris, réancrés à la conversion).
  run(DEPLIER);
  assert.equal(json(`${TOUS}.filter(p=>typeof p.rh==='string'&&p.rh.includes('@')).length`), 0);
  assert.deepEqual(json(LECTURES), lectures, 'flèches et courbe identiques au format d’origine');
  assert.deepEqual(ecran(h.command('snapshot')), modele, 'modèle de l’interface identique');
  run('nativeSystems.domain("releveQualites").convertir(S)');
  const converti = run('JSON.stringify(S)');
  h.restore(depart);
  assert.equal(converti, run('JSON.stringify(S)'), 'conversion = état ancré au caractère près');
  h.week(1);
  const suiteAncree = run('JSON.stringify(S)');
  h.restore(depart); run(DEPLIER); h.week(1);
  assert.equal(run('JSON.stringify(S)'), suiteAncree, 'semaine suivante : même carrière au caractère près');
  run('validateCareer(S)');
});

test('ancienne sauvegarde (format d’origine) : rechargée, convertie, mêmes flèches et même courbe, plus légère', () => {
  run('delete S.clubMeetings');
  const lectures = json(LECTURES), marche = json(LECTURES_MARCHE), modele = ecran(h.command('snapshot'));
  const actuel = run('JSON.stringify(createSaveDocument())');
  run(DEPLIER);
  assert.equal(json(`${TOUS}.filter(p=>typeof p.rh==='string'&&p.rh.includes('@')).length`), 0, 'carrière au format d’origine');
  const ancien = run('JSON.stringify(createSaveDocument())');
  assert.ok(ancien.length - actuel.length > 50 * json(`${TOUS}.filter(p=>typeof p.rh==='string').length`), 'gain par joueur : ' + (ancien.length - actuel.length));
  h.command('import', { text: ancien });
  run('delete S.clubMeetings');
  assert.equal(run('S.releveQualites.f'), 2, 'convertie à l’import');
  assert.ok(json(`${TOUS}.filter(p=>typeof p.rh==='string'&&p.rh.includes('@')).length`) > 1000, 'relevés ancrés');
  assert.deepEqual(json(LECTURES), lectures, 'mêmes flèches et même courbe');
  assert.deepEqual(json(LECTURES_MARCHE), marche, 'marché : mêmes flèches que le vivier');
  assert.deepEqual(ecran(h.command('snapshot')), modele, 'modèle de l’interface identique');
  // Export suivant : relevés identiques à ceux de la carrière jamais dépliée (l'import pose par ailleurs ses propres
  // valeurs de départ, la fragilité des joueurs arrivés par exemple).
  const releves = texte => { const s = JSON.parse(texte).state; return { marque: s.releveQualites, joueurs: [...s.clubs.flatMap(c => c.players), ...s.economy.freeAgents, ...(s.development?.academy || [])].map(p => [p.id, p.rq ?? null, p.rh ?? null]) }; };
  assert.deepEqual(releves(run('JSON.stringify(createSaveDocument())')), releves(actuel), 'mêmes relevés exportés que sans le passage par l’ancien format');
});
