# Audit de réconciliation RugbyData — TOP 14 et PRO D2 (2026-11-02)

> **Statut : audit uniquement — AUCUNE statistique intégrée dans Rugby Réel.** Ne pas fusionner cette PR comme si c'était un import.

## Sources originales vérifiées

- TOP 14 : https://docs.google.com/spreadsheets/d/1CUtwAVQksV7qFMhkLNGL843Q_WkeuiGwPDvmdXugiws/edit
- PRO D2 : https://docs.google.com/spreadsheets/d/1gNq9md0hgzuye_SA8Qk5mzqNREELA_WHM9CnFAFEtes/edit
- Référence BDD DATA V6 : branche `data/rugby-master-v6-bulk-20261102`, `modding/data06/rugby-master-2026-2027.json`. Schéma `rugby-master-sports-v6`, 1 592 joueurs.
- Protocole partagé de coordination : issue #73.

## Audit exécuté sur les deux exports Excel complets

Le parseur local Python (lecture XML XLSX, sans écriture) a inspecté les feuilles des deux classeurs et produit un journal de toutes les observations distinctes, ainsi que leurs motifs d'attente. Les fichiers de travail et le script complet ont été remis à l'utilisateur dans l'archive de l'intervention.

| Compétition | Lignes analysées sur onglets retenus | Empreintes d'observation répétées | Observations distinctes en attente | Signaux de divergence de valeur |
|---|---:|---:|---:|---:|
| TOP 14 | 154 878 | 78 232 | 76 646 | 8 |
| PRO D2 | 31 362 | 10 247 | 21 115 | 598 |
| Total | 186 240 | 88 479 | 97 761 | 606 |

Le comptage de toutes les feuilles (brutes, dérivées et archives) donne 178 301 lignes TOP 14 et 60 434 lignes PRO D2, mais **ces nombres ne doivent pas être additionnés en statistiques distinctes**.

### Contrôles de qualité

- PRO D2 2025-2026 : 11 278 lignes de vue régulière, 1 668 lignes de vue finale, 192 observations joueurs 2024-2025 alternatives vérifiées par lecture.
- `Aperçu général` : 642 cas parmi les observations distinctes TOP 14 et 20 923 cas PRO D2, contexte non reconstitué. Ne pas insérer ces observations sans validation de la rubrique.
- TOP 14 : au moins 61 valeurs non directement numériques (p. ex. `90.24 %`) ; certaines cellules `Unité` ont des contenus incompatibles (`-2.0`). Conserver ces valeurs brutes.
- Les « conflits » ci-dessus sont des signaux de même compétition/saison/phase/sujet/indicateur avec valeurs différentes : pas des conflits prouvés avec la BDD. La rubrique potentiellement ambiguë peut expliquer une partie de ces écarts.
- L'empreinte de doublon ignore le rang et la position de la ligne source ; elle ne prouve donc pas une égalité stricte de toutes les cellules.
- `Tout` et `Phase régulière`/`Phase finale` sont des scopes différents, sans somme implicite. `Feuilles de match` n'est pas `matchs joués`, ni `titularisations`, ni `minutes`.
- Valeurs absentes conservées inconnues ; aucun zéro fabriqué.

## Blocage de l'intégration

Le connecteur GitHub a permis de lire le schéma et la taille du JSON DATA V6 (env. 3 Mo), mais n'a pas livré ce JSON au même système de fichiers que les exports Excel. Le rapprochement exhaustif par identifiants existants n'a donc pas été réalisé. De plus, le chemin DATA est réservé à l'autre développeur selon la coordination #73.

**0 enregistrement ajouté à la BDD ; 0 dédoublonnage BDD attesté ; 0 conflit avec la BDD résolu ; 0 tests du moteur exécutés.**

## Prochaine étape avant import

1. Dans un environnement ayant simultanément accès aux deux exports et au JSON DATA V6 intégral, rapprocher clubs/joueurs par identifiant stable, nom normalisé, club et saison ; bloquer les homonymes.
2. Définir une clé de fait `competition+saison+phase+type+id+indicateur+unité+portée+source` et comparer à l'existant ; consigner les conflits sans écrasement silencieux.
3. Valider le contexte original des rubriques `Aperçu général` ambiguës ; garder les autres en attente.
4. Import idempotent sur branche DATA dédiée **après levée de réservation**, tests d'import répété et sauvegardes, PR distincte, CI officielle et gate avant fusion.
