# Couleurs sémantiques et densité du classement — 8 novembre 2026

Le Bureau affiche désormais les sept colonnes `# / Club / J / V / N / D / Pts`. Les deux classements utilisent les mêmes badges : victoire verte, nul ambre, défaite rouge. Lettres, en-têtes, légende visible et descriptions accessibles complètent la couleur. Le club courant garde son repère géométrique et son accent.

## Palette et primitives

| Sens | Encre | Fond opaque | Contraste texte/fond |
| --- | --- | --- | ---: |
| Victoire | `#24583B` | `#DFEBDF` | 6,74:1 |
| Nul | `#77520B` | `#F3E5B9` | 5,58:1 |
| Défaite | `#8A342F` | `#F2DED8` | 6,21:1 |
| Inconnu | `#5D5952` | `#E8E1D6` | 5,36:1 |

`ui/data_semantics.gd` centralise `palette`, `badge`, `count_badge`, `outcome_badge`, `recent_form` et `legend`. Le rôle vient de l'appelant ; aucun seuil financier ni règle sportive n'est déduit d'une couleur. Les fonds opaques conservent le contraste lorsque le parent est sélectionné, survolé ou pressé. Les neutres du Bureau sont alignés sur la coque : papier `#F0F1EC`, encre `#20282C`, texte secondaire `#5F6A6E`, filets `#CCD2D0`.

## Données et densité

Les cellules lisent les champs publics `rank`, `played`, `won`, `drawn`, `lost`, `pf`, `pa`, `points`. Les valeurs connues restent identiques, y compris les points négatifs. Une valeur absente ou invalide donne `—`, jamais un zéro inventé. La différence affiche seulement la soustraction des PF/PA connus déjà projetés.

La forme consomme `club.form`, liste chronologique de résultats V/N/D de championnat. Elle conserve les six derniers éléments, leur ordre et les positions inconnues. Une liste courte reste courte. Sans résultat conservé, un seul tiret apparaît.

Le classement adapte sa capacité à la hauteur réellement disponible, sans reconstruire l'application lors d'un redimensionnement. Les divisions de quatorze et seize clubs sont reçues entières en 1920×1080 et 2560×1440. En 1280×720, huit lignes tiennent et la pagination reste accessible au clavier. Aucun ordre de compétition ou total de points n'est recalculé.

À partir de 1380 px de largeur disponible, la table est bornée à 1040 px et un panneau latéral présente notre club : identité, division, rang, points, matchs joués, PF/PA, bilan V/N/D et forme. Ces valeurs viennent de sa ligne dans `model.leagues[].rows[]`, avec repli sur le club public et `—` pour les champs absents. Aucun historique individuel ni avis n'est inventé.

## Vérifications exécutées

SDK Godot Windows 4.7.2, profils explicites sur E:, copie externe figée des scripts. Aucun profil personnel utilisé. Les essais n'ont pas exporté de nouvel EXE et ne constituent pas un benchmark.

| Contrôle | Résultat reçu |
| --- | --- |
| Fixtures des vrais constructeurs UI, quatre formats de 720p à 1440p, Node 22.23.4 et Node 26.13.0 | 53 053 contrôles, zéro échec pour chaque version |
| Vraies pages avec worker, Node 22, affichage Windows | 1 102 contrôles, zéro échec ; onze PNG |
| Vraies pages avec worker, Node 26, headless | 1 091 contrôles, zéro échec |
| Témoin Bureau renforcé, Node 22 puis Node 26, headless | 751 contrôles, zéro échec pour chaque version |

Les oracles vérifient les compteurs connus dans les deux tableaux, les points négatifs, les champs manquants, la forme courte/inconnue, les contrastes sur plusieurs accents et états du parent, la géométrie des lignes et du nom du club, les deux divisions, la pagination/focus, les liens du Bureau et la densité PC native. Le témoin Bureau a été adapté de six à sept colonnes et aux labels contenus dans les badges ; ses contrôles ont été conservés.

Sur les vraies pages, la consultation et la navigation ne produisent aucune requête métier. La projection complète, l'export complet incluant S/RNG et les empreintes de tous les fichiers JSON du profil restent identiques après le préchauffage initial des conseils. La fixture isolée vérifie aussi l'absence de tirage du RNG UI et l'intégrité d'un fichier de profil témoin.

Commande ciblée courante, après définition de `CD_GODOT_EXE` ou `CD_GODOT_EXECUTABLE` :

```powershell
node --test tests/godot-data-semantics.cjs
```

Pour la réception graphique, ajouter `CD_SEMANTIC_GRAPHICS=1` et un répertoire explicite `CD_SEMANTIC_TEMP`. Les variables `CD_SEMANTIC_PROJECT` et `CD_SEMANTIC_SCRIPT` permettent de viser une copie figée. `CD_SEMANTIC_PROOF` dirige la preuve isolée ; chaque vraie réception crée son propre profil sous le répertoire temporaire choisi.

