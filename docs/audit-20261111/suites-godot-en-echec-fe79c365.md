# Audit des 20 suites Godot en échec — Rugby Legacy 27

Date : 2026-11-11. Audit en lecture seule. Version de référence : `fe79c365` (tête publiée de la PR #539), worktree `/home/claude/wt-tests`. Échecs d'origine observés sur `3b42dbf2` (journaux `/home/claude/tests-543-godot-2/logs`).

## Résumé

- Les 20 suites ont été **relancées sur `fe79c365`** (Godot 4.7.2, Linux, Xvfb 2560x1440). **19 échouent encore, 1 passe** (`godot-match-journal`, dont le test a été réécrit entre les deux commits).
- **Aucun échec n'est propre à Linux, au rendu logiciel ou aux polices** : toutes les causes sont dans des dimensions en pixels fixes, des données du moteur ou des noms de nœuds.
- **17 suites sur 20 échouent uniquement parce que le test n'a pas suivi le jeu.** Trois évolutions expliquent presque tout :
  1. les **rendez-vous de club obligatoires** (commit `9f8f77c7`) : tant qu'un rendez-vous est en attente (une conférence de presse l'est dès la création de carrière), le moteur refuse toute commande d'écriture avec « Rendez-vous du club : terminez le rendez-vous du club avant de poursuivre » ;
  2. l'**immersion contextuelle** (conférence de presse en salle 3D, match en direct plein écran) qui remplace les anciens écrans et verrouille la navigation ;
  3. la **connaissance partielle des joueurs** (`d01147c1`, `3c744f9d`) : potentiel publié en fourchette, niveau `null` pour les joueurs non observés.
- **3 suites révèlent un vrai défaut du jeu**, dont un seul notable : le **dialogue d'offre de contrat, large de 1540 px fixes, est rogné sur tout écran de moins de 1568 px de large** (gravité moyenne).
- Aucune de ces 20 suites n'est citée dans `.github/workflows`, `package.json`, `scripts/` ou `ci/` (recherche sur six d'entre elles) : elles ne tournent vraisemblablement pas en CI, ce qui explique qu'elles aient dérivé.

## Tableau récapitulatif

Verdicts : (a) vrai défaut du jeu · (b) test qui n'a pas suivi le jeu · (c) propre à Linux/rendu/polices · (d) indéterminé.

