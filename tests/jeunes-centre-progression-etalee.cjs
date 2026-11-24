'use strict';
// Jeunes du centre : progression étalée (choix de Léo du 23/11/2026, même mécanisme que l'idée FM27 n° 14,
// native/engine/in-season-development.cjs). Un point de niveau d'un jeune ne monte plus d'un coup ses 11 compétences
// et ses 36 qualités : le niveau monte tout de suite, le reste arrive semaine après semaine (0,1 point au moins),
// une qualité à la fois, sans rien perdre ni compter deux fois. Carrière Monde (world-champ), déterministe.
const test = require('node:test'), assert = require('node:assert/strict');
const { context } = require('./monde-harness.cjs');

const h = context(827381, { club: 102, console: false });
const run = src => h.run(src);
const json = src => JSON.parse(run('JSON.stringify(' + src + ')'));
test.after(() => h.close());

// Outils de la VM : qualités d'un joueur, compétences effectives, une semaine d'entraînement telle que la vit le moteur
// (relevé d'avant commande, part de la semaine, suivi des qualités).
run(`var qual=p=>nativeAttributeStore.project(p).attributesV2,moy36=p=>Object.values(qual(p)).reduce((a,b)=>a+b,0)/36,
 effectives=p=>Object.fromEntries(Object.keys(ATTR).map(k=>[k,skill(p,k)])),
 semaineJeune=()=>{const base=nativeAttributeStore.before(S,false);nativeInSeasonDevelopment.hebdo();nativeAttributeStore.complete(S,base,false);},
 commande=f=>{const base=nativeAttributeStore.before(S,false);f();nativeAttributeStore.complete(S,base,false);},
 choisir=liste=>liste.find(p=>p.academy&&!p.dev.etale&&p.dev.potential>=p.rating+3&&Object.values(qual(p)).every(v=>v<=95)&&Object.values(p.skills).every(v=>v<=97));`);

test('centre du club : le niveau monte tout de suite, compétences et qualités semaine après semaine', () => {
  run(`var j=choisir(S.development.academy);if(!j)throw Error('jeune introuvable');
   var q0=qual(j),e0=effectives(j),n0=j.rating,note0=roleNote(j);j.dev.xp=0;commande(()=>growPlayer(j,1.2,false));`);
  assert.equal(run('j.rating'), run('n0+1'), 'niveau : +1 tout de suite');
  assert.deepEqual(json('qual(j)'), json('q0'), 'aucune qualité ne bouge encore');
  assert.deepEqual(json('effectives(j)'), json('e0'), 'compétences de match inchangées');
  assert.equal(run('roleNote(j)'), run('note0'));
  assert.equal(run('j.dev.etale.n'), 1, 'un point en attente');
  run('validateCareer(S)');
  const sauts = [];
  for (let k = 0; k < 12 && run('!!j.dev.etale'); k++) {
    const avant = run('moy36(j)'); run('semaineJeune()'); sauts.push(run('moy36(j)') - avant);
  }
  assert.equal(run('j.dev.etale'), undefined, 'réservoir vidé, état effacé');
  assert.ok(sauts.length >= 9 && sauts.length <= 10, 'un point en 10 semaines au plus : ' + sauts.length);
  assert.ok(Math.max(...sauts) <= .12, 'plus gros saut hebdomadaire des qualités : ' + Math.max(...sauts).toFixed(3));
  const fin = json('(()=>{const q=qual(j),e=effectives(j);return {q:Object.keys(q).map(k=>q[k]-q0[k]),e:Object.keys(e).map(k=>Math.round((e[k]-e0[k])*100)/100)};})()');
  assert.ok(fin.q.every(d => d === 1), 'chaque qualité +1, une seule fois : ' + fin.q.join(','));
  assert.ok(fin.e.every(d => d === 1), 'chaque compétence +1 : ' + fin.e.join(','));
  run('validateCareer(S)');
});

test('centre d\'un club géré : le gain de l\'accueil est étalé de la même façon', () => {
  run(`var g=choisir(S.aiRoster.academies.flatMap(a=>a.players));if(!g)throw Error('jeune géré introuvable');
   var gq0=qual(g),gn0=g.rating;g.dev.xp=0;commande(()=>growPlayer(g,1.2,false));`);
  assert.equal(run('g.rating'), run('gn0+1'));
  assert.deepEqual(json('qual(g)'), json('gq0'));
  run('semaineJeune()');
  assert.ok(run('moy36(g)-Object.values(gq0).reduce((a,b)=>a+b,0)/36') > 0, 'première part versée');
  run('validateCareer(S)');
  run('commande(()=>nativeInSeasonDevelopment.liberer(g))');
  assert.ok(json('(()=>{const q=qual(g);return Object.keys(q).every(k=>q[k]===gq0[k]+1);})()'), 'tout versé : chaque qualité +1');
});

test('intersaison et ancienne sauvegarde : le reste est versé d\'un coup, rien n\'est perdu', () => {
  run(`var v=choisir(S.development.academy);var vq0=qual(v);v.dev.xp=0;commande(()=>growPlayer(v,1.2,false));semaineJeune();semaineJeune();
   commande(()=>ageDevelopmentPlayer(v,S.season));`);
  assert.equal(run('v.dev.etale'), undefined);
  assert.ok(json('(()=>{const q=qual(v);return Object.keys(q).every(k=>q[k]===vq0[k]+1);})()'), 'reste versé à la transition');
  // Ancienne sauvegarde : aucun jeune n'a d'état ; une partie relue telle quelle reste valide.
  run('for(const p of S.development.academy)delete p.dev.etale;validateCareer(S);');
  // État d'une saison close sans transition : versé à la semaine suivante.
  run(`var w=choisir(S.development.academy);var wq0=qual(w);w.dev.xp=0;commande(()=>growPlayer(w,1.2,false));w.dev.etale.s=S.season+1;semaineJeune();`);
  assert.equal(run('w.dev.etale'), undefined);
  assert.ok(json('(()=>{const q=qual(w);return Object.keys(q).every(k=>q[k]===wq0[k]+1);})()'), 'reste d\'une saison close versé');
});

test('semaines réelles du moteur : les qualités d\'un jeune ne sautent plus d\'un point', () => {
  run(`var r=choisir(S.development.academy);var rq0=moy36(r);r.dev.xp=0;commande(()=>growPlayer(r,1.2,false));`);
  const series = [];
  for (let k = 0; k < 3; k++) { h.week(1, { validate: false }); series.push(run('moy36(r)-rq0')); }
  // Séances et matchs de la semaine peuvent ajouter un point : au plus une part de chaque réservoir par semaine.
  for (let k = 0; k < series.length; k++) assert.ok(series[k] - (series[k - 1] || 0) <= .25, 'semaine ' + k + ' : ' + series.map(x => x.toFixed(2)).join(' '));
  assert.ok(series.at(-1) > 0, 'progression versée');
  run('delete S.clubMeetings;validateCareer(S)');
});
