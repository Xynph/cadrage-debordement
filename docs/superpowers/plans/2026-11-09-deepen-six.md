# Approfondir six chantiers — Implementation Plan

> **For agentic workers:** Use superpowers:subagent-driven-development for implementation and independent review.

**Goal:** Transformer les premières tranches en choix plus profonds et réellement jouables, puis recevoir la CI complète du dernier commit publié sans terminer sur un résultat en attente.
**Architecture:** Six worktrees depuis1e26758 ; domaines natifs isolés, hooks et transactions centralisés par root. Design détaillé et tests de chaque lot dans docs/deepen-*.md. L’utilisateur a autorisé la poursuite autonome sans questions routine.
**Tech Stack:** Node22/CJS et Godot4.7.2, moteur existant hors ligne.
**Spec:** Comparatif concurrentiel et demande utilisateur « ne t’arrête pas tant que c’est pas tout bon ; approfondis les différents sujets ». Les choix de périmètre ci-dessous sont ceux du constructeur, fondés sur les limites documentées de la première livraison.

## Global Constraints
- Aucun service payant ou réseau nécessaire au jeu, ni donnée officielle inventée.
- Anciennes sauvegardes préservées ; domaines persistants neufs explicitement activés et strictement validés.
- Pas de modification rétroactive du budget d’une carrière sans accord explicite dans le jeu.
- Vraies mesures, jamais de statistique individuelle ou causalité fabriquée.
- Un seul intégrateur/publieur ; aucune fusion pendant cette intervention.
- Source de la PR424 :1e2675809cabd6c0351cced1795c951b08ae6168 ; main e38a79f vérifié.

## Review Focus
- Marché : un seul gagnant/contrat, argent conservé, commandes périmées et refus atomiques.
- Staff : salaire explicite, paiement unique, pas double prélèvement, redressement possible et anciennes carrières inchangées.
- Historique : minutes/scènes attribuables, capture unique, champs inconnus affichés comme tels, bornes/imports/mobilité.
- Jeunes : fenêtre récente reconstruite sur observations disponibles, priorité des plans et absence de bonus cumulés.
- Relecture : chronologie locale sans mutation du vivant, changement de contexte ferme ancien lecteur.
- Personnalisation : calendrier réellement supporté, compatibilité sauvegarde/saison2 et pas d’altération silencieuse de compétition officielle.

## Tâches
- [x] Marché : offres modifiables, réponses motivées et concurrence IA réelle sur cibles sous contrat. Fichiers interclub-market.cjs et interclub_market_view.gd.
- [x] Staff : nouveau staff-employment.cjs optionnel, salaires/barèmes fictifs transparents, contrats, prévision et résiliation soutenable, UI Staff.
- [x] Analyses : nouveau player-match-history.cjs, activation explicite, capture mesurée après match, vue individuelle et ratios si minutes fiables.
- [x] Jeunes : bilans récents, objectifs courtterme et liens opérationnels vers prêt/promotion existants, youth-development.cjs et vues dédiées.
- [x] Match : chronologie/repères des consignes et actions, lecture locale utile sans nouveau plaquage fictif, match_action_review.gd et Journal.
- [x] Éditeur : custom-competition.cjs, parcours de création fictive effectivement jouable sur périmètre compatible avec le moteur, preview/confirmation/reprise/saison2.

Chaque agent lit l’existant, écrit son design/plan, reproduit une absence/erreur par test, implémente, vérifie les tests utiles et livre un commit. Root reçoit ses interfaces avant de modifier les fichiers partagés. Revues indépendantes croisées après livraison.

## Intégration
- [x] Recevoir la CI de1e26758 pendant le développement (run42660255878).
- [x] Intégrer domaines et commandes, adaptateurs création/validation nécessaires et UI réellement accessible classique/immersive.
- [x] Tester combinaisons, imports, refus disque, reprise et transitions sur le vrai worker ; recevoir Godot sur routes réelles.
- [ ] Publier une seule tête finale avec journal complet, recevoir sa CI intégrale et le gate officiel sans fusion.

## Journal de réception (reprise)
- CI de base1e26758 reçue SUCCESS, run42660255878 ; elle ne valide pas les approfondissements locaux.
- Marché reçu edef2665→e14f7ef ; borne salaire IA96c18d1→a62b445 revue scoped clean. Compat profondeur fiction30 en finalisation par agent market, garder37référence.
- Staff91c7b0f→8ca8ce6 ; provision8paies b86721e→bcb8ad4 ; vrai client adoption/paie/rupture4ed74f→b15baae (141contrôles). Recrutement/prolongation avec durée conservée après refus en finalisation agent staff.
- Analyses2ba21aa→b9d990f ; borne23paréquipe+vrai client43contrôles e02019e→855506d. Revue receive_market clean après ces deux corrections.
- Jeunes791e66d→1f785ae (36tests,147contrôles UI, prêt/promotion réels) ; brouillons annulation/refus d36f1fa→77b03af (88contrôles), revue numérique marché clean, revue UX finale encore à confirmer.
- Match7caed68→0df1620 (51contrôles vrai client, régressions43/297). Revue analytics clean.
- Éditeur0a72d6d→217e3f8 ; UI/coreweb5b9e67d→50b6a3c ; final doc/tests c23eaca→d02e1cf (182matches,S2native+web,50contrôles UI). Revue receive_market clean. Root a corrigé présentation custom et titre dans model/worker noncommittés.
- Root partagé NONCOMMITTÉ : domaines customCompetition/staffEmployment/playerMatchHistory dans native-systems ; worker new_career custom, negotiation avant horloge/persist avec garde état/seed/store, titrecustom ; main garde InterclubMarket après refus ; model présentation custom canonique.
- Root premier regroupement backend :22tests PASS, log /tmp/deepen-first-integration.log.
- Test nouveau tests/deepen-six-integration.cjs combine carrière custom+staff payé+mentorat+plan jeune+enchère+historique individuel+reprise/import. Rouge actuel légitime : aucun candidat disponible sous garde37dansnouvellefiction30. Agent market ferme ce défaut d’accessibilité sans rabaisser populationglobale37.
- Exigence utilisateur réaffirmée : ALLER AU BOUT DES SIX CHANTIERS en parallèle, ne pas finir sur CI en attente. Après corrections et revues finales, tests backend/UI combinés adaptés, commit/push unique, CI complète exacte puis gate sans --merge. Aucune fusion autorisée dans cette intervention.

## Verdict local final
Tous les domaines et correctifs de revue intégrés. Profondeurfictionb0c7f6→0845b41, transportstaffda22c5a→ecd58f7 reçus et relus ; historique23/équipe et vraieUIe02019e→855506d ; draftsjeunesd36f1fa→77b03af. Root57testsbackendPASS et12recettesGodotPASS sansskip. Testcroisécustom+salaires+mentorat+jeunes+enchère+historique+reprise/importPASS. Revueséditeur,staff,marché,analytics,jeunesse,match etinterfacesroot reçues sans blocage restant. CI complète exacte finale à recevoir après publication, sans arrêt anticipé.
