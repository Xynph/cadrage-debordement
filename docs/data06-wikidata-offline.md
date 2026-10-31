# DATA-06 — Wikidata CC0 : export et import hors ligne

## Export public autorisé

1. Ouvrir https://query.wikidata.org/ avec un navigateur disposant d'Internet.
2. Coller le contenu de `modding/data06/wikidata-rugby-players.rq`.
3. **Vérifier le QID de l'occupation joueur de rugby à XV** dans Wikidata avant exécution.
4. Exécuter, puis télécharger les résultats au format CSV ou JSON (SPARQL Query Results JSON).
5. Conserver le fichier brut, sa date, la provenance et la mention CC0. Ne pas committer automatiquement une archive énorme dans le dépôt.

Commande : `node tools/data06-wikidata-offline.cjs export.csv` (ou `export.json`).
Tests : `node --test tests/data06-wikidata-offline.cjs`.

## Limitations et contrôles

Le catalogue de référence DATA-03 contient 1592 identifiants LNR. Le programme analyse les exports et rapproche les noms, mais **n'attribue JAMAIS un QID à un ID LNR sur la seule égalité de nom** : toute correspondance part en `review` avec ses candidats. Les historiques clubs P54 peuvent être anciens et ne valident pas l'effectif au 01/07/2026. Les valeurs P569 (naissance), P2048 (taille), P2067 (poids), P27 (citoyenneté) sont conservées à titre de preuves candidates mais ne sont PAS importées dans la carrière sans validation d'identité.

**Aucun export réel n'a été obtenu pendant cette livraison** : échecs DNS HTTPS sortant documentés dans l'issue #73. Les tests inclus utilisent uniquement des fixtures synthétiques, donc aucune couverture du catalogue réel par Wikidata n'est annoncée. Les chiffres de matches certains/ambiguïtés demeurent NON MESURÉS sur le vrai export.

Licence : données structurées Wikidata sous CC0 (https://www.wikidata.org/wiki/Wikidata:Licensing). Pas de Firecrawl, pas de lecture réseau par ce programme, ni modification des sauvegardes.
