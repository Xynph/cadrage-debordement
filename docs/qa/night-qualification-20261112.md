# Réceptions ciblées du 12 novembre 2026 : guards, Carnet et séance

Ce reçu conserve des exécutions Linux SDK locales distinctes, réalisées par root sous verrou Godot unique, puis documentées sans nouvelle exécution par l’agent QA. Il ne constitue pas une campagne globale ni un résultat du prochain CI. Aucun résultat Windows, animation ou FPS n’est qualifié ici. Les totaux attendus du registre (76/57/75 et JS646) restent des attentes, pas des résultats déduits de ces réceptions.

Les [preuves et empreintes](evidence/night-qualification-20261112/manifest.json) comprennent les logs originaux légers, quatre rapports guards compacts, les diagnostics séance filtrés, six PNG originaux et les [hashes des sources exactes](evidence/night-qualification-20261112/source-hashes.json). Aucun profil, historique complet ou modèle entier n’est publié. Le [manifeste de provenance](evidence/night-qualification-20261112/provenance-manifest.json) distingue copies inchangées et whitelist ; les hashes du rapport séance brut sont conservés sans publier ses 292606 octets.

## Sources et résultats séparés

Durées en millisecondes : « sous-test » est `duration_ms` du test Node ; « TAP » est la durée totale de ce processus Node. Elles ne sont pas une mesure isolée du worker ou du rendu.

| Cas | Source exacte | Résultat / sortie | Sous-test ms | TAP ms |
| --- | --- | --- | ---: | ---: |
| Guards graphique, référence locale | `1a7b083b8a090d735ef1b08245b5f4faf430f76b` | 103 contrôles, 0 échec / 0 | 118309.369241 | 118368.141499 |
| Guards graphique, visibilité | `4d5b0df8d218c0c1e6d64459603db91b18cc05c4` | 103 contrôles, 0 échec / 0 | 114570.704299 | 114643.38538 |
| Guards graphique, cache Art | `70305d1137be5779758472fcc9a4e8eec10f2e95` | 112 contrôles, 0 échec / 0 | 61704.369378 | 61760.28109 |
| Guards headless, cache inactif | `70305d1137be5779758472fcc9a4e8eec10f2e95` | 99 contrôles, 0 échec / 0 | 38756.059257 | 38825.98144 |
| Carnet sans captures, cible minimale corrigée | `340aa4ea61e7321545051f5890b486ea66806673` | 4672 contrôles, 0 échec / 0 | 74378.040811 | 74443.151494 |
| Carnet graphique, même correction | `340aa4ea61e7321545051f5890b486ea66806673` | 4726 contrôles, 0 échec / 0 | 159413.89923 | 159469.267201 |
| Séance graphique, régression ciblée | `4d5b0df8d218c0c1e6d64459603db91b18cc05c4` | 146 contrôles, 0 échec / 0 | 56512.938614 | 56579.669004 |

Les variantes headless et graphique ne s’additionnent pas pour annoncer une couverture nouvelle. Leurs différences de comptage incluent les assertions de captures. Les logs par cas sont dans les sous-dossiers portant les mêmes noms que dans le manifeste.

## Guards : visibilité et expérience de cache

L’échec CI initial sur `1a7` reste réel : le superviseur a interrompu le wrapper après **180007 ms**, statut nul, `ETIMEDOUT`, sans stdout enfant exploitable. La réussite locale du même code en 118368.141499 ms ne reproduit pas ce timeout et n’en établit pas la cause. Le log CI historique est conservé séparément dans les preuves existantes [du gel 1a7](evidence/night-qualification-20261112/history-ci-guards-1a7/guards-timeout-original.log).

Le wrapper guards transmet désormais les chunks stdout/stderr tout en collectant le contenu complet pour les regex et assertions finales. Les événements Node `begin` et `exit` sont présents dans le reçu visibilité. Root a observé `NIGHT_CHILD begin` et `NIGHT_PROGRESS initialize/run` pendant que Godot tournait. Le superviseur extérieur utilisant encore `spawnSync`, cela améliore la capture partielle disponible à sa sortie ou son timeout ; ce reçu ne prouve pas un affichage GitHub en direct. Délais 150/180, budget restant, cadence maximale 60 et absence de retry sont conservés.

L’expérience `703` reprend exactement le helper Art existant dans le test guards : seuls les SubViewports disposant d’une caméra 3D sont mis en cache entre vrais redraws de création/redimensionnement et redraws frais avant capture. Le viewport racine 2D reste actif ; Gabi, les scènes contextuelles et le match réels restent présents. Les **103 contrôles graphiques originaux** et le scénario complet sont préservés. Huit textures effectivement rendues et dimensionnées, plus un contrôle de fin des redraws différés, donnent **112** contrôles. `render_scope`, `cache_enabled=true` et les huit entrées `rendered_3d` sont sérialisés. Le reçu headless indique explicitement `cache_enabled=false` et `rendered_3d=[]` ; aucun nouveau contrôle de texture ni changement du comportement headless.

