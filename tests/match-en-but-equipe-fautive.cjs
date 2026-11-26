'use strict';
// Faits d'en-but (en-avant de l'attaque, porteur tenu, coup de pied aplati par la défense) : le texte nomme toujours
// l'équipe fautive (journal, bandeau des temps forts 3D et écran intermédiaire 2D lisent ce même texte). Matchs joués par le
// vrai moteur (carrière Monde, comme tests/match-temps-forts-pied.cjs), puis projection `live.direct` du pont natif.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { worldYouth } = require('./helpers/youth-world-harness.cjs');
const { ouvrir, creer, jusquAuMatch } = require('./helpers/carriere-monde.cjs');
const { skipMatchTalk } = require('./helpers/scene-match-talks.cjs');
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

test('Chaque fait d’en-but nomme l’équipe fautive (vrais matchs du moteur)', { timeout: 1800000 }, () => {
  const vus = { 'held-up': 0, 'ingoal-knock-on': 0, 'attacking-kick-grounded': 0 };
  const manques = [];
  for (const m of simuler(NOMBRE)) {
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

test('Le bandeau des temps forts (projection du pont) nomme l’équipe fautive', { timeout: 170000 }, () => {
  // Match de la carrière du film (scripts/match-filme.ps1 : club 102, cadence hebdomadaire), graine 4247, joué par le vrai
  // moteur : la simulation s'arrête dès que deux plans d'en-but (porteur tenu, coup de pied aplati…) sont projetés dans les
  // temps forts « dynamique » (aux minutes 11 et 20 de cette graine), pour rester sous la limite de 180 s des suites en CI.
  const vus = [], manques = [];
  const jeu = ouvrir({ seed: 4247, hebdomadaire: true });
  try {
    let model = jusquAuMatch(jeu, creer(jeu, 102));
    if (!model.selection.valid) model = jeu.call('auto_lineup');
    if (!model.selection.valid) model = jeu.call('promote_cover', { confirmed: true });
    model = skipMatchTalk(jeu.call('begin_match'), jeu.call);
    const lire = live => {
      for (const p of live.direct?.tempsFort?.plans || []) {
        const fait = live.events[p.index]?.scene;
        if (fait?.kind !== 'ingoal' || !CAUSES.includes(fait.cause) || vus.includes(p.index)) continue;
        vus.push(p.index);
        const abbr = String(live.teams[fait.team]?.abbr || '');
        // Le bandeau dit l'équipe : le sigle de son club figure dans la légende du plan.
        if (!abbr || !p.texte.includes(abbr)) manques.push(`${fait.cause} équipe ${fait.team} (${abbr}) : ${p.texte}`);
      }
    };
    for (let ticks = 0; ticks < 200 && !model.live.finished && vus.length < 2; ticks++) {
      model = skipMatchTalk(model, jeu.call);
      if (model.live.paused) model = jeu.call('pause', { paused: false });
      model = jeu.call('tick', { minute: true, temps_forts: 'dynamique' });
      lire(model.live);
    }
  } finally { jeu.fermer(); }
  assert.ok(vus.length >= 2, `assez de plans d’en-but projetés (${vus.length})`);
  assert.deepEqual(manques, [], `${manques.length} légendes d’en-but sans nom d’équipe sur ${vus.length}`);
});
