# Revue UX 13 à 19 (commande /ux-review)

**Date** : 19/11/2026
**Reviewer** : ux-review skill (procédure de `.claude/skills/ux-review/SKILL.md`), corrections faites en tant que ux-designer
**Palier d'accessibilité** : Standard, engagé (`design/accessibility-requirements.md`)
**Plateforme** : PC souris + clavier ; manette hors périmètre (pas un motif de refus). Aucun bloc `platform` dans `project.yaml` et `technical-preferences.md` non configuré : entrées lues dans l'en-tête de chaque fiche et dans la consigne.
**Pattern Library** : `design/ux/interaction-patterns.md` existe (brouillon d'état des lieux).
**Hypothèse déclarée** : aucun GDD sous `design/gdd/` ni `docs/gdd/`, aucun `systems-index.md`. Par dérogation du projet, l'alignement est contrôlé contre `design/player-journey.md` (§ 1.3 et tableau des « 5 secondes »), `design/game-brief.md` (non relu en détail ici), `docs/rugby-rules-reference.md` et le code. Ce n'est pas un GDD : à dire clairement.
**Checklist assumée** : aucune fiche n'a de ligne `> **Template**:`. Classement par nom : `hud.md` → 3B ; les six autres → 3A (nom non reconnu = 3A par défaut de la procédure).

## Tableau de synthèse

| Fiche | Checklist | Verdict initial | Verdict après corrections | Problème principal |
|---|---|---|---|---|
| hud.md | 3B | NEEDS REVISION | **APPROVED** | Source de code déclarée introuvable (elle existe) ; TBD en §10.2 ; état avant-match absent |
| 14-match-entracte | 3A | NEEDS REVISION | **APPROVED** | Localisation, checklist d'entrée et critère de performance absents |
| 15-apres-match | 3A | NEEDS REVISION | **APPROVED** | Mêmes manques ; note du match sans source (rendue facultative) |
| 16-calendrier-classement | 3A | NEEDS REVISION | **NOT ASSESSED** | Zones promotion/relégation : règle « à documenter » dans `rugby-rules-reference.md` |
| 17-finances | 3A | NEEDS REVISION | **NEEDS REVISION** | « Disponible pour recruter » (but n° 2 des 5 s) sans aucune source dans le code |
| 18-club | 3A | NEEDS REVISION | **APPROVED** | Seuils de confiance non fixés (proposés), manques communs |
| 19-formation | 3A | NEEDS REVISION | **APPROVED** | Question bloquante « où se décide promouvoir / garder / libérer » : résolue par le code |

Constat commun aux six fiches 3A : sections « Localisation » (longueurs max), « Checklist de complétude des entrées » et critère de performance absents ; ajoutés en §13 de chaque fiche. Aucune fiche n'a de ligne `Template`, ce qui fait tomber le classement sur le nom de fichier (advisory : à ajouter).

---

## 1. hud.md (HUD du match 3D) — APPROVED après corrections

**Complétude 3B : 10/10.** Philosophie, architecture, zones avec marges, éléments, états par contexte, hiérarchie MUST/SHOULD/CAN/ALWAYS, budget visuel, plateformes, réglages, critères (plus de 5).

**Problèmes**
1. **Source du code déclarée introuvable** [BLOQUANT, corrigé]. La fiche disait ne pas trouver le code (`match_view`). `match_view.gd` est bien la scène 3D (terrain, stade, ballon) et ne contient aucun HUD ; le HUD vit dans `native/godot/ui/contextual/live_view.gd` (bandeau score/horloge, bouton PAUSE, ligne météo, barre de commandes, tiroir Stats/Journal) et `match_temps_forts.gd`. En-tête corrigé.
2. **Écart fiche / code** [ADVISORY, noté]. Le code a : ÉQUIPE, STATS, JOURNAL, TV, VUE DE DESSUS, CONTACT, Cadence ×1/×4/×12, CONFIER LA FIN À L'ADJOINT, VALIDER LA JOURNÉE → ; PAUSE dans le bandeau du score. La fiche décrit la cible (4 boutons). Le déplacement de chaque bouton existant est maintenant écrit dans l'en-tête.
3. **§10.2 : mesures « TBD »** [BLOQUANT, corrigé] : remplacées par des cibles à 100 % et 130 %.
4. **État manquant** [corrigé] : avant-match / tunnel ajouté au tableau des états (§5).
5. **Questions ouvertes** : emplacement du code et libellé « Sec » résolus (c'est la ligne météo `MatchWeather`, « Temps sec », coupée par `clip_text`).

**GDD / règles** : cartons, mi-temps, blessure : alignés sur `docs/rugby-rules-reference.md`. Aucun systems-index : justification d'absence non applicable.
**Accessibilité** : COMPLIANT sur le papier (D5, M4, S1, S3, S6, T2, C5 traités). Mesures de contraste et de surface HUD (§7) encore « à mesurer » : ce sont des critères de réception, pas des trous de spécification.
**Pattern Library** : N/A (pas de checklist de bibliothèque pour un HUD).
**Vérification code** : le directeur du match avale déjà Échap, F1, Ctrl+K, Alt+flèches pendant le direct (`director.gd`, `_input`) ; Espace / T / 1-3 n'existent pas : « à créer » est exact.

**Blocking** 0 · **Advisory** 3 (mesures à prendre sur capture ; écart de boutons à résorber à l'implémentation ; raccourcis Espace/T/1-3 à confirmer par Léo) · **Not assessed** 0.

---

## 2. 14-match-entracte.md — APPROVED après corrections

**Complétude 3A** : manquaient Localisation, Checklist d'entrée, critère de performance (ajoutés, §13). Le reste (but, contexte, navigation, disposition, états, interactions, données, transitions, accessibilité, critères) est présent.

**Problèmes**
1. **Localisation absente** [BLOQUANT, corrigé] : longueurs max ajoutées.
2. **Checklist d'entrée absente** [BLOQUANT, corrigé] : souris, clavier seul, manette hors périmètre.
3. **Critère de performance absent** [corrigé] : ouverture < 500 ms.
4. **Aucune capture 1920** [ADVISORY] : contrastes en « TBD », visuels non vérifiés. Rester un critère de réception.
5. **Mon XV passe sous le terrain « à < 1100 px »** [ADVISORY] : le minimum supporté est 1280 ; la règle ne sert que si la fenêtre est redimensionnée plus petit (E3). À confirmer.

**GDD / parcours** : ALIGNED avec journey § 1.3 et la ligne 14 (domination, changement, vitesse, Gabi). Décisions de Léo respectées (une seule mise en page, pas de « Passer », pas de sortie en plein match).
**Accessibilité** : COMPLIANT (D5 forme + numéro, D6 valeur à côté de la barre, M1 réduit, K1/K3).
**Pattern Library** : CONSISTENT ; un nouveau motif (barres face à face) est déclaré et déjà listé en « manquants » n° 1.

**Blocking** 0 · **Advisory** 2 · **Not assessed** 0.

## 3. 15-apres-match.md — APPROVED après corrections

**Problèmes**
1. **Localisation, checklist d'entrée, critère de performance** [corrigés, §13].
2. **Note du match et place au classement sans source vérifiée** [ADVISORY, rendu facultatif] : le bandeau affiche score + issue en mots (obligatoires) ; note et rang seulement si le moteur les fournit. Aucune case vide. Reste une question pour game-designer.
3. **Couleur seule pour le sens d'une raison** [déjà traité par la fiche] : le code (`_remplir_pourquoi`) colore en ivoire ou vert clair ; la fiche impose ▲ ▼ et le mot. À implémenter.
4. **Texte coupé à 2 lignes** (`max_lines_visible = 2`) [déjà traité par la fiche : 3 lignes + infobulle].
5. **Libellé du bouton de fin** [ADVISORY] : le code de `live_view.gd` dit « VALIDER LA JOURNÉE → », la fiche « VALIDER LE RÉSULTAT » (moteur). À aligner (ajouté en critère §13).
6. **Aucune capture de l'après-match** [ADVISORY].

**GDD / parcours** : ALIGNED avec journey n° 5 (3 raisons d'abord) et ligne 15.
**Accessibilité** : COMPLIANT sur le papier ; les 5 teintes de levier (`LEVIER_TEINTES`) restent à valider en contraste (le mot en capitales est toujours présent, donc pas de dépendance à la couleur).
**Pattern Library** : CONSISTENT (réutilise la décision « Échap ne quitte pas » ; motif manquant n° 1 pour les barres).

**Blocking** 0 · **Advisory** 4 · **Not assessed** 0.

## 4. 16-calendrier-classement.md — NOT ASSESSED après corrections

**Complétude 3A** : manquaient Localisation, Checklist d'entrée, critère de performance (ajoutés). États très complets (J0, saison, fin de saison, compétition non disputée, rivalités vides).

**Dimension non évaluable**
- **Zones de promotion / barrage / maintien / relégation (D4)** : la fiche s'appuie sur des règles « NON SOURÇABLE ». `docs/rugby-rules-reference.md` confirme que accession-relégation et mesures administratives « restent à documenter ». La fiche ne les invente pas (ajout §13 : zone affichée seulement si la donnée de la compétition la fournit). Le jugement « les zones sont correctes » n'est donc pas possible. Il faudrait : l'article de règle par compétition, ou une donnée de zone dans le moteur.

**Problèmes**
1. **Localisation, checklist d'entrée, performance** [corrigés].
2. **Échap** [ADVISORY] : la fiche écrit « retour, jamais pause » alors que le code ouvre la pause sur un écran racine (interaction-patterns #1). Marqué comme cible dans §13 ; décision de Léo.
3. **Onglets non capturés** (Phases finales, Statistiques, Palmarès, Échos, Carnet) [ADVISORY, déclaré par la fiche].
4. **Tableau hors socle** : migration annoncée par la fiche, non faite.

**Accessibilité** : COMPLIANT sur le papier (D2 forme V/N/D avec lettre, D4 liseré + libellé + légende, K1/K2, T1).
**Pattern Library** : CONSISTENT ; trois rangées d'onglets réduites à une (recommandation conforme au motif manquant n° 11).

**Blocking** 0 · **Advisory** 3 · **Not assessed** 1 (règles de zones).

## 5. 17-finances.md — NEEDS REVISION

**Problèmes**
1. **« Disponible pour recruter » n'a aucune source** [BLOQUANT, non corrigeable ici]. C'est le but n° 2 des 5 secondes. La fiche dit « budget transferts (à confirmer) » ; une recherche sous `native/` (budget de transferts, recrutement) ne trouve aucune notion. Seuls `finance.cash` et `finance.wage` sont attestés. Il faut que game-designer / économie définisse la valeur, ou que le but n° 2 soit reformulé en « marge salariale » (déjà proposée dans la fiche). Tant que ce n'est pas fait, le bloc affiche « Budget non fixé ».
2. **Seuils du verdict** [corrigé, à confirmer] : « vert / tension / rouge » définis en §13 à partir des états de §5 (marge ≥ 0 ; marge < 0 et projection ≥ 0 ; trésorerie ou projection < 0), comme réglages de données.
3. **Localisation, checklist d'entrée, performance** [corrigés].
4. **Cinq onglets non capturés ; source des champs au-delà de `cash` et `wage` non vérifiée** [ADVISORY].
5. **« Classement » dans Finances : de quoi ?** [ADVISORY, question ouverte].

**GDD / parcours** : GAPS FOUND (journey ligne 17 : « combien il peut dépenser »).
**Accessibilité** : COMPLIANT sur le papier (verdict mot + icône, signe +/−, barres hachurées).
**Pattern Library** : CONSISTENT (W1 : confirmation avec focus sur Annuler).

**Blocking** 1 · **Advisory** 3 · **Not assessed** 0. À faire : [`/ux-review`] relancé après décision sur la source de « disponible pour recruter ».

## 6. 18-club.md — APPROVED après corrections

**Problèmes**
1. **Seuils de confiance (Solide / Fragile / Menacé) non fixés** [BLOQUANT, corrigé comme proposition] : ≥ 70 / 40-69 / < 40, réglages de données à confirmer par game-designer ; le chiffre /100 reste toujours affiché.
2. **Localisation, checklist d'entrée, performance** [corrigés].
3. **Trois onglets non capturés** (Direction, Infrastructures, Histoire) [ADVISORY] : leur contenu n'est pas spécifié ici.
4. **Deux « Entraîneur principal »** [ADVISORY] : doublon de données possible, question pour game-designer.
5. **Libérer un membre du staff** : spécifié avec confirmation, coût, focus sur Annuler. Il faudra vérifier que la commande existe côté moteur à l'implémentation.

**GDD / parcours** : ALIGNED avec la ligne 18.
**Accessibilité** : COMPLIANT sur le papier (D6 jauge + mot + seuil, C5 voile sur photo, T1).
**Pattern Library** : CONSISTENT (réutilise W1, motif manquant n° 6, onglets n° 11).

**Blocking** 0 · **Advisory** 3 · **Not assessed** 0.

## 7. 19-formation.md — APPROVED après corrections

**Problèmes**
1. **Question « bloquante pour la spec » : où se décident promouvoir / garder / libérer** [BLOQUANT, résolu par lecture du code]. Promouvoir : commande `academy_promote` (`academy_pathways_view.gd`, avec confirmation chiffrée), atteinte aujourd'hui par « Préparer une intégration » (`academy_canvas.gd`). Garder / Libérer : `academy_intake_confirm` (`academy_intake_view.gd`), à l'arrivée de la promotion seulement. Aucune libération hors de ce moment trouvée. La fiche (§13) en tire : Promouvoir toujours disponible (si place pro), Garder / Libérer seulement pendant la revue d'effectif, boutons absents sinon.
2. **Libellé de critère §11** [corrigé par §13] : reformulé selon ce qui existe.
3. **Localisation, checklist d'entrée, performance** [corrigés].
4. **Quatre onglets non capturés ; suivi individuel « Indisponible »** [ADVISORY].
5. **Libérer à tout moment** : nouvelle commande moteur, non requise ici ; arbitrage Léo.

**GDD / parcours** : ALIGNED avec la ligne 19 une fois la correction faite.
**Accessibilité** : COMPLIANT sur le papier (statut mot + icône, progression signée, 13 px des tableaux, D3).
**Pattern Library** : CONSISTENT.

**Blocking** 0 · **Advisory** 3 · **Not assessed** 0.

---

## Questions pour Léo (arbitrages, sans blocage)

1. **Raccourcis en match** : Espace = Pause / Reprendre, T = Équipe, 1/2/3 = caméras pendant le direct (hud, 14).
2. **Page Centre** : la retirer du rail tant qu'elle n'a aucune action (19). **Résolu le 19/11/2026 : retirée.**
3. **Suivi des jeunes** : le fusionner dans l'onglet Progression de Formation (19). **Résolu le 19/11/2026 : fusionné dans Formation.**
4. **Onglets** : garder trois pages avec une seule rangée d'onglets (16), plutôt que fusionner Classements et Calendrier.
5. **Replier le multiplex et le classement en direct sous PLUS** dans l'entracte (14).
6. **Échap sur un écran racine** : retour ou menu pause (16, interaction-patterns #1). **Résolu le 19/11/2026 : Échap ouvre le menu pause (après fenêtre, puis retour de fiche), et le menu est aussi accessible par un bouton visible dans la coque.**
7. **Libérer un jeune hors de la revue d'effectif** : oui ou non, avec une nouvelle commande moteur (19).
8. **Gabi après victoire** : nomme-t-il toujours une cause négative ? (15)
9. **« Disponible pour recruter »** : quelle valeur (budget de transferts ? marge salariale ?) (17). **Résolu le 19/11/2026 : « Budget de transferts », distinct de la trésorerie ; évolution moteur à spécifier (game-designer / economy-designer).**
10. **Zones de classement** (16) : **Résolu le 19/11/2026 : zones lues par compétition dans les données, comme dans la réalité ; documentation à écrire dans `docs/rugby-rules-reference.md`.**

## Fichiers modifiés par la revue (sans commit)

`design/ux/hud.md` (corrections dans le texte), et section « 13. Ajouts de la revue UX » ajoutée à `14-match-entracte.md`, `15-apres-match.md`, `16-calendrier-classement.md`, `17-finances.md`, `18-club.md`, `19-formation.md` ; une ligne de question ouverte mise à jour dans 15 et 19.
