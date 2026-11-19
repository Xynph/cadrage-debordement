# UX Review : Centre des transferts et négociation

**Date** : 19/11/2026
**Reviewer** : méthode `/ux-review` appliquée par l'ux-designer (`/team-ui` phase 1c, mode autonome). Auto-revue : l'auteur de la fiche est aussi le relecteur ; une relecture indépendante reste conseillée avant l'implémentation.
**Document** : `design/ux/20-transferts.md`
**Checklist** : 3A (ligne `> **Template**: UX Spec`)
**Platform Target** : `project.yaml` n'a pas de bloc `platform` ; repli sur l'en-tête de la fiche et la fiche 09 : PC, souris + clavier, manette hors périmètre
**Accessibility Tier** : Standard, **engagé** dans `design/accessibility-requirements.md` (avec l'exception de densité FM du 19/11/2026)

## Passe 1 — verdict : NEEDS REVISION

### Completeness : 15/15 sections présentes
En-tête, but, contexte d'arrivée, navigation, entrées/sorties, mise en page (wireframes 1280×720 de 6 onglets + Négociation, tableaux de zones), états, carte des interactions, données, événements, transitions, entrées, accessibilité, localisation, critères d'acceptation (12).

### Quality Issues : 6
1. **Échap contredit la règle unique** [BLOCKING] — Critère « Échap ramène à la Réception » alors que §3 applique la règle de Léo (fenêtre, sous-écran, sinon pause). Fix : Alt+← (historique N3) pour revenir à la Réception.
2. **Report et rallonges absents de l'affichage du budget** [BLOCKING, GDD] — `budget-transferts.md` R5 et R3 bis demandent « Report de la saison passée » et « Rallonges accordées (n sur m) » ; le bandeau commun ne montrait que dépensé · reconstitué. Fix : infobulle du budget alignée sur la fiche 09 §6.1.
3. **Ordre de la file « À traiter » non défini** [BLOCKING] — élément principal des 5 secondes sans règle de tri ni de sortie. Fix : ordre fixe en 5 groupes, sortie seulement quand c'est traité (pas de délai).
4. **Raccourcis en conflit** [BLOCKING] — Alt+← / → proposé pour changer de chapitre et revenir d'une étape, alors qu'il porte l'historique (N3) ; Ctrl+Tab annoncé à la fois pour les chapitres et les onglets. Fix : chapitres au Tab (N2 n'a pas de raccourci), étape précédente Maj+Tab + Entrée, Ctrl+Tab réservé aux onglets.
5. **Prime à la signature dans la négociation entre clubs** [ADVISORY] — le moteur (`interclub_negotiate`) ne porte pas de prime ; le wireframe en affichait une. Fix : ligne retirée, étapes par type précisées.
6. **Plateforme non nommée dans l'en-tête ; dates du calendrier dans le désordre (31/01 avant 01/01)** [ADVISORY] — Fix : ligne « Plateforme », wireframe réordonné.

## Passe 2 (après corrections) — verdict : APPROVED

### Completeness : 15/15

### Quality Issues : 0 bloquant, 2 conseils
1. **Quatre projections moteur à créer** [ADVISORY] — `transfers.calendar`, `transfers.negotiations[]`, pré-contrats, `transfers.history[]` n'existent pas. La fiche le dit (§6.1, §14), donne le comportement en leur absence et n'invente aucune donnée côté interface : ce n'est pas un trou de spécification, c'est un ordre de livraison (budget, ventes, marché entre clubs d'abord).
2. **Questions de règle laissées au GDD du calendrier** [ADVISORY] — achat conclu d'avance hors période, date d'arrivée d'un achat en période : les deux états sont décrits, la règle tranchera lequel s'affiche.

### GDD Alignment : ALIGNED
- `budget-transferts.md` — refus écrit (R3), rallonge (R3 bis : montant arrondi au millier supérieur, effet −3/−1, n sur m), prolongation hors enveloppe (R2), report (R5), caisse libre (R6), budget inactif : couverts.
- `vente-joueurs.md` (PR #1009) — ligne de période, offre spontanée signalée, relance unique +5/10/15 %, blocage écrit avant le clic, confirmation W1 complète (caisse, effectif, compléments, budget +50 %, JIFF, feuille, conséquences légères), accords différés au 1er mai, courrier vers l'onglet : couverts (texte repris de la fiche 09 de la PR, non réécrit).
- Calendrier des mutations LNR et pré-contrats : **GDD pas encore écrit** ; la fiche couvre les règles fournies par Léo (31/12, 31/01 ×2, jokers, 1er mai – 30 juin, 6 derniers mois, 1er juillet) et marque la dépendance. À recontrôler quand le GDD paraîtra.

### Accessibility : COMPLIANT (palier Standard engagé)
- Couleur jamais seule (statut, étape, période, dépassement en mots), capture en niveaux de gris en critère d'acceptation.
- Contrastes 4,5:1 / 3:1, focus ≥ 2 px, ordre de focus défini pour le Centre et la Négociation.
- Densité FM avec échelle 90-130 % et comportement à 130 % décrit.
- Aucun délai imposé ni notification qui disparaît seule ; confirmations d'argent W1 focus sur Annuler.
- Tout au clavier, aucun raccourci à une lettre pendant une saisie.

### Pattern Library : CONSISTENT
- N2, N3, N5, E2, E3, W1, F2, F7, F8, F9 référencés sans être redéfinis ; déviations W1/W3 justifiées (décision de Léo).
- Trois nouveaux motifs signalés pour la bibliothèque : P1 écran à étapes, P2 colonne budget fixe, P3 file « À traiter ».

### Verdict : APPROVED
**Blocking issues** : 0
**Advisory issues** : 2 (projections moteur à livrer, règles du GDD calendrier à trancher)
**Dimensions not assessed** : 0

La fiche peut passer à `/team-ui` phase 2 (direction artistique). Elle ne doit pas être implémentée en entier avant le GDD du calendrier : commencer par Vue d'ensemble (sans calendrier complet), Offres reçues, Joueurs proposés et l'écran Négociation (joueur libre, entre clubs, prolongation).
