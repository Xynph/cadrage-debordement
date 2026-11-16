# Progression lisible des jeunes — décisions et observations réelles

## Situation et budget existant

Le jeu possède déjà son moteur de progression. `developmentTraining` accorde 0,055 XP en séance normale ou 0,10 en intensif, pondérée par âge, condition, fatigue V27 et préparation collective. `recordDevelopmentMatch` utilise seulement les minutes réellement observées et son marqueur d'idempotence ; 80 minutes apportent 0,12 XP avant pondérations. Le financement du centre peut ajouter son budget payé existant. V29 répartit un seul budget entre note générale et qualité au poste : 1 XP général vaut un point de note, 0,5 XP ciblée un point de qualité, plafonné à +4 par attribut et +8 au total. Le potentiel et l'âge restent contraignants.

Les profils issus de la base officielle suivent au contraire la courbe annuelle V11 : les activités alimentent une exposition annuelle, les 36 attributs sont projetés vers les qualités du jeu, et les effets sont appliqués une fois à la transition. La spécialisation V29 ne s'y applique pas. La projection indiquera cette différence au lieu de promettre une spécialisation sans effet.

V72 apporte un mentorat payé et une détection annuelle. V83, V90 et V95 possèdent aussi des bonus historiques explicites à la clôture ; V102 ne change que le parcours conseillé. Ces modules sont des contrats existants distincts et ne reçoivent aucun bonus supplémentaire ici. En mode Monde, `academyPathways` refuse actuellement ses compétitions juniors : ce chantier ne les active ni ne leur invente une homologation.

## Choix retenu

Un module natif isolé observe tous les jeunes propres au club depuis une baseline créée explicitement. Aucune baseline historique n'est reconstruite. Il propose trois affectations du budget déjà gagné, sans nouveau moteur ni supplément :

- `general` : XP générale, qualité ciblée à 0 % ; objectif de progression globale.
- `specialist` : 50 % générale / 50 % ciblée sur une qualité autorisée au poste, soit le mécanisme V29 existant.
- `integration` : 75 % générale / 25 % ciblée ; étapes de passage au groupe professionnel et minutes réellement jouées.

La répartition ciblée concerne les appels qui autorisent déjà V29. Les appels historiques `allowFocus=false` restent généraux. Les profils annuels V11 refusent `specialist` ; `general` et `integration` servent à suivre les expositions et les étapes réelles, sans changer les coefficients de leur courbe annuelle. Le texte public distingue cette portée. Les objectifs ne créent ni minute, ni salaire, ni promotion automatique, ni prime.

Changer de qualité conserve les points déjà acquis et annule seulement l'XP ciblée partielle, comme V29. Changer de plan sans changer de qualité conserve cette XP. Les erreurs de choix sont révisables hors match et avant la séance ; aucune récompense n'est attachée au fait de choisir, observer ou rouvrir une page.

## État et API

Nouveau domaine `youthDevelopment`, factory autonome `native/engine/youth-development.cjs`, alias VM `CDYouthDevelopment`. Activation explicite uniquement ; l'absence de `S.youthDevelopment` conserve exactement les anciennes traces et le RNG.

- `youth_development_enable`: `{context:{season,week,club},confirmed:true}`.
- `youth_development_plan`: `{context,confirmed:true,playerId,plan,focus:null|ATTR}`.
- Factory : `project(s=S)`, `validate(s)`, `execute(command,payload)`, `observe(s,reason)`, `growthShare(s,p,allowFocus)`, `installHooks()` sans mutation.

La commande et la persistance appartiennent à la transaction du worker. Le module ne lit ni disque, ni réseau, ni hasard. Il ne garde aucun nom ni portrait dans les baselines : seulement ID, propriétaire de la baseline, contexte, chiffres et énumérations. L'affichage reprend les identités courantes du joueur. Les baselines suivent l'ID lors d'une promotion ; les joueurs qui quittent le club ne continuent pas à révéler leurs nouvelles qualités.

Les hooks d'observation, après les traitements existants, sont `trainWeek`, `recordDevelopmentMatch`, `rollDevelopmentYear`, `advanceSeason`, `promoteYouth`, `managerMobilityOnSeasonStart`. `enable` et `plan` servent de raisons internes. Une observation identique est sans effet. La validation et la projection n'observent, n'initialisent et ne réparent jamais un état importé.

## Vérifications

Test rouge puis vert de conservation exacte du budget XP et des attributs réellement modifiés. Tests d'absence de plan, attribut hors poste, âge, potentiel atteint, blessure/charge, duplication de match et révision sans récompense ; sérialisation stricte, projection pure, vraie baseline sans passé inventé, promotion/transition annuelle/mobilité et refus de persistance via le raccord natif. Aucun nouveau run de dix saisons : campagnes courtes et régressions V29/V72 existantes suffisent ici.

Le DTO public conserve le niveau général déjà exposé par le modèle natif. Son champ `potential` est l’estimation au poste de `potentialAtRole` calculée sur une copie, avec `potentialBasis=role-estimate`, et non une nouvelle révélation du plafond moteur. Les snapshots utilisent cette même estimation ; les limites effectives restent appliquées uniquement par le moteur existant. Les qualités sont calculées sur une copie et correspondent à `skill(p,key)` sans facteur de condition.

Le raccord amorce aussi les nouveaux entrants avant leur première séance ou leurs premières minutes, puis observe après l’événement : cela conserve une référence connue avant le gain sans reconstruire un passé. Pour la progression annuelle, l’interface masque les ratios XP et précise que les plans général/intégration sont des objectifs de suivi ; leur choix ne modifie ni la courbe ni l’exposition réelle.

Les repères affichés sont distincts : +1 niveau général, +1 qualité ciblée, ou promotion et 240 nouvelles minutes à partir de la baseline. Les anciennes minutes ne terminent pas artificiellement un nouvel objectif d’intégration. Aucun repère ne paie de prime ou ne déclenche une progression ; l’absence de baseline reste une absence de mesure.
