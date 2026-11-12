# Match « comme FM » : temps forts, coupes et écran intermédiaire — conception du 11 novembre 2026

Demande de Léo : « pour les matchs, réfléchis et recherche comment FM construit ses
matchs (temps forts notamment, skip quand le ballon sort en touche ou avant de
reprendre le jeu par exemple). Il faut plus ressembler à ça. »

Les sections 1 à 8 sont la conception. Elle s'appuie sur le code de `origin/main`
(`96f53704`), sur 24 matchs joués avec le vrai moteur natif et sur les sources citées en
fin de document. **La section 9 décrit la première tranche jouable, réalisée le même jour
derrière `CD_MATCH_TEMPS_FORTS=1`.** **La section 10 décrit la suite : sur décision de Léo,
le match en temps forts est devenu le mode de base du jeu** ; le direct d'origine reste
accessible par `CD_MATCH_TEMPS_FORTS=0`.

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
9. **Première tranche jouable, réalisée (§ 9)** : alternance temps fort / écran
   intermédiaire derrière `CD_MATCH_TEMPS_FORTS=1`, sans toucher aux gestes ni à la
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
5. **Plusieurs causes n'étaient lisibles que dans le texte** : 50:22, pénaltouche, ballon tenu
   en but, en-avant dans l'en-but, couleur du carton, essai « sur ballon porté ». Le
   moteur les connaissait (`RESTART_CAUSES`, `origin`), sans les écrire dans la scène,
   alors que la règle du dépôt est « jamais déduit de la prose ». **Corrigé dans cette PR**
   (§ 9.2) : la scène porte maintenant `cause`, `card`, `origin` et `conversion`.
6. **Incohérence déjà présente, non corrigée** : « essai sur ballon porté » est annoncé pour
   toute touche proche de la ligne conclue par un essai, même quand la combinaison jouée
   n'est pas le ballon porté. Le geste de la PR 554 lit la combinaison : il ne montrera pas
   de maul sur ces essais. Description précise au § 9.6 ; à arbitrer côté moteur.
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

Durées de plan jouées par la tranche réalisée, à vitesse normale **[code]** : progression
balle en main, la distance gagnée à 6,5 m/s (entre 0,8 et 3,6 s) puis 1 s au contact ; jeu
au pied 2,5 s ; réception 2 s ; alignement formé 1,5 s puis lancer-prise 2 s ; ballon porté
5 s de plus ; mêlée liée 1,5 s puis sortie 3 s ; récupération 2 s (2,5 s en conquête) ;
faute de main 1,8 s ; coup de sifflet 1,5 s ; carton 2,5 s ; tir au but 4,5 s (4 s manqué),
dont 1,2 s tireur prêt ; essai 3,5 s puis transformation 4 s ; renvoi 2,5 s ; action d'en-but
3 s ; entrée 0,6 s, sortie 0,8 s, coupe 0,3 s. Ce sont des **planchers** : quand la vue 3D
joue un geste plus long (touche portée, ballon porté, essai aplati de la PR 554), la lecture
l'attend. Pas de ralenti dans cette tranche.

Sélection **en direct** (`en_direct`, § 9.3) sur les 24 matchs **[mesuré, calculé sur les
journaux]**. « Total » = action + horloge de l'écran intermédiaire à 1,5 s par minute
sautée, hors pauses, causeries et délai du moteur.

| Niveau | Ce qu'il montre | Temps forts | Action | Total | Plans sautés | Minutes sautées |
| --- | --- | --- | --- | --- | --- | --- |
| **Commentaire seul** | écran intermédiaire uniquement | 0 | 0 | 2 min 09 | 100 % | 100 % |
| **Résumé** | ce qui change le score ou l'effectif, amorce d'un plan | 8,0 (5–13) | 1 min 18 (0 min 44 – 2 min 05) | 3 min 14 | 89,8 % | 90,5 % |
| **Clés** (seuil 78, amorce 2) | + cartons, tirs manqués, essais refusés, ballons sauvés près de la ligne, coup d'envoi | 12,2 (7–19) | 1 min 55 (1 min 06 – 2 min 42) | 3 min 45 | 81,3 % | 85,1 % |
| **Étendus** (seuil 56, amorce 4) | + franchissements, pression dans les 22, conquêtes volées, touches et mêlées à 5 m | 21,7 (16–32) | 3 min 21 (2 min 21 – 4 min 45) | 4 min 50 | 62,8 % | 69,3 % |
| **Dynamique** (seuil de 54 à 80 selon la tension) | entre clés et étendus, selon l'enjeu | 17,5 (8–29) | 2 min 49 (1 min 17 – 4 min 25) | 4 min 26 | 70,0 % | 75,4 % |
| **Match complet** | tous les plans, temps morts coupés, sans retour à l'écran intermédiaire tant que le jeu continue | en continu | 7 min 27 (6 min 44 – 8 min 11) | 7 min 40 | 0 % | 10,2 % |

Une séquence dure en moyenne 8 s en dynamique (médiane 7,7 ; maximum 23,2). Tous les
essais sont montrés à tous les niveaux, sauf en commentaire seul (100 sur 100).

La sélection a posteriori du premier prototype (`temps_forts`, sur le journal complet)
donne, avec les mêmes durées de plan : résumé 1 min 39, clés 2 min 13, étendus 3 min 45,
dynamique 3 min 16, complet 6 min 24. L'écart vient de ce qu'en direct une fenêtre ne peut
pas s'étendre vers le futur ni fusionner avec la suivante.

**Budget de temps.** Chaque niveau a une durée d'action cible pour 80 minutes (clés : 1 min 30
à 2 min 50 ; étendus : 3 min 20 à 5 min ; dynamique : 1 min 30 à 5 min 20). **Régulateur** :
toutes les cinq minutes de match, le temps d'action déjà montré est comparé à la cible au
prorata de l'horloge ; le seuil se déplace de 4 points, dans la limite de 16. Conséquence
voulue : **la durée d'un match est prévisible**, ce qui compte quand on enchaîne une saison.

**Mode dynamique**, à la manière de FM26 **[mesuré]** : quand la tension est d'au moins 0,8,
40 % des plans sont montrés ; quand elle est de 0,45 ou moins, 8 %. Par match : écart final
de 7 points ou moins, 3 min 14 d'action, 21 temps forts, 4 min 43 au total ; écart de plus
de 14, 2 min 18, 13,6 temps forts, 4 min 03. Dans un match plié (tension sous 0,35), une
pénalité réussie n'est plus « toujours montrée » : elle passe par le fil. Les essais et les
cartons rouges restent toujours montrés, avec une amorce réduite à un ou deux plans.

