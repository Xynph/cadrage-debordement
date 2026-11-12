# Analyse des performances et tableau de bord du club : liens de lecture

Base : `d896d631bd2ea141283c0e09609695a547a6b200`.
Branche : `cloud/rg27-night-analysis-club-20261111`.

## Collisions examinées avant écriture

Les deux chemins ont été comparés aux 18 références locales `origin/claude/*`
disponibles à la reprise. Aucun diff de production de ces branches ne les touche.
La branche `preuves-recette-linux-20261111`, sans merge-base avec `origin/main`,
n’est pas comparable par triple point ; elle porte des preuves, pas ce chantier.
Les moteurs, calendriers, données, salaires et animations réservés ne sont pas
modifiés. La réservation de ces deux vues figure dans #576.

## Inventaire

| Source | Avant | Destination de lecture |
| --- | --- | --- |
| Joueur sélectionné dans les performances individuelles | Nom statique sous le sélecteur | Fiche complète du joueur connu par ID |
| Adversaire des cinq dernières rencontres | Nom dans le bilan | Détail du club par ID publié |
| Score collectif | Texte | Détail de la rencontre seulement si fixtureId, saison courante, équipes, phase et score concordent avec la fixture publiée |
| Clubs d’une apparition individuelle | IDs dans le texte conservé | Noms publics cliquables des clubs concernés, si leurs IDs sont consultables |
| Score/rencontre d’une apparition individuelle | Pas de fixtureId publié dans cette projection | Aucun lien inventé |
| Personnes du staff sur Club/Vue d’ensemble | Noms et portraits statiques | Profil du membre exact, par ID |
| Leader du vestiaire | Nom statique | Fiche complète seulement si le joueur est connu |
| Trésorerie et salaires du pied de page Club | Valeurs statiques | Onglets Trésorerie et Salaires existants |

Le sélecteur `PerformancePlayerChoice` conserve sa fonction de sélection. Son
choix est mémorisé par ID dans l’état de lecture pour le restaurer après un
aller-retour par les nouveaux liens ; aucun signal métier n’est ajouté. Le
bouton d’activation du registre individuel conserve son geste métier explicite ;
aucun nouveau lien ne l’appelle ni ne conserve automatiquement de performances.
Les résultats sans ID sûr ou d’une autre saison restent lisibles en texte.

Les boutons reprennent les styles existants de leurs vues : Carnet pour les
performances, zones transparentes avec le focus existant sur ClubCanvas. Aucun
chiffre, calcul, graphique, texte de conseil ou valeur cachée n’est ajouté.

## Faux hôtes et API commune

Les deux vues obtiennent le contrôleur uniquement si la propriété
`navigation_controller` existe et fournit `entity_available`. Un hôte de rendu
sans contrôleur conserve le texte ; il n’émet ni erreur d’accès ni navigation
parallèle. Toutes les activations effectives passent par `EntityLink.bind` et
le contrôleur commun. Les gardes et l’historique restent ceux du jeu.

Contrôles : `PerformancePlayerLink`, `PerformanceMatchScore_FIXTUREID`,
`PerformanceOpponent_CONTEXTE`, `PerformanceAppearanceClub_CLE`,
`PerformanceAppearanceOpponent_CLE`, `ClubStaffName_ID`,
`ClubStaffPortrait_ID`, `ClubLeaderLink`, `ClubCashLink`, `ClubWagesLink`.
Les métadonnées `entity_kind`/`entity_id` portent les vrais identifiants.

## Validation préparée

Les contrôles ciblés doivent couvrir le rendu sans contrôleur, le refus d’un
score sans fixtureId, d’une autre saison ou ne correspondant plus aux équipes
et au résultat, la conservation du sélecteur et du registre désactivé, les fiches
joueur/staff/club et les onglets financiers, puis sauvegarde/état/RNG et silence.
Aucun Godot ni import lancé dans ce worktree ; les reçus seront ceux du candidat
commun effectivement assemblé et testé par l’intégrateur.

Tests préparés : `tests/godot-analysis-club-links.cjs` et `.gd`. Les premiers
contrôles sont des fixtures isolées de rendu/lookup : hôte sans contrôleur et
refus des incohérences de saison, équipes, score ou phase. Ils ne sont pas des
preuves d’un match réellement simulé. La deuxième partie prépare une carrière
réelle, distingue l’activation explicite du registre (préparation) de toutes les
consultations suivantes, active les liens staff/finances/joueur au clavier et à
la souris, vérifie le retour au choix du joueur puis les octets de sauvegarde,
l’état/RNG et le silence de Gabi. Le script ne prétend pas recevoir un lien de
score réel : ce geste doit être repris avec le checkpoint de rencontre déjà
qualifié par la recette commune. Wrapper JavaScript vérifié, aucun SDK lancé ici.

