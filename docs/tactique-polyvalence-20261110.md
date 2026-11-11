# Tactique : aptitude au maillot et affectations directes

Base reçue : `d175323`. Conception approuvée par l'intégrateur : conserver les
trois colonnes de la Tactique existante (XV, identité, banc et joueur).

La note est la projection `positionRatings[str(positionNumber)]` du joueur
consulté au poste choisi. La condition reste une donnée distincte ; l'interface
n'invente aucun second malus. `selection.slots[].eligibleIds` est la seule
autorité d'affectation, notamment pour les qualifications de première ligne.

Dernière instruction de présentation : Banc et Hors groupe sont simultanément
visibles juste à droite du terrain ; Identité de jeu est la colonne droite.
Le terrain garde `Rect2(280,264,1070,906)`, le banc occupe
`Rect2(1366,264,598,529)`, Hors groupe `Rect2(1366,809,598,361)` et Identité
`Rect2(1980,264,548,906)`. Les quatre tuiles inférieures restent présentes.

Les cartes du terrain exposent le portrait existant, le numéro et la note
au poste, avec une surface rectangulaire entière pour les déplacements.
Hors groupe est la différence exacte de l'effectif et de tous les IDs du XV
et du banc. Sa liste défile dans sa tuile, garde son en-tête et affiche la
note à la cible explicitement nommée. Le banc conserve huit places et les
opérations par clic et clavier. Aucun nouvel écran n'est créé. L'ancien
projet d'onglets alternés et de carte Joueur sélectionné est abandonné.

Le glisser-déposer utilise une seule commande `set_lineup`, comme le choix
classique. Le moteur décide l'échange ou le refus. Une source périmée, étrangère
au club, une cible non éligible, un match engagé ou une commande en attente
ne permet aucune affectation. Annuler un glisser ne modifie rien.

Approches : modifier les positions localement aurait contourné les validations ;
une nouvelle page aurait cassé le cadre demandé. L'approche retenue étend les
boutons et les données de la page actuelle avec un module de sélection dédié.

## Plan d'implémentation

- [x] Banc de réception sur la vraie application et scénarios de refus avant
  l'implémentation ; vérifier les échecs attendus.
- [x] Module dédié : lecture stricte des notes/projections, contrôle des sources
  et cibles, classes de boutons glissables et aperçu de déplacement.
- [x] Raccord de la page existante : portraits, notes aux quinze postes,
  banc et Hors groupe simultanés à en-têtes fixes, Identité à droite.
- [x] Réception : même joueur à son poste puis au n°10, clic/clavier, affectation
  réelle, échange, refus première ligne, annulation et absence de doublons.
- [x] Capture réelle 2560×1440 sur cache privé, preuves et passation GitHub.

## Risques à vérifier

Une note absente doit rester « — » ; elle ne doit pas devenir la note du poste
principal. Les notes à zéro doivent rester visibles. Un ID obsolète ou inconnu
doit être refusé sans commande. Les consultations et annulations conservent
l'export et le profil. Le défilement de l'effectif reste dans sa carte. La
projection du banc doit fournir son numéro d'aptitude : aucun numéro 16–23
n'est interprété comme un poste de terrain.

## Réception intermédiaire du cadrage

Avec la projection moteur `c45557e`, la vraie application X11 2560×1440 passe
**192 contrôles**, dont les 105 paires de rectangles du terrain sans intersection,
les quinze portraits chargés et leurs notes projetées, la partition exacte des
trois groupes, le choix de la cible au clavier et l'absence d'écriture sportive
lors de la consultation. Les notes au n° 10 chutent fortement pour un pilier
selon le moteur. Cette réception de présentation ne valide pas encore les
déplacements et effets sportifs du second commit Simulation.

[Capture réelle du cadrage avec notes](tactique-polyvalence-20261110/tactique-portraits-horsgroupe-1440.png).
[Rapport](tactique-polyvalence-20261110/cadrage-report.json).

