# DATA-05 — CLI unifié, imports des profils existants et coût maîtrisé

`tools/data05-unified.cjs` consolide la récupération directe et le secours Firecrawl. Il charge les 4 JSON DATA-03 (30 clubs, 1 592 IDs), dédoublonne les URLs, **importe trois familles de lots** (`data05-bulk`, `data05-bulk2`, `data05-bulk3` : potentiellement **240 profils sans nouvelle facturation**), écrit un cache atomique par ID, évite le re-téléchargement, exporte `players.json` et `report.json`. Le budget Firecrawl est un **maximum d'appels** et non une garantie de coût identique.

## Lancement local Node 22+
Depuis la racine du dépôt, après vérification des conditions d'accès de la LNR et de robots.txt :

```bash
node --test tests/data05-unified.cjs
node tools/data05-unified.cjs --limit 10 --budget 0 --concurrency 2 --delay-ms 1000
# Secours Firecrawl autorisé après examen des crédits :
FIRECRAWL_API_KEY=... node tools/data05-unified.cjs --limit 50 --budget 15 --concurrency 2
```

Par défaut, **10 candidats au maximum, zéro crédit payant** ; `--limit 0` vérifie/import seulement le cache existant sans requête externe. Lancer `--limit 1592` ne doit se faire qu'après contrôle effectif de l'accès légal et technique aux pages LNR et du nombre de crédits. Le conteneur actuel ne peut pas contacter directement `top14.lnr.fr` : aucune collecte gratuite de 1 352 pages n'est revendiquée.

## Dépendance bloquante : PR #128
Sur `main` contrôlé le 31/10/2026, les fichiers `modding/data05-bulk3/profiles-01..05.json` de la PR #128 ne sont **pas fusionnés**. L'importeur exige, volontairement, la présence des 15 fichiers historiques et échoue avec `Missing input` tant que le contenu #128 n'est pas intégré dans le checkout. **Il ne suffit pas d'avoir la branche #128 distante**. Après sa fusion réussie par l'intégrateur, le même programme importera les 240 profils si leurs IDs, URLs et clubs correspondent au catalogue. Ni chiffre importé en production, ni campagne intégrale ne doivent être déclarés avant exécution réelle.

## Qualité, limites
Les trois formes des historiques sont normalisées ; naissance exacte = null, appartenance au 01/07/2026 = false/non vérifiée. Les pages HTML sans nom et âge sont incomplètes : seulement alors, avec clé et budget positif, le secours Firecrawl s'applique. L'absence de poste/nationalité sur un nouvel HTML est conservée null, jamais inventée. Ce collecteur n'intègre **aucune stratégie de contournement** des restrictions 403/429/CAPTCHA, ni garantie de fonctionnement sur site rendu côté client. 2 requêtes concurrentes par défaut (max 4), pause 1 s après chaque tâche. Les tests mockés n'établissent pas l'accès HTTP live.

**CI PR #129 actuellement en échec**, CI #131 SUCCESS. Nouvelle PR distincte pour isoler les corrections, sans fusion ni modification `dist/**`. Vérifier la CI de cette PR et les validations de l'intégrateur.
