'use strict';
// Jeu au pied réaliste (docs/jeu-au-pied-20261125.md) : matchs de Top 14 joués par le vrai moteur (carrière world-champ,
// harnais du monde, graine fixe), journal lu fait par fait.
// - les équipes tapent (au moins 12 coups de pied de jeu par match), surtout en touche (6 et plus), et le porteur
//   « poussé en touche » devient rare (3 par match au plus, moins que les touches au pied), la touche directe sans gain
//   de terrain aussi (0,5 par match au plus) ;
// - les renvois aux 22 mètres ne sont plus exceptionnels ; quelques 50:22 sur l'échantillon ;
// - les lois : touche directe hors de ses 22 = lancer adverse à l'endroit du coup de pied, 50:22 seulement depuis son
//   camp vers les 22 adverses, botteur nommé sur les touches au pied (match 2D/3D, fiche de stats).
const assert = require('node:assert/strict');
const { test } = require('node:test');
const { worldYouth } = require('./helpers/youth-world-harness.cjs');

// 240 matchs (48 avant le 26/11) : à ~0,02-0,03 50:22 par match, 48 matchs donnaient zéro une fois sur trois selon la graine
// et le moindre tirage de plus du moteur (lois manquantes) ; mêmes bornes, échantillon plus grand.
const N = 240, COMP = 'elite';

function jouer(n) {
  const matchs = [];
  for (let monde = 0; matchs.length < n; monde++) {
    const t = worldYouth({ seed: 51117 + monde * 101, club: (monde % 2) * 7 }); // clubs 0 et 7 en alternance (tous ne sont pas jouables)
    const total = Number(t.run(`S.worldMode.fixtures.filter(f=>f.competitionId==='${COMP}'&&f.phase==='league').length`));
    for (let i = 0; i < 24 && matchs.length < n; i++) {
      matchs.push(JSON.parse(t.run(`(()=>{const f=S.worldMode.fixtures.filter(f=>f.competitionId==='${COMP}'&&f.phase==='league')[(${i}*7+${monde}*13)%${total}];
        S.round=f.week;const pair=[f.homeId,f.awayId];for(const id of pair)CDFranceCareer.ensureAISheet(S.clubs[id]);S.club=pair[0];
        const l=createRugbyMatch(pair,null,false);for(let n=0;!l.finished;n++){if(n>4000)throw Error('boucle');l.paused=false;advanceRugby(l)}
        return JSON.stringify({kicks:l.tacticalStats[0].kicks+l.tacticalStats[1].kicks,events:l.events.map(e=>({text:e.text,s:e.scene?{kind:e.scene.kind,team:e.scene.team,cause:e.scene.cause,actor:e.scene.actor??null,receiver:e.scene.receiver??null,from:e.scene.from?.x??null,to:e.scene.to?.x??null}:{}}))})})()`)));
    }
  }
  return matchs;
}

test('Jeu au pied : dégagements, occupation, renvois aux 22 m et lois de la touche', () => {
  const matchs = jouer(N);
  const c = {}, add = (k, v = 1) => { c[k] = (c[k] || 0) + v; };
  const fautes = [];
  for (const m of matchs) {
    add('kicks', m.kicks);
    m.events.forEach((e, i) => {
      const s = e.s;
      if (s.kind === 'touch') add('touch:' + s.cause);
      if (s.kind === 'drop22') add('drop22');
      if (s.kind === 'goalLine') add('goalLine');
      if (s.kind === 'kick' && /chandelle|par-dessus|rasant/.test(e.text)) add('contestes');
      if (s.kind === 'touch' && s.cause === 'direct-touch' && /sans gain/.test(e.text)) add('sansGain');
      // Le joueur qui prend le ballon est nommé dans le fait : le match 2D/3D le place au point de chute (pas de ballon seul au sol).
      if (s.kind === 'kick' && s.receiver == null) fautes.push('coup de pied sans joueur au point de chute : ' + e.text);
      if (s.kind === 'touch' && ['direct-touch', 'indirect-touch', '50-22'].includes(s.cause)) {
        if (s.actor == null) fautes.push('touche au pied sans botteur : ' + e.text);
        const own22 = s.team === 0 ? s.from <= 22 : s.from >= 78;
        // Lancer accordé juste après la sortie (un avantage en cours ou la fin de période peuvent l'empêcher).
        const lancer = m.events[i + 1]?.s.kind === 'lineout' ? m.events[i + 1] : null;
        // Touche directe hors de ses 22 : lancer adverse à hauteur du coup de pied (loi 18).
        if (s.cause === 'direct-touch' && !own22 && lancer && Math.abs(lancer.s.from - Math.min(95, Math.max(5, s.from))) > 1)
          fautes.push(`touche directe hors des 22 avec gain : ${e.text} (${s.from} → lancer ${lancer.s.from})`);
        if (s.cause === '50-22') {
          const ownHalf = s.team === 0 ? s.from < 50 : s.from > 50, opp22 = s.team === 0 ? s.to >= 78 : s.to <= 22;
          if (!ownHalf || !opp22) fautes.push('50:22 irrégulier : ' + e.text);
          if (lancer && lancer.s.team !== s.team) fautes.push('50:22 sans le lancer : ' + e.text);
        }
      }
    });
  }
  const par = k => (c[k] || 0) / N;
  const auPied = par('touch:direct-touch') + par('touch:indirect-touch') + par('touch:50-22');
  const r = { coupsDePied: par('kicks'), touchesAuPied: auPied, pousse: par('touch:carry-touch'), contestes: par('contestes'), renvois22: par('drop22'), renvoisEnBut: par('goalLine'), cinquante22: c['touch:50-22'] || 0, sansGain: par('sansGain') };
  const msg = JSON.stringify(r);
  assert.deepEqual(fautes.slice(0, 5), [], 'lois du jeu au pied');
  assert.ok(r.coupsDePied >= 12 && r.coupsDePied <= 30, 'coups de pied de jeu par match ' + msg);
  assert.ok(r.touchesAuPied >= 6 && r.touchesAuPied <= 16, 'touches au pied par match ' + msg);
  assert.ok(r.pousse <= 3 && r.pousse < r.touchesAuPied, 'porteur poussé en touche rare ' + msg);
  assert.ok(r.contestes >= 1.5, 'chandelles, rasants et coups de pied par-dessus ' + msg);
  assert.ok(r.renvois22 + r.renvoisEnBut >= 1.8, 'renvois aux 22 mètres et sur la ligne d’essai ' + msg);
  assert.ok(r.cinquante22 >= 1 && r.cinquante22 / N <= 0.6, '50:22 rares mais présents ' + msg);
  // Touche directe sans gain de terrain : rare au haut niveau (0,3-0,5 par match), pas une forme courante de perte de balle.
  assert.ok(r.sansGain <= 0.5, 'touche directe sans gain rare ' + msg);
});
