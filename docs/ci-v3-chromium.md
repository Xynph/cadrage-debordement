# CI V3 — réceptions Chromium UI mutualisées (02/11/2026)

## Référence réelle avant modification
Sur le **même commit de PR** `7964ab962d49590af615738231590e41da6162f3` le 01/11/2026, l'API GitHub Actions montre quatre jobs réussis :

| Workflow | Run GitHub | Durée job | Installation Playwright 1.57/Chromium |
| --- | --- | ---: | ---: |
| UI01 (navigation, contraste, menu) | [#41346182859](https://github.com/Xynph/cadrage-debordement/actions/runs/41346182859) | 46 s | 17 s |
| UI02 (fiches et tableaux) | [#41346182759](https://github.com/Xynph/cadrage-debordement/actions/runs/41346182759) | 28 s | 16 s |
| Centres natifs (recrutement et formation) | [#41346182871](https://github.com/Xynph/cadrage-debordement/actions/runs/41346182871) | 30 s | 21 s |
| V4 Premium (thèmes, largeurs, sauvegardes) | [#41346182763](https://github.com/Xynph/cadrage-debordement/actions/runs/41346182763) | 94 s | 20 s |
| **Total** | **4 jobs** | **198 s** | **74 s** |

Ces durées correspondent à `started_at`→`completed_at` (jobs et étapes), pas aux minutes facturées arrondies. Les quatre jobs s'exécutaient en parallèle : **198 s n'est pas le délai d'attente mural**.

## Architecture V3
Le nouveau `.github/workflows/ui-browser-consolidated.yml` regroupe ces **7 mêmes scripts Python** en un job, une installation Chromium/Playwright 1.57. Anciennes définitions disponibles par `workflow_dispatch` pour les diagnostics séparés ; aucun test supprimé. Sur `dist/index.html`, tous les sept parcours s'exécutent.

Le sélecteur déterministe `ci/ui-browser-selector.cjs` déclenche les familles selon les filtres historiques. Toute modification de `dist/**` conserve **les deux scripts Premium V4**, dont les sauvegardes, même si les autres parcours ne sont pas concernés. Modification de `dist/index.html`, du sélecteur, du nouveau workflow, diff inconnu, malformé ou absent : exécution de tous les sept scripts. Un autre `dist/ui*` active aussi UI01 ; `dist/ui02-*.js/css` active UI02, `dist/ui03-*` et `dist/ui04-*` activent les centres. Suite de tests `tests/ci-ui-browser-selector.cjs` intégrée au workflow et à la CI JavaScript existante.

**Préservation du push** : UI01 était déclenché en PR et en push sur `main` et `integration/ui01-reviewed`. Le nouveau workflow a les mêmes chemins push et n'exécute que ses trois scripts UI01 sur push. Les anciens noms de workflows restent lancables manuellement. Concurrence bornée sur les anciennes têtes PR ; pas d'annulation des push `main`.

Les scripts passent individuellement, les échecs sont accumulés puis font échouer le job ; les captures UI01, UI02 et preuves Premium conservent leurs noms et rétention 7 jours. V4.9 reste séparé car Playwright 1.58.

## Mesure après publication
Comparer la durée **réelle du job V3 complet exécutant les sept scripts sur le HEAD de sa PR** à la référence 198 s, puis l'étape d'installation unique aux 74 s historiques. Le gain observé dépend des runners et des contenus de branche : ne pas garantir un pourcentage ni confondre minutes runners et attente murale ; la séquentialisation des sept tests peut rallonger le délai critique par rapport aux anciens jobs parallèles. Aucun changement du jeu, des sauvegardes, du gate, des contrôles JavaScript requis ou des protections de `main`. Une seule PR sans fusion ; accord explicite requis avant intégration et CI post-fusion 7/7.