## Finition éditoriale du Bureau

Les colonnes latérales sont des piles de tuiles distinctes : accès au carnet, contrats proches, préparation de la semaine, journal, cap sportif, moyens et préparation de match. Le fond sombre reste visible entre les tuiles et sous leur contenu. Les titres ont été contenus à 24 px ; la photo du prochain rendez-vous reste la seule grande image du Bureau. L'action calendrier demeure dans la chronologie centrale, sans répéter un second rendez-vous dans les décisions.

La tuile contrats montre trois premières échéances au maximum, triées sur le vrai `contractEnd`, puis l'ID pour un ordre stable. Portrait, nom et saison viennent des joueurs publics. Chaque ligne ouvre sa fiche par son ID ; aucune prolongation n'est commandée par cette vue.

Deux vignettes de 110 px servent de repères du club : ville et stade, libellés issus de `club.presentation`, images déjà présentes dans `assets/club-atlas`. Une identité absente donne `—` et une surface sobre ; aucune photo d'un autre club n'est substituée. Les légendes longues sont bornées à deux lignes et restent disponibles dans les infobulles. Aucun téléchargement ni nouvel asset.

Le comportement compact de 720p conserve les mêmes nœuds et déplace le cap sportif dans la colonne de lecture, avant le journal. Les actions, le défilement, les fiches des cinq joueurs et les nouveaux liens contractuels sont reçus par le témoin existant, sans réduire ses contrôles.

Réception graphique finale du Bureau : `graphics/cd-semantic-app-xZBn5R/bureau-2560.png`, `bureau-1280.png` et `bureau-1280-cap.png`, regardées. Les grandes colonnes claires vides de la capture S1 ont disparu. Les cartes de décisions et leurs trois échéances sont distinctes, les petites photos restent secondaires et le classement conserve ses sept colonnes. Le vide résiduel sous le contenu est sombre ; aucun remplissage par des statistiques répétées ou un historique inventé.

Le témoin Bureau final passe **751 contrôles / zéro échec** sous Node 22.23.4 et Node 26.13.0, notamment les surfaces limitées à leur contenu, les vrais IDs, l'identité manquante sans photo substituée, les quatre tailles jusqu'à 2560×1440, les variantes de palette, le match réel et la pureté des actions. Logs : `witness-office-final22/run.log` et `witness-office-node26/run.log`. La réception réelle Windows des pages conserve **1 102 contrôles / zéro échec**, avec projection/export S-RNG et tous les JSON du profil inchangés. Ce passage précède seulement le dernier garde-fou de valeur nulle, dont le rendu nominal est identique et qui est reçu en headless sur les deux versions.

## Preuves et critique visuelle

Racine externe : `E:/Cadrage-Debordement/artefacts/native06-20261108/da-colors-integration/`.

- `graphics/cd-semantic-app-nYfbkd/` : réception des classements, notamment `classements-1280.png`, `classements-2560.png`, `classements-1920-accession.png` ; ses captures Bureau précèdent la dernière finition.
- `graphics/cd-semantic-app-xZBn5R/` : réception du Bureau final, notamment `bureau-1280.png`, `bureau-1280-cap.png` et `bureau-2560.png`.
- `graphics/run.log`, `headless26/run.log`, `unit22/run.log`, `unit26/run.log`, `witness/run.log`, `witness26/run.log` : sorties réellement exécutées.
- `frozen-source-manifest.json` et `integrated-files.sha256.json` : empreintes des scripts reçus et des chemins livrés.
- `run-reception.cjs` : reproduction externe ; modes `freeze`, `graphics`, `headless26`, `unit22`, `unit26`, `witness26`.

Les captures réelles ont été regardées. Les badges restent lisibles dans les deux formats ; les légendes et le repère du club sont visibles. Les quatorze/seize lignes et le panneau latéral tiennent en 1080p/1440p. Un repli du nom de club lettre par lettre, découvert sur la première capture du panneau, a été corrigé puis reçu de nouveau ; son oracle de largeur/hauteur est conservé.

Le fond de la table garde du vide sous les quatorze lignes en 1440p. Le Bureau utilise désormais des cartes limitées à leur contenu, sur le fond sombre commun. Le vide restant en 1440p est un espace de travail sombre ; il ne prolonge plus les surfaces claires jusqu’au bas de la fenêtre. La fixture réelle utilise une carrière neuve : les zéros et l'absence de forme sont réels. Les résultats V/N/D non nuls sont couverts par des fixtures explicites, sans simuler une saison ni inventer des matchs.

Aucun moteur, format de sauvegarde, règle de compétition, thème global ou shell n'est modifié par ce lot. La CI distante, le commit et l'intégration finale restent à réaliser par l'intégrateur.
