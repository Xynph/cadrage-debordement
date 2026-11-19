# Revue UX (/ux-review) — fiches 07 à 12

**Date** : 19/11/2026
**Reviewer** : ux-review skill, mode autonome, rigueur `minimal` ; corrections faites en tant que ux-designer (le kit révise, il ne jette pas)
**Documents** : `design/ux/07-effectif.md`, `08-fiche-joueur.md`, `09-recrutement.md`, `10-composition.md`, `11-preparation.md`, `12-avant-match.md`
**Checklist** : 3A (UX Spec) pour les six. Aucune fiche n'avait la ligne `> **Template**:` ; classées par nom (autre que `hud.md` / `interaction-patterns.md` → 3A). La ligne `> **Template**: UX Spec` a été ajoutée aux six.
**Plateforme** : PC, souris + clavier ; manette hors périmètre (non retenue comme motif de refus, comme demandé).
**Palier d'accessibilité** : Standard, engagé (`design/accessibility-requirements.md` présent).

## Sources de vérité utilisées

- Palier : `design/accessibility-requirements.md` (engagé).
- Motifs : `design/ux/interaction-patterns.md` (présent, donc dimension Pattern Library évaluée).
- Alignement « GDD » : **`docs/gdd/` est vide** (aucun GDD, aucune section « UI Requirements » à croiser). Comme l'instruction le désigne, `design/game-brief.md` et `design/player-journey.md` (§1 et §2, lignes 07 à 12 et friction §3) servent de référence d'alignement ; `docs/rugby-rules-reference.md` (loi 3) pour la composition. Si l'on exige un GDD au sens strict, la dimension « GDD Alignment » serait NOT ASSESSED ; je la rapporte alignée sur ces substituts désignés, pas sur un GDD.
- Aucune lecture du moteur Godot n'a été faite (consigne) ; un seul fait de code a été relevé par recherche de texte (bouton « Préparer la causerie », `match_avant.gd`).

## Tableau récapitulatif

| Fiche | Verdict initial | Verdict après corrections | Problème principal |
|---|---|---|---|
| 07 Effectif | NEEDS REVISION | **APPROVED** | Ctrl K détourné de l'accès rapide ; points forts absents du panneau (journey §2) ; sections manquantes |
| 08 Fiche joueur | NEEDS REVISION | **APPROVED** | Pas de table de sources ; sections manquantes ; wireframe 3/2 au lieu de 3/3 |
| 09 Recrutement | NEEDS REVISION | **APPROVED** | Budget de recrutement présenté comme acquis ; file de fins de contrat absente du bloc ; sections manquantes |
| 10 Composition + plan | NEEDS REVISION | **APPROVED** | Annulation en 8 s (K7/M6) ; propriétaire du brouillon contradictoire ; page Plan de jeu sans états |
| 11 Préparation + entraînement | NEEDS REVISION | **APPROVED** (réserve sur la partie B) | Wireframes incohérents (jour de match) ; libellé de poste/secteur contradictoire ; partie B lue dans le code seul |
| 12 Avant-match | NEEDS REVISION | **APPROVED** | Garde-fou Espace contredit par le focus initial sur le bouton |

Communs aux six (corrigés dans les fiches) : pas de ligne Template ; pas de section Transitions (entrée/sortie), Localisation (longueurs maximales) ni bloc « Entrées » ; critère de performance (écran ouvert en < 200 ms) absent ou partiel ; ratios de contraste non écrits ; déviation d'Échap vs N5 non listée (09, 10, 11, 12).

---

## UX Review : 07 Effectif

### Completeness : 15/15 après corrections (11/15 avant)
- Ajoutés : Transitions, Localisation, bloc Entrées (§11 bis), critère de performance déjà présent (< 200 ms), ratios de contraste (§9).
- Events Fired : limité aux deux événements de §6.5 (`ContractNegotiationRequested`, `OpenPlayerSheet`) ; le reste est de l'état d'interface (tri, filtre, sélection, explicitement sans commande moteur) : explication nulle présente.

