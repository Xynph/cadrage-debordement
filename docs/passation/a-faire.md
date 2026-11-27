# Backlog priorisé

Chaque item donne le contexte, les fichiers utiles et le critère de fin. Priorités : **P0** à faire en premier (état de `main`), **P1** important, **P2** utile, **P3** si le temps le permet. Respecter [regles-du-createur.md](regles-du-createur.md) : une PR courte par chantier, vérificateur GO avant tout « c'est fait », aucun seuil abaissé, aucun choix visuel nouveau sans options.

Rappel d'économie : un chantier = une conversation ou un agent ; en cas de lot multi-écrans, faire d'abord l'inventaire par l'agent `eclaireur`.

## P0 — Remettre et garder `main` vert

### P0-1. Contrôler l'état de `main` et des PR en vol
- Contexte : au moment de la passation, #1350, #1362 et #1365 avaient la fusion auto armée et leur CI tournait ; la batterie de `main` sur #1363 était en cours (voir [etat-27-novembre.md](etat-27-novembre.md)).
- Faire : `gh pr list --state open` ; `gh run list --workflow "Tests JavaScript" --branch main --limit 10`. Pour chaque rouge : lire **tous** les jobs en échec (`gh run view <id> --log-failed`), classer chaque suite en (a) défaut du jeu, (b) test périmé, (c) hasard ou lenteur de runner. Corriger dans cet ordre, une PR par famille.
- Désarmer la fusion auto de #908 (`gh pr merge 908 --disable-auto`) : PR hors sujet, en conflit.
- Critère de fin : la dernière batterie programmée de `main` est verte (ou ses rouges sont tous expliqués et corrigés par une PR en cours) ; aucune PR de retour arrière automatique n'est ouverte sans raison.

### P0-2. Vérifier `match-pilotage` et la suite des tests de calage après K2 et K3
- Contexte : `match-pilotage` « attaquer leur aile faible rapporte » est un test à graine fixe au bord de son seuil (voir [moteur-match.md](moteur-match.md)). Avec #1350 les suites `match-realite-championnats`, `match-ia-decisions`, `bonus-fin-de-match`, `match-consignes-direct` ont été touchées.
- Fichiers : `tests/match-pilotage.cjs`, `tests/match-realite-championnats.cjs`, `tests/match-ia-decisions.cjs`, `tests/match-remplacants.cjs`, `tests/match-niveau-poste.cjs`.
- Critère de fin : ces suites sont vertes sur `main`. Si `match-pilotage` est rouge : élargir l'échantillon des séries « faible » à au moins 1 500 matchs, **même seuil de 1 point** (erreur type environ 0,45) ; PR de test sans fusion auto, listée dans [decisions-a-valider.md](decisions-a-valider.md).

## P1 — Famille de tests à rendre verts et fiables

