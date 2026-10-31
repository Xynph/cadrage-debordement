# DATA-06 — Revue hors ligne des transferts non rapprochés

Module autonome de triage pour les **46 cas non résolus** dans la PR #142 (12 identités dans un autre club, 34 absentes du catalogue exact). Il prend un fichier de réconciliation fourni explicitement et recherche des **candidats approximatifs** parmi les 1592 IDs du roster officiel enregistré. La distance textuelle ne prouve ni identité, ni mutation, ni club à une date donnée.

Usage après récupération explicite du JSON de #142 : `node tools/data06-triage.cjs chemin/vers/transfer-reconciliation-2026-2027.json`. La sortie liste des candidats jusqu'à distance 3 mais laisse **tous** les cas en revue humaine (`linkedId:null`, `autoImported:false`). Aucun accès réseau, aucune écriture dans le catalogue, aucune modification de sauvegardes. Nécessite ensuite une preuve nominative officielle datée et un contrôle du club avant de résoudre l'identité.

Tests : `node --test tests/data06-triage.cjs`. Ne pas fusionner avant contrôle CI sur le HEAD exact. Cette PR indépendante ne réécrit pas les 80 mutations ni les 1592 joueurs.
