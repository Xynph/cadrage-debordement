# Retirer les identités réelles du dépôt public : inventaire et plan

Relevé du 11 novembre 2026 sur la tête de #543 (`0dad8da5`). Décision de
Léo : oui au retrait, le pack « Rugby Réel » reste en local et continue de
s'importer dans le jeu comme un mod.

Ce document inventorie et planifie. **Rien n'est supprimé par cette PR.**

## Ce que le retrait ne change pas

Le pack Rugby Réel se rattache au jeu par les **identifiants** des joueurs,
des staffs, des clubs et des compétitions (`lnr:862`, `staff:0:…`), pas par
leurs noms. Tant que ces identifiants restent dans la base du jeu, le pack
importé affiche les vrais noms, logos et portraits comme aujourd'hui. Il vit
sur le PC de Léo, hors du dépôt et hors de l'exécutable.

## Inventaire

Recherche des 1 592 noms complets de `dist/lnr-rosters-data.js` dans tous
les fichiers suivis par Git, sans tenir compte de la casse : **55 fichiers**.

| Emplacement | Fichiers | Lignes avec un nom réel | Nature |
| --- | --- | --- | --- |
| `modding/` (data01 à data06) | 36 | 3 801 | Recherches et collectes : effectifs, transferts, années de naissance |
| `data/scouting/review-v12/` et `data/roster-foundation/` | 5 | 2 935 | Preuves de carrière et de saison, registre des postes vérifiés |
| `docs/` | 7 | 121 | Rapports de collecte et d'audit des notes |
| `tests/` | 5 | 8 | Noms cités dans des assertions |
| `dist/` | 2 | 2 | `lnr-rosters-data.js` (les 1 592 noms sur une ligne) et une question de presse |

Hors de cette recherche, constaté par lecture :

- `data/staff/verified.json` : 471 membres de staff sous leur vrai nom.
- `data/world/foreign-inputs.json` et les registres du Monde : joueurs
  étrangers sous des alias obtenus en changeant une à trois lettres.
- `dist/rugby-common-rosters.js`, la base du jeu : 1 528 noms sur 1 592 à
  trois lettres au plus du nom réel, mêmes identifiants, âges et postes.
- `dist/press-question-bank.js:10` : dix journalistes réels, avec leur média
  et l'adresse de leur page d'auteur, auxquels le jeu prête une personnalité
  et des questions inventées (constat P2 de
  `docs/audit-priorites-cloud-20261111.md`). À traiter comme les joueurs :
  journalistes et médias inventés dans la base, noms réels dans le pack.

Total à déplacer : environ 9 Mo.

## Pourquoi ce n'est pas une simple suppression

Ces fichiers sont des **sources** dont le dépôt recalcule ses données :

- `scripts/build-rugby-common.cjs` recompile la base du jeu à partir de
  `dist/lnr-rosters-data.js`. La construction de l'exe lance ce script en
  mode contrôle et échoue si le résultat diffère.
- `scripts/build-roster-foundation.cjs` et `build-staff-registry.cjs` font de
  même avec les registres vérifiés.
- 42 suites de tests, 15 outils et 6 workflows lisent ces sources.
- La version web historique charge `lnr-rosters-data.js` directement.

Les retirer sans préparation casserait la construction et la CI.

## Plan en quatre étapes

### 1. Un dépôt de données privé, sans CI

Créer un dépôt privé, par exemple `Xynph/rugby-reel-donnees`, et y copier
`modding/`, `data/scouting/`, `data/roster-foundation/`, `data/staff/`, les
fichiers `dist/lnr-*.js` qui portent des identités, les outils de collecte
(`tools/data0*`, `tools/rugby-real-v12`, `tools/lnr-v12-v11-preview`) et
leurs tests. Un dépôt privé est gratuit ; sans workflow, il ne consomme
aucune minute de CI. **Demande l'accord de Léo** : c'est une modification de
la configuration GitHub.

À défaut, ces dossiers peuvent vivre seulement sur le PC, avec le pack.

### 2. Un dépôt public qui se suffit

- Les compilateurs acceptent l'absence des sources : ils vérifient alors
  l'empreinte des fichiers compilés et l'annoncent clairement (« sources
  privées absentes, recompilation non contrôlée »). Pas de repli silencieux.
- Les 42 suites qui lisent les sources partent avec elles dans le dépôt
  privé. Les suites qui testent le jeu sur la base compilée restent.
- Les 6 workflows de données réelles partent aussi.
- La version web historique perd son mode « effectifs réels ».

### 3. Une base du jeu réellement fictive

Remplacer les noms dérivés par des noms générés sans lien avec les joueurs
réels : listes de prénoms et de patronymes par nationalité, tirage par
graine, contrôle automatique qu'aucun nom généré n'est à moins de quatre
lettres d'un nom réel du même club. Les identifiants, âges, postes et notes
ne changent pas. Les carrières existantes gardent les noms enregistrés dans
leur sauvegarde ; à vérifier par un test.

Le contrôle a besoin de la liste réelle : il tourne dans le dépôt privé,
qui publie seulement la base générée.

### 4. L'historique

Après les étapes 1 à 3, les noms restent lisibles dans l'historique Git
public. Les effacer demande une réécriture de l'historique, qui invalide
toutes les branches et PR ouvertes. À ne faire qu'une fois les PR triées,
avec l'accord explicite de Léo et une copie complète du dépôt.

## Ordre et collisions

Codex Cloud stabilise en ce moment la version commune (#539) et sa CI. Les
étapes 2 et 3 touchent des tests et des workflows de cette CI : elles
commencent **après la fusion de la version commune**. L'étape 1 peut se faire
tout de suite, elle ne modifie pas le dépôt public.

## Décisions de Léo (11 novembre 2026)

1. **Dépôt privé de données** : fait. `Xynph/rugby-reel-donnees`, privé, sans
   CI, contient les 122 fichiers et leur manifeste. Rien n'est encore retiré
   du dépôt public.
2. **Base du jeu à noms inventés, vrais noms par le pack importable** :
   accepté. Sans pack, une nouvelle carrière affiche des inconnus ; avec le
   pack Rugby Réel, les vrais noms, comme aujourd'hui.
3. **Réécriture de l'historique** : plus tard.

Je ne suis pas juriste. Ce plan réduit l'exposition ; il ne remplace pas un
avis sur le droit des données personnelles et le droit à l'image.
