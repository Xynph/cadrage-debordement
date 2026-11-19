# Revue UX 01 à 06 (/ux-review)

Date : 19/11/2026. Relecteur : skill `ux-review`, puis corrections par le rôle ux-designer, puis réévaluation.
Fiches : `design/ux/01-accueil.md`, `02-creation.md`, `03-chargement.md`, `04-bureau.md`, `05-reception.md`, `06-presse.md`.

## Cadre de la revue

- **Checklist** : 3A (fiche d'écran) pour les six. Aucune n'a de ligne d'en-tête `> **Template**:` : classées 3A par défaut (nom de fichier), faute de mieux.
- **Plateforme** : PC souris/clavier ; manette hors périmètre (décision projet), non retenue comme motif. Note : `.claude/rules/ui-code.md` du kit exige encore la manette ; `CLAUDE.md` et la consigne de Léo priment.
- **Palier d'accessibilité** : Standard, engagé (`design/accessibility-requirements.md`) : dimension évaluable.
- **Bibliothèque de motifs** : `design/ux/interaction-patterns.md` présente : dimension évaluable.
- **Alignement GDD** : `docs/gdd/` n'existe pas. L'alignement a été vérifié contre les entrées désignées pour cette revue (`game-brief.md`, `player-journey.md`), pas contre des GDD. À rouvrir quand des GDD existent.
- **Limite** : aucune capture, aucun Godot. Les corrections s'appuient sur la lecture du code (`entry_canvas.gd`, `creation_options/*`, `press_canvas.gd`, `press_view.gd`, `press_people_view.gd`). Le rendu reste à vérifier à l'écran.

## Tableau de synthèse

| Fiche | Verdict initial | Problème principal | Verdict final (après révision) |
|---|---|---|---|
| 01 Accueil | NEEDS REVISION | sections manquantes (événements, transitions, localisation, contrôle d'entrée, critères de performance et de résolution) ; lien « Identités et packs » absent du wireframe ; destination de « Reprendre » en désaccord avec le code | APPROVED |
| 02 Création | NEEDS REVISION | étape « Carrière » non spécifiée (« non capturé ») ; bouton nommé « Commencer » au lieu de « Prendre les rênes » ; mêmes sections manquantes | APPROVED |
| 03 Chargement | NEEDS REVISION | contradiction §6 / §7 (pas de bouton Annuler vs bouton « Arrêter » à 20 s) et focus ; message « Ouverture du profil… » cité par 01 mais absent du tableau ; mouvement réduit incomplet ; sections manquantes | APPROVED |
| 04 Bureau | NEEDS REVISION | décompte de cartes faux (6 annoncé, 7 dessinés) ; objectif du conseil promis par le brief mais absent ; source de Gabi absente ; sections manquantes | APPROVED |
| 05 Réception | NEEDS REVISION | Échap en désaccord avec 04 ; question « bascule conférences » restée ouverte alors que le code la tranche ; sections manquantes | APPROVED |
| 06 Presse | NEEDS REVISION | trois onglets sur quatre sans contenu ; impasse du bouton « Préparer la conférence » (le code n'affiche les questions que depuis l'invitation du courrier) ; réglage « Conférences ordinaires » déplacé vers un onglet où il serait introuvable ; Échap ; sections manquantes | APPROVED |

« APPROVED » vaut pour la spécification : prête pour `/team-ui` phase 2 (conception visuelle). Réserves non bloquantes : rendu non capturé, hypothèses de noms de commandes marquées « à confirmer », et les points de la section « Questions pour Léo ».

## Constats communs aux six fiches (corrigés)

1. **Événements émis** : absent partout. Ajouté, avec les commandes réellement lues dans le code (`club_mail_reply`, `calendar_mail_decide`, `press_conference`, `press_delegate`, `press_policy`, `new_career`, `request_stop`, `set_lineup`) ; les autres marquées « nom à confirmer ».
2. **Transitions et animations** : absent partout. Ajouté, avec le comportement sous « Mouvement réduit » (M1) et « Transitions : Aucune » (M2).
3. **Contrôle d'entrée** (souris + clavier) : absent. Ajouté sous forme de liste cochée par fiche.
4. **Localisation** : absente. Ajouté : limites de caractères et marge de 40 %. Le jeu est en français seul aujourd'hui.
5. **Critères d'acceptation** : critère de performance (≤ 500 ms, seuil déjà utilisé par le panneau d'attente) et critère de résolution (1280×720, 1920×1080, 2560×1440, 21:9, 130 % de texte) ajoutés.

## Corrections faites, fiche par fiche

### 01 Accueil
- Wireframe et tableau §5 : lien « Identités et packs » ajouté (il était décrit en §9 mais ni dessiné ni listé).
- §9 : ajout de la ligne « Destination de Reprendre » : le code ouvre aujourd'hui Réception ; la fiche vise le Bureau via 03.
- Section 12 ajoutée (événements, transitions, contrôle d'entrée, localisation, critères).

### 02 Création
- §3 : contenu réel de l'étape « Options de carrière » relevé dans `creation_options/layout.gd` (club, première saison, Gabi, mot du président, rivalités, championnats suivis, vestiaire, rendez-vous ; conditions d'inactivité du bouton final).
- Libellé corrigé partout : « Commencer » devient « Prendre les rênes », avec « ← Changer de club ».
- Question ajoutée sur le bloc « Défis de départ » (existe dans le code, absent de la fiche).
- Section 13 ajoutée.

### 03 Chargement
- §6 : contradiction levée : pas de bouton Annuler en usage normal, sauf « Arrêter » après 20 s pour une commande annulable ; ce bouton prend le focus.
- Tableau §3 : message « Ouverture du profil… » ajouté.
- Mouvement réduit : apparition et disparition instantanées (ou fondu de 100 ms au plus).
- Section 12 ajoutée.

### 04 Bureau
- Décompte corrigé : 7 blocs (4 cartes + bandeau de 3 aperçus) ; critère d'acceptation et ligne cognitive alignés.
- Ligne « Objectif du conseil » ajoutée dans la carte des priorités (brief, « première minute » ; fiche 02) ; critère d'acceptation ajouté.
- Source et valeur par défaut de Gabi précisées.
- Section 12 ajoutée.

### 05 Réception
- Échap aligné sur 04 (règle provisoire : fenêtre ouverte d'abord, sinon menu pause) ; pied de page « Échap Menu ».
- Question de la bascule vers les conférences résolue d'après `press_view.gd` (« Revenir au courrier »).
- Section 12 ajoutée.

### 06 Presse
- Contenu des onglets Conférence, Historique et Portraits relevé dans le code et décrit.
- Impasse du bouton « Préparer la conférence » documentée (code actuel, cible proposée).
- Libellé « Donner la conférence » corrigé en « Publier mes réponses » (libellé réel) ; « Laisser Gabi répondre » ajouté.
- Réglage « Conférences ordinaires » : il doit rester visible en permanence dans l'onglet Conférence, sinon introuvable sans invitation.
- Échap aligné sur 04 ; navigation du rail à confirmer.
- Section 12 ajoutée.

## Questions pour Léo (ne bloquent pas)

1. **Échap sur un écran racine** (Bureau, Réception, Presse) : ouvre le menu pause (état actuel, règle provisoire écrite dans 04, 05, 06) ou ne fait rien ?
2. **« Reprendre la carrière »** : doit-il arriver au Bureau (cible des fiches) ou rester sur Réception (code actuel) ?
3. **Densité du Bureau** : corps de texte à 14 px à 1080p (accessibilité) contre ~12 px (brief) ; le Bureau devient plus aéré.
4. **Réponses de courrier du club** : envoyer en deux temps (choisir puis « Envoyer la réponse », avec annulation) au lieu d'un clic ?
5. **Marquage « lu » aux flèches** : seulement après 1 s, pour ne pas vider la boîte en parcourant ? Et « Tout marquer comme lu » : acceptable ?
6. **Publication d'une conférence** : récapitulatif des conséquences avant publication (aujourd'hui un seul clic) ?
7. **Conférence de presse** : garder le circuit « invitation du courrier seulement », ou permettre l'accès direct depuis Presse ?
8. **Objectif du conseil sur le Bureau** : bien voulu sur l'écran (le brief le promet) ; la donnée existe-t-elle sous forme d'une ligne ?
9. **Noms** : « Identités et packs » à renommer ? Bloc « Défis de départ » à garder ?
10. **Noms réels** vus dans des captures (clubs, journalistes) : pack local actif, ou fuite dans le jeu de base ? (déjà ouvert dans 02 et 06)

## Dimensions : bilan final

| Dimension | Résultat |
|---|---|
| Complétude (3A) | présente sur les six après révision |
| Alignement GDD | aligné au brief et au parcours ; aucun GDD n'existe (voir cadre) |
| Accessibilité (Standard) | conforme au niveau spécification ; écarts d'implémentation du document d'exigences (T3, E2, D7, M1, M4 « Pas encore ») hors périmètre de ces fiches |
| Bibliothèque de motifs | cohérente ; nouveaux motifs (réponse en deux temps, « Voir plus », lien d'effacement de filtre) signalés comme déviations dans 05 et 06 |
| Dimensions NOT ASSESSED | aucune |
