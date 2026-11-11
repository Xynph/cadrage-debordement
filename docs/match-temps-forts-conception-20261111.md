# Match « comme FM » : temps forts, coupes et écran intermédiaire — conception du 11 novembre 2026

Demande de Léo : « pour les matchs, réfléchis et recherche comment FM construit ses
matchs (temps forts notamment, skip quand le ballon sort en touche ou avant de
reprendre le jeu par exemple). Il faut plus ressembler à ça. »

Ce document est une conception, pas une livraison de jeu. Il s'appuie sur le code de
`origin/main` (`96f53704`), sur 24 matchs joués avec le vrai moteur natif et sur les
sources citées en fin de document. Il est accompagné d'un prototype de sélection des
temps forts (`native/engine/match-highlights.cjs`, pur calcul, branché sur aucun écran).

Convention de lecture : **[source]** = ce qu'une source dit ; **[code]** = lu dans le
dépôt ; **[mesuré]** = exécuté pendant ce travail ; **[déduit]** = conclusion personnelle ;
**[proposé]** = à réaliser.

## 1. En bref

1. **Le diagnostic n'est pas « le match est trop long », c'est « tout a le même poids ».**
   Aujourd'hui chaque ligne du journal reste 0,32 s à l'écran, un essai comme un
   changement de consigne adverse : 200 événements, environ une minute de 3D pour
   80 minutes [code, mesuré]. FM fait l'inverse : peu de moments, montrés à vitesse
   de jeu, et un écran de synthèse entre deux [source].
2. **Trois états d'écran** : *temps fort* (3D, vitesse de jeu), *écran intermédiaire*
   (terrain 2D, horloge accélérée, fil, chiffres, conseil du staff), *arrêt-décision*
   (le match attend le manager). Le match alterne entre les trois.
3. **Un temps fort est une fenêtre du journal** : il commence au lancement de l'action
   (touche ou mêlée déjà formée, renvoi, ballon récupéré), finit au ballon mort, et
   porte un score d'intérêt calculé sur des faits du moteur (type, zone, écart,
   minute, bonus en jeu).
4. **On coupe le trajet, pas la phase.** Au rugby, l'arrêt de jeu est l'endroit où le
   match se décide (pénalité : poteaux ou touche ; mêlée ; touche à 5 m). On saute la
   marche vers la remise en jeu, jamais la remise en jeu elle-même.
5. **Cinq niveaux, pas six** : commentaire seul, résumé, clés, étendus, match complet,
   plus un mode dynamique par défaut. Durées mesurées par le prototype : de 2 à 8
   minutes d'action. Un « match complet » de 25 minutes comme dans FM est hors de
   portée du moteur actuel (une action par minute simulée) ; il faut le dire.
6. **Le mode dynamique suit la tension, bonus compris.** Écart, minute, phase finale,
   et — spécifique au rugby français — bonus offensif et défensif encore en jeu.
7. **Pas de moteur « en avance »** : la première tranche revient en arrière sur des
   actions déjà simulées pour construire l'amorce. Les ordres du manager restent
   appliqués tout de suite, comme aujourd'hui.
8. **Le manager ne peut pas rater une décision** : le match s'arrête de lui-même sur
   carton, mi-temps, et sur les choix que le joueur s'est réservés ; le reste passe en
   notification non bloquante.
9. **Première tranche jouable** : alternance temps fort / écran intermédiaire sur les
   faits existants, derrière `CD_MATCH_TEMPS_FORTS=1`, sans toucher aux gestes ni à la
   vue 3D en cours de travail dans les PR 554 et 555.

## 2. Ce que fait Football Manager

### 2.1 Ce que disent les sources

| Sujet | Ce que dit la source | Source |
| --- | --- | --- |
| Niveaux de temps forts (FM22, FM23 console) | On peut regarder le match « entier » (« note, this is not actually 90 minutes »), des temps forts étendus, seulement les événements clés, ou aucun, avec le seul texte de commentaire. | Manuel officiel SI [S1][S2][S3] |
| Niveaux de temps forts (FM23, FM24) | Liste déroulante : Full Match, Comprehensive, Extended, Key, Only Commentary. Curseur « Match Speed During Highlights » au-dessous. | Guides tiers [S7][S8] |
| Entre deux temps forts | « there will be spells where there is no action to show » ; on y voit des informations clés sur le déroulement, et des conseils du staff « for you to take on board and action as you see fit ». | Manuel officiel SI [S1][S2][S3] |
| Horloge entre deux temps forts (FM Mobile 2024) | Réglage : « how quickly the clock moves when there is no action to show » ; surimpressions d'information activables pendant ces temps morts. Volets : Match Stats, Match Overview, notes des joueurs, zones d'action, scores des autres matchs, classement en direct. | Manuel officiel SI [S4] |
| Temps forts dynamiques (FM26) | « Dynamic Highlight mode adjusts the number of highlights you see based on the context of the match you're in. The more important and more dramatic a game, the more highlights you'll see. If you're already 4-0 up and closing in on victory, the number of highlights will drop accordingly. » | Site officiel [S5] |
| Écran intermédiaire (FM26) | Nouvel écran « Match Overview » entre les temps forts, avec la vue 2D classique intégrée, l'avis du staff, les nouvelles des autres matchs, et des cartes de données dépliables (xG, xA). | Site officiel [S5] |
| Écran intermédiaire (FM26, suite) | La vue 2D de l'écran intermédiaire suit positions et formes tactiques ; d'après la page, cliquer dessus mène au temps fort correspondant. | Site officiel [S6] |
| Écran intermédiaire (FM27) | L'écran entre les temps forts accepte l'échange de tuiles ; retour des cartes de chaleur et des zones d'action ; le staff signale les changements tactiques adverses. | Site officiel [S9] |
| Ralentis | Activables ou non (manuel). FM26 : l'angle du ralenti dépend du type de but. FM Mobile : ralentis de but activables, vitesse réglable. | [S1][S4][S5] |
| Interventions | Boutons de raccourci pour remplacements et changements tactiques ; « Full Tactics » ouvre l'écran complet ; cris depuis le bord du terrain ; tablette pour interroger le staff. | Manuel officiel SI [S1][S2] |
| Interventions (FM Mobile 2024) | Sur événement important (blessure…), une fenêtre s'ouvre avec le contexte donné par l'adjoint ; « At the first pause in play you will be taken to the Tactics screen ». | Manuel officiel SI [S4] |
| Prise en compte des ordres (FM 2010) | Le remplaçant entre « in the next break in play » ; les consignes ne sont pas appliquées tout de suite et sont transmises « during the next break in play » ; il est conseillé de mettre en pause avant d'ouvrir la tactique, sinon le match continue. | Guide tiers ancien [S10] |
| Consignes rapides (FM27) | « Tactical Tweaks » appliqués depuis le bord du terrain sans passer par l'écran tactique, actifs tant qu'on ne les retire pas ; le staff conseille quand en activer ou en retirer. | Site officiel [S9] |
| Avant et après | Réunion du staff d'avant-match, réaction à la feuille de match, causerie ; causerie de mi-temps ; à la fin, tour des autres résultats et réactions des médias. FM26 : séquences d'avant et d'après-match refaites. | [S1][S5] |
| Réglages (FM26) | Temps forts dynamiques ; type de temps forts ; vitesse pendant et entre les temps forts (une vitesse trop élevée rend le match difficile à lire et à corriger). | Guide tiers [S11] |

