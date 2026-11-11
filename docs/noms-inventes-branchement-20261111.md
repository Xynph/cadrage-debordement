# Noms inventés branchés dans la base du jeu

Relevé du 11 novembre 2026, sur `main` `96f53704`. Décision de Léo : la base
du jeu porte des noms inventés ; les vrais noms viennent uniquement du pack
« Rugby Réel » que le joueur importe. Ce document décrit le branchement de
ces noms dans le dépôt du jeu. Il suit l'étape 3 du plan de retrait
(`docs/retrait-noms-reels-plan-20261111.md`, PR #549).

## Ce qui change

Chaque joueur et chaque membre de staff de la base garde son identifiant,
son club, son poste, son âge et ses notes. Seul son nom affiché change.

| Registre | Personnes | Avant | Après |
| --- | ---: | --- | --- |
| `dist/rugby-common-rosters.js` (30 clubs français) | 1 592 joueurs | nom source, dernière lettre de chaque mot changée | nom de `data/names/noms-joueurs-v1.json` |
| `data/world/foreign-inputs.json` puis `native/engine/world-registry.json` (PREM, URC, invités) | 1 616 joueurs (et les 1 592 français recopiés) | idem | nom de `noms-monde-v1.json` |
| `world-pacific-extension.json` | 381 joueurs | alias fabriqué | idem |
| `world-japan-extension.json` | 1 078 joueurs | alias fabriqué | idem |
| `world-nationale-extension.json` | 615 joueurs | alias fabriqué | idem |
| `world-champ-extension.json` | 596 joueurs | alias fabriqué | idem |
| `world-legacy-aliases.json` | 6 anciens identifiants du Champ | alias fabriqué | nom de leur identifiant actuel |
| `native/engine/staff-registry.json` | 428 staffs français | nom source, dernière lettre changée | nom de `noms-staffs-v1.json` |
| `world-staff-registry.json` | les 428 français et 380 étrangers | idem | `noms-staffs-v1.json` et `noms-monde-staffs-v1.json` |
| `world-pacific-staff-extension.json` | 139 staffs | alias fabriqué | `noms-monde-staffs-v1.json` |
| `world-japan-staff-extension.json` | 912 staffs | alias fabriqué | idem |
| `world-nationale-staff-extension.json` | 155 staffs | alias fabriqué | idem |
| `world-champ-staff-extension.json` | 146 staffs | alias fabriqué | idem |

Total : 116 clubs, **5 878 joueurs** et **2 160 staffs**, tous renommés. La
comparaison champ par champ avec `96f53704` ne montre aucun autre écart que
les noms et trois empreintes de provenance (voir « Fichiers régénérés »).

## D'où viennent les noms

Les quatre fichiers de `data/names/` sont des copies à l'octet près de
`propositions/` dans le dépôt privé `rugby-reel-donnees` (branche
`claude/noms-inventes-v1`, commit `3741a5f`). Ils ne contiennent que des
identifiants et des noms inventés.

| Fichier | Contenu | SHA-256 |
| --- | --- | --- |
| `noms-joueurs-v1.json` | 1 592 joueurs des 30 clubs français | `b8ace381…aebd1e4` |
| `noms-staffs-v1.json` | 471 staffs français, dont les 428 du registre | `ec2e7fec…49f631f` |
| `noms-monde-v1.json` | 4 286 joueurs des 86 autres clubs, 6 anciens identifiants | `1a9b72d9…c5c57f67` |
| `noms-monde-staffs-v1.json` | 1 732 staffs des 86 autres clubs | `2c3c7a17…537e1d51` |

Les empreintes complètes sont dans `tests/base-names.cjs`, qui refuse un
fichier modifié. Le générateur, ses viviers et ses contrôles restent dans le
dépôt privé, parce que les contrôles lisent les vrais noms. Les 43 staffs
français nommés sans figurer au registre sont ceux que la source ne permet
pas d'importer ; leurs lignes ne servent à rien dans le jeu.

Règles appliquées par le générateur et recontrôlées à part : aucun nom
complet ni patronyme d'un joueur ou d'un staff réel de la base française ;
aucun nom qui retombe sur un ancien alias ou sur le nom dont il était tiré ;
quatre lettres d'écart au moins avec chaque joueur du même club ; un
patronyme une seule fois par club ; aucun homonyme dans la base.

## Chaîne de compilation

`scripts/base-names.cjs` lit `data/names/` et sert les quatre tables. Plus
aucun script ne fabrique un nom à partir d'une identité source.

| Script | Rôle |
| --- | --- |
| `scripts/build-rugby-common.cjs` | compile la base commune ; lit le nom par identifiant ; inscrit l'empreinte du fichier de noms dans `sources` |
| `scripts/build-staff-registry.cjs` | compile le staff français ; lit le nom par identifiant |
| `scripts/base-names.cjs` | écrit le champ `alias` de `data/world/foreign-inputs.json` et, par identifiant, les registres dont le compilateur n'est pas dans le dépôt (quatre extensions, anciens identifiants, staffs du Monde) |
| `scripts/build-world-registry.cjs` | inchangé : recompile `world-registry.json` à partir des entrées |
| `scripts/build-world-identity-pack.py` | la table `ENDINGS` et la fonction `pseudonym` sont supprimées ; le staff étranger public prend son nom dans `noms-monde-staffs-v1.json` et la compilation s'arrête si un identifiant n'a pas de nom ou si ce nom est celui d'une identité privée |

Recompiler, dans cet ordre :

```bash
node scripts/build-staff-registry.cjs
node scripts/build-rugby-common.cjs
node scripts/base-names.cjs
node scripts/build-world-registry.cjs
```

Chaque commande accepte `--check`. La préparation de l'exécutable
(`scripts/build-godot-prototype.py`) lance les quatre contrôles.

## Identifiants et pack Rugby Réel

Aucun identifiant ne change. Le pack s'accroche aux identifiants (`lnr:…`,
`world:…`, `staff:…`), pas aux noms : il s'importe et s'applique comme
avant. `tests/base-names-worker.cjs` le montre avec un pack manifestement
factice (« Joueur Test 1 », « Staff Test 1 ») pour un joueur français, un
joueur du mode Monde et un staff : le nom du pack s'affiche sur le bon
identifiant, plus aucun texte n'affiche le nom de base remplacé, la carrière
enregistrée ne reçoit jamais le nom du pack, et le retour à la présentation
de base rend les noms de base.

