# Vérification transversale V46–V51

Cette branche **isolée de main** ne modifie aucun module existant. Son test `tests/v46-v51-contracts.cjs` vérifie les exports et le comportement pluriannuel quand les modules V46–V51 sont présents **ensemble**. En leur absence, il affiche explicitement `SKIP` et la liste des dépendances absentes : il ne prétend jamais à une validation de l'interopérabilité.

## Pour l'intégrateur
1. Assembler les SHA vérifiés des PR #40 à #44 et #46 sur une branche de test.
2. Exécuter `node tests/v46-v51-contracts.cjs` et la totalité de la CI.
3. Corriger tout désaccord d'API et vérifier les anciennes sauvegardes du jeu.
4. N'autoriser la fusion qu'après succès effectif des tests et procédure `ci/release-gate.cjs`.

Le test ne modifie pas les sauvegardes. Les finances et les scores sont fictifs. Le `SKIP` attendu sur main ne constitue **pas** une réussite des tests inter-PR.
