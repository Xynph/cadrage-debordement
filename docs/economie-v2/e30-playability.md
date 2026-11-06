# Économie V2 — E3.0 : qualification de jouabilité, avant tout raccordement

**Statut** : laboratoire isolé, PR DRAFT empilée sur #351. Pas d'édition des modules E1–E2.9, jeu, fichiers de sauvegardes, interface, finances réelles du moteur, PRODUCTEUR, MATCH 3D, DATA/LNR ou gate. Les quatre scénarios sont **synthétiques** ; aucune simulation ne remplace les 90 saisons natives.

## Décisions sportives compréhensibles

| Choix du manager | Effet dans la prévision | Contrepartie sportive |
| --- | --- | --- |
| Maintenir le projet | Dépense les **achats optionnels** au calendrier choisi | Conserve le rythme des investissements mais peut mettre le cash en déficit |
| Échelonner les projets | N'engage que les achats optionnels finançables au-dessus d'une **réserve choisie par le joueur**, met le reste en attente non contractuelle | Progression des installations / projets plus lente, sans amende fictive |
| Suspendre les achats | N'engage pas les achats optionnels durant l'horizon simulé | Le joueur renonce provisoirement aux améliorations, mais préserve la trésorerie |

Les charges réellement exigibles sont **toujours déduites à la date prévue** ; aucune option ne peut les effacer, négocier sans contrepartie ou les qualifier fictivement de « reportées ». Le planificateur n'invente ni prêt, ni recette, ni dette, ni baisse de salaires. La réserve volontaire est un objectif de planification, **pas un plancher salarial ni une sanction**. Si les coûts obligatoires dépassent toutes les ressources, l'outil dit explicitement qu'un choix d'achats facultatifs ne suffit pas, plutôt que de produire une victoire artificielle.

`compare` présente des soldes semaine par semaine, le premier déficit éventuel, le premier retour à l'équilibre, les achats réellement réalisés et ceux laissés facultatifs. Les flux `income` et `required` doivent déjà être connus de l'appelant ; aucune promesse commerciale non documentée ne peut se transformer en revenu.

## Qualification de crises

Quatre scénarios déterministes explicitement synthétiques :
- Déficit temporaire de recettes, puis reprise de recettes déjà inscrites dans le calendrier.
- Surinvestissement dans les projets facultatifs ; réduire ou étaler ces achats évite un déficit sans réduire les obligations.
- Coûts obligatoires impossibles à couvrir ; aucun choix magique ni crédit non signé.
- Revenus futurs déjà confirmés dans les données de l'exercice ; la remontée ne vient pas d'une subvention inventée.

Les tests vérifient le coût réel des arbitrages (améliorations différées), les soldes, l'absence de nouveaux engagements fictifs, les règles d'insolvabilité et la non-mutation des entrées. Ce **n'est pas** un test UX avec un joueur humain ni une intégration de ces options dans le jeu : une validation visuelle des écrans, de l'IA et du taux d'échec reste indispensable.

## Données du vrai moteur (lecture seule)

Workflow GitHub : trois profils × deux graines × 15 saisons, 435 tours / 14 intersaisons / trois imports par campagne. `ci/economy-v2-e30-run.cjs` réutilise la campagne E2.9, les contrôles de sauvegarde état/checksum et les indicateurs descriptifs des 14 clubs. Le proxy de pression (`cash < 29 × masse salariale hebdomadaire`) **ne représente pas une dette**, une faillite, une pénalité ni un seuil imposé ; les sorties sont expressément qualifiées d'observations. Aucun passif inconnu n'est converti en zéro.

## Autorité d'intégrité — limites à lever avant intégration

Le témoin anti-rollback E2.9 attend une interface d'autorité `current/compareAndSet`, mais sa fixture HMAC locale peut être restaurée en même temps que le registre. Une autorité de **production** exigerait un service monotone hors du domaine d'écriture de la sauvegarde, des permissions séparées, gestion/rotation de clés, journaux d'audit et récupération supervisée. Le jeu PC offline demande un arbitrage spécifique de disponibilité, sans rendre une partie inutilisable faute de réseau. E3.0 n'ajoute **aucune** autorité non vérifiée et ne change pas le registre.

**Principe produit** : crises difficiles mais récupérables par de vrais choix, sans pénalité artificielle, sans dette inventée, sans supprimer une dépense légalement due. Aucun READY, /cd-check, gate ni fusion.
