# Audit URC / Super Rugby Pacific — 9 novembre 2026

Audit en lecture seule sur le code de référence `e2f111a2330462aa6545866441289346ac92f2d0` (la branche courante contient aussi le test Godot #416, sans incidence). Aucun code de jeu, branche, PR ou commentaire GitHub modifié par cet audit.

## Conclusion opérationnelle

Aucun écart réglementaire nouveau certain et borné démontré. Les deux lacunes documentaires majeures sont déjà signalées explicitement dans le moteur. Il serait incorrect de convertir ces références provisoires en règles confirmées pour les saisons jouées. Prioriser EPCR si son audit trouve une règle 2026/27 intégrable, et préparer ici un lot de qualification URC/Pacifique sans mutation des règles.

## Éditions réellement jouées

- URC : première saison 2026/27, 16 équipes, 18 journées et huit qualifiés. Profil détaillé de repli URC **2025/26** marqué `provisional-current-edition-unavailable` dans `native/engine/world-competitions.cjs:52`. Le format 2026/27 est corroboré séparément ; il n'établit pas les règles de feuille ou d'inscription.
- Super Rugby Pacific : première saison **2027**, dix clubs, 17 tours, 16 rencontres par club et un repos. Code `native/engine/super-rugby-pacific.cjs` : calendrier/tableau `confirmed-2027`, mais barème, départages et horloge sous politique explicite `srp-2026-reference`, statut `provisional-2026-reference-not-verified-for-2027`. Les saisons suivantes utilisent un modèle de simulation `repeat-2027-template`, pas des calendriers officiels annoncés.
- Versions Monde v1–v5 listées dans `native/engine/world-editions.cjs:11–15`. `world-career.cjs:10,34` calcule URC 2026 + saison − 1 et SRP 2027 + saison − 1.

## Sources officielles effectivement lues avec Firecrawl

1. https://www.unitedrugby.com/about/competition-rules/ — récupération live HTTP 200. Source officielle mais **mélange d'éditions** : titre final 2021/22, date limite d'inscription 21 mars 2022, qualifications européennes 2024/25. Ce texte décrit notamment 50 inscrits au maximum, au moins dix premières lignes et remplacements d'inscription à 48 h ; ces contraintes ne doivent pas être imposées aux carrières 2026/27 sans texte de cette édition. Ne pas prendre la disponibilité d'un site pour une validation temporelle de son contenu.
2. https://super.rugby/superrugby/about-super-rugby/tournament-format/ — récupération live HTTP 200. Le texte annonce expressément **2026**, onze équipes et quatorze matchs par équipe : ce format n'est plus celui du calendrier 2027. Il détaille +3 essais d'écart, défaite à sept points ou moins, wins/diff/tries/tryDiff/tirage, point en or jusqu'à dix minutes, deux prolongations de dix minutes puis mort subite de dix minutes et cinq buteurs. Les politiques provisoires du code reprennent correctement ce statut de référence 2026.
3. https://super.rugby/superrugby/news/expanded-season-and-high-stakes-finals-series-confirmed-for-2027/ — récupération live HTTP 200 ; publié **1 juillet 2026**. Confirme dix équipes, 17 semaines, 16 matchs, top six, seeds 1–2 directement en demi-finale, éliminations 3–6 et 4–5, reseeding des demi-finales et finale 26 juin 2027. Phrase introductive « respectively » contradictoire avec le tableau explicite, déjà reconnue dans `docs/super-rugby-pacific-2027.md`. Code et documentation suivent le tableau explicite.
4. https://stats.unitedrugby.com/match-centre/table/2026-27 — trouvé dans les recherches (extrait seulement, pas une seconde lecture complète). Confirme qu'il s'agit bien du centre 2026/27, mais ne suffit pas à prouver un règlement consolidé.

La référence URC 2025/26 déjà enregistrée reste https://d19fc3vd0ojo3m.cloudfront.net/irfu/wp-content/uploads/2025/09/26090041/001.-Championship-Rules-25_26__CLEAN.pdf . Elle n'a pas été relue dans ce tour ; ne pas présenter le PDF 2026/27 comme retrouvé. Les recherches ciblées URC et Irish Rugby n'ont pas localisé la nouvelle consolidation (résultats AIL exclus : autre compétition).

## Comparaison au code et limites

- `world-competitions.cjs` : barème URC quatre essais et bonus défensif <=7 ; critères points/victoires/diff/essais/points marqués/diff essais/suspensions/jaunes. Quarts 1–8, 2–7, 3–6, 4–5 et SF Q1–Q4, Q2–Q3 cohérents avec le résumé de référence. Lieu de finale à désigner, pas stade résident déduit.
- `world-career.cjs:34` ne fournit pas de registre de suspensions en commission ou de totaux de jaunes au calcul URC. Le module de classement distingue ces critères manquants et les tirages de jeu. C'est une **limite connue de simulation**, pas une raison d'inventer une suspension à partir d'un carton ni de prétendre à une conformité complète.
- `super-rugby-pacific.cjs:100+` : bonus et classement cohérents avec la référence 2026, tri final sans preuve marqué non résolu et politique explicite exigée. `srp-match.cjs` implémente déjà le point en or et les phases supplémentaires. Pas de besoin de réécrire ces mécanismes sans nouvelle source 2027.
- Les règles particulières d'inscription et de feuille de chaque ligue ne sont pas établies par cet audit. Les réglementations sportives, règles migratoires, nationalité et éligibilité ne peuvent pas être déduites de la composition anonymisée d'un effectif.

## Lot parallèle recommandé

**Qualification des références URC et Pacifique**, sans modification réglementaire ni format de sauvegarde :

- nouveaux chemins proposés `tests/urc-pacific-rules-boundary.cjs` et `docs/urc-pacific-qualification-20261109.md` ; ils restent disjoints des fichiers EPCR ; aucun changement `world-competitions.cjs`, `world-career.cjs`, `worker.cjs`, sauvegardes ou données dans ce lot ;
- vérifier au niveau intégration que provenance et statut provisoire restent cohérents pour URC 2026/27 et SRP 2027, sans confondre le calendrier confirmé et la politique de match ;
- contrôler le changement de saison avec fixtures synthétiques : 16 matchs Pacifique, repos, tirage stable, absence d'Europe, export/réouverture identiques ;
- cas URC de classement complètement égal : ne pas annoncer « moins de suspensions » si les données de commission sont inconnues ; conserver et tester la distinction entre résultat sportif vérifié et hypothèse de tirage ;
- avant d'ajouter une nouvelle suite, compléter le manque précis trouvé dans les suites existantes (éviter de dupliquer leur implémentation).

L'implémentation de nouvelles contraintes de feuille/inscription URC ou SRP doit attendre une preuve de l'édition jouée ; un travail documentaire est possible immédiatement. Les règles EPCR peuvent avancer indépendamment dans leur propre lot, à coordonner si elles touchent les modules mondiaux partagés.

## Accès et validation

Firecrawl a bien accédé aux deux sites officiels malgré la liste réseau du terminal limitée notamment à api.github.com. Aucun ajout de domaine ou identifiant n'a été nécessaire pour cet audit. Les sorties des recherches sont des extraits ; seules les trois pages marquées lues ont été récupérées intégralement.

Test ciblé lancé sous Node 22.23.4 : `node --test tests/world-competitions.cjs tests/world-urc-shootout-v5.cjs tests/srp-world-calendar.cjs`. Résultat : **28 tests réussis, zéro échec, zéro ignoré** en 1,4 s. Log : `/workspace/work/urc-pacific-tests.log`. Ces tests valident les scénarios existants, pas la disponibilité de nouvelles règles 2026/27 ou 2027.
