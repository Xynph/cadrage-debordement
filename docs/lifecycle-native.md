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

`media-packs.project` parcourt l'ensemble du modèle, dont `clubLife.staffCareer`, et traite `identity.id` avec les identifiants source. Après cette projection, `staff.applyCareerPresentation` aplatit uniquement le nom, le libellé de rôle et les champs de portrait présentés vers le membre/candidat : l'UI qui lit `person.name` reçoit la même identité que celle de l'annuaire. Cela fonctionne même si un libellé de référence a été nettoyé pour respecter les caractères autorisés des sauvegardes. Les IDs de commande ne changent pas. Les packs ne modifient pas les noms anonymisés persistés ni les compétences/contrats.

## Réception ciblée

Les huit tests `tests/lifecycle-native.cjs` couvrent nouvelles carrières sur cinq modes, lecture d'un document d'ancien format sans activation, deux ordres d'activation indépendants, RNG/horloge/cash conservés à l'activation, commandes staff et refus périmés/étrangers, véritable refus disque avec rollback et réessai, imports d'horloge/source falsifiés, retraite volontaire et identité présentée sans changement d'ID.

`tests/staff-packs.cjs` conserve sa recette v1/v2, portraits, bascule/reprise, corruption et refus ; les recherches d'identité de référence acceptent maintenant `sourceStaffId` pour les nouveaux membres dynamiques, avec assertions supplémentaires sur l'ID de commande et l'identité projetée dans `clubLife`.

La recette manuelle de deux transitions natives réelles a réussi : 2 × 34 semaines, 2 × 433 résultats, trois réouvertures exactes, 545 puis 548 membres âgés exactement d’un an et trois reconversions par transition. Le reçu et les empreintes des sources réellement exécutées figurent dans `lifecycle-native-reception-20261109.md`. Les tests VM du domaine seuls ne remplacent pas cette preuve de raccordement au moteur. Aucun profil personnel ou média privé n'est utilisé.


## Interface et portraits gratuits

Les commandes staff sont disponibles dans Staff : annuaire des clubs, recherche, candidats, archives et pagination de vingt profils. Recrutements et prolongations fixent une durée ; libérations et retraites demandent confirmation. Les contrats et mouvements sont réellement persistés. Les anciennes carrières proposent une activation explicite. Le panneau des besoins de recrutement présente la population persistante et son activation conjointe avec le staff.

Les portraits fournis par un pack restent prioritaires, y compris une identité source imbriquée d’ancien joueur reconverti. À défaut, le jeu compose localement des portraits à partir de 48 visages fictifs IA prégénérés. Aucun réseau, abonnement, clé ou facturation à l’usage. Les variations et le vieillissement restent illustratifs ; des ressemblances sont possibles. Les aperçus du club et les deux versions de l’annuaire utilisent ce même rendu.

Réception Godot 4.7.2 Linux X11/Mesa : 57 contrôles réels réussis sur 1280×800, 1440×900 et 1920×1080, avec signatures, prolongation, libération, identité source officielle prioritaire et conservation état/RNG/disque pendant la navigation. 379 contrôles graphiques distincts qualifient les portraits et les variations visibles sur une même cellule source. Le poste utilise un écran virtuel et une voix TTS factice locale pour initialiser les API ; aucune synthèse audible ni recette Windows n’est revendiquée.

Quatre fixtures de capacité réellement importées avec le staff actif conservent les limites existantes : pool généré World 11 347 791 octets / 16 Mio, Champ 21 544 857 / 24 Mio ; pool de professionnels source libérés avec douze historiques chacun World 12 503 075 / 16 Mio et Champ 23 754 693 / 24 Mio. Ce sont des fixtures de taille, sans prétendre avoir joué douze années sur ces états.

La recette UI étendue vérifie aussi l’import d’une vraie initialisation v1, l’annulation sans mutation, l’activation indépendante du staff puis du vivier, les joueurs/trésoreries conservés et le RNG sportif inchangé. Les neuf tests du cycle staff refusent désormais les cibles IA augmentées ou diminuées par rapport aux sources immuables ; les ordres des clés et des équipes restent libres.
