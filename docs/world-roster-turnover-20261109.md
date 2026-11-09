# Réconcilier les mouvements d’effectif dans les carrières Monde

`ci/world-roster-turnover-audit.cjs` est un outil manuel d’observation des identifiants professionnels, académies, marché visible et agents libres. Il complète le banc de carrière longue : ce dernier mesure les soldes et volumes ; cet outil explique les changements d’appartenance et contrôle que chaque variation du nombre de professionnels correspond aux arrivées et départs effectivement observés. Aucun effectif, salaire, coefficient ou résultat sportif n’est ajusté.

## Exécution

```bash
node ci/world-roster-turnover-audit.cjs --seed 827381 --mode world --seasons 2 --out /tmp/turnover-2s.json
node --test tests/world-roster-turnover.cjs
```

La graine et la destination sont obligatoires ; une destination existante est refusée. Les modes `world`, `world-pacific`, `world-japan`, `world-nationale` et `world-champ` sont acceptés. Le club par défaut est 0 ; `--club` permet d’en choisir un autre valide pour le mode. Le nombre de saisons est limité à une ou deux et le budget par défaut à vingt minutes, modifiable avec `--budget-ms`. La prise en charge d’un mode par la CLI ne constitue pas une recette exécutée de toutes ses variantes.

L’outil ouvre un profil jetable, crée la carrière par le vrai worker et suit les commandes publiques habituelles : composition automatique si nécessaire, `promote_cover` confirmé uniquement si la feuille reste incomplète, vrai coup d’envoi, délégation et validation des semaines. Il reprend la politique passive du banc dix saisons : aucune décision de recrutement, prolongation ou investissement du manager. Les autres clubs suivent leur IA habituelle. Après chaque saison complète, il observe la transition suivante ; deux saisons livrent donc les passages S1→S2 et S2→S3. La réouverture finale compare exactement l’export public et les octets du profil privé.

## Identités, preuves et inconnues

Les professionnels ont une appartenance exclusive par club. Les académies du manager et des clubs IA sont relevées séparément. Un joueur peut apparaître à la fois dans le marché visible et les agents libres : il ne compte qu’une fois parmi les identités uniques, avec ses deux surfaces de présence. Un même ID professionnel appartenant simultanément à deux clubs provoque un échec explicite de l’audit.

Les événements IA sont accumulés chaque semaine : cela conserve les preuves avant que le journal de 180 événements ne les évince. Un grand nombre de changements au sein d’une même commande de transition peut néanmoins dépasser ce plafond. Les compteurs agrégés du jeu ne constituent pas une preuve nominative manquante.

- Changement observé de club professionnel : recrutement/transfert, indépendamment d’une preuve de coût ou de négociation absente.
- Passage observé d’une académie au groupe professionnel du même club : promotion. Une promotion ou un renfort d’urgence peut aussi être établi par un événement explicite nominatif.
- Sortie vers les agents libres ou le marché : libération seulement si un événement nominatif l’atteste, ou si l’échéance contractuelle observée est expirée et que le joueur est effectivement retrouvé dans ce vivier.
- Retraite : nouvel enregistrement nominatif du registre des retraites, ou événement IA de retraite pour le professionnel concerné.
- Disparition professionnelle sans preuve suffisante, ou arrivée professionnelle sans origine ni événement établis : **`unknown`**, jamais réparation ou retraite inventée.
- Changements de surface académie/marché : **`pool-change`**. Ils ne sont pas présentés comme des pertes définitives de joueurs. La sortie d’une académie à la limite d’âge ne constitue pas automatiquement une retraite.

Les flux sont des mouvements nets par ID entre deux points, pas le décompte exhaustif de toutes les transactions intermédiaires. Un départ puis retour au même lieu peut ne produire aucun flux net ; les renouvellements sans changement d’appartenance ne sont pas comptés comme arrivées. Les nombres de recrutements/libérations ne doivent donc pas être lus comme les totaux bruts du mercato.

Chaque période contient les flux par ID, leur base de preuve, les lieux avant/après, les événements disponibles et le bilan par club : `après = avant + arrivées − départs`. Le résidu doit être nul. Les inconnues restent visibles même lorsque cette conservation arithmétique est satisfaite : compter correctement un départ ne prouve pas sa cause.

## Mesures par club

Aux points initial, fin de saison et après transition : nombre de professionnels et d’espoirs, somme des salaires hebdomadaires fictifs, âges observés, contrats échus et couverture du sélecteur de feuille à 23 du jeu. Le sélecteur `buildSheet` réel est exécuté via le chargeur de test existant, sur une copie indépendante de l’état : aucun joueur ne reçoit de poste artificiel dans la carrière.

Cette couverture est celle du sélecteur générique du moteur, avec les blessures du point observé. Ce n’est pas une preuve d’habilitation officielle de première ligne, d’inscription EPCR ou de conformité aux quotas propres à une compétition. Une feuille complète de jeu ne justifie donc pas le terme « viable officiellement ». Le minimum professionnel et la liste des feuilles incomplètes portent sur l’ensemble des clubs du registre, invités compris ; ils ne constituent pas un seuil réglementaire inventé.

## Réception

Les six tests courts couvrent conservation des flux prouvés, refus d’inventer la cause d’une disparition, alias marché/agents libres, double appartenance professionnelle interdite, non-mutation des entrées et validation de la CLI. La campagne réellement exécutée est consignée ci-dessous après réception ; les modes non exécutés ne sont pas annoncés reçus.

