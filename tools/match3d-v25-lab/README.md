# MATCH 3D V25 — laboratoire distant pour le mode Chat

Réception effective et bilan : [autonomie Chat vérifiée](../../../docs/match3d-v25-chat-autonomy.md).

Branche exclusive : `research/match3d-v25-open-source-tools-20261105`. Aucun gate/fusion. Le lot 24 est uniquement lu au commit `2d8c8c7eee5aa0dad899aa6bb119e95bda0e7987` de PR #300.

## Relancer depuis Chat

1. Lire le HEAD R&D et les derniers messages #73. Réserver les chemins à modifier. Ne jamais éditer PR #300 pour ces essais.
2. Modifier les scripts R&D sous `tools/match3d-v25-lab/remote/`, ou créer un petit fichier daté `remote/requests/<identifiant>.json` (contenu : objet décrivant l'essai). Le push sur la branche R&D déclenche `.github/workflows/match3d-v25-rd.yml`. Le fichier de requête est un déclencheur, pas un programme exécuté. Le SHA testé est le SHA exact du push.
3. Sans changement de code, l'interface GitHub Actions offre `workflow_dispatch` si disponible ; sinon le connecteur Chat peut relancer le job d'une réception terminée, ou créer une nouvelle requête datée. Aucune modification de main n'est nécessaire.
4. Lire les runs filtrés par `head_sha`, puis les jobs et leurs étapes. Attendre leur conclusion avant de parler de succès. Ne pas confondre un ancien run vert avec le nouveau HEAD.
5. Lire les artefacts du run. Télécharger le ZIP `match3d-v25-rd-<HEAD>`, ouvrir `manifest.json`, comparer `head` et `baseline`, vérifier les SHA256 et inspecter les vraies captures. Lire les logs des essais FAIL. Le seul vert du workflow ne signifie pas que tous les outils optionnels sont qualifiés.

Interfaces GitHub accessibles en Chat :

```text
GET /repos/Xynph/cadrage-debordement/actions/runs?head_sha=<HEAD>&per_page=20
GET /repos/Xynph/cadrage-debordement/actions/runs/<RUN>/jobs
GET /repos/Xynph/cadrage-debordement/actions/runs/<RUN>/artifacts
```

Le connecteur fournit `fetch`, `fetch_workflow_run_artifacts`, `download_workflow_artifact`, `fetch_workflow_job_logs`, `rerun_workflow_job`, `create_file` et `update_file`. Les quatre premiers servent à recevoir/inspecter ; les deux derniers permettent la requête de relance, sans shell local ni navigateur graphique obligatoire.

## Commandes exactes sur runner ou poste Linux

Après checkout de la branche R&D, placer un checkout **indépendant** de PR #300 dans `baseline/` au SHA verrouillé. Node 24.11.0, Python 3.12 et dépendances système de Chromium sont préparés par le workflow.

```sh
python tools/match3d-v25-lab/remote/test_audit.py
python tools/match3d-v25-lab/remote/run.py acquire
python tools/match3d-v25-lab/remote/run.py audit
python tools/match3d-v25-lab/remote/run.py tools
python -m pip install playwright==1.57.0
python -m playwright install --with-deps chromium
python tools/match3d-v25-lab/remote/run.py browser
python tools/match3d-v25-lab/remote/run.py finalize
```

`remote/lock.json` contient les commits et versions. Les `package-lock.json` **des sources épinglées** sont utilisés par `npm ci`, jamais un `npm install` libre. `acquisition.json` consigne leurs SHA256, les licences et les assets GLB upstream. Le ZIP Blender est comparé au fichier SHA256 officiel. Le pack CC0 doit être vérifié contre sa première empreinte de réception consignée et verrouillée dans le même manifeste de versions.

## Artefacts et diagnostic

Tout est sous `rd-report/` dans le ZIP :

| Chemin | Contenu |
| --- | --- |
| `manifest.json` | HEAD exact, baseline, version Node/Python, statut de chaque essai, SHA256 de chaque preuve |
| `acquisition.json` | Sources et empreintes des téléchargements, licences, locks et assets |
| `published-auditor.log` | Exécution du véritable auditeur publié V25 sur les 16 GLB |
| `binary-audit.json` | 53 joints, données binaires de peau et matrices, clips, topologie des vrais GLB |
| `baseline-glb/` | Copies CC0 des quatre sources et douze LOD, jamais modifiées |
| `blender.json`, `blender-headless.log` | Import/export corps LOD0/1/2 et registration Rigger |
| `copies/` | GLB de test exportés dans des copies indépendantes |
| `ara-*.log`, `mesh2motion-*.log` | Installation/build/essais ; distinguer chaque statut |
| `*.status.json` | Commande exacte, durée observée, résultat et log associé |
| `match3d-v24-*-report/` | Captures et rapports LOD, contacts, surfaces, 30 rigs, paires SwiftShader |
| `baseline-runtime-report/` | Réception du rendu de match existant et du fallback, séparée du stage V24 |

Un échec d'acquisition : vérifier réseau officiel et checksum, **ne pas remplacer silencieusement une empreinte**. Un échec npm : lire le log et le lock upstream. Un échec Blender : lire version, traceback et registration ; ne pas altérer le rig original pour faire passer le test. Un échec Chromium : examiner les erreurs JS, les requêtes externes bloquées et la capture du dernier scénario. Le verdict `receipt.complete` exige les étapes de la liste `REQUIRED` dans `remote/run.py` : acquisition et manifeste, deux auditeurs, Blender/Rigger, builds/export Ara et Mesh2Motion avec réimportation, cinq scénarios Chromium, offline et rendu de match existant. Un échec requis produit `PARTIAL_OR_FAILED` et un workflow en échec, avec les preuves conservées. Cela ne constitue toujours pas une approbation artistique des résultats. Les tests expérimentaux supplémentaires gardent leur propre statut dans le manifeste.

## Licences et redistribution

- Corps/vêtements lot 24 : CharacterCreator CC0 selon `LICENSE-NOTES.md`, `asset_licenses.json` et manifeste du SHA #300. Les quatre SHA256 source sont revérifiés.
- Mesh2Motion : code MIT, assets/animations CC0 ; les preuves de licence sont acquises au commit verrouillé.
- Ara : MIT, données principales MakeHuman CC0. Les clips dérivés CMU sont utilisables dans un jeu commercial mais ne doivent pas être revendus comme banque autonome. Aucun nouvel achat, modèle IA, API cloud ou téléchargement de poids n'est requis. Les exports de personnage de test restent assortis de ces conditions.
- Blender et Rigger : GPL pour les logiciels ; aucun code GPL n'est intégré au moteur du jeu. Conserver les notices et fournir le code correspondant si ces outils sont redistribués. Les œuvres exportées restent soumises aux droits de leurs données sources.
- MakeHuman : distinguer le logiciel AGPL des données CC0. Aucun modèle à restriction territoriale France/UE ni backend propriétaire n'est utilisé.

## Limites matérielles et conservation

Runner standard `ubuntu-24.04`, **sans GPU matériel demandé**. Les ressources CPU/RAM/disque réellement visibles sont relevées dans les fichiers `runner-*`. Le benchmark est apparié sur SwiftShader avec `gl.finish`, dans une scène isolée ; aucune mesure GPU natif/VRAM ni FPS du match réel n'est revendiquée.

Références officielles : [runners](https://docs.github.com/en/actions/reference/runners/github-hosted-runners), [limites](https://docs.github.com/en/actions/reference/limits), [rétention](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/download-workflow-artifacts). GitHub borne un job hébergé à 6 heures ; celui-ci est limité à 55 minutes. Le dépôt est public : les runners standard publics sont utilisables sans abonnement supplémentaire, sous limites GitHub. Aucun runner GPU payant n'est demandé. Les quotas/règles peuvent évoluer ; ne pas activer de dépassement payant. Les ZIP sont conservés 14 jours (ou moins selon politique du dépôt), **ce ne sont pas des archives permanentes**. Le code et les SHA sont durables ; les preuves expirées doivent être régénérées. Aucun exécutable Blender, node_modules ou dépendance générée n'est committé.

## Ce qui reste à qualifier

L'autonomie d'exécution n'est pas une qualification anatomique. Mesh2Motion doit préserver réellement le rig à l'export ; le test minimal ne constitue pas un ajustement/auto-rig/retarget réussi. Ara génère un personnage alternatif, son CLI n'importe pas un rugbyman canonique existant. Rigger registration et tests synthétiques ne prouvent pas le réglage correct des mains, des poids ou du squelette d'un rugbyman. Le stage 30 rigs V24 reste distinct du runtime du match réel. Les diagnostics de surface sont ceux du HEAD immuable du lot 24 : leurs limites restent visibles, sans correction cosmétique.

Les changements de tests et les corrections par script peuvent être développés en Chat puis exécutés sur Actions. Une retouche artistique à la souris peut rester utile, mais elle n'est pas requise pour relancer les tests préparés. Une mesure GPU Windows native nécessite un poste GPU ou un runner approprié : elle ne peut pas être obtenue par SwiftShader.
