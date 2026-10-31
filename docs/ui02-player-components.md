# UI-02B — Composants visuels autonomes (31 octobre 2026)

Ce lot part du commit `d3afa283359b13d9e393eb90d305d7411bf638c7` du dépôt GitHub. Il prépare **les vues et interactions**, sans raccorder de nouveau code à la navigation du jeu. UI-01 est en cours de réception par le seul intégrateur (PR #82), UI-02A de projection de données est en attente de revue (PR #81).

## Fichiers nouveaux

- `dist/ui02-player-components.js` : module UMD indépendant acceptant strictement les modèles de données déjà projetés par UI-02A : `renderPlayer`, `renderTable`, `renderComparison`, `bindActions`.
- `dist/ui02-player-components.css` : composants scellés sous `.cd02`, identité bleu nuit/violet, palette claire Tribune conditionnelle, tableaux denses et responsive 1100/760/410 px.
- `tests/ui02-player-components.cjs` : tests DOM HTML échappé, rendu métier fidèlement restitué, onglets, listes vides, actions déléguées/désabonnement, attributs natifs, thèmes et accessibilité structurelle.
- `docs/ui02-player-components.md` : ce plan de raccordement.

## Contrat de données et fonctionnalités

Les structures d'entrée reprennent les propriétés **déjà définies** dans `dist/ui02-player-data.js` de la PR #81 : `playerView`, `tableView` et `comparePlayers`. Les composants n'importent pas ce module : ils peuvent donc rester isolés tant que #81 est ouverte. Lors du raccordement, l'intégrateur injectera les objets de lecture de son choix. Aucune requête ni écriture de sauvegarde, aucun moteur de match appelé, aucun calcul de note, potentiel ou recrutement recréé.

La fiche propose les onglets `Profil`, `Attributs`, `Contrat`, `Progression`. Les 11 attributs conservés par le moteur sont regroupés uniquement visuellement en Conquête, Défense, Jeu et technique, Mental et endurance ; aucune pondération ajoutée. L'historique ne montre que les saisons enregistrées, et affiche un état vide si absent. Salaires et contrats sont présentés comme valeurs fictives du jeu : `contractEnd` signifie un numéro de saison, pas une date calendrier.

Le tableau supporte une sélection de colonnes, les quatre préréglages et des boutons de tri, la recherche et l'ouverture de la fiche. `bindActions(container, callbacks)` délègue les événements au contrôleur qui sera raccordé **ultérieurement**. Les mutations du tableau, des filtres et du modèle restent la responsabilité du raccordement futur ; aucune prétention d'écran immédiatement jouable.

## Sécurité et accessibilité

Toutes les données externes sont échappées dans les contextes texte et attribut HTML : jamais de `onclick` injecté ni d'HTML provenant du nom d'un joueur. Les barres de progression ne reçoivent que des nombres finis bornés à 0–100. Tableaux avec cellules `th` / `scope`, zone tablist / tabpanel, étiquettes des champs, tri `aria-sort`, focus visible, animations réduites. Après intégration, contrôler visuellement et avec clavier/lecteur d'écran, y compris la gestion du focus entre onglets et sur tableaux filtrés.

## Conditions de raccordement

1. Attendre la fusion et la **CI post-fusion** de la PR #82 ou une reprise explicitement autorisée.
2. Faire revoir la PR #81 et UI-02B, puis créer une branche d'intégration UI-02 à partir du nouveau `main`, avec réservations explicites des fichiers de présentation partagés.
3. Insérer les nouveaux scripts/style dans `dist/index.html` **à ce moment-là seulement**, réutiliser les thèmes Système/Tribune/Analyste, construire le contrôleur via `CDUI02Data` + `CDUI02Components`, et raccorder les boutons aux routes du jeu sans perturber la feuille à 23 ni le moteur.
4. Rejouer les CI de PR et de `push`, compatibilité anciennes sauvegardes, V40, V58, campagne multi-clubs et ergonomie Chromium et Windows portable.

**Aucun fichier existant modifié.** Aucun rendu Chromium réel ou Windows natif revendiqué pour ce lot statique. Pas de copie de code, images, polices ni d'assets propriétaires de FM24/FM27.