**Un plan isolé ne fait pas un temps fort** : hors score et exclusion, une action retenue
qui ne donnerait qu'un plan voit son amorce allongée de deux plans ; à défaut, l'horloge
continue. Sans cette règle, un match serré enchaînait des allers-retours de trois secondes.

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
`match_gestes.gd`, ni `dist/match2d.js`. **État au 11 novembre au soir : les lots 0, 1 et 2
sont réalisés dans cette PR (§ 9), avec une partie des lots 5 (niveaux, dynamique,
régulateur, temps fort ouvert) et 6 (arrêt sur carton).** Le tableau garde le découpage
d'origine.

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

## 6. Sélection : module et tests

- `native/engine/match-highlights.cjs`, deux entrées :
  - `en_direct(events, {niveau, eliminatoire, bonus, cible})` : la sélection jouée par le
    direct. Elle rend une décision par rafale (les événements d'un même pas du moteur),
    la liste des temps forts déjà décidés et `courant`, celui de la dernière rafale.
    Chaque temps fort porte ses plans : `{i, kind, duree, mouvement, coupe}`, et, après un
    essai, un plan `transformation` déduit (`reussie`).
  - `temps_forts(events, {niveau, …})` : la sélection a posteriori du premier prototype,
    gardée comme référence de mesure.
  - Exporte aussi `normaliser`, `tension`, `NIVEAUX`, `DUREES`, `HORLOGE`.
- **Pur calcul** : aucun `require`, aucun tirage, journal non modifié (le test le passe gelé).
- `tests/match-highlights.cjs` : 11 tests, 2 s. Pour `en_direct` : la décision d'une rafale
  ne dépend que du passé et ne change plus ensuite (préfixes du journal comparés au
  journal complet, à chaque niveau) ; temps forts triés et disjoints, amorce jamais sur un
  plan déjà montré ; résultat répétable ; tout essai montré avec sa transformation ;
  amorce d'un essai sur la minute précédente ; remises en jeu par une coupe.
- Limites : seuils réglés sur 24 matchs de première journée (pas de phase finale, écart
  maximal 23) ; ni 50:22 ni combinaison « ballon porté » dans l'échantillon, donc ces deux
  types ne sont vérifiés que par leur code ; durées de plan fixées par le code, pas
  mesurées sur un écran rapide.

## 7. Vérifications non faites

- Pour la conception (§ 1 à 6) ; celles de la tranche réalisée sont au § 9.8.
- Délai d'une requête au moteur : environ 0,8 s par `tick` mesuré ici sur une machine très
  chargée ; à mesurer sur le PC de Léo avant de fixer l'horloge « éclair ».
- Les textes en ligne de World Rugby n'ont pas été relus ; la référence du dépôt
  (`docs/rugby-rules-reference.md`, lois 3, 5, 7, 12, 18 à 21) a servi de base.
- Les vidéos officielles de FM26 et FM27 n'ont pas été regardées ; les règles de début et
  de fin d'un temps fort de FM restent non sourcées (§ 2.2).
- Pro Cycling Manager : aucune source lue.

## 9. Tranche jouable réalisée (11 novembre 2026)

État de cette section : la première tranche, telle que livrée derrière la variable
d'environnement `CD_MATCH_TEMPS_FORTS=1`, sans toucher à `match_view.gd`, `match_gestes.gd`
ni `dist/match2d.js`. **Depuis, le mode est devenu celui du jeu par défaut et la branche
contient les PR 554 et 555 : voir la section 10**, qui fait foi pour les variables, les
tests et la capture.

### 9.1 Ce que voit le joueur

1. Le **coup d'envoi** en 3D : équipes en place, renvoi, réception.
2. L'**écran intermédiaire** : terrain vu de dessus avec la bande de dix mètres où se joue
   le match, le ballon, la flèche de l'équipe en possession, les trois dernières actions
   et les repères des essais, pénalités et cartons ; le fil (sans messages d'avantage) ;
   sept chiffres ; le regard de l'adjoint et son bouton quand le moteur en projette un.
   L'horloge avance d'une minute par requête au moteur.
3. Quand une action est retenue, la 3D revient par un fondu, **repart d'où l'action se
   trouvait** (retour sur des plans déjà simulés) et joue les plans à vitesse de jeu :
   une progression balle en main dure le temps de sa distance à 6,5 m/s, au lieu d'un
   déplacement en 0,55 s. Le bandeau montre l'horloge et le score **de l'instant rejoué**.
4. Touche, mêlée, renvoi, tir au but et transformation arrivent par une **coupe franche**
   sur la phase en place ; le tireur attend 1,2 s avant de frapper. Après un essai, un plan
   « transformation » déduit montre le buteur à 22 m, dans l'axe de l'essai.
5. À la fin du temps fort, la 3D reste à l'écran le temps de savoir si l'action continue
   à la minute suivante ; sinon l'écran intermédiaire revient.
6. **Arrêt automatique** : carton contre mon équipe ou carton rouge adverse (après le temps
   fort, jamais pendant), mi-temps (déjà existante). Une carte propose Banc, Tactique,
   Reprendre. Les ordres se donnent en pause et s'appliquent comme aujourd'hui.

### 9.2 Faits structurés du journal (lot 1)

| Champ de la scène | Sur quel `kind` | Valeurs | Écrit par |
| --- | --- | --- | --- |
| `cause` | `touch` | `carry-touch`, `indirect-touch`, `direct-touch`, `penalty-touch`, `50-22`, `missed-goal-touch`, `period-end` | `resolveTouch`, `missedGoal` (`dist/restarts.js`), `advanceFlowPlay` (`dist/matchflow.js`) |
| `cause` | `ingoal` | `held-up`, `attacking-kick-grounded`, `ingoal-knock-on`, `kick-dead`, `defender-grounded` | `resolveInGoal` (`dist/restarts.js`) |
| `card` | `card` avec `incident` | `yellow`, `red20`, `red` | `giveMatchCard` (`dist/rugby.js`) |
| `origin`, `conversion` | `try` | `open`, `maul`, `scrum` ; vrai ou faux | `scoreTry` (`dist/rugby.js`) |

Chaque valeur est une variable déjà calculée à l'endroit où l'événement est écrit ;
`captureMatchAction` (`dist/match-actions.js`) ne la recopie que si elle appartient au
domaine attendu, et `validateActionScenes` (`dist/saves.js`) contrôle les mêmes domaines.
La sélection ne lit plus le texte que pour un journal commencé avant ces champs.

**Résultats sportifs inchangés — preuves [mesuré]** :
- les 24 matchs du moteur natif rejoués avec les mêmes graines après la modification :
  **24 sur 24 identiques** (journal, score, essais, statistiques, météo) une fois retirés
  les 658 champs nouveaux ;
- 4 matchs du harnais comparés à `96f53704` : empreinte SHA-256 identique (journal sans
  les nouveaux champs, score, statistiques, feuilles de match, tirage suivant) ;
- dans le dépôt, `tests/match-structured-facts.cjs` rejoue trois matchs contre un témoin
  qui ignore ces champs à l'enregistrement : même journal, même score, même tirage suivant.

### 9.3 Sélection en direct, sans moteur en avance

Le moteur avance d'une minute par pas ; les événements d'un pas forment une **rafale**.
À chaque rafale, `en_direct` décide : jouer en 3D ou laisser l'horloge filer.

- **Seul le passé est lu.** L'amorce remonte sur des plans déjà simulés et pas encore
  montrés, jamais plus loin que la fin du temps fort précédent. Aucun plan n'est montré
  deux fois.
- **Sans état.** La fonction rejoue toutes les décisions depuis le coup d'envoi à partir du
  journal : le résultat est répétable, et la décision d'une rafale ne change plus quand le
  match continue (contrôlé sur tous les préfixes d'un match, à chaque niveau).
- **Temps fort ouvert.** Si le dernier plan montré n'est ni un ballon mort ni un ballon
  perdu, la rafale suivante prolonge le temps fort quand elle reste intéressante (seuil
  abaissé de 16 points) ou quand la même équipe reste dans les 22 ; deux prolongations au plus.
- **Fin de match serrée.** Après la 78e minute, à un essai transformé d'écart ou moins,
  toute rafale jouable est montrée.
- **Régulateur de rythme** et **plan isolé** : § 4.4.

### 9.4 Côté moteur

- `native/engine/match-direct.cjs` (nouveau) : projection `live.direct` — niveau, horloge,
  possession, zone, fil, traces, repères, chiffres, élan, cartons en cours, bilan, temps
  fort courant (plans avec leur scène 3D, position de départ, score avant et après),
  arrêt-décision. Les scènes des plans passés sont relues par la fonction existante
  `matchScene` en déplaçant le curseur de présentation, toujours remis à sa place.
- `native/engine/worker.cjs` : option `matchHighlights` de `createBridge` ; au lancement,
  `CD_MATCH_TEMPS_FORTS=1` l'active avec le niveau `CD_MATCH_TEMPS_FORTS_NIVEAU`
  (`aucun`, `resume`, `cles`, `etendus`, `dynamique` par défaut, `integral`). La commande
  `tick` accepte `{minute:true, temps_forts:<niveau>}` : une minute simulée par pas,
  présentation à jour avant et après ; le niveau peut changer en cours de match. Sans
  l'option, ce pas est refusé et `live.direct` n'existe pas.
- **Aucun effet sur le match** : même carrière et même tirage suivant qu'avec le pas
  ordinaire (`tests/match-direct.cjs`).

### 9.5 Côté Godot

- `native/godot/ui/contextual/match_temps_forts.gd` (nouveau) : la régie. Trois états
  (intermédiaire, temps fort, attente). Elle rejoue localement la liste de plans du moteur,
  sans requête par plan, par l'interface publique de la vue 3D : `apply_frame` et
  `is_presenting_extended_pass`.
- `native/godot/ui/contextual/match_between.gd` (nouveau) : l'écran intermédiaire. Composants
  et couleurs de l'habillage existant (`skin.gd`), aucune ressource ajoutée.
- `native/godot/ui/contextual/live_view.gd` : création de la régie si la variable est
  posée ; la cadence devient le choix de l'horloge (posée 3 s par minute, normale 1,5 s,
  rapide 0,6 s, éclair 0,25 s).
- `native/godot/main.gd` : une ligne, le minuteur du direct laisse la main à la régie.
- **Réglages** : niveau par `CD_MATCH_TEMPS_FORTS_NIVEAU` et par la liste « Temps forts » de
  l'écran intermédiaire (gardée pour la session) ; horloge par la liste de la barre de
  commandes ou `CD_MATCH_TEMPS_FORTS_HORLOGE` ; vitesse des temps forts par
  `CD_MATCH_TEMPS_FORTS_VITESSE` (0,5 à 4, 1 par défaut). Il n'existe pas d'écran de
  réglages de match : rien n'est écrit dans les préférences.

**Point d'accroche pour les PR 554 et 555.** La régie envoie à la vue 3D chaque plan dans
l'ordre du journal, sortie en touche et mise en place comprises, avec le journal tronqué à
l'action montrée, et attend tant que `is_presenting_extended_pass()` est vrai. Les gestes et
la coupe vers la remise en jeu (`cut_to_restart`) se déclenchent donc sur les mêmes faits
qu'aujourd'hui, sans modification ici. Quand les gestes sont actifs (`CD_MATCH_GESTES=1`),
la régie ne fait plus sa propre coupe franche et laisse celle de la vue. **Non vérifié** :
les deux variables ensemble n'ont pas été essayées, la branche 554 n'étant pas fusionnée.

### 9.6 Incohérence « essai sur ballon porté » (corrigée le 11 novembre au soir, § 11.1)

- **Constat [mesuré]** : sur les 24 matchs, 18 essais sur 100 portent `origin:'maul'` et le
  texte « sur ballon porté », et **aucun** n'a été précédé d'une touche jouée avec la
  combinaison `maul` : toutes les touches gagnées de l'échantillon ont `move:'equilibre'`.
- **Cause [code]** : dans `contestSetPiece` (`dist/rugby.js`), une touche gagnée à moins de
  23 m de la ligne peut donner un essai dans le même pas, avec l'origine
  `playbookRules(l)&&['fond','courte'].includes(move.move)?'open':'maul'`. Toute combinaison
  autre que « fond de touche » et « touche courte » — donc aussi le lancer « équilibré »
  par défaut — produit `maul`, sans qu'un ballon porté ait été annoncé ni simulé.
- **Conséquences** : le journal annonce un ballon porté qui n'a pas été joué ; le geste de
  maul de la PR 554 se déclenche sur la combinaison `maul` et ne s'affichera pas pour ces
  essais ; la statistique « essais sur ballon porté » ne dit rien du carnet de jeu.
- **Deux corrections possibles, à trancher** : (a) n'écrire `maul` que si la combinaison
  jouée est le ballon porté, et « sur lancement de touche » sinon — changement de texte et
  de fait, sans effet sur le score ; (b) considérer qu'un essai direct après touche près de
  la ligne est toujours un ballon porté, et faire porter `move:'maul'` par la conquête
  correspondante. Je recommande (a) : elle ne change aucun tirage.

### 9.7 Tests et preuves

| Test | Ce qu'il prouve | Résultat ici |
| --- | --- | --- |
| `tests/match-highlights.cjs` | sélection a posteriori et en direct : causalité, répétabilité, essais montrés, coupes | 11 sur 11, 2 s |
| `tests/match-structured-facts.cjs` | faits structurés : match inchangé, accord avec le texte, validation des sauvegardes | 3 sur 3, 9 s |
| `tests/match-direct.cjs` | vrai moteur natif : rien sans l'option ; projection minute par minute ; pas « minute » sans effet sur le match | 3 sur 3, 50 s |
| `tests/godot-match-temps-forts.cjs` | vraie interface sans affichage et vrai moteur : sans la variable, rien ; avec, coup d'envoi en 3D → écran intermédiaire → second temps fort → écran intermédiaire ; commentaire seul ; arrêt sur carton et reprise ; rien de coupé en 1280×720 et 1920×1080 | 10 puis 171 contrôles, 0 échec, 36 s |
| `tests/godot-match-temps-forts-capture.cjs` | outil de capture (ne fait rien sans `CD_MATCH_TEMPS_FORTS_PROOF`) | voir § 9.9 |

Tests existants relancés après les modifications, tous réussis : `match-actions`,
`restarts`, `matchflow`, `rugby`, `saves`, `discipline`, `match-rules`, `match2d`,
`v19-advantage`, `goalkicking`, `frontrow`, `match3d-adapter`, `ci-selection`,
`animation-live-cut`, `match-pass-live`, `godot-match-journal` (351 contrôles).
`godot-match-action-review` échoue ici : il appelle `_select_tab` sur la vue contextuelle
du direct, qui n'a pas cette fonction sur `origin/main` non plus ; échec antérieur à cette
PR d'après la lecture du code, **non rejoué sur `main`**.

### 9.8 Ce qui a été vu à l'écran, mesures, non vérifié

**Vu à l'écran [exécuté]**, sous Linux, rendu logiciel (`llvmpipe`, OpenGL), 1280×720, vraie
interface et vrai moteur, par le script de capture : deux débuts de match (12 minutes avec
une graine au hasard, 7 minutes avec la graine 11), 167 images regardées par planches :

- **Coup d'envoi** : les deux équipes en place, le renvoi, la réception, la légende du
  plan sous le terrain, l'horloge « 0′ » ([image](match-temps-forts-20261111/01-coup-d-envoi.jpg)).
- **Écran intermédiaire** : terrain vu de dessus avec les en-buts aux couleurs des clubs,
  la bande de dix mètres en surbrillance, le ballon et la flèche de possession ; le fil ;
  les sept chiffres ; le regard de l'adjoint et son bouton ; la liste « Temps forts » ;
  l'horloge de la barre de commandes. Rien de coupé en 1280×720
  ([image](match-temps-forts-20261111/02-ecran-intermediaire.jpg)).
- **Temps fort en jeu courant** (2e minute) : ballon récupéré, les trente joueurs, la
  caméra qui suit le ballon ([image](match-temps-forts-20261111/03-temps-fort.jpg)).
- **Coupe vers une touche formée** (graine 11, 1re minute) : les deux alignements en place
  dès la première image du plan, puis la conquête
  ([image](match-temps-forts-20261111/04-touche-formee.jpg)).
- **Essai puis transformation** : essai en coin, score affiché 0 – 0 pendant le plan puis
  0 – 5 ; coupe sur le buteur isolé à 22 m dans l'axe de l'essai, tir, ballon qui passe à
  côté ([image](match-temps-forts-20261111/05-transformation.jpg)).
- **Progression à vitesse de course** (3e et 4e minutes) : le porteur avance d'image en
  image jusque dans les 22 mètres, les deux lignes suivent, au lieu d'un saut d'une
  position à l'autre ([image](match-temps-forts-20261111/06-progression.jpg)).
- **Temps fort prolongé** : à la 5e minute, la rafale suivante est jouée à la suite, sans
  retour à l'écran intermédiaire.
- **Enchaînement** temps fort → écran intermédiaire → temps fort, sans intervention, sur
  sept minutes de match (trois temps forts et une prolongation).

Défauts vus sur ces captures et corrigés ensuite, **sans nouvelle capture** : la légende de
l'essai annonçait la transformation manquée et le score avant l'image (elle s'arrête
maintenant à l'essai, et un tir au but affiche « Tir au but. » jusqu'à la frappe) ;
l'horloge de l'écran intermédiaire s'écrivait « 1 min » au lieu de « 1′ ».

Ce qui reste faible à l'image : sans les gestes de la PR 554, touche et essai sont des
placements, pas des gestes ; pendant la transformation, les autres joueurs restent où
l'essai les a laissés ; la caméra « TV » est lointaine.

**Mesures.**
- Durée d'un match par niveau, sélection en direct, calculée sur 24 journaux : tableau du
  § 4.4 (dynamique : 2 min 49 d'action, 4 min 26 avec l'horloge normale ; de 3 min 14 à
  5 min 43 selon le match).
- Délai du moteur : 0,67 s par minute simulée ici (machine à 2 cœurs très chargée), soit
  environ une minute de plus par match ; à mesurer sur le PC de Léo.
- Lecture réelle : sans affichage et à vitesse ×4, le coup d'envoi (5,9 s prévues) est joué
  en 1,37 s et un essai (11,2 s prévues) en 2,57 s : la lecture tient les durées prévues.
- **Les durées relevées sous rendu logiciel ne valent rien** : à moins de 2 images par
  seconde, Godot plafonne le pas de temps et tout le jeu ralentit (un coup d'envoi de 5,9 s
  y dure 48 s). Sur un PC à 30 images par seconde ce plafond ne joue pas.

**Non vérifié.**
- Aucune exécution sous Windows ni avec une carte graphique ; aucun match entier vu à l'écran.
- `CD_MATCH_TEMPS_FORTS=1` avec `CD_MATCH_GESTES=1` (PR 554 et 555 non fusionnées).
- Pause demandée par le manager au milieu d'un temps fort (le code fige la lecture ; pas
  de test), « Confier la fin à l'adjoint », fin de match et causerie d'après-match en
  temps forts. À la mi-temps, la causerie s'ouvre dès la dernière minute simulée : le
  dernier temps fort de la période, s'il y en a un, est joué après elle.
- Rendu en 1920×1080 : seule la mise en page est contrôlée par le test sans affichage.
- La suite complète des tests du dépôt n'a pas été relancée ici ; seuls les tests du § 9.7
  l'ont été.

**Limites connues de la tranche.**
- **Le son suit le moteur, pas l'instant rejoué** : l'ambiance d'un essai peut précéder son
  image de quelques secondes. À traiter avec la régie (lot son).
- Pas de ralenti, pas d'avant-match ni d'écran de mi-temps ou de fin dédiés, pas d'autres
  matchs en direct (lots 4 et 7).
- Arrêt automatique sur « choix réservé » (pénalité : me demander) non fait : il faut que le
  moteur sache attendre une décision (lot 6).
- Les joueurs hors porteur glissent encore d'une formation schématique à l'autre ; seule
  la progression balle en main est ralentie à vitesse de course. Sans les gestes de la
  PR 554, une touche ou un essai restent des placements, pas des gestes.
- Mode « mouvements réduits » : non traité (la conception prévoit d'y forcer le commentaire seul).
- Le niveau et l'horloge choisis à l'écran valent pour la session, pas pour le profil.
- Seule la vue contextuelle du direct est branchée ; l'ancien écran `match_screen.gd` ne l'est pas.
- Après un redémarrage du jeu en cours de match, le dernier temps fort peut être rejoué une fois.

### 9.9 Lancer la capture sur un PC Windows

Depuis la racine du dépôt, projet Godot déjà importé, Node installé :

```
set CD_GODOT_EXE=C:\chemin\vers\Godot_v4.7.2-stable_win64.exe
set CD_MATCH_TEMPS_FORTS_PROOF=E:\captures\temps-forts
node tests\godot-match-temps-forts-capture.cjs
```

(PowerShell : `$env:CD_GODOT_EXE="…"; $env:CD_MATCH_TEMPS_FORTS_PROOF="…"; node tests\\godot-match-temps-forts-capture.cjs`.)

Le script crée une carrière de test dans un dossier temporaire (le profil du joueur n'est
pas touché), ouvre le match au coup d'envoi, joue le match entier en mode dynamique sans
intervention (causeries passées, reprise à la mi-temps et après un carton), écrit
`tf-00001.jpg`… et `report.json` dans le dossier donné, puis ferme le jeu.

| Variable | Défaut | Rôle |
| --- | --- | --- |
| `CD_MATCH_TEMPS_FORTS_PROOF` | — (requis) | dossier absolu des images, de `report.json` et de `godot.log` |
| `CD_MATCH_TEMPS_FORTS_NIVEAU` | `dynamique` | `aucun`, `resume`, `cles`, `etendus`, `dynamique`, `integral` |
| `CD_MATCH_TEMPS_FORTS_SIZE` | `1280x720` | taille de la fenêtre et des images |
| `CD_MATCH_TEMPS_FORTS_EVERY` | `5` | une image enregistrée toutes les N images affichées, à 30 images/s : 6 images par seconde, environ 1 800 images pour 5 minutes |
| `CD_MATCH_TEMPS_FORTS_MAX` | `2400` | plafond d'images ; au-delà le match continue sans enregistrer (`tronque` dans le rapport) |
| `CD_MATCH_TEMPS_FORTS_HORLOGE` | `normale` | `lente`, `normale`, `rapide`, `eclair` : accélère l'écran intermédiaire |
| `CD_MATCH_TEMPS_FORTS_VITESSE` | `1` | vitesse des temps forts, de 0,5 à 4 |
| `CD_MATCH_TEMPS_FORTS_SEED` | `7` | graine du moteur : même graine, même match |
| `CD_MATCH_TEMPS_FORTS_CLUB` | `0` | club dirigé |
| `CD_MATCH_TEMPS_FORTS_MINUTES` | `0` | arrêt après cette minute de match (0 : match entier) |
| `CD_MATCH_TEMPS_FORTS_GODOT_ARGS` | — | arguments Godot supplémentaires |

`report.json` donne pour chaque image son nom, l'instant en millisecondes, l'état
(`temps_fort`, `intermediaire`, `attente`, `arret`, `causerie`), l'horloge et le score
affichés ; et le journal de régie (chaque temps fort : type, durée prévue, durée réelle).
Pour une vidéo plus courte : `CD_MATCH_TEMPS_FORTS_HORLOGE=rapide`. Pour moins d'images :
augmenter `CD_MATCH_TEMPS_FORTS_EVERY`.

**Ce que la capture par défaut doit montrer** (graine 7, club 0, mode dynamique ; rejoué
côté moteur seul **[mesuré]**) : score final 31 – 15, six essais, 14 temps forts et deux
prolongations, 2 min 41 d'action prévue et 1 min 47 d'horloge, un arrêt sur carton — soit
environ 4 min 30 plus le délai du moteur et les reprises. Dans l'ordre : coup d'envoi ;
conquête volée (1′) ; franchissement (2′) ; franchissement (12′) puis essai (14′) ;
franchissement après le renvoi (14′) ; essais (20′, 21′) ; ballon gratté (21′) ; pénalité
(23′) ; carton jaune puis essai (29′) ; essais (59′, 60′) ; pénalité (68′) ; carton jaune
(75′). Entre la 29e et la 59e minute, match plié : l'horloge file sans temps fort.

Sous Linux sans carte graphique (contrôle seulement) :

```
CD_GODOT_EXE=<godot> CD_MATCH_TEMPS_FORTS_PROOF=<dossier> CD_MATCH_TEMPS_FORTS_MINUTES=7 \\
CD_MATCH_TEMPS_FORTS_GODOT_ARGS="--display-driver x11 --rendering-method gl_compatibility --audio-driver Dummy" \\
xvfb-run -a -s "-screen 0 1280x720x24" node tests/godot-match-temps-forts-capture.cjs
```

### 9.10 Prochaine étape

Voir la vidéo du match entier sur le PC de Léo, puis, dans l'ordre : le son calé sur la
régie ; la fusion avec les gestes des PR 554 et 555 (essai conjoint des deux variables) ;
l'écran intermédiaire repris par la graphiste ; les arrêts sur choix réservé.

## 10. Le match en temps forts devient le mode de base (11 novembre 2026, suite)

Décision de Léo : le match ne montre que les temps forts, à vitesse réelle ; on coupe le
trajet (replacements), pas la phase (une touche ou une mêlée qui compte est montrée déjà
formée). Entre deux temps forts, l'écran intermédiaire (terrain vu de dessus, horloge
accélérée, commentaire, chiffres, conseil de l'adjoint) ; arrêt quand le manager doit
décider. Cette section fait foi sur la section 9 pour les variables, les tests et la capture.

### 10.1 Variables

| Variable | Sans elle | Rôle |
| --- | --- | --- |
| `CD_MATCH_TEMPS_FORTS=0` | temps forts actifs | repli complet sur le direct d'origine : le moteur ne projette rien, pas de régie, cadence ×1 / ×4 / ×12 |
| `CD_MATCH_GESTES=0` | gestes actifs avec les temps forts | temps forts sans les gestes ni la coupe vers les remises en jeu de #554 (la régie fait alors sa propre coupe franche) ; sans effet dans le direct d'origine |
| `CD_MATCH_TEMPS_FORTS_NIVEAU` | réglage du profil, sinon `dynamique` | niveau imposé au lancement (`aucun`, `resume`, `cles`, `etendus`, `dynamique`, `integral`) |
| `CD_MATCH_TEMPS_FORTS_HORLOGE` | `normale` | horloge de l'écran intermédiaire (`lente`, `normale`, `rapide`, `eclair`) |
| `CD_MATCH_TEMPS_FORTS_VITESSE` | `1` | tests seulement : accélère la lecture des temps forts (0,5 à 4) |

`CD_MATCH_TEMPS_FORTS=1` reste accepté (même effet que l'absence de variable).

### 10.2 Ce qui a changé depuis la section 9

- **Mode de base** : le moteur lancé par le jeu (`native/engine/worker.cjs`) projette
  `live.direct` sans variable ; la vue contextuelle du direct crée la régie, le cadrage et
  les gestes. Le niveau se choisit dans la barre du match (dont « Match complet ») et il
  est enregistré dans les réglages du profil (`match_highlights`, `user_preferences.gd`).
- **Gestes de #554 et #555 avec les temps forts** (branches fusionnées dans celle-ci,
  commit `21aefe51`). Interblocage corrigé : la capture se figeait après le premier temps
  fort quand la régie attendait sans fin un geste ou une réponse du moteur. Plus aucune
  attente sans échéance : un geste tient l'image au plus 12 s par plan, une minute
  demandée sans réponse est redemandée après 3 s, après une erreur du moteur nouvel essai
  toutes les 5 s ; chaque échéance est écrite dans le journal de régie (`suivi`,
  événement `echeance`) et le test exige qu'il n'y en ait aucune sur 22 minutes de match.
- **Gros plan sur chaque temps fort** (`native/godot/match_cadrage.gd`, nouveau) : la caméra
  suit le ballon et les joueurs concernés, 12 à 18 m visibles en jeu courant, plus large
  pour les jeux au pied et les longues courses ; coupe nette à l'entrée d'un temps fort et
  sur une coupe vers une phase ; le ballon ne sort jamais du champ, y compris pendant le
  recadrage d'un geste ; repli sur le cadrage d'origine si le calcul dégénère.
- **Gros plan d'une suite** : une suite qui reprend après l'écran intermédiaire (pause,
  arrêt) pose le cadrage rapproché d'emblée ; elle partait d'un plan large pendant une
  demi-seconde (relevé par le test : 6 images à plus de 26,5 m de hauteur visible).
- **Écran intermédiaire à l'échelle de la fenêtre** (`match_between.gd`) : tailles calculées
  sur la fenêtre, fil défilant, colonnes occupées. Aucun choix de couleurs ni de style :
  composants et couleurs existants (`skin.gd`), en attendant la graphiste.
- **Ordre à la mi-temps et à la fin** : la causerie de mi-temps et le débrief attendent la
  fin du dernier temps fort de la période (`director.gd` interroge la vue ; la régie
  relance `sync` quand la lecture est finie).
- **Pause, adjoint, sauvegarde** : une pause demandée pendant un temps fort fige l'image et
  la reprise la relance ; « Confier la fin à l'adjoint » et un match repris d'une
  sauvegarde ne rejouent pas ce que le moteur a déjà joué (l'écran intermédiaire montre où
  en est le match) ; ce qui a été montré est retenu par rencontre, la vue peut être
  recréée sans rejouer un temps fort.
- **Plus de rejeu après un ordre donné en pause** : la clé d'un temps fort est désormais
  son début et son dernier plan (`match-highlights.cjs`), et non la fin de sa fenêtre. Un
  remplacement ou une consigne s'écrivent à la minute en cours et allongeaient la fenêtre
  de bandeaux : le temps fort déjà montré changeait de clé et la régie le rejouait (vu
  sur le parcours du joueur : coup d'envoi joué trois fois ; mesuré sur un match du
  harnais : 12 temps forts sur 21 auraient changé de clé après un remplacement).
- **Son** : le stade suit l'image montrée (essai, tir réussi ou manqué déclenchés par la
  régie), plus l'avance du moteur.
- **Journal ouvert pendant un temps fort** : il s'arrête à l'action montrée (le moteur a
  une minute d'avance) au lieu d'annoncer l'essai avant l'image.
- **Projection en échec** : si la projection `live.direct` lève une erreur, le modèle part
  sans elle (raison dans `live.directError`) et la vue rend la main au direct d'origine au
  lieu de bloquer le match.
- **Capture** : la fenêtre est réellement forcée à la taille demandée, la taille réelle
  des images est écrite dans `report.json`, qualité JPEG réglable, garde-fou de gel
  (arrêt avec diagnostic `fige` et code 3).

### 10.3 Tests touchés

| Test | Changement |
| --- | --- |
| `tests/match-highlights.cjs` | la clé d'un temps fort suit ses plans ; un remplacement et deux consignes ajoutés à la dernière minute ne changent ni la clé ni les plans du temps fort courant (dynamique et match complet) |
| `tests/match-direct.cjs` | le moteur en processus projette les temps forts sans variable, et sans erreur de projection ; `CD_MATCH_TEMPS_FORTS=0` les retire |
| `tests/godot-match-temps-forts.{cjs,gd}` | cinq modes : `inactif` (repli), `actif`, `gestes` (22 minutes à vitesse réelle avec les gestes, sans gel ni échéance, cadrage contrôlé image par image), `reprise` (match repris d'une sauvegarde puis confié à l'adjoint), `defaut` (parcours du joueur sans variable : causerie, coup d'envoi, pause pendant un temps fort — coup d'envoi lu à vitesse réelle le temps de cette étape —, journal ouvert, remplacement et consigne sans rejeu, mi-temps, fin, débrief, son) |
| `tests/godot-match-temps-forts-capture.{cjs,gd}` | capture du mode de base, sans variable de mode |
| `tests/godot-contextual.cjs` | le parcours `flow` avance le match par pas du direct : il tourne avec `CD_MATCH_TEMPS_FORTS=0` |
| `tests/godot-match-journal.cjs` | vérifie le journal au fil des pas du direct : il tourne avec `CD_MATCH_TEMPS_FORTS=0` |
| `tests/godot-preferences.gd` | nouvelle clé `match_highlights` dans les réglages |

### 10.4 Résultats

Exécutés le 11 novembre 2026 au soir sur la machine de travail (Linux, 2 cœurs, Godot 4.7.2
sans affichage, vrai moteur), après le commit `3ddd5b9b`, une suite à la fois :

| Suite | Résultat |
| --- | --- |
| `godot-match-temps-forts` | 5 modes, 283 contrôles, 0 échec : repli 12 · actif 176 · gestes 14 (22 minutes, 5 141 images observées, hauteur visible de 11,7 à 26 m, ballon jamais hors champ, aucune échéance) · reprise 21 · défaut 60 (causerie de mi-temps et débrief dans l'ordre, 8 réactions du stade calées sur l'image) |
| `match-direct` | 4 sur 4 |
| `match-highlights` | 12 sur 12 (dont le nouveau test des ordres en pause) |
| `match-actions`, `match-commentary-filters`, `match-pass-live`, `match-rules`, `match-structured-facts`, `match-tactical-visual`, `matchflow` | tous réussis |
| `godot-match-journal`, `godot-match-cut`, `godot-match-framing`, `godot-match-gestes`, `godot-match-gestes-scenes`, `godot-match-motion`, `godot-match-pass`, `godot-match-presentation`, `godot-match-silhouettes`, `godot-match-stadium-evening`, `godot-match-contact07` | tous réussis |
| `godot-contextual` (5 parcours) | réussi |
| `godot-preferences`, `godot-soundscape06` | réussis |
| `godot-match-action-review` | **échec antérieur à cette PR** : `_select_tab` absent de `live_view.gd`, puis délai dépassé ; la suite échoue aussi sur `main` (audit du 11 novembre, `96f53704`) |
| `scripts/build-rugby-common.cjs --check` | base commune à jour |

Avant les corrections de cette passe, `godot-match-temps-forts` échouait sur deux points :
six images en plan large au début d'une suite (mode gestes) et le coup d'envoi rejoué après
un remplacement et une consigne donnés en pause (mode défaut). Les deux sont corrigés dans
le jeu, pas dans le test. Le seul ajustement du test est la vitesse de lecture pendant
l'étape de pause : à ×4, le coup d'envoi pouvait finir avant la réponse du moteur.

### 10.5 Capture d'un match complet sur un PC Windows

Depuis la racine du dépôt (branche de la PR 560), projet Godot importé, Node installé.
Aucune variable de mode : la capture montre ce que voit le joueur, temps forts et gestes.

```
set CD_GODOT_EXE=C:\chemin\vers\Godot_v4.7.2-stable_win64.exe
set CD_MATCH_TEMPS_FORTS_PROOF=E:\captures\temps-forts
set CD_MATCH_GESTES=
node tests\godot-match-temps-forts-capture.cjs
```

PowerShell :

```
$env:CD_GODOT_EXE="C:\chemin\vers\Godot_v4.7.2-stable_win64.exe"
$env:CD_MATCH_TEMPS_FORTS_PROOF="E:\captures\temps-forts"
Remove-Item Env:CD_MATCH_GESTES -ErrorAction SilentlyContinue
node tests\godot-match-temps-forts-capture.cjs
```

La capture ignore `CD_MATCH_TEMPS_FORTS` ; la ligne qui vide `CD_MATCH_GESTES` ne sert que
si la fenêtre l'a gardé à `0` d'un essai précédent (capture sans les gestes). Autres réglages : § 9.9 ; s'y ajoutent
`CD_MATCH_TEMPS_FORTS_QUALITE` (JPEG, 30 à 95, 72 par défaut) et `CD_MATCH_TEMPS_FORTS_GEL`
(secondes sans progrès avant l'arrêt avec diagnostic, 120 par défaut). En 1920×1080 :
`set CD_MATCH_TEMPS_FORTS_SIZE=1920x1080`. Code de sortie 3 : direct figé, diagnostic
dans `report.json` (`fige`) et `godot.log`. Le rapport donne la taille réelle des images
(`image_size`), le pilote graphique, et `gestes: true` quand les gestes étaient actifs.

### 10.6 Non vérifié, limites

- **Aucune exécution sous Windows ni avec une carte graphique ; aucun match entier vu à
  l'écran avec les gestes.**
  Sous Linux (rendu logiciel `llvmpipe`, Xvfb), une capture courte du mode de base a
  tourné sans gel : 3 minutes de match, 19 images réellement en 1280×720, gestes actifs,
  2 temps forts, aucune échéance ; à l'œil, gros plan en jeu courant et écran
  intermédiaire en place. Le match entier n'a pas été capturé ici (trop lent en rendu
  logiciel).
- Les tests sans affichage ne disent rien de la fluidité : sous rendu logiciel, moins de
  2 images par seconde (§ 9.8).
- Le niveau « Match complet » n'est contrôlé que par sa présence dans la liste ; aucun
  match entier joué à ce niveau.
- Le gros plan est contrôlé par la hauteur visible et la place du ballon, pas par l'œil :
  à juger sur la capture.
- Le repli sur le direct d'origine en cas d'erreur de projection n'est pas provoqué par un
  test Godot (côté moteur, le test vérifie seulement qu'un match se projette sans erreur).
- Restent valables les limites du § 9.8 non reprises ici : pas de ralenti, pas d'écrans
  d'avant-match, de mi-temps et de fin dédiés, pas d'autres matchs en direct, arrêt sur
  « choix réservé » non fait, mode « mouvements réduits » non traité, ancien écran
  `match_screen.gd` non branché ; incohérence « essai sur ballon porté » (§ 9.6) non
  tranchée, le geste de maul ne se voit donc pas sur ces essais.

### 10.7 Suite

Voir la capture du match entier sur le PC de Léo (graine 7, club 0 : d'après le § 9.9,
score attendu 31 – 15) ; trancher l'incohérence « essai sur ballon porté » (§ 9.6) ;
l'écran intermédiaire repris par la graphiste ; les arrêts sur choix réservé (pénalité :
me demander) ; le mode « mouvements réduits ».

## 11. Essai visible, gestes adaptés, défauts de la capture Windows (11 novembre 2026, nuit)

Branche `claude/match-nuit-20261111` : PR 560 (temps forts, avec 554 et 555) + PR 571
(animations adaptées), puis ce qui suit.

### 11.1 « On ne dit essai que si on voit l'essai »

Décision de Léo. Constat avant correction, sur le moteur natif (graines 7, 11, 1000) :
chaque essai du score faisait déjà partie d'un temps fort montré (l'essai est « forcé »
à tous les niveaux sauf « commentaire seul »), **mais la scène 3D ne montrait pas toujours
le fait** :

1. **Essai « sur ballon porté » sans ballon porté (§ 9.6)** — origine **moteur**. Tranché :
   un essai marqué dans le même pas qu'une touche gagnée près de la ligne (origine `maul`)
   **est** un ballon porté, quelle que soit la combinaison de lancer. Le moteur l'écrit sur
   la conquête du même pas : fait structuré `porte: true` (`contestSetPiece`,
   `dist/rugby.js`), posé après le tirage de l'essai, sans tirage supplémentaire (même
   match, même score, même journal hors ce champ : contrôlé par un témoin). La sélection
   (`match-highlights.cjs`), la scène (`match2d.js`, formation du ballon porté), la
   validation des sauvegardes (`saves.js`) et la vue (`match_gestes.gd`) le lisent : la
   touche « équilibrée » suivie de l'essai montre maintenant le ballon porté puis le
   marqueur qui s'en détache. Option (a) du § 9.6 écartée : elle aurait gardé un essai de
   touche sans geste lisible et changé le texte du commentaire.
