## UX Review : Coque commune (auto-relecture, 2 passes)
**Date** : 2026-11-19 · **Reviewer** : ux-review (auto-relecture par le ux-designer, mode autonome) · **Document** : `design/ux/coque-commune.md`
**Checklist** : 3A (en-tête `Template: UX Spec`) · **Platform Target** : PC souris + clavier (config `project.yaml` non relue, en-tête repris) · **Accessibility Tier** : Standard (`design/accessibility-requirements.md`, engagé)

### Passe 1 : verdict NEEDS REVISION
Complétude : 15/15 sections présentes (Q&A, 13 localisation, 14 critères ≥ 5, 11 manette et tactile marqués non applicables).
Problèmes :
1. **États : chargement non documenté** [BLOQUANT] : la coque lit club, date, courrier à l'ouverture, aucun état d'attente. Où : §6. Correctif : ajouter chargement.
2. **Questions ouvertes sans décision ni motif de report** [BLOQUANT] : Q1 à Q4 étaient « Défaut » ou « Déféré » sans raison. Où : §15. Correctif : décision écrite ou raison du report.
3. **Contraste incomplet** [BLOQUANT] : touche « Ctrl K » posée sur `panneau-2` (fond de la touche dans le champ) absente de la table. Où : §12. Correctif : ajouter 8,16:1.
4. Pas de GDD propre à la coque [ADVISORY] : alignement GDD non applicable, le contrat vient des décisions de Léo et de la charte.
5. Bibliothèque de motifs [ADVISORY] : sept motifs changent (N1, N3, N4, N5, N6, F5, G1), listés dans « Écarts » ; la mise à jour de `interaction-patterns.md` reste à faire à l'implémentation.
6. Lecteur d'écran [ADVISORY] : annonces prévues mais hors palier engagé (Standard du projet) ; pas de contradiction.

### Corrections appliquées dans la fiche
- §6 : ligne « Chargement / données de club absentes » (coque posée à vide ≤ 200 ms, puis valeurs ; repli sans nom figé).
- §12 : `panneau-2` ajouté (8,16:1).
- §15 : Q1 et Q3 décidées en autonomie (révisables) ; Q2 et Q4 reportées avec motif (dépendent des sections et des écrans appelants).

### Passe 2 : relecture après corrections
- Complétude 15/15 ; états : repos, survol, actif, focus, désactivé, chargement, vide, erreur (sauvegarde), blocage, calcul documentés ; durée de l'auto-fermeture : aucune (la ligne « Sauvegardé » reste).
- Clavier : ordre de focus complet (barre, rail, contenu), toutes les actions souris ont un équivalent ; focus piégé dans le menu pause.
- Données : aucun propriétaire « UI » ; fréquence de mise à jour déclenchée par un événement nommé ; absence traitée pour chaque donnée.
- Événements : toute action change d'état ou de page est dans §9 (Menu, Échap, Continuer, Sauvegarde, Recherche).
- Accessibilité : Standard atteint (focus, contrastes chiffrés, couleur jamais seule) avec l'exception de densité décidée par Léo.
- Critères d'acceptation : 11 critères binaires, perf et résolution présents, aucun ne renvoie à un autre document.
- Cohérence avec les règles de Léo : R1 (continuer bloqué ouvre la cause, Précédent désactivé marqué explicitement), R2 (aucune fenêtre ajoutée ; menu pause et infobulles dans les exceptions).

### Accessibilité : COMPLIANT (palier Standard, exception de densité tracée)
### Alignement GDD : N/A (aucun GDD de coque)
### Pattern Library : INCONSISTENCIES FOUND, tracées dans « Écarts » (N1, N3, N4, N5, N6, F5, G1, plus charte §3C et §7.1) ; à reporter dans `interaction-patterns.md`

### Verdict : APPROVED
**Bloquants** : 0 · **Advisory** : 3 (points 4 à 6) · **Dimensions non évaluées** : 0
Réserve : Q1 (aide de Gabi devenue écran) et Q3 (bouton « +1 j ») sont des décisions prises en autonomie que Léo peut inverser ; Q2 (rail en sélection nationale, place d'Entraînement) reste à trancher avant l'implémentation de ces deux zones. La fiche est prête pour `/team-ui` Phase 2 (traitement visuel : `production/ui/coque-commune/visual-design.md`).