### Monde : deux saisons reçues

Source moteur `c07ce6a68adfa4f6aee72caab4523c77508bf8e3`, Node 22.23.4, club 0, graine 827381, horloge fixe 1794178800000. **Deux saisons complètes de 791 résultats chacune**, deux transitions jusqu’au début de S3 et réouverture finale identique. Durée réelle : **198,219 s**. Le profil jetable a été supprimé ; aucune installation ou carrière personnelle n’a été utilisée.

| Point | Professionnels | Espoirs | Minimum pro par club | Feuilles génériques incomplètes |
| --- | ---: | ---: | ---: | --- |
| initial | 3208 | 15 | 36 | 14, 25, 27 |
| end-S1 | 3227 | 15 | 37 | Aucune |
| after-transition-S1 | 2866 | 885 | 32 | Aucune |
| end-S2 | 2886 | 883 | 33 | Aucune |
| after-transition-S2 | 2563 | 1749 | 25 | Aucune |

Les trois couvertures initiales incomplètes concernent les IDs 14, 25 et 27. Elles représentent l’observation du sélecteur au point initial, pas une preuve qu’un club serait définitivement incapable de jouer : la carrière ajoute ensuite des renforts d’urgence par ses voies existantes. Les points de clôture et d’après-transition observés ont des feuilles génériques complètes.

| Période | Recrutements | Promotions | Urgences | Libérations | Retraites | Causes professionnelles inconnues |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| season-1 | 0 | 0 | 19 | 0 | 0 | 0 |
| transition-1 | 1 | 0 | 2 | 59 | 63 | 245 |
| season-2 | 0 | 2 | 15 | 0 | 0 | 3 |
| transition-2 | 6 | 4 | 6 | 58 | 33 | 260 |

Chaque bilan par club est conservé sans résidu. Cela ne rend pas les causes inconnues connues : les traces nominatives et les viviers sont bornés. Le rapport distingue aussi les changements de surface non professionnelle (`pool-change`), qui ne figurent pas comme recrutements ou retraites dans le tableau.

Le JSON complet contient les âges et salaires hebdomadaires fictifs de chacun des 58 clubs à chaque point. Sur cette trajectoire unique, les professionnels passent de 3 208 à 2 563 et les académies de 15 à 1 749 au début de S3 ; ce signal demande des observations sur plusieurs graines et saisons. Il ne justifie aucun coefficient ou seuil de remplacement choisi arbitrairement.

Reçu de travail : `/workspace/work/world-roster-turnover-2s.json` et journal correspondant. Empreinte du fichier outil exécuté : `f1cd080d598385fc9264e8fbebe12ffa4da463bff760790c46340d9033ad3c39`. Les résultats publiés ici sont une synthèse du reçu, pas un scénario ajouté à la CI complète. Le banc se lance manuellement pour garder la CI courte.

### Monde + Champ : une saison supplémentaire reçue

Même source moteur, même runtime, graine 827381, club 0, mode `world-champ` : **une saison complète de 1 425 résultats**, transition S1→S2 et réouverture exacte. Durée réelle : **185,498 s**. Cette recette distincte confirme que l’outil fonctionne avec le registre étendu ; elle n’est pas annoncée comme deux saisons Monde + Champ.

| Point | Professionnels | Espoirs | Minimum pro par club | Feuilles génériques incomplètes |
| --- | ---: | ---: | ---: | --- |
| initial | 5878 | 15 | 26 | 14, 25, 27, 98 |
| end-S1 | 5912 | 15 | 29 | 98 |
| after-transition-S1 | 5293 | 1755 | 28 | 92, 98 |

La transition étendue relève 80 retraites prouvées, 58 libérations étayées, 2 recrutements nets et 3 renforts d’urgence prouvés. **488 causes de mouvements professionnels restent inconnues**. Tous les bilans d’IDs par club ont un résidu nul. Le plafond des traces nominatives limite encore davantage l’attribution causale sur ce monde de 116 clubs.

Reçu de travail : `/workspace/work/world-roster-turnover-champ-1s.json`, journal correspondant. Empreinte de l’outil identique à celle du reçu Monde : aucun changement d’algorithme entre les deux campagnes. Les scénarios représentent trois saisons simulées au total, mais une seule graine et deux modes distincts ; ils ne certifient aucun équilibre de carrière à dix saisons.

### Garde des doublons professionnels renforcée après revue

Une fixture rouge a établi qu’un doublon à l’intérieur du même club était dédupliqué dans les emplacements, tout en restant compté deux fois dans le total professionnel. Cela pouvait produire un bilan par ID artificiellement sans résidu. `inventory()` refuse désormais toute seconde occurrence professionnelle d’un ID, dans le même club comme dans deux clubs distincts. Les présences communes aux surfaces marché/agents libres restent dédupliquées normalement. Le chemin CLI passe par cette même validation avant tout bilan.

Six tests courts réussissent après correction, dont le contre-exemple qui échouait auparavant et le refus de construire un faux bilan à partir de cet inventaire. Aucun moteur ou résultat des campagnes n’est modifié. Les deux reçus longs ci-dessus restent ceux de l’outil à l’empreinte antérieure indiquée : cette garde supplémentaire ne transforme pas leurs valeurs, et aucune nouvelle campagne longue n’est revendiquée pour cette modification d’entrée.
