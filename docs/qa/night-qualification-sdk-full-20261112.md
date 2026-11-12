# Qualification finale — SDK complet reçu le 12 novembre 2026

Le run [43157636998](https://github.com/Xynph/cadrage-debordement/actions/runs/43157636998), tentative **1**, est **terminé avec succès : quatre jobs verts**, sur le SHA exact `ec0044ea99e22aeaad29751ccde1279c1699b577`, branche `cloud/rg27-night-qualification-20261112`, événement `workflow_dispatch`, `scope=full`. Root a demandé cette campagne une fois à 04:52 UTC ; aucune relance, annulation ou modification de source n’est effectuée pour ce reçu.

Les **76 résultats SDK sont présents, réussis et de statut 0**. Leur multiensemble correspond exactement aux deux registres lus depuis les objets Git de ce SHA : **57 suites, 75 couples suite/cas distincts**, doublon historique Guide/layout-native conservé.

| Job | ID | Cas réussis/reçus | Conclusion |
| --- | ---: | ---: | --- |
| sdk-portraits-staff | 130981171153 | 21/21 | success |
| sdk-parcours | 130981171394 | 21/21 | success |
| sdk-layouts | 130981171431 | 22/22 | success |
| sdk | 130981171457 | 12/12 | success |

## Cas reçus et ancien rouge préservé

Le Carnet complet reçoit **4 670 contrôles / 0 échec**, en **49 316 ms** ; ses compteurs stdout sont `requested=0 started=0 id=0`. Night guards reçoit **112/0**, en **55 868 ms** ; le nouveau parcours de séance reçoit **146/0**, en **46 195 ms**. Les sept variantes Night ont chacune leur résultat de statut 0. Les totaux de contrôles sont ceux effectivement observés, pas des seuils imposés à des assertions dépendantes du contexte rendu. Le GD et le wrapper exacts conservent les contrôles vocaux et les champs de rapport ; aucun résultat local 112/99 ou 4672/4726 n’est substitué au compte CI.

La [campagne complète antérieure sur `1a7b083b`](night-closeout-sdk-full-20261112.md) reste **rouge, 74/76** : Carnet et Night guards n’y sont pas requalifiés. Le présent succès sur une nouvelle source n’établit pas, à lui seul, une cause unique au précédent timeout ni un gain causal de performance.

GestionCarnet reçoit **274/0** avec `speech_requests=0`, `speech_starts=0`, `speech_id=0` dans son état final. Les quatre variantes Art impriment **224/0, 217/0, 211/0 et 175/0**, soit **827 contrôles**, avec respectivement **49, 46, 44 et 7 captures annoncées** (146). Les comptes locaux et ceux des anciennes campagnes restent distincts. Les [lignes originales](evidence/night-qualification-sdk-full-20261112/extra-counts.log) sont conservées ; les captures annoncées ne sont ni recopiées ni présentées comme inspectées ici.

## Matrices et traçabilité

Hors des 76 résultats de registre, le job `sdk` reçoit les matrices P1 **4 942/0** et **1 905/0**, puis les **trois contrats réussis**. Les [résultats détaillés](evidence/night-qualification-sdk-full-20261112/sdk-results-summary.json) et [métadonnées des quatre jobs et étapes](evidence/night-qualification-sdk-full-20261112/run.json) conservent variantes, statuts, durées et débuts/fins.

La [provenance](evidence/night-qualification-sdk-full-20261112/provenance.json) conserve les empreintes de 34 fichiers source obtenues avec `git show SHA:chemin` et `git rev-parse SHA:chemin`, ainsi que le delta hors documentation exact depuis `1a7b083b` : `month_calendar.gd`, `rg27-night-navigation.cjs`, `rg27-night-navigation.gd`. Les quatre fichiers `job-*-results.log` sont des extraits originaux horodatés de jobs terminés, lus par le connecteur GitHub. [SHA256SUMS](evidence/night-qualification-sdk-full-20261112/SHA256SUMS) vérifie les fichiers légers.

Le verdict JavaScript du même SHA appartient au run séparé **43157653421** ; il n’est pas anticipé ici. Aucun ancien vert ne qualifie une autre source. Ce reçu ne modifie aucun registre, workflow, timeout, limite VM, seed, permission ou budget. Aucun profil, export, log intégral ou PNG récupéré, SDK local, import, worker ou recette Windows ; aucune fusion ou publication vers main.
