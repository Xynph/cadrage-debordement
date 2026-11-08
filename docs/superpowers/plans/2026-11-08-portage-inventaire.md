# Portage complet de l’inventaire — plan d’exécution

**Spécification :** `docs/superpowers/specs/2026-11-08-portage-inventaire.md`.
**Base :**2e0fff10 ; branche feature/portage-inventaire-20261108 ; dépendance PR396.
**Méthode :** sous-systèmes autonomes sur chemins disjoints, raccordement sérialisé par l’intégrateur, tests rouges puis implémentation et revue ciblée. Pas d’approbation humaine intermédiaire pour les choix ordinaires déjà autorisés.

## Contrat commun des contrôleurs

Chaque nouveau module `native/engine/<domaine>.cjs` exporte un objet Node `{files, commands, factory}`. `files` est le manifeste fermé des scripts dist requis avant game.js. `commands` contient les noms exacts de commandes. `factory` est une fonction autonome sérialisable dans la VM, exécutée après les modules et game.js. Elle renvoie `{project, validate, execute, installHooks}`. `validate(state)` est pur et lève une erreur française pour tout état propre invalide ; absence de champ acceptée. `project()` lit le vrai S sans le modifier ni consommer le RNG. `execute(command,payload)` lève pour un retour métier refusé ; aucune écriture disque. `installHooks()` n’installe que des hooks fonctionnels idempotents. Pas de code fourni par le protocole.

Noms de projections : `press`, `relationships`, `academyPathways`, `clubWorld`, `clubStrategy`, `managerCareer`, regroupées dans `model.clubLife`. Les vues reçoivent ces dictionnaires et une référence à l’application, selon les vues natives existantes ; seules les commandes explicites modifient la carrière. Les projections exposent IDs, chiffres et textes sans noms concaténés lorsque les identités du pack doivent pouvoir changer.

## Task1 — Presse réellement jouable

Propriétaire : producteur presse. Chemins : `native/engine/press.cjs`, `native/godot/ui/press_view.gd`, `tests/native-press*.cjs` et les six fichiers dist presse listés ci-dessous. Ni worker/model/main/build ni validateur central ne sont modifiés par ce producteur.

1. Lire `portage-hors-match-architecture.md` dans les artefacts de session et les modules : press-relations, press-question-bank, media-evidence-v60, media-native-adapter-v60, media-world-v60, press-conference-interactive. Conserver leur métier, séparer le démarrage headless de l’installation web.
2. Écrire une recette du vrai worker (copie test temporaire permise) démontrant conférence, effets, doublon refusé, semaine34, reprise avec namespaces presse et non-mutation des lectures. Exécuter rouge avant correction.
3. Implémenter le contrôleur : journal structuré par division/IDs ; préparation pure2–4questions,4réponses ; `press_conference` avec clé attendue saison/semaine/club + questionId/answerId. Rejeter préparation périmée, conférence répétée ou match en cours.
4. Valider strictement `pressRelations`, `pressConference` et leurs historiques, semaines34 selon calendrier actif. Garder le calendrier historique. Ne pas cumuler conférence simple et riche.
5. Vue Godot : journal lisible, accès conférence, choix espacés, résultat moral/confiance/opinion et historique. Ne pas changer les38fragments du coach dans ce lot.
6. Reprise/import/export/rollback, identités anonymes/pack et faits futurs exclus. Fournir rapport précis, modifications et raccords nécessaires. Revue ciblée avant intégration.

## Task2 — Vestiaire, relations et mémoire des rivalités

Propriétaire : producteur vie du club. Chemins : `native/engine/{relationships,club-world}.cjs`, `native/godot/ui/{relationships_view,world_view}.gd`, `tests/native-{relationships,club-world}*.cjs`, `dist/{vestiaire-v64,relations-duos-v70,living-locker-room-v117-v123,interclub-world-v124-v130}.js`. Pas de changement worker/central/core de compétition.

