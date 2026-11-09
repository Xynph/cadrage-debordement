# Raccord natif des populations et des carrières de staff

Le worker reste l'unique autorité de transaction disque. Les domaines ne reçoivent ni stockage ni RNG externe : `population_enable` active explicitement une ancienne population v1, et les commandes de staff sont exécutées par la même instance `CDStaffCareer` que la validation, la capture des retraites et la projection.

## Commandes et projections

`population_enable` exige `{confirmed:true, context:{season,week,club}}` exact et aucun paramètre supplémentaire. L'activation refuse un match actif, une phase incompatible, des négociations en cours ou un cycle déjà actif. Elle appelle `enablePopulationPolicy()` puis initialise le staff si nécessaire ; un staff déjà actif n'empêche pas l'activation de la population. À l'inverse, `staff_career_enable` permet l'activation du staff si la population est déjà v2. Lire ou importer une ancienne carrière n'active aucun cycle silencieusement.

Les nouvelles carrières utilisent la population v2 et le staff de carrière. Les éditions avec catalogue utilisent les sources anonymisées de leur édition ; les modes sans catalogue reçoivent uniquement des rôles fictifs déclarés. Le registre initial n'est jamais modifié. Une map sérialisée puis gelée dans la VM lie chaque databaseId aux clubs de son annuaire ; aucun objet source Node mutable n'est partagé avec le domaine.

- `model.meta.population` : version, active, canEnable, requiresConfirmation, referenceAccessible, knownAccessible et historique de population.
- `model.clubLife.staffCareer` : active, enabled, contexte exact, équipes, candidats/marché, historique, archives/retraites, contraintes de contrat, coûts et notice.
- `model.staff.teams` : annuaire dynamique pour un cycle actif, annuaire historique inchangé pour une ancienne carrière inactive. Les membres gardent leurs IDs de commande `staff-career:…` ; `sourceStaffId`, `sourcePlayerId` et `identity.id` servent uniquement de références d'identité.

Les payloads staff exigent toujours contexte et confirmation : `staff_hire` ajoute candidateId/years, `staff_renew` staffId/years, `staff_release` et `staff_retire` staffId. Les réponses possèdent `meta.staffCareerAction`, distinct d'une simple consultation de l'annuaire. Les coûts nuls sont explicitement déclarés par cette version descriptive ; aucun bonus sportif ou coefficient financier n'est ajouté.

## Transitions, horloges et conservation

Le raccord capture les références professionnelles avant le vrai `rollDevelopmentYear`, laisse le moteur vieillir et retirer les joueurs, puis transmet les références vieillies effectivement disparues à `captureRetirement`. Le domaine peut proposer une reconversion selon sa politique et garde une preuve d'origine ; il ne transforme pas automatiquement chaque retraité en entraîneur et n'invente aucun diplôme officiel.

Après le changement réel de saison, le staff avance une fois. Si un moteur historique valide l'état avant de rendre la main au wrapper de transition, un garde temporaire et privé ne reconnaît que l'identité exacte de la carrière en cours de transition ; il termine son horloge de staff avant cette validation. Il ne relâche aucune règle : un objet importé ou cloné ne correspond pas au garde, et conserve ses contrôles d'horloge stricts. Les erreurs et timeouts effacent ce contexte transitoire avant restauration de l'ancien état.

## Identités et portraits

`media-packs.project` parcourt l'ensemble du modèle, dont `clubLife.staffCareer`, et traite `identity.id` avec les identifiants source. Après cette projection, `staff.applyCareerPresentation` aplatit uniquement le nom et les champs de portrait présentés vers le membre/candidat : l'UI qui lit `person.name` reçoit la même identité que celle de l'annuaire. Cela fonctionne même si un libellé de référence a été nettoyé pour respecter les caractères autorisés des sauvegardes. Les IDs de commande ne changent pas. Les packs ne modifient pas les noms anonymisés persistés ni les compétences/contrats.

## Réception ciblée

Les tests `tests/lifecycle-native.cjs` couvrent nouvelles carrières sur cinq modes, lecture d'un document d'ancien format sans activation, deux ordres d'activation indépendants, RNG/horloge/cash conservés à l'activation, commandes staff et refus périmés/étrangers, véritable refus disque avec rollback et réessai, imports d'horloge/source falsifiés, retraite volontaire et identité présentée sans changement d'ID.

`tests/staff-packs.cjs` conserve sa recette v1/v2, portraits, bascule/reprise, corruption et refus ; les recherches d'identité de référence acceptent maintenant `sourceStaffId` pour les nouveaux membres dynamiques, avec assertions supplémentaires sur l'ID de commande et l'identité projetée dans `clubLife`.

La recette manuelle de deux transitions natives réelles est exécutée et consignée séparément après ce commit ; elle n'est pas présentée comme reçue avant son verdict. Les tests VM du domaine seuls ne remplacent pas cette preuve de raccordement au moteur. Aucun profil personnel ou média privé n'est utilisé.
