# Rugby Legacy 27 — autonomie du 11 novembre 2026

Base figée : `96f537040bf9f2e37bf10b0a9b09518b732244a2`. Arrêt au plus tard le 11 novembre à 18:00 UTC (19:00 Paris), ou lorsque les trois livrables sont atteints. Aucune fusion, aucune question, aucun service payant ni changement des paramètres GitHub. Les décisions sont prudentes, réversibles et documentées. Les anciennes autorisations de fusion ne valent pas pour cette tranche.

## Exécution et responsabilités

1. Fenêtres : reproduire puis corriger uniquement la géométrie. Un producteur possède le dialogue contrat et le redimensionnement partagé ; un autre possède calendrier, entrées contextuelles et balayage. Mesurer rectangles, contrôles accessibles et défilements aux quatre tailles demandées, avec un témoin 2560×1440. Les écrans réservés à Claude sont mesurés mais ne sont pas modifiés. Une PR brouillon commune et une liste explicite des dialogues non ouverts.
2. SDK : un producteur reprend les neuf wrappers sans helper ; un autre rejoue les vingt suites auditées et six blocages, puis sépare les correctifs par cause. Les anciens échecs ne prouvent pas ceux de main96. Aucun délai relevé pour masquer une erreur de script ; distinguer code testé et lecture seule. Ajouter uniquement les suites qualifiées à une proposition CI.
3. Réception : deux producteurs lisent et testent les candidats de Claude dans des copies jetables. Verdict par SHA, rafraîchi si le candidat bouge. Priorité #555, packs, #553, calendrier, puis #552/#554/#550. Aucun correctif de leur production ; signaler les défauts au moyen de rapports et commentaires de réception.
4. Intégrateur Cloud : seul rédacteur GitHub, branches/PR brouillons séparées par cause, rassemble preuves et limites. La recette Windows des drapeaux reste conditionnée à la chaîne existante ; ne jamais appeler une recette Linux « Windows ». Traiter les fixtures historiques réelles et le mapping lineout seulement après les priorités.

## Ressources et preuves

Les six producteurs ont chacun un worktree distinct. Un verrou `/tmp/rg27-godot-sdk.lock` sérialise chaque commande Godot ; les mesures initiales P1 passent avant les campagnes P2. Rendu Linux X11 réel avec Xvfb et Mesa, audio Dummy, profils jetables extérieurs au jeu, Gabi silencieux. Les assets ignorés et sidecars importés sont préparés avant les suites afin de distinguer un défaut de fixture d’un défaut produit. Conserver sorties complètes, résultats, commit testé, captures réellement obtenues et commandes reproductibles. Les preuves Windows de la livraison précédente restent celles de leur paquet, pas celles des candidats.

## Critères de livraison

- PR géométrie avec mesures avant/après et reste à faire.
- Suites ciblées chacune mise à jour ou classée avec preuve, une PR par famille.
- Chaque candidat Claude a un verdict reçu / à corriger / refusé, ou absence de candidat explicitement constatée.
- Bilan unique : exécuté, déduit, non exécuté, liens, fichiers, limites et prochaine étape. Effort Sol recommandé indiqué dans les messages projet.
