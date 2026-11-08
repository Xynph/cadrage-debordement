# Densité PC du carnet natif — lot 0.6

La décision de Léo du 8 novembre privilégie un écran de gestion PC : davantage de lignes et de tuiles factuelles, des textes plus petits et une vraie surface native sur son écran2560×1440. Le carnet conserve ses six rubriques, son identité anthracite/ivoire/couleur du club et les mêmes faits du moteur.

## Échelle et présentation courantes

Les styles partagés ont été raccordés séparément : corps12, petits labels11, titres16–20, métriques20, boutons et outils28 ; paddings de l’ordre de8×4. Le shell réduit aussi son empreinte. La référence suit maintenant les dimensions physiques de la fenêtre, **sans plafond1920×1080** :1280×720,1600×900,1920×1080 et2560×1440 restent à1:1. Cela ne constitue pas une simulation du DPI Windows.

### Effectif

Le tableau utilise des lignes26pixels et un intervalle2pixels. Filtres légendés, recherche, tri, comparateur et pagination restent accessibles ; la capacité est calculée sur le vrai viewport disponible. Le champ de recherche, son caret, sa sélection et son focus restent vivants pendant les changements de page et de taille.

Les colonnes s’ajoutent selon la largeur réellement disponible : nom, poste, âge, niveau, condition, puis salaire courant par semaine/échéance, minutes/apparitions/charge et enfin potentiel/note au poste/sélection. Le grand tableau donne davantage de largeur au poste et conserve les noms complets lorsque la place le permet ; chaque ligne et chaque valeur tronquée gardent leur texte complet en infobulle. Le salaire est celui du modèle courant, pas un montant estimé par l’UI. «S3» désigne une saison de carrière.

| Fenêtre physique | Lignes entièrement visibles dans la fixture | Hauteur de liste |
|---|---:|---:|
|1280×720|10|294|
|1600×900|16|466|
|1920×1080|23|646|
|2560×1440|36|1006|

Les minima de réception sont9lignes en720p,20en1080p et28en1440p. La répartition courante donne environ56% au tableau et44% au dossier.

### Dossier joueur

Le nom mesure18pixels, le portrait48. Les quatre onglets restent **Aperçu / Attributs / Contrat / Repères**, avec Contrat à l’indice2. L’aperçu comporte six vrais panneaux, répartis sur **deux colonnes indépendantes à hauteurs naturelles**, sans étirer artificiellement les cartes :

- Situation et préparation : condition, charge, statut de sélection et charge individuelle prévue.
- Contrat courant : libellé et salaire exacts, disponibilité de prolongation et durée possible si le modèle la fournit.
- Usage en saison : minutes, apparitions, numéro et note au poste.
- Évaluation : niveau et potentiel déjà projetés.
- Profil de jeu : les onze attributs avec petits chiffres/barres et radar compact. Les valeurs proviennent directement du modèle ; aucune statistique supposée n’est créée.
- Postes : les postes conservés dans la référence de départ ; origine et détails restent dans Repères. Une note personnelle n’apparaît que si une entrée projetée existe déjà pour l’ID courant. Son aperçu est borné à quatre lignes avec texte complet en infobulle.

Les actions de note et de comparaison restent sur une ligne de28pixels sous ces faits. La prolongation et la charge demeurent dans Contrat. Attributs et Repères conservent les lectures détaillées et leur défilement local si nécessaire. La fiche courante mesure536pixels utiles dans la fixture ; elle s’ajuste au contenu et au budget du viewport, sans réserver une grande surface ivoire vide. Les noms, notes et données ne sont pas interprétés en BBCode.

Le redimensionnement est porté par le ScrollContainer propre à chaque dossier, et ses appels différés utilisent des WeakRef. Un dossier remplacé ne conserve donc aucun rappel vers ses anciens widgets. La pagination, la recherche, la sélection et les popups gardent leurs instances/brouillons pendant les changements de taille.

## Quatre panneaux de contexte desktop

À partir de1000pixels de hauteur, une grille2×2 apparaît sous les six panneaux de faits, avec des hauteurs naturelles et des commandes visibles. Les fenêtres720/900 restent compactes. Les nœuds s’adaptent au seul changement de hauteur, même avec un brouillon de carnet ouvert.

- **Concurrence au poste** : niveau, condition, âge et salaire sont comparés aux moyennes de tout l’effectif projeté, explicitement étiquetées «Joueur / moyenne de l’effectif». Jusqu’à cinq coéquipiers au même poste principal ouvrent le vrai comparateur avec deux IDs. Trois sont visibles aux hauteurs intermédiaires, cinq en1440p. Aucune couverture ni aptitude secondaire n’est supposée.
- **Développement** : orientation, niveau général au début de saison et écart actuel, puis deux vrais bilans annuels au maximum. Le niveau général et la note au poste restent distincts. À vide : «Premier bilan annuel à venir». Aucune courbe passée n’est créée.
- **Forme & prestations** : disponibilité et condition/charge actuelles ; minutes par apparition uniquement si le nombre d’apparitions est positif. Zéro minute et zéro apparition donnent «Première apparition à venir». Aucune série fictive de cinq matchs ou note individuelle de rencontre.
- **Staff & carnet** : consigne collective explicitement nommée, éventuel avis individuel archivé et daté par ID, puis note personnelle. Le conseil de groupe ne devient pas une opinion individuelle. Le même aperçu est déplacé depuis Postes, sans duplication entre joueurs ni reconstruction du brouillon.

