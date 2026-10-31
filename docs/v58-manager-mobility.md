# V58 — candidatures et mobilité du manager dans la carrière native

## Fonction jouable

Activation volontaire depuis le bureau du manager. La carrière intégrée, le monde V46–V51 et les effectifs IA V59 doivent déjà être actifs. Les anciennes sauvegardes ne sont pas migrées silencieusement. La version générale de sauvegarde reste V2 ; les nouveaux champs `managerMobilityVersion:1` et `managerMobility` sont facultatifs et validés explicitement.

Après la finale, le joueur peut candidater auprès des autres clubs. La direction répond immédiatement suivant un modèle déterministe fondé sur les vrais classements, confiance des entraîneurs, réputation et trésorerie. Un club stable peut refuser. Il s'agit de candidatures spontanées, PAS d'un marché prétendant recenser des postes vacants réels. Les coefficients sont des choix de jeu à équilibrer.

Une offre peut être refusée ou examinée puis acceptée. Une seule nomination est possible à la fois et peut être annulée avant le passage de saison. Le joueur dirige encore son club actuel jusqu'à la clôture. Le changement est exécuté après les traitements natifs d'intersaison, avant sauvegarde finale. Le club actuellement dirigé reste exclusivement `S.club` : aucun deuxième registre de titulaires.

## Conservation des données

- Aucun argent ni joueur professionnel n'est transféré avec le manager. Le financement et les salaires continuent de dépendre des mécanismes natifs, une seule fois.
- Les installations et dettes restent rattachées aux clubs. Les espoirs du club quitté passent sous gestion IA et ceux du nouveau club deviennent son centre accessible ; aucun doublon à la prise de poste.
- Le centre transféré à l'IA peut conserver jusqu'à 12 jeunes au moment du relais. Les choix de renouvellement et la limite ordinaire de six du prochain cycle V59 restent inchangés.
- Les mouvements IA historiques du nouveau club restent conservés. Le validateur accepte ces traces uniquement jusqu'à la saison de prise de poste.
- Les comptes de l'ancien bureau et les revues de direction sont archivés par club. Les observations financières pendant les années où le club est géré par l'IA ne sont pas réinventées.
- Les missions de recrutement du bureau, objectifs individuels et actions locales de vestiaire sont réinitialisés lors du changement. Les contrats professionnels, résultats, palmarès et journaux globaux de transfert restent présents.
- Aucun salaire personnel du manager, aucune indemnité ni licenciement automatique du joueur ne sont ajoutés dans cette première tranche.

## Transaction et sauvegardes

La transition est protégée par un instantané en mémoire : les sauvegardes intermédiaires sont suspendues ; une erreur restitue l'état antérieur. Le document natif est validé avant écriture finale. Une erreur réelle du stockage reste visible selon le mécanisme de sauvegarde existant : aucun repli silencieux.

Les fonctions de risque et d'affinité V48 sont réutilisées. Le remplacement déjà compté par V48 en clôture annuelle n'est pas compté deux fois. Les prototypes #60 à #63 ne sont pas fusionnés en bloc.

## Validation

`tests/manager-mobility.cjs` utilise le vrai harness et les vrais matchs : 22 scénarios couvrant trois saisons, deux prises de poste, comptes comparés à un témoin sans mutation, espoirs, offres/refus, annulation, reprise JSON, vues natives et dix corruptions. Une graine identique est réinstallée dans les contextes comparés ; ce n'est PAS une preuve de persistance du générateur aléatoire de production.

La CI complète et la validation post-fusion sur le SHA exact restent obligatoires. Aucun test Windows natif ni validation manuelle d'une sauvegarde personnelle n'est revendiqué.
