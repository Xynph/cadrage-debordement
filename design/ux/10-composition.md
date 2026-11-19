# Fiche UX 10 — Composition et plan de jeu

Décisions de Léo du 19/11/2026 intégrées : densité « Football Manager » (corps ~13 px, tableaux 12-13 px, en-têtes 11-12 px, jamais sous 11 px à 1080p ; lignes de tableau 24-26 px ; échelle d'interface 90/100/115/130 %) ; règle unique d'Échap (ferme la fenêtre, sinon retour de fiche/sous-écran, sinon menu pause) et bouton « Menu » visible dans la coque.

> **Template**: UX Spec
> **Statut** : proposé (ux-designer CCGS, 19/11/2026, mode autonome, rigueur `minimal`)
> **Écran** : `Composition` (route « Tactique », chapitre Composition / Préparation / Plan de jeu / Match) et page `Plan de jeu` (quatre zones) · carrière Monde · souris + clavier
> **Phases du parcours** : première heure (première composition), semaine type (étape finale avant Continuer)
> **Palier d'accessibilité** : Standard (exigence K6 : alternative clavier au glisser-déposer)
> **Liés** : fiche 11 (préparation), fiche 12 (avant-match), `design/ux/interaction-patterns.md` (E6, E7, E8, W1, W2, N2), `docs/rugby-rules-reference.md` (loi 3 : 15 titulaires, jusqu'à 8 remplaçants, six premières lignes formées pour une feuille à 23)
> **Hors périmètre** : composition pendant le match (écran 14) ; elle réutilise le même composant (voir §11)

## 1. But

- **Joueur** : poser son XV et son banc (23 noms, postes 1 à 15 et remplaçants 16 à 23), **savoir si la feuille est valide et ce que ses choix changent face à l'adversaire**, régler les consignes, puis valider.
- **Jeu** : obtenir une feuille réglementaire et un plan de jeu, avec un retour clair sur l'impact (le « Pourquoi » de l'après-match s'appuie dessus).
- **Dans les 5 secondes** : (1) la feuille est-elle valide ? sinon pourquoi, (2) quel poste est sélectionné, (3) comment le XV se compare à l'adversaire.

## 2. Contexte d'arrivée

| Question | Réponse |
|---|---|
| Venu de | Préparation (« Revoir la composition »), Bureau (« Préparer le match »), Avant-match (« Ouvrir la composition »), rail Tactique |
| État d'esprit | Responsabilité, doute ; plaisir de bricoler |
| Charge cognitive | Haute : 23 postes, états, règles, adversaire |
| Veut | Une feuille valide en peu de clics, un XV qui lui plaît |
| Craint | Aligner un blessé, oublier la première ligne du banc, être éjecté par un message d'erreur |

**Cible émotionnelle** : « Je dirige, j'ai le contrôle, le staff me protège de l'erreur. »

## 3. Navigation

```
Carrière Monde › Tactique (chapitre)
  ├── Composition                       ← page de cette fiche : XV, banc, candidats, impact
  │     └── Onglets : Composition · Consignes · Phases arrêtées
  ├── Plan de jeu                       ← page « quatre zones » (section 7 de cette fiche)
  ├── Préparation (11)
  └── Match (12)
```

- **Modalité** : écran plein, non modal. Les candidats s'ouvrent dans un **panneau**, pas dans une fenêtre (voir §6.3).
- **Entrées** : rail (Tactique), Préparation, Avant-match, Bureau, accès rapide.
- **Sorties** : Valider la feuille → retour à Préparation (ou Avant-match si veille/jour de match) ; Échap = retour sans perdre le travail (la feuille en cours est conservée en brouillon) ; fiche joueur (Entrée sur un nom, retour à la même place).
- **Échap** : ferme panneau/fenêtre ouvert, annule un « prendre » en cours (voir §8), sinon retour d'une sous-page (Plan de jeu vers Composition) ; sur l'écran principal sans rien d'ouvert, ouvre le menu pause (règle unique de Léo, 19/11/2026).

## 4. Hiérarchie

1. **Principal** : le XV de départ sur le terrain (15 postes) avec la **ligne de validité** qui l'accompagne.
2. **Secondaires** : (a) le banc (8) ; (b) le panneau « Candidats pour le poste n° X » ; (c) l'impact face à l'adversaire.
3. **Reste** : consignes globales (onglet), phases arrêtées (onglet), plan par zone (page séparée), vigilance physique, proposition du staff.

## 5. Wireframe 1280×720 (onglet « Composition »)

```
┌────┬───────────────────────────────────────────────────────────────────────────────────────┐
│    │ Le XV de départ.   Meadowbridge R. – Alder Fen XV · J1 · sam. 19/09 17:00               │
│ Nav│ ● Feuille valide · 15 + 8 · 1ʳᵉ ligne 6/6   [Proposition du staff][Enregistrer][Valider la feuille →]│
│124 │ [Composition][Consignes][Phases arrêtées]                       Plan : Équilibré [Modifier]│
│ px │ ┌ XV de départ ────────────────────────┐ ┌ Banc 8/8 ──────────┐ ┌ Impact vs adversaire ┐│
│    │ │ ①Fairclough ②Ollerenshaw ③Atherton   │ │16 Blackburn  c.2 ◉ │ │ Mêlée   60 ▬▬▬ ▬▬ 58││
│    │ │   ④Coates     ⑤Dangerfield           │ │17 Blakeley   c.1   │ │ Touche  62 ▬▬▬ ▬▬▬ 63││
│    │ │ ⑥Bickerstaff ⑧North ⑦McCulloch       │ │18 Smart      c.3   │ │ Puissance 65  vs 63  ││
│    │ │        ⑨Gannon                       │ │19 Haines     c.4-8 │ │ Passe 63 vs 62       ││
│    │ │        ⑩Amos                         │ │20 Slingsby   c.6-8 │ │ Pied 63 vs 60        ││
│    │ │   ⑫Chandler   ⑬Brooks                │ │21 Boothroyd  c.9   │ │ Discipline 64 vs 63  ││
│    │ │ ⑪Forbes   ⑮Booth   ⑭Dearden        │ │22 Abbott     c.10  │ │ ────────────────────│
│    │ │  chaque carte : n°, nom, note /100   │ │23 Sutcliffe  c.11  │ │ Vigilance physique  ││
│    │ └──────────────────────────────────────┘ └────────────────────┘ │ Aucune alerte        ││
│    │ ┌ Candidats pour le poste n° 5 · Deuxième ligne ─────────────── [Hors feuille seul.] ┐   │
│    │ │ Joueur          Postes maîtrisés   Note   Condition  Statut                         │   │
│    │ │ K. Dangerfield  4 · 5              58     100 %      Titulaire n° 5 (actuel)        │   │
│    │ │ P. Haines       4 · 5              60     100 %      Remplaçant n° 19 · échanger    │   │
│    │ │ L. Simmons      1                  —      100 %      Non qualifié au poste           │   │
│    │ └─────────────────────────────────────────────────────────────────────────────────────┘   │
├────┴──┬──────────────────────────────────────────────────────────────────────────────────────┤
│ pied  │ Entrée Choisir · Espace Prendre/Poser · ↑↓←→ Poste · Échap Retour · F1 Aide           │
└───────┴──────────────────────────────────────────────────────────────────────────────────────┘
```

| Zone | Contenu | Taille | Défile ? | Débordement |
|---|---|---|---|---|
| En-tête | titre, match, ligne de validité, 3 boutons | 100 % × 14 % | Non | Ligne de validité : 2 lignes max, « Voir tout » si plusieurs blocages |
| Onglets + résumé de plan | 3 onglets, « Plan : Équilibré · Modifier » | 100 % × 6 % | Non | — |
| XV de départ | 15 cartes de poste | 43 % × 46 % | Non | Photo masquée sous 1400 px utiles (n°, nom, note restent) |
| Banc | 8 lignes (16-23) | 25 % × 46 % | Non | Nom abrégé (initiale + nom) |
| Impact | 6 barres face à face + vigilance | 27 % × 46 % | Non | Barres → chiffres seuls sous 1100 px |
| Candidats | liste triée du poste choisi | 100 % × 26 % | Verticalement | 3 lignes visibles puis défilement |
| Pied | raccourcis | 100 % × 5 % | Non | — |

**Focus à l'ouverture** : le poste n° 1 (ou le premier poste vide / invalide s'il y en a un).

## 6. Blocs et données (page Composition)

### 6.1 Ligne de validité

Un seul indicateur remplace les deux pastilles actuelles « 23 joueurs sélectionnés » et « Composition valide » :
- Valide : « **Feuille valide** · 15 titulaires + 8 remplaçants · première ligne 6/6 formés ».
- Non valide : « **Feuille incomplète** : il manque un talonneur sur le banc. [Corriger →] » : chaque blocage porte sa **correction** (focus sur le poste concerné).
- Avertissements non bloquants (liste repliée) : joueur sous 80 % de condition, retour de blessure récent, absent en sélection avant la date du match, deux joueurs du même poste sur la feuille sans raison.

Règles de blocage (loi 3, `docs/rugby-rules-reference.md`) : 15 titulaires aux postes 1-15, **jusqu'à 8 remplaçants** (le compteur « Banc 8/8 » est un objectif ; qu'un banc plus court soit valide dépend de la compétition, question 6, §14), chacun qualifié et disponible, **six premières lignes formées** sur la feuille à 23 couvrant les postes requis. La liste des règles de blocage vient du moteur ; l'interface ne la recalcule pas.

