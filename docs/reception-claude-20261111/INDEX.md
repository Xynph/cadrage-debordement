# Verdicts de réception des candidats Claude

Dernier relevé GitHub du 11 novembre 2026 : `main` reste
`96f537040bf9f2e37bf10b0a9b09518b732244a2`. Les têtes ci-dessous sont celles
vérifiées à la clôture ; les reçus des anciennes têtes restent archivés.
Aucune fusion, activation générale ou modification
des sujets réservés n'a été effectuée.

| Candidat | Tête examinée | Verdict | Preuve et limite |
| --- | --- | --- | --- |
| [#555 — touche](https://github.com/Xynph/cadrage-debordement/pull/555) | `eb426d83` | **Reçu** | [80 matchs et six suites](555-touche.md) ; état persistant et RNG identiques. Confort du rendu non qualifié. |
| [#558 — packs pendant un rendez-vous](https://github.com/Xynph/cadrage-debordement/pull/558) | `dd094c17` | **Reçu** | [API et scénario complémentaire](558-packs-rendez-vous.md) ; rendez-vous et RNG conservés. Explication documentaire sur les citations à corriger. |
| [#553 — journalistes inventés](https://github.com/Xynph/cadrage-debordement/pull/553) | `e8bbc5ef` | **À corriger** | [Défaut reproduit](553-journalistes.md) : le pack réécrit des questions et réponses archivées dans leur projection à l'écran. |
| [#573 — calendrier](https://github.com/Xynph/cadrage-debordement/pull/573) | `d88dc4db` | **À corriger** | [Recette et comparaison](573-calendar-final.md) : alternance et reprise fonctionnelles, mais `france-saves` échoue deux fois sur la limite VM de 15 s ; le même fichier passe sur main96. |
| [#552 — salaires et budgets](https://github.com/Xynph/cadrage-debordement/pull/552) | `56661930` | **À corriger** | [Nouvelle reprise reproduite](552-refresh-final.md) : le premier snapshot perd toujours le budget et le plancher projetés. Le raccord de main ne corrige pas ce défaut. |
| [#554 — gestes du match](https://github.com/Xynph/cadrage-debordement/pull/554) | `a244814e` | **Reçu comme expérience OFF par défaut** | [129 contrôles Godot](554-gestes-actualisation.md), setter OFF/ON ; pas de recette de fluidité ni Windows. |
| [#550 — socle Effectif](https://github.com/Xynph/cadrage-debordement/pull/550) | `44b67211` | **Reçu comme expérience OFF par défaut** | [34 contrôles par taille 720/1080](../experimental-flags-review-20261111.md), ancien écran et profil préservés OFF ; Windows non qualifié. |

Les constats « à corriger » ont leurs sondes et résultats durables ; ils ne sont
pas des corrections effectuées dans la production de Claude. Les réceptions
Linux ne valent pas exécution de l'EXE Windows. La chaîne Windows actuelle
retire les drapeaux expérimentaux : un paquet lancé ainsi ne prouverait pas le
fonctionnement ON. Ce point reste une limite explicite de réception.

Le [mapping de sélection CI de la touche, #557](https://github.com/Xynph/cadrage-debordement/pull/557)
est proposé séparément et dépend de #555. Le remplacement des fausses fixtures
historiques reste [bloqué par l'absence d'un export authentique compatible](p4-fixtures-historiques.md) :
la vraie sauvegarde publiée trouvée est France30/S2, le scénario demandé
Monde58/S1. Aucun export récent modifié n'est présenté comme une ancienne
sauvegarde livrée.
