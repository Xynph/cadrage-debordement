# Qualité des staffs et contrats de départ — audit Cloud du 9 novembre 2026

L’outil `ci/staff-contract-quality-audit.cjs` audite les cinq éditions anonymisées du monde et leur staff, en lecture seule. Il ne collecte aucune nouvelle donnée, ne vérifie pas les pièces privées du PC et ne prétend pas certifier des fonctions actuelles ou des échéances réelles.

## Exécution et API

```bash
node ci/staff-contract-quality-audit.cjs > /tmp/staff-contract-quality.json
node --test tests/staff-contract-quality-audit.cjs
```

La commande écrit uniquement le JSON sur stdout. Code de sortie 0 lorsque le contrôle complet est valide, 1 en présence d’erreurs, d’une applicabilité inconnue ou d’un échec du chargement des entrées. Les avertissements ne font pas échouer le contrôle. Aucun timestamp d’exécution, chemin local, nom de personne, libellé de fonction ni URL brute n’est incorporé au rapport. Les exemples utilisent seulement les IDs opaques des catalogues et des numéros de club. Les erreurs du chargeur sont volontairement réduites à un code stable afin de ne pas exposer une donnée source dans un message d’exception.

Exports utilisables depuis un autre outil :

- `loadProductionInputs(root?)` charge les JSON et utilise les **builders de production** `world-pacific-registry.cjs`, `createWorldEditions` et `staff.forDatabase`. Les profils français sont résolus depuis l’export embarqué `dist/rugby-roster-foundation.js` ; ils ne sont pas traités comme des données manquantes parce qu’ils ne figurent pas dans `worldProfiles`.
- `auditEdition({edition, staffRegistry, foundation?, opening?})` est un validateur pur de fixtures ou de catalogues chargés.
- `auditAll(inputs)` renvoie le rapport `staff-contract-quality-v1`, dont `valid` et `privateEvidenceVerified:false`.

Le rapport est déterministe à entrées identiques. Les éditions sont cumulatives : **ne pas additionner leurs nombres de joueurs ou staffs comme des individus distincts**.

## Ce qui est contrôlé

Erreurs certaines : identifiants mal formés ou dupliqués, club ou profil orphelin, appartenance explicite contradictoire, rôle vide ou de type invalide, dates ou références de forme invalide, incohérence année/saison d’échéance, décalage entre échéance d’un profil étranger et valeur du joueur source, source française référencée absente du dictionnaire embarqué, override sans joueur ou mauvais club, terme d’ouverture invalide, alias manquant, chaîne/cycle d’alias et terme d’ouverture qui réintroduirait une entrée inactive.

Le registre d’ouverture ne s’applique qu’à l’édition Champ v5. Le rapport donne `opening.status` (`available`, `not-applicable`, `missing`, `invalid` ou `unknown`) et `opening.applies` (booléen, ou `null` si la politique n’est pas déterminable). Les autres éditions connues signalent explicitement `not-applicable` ; un fichier absent n’est jamais assimilé à cette non-applicabilité.

Dans l’API pure, une v5 sans registre donne `status: 'unknown'`, `valid: false`, un avertissement `opening-register-missing`, et des compteurs d’actifs prospectifs, d’alias et d’overrides à `null`, globalement et par club pour les actifs. Un registre partiel ou contradictoire produit une erreur et les mêmes compteurs non vérifiés ; il ne devient pas une preuve de zéro alias. Le nombre d’IDs du catalogue reste connu. Le chargeur CLI exige toujours le fichier de production : son absence donne le code de sortie 1 et un rapport expurgé.

Les liens d’identité/version/mode entre édition, registre et marqueur sont contrôlés lorsque ces champs sont présents. Une version d’édition 4 liée à un registre 5 est une contradiction, pas une raison d’ignorer silencieusement la politique d’ouverture ; l’applicabilité et les compteurs dérivés deviennent non vérifiés. L’outil garde les six IDs historiques dans le catalogue et calcule leur exclusion prospective de la nouvelle carrière suivant la politique existante. Un alias dont le canonique est dans un autre club est accepté et compté : le transfert documentaire déjà reçu n’est pas pris à tort pour une erreur d’appartenance. Les bornes minimales ne remplacent pas une échéance existante plus longue.

Les fonctions de staff restent des **descriptions libres multilingues**, pas une nomenclature réglementaire fermée. La couverture par club donne nombre de fiches, nombre de rôles renseignés, nombre de libellés distincts, fiches historiques et sources ayant une date ou une saison. Aucun minimum de postes, aucune licence de coach ni fonction actuelle n’est inventé. Les dates ISO civiles et les timestamps ISO avec fuseau, présents dans les sources embarquées, sont acceptés.

Avertissements séparés : rôle historique, caractère historique inconnu, source non datée et sans saison, source postérieure au relevé à contrôler, échéance explicitement estimée, provenance ou terme absent, échéance déclarée officielle sans référence exploitable, conflits de faits déjà déclarés, et pièces individuelles d’ouverture non embarquées. Une donnée inconnue ne devient pas fausse ; une estimation explicitement annoncée ne devient pas un bug.

`contractOfficialDeclared` est une déclaration des métadonnées, pas une contre-vérification de la publication source. `staffCurrentDeclared` signifie seulement `historical:false` dans le snapshot, **pas que la personne occupe encore cette fonction aujourd’hui**. `openingChanges` compare le terme initial dérivé aux termes sources, sans créer une carrière ni modifier le moteur.