### 2.2 Ce que je n'ai pas trouvé dans une source

- **Le début et la fin exacts d'un temps fort** (combien de secondes avant l'action
  décisive, quand il s'arrête) : aucune source consultée ne le dit. Ce que j'en sais
  vient de l'usage du jeu et n'est pas vérifié ici : un temps fort commence pendant la
  construction, se termine peu après la conclusion, et un coup de pied arrêté apparaît
  joueurs déjà placés. **[déduit, non sourcé]**
- **La durée réelle d'un match par niveau** : le fil de forum consulté [S12] ne donne
  aucun chiffre. Mes ordres de grandeur (5 à 10 minutes en « clés », plusieurs dizaines
  en « match entier ») sont des souvenirs d'usage, **non vérifiés**.
- **Les critères de choix d'un temps fort par niveau** : non publiés à ma connaissance.

### 2.3 Autres jeux de management

- **Tennis Manager** (test tiers de l'édition 2023 [S13]) : match 3D en temps réel, quatre
  caméras, vitesse réglable ; on peut choisir quels temps forts on voit pour avancer plus
  vite ; consignes d'intensité par situation (service, retour, **points importants**),
  tactique et parole au joueur pendant le match ; simulation rapide pour les premiers
  tours. À retenir **[déduit]** : la notion de « point important » comme unité de
  condensation, proche de notre score d'intérêt.
- **Pro Cycling Manager** : je n'ai pas trouvé de source lisible sur la présentation de
  course (le guide en ligne de l'éditeur n'affiche pas son texte [S14]). Ce que j'en
  connais — course 3D à accélération réglable, simulation rapide ou détaillée — est
  **non vérifié** et ne fonde aucune décision ici.
- **Jeux de management de rugby** : National Rugby Manager annonce un match 2D ou 3D, la
  stratégie modifiable en direct et des ralentis des meilleurs essais **en fin de match**
  [S15] ; Pro Rugby Manager 2 proposait 2D, 3D ou simulation, avec ordres en direct [S16].
  Aucun ne décrit un système de temps forts à la FM : il n'y a pas de modèle rugby à
  copier **[déduit]**.

## 3. État des lieux du jeu (`origin/main`, `96f53704`)

### 3.1 Simulation

- Un pas de simulation = **une minute de jeu** : `advanceRugby(l)` (`dist/rugby.js`)
  incrémente `l.minute`, puis `advanceCausalPlay` (`dist/restarts.js`) tire **une action** :
  pénalité, faute de main, sortie en touche, jeu au pied ou progression balle en main ;
  l'action entraîne sa suite dans le même pas (pénalité → carton → tir ou pénaltouche →
  alignement → conquête → essai → renvoi). **[code]**
- Chaque fait est une ligne du journal `l.events` : `{min, period, type, text, scene}`.
  La scène (`captureMatchAction`, `dist/match-actions.js`) porte `kind`, `team`,
  `possession`, `from`, `to`, `score`, `tries`, `move`, `incident`, `actor`, `plans`, `on`
  (les 2 × 15 joueurs présents). Elle n'existe que pour le match du joueur
  (`l.userSide >= 0`). **[code]**
- 25 valeurs de `kind` : `message`, `carry`, `turnover`, `scrum`, `lineout`,
  `setpiece-win`, `setpiece-loss`, `kick`, `kickoff`, `drop22`, `goalLine`, `reception`,
  `touch`, `hand-fault`, `try`, `goal`, `miss`, `penalty`, `advantage`, `card`, `sub`,
  `tactic`, `break`, `end`, `ingoal`. **[code]**
- Le moteur produit : essais (avec transformation **dans le même événement**), pénalités
  tentées, cartons jaunes et rouges, avantage, 50:22, ballon tenu en but, en-avant dans
  l'en-but, renvois aux 22 et sur la ligne, mêlées non disputées. Il **ne produit pas** :
  drop, blessure en cours de match (les blessures sont appliquées après le coup de
  sifflet), essai de pénalité, arbitrage vidéo. **[code, mesuré]**
- Les autres matchs de la journée sont simulés **à la validation de la journée**
  (`finishRound`), pas pendant le direct. **[code]**

### 3.2 Direct

- Le minuteur de `native/godot/main.gd` envoie `tick` toutes les **0,32 s** ; chaque
  `tick` avance d'**un événement** (`presentationTick` : s'il reste des événements de la
  minute à montrer, il avance le curseur ; sinon il simule la minute suivante). La
  cadence ×4 ou ×12 envoie 4 ou 12 pas par requête : seules une scène sur 4 ou sur 12
  sont affichées. **[code]**
- Seule attente variable aujourd'hui : la passe longue projetée
  (`is_presenting_extended_pass`, 0,52 s). La PR 554 étend ce mécanisme aux gestes
  (touche, ballon porté, essai) : la séquence témoin passe de 3,2 s à 16 s. **[code, doc PR 554]**
- **« Coupe » dans le code actuel = crochet du porteur**, pas coupe de montage :
  `native/godot/match_cut.gd`, `tests/godot-match-cut.*`, `tests/animation-live-cut.cjs`
  testent l'appui et le changement de direction ; `tests/match-pass-live.cjs` la passe
  projetée. Il n'existe aucune coupe de réalisation sur `main`. **[code]** Je propose
  d'appeler la nouvelle notion **« coupe de réalisation »** partout, pour ne pas
  confondre.
- Écran (`native/godot/ui/contextual/live_view.gd`) : bandeau score et horloge, les deux
  dernières lignes du journal, tiroirs Tactique / Banc / Stats / Journal, trois caméras
  (TV, tactique, contact), cadence ×1 / ×4 / ×12, « Confier la fin à l'adjoint ». **[code]**
- Déjà disponibles et réutilisables **[code]** :
  - journal filtrable (`ui/match_journal.gd` : Tous, Scores, Discipline, Changements, Conquête) ;
  - revue d'action avec terrain schématique (`match_action_review.gd`, classe `ActionPitch`,
    et une première liste d'événements « clés » `KEY_KINDS`) ;
  - statistiques `live.statsRows` : possession, territoire, mêlées et touches conservées,
    pénalités concédées, cartons, tirs, transformations ;
  - compteurs tactiques du moteur `l.tacticalStats` (courses, mètres, longs gains, jeu au
    pied, fautes de main, récupérations), non affichés en direct ;
  - conseil de l'adjoint `decisions.liveAdvice` (« Le regard de l'adjoint », bouton
    « Appliquer ces consignes ») ;
  - causeries d'avant-match, de mi-temps et d'après-match (`native/engine/match-talks.cjs`) ;
  - préférences `user_preferences.gd` : caméra, qualité, mouvements réduits, stade de soirée.
