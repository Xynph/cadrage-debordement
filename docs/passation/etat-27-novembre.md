# État exact au 27/11/2026 (milieu de journée)

Photographie prise à partir de `main` au commit « test(staff): feuille déléguée réparée après une blessure du jour de match » (#1363). Tout ce qui suit est à **recontrôler** avec `gh pr list --state open` et `gh run list --workflow "Tests JavaScript" --branch main --limit 10` avant d'agir : plusieurs PR étaient en cours de CI.

## 1. PR fusionnées récentes (26 et 27/11)

### Moteur de match et réalisme

| PR | Ce que ça change côté jeu |
| --- | --- |
| #1305 | Transformation : défense en en-but puis charge, caméra sur le buteur ; défense à 10 m sur pénalité ; bandeau 3D tenu pendant l'arrêt |
| #1307 | Jeu au pied réaliste (≈ 13 coups de pied par match, ≈ 7 touches au pied) |
| #1308 | Récit cohérent : en-avant raconté, avantage selon la loi 7, buteur arrière |
| #1312 | Chorégraphe 3D : le plaqueur du moteur est celui de l'écran ; remplaçant entré en scène |
| #1313 | Conquête : ≈ 90 % des mêlées et 86 % des touches gardées sur son lancer |
| #1314 | IA de match : remplacements par vagues, choix de pénalité selon distance, score, minute ; buteur titulaire ; défense regroupée en fin de match |
| #1316 | Temps forts au pied (option B) et légendes de coups de pied |
| #1319 | Écran intermédiaire : « En-avant, équipe fautive », horloge juste, carton lisible |
| #1320 | Contacts 3D : plus de têtes ni de bustes dans un autre joueur en mêlée et au plaquage |
| #1323 | 50:22 crédibles, test de la défense regroupée |
| #1325, #1331 | Sonde de contacts testée ; bras posés sur les corps (mêlée, maul, plaquage, ruck) |
| #1339 | Jambes sorties de côté du joueur au sol au ruck |
| #1334 | K1 : les consignes données en direct changent vraiment la suite du match |
| #1338 | XV complet dans la fenêtre Équipe (pilier exclu par un jaune à son poste) |
| #1329 | L'en-but nomme l'équipe fautive (bandeau 3D, liaison, écran 2D) ; pastille ESSAI périmée retirée |
| #1330, #1332 | Fil de l'écran intermédiaire à jour ; plus de pelouse vide pendant les fondus |
| #1353 | Relance aussitôt perdue racontée ; test des fautes de main et de l'avantage |
| #1356 | **Remontées tardives réalistes** (défense regroupée à deux scores) |
| #1351 | **K2 : le niveau de chaque joueur compte dans les phases de son poste** (fusionnée à 10 h 39 UTC) |
| #1364 | Le bandeau donne le ballon à l'équipe qui l'a à l'image |

### Interface, sauvegarde, jeu

| PR | Ce que ça change |
| --- | --- |
| #1326 | Reprise exacte d'un ancien journal dont un « Continuer » franchit une semaine (vrai défaut corrigé) |
| #1354 | Carrière Monde exportée juste après un match : réimportable (vrai défaut corrigé) |
| #1336 | Avant-match : frise des essais et bandeau 1280×720 sans débordement |
| #1344 | Charte : plus d'ombre portée sur les pastilles de lettre de la Composition |
| #1349 | Composition : les cartes du pack ne se chevauchent plus |
| #1347 | Grand Bureau 2560 : dernier résultat cliquable, joueur surveillé lié |
| #1345 | Match : « Mon XV » reste dans l'écran à la 76e minute ; planche du direct reprend les arrêts de jeu |
| #1342 | La fenêtre d'un club suit le score du bandeau |
| #1335 | Cris à un joueur sans erreur de méta ; suites du direct reprennent les arrêts |
| #1340 | Pastille du dernier match nommée à part (avant-match) |
| #1355 | **Performance du direct** : la 3D cachée sous l'écran 2D n'est plus rendue (×3 à ×10 d'images par seconde sur la CI lente, rien ne change à l'écran) |

### CI et tests

| PR | Contenu |
| --- | --- |
| #1324 | Préchauffage des portraits : mêmes seuils, meilleur de 3 passes |
| #1327, #1328 | Poids des suites Godot remesurés ; six jobs Godot au lieu de cinq |
| #1348 | Les push de `main` ne s'annulent plus entre eux : la batterie va au bout à chaque fusion |
| #1341 | Plafond de `godot-match-grands-moments` 300 vers 600 s (mesuré : 13 temps forts au lieu de 9, 173 vers 277 s) |
| #1333, #1343, #1337, #1346, #1352 | Tests périmés remis au vert, `match-lois-completes` sous sa limite, graine de la liaison du monde, liaison scriptée |
| #1357 | Mise en page de la Composition testée en mode Monde (test `godot-interface-layout` de retour en CI) |
| #1358, #1359 | Attentes en temps réel (cris-banc, temps-forts) ; reprise après le carton de la 5e minute (3 suites du direct) |
| #1360, #1361 | Essais de pénalité comptés ; réinvestissement selon la marge prévue |
| #1363 | Feuille déléguée réparée après une blessure du jour de match |

## 2. PR encore ouvertes au moment de la passation

| PR | Sujet | Statut |
| --- | --- | --- |
| #1350 | **K3 : les remplaçants comptent** (fraîcheur du match, remplacement au poste, IA qui remplace talonneur par talonneur) | Prête, fusion auto armée, vérificateur GO, CI en cours. Voir [moteur-match.md](moteur-match.md) pour les chiffres et le piège du seuil (36,7 % pour 35) |
| #1362 | Test `planche-direct-2d` : message d'échec clair (plus de code 1 muet) | Fusion auto armée, CI en cours |
| #1365 | Test `vente-joueurs` : chrono de la journée au meilleur de 3 mesures, même seuil de 1,5 s | Fusion auto armée, CI en cours, vérificateur GO |
| #944 | Historique du train de fusion | Hors sujet (« plus d'actualité » selon le créateur). Brouillon : ne pas toucher |
| #908 | Bruits de match enregistrés | Hors sujet. En conflit avec `main` depuis le 18/11 et **fusion auto armée par erreur** : la désarmer (`gh pr merge 908 --disable-auto`) et ne pas la fusionner |

Si #1350 rougit : lire `gh pr checks 1350` ; si c'est « Suites 4/10 » à cause d'une suite lente, `gh pr update-branch 1350` relance. Elle touche `dist/matchflow.js`, `dist/opposition.js`, `dist/restarts.js` et a élargi `tests/match-consignes-direct.cjs` (24 vers 192 matchs, mêmes graines et mêmes assertions, accord du créateur, poids CI 1200 s).

Chantiers terminés, dont les conversations sont à clore : « Lois manquantes », « Défense et gestes 3D » (tout fusionné : #1317, #1318, #1322), « contacts 3D bras ».

## 3. Ce qui est vérifié GO (vérificateur indépendant, vrai jeu ou vraie CI)

#1305, #1307, #1308, #1312 (réserve de marge sur 3 graines), #1314, #1316, #1319, #1320, #1323, #1334, #1338, #1345, #1349, #1354, #1355 (GO a posteriori, paires simultanées PR contre `main`), #1356, #1357 à #1361, #1363, #1365, #1351 (K2), #1350 (K3, GO du vérificateur le 27/11 ; reste la CI). Réserves connues de ces GO :

- #1312 : le test « plaqueur du moteur à l'écran » passe avec une marge étroite (28/45 = 0,62 pour un seuil de 0,56 sur les graines 7, 8, 9).
- #1355 : la fusion est partie par un réarmement extérieur avant la fin de l'arbitrage ; l'arbitrage a ensuite donné GO.
- #1350 : `match-remplacants` à 36,7 % pour un seuil de 35 (main : 18,1 %).

## 4. Rouges connus de la batterie de `main` et leur cause

Les batteries complètes de `main` étaient rouges presque toute la matinée du 27/11 parce que chaque correctif révélait le suivant (rouges en cascade). État par cause :

| Cause | Suites | Statut |
| --- | --- | --- |
| Carton à la 5e minute non repris (le match attend « Reprendre », voulu) | `godot-consignes-match`, `godot-conseil-adjoint`, `godot-planche-direct-stat-periodes` | Corrigé (#1359) |
| Rythme du test cris-banc (boucle « 10 images à ×16 » qui fait filer le match jusqu'à la mi-temps) et course du test temps-forts (lit le plan juste après la pause sur une machine lente) | `godot-cris-banc`, `godot-match-temps-forts` | Corrigé (#1358). Les deux restaient les plus lourdes et les plus fragiles ; relire leur durée en CI |
| Essais de pénalité non comptés par les tests | `match-essai-visible`, `stats-fiche-joueur` | Corrigé (#1360). Limite : depuis #1356, les graines 7 et 1000 n'ont plus d'essai de pénalité, donc le plan « penalty-try » de `match-essai-visible` n'est plus exercé |
| Club riche qui ne réinvestit plus s'il prévoit une perte | `investissements-excedents` | Corrigé (#1361) |
| Feuille déléguée réparée après une blessure à l'entraînement | `delegue-composition-staff` (sous-test 2) | Corrigé (#1363) |
| Chrono d'une journée de vente de joueurs à 1,0 à 1,8 s pour 1,5 s permis en CI (0,7 s en local) | `vente-joueurs` (Suites 4/10) | Correctif dans #1365 (meilleur de 3) ; en cours |
| Délais dépassés sur runner lent (+60 % partout) | `presse-rapide-monde`, `world-zones-classement`, `world-nouvelle-saison-rapide` (23,6 s pour 20 s) | À surveiller ; pas de défaut du jeu. Ne pas relever les limites sans mesure |
| Test de vitesse du préchauffage des portraits (251 à 256 ms pour 250 ms) | `godot-portraits-prechauffage` | Intermittent sur CI chargée ; seuil inchangé ; relancer, mais lire le journal avant (une fois c'était un vrai rouge) |
| Rouges rares et isolés (voir [solidite-ci.md](solidite-ci.md) section 4) | `godot-survols-club-courbe-rebours`, `deepen-analytics-real-ui`, `godot-equipe-type`, `godot-preparation-ecran`, `godot-centre-cartes`, `godot-phrases-lot10`, `godot-apres-match` | À reprendre si ils reviennent |

Au moment de la passation, la batterie de `main` sur le dernier commit (qui inclut #1363) était **en cours** ; les deux précédentes avaient échoué sur `Suites 5/10` et `Suites 7/10` (suites qui se terminent en environ 76 s, limite 180 s). Vérifier avant tout autre chose si `main` est vert. Rappel : `main` rouge doit être corrigé **avant toute autre fusion**, et `main-rouge.yml` peut ouvrir tout seul une PR de retour arrière.

Autres points :

- `match-pilotage` (« attaquer leur aile faible rapporte », seuil 1 point) était au bord du seuil sur la branche K2 (+0,74 sur 400 matchs, alors que 2 × 3000 matchs donnaient +2,55 ± 0,23 : c'est un tirage défavorable des 400 graines, pas un défaut du moteur). Proposition faite : passer les séries à au moins 1 500 matchs, même seuil. #1351 est fusionnée : vérifier que `match-pilotage` est vert sur `main` et, sinon, appliquer cette proposition **sans toucher au seuil**.
- `godot-match-temps-forts` démarre parfois 0,1 à 2 minutes avant la coupure de 45 minutes du job : à revérifier maintenant que six jobs et les poids remesurés sont actifs.
- `godot-match-liaison-monde` dépend désormais d'une séquence écrite (#1352) et plus des tirages ; `godot-planche-*` dépendent encore de la graine 3.

## 5. Calage chiffré du moteur de match

Cibles : Top 14 réel, matchs serrés (écart ≤ 7) ≈ 40 %.

| Indicateur | Valeur actuelle | Cible / remarque |
| --- | --- | --- |
| Top 14, matchs serrés | 41 à 43 % après #1323 ; 38,5 à 39,3 % en IA contre IA sur 2 × 600 avec K3 | Réel ≈ 40 %. Tenu |
| URC, matchs serrés | ≈ 34 % après #1323 ; 36,7 à 38,8 % en saisons avec K2 / K3 | Réel ≈ 41 %. À surveiller à chaque lot |
| Premiership, matchs serrés | 38,0 vers 39,5 % avec K3 | |
| Favori (Top 14) | 63,4 à 63,8 % | Stable |
| **Remontées tardives** (mené de 11 à 14 à la 75e, écart ≤ 7 à la fin) | Avant #1356 : 34 % en saison Monde (21 % en IA contre IA) pour une cible de 20 à 25 %. Après #1356 : < 20 % sur main (16,9 % sur 2 × 600). Avec K3 : 20,9 % | **Réserve ouverte** : valeur à vérifier par championnat, il peut rester des écarts (les mesures de la veille sont par championnat, pas toutes refaites après #1356) |
| Points par match (Top 14) | 50,3 sur main, 51,0 avec K3 | Réel ≈ 51 |
| Cartons jaunes | 1,8 par match avant (anomalie 11) ; baisse d'environ 15 % signalée après les derniers lots | Réel 1,1 à 1,5. **À examiner** : mesurer sur 150 matchs, la baisse vient probablement d'un des lots de lois ; vérifier qu'on ne passe pas sous la fourchette réelle |
| Essais de pénalité | ≈ 0,12 par match en Top 14 | Dans la fourchette réelle |
| 50:22 | ≈ 0,3 par match | Réel 0,3 à 0,5 |
| Coups de pied | ≈ 13 par match | Réel 40 à 50 en jeu réel selon la source ; décision : calage « invariant » de possession gardé |
| Remplaçants (K3) | Un changement à la 50e modifie la suite dans 25 à 40 % des matchs (main : 15 à 30 %) ; marge +0,98 contre −0,39 | Voir [moteur-match.md](moteur-match.md) |
| Niveau au poste (K2) | Club de référence 40,3 % vers 42,3 % de victoires (marge neutre à moins d'un point) ; un titulaire à −15 au poste pèse de −0,4 à −4,6 points selon le poste (pilier 0 vers −2,6, talonneur −2,9 vers −4,6) | Voir [moteur-match.md](moteur-match.md) |
| Unicité | 600 déroulements différents sur 600 | Tenu |

Rappel : le joueur ne voit jamais le poids exact d'une décision (incertitude) ; ces chiffres sont des mesures de développement.

## 6. Chiffres de test et de CI utiles

- 10 jobs de suites Node, 6 jobs Godot, un agrégateur `Validation CI`. Limites : 50 min par job de suites, 55 min par job Godot (45 min pour l'étape des suites Godot) ; les jobs Godot durent environ 36 min à six jobs.
- Suites les plus lourdes en Godot : `godot-cris-banc` (965 s mesurées en CI avant #1355 et #1358), `planche-carte-joueur`, `planche-direct-2d` et `-tableau`, `consignes-match`, `temps-forts`, `stat-periodes`, `godot-match-grands-moments` (277 s, plafond 600 s).
- Disque du PC du créateur : environ 130 Go libres au moment de la passation (sans objet en cloud).
