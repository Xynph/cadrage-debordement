# Correctif commun — SDK complet reçu le 12 novembre 2026

Le run SDK complet [43138356742](https://github.com/Xynph/cadrage-debordement/actions/runs/43138356742), tentative 1, est **terminé avec succès** sur le SHA publié et gelé `76077ed3f2af0ff029c8a413fc26451a25ac647f`, branche `cloud/rg27-night-followup-20261112`, événement `workflow_dispatch`, `scope=full`. Root a demandé cette seule campagne après les correctifs ; le présent reçu ne déclenche aucune action.

Les quatre jobs sont verts et les **75 `SDK_RESULT` attendus sont tous présents, réussis et de statut 0**. Le multiensemble des résultats est exactement égal aux cas des deux registres lus depuis l’objet Git 7607 : 56 suites, 74 couples suite/cas distincts, doublon historique Guide/layout-native conservé.

| Job | ID | Cas reçus/réussis |
| --- | ---: | ---: |
| sdk | 130919047467 | 12/12 |
| sdk-portraits-staff | 130919047816 | 20/20 |
| sdk-parcours | 130919047754 | 21/21 |
| sdk-layouts | 130919048035 | 22/22 |

Les matrices P1, hors des 75 résultats de registre, sont également reçues : **4 797/0 et 1 905/0**, puis **trois contrats réussis**. Les [résultats détaillés](evidence/night-followup-sdk-full-20261112/sdk-results-summary.json) et [métadonnées complètes des jobs](evidence/night-followup-sdk-full-20261112/run.json) conservent les variantes, statuts, durées et débuts/fins.

## Cas précédemment rouges

Les quatre cas rouges de la [campagne initiale S](night-common-sdk-initial-20261112.md) réussissent dans cette nouvelle campagne complète, sur sa nouvelle source exacte : staff hire **104/0 en 22 814 ms** ; Night guards **103/0 en 136 192 ms** ; Carnet **4 286/0 en 80 062 ms** ; GestionCarnet **274/0 en 44 835 ms**. Ce constat ne réécrit pas la tentative initiale ni n’établit à lui seul une cause unique à ses deux timeouts.

Les sept variantes Night sont vertes ; les contrôles annoncés sont reading 134, nation 23, guards 103, prospects 70, staff 54, quote 66 et report 47. Le graphique public Analyse/Club/Bureau est vert en **84 665 ms**. Le lecteur historique est reçu en **90 858 ms**.

## Art et silence observé

| Variante Art | Contrôles | Captures annoncées | Échecs | Durée du contrôleur |
| --- | ---: | ---: | ---: | ---: |
| routes-1280 | 224 | 49 | 0 | 70 653 ms |
| routes-1600 | 217 | 46 | 0 | 79 327 ms |
| routes-1920 | 211 | 44 | 0 | 91 909 ms |
| progression | 188 | 7 | 0 | 135 593 ms |
| **Total** | **840** | **146** | **0** | — |

Les [lignes originales de contrôles](evidence/night-followup-sdk-full-20261112/extra-counts.log) sont conservées. Le GD Art de cette source garde ses assertions d’observabilité du vrai guide, demandes/débuts de parole à zéro et absence d’activation de voix ; les quatre recettes les passent. GestionCarnet fournit aussi explicitement `speech_id=0`, `speech_requests=0`, `speech_starts=0` dans son état final. Aucun appel vocal n’est demandé pour fabriquer ce reçu.

Les captures sont celles annoncées par les wrappers réussis ; elles ne sont pas recopiées ni présentées comme inspectées dans ce reçu textuel. Aucun PNG fabriqué ou profil complet de runner n’est ajouté. Ces durées ne qualifient ni animation/FPS, ni Windows, ni un gain causal à checkpoint/seed identique par rapport à un autre run.

## Traçabilité et limites

La [provenance](evidence/night-followup-sdk-full-20261112/provenance.json) contient 25 hashes de fichiers source obtenus avec `git show SHA:chemin` et `git rev-parse SHA:chemin`, les changements hors documentation depuis S et les comptes séparés. Les quatre fichiers `job-*-results.log` sont des extraits originaux horodatés de jobs terminés, obtenus en lecture seule par le connecteur GitHub. [SHA256SUMS](evidence/night-followup-sdk-full-20261112/SHA256SUMS) vérifie les huit fichiers légers.

Aucun registre, workflow, timeout enfant/superviseur/job, limite VM, seed, permission ou budget n’est modifié par cette réception. Le verdict **JavaScript du correctif est celui du run séparé 43138359860** ; ce document n’en anticipe pas le résultat. Le vert JavaScript de S et le vert du main f9c restent des reçus historiques distincts. Aucun merge ou push vers main n’est effectué.
