# Réception ciblée des trois expériences Claude — 11 novembre 2026

Audit seul, sans changement du code de production, fusion, activation, jugement de
style ou exécution Windows. Node 22.23.4 Linux ; Godot 4.7.2 Linux. Les copies
`git archive` sont isolées dans `/workspace/tmp/flags-review/`. Tous les appels
Godot passent par `/tmp/rg27-godot-sdk.lock`, audio Dummy. Les verdicts techniques
ne constituent pas un accord d'intégration ou de direction artistique.

## Références examinées

Descriptions et commentaires GitHub lus le 11 novembre ; aucun commentaire sur
les trois PR au moment du relevé. Références rugby et données du jeu du dépôt lues.
Les budgets restent une simulation avec estimations, aucune certification des
lois ou budgets officiels n'est déduite des tests.

| PR | Head examiné | Base réelle et portée du verdict |
| --- | --- | --- |
| [552](https://github.com/Xynph/cadrage-debordement/pull/552) salaires | `73b28ef334708c302254b4c3603caef102a6c430` (relecture de `1cab6ccf`) | Cible GitHub `integration/oval-cloud-complet-20261110`, `00eccffe` ; parent avant expérience `fe79c36`. Pas rebasée sur `main` `96f53704`. |
| [554](https://github.com/Xynph/cadrage-debordement/pull/554) gestes | `b25c0aabc34dd519432c78ddec813bcec8a664c0` | Merge de `main` `96f53704` déjà présent dans ce head. Le conflit décrit dans le corps de PR est historique. |
| [550](https://github.com/Xynph/cadrage-debordement/pull/550) socle Effectif | `44b672115482ec4c58f5fc02994edb700fb7967a` | Merge de `main` `96f53704` déjà présent dans ce head. |

## Drapeaux et états sauvegardés

Lecture du code : les trois variables exigent la chaîne exacte `1`. Absence,
`0`, `true` ou autre valeur ne déclenchent pas la branche d'environnement.

- Salaires : `worker.cjs` lit `process.env.CD_SALAIRES_PAR_NIVEAU` dans le
  processus Node extérieur au VM, uniquement pendant `new_career`. Le VM ne
  reçoit pas `process` ; les modules de calcul lui sont injectés explicitement.
  La marque `S.startingSalaries` porte ensuite le choix de carrière : éteindre
  l'environnement ne reconvertit pas les salaires ni l'économie d'une carrière
  marquée. L'activation sur une ancienne carrière n'est pas une migration.
- Gestes : `match_view.gd:_ready` appelle `set_gestes(true)` uniquement si
  `OS.get_environment("CD_MATCH_GESTES") == "1"`. Le défaut `_gestes == null`
  garde la branche historique. Le script de recette utilise aussi le setter
  direct : ce test seul ne prouve pas le trajet d'environnement.
- Socle : `SocleEffectif.actif(app)` exige le drapeau exact **ou** la métadonnée
  explicite `socle_effectif=true`. Cette métadonnée est absente par défaut.
  L'aiguillage du shell intervient après la fiche complète du joueur ; sinon
  l'ancien rendu reste sélectionné. Le `preload` du nouveau module est toutefois
  exécuté même OFF : la compilation de ce module fait partie de la régression.

## PR 552 — à corriger, sans refus de l'expérience

### Défaut reproduit : première projection après reprise incohérente

Reproduit sur `1cab6ccf`, puis de nouveau sur le head actualisé `73b28ef3`
(sortie identique), graine 27, horloge `1794178800000`, nouvelle carrière commune
club 29, drapeau ON : fermer le bridge, retirer le drapeau puis ouvrir un nouveau
bridge sur le même profil et demander immédiatement `snapshot`.

| Champ | Juste après création ON | Premier snapshot après reprise |
| --- | ---: | ---: |
| Marque sauvegardée | version 3 / 52 semaines | conservée |
| Plancher salarial exposé | 270 €/semaine | absent, UI repli à 1 000 € |
| Recettes hebdomadaires prévues | 222 300 € | 160 000 € |
| Charges hebdomadaires prévues | 258 900 € | 50 670 € |
| Trésorerie prévue en fin de saison | 2 449 900 € | 6 017 220 € |
| Budget de saison projeté | présent | absent |

Cause déduite du code et conforme à la reproduction : `snapshot`, `export` et
`shutdown` retournent avant l'installation de `BRANCHEMENT` dans `handle`.
Les fonctions `budgetActif` et `budgetFinance` n'existent donc pas encore dans
le VM du nouveau bridge. `engine_bridge.gd:start` envoie justement `snapshot`
comme première commande. L'écran Finances expose alors l'ancienne projection ;
`contract_negotiation.gd` reprend son plancher de secours de 1 000 €. Le choix
ON/OFF de l'environnement à la reprise ne résout pas l'ordre d'installation.

Correction attendue chez le producteur : installer les hooks avant la première
projection, puis ajouter une régression qui compare le modèle initial de reprise
au modèle budgétaire avant fermeture, sans commande mutante intermédiaire.
Preuves exécutées : [résultat](qa/experimental-flags-20261111/resume-projection.json)
et [sonde](qa/experimental-flags-20261111/resume-probe.cjs).

### Compatibilité OFF effectivement mesurée

Sonde identique exécutée sur le parent pré-expérience `fe79c36`, le premier head
`1cab6ccf` et le nouveau head `73b28ef3`,
environnement absent : création, entraînement, composition, match délégué,
clôture, export/import puis reprise du profil. Les quatre textes exportés sont
**identiques octet pour octet entre base et head**. Aucune marque nouvelle.

- SHA256 création : `c13f91fc1dae638a62e518b9830566f2f2d3bb0e53198d203bafd80864fabc04`.
- SHA256 après semaine, après import et après reprise :
  `96cc80043eff2ad5a5cb061aa5f9a1e3b2189c1c0d521861a695bb36f93fb367`.

La même sonde ON conserve la marque version 3 / 52 semaines ; export/import et
reprise après retrait du drapeau restent identiques, SHA256 après semaine
`41a00945f1a533314b2eb00b007c782eda707308a82e5438f7a81197c2d9a1f8`.
Cette preuve concerne les données, et ne résout pas le défaut de projection.
Les [résumés JSON et la sonde](qa/experimental-flags-20261111/) sont conservés.
Les exports complets locaux, environ 22 Mio par scénario, ne sont pas ajoutés.

Reproduction Linux depuis ce dépôt (copie de source fournie en argument) :

```sh
env -u CD_SALAIRES_PAR_NIVEAU node docs/qa/experimental-flags-20261111/worker-probe.cjs /chemin/copie-source /tmp/off-result.json
node docs/qa/experimental-flags-20261111/resume-probe.cjs /chemin/copie-source
```

La seconde sonde crée son propre profil temporaire, active la création, ferme,
retire l'environnement puis ouvre le profil en lecture. Elle ne modifie aucune
carrière utilisateur. La sortie du nouveau head est également conservée dans
[résultat `73b28ef3`](qa/experimental-flags-20261111/resume-projection-73b28ef3.json).


La comparaison exacte OFF ci-dessus a aussi été rejouée sur `73b28ef3`, avec
les quatre mêmes textes et empreintes. Le delta vers
`73b28ef3` modifie seulement `club-budget.cjs`, `league-economy.cjs` et les tests
de cette dernière : cache de calculs, réputation et préférences de transfert,
sans modification de `worker.cjs`. Les preuves de reprise et de compatibilité OFF ont donc été
réexécutées sur ce nouveau head.

Ce résultat ne vaut pas preuve OFF contre `main` : le head de la PR manque des
changements de `main` et doit être rebasé puis reçu à nouveau. Le corps de PR et
son document indiquent encore un plancher 1 000 € non corrigé et un écran Finances
non branché : ces constats sont périmés au head `1cab6ccf`, qui les modifie.

### Suites Node et portée

- `1cab6ccf`, suite des trois fichiers : 49/51. Deux tests OFF du vrai moteur
  échouent sur `finish_round` avec le délai VM interne de 15 s, sous charge.
  Ils ne démontrent pas une régression de calcul ; les sondes comparatives
  indépendantes OFF sont passées. Ne pas annoncer cette première suite verte.
- `73b28ef3`, `club-budget.cjs` + `league-economy.cjs` séquentiels : **39/39**,
  40,7 s. `starting-salaries.cjs` rejouée seule : **14/14**, 357,1 s.
  Soit **53/53 sur le nouveau head** en deux exécutions séquentielles.
  Les journaux TAP sont conservés avec les sondes. Cela ne couvre pas la
  première projection de reprise, qui reste incorrecte dans la sonde dédiée.

## PR 554 et PR 550 — recettes en cours

Lecture statique et suites purement Node exécutées : fixture des gestes
identique aux faits du moteur (**1/1**, le test Godot ignoré dans cette exécution) ;
architecture socle (**1/1**, deux tests Godot ignorés).

La première tentative Godot du socle depuis `git archive` est **invalidée** :
`assets/clubs.json`, produit du staging officiel, était absent. L’erreur de
chargement qui en résulte n’est pas attribuée à la PR. Staging officiel ensuite
exécuté avec succès sur les copies 550 et 554. Les recettes Godot suivantes sont
suspendues pour laisser le verrou aux régressions P1 geometry/contracts.
Verdicts définitifs et résultats Godot à consigner après exécution.

## Windows natif : voie possible, non exécutée

La recette `main` `96f53704` impose Windows natif et un ZIP au SHA exact.
`ci/windows-receipt.ps1` vide l'environnement puis reconstruit une liste fermée :
les trois variables expérimentales n'y figurent pas. Ajouter un drapeau au job
appelant ne suffirait donc pas. Un script externe `--script` ne remplace pas le
main loop exporté : les drivers embarqués `ci/windows-*.gd` et l'ACK de leur
chaîne constituent la voie existante.

La recette actuelle ne prouve donc aucun effet ON de ces trois expériences.
Le runner standard Windows public existant ne suffit pas à lui seul : il faudrait
une réception explicite du choix de recette, des variables effectivement transmises
et de l'effet observé dans le ZIP exact. Cette extension est différée par
l'intégrateur : priorité aux régressions P1/P2 et aux preuves Linux.

**Windows natif non fait pour ces trois expériences.** Aucun outil QA, workflow,
réglage, label ou lancement GitHub n'a été modifié pour cet audit. Aucun service
payant n'a été utilisé. Les tests Linux présents dans ce rapport ne sont jamais
qualifiés de tests Windows.