Root conserve ce pattern sûr après une durée TAP observée de **61.760 s**, contre **114.643 s** pour le précédent scénario réel similaire. **Les profils initiaux, seeds et clocks diffèrent entre exécutions. Ce n’est pas le même checkpoint ni une comparaison causale contrôlée.** Aucun gain général, diagnostic de cause CI, résultat FPS ou qualification d’animation n’en découle.

Chaque rapport guards contient quatre reçus indépendants : rendez-vous obligatoire, causerie obligatoire, match immersif et consultation du résultat historique. Dans chacun, les paires de hash profil, seed et clock sont égales avant/après, `state_unchanged=true` et `link_commands=0`. Ces valeurs réelles sont conservées ; leur égalité est interne à chaque consultation, pas transversale aux exécutions. Chaque reçu vérifie strictement parole demandée/démarrée/identifiant à **0/0/0**.

## Carnet et séance

Le rouge Carnet sur `1a7` reste conservé dans `final-carnet-1a7-red/wrapper.log` : **4666 contrôles dont 27 échecs**, portant sur la taille utilisable des nouveaux boutons séance, wrapper rouge. Le correctif `340` maintient la cible minimale après l’ajustement global de layout ; les deux réceptions suivantes restent distinctes, sans effacer ce rouge. Les logs Carnet contiennent les trois compteurs réels `requested=0 started=0 id=0` ; aucun champ vocal n’a été inventé dans un rapport Carnet absent.

La séance `4d5` est une nouvelle régression de 146 contrôles. Elle ne remplace ni le reçu historique AA8 de 132 contrôles ni le [reçu b860 de 146 contrôles](night-calendar-session-reading-20261112.md). Les diagnostics whitelistes gardent la date publiée sélectionnée **8 septembre**, le jour courant **7 septembre**, le filtre `matches`, le focus `CalendarWeekSessionLink_…` et les valeurs `CalendarProgramScroll` avant/après : clavier **12**, souris **130** dans cette exécution. Le brouillon non appliqué `standard` pour `weekly:1:0:league:0:13` est conservé au retour. La garde est préparée depuis le courrier de l’invitation réelle.

Le test séance vérifie les invariants modèle/profil/bridge/dernière commande/timer ; il ne sérialise pas de paires de hashes profil : aucune paire n’est reconstruite ici. Le rapport sérialise bien parole **0/0/0**. Le footer « moral 75→76 » visible provient de la conférence de préparation avant baseline, pas de la consultation de séance. Le créneau consulté est un programme publié, pas un compte rendu d’exécution. Les cas invalides/past/collision restent des projections synthétiques isolées sans capture ni persistance. Clavier/souris sont injectés dans le viewport SDK ; ce reçu ne reprend pas la qualification OS X11 native antérieure de 59 contrôles.

## Lecture visuelle des originaux

Six PNG sont publiés sans retouche ; les dimensions natives figurent dans le manifeste.

- Carnet : `calendrier-1280.png` **1280×800**, `calendrier-1440.png` **1440×900**, `calendrier-1920.png` **1920×1080**. Les suffixes sont des largeurs, pas trois captures 1440p. QA a inspecté les deux premières et root la troisième. Grille, jours et panneau programme restent lisibles ; certains noms d’adversaires de la grille compacte sont tronqués avec ellipse. Les scrollbars sont visibles. Une image seule ne valide ni hitarea ni activation ; ces propriétés relèvent des assertions SDK.
- Séance : `session-1440.png` **2560×1440**, inspectée QA. Semaine et jour sélectionné restent visibles, programme et axes par poste lisibles. Le nom historique du fichier ne remplace pas sa dimension native.
- Guards : deux PNG **2560×1440**, inspectés QA. Le match réel en pause est présent avec joueurs/terrain et commandes ; le dialogue historique affiche Toulouse–Vannes **18–40**. Le score appartient à cette exécution, pas aux autres checkpoints publics antérieurs. Ces captures fixes ne qualifient pas le mouvement du match.

Root a exécuté ces cas sous audio Dummy et contrôlé le silence. L’absence de `libspeechd` et l’avertissement V-Sync présents dans certains logs sont conservés tels quels ; ils ne sont pas présentés comme une preuve de silence. Aucun SDK, worker, nouvel input ni capture n’a été lancé pendant cette préparation documentaire. Le prochain résultat CI consolidé reste en attente.
