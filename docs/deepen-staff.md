# Emploi rémunéré du staff — conception et plan

## Choix produit
Le club active volontairement l'économie nominative du staff. L'activation seule ne transforme aucun contrat historique : chaque membre en poste doit être adopté explicitement, après présentation du salaire, de l'engagement et de la prévision. Les nouveaux recrutements du club activé passent par cette économie. Le cycle descriptif v1 garde ses champs et son salaire zéro ; un domaine indépendant conserve les engagements financiers réels du jeu.

Barème hebdomadaire fictif par rôle : entraîneur 500 €, adjoint 350 €, formation 300 €, recruteur 250 €, analyste 250 €, médical 400 €, préparation physique 300 €, encadrement 200 €. Aucun tarif ne se fonde sur une compétence réelle ou estimée d'une personne. Pas de prime de signature, pas de bonus sportif nouveau. Le noyau de cinq rôles coûte 1 650 €/semaine, soit 47 850 € sur29semaines, 56 100 € sur34 ou 75 900 € sur46. Un engagement doit laisser 50 000 € de trésorerie et provisionner jusqu'à huit paies restantes du contrat. La rupture coûte au plus deux paies (ou moins s'il en reste moins), ce qui permet le redressement.

Le paiement est commun aux trois calendriers : `financeWeek` règle tous les contrats adoptés encore valides, une seule fois par saison/semaine. Un club quitté continue d'assumer les contrats qu'il a signés. Un contrat expiré, une retraite ou une libération arrête les paies. Les reconductions IA du cycle descriptif n'étendent pas silencieusement un engagement financier. Aucun coût existant de réunion, protocole médical, installations ou salaire joueur n'est repris : les réunions sont des dépenses ponctuelles distinctes, les salaires descriptifs nominaux sont nuls.

Alternative écartée : imposer des salaires à tout l'annuaire au démarrage, qui aurait créé une charge rétroactive et multiplié les dépenses sur la base d'identités documentaires.

## Plan
- [x] Tests rouges du domaine et de la cadence de paie, garde anti-contournement, anciennes carrières et import strict.
- [x] Domaine `staffEmployment` et commandes nominatives, projection des devis et engagements.
- [x] UI Staff commune, montant visible avant chaque confirmation.
- [x] Vraies semaines worker, reprise/import, échec disque et solvabilité sur plusieurs graines.

## Raccordement
Ajouter `staffEmployment:require('./staff-employment.cjs')` au manifeste `domains` de `native-systems.cjs`. Aucun changement du format v1 de staff, du worker ou des coefficients financiers globaux. Les commandes sont `staff_employment_enable/adopt/hire/renew/release/retire`. L'UI Staff partagée utilise `clubLife.staffEmployment` ; le budget séparé explicite que les autres dépenses/recettes sont exclues de cette projection. Le débit réel apparaît dans le grand livre existant.

`installHooks` enveloppe `financeWeek` et les commandes du domaine staff existant. Le verrou de paie est commun, y compris quand aucune personne n'est encore rémunérée : adopter après une paie vide ne facture ni ne prévoit une paie passée. Les anciennes signatures gratuites sont empêchées après activation, les libérations gratuites d'un contrat adopté également. La délégation vers le cycle v1 ne contourne pas ses limites d'âge ou de durée. Une rupture reste possible en trésorerie négative : l'indemnité est débitée et le salaire récurrent s'arrête, plutôt que d'interdire le redressement. Le devis s'arrête au plus tard à la retraite simulée connue ; une reconduction descriptive IA n'étend pas le contrat rémunéré.

## Vérification
Les tests de domaine couvrent activation gratuite, absence de migration, devis exacts, paie unique, import strict, contrat expiré/parti, obligation d'un ancien club après mobilité, réserve financière, refus sans mutation, paie vide puis adoption, rupture en insolvabilité et retraite prévue.

Les tests du vrai worker enregistrent le domaine par une adaptation du manifeste **uniquement dans le banc**, équivalente au raccordement root. Une copie de profil conserve l'état du hasard pour le contrefactuel sans économie staff ; les export/import recalculent le checksum normal de test. Une première tentative de banc a volontairement exposé un checksum périmé, puis un parcours sans confirmation de promotion de couverture ; ces défauts du banc sont corrigés. L'état, le profil disque et les erreurs restent visibles. Le refus d'écriture est provoqué par un répertoire à la place du fichier : aucune carrière ni trésorerie partiellement modifiée ne reste publiée.

Mesures sur trois graines (27,827381,414), huit semaines réelles et cinq contrats de base : 1 650 €/semaine, 13 200 € cumulés, trésoreries finales respectives 8 777 852 €, 8 895 440 € et 8 740 624 €. Les différences avec le contrefactuel sont exactement ces charges et les résultats sportifs sont identiques. Ce banc démontre la solvabilité de ces ouvertures fictives, pas un équilibrage universel de tous les clubs.

Une saison fictive entière a réellement parcouru 29 paies, dont les trois semaines de phases finales : 14 500 € pour un entraîneur à500€, puis 14 500 € d'engagement restant enS2. Les calendriers France34 et Monde46 sont vérifiés séparément par le worker. La recette Godot4.7.2 headless contrôle activation, devis, salaire, durée et indemnité de rupture ; elle ne prétend pas être une recette Windows.

## Réception du vrai parcours Staff dans le client natif

`tests/deepen-staff-real-ui.cjs/.gd` démarre réellement `main.tscn` et son worker de production. Le banc a reçu **141 contrôles, zéro échec**, sur la combinaison d'intégration Cloud `/workspace/work/parallel-six`, sous Godot4.7.2 et Node22. Aucun objet d'application simulé ni confirmation automatique n'est utilisé dans cette recette.

Depuis la route Staff à1920×1080, elle annule puis confirme l'activation, ouvre le budget et le devis nominatif et les annule sans écrire de carrière. Elle vérifie les fenêtres et boutons à1280×720 et1920×1080. Un obstacle réel remplace le fichier de profil : l'adoption confirmée échoue visiblement, puis l'état exporté et les octets originaux restent identiques après restauration du fichier. Le réessai public confirme l'adoption à500€/semaine. Une semaine réelle produit exactement un paiement de500€ et son débit au grand livre. La rupture est d'abord annulée, puis confirmée :1000€ d'indemnité et aucun salaire récurrent. Le moteur est effectivement arrêté, un nouveau main est instancié, et la reprise du profil retrouve exactement l'état après rupture.

Commande de réception : `CD_STAFF_REAL_ROOT=/workspace/work/parallel-six CD_GODOT_EXECUTABLE=/workspace/.cloud-setup/tools/godot472/Godot_v4.7.2-stable_linux.x86_64 /workspace/.cloud-setup/tools/node22/bin/node --test tests/deepen-staff-real-ui.cjs`. Sans `CD_STAFF_REAL_ROOT`, le test utilise le dépôt qui le contient après intégration. Les traces restent dans un répertoire temporaire imprimé par le banc. La garde du test backend n'injecte le manifeste que sur une base où le domaine manque ; sur la combinaison intégrée, les tests exercent le bootstrap réel sans modification.