## Résultat sur la base `c07ce6a6`

| Édition | Clubs catalogue / jouables | Joueurs catalogue | Actifs prospectifs | Fiches staff | Erreurs certaines |
| --- | --- | --- | --- | --- | --- |
| Monde | 58 / 56 | 3 208 | 3 208 | 808 | 0 |
| + Pacifique | 68 / 66 | 3 589 | 3 589 | 947 | 0 |
| + Japon | 88 / 86 | 4 667 | 4 667 | 1 859 | 0 |
| + Nationale | 102 / 100 | 5 282 | 5 282 | 2 014 | 0 |
| + Champ | 116 / 114 | 5 884 | 5 878 | 2 160 | 0 |

Les deux clubs invités font partie du catalogue et de l’audit, sans être proposés comme clubs jouables. Sur v5, trois fiches sont explicitement historiques ; 1 951 n’ont ni date ni saison de source embarquée. Ces chiffres justifient une réserve sur l’actualité, pas une réécriture de fonctions sans leurs pièces privées.

Les métadonnées de contrats du catalogue v5 comptent 87 échéances déclarées officielles et 5 797 explicitement estimées. Le registre documentaire d’ouverture porte 114 termes actifs, soit 96 fins de saison et 18 bornes minimales. Il change 71 termes initiaux par rapport à la base estimée/profilée. Ces 114 lignes sont comptées séparément : elles ne convertissent pas rétroactivement les métadonnées sources estimées en preuves officielles. Les pièces nominatives privées ne sont pas intégrées dans le rapport. Les six exclusions d’alias, dont un transfert entre clubs, sont conservées.

Aucun identifiant orphelin, rôle invalide, source française pendante ou contradiction d’échéance certaine n’a été trouvé sur ces cinq éditions. Ce résultat ne prouve ni l’exhaustivité des staffs ni la conformité réglementaire des fonctions et des contrats.

## Qualification et limites

Neuf tests sous Node 22.23.4 : estimations et inconnus honnêtes, identités/appartenances contradictoires, alias et transfert, sources/termes incohérents, absence de fuite de champs nominatifs/URLs, entrées gelées et non-mutation, puis chargement réel des cinq éditions via les builders de production et répétition déterministe. Les cas adversariaux supplémentaires couvrent registre d’ouverture absent ou partiel, aliases invalides, contradictions identité/version/mode, politique réellement non applicable, et CLI privé de ses entrées (sortie 1 expurgée). Les fixtures injectent des fautes qui doivent être détectées ; elles ne se limitent pas à recopier les attentes de structure du catalogue.

Le profil persistant, les historiques de staff privés, les sources nominatives, les fichiers de jeu, les registres et l’économie ne sont pas modifiés. Aucun test Windows, sauvegarde réelle ou nouvelle collecte externe n’est revendiqué. Les contrats d’ouverture déjà reçus disposent de leur propre test de création/réouverture/import ; cet outil est un contrôle complémentaire de qualité documentaire, pas une migration.


## Adaptation au catalogue actif dédoublonné — réception66d6225

Le tableau `c07ce6a6` ci-dessus reste un reçu historique. Après séparation des six fiches alias dans le lecteur legacy, le catalogue actif Champ compte **5878fiches**, dont5878actives prospectives ; le support d’anciens packs et exports conserve **6fiches legacy séparées**, soit5884IDs lisibles au total, sans six personnes nouvelles. Les2160fiches staff ne changent pas. Les contrats du catalogue actif comptent87déclarés officiels et5791estimés ; les114termes d’ouverture et71modifications de terme restent identiques.

L’audit lit le registre `registry.compatibilityAliases` exposé par les builders production. Il vérifie l’absence des aliases dans le catalogue actif, leur ancien propriétaire Champ, le playerId de leur fiche, leur canonicalId actif et l’égalité exacte avec le mapping du registre d’ouverture. Il ne reconstitue pas un propriétaire à partir du seul mapping d’ouverture. Une source legacy absente, incohérente, cyclique, liée au mauvais club ou réintroduite parmi les actifs reste une erreur.

Les compteurs distinguent désormais `players` (lignes du catalogue actuel), `legacyAliasPlayers` (fiches isolées du lecteur), `playersIncludingLegacyAliases` (ensemble d’IDs lisibles), `catalogueInactiveAliases` (aliases encore dans le catalogue fourni) et `inactiveAliases` (mappings d’ouverture). Sur Champ courant :5878/6/5884/0/6. `prospectiveActivePlayers` vaut5878 : aucun second retrait des six fiches déjà enlevées. Les anciennes fixtures avec aliases présents dans le catalogue gardent leur exclusion prospective. En cas de registre d’ouverture inconnu ou invalide, les compteurs dérivés de compatibilité sont `null`, pas zéro certifié.

Régression reproduite sur66d6225 sous Node22.23.4 : le contrôle réel signalait douze fausses erreurs d’alias pendant que les huit autres tests passaient. Le raccord au lecteur explicite et une fixture dédoublonnée adversariale rétablissent les contrôles sans désactiver les gardes. Aucun registre, donnée, worker, profil, coefficient ou source privée n’est modifié.
