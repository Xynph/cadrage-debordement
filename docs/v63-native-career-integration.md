# V63 — Validation native hors match, reprise et finances

## Portee reelle

Ce lot lance les scripts originaux du jeu depuis `tests/harness.cjs` : `game.js`, `career-integration.js`, `world-career.js`, `saves.js`, leurs dependances, et une vraie journee simulee par le moteur. Il ne se contente pas d'analyser les sources.

Scenarios : activation des systemes natifs, export/import du document de sauvegarde, offre d'investissement, depense dans la tresorerie et refus d'un second investissement, historique, tableaux de bord purs, reprise du monde, sauvegarde ancienne sans monde, corruption de reputation refusee, resultats des 7 vrais matchs et controle du registre financier.

## Compatibilite et limites

Le harness emule un navigateur et stocke les donnees en memoire ; **aucune sauvegarde utilisateur ni aucun fichier de jeu n'est modifie**. Les tests ne constituent pas une validation Windows ni une activation des nouvelles PR V58–V61. Ils couvrent les mecanismes actuels de main, pas les interfaces candidates.

Les PR #60 a #63 proposent un second cycle de vie des entraineurs : ne raccorder qu'aux postes et au marche de V48 deja actifs. Les PR #64, #66 et #67 exigent un calendrier et des resultats reels. La PR #68 ne doit pas dupliquer la confiance de la direction V42. La PR #65 sur les effectifs est un chantier distinct.

**Integration recommandee** : faire auditer ce jeu de tests natifs par l'integrateur, puis raccorder un seul systeme candidat a la fois et rejouer ce banc avant/apres, y compris sur d'anciens exports et plusieurs saisons. Aucune fusion ici.
