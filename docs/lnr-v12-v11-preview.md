# Pré-raccordement Rugby Réel V12 + âge V11 — sans activation de production

## Dépendances GitHub contrôlées

- `main` vérifié au début : `8cfa697b6702f7183aa5b7a4790a7e7b9d399886`.
- PR [#374](https://github.com/Xynph/cadrage-debordement/pull/374) DRAFT, parent exact `81182f13d6c8954086a9e5d26e44d1cb9f10de45`. Revue V12 complète des **1 592 joueurs × 36 attributs**, projection 11 compétences, variante de profondeur douce retenue hors production.
- PR [#373](https://github.com/Xynph/cadrage-debordement/pull/373) DRAFT, HEAD exact `b099230c66641f9af06f40101fb67162db40b4b9` ; courbes annuelles candidates `tools/rugby-real-v11/aging.cjs`, recherchées et testées. État GitHub observé : `mergeable_state=dirty`. Aucun contenu de #373 modifié ; son SHA est épinglé dans la CI de ce prototype.
- Ruleset actif `26326518` sur main. Branches du producteur préservées ; la présente PR **empilée sur la branche #374** ne prétend pas être fusionnable directement dans main.

## Prototype exécutable et contrat d'activation proposé

`tools/lnr-v12-v11-preview/bridge.cjs` :
1. `candidate(master, report)` : applique V12 *une seule fois* sur le master en mémoire, puis la profondeur `mild` sur une copie. Aucun réempilement V6-V11 ; master inchangé.
2. `playerForNative(base, reviewed)` : conserve ID, groupe et **poste natif du générateur LNR** : remplacer le poste par celui estimé V12 rendait six postes de feuille incompatibles lors du premier test GitHub. Il remplace les 11 compétences par la projection des 36 attributs du joueur V12, sans ajouter une seconde note générale. Fixe `rating=skillBase=ratingV12`, si bien que `skill(p,k)=skills[k]+rating-skillBase` démarre sans bonus caché. Les six traits et le potentiel absolu historique restent identiques.
3. `initDevelopment(p, ensureDevelopment)` : conserve l'objet `dev` natif, historique, minute, fatigue et spécialisation existants, mais remplace **uniquement pour cette nouvelle carrière fictivement calibrée** le plafond `dev.potential` par `min(99, ratingV12+max(0,potentialHistorique-ratingHistorique))`. Cela préserve la réserve de progression **relative** historique, sans confondre les échelles ni réécrire `potential`. Un joueur déjà chargé dans une sauvegarde antérieure ne doit jamais passer dans ce convertisseur.
4. `evolveOnce(p, state, inputs, agingStep)` : consomme la courbe V11 à un seul passage annuel, re-projette les compétences depuis les attributs évolués, maintient `rating=skillBase` pour éviter une seconde addition de note et respecte l'idempotence `lastSeason`. **Contrat de raccordement, pas branchement réel :** dans `dist/development.js`, il faudrait ensuite **remplacer** le chemin `ageDevelopmentPlayer` et le moteur d'expérience V27 pour les nouveaux joueurs V12 plutôt que les additionner. Pas de second vieillissement, pas d'incrément implicite de `rating` dans `growPlayer`.
5. `alignRoster(original, selected)` : applique le mapping par IDs LNR stricts, conserve les joueurs de couverture natifs et refuse les identités absentes. Ne touche ni à l'ordre des équipes, ni au calendrier.

## Preuves GitHub

[Workflow dédié LNR V12/V11](https://github.com/Xynph/cadrage-debordement/actions/workflows/lnr-v12-v11-preview.yml) lancé sur la branche d'intégration. Les tests sont exécutés sur le véritable `tests/harness.cjs` utilisant `dist/lnr-career.js`, `dist/development.js`, `dist/rugby.js`, `dist/saves.js` et le moteur natif `createRugbyMatch → advanceRugby → applyMatchInjuries`.

La première CI a **réellement échoué** sur l'écrasement des postes (6 erreurs de feuille), correction faite en préservant `pos/fam` LNR. La deuxième a échoué sur une méthode de restauration incomplète du harness ; l'essai final importe via `parseSaveDocument` avec checksum, puis reconstruit l'état testé. Le test d'une **ancienne sauvegarde fictive** confirme qu'aucun enrichissement rétrospectif n'est effectué.

Le test final couvre : 1 592 IDs, rôles et attributs sur copies, 1 592 projections sans bonus, potentiel/traits invariants, vraie carrière TOP 14, feuille complète 15+8, vrai match, export puis lecture validée du JSON de sauvegarde LNR, ancien export fictif, cycle annuel V11, idempotence et refus d'une saison invalide. Il ne couvre **pas** une saison 2 LNR complète ou une sauvegarde réelle Windows.

## Blocages avant production et plan d'intégration

**STOP activation immédiate :**
- `dist/lnr-career.js:lnrGamePlayers` ne charge pas les 36 attributs. Ajouter un opt-in explicite/version de conversion, appliqué uniquement lors de création **nouvelle** carrière Rugby Réel au `01/07/2026`. Ne pas transformer les anciennes sauvegardes, qui doivent continuer à utiliser leur barème originel. Conserver positions natives jusqu'à l'audit sûr des groupes/qualifications de première ligne.
- `dist/development.js:ensureDevelopment`, `growPlayer`, `ageDevelopmentPlayer`, `rollDevelopmentYear` : un seul propriétaire de l'évolution par joueur. Conserver `dev` du moteur pour son suivi ; remplacer le calcul de variation annuel par V11 sous versionnement de carrière explicite, et recalculer les 11 compétences une seule fois depuis les 36 notes. S'assurer que les réserves de potentiel, les XP focalisés, les blessures, les retraites et les formations continuent à fonctionner : le prototype ne valide pas ces chemins sur plusieurs saisons.
- `dist/saves.js:validateCareer` refuse actuellement `saveInt(h.age,16,60)` alors que le mode LNR admet des joueurs âgés de 15 ans. La proposition isolée #373 `save-proposal.json` limite l'exception à LNR : `saveInt(h.age, s.lnrMode!==undefined?15:16, 60)`. Elle n'est **pas activée** ici ; les 14 ans restent refusés et les fictifs 15 ans refusés. Tester explicitement 3 imports sur 3 saisons et cas altérés avant patch.
- La sensibilité `tacticalEdge` 0,008 est testée seulement dans le harness de #374 et **ne doit pas** être propagée directement. Rejouer match, discipline, essais, fatigue, recrutement, départs et adversaires variés après raccordement ; pas de bonus division.
- La carrière senior actuelle ne simule pas les deux divisions avec promotion/relégation ; aucune fréquence de maintien ni remontée de saison n'a été testée.
- Synchroniser d'abord #374 (behind) et résoudre séparément le conflit #373 (dirty), sans modifier leurs branches sans coordination. Réserver les `dist/**` nécessaires auprès du développeur propriétaire avant toute modification, puis gate officiel uniquement sur HEAD exact.

**Décision intégrateur :** le prototype constitue une étape de compatibilité testée, **pas une activation prête pour fusion**. Ne fusionner ni cette PR, ni #374, ni #373 avant le raccordement de production réservé, la compatibilité des sauvegardes sur saisons réelles, le contrôle officiel et la CI post-fusion. Aucun bypass.
