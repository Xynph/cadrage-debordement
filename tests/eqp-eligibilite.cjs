'use strict';
// Éligibilité anglaise (EQP) des effectifs de Premiership, carrière Monde (native/engine/eqp_eligibilite.json,
// native/engine/player-facts.cjs) : ~70 % d'EQP comme en vrai, club par club près de sa cible, tirages déterministes
// (naissance, ascendance, 60 mois de résidence, joueur déjà sélectionné ailleurs), joueurs documentés inchangés.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { context } = require('./monde-harness.cjs');

const regles = JSON.parse(fs.readFileSync(path.join(__dirname, '../native/engine/eqp_eligibilite.json'), 'utf8'));

test('Premiership : ~70 % d’EQP, chaque club près de sa cible', () => {
  const h = context(4242, { club: 102, console: false });
  try {
    const r = JSON.parse(h.run(`(()=>{const J=nativeSystems.domain('jiff'),out={clubs:{},etrangers:0,residence:0,ascendance:0,profils:[]};
      for(const id of S.worldMode.leagues.prem.members){const ps=S.clubs[id].players;out.clubs[id]={n:ps.length,eqp:ps.filter(p=>J.isEqp(p)).length};
       for(const p of ps){const f=nativeFacts.angleterreProfil(p.id);if(!f)continue;out.profils.push([p.id,f.naissance,f.eqp]);
        if(f.naissance!=='ENG'){out.etrangers++;if(f.eqp&&f.annees*12>=60)out.residence++;if(f.eqp&&f.ascendance)out.ascendance++;
         if(nativeFacts.eligible(p.id,'ENG')!==f.eqp||!nativeFacts.eligible(p.id,f.naissance)||nativeFacts.origin(p.id)!==f.naissance)throw Error('incohérent '+p.id);}}}
      return JSON.stringify(out)})()`));
    let n = 0, eqp = 0;
    for (const [id, c] of Object.entries(r.clubs)) {
      n += c.n; eqp += c.eqp;
      const cible = regles.cibles[id];
      assert.equal(typeof cible, 'number', 'cible du club ' + id);
      assert.ok(Math.abs(c.eqp / c.n - cible) <= 0.08, `club ${id} : ${(100 * c.eqp / c.n).toFixed(0)} % pour ${cible * 100} %`);
    }
    assert.ok(eqp / n >= 0.66 && eqp / n <= 0.75, `Premiership : ${(100 * eqp / n).toFixed(1)} % d’EQP`);
    // Les trois voies existent : nés ailleurs devenus EQP par la résidence et par l'ascendance.
    // Depuis le 19/11/2026, 293 joueurs ont un statut établi (recherche) : il reste ~340 tirages, d'où ~80 nés ailleurs.
    assert.ok(r.etrangers > 50 && r.residence > 10 && r.ascendance > 3, JSON.stringify({ e: r.etrangers, res: r.residence, asc: r.ascendance }));
    // Déterministe : mêmes profils dans une seconde carrière.
    const h2 = context(99, { club: 102, console: false });
    try {
      const echantillon = r.profils.slice(0, 200);
      const again = JSON.parse(h2.run(`JSON.stringify(${JSON.stringify(echantillon.map(x => x[0]))}.map(id=>{const f=nativeFacts.angleterreProfil(id);return [id,f.naissance,f.eqp]}))`));
      assert.deepEqual(again, echantillon);
    } finally { h2.close(); }
  } finally { h.close(); }
});
