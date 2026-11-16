# Passation vers Codex — 15/11/2026

Session Claude « mode Monde / centre de formation / notes réalistes » (13-15/11). État au 15/11 à 9 h : main = `b0fe0988`, aucune PR ouverte de cette session. PR ouvertes d'autres sessions : #714 (Gabi, brouillon), #670 (macOS, Codex, brouillon). #713 (délégation : composition par le staff) a disparu des PR ouvertes : vérifier si elle a été fusionnée ou fermée.

## Règles du projet (à respecter)
- **Un seul mode : le mode Monde** (`new_career` mode `world-champ`, 116 clubs). Aucun test ne doit tourner dans l'ancien mode ; les suites encore héritées portent `process.env.CD_MODES_HERITES='1'` (ligne 2) et sont exclues de la CI (`ci/legacy-modes.cjs`, garde `tests/ci-modes-monde.cjs`).
- **Coordination sur le ticket #591** : RÉSERVÉ avant un chantier, PRÊT, FUSIONNÉ ; un seul intégrateur à la fois (demander/libérer le créneau sur #591).
- **CI** : fusionner seulement si « Validation CI » est verte et la PR non « dirty » (une PR en conflit ne lance pas de CI). API GitHub REST uniquement. Poids/budgets des suites : `ci/suite-weights.json` et `ci/run-shard-suites.sh` ; la garde `node tests/ci-shard-replay.cjs` refuse les poids non mesurés — régénérer depuis les journaux réels (`node ci/suite-weights.cjs js <journaux> --garder`, cf. #668/#717), jamais de poids réduit artificiellement, jamais d'affaiblissement d'un contrôle.
- **Aucune identité réelle dans le dépôt public** (noms, dates de naissance, portraits, logos) : elles vivent dans le dépôt privé `Xynph/rugby-reel-donnees` et dans le pack « Rugby Réel » (release du dépôt privé, 5 884 joueurs, 2 160 staffs, 116 clubs). Contrôle : `CD_SOURCES_PRIVEES=<clone privé> node tests/base-names-leak.cjs` (0 nom réel attendu). Le dépôt public reste **public** (CI gratuite) ; l'historique contient encore d'anciennes données : décision de Léo = ne rien faire pour l'instant, puis plus tard repartir d'un dépôt public neuf (ancien dépôt renommé et passé en privé).
- Fichier `LICENSE` « tous droits réservés » en place (#701).
- Jamais de fichiers Mixamo ni de portraits réels dans le dépôt public ; ne jamais remplacer les portraits réels du mod Rugby Réel. Aucune dépense sans accord de Léo.

## Ce qui a été livré (13-15/11)
| Sujet | PR |
|---|---|
| Centre de formation politique 3 (Crabos/Espoirs, génération du 1er juillet, rapports) | #626, #618 (budget centre par pays) |
| Mode Monde unique, harnais Monde, migrations de tests (tous lots) | #637, #639, #655, #694, #686-#692 |
| Championnats actifs + jauge de fluidité | #643/#644 |
| Portraits selon la carrure | #641 |
| JIFF en mode Monde | #660 |
| Sauvegarde incrémentale (−32 % par semaine) | #661, #669, #672 |
| Tri des ~160 anciennes PR + suppression de 175 branches (workflow manuel `nettoyage-branches.yml`) | #696, #700 |
| Budget de saison réaliste par défaut (nouvelles carrières) | #699 |
| Leviers de redressement (Finances > Budget) | #691 |
| Retrait des identités réelles du dépôt public | #702, #703 |
| Presse locale par pays (48 journalistes, 25 médias inventés ; vrais noms sourcés dans le pack) | #705 |
| Courbe de niveau du moteur (+6 ≈ 76 %, +10 ≈ 86 %, domicile ≈ 64-65 %) | #712, #725 |
| Barème senior V2 : notes/potentiels selon niveau réel joueur/club/championnat (nouvelles carrières) | #716, #735 |
| Chorégraphe corrigé + « match piège » (exploits à l'extérieur) | #734 |
| Test de mobilité du manager remis en CI (sauvegarde de fin de saison en cache) | #733 |
| Promesses publiques en conférence de presse | #732 |

Documents utiles : `docs/courbe-niveau-moteur-20261114.md`, `docs/retrait-noms-reels-plan-20261111.md`, `docs/salaires-par-niveau-20261111.md` ; étude des notes : doc projet `notes-clubs-championnats-20261114.md`.

## Données de niveau réel (barème V2)
- Sources privées : `rugby-reel-donnees/niveaux/` — `niveaux-<championnat>.csv` (id, classe internationale, statut titulaire/rotation/réserviste/jeune, U20, étage du club, sources, confiance) et `clubs-<championnat>.csv` (étage cador→relégable), + statut LNR dérivé de `data/scouting/review-v12/career-evidence.json` (minutes 2024-25/2025-26). Consigne de collecte : `niveaux/CONSIGNE.md`.
- Table publique non nominative : `native/engine/world-niveaux-v2.json`, compilée par `node tools/compile-niveaux-v2.cjs <clone privé>` (+ `--check`).
- Couverture : statut connu ≈ LNR, Nationale, Premiership 86 %, URC 82 %, Championship 72 %, Super Rugby 59 % ; **Japon D1/D2 : 0 %** ; 497 internationaux identifiés.

## Chantiers restants (par priorité)
1. **Statut des joueurs du Japon (D1 657, D2 421)** — seule source : feuilles de match officielles `https://league-one.jp/en/match/<id>/print` (D1 2025-26 ≈ ids 29250–29370 ; D2 à repérer). Le site renvoie **HTTP 429 en cas de rafale** : une requête à la fois, ≥ 10 s d'écart. Calculer titularisations/entrées par joueur, appliquer la règle de `CONSIGNE.md`, rapprocher par nom (romaji) dans le même club, mettre à jour les CSV dans le dépôt privé, puis recompiler la table (`compile-niveaux-v2.cjs`) et ouvrir une PR (contrôle base-names-leak). Une feuille déjà lue : match 29271.
2. **Recalage fin du barème V2** : Premiership et Super Rugby ≈ 2,5 points au-dessus des cibles (78 / 77,5), faute de statut pour une partie des joueurs ; Toulouse au-dessus de la cible de meilleur XV (85). À refaire après le point 1 et avec plusieurs graines/saisons.
3. **Moteur** : sur vrais effectifs à ~16 points d'écart, le plus faible gagne chez lui 12,4 % au résultat rapide contre 7,0 % au moteur complet (écart à réduire) ; scores moyens ≈ 54 points (complet) vs ≈ 49,5 (rapide).
4. **Promesses en conférence** : barèmes d'effets et seuils de vraisemblance à régler à l'usage ; pas de test du verdict Coupe des champions ; pas de carte sur le Bureau (seulement l'écran Club).
5. **Presse internationale** : 26 journalistes et 11 médias réels introuvables (Géorgie, Nationale, coupes d'Europe, seconds médias de plusieurs pays) → le nom inventé reste affiché.
6. **Salaires des Espoirs** : 2 000 €/semaine figés dans la validation des sauvegardes, au-dessus du salaire médian pro du budget réaliste → chantier à part (validateur `dist/saves.js`).
7. **Validation incrémentale** : `validateCareer` (~0,5 s, 13 000 joueurs) et `staffCareer` (~0,14 s) tournent en entier à chaque commande ; modèle envoyé à Godot ≈ 18,5 Mo.
8. **Dette de tests** : suites Godot encore en ancien mode exclues de la CI (godot-analysis-club-links, godot-epcr-preparation, godot-immersive-reception, native-relationships-ui, godot-review-regressions, godot-finance-ledger-links, godot-interface-layout, godot-match-action-review) + autres suites `CD_MODES_HERITES` (lister avec `git grep -l "CD_MODES_HERITES='1'" tests/`).
9. **À vérifier dans le jeu (Godot, par Léo)** : centre de formation (génération, suivi, rapport), choix des championnats + jauge, portraits/carrure, leviers Finances, presse locale, promesses (salle de presse + écran Club), ressenti des écarts de niveau.

## Pièges connus
- Une PR « dirty » ne lance pas de CI : remettre à jour sur main juste avant de pousser (main bouge vite).
- Toute branche qui touche au moteur doit régénérer la séquence des gestes (fixtures).
- Le club humain d'une carrière de test qui garde une feuille figée s'épuise (condition 40 % après 20 semaines) : utiliser la composition automatique dans les mesures.
- Le dépôt privé n'a pas de CI et ne doit pas en avoir.
