# Renouvellement des joueurs v2 — vérifications Cloud

La politique est décrite dans `superpowers/specs/2026-11-09-player-population-design.md`. Elle ne conserve pas artificiellement les grands effectifs initiaux : elle vise une profondeur qualifiée de 37 professionnels et une population disponible, professionnels plus candidats majeurs, référencée à la création. Les retraites restent effectives.

## Régressions et nouveaux flux

Les neuf tests `player-population.cjs` vérifient l'activation volontaire des anciennes carrières, les diplômés IA et humains de 22 ans, leurs identifiants conservés, les émergences stables du bassin abstrait, la profondeur, les contraintes salariales, le cap du vivier et ses sorties explicites. Ils refusent les identités contradictoires entre marché et stock, les versions/provenances incohérentes et les joueurs actifs dont l'identifiant est déjà retiré. Les mineurs libérés peuvent vieillir dans le stock mais restent absents des propositions et du compte accessible avant 18 ans. L'ordre des clés JSON ne modifie pas la validité.

Le vrai worker couvre export/import/réouverture, refus de corruption à checksum recalculée, échec injecté de publication disque avec carrière et profil inchangés, puis une offre humaine, une contre-proposition, son import et une signature réellement payée avant réouverture. Les sauvegardes v1 ne sont pas activées à leur lecture.

Les suites historiques d'effectifs et de blessures exactes restent explicitement en politique v1 : leurs trajectoires de graine et d'identifiants sont ainsi conservées. La v2 ne consomme plus les tirages consacrés auparavant à neuf profils de marché éphémères par semaine ; comparer leurs blessures exactes à celles d'un nouveau départ v1 n'est donc pas un contrat de cette nouvelle politique.

## Douze saisons du vrai moteur, 14 clubs

`node tests/player-population-seasons.cjs`, graine du harness 827381 : douze saisons achevées en 47 968 ms, 69 signatures IA, 362 promotions/renforts, 259 retraites observées et 253 graduations vers le marché. Les chiffres de retraite sont dédupliqués à partir des identifiants du journal ; la clôture d'une saison précède le vieillissement à sa transition.

| Clôture | Professionnels | Candidats disponibles | Total accessible | Effectifs IA min–max | Export (octets) |
| --- | ---: | ---: | ---: | --- | ---: |
| S1 | 427 | 13 | 440 | 30–32 | 421 693 |
| S5 | 504 | 113 | 617 | 37–37 | 955 653 |
| S10 | 504 | 280 | 784 | 37–37 | 1 523 592 |
| S12 | 504 | 279 | 783 | 37–37 | 1 565 504 |

La référence initiale de cette petite carrière est 440. Cette trajectoire n'est pas une mesure du catalogue Monde de 58 clubs : ses effectifs initiaux sont beaucoup plus petits. Les réouvertures JSON en S5 et S10 conservent exactement l'état. La campagne longue Monde sur SHA figé est une vérification distincte.

## Capacité des sauvegardes sans relever les limites

`node tests/player-population-capacity.cjs` importe dans le vrai worker deux fixtures conservatrices : les effectifs professionnels initiaux complets, le vivier à son plafond et douze lignes d'historique par candidat, avec une copie complète du marché. Elles sont valides pour le schéma ; elles ne prétendent pas représenter douze années jouées. Aucun historique n'a été compacté et les limites existantes restent inchangées.

| Édition | Clubs | Candidats | Historique/candidat | Export (octets) | Limite | Marge |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Monde | 58 | 1 160 | 12 | 10 902 301 | 16 777 216 | 5 874 915 |
| Monde + Champ | 116 | 1 900 | 12 | 20 381 093 | 25 165 824 | 4 784 731 |

Un export hors limite reste un échec explicite du mécanisme existant. Ces fixtures testent le coût du vivier ajouté et ne démontrent pas que tout assemblage possible de tous les historiques et textes au maximum autorisé entre dans un seul fichier.

La réception complémentaire inclut `ai-roster-cycle.cjs` (douze saisons v1), `ai-transfer-competition.cjs`, `world-academy-aging.cjs`, `world-save.cjs`, `world-save-runtime.cjs`, `world-worker-atomic.cjs`, `manager-mobility.cjs` et `native-fiction-sheet.cjs`. Elle ne remplace pas la CI complète d'intégration ni une réception Godot Windows.