### 6.2 Terrain : 15 cartes de poste

Chaque carte : n° (pastille), Prénom NOM (court), note au poste /100 (« 66 »), état (condition < 80 % : icône + « 74 % » ; indispo : icône + mot « Blessé » ; sinon rien). Poste vide : cadre pointillé + « Poste n° 7 vide » (jamais un fond noir).
Disposition : terrain à l'horizontale, l'équipe attaque vers la droite (flèche « Sens de l'attaque » conservée), n° 1 en haut à gauche, n° 15 en bas à droite ; l'ordre du rugby est respecté (première ligne 1-2-3, deuxième ligne 4-5, troisième ligne 6-8-7, charnière 9-10, trois-quarts 11-12-13-14, arrière 15).

### 6.3 Choisir un joueur : un seul motif (remplace E6 + E7)

Sélectionner un poste du terrain ou du banc (clic simple, ou ↑↓←→ + Entrée) ouvre/remplit le panneau **Candidats pour le poste n° X · Poste**. Il n'y a plus de fenêtre modale « Poste 05 · choisir un joueur » et plus de liste « Hors groupe » séparée.

| Colonne | Contenu | Tri |
|---|---|---|
| Joueur | photo 24 px + Prénom NOM | — |
| Postes maîtrisés | numéros et mots (« 4 · 5 ») | — |
| Note au poste | /100 ; « — » si non qualifié (**jamais « 0 »**, comme aujourd'hui) | **défaut : décroissant** |
| Condition | % + barre, repère 80 % | — |
| Statut | « Titulaire n° 5 (actuel) » · « Remplaçant n° 19 · échanger » · « Hors groupe » · « Blessé · retour jj/mm » · « En sélection · retour jj/mm » · « Non qualifié au poste » | — |

Les candidats **non éligibles restent visibles, grisés, avec la raison en texte** dans la colonne Statut (pas seulement en infobulle) ; Entrée sur eux ne fait rien mais annonce la raison. Cela supprime l'avis modal générique « Affectation indisponible ».
Un candidat déjà sur la feuille : l'action est « **échanger** » (les deux postes permutent).
Filtre « Hors feuille seulement » (désactivé par défaut) ; recherche de nom au focus.

### 6.4 Banc (16 à 23)

Colonnes : n°, Joueur, « Couvre » (numéros de postes couverts), Condition. Marque de première ligne (icône + mot « 1ʳᵉ ligne ») sur les joueurs formés. Compteur « première ligne 6/6 » avec le détail en infobulle. La convention 16-18 = première ligne n'est montrée qu'en indication (« généralement »), la règle étant la somme sur 23.

### 6.5 Impact face à l'adversaire

Six barres opposées (nous / adversaire) : **Mêlée, Touche, Puissance des avants, Passe et vitesse, Jeu au pied, Discipline** ; chiffres à chaque bout, écart au centre (« +2 »), avec « projection du staff » en infobulle. Elles se **recalculent à chaque changement de poste** et l'écart modifié clignote une fois (fixe si mouvement réduit). Remplace : la colonne « Identité de jeu » avec ses 5 barres et 3 cartes (Conquête, Défense, Animation offensive) et la rangée basse « Mêlée / Touche / Jeu au pied » (doublons).
« Vigilance physique » : une ligne (« Aucune alerte » ou « 2 joueurs sous 80 % : P. Haines, K. Wakefield »).

### 6.6 Plan, consignes, staff

- **Résumé de plan** (« Plan : Équilibré · Défense : Équilibrée · Modifier ») sur l'onglet Composition ; « Modifier » ouvre l'onglet Consignes. Remplace les trois pastilles « Équilibré / Occupation / Large » qui répètent l'onglet Consignes et le « Plan de jeu » de l'entracte.
- **Proposition du staff** (bouton, ex. « SÉLECTION DU STAFF ») : applique la composition recommandée ; message « Proposition du staff appliquée · **Annuler** » (retour à l'état précédent). Le message et l'annulation restent **jusqu'à la prochaine action du joueur**, sans disparition automatique (K7, M6) ; Ctrl+Z fait de même.
- **Enregistrer** : enregistre la composition comme modèle réutilisable (libellé exact à confirmer avec le moteur : « Enregistrer le plan » actuel est ambigu).
- **Valider la feuille** (principal, seul bouton plein) : envoie la feuille au moteur ; reste désactivé tant que le moteur déclare un blocage, avec la raison en texte juste à côté.
- Onglet **Analyse adverse** : retiré de cette page (doublon du dossier adverse de la Préparation) ; remplacé par un lien « Voir le dossier adverse → » dans l'impact.

### 6.7 Données et événements

| Donnée | Source | Rafraîchie | Absence |
|---|---|---|---|
| Joueurs, postes qualifiés, notes au poste | moteur (effectif, évaluation de poste) | à chaque jour, blessure, convocation | « — » |
| Validité, blocages, avertissements | moteur (règles de feuille) | à chaque affectation | « Validité inconnue » + Réessayer |
| Barres adverses | dossier adverse (Préparation) | à chaque affectation | barres adverses « — » |
| Brouillon de feuille (non validé) | moteur (brouillon de feuille ; `LineupSlotSet` le modifie, `LineupValidated` le valide) : l'interface ne garde que la sélection, le joueur « pris » et le filtre | à chaque affectation | dernière feuille validée |

| Action | Événement | Payload |
|---|---|---|
| Choisir un candidat | `LineupSlotSet` | `{slot, playerId}` |
| Échanger deux postes | `LineupSlotsSwapped` | `{slotA, slotB}` |
| Libérer un poste | `LineupSlotCleared` | `{slot}` |
| Proposition du staff | `LineupStaffProposalApplied` | `{}` |
| Valider | `LineupValidated` | `{slots[23]}` |
| Plan par zone | `ZonePlanSet` | `{zone, phase, planId}` |

## 7. Page « Plan de jeu » (quatre zones)

**But** : régler, zone par zone, l'attaque et la défense quand le plan général ne suffit pas (réglage avancé).

**Contenu actuel** : quatre cartes (01 Tes 22 mètres, 02 Tes 22 → milieu, 03 Milieu → leurs 22, 04 Leurs 22 mètres), chacune avec Attaque et Défense (liste « Plan principal ») + schéma du terrain + phrase d'avertissement. **Proposé** : un seul tableau.

| Zone (du plus défensif au plus offensif) | Attaque | Défense |
|---|---|---|
| 1 · Tes 22 mètres | liste (défaut : « Suit le plan principal ») | liste (idem) |
| 2 · Tes 22 → milieu | idem | idem |
| 3 · Milieu → leurs 22 | idem | idem |
| 4 · Leurs 22 mètres | idem | idem |

- Le schéma du terrain reste à droite : cliquer une zone met le focus sur sa ligne et inversement ; la zone active est repérée par bordure + numéro (pas seulement par la couleur).
- Libellés : « Plan principal (Équilibré) » dans la liste, **une seule fois** (les étiquettes « Équilibré / Équilibrée » en doublon au-dessus de chaque liste sont retirées).
- Résumé en tête : « Attaque principale : Équilibré · Défense principale : Équilibrée » avec « Consignes principales → ».
- Onglets frères : **Phases arrêtées** et **Lecture du match** (non relus ici : même tableau, voir questions ouvertes).
- La phrase finale (« Une consigne locale remplace le plan principal dans sa zone… ») reste, au pied.
- Clavier : Tab entre listes, ↑ ↓ pour choisir (le choix s'applique à la sortie du menu), Entrée ouvre ; Échap ferme sans changer.

**États de la page « Plan de jeu »** :

| État | Rendu |
|---|---|
| Normal | 4 lignes, chaque liste sur « Suit le plan principal » par défaut ; zone liée au schéma |
| Zone modifiée | libellé de la liste en gras + mot « Local » (pas la couleur seule) |
| Aucun plan disponible | liste réduite à « Suit le plan principal » ; message « Aucun plan local disponible pour cette zone. » |
| Chargement / validation | listes grisées 0,35 s ; raison en texte |
| Commande refusée | message en tête avec raison et correction, sans modale (comme §9) |
| Lecture seule | match commencé : « Le plan est verrouillé depuis le coup d'envoi. » |
| Erreur de données | bandeau + Réessayer ; page en lecture |

Entrées : rail (Tactique › Plan de jeu), Préparation (« Carnet de jeu »), Avant-match (« Ouvrir le plan de jeu »), onglet Composition (« Modifier »). Sortie : Échap = retour à l'origine. Données : plans et consignes du moteur (rafraîchis à chaque changement), jamais calculés par l'interface ; absentes : « Suit le plan principal ».

## 8. Actions et raccourcis

| Action | Souris | Clavier | Réponse |
|---|---|---|---|
| Choisir un poste | clic carte | ← → ↑ ↓ (poste voisin le plus proche dans la direction, sur le terrain puis le banc), Tab (n° croissant 1→15, puis banc 16→23) | cadre épais, panneau Candidats mis à jour |
| Affecter un candidat | clic ligne | Entrée sur le poste → focus dans Candidats, ↑ ↓, Entrée | permutation ou remplacement, impact recalculé |
| **Déplacer un joueur (alternative clavier au glisser-déposer)** | glisser-déposer carte → carte, ou liste → carte | **Espace** sur un joueur = « prendre » (état annoncé : « Joueur n° 5 pris »), flèches vers la destination, **Espace** = poser (échange) ; **Échap** annule | surbrillance des destinations compatibles, mouvement fixe si mouvement réduit |
| Libérer un poste | bouton « Libérer » dans le panneau | Suppr | poste vide, validité recalculée |
| Proposition du staff | bouton | Tab, Entrée | message avec Annuler |
| Valider | bouton | Tab, Entrée ; Ctrl+Entrée depuis n'importe quel poste | W1 si avertissements (voir §9) |
| Ouvrir une fiche | double-clic carte | Maj+Entrée | fiche 08, retour au même poste |
| Changer d'onglet | clic | Ctrl+Tab, ← → | motif d'onglets unique |
| Clic droit sur un poste | menu : Fiche joueur · Libérer · Échanger avec… | touche Menu | motif « menu rapide » |

Le glisser-déposer reste une commodité souris ; **aucune action n'en dépend** (K6). Espace appartient à l'élément ciblé dès qu'on a navigué (Tab ou flèches, N5) : il ne déclenche jamais « Continuer » sur cet écran.

## 9. États

| État | Déclencheur | Rendu | Comportement |
|---|---|---|---|
| Valide | feuille complète, aucun blocage | « Feuille valide » + Valider actif | — |
| Incomplète / invalide | poste vide, joueur indisponible, première ligne insuffisante | « Feuille incomplète » + cause + « Corriger → » ; Valider grisé avec raison à côté | focus du « Corriger » amène au poste |
| Avertissements | condition < 80 %, retour de blessure | pastille « 2 avertissements » dépliable ; Valider actif | Valider ouvre W1 : titre « Valider avec 2 avertissements ? », boutons « Valider la feuille » / « Revoir », focus sur « Revoir » |
| Poste sélectionné | clic/clavier | cadre épais + titre du panneau | — |
| Poste vide | joueur libéré, blessure | cadre pointillé + « Vide » | panneau Candidats prêt, tri par note |
| Candidat non éligible | blessé, non qualifié, absent | grisé + raison en texte | Entrée n'affecte pas, annonce la raison |
| Joueur « pris » (clavier/souris) | Espace / début de glisser | joueur en surbrillance, destinations compatibles marquées | Échap annule |
| Première fois | première composition | feuille déjà **proposée par le staff** (modifiable en 2 clics) ; Gabi : « Clique un poste pour voir qui peut le tenir. » | disparaît après un choix |
| Chargement | validation en cours | Valider en « Validation… » grisé, pas d'effet sur le terrain | 0,35 s avant d'afficher |
| Commande refusée | le moteur rejette la feuille | message en tête, sous l'en-tête : raison + correction ; **pas de modale** | focus sur le premier blocage |
| Feuille verrouillée | match commencé ou joué | lecture seule : « La feuille est verrouillée depuis le coup d'envoi. » | pas d'actions |
| Erreur de données | joueurs illisibles | bandeau + Réessayer | écran en lecture, pas de crash |

## 10. Accessibilité (T1, C1, C3, D1, D3, D6, K1, K2, K6, K8)

- **Alternative clavier au glisser-déposer** : « Espace prendre / poser » et sélection puis Entrée dans Candidats ; documentée au pied et dans F1 ; équivalent complet (K6).
- Texte ~13 px à 1920 (12 px dans les tableaux Banc et Candidats) ; carte de poste : nom ≥ 12 px, note ≥ 13 px ; **le « 15 titulaires » ne tombe jamais sous 11 px** à 1280 (les cartes passent sans photo).
- Statuts en mots (blessé, non qualifié, en sélection) + icône ; pas de ligne rouge seule ; note au poste en chiffre.
- Contraste ≥ 3:1 pour le cadre de sélection et le focus, qui sont **deux signes distincts** (épaisseur et forme) ; focus ≥ 2 px, distinct de la sélection.
- Ordre de focus : rail → en-tête (Proposition du staff, Enregistrer, Valider) → onglets → terrain (1→15) → banc (16→23) → Candidats (filtres puis lignes) → Impact (lecture) → pied.
- Annonces d'état (si technologie d'assistance disponible ; sinon texte visible) : « Poste n° 5 sélectionné, candidats : 8 », « Joueur n° 5 pris », « Joueur n° 5 posé en n° 19 », « Feuille incomplète : il manque un talonneur ».
- Barres d'impact : valeurs numériques aux deux bouts (D6).
- Aucune limite de temps (K7) ; le brouillon survit à un changement d'écran.
- Mouvement réduit : le clignotement de l'écart d'impact devient un changement instantané.
- **Contraste** : texte ≥ 4,5:1 sur son fond réel (cartes de poste comprises) ; cadres, focus, icônes d'état et barres ≥ 3:1 (C1, C3) ; jetons à valider avec la direction artistique.

## 11. Ce qu'on retire, déplace, garde

| Écran actuel | Décision |
|---|---|
| Fenêtre modale « Poste 05 · choisir un joueur » + liste « Hors groupe » + avis « Affectation indisponible » | **Remplacées** par le panneau Candidats (grisés + raisons visibles) |
| Pastilles « 23 joueurs sélectionnés » + « Composition valide » | Fusionnées dans la ligne de validité |
| « Valider les 23 » et « Enregistrer le plan » | « Valider la feuille » (seul principal) ; « Enregistrer » secondaire |
| Colonne « Identité de jeu » (3 pastilles + 5 barres + 3 cartes) | Remplacée par « Impact » (6 barres face à face) ; plan = résumé + lien Consignes |
| Rangée basse Mêlée / Touche / Jeu au pied + Vigilance physique | Doublon des barres retiré ; vigilance gardée en une ligne dans l'Impact |
| Bannière « Avis du staff » (grande image) | Retirée ; son message va dans la ligne de validité |
| Onglet « Analyse adverse » | Retiré (lien vers le dossier adverse de la Préparation) |
| « Note au poste 0 » des joueurs non qualifiés | « — » + raison |
| Terrain 15 postes, banc 8, XV proposé par le staff | **Gardés** |
| `lineup_board.gd` (ancien terrain, police 11 px) | Hors périmètre : dette à retirer (relevé n°13) |
| Composition en match (écran 14) | Même composant, bouton « Valider et reprendre », nombre de permutations restant en plus ; non spécifié ici |

## 12. Déviations des motifs

- **E6 / E7** : fusion en un motif « choisir un joueur » (incohérence 2 du relevé).
- **E7** : glisser-déposer avec alternative clavier (motif manquant n°12).
- **W2** : l'avis modal d'erreur est remplacé par un message en ligne avec correction ; la modale reste pour les erreurs bloquantes du moteur.
- **W1** : « Valider avec n avertissements ? » nomme l'action, focus sur « Revoir ».
- **N5** : Échap ferme d'abord fenêtre, « pris » ou panneau, puis revient de la sous-page, et n'ouvre le menu pause que sur l'écran principal (règle unique de Léo, 19/11/2026).

## 12 bis. Transitions, localisation, entrées

**Transitions** : ouverture/sortie instantanées (100 ms au plus en « Normales », 0 en « Aucune ») ; changement d'onglet et ouverture du panneau Candidats : instantanés ; permutation de deux joueurs : changement net, avec un cadre de surbrillance de 150 ms (nul en « Mouvement réduit ») ; recalcul des barres d'impact : valeurs immédiates, clignotement de l'écart une seule fois (M4 : jamais plus de 3 par seconde) ; squelette de chargement 0,35 s.

**Localisation** (+40 % prévu ; pas de nom tronqué sur la carte de poste, abréviation « initiale + nom » prévue) : titre ≤ 30 ; ligne de validité ≤ 2 lignes de 60 ; chaque blocage ≤ 70 ; bouton ≤ 24 (« Valider la feuille ») ; Prénom NOM carte ≤ 18 (abrégé au-delà) ; nom au banc ≤ 22 ; libellé de barre d'impact ≤ 22 ; statut candidat ≤ 40 ; titre du panneau ≤ 48.

**Entrées (souris + clavier ; manette hors périmètre)** : [x] choisir, affecter, échanger, libérer, valider à la souris ; [x] les mêmes au clavier, dont « prendre / poser » (§8) ; [x] ordre de focus (§10) ; [x] glisser-déposer facultatif avec alternative complète ; [x] aucune précision de souris requise.

## 13. Critères d'acceptation

- [ ] Ouvert, la page répond (focus placé) en < 200 ms ; l'affectation d'un candidat met à jour la ligne de validité en < 200 ms.
- [ ] Un « Annuler » de la proposition du staff reste affiché jusqu'à la prochaine action (aucune minuterie).
- [ ] La feuille entière (15 + 8) se compose au clavier seul ; le déplacement d'un joueur marche par « Espace / flèches / Espace ».
- [ ] Un candidat non éligible est grisé et sa raison est écrite dans la ligne ; aucune note « 0 » n'apparaît.
- [ ] Un blocage de feuille s'affiche avec sa correction ; « Valider » est grisé avec la raison à côté.
- [ ] Les 6 barres d'impact se recalculent en < 200 ms après une affectation.
- [ ] À 1280×720 et 130 % : 15 postes, banc et ligne de validité visibles sans défiler ; aucun texte sous 12 px.
- [ ] Valider avec avertissements demande confirmation avec focus sur « Revoir ».
- [ ] Capture en niveaux de gris : joueur blessé, condition basse, poste vide distinguables par mots/icônes.
- [ ] Plan de jeu : les 4 zones tiennent dans un tableau ; la zone du schéma suit le focus de la ligne.

## 14. Questions ouvertes

| Question | Propriétaire | Statut |
|---|---|---|
| « Enregistrer le plan » : modèle de composition, de consignes, ou les deux ? | game-designer | À confirmer |
| Règle « six premières lignes formées » : lister les cas bloquants exacts dans le message | game-designer + moteur | À relever (loi 3, rugby-rules-reference) |
| Onglets « Phases arrêtées » et « Lecture du match » : même tableau que les zones ? | ux-designer | Non relus ici |
| Conserver deux emplacements pour les consignes (onglet Consignes et page Plan de jeu) ? | Léo | Proposé : onglet = global, page = avancé par zone |
| Mêlée non disputée / exclusion de première ligne : avertissement sur la feuille ? | game-designer | À décider |
| Banc de moins de 8 : valide selon la compétition (loi 3 : « jusqu'à huit selon l'organisateur ») ? | game-designer + moteur | À relever |
| Le moteur garde-t-il un brouillon de feuille entre deux validations (hypothèse de §6.7) ? | ui-programmer + moteur | À confirmer |
| Échap sur un écran racine du chapitre Tactique : retour ou pause ? | Léo | **Résolue le 19/11/2026** : menu pause |
