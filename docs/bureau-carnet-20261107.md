# Bureau « Le carnet du club » — réception du 7 novembre 2026

Le Bureau Godot reprend la maquette v6 approuvée : journal ivoire à gauche, prochain rendez-vous photographique au centre, suite de saison, groupe et résultats ; rail sportif ivoire avec classement de proximité, objectif, confiance, moyens et préparation. DM Sans porte les textes et l’en-tête ouvert ; Barlow Condensed les titres courts. Le logo bitmap approuvé conserve le bouton et le focus du menu.

## Données et fonctions

- Les contrats concernent les échéances jusqu’à la saison suivante ; le lien sélectionne une vraie fiche par ID, où les possibilités de prolongation restent celles du moteur.
- Les postes manquants et erreurs viennent de `selection`, la priorité de préparation de `meta.trained`. Les nouvelles sont les chaînes du modèle : aucun expéditeur ni horaire fictif.
- Le prochain match et quatre rencontres à venir viennent de `next` et `calendar`. Les semaines sont celles de la cadence abstraite du jeu ; aucune date civile n’est inventée. Les résultats sont ceux des rencontres réellement jouées.
- Cinq joueurs de la composition sont montrés, complétés depuis l’effectif si nécessaire, avec condition et blessure. Chaque nom ouvre sa fiche.
- Le classement utilise les lignes déjà ordonnées de la division courante. La fenêtre de huit lignes contient le club même au premier ou au dernier rang ; aucun nouveau départage n’est calculé.
- Objectif, forme, confiance, trésorerie et masse salariale viennent du modèle. Les finances sont fictives ; aucune courbe de rang ni prévision non disponible n’est dessinée.
- Composition, Effectif, Préparation, Calendrier, Classements et Finances sont de vraies navigations. L’action principale réutilise les gardes existantes du direct, des commandes en attente et de l’intersaison.

## Vérification exécutée

SDK Windows natif Godot **4.7.2 stable**, rendu OpenGL sur NVIDIA RTX 4080 SUPER ; Node de l’environnement E:. Profils jetables sous `E:/Cadrage-Debordement/temp`, jamais la carrière personnelle.

```powershell
. E:/Cadrage-Debordement/environnement.ps1
$env:CD_GODOT_EXECUTABLE=$env:CD_GODOT_EXE
node --test tests/godot-office-ui.cjs
$env:CD_OFFICE_GRAPHICS='1'
$env:CD_OFFICE_CAPTURES='E:/Cadrage-Debordement/temp/bureau-carnet-captures'
node --test tests/godot-office-ui.cjs
node --test tests/godot-assets.cjs tests/godot-management.cjs tests/godot-review-regressions.cjs tests/godot-pack-ui.cjs
```

RED observé avant implémentation : dix sections absentes, treize contrôles, sortie 1. GREEN : 330 contrôles natifs, puis 331 avec la capture complémentaire journal/préparation, zéro échec. Quatre suites de non-régression : cinq tests réussis, aucun échec ; elles conservent les erreurs attendues des incidents de disque et transport provoqués.

Vraies carrières : base commune Élite et Accession, France 30, historique fictif 14. Vrais boutons et fiches, poste vidé par commande existante, début/pause/délégation/validation d’un vrai match. Les navigations sont comparées sur l’intégralité de l’état exporté — RNG inclus — et sur les octets de `donnees.json`.

Noms et nouvelles longs, terrain neutre, pack manquant, absence de rencontre et intersaison sont des **copies de projection destinées à la présentation**, pas des situations sportives tirées au hasard ni des sauvegardes altérées importées. Les captures correspondantes portent `projection` dans leur nom.

## Lecture et limites

Captures natives inspectées à **1280×800, 1440×900 et 1920×1080**. Le projet garde sa mise à l’échelle native existante. Les trois colonnes défilent localement et suivent le focus ; les résultats, nouvelles longues ou la fin de la préparation peuvent donc nécessiter ce défilement. Les noms très longs sont tronqués dans les lignes compactes avec nom complet au survol du classement ; les fiches restent accessibles.

Aucune modification du moteur, de l’économie, de la base, du format/import des sauvegardes, du rendu de match, du thème global ou des workflows/gates. Aucun média officiel du pack privé n’est ajouté au dépôt. La CI distante, la revue et la réception du ZIP complet relèvent du lot d’intégration ; cette note ne les présente pas comme déjà achevées.
