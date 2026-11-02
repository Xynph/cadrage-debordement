# DATA-05 — Collecteur automatisé LNR / Firecrawl

## Source et utilisation

`tools/data05-collect.cjs` lit exactement les quatre fichiers de base `modding/data03/{top14-a,top14-b,prod2-a,prod2-b}.json` : **30 clubs, 1 592 IDs LNR uniques**. L'outil n'interroge aucune image et ne crée aucun faux attribut absent des sources.

Prérequis Node >=18 ; un compte Firecrawl et une clé `FIRECRAWL_API_KEY` passée **uniquement par variable d'environnement** (ne jamais la committer).

```bash
FIRECRAWL_API_KEY=... node tools/data05-collect.cjs --input modding/data03 --output modding/data05-collector/results --concurrency 4 --limit 10 --budget 15
```

Après validation d'un échantillon, le même lancement sans `--limit` poursuit la collecte. **Ne pas enlever le plafond `--budget` sans vérifier les crédits restants.** Le paramètre `--budget` limite les *appels tentés*, et non le montant facturé (le coût par appel est fixé par Firecrawl). Les reprises sont plafonnées à deux par profil ; le quota s'applique également à ces tentatives. Parallélisme configurable **1 à 8**, 4 par défaut.

Chaque joueur vérifié est écrit dans `results/cache/lnr-<id>.json` par écriture atomique ; une relance utilise ces fichiers et ne les redemande pas. Sorties : `results/profiles.json` (enregistrements réussis), `results/report.json` (réussites, erreurs, manquants). Si une fiche ne fournit pas nom/groupe de poste/nationalité/âge, elle n'est pas enregistrée et figure dans les erreurs. Date de naissance exacte et appartenance historique au 01/07/2026 restent explicitement inconnues. Ne pas diffuser les photos/emblèmes LNR.

## Budget au 31 octobre 2026

**749 crédits Firecrawl** disponibles au contrôle préalable. Les 1 352 profils non approfondis dépasseraient ce nombre au coût hypothétique d'un crédit par page, sans retries. **Collecte massive volontairement non lancée** : contrôle budget nécessaire. On peut commencer par `--limit 10 --budget 15` et poursuivre jusqu'au seuil autorisé. Le programme est autonome sur toute la liste et peut reprendre automatiquement.

## Tests

`node --test tests/data05-collector.cjs` : extraction exacte sur page-test, cache/reprise (un seul appel), budget 0, validation et champs historiques inconnus. Pour le test en situation réelle, une clé Firecrawl accessible au processus Node est requise ; les appels aux outils Firecrawl de cette conversation ne sont pas une preuve que le script Node a exécuté son appel API HTTP.

**Limite actuelle :** le cache propre à ce collecteur n'importe pas automatiquement les PR DATA-05 précédentes. Ne pas considérer 240 profils déjà consultés comme un cache préexistant du nouveau script ; prévoir reprise/migration des lots antérieurs avant collecte massive.

Aucune modification `dist/**`, moteur, sauvegarde, modèles fictifs, ou données historiques effectuée. Intégrateur uniquement pour contrôle et fusion de la PR.
