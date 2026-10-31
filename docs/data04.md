# DATA-04 — Enrichissement réel LNR (31/10/2026)

## Couverture et limites
Quatre nouveaux fichiers `modding/data04/top14-a.json`, `top14-b.json`, `prod2-a.json`, `prod2-b.json` enrichissent **1 592/1 592 identifiants de joueurs** déjà publiés dans PR #121 : groupe de poste LNR (1ère ligne, 2ème ligne, 3ème ligne, demi de mêlée, demi d'ouverture, ailier, arrière, centre). **1 559 nationalités publiées** récupérées par images-texte des drapeaux LNR. **33 nationalités nulles** restent à vérifier individuellement. Ces groupes ne garantissent pas un poste spécialisé (pilier droit vs gauche, etc.).

Trois profils individuels consultés explicitement : Barnabé Massa (1m80, 101 kg, 22 ans), Giorgi Dzmanashvili (1m86, 122 kg, 24 ans), Pierre Jouvin (1m85, 105 kg, 22 ans). Valeurs affichées le jour de collecte ; **aucune date de naissance exacte fournie**, champ null. Aucun âge calculé ou transféré au 1er juillet 2026 sans preuve.

Les pages LNR /effectif-staff examinées affichent les joueurs, mais **aucune liste des membres du staff structurée dans leur Markdown**, donc **0 staff validé** au cours de ce lot. Recherche à poursuivre sur sites officiels des clubs ou pages d'encadrement propres.

## Rapprochement des arrivées
`modding/data04/arrival-reconciliation.json` compare les **30 arrivées documentées** de DATA-02 aux 1 592 noms de DATA-03. La comparaison normalisée des noms a trouvé **21 correspondances** et **9 absences** ; ces absences ne prouvent ni départ ni non-appartenance au club, et le seul nom ne prouve pas une identité de manière définitive. Contrôles supplémentaires par ID, nom complet et date d'arrivée obligatoires.

## Chronologie indispensable
Ceci est un **instantané au 31/10/2026**. Les transferts peuvent être intervenus après le 01/07/2026 ; le **véritable effectif historique au 1er juillet 2026 reste non établi**. Conserver null pour les contrats, budgets, salaires, stats non trouvées. Aucun logo ni photo embarqué. Ne pas rattacher ces données au jeu par défaut ; elles restent dans le mod Rugby Réel optionnel.

## Tests et dépendances
`tests/data04.cjs` vérifie les quantités, unicité des IDs, la réconciliation et les profils. Le lot est autonome sur les fichiers DATA-04, mais pour l'intégration réelle attend **PR #121 DATA-03** et **PR #119 MAPPING-01** (fusionnée). Ne pas toucher à `dist/**` ni aux anciennes sauvegardes.

## Sources
- `https://top14.lnr.fr/club/<slug>/effectif-staff` (14 pages)
- `https://prod2.lnr.fr/club/<slug>/effectif-staff` (16 pages)
- Fiches individuelles : https://top14.lnr.fr/joueur/862-barnabe-massa ; https://top14.lnr.fr/joueur/3233-giorgi-dzmanashvili ; https://prod2.lnr.fr/joueur/3129-pierre-jouvin
- Arrivées : https://top14.lnr.fr/actualite/le-tableau-des-transferts-pour-la-saison-20262027
