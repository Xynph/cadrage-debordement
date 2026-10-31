# R10 — Portail d'acceptation du mod et de la carrière

## Constat GitHub
Au démarrage de R10, main `a1d82ba4`; PR R2 #99, R3 #100, R4 #101 et R5 #102 fusionnées. PR empilées R6 #103, R7 #104, R8 #105 et R9 #106 ouvertes, l'intégrateur réserve le jeu `dist/**` et l'intégration des nouvelles carrières. Tests JavaScript des quatre PR de base réussis ; aucun workflow visible sur les têtes des PR empilées.

## Livraison
`tests/mod-r10-acceptance.cjs` est une **acceptation de chaîne technique hors moteur** : construit un ZIP réel (CRC32 valide), contenant un club fictif et une image fictive, le convertit avec le pont R8, installe les données via l'API R5 **simulée**, vérifie l'absence d'activation implicite, crée une carrière via R9, vérifie le lien ID/version après sérialisation, teste la reprise, puis vérifie que l'ancienne sauvegarde n'est pas mutée. Cas négatifs : JSON corrompu, empreinte image modifiée, CRC32 incorrect, mod absent, divergence de version et restauration de l'état après refus.

Le test **simule l'API R5** ; il ne prouve donc ni la compatibilité native avec le vrai module R5 ni le fonctionnement du jeu Windows/navigateur. Cette distinction doit être conservée dans tous les rapports.

## Critères restants avant FEU VERT de production
1. Fusion de R7 (#104) après R4, R8 (#105) après R7, R9 (#106) après R8 ; R6 (#103) après R5, avec CI complète du dernier SHA et post-fusion sur main.
2. Un adaptateur de normalisation du JSON R1/R2 vers un seul registre R5 ; aucun état global concurrent dans R3.
3. Raccordement par l'intégrateur des écrans (import ZIP, contrôle des images et affichage), sélection d'univers lors de la **création** de carrière, sauvegarde, fermeture et reprise.
4. Test Chromium/Windows **dans le jeu réel** : pack valide, pack altéré, joueur fictif, club fictif, retour au jeu initial, reprise version exacte, rejet version divergente, ancienne sauvegarde inchangée. Toute validation doit être attribuée à sa vraie source et son dernier SHA.
5. Le jeu de base reste fictif ; aucun contenu réel ou visuel tiers fourni.

Test R10 : `node tests/mod-r10-acceptance.cjs`. Aucune fusion par le producteur.