- Interventions du manager **[code]** : consignes d'attaque et de défense (`set_tactics`) et
  remplacements (`substitute`), **seulement match en pause** et présentation à jour. La
  mise en pause saute la présentation à l'état courant du moteur. La politique de
  pénalité (auto / points / touche, `l.penaltyPolicies`) et le carnet de jeu (combinaisons
  de touche, mêlée, renvoi) existent dans le moteur mais **n'ont pas de commande native
  pendant le match**. La pause automatique sur essai ou carton existe dans le moteur
  (`pauseOnTry`, `pauseOnCard`) mais n'a pas de réglage natif.

### 3.3 Mesures (24 matchs, moteur natif, première journée, graines et clubs variés)

Méthode : sonde hors dépôt (`/home/claude/audit/temps-forts/sonde.cjs`) qui crée une
carrière par le vrai `worker.cjs`, lance le match et le confie à l'adjoint (`delegate`).
J'ai vérifié sur un match que le journal obtenu ainsi est identique, ligne pour ligne,
à celui du match joué pas à pas (206 événements). **[mesuré]**

| Mesure par match | Moyenne | Minimum – maximum |
| --- | --- | --- |
| Événements du journal | 200,5 | 185 – 227 |
| Minutes simulées (arrêts de jeu compris) | 85,5 | 82 – 88 |
| Événements par minute | 2,3 (médiane 2) | 1 – 8 |
| Plans jouables en 3D / bandeaux (avantage, consigne, remplacement, message) | 155,8 / 44,7 | — |
| Points marqués / essais / écart final | 34,8 / 4,2 / 9,7 | 19–52 / 1–6 / 1–23 |
| Durée du direct actuel à ×1 (200,5 × 0,32 s, **calculée**, hors attentes de passe et délai du moteur) | ≈ 64 s | — |

| `kind` | Par match | Part |
| --- | --- | --- |
| `advantage` | 26,9 | 13,4 % |
| `carry` | 21,1 | 10,5 % |
| `setpiece-win` | 20,4 | 10,2 % |
| `touch` | 16,8 | 8,4 % |
| `turnover` | 16,3 | 8,1 % |
| `lineout` (mise en place) | 13,8 | 6,9 % |
| `scrum` (mise en place) | 11,7 | 5,8 % |
| `reception` | 10,3 | 5,1 % |
| `penalty` | 10,0 | 5,0 % |
| `kickoff` | 8,7 | 4,3 % |
| `sub` | 8,0 | 4,0 % |
| `tactic` | 6,6 | 3,3 % |
| `hand-fault` | 6,4 | 3,2 % |
| `setpiece-loss` | 5,1 | 2,5 % |
| `try` | 4,2 | 2,1 % |
| `card` (dont 1,5 carton infligé, le reste des retours) | 2,8 | 1,4 % |
| `goal` | 2,7 | 1,3 % |
| `miss` (dont 1,5 tir manqué) | 2,4 | 1,2 % |
| `kick`, `message`, `break`, `end`, `drop22`, `ingoal`, `goalLine` | 1,3 – 0,6 chacun | < 1 % |

Faits rares ou absents sur ces 24 matchs **[mesuré]** : franchissement d'au moins 22 m
4,8 par match ; ballon tenu en but 0,5 ; en-avant dans l'en-but 0,1 ; touche à 10 m ou
moins de la ligne 0,4 ; mêlée à 10 m ou moins 0,5 ; carton rouge 0,2 ; **50:22 : aucun** ;
combinaison « ballon porté » : **aucune** (le carnet par défaut lance « équilibré »), alors
que 0,8 essai par match est annoncé « sur ballon porté » par le texte.

### 3.4 Constats critiques

1. **Tout a le même temps d'écran.** 13 % des lignes sont des messages d'avantage
   (« Avantage sur en-avant », « Aucun avantage obtenu : retour à la mêlée ») qui
   occupent l'écran autant qu'un essai.
2. **Une action par minute.** Le « match complet » du moteur contient environ 156 plans :
   à durée naturelle, moins de 8 minutes (§ 4.4). Les niveaux hauts de FM ne se
   distinguent donc pas ici ; il n'y a pas de matière pour 25 minutes.
3. **72 % des essais arrivent sans aucun plan avant eux dans la même minute** **[mesuré]** :
   la construction est dans les minutes précédentes. Un temps fort doit pouvoir remonter
   au-delà de la minute courante.
4. **Essai et transformation sont un seul événement** : la « transformation prête » est un
   plan de présentation à déduire du score (5 ou 7 points), pas un fait séparé.
5. **Plusieurs causes ne sont lisibles que dans le texte** : 50:22, pénaltouche, ballon tenu
   en but, en-avant dans l'en-but, couleur du carton, essai « sur ballon porté ». Le
   moteur les connaît (`RESTART_CAUSES`, `origin`), mais ne les écrit pas dans la scène.
   Or la règle du dépôt est « jamais déduit de la prose ».
6. **Incohérence déjà présente** : « essai sur ballon porté » est annoncé pour toute touche
   proche de la ligne conclue par un essai, même quand la combinaison jouée n'est pas le
   ballon porté. Le geste de la PR 554 lit la combinaison : il ne montrera pas de maul sur
   ces essais. À arbitrer côté moteur (lot 1).
7. **La pause fait sauter l'image** à l'état courant du moteur : gênant dès qu'un temps
   fort dure plusieurs secondes.

## 4. Conception pour le rugby à XV

### 4.1 Trois états d'écran

```
                 action retenue                     fin d'action, rien à suivre
 ÉCRAN INTERMÉDIAIRE ───────────────▶ TEMPS FORT ───────────────────────────▶ ÉCRAN INTERMÉDIAIRE
        │   ▲                              │
        │   │ décision prise               │ carton, mi-temps, choix réservé
        ▼   │                              ▼
      ARRÊT-DÉCISION ◀─────────────────────┘
```

- **Écran intermédiaire** : l'horloge court (1,5 s par minute de match par défaut), le
  terrain 2D montre où est le ballon et qui l'a, le fil défile. Une minute = une requête
  au moteur.
- **Temps fort** : la 3D joue une suite de plans à vitesse de jeu, avec des coupes de
  réalisation sur les temps morts. Le jeu ne demande rien au moteur pendant ce temps : il
  rejoue une liste de scènes déjà calculées.
- **Arrêt-décision** : le match attend. Carte de décision au premier plan.