## Complément graphique préparé, sans exécution

`tests/godot-analysis-club-graphics.cjs` et `.gd` sont opt-in :
`CD_ANALYSIS_CLUB_GRAPHICS=1`, SDK explicite et affichage X11 existant.
Le délai enfant reste **150 secondes**, dans la garde commune de **180 secondes**.
Aucun import ni lancement du SDK n’a été effectué sur ce worktree.

Pour une reprise locale, `CD_ANALYSIS_CLUB_GRAPHICS_SOURCE` désigne un profil,
son dossier `PrototypeGodot` ou `donnees.json`. Le wrapper copie le dossier
complet vers un nouveau temporaire avant toute ouverture du worker ; il hache
le fichier source avant et après, y compris après un échec, et conserve
`source-copy.json`. Aucun chemin `/tmp` local n’est requis par la CI : la CI
ignore cette option et crée elle-même son checkpoint via les commandes publiques
et les helpers `prepare_match_day`, causeries, `delegate`, puis
`finish_match_week`, sans modifier les délais.

Le checkpoint local prioritaire proposé par l’intégrateur a été inspecté en
lecture seule : `/tmp/cd-reader-history-tZu0GW/PrototypeGodot` conserve le résultat
propre `accession:2026:league:0:4`, saison 1, clubs 16/29, score 19–10. Il ne
contient pas de registre individuel activé. La recette conserve cet ID exact et
ne fabrique aucun match. Si aucune rencontre de saison sûre n’existe, elle
consigne l’indisponibilité plutôt que de substituer une rencontre.

L’éventuelle activation du registre est une **commande publique explicite de
préparation sur la copie**, avant le baseline navigation. Les anciennes feuilles
ne sont pas reconstruites. Les activations ensuite vérifiées sont le score
collectif réel→fiche de rencontre, l’adversaire→club, les retours avec même
instance/focus/défilement, le choix de joueur→fiche→retour au même choix, le staff
et les onglets Trésorerie/Salaires. La sauvegarde, le registre et l’état/RNG sont
comparés après ces consultations ; les compteurs de parole doivent rester à zéro.

Trois captures natives 2560×1440 sont prévues : l’analyse, la fiche de la vraie
rencontre et le Bureau sur le même checkpoint. Leur existence, leurs dimensions et leurs SHA seront vérifiés dans
`report.json`. Elles ne sont pas annoncées comme obtenues avant l’exécution.
Le wrapper JavaScript a passé `node --check` ; la validation du SDK reste à
l’intégrateur sur le candidat commun effectivement assemblé.


## Complément Bureau sur le même replay

Le helper séparé `tests/helpers/office-reading-cases.gd` complète le même client
et le même profil jetable. Le wrapper conserve un seul clone, un seul setup
public éventuel, la frontière de baseline déjà placée après l'activation
explicite du registre, puis les mêmes comparaisons sauvegarde/état/RNG et
compteurs de parole. Aucun nouveau match, semaine, entraînement ou commande
métier n'est ajouté par le helper. Les délais enfant 150 s et commun 180 s
restent inchangés.

Les gestes ajoutés sont clic réel sur le prochain adversaire puis Back,
Entrée sur sa date publiée puis Back, clic sur l'alerte physique lorsqu'un
joueur à surveiller existe, et score du résultat de calendrier attendu lorsque
son ID est unique et concordant. Les données absentes du checkpoint sont
explicitement consignées dans `visits` avec `available: false` et leur raison ;
elles ne deviennent pas de faux cas de fatigue ou de résultat reçu. La capture
Bureau est prise dans le vrai client en 2560×1440, sans aperçu fabriqué.

Après chaque Back depuis un détail, le replay exige la fenêtre masquée ou
libérée et `navigation_controller._blocked() == false`, puis le focus et le
défilement de la source. Ces assertions sont aussi ajoutées aux deux retours
initiaux Analyse→rencontre et Analyse→club. Si un lecteur antérieur reste actif,
le helper échoue explicitement au lieu de changer la route derrière sa fenêtre ;
il n'appelle ni `_travel` directement ni FERMER pour contourner un défaut du
raccourci. La correction commune du registre page→modal, détenue par le
propriétaire du contrôleur, doit être assemblée pour la réception.

Ce complément est préparé sur `b4c894ec`, et requiert les liens Bureau
`321849e1` puis leur correctif `231b229b`. Aucun Godot/import ou SDK n'a été
exécuté dans le worktree de préparation. La précédente réception Analyse/Club
et ses échecs ne sont pas transformés en reçu de ce scope étendu.