### Quality Issues : 4 trouvés, 3 corrigés
1. **Ctrl K détourné** [BLOCKING, corrigé] : §7 donnait « / ou Ctrl K = recherche locale », alors que Ctrl K / Ctrl F sont l'accès rapide global (N4/N5) et que le pied de page annonce « Ctrl K Chercher ». Corrigé : « / » seul pour la recherche locale, Ctrl K inchangé.
2. **Points forts absents** [BLOCKING, corrigé] : journey §2 (07) demande « voir ses points forts et son état » ; le panneau n'en montrait pas. Ajouté : 3 points forts (mêmes clés que la fiche 08).
3. **Échap ambigu** [ADVISORY, corrigé] : §3 disait « ne fait rien d'autre » puis « n'ouvre pas la pause tant qu'un filtre est actif ». Ordre de priorité écrit ; comportement sans filtre = actuel jusqu'à la décision de Léo.
4. **Compteur « Aptes » ouvre « Tous »** [ADVISORY, non corrigé] : un filtre « Aptes » serait plus honnête ; consigné en question ouverte.

### GDD Alignment : ALIGNED (sur journey + brief)
- Journey 07 : trouver (recherche, filtres, tri), points forts, état, fiche : couvert (après ajout des points forts). Friction §3.4 (file de contrats) : vue « Contrats » + compteur.
- Manque restant : écran de comparaison appelé d'ici non spécifié (question ouverte ajoutée, vaut pour 08 et 09).

### Accessibility : COMPLIANT (Standard)
- Focus order, focus ≥ 2 px distinct, couleur non seule (statut en mots, D1/D3/D6), ratios écrits (C1/C3), tri et comparaison au clavier, aucun glisser-déposer.
- **Réserve (arbitrage Léo)** : hauteur de ligne 32 px (K6) contre 28 px actuel. Ne bloque pas ; critère d'acceptation ajouté.

### Pattern Library : CONSISTENT
- N1, N5, E2, E3, F3, F8 référencés ; déviations E3, N5, E2 listées ; « menu rapide » (manquant n°4) et onglets Ctrl+Tab (manquant n°11) signalés comme nouveaux.

### Verdict : APPROVED (après révision)
**Blocking** : 0 restant (2 corrigés) · **Advisory** : 1 restant · **Dimensions not assessed** : 0

---

## UX Review : 08 Fiche joueur

### Completeness : 15/15 après corrections (11/15 avant)
- Ajoutés : table Sources/rafraîchissement/absence (§6.4 bis), Transitions, Localisation, Entrées (§11 bis), critère de performance, ratios de contraste.

### Quality Issues : 3 trouvés, 3 corrigés
1. **Aucune source ni propriétaire de donnée** [BLOCKING, corrigé] : §6.1 donnait format et absence, pas la source. Table ajoutée, « l'interface ne possède aucune de ces données ».
2. **Wireframe 3 forts / 2 faibles** [ADVISORY, corrigé] : le texte dit 3 et 3 ; ajout de « Passe 49 ».
3. **Comparer sans écran** [ADVISORY, non corrigeable ici] : écran de comparaison non spécifié ; question ouverte.

### GDD Alignment : ALIGNED
- Journey 08 (poste, niveau, potentiel, état, contrat ; prolonger, comparer, retour) : couvert, y compris le verdict en une ligne.

### Accessibility : COMPLIANT (Standard)
- Texte ≥ 14 px (13 px tableau), D3 blessure icône + gravité en mots, D6 chiffre + repère, focus visible, tout au clavier, ratios écrits.

### Pattern Library : CONSISTENT
- N2, N5, F3 déviés explicitement ; onglets avec Ctrl+Tab (manquant n°11).

### Verdict : APPROVED (après révision)
**Blocking** : 0 restant · **Advisory** : 1 restant (écran de comparaison) · **Dimensions not assessed** : 0

---

## UX Review : 09 Recrutement

### Completeness : 15/15 après corrections (11/15 avant)
- Ajoutés : bandeau « fins de contrat » (§6.1 bis), Transitions, Localisation, Entrées (§11 bis), critère de performance, ratios de contraste, durée du message « Plus disponible ».

### Quality Issues : 4 trouvés, 3 corrigés
1. **Budget de recrutement présenté comme acquis** [ADVISORY, corrigé et remonté à Léo] : le texte remplaçait « Trésorerie » par « Disponible pour les transferts » alors que l'existence d'un budget distinct est une question ouverte. Réserve écrite avec libellé de repli « Trésorerie disponible ».
2. **File de fins de contrat sans bloc** [BLOCKING, corrigé] : la sortie « bandeau n fins de contrat » (journey §3.4, §1.4) n'était définie nulle part. Bloc ajouté (visible si n > 0, ouvre Effectif › Contrats).
3. **Message « Plus disponible » sans durée** [ADVISORY, corrigé] : reste jusqu'à l'action suivante (M6).
4. **Comparaison de 2 pistes sans écran** [ADVISORY, non corrigeable ici] : question ouverte.