**Sans moteur en avance.** FM calcule en avance et rejoue ; ici ce serait coûteux et
dangereux (ordres appliqués avec retard, ou resimulation). À la place **[proposé]** : quand
la minute simulée contient une action retenue, le temps fort **revient en arrière** sur
les plans déjà simulés des minutes précédentes — que l'écran intermédiaire n'a montrés
qu'en 2D et en une ligne de texte — et les joue en 3D jusqu'à l'action. L'horloge
affichée pendant le temps fort est celle du plan joué. Aucun fait futur n'est connu
d'avance, donc aucun ordre du manager n'est appliqué « dans le passé ».

Pour la suite d'une action (touche à 5 m : que donne-t-elle ?), le temps fort **reste
ouvert** : tant que la minute suivante prolonge l'action (même équipe, toujours dans les
22, ou nouvelle action retenue), on reste en 3D ; sinon on rend la main à l'écran
intermédiaire.

### 4.2 Typologie des temps forts

Base = intérêt avant contexte, sur 100. « Amorce » = plans remontés avant l'action
décisive ; elle s'arrête toujours au **lancement** de l'action (alignement ou mêlée déjà
formés, renvoi, ballon récupéré) et ne franchit jamais un ballon mort antérieur. Tout ce
qui suit est implémenté dans le prototype, sauf mention « absent du moteur ».

| Temps fort | Fait du moteur qui le déclenche | Début | Fin | Base |
| --- | --- | --- | --- | --- |
| **Essai** | `kind:'try'` | Lancement de l'action : jusqu'à 2 plans (clés), 4 (étendus) | Transformation jouée ; le renvoi est coupé | 100, toujours montré |
| **Pénalité réussie** | `kind:'goal'` | Coup de sifflet (`penalty`), carton éventuel | Drapeaux levés | 74, toujours montrée (sauf match plié en dynamique) |
| **Pénalité manquée** | `type:'miss'` | Coup de sifflet | Ballon mort ou récupéré | 64 |
| **Carton rouge** | `card` avec `incident`, cause « rouge » | Coup de sifflet | Sortie du joueur, décision qui suit | 94, toujours montré |
| **Carton jaune** | `card` avec `incident` | Coup de sifflet | Idem | 80 |
| **Essai refusé** (en-avant dans l'en-but) | `ingoal`, cause `ingoal-knock-on` | Lancement de l'action | Renvoi sur la ligne coupé | 84 |
| **Ballon tenu en but** | `ingoal`, cause `held-up` | Lancement de l'action | Idem | 82 |
| **50:22** | `touch`, cause `50-22` | Le coup de pied | Alignement formé, conquête | 64 |
| **Touche à 5 m** | `lineout` à 10 m ou moins de la ligne adverse | Alignement **déjà formé** | Jusqu'à 3 plans après la mise en place (conquête comprise), ou ballon mort | 60 (54 entre 6 et 10 m) |
| **Mêlée à 5 m** | `scrum` (mise en place) à 10 m ou moins | Packs **déjà liés** | Idem | 58 (52) |
| **Ballon porté** | `setpiece-win` avec `move:'maul'` dans les 22 | Alignement formé | Arrêt du maul ou essai | 58 à 10 m ou moins, sinon 50 |
| **Franchissement** | `carry` d'au moins 22 m (seuil `longGains` du moteur) | Amorce normale du niveau | Plaquage ; un plan de plus en « étendus » | 50 ; 60 s'il entre dans les 22 |
| **Près de la ligne** | `carry` finissant à 8 m ou moins | Lancement | Un plan après | 54 |
| **Pression dans les 22** | au moins 2 plans de suite de la même équipe dans les 22 | Premier plan dans les 22 | Dernier plan de la série | 36 + 8 par plan, plafond 72 |
| **Ballon sauvé** | `turnover` ou `setpiece-loss` gagné par la défense dans ses 22 | L'attaque qui précède | La récupération | 54 ; 62 à 10 m ou moins |
| **Ballon gratté haut** | même fait, à 30 m ou moins de la ligne adverse | Idem | Un plan après | 50 |
| **Conquête volée** | `setpiece-loss` ailleurs | Mise en place formée | La prise | 40 |
| **En-but sous pression** | `ingoal`, cause `defender-grounded` (mêlée à 5 m à suivre) | Lancement | La mêlée formée | 58 |
| **Coup d'envoi** / **reprise** | premier `kickoff` / premier après `break` | Tireur prêt | Réception + un plan | 45 (toujours montré) / 40 |
| **Fin de match serrée** | dernier plan jouable si l'écart final est de 7 points ou moins | Amorce normale | Coup de sifflet final | 80, toujours montrée |
| **Pénalité sifflée à portée**, **faute de main dans les 22**, **long jeu au pied**, **en-but défendu** | `penalty` à 45 m ou moins ; `hand-fault` dans les 22 ; `kick` de 35 m ou plus ; `ingoal` autres causes | — | — | 30, 38, 26, 36 : niveau « étendus » seulement si le match est tendu |
| **Drop**, **blessure**, **essai de pénalité**, **arbitrage vidéo** | **absents du moteur** | — | — | prévus : 70, 60, 100, +10 |

Un carton **contre mon équipe**, une blessure, un essai encaissé ne sont pas plus
« intéressants » qu'en face : le score d'intérêt reste neutre. Ce qui change, c'est
l'arrêt-décision qui suit (§ 4.7).

### 4.3 Score d'intérêt

`score = base × (0,72 + 0,56 × tension)`, plus 12 si l'action change le meneur ou ramène
l'écart à 7 points ou moins, borné à 100. Toutes les entrées existent dans la scène :
`kind`, `team`, `possession`, `from.x`, `to.x`, `score`, `tries`, `move`, `incident`,
minute et période de l'événement.

**Tension** (de 0 à 1), calculée au moment de l'action :

| Entrée | Effet |
| --- | --- |
| Écart au score **avant** l'action | 3 points ou moins : 1,0 ; 7 ou moins : 0,9 ; 14 ou moins : 0,62 ; 21 ou moins : 0,42 ; au-delà : 0,2 |
| Dernières vingt minutes | +0,15 si l'écart est de 7 ou moins ; −0,10 s'il dépasse 21 |
| Fin de première période (37e et après), écart de 14 ou moins | +0,05 |
| Dix premières minutes | −0,15, sans descendre sous 0,5 |
| Bonus en jeu après la 55e (hors phase finale) : écart de 4 à 12 points (bonus défensif à 5), ou 2 ou 3 essais d'écart (bonus offensif à 3) | +0,12 |
| Match à élimination | +0,10 |

Zone et série de phases entrent dans la **base** (touche à 5 m, près de la ligne, pression
dans les 22), pas dans un multiplicateur : un franchissement de ses propres 22 jusqu'au
milieu vaut moins qu'une entrée dans les 22 adverses, quel que soit le score.

**Limite** : la « série de phases » n'existe pas dans le moteur. Elle est approchée par le
nombre de plans consécutifs de la même équipe. Un vrai compteur de temps de jeu
demanderait une simulation plus fine que la minute (hors périmètre).

### 4.4 Niveaux et durées

Durées de plan visées, à vitesse normale **[proposé]** : progression balle en main 4,5 s ;
jeu au pied 4 s ; réception 2,5 s ; alignement formé 1,5 s puis lancer-prise 2 s ; ballon
porté 7 s ; mêlée liée 1,5 s puis sortie 4 s ; récupération 3 s ; faute de main 2 s ;
coup de sifflet 1,5 s ; carton 3 s ; tir au but 6 s (5,5 s manqué) ; essai 5 s puis
transformation 4,5 s ; renvoi 3 à 3,5 s ; entrée 0,6 s, sortie 0,8 s, coupe 0,3 s ;
ralenti 6 s. Les durées de la touche, du ballon porté et de l'essai reprennent celles
mesurées par la PR 554.

Résultat du prototype sur les 24 matchs **[mesuré]**. « Total » = action + horloge de
l'écran intermédiaire à 1,5 s par minute sautée, hors pauses et causeries.

| Niveau | Ce qu'il montre | Temps forts | Action | Total | Plans sautés | Minutes sautées |
| --- | --- | --- | --- | --- | --- | --- |
| **Commentaire seul** | écran intermédiaire uniquement | 0 | 0 | 2 min 09 | 100 % | 100 % |
| **Résumé** | ce qui change le score ou l'effectif, amorce d'un plan | 7,3 (5–10) | 1 min 54 (1 min 03 – 2 min 45) | 3 min 46 | 90,6 % | 87,5 % |
| **Clés** (seuil 78, amorce 2) | + cartons, tirs manqués, essais refusés, ballons sauvés près de la ligne, coup d'envoi | 11,3 (6–16) | 2 min 43 (2 min 03 – 3 min 30) | 4 min 22 | 81,3 % | 76,9 % |
| **Étendus** (seuil 56, amorce 4) | + franchissements, pression dans les 22, conquêtes volées, touches et mêlées à 5 m | 16,8 (13–20) | 4 min 46 (4 min 03 – 5 min 54) | 5 min 46 | 55,3 % | 46,6 % |
| **Dynamique** (seuil de 54 à 80 selon la tension) | entre clés et étendus, selon l'enjeu | 14,0 (8–20) | 3 min 53 (2 min 10 – 5 min 30) | 5 min 10 | 66,7 % | 59,3 % |
| **Match complet** | tous les plans, temps morts coupés | 2 périodes | 7 min 45 (6 min 55 – 8 min 37) | 7 min 45 | 0 % | 0 % |

Un temps fort dure en moyenne 14,5 s en « clés » (médiane 12,2 ; maximum 31,3) et 17,1 s
en « étendus » (maximum 57,6).

**Budget de temps.** Chaque niveau a une durée d'action cible (résumé : 2 min 30 au plus ;
clés : 2 à 3 min 30 ; étendus : 4 min 30 à 6 min 30 ; dynamique : 2 à 7 min). Match
pauvre : le seuil baisse par paliers de 4 points jusqu'à tenir le minimum. Match trop
riche : les temps forts non « toujours montrés » les moins intéressants sont retirés.
Conséquence voulue : **la durée d'un match est prévisible**, ce qui compte quand on
enchaîne une saison. En direct, ce réglage a posteriori devient un régulateur : toutes
les dix minutes de match, comparer le temps d'action cumulé à la cible et déplacer le
seuil de 4 points.

