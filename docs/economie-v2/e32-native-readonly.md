# Économie V2 E3.2 — audit et adaptateur natif strictement consultatif

**Statut : R&D, DRAFT.** Base E3.1, sans modification d'aucun fichier E1–E3.1, moteur, sauvegarde, PRODUCTEUR, MATCH 3D, DATA/LNR, gate ou main.

## Contrat de preuve, source native

L'adaptateur `ci/economy-v2-e32-adapter.cjs` reçoit la **série E2.4 `ci/economy-v2-obligations-run.cjs`** : quinze fins de saisons × quatorze clubs, dérivées des états `S.clubs` et `worldManagement.clubInfo` de la carrière. On affiche seulement les données effectivement disponibles : trésorerie, dette existante, masse salariale hebdomadaire, nombre de contrats avec échéance saisonnière connue et expirants. La méthode `tests/career-resilience/native.cjs` fournit un **snapshot initial séparé** des niveaux d'installations et de réputation ; les installations **ne sont pas** une série annuelle ni une annonce d'investissement.

Les valeurs absentes restent `null` : échéancier de comptes fournisseurs et salaires légalement exigibles, recettes futures confirmées, coût des projets facultatifs, gain sportif d'un projet. Le budget salarial 29 semaines est une approximation descriptive **et non une dette**. Une offre/une négociation n'est pas un contrat exécutoire, et un changement de club d'un joueur ne révèle pas son indemnité de transfert. Les structures `S.careerManagement.sponsor` et `academyInvestment` sont propres au club piloté, pas un calendrier fiable de projets et recettes des 14 clubs ; E3.2 n'en infère aucun coût ni encaissement. La dette `worldManagement.clubInfo[].debt` est réellement observée, mais son détail contractuel et ses échéances ne sont pas déduits de son solde.

## Interface PC

`node ci/economy-v2-e32-run.cjs reference 827381` crée `economy-v2-e32-reports/e32-reference-827381.html`, une page standalone et hors du jeu. Une section **natif** offre sélection des quatorze clubs, indicateurs dernière saison et tableau 15 saisons, avec mention des installations uniquement au départ. La section **E3.1** reste une comparaison avant/après de quatre scénarios SYNTHÉTIQUES, sans transposition à un club et sans commande de mutation. La séparation est explicite en texte et en code ; aucune promesse de solvabilité native n'est formulée.

## Preuves attendues

Le workflow E3.2 exécute trois profils × deux graines × quinze saisons natives via E2.4, et une campagne appariée E3.1 pour contrôler les séries et la parité état/checksum de sauvegarde ; ce sont **deux exécutions du même profil/graine**, pas 180 saisons indépendantes à annoncer. Chaque campagne doit conserver 435 tours, trois imports et 210 passifs non mesurables (quatorze clubs × quinze saisons). Tests de refus d'un payable imaginairement renseigné et du niveau d'installation hors borne, non-mutation des entrées, injection HTML et préservation de E3.1. Un job Chromium distinct réalise **les captures réelles 1920×1080 et 1440×900**, sélection de deux clubs, 15 lignes, trois choix E3.1, aucune erreur JS ni débordement horizontal. Aucun succès revendiqué tant que la CI du HEAD exact n'est pas terminée.

## Limites

Les données de bilan annuelles ne suffisent toujours pas à produire un échéancier de trésorerie des projets du club. Avant tout raccord métier, il faudra une provenance fiable des engagements datés, de vrais investissements volontaires et de leurs effets sportifs mesurés. Les termes HMAC locaux E2.9 ne constituent pas une autorité anti-rollback extérieure garantie sur PC offline. **Aucun READY, gate ou fusion**.
