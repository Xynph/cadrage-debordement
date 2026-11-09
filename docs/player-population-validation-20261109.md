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

La référence initiale de cette petite carrière est 440. Cette trajectoire n'est pas une mesure du catalogue Monde de 58 clubs : ses effectifs initiaux sont beaucoup plus petits. Les réouvertures JSON en S5 et S10 conservent exactement l'état. La campagne Monde sur SHA figé ci-dessous fournit une vérification distincte de cette petite carrière.

## Capacité des sauvegardes sans relever les limites

`node tests/player-population-capacity.cjs` importe dans le vrai worker deux fixtures conservatrices : les effectifs professionnels initiaux complets, le vivier à son plafond et douze lignes d'historique par candidat, avec une copie complète du marché. Elles sont valides pour le schéma ; elles ne prétendent pas représenter douze années jouées. Aucun historique n'a été compacté et les limites existantes restent inchangées.

| Édition | Clubs | Candidats | Historique/candidat | Export (octets) | Limite | Marge |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Monde | 58 | 1 160 | 12 | 10 902 301 | 16 777 216 | 5 874 915 |
| Monde + Champ | 116 | 1 900 | 12 | 20 381 093 | 25 165 824 | 4 784 731 |

Un export hors limite reste un échec explicite du mécanisme existant. Ces fixtures testent le coût du vivier ajouté et ne démontrent pas que tout assemblage possible de tous les historiques et textes au maximum autorisé entre dans un seul fichier.

La réception complémentaire inclut `ai-roster-cycle.cjs` (douze saisons v1), `ai-transfer-competition.cjs`, `world-academy-aging.cjs`, `world-save.cjs`, `world-save-runtime.cjs`, `world-worker-atomic.cjs`, `manager-mobility.cjs` et `native-fiction-sheet.cjs`. Elle ne remplace pas la CI complète d'intégration ni une réception Godot Windows.


## Monde de 58 clubs : dix saisons sur la production figée

Le reçu versionné `player-population-world-ten-season-20261109.json` porte sur la source **b04d508fd69eebc7d335591ce1760a4f3abce7c5**, le banc `ci/world-ten-season-audit.cjs` inchangé (SHA-256 `77945740f77936422c1df39c845446890c9cb251f5c05139d2552e44280e1a5e`), Node 22.23.4, la graine 827381 et le club humain 0 fixe. Ce run est en mode Monde v1 de 58 clubs, avec le cycle d'effectifs IA v2. Il ne teste pas dix saisons de Monde + Champ ni dix saisons couplées au nouveau cycle du staff.

**Dix saisons uniques sont achevées, avec 7 910 rencontres réelles et 7 910 résultats, 1 231 commandes et neuf transitions de saison.** La population accessible passe de **3 258** à **3 295** (+1,14 %) : elle comprend les professionnels enregistrés, y compris ceux déjà sous contrat avant 18 ans, plus les candidats majeurs réellement présents sur le marché. Les 880 espoirs IA et 61 espoirs humains de S10 sont explicitement exclus de ce total. Les effectifs IA finaux comptent 37–38 professionnels et le club humain 36. Au sein des populations accessibles, 2 082 joueurs sont des regens, dont 1 332 professionnels. Les compteurs de la politique enregistrent 1 120 graduations, 88 émergences du bassin des petits clubs et 1 921 sorties de candidats excédentaires vers ce bassin abstrait.