1. Lire les contrats des API, les sources officielles de règles avant tout effet sur le match et le rapport d’architecture. Écrire puis exécuter tests rouges sur les décisions et persistance.
2. Porter les conversations/promesses existantes, l’événement hebdomadaire à3choix, leadership et duos. N’activer un bonus de match qu’avec preuve des partenaires effectivement actifs et même borne historique ; sinon signaler le raccord nécessaire au parent.
3. Projections pures, commandes contextualisées, validateurs stricts des états optionnels et bornes de taille/historique. Pas de pénalité d’une métrique absente ; prévenir les décisions répétées.
4. Observer les résultats réellement joués dans France30 et le mode historique, avec identité de fixture et déduplication. Préserver les H2H/palmarès fiables et distinguer les récits fictifs.
5. Deux vues lisibles : vestiaire avec personnes/engagements/retours, monde avec rivalités/confrontations/historique. Prévoir les IDs pour projection des packs.
6. Tester effets réels, partenaire blessé, échéance, save rejetée, reprise, saison suivante et club29 ; rapport/revue ciblée.

## Task3 — Formation avancée et générations à30clubs

Propriétaire : producteur académie. Chemins : `native/engine/academy.cjs`, `native/godot/ui/academy_pathways_view.gd`, `tests/native-academy*.cjs`, `dist/youth-pathways-v72.js` et tous les `dist/espoirs-*v73` à `v104` explicitement recensés dans l’inventaire. Le validateur central reste à l’intégrateur.

1. Lire les règles/données, les namespaces et dépendances V72–104 et les tests existants. Définir l’adaptation30clubs dans le rapport avant code : centre attaché au club, calendrier junior distinct de celui des seniors, transferts/promotions identifiables, pas de mélange avec les1592profils réels.
2. Tester rouge puis porter détection et mentorat sur les15Espoirs existants et les mêmes coûts. Exposer trajectoire, minutes, objectifs et génération sans duplication de joueurs.
3. Étendre le parcours Espoirs avec validateurs stricts, versions et hooks annuels uniques. Ne jamais supprimer le refus France30 sans preuve d’un état compatible ; fournir au parent un validateur exact permettant l’extension contrôlée.
4. Une vue du centre avec filtres, parcours individuel, mentorat/détection et mémoire des générations ; confirmations des dépenses et promotions.
5. Tester30clubs, changements de club, promotion unique, nouvelle génération annuelle unique, anciennes sauvegardes, échec disque, checkpoints15saisons et plafond5Mio/nœuds. Les preuves insuffisantes restent explicitement ouvertes.
6. Rapport/revue ciblée avant activation des extensions complexes.

## Task4 — Raccord natif et stratégie du club

Propriétaire : intégrateur. Chemins partagés worker/model/main/build/gestion/packs/validateurs centraux et nouveaux `native-systems.cjs`, `club-strategy.cjs`, `strategy_view.gd`, tests associés ; dist staffV65–68, briefingV69, agentsV71, directionV105–110, supportersV111–116, board-calendar, career-integration/world-career selon besoin.

1. Orchestrer les manifestes avant game.js, factories après game.js, validation de démarrage/import et projection pure. Les commandes restent dans la transaction existante, pas de deuxième fichier de carrière.
2. Ajouter les contrôleurs successivement quand leurs tests passent, raccorder les noms d’écrans et l’import des identités. Tester la reprise d’un état qui dépend d’un nouveau module.
3. Exposer investissements0/4000/12000, installations, sponsor, revue du conseil et objectifs avec vrais contrôleurs, devis avant dépense,34semainesFrance30/29historiques.
4. Ajouter réunions staff, plans de travail, suivi médical, stratégies d’agents et supporters après qualification de leurs effets. Aucune recette supporters pour un faux créneau sans match réel.
5. Tests de débit/signature/clôture uniques, anciennes carrières, erreurs disque, état hostile et données absentes. Vue stratégie : finances, cap de saison et décisions ; éviter un unique écran surchargé.

## Task5 — Carrière du manager et recrutement durable

Propriétaire : intégrateur après stabilité des hooks. `native/engine/manager-career.cjs`, `manager_career_view.gd`, tests, `dist/manager-mobility.js` ; raccords aux suivis existants et bureau des agents.

1. Exposer candidatures/offres/acceptation/confirmation intersaison à partir du système existant, sans ajouter les anciens prototypes de contrats personnels.
2. Qualifier le changement Élite↔Accession, former club, académie, packs et archives, puis nouvelle saison et reprise. Contextualiser les confirmations pour refuser une offre devenue périmée.
3. Suivis persistants de recrutement, plan à3saisons et négociations avec engagement calculé sur le vrai calendrier.