| Suite | Verdict | Échec sur fe79c365 | Gravité | En une phrase |
|---|---|---|---|---|
| `godot-review-regressions` | **a** | oui (1 contrôle au lieu de 2) | moyenne | Dialogue de contrat plus large que la fenêtre en 1440x900 ; l'autre contrôle (défilement de la fiche) passe désormais, test corrigé. |
| `godot-carnet-ui` | **a** + b | oui | moyenne + faible | Même dialogue de contrat ; Calendrier plus haut que la zone visible sous 1440p ; le reste est obsolète (coup d'envoi réservé au jour de match). |
| `godot-fatigue-overview` | **a** + b | oui | faible | Le bouton « Observer la préparation » pousse la page d'entraînement de 16 px hors de l'écran ; le reste vient du rendez-vous obligatoire non traité par le test. |
| `godot-pack-ui` | b (+ a à arbitrer) | oui | faible | La reprise arrive en Réception et non au Bureau ; à noter : `pack_select` est refusé tant qu'un rendez-vous est en attente. |
| `deepen-youth-draft` | b | oui | — | Le test ne traite pas le rendez-vous obligatoire : sa première commande est refusée, tout le reste en découle. |
| `deepen-youth-ui` | b | oui | — | Idem (message moteur confirmé par sonde). |
| `godot-guide-integration` | b | oui | — | `advance_day` refusé : le test répond à la conférence mais ne clôt pas le rendez-vous. |
| `godot-reception-decisions` | b | oui | — | Le courrier ouvre maintenant la salle de presse 3D ; le test attend l'ancien écran « Presse » et son bouton retour. |
| `native-press-ui` | b | oui | — | Même cause. |
| `godot-playbook-watch-ui` | b | oui | — | Pendant un match en direct la navigation est verrouillée ; le test veut ouvrir Plan de jeu et Recrutement. |
| `godot-career-final-fixes` | b | oui (1 sous-test sur 8) | — | Le test pilote l'ancien écran de match (`tab`, `side`) ; le direct est maintenant `contextual/live_view.gd`. |
| `godot-office-ui` | b | oui | — | Le test cherche les nœuds de l'ancien Bureau « carnet » (`office_view.gd`), qui n'est plus affiché en carrière. |
| `godot-squad-column-sort` | b | oui | — | Le test fournit un potentiel chiffré ; le jeu trie sur la fourchette `potentialRange` publiée par le moteur. |
| `godot-portrait-continuity` | b | oui | — | Le test fait `float(rating)` sur des joueurs du marché dont le niveau est `null` (non observés). |
| `godot-academy-portraits` | b | oui | — | Formation s'ouvre sur l'onglet U21 (30 joueurs) ; le test cherche le premier académicien, un U18 de 17 ans. |
| `godot-youth-scout-ui` | b (d sur un point) | oui | — | Le test suppose plus de 20 candidats en détection et des profils « annuels » : la carrière témoin en donne 9 et aucun. |
| `godot-club-memory` | b | oui | — | La phrase « Aucun passé n'est inventé » a été retirée volontairement (`f4e2c2f6`). |
| `godot-regen-portraits` | b | oui | — | L'infobulle « composition locale… non garanties » a été remplacée par le nom du joueur (`f4e2c2f6`). |
| `godot-immersion-copy` | b | oui | — | Le faux hôte du test n'a pas la constante `Immersive` que la Réception lit désormais. |
| `godot-match-journal` | b | **non (passe)** | — | Test réécrit dans `fe79c365` ; l'échec sur `3b42dbf2` venait du test. |

Aucune suite classée (c).

## Vrais défauts du jeu

### 1. Dialogue d'offre de contrat rogné sous 1568 px de large — gravité moyenne

- **Fichier** : `native/godot/ui/contract_negotiation.gd`, lignes 59 (`app._prepare_dialog(dialog,1540)`), 63 (`content.custom_minimum_size.x = 1460`) et 170 (`Dialogs.show_centered(dialog,Vector2i(1540,860))`). Ces largeurs ne passent pas par `C.px()` : elles ne suivent pas la densité de l'écran.
- **Mécanisme** : `native/godot/ui/immersive08/dialogs.gd`, `_fit()` (lignes 62-68) tente de réduire le dialogue à `largeur d'écran - 28`, mais `min_size` (1540) l'en empêche ; il sort alors sans recentrer (`if available.x<0 … return`).
- **Scénario** : fenêtre 1440x900 (taille par défaut de `project.godot`) ou 1280x720 (minimum déclaré) → Recrutement → proposer un contrat à un joueur ; identique pour « Proposer une prolongation » depuis l'effectif.
- **Mesures exécutées sur `fe79c365`** (largeur du dialogue : 1540 px dans tous les cas) :

| Fenêtre | Position | Partie droite invisible |
|---|---|---|
| 1280x720 | x = 0 | 260 px |
| 1366x768 | x = 0 | 174 px |
| 1440x900 | x = 0 | 100 px |
| 1600x900 | x = 30 | rien |
| 1920x1080 et 2560x1440 | centré | rien |

- **Conséquence pour le joueur** : le bloc « Votre nouvelle proposition » (salaire, durée, bouton « Reprendre la contre-offre ») est coupé à droite ; les flèches des champs numériques et la croix de fermeture sont hors écran. Les boutons Annuler et Autoriser restent visibles et la saisie au clavier reste possible : gênant, pas bloquant.
- **Captures** : `/home/claude/scratch/preuves-tests-godot/contrat-1440x900.png` et `contrat-1280x720.png`.
- **Origine** : commit `4a74b963` (« dossier dense 1440p »), absent de la branche `main` locale : c'est une régression apportée par la pile de PR.
- **Réserve** : en mode sans affichage (`--headless`), le dialogue en 1280x720 se place en y = 328 et ses boutons sortent de l'écran ; sous Xvfb avec rendu réel il se place en y = 36 et les boutons sont visibles. Je retiens la mesure avec rendu réel.

### 2. Calendrier plus haut que la zone visible sous 1440p — gravité faible

- **Fichier** : vue mensuelle `native/godot/ui/immersive08/month_calendar.gd` (nœud `CarnetCalendar`).
- **Mesures exécutées** (hauteur minimale de la page / hauteur disponible) : 1280x800 : 834 / 663 ; 1440x900 : 861 / 755 ; 1920x1080 : 958 / 905 ; 2560x1440 : 1120 / 1212 (tient).
- **Conséquence** : en 1080p le bas du calendrier dépasse de 53 px (171 px en 1280x800) ; il faut faire défiler la page. Rien n'est inaccessible.
- **Réserve** : je n'ai pas identifié l'élément qui ne suit pas la densité, ni vérifié si c'était déjà le cas sur `main`.

### 3. Les entrées contextuelles poussent les pages à hauteur fixe hors de l'écran — gravité faible

- **Fichier** : `native/godot/ui/contextual/director.gd`, `install_entrypoints()` (lignes 214-240) et `_add_training_entry()`. Le bouton « OBSERVER LA PRÉPARATION » (28 px + 16 px d'écart) et le bloc « Les invitations du club » (108 px + 16) sont insérés au-dessus d'un canevas de hauteur fixe (`shell.gd` ligne 136, `Vector2(2248,1244)`).
- **Mesures exécutées en 2560x1440** : Préparation, onglet Entraînement : contenu 1288 px pour 1272 disponibles (+16) ; Réception avec une invitation en attente : 1248 pour 1152 (+96 ; +103 en 1080p).
- **Conséquence** : la page entière défile légèrement ; quand la molette arrive en bout de tableau (fatigue, plans individuels), l'en-tête et le panneau se décalent de 16 px. C'est exactement ce que relève `godot-fatigue-overview` (« En-tête et panneau fixes pendant le défilement »).
- **Origine** : commit `283ecd02` (#525), présent dans `main`.

### 4. Point à arbitrer : la gestion des packs est bloquée par un rendez-vous en attente — gravité faible

- **Fichier** : `native/engine/club-meetings.cjs`, `guard()` (lignes 167-189) ; seules les commandes de `readCommands` (ligne 21 : `snapshot`, `export`, `save`, `load`, `import`, `shutdown`, listes de profils) et `new_career` passent.
- **Scénario exécuté** (`godot-pack-ui`) : reprise d'une carrière dont le pack d'identités est absent ; l'avertissement invite à gérer les packs, mais `pack_select {id:"base", scope:"career"}` est refusé avec « terminez le rendez-vous du club avant de poursuivre » tant que la conférence de presse n'est pas faite.
- **Conséquence** : un réglage de présentation, sans effet sportif, est bloqué par une garde sportive. Je ne sais pas si c'est voulu ; à décider.
- Remarque liée, par lecture et sonde : la conférence ne s'ouvre que depuis son courrier en Réception, et une fois ouverte on ne peut plus la quitter (Échap est neutralisé, pas de bouton retour, navigation refusée) avant d'avoir publié ses réponses. Conforme au commentaire du code (« The appointment remains mandatory »), mais le message d'erreur ne dit pas où aller.

## Détail des tests obsolètes (b)

| Suite | Cause précise | Preuve |
|---|---|---|
| `deepen-youth-draft`, `deepen-youth-ui` | `new_career` puis activation du suivi des jeunes sans `settle_club_meetings` ; commande refusée par la garde. | Sonde exécutée sur `deepen-youth-ui` : `erreur moteur = Rendez-vous du club : terminez…`. Même première ligne d'échec pour `-draft` (déduit). |
| `godot-guide-integration` | `clear_press()` envoie `press_conference` mais jamais `club_meeting_continue` ; `advance_day`, `begin_match`, `delegate` sont refusés. | Sonde exécutée : même message, rendez-vous courant `press`. Le nombre d'échecs varie d'un lancement à l'autre (7 puis 65). |
| `godot-reception-decisions`, `native-press-ui` | `InboxOpenPressInvitation` ouvre la salle 3D (`contextual/press_room_view.gd`) ; la route reste « Réception ». Les contrôles suivants échouent en cascade car la salle masque la Réception. | Sonde exécutée : `director_active=true kind=press`, questions et boutons `PressAnswer_*`, `PressPublish` présents. |
| `godot-playbook-watch-ui` | Sauvegarde avec match en direct : `director.gd` force la route « Match » et `_navigate` refuse toute autre cible ; `app.body` reste nul. | Lecture de `main.gd` (`_navigate`) et `director.gd` (`match_immersed`) ; erreur `find_child` sur `Nil` à la ligne 89 du test. Non sondé. |
| `godot-career-final-fixes` | `app.match_screen` est un `live_view.gd` (propriété `drawer_tab`), plus un `match_screen.gd` (`tab`, `presence_key`, `side`). Les 7 autres sous-tests passent. | Relance + lecture. |
| `godot-office-ui` | `Immersive.render()` prend toujours la main en carrière ; `office_view.gd` (nœuds `OfficeCarnet`, `OfficeJournalCard`…) n'est plus instancié. | Lecture de `main.gd` `_render` et `shell.gd` ligne 142. |
| `godot-squad-column-sort` | `squad_canvas.gd` ligne 207 trie via `knowledge_sort_value` → `player_knowledge_text.gd` `bounds()`, qui ne lit que `potentialRange`. Le moteur publie `potential:null` + `potentialRange` (`player-knowledge.cjs` lignes 181-182). Le jeu de test ne fournit que `potential`. Test écrit avant `d01147c1`. | Lecture ; les 8 autres colonnes numériques passent. |
| `godot-portrait-continuity` | Ligne 62 du test : `float(a.rating)` sur le marché, où `rating` vaut `null` pour les joueurs non observés. | Lecture + erreur « Nonexistent 'float' constructor ». |
| `godot-academy-portraits` | Onglet par défaut « Effectif U21 » ; le joueur recherché (`youth-0-1-0`, 17 ans) est en U18. | Sonde exécutée : 30 lignes affichées sur 60 académiciens, joueur absent des lignes. |
| `godot-youth-scout-ui` | Carrière témoin : 9 candidats en détection (le test en veut plus de 20), 98 jeunes tous en modèle `xp` (aucun `annual-v11`). | Sonde exécutée. **Indéterminé** : je n'ai pas vérifié si 9 candidats est le volume voulu par la conception. |
| `godot-club-memory`, `godot-regen-portraits` | Textes retirés par `f4e2c2f6` (« préserver l'immersion »). | `git show f4e2c2f6`. |
| `godot-immersion-copy` | `reception_canvas.gd` ligne 55 lit `app.Immersive.Selections` ; la classe `Host` du test n'a que `model`. | Relance + lecture. |
| `godot-pack-ui` | Après « Reprendre » ou un import, la route est « Réception » (`main.gd` lignes 270-273) ; l'avertissement de pack absent est bien affiché. | Sonde exécutée. |
| `godot-carnet-ui` (partie b) | Bouton « COUP D'ENVOI » présent mais désactivé : « Le coup d'envoi s'ouvre le jour de la rencontre » (`match_screen.gd` lignes 255-258) ; le test ne fait pas avancer le calendrier. Les contrôles « pendant le direct » échouent en cascade. | Sonde exécutée. |
| `godot-fatigue-overview` (partie b) | `set_player_load` refusé par la garde des rendez-vous. | Message dans le journal de relance. |
| `godot-match-journal` | Test réécrit entre `3b42dbf2` et `fe79c365` (113 lignes modifiées). | Relance : passe en 38 s. |

## Méthode et limites

- **Exécuté** : relance des 20 suites sur `fe79c365` ; une douzaine de sondes GDScript hors dépôt (copies de tests avec des `print`, ou scripts dédiés), lancées sur le même worktree ; deux captures d'écran sous Xvfb.
- **Déduit par lecture seulement** : `godot-playbook-watch-ui`, `godot-career-final-fixes`, `godot-office-ui`, `godot-squad-column-sort`, `godot-portrait-continuity`, `godot-immersion-copy`, `deepen-youth-draft`.
- **Non fait** : aucune comparaison avec `main` (sauf l'appartenance de cinq commits à la branche `main` locale, qui peut être en retard) ; aucun essai sous Windows ; pas de recherche de la cause exacte du dépassement du Calendrier.
- Rien n'a été modifié, validé ni poussé ; `git stash` non utilisé. `git status` de `/home/claude/wt-tests` : aucun fichier suivi modifié. `/home/claude/wt-543` n'a pas été touché.

## Fichiers

- Journaux de relance : `/home/claude/scratch/preuves-tests-godot/logs-fe79c365/`
- Résultats (suite, code de sortie, durée) : `/home/claude/scratch/preuves-tests-godot/resultats-fe79c365.tsv`
- Sondes : `/home/claude/scratch/preuves-tests-godot/sondes/`
- Captures : `/home/claude/scratch/preuves-tests-godot/contrat-1440x900.png`, `/home/claude/scratch/preuves-tests-godot/contrat-1280x720.png`