Ces panneaux utilisent les projecteurs existants de développement, entraînement, recrutement et carnet. Aucun champ de carrière ni stockage supplémentaire. Le dossier compact mesure536pixels utiles dans la fixture, puis environ900à1080p et934à1440p avec les quatre contextes.

## Autres vues et immersion

Le Bureau conserve ses cinq tuiles de repères et ses deux/trois colonnes ; le cap sportif est déplacé en place avec son focus. Composition garde quinze postes et le banc. Recrutement sépare Pistes/Travail du staff. Calendrier, classements et flux restent paginés. Création conserve ses tuiles, sa pagination et son action principale visibles. Les sélections papier gardent leur repère dans les états normal, survolé et appuyé et leur contour de focus distinct.

Le vocabulaire courant présente Trésorerie, salaire et le monde d’Oval Legacy27. Les références officielles, estimations, dates et limites restent accessibles dans Repères/crédits/documentation. Le calendrier financier conserve son nombre réel de semaines payées. Aucun changement de règle, d’économie, de joueur ou de format de sauvegarde n’est introduit par cette présentation.

## Réception et preuves

`tests/godot-readability06.cjs` fige le projet et les scripts, isole tous les profils/APPDATA/LOCALAPPDATA/TEMP surE, puis vérifie le parsing avant de lancer le vrai shell/worker. Son timeout d’exécution reste inchangé. Les erreurs de script restent strictement refusées.

La recette contrôle les quatre références physiques, les lignes réellement contenues, les colonnes, les six panneaux et la source exacte des chiffres/barres/contrat/salaire. Elle vérifie aussi les actions dans les vrais viewports imbriqués, les pages sans défilement global, la pagination clavier, la recherche Unicode/caret/sélection, le changement de joueur puis resize, et les brouillons d’offre et de carnet sur les mêmes fenêtres. Une note fictive est enregistrée dans le profil de fixture avant le point de comparaison ; sa projection est reçue uniquement pour son ID. Après cette préparation, les octets du profil et l’export/RNG restent exacts pendant la lecture.

La première réception de densité était réellement rouge :5/13/20lignes aux formats720/1080/1440, lignes40pixels et absence des tuiles/colonnes. Le premier design à six résumés sur trois colonnes a ensuite été vu en capture1440 et rejeté pour son grand vide à droite. Le nouveau scénario changement de joueur/resize a aussi reproduit les anciennes captures libérées dans les callbacks ; ce résultat n’a pas été compté comme vert. Les rapports du lot conservent les chemins de ces preuves et des validations finales.

La réception finale compte **650 contrôles headless, zéro échec**, avec les lignes10/16/23/36, les onze chiffres/barres, les quatre contextes, les moyennes, le comparateur aux deux IDs, les notes et les brouillons : `E:/Cadrage-Debordement/temp/cd-readability06-o75nGj/report.json`. La capture SDK Windows native2560×1440 a été produite et inspectée : `E:/Cadrage-Debordement/temp/pc-profile-v3-0f953b53/effectif-pc-2560-preview.png`. Détail des RED/GREEN et limites dans `densite-pc-profile.md`, dans le dossier d’artefacts du lot hors dépôt.

Commandes, après chargement de `E:/Cadrage-Debordement/environnement.ps1` et `CD_GODOT_EXECUTABLE=CD_GODOT_EXE` :

```text
node --test --test-concurrency=1 tests/godot-readability06.cjs
```

`CD_READABILITY06_GRAPHICS=1` active le SDK Windows graphique. `CD_READABILITY06_CAPTURE=effectif-2560` ne garde que cette image ; aucun contrôle ni taille ne sont retirés. Les campagnes GPU/CPU et la réception du candidat déplacé sont sérialisées par l’intégrateur.

## Historique utile et limites

La première version du lot utilisait une référence plafonnée1920 et des listes4/7/11lignes ; ces choix sont remplacés par la décision PC. Le défaut antérieur de dossier248pixels, avec comparaison coupée et476pixels inutilisés, avait été reproduit12fois puis corrigé. L’oracle insuffisant qui ne regardait que le scroll extérieur a été renforcé pour les viewports intérieurs.

Une capture SDK Windows n’est pas une réception du binaire exporté. Le DPI réel125/150%, la4K et l’ultrawide restent des réceptions distinctes. Les longues références ou certains dossiers secondaires peuvent défiler localement ; aucune absence de tout défilement pour des textes arbitraires n’est promise. Aucun ancien enregistrement Gabi n’est substitué à un texte réécrit. Le parent garde la version, le journal de développement, le candidat EXE et la publication.
