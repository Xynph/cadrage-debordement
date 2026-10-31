# Correctifs natifs : prime de champion et entretien previsionnel

## Origine et perimetre
Audit #85, base main e706d6a, candidat 6dfa6cf : Vannes champion en saison 7 (profil modeste, graine 99173) cree 101 ecritures alors que le validateur en autorise 100. Le previsionnel V41 omet aussi les frais natifs des installations actives. Les preuves historiques de #85 restent intactes.

## Correction livrable
- `finishRound` utilise `ledgerEntry` pour la prime de 1 000 000 : credit unique et bornage centralise. Aucun changement du montant, du vainqueur, des regles sportives ou du format des sauvegardes.
- `careerBudgetModel` additionne formation et `worldUpkeep` du club gere lorsque le monde est actif. Niveau initial 2 : aucun surcout ; niveau 3 : 2 900 par periode. La projection et ses variantes sont en lecture seule et ne prelevent rien.
- La description du previsionnel mentionne les frais d'entretien. Les conventions de periodes, la billetterie, les primes, le calendrier et les coefficients economiques restent inchanges.

## Tests et avant/apres
`tests/champion-budget-regression.cjs` comprend 22 groupes : finale simulee nativement sur une fixture de frontiere avec registre plein, titre/non-titre, reprise automatique et import confirme, idempotence, erreur de stockage/reessai, anciennes carrieres sans monde, intersaison et rejet maintenu d'un registre de 101 lignes. Previsions controlees aux niveaux 2, 3, 7 et 10, trois sponsors, formation et scenarios alternatifs.
Les memes assertions ont ete executees avant/apres en preparation : 14 echecs sur les sources historiques, puis 22 groupes reussis sur le candidat. La CI finale sur SHA exact demeure obligatoire.

Le banc #85 est repris sans enlever de campagne : 3 profils x 2 graines x 15 saisons, dont modeste/99173. La reproduction de l'oubli de frais devient une assertion d'egalite prevision/reglement. Les preuves de depassement artificiel restent negatives. Les runners continuent a refuser les campagnes incompletes et a conserver l'etat fictif en cas d'echec.

## Limites et sauvegardes deja affectees
Ce correctif previent le depassement ; il ne modifie ni n'importe silencieusement les anciennes sauvegardes invalides. La copie de recuperation existante reste preservee et necessite une procedure explicite sur copie si l'utilisateur rencontre deja ce cas. Aucune sauvegarde personnelle utilisee. Pas de test Windows natif ni de reequilibrage global revendique.
La source UI-02C #84 et les modules UI-03 du producteur restent hors perimetre. #75 reste intacte. Livraison uniquement apres PR non brouillon, CI complete verte et CI post-fusion.
