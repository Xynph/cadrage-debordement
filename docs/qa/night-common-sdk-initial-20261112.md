# SDK commun initial — reçu rouge du 12 novembre 2026

La campagne complète initiale [43129063385](https://github.com/Xynph/cadrage-debordement/actions/runs/43129063385), tentative 1, est **terminée en échec** sur le SHA publié et gelé `37e085b687b4e9a603085beaa50fecf9d6cace22`, branche `cloud/rg27-night-common-20261111`, événement `workflow_dispatch`, demande `scope=full`. Root l’a déclenchée une fois ; aucune annulation ou relance du SDK initial n’est revendiquée.

Les **75 `SDK_RESULT` attendus sont présents : 71 réussis et quatre échecs**, couvrant 56 suites et 74 couples suite/cas distincts. Le doublon historique Guide/layout-native est conservé. Le [résumé JSON](evidence/night-common-sdk-initial-20261112/sdk-results-summary.json) contient chaque suite, variante, durée, statut et erreur ; les [métadonnées du run](evidence/night-common-sdk-initial-20261112/run.json) identifient les jobs et étapes.

| Job | ID | Résultats attendus/reçus | Réussis | Échecs | Verdict |
| --- | ---: | ---: | ---: | ---: | --- |
| sdk | 130888398481 | 12/12 | 12 | 0 | success |
| sdk-portraits-staff | 130888398043 | 20/20 | 18 | 2 | failure |
| sdk-parcours | 130888398450 | 21/21 | 19 | 2 | failure |
| sdk-layouts | 130888398500 | 22/22 | 22 | 0 | success |

Le job historique reçoit aussi les matrices P1 hors registre : **4 797 contrôles / zéro échec**, puis **1 905 / zéro**, et **trois contrats réussis**. Elles ne gonflent pas les 75 résultats de registre. Les quatre variantes Art du candidat commun réussissent : routes-1280 52 561 ms, routes-1600 59 145 ms, routes-1920 70 593 ms, progression 93 798 ms. Ces durées ne constituent pas une comparaison à seed/checkpoint égal avec un autre candidat.

## Les quatre échecs exacts

| Suite et cas | Durée du contrôleur | Constat disponible dans les logs finis |
| --- | ---: | --- |
| `tests/deepen-staff-hire-ui.cjs`, default | 25 621 ms | 89 contrôles, six messages d’échec : « Commande clavier présente » trois fois ; « Choix de durée public » ; « Prolongation préparée trois saisons conservée après fermeture » ; « Prolongation réelle trois saisons sans contrat financier en double ». Statut enfant 1. |
| `tests/rg27-night-navigation.cjs`, guards | 180 074 ms | `spawnSync .../node ETIMEDOUT`, statut enfant null. Aucun stdout/stderr entre l’ouverture du groupe et le résultat ; aucune cause préparation/UI n’est attribuée. |
| `tests/godot-carnet-ui.cjs`, default | 64 970 ms | 4 281 contrôles, un échec : « Cible et texte utilisables Classements CompetitionNextDateLink ». Statut enfant 1. |
| `tests/godot-gestion-carnet.cjs`, default | 180 103 ms | `spawnSync .../node ETIMEDOUT`, statut enfant null. Aucun stdout/stderr intermédiaire ; aucune exception ou cause produit n’est démontrée par ce reçu. |

Les six autres variantes Night réussissent. Le nouveau graphique public Analyse/Club/Bureau réussit en 108 863 ms ; ce succès ne compense pas les quatre cas rouges. Les rapports locaux antérieurs sur d’autres sources ou avec un pilote tracé restent des preuves séparées.

## Provenance et limites

Les [hashes de source](evidence/night-common-sdk-initial-20261112/provenance.json) sont calculés depuis les objets Git du SHA gelé avec `git show SHA:chemin` et `git rev-parse SHA:chemin`, y compris les deux registres, le contrôleur et les quatre couples wrapper/GD concernés. Aucun fichier produit du worktree commun mouvant n’est utilisé comme référence.

Les logs sont des extraits textuels originaux de jobs **terminés**, obtenus en lecture seule par le connecteur GitHub ; leurs timestamps sont conservés. Les blocs complets [staff](evidence/night-common-sdk-initial-20261112/job-130888398043-staff-hire-full.log) et [Carnet](evidence/night-common-sdk-initial-20261112/job-130888398450-carnet-full.log) préservent les assertions. Les fichiers `job-*-results.log` ou `*-counts.log` conservent les résultats des quatre jobs. Le [fichier SHA256SUMS](evidence/night-common-sdk-initial-20261112/SHA256SUMS) vérifie les neuf fichiers légers du reçu.

L’API artifacts n’a retourné aucune archive à l’inspection après les jobs. Aucun profil complet ni PNG n’est archivé ici ; aucun visuel n’est fabriqué. L’absence de traces de timeout empêche un diagnostic causal. Aucun timeout, limite de VM, workflow, registre, paramètre GitHub, seed ou budget n’a été modifié pour cette réception.

La reprise ciblée guards **43134340431**, demandée ensuite une fois par root sur le même SHA S, doit être identifiée et reçue séparément. Son résultat n’est pas inclus dans ce document initial ; même un succès ne transformerait pas cette tentative complète rouge en campagne complète verte. Les CI JavaScript du lot commun et du main ont également leurs propres runs et verdicts.
