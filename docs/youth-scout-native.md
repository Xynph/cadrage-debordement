# Raccord natif : détection des regens et suivi des jeunes

Le raccord conserve le worker comme unique autorité de transaction et de publication disque. Les factories des deux domaines sont injectées dans la VM depuis le manifeste fermé `native-systems.cjs`, puis projetées automatiquement dans `model.clubLife`. Aucun nouveau catalogue ni tarif.

## Contrat

- `clubLife.regenScouting` : candidats majeurs de population v2, origines connues, fourchettes datées de recrutement, besoins, shortlist et conditions contractuelles existantes. `regen_shortlist` modifie seulement le suivi existant ; missions à 5 000 € et négociations passent par `scout_mission` et `recruit`.
- `clubLife.youthDevelopment` : suivi explicitement activé par `youth_development_enable`, puis objectifs `general`, `specialist` ou `integration` par `youth_development_plan`. Les deux commandes demandent `confirmed:true` et le contexte exact `{season,week,club}`. Aucune activation à la lecture, à l'import ou à la création d'une carrière.
- `CDYouthDevelopment` désigne exactement l'instance du domaine. Les observations suivent les fonctions natives `trainWeek`, `recordDevelopmentMatch`, `rollDevelopmentYear`, `advanceSeason`, `promoteYouth` et `managerMobilityOnSeasonStart`, autour de leurs wrappers préexistants (avant pour amorcer les nouveaux entrants, puis après pour mesurer les changements). Elles ne donnent aucun point, minute, argent ou gain supplémentaire.
- La spécialisation active répartit le budget existant pour les regens selon le module auteur. Les profils annuels V11 ne reçoivent pas cette allocation : `specialist` est refusé. Les règles et limites détaillées appartiennent aux documents des domaines.

## Plan d'intégration

1. Écrire un témoin vrai worker rouge pour l'exposition et la lecture pure du domaine de détection ; enregistrer sa factory puis revoir le témoin vert.
2. Après réception du module jeunes, ajouter les témoins de suivi non actif par défaut, activation explicite, décisions sans gain immédiat et observations des opérations réelles. Ajouter factory, alias unique et wrappers externes.
3. Vérifier ancienne sauvegarde sans champ, imports altérés, contexte périmé, joueur étranger, refus réel de publication disque et reprise exacte. Comparer RNG, horloge, store et données de jeu lorsque l'action ne doit modifier que le suivi.
4. Rejouer les deux suites de domaine et les régressions ciblées de systèmes/décisions/formation ; documenter les résultats réellement reçus avant commit du raccord.

## Points de vigilance

Les projections travaillent sur des copies des joueurs. Les fourchettes ne révèlent ni potentiel caché ni statistiques non observées. Le suivi des jeunes utilise l’estimation au poste `potentialAtRole` sur copie, marquée `potentialBasis:role-estimate`, pour les références et variations ; aucun plafond moteur brut nouveau n’est projeté. Les hooks n'appellent pas `observe` depuis un validateur ou l'import. Une sauvegarde incorrecte est refusée, jamais corrigée silencieusement. Les retours des fonctions natives sont conservés ; les matchs et coefficients restent sous l'autorité des moteurs existants.

## Réception

Les quinze tests courts de `tests/youth-scout-native.cjs`, `tests/youth-development-plan.cjs` et `tests/youth-development-observation.cjs` passent sous Node22 en 31,7 s. Les six cas du raccord utilisent le vrai worker de production, sans registre substitué : nouvelle carrière et import/reprise restent inactifs jusqu’au choix explicite ; l’activation conserve toutes les données de jeu, le RNG et l’horloge ; un plan ne donne aucun gain immédiat ; un entraînement réel suit le partage 75/25, puis un second appel déjà appliqué ne donne aucun gain ni observation supplémentaire ; contextes périmés, joueur étranger, focus invalide et spécialisation annuelle sont refusés ; la publication disque refusée restaure l’état et permet un réessai ; imports de métriques impossibles, horloges futures et IDs dupliqués sont refusés atomiquement. Les snapshots actifs restent purs et les reprises conservent les octets privés exacts.

Le témoin de détection a d’abord échoué sur le registre absent, puis passé après raccord. Le même scénario d’XP échoue aussi dans une copie isolée privée de l’alias et des observations : il reçoit le partage de repli 50/50. Cela vérifie que l’instance du domaine actif pilote bien le vrai moteur. Les sources de production ne sont pas modifiées pour ce contre-test.

Les huit tests de détection et les régressions systèmes/décisions ont également passé avant le raccord jeunes (26,1 s). La recette de saison réelle et la recette Godot sont encore à recevoir au moment de ce commit ; aucun succès de campagne longue, paquet Windows ou CI complète n’est déduit de ces tests courts.

## Assemblage sur la tête de la PR423

Le raccord suivant capture aussi les références avant chaque opération observée. Un test vrai worker reproduit le défaut initial : après recrutement postérieur à l’activation, la première séance devenait sa propre référence et masquait 0,077 XP. La référence pré-séance vaut maintenant 0, la première variation réelle reste visible, et la reprise conserve ce suivi. L’amorçage est limité au suivi déjà explicitement actif ; il ne s’exécute jamais pendant une lecture, l’import ou la validation.

La réception d’intégration complète et les limites sont dans `docs/youth-scout-integration-20261109.md`. Le reçu de saison historique reste distinct ; aucune nouvelle campagne longue n’est assimilée à ce correctif.
