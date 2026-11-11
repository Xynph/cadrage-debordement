# Effectif : tri complet et liste continue

Réception Cloud du 10 novembre 2026, [PR #523](https://github.com/Xynph/cadrage-debordement/pull/523).
Le lot produit ne modifie que `squad_canvas.gd` ; aucun moteur ni état global n’est changé.

## En jeu

Chaque en-tête visible trie dans les deux sens : numéro, joueur, poste, âge,
niveau, potentiel, condition, fatigue, note, salaire, contrat, minutes et statut.
Le motif de surveillance est également triable dans le groupe correspondant.
Le critère actif porte une flèche et une couleur, avec son sens dans le nom
accessible. Clic et Entrée utilisent le même tri et gardent le focus sur l’en-tête.

Les données numériques sont comparées comme nombres, les textes sans distinction
de casse ou d’accents. Les valeurs absentes, non numériques ou non finies sont
placées en dernier dans les deux sens. Les égalités gardent l’ordre stable des
identifiants. Le tri de poste conserve les familles rugby, puis le libellé du
poste : cet ordre est indiqué dans l’infobulle. Le statut d’un blessé correspond
au statut effectivement affiché. La condition reste sa valeur publiée par le moteur.

La liste filtrée est triée intégralement et rendue sans limite ni pagination.
Toutes les lignes sont dans le `ScrollContainer` interne, à 34 px avec séparation
de 2 px. La molette sur la liste fait défiler uniquement les joueurs : filtres,
en-têtes et dossier latéral restent fixes. Début et Fin atteignent les extrémités,
Page haut/bas déplacent le focus d’environ une hauteur de liste. Ces touches ne
changent pas de page ni de données. Le compteur indique l’effectif filtré complet.

## Réception observée

- **104 contrôles sans fenêtre réussis**, avec les cas de valeurs inconnues,
  zéros, égalités, accents, statuts et motifs.
- **107 contrôles graphiques X11 réussis**, exclusivement en 2560×1440, sur une
  vraie carrière créée par le moteur et des cas UI contrôlés identifiés.
- Les treize en-têtes sont cliqués puis inversés au clavier ; leurs flèches suivent.
- Quarante joueurs donnent quarante lignes, au-delà de l’ancienne limite de 24.
- Le dernier joueur source peut venir en tête du tri : aucun sous-ensemble n’est trié.
- La molette et Fin/Début atteignent les lignes tout en gardant le cadre fixe.
- Aucun ordre moteur supplémentaire et empreinte sportive inchangée après consultation.

Les tests de tri global et de surveillance utilisent des projections contrôlées,
jamais écrites dans la carrière. Les deux captures principales retrouvent les
valeurs du vrai modèle avant de photographier le tableau. La troisième capture
locale, nommée `effectif-motif-cas-controle-1440.png`, est explicitement un cas QA.

Captures inspectées : [tri des notes](effectif-tri-colonnes-20261110/effectif-tris-1440.png)
et [dernier joueur atteint](effectif-tri-colonnes-20261110/effectif-dernier-joueur-1440.png).
[Rapport graphique](effectif-tri-colonnes-20261110/report.json) et
[empreintes](effectif-tri-colonnes-20261110/sha256.json).

```sh
CD_GODOT_EXECUTABLE=/chemin/vers/Godot node --test tests/godot-squad-column-sort.cjs
```

Pour X11, ajouter `CD_SQUAD_SORT_GRAPHICS=1` et
`CD_SQUAD_SORT_OUTPUT=/tmp/oval-squad-sort-1440`. Le profil est créé dans un autre
dossier temporaire, hors de l’application. Le serveur privé :94 a été arrêté
après réception. Le banc graphique a duré environ 102 secondes sur rendu logiciel.

## Coordination et suite

Le libellé et les valeurs de salaire n’ont pas été modifiés par ce lot : le
chantier salaire remplace les formateurs et l’intégrateur raccorde le libellé
de colonne. L’entrée vers le dossier de contrats ajoutée dans le cumul est hors
de ce diff et doit être conservée lors de l’intégration.

Prochaine étape : recevoir le cumul avec les autres tableaux continus et le
formateur de salaire. Aucune CI supplémentaire lancée, aucune fusion ni nouvelle
validation Windows revendiquée.