**Mode dynamique**, à la manière de FM26 **[mesuré]** : quand la tension est d'au moins 0,8,
44 % des plans sont montrés ; quand elle est de 0,45 ou moins, 8 %. Par match : écart
final de 7 points ou moins, 4 min 14 d'action et 15,4 temps forts ; écart de plus de 14,
3 min 22 et 12,8. Dans un match plié (tension sous 0,35), une pénalité réussie n'est plus
« toujours montrée » : elle passe par le fil et le score clignote. Les essais et les
cartons rouges restent toujours montrés, avec une amorce réduite à un ou deux plans.

**Je recommande** le mode dynamique par défaut, et de ne pas proposer « Complets » de FM :
entre « étendus » et « match complet », il n'y a pas assez de matière pour un cran de plus.

### 4.5 Coupes de réalisation

Principe : **on coupe le trajet, on garde la phase.** Coupe franche par défaut (c'est la
grammaire de la télévision et elle est instantanée à lire) ; fondu réservé aux
changements d'état d'écran.

| Temps mort | On quitte sur | On arrive sur | Transition | Fait du moteur |
| --- | --- | --- | --- | --- |
| Sortie en touche | Ballon qui franchit la ligne (1,5 s) | **Alignement formé**, lanceur ballon en main (1,5 s), puis lancer | Coupe franche | `touch` → `lineout` (mise en place) |
| Pénalité → poteaux | Coup de sifflet, lieu de la faute (1,5 s) | **Tireur prêt**, ballon sur le tee (2 s), tir, drapeaux | Coupe franche | `penalty` → `goal` ou `miss` |
| Pénalité → touche | Coup de sifflet | **Alignement formé** au point de sortie ; le coup de pied en touche n'est montré qu'en « match complet » | Coupe franche | `penalty` → `touch` (cause pénaltouche) → `lineout` |
| Carton | Coup de sifflet | Joueur sanctionné isolé, carton au bandeau (3 s) | Coupe franche | `penalty` → `card` avec `incident` |
| Faute de main → mêlée | La faute (2 s) | **Packs liés**, demi de mêlée ballon en main (1,5 s), introduction | Coupe franche | `hand-fault` → `scrum` (mise en place) |
| Essai → transformation | Ballon aplati, bras levés (5 s) | **Buteur prêt** face aux poteaux (plan déduit), tir, résultat | Coupe franche ; ralenti éventuel avant | `try` (transformation dans le même événement) |
| Points marqués → renvoi | Résultat du tir | Écran intermédiaire ; ou, si la réception lance une action retenue, **équipes en place**, botteur prêt | Fondu 0,8 s vers l'écran intermédiaire ; coupe franche sinon | `kickoff` → `reception` |
| Ballon mort → renvoi aux 22 ou sur la ligne | L'action d'en-but (3,5 s) | Botteur prêt sur sa ligne | Coupe franche | `ingoal` ou `miss` → `drop22` / `goalLine` |
| Avantage non obtenu | — | Retour **direct** à la mêlée ou à la pénalité déjà en place | Coupe franche, bandeau « retour à la faute » | `advantage` |
| Mi-temps, fin | Coup de sifflet (2 à 3 s) | Écran de mi-temps ou de résultat | Fondu 0,8 s | `break`, `end` |
| Entrée et sortie de temps fort | Écran intermédiaire | Premier plan / écran intermédiaire | Fondu 0,6 s à l'entrée, 0,8 s à la sortie | — |

**Jamais montré en 3D** (bandeau ou fil seulement) : annonce et fin d'avantage, consigne
adverse, remplacement (un bandeau « 16 entre, 2 sort »), retour de carton jaune, message de
météo, la ligne « le tir manqué devient mort », les joueurs qui marchent vers une remise en
jeu, le ballon qu'on va chercher. En « clés » et « étendus », le coup de pied de pénaltouche
et le renvoi après des points ne sont pas montrés non plus.

