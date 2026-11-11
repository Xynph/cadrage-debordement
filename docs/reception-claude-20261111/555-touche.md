# Réception PR555 — reçu

Candidat exact `d05b5f752db3cebfb098c01b4b0d7dcf1743bf8f`, base de réception main `96f537040bf9f2e37bf10b0a9b09518b732244a2`. Description, documentation et commentaires lus (aucun commentaire). La base de PR est `integration/oval-cloud-complet-20261110` : son cumul n’est pas pris pour du main. Le patch du seul commit candidat s’applique sans conflit dans une copie jetable de main96. Aucune modification produit effectuée dans la branche de réception.

`dist/match2d.js:17` remplace `side===team` par `side===0` pour le x des slots0–7 en touche. Le sens d’attaque reste constant entre les deux périodes dans ce moteur ; le correctif rend l’alignement cohérent avec les non-participants lorsque l’équipe1 lance. C’est une convention spatiale de présentation ; cette réception ne certifie pas la conformité de l’ensemble d’une touche à la loi18. Le couloir, la profondeur et le lanceur restent les limites documentées du candidat.

## Vérifications exécutées

- `tests/lineout-side.cjs` : **rouge sur main96**, au premier contrôle équipe1 lançant ; **vert sur main96 + patch**, 186 scènes, dont équipe0/période1:45, équipe1/période1:51, équipe1/période2:43, équipe0/période2:47.
- `tests/match2d.cjs`, `match-actions.cjs`, `match3d-adapter.cjs`, `v27-physical-load.cjs`, `world-wage-forecast.cjs` : rc0 sur main96 + patch.
- Sonde comparative indépendante avant/après : **PASS, 80/80 matchs**, 15 140 ticks de scènes, 774 scènes changées. Vingt graines × quatre clubs (0,3,7,11), même tactique conquête, `matchScene` à chaque tick. Comparaison de l’état carrière complet en SHA256 et du prochain tirage aléatoire ; les seuls écarts de scène autorisés sont les x des slots0–7 en touche lancée par l’équipe1. L’état carrière comparé inclut effectifs, conditions/charges physiques, salaires, finances et journal du match.
- `native-academy-network-validation.cjs` : rc0, 110 imports invalides à checksum exact refusés en V1/V2 ; API historiques/jours réels, options valides, pureté, profil/export/octet/RNG préservés.

## Collision avec PR554 : lecture ciblée

PR554 head `b25c0aabc34dd519432c78ddec813bcec8a664c0`, `native/godot/match_gestes.gd`, fonction `_align` : les positions du geste sont recalculées depuis `line_x` avec `facing = team==0 ? 1 : -1`, `x = line_x - facing*0.6`. Le correctif555 ne donne pas lieu à une inversion arithmétique supplémentaire dans cette fonction ; le geste redéfinit ses propres positions. Ce constat est une lecture ciblée du code554, pas une réception graphique du cumul554+555. Le déploiement optionnel reste à recevoir par l’intégrateur.

## Verdict

**Reçu** pour la correction ciblée de placement, sur le SHA exact et main96. Les résultats sportifs et l’état carrière sont préservés dans les 80 scénarios rejoués ; les limites de géométrie et de rendu restent explicites.

## Limites

Aucun SDK, rendu Godot, navigateur ou Windows exécuté par cette réception. Aucun changement CI : le nouveau test n’est pas associé à `dist/match2d.js` par le sélecteur ciblé actuel ; l’intégrateur doit décider d’ajouter cette sélection avant intégration. Aucun fichier de moteur ou test partagé modifié par le récepteur.

## Sonde reproductible

Enregistrer le bloc ci-dessous hors dépôt, puis lancer avec Node22 en arguments les copies de main96 avant et après application du patch555. Les tests utilisent `tests/harness.cjs` réel, sans SDK.

```js
'use strict';
const assert=require('node:assert/strict'),crypto=require('node:crypto');
const [before,after]=process.argv.slice(2);const A=require(before+'/tests/harness.cjs'),B=require(after+'/tests/harness.cjs');
const hash=x=>crypto.createHash('sha256').update(x).digest('hex');let scenes=0,changed=0,matches=0;
for(let seed=1;seed<=20;seed++)for(const club of [0,3,7,11]){
const a=A.context(),b=B.context();for(const h of [a,b])h.run(`(function(){let s=${seed}*7919+13;Math.random=()=>{s=(Math.imul(s,1664525)+1013904223)>>>0;return s/4294967296}})();start(${club});S.tactic='conquete';beginMatch();continueMatch();`);
for(let tick=0;tick<4000&&!a.run('S.live.finished');tick++){
for(const h of [a,b])h.run('if(S.live.paused)continueMatch();presentationTick(S.live);');
const x=JSON.parse(a.run('JSON.stringify(matchScene(S.live))')),y=JSON.parse(b.run('JSON.stringify(matchScene(S.live))'));scenes++;
if(JSON.stringify(x)!==JSON.stringify(y)){
assert.equal(x.kind,'lineout');assert.equal(x.team,1);changed++;
for(let i=0;i<x.players.length;i++){const p=x.players[i],q=y.players[i];if(p.slot<8){assert.equal(q.x,Math.max(2,Math.min(98,x.ball.x+(p.side===0?-2:2))));p.x=q.x;}}
assert.deepEqual(x,y);
}
}
assert.equal(a.run('S.live.finished'),true);assert.equal(b.run('S.live.finished'),true);
// Full career state includes the roster, salaries, physical loads, finances and match log.
const sa=a.run('JSON.stringify(S,(k,v)=>k==="visualSource"?undefined:v)'),sb=b.run('JSON.stringify(S,(k,v)=>k==="visualSource"?undefined:v)');assert.equal(hash(sa),hash(sb));assert.equal(a.run('Math.random()'),b.run('Math.random()'));matches++;
if(matches%20===0)console.log(JSON.stringify({matches,scenes,changed}));
}
console.log(JSON.stringify({passed:true,matches,scenes,changed,assertions:'full career state SHA256 and next RNG equal; scene changes restricted to lineout team1 x slots0-7'}));
```