Sans pack, une nouvelle carrière affiche des inconnus. Avec le pack, elle
affiche les noms du pack.

## Sauvegardes existantes

Une carrière enregistre les noms de ses joueurs et de son staff. Choix
retenu, le plus simple et le moins surprenant : **une sauvegarde existante se
charge et garde ses noms.** Rien n'est réécrit au chargement ; il n'y a pas
de migration.

- Identifiants, effectifs, contrats, textes des questions et réponses de
  presse déjà archivées, actualités et courrier : inchangés à l'octet près
  après import puis export. Il n'y a donc aucun conflit entre une migration
  et les archives de presse.
- Une nouvelle carrière porte les noms inventés.
- Avec le pack, une ancienne carrière affiche les noms du pack, y compris
  dans les textes qui citaient ses anciens noms : la correspondance est
  établie par identifiant sur les noms que la carrière porte.

Trois contrôles de chargement comparaient un nom enregistré au registre
courant. Ils refusaient toute carrière commencée avant le changement, et ils
auraient refusé de même toute carrière après une future révision des noms.
Ils sont levés :

1. `native/engine/world-career.cjs` : en mode Monde, le nom de chaque joueur
   devait être celui du registre.
2. `native/engine/staff-career.cjs` : le nom d'un staff de référence devait
   être celui du registre.
3. `native/engine/staff-career.cjs` : le nom d'un staff de complément et son
   rang de tirage devaient être ceux que donne le registre courant. Ce rang
   dépend des noms déjà pris : deux noms de la nouvelle table déplaçaient un
   tirage dans les éditions Japon et Nationale.

