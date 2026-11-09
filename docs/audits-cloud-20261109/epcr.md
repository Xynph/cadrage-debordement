# Audit EPCR — inscriptions et feuille — 9 novembre 2026

Audit en lecture seule du jeu sur les sources identiques au main e2f111a2330462aa6545866441289346ac92f2d0 (checkout courant 616a608, correctif de test Godot sans changement du moteur). Aucun changement du code, aucune PR ni message GitHub.

## Saison et sources

Le natif Monde débute en **2026–2027** : `world-career.cjs` fixe `startYear:2026`, les coupes utilisent `season:2026+s.season-1`, `world-model.cjs` expose ces années. Les éditions v1 à v5 portent des profils `world-pro-2026-27-*`. Le profil de lois de match historique et l'édition des compétitions demeurent deux sujets différents.

Sources officielles lues intégralement par Firecrawl, réponses HTTP 200 le 09/11/2026, pages explicitement titrées « summary of the rules for the 2026/27 » :

- Champions Cup : https://www.epcrugby.com/champions-cup/champions-cup-rules
- Challenge Cup : https://www.epcrugby.com/challenge-cup/ecc-rules

Les pages sont des **résumés officiels**, sans date de publication affichée. La saison 2026/27 est attestée dans le corps ; le texte complet du règlement/handbook n'a pas été récupéré. Aucune règle 2025/26 n'est supposée reconduite. La recherche et les deux lectures officielles ont fonctionné via Firecrawl ; cela ne certifie pas que curl depuis l'exécuteur peut joindre les mêmes domaines.

## Prescriptions communes vérifiées

| Section | Citation courte | Conséquence sûre |
| --- | --- | --- |
| 3.1 | « a squad of up to 42 players » ; « a minimum of 10 ... front row » | Liste de compétition distincte de l'effectif sous contrat, maximum 42 ; minimum 10 joueurs capables de première ligne. Première inscription : jeudi **8 octobre 2026**. Enregistrement régulier auprès du club et de l'Union requis. |
| 3.2 | « between 19 and 23 players for each match » | Le résumé admet 19 à 23 ; 23 est donc un sous-ensemble valable, pas une obligation EPCR universelle. |
| 3.3 | « a minimum of six front row players » | Feuille avec couverture des trois postes au premier remplacement. Ne pas assimiler fam « avants » à une qualification. Si absence de remplaçant qualifié provoque mêlées non disputées, le joueur sorti ne peut être remplacé. |
| 3.4 | « up to five Additional Players during the pool stage, each to replace a player previously registered » | Cinq remplacements d'inscrits pendant les poules ; réinscription des joueurs retirés possible à la place de leur remplaçant. |
| 3.4 | « a three-month contract » ; « must not have played for another club in the same tournament » | Il faut une preuve de durée contractuelle et d'apparition pour un autre club dans le tournoi ; la seule appartenance actuelle ou la nationalité ne suffit pas. |
| 3.4 | « by 12 noon (GMT) on the Wednesday before the match » | Date limite des inscriptions additionnelles : mercredi 12 h GMT avant rencontre. L'heure du PC ne doit jamais décider l'éligibilité de la carrière. |
| 3.5 | « Second Registration (25 March 2027) » ; « up to three players » | Deuxième inscription : 25 mars 2027, trois joueurs supplémentaires. Ne pas inventer à partir du résumé si le plafond 42 est porté à 45 ou quelles exceptions détaillées s'appliquent. |
| 7.1 | « Thursday before a Friday match » ; « Friday before a weekend match » | Annonce feuille 12 h GMT jeudi pour vendredi, vendredi pour week-end ; modifications limitées aux circonstances exceptionnelles. Le résumé ne détaille pas celles-ci. |

## Confrontation au moteur