2. **Ballon qui saute du porteur au marqueur** — origine **mise en scène**. Le moteur
   désigne un marqueur qui n'est pas toujours le porteur de l'action montrée juste avant ;
   la vue faisait voler le ballon jusqu'à lui en 0,3 s, à travers le terrain. Désormais le
   porteur avance, le marqueur arrive en soutien déjà lancé et reçoit une **passe en
   retrait** (jamais vers l'avant), puis court et aplatit.
3. **Aplati sur la ligne, course surhumaine** — mise en scène. Le ballon est aplati **dans
   l'en-but, 2 m derrière la ligne**, dans l'axe du point d'essai du moteur ; une longue
   échappée dure ce qu'elle dure (8 m/s de pointe au plus, 10 s au plus, sous l'échéance
   de 12 s de la régie) au lieu de tenir en 3 s.

Exception assumée : au niveau « Commentaire seul », aucun temps fort n'est joué (choix
explicite du joueur). « Confier la fin à l'adjoint » et un match repris d'une sauvegarde
ne rejouent pas ce que le moteur a déjà joué (§ 10.2).

Tests : `tests/match-essai-visible.cjs` (5 matchs du harnais × 5 niveaux montrés ; plan
d'essai avec le marqueur du commentaire ; essai sur ballon porté précédé de sa conquête
`porte` dans le même temps fort ; témoin sans le champ ; validation des sauvegardes ;
moteur natif minute par minute sur les graines 7 et 1000 : un plan d'essai par essai du
score), `tests/godot-match-essai.cjs` (passe en retrait, ballon jamais téléporté, allures
humaines, aplati dans l'en-but, ballon porté formé sur le seul fait `porte`).

### 11.2 Gestes adaptés en match

Voir `docs/match-animations-adaptees-20261111.md`, section « Gestes joués avec la
bibliothèque ». Sans `CD_MATCH_ANIMATIONS`, rien ne change.

### 11.3 Défauts de la capture Windows d'un match complet

- **Images sombres et vides vers la 75e minute** : reproduit sous Linux (capture du § 9.9,
  graine 7, même match 31 – 15). Le temps fort de la 75e minute est une pénalité (plaquage
  dangereux) puis un carton jaune. Pendant le coup de sifflet, la caméra rapprochée des
  temps forts (`match_cadrage.gd`) ne gardait que les joueurs à moins de 9 m du ballon ;
  sur un ballon mort personne ne l'est : elle serrait l'herbe autour du ballon (0 joueur à
  l'image, image sombre). Ce n'était ni le voile de transition ni une caméra perdue.
  Correctif : un plan cadre au moins les six joueurs les plus proches (30 m au plus) et les
  arrêts de jeu (`penalty`, `card`, `advantage`, `ingoal`, `hand-fault`) sont cadrés en plan
  large. Test `godot-match-cadrage-arret` sur ce temps fort exact (fixture extraite du
  moteur) : 0 joueur à l'image avant, 8 (caméra TV) et 3 (caméra contact) au moins après.
- **Deux boutons « TACTIQUE »** dans la barre du match : le tiroir des consignes garde
  « TACTIQUE », la caméra vue de dessus s'appelle « VUE DE DESSUS » (même nom dans les
  réglages). Aucun choix de style.
- **`tests/godot-match-action-review.cjs`** (échouait déjà sur `main`) : le journal du
  direct s'ouvre dans le tiroir de la vue contextuelle (`_toggle_drawer("Journal")`) ; le
  contrôle « la navigation abandonne la relecture » devient « pendant le direct, la
  navigation est refusée (immersion) et la relecture reste celle du match, jusqu'à sa
  fermeture ». 46 contrôles, 0 échec.

### 11.4 Exécuté, non vérifié

- Tests (Linux, Godot 4.7.2, une suite à la fois) : nouveaux `match-essai-visible`,
  `godot-match-essai`, `godot-match-gestes-adaptes`, `godot-match-cadrage-arret` ; relancés
  sans échec : `match-highlights`, `match-structured-facts`, `match-actions`, `saves`,
  `match-direct`, `matchflow`, `rugby`, `restarts`, `match-rules`, `match2d`,
  `match3d-adapter`, `match-pass-live`, `match-commentary-filters`, `match-tactical-visual`,
  `discipline`, `goalkicking`, `frontrow`, `v19-advantage`, `godot-match-temps-forts`
  (5 modes, 283 contrôles), `godot-match-gestes` (129), `godot-match-animations`,
  `godot-match-action-review` (46), `godot-match-journal`, `godot-match-framing`,
  `godot-match-cut`, `godot-match-motion`, `godot-match-pass`, `godot-match-presentation`.
- Graines 3, 11, 42, 99 et 2024 (moteur natif, minute par minute, niveau dynamique) :
  23 essais, 23 joués dans un temps fort ; les deux essais sur ballon porté suivent leur
  conquête `porte`.
- Captures Xvfb (rendu logiciel, graine 7, 24 premières minutes : touche à la 1re, essais
  aux 14e et 20e, touche, ballon porté et essai à la 21e), avec et sans
  `CD_MATCH_ANIMATIONS` ; match complet sans la bibliothèque pour la 75e minute.
- **Non vérifié** : rien sous Windows ni en Forward+ ; allure des clips Mixamo jugée à
  l'œil sur ces captures seulement ; le plaqué déclenché par la régie n'a pas de test
  automatique avec bibliothèque ; suite complète du dépôt non relancée.

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