Les autres contrôles restent : forme et longueur du nom, identifiants,
profils, contrats. Un nom contenant du balisage est toujours refusé.

Conséquence à connaître : le moteur ne vérifie plus, au chargement, qu'un nom
de pack n'a pas été écrit dans une carrière du mode Monde. La garantie est
portée par les tests de sélection de pack, qui comparent la carrière
enregistrée avant et après.

Vérifié sur cinq carrières créées avec `96f53704` avant le changement (base
commune, Monde 58 clubs, Japon, Nationale, Champ à 116 clubs) : import du
fichier exporté et reprise du profil sur disque sans erreur, état identique.
Ces fichiers portent les anciens alias ; ils ne sont pas dans le dépôt. Le
test du dépôt fabrique l'équivalent avec des noms factices.

## Affichage

La base a maintenant une seule forme : « Prénom NOM » pour les joueurs,
« Prénom Nom » pour le staff. Les joueurs du mode Monde passent de
« Prénom Nom » à « Prénom NOM ».

Trois écrans découpaient un nom. Ils partagent désormais
`native/godot/ui/person_name.gd`, qui ne réduit jamais un patronyme à son
dernier mot :

| Écran | Avant | Après |
| --- | --- | --- |
| Préparation, schéma du XV (`preparation_canvas.gd`) | dernier mot : « GAC » pour « Julien LE GAC » | « LE GAC » |
| Composition immersive (`tactics_canvas.gd`) | « J. LE GAC » | inchangé pour la base ; « J. DUPONT » pour un prénom en deux mots |
| Feuille de match classique (`lineup_board.gd`) | « LE GAC » | inchangé pour la base |

La base compte 76 joueurs au patronyme de plusieurs mots (« LE … »,
« VAN … », « DU … », « DOS … »), 21 noms à apostrophe (« O'… ») et 45
noms à trait d'union ; aucun prénom en deux mots. Le nom le plus long a
26 caractères.

Le moteur découpe un nom à un seul endroit : les joueurs de complément
(`native/engine/professional-depth.cjs`) reçoivent le premier mot du nom
d'un coéquipier et le dernier mot du nom d'un autre. Ce comportement n'est
pas modifié ; un complément peut donc s'appeler « … GAC ».

## Vérification de fuite

Après le changement, sur tous les fichiers suivis du dépôt, sans tenir
compte de la casse, des accents ni de la ponctuation :

- **Anciens alias** (8 043 noms distincts relevés dans les registres de
  `96f53704`, qui tiennent lieu de vrais noms pour les joueurs étrangers) :
  **0 occurrence**. Avant le changement : 11 700 occurrences dans 14
  fichiers, tous des registres.
- Morceaux d'alias, mot à mot, hors des dossiers de recherche : aucun. Les
  mots communs aux deux listes sont des mots courants.
- Les deux contrôleurs du dépôt privé passent sans écart sur les noms relus
  dans les registres recompilés.
- **Vrais noms français** (2 062 noms du dépôt privé) : 21 194 occurrences
  dans 64 fichiers, **inchangées par cette PR**. Aucune n'est dans la base du
  jeu. Elles sont dans les sources de recherche décrites ci-dessous.

`tests/base-names-leak.cjs` rejoue ce contrôle à chaque exécution, sans rien
écrire : il relit les 1 592 joueurs et 471 staffs réels de la base française
dans les sources de recherche du dépôt, puis vérifie que les 116 clubs
composés (5 878 joueurs et 6 anciens identifiants), les 2 160 staffs de
l'édition Champ, la base commune et le registre du staff français ne portent
ni un vrai nom complet ni un vrai patronyme, que chaque nom affiché vient des
tables de `data/names/`, et qu'aucun fichier livré avec le jeu (dossier
`native/`, modules du moteur chargés depuis `dist/`) ne cite un vrai nom.