Le mode `CD_TACTICS_DRAG_PREVIEW=1` arrête le banc après la consultation ;
le banc complet garde les scénarios de vrais glissers, annulation et affectation.

## Réception des parcours après reprise

Le banc complet passe **397 contrôles sans échec** sur la vraie application :
glisser souris terrain vers terrain, banc vers terrain et Hors groupe vers
terrain, annulation réelle par Échap, refus des IDs périmés/inconnus/étrangers,
partition après chaque affectation, clavier, liste complète et en-têtes fixes.
Une vraie commande en attente verrouille le déplacement ; un vrai match lancé
verrouille le glisser-déposer, la sélection du staff, les candidats et Libérer.

Le dialogue de choix du poste conserve les Consignes individuelles du joueur
actuel. Sa consultation et son annulation gardent le profil identique.
[Rapport des actions](tactique-polyvalence-20261110/actions-report.json).

Le banc historique `godot-immersive08.gd` a aussi été tenté en mode `office`,
mais s'arrête avant Tactique sur les anciennes assertions Effectif demandant
une pagination puis un accès `roster.page` absent (ligne 1116). Il reste hors
cible comme décidé dans la base reçue ; aucune attente de ce banc n'est modifiée
dans ce lot. La réception dédiée ci-dessus exerce le parcours complet.

## Raccord sportif et défense contextualisée

Avec le moteur `2a1f767` reçu après `c45557e`, le banc complet passe
**433 contrôles sans échec** en headless. Il déplace réellement un pilier du
numéro 1 au numéro 10, vérifie la chute d'aptitude affichée, la source vide si
l'échange inverse est interdit, le reçu `meta.lineupChange.vacatedSlot`,
l'absence de doublons et la note principale inchangée.

Le résumé DÉFENSE consomme désormais directement `decisions.lineupDefence`,
entier de 0 à 100 produit par le même dossier contextualisé que le moteur. La
moyenne brute des qualités ne sert que pour une ancienne projection sans ce
champ. Une projection présente mais invalide est affichée « — ». Aucun malus
supplémentaire n'est calculé dans l'interface. Le banc vérifie que la défense
et le dossier changent après le vrai déplacement et que le résumé affiche
exactement la projection reçue.

## Réception graphique finale

**436 contrôles, aucun échec**, vraie application X11 en 2560×1440, Node
22.23.4 et Godot 4.7.2. Les trois captures ont été inspectées. Le pilier choisi
passe de **73 à 13** au numéro 10 ; la place 1 reste à pourvoir puisque le
retour de l'occupant délogé serait illégal. La défense projetée passe de 76
au cadrage initial à 72 après les déplacements de la recette. Le dossier
offensif reflète également le placement. Ces valeurs sont celles du moteur,
sans modification de niveau global ni calcul sportif dans l'interface.

- [Cadrage final et notes par poste](tactique-polyvalence-20261110/tactique-finale-portraits-1440.png).
- [Après affectation depuis Hors groupe](tactique-polyvalence-20261110/tactique-finale-affectation-1440.png).
- [Même pilier au numéro 10](tactique-polyvalence-20261110/tactique-pilier-au10-1440.png).
- [Rapport complet](tactique-polyvalence-20261110/final-report.json).

```sh
DISPLAY=:98 LIBGL_ALWAYS_SOFTWARE=1 LP_NUM_THREADS=2 \
CD_TACTICS_DRAG_GRAPHICS=1 CD_TACTICS_DRAG_OUTPUT=/tmp/oval-tactics-final \
CD_GODOT_EXECUTABLE=/workspace/.cloud-setup/tools/godot472/Godot_v4.7.2-stable_linux.x86_64 \
/workspace/.cloud-setup/tools/node22/bin/node --test tests/godot-tactics-position-drag.cjs
```

Le SDK utilise le cache du worktree privé ; les profils et préférences de la
recette restent dans `/tmp`. Le serveur privé est fermé après réception.
