'use strict';
// Faits d'en-but (en-avant de l'attaque, porteur tenu, coup de pied aplati par la défense) : le texte nomme toujours
// l'équipe fautive (journal, bandeau des temps forts 3D et écran intermédiaire 2D lisent ce même texte). Matchs joués par le
// vrai moteur (carrière Monde, comme tests/match-temps-forts-pied.cjs), puis plans des temps forts choisis par la sélection
// du direct (match-highlights.cjs `en_direct`). La projection complète par le pont natif (plans et déroulé 2D) est vérifiée,
// avec la légende du bandeau 3D, par tests/godot-match-en-but-libelles.cjs (préparation de carrière trop lente pour ce fichier).
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { worldYouth } = require('./helpers/youth-world-harness.cjs');
const selection = require('../native/engine/match-highlights.cjs');

const NOMBRE = Number(process.env.CD_EN_BUT_MATCHS) || 60;
const CAUSES = ['held-up', 'ingoal-knock-on', 'attacking-kick-grounded'];

function simuler(nombre) {
  const matchs = [];
  for (let monde = 0; matchs.length < nombre; monde++) {
    const t = worldYouth({ seed: 827381 + monde * 101, club: monde * 7 });
    const total = Number(t.run('CDWorldCareer.fixtures(S).length'));
    for (let i = 0; i < 42 && matchs.length < nombre; i++) {
      matchs.push(JSON.parse(t.run(`(()=>{const f=CDWorldCareer.fixtures(S)[${i % total}];const pair=[f.homeId,f.awayId];for(const id of pair)CDFranceCareer.ensureAISheet(S.clubs[id]);
      S.club=pair[0];const l=createRugbyMatch(pair,null,false);for(let n=0;!l.finished;n++){if(n>4000)throw Error('boucle');l.paused=false;advanceRugby(l)}
      return JSON.stringify({events:l.events,abbr:pair.map(ci=>S.clubs[ci].abbr)});})()`)));
    }
  }
  return matchs;
}

let matchs = null;
const jouer = () => matchs || (matchs = simuler(NOMBRE));

test('Chaque fait d’en-but nomme l’équipe fautive (vrais matchs du moteur)', { timeout: 1800000 }, () => {
  const vus = { 'held-up': 0, 'ingoal-knock-on': 0, 'attacking-kick-grounded': 0 };
  const manques = [];
  for (const m of jouer()) {
    for (const e of m.events) {
      const s = e.scene;
      if (!s || s.kind !== 'ingoal' || !CAUSES.includes(s.cause)) continue;
      vus[s.cause]++;
      const abbr = m.abbr[s.team];
      if (!e.text.includes(abbr)) manques.push(`${s.cause} (${abbr}) : ${e.text}`);
      // Le texte reste lisible par la sélection des temps forts (détection de la cause).
      assert.equal(selection.normaliser([e])[0].cause, s.cause, e.text);
    }
  }
  for (const c of CAUSES) assert.ok(vus[c] >= 3, `${c} : assez de cas observés (${JSON.stringify(vus)})`);
  assert.deepEqual(manques.slice(0, 5), [], `${manques.length} faits d’en-but sans nom d’équipe`);
});

test('Les plans d’en-but des temps forts nomment l’équipe fautive (sélection du direct sur de vrais matchs)', { timeout: 170000 }, () => {
  // Plans réellement retenus par la sélection en niveau « dynamique » (le bandeau 3D en reprend le texte du fait).
  const manques = [];
  let plans = 0;
  for (const m of jouer()) {
    const bilan = selection.en_direct(m.events, { niveau: 'dynamique' });
    for (const h of bilan.tempsForts) for (const p of h.plans) {
      const s = m.events[p.i]?.scene;
      if (s?.kind !== 'ingoal' || !CAUSES.includes(s.cause)) continue;
      plans++;
      if (!m.events[p.i].text.includes(m.abbr[s.team])) manques.push(`${s.cause} (${m.abbr[s.team]}) : ${m.events[p.i].text}`);
    }
  }
  assert.ok(plans >= 5, `assez de plans d’en-but retenus (${plans})`);
  assert.deepEqual(manques.slice(0, 5), [], `${manques.length} plans d’en-but sans nom d’équipe sur ${plans}`);
});