Une seule exception, hors des registres : le journaliste `fiction-1` de
`dist/press-question-bank.js` porte le nom d'un joueur réel de la base
française. Ce fichier est repris par la PR #553 ; le test tolère cet
homonyme et seulement lui, en attendant qu'il soit renommé.

## Ce qui reste réel

Hors du périmètre de cette PR, à traiter par les étapes suivantes du plan :

- **Sources de recherche à identités réelles**, toujours dans le dépôt
  public : `modding/` (39 fichiers), `data/scouting/review-v12/`,
  `data/roster-foundation/`, `data/staff/verified.json`,
  `dist/lnr-rosters-data.js`, `dist/lnr05-enriched-data.js` (adresses de
  profils), neuf rapports de `docs/` et sept tests. Les compilateurs de la
  base commune et du staff français les lisent encore pour les profils
  sportifs ; ils n'en tirent plus aucun nom.
- **Journalistes** : dix journalistes réels dans
  `dist/press-question-bank.js`, traités par la PR #553.
- **Clubs** : clés et identifiants de clubs réels (`toulouse`, `racing-92`,
  `prem:bath`, `urc:leinster`, `srp:blues`…), noms de jeu bâtis sur une ville
  réelle pour les 30 clubs français, 14 noms de clubs réels dans
  `dist/saves.js`, table de correspondance `world-data/mapping01/`.
- **Stades** : stades réels des 30 clubs français dans les registres, et
  fichiers de lieux `prem-urc-venues`, `jlo-venues`, `srp-venues`,
  `epcr-pool-venues`.
- **Compétitions** : « Super Rugby Pacific », « Japan Rugby League One »,
  « Nationale », « Champ Rugby », « PREM », « United Rugby », coupes
  européennes et compétitions internationales ; calendriers publiés et
  palmarès de `club-history.json`.
- **Profils** : club, poste, âge, date de naissance et notes restent ceux du
  joueur réel. Un nom inventé retire le nom, pas la ressemblance.
- **Noms tirés au sort** (jeunes, joueurs libres, staffs de complément) : ils
  viennent de viviers de prénoms et de patronymes courants. Sur les 832
  combinaisons du vivier générique (`dist/world-data.js`, jeunes du centre de
  formation), 4 sont le nom d'un joueur réel de la base ; 2 des 144
  combinaisons du vivier des clubs formateurs
  (`dist/espoirs-strategy-v95-v100.js`) aussi. Les changer modifie les noms
  tirés pour toutes les carrières : c'est une étape à part.
- **Historique Git** : les anciens alias et les vrais noms y restent
  lisibles. Leur effacement est reporté.

## Fichiers régénérés

| Fichier | Pourquoi |
| --- | --- |
| `dist/rugby-common-rosters.js` | 1 592 noms ; nouvelle entrée `sources` pour le fichier de noms |
| `native/engine/staff-registry.json` | 428 noms |
| `data/world/foreign-inputs.json` | champ `alias` de 1 616 entrées |
| `native/engine/world-registry.json` | 3 208 noms ; `baselinePlayersSha256` et `inputHashes.foreignInputs` suivent leurs sources |
| quatre `world-*-extension.json`, `world-legacy-aliases.json` | noms, par identifiant |
| `world-staff-registry.json`, quatre `world-*-staff-extension.json` | noms, par identifiant |

`dist/rugby-roster-foundation.js` ne change pas. Aucune fixture de test ne
figeait un nom ou une empreinte de ces registres.

## Limites

- Les viviers ont été écrits de mémoire ; ceux du Japon, des Fidji, des
  Tonga, des Samoa et de la Géorgie restent à faire relire. Une révision des
  noms se fera par une nouvelle version des fichiers de `data/names/` ; les
  carrières commencées garderont leurs noms.
- Les vrais noms des joueurs étrangers ne sont dans aucun dépôt : le contrôle
  du mode Monde raisonne sur les anciens alias.
- `scripts/build-world-identity-pack.py` n'a pas été rejoué de bout en bout :
  il demande le manifeste privé du pack. Sa partie staff a été exercée avec
  un manifeste factice.
