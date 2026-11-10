# Bureau : trois priorités expliquées

Chantier Cloud du 10 novembre 2026, sur la chaîne #508/#507. La [PR #511](https://github.com/Xynph/cadrage-debordement/pull/511) réserve ce périmètre.

## Comportement

Le Bureau compact et le Bureau large utilisent maintenant la même projection
`office_priorities.gd`. Les trois décisions affichées dépendent de la situation,
avec numéro, motif lisible, échéance et action. Le texte complet reste disponible
en infobulle et dans le nom accessible lorsque le gabarit abrège une ligne longue.
Le carnet personnel et l’accès à l’entraînement restent accessibles.

L’ordre est explicite et stable : match en cours/résultat, presse obligatoire,
clôture de saison ou feuille invalide, trésorerie négative, absences internationales
confirmées, blessures, échéances de contrat, prochain match, entraînement et
recrutement. Les situations absentes ne créent pas d’alerte. Le contrat le plus
proche est choisi par échéance puis identifiant, pas selon l’ordre du tableau.

Les motifs de feuille proviennent de `selection.errors`. Les échéances reprennent
`contractEnd`, `next.date` ou la date de retour de la projection internationale.
Une trésorerie de jeu négative ouvre les comptes sans ajouter de seuil financier.
Les absences utilisent uniquement `international.availability` quand `clubManaged`
est vrai et `absentCount` positif ; les anciennes projections sans ce champ restent
acceptées. Le parcours ouvre Sélections dans la section `availability`.

Toutes les actions de cette carte sont des consultations. Le résultat conduit au
match ; sa validation reste une décision explicite dans l’écran concerné.
À la fin d’un direct, la priorité actualise son titre et son échéance sans recréer
le bouton ni perdre le focus. Une carrière absente affiche un état vide.

## Réception locale

Node 22.23.4 et Godot 4.7.2 Linux : **87 contrôles réussis sans fenêtre**, sans test
ignoré, sans erreur de script. Le banc ouvre une carrière common via le vrai moteur,
puis reçoit les interfaces à 1280×720, 1920×1080 et 2560×1440. Il teste aussi les
projections d’alerte contrôlées, les contrats de deux échéances et les noms longs.

- Les trois actions sont présentes et accessibles au focus.
- Entrée sur la priorité presse ouvre la vraie Réception.
- Les priorités de trésorerie et de résultat ouvrent leurs écrans.
- Un tick final actualise le titre tout en conservant le focus.
- Les consultations n’envoient aucune commande supplémentaire au moteur.
- L’empreinte du profil sportif reste identique.

[Rapport headless conservé](bureau-priorites-cloud-20261110-report.json).
Les scénarios de projection contrôlée ne constituent pas une simulation de carrière
blessée ou insolvable. Les lois et calculs sportifs ne sont pas modifiés.

```sh
CD_GODOT_EXECUTABLE=/chemin/vers/Godot node --test tests/godot-office-priorities.cjs
```

Pour les captures X11, ajouter `CD_OFFICE_PRIORITIES_GRAPHICS=1` et
`CD_OFFICE_PRIORITIES_OUTPUT=/tmp/recette-bureau`. Le même banc produit une image
pour chaque définition et un rapport JSON. Le profil de recette est créé dans un
autre dossier temporaire, hors de l’application. Préparer les ressources par le
stage du projet et l’import Godot avant exécution.

## Périmètre et intégration

Fichiers de jeu limités à `office.gd`, `office_canvas.gd` et au module dédié.
Aucun moteur, format de sauvegarde ou écran d’un autre chantier n’est modifié.
Les captures graphiques de l’intégration sont centralisées par l’intégrateur.
Aucune nouvelle validation Windows, CI distante verte ou fusion n’est revendiquée.
La CI habituelle ne se déclenche pas sur cette PR empilée visant la branche #508.

Prochaine étape : intégrer le lot à la branche de réception, exécuter le banc en
rendu X11, puis la suite de navigation sur le cumul des six chantiers.
