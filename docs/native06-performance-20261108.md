# Sauvegardes natives — coût de validation et d'empreinte

Le post-fusion de la PR397, exécution GitHub `42507156072` sur `6c38020a`, a arrêté deux campagnes après 180 s : `native-academy-integrated-long` et `native-club-support-season`. Le succès antérieur de la CI de PR ne valide pas ce post-fusion. La présente modification conserve les scénarios et tous leurs contrôles.

## Modification bornée

Deux fonctions de `dist/saves.js` utilisent désormais des références locales, limitées à leur appel :

- `safeTree` lie `saveCheck`, `saveNumber`, `saveObject` et `Array.isArray` avant de parcourir l'arbre ; les mêmes fonctions sont appelées aux mêmes endroits.
- `saveChecksum` lie `Math.imul` avant la boucle FNV existante.

Aucun contrôle, message, ordre de visite, seuil de complexité, algorithme, empreinte ou format n'est modifié. Il n'y a ni cache persistant ni suppression de sérialisation. Les appels du worker, sauvegardes, validations, simulations, règles et RNG restent ceux du moteur courant. Les optimisations antérieures de `buildSheet` et `activePlayers` ne sont pas retouchées. `worker.cjs`, les scénarios de test, workflows, gates et délais restent inchangés par ce correctif.

Le gain vient de la résolution de références répétées dans le contexte VM, pas d'un travail métier supprimé. Le diagnostic a également constaté le coût des sérialisations internes pendant une délégation ; aucune coalescence de sauvegarde n'est incluse ici.

## Mesures locales avant/après

Profils Node22 Windows isolés, mêmes commandes, données et seeds, avec V8 CPU profiling sur les deux versions. Les temps ci-dessous sont des observations locales uniques, pas une promesse de délai sur GitHub.

| Échantillon réel | Avant | Après | Variation observée |
| --- | ---: | ---: | ---: |
| 10 semaines intégrées, checkpoint/import/reprise semaine 10 | 23,020 s | 15,897 s | −30,9 % |
| 6 semaines Support, reprise du premier live | 33,074 s | 25,605 s | −22,6 % |

Temps attribués par les profils aux fonctions ciblées, tous leurs sites d'appel regroupés :

| Fonction | Support avant → après | Intégré avant → après |
| --- | ---: | ---: |
| `safeTree`, inclusif | 5,045 → 1,609 s | 5,774 → 1,769 s |
| `saveChecksum` | 2,250 → 0,306 s | 2,725 → 0,337 s |

Les exports complets et les fichiers `donnees.json` des deux échantillons sont identiques **octet par octet avant/après**. Seeds identiques : Support `2709369375`, intégré `2981339948` ; horloge fixée à `1700000000000`. Les projections pures conservent aussi le disque. Ces comparaisons sont distinctes des campagnes complètes suivantes.

## Campagnes complètes réellement exécutées

Les fichiers de test d'origine sont exécutés sans modification sous Node `v22.23.4`, successivement, avec un plafond externe de **180 000 ms conservé**. Le seul préchargement diagnostique recueille le temps CPU du processus à sa sortie et écrit les preuves hors dépôt.

| Campagne complète | Temps mural | CPU utilisateur | CPU système | Résultat |
| --- | ---: | ---: | ---: | --- |
| `native-academy-integrated-long` | 113,796 s | 118,562 s | 10,375 s | code 0, pas de timeout |
| `native-club-support-season` | 160,152 s | 169,110 s | 11,969 s | code 0, pas de timeout |

La campagne intégrée termine deux saisons, arrive en S3, conserve les six checkpoints 10/20/34 avec import/export et reprise exacts, conférences hebdomadaires, décisions vestiaire et domaines natifs actifs. Maximum observé : 4 940 124 octets et 315 944 nœuds.

La campagne Support conserve ses 34 semaines, 30 briefings et matchs délégués, huit projections pures en semaines 27–34, neuf reprises exactes dont fin S1 et import S2, puis réunion et négociation en S2. Aucun match, semaine, assertion ou reprise n'a été retiré.

**La marge Support n'est que de 19,848 s sur le plafond local.** Les deux résultats Windows ne remplacent pas une nouvelle CI Linux sur le SHA publié, puis sa validation post-fusion. Le post-fusion historique reste rouge ; aucune réussite distante future n'est acquise.

## Compatibilité vérifiée

`tests/native-save-hotpaths06.cjs` compare les fonctions courantes aux corps historiques réels de `safeTree` et `saveChecksum`, capturés de `54d67fa9` et confrontés à `6c38020a`. Il couvre 205 empreintes dont un état réel, Unicode, emoji, surrogate isolé et valeurs générées déterministiquement ; aucune mutation d'entrée. Le second contrôle compare acceptation et messages sur les textes/clés/types/nombres interdits, profondeur, tailles, les trois plafonds 200 000/400 000/650 000 nœuds et l'ordre de lecture de `Object.entries` avant un refus de clé.

Les deux contrôles passent sous Node22 et Node26, sans assertion de performance murale en CI et sans dépendance aux nouveaux domaines natifs 0.6. Parsing Node et `git diff --check` reçus. Les fonctions optimisées n'ajoutent ni migration ni changement d'empreinte des anciennes sauvegardes ; les comparaisons avant/après et les allers-retours des campagnes conservent leurs résultats observés.

Les rapports CPU, sorties, exports et empreintes de sources sont conservés hors dépôt dans `E:/Cadrage-Debordement/artefacts/native06-20261108/performance`. La réception de publication/CI appartient à l'intégrateur ; aucune fusion ou distribution nouvelle n'est annoncée par ce sous-lot.
