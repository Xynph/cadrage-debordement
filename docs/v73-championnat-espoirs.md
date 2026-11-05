# V73 — Championnat Reichel Espoirs Élite simulé

## Format 2026–2027 et sources
Source FFR : https://www.ffr.fr/actualites/competitions-federales-les-poules-pour-la-saison-2026-2027
Poule 1–4 et format précis : https://www.stade.fr/association-sfp/association/la-poule-des-espoirs-26-27/
Format complémentaire du Challenge : https://preprod.ubb.link/actualites/10418-espoirs-la-poule-est-connue-pour-cette-saison-26-27.html

**24 centres Espoirs**, dont les 14 centres des clubs seniors jouables et **10 centres supplémentaires** provenant des clubs engagés en Reichel Élite (dont des clubs de PRO D2). Poules géographiques de la saison 2026–2027 via identifiants de club explicites, jamais les positions successives d'un tableau. En univers fictif, les noms fictifs remplacent les noms réels; en mode Rugby Réel optionnel, les noms des dix centres supplémentaires sont des libellés seulement et tous les joueurs Espoirs sont générés. Il ne s'agit PAS d'un export officiel FFR des effectifs ni de résultats réels.

**Première phase** : 4 poules de 6, 10 journées aller/retour, 12 rencontres par journée, soit 120 rencontres. Les quatre premiers de chaque poule passent en qualification ; les deux derniers rejoignent le Challenge.

**Deuxième phase** : 4 poules de 4 (16 qualifiés), et 2 poules de 4 (8 clubs Challenge), 6 journées aller/retour soit 72 rencontres. Les deux premiers de chaque poule de qualification passent aux quarts, puis demi-finales et finale. Le Challenge comporte demi-finales et finale.

Les affiches, les scores et les résultats sont simulés, sans prétendre reprendre le calendrier officiel FFR 2026–2027 ni ses horaires ou sa totalité des règles de départage. Les rencontres Espoirs se déroulent pendant les journées du senior, et les phases finales sont achevées par l'intersaison. Les bonus sportifs utilisent ici la règle simplifiée du moteur senior (écart d'essais >=3, bonus défensif <=5), à distinguer du règlement FFR. La notion de catégorie d'âge est simulée par les générations 17–21 ans existantes.

## Jeu et compatibilité
- Composition XV par poste dans la Formation, choix d'une rotation performance/développement/repos/équilibre; gestion automatique des autres centres.
- Résultats et classement séparés du TOP 14 senior; progrès individuels bornés par le potentiel, fatigue et récupération, minutes Espoirs et recommandation de promotion ; promotion effective uniquement via l'action native du centre de formation.
- État optionnel `v73Espoirs` dans la carrière, 24 équipes, 26 tours de calendrier (dont semaines de repos), archives des 4 dernières saisons. Sauvegardes V72 et plus anciennes sans champ V73 restent valides; création différée de la compétition au premier affichage ou à la première journée.
- Aucun accès aux fichiers MATCH 3D #300; aucun nouveau droit de fusion.

## Réception technique
Exécuter `node tests/v73-espoirs-league.cjs`, `node tests/v72-youth-pathways.cjs` et les suites CI GitHub requises; contrôler le SHA exact de la PR avant tout gate officiel. Inspecter le format de sauvegarde, l'absence de doublons dans les poules et les joueurs, et le passage à plusieurs saisons.
