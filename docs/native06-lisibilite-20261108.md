# Lisibilité et densité du carnet natif — lot 0.6

La consigne prioritaire de Léo pendant le lot est de réduire les écritures sur tous les écrans et de rendre les actions accessibles sans descendre dans la page. Le carnet conserve son identité anthracite, ivoire et couleur du club, ses six rubriques et ses données. Les listes longues utilisent des pages et les dossiers des sous-onglets, sans nouveau menu principal.

## Présentation retenue

La correspondance centrale de `game_skin.gd` ramène les anciennes tailles explicites à une échelle cohérente : corps courant 13–14 pixels logiques, secondaire 12, titres 20–22, grands repères 24. Les anciens très grands titres sont plafonnés à 30 ; le titre du shell est réglé séparément par l'intégrateur. Les boutons courants mesurent 36 pixels de haut, les outils de lecture 34. Les marges standard passent à 12 horizontalement et 8 verticalement. Les couleurs, valeurs et faits ne changent pas.

L'interface utilise une référence native jusqu'à **1920×1080**, au lieu du plafond 1600×900. Les fenêtres 1280×720, 1600×900 et 1920×1080 sont donc à 1:1 ; à 2560×1440, le rapport est 4/3. Ce redimensionnement logique ne constitue pas un test de DPI Windows.

| Vue | Disposition et accès direct |
|---|---|
| Bureau | Cinq tuiles de repères distinctes, hautes de 54 pixels dans le témoin. Deux colonnes à 720p, trois aux formats plus larges. Le feuillet de décisions gagne une largeur utile de 359 pixels à 720p. Le cap sportif et son défilement sont déplacés en place en mode compact, sans reconstruction ni perte de focus. Le titre de contrat est raccourci, les échéances restent explicites. |
| Effectif | Commandes compactes, filtres légendés, pagination calculée sur la hauteur disponible. Le même champ de recherche reste vivant pendant les changements de page et de taille. La fixture et le shell courant présentent 4, 7 puis 11 joueurs entiers aux références 720, 900 et 1080. |
| Dossier joueur | Identité et trois valeurs en tête, puis **Aperçu / Attributs / Contrat / Repères**. Comparaison dans Aperçu ; prolongation et charge individuelle dans Contrat. Les commandes sont visibles directement à 720p. Les références longues gardent un défilement local de lecture. |
| Recrutement | **Pistes / Travail du staff** séparent les cartes et la réunion existante. Pages de 2, 4 ou 6 joueurs selon la hauteur, avec âge, niveau, salaire demandé et actions sur une fiche compacte. Suivre et Proposer un contrat sont entièrement visibles. Les missions et rapports restent dans Travail du staff. |
| Composition | Terrain minimal de 360 au lieu de 420 pixels, portraits adaptés et cartes distinctes ; quinze postes et banc conservés. |
| Calendrier, classement, flux | Pages de 5, 6 et 6 entrées. Ces capacités stables conservent les bornes lors d'un redimensionnement. Le journal financier précise que ses totaux concernent toutes les pages et les mêmes écritures. Le lien des contrats est fixé sous le feuillet financier. |
| Création et accueil | Marque plus compacte, nom de club enveloppé ; création par huit tuiles sur deux colonnes, pagination et validation directement visibles. |

Les sélections papier conservent leur barre géométrique dans les états normal, survolé et appuyé. La désélection la retire dans les trois états ; le focus garde son contour distinct. Le signal ne repose donc pas sur la seule couleur. Les grands montants peuvent revenir à la ligne sans élargir leur tuile.

La consigne d'immersion reçue ensuite retire les avertissements de fabrication des flux ordinaires : Trésorerie, salaire courant, salaire demandé et paiement à la signature utilisent le vocabulaire du club. La création présente le monde d'Oval Legacy 27. Le calendrier financier conserve son nombre réel de semaines payées dans la carrière. Les références officielles, estimations et dates restent dans Repères ; les crédits et cette documentation conservent l'explication des données de simulation.