## Task6 — Gabi, interfaces et match3D

Propriétaire : intégrateur, après disponibilité des projections ; graphisme sur scène isolée si nécessaire.

1. Terminer la prise Algenib/Sud-Ouest approuvée avec une hauteur plus grave ; uniquement outils gratuits et source autorisée. Conserver l’audio provisoire si la génération reste bloquée, sans l’annoncer final.
2. Donner à Gabi des observations contextuelles courtes issues des données des écrans ; arrêt au direct/menus et accès clavier préservé.
3. Appliquer le carnet aux nouveaux écrans, tableaux àdensité réglée, titres/chiffres/couleurs hiérarchisés et comparaison de joueurs. Contrôler aux trois résolutions.
4. Qualifier un contact Godot continu avec pieds/mains/ballon corrects avant toute substitution d’animation. Benchmark30acteurs et troisLOD ; pas de nouvelle règle physique à partir d’un prototype non reçu.

## Task7 — Qualification globale, publication et livraison

1. Revue indépendante des sous-systèmes et branche entière ; corriger les défauts bloquants avec tests de régression.
2. Rejouer les tests ciblés sauvegardes, réglementation, packs, moteur, UI réelle et longues carrières. Comparer state/RNG/octets après consultation/reprise ; mesurer limites5Mio.
3. Mettre àjour inventaire/README/DEVELOPPEMENT dans le même lot. État par candidat : livré, reçu mais non intégré, en cours, R&D ; jamais « complet » sur simple chargement.
4. Publier commits/PR, vérifier HEAD/CI/gate puis fusion sérialisée conforme aux protections. Aucune CI en attente comptée comme succès.
5. Construire Windows dans un nouveau dossierE, recevoir l’EXE déplacé sans Node système/réseau, préserver profil personnel, actualiser seul raccourci bureau. Passation#73 et bilan bref avec preuves.

## Task8 — Personnalités presse et cinq réponses

Demande complémentaire explicite de Léo ; lire la précision de la spécification. Producteur distinct, press.cjs + trois distpresse + nouveau press_people_view.gd, tests concernés. La vue presse principale reste au DA jusqu’à libération explicite.

1. Conserver intégralement les30identités/10groupes de médias et500IDs de questions. Corriger le français, préserver les IDs des4réponses historiques, ajouter une cinquième réponse humoristique àchaquequestion :2500options,5tons aux effets bornés et expliqués.
2. Donner des traits de dialogue cohérents aux5styles et conserver leurs spécialités. Différencier clairement les personnages fictifs et journalistes référencés ; les propos et traits de simulation ne sont pas attribués comme faits réels.
3. Namespace optionnel strict pour relations individuelles avec le coach, par IDstable, sans créer d’état àla lecture. Compteur, score lisible et mémoire courte des vrais échanges ; pas de souvenirs reconstitués arbitrairement sur anciennes carrières.
4. Mettre àjour les relations lors des seules réponses explicites, préserver les échanges après mobilité. Historique exact des questions/réponses et du journaliste ; anciens exports toujours acceptés. Budget mémoire cible<30Kio même avec30contacts.
5. Vue carnet des journalistes/relations, retours visibles en conférence et après réponse. La présentation des5choix doit rester lisible et accessible au clavier à1280×720.
6. Tests rouges puis verts des5options/IDsanciens, caractère distinct des tons, relations/styles/mémoire, import/export/reprise/mobilité, inconnus/refusdisque, puretéS/RNG et calendrierFrance34/historiqueS2. Revue indépendante ciblée avant livraison.

## Task9 — Gabi contextuel et caractère

Brief et rapport dans le workspace du plan, `task-9-gabi-brief.md` et `task-9-gabi-report.md`. Conserver les38enregistrements historiques ; nouveaux fragments explicitement pending. Intégrateur seul main/build/speech. Premièrevisite/événements factuels, petitesbulles et silence en direct, modes manuels/TOUR compatibles, reprise des préférences. Revue et correction navigation d'une bulle automatique avant réception EXE.

## Task10 — Navigation rapide native