| Clôture | Professionnels | Candidats majeurs visibles | Total accessible | Export (octets) |
| --- | ---: | ---: | ---: | ---: |
| Départ | 3 208 | 50 | 3 258 | 7 276 845 |
| S1 | 3 233 | 49 | 3 282 | 8 615 644 |
| S2 | 2 892 | 385 | 3 277 | 10 080 504 |
| S3 | 2 623 | 692 | 3 315 | 11 382 243 |
| S4 | 2 391 | 1 013 | 3 404 | 12 710 692 |
| S5 | 2 267 | 1 160 | 3 427 | 12 972 575 |
| S6 | 2 200 | 1 155 | 3 355 | 12 112 578 |
| S7 | 2 162 | 1 152 | 3 314 | 11 159 200 |
| S8 | 2 152 | 1 154 | 3 306 | 10 222 165 |
| S9 | 2 150 | 1 151 | 3 301 | 9 942 526 |
| S10 | 2 147 | 1 148 | 3 295 | 9 727 803 |

Le pic d'export est **12 972 575 octets** en S5, sous la limite inchangée de 16 777 216 octets. Le dernier export mesure **9 727 803 octets**, SHA-256 `e64814c53f2fc5c1bf819fd31b34458ea8c0f39c6fe985dd025a48df8db2ac77`. Les clôtures S5 et S10 sont suivies d'une fermeture et réouverture : l'export entier et le profil privé, curseur RNG et horloge inclus, restent identiques. Le profil final porte le SHA-256 `eaf950f3ea46bea72491c536209cbf526f2d23358e2f53f7cf051d4618c33bbd` ; aucun profil volumineux n'est committé.

### Interruption et reprise explicites

Le premier segment a été interrompu brutalement avec **exit 137** après la clôture S4, pendant des suites locales concurrentes ; le cgroup Cloud a enregistré deux OOM kills. Son rapport est resté marqué `running`, faute de sortie normale : ce segment ne constitue donc pas à lui seul une réussite de dix saisons. Son checkpoint atomique S4W46, phase `ended`, a été conservé avec le reçu correspondant ; le profil de 14 434 570 octets porte le SHA-256 `e3d07774a96c43b319a276308d61a616130d0c7df54086767715778664419413`.

Après arrêt des charges concurrentes, le banc a repris ce checkpoint sur le même SHA et avec le même hash de banc. Il a prouvé `stateIdentical=true` et `privateProfileIdentical=true` avant toute nouvelle simulation. Le hash de l'export à cette frontière est `8efc596d73a46fcafb81e2015413496fcac493ab0ea8f5b71c3810fae895fd3e`. Les quatre bilans antérieurs ont été conservés et les six saisons restantes exécutées ; S4 n'a pas été recomptée. Le second segment se termine avec **exit 0**, `status=completed`, `passed=true` et les saisons uniques 1 à 10. Le temps cumulé enregistré par le banc est 1 275 079 ms, hors délai entre les deux segments. Le reçu JSON conserve les segments, la reprise, les deux réouvertures et les signatures des fichiers bruts.

### Stress complémentaire des profils source

Une seconde variante de capacité remplit le vivier de **vrais profils source majeurs libérés**, avec leurs attributs et références d'origine, retirés de leurs effectifs pour respecter la propriété unique. Chaque candidat conserve douze lignes d'historique, et le marché en porte une copie complète. L'import du vrai worker réussit :

| Édition | Candidats source | Export (octets) | Limite | Marge |
| --- | ---: | ---: | ---: | ---: |
| Monde 58 clubs | 1 160 | 12 057 585 | 16 777 216 | 4 719 631 |
| Monde + Champ 116 clubs | 1 900 | 22 590 929 | 25 165 824 | 2 574 895 |

Ces variantes sont des fixtures de capacité valides pour le schéma, sans revendiquer des années jouées ni une réception du staff couplé. Aucune compaction d'historique ni hausse de plafond n'a été nécessaire.

La trajectoire longue reste limitée à une graine et un club humain fixe, sans entraînement, investissement, recrutement ou renouvellement humain ajouté par le banc ; les promotions de couverture nécessaires pour continuer les matchs sont consignées. L'équilibrage financier global, d'autres graines, Monde + Champ à long terme, le staff couplé et la réception visuelle Godot relèvent de validations distinctes. La CI d'intégration sera référencée par l'intégrateur.