**Existant** : la PR 554 fait attendre le match pendant un geste et recadre la caméra ; la
PR 555 met les avants en marche vers l'alignement dès la sortie en touche ; l'autre agent
ajoute une coupe vers les remises en jeu derrière `CD_MATCH_GESTES=1`. Cette table est
la liste complète à couvrir ; **manque** : tireur prêt, buteur prêt, packs liés, joueur
sanctionné isolé (poses à créer), et un plan « transformation » qui n'a pas d'événement.

**Désaccord assumé avec une lecture littérale de la demande.** « Skip quand le ballon sort
en touche » : oui pour le trajet, non pour la touche. Sauter les 14 touches et les 12
mêlées d'un match ôterait au joueur la seule preuve visible de ce qu'il a construit
(alignement, première ligne, combinaisons du carnet). Dans les niveaux bas elles ne sont
montrées que si elles comptent (à 5 m, volées) ; mais quand on les montre, on les montre
en place et jouées.

### 4.6 Écran intermédiaire

Contenu et hiérarchie seulement ; l'habillage revient à la graphiste. Par ordre de
priorité de lecture :

1. **Score, horloge, possession.** L'horloge court visiblement plus vite ; un témoin dit
   pourquoi on n'est pas en 3D (« jeu au milieu du terrain »). *Existe* : bandeau de
   `live_view.gd`, `live.minute`, `live.score`. *Manque* : témoin de possession
   (`scene.possession`).
2. **Terrain 2D vu de dessus**, plus grand élément de l'écran : bande de 10 m où se trouve
   le ballon, sens du jeu, équipe en possession, trace des trois dernières actions,
   repères des temps forts passés (essai, pénalité, carton) **cliquables pour les revoir**.
   C'est lui qui raconte l'occupation, ce que dix secondes de 3D ne peuvent pas faire.
   *Existe* : `live.scene` (30 joueurs et ballon), `ActionPitch`, revue d'action.
   *Manque* : la bande de zone et les repères.
3. **Fil de commentaire** : quatre lignes, la dernière en évidence, sans les messages
   d'avantage ni les retours de carton. *Existe* : `match_journal.gd` et ses filtres.
4. **Six chiffres du rugby**, mon équipe contre l'adversaire : occupation, possession,
   conquête (touches et mêlées gagnées sur ses lancers), pénalités concédées et cartons,
   franchissements, ballons perdus. *Existe* : `statsRows` pour les quatre premiers,
   `tacticalStats` (`longGains`, `handErrors`) pour les deux derniers, à projeter.
   *Absent du moteur* : plaquages, rucks gagnés, mètres après contact.
5. **Élan du match** : barre des dix dernières minutes (qui a joué chez qui), calculée du
   journal. *Manque* ; calcul simple sur `scene.to.x`.
6. **Le regard de l'adjoint** : un seul conseil à la fois, avec sa raison et le bouton
   pour l'appliquer. *Existe* : `decisions.liveAdvice`. *Manque* : signaler qu'il a changé.
7. **Mon équipe** : quinze pastilles de fraîcheur, cartons en cours avec leur minute de
   retour, remplacements restants. *Existe* : `live.lineup` (`condition`),
   `live.substitutions`. *Manque* : la minute de retour (connue du moteur, `cards[].until`).
8. **Autres matchs** : scores de la journée. *N'existe pas en direct* (§ 3.1) ; lot 7.
9. **Commandes** : pause, vitesse de l'horloge, Tactique, Banc, « Confier à l'adjoint ».

Sur cet écran, la 3D n'est pas rendue (ou figée et assombrie derrière) : c'est aussi un
gain de performance sur les machines modestes.

### 4.7 Interventions du manager

- **Quand le match s'arrête de lui-même (arrêt-décision)** : carton contre mon équipe
  (qui sort, qui couvre ; première ligne) ; carton rouge adverse ; mi-temps ; blessure
  (quand le moteur en produira) ; pénalité pour mon équipe **si** le joueur a choisi
  « me demander » (poteaux, touche, à portée seulement) ; fin de match. Après un essai
  encaissé : arrêt en option, désactivé par défaut.
- **Notification non bloquante** (bandeau sur l'écran intermédiaire, 4 s, cliquable) :
  nouveau conseil de l'adjoint, consigne adverse changée, remplacement adverse, retour
  d'un carton, joueur sous 50 % de fraîcheur, 60e minute sans remplacement.
- **Jamais d'arrêt pendant un temps fort** : la carte attend la fin du plan en cours.
- **Ouvrir Tactique ou Banc met en pause** (réglage, activé par défaut). On peut aussi
  préparer ses ordres sans pause.
- **Application** : avec la première tranche, moteur et écran sont à la même minute hors
  temps fort ; l'ordre s'applique à la minute suivante, comme aujourd'hui. Un ordre donné
  **pendant** un temps fort s'applique à sa sortie ; l'écran l'annonce (« Consigne
  transmise au prochain arrêt de jeu »). C'est ce que décrit le guide de FM 2010 [S10], et
  c'est plus juste au rugby qu'au football : l'entraîneur est en tribune, les consignes
  passent aux arrêts.
- **Consignes rapides** **[proposé]**, à la manière des « tweaks » de FM27 [S9] : trois
  boutons toujours visibles — *prendre les points / chercher la touche* (existe :
  `penaltyPolicies`, sans commande native), *occuper au pied / garder le ballon* (existe :
  consignes d'attaque), *ballon porté sur nos touches* (existe : carnet de jeu, sans
  commande native en match).
- **Ne rien rater** : la minute d'un événement non vu reste dans le fil avec un repère sur
  le terrain 2D ; tout repère est rejouable. Aux vitesses rapide et éclair, l'horloge
  ralentit d'elle-même pendant 3 s après un carton ou un changement de meneur.

### 4.8 Ralentis et présentation

**Ralentis, version minimale crédible.** Un seul cas d'abord : l'essai dont le score
d'intérêt atteint 85. On rejoue **le dernier plan** (course et plongeon, 3 s) à demi-vitesse
depuis la caméra « contact », soit 6 s, puis coupe vers le buteur. Réglage : jamais /
essais importants / tous les essais. Pas de ralenti sur ballon porté tant que les
regroupements ne se lisent pas de près (constat de la doc PR 554). Plus tard : essai
refusé, ballon tenu, carton rouge. En attendant le ralenti 3D, le bouton « revoir »
ouvre la revue d'action existante.

**Avant-match.** Une carte : les deux clubs, l'enjeu (journée, places au classement),
la météo (`l.weather`), les deux XV, la consigne choisie, l'avis de l'adjoint. Puis la
causerie (existe). Puis le coup d'envoi, premier temps fort, toujours montré.