Fichiers : nouveau `native/godot/ui/navigation_controller.gd`, nouveaux `tests/godot-navigation*.{cjs,gd}` ; parent seul raccord main.

- [ ] Tester les absences, accents, doublons de noms, résultats par ID, navigation interchapitres et retour après changement de carrière.
- [ ] Contrôleur `setup(app)`, `observe(route, player_id, staff_club)`, `reset()`, `controls()->Control`, `handle_shortcut(event)->bool`, `open_palette()`.
- [ ] Palette Ctrl+K : routes réellement autorisées et joueurs projetés effectif/marché, recherche accent-insensible, résultats limités, vide clair. Entrée ouvre le bon écran/dossier par ID ; Échap ferme d'abord la palette.
- [ ] Historique session borné60entrées, précédent/suivant Alt+gauche/droite, restauration de l'ID sélectionné, invalide nettoyé à nouvelle carrière/import. Ne pas capturer les flèches d'un champ texte ou d'une fenêtre tierce.
- [ ] Vrais contrôles3résolutions ; pas de S/RNG/écriture carrière ; revue indépendante avant intégration.

## Task11 — Mémoire du club et saisons comparées

Fichiers : nouveau `native/godot/ui/club_memory_view.gd`, nouveaux `tests/godot-club-memory*.{cjs,gd}`. Parent raccord `ClubViews.club` en deux onglets Territoire/Histoire sans supprimer accès crédits.

- [ ] Projection pure de division/rang/titre/mouvements dans model.archives.seasons, rencontres réellement disponibles de l'actuel club dans clubLife.clubWorld.events, et prises de poste conservées dans managerCareer.history.
- [ ] Chronologie datée/sources distinguées, filtres sport/club/saisons ; aucun passé antérieur inventé, aucune réaction fictive présentée comme fait.
- [ ] Deux saisons sélectionnables parmi celles réellement conservées, comparer rang dans sa division et titre/montée/descente ; ne pas comparer un rang1Accession comme supérieur mathématique au rang14Élite. Données absentes explicitement non conservées.
- [ ] IDs du pack et cas ancien/vide ; mobilité du coach distincte de l'histoire du club courant ; trois résolutions et pureté S/RNG/disque.

## Task12 — Journal du match lisible

Fichiers : nouveau `native/godot/ui/match_journal.gd`, modification `ui/match_screen.gd` aprèslibération ; nouveaux `tests/godot-match-journal*.{cjs,gd}`. Aucun match_view/règle/adaptateur métier modifié.

- [ ] Tester journal vide, anciens événements sanskind, score/minute réels, filtres accent/textes longs et évolution du live.
- [ ] Quatrième onglet Journal dans le panneau du match, catégories à partir des métadonnées réelles (Tous, Scores, Discipline, Changements, Conquête selon couverture). Ne pas déduire une sanction du seul texte d'un autre type.
- [ ] Garder filtres/focus/défilement lors des ticks ; annoncer nouveaux événements sans forcer le retour au bas pendant lecture. Retour direct au dernier événement explicite ; aucune promesse de replay moteur.
- [ ] Réception clavier/mouse aux trois tailles, match réel en pause et direct, export/RNG/disque identiques après consultations.

## Task13 — Préférences de confort distinctes de la carrière

Fichiers : nouveau `native/godot/ui/user_preferences.gd`, nouveau `ui/preferences_dialog.gd`, nouveaux `tests/godot-preferences*.{cjs,gd}` ; parent main, raccordsMatch/Portrait sérialisés après Task12 et Task9.

- [ ] Profil version1borné : volume général0–100, réduction des mouvements bool, qualité economy/balanced/detail, caméra tv/tactical/action. Aucun champ de carrière, pas de nouveau réglage de notes.
- [ ] Sauvegarde atomique dans le dossier de profil explicite, erreurs visibles, ancien/inconnu/malformé conservé, pas de repli ailleurs. Paramètres utilisables avant carrière.
- [ ] Volume ne change pas la préférence muet de Gabi. Mouvement réduit fige les mouvements décoratifs/transition de caméra sans cacher les positions ou événements, et ne change pas le temps du match.
- [ ] Valeurs effectives et interface cohérentes après reconstruction/restart, pack/import/nouvelle carrière ne modifient pas les préférences utilisateur. Tests lecturepure et Windowsgraphique.
## Task15 — Préparation en sous-onglets et courte hauteur

