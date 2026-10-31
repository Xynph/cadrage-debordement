# DATA-05 — Audit réel du cache et dry-run sans crédits

Après intégration des PR #128 et #132 sur `main`, cette étape ajoute un audit déterministe exécuté sur **les 15 vrais fichiers JSON** présents dans le dépôt, et non sur des fixtures : `node tools/data05-audit.cjs`.

- Reconstitue les 1 592 joueurs DATA-03, contrôle les 240 profils des trois familles DATA-05 : clés LNR uniques, club et URL identiques à DATA-03, sous-totaux 90 + 60 + 90 ;
- Exécute `run({limit:0,budget:0})` du collecteur unifié dans un dossier temporaire, puis vérifie exactement **240 fichiers importés**, zéro appel Firecrawl, zéro collecte HTTP et 240 exportés en JSON ;
- Refuse les écarts et nettoie le dossier temporaire, ne modifie pas les sauvegardes ou le mod fictif ;
- Tests automatiques `node --test tests/data05-audit.cjs` sur les **données réelles du dépôt**. La CI de cette nouvelle PR est nécessaire avant fusion.

Ce mode audit **n'implique pas que les 1 352 pages manquantes aient été téléchargées**. L'accès HTTP direct LNR reste indisponible dans le conteneur producteur ; ne pas contourner 403/429/CAPTCHA. Les 240 profils importés représentent un instantané daté de collecte et ne prouvent pas l'appartenance au 1er juillet 2026. La PR #129 a une CI en échec et ne doit pas être fusionnée automatiquement ; la PR #131 a réussi ses tests mais apporte un collecteur concurrent, à examiner pour abandon au profit du collecteur #132 déjà fusionné.
