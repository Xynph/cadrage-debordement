# Retrait des six doublons du catalogue actif

Base vérifiée sur GitHub : `main` **1ffca09b2e81d41011c4329fde5e30849479b161**, le 9 novembre 2026. Ce lot répond à la suppression demandée des fiches en double sans perdre les statistiques, contrats et photos des anciennes parties.

## Identités conservées et niveau de preuve

Le mapping reprend exactement les six rapprochements déjà reçus dans [la PR409](https://github.com/Xynph/cadrage-debordement/pull/409) et [la PR414](https://github.com/Xynph/cadrage-debordement/pull/414), intégrés notamment par [af62a98](https://github.com/Xynph/cadrage-debordement/commit/af62a983377e00998e08c43817523f31148c967a) et [c07ce6a](https://github.com/Xynph/cadrage-debordement/commit/c07ce6a68adfa4f6aee72caab4523c77508bf8e3). La [réservation du complément](https://github.com/Xynph/cadrage-debordement/issues/73#issuecomment-6734468824) et `docs/champ-donnees-depart-2026-27.md` décrivent le périmètre. Ces décisions attestent les rapprochements antérieurs, pas une nouvelle vérification nominative dans Cloud.

Les pièces nominatives et archives RFU/club ont été explicitement conservées dans le dossier privé du producteur. Elles ne sont pas disponibles ici : aucun nom réel, URL de profil ou recoupement de naissance n'est inventé. Les noms anonymisés du catalogue et les écarts d'âge/note ne servent jamais à identifier un doublon. Les cinq premiers rapprochements réconcilient une variante de feuille de match avec la fiche du club ; le dernier conserve la fiche du club d'arrivée après le transfert attesté dans le lot antérieur.

| Fiche retirée | Fiche conservée | Club alias → canonique |
|---|---|---|
| `world:champ:13c1a3ff3ff86c5e2c36` | `world:champ:8a3d1b00165633022e1a` | 112 → 112 |
| `world:champ:2e0362b3d347ff05eefe` | `world:champ:02dad2e791f224c3284d` | 112 → 112 |
| `world:champ:3c3b80e0f9597c98651f` | `world:champ:f7fc757633765b1e925e` | 109 → 109 |
| `world:champ:22df93e82174027f0b2c` | `world:champ:7c8b8a958fb0522bb063` | 102 → 102 |
| `world:champ:724a9a498090dffad81a` | `world:champ:021410b35826722cb7df` | 108 → 108 |
| `world:champ:a6d42bfb1fbfb50d91f5` | `world:champ:dfa7f4a1b41a97e7f0a8` | 113 → 109 |

Chaque canonique est actif, distinct et absent de la liste des variantes. Aucun autre rapprochement n'est déduit de la seule ressemblance des noms.

## Changement et compatibilité

`world-champ-extension.json` passe de **602 à 596 joueurs/profils**. Le catalogue composé passe de **5 884 à 5 878** ; les nouvelles carrières restent à **5 878**, car elles excluaient déjà ces six fiches. Les clubs affectés contiennent respectivement 36 joueurs (102), 35 (108), 36 (109), 34 (112), 60 (113). Les 116 clubs, les données des 596 autres joueurs du Champ, leurs profils et toutes les autres métadonnées restent strictement identiques à la base.

Les six objets complets et leurs profils originaux sont déplacés sans modification dans `world-legacy-aliases.json` (`world-legacy-aliases-v1`). Ils ne figurent plus dans `clubs[].players`, `worldProfiles`, ni `playerCount`. La composition les expose séparément au lecteur ; `sourcePlayerKnown` et la validation savent encore reconnaître une ancienne fiche présente dans une carrière. La création utilise uniquement le catalogue actif. Aucune migration de partie, suppression de contrat, fusion de minutes ou réécriture d'export n'est imposée.

L'analyse et la lecture des packs autorisent les six anciens IDs, avec leurs bornes historiques de 5 884 entrées. Une identité canonique fournie par le pack est prioritaire ; un portrait déjà lié à l'alias reste utilisable lorsque le canonique n'en possède pas. Cette résolution concerne la présentation, conserve le manifeste et les fichiers d'origine, et n'ajoute aucun joueur. Les IDs inconnus restent refusés. Aucun disque ou dossier photo externe n'est modifié.

Le constructeur Windows copie l'ensemble de `native/engine` avec `shutil.copytree`, puis les fichiers du manifeste `CORE_FILES` dans `engine/core`. Le nouveau JSON est ainsi inclus sans modifier le script ni la CI. La réception reproduit ce layout réel avec le worker Node Linux ; elle ne prétend pas avoir exécuté l'exécutable Windows.

## Vérifications exécutées

- Test rouge initial : catalogue à 5 884 au lieu de 5 878 ; test pack rouge après retrait des fiches : ancien ID refusé avant adaptation du lecteur.
- **15 tests ciblés passent sous Node22 en 19,1 s** : catalogue, six mappings, création Monde complet, échéances, éditions antérieures, registre et packs Champ, médias et médias adversariaux ; export de fixture ancienne contenant les six alias, reprise et import exacts ; projection de la photo alias/canonique sans mutation du moteur ; pack historique complet et refus d'un ID inconnu.
- Comparaison structurelle à `1ffca09` : les 596 autres joueurs et profils sont égaux, les six copies de compatibilité sont égales aux objets supprimés, toutes les métadonnées et déplacements restent égaux. Le mapping produit un seul transfert de club, 113 → 109. Preuve de travail : `world-catalogue-dedup-proof.json`, hors dépôt.
- Un véritable export de réception antérieure à la PR414, **5 881 joueurs**, empreinte SHA256 `3809d2f05750b2d9913258485dce3e9b280d5a9d320b8eb4c3eb7d8d4f965938`, est réimporté puis rouvert dans le layout embarqué : export et profil privé strictement égaux, RNG et horloge conservés. Cette sauvegarde de test anonymisée de 14 Mo reste hors Git.
- `build-godot-prototype.py --stage-only` passe avec Node22, y compris les trois compilateurs en `--check` et les assets existants. Le JSON copié dans le layout embarqué est identique à sa source.

Aucun coefficient, règle de rugby, jeunesse, portrait généré ou historique privé n'est modifié. Les anciennes parties peuvent conserver des doublons historiques : les effacer automatiquement nécessiterait une migration explicite des contrats, feuilles et statistiques. Le présent lot supprime les doublons du catalogue et des nouveaux départs tout en préservant ces parties.