### GDD Alignment : ALIGNED
- Journey 09 : pistes prioritaires, comparer 2 profils, négociation, argent disponible : couvert.

### Accessibility : COMPLIANT (Standard)
- Priorités en mots (pas de rouge/ambre/vert seuls), montants jamais tronqués (T5), focus sur Annuler pour un engagement d'argent, K7 respecté. **Réserve** : lignes 32 px (arbitrage Léo, même point que 07).

### Pattern Library : CONSISTENT
- E3 étendu (incohérence 3 du relevé), W1 avec bouton nommé, F8 états vides ; N5 (Échap) ajouté aux déviations.

### Verdict : APPROVED (après révision)
**Blocking** : 0 restant · **Advisory** : 1 restant · **Dimensions not assessed** : 0

---

## UX Review : 10 Composition et plan de jeu

### Completeness : 15/15 après corrections (11/15 avant)
- Ajoutés : États, entrées, sorties et données de la page « Plan de jeu » (§7), Transitions, Localisation, Entrées (§12 bis), critères de performance.

### Quality Issues : 5 trouvés, 4 corrigés
1. **Annulation de la proposition du staff limitée à 8 s** [BLOCKING, corrigé] : contredit K7 et M6 (contenu qui disparaît seul). Corrigé : reste jusqu'à la prochaine action ; Ctrl+Z ajouté.
2. **Propriétaire du brouillon contradictoire** [BLOCKING, corrigé] : « brouillon = état d'interface » alors que chaque affectation envoie `LineupSlotSet` et que la validité vient du moteur (checklist : l'interface ne possède pas d'état de jeu). Corrigé : le brouillon vit côté moteur ; l'interface garde sélection, « pris » et filtre ; hypothèse à confirmer (question ajoutée).
3. **Page « Plan de jeu » sans états** [ADVISORY, corrigé] : tableau d'états ajouté. Onglets frères « Phases arrêtées » et « Lecture du match » : **non spécifiés** (déclarés « non relus » dans la fiche).
4. **Banc : « jusqu'à 8 » (loi 3) contre « 8/8 » et 23 obligatoires** [ADVISORY, corrigé en partie] : formulation clarifiée ; validité d'un banc court : question ouverte.
5. **Flèches sur le terrain sans règle** [ADVISORY, corrigé] : « poste voisin le plus proche dans la direction ».

### GDD Alignment : ALIGNED (journey + brief + loi 3)
- Journey 10 : XV valide, changer un poste, impact, consignes, valider : couvert ; « composition proposée par défaut, modifiable en 2 clics » : état Première fois. Loi 3 : 15 + jusqu'à 8, six premières lignes formées sur 23, règles de blocage fournies par le moteur (non recalculées).

### Accessibility : COMPLIANT (Standard)
- K6 : alternative clavier complète au glisser-déposer (Espace / flèches / Espace, Échap annule) ; statuts en mots + icône ; cadre de sélection et focus = deux signes ; annonces d'état en texte visible ; ratios écrits.

### Pattern Library : CONSISTENT
- E6/E7 fusionnés, W1 nommé, W2 en ligne, motif manquant n°12 ; N5 (Échap) ajouté.

### Verdict : APPROVED (après révision)
**Blocking** : 0 restant (2 corrigés) · **Advisory** : 2 restants (onglets Phases arrêtées / Lecture du match ; banc court) · **Dimensions not assessed** : 0

---

## UX Review : 11 Préparation et entraînement

### Completeness : 15/15 après corrections (11/15 avant)
- Ajoutés : Transitions, Localisation, Entrées (§11 bis), critère de performance, ratios de contraste.

### Quality Issues : 4 trouvés, 4 corrigés
1. **Wireframes incohérents** [ADVISORY, corrigé] : le match tombe un samedi mais la semaine affichait « Sam Activation ○ » et « 5 faites sur 6 ». Corrigé : « Sam ★ Match », « 4 faites sur 5 » (cohérent avec « Aller au jour de match » = veille).
2. **Libellé de secteur contradictoire** [ADVISORY, corrigé] : « Occupation au pied (… harmoniser en Jeu au pied) » : fixé sur « Jeu au pied », comme la Composition.
3. **« Effet attendu » sans source garantie** [ADVISORY, corrigé] : source moteur, ligne masquée si valeur absente (pas de phrase générique).
4. **Échap non listé en déviation** [ADVISORY, corrigé].

