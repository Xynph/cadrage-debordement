# Procédure de reprise de l'import TOP 14 / PRO D2

**Ne pas déclarer d'intégration avant une vérification du fichier JSON résultant.** L'outil est conservateur, sans écriture sur le JSON source.

## Exports originaux

- TOP14 : https://docs.google.com/spreadsheets/d/1CUtwAVQksV7qFMhkLNGL843Q_WkeuiGwPDvmdXugiws/edit
- PRO D2 : https://docs.google.com/spreadsheets/d/1gNq9md0hgzuye_SA8Qk5mzqNREELA_WHM9CnFAFEtes/edit
- BDD : `modding/data06/rugby-master-2026-2027.json` depuis branche DATA V6, non modifiée par cette PR.

L'archive d'audit remise à l'utilisateur contient `stage_exports.py` et `audit/pending.ndjson` (97 761 observations distinctes). **Ce dépôt ne contient pas les exports XLSX ni l'archive volumineuse.**

## Utilisation

1. Copier la BDD JSON **complète** et les exports XLSX sur la machine disposant de Node.
2. Utiliser le staging existant ou reconstruire `pending.ndjson` avec `stage_exports.py`.
3. Fournir `mapping.json` au format `mapping.template.json`, uniquement avec des correspondances vérifiées : chaque `clubAliases` contient `competition`, `season`, `source`, `clubId`, `evidenceUrl`. Chaque `verifiedMembership` contient `playerId`, `clubId`, `season`, `evidenceUrl`.
4. Exécuter :

```bash
node --test tools/rugby-import-audit/import_into_v6.test.mjs
node tools/rugby-import-audit/import_into_v6.mjs \
  --db rugby-master-2026-2027.json \
  --input pending.ndjson \
  --mapping mapping.json \
  --out rugby-master-2026-2027.import.json \
  --report import-report.json
```

5. Rejouer sur le fichier produit en utilisant **un autre chemin de sortie** : vérifier `added=0` et égalité des observations.
6. Contrôler les périodes/identifiants, sauvegardes et CI avant une PR DATA dédiée et éventuelle fusion.

## Gardes

- `Aperçu général` refusé tant que le sens original de la rubrique n'est pas prouvé.
- Joueur : nom unique dans sa compétition **et** affiliation club+saison vérifiée explicitement ; pas de rapprochement hasardeux sur le seul nom.
- Club : alias explicite sourcé et lié à la saison.
- Pas de fusion de phases `Tout`, `Régulière`, `Finale`. Les statistiques de feuilles de match ne sont pas renommées matchs joués.
- Aucun écrasement de `performance2025_2026` ou d'anciennes observations ; divergences reportées.
- Zéro observé conservé, valeur manquante mise en attente.
- Import dans la BDD existante sous `rugbyDataObservations`, jamais une deuxième BDD ni une réécriture du fichier source.

## Exécution du 2 novembre 2026

L'outil local de la même logique a réussi 5 tests unitaires sur données synthétiques, et relu **97 761** observations du staging avec manifeste vide / BDD factice : **0 ajout ; 97 761 en attente** (TOP14 76 646, PRO D2 21 115). Ceci **ne constitue PAS un test sur la BDD réelle**, ni un import. Aucune mutation de `modding/data06`.
