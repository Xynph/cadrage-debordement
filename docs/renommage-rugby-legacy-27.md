# Renommage en « Rugby Legacy 27 »

Décision de Léo, 10 novembre 2026 : le jeu « Oval Legacy 27 » devient
**Rugby Legacy 27**. Ce document est la référence du renommage : périmètre,
invariants de compatibilité, vérification du nom et étapes restantes.

## Ce qui change (PR du 13 novembre 2026)

| Élément | Avant | Après |
| --- | --- | --- |
| Titre de fenêtre (`project.godot`) | Oval Legacy 27 — Rugby Manager | Rugby Legacy 27 |
| Textes du jeu (accueil, crédits, bulle du logo, panneaux du stade, packs, boîtes de fichiers) | OVAL LEGACY 27 | RUGBY LEGACY 27 |
| Nom proposé à l'export d'une carrière | `Oval-Legacy-27.json` | `Rugby-Legacy-27.json` |
| LISEZ-MOI de la distribution, manifeste de build, README, AGENTS.md, registre des ressources | Oval Legacy | Rugby Legacy |

Le renommage est produit par `node scripts/rename-brand.cjs`. La commande est
**rejouable** : après la fusion d'une branche qui réintroduit l'ancien nom,
la relancer suffit. `tests/brand-name.cjs` échoue tant qu'un ancien nom
subsiste dans le périmètre. Ce lot reprend l'intention de #546 (fermée au tri
du 13/11) en la réduisant aux textes.

## Ce qui ne change pas, volontairement

Aucune carrière ne doit être perdue ni convertie. Ces identifiants sont
techniques et restent identiques :

- **Dépôt, profil, formats** : voir ci-dessous.

## Ce qui a été renommé ensuite (13 novembre, PR logo et exécutable)

- **Logo** : `branding/rugby-legacy-27-logo.png` (lettrage « RUGBY LEGACY 27 /
  CLUB MANAGER », repris de la proposition de la PR #546) remplace
  `oval-legacy-27-logo.png` ; l'icône devient `rugby-legacy-27-icon.png`.
  **Logo PROVISOIRE** en attendant la graphiste.
- **Exécutable et archive** : `RugbyLegacy27.exe`, dossier
  `RugbyLegacy27-PrototypeGodot` et archive
  `RugbyLegacy27-PrototypeGodot-Windows-x64.zip`, dans `ci/`, `scripts/`,
  `windows-release.cfg`, le README et les tests. Les rapports datés d'avant le
  13/11 gardent l'ancien nom (historique).

- **Profil Windows** : `%APPDATA%\CadrageDebordement\PrototypeGodot`. Le jeu
  renommé lit et écrit au même endroit. Il n'y a donc ni copie, ni second
  profil, ni écrasement possible. Le test rouvre une carrière du mode Monde
  créée dans ce dossier et vérifie que ses octets ne changent pas.
- **Format d'export** `cadrage-debordement-save` et **format de calendrier**
  `oval-legacy-fictional-calendar` : les exports et calendriers existants
  restent importables.
- **Dépôt GitHub** `Xynph/cadrage-debordement` : jamais renommé sans décision de Léo.
- **Provenance** des illustrations, sons et voix (`native/godot/art`,
  `native/godot/audio`, `native/godot/guide/assets`) : ces fichiers et leurs
  manifestes décrivent une production passée, parfois avec empreinte.
- **Journal et rapports datés** (`DEVELOPPEMENT.md`, `docs/…-2026MMJJ.md`) :
  ils racontent le projet sous son nom de l'époque.
- **Lanceur web historique** (`offline/`, `CadrageDebordement.exe`) : produit
  distinct, non distribué avec la version native.

### Pourquoi ne pas déplacer le profil maintenant

Un dossier `%APPDATA%\RugbyLegacy27` serait plus cohérent, mais le déplacer
n'apporte rien au joueur et crée trois risques réels : deux profils
concurrents si un ancien exécutable est relancé, une copie à travers la
jonction utilisée sur le PC de développement, et un verrou `profil.lock`
laissé dans l'ancien dossier. Si le déplacement est souhaité avant une
publication, il doit faire l'objet d'une PR séparée : copie au premier
lancement seulement si le nouveau dossier est absent, ancien dossier conservé
intact, message visible, test de non-écrasement.

## Vérification du nom (11 novembre 2026)

Recherches web effectuées : « Rugby Legacy » avec jeu vidéo, Steam, jeu
mobile, Google Play, App Store, itch.io, marque, INPI, EUIPO, USPTO.

- **Aucun jeu vidéo** nommé « Rugby Legacy » n'a été trouvé. Les jeux de
  rugby relevés portent d'autres noms : Rugby 25, Rugby 22, Rugby Manager
  25/26, Rugby Challenge, Rugby League Live.
- L'expression existe hors du jeu vidéo, pour des fonds et programmes
  fédéraux : « USA Rugby Legacy Fund » (annoncé le 29 octobre 2026),
  « Legacy Fund » de New Zealand Rugby, « Community Rugby Legacy Equipment
  Program » de Rugby Australia. Ce ne sont pas des produits concurrents.
- **Limite** : aucune base officielle de marques n'a pu être interrogée
  (TMview refuse la lecture automatisée ; INPI, EUIPO et USPTO n'ont pas été
  consultés directement). L'absence de résultat web ne vaut pas recherche
  d'antériorité.

Risques à connaître avant une publication commerciale :

1. « Rugby » est descriptif et « Legacy » courant : le nom est libre d'usage
   mais **faiblement protégeable**. Un concurrent pourrait choisir un nom
   voisin.
2. Avant une fiche Steam, faire une recherche à l'identique et de similitude
   en classes 9 et 41 sur les bases INPI, EUIPO et USPTO, et vérifier les
   noms de domaine et de boutique.
3. Le nom ne doit pas laisser croire à une licence officielle : ne pas
   l'associer à des logos, compétitions ou fédérations réels.

## Propositions soumises à Léo, non appliquées

- **Renommer le dépôt GitHub** en `Xynph/rugby-legacy-27`. GitHub redirige
  les anciennes adresses, mais cinq workflows et onze scripts de CI contiennent
  le nom exact du dépôt (`github.repository == 'Xynph/cadrage-debordement'`).
  À faire dans une PR dédiée, une fois les PR ouvertes intégrées.
- **Renommer le dossier de travail du PC** `E:\Cadrage-Debordement`. Les
  copies de travail Git, le raccourci du bureau, `environnement.ps1` et la
  jonction du profil contiennent ce chemin en dur. Un renommage manuel les
  casse ; il faut un script qui met à jour ces quatre points ensemble.