### GDD Alignment : ALIGNED
- Journey 11 : forme V/N/D, danger principal, charge d'entraînement : couvert. Friction §3 : « Aller au jour de match » grisé avec raison.

### Accessibility : COMPLIANT (Standard)
- D2 : lettre + forme + infobulle ; rapport de force avec chiffres aux deux bouts (D6) ; « À faire » en icône + mot ; ratios écrits.

### Pattern Library : CONSISTENT
- Motif manquant n°1 (barres face à face), F6, W1, N2.

### Verdict : APPROVED (après révision), avec réserve
**Blocking** : 0 · **Advisory** : 2 restants · **Dimensions not assessed** : 0
- **Réserve** : l'écran Entraînement (partie B) est lu dans le code seul (aucune capture) ; la réduction « 14 cartes → 4 visibles » est marquée « à valider écran par écran ». Le verdict porte sur la conformité de la spec, pas sur l'état réel de l'écran.

---

## UX Review : 12 Avant-match

### Completeness : 15/15 après corrections (11/15 avant)
- Ajoutés : Transitions, Localisation, Entrées (§11 bis), critère de performance, ratios de contraste, verrou d'ouverture.

### Quality Issues : 4 trouvés, 4 corrigés
1. **Garde-fou Espace contredit** [BLOCKING, corrigé] : la fiche donnait le focus initial à « Coup d'envoi » (K8) tout en promettant qu'Espace ne lance rien « tant que le bouton n'a pas le focus ». Avec le focus déjà sur le bouton, un Espace répété depuis le Bureau lançait le match. Corrigé : verrou de 0,5 s à l'ouverture, touche maintenue ignorée, critère d'acceptation réécrit ; reste à valider par Léo (changement de N5/N6).
2. **« Préparer la causerie » non spécifié** [ADVISORY, corrigé] : le code ouvre le Vestiaire ; ajouté (le contenu du Vestiaire reste hors fiche).
3. **Cases « ✓ » sur les clés de Gabi** [ADVISORY, corrigé] : confondues avec « fait » ; numérotées 1, 2, 3.
4. **Échap non listé en déviation** [ADVISORY, corrigé].

### GDD Alignment : ALIGNED
- Journey 12 : comprendre que le match va commencer, lancer, vérifier la feuille : couvert ; décision du 16/11 (reprise avant le match) : bandeau de reprise.

### Accessibility : COMPLIANT (Standard)
- C5 voile sur photo (5 météos), couleur non seule (D2, D5, statut icône + mot), délégation avec focus sur Annuler, ratios écrits.

### Pattern Library : CONSISTENT
- N5/N6, W1, F9 déviés explicitement.

### Verdict : APPROVED (après révision)
**Blocking** : 0 restant (1 corrigé) · **Advisory** : 0 · **Dimensions not assessed** : 0

---

## Questions pour Léo (ne bloquent pas)

1. **Échap sur un écran racine** (07, 09, 10, 11, 12) : retour, ou menu pause comme aujourd'hui ? Les fiches écrivent « retour » partout et gardent le comportement actuel sans filtre ni fenêtre (07).
2. **Hauteur de ligne des tableaux** (07, 09) : 32 px (K6, environ 17 lignes visibles) ou 28 px actuels (21 lignes) ?
3. **Budget de recrutement** (09) : existe-t-il un plafond distinct de la trésorerie ? Sinon le libellé devient « Trésorerie disponible ».
4. **Verrou de 0,5 s sur « Coup d'envoi »** (12) : acceptable (changement de N5/N6) ?
5. **Confirmation avant le coup d'envoi** avec avertissements ouverts (12) : proposé non.
6. **Précédent/suivant** de la fiche depuis la composition (08) : XV, groupe ou aucun.

## Autres suites (hors Léo)

- Fiche à créer : écran de comparaison à 2 (07, 08, 09 y renvoient).
- Onglets « Phases arrêtées » et « Lecture du match » (10) : non spécifiés.
- Capture de l'écran Entraînement à produire (11).
- game-designer : banc court valide ? effets des modes de charge ; brouillon de feuille côté moteur.
- Fichiers touchés : les six fiches, uniquement. Aucun commit, aucun Godot.
