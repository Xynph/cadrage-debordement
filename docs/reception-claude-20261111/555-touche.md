# Réception PR555 — candidat2f5d9ba reçu sur périmètre logique

Candidat géométrique `66f391fccaef008ba7adfd0d60972686ee9478a5`, base main `96f537040bf9f2e37bf10b0a9b09518b732244a2`. La réception antérieure de `d05b5f752db3cebfb098c01b4b0d7dcf1743bf8f` reste une preuve historique limitée à ce SHA. Le nouveau head contient le commit produit `35b8751d` et un commit documentaire66f : il ne faut donc pas transférer automatiquement les 80 matchs précédents au nouveau code. Description actualisée et commentaires relus (aucun commentaire).

Le nouveau head `2f5d9ba57b3b98f4e99ca340393ad62aa91f0e62` fusionne66f et main96. Son diff final contre main96 porte uniquement sur les quatre fichiers touche ; les trois fichiers code/tests ont exactement les blobs testés dans notre copie main96+patch66f. La preuve sur cette copie vaut donc pour le code de2f, sans rejouer à cause du seul rattachement à main.

## Delta production et réception ciblée

`dist/match2d.js:11` borne la marque de touche à5–95 dans la projection ; `:19`–`:25` place les rangées à0,5m de leur côté, le lanceur sur la marque et la touche, son vis-à-vis à2m de la marque/y3, le receveur2m derrière la rangée, les autres joueurs à distance ou sur leur ligne de but ; `:35` exempte cette scène des bornes générales afin de permettre ces positions. Aucune écriture sportive/RNG ajoutée. Les dimensions et l’attribution systématique des rôles par slot restent des abstractions, notamment équipes réduites non rééquilibrées.

Le delta code/tests a été appliqué sans conflit dans la copie jetable de main96 déjà munie de d05. Blob testé `dist/match2d.js` : `bfe7aac751448c35608be8c0a1b717e451fd0e04`, exactement identique à66f ; blob `tests/lineout-geometry.cjs` : `9ec7f9df9f3993580fe1d4174c9df13172975b69`, également identique.

- `tests/lineout-side.cjs` : rc0.
- `tests/lineout-geometry.cjs` : rc0,310 scènes dont274 réelles,31 réelles près des en-buts et36 construites ;631 non-participants sur leur ligne de but. Contrôles d’état/RNG sans mutation et conservation par l’adaptateur inclus.
- `tests/match2d.cjs`, `match-actions.cjs`, `match3d-adapter.cjs` : rc0.
- Nouvelle sonde80 matchs **main96 → main96+55566f : PASS80/80**,15 140 ticks de scènes,1 332 scènes modifiées. Les seuls écarts permis sont les coordonnées de joueurs et les x du ballon/de l’origine dans les scènes `lineout`. Métadonnées complètes, scènes hors touche, état carrière complet et RNG suivant sont comparés ; ce passage remplace le report automatique de la preuve d05.

## Verdict courant

**Reçu sur le périmètre logique/géométrique** pour2f5d9ba : nouveaux tests ciblés verts et80 matchs rejoués avec état carrière/RNG identiques. **Réception graphique et cumul554 non acquis**, pour les réserves ci-dessous. Les anciennes suites physique/salaires/réseau ci-dessous ont été exécutées surd05 ; elles ne sont pas revendiquées comme réexécutées sur66f/2f. Le nouveau rejeu compare toutefois l’état carrière complet de66f/2f àmain96.

## Réserve de présentation et cumul554

La description actuelle reconnaît une vitesse de mise en place aggravée (pointe déclarée75,8m/s, contre50,9 auparavant), non corrigée. Ce chiffre provient du producteur ; il n’a pas été remesuré ici. La géométrie statique et la conservation du moteur n’établissent donc pas la qualité de la transition visuelle. Ballon ày4 plutôt qu’aux mains du lanceur, équipes réduites et touche rapide restent des limites explicites. Ce lot n’est pas une réception graphique d’un match complet.

Le nouveau document du producteur décrit des divergences avec554 : marque bornée6–94 au lieu de5–95, couloir1,2m au lieu de1m, vis-à-visy2,6 au lieu de3, receveur2,8m au lieu de2. La lecture ciblée précédente de `_align` confirme qu’il recalcule sa géométrie depuis la marque : pas de double inversion arithmétique, mais ses positions ne deviennent pas celles de66f par simple combinaison. La fixture du cumul doit être régénérée et le cumul reçu séparément. Aucun Godot/cumul554+555 ni Windows exécuté par ce récepteur.

## Réception historique d05

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


## Sonde reproductible du candidat66f

Enregistrer ce bloc hors dépôt et le lancer avec Node22, en arguments les copies de main96 avant et après patch55566f. Le test utilise le vrai harness sans SDK.

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
assert.equal(x.kind,'lineout');changed++;x.ball.x=y.ball.x;x.origin.x=y.origin.x;
for(let i=0;i<x.players.length;i++){const p=x.players[i],q=y.players[i];p.x=q.x;p.y=q.y;}
assert.deepEqual(x,y);
}
}
assert.equal(a.run('S.live.finished'),true);assert.equal(b.run('S.live.finished'),true);
// Full career state includes the roster, salaries, physical loads, finances and match log.
const sa=a.run('JSON.stringify(S,(k,v)=>k==="visualSource"?undefined:v)'),sb=b.run('JSON.stringify(S,(k,v)=>k==="visualSource"?undefined:v)');assert.equal(hash(sa),hash(sb));assert.equal(a.run('Math.random()'),b.run('Math.random()'));matches++;
if(matches%20===0)console.log(JSON.stringify({matches,scenes,changed}));
}
console.log(JSON.stringify({passed:true,matches,scenes,changed,assertions:'full career state SHA256 and next RNG equal; scene changes restricted to lineout ball/origin x and player x/y; all metadata preserved'}));
```
