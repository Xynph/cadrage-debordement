# V61 — Calendrier de suivi des objectifs de la direction

La V42 déjà intégrée fournit objectifs, confiance du président et sponsoring. **V61 ne doit pas devenir un second système de direction**. Ce prototype est un adaptateur autonome de réunions périodiques : échéances par semaine, critères mesurables (victoires, points, classement, trésorerie), poids, bilan, objectifs non vérifiables sans données, ordre des prochains jalons, historique et changement de saison.

**Intégration impérative** : mapper les objectifs natifs V42 en entrée, réutiliser la confiance du président native en sortie, ne jamais appliquer deux fois les variations. Les chiffres et coefficients du prototype sont fictifs. Les résultats doivent provenir de S.history, la trésorerie du ledger réel et les semaines du calendrier natif. Pas de nouvelles sauvegardes ni fichier partagé. Revoir les cas où les objectifs restent non vérifiables, les réunions répétées et les objectifs intersaison avant activation.

Tests : onze contrats déterministes, 15 saisons, reprise JSON, absence de double sanction par objectif. Aucune validation du gameplay réel, ni test natif Windows. Conserver cette PR en brouillon sans fusion, pour revue par l'autre développeur.
