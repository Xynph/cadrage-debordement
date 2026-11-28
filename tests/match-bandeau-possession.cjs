'use strict';
// Bandeau « X a le ballon » contre l'image, sur de vrais matchs du moteur (carrière Monde, IA contre IA).
// La ligne d'état (3D : etat_du_plan ; 2D : etat_du_deroule) nomme l'équipe de scene.possession ; l'image montre
// le porteur : coup de pied de jeu = le receveur nommé, placé au point de chute avec le ballon en main
// (match_presentation.carrier_id, match2d.js) ; porteur, réception, récupération, pénalité jouée vite = l'acteur.
// Signalé par Léo (« le bandeau donne le ballon à la mauvaise équipe ») ; vu en film le 26/11 : « Alder Fen XV
// a le ballon » pendant 2,4 s alors que Meadowbridge capte le dégagement (« dégage dans le champ ; X capte pour Y »,
// le fait était écrit avant le changement de possession : dist/restarts.js, jeuAuPiedPerdu « relance »).
const assert = require('node:assert/strict');
const { worldYouth } = require('./helpers/youth-world-harness.cjs');

// Mondes et rencontres où le moteur joue ce dégagement capté (sonde du 27/11 : 7 cas sur 60 matchs).
const MONDES = [10, 12];
// 30 rencontres par monde (au lieu de 9, mêmes mondes, mêmes contrôles) : avec les remplaçants (K3), les tirages changent et
// 9 rencontres ne couvraient plus que 2 dégagements captés pour 3 exigés (sonde du 28/11 : 13 sur 80 rencontres).
const PAR_MONDE = 30;
let faits = 0, degages = 0;
const faux = [];
for (const monde of MONDES) {
  const t = worldYouth({ seed: 827381 + monde * 101, club: monde * 7 });
  const total = Number(t.run('CDWorldCareer.fixtures(S).length'));
  for (let i = 0; i < PAR_MONDE; i++) {
    const r = JSON.parse(t.run(`(()=>{const f=CDWorldCareer.fixtures(S)[${(i * 7) % total}];const pair=[f.homeId,f.awayId];for(const id of pair)CDFranceCareer.ensureAISheet(S.clubs[id]);
      S.club=pair[0];const l=createRugbyMatch(pair,null,false);for(let n=0;!l.finished;n++){if(n>4000)throw Error('boucle');l.paused=false;advanceRugby(l)}
      return JSON.stringify(l.events.map(e=>{const s=e.scene;if(!s)return null;const cote=id=>id==null?-1:(s.on||[]).findIndex(on=>on.includes(id));
        return {min:e.min,text:e.text,kind:s.kind,possession:s.possession,receveur:cote(s.receiver),acteur:cote(s.actor)}}).filter(Boolean));})()`));
    for (const e of r) {
      const image = e.kind === 'kick' ? e.receveur : ['carry', 'reception', 'turnover', 'quick-tap'].includes(e.kind) ? e.acteur : -1;
      if (image < 0) continue;
      faits++;
      if (/dégage dans le champ ; .* capte pour/.test(e.text)) degages++;
      if (image !== e.possession) faux.push(`monde ${monde} match ${i} ${e.min}′ ${e.kind} : bandeau ${e.possession}, image ${image} — ${e.text}`);
    }
  }
  t.close();
}
assert.ok(faits > 500, `faits avec porteur à l'image : ${faits}`);
assert.ok(degages >= 3, `dégagements captés puis relancés joués par le moteur : ${degages} (le test doit les couvrir)`);
assert.deepEqual(faux, [], `bandeau qui donne le ballon à l'autre équipe que l'image (${faux.length} sur ${faits}) :\n${faux.join('\n')}`);
console.log(`match-bandeau-possession : ${faits} faits sur ${MONDES.length * PAR_MONDE} matchs, ${degages} dégagements captés, bandeau = image`);