## Vérifications réellement exécutées

Le témoin `tests/godot-readability06.cjs` fige les scripts dans un projet temporaire, utilise le vrai worker et un profil jetable, puis contrôle les quatre tailles. **293 contrôles réussis, zéro échec sur la dernière exécution** : huit vues sans défilement global, pages affichées de calendrier/classement/flux sans défilement local, actions de recrutement et d'entraînement visibles, actions du dossier dans leur onglet, huit tuiles de création et validation, accès à tous les joueurs par pagination clavier, recherche Unicode, caret, sélection, confirmation et brouillon d'offre sur les mêmes instances. Les octets du profil et l'export complet, RNG compris, restent identiques après la lecture. Rapport final figé : `E:/Cadrage-Debordement/artefacts/native06-20261108/cd-readability06-P1cTwX/report.json`.

Suites complémentaires exécutées : Carnet **1 892**, Gestion **190**, Bureau **517**, Composition **536**, Interface adaptative **813** et Gabi contextuel **176** contrôles réussis, zéro échec. Les anciens parcours ouvrent le vrai onglet Contrat et recherchent un candidat hors page par MarketSearch. Les assertions métier et de focus sont conservées ; l'ancienne attente de défilement devient conservation de page et accès clavier. Les références physiques utilisent désormais 1920×1080, avec un cas 2560×1440. Ces preuves ne remplacent pas la réception du binaire final.

La revue croisée a reproduit un rappel `OfficeColumns._adapt` après retrait du root : `get_viewport()` n'existait plus. La reproduction dédiée a d'abord échoué, puis passe avec une garde de cycle de vie avant tout accès. Les rappels différés et signaux tardifs d'un Bureau sorti de l'arbre sont ignorés ; le test Gabi contextuel conserve son refus strict des erreurs de script.

Commande headless du témoin sous PowerShell, après chargement de l'environnement de recette :

```powershell
$env:CD_GODOT_EXECUTABLE=$env:CD_GODOT_EXE
$env:CD_READABILITY06_TEMP='E:/Cadrage-Debordement/artefacts/native06-20261108'
node --test --test-concurrency=1 tests/godot-readability06.cjs
```

Le nouveau wrapper isole APPDATA, LOCALAPPDATA, TEMP, profil, logs et manifeste sur son répertoire de preuve. Pour les anciens wrappers, il faut aussi rediriger explicitement APPDATA et LOCALAPPDATA sur E: : le script d'environnement général ne le fait pas.

## Réception graphique et DPI restant à recevoir

Ces preuves sont headless. Aucune nouvelle capture GPU, réception du vrai EXE, qualité visuelle finale, échelle Windows 125/150 %, 4K ou ultrawide n'est annoncée reçue par ce lot.

L'intégrateur peut définir `CD_READABILITY06_GRAPHICS=1` pour produire les captures comparables Bureau, Effectif, Finances, huit vues denses, création, focus et offre de contrat aux quatre tailles. Inspecter aussi les quatre onglets du dossier, Travail du staff, les derniers joueurs par pagination, les noms longs et les couleurs extrêmes. Les références lues sont les captures du vrai candidat02 déplacé, notamment Bureau/Effectif/Finances à 1280×720 ; elles ne sont pas attribuées à une nouvelle build.

Pour recevoir 125/150 % sans toucher le bureau de Léo : utiliser une session ou machine Windows de recette déjà configurée, relever l'échelle effective avant lancement, puis les dimensions physiques et logiques ainsi que les DPI et l'échelle déclarés par Godot. Le harnais les enregistre en mode graphique tout en laissant `real_dpi_tested=false` tant que cette réception séparée n'est pas documentée. Un viewport différent n'est jamais une simulation du DPI réel.

Aucune règle sportive, donnée de joueur, économie centrale ou format de sauvegarde n'est modifié. Les longues références et certains dossiers secondaires peuvent conserver un défilement local de lecture ; l'absence de tout défilement pour un contenu arbitrairement long n'est pas revendiquée.
