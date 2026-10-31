# DATA-05-BULK2 — extension des profils LNR, 31/10/2026

Cycle producteur indépendant à partir de main c022f98d. Sélection déterministe des joueurs aux indices 3 à 7 de chaque club DATA-03 : **150 candidats**, sans chevauchement avec les trois premiers joueurs des 30 clubs traités dans PR #126.

**60 pages individuelles réellement extraites avec Firecrawl**, 5 lots de 12, couvrant les 12 premiers clubs de la liste. Tous les 60 ont un ID LNR distinct, un nom, une nationalité, un groupe de poste, un âge publié et une URL source. **43/60** ont taille et poids publiés ; 17 mensurations sont partiellement ou totalement manquantes et préservées null. Les 90 candidats restants de cette sélection ne sont PAS traités et ne doivent pas être comptés parmi les fiches enrichies.

Au cumul de cette campagne, PR #126 couvrait 90 fiches, et ce lot 60 autres fiches sans recouvrement de sélection, soit **150 pages individuelles distinctes** via les deux cycles. PR #123 incluait 12 autres consultations qui peuvent recouper les 90 premières, ne pas additionner.

**Staffs :** pas de nouveaux membres vérifiés pour ce lot ; restent les deux clubs documentés par PR #126 (ASM Clermont, UBB). **28 clubs sans preuves nominatives**. Aucun staff ne doit être déclaré présent au 01/07/2026 sur une simple fiche actuelle.

**Transferts / prêts :** les 30 arrivées DATA-02 ont été consignées dans PR #126, mais sans dates d'effet certifiées. Aucune nouvelle date de transfert ou de prêt n'a été retrouvée dans ce lot de fiches individuelles. Effectifs au 01/07/2026 non reconstitués ; naissance exacte null, appartenance historique non vérifiée. Ne pas confondre instantané 31/10/2026 et effectif de départ.

Contrôles : 60 identifiants et URL/club recoupés sur fichiers GitHub, 60 uniques, 43 mensurations complètes, 12 clubs. Un test exécutable `node --test tests/data05-bulk2.cjs` est livré et doit être réellement exécuté par CI ; ne pas considérer les tests anciens comme preuve de cette branche.

**Aucun fichier jeu dist/**, sauvegarde, staff inventé, salaire ou budget inventé. PR #121, #122, #123, #126 restent des dépendances ouvertes ; aucun merge producteur.