# UX Spec : 17 — Finances

Décisions de Léo du 19/11/2026 intégrées : densité « Football Manager » (corps ~13 px, tableaux 12-13 px, en-têtes 11-12 px, jamais sous 11 px à 1080p ; lignes de tableau 24-26 px ; échelle d'interface 90/100/115/130 %) ; règle unique d'Échap (ferme la fenêtre, sinon retour de fiche/sous-écran, sinon menu pause) et bouton « Menu » visible dans la coque ; « Budget de transferts » distinct de la trésorerie.

> **Statut** : en conception (proposé, non validé par Léo)
> **Auteur** : ux-designer (CCGS), mode autonome, rigueur `minimal`
> **Dernière mise à jour** : 19/11/2026
> **Phase du parcours** : 1.2 semaine type (décision ponctuelle), 1.4 fin de saison
> **Identifiant** : écran Finances (canevas dédié, 6 onglets : Synthèse, Trésorerie, Salaires, Transferts, Budget, Classement)
> **Plateforme** : PC souris + clavier ; palier Standard
> **Sources** : capture `finances-1920.png` (onglet Synthèse, semaine 5). `ui/decision_feedback.gd` lit `finance.cash` et `finance.wage`.
> **Non vérifié** : les cinq autres onglets, le grand livre, les états d'erreur et de déficit.

---

## 1. But

**Besoin** : savoir si le club est « dans le vert » et combien on peut dépenser sans mettre le conseil en colère.
**But du joueur** : répondre en 5 secondes à « puis-je recruter ou prolonger ? » et repérer ce qui pèse.
**Besoin du jeu** : lier les décisions (contrats, installations) à leurs conséquences chiffrées ; alimenter la confiance du conseil.

### 5 secondes
1. Un verdict : « Dans le vert / Sous tension / Dans le rouge » et la trésorerie.
2. Combien il peut dépenser : **Budget de transferts** (montant restant / alloué par le conseil, distinct de la trésorerie) + marge salariale.
3. Les trois vigilances (contrats, infrastructures, échéances).

### Hiérarchie
| Rang | Bloc | Pourquoi |
|---|---|---|
| Principale | Verdict + trésorerie + « Budget de transferts » | Répond à la question du joueur |
| Secondaire 1 | Vigilances (contrats à anticiper, infrastructures) | Ce qui demande une décision |
| Secondaire 2 | Prochaines échéances (semaine prochaine : salaires, formation, recettes) | Anticiper |
| Secondaire 3 | Répartition des charges (salaires, formation, staff) | Comprendre ce qui pèse |
| Derrière les onglets | Flux de trésorerie, flux récents, grand livre, budget détaillé | Analyse |

---

## 2. Contexte à l'arrivée

| Question | Réponse |
|---|---|
| Venait de | Bureau (alerte du conseil), Recrutement (avant une offre), fin de saison |
| Émotion | Prudence ; peur de mal dépenser |
| Charge cognitive | Moyenne : chiffres, unités variées |
| Sait déjà | Sa trésorerie approximative |
| Veut | Un feu vert ou rouge, un montant |
| Craint | Découvrir trop tard un déficit ; mal lire un chiffre |

**Cible émotionnelle** : « Je sais où j'en suis, je décide sans peur. »

---

## 3. Navigation

```
Finances (rail)
  └── Synthèse · Trésorerie · Salaires · Transferts · Budget · Classement
        ├── Vigilance « 25 contrats à anticiper » → Recrutement/Contrats
        ├── Vigilance « Infrastructures » → Club > Infrastructures
        └── « Ajuster les engagements » → Budget
```
**Mode** : écran plein.

| Entrée | Déclencheur |
|---|---|
| Rail, touche chiffre | clic |
| Alerte du conseil (Bureau, courrier) | lien |
| Recrutement avant offre | « Voir mes finances » |
| Fin de saison | alerte |

| Sortie | Destination |
|---|---|
| Vigilances | Contrats, Club |
| Ajuster les engagements | onglet Budget |
| Clic sur une opération | détail du flux |
| Échap | règle unique (décision de Léo, 19/11/2026) : ferme la fenêtre, sinon retour (historique), sinon menu pause |

---

## 4. Disposition

### 4.1 Wireframe 1280×720 (Synthèse)

```
┌────┬───────────────────────────────────────────────────────────────────────┐
│Rail│ ‹ Alder Fen XV › Finances                          [Préparer →]       │
│    ├───────────────────────────────────────────────────────────────────────┤
│    │ [Synthèse][Trésorerie][Salaires][Transferts][Budget][Classement]      │
│    ├───────────────────────────────────────────────────────────────────────┤
│    │ ┌ VERDICT ──────────────────────────────────────────────────────────┐ │
│    │ │ ● DANS LE VERT     Trésorerie 3,54 M€                             │ │
│    │ │ Budget de transferts : X € restant / Z € alloué · Marge salariale : Y │ │
│    │ └────────────────────────────────────────────────────────────────────┘ │
│    │ ┌ VIGILANCES ─────────────────┐ ┌ PROCHAINES ÉCHÉANCES ─────────────┐ │
│    │ │ ! 25 contrats à anticiper → │ │ Sem. 6 · Salaires      −22 300 €  │ │
│    │ │ ! Infrastructures (devis) → │ │ Sem. 6 · Formation      −4 300 €  │ │
│    │ └─────────────────────────────┘ │ Sem. 6 · Recettes      +62 400 €  │ │
│    │ ┌ OÙ VA L'ARGENT ─────────────┐ └────────────────────────────────────┘ │
│    │ │ Salaires 29 % ▓▓░░░░░░░     │ ┌ COURBE : 12 dernières semaines ─────┐ │
│    │ │ Formation 6 % ▓░░░░░░░░     │ │ (ligne : solde ; barres : mouvements)│ │
│    │ │ Staff, fonct. 65 % ▓▓▓▓▓▓   │ └──────────────────────────────────────┘ │
│    │ └─────────────────────────────┘                                          │
│    │ [ Ajuster les engagements → ]                                           │
│    │ Pied : Espace Suite · 1 à 9 Menus · Échap Retour · Ctrl K · F1          │
└────┴───────────────────────────────────────────────────────────────────────┘
```
Le tableau « flux récents » (8 lignes, pagination 1/5) passe dans l'onglet Trésorerie.

### 4.2 Zones
| Zone | Contenu | Taille | Défilable | Débordement |
|---|---|---|---|---|
| Barre d'onglets | 6 onglets | pleine × 5 % | Non | — |
| Verdict | état + trésorerie + disponible | 20 % | Non | — |
| Vigilances | 2 à 3 lignes à action | 20 % × 25 % | Non | « Voir tout » |
| Échéances | 3 à 5 lignes | 20 % × 25 % | Non | — |
| Répartition | 3 barres + valeurs | 20 % × 25 % | Non | — |
| Courbe | solde sur 12 semaines | 20 % | Non | — |

### 4.3 Composants
| Composant | Rôle | Existant ? |
|---|---|---|
| Carte de verdict (chip + mot + trésorerie) | feu vert / orange / rouge en mots | **Nouveau** (compte sur le principe : couleur + mot + icône) |
| 4 cartes de chiffres du haut (Trésorerie, Marché du recrutement, Salaires, Marge courante) | aujourd'hui | Existant → **réduit à 2 chiffres** (trésorerie, Budget de transferts restant / alloué) ; « Marché du recrutement 27 profils » est du recrutement, pas de la finance : déplacer |
| Vigilance (ligne à action) | décision | Existant |
| Échéance | anticipation | Existant |
| Barres de répartition avec % | où va l'argent | Existant |
| Courbe de flux | historique | Existant : **axe n° 12 → n° 1** déroutant, remplacer par semaines datées |
| Tableau des opérations | détail | Existant, réutiliser le socle `tableau.gd` |

**Focus à l'ouverture** : l'onglet courant. Premier élément de contenu : la ligne de vigilance la plus urgente.

---

## 5. États

| État | Déclencheur | Visuel | Comportement |
|---|---|---|---|
| Dans le vert | trésorerie et marge positives | chip « Dans le vert » + coche | — |
| Sous tension | marge courante négative mais trésorerie positive à fin de saison | chip ambre « Sous tension » + « Marge −14,5 k€ par semaine, trésorerie suffisante jusqu'à la sem. N » | **C'est la situation de la capture** : marge à −14,5 k€ mais projection positive (3,75 M€), sans verdict |
| Dans le rouge | trésorerie < 0 ou prévision < 0 | chip rouge « Dans le rouge » + triangle ; blocage des offres expliqué | Gabi prévient |
| Première semaine | pas d'historique | « Pas encore de flux : le premier mouvement arrive en semaine 1 » | graphique remplacé |
| Aucune vigilance | rien à signaler | « Rien à surveiller cette semaine. » + coche | — |
| Chargement | moteur | « … » | boutons grisés avec raison |
| Erreur de calcul | moteur | « Les chiffres de la semaine ne sont pas disponibles. Réessaie. » + bouton | — |
| Fin de saison | bilan | bandeau « Bilan de la saison » + décisions de contrats à ranger | — |

---

## 6. Interactions

### 6.1 Souris
| Cible | Action |
|---|---|
| Onglet | clic |
| Vigilance | clic ouvre l'écran lié |
| Ligne d'échéance | clic ouvre le détail |
| Barre de répartition | survol : montant et reste de la saison |
| Opération du tableau | clic, détail ; en-tête = tri |
| Pagination | Préc./Suiv. |

### 6.2 Clavier
| Touche | Effet | Statut |
|---|---|---|
| Tab / Maj+Tab | boutons et lignes | à vérifier |
| Ctrl+Tab | onglet suivant | proposé |
| ↑ ↓ dans les tableaux | ligne | à brancher |
| Entrée | ouvre | existant |
| Échap, Espace, F1, Ctrl K | globaux | existant |

### 6.3 Restrictions
Mode consultation : pas d'écriture. « Ajuster les engagements » mène à un écran avec confirmation (voir `interaction-patterns.md` W1 : libellé = action, focus sur Annuler).

---

## 7. Données

| Donnée | Source | Mise à jour | Format | Si manquant |
|---|---|---|---|---|
| Trésorerie | `finance.cash` | à chaque semaine, à chaque opération | euros | « — » |
| Masse salariale | `finance.wage` | à chaque contrat | euros / semaine | « — » |
| Disponible pour les transferts | `finance.transferBudget.disponible` (enveloppe : `enveloppe`, détail : `depense`, `reconstitue`) | à chaque dépense, vente ou mouvement de caisse | euros à l'euro + « sur X € alloués par le conseil » | `transferBudget` absent ou `actif` faux : tuile actuelle « Marché du recrutement » conservée (pas de « Budget non fixé ») |
| Report et rallonge (19/11/2026) | `finance.transferBudget.report`, `rallonge`, `rallongesAccordees`, `rallongeMax` | passage de saison (report), réponse du conseil (rallonge) | « sur X € alloués » = enveloppe + report + rallonges ; infobulle : « Report de la saison passée : X € » et « Rallonges accordées par le conseil : X € (n sur m possibles) », lignes absentes si 0. La demande de rallonge se fait depuis Recrutement (fiche 09 §6.6), jamais depuis Finances | champs lus comme 0 (sauvegarde antérieure) |
| Marge courante par semaine | revenus − charges connus | semaine | euros | « — » |
| Répartition des charges | grand livre | semaine | % + euros | masquée |
| Flux | grand livre | par opération | date, libellé, montant | « Aucun flux » |
| Vigilances | contrats, installations, conseil | semaine | texte + route | « Rien à surveiller » |
| Projection fin de saison | prévision | semaine | euros | « — » |

Source des champs au-delà de `cash` et `wage` : **non vérifiée dans le code lu**. L'UI lit, n'écrit pas.

**Événements** : ouvrir un écran lié ; « Ajuster les engagements » (navigation).

---

## 8. Ce qu'on retire ou déplace

| Élément | Décision | Raison |
|---|---|---|
| Carte « Marché du recrutement · 27 profils » | Déplacer vers Recrutement | Pas une donnée financière |
| Bandeau hero « Garder une longueur d'avance. » | Réduire à un titre | Surcharge décorative, ~190 px |
| Chips « hors cotisations », « hors guichet », « Trésorerie du club », « 27 accessibles » | Retirer | Bruit ; jargon |
| Préfixe « Semaine 4 · Préparation · » répété sur chaque ligne de flux | Retirer, mettre la semaine en colonne | Lecture |
| Vocabulaire : « écritures », « journal », « cumul net affiché », « engagements connus » | Remplacer par « mouvements », « historique », « solde », « dépenses prévues » | Vocabulaire de manager, G2 |
| Unités mélangées (k€, M€, € entiers) | Une règle : ≥ 1 M€ en M€ (2 décimales), sinon en k€ (1 décimale), détail en € | Cohérence |
| Marge négative sans verdict | Ajouter la chip de verdict et une phrase | Besoin des 5 secondes |
| Axe « n° 12 … n° 1 » | Semaines datées de gauche à droite | Compréhension |
| Projection du bas « Solde positif » seul | Fusionner dans le verdict | Doublon |
| Numérotation 01-08 des lignes de flux | Retirer | Aucune valeur |

---

## 9. Animations
| Transition | Durée | Réduit |
|---|---|---|
| Changement d'onglet | fondu 150 ms | instantané |
| Barres de répartition qui se remplissent | 300 ms | valeur directe |
Pas de compteur qui défile pour les montants.

---

## 10. Accessibilité (Standard : D6, T1, T5, C1, K1)

| Texte | Fond | Seuil |
|---|---|---|
| Montants et libellés | panneau sombre | 4,5:1 |
| Chips de catégorie (« Installations », « Salaires », « Autre ») | teinte | 4,5:1 sur la teinte de la chip |
| Chiffres en vert (entrées) / rouge (sorties) | tableau | signe + / − écrit, jamais la couleur seule |

| Élément | Risque | Mitigation |
|---|---|---|
| Verdict | vert/ambre/rouge | mot + icône (coche, point d'exclamation, triangle) |
| Courbe (barres vertes / rouges) | couleur | légende avec forme ; barres des sorties hachurées |
| Barres de répartition | couleur | % écrit |

**Focus** : onglet → verdict → vigilances → échéances → répartition → courbe → bouton. **Annonces** : « Dans le vert, trésorerie 3,54 millions d'euros ».
**Charge cognitive** : 5 blocs sur la Synthèse (aujourd'hui 8) ; chiffres ≤ 7.

---

## 11. Critères de réception

- [ ] Un verdict en mots (vert / tension / rouge) visible sans défiler.
- [ ] « Disponible pour recruter » affiché en tête.
- [ ] Aucune unité mélangée dans un même bloc.
- [ ] Aucun terme comptable (« écritures », « guichet ») sans infobulle d'explication.
- [ ] Entrées et sorties distinguables en niveaux de gris (signe, forme).
- [ ] Tout texte ≥ 12 px réels (tableaux) / 13 px (corps) à 1920 ; jamais sous 11 px.
- [ ] Tableau triable et parcourable au clavier.
- [ ] Les 5 blocs tiennent à 1280×720 sans défilement.

## 12. Questions ouvertes

| Question | Propriétaire | Résolution |
|---|---|---|
| Quel est exactement le « budget transferts » disponible, et qui le fixe ? | game-designer | Résolue : le conseil, une fois par saison ; `finance.transferBudget` ([GDD](../../docs/gdd/budget-transferts.md)) |
| Quand le verdict passe-t-il de « tension » à « rouge » ? (seuils) | game-designer / économie | Ouverte |
| Cinq onglets non capturés | ui-programmer | À capturer |
| « Classement » dans Finances : de quoi ? (non vérifié) | game-designer | Ouverte |

## 13. Ajouts de la revue UX (19/11/2026)

**Seuils du verdict (proposés, à confirmer par game-designer)** : « Dans le vert » = marge courante ≥ 0 ; « Sous tension » = marge < 0 mais trésorerie projetée à fin de saison ≥ 0 ; « Dans le rouge » = trésorerie ou projection < 0. Ces trois conditions sont des réglages de données, pas des constantes d'interface.

**Bloquant levé (19/11/2026)** : « Disponible pour les transferts » (but n° 2 des 5 secondes) a sa source : `finance.transferBudget` (règle : [docs/gdd/budget-transferts.md](../../docs/gdd/budget-transferts.md)). Budget actif : la deuxième tuile du haut, à côté de la Trésorerie, affiche le restant à l'euro et « sur X € alloués par le conseil » ; infobulle : enveloppe, trésorerie, dépensé, reconstitué, nombre de profils au marché ; clic = Recrutement. Budget inactif : tuile « Marché du recrutement » inchangée.

**Localisation (longueurs max, +40 % prévus)** : verdict 18 caractères ; libellé de vigilance 48 ; libellé d'échéance 30 ; montant 12 (« −1,25 M€ ») ; bouton 28.

**Méthodes d'entrée (PC)**
- Souris : §6.1 ; lignes de tableau 24-26 px de haut (comme Football Manager).
- Clavier seul : Tab dans l'ordre de §10, ↑ ↓ dans les tableaux, Ctrl+Tab pour les onglets ; aucun glisser-déposer.
- Manette : hors périmètre.

**Critères supplémentaires**
- [ ] La Synthèse s'affiche en moins de 400 ms.
- [ ] Rendu correct à 1280×720, 1920×1080 et 2560×1440.


## 14. Revue DA du 20/11/2026 : choix de Léo et mise en œuvre

**Choix de Léo** : variante 1 « Verdict en tête, quatre blocs » (avis DA). Emprunts : le bloc **Alloué / Engagé / Restant** de la variante 3 (budget de transferts) ; la **colonne de verdict fixe** de la variante 2 sur les autres onglets. Maquettes : `direction-artistique/interface/revue-20261119/apercus/17-finances-{1,2,3}.png`.

**Synthèse** : verdict de la semaine (mot + pictogramme + « palier n sur 3 » + trois repères Saine / Sous tension / En danger + phrase), puis trois chiffres (trésorerie, budget de transferts en trois cases, marge courante), puis Vigilances, Prochaines échéances, Où va l'argent, et la courbe des 12 derniers mouvements. Seuils du verdict : §13 (marge ≥ 0 / marge < 0 avec prévision ≥ 0 / trésorerie ou prévision < 0).
**Autres onglets** : colonne fixe à gauche (verdict, trésorerie, budget de transferts, marge, vigilances) et contenu à droite. La colonne est présente aussi sur Classement.
**Budget de transferts** : Alloué = enveloppe + report + rallonges ; Engagé = dépensé − reconstitué ; Restant = disponible (peut être limité par la caisse : la note le dit). La demande de rallonge reste dans Recrutement (§7) ; le bloc ouvre Recrutement.
**Tout est cliquable** : verdict → Budget ; trésorerie → Trésorerie ; budget de transferts → Recrutement ; marge → Budget ; vigilances → Salaires (contrats à anticiper), Infrastructures (Stratégie), Salaires (plafond) ; échéances et lignes de répartition → Salaires, Budget, Trésorerie, Infrastructures ; chaque mouvement du journal → l'écran de sa catégorie ; barre de la courbe → le mouvement dans la Trésorerie ; noms de joueurs → fiche complète (survol : mini-fiche) ; noms de clubs (Classement) → fiche du club ; totaux du journal (Trésorerie) → Budget. Aucune fenêtre ; Finances ne dépense rien elle-même (les dépenses se confirment sur leur écran : Infrastructures, Formation, Recrutement).
**1280×720** : le plancher de 12 px grossit le petit texte ; le verdict garde alors les trois paliers (mot + symbole) et la phrase, le barème détaillé passe en infobulle ; la marge de la Synthèse met recettes et charges sur deux lignes ; le détail des vigilances prend toute la largeur.
**Graphes** : série « nous » en trait du club, entrées pleines et sorties hachurées en ivoire-2 (forme, pas couleur), ligne d'équilibre en tirets sur une graduation « 0 € » (graduations rondes 1/2/5) ; le journal ne porte ni date ni semaine : aucune valeur hebdomadaire inventée, l'axe va du mouvement le plus ancien au plus récent.
**Couleurs** : jetons de la charte seulement ; aucun or ; D / N / V réservés aux étiquettes de santé des clubs (liseré teinté + mot, sans pastille arrondie ; ton club : fond relevé + liseré ivoire, pas de cadre complet).