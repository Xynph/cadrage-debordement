# DATA-01 — Inventaire de recherche Rugby Réel 2026-2027

**Périmètre :** inventaire indépendant de recherche, pas encore un mod prêt à distribuer ni à installer. Aucun contenu réel ajouté au jeu de base fictif. Seuls des faits textuels référencés ont été relevés ; aucune image, logo, photo ou base de données complète de tiers n'est copiée.

## Collecte effectuée
- 14 clubs du TOP 14 et leurs stades : https://top14.lnr.fr/clubs
- 16 clubs de PRO D2 et leurs stades : https://prod2.lnr.fr/clubs
- Dates de saison TOP 14 / PRO D2 : https://top14.lnr.fr/actualite/calendrier-20262027-les-dates-connues et https://prod2.lnr.fr/actualite/decouvrez-le-calendrier-2026-2027-de-pro-d2
- **Dix mouvements de joueurs, seulement comme échantillon vérifiable**, non des effectifs : https://top14.lnr.fr/actualite/le-tableau-des-transferts-pour-la-saison-20262027
- Catalogue de compétitions fédérales et jeunes (composition des poules à importer plus tard) : https://amp.www.ffr.fr/actualites/competitions-federales-les-poules-pour-la-saison-2026-2027

**Avertissement de fraîcheur :** certaines pages de clubs peuvent garder des titres de saison ancienne ; les correspondances clubs/divisions doivent être recontrôlées avant publication du mod. Ce relevé est un instantané de sources consultées au 31 octobre 2026, pas une garantie d'effectifs définitifs.

## Travail restant (DATA-02 et au-delà)
1. Effectifs **complets** des 30 équipes avec fiches publiques joueurs, postes, âges, taille, poids, nationalité, minutes ; dédoublonnage avec la source transferts ; distinguer titulaire, espoir, prêt et incertitude.
2. Staffs et centres de formation : fiches officielles clubs, entraîneurs et jeunes publiquement identifiés seulement. Aucune donnée personnelle non publique sur mineurs.
3. Calendrier match par match, stades et capacité sourcée, compétitions fédérales par poule, mécanismes promotion/relégation.
4. Budgets réels uniquement sourcés ; salaires et contrats manquants restent **inconnus**, jamais estimés comme faits.
5. Logos et portraits : seulement un inventaire d'URLs des ayants droit et conditions de réutilisation ; intégrer les fichiers binaires uniquement après autorisation vérifiée.
6. Adapter cet inventaire à un manifeste de mod versionné compatible R2/R4/R5 après validation par l'intégrateur. Ne pas importer directement ce JSON de recherche dans le moteur.

## État des droits
La publication en ligne des noms, scores ou effectifs n'accorde pas automatiquement le droit de réutiliser une base complète, des portraits ou des marques. `distributionStatus: research-only-rights-not-established` évite toute confusion. L'utilisateur pourra contrôler les droits des sources retenues.

Test : `node tests/mod-data01.cjs`; l'exécution et la CI doivent être constatées et non présumées.
