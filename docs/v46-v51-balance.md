# Banc d'essai V46–V51 — équilibre statistique

Le test `node tests/v46-v51-balance.cjs` lance 20 graines × 15 saisons × 14 clubs = **4 200 clubs-saisons**, et reproduit intégralement la campagne pour détecter le non-déterminisme.

Indicateurs : concentration des titres, champions différents, clubs-saisons déficitaires ou sous restriction, investissements réellement payés, événements d'infrastructure et confiance moyenne des entraîneurs en fin de carrière.

Il vérifie les invariants de données sans imposer de seuils arbitraires de « réalisme ». Des profils initiaux fictifs et l'absence de véritables matchs limitent fortement les conclusions. La confiance finale n'est **pas** un taux de licenciement ; aucun chiffre d'entraîneurs remplacés ne peut en être déduit.

Option : `CD_BENCH_REPORT=bench.json node tests/v46-v51-balance.cjs`. Le rapport JSON peut être archivé en artefact CI pour comparer les changements futurs. Aucun fichier de sauvegarde du jeu n'est modifié.
