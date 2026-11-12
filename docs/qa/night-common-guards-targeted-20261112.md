# Guards — reprise ciblée stricte du 12 novembre 2026

La reprise [43134340431](https://github.com/Xynph/cadrage-debordement/actions/runs/43134340431), job `sdk-targeted` **130905913641**, tentative 1, est **terminée avec succès** sur le SHA exact `37e085b687b4e9a603085beaa50fecf9d6cace22`, branche `cloud/rg27-night-common-20261111`, événement `workflow_dispatch`.

Root a demandé ce seul cas après la fin de la campagne initiale : `scope=targeted`, suite `tests/rg27-night-navigation.cjs`, variante `guards`. Le [log terminé](evidence/night-common-guards-targeted-20261112/job-results.log) confirme ces trois sélecteurs et **un `SDK_RESULT` réussi, statut 0, 109 631 ms, 103 contrôles et zéro échec**. Les [métadonnées](evidence/night-common-guards-targeted-20261112/run.json), [hashes de source](evidence/night-common-guards-targeted-20261112/provenance.json) calculés depuis les objets Git S et [sommes des trois fichiers](evidence/night-common-guards-targeted-20261112/SHA256SUMS) accompagnent ce reçu léger.

Le wrapper et le GD sont ceux du SHA strict publié ; le pilote local tracé n’y est pas ajouté. Les gardes et assertions restent celles de cette source. Aucun profil complet ou PNG n’est archivé ici. Aucun lancement supplémentaire, annulation, augmentation de délai ou modification de configuration n’est effectué pour cette documentation.

La campagne initiale [75 cas / 71 réussis / quatre échecs](night-common-sdk-initial-20261112.md) reste rouge. Ce succès ciblé ne démontre pas la cause du timeout initial de guards et ne constitue pas une nouvelle campagne complète verte ; les trois autres échecs initiaux restent à traiter séparément.