- `native/engine/world-competitions.cjs:rules()` cite déjà les pages EPCR, et traite format, bonus, classements et élimination. Il **ne comporte pas** de registre de joueurs EPCR.
- `native/engine/world-career.cjs:worldSetup()` construit `worldMode.europe[id]` avec `pools`, `phase`, `champion`, `finalist`, puis `seeds/transfers` de **clubs**. Ces transferts de clubs vers Challenge ne sont pas des inscriptions de joueurs.
- `native/engine/world-model.cjs` projette les poules et les phases mais aucune liste de joueurs inscrits / remplacement / deadline EPCR.
- `native/engine/worker.cjs:COMMANDS` n'a pas de commande d'inscription EPCR. `begin_match` appelle le moteur et effectue un rollback si le coup d'envoi est refusé ; aucune garde spécifique EPCR observée.
- `dist/rugby.js:sheetErrors()` impose 15 titulaires et 8 remplaçants, unicité, disponibilité et postes. `slotEligible()` distingue pilier gauche/droit et famille talonneur ; `benchEligible()` garantit les trois premières lignes de remplacement. C'est une base pour la couverture de poste, **pas une preuve d'inscription européenne**.
- `japan-eligibility.cjs` est un exemple utile de module pur (inscription, feuille, substitutions et solveur), mais ses quotas japonais ne doivent jamais être utilisés pour l'Europe.
- `world-career.cjs` valide strictement les clés de `worldMode` et reconstruit les compétitions à l'import : ajouter une liste persistante n'est pas une petite propriété libre. L'édition exacte et les sauvegardes anciennes doivent être préservées.
- Les contrats courants sont souvent décrits par échéance de saison (`contractEnd`) ; aucune preuve suffisante observée pour en déduire systématiquement une durée de trois mois ou l'horodatage de signature d'un renfort. Des échéances réelles de départ existent dans le lot contrats, mais cela ne remplace pas l'historique d'inscription et d'apparition EPCR.

## Lots recommandés

### Lot minimal indépendant, implémentable sans migration

Un module pur `native/engine/epcr-eligibility.cjs`, tests `tests/epcr-eligibility.cjs` et documentation `docs/epcr-eligibility-2026-27.md` :

1. Profil explicitement fixé à 2026/27 avec sources et sections ; refuser une saison non couverte plutôt qu'extrapoler.
2. Validation d'une liste fournie : IDs uniques, maximum 42, minimum 10 premières lignes attestées.
3. Validation d'une feuille fournie : 19–23, 15 titulaires, IDs uniques présents sur liste, minimum six premières lignes et couverture PG/T/PD attestée.
4. Rapports structurés distinguant erreur certaine et information manquante. Pas d'inférence « inscrit » depuis « au club ».
5. Tests limites 18/19/23/24, 41/42/43, 9/10 premières lignes, faux spécialiste, doublon, joueur absent de liste, couverture manquante ; non-mutation de toutes les entrées.

Ce lot constitue une fondation testée, **pas encore une fonctionnalité jouable ni un système d'inscription conforme de bout en bout**. Un premier raccordement de projection peut afficher « inscription non suivie » pour les anciennes éditions au lieu de bloquer artificiellement leurs matchs.

### Lot jouable suivant, partagé avec l'intégrateur

Nouvelle politique/édition de carrière, registre EPCR persistant par club et compétition, command API, projection et écran de gestion ; sélection IA respectant les listes ; garde de coup d'envoi pour les deux équipes. Chemins communs probables : `worker.cjs`, `world-career.cjs`, `world-model.cjs`, `world-editions.cjs`, chargeur/runtime natif et scripts UI. Ne pas les modifier en parallèle avec URC/Pacifique sans coordination.

La première liste doit être choisissable avant le 8 octobre. Les renforts de poules doivent enregistrer qui remplace qui, le temps de carrière, la durée contractuelle et les apparitions interclubs. La seconde inscription ne doit pas être extrapolée en « 45 permanents » sans texte complémentaire. Conserver les anciennes carrières sur leur ancienne politique ou fournir une migration explicite et testée ; ne jamais réécrire silencieusement leur histoire.

Tests indispensables du raccordement : vraie création Monde, liste et feuille pour les deux clubs, refus atomique et RNG/disque inchangés, marché après deadline, blessure entraînement avant coup d'envoi, apparition avec autre club, mercredi 11:59/12:00 GMT, réinscription, seconde fenêtre, export/import/réouverture, transition saison 2, anciennes éditions non modifiées. `tests/world-worker-season.cjs` et les tests natifs de sauvegarde sont des bases pertinentes ; ne pas confondre `tests/world-career.cjs` (gestion historique web) et les tests du natif Monde.

## Ce qui reste à confirmer avant le lot jouable complet

Handbook consolidé EPCR 2026/27 et exceptions ; sens exact de « three-month contract » (durée contractuelle, pas ancienneté acquise) ; plafond de liste après seconde inscription ; règle de changement Champions/Challenge pour un joueur déjà apparu ; éléments de qualification de première ligne attestables dans nos fixtures ; représentation de l'heure et des dates dans les semaines du moteur ; gestion des saisons futures (politique figée explicitement, jamais présentée comme règlements futurs officiels).

Aucun test moteur exécuté pendant cet audit documentaire. Aucun code, donnée, profil ou sauvegarde modifié.