### P1-1. Rouges rares isolés de la batterie Godot
- Suites : `deepen-analytics-real-ui`, `godot-equipe-type`, `godot-preparation-ecran`, `godot-centre-cartes`, `godot-phrases-lot10`, `godot-apres-match`, `godot-survols-club-courbe-rebours`.
- Contexte : rouges un jour sur plusieurs, sans lien avec un changement de code. Cause probable pour `survols-club-courbe-rebours` : l'ancre survolée est libérée pendant l'attente du test (vers la ligne 69), `SCRIPT ERROR: Cannot call method 'get_meta' on a previously freed instance`. Analyse complète dans [solidite-ci.md](solidite-ci.md) section 3.
- Faire : pour chaque suite, relire les journaux des runs rouges (`gh run view <id> --log-failed`, ou `log-reader`), classer (a), (b) ou (c), corriger le jeu pour un vrai défaut (l'attente d'un nœud libéré est souvent un vrai défaut de reconstruction d'écran), figer la graine pour un hasard.
- Critère de fin : 5 batteries programmées consécutives sans rouge sur ces suites.

### P1-2. Marges de temps des suites Godot
- Contexte : `godot-match-temps-forts` démarre parfois 0,1 à 2 min avant la coupure de 45 min du job ; `godot-interface-layout` (de retour en CI avec #1357, poids posé à 200 s, plafond par défaut 300 s) est à surveiller sous le rendu logiciel ; `godot-cris-banc` et les planches du direct restent les suites les plus lourdes.
- Fichiers : `ci/suite-weights.json` (section `godot`), `ci/run-godot-suites.sh` (`suite_limits`), `ci/ci-jobs.cjs`.
- Faire : remesurer les poids sur les 10 à 15 prochains runs programmés verts (`gh run list --event schedule`), rééquilibrer les jobs. Si une suite dépasse son plafond de façon répétée : **mesurer d'abord**, relever la limite seulement avec la mesure en preuve (c'est ce qui a été fait pour `grands-moments`, #1341).
- Critère de fin : aucun job Godot ne dépasse 40 min sur 5 runs ; aucune suite coupée par son plafond.

### P1-3. Rendu du direct en CI (suite de #1355)
- Contexte : en CI le rendu logiciel tourne à environ 1 image par seconde pour l'écran du direct en 1920 et 2560 ; #1355 a supprimé le rendu de la 3D cachée sous l'écran 2D (12 images par seconde en pause, 4 en match lancé). Toutes les suites du direct en bénéficient mais restent lentes.
- Fichiers : `native/godot/live_view.gd`, `native/godot/ui/`, suites `tests/godot-planche-*`, `godot-cris-banc`, `godot-match-*`.
- Faire : mesurer où va le temps d'une image du direct (profil CI), réduire le coût sans changer l'apparence ni les chiffres ; les attentes des tests restent en temps réel, jamais en images.
- Critère de fin : durée de `godot-cris-banc` et des planches du direct divisée par deux sur CI, sans changement visuel (vérificateur sur film).

### P1-4. Tests qui dépendent d'une graine
- Contexte : `match-liaison-monde` est désormais scripté (#1352), mais `godot-planche-*` jouent la graine 3 (carton à la 5e minute), et `match-essai-visible` n'exerce plus de plan « essai de pénalité » depuis #1356 (graines 7 et 1000).
- Faire : pour chaque test, vérifier qu'il reste vert sur 3 graines et rouge si on casse la fonction ; remplacer une graine dont le plan n'est plus exercé par une graine qui l'exerce (même contrôle, même seuil), avec accord (liste dans [decisions-a-valider.md](decisions-a-valider.md)).
- Critère de fin : liste des tests à graine fixe dans `docs/` avec la graine, ce qu'elle doit produire, et le test qui le vérifie.

### P1-5. Anciens tests exclus de la CI (`CD_MODES_HERITES`)
- Contexte : des tests sur l'ancien mode France sont exclus de la CI (`ci/legacy-modes.cjs`). `godot-interface-layout` a été migrée (#1357) ; le reste est à migrer vers le Monde ou à supprimer (suppression : demander au créateur).
- Faire : `node ci/legacy-modes.cjs list` (ou lire le fichier), proposer migrer / supprimer pour chaque test, migrer ceux qui protègent un écran vivant.
- Critère de fin : liste de décision dans [decisions-a-valider.md](decisions-a-valider.md) et migrations faites pour les évidentes.

## P1 — Moteur de match (réalisme)

Source détaillée : [moteur-match.md](moteur-match.md). Toujours : calage réel par championnat tenu (favori, matchs serrés, points, essais), une PR par lot, chiffres avant/après dans la PR, jamais l'effet exact montré au joueur.

### P1-6. Remontées tardives par championnat
- Contexte : mené de 11 à 14 points à la 75e puis écart ≤ 7 à la fin : 34 % en saison Monde avant #1356 pour une cible de 20 à 25 %. Depuis #1356 : 16,9 % sur main, 20,9 % avec K3 (2 × 600 matchs Top 14 en IA contre IA). Pas refait pour tous les championnats.
- Fichiers : `dist/rugby.js`, `dist/opposition.js` (défense regroupée en fin de match), `scripts/mesure-essais-monde.cjs`, scripts de calage décrits dans [moteur-match.md](moteur-match.md).
- Critère de fin : tableau « remontées tardives » pour Top 14, Premiership, URC, Pro D2, Super Rugby, Japon sur 6 saisons Monde, tous dans 20 à 25 % (ou écart justifié) ; `match-realite-championnats` vert.

### P1-7. Matchs serrés par championnat (URC et autres)
- Contexte : Top 14 ≈ 40 % (tenu) ; URC 34 à 38,8 % pour un réel de 41 % ; Japon 29,6 à 34,9 % (réel 30). À re-mesurer à chaque lot du moteur.
- Critère de fin : tous les championnats à ±3 points du réel sur 6 saisons.

### P1-8. Cartons jaunes en baisse d'environ 15 % : à examiner
- Contexte : l'anomalie 11 donnait 1,8 jaune par match pour un réel de 1,1 à 1,5 ; une baisse d'environ 15 % a été signalée après les derniers lots de lois (valeur non rejouée dans cette passation).
- Fichiers : `dist/rugby.js` (fautes, cartons), `tests/cartons-realistes.cjs`, `tests/incidents-match.cjs`.
- Critère de fin : mesure sur 150 matchs par championnat ; si on passe sous 1,1 par match, remonter ; sinon documenter.

### P1-9. Restes de la liste d'anomalies (`ANOMALIES.md` du chantier)
- Fautes de main et avantage : fait en partie (#1308, #1353) ; **relancer l'audit du journal sur 150 matchs** (cohérence de l'avantage, deux récupérations de suite sans course racontée, renvoi repris par l'équipe qui botte) pour confirmer qu'il ne reste rien.
- Mêlées et lois secondaires : mêlées un peu rares (10 pour un réel de 12 à 15), renvois aux 22 m rares (0,8 pour un réel d'environ 3), mauls hors touche-pénalité (aucun), possessions très courtes (65 % s'arrêtent après une action).
- Divers rares : 9e remplacement, talonneur remplacé par un ailier (K3 l'a traité côté IA : à confirmer), joueur sorti qui revient remplacer un blessé (peut être légal), mi-temps qui déborde jusqu'à 5 min.
- Critère de fin : audit relancé, tableau des restes mis à jour, un lot par famille.

### P1-10. Niveau au poste et remplaçants : suivi
- Contexte : K2 (#1351, fusionnée) et K3 (#1350, en CI). Références mesurées dans [moteur-match.md](moteur-match.md). Restent : ailiers, centres et arrière ont un effet encore faible (à peine −0,4 à −1,6 point à −15 au poste) ; une marge de test étroite (`match-remplacants` 36,7 % pour 35).
- Critère de fin : élargir l'échantillon de `match-remplacants` à même seuil si le test est instable ; mesurer les 6 saisons Monde après fusion des deux.

## P2 — Écrans, charte, résolutions

### P2-1. Audit des écrans non touchés depuis 10 jours
- Contexte : beaucoup d'écrans ont été refaits du 19 au 25/11 (charte, Effectif, survol, couleurs). D'autres n'ont pas été revus.
- Faire : `git log --since=2026-11-17 --name-only -- native/godot/ui` pour lister les fichiers d'écran touchés ; comparer à `docs/carte-code/ECRANS.md` ; les écrans de la carte absents de ce journal sont à auditer. Utiliser l'agent `eclaireur`, puis la commande `/ux-review` ; faire des captures **après** seulement.
- Critère de fin : liste des écrans non touchés avec, pour chacun, les écarts à la charte (voir P2-2) ; lots courts d'une famille d'écrans.

### P2-2. Cohérence avec la charte finale
- Points à contrôler écran par écran : panneaux de rayon 18 sans bordure, cartes 12, cases 6, un seul aplat doré (le bouton « Continuer ») ; Anton (droit) pour les grands titres ; **aucune phrase explicative** ; couleurs de donnée communes ; ombres 4 px sur panneaux, cartes et tuiles seulement ; survol de ligne ; mini-fiche seulement via « (i) » après 0,5 s ; clic nom = fiche complète ; tout élément cliquable ouvre quelque chose ; clic direct sans confirmation ; écrans de scène obligatoire sans navigation de sortie.
- Fichiers : `design/art/art-bible.md`, `native/godot/ui/charte.gd`, `docs/carte-code/ECRANS.md`.
- Point de départ connu (état au 25/11) : une vingtaine de fichiers utilisent encore l'ancienne `MiniFiche.lier` (mini-fiche immédiate au survol du nom) au lieu de `CarteSurvol.lier_info` ; chercher avec `node scripts/carte-code.cjs --cherche "MiniFiche.lier"`. Préparation (joueurs à surveiller) était citée.
- Critère de fin : zéro appel à l'ancien survol dans les écrans de carrière ; une suite qui clique chaque élément créé.

### P2-3. Résolutions : 1280×720, 1440p, 2560
- Contexte : cibles du créateur : 2560×1440 (sa résolution) et 1920×1080 ; match : 2560 et 1920, 1280 ignoré ; la mise en page des autres écrans est testée de 720p à 1440p par `godot-interface-layout`. Bureau large 2560 : dernier résultat cliquable (#1347). Point en suspens : sur un écran très chargé, le banc du match devient défilable (ses 8 lignes sont gardées).
- Faire : balayer les écrans principaux dans les quatre résolutions (captures en ligne : `bash ci/en-ligne.sh --ref <branche> --captures <liste>`), chercher débordements, textes coupés, cartes qui se chevauchent, cibles cliquables trop petites ; étendre `godot-interface-layout` aux écrans non couverts.
- Critère de fin : aucun débordement sur les écrans de carrière dans les trois résolutions ; le test de mise en page couvre les écrans corrigés.

### P2-4. Incertitude : chiffres exacts avant d'agir
- Contexte : environ 30 endroits montrent encore un chiffre exact avant d'agir (entraînement, réunion de staff, rapport de force, offres, blessures, courrier du club, vestiaire, énergie prévue, phases arrêtées, conseil), 34 de plus sont trop précis. La grammaire commune (A : pastille du staff, B : fourchette ou palier, C : flèche ▲▼) attend le choix du créateur : voir [decisions-a-valider.md](decisions-a-valider.md).
- Faire d'ici là : l'inventaire n'est pas dans le dépôt ; le refaire par grep (formats « +N % », « −N », « N → M ») sur les écrans d'entraînement, de staff, de transferts, de blessures, du courrier ; préparer les maquettes des 3 options pour le créateur, **sans rien intégrer**.
- Critère de fin : inventaire versé dans `docs/`, options en captures, et rien d'intégré avant la réponse.

### P2-5. Écrans signalés en suspens
- Compte rendu de presse : mise en page ancienne (petits textes serrés à droite, grand vide à gauche, image sombre) alors que l'écran des questions est refait ; proposition : le refaire comme l'écran des questions (question dans [decisions-a-valider.md](decisions-a-valider.md)).
- Calendrier, bouton « ? » : un clic n'ouvre rien (l'aide se replie faute de place, même en 1920×1080) ; proposition : une petite fenêtre.
- Sauvegardes Monde : une carrière Monde dépasse la limite d'une sauvegarde ordinaire (24 Mio) et sort en format réduit (≈ 19 Mio, ≈ 5 Mio de marge) ; le relevé hebdomadaire des qualités de chaque joueur est la première source à alléger (questions dans [decisions-a-valider.md](decisions-a-valider.md)).

## P2 — Moteur : économie et saisons

- Équilibre financier Pro D2 / D2 japonaise : clubs dans le rouge en saisons 2 et 3 corrigés par un propriétaire qui dépasse jusqu'à 30 % de sa promesse (choix à faire, voir [decisions-a-valider.md](decisions-a-valider.md)). Un vérificateur doit rejouer la VRAIE saison (graines 4242, 7, 2026) avant tout « c'est fait ».
- Bug de sauvegarde en saison 2 (club 80, D2 japonaise) corrigé à la source pour les gros staffs (#1280), cas exact jamais reproduit : en attente de la carrière du créateur.

## P3 — Restes 3D connus (non traités, décision du directeur et du créateur)

Contexte commun : mesures de `tools/match-filme/sonde_contacts.gd` (testée par #1325) ; résultats chiffrés dans la description des PR #1325, #1331, #1339 (bras entrés de plus de 8 cm : mêlée 42–310 images vers 0–5, plaquage 289–813 vers 0–7, ruck 148–300 vers 0–5, ballon porté ~550 vers 16). Fichiers : `native/engine/match-choregraphe.cjs`, `native/godot/match_choregraphie.gd`, `native/godot/match_joueur_v5.gd`.

### P3-1. Épaule qui entre dans le buste de l'autre
- Mêlée 70–356 images, plaquage 438–620, jusqu'à 15–19 cm. Écarter les joueurs a été refusé (le contact doit rester serré) ; tourner la clavicule est visible et risqué.
- Critère de fin : option proposée au créateur en captures (clavicule tournée de peu ou contact accepté), sinon laisser.

### P3-2. Bras qui se croisent dans les liaisons
- Jusqu'à 12 cm dans les liaisons (mêlée, maul). Mesurable par la sonde.
- Critère de fin : bras croisés sous 4 cm sur 3 films, sans que la liaison perde son aspect.

### P3-3. Arrivées en course au ballon porté
- Joueurs qui arrivent en courant et entrent dans les liés (buste ou tête jusqu'à 24–28 cm, 2 films sur 4).
- Critère de fin : sonde sous 8 cm sur 4 films ; arrivées qui s'arrêtent au contact.

### P3-4. Divers 3D
- Pieds parfois en l'air pendant le plaquage, quelques facettes sur le maillot, arbitre à l'ancien modèle, ballon gros dans les mains. Le **geste du botteur au drop** demande un pack d'animations privé (hors dépôt) : décision du créateur requise, ne rien intégrer.

## P3 — Outillage et hygiène

- Voir `docs/passation/solidite-ci.md` pour les commandes de diagnostic CI.
- Le suivi des tokens : `node scripts/mesure-tokens.cjs` une fois par semaine (mesure du gain de la carte du code à refaire).
- Mettre à jour `FAUX-FAIT` (leçons des fausses fins) : ce fichier est tenu hors dépôt par le créateur ; en cloud, ajouter les leçons dans la description de la PR concernée.
- Branches et worktrees fusionnés : supprimer. `ci/branches-a-supprimer.txt` liste des branches du dépôt à supprimer (suppression distante : demander).

## Lacunes de cette passation (écrite dans l'urgence le 27/11)
- Les listes de suites (P1-5, P1-4) sont à produire : non inventoriées.
- L'inventaire « incertitude » et les rapports d'audit du moteur sont hors dépôt et non repris.
- Les chiffres de calage sont à rejouer après la fusion de #1350 (non confirmée) ; la baisse des cartons jaunes (~15 %) vient d'une consigne orale, non remesurée.
- L'état de `main` et des PR (#1350, #1362, #1365) est à recontrôler : ce document date du 27/11 en milieu de journée.