**Mi-temps.** Coup de sifflet en 3D (2 s), puis écran de synthèse : score et marqueurs,
les six chiffres, l'élan des quarante minutes, fraîcheur des quinze, conseil de l'adjoint,
accès direct Tactique et Banc. Puis la causerie (existe). Le match ne reprend que sur
action du joueur (existe : `atBreak`).

**Fin.** Coup de sifflet (3 s), puis résultat : score, marqueurs lus dans le journal,
points de classement et bonus obtenus, les trois temps forts au meilleur score
rejouables, causerie d'après-match (existe), « Valider la journée ». Homme du match :
à vérifier, je n'ai pas cherché si une note par joueur est disponible en fin de match.

### 4.9 Réglages

| Réglage | Valeurs | Défaut | Existant |
| --- | --- | --- | --- |
| Temps forts | commentaire seul, résumé, clés, étendus, dynamique, match complet | dynamique | non |
| Vitesse des temps forts | 0,75× ; 1× ; 1,5× ; 2× | 1× | remplace la cadence ×1 / ×4 / ×12 |
| Horloge entre les temps forts | lente 3 s par minute, normale 1,5 s, rapide 0,6 s, éclair 0,25 s | normale | non |
| Ralentis | jamais, essais importants, tous les essais | essais importants | non |
| Pause en ouvrant Tactique ou Banc | oui / non | oui | pause manuelle requise aujourd'hui |
| Arrêts automatiques | carton (toujours), essai encaissé, pénalité « me demander », conseil de l'adjoint | carton seul | `pauseOnTry` et `pauseOnCard` dans le moteur, sans réglage natif |
| Fil de commentaire pendant les temps forts | oui / non | oui | deux lignes affichées |
| Caméra, qualité, stade de soirée | inchangés | — | `user_preferences.gd` |
| Mouvements réduits | force « commentaire seul », terrain 2D | — | force déjà la caméra tactique |

### 4.10 Ce qui ne se transpose pas de FM

1. **L'arrêt de jeu n'est pas un temps mort.** Au football on peut tout couper entre deux
   occasions. Au rugby la pénalité sifflée ouvre un choix, la mêlée est un combat, la
   touche à 5 m est l'occasion elle-même. *Recommandation* : coupes vers la phase en
   place (§ 4.5), jamais suppression de la phase. *Plaisir de jeu* : le joueur voit
   payer son recrutement en première ligne.
2. **On marque trop souvent pour que « but = temps fort » suffise.** 4,2 essais et 2,7
   pénalités par match ici : le seul score donne déjà sept temps forts. *Recommandation* :
   niveau « résumé » en dessous de « clés », et pénalités non montrées quand le match est
   plié en dynamique.
3. **L'histoire d'un match de rugby est territoriale.** Dix secondes de 3D ne disent pas
   qu'on campe chez l'adversaire depuis un quart d'heure. *Recommandation* : l'écran
   intermédiaire porte ce récit (terrain 2D en premier, élan du match). Chez FM il
   complète ; ici il est la moitié du match.
4. **« Match entier » n'a pas le même sens.** Le manuel de FM précise que le sien ne dure
   pas 90 minutes [S1] ; le nôtre durerait moins de 8 minutes. *Recommandation* : le
   nommer « match complet », ne pas promettre plus, et traiter la finesse de simulation
   (phase par phase) comme un chantier moteur séparé.
5. **Dynamique selon le seul score : insuffisant.** Un 31–6 à la 65e reste un match à
   regarder si le bonus offensif tient à un essai. *Recommandation* : bonus et phase
   finale dans la tension (§ 4.3).
6. **Les ralentis par type de but** supposent une animation qui tient en gros plan.
   *Recommandation* : un seul ralenti, sur l'essai en jeu ouvert, tant que les
   regroupements restent des poses calculées.
7. **Les cris depuis la touche** n'ont pas d'équivalent : au rugby le message passe aux
   arrêts. *Recommandation* : le dire à l'écran, et en faire une règle simple plutôt qu'un
   défaut.

## 5. Plan de réalisation

Chaque lot est une PR courte. Les lots 2 à 4 n'éditent ni `match_view.gd`, ni
`match_gestes.gd`, ni `dist/match2d.js`.

| Lot | Contenu | Fichiers | Drapeau | Tests | Risques |
| --- | --- | --- | --- | --- | --- |
| **0** (cette PR) | Conception, prototype de sélection, mesures | `docs/…`, `native/engine/match-highlights.cjs`, `tests/match-highlights.cjs` | — | 7 tests node | aucun effet en jeu |
| **1** Faits structurés | Écrire dans la scène : `cause` (touche, en-but, renvoi), `card` (jaune, rouge), `conversion` (réussie ou non), `origin` de l'essai, `choice` de la pénalité ; trancher « essai sur ballon porté » | `dist/restarts.js`, `dist/rugby.js`, `dist/match-actions.js`, `dist/saves.js` (`validateActionScenes`) | aucun (champs ajoutés) | `tests/match-actions.cjs`, `restarts`, `saves` ; même graine → même score et mêmes textes | la validation des sauvegardes contrôle les champs de scène ; ne consommer aucun tirage |
| **2** Tranche jouable | Projection `live.tempsFort` (fenêtre, type, score, scènes à rejouer) quand la minute simulée contient une action retenue ; `tick` par minute ; lecture locale de la liste de scènes ; écran intermédiaire minimal (score, horloge, terrain 2D, fil) | `native/engine/model.cjs`, `worker.cjs`, `native/godot/main.gd` (`_live_tick`), `ui/contextual/live_view.gd`, nouveau `ui/contextual/match_between.gd` | `CD_MATCH_TEMPS_FORTS=1` | node : projection pure (ni carrière ni tirage modifiés, comme `tests/match-pass-live.cjs`) ; Godot sans affichage : bascule des trois états | accord avec l'attente de geste des PR 554 et 555 ; délai du moteur par requête à mesurer sur le PC de Léo |
| **3** Coupes de réalisation | Table du § 4.5 complète ; poses « tireur prêt », « packs liés », « buteur prêt » ; plan de transformation | `match_view.gd`, `match_gestes.gd` — **après fusion de 554 et 555, par ou avec l'agent qui y travaille** | `CD_MATCH_GESTES=1` | `tests/godot-match-gestes.*` étendus | collision de fichiers : ne pas commencer avant |
| **4** Écran intermédiaire complet | Chiffres, élan, conseil, fraîcheur, repères cliquables ; maquette de la graphiste | `match_between.gd`, `model.cjs` (projection de `tacticalStats`, minute de retour des cartons) | idem lot 2 | Godot sans affichage ; captures 1440 | lisibilité : à juger sur captures |
| **5** Niveaux et dynamique | Réglage du niveau, régulateur de rythme, temps fort « ouvert », préférences | `match-highlights.cjs` (variante en ligne), `user_preferences.gd`, `preferences_dialog.gd` | idem | égalité en ligne / a posteriori sur journaux enregistrés, hors budget | réglage des seuils à refaire après le lot 1 |
| **6** Décisions | Arrêts-décision, notifications, consignes rapides, politique de pénalité et carnet en match | `worker.cjs` (commandes), `dist/opposition.js`, `live_view.gd` | idem | règles : `docs/rugby-rules-reference.md` (lois 3 et 20) | effet sportif réel : seulement par décision du joueur |
| **7** Présentation | Avant-match, mi-temps, fin, ralenti d'essai, autres matchs en direct (simulés au coup d'envoi, révélés à la minute) | `live_view.gd`, `match_view.gd`, `dist/game.js` (`finishRound`) | idem | même graine → mêmes résultats des autres matchs qu'aujourd'hui, ou écart documenté | l'ordre des tirages change si les autres matchs sont simulés plus tôt |

