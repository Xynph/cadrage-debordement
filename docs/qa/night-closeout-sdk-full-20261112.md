# Clôture commune — campagne SDK complète rouge du 12 novembre 2026

Le run [43152464850](https://github.com/Xynph/cadrage-debordement/actions/runs/43152464850), tentative **1**, est **terminé en échec** sur le SHA publié et gelé `1a7b083b8a090d735ef1b08245b5f4faf430f76b`, branche `cloud/rg27-night-closeout-20261112`, événement `workflow_dispatch`, `scope=full`. Il a été demandé une fois par root à 04:05 UTC ; aucune relance, annulation ou modification de source n’est effectuée pour ce reçu.

Les quatre jobs sont terminés : **deux réussis et deux en échec**. Les **76 résultats attendus sont tous présents : 74 réussis, deux rouges**. Leur multiensemble correspond exactement aux deux registres lus depuis les objets Git de ce SHA : **57 suites, 75 couples suite/cas distincts**, doublon historique Guide/layout-native conservé. La couverture complète ne transforme pas ce reçu rouge en qualification globale.

| Job | ID | Cas réussis/reçus | Conclusion |
| --- | ---: | ---: | --- |
| sdk-parcours | 130964651924 | 20/21 | failure |
| sdk-portraits-staff | 130964652175 | 20/21 | failure |
| sdk-layouts | 130964652205 | 22/22 | success |
| sdk | 130964652270 | 12/12 | success |

## Deux échecs conservés

- **Carnet**, `tests/godot-carnet-ui.cjs/default` : statut **1**, **75 128 ms**, résumé **4 666 contrôles / 27 échecs**. Les [27 assertions originales](evidence/night-closeout-sdk-full-20261112/carnet-failures-original.log) sont toutes « Cible et texte utilisables Calendrier » : 26 cibles `CalendarSessionGridLink_<hash>` et une `CalendarSessionDetail_<hash>`. Le stdout conserve `CARNET_SPEECH requested=0 started=0 id=0`. Il s’agit d’échecs de l’assertion géométrique, sans retirer ni assouplir celle-ci dans ce reçu.
- **Night guards**, `tests/rg27-night-navigation.cjs/guards` : statut **null**, **180 007 ms**, erreur exacte `spawnSync /opt/hostedtoolcache/node/22.23.4/x64/bin/node ETIMEDOUT`. L’[extrait original](evidence/night-closeout-sdk-full-20261112/guards-timeout-original.log) ne contient aucun stdout enfant entre l’en-tête de ce cas et le résultat du superviseur. Il ne permet pas de localiser sa phase ni d’affirmer une cause unique, un refus métier ou une erreur de script interne.

Les autres cas ne sont pas substitués à ces échecs. Le nouveau parcours de séance reçoit **146 contrôles / 0 échec**, statut 0, **75 798 ms** ; cette recette ciblée verte coexiste avec les 27 assertions rouges du Carnet complet. GestionCarnet reçoit **274/0**, avec `speech_requests=0`, `speech_starts=0`, `speech_id=0` dans son état final. Les six autres variantes Night sont vertes ; la variante guards n’a aucun total de contrôles reçu dans ce run.

## Contrôles séparés du registre

Le job `sdk` reçoit les matrices P1 **4 942/0** puis **1 905/0** et les **trois contrats réussis**, hors des 76 résultats de registre. Les quatre variantes Art donnent respectivement **224/0, 217/0, 211/0 et 168/0**, avec **49, 46, 44 et 7 captures annoncées**. Ces nombres décrivent cette source et ce passage ; aucune invariance de total avec une ancienne campagne n’est supposée. Les [lignes originales](evidence/night-closeout-sdk-full-20261112/extra-counts.log) sont jointes. Les PNG ne sont ni recopiés ni annoncés inspectés ici.

## Provenance et portée

Les [résultats détaillés](evidence/night-closeout-sdk-full-20261112/sdk-results-summary.json), les [métadonnées run/jobs/étapes](evidence/night-closeout-sdk-full-20261112/run.json) et la [provenance](evidence/night-closeout-sdk-full-20261112/provenance.json) conservent les statuts, variantes, durées, débuts/fins et 32 empreintes source calculées par `git show SHA:chemin` / `git rev-parse SHA:chemin`. Les quatre extraits `job-*-results.log` proviennent des logs terminés du connecteur GitHub ; [SHA256SUMS](evidence/night-closeout-sdk-full-20261112/SHA256SUMS) couvre les fichiers légers.

Le run JavaScript **43152477147** du même SHA reste un reçu indépendant ; son résultat n’est pas anticipé ici. Les campagnes de S37 et de `76077ed3` restent inchangées et ne qualifient pas ce nouveau HEAD. Aucun profil complet, export, log intégral ou asset n’est ajouté. Aucun SDK local, worker, import, changement de seuil, registre, workflow, délai, budget ou permission ; aucune recette Windows, fusion ou publication vers main.
