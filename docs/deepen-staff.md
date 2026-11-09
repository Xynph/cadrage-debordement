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