**Première tranche jouable, la plus petite** : lot 2 seul, sans le lot 1 (le prototype lit
encore les causes dans le texte, à un seul endroit). Ce que Léo verrait avec
`CD_MATCH_TEMPS_FORTS=1` : coup d'envoi en 3D ; l'horloge file sur un terrain 2D ; la 3D
revient pour un essai avec les deux actions qui l'ont amené, puis repart. Ce qui
manquerait encore : coupes soignées (lot 3), chiffres et conseil (lot 4), choix du niveau
(lot 5). Sans le drapeau, le match est celui d'aujourd'hui.

## 6. Prototype

- `native/engine/match-highlights.cjs` : `temps_forts(events, {niveau, eliminatoire,
  bonus, ralentis, cible})` rend `{tempsForts:[{debut, fin, minuteDebut, minuteFin, type,
  types, score, force, duree, plans, coupes, ralenti}], nombre, dureeAction, plansMontres,
  partPlansSautes, minutesSautees, dureeHorloge…}`. Exporte aussi `normaliser`, `tension`,
  `NIVEAUX`, `DUREES`, `HORLOGE`.
- **Pur post-traitement** : aucun `require`, aucun tirage, journal non modifié (le test le
  passe gelé). Il n'est appelé par aucun fichier du jeu.
- `tests/match-highlights.cjs` : 7 tests, 2 s. Essai après pénaltouche commençant à
  l'alignement formé ; pénalité, carton et tir dans un seul temps fort ; tension ; erreurs
  explicites ; sur un vrai match simulé, temps forts triés et disjoints à chaque niveau,
  durées croissantes du résumé au match complet ; tout essai et toute pénalité réussie
  couverts ; pureté.
- Limites : calcul **a posteriori** sur le journal complet (la variante en ligne est le
  lot 5) ; causes lues dans le texte en attendant le lot 1 ; durées de plan **visées**, pas
  mesurées à l'écran ; seuils réglés sur 24 matchs de première journée seulement (pas de
  phase finale, pas de match très déséquilibré : écart maximal 23) ; ni 50:22 ni ballon
  porté dans l'échantillon, donc ces deux types ne sont vérifiés que par leur code.

Rejouer :

```
node --test tests/match-highlights.cjs
node -e "const H=require('./native/engine/match-highlights.cjs');console.log(H.temps_forts(require('./journal.json'),{niveau:'dynamique'}))"
```

## 7. Vérifications non faites

- Aucune exécution dans Godot : rien de ce document n'a été vu à l'écran.
- Délai d'une requête au moteur : environ 0,8 s par `tick` mesuré ici sur une machine très
  chargée ; à mesurer sur le PC de Léo avant de fixer l'horloge « éclair ».
- Les textes en ligne de World Rugby n'ont pas été relus ; la référence du dépôt
  (`docs/rugby-rules-reference.md`, lois 3, 5, 7, 12, 18 à 21) a servi de base.
- Les vidéos officielles de FM26 et FM27 n'ont pas été regardées ; les règles de début et
  de fin d'un temps fort de FM restent non sourcées (§ 2.2).
- Pro Cycling Manager : aucune source lue.

## 8. Sources

Consultées le 11 novembre 2026. « Officiel » = Sports Interactive ou l'éditeur du jeu.

- **[S1]** Manuel officiel Football Manager 2022, « Matchday » — https://community.sigames.com/manual/football-manager-2022/matchday-r989/
- **[S2]** Manuel officiel Football Manager 2023 Touch et console, « Playing a Match » — https://community.sports-interactive.com/sigames-manual/football-manager-2023-touch-and-console-edition/playing-a-match-r4758
- **[S3]** Manuel officiel Football Manager 2022 Touch, « Matchday » — https://community.sigames.com/manual/football-manager-2022-touch/matchday-r1010/
- **[S4]** Manuel officiel Football Manager 2024 Mobile, « Matchday » — https://community.sports-interactive.com/sigames-manual/football-manager-mobile-2024/matchday-r5239
- **[S5]** Site officiel, « Where Storytelling Evolves: FM26's Match Day Experience » — https://www.footballmanager.com/fm26/features/where-storytelling-evolves-fm26s-match-day-experience
- **[S6]** Site officiel, « Back to The Dugout » (FM26) — https://www.footballmanager.com/node/993
- **[S7]** GGRecon, « Football Manager 2024: how to change highlights » (tiers) — https://ggrecon.com/guides/football-manager-2024-change-highlights
- **[S8]** VideoGamer, « Football Manager 2023: how to change highlight speed » (tiers) — https://www.videogamer.com/news/football-manager-2023-fm23-how-to-change-highlight-speed
- **[S9]** Site officiel, « FM27: Tactical Tweaks and Match Engine Upgrades » (version de développement, susceptible de changer) — https://www.footballmanager.com/node/1108
- **[S10]** Altered Gamer, « Playing a Match in FM 2010 » (tiers, ancien) — https://www.alteredgamer.com/football-manager/55966-fm-2010-guide-playing-a-match
- **[S11]** Sortitoutsi, « FM26: how to set up your preferences » (tiers) — https://sortitoutsi.net/content/75736/fm26-how-to-set-up-your-preferences
- **[S12]** FM Scout, fil « Play time versus ingame progression » (tiers, sans chiffre utile) — https://www.fmscout.com/q-6817-Play-time-versus-ingame-progression.html
- **[S13]** GM Games, test de Tennis Manager 2023 (tiers) — https://gmgames.org/?p=17515
- **[S14]** Cyanide, guide en ligne de Pro Cycling Manager 2020, page « Race » (texte non affiché) — https://web.cyanide-studio.com/games/cycling/2020/pcm/guide/race
- **[S15]** Steam, fiche de National Rugby Manager (éditeur) — https://store.steampowered.com/app/752640
- **[S16]** Hexus, test de Pro Rugby Manager 2, page 5 (tiers) — https://hexus.net/gaming/reviews/pc/1028-pro-rugby-manager-2/?page=5

Lues sans rien apporter de plus : FM Scout « FM26 Match Day Experience », Football Manager
Blog « FM26 Match Day Experience » (reformulations du site officiel), Gamepressure FM 2016
et FM 2020 (interface des remplacements, sans règle d'application).
