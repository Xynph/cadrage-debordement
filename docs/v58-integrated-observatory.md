# V58 — Première intégration jouable, sans inventer de contrats

## Décision d'intégration

L'audit des PR #60 à #63 montre une chaîne de modules purs empilés : `coach-career` → `coach-negotiations` → `coach-contract-cycle`, fondée sur des profils et budgets fictifs. Le `main` actuel possède déjà `CDCoachMarket.dismissalRisk`, la confiance du manager, les changements de techniciens adverses et un validateur rigoureux de sauvegardes. **Copier les PR en bloc créerait une deuxième source de vérité** pour les postes et le budget et exigerait une migration des sauvegardes non conçue.

La première tranche de production est donc un **observatoire des bancs sous pression** dans le bureau du manager. Elle exploite les véritables `S.clubs` et `S.worldManagement.clubInfo`, et délègue le risque au calcul natif V48. Elle affiche les trois clubs adverses les plus exposés, sans créer de postes vacants ni de fausses offres et sans modifier l'état de carrière.

Fichiers :
- `dist/coach-opportunities.js` : API pure `CDCoachOpportunities.snapshot`.
- `dist/world-career.js` : affichage dans le bureau du manager.
- `dist/index.html` : chargement avant `world-career.js`.
- `tests/harness.cjs` : même chargement dans le jeu testé.
- `tests/v58-native-coach-opportunities.cjs` : tests sur la vraie carrière, contrôle des sauvegardes anciennes et refus d'état corrompu.

## Limites impératives et travaux suivants

Ce lot apporte un affichage **dans le jeu jouable**, pas encore un marché de recrutement du manager : aucun contrat de coach n'est créé, aucune candidature ni mutation n'est proposée et aucun profil artificiel ne se substitue aux vrais clubs. Les PR #60–#63 restent à trier avec le producteur; seules les règles réutilisables doivent être raccordées à la carrière réelle avec des transitions de club, UI, validations et migration de sauvegardes explicites. Le banc d'essai V58 initial n'est pas un test de la fonction complète dans le jeu.

Avant tout marché réel : contrôler qu'une seule direction peut posséder un poste, que les contrats n'impliquent pas deux écritures salariales, que le changement de club applique les règles de carrière, que les identifiants et durées sont validés au chargement, et que les anciennes sauvegardes restent ouvrables.

En cas de PR avec changement de sauvegarde, ce document ne suffit pas : effectuer plusieurs reprises réelles et les validations de sécurité de `saves.js`. Ne pas fusionner les prototypes empilés directement.