Résoudre la densité de la page actuelle par Dossier / Consignes / Entraînement, en conservant les commandes et paramètres sportifs, les listes tactiques de190unités et la mémoire UI horscarrière. Qualifier vraie main.tscn, clavier/souris et3résolutions avant revue. Le défaut de recherche Unicode/compteur import du Journal entre en round1 de correction, et sa disposition compacte est reçue en parallèle. Aucun basculement global1:1 avant comparaison visuelle après ces corrections et Gabi.

## Task16 — Gabi compact et stable à720p

Conserver toutes les répliques et fréquences déjà reçues. Adapter la petite bulleBD et le portrait à la largeur utile, simplifier le contexte automatique et stabiliser son placement ; garder commandes principales, titre, texte, options et erreurs accessibles. Une éventuelle réduction après lecture ne coupe jamais la parole ni les visites manuelles. Réception vraie UI, troisrésolutions et variante1:1 privée avant choix global.

## Task17 — Retour discret sur les décisions (N10)

Après correction des défauts démontrés, afficher dans le pied de page le dernier choix réellement appliqué et ses effets mesurés ; historique volontaire des dix derniers reçus de session, hors sauvegarde sportive. Distinguer contre-offre et signature, calcul réel et prévision, absence d'effet et décision répétée. Aucun reçu de succès après refus ou erreur. Parent seul raccord main, module pur et tests réels par producteur, revue indépendante. Pas de nouveau menu principal ni de grande notification flottante.

## Réception de l'échelle adaptative (N12)

L'audit initial ne justifiait pas une bascule1:1 immédiate. Après corrections courte hauteur, comparer une référence dynamique plafonnée à1600x900 : pixels natifs à720p/900p, confort actuel conservé à1080p. Prototype privé avant décision, toutesroutes/sous-onglets critiques reçus, pas de zoom arbitraire ni promesse DPI/4K non testée.

## Task18 — Cartes de composition et banc à courte hauteur

L'audit adaptatif établit18paires de cartes chevauchées à720p et une remontée après sélection du banc. Corriger la disposition des six rangées, conserver portraits et noms lisibles, et rétablir scroll/focus après reconstruction ; aucune règle de sélection ni qualification modifiée. Réception des15clics/23postes, reset/import, captures et revue avant choix global d'échelle. Réduire les espacements du tableau Effectif court si cela libère des lignes sans supprimer de filtres.

## Task19 — Cadrage et distinction visuelle des équipes

Conserver le modèle stylisé et les animations déjà reçues. Distinguer TV proche et fluide de la vue tactique entière, rapprocher la caméra Action, et résoudre les couleurs de maillots trop proches par une palette originale lisible. Présentation seule, aucune donnée sportive modifiée. Captures et continuité réelle, bords de terrain, changements de modes, préférence calme et mesures troisLOD ; le plaquage à deux corps reste explicitement partiel.

## Task20 — Intégration adaptative et redimensionnement

Après audit, choisir une référence dynamique plafonnée à1600x900. Recalculer la disposition au seuil de hauteur lors d'un vrai resize, sans perdre focus, banc, formulaires, lecture ou modales. Le guide replié utilise une place transparente dans le pied de page existant afin de rendre le bouton des décisions entièrement cliquable ; les bulles restent libres au-dessus. Contrat CoachCompactDock144x34, parent transfère main au producteur d'intégration et guide au producteur Gabi, chemins disjoints. Aucun stockage carrière ni réglage payant ajouté. Revue et captures intégrées avant paquet0.5.

## Task21 — Production vocale approuvée, si le quota le permet

Après4h37sansappel, un essai unique du même projet gratuit a réussi à14:59UTC. Reprendre horsproduction les74textes exacts avec Algenib/style approuvé, unappel àlafois etespacement>=25s ; arrêter au premier refus sanscontournement. Conserver11clips existants parhash/provenance. QCformat/texteASRlocale etécarts, aucunecopie dansjeu avantcouverturecomplète/revue. Si quota refuse, garder la voix provisoire explicitement et poursuivre les autres chantiers.
