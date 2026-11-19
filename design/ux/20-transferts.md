# Fiche UX 20 — Centre des transferts et négociation

> **Template**: UX Spec
> **Statut** : **REJETÉE par Léo le 19/11/2026** (« j'aime pas tout ça… je veux plutôt la même façon de faire que FM ou Tennis Manager ou autre avec des vrais écrans pour chaque offre »). Conservée pour mémoire ; ne pas l'implémenter. Remplacée par le flux « une offre = un écran » : `production/ui/transferts/recherche-flux-offres.md` et `production/ui/transferts/decisions-leo-20261119.md`.
> **Ancien statut** : proposé, revu APPROVED (ux-designer CCGS, `/team-ui` phase 1, 19/11/2026, mode autonome, rigueur `minimal`) — conception seulement, aucun code
> **Écrans** : `Centre des transferts` (écran plein, 6 onglets) + `Négociation` (écran plein dédié) · carrière Monde
> **Plateforme** : PC (Windows, version native Godot), souris + clavier ; manette et tactile hors périmètre du projet
> **Phases du parcours** : semaine type (offre reçue, poste à combler), hiver (joueurs libres jusqu'au 31/12, recrues supplémentaires jusqu'au 31/01, pré-contrats dès janvier), période des mutations (1er mai – 30 juin), arrivées du 1er juillet
> **Palier d'accessibilité** : Standard (exception de densité « Football Manager » du 19/11/2026, `design/accessibility-requirements.md`)
> **Liés** : fiche 09 (Recrutement : pistes, recruteurs, rapports — inchangée sauf §10), fiche 17 (Finances), fiche 07 (Effectif, vue Contrats), fiche 08 (Fiche joueur, onglet Contrat), fiche 05 (Réception, courrier « transferts ») ; GDD `docs/gdd/budget-transferts.md`, `docs/gdd/vente-joueurs.md` (PR #1009), calendrier des mutations LNR et pré-contrats (chantier en cours, GDD à venir) ; motifs `design/ux/interaction-patterns.md` (N2, N5, E1, E2, E3, W1, W2, F1, F2, F7, F8, F9) ; recherche `production/ui/transferts/recherche-fm.md`

Demande de Léo (19/11/2026) : « je veux que les écrans de transfert soient des vrais écrans comme dans FM. » On reprend **les fonctions et l'organisation** du Transfer Centre de Football Manager (hub unique, onglets, négociation dédiée, offres reçues traitées au même endroit), **pas son apparence** : couleurs, mises en page et identité restent celles de Rugby Legacy 27.

## 1. But

- **Joueur** : conduire tous ses mouvements de joueurs au même endroit — voir ce qu'il peut dépenser, où en sont ses affaires, répondre aux clubs qui veulent ses joueurs, signer pour la saison prochaine — sans empiler les fenêtres.
- **Jeu** : faire du marché un temps fort de la saison (échéances du calendrier des mutations, accords différés, arrivées du 1er juillet) et rendre lisibles les règles d'argent (enveloppe du conseil, rallonge, reconstitution par les ventes, report).
- **Dans les 5 secondes** (Vue d'ensemble) : (1) **ce qui attend ma réponse** (offres, négociations, échéance proche) ; (2) **combien je peux dépenser** (disponible / enveloppe) ; (3) **où en est le calendrier** (période ouverte ou fermée, prochaine date).

## 2. Contexte d'arrivée

| Question | Réponse |
|---|---|
| Venu de | Rail (Recrutement › Transferts) ; courrier « offre_transfert », « vente_executee », « vente_annulee » (lien direct vers l'onglet) ; Bureau (alerte « offre à traiter », « période des mutations ouverte ») ; fiche joueur (« Approcher », « Proposer aux autres clubs ») ; Recrutement (« Approcher le joueur » ouvre la Négociation) |
| État d'esprit | Semaine type : réactif (une offre est arrivée). Hiver et mai-juin : stratège (bâtir la saison prochaine), sous pression des dates |
| Charge cognitive | Haute : argent, dates, plusieurs affaires en parallèle, informations incomplètes |
| Veut | Savoir quoi traiter d'abord ; décider vite et en connaissance de cause |
| Craint | Rater une échéance ; dépasser l'enveloppe ; vendre un cadre sans le savoir ; perdre une affaire faute de réponse |

**Le joueur arrive en voulant** traiter ce qui est en attente puis préparer le prochain mouvement. **Cible émotionnelle** : « Je tiens mon marché en main, comme un vrai manager. »

## 3. Navigation

```
Carrière Monde
  └── Recrutement (rail)                       ← sous-navigation de chapitre N2
        ├── Pistes          = fiche 09 (Besoins · Recherche · Joueurs suivis · Rapports, missions, comparaison)
        └── Transferts      = CET ÉCRAN, « Centre des transferts »
              ├── Vue d'ensemble (défaut)
              ├── Négociations (n)
              ├── Offres reçues (n)
              ├── Joueurs proposés (n)
              ├── Pré-contrats (n)
              ├── Historique
              └── Négociation · {Joueur}     ← ÉCRAN PLEIN dédié (pas une fenêtre)
```

- **Modalité** : écran plein ; la Négociation est un **écran plein** qui remplace le Centre (fil d'Ariane « Recrutement › Transferts › Négociation · Prénom NOM ») ; seules les **confirmations** restent en fenêtre W1 (engagement d'argent). Plus aucune pile de fenêtres (fin de W3 pour la négociation, le marché entre clubs et les offres reçues).
- **Entrées** : rail Recrutement puis bouton de chapitre « Transferts » (N2) ; courrier (arrive sur l'onglet concerné, ligne sélectionnée) ; Bureau ; fiche joueur ; « Approcher » de la fiche 09 (arrive dans la Négociation) ; accès rapide N4 (« transferts », « offres », « négociation »).
- **Sorties** : fiche joueur (Entrée sur une ligne) ; Finances (clic sur le bloc budget) ; Effectif › Contrats (lien « fins de contrat ») ; Recrutement › Pistes (lien « Trouver un joueur »).
- **Échap** (règle unique du 19/11/2026) : ferme la confirmation ouverte ; sinon, dans la Négociation, revient au Centre (onglet d'origine, brouillon conservé) ; sinon referme le panneau de détail ouvert ; sinon menu pause.
- **Retour d'une Négociation** : l'onglet et la ligne d'origine sont restaurés (focus sur la ligne).

## 4. Hiérarchie

1. **Principal** : la file « À traiter » (Vue d'ensemble) ; la ligne sélectionnée et son action (autres onglets) ; l'offre en cours (Négociation).
2. **Secondaires** : (a) le **budget** (disponible / enveloppe), présent en tête de **chaque** onglet et en colonne fixe dans la Négociation ; (b) la **période** (ouverte/fermée + prochaine date) ; (c) les compteurs d'onglets.
3. **Reste** : historique, échos du marché, détails de valeur, conséquences légères d'un départ.

## 5. Wireframes 1280×720

Conventions : rail 124 px à gauche (N1), barre haute N3 au-dessus (non redessinée), pied 36 px (F4). `[ ]` bouton, `( )` pastille, `▾` liste, `»` lien. Le **bandeau commun** (B) est identique sur les six onglets.

### 5.0 Bandeau commun (haut de chaque onglet, 64 px)

```
│ Recrutement › Transferts      (Pistes)(Transferts)                                                 │
│ CENTRE DES TRANSFERTS   Disponible 1 240 000 € sur 1 600 000 €  »   Période des mutations : FERMÉE │
│                         dépensé 410 000 · reconstitué 50 000          réouverture le 1er mai (J-163)│
│ [Vue d'ensemble][Négociations 2][Offres reçues 1][Joueurs proposés 3][Pré-contrats 0][Historique]  │
```

### 5.1 Vue d'ensemble (défaut)

```
┌────┬───────────────────────────────────────────────────────────────────────────────────────────────┐
│Nav │ (bandeau commun B)                                                                             │
│    ├──────────────────────────────────────────────┬────────────────────────────────────────────────┤
│    │ À TRAITER (3)                                │ CALENDRIER DES MUTATIONS                        │
│    │ ▸ Offre de Dax pour Tom ROUX · 60 000 €      │ 19/11 ● aujourd'hui                             │
│    │   expire fin de la semaine prochaine [Voir]  │ 31/12   fin des signatures de joueurs libres    │
│    │ ▸ Négociation : Léo MARTIN attend ta         │ 01/01   pré-contrats possibles (6 derniers mois)│
│    │   proposition (2/3)              [Reprendre] │ 31/01   fin des 2 recrues supplémentaires (2/2) │
│    │ ▸ Accord avec Bayonne : départ de Hugo PETIT │ 01/05 → 30/06  période des mutations            │
│    │   le 1er mai · à revérifier      [Voir]      │ 01/07   arrivées et départs effectifs           │
│    ├──────────────────────────────────────────────┤ Jokers médicaux : 1 joueur éligible »           │
│    │ MOUVEMENTS PRÉVUS                            ├────────────────────────────────────────────────┤
│    │ Arrivées (1er juillet) : 1 pré-contrat       │ BESOINS DU CLUB (rappel)                        │
│    │ Départs : 1 accord (1er mai) · 6 fins de     │ P1 Talonneur · P2 Deuxième ligne · P3 3e ligne  │
│    │ contrat »                                    │ Pistes suivies : 4  » Trouver un joueur          │
│    │ Bilan de la saison : −360 000 € (net)        ├────────────────────────────────────────────────┤
│    │                                              │ ÉCHOS DU MARCHÉ (5 derniers)                    │
│    │                                              │ Clermont recrute un pilier pour 220 000 € …     │
├────┴──────────────────────────────────────────────┴────────────────────────────────────────────────┤
│ Échap Retour · Ctrl+Tab Onglet suivant · Entrée Ouvrir · F1 Aide                                    │
└─────────────────────────────────────────────────────────────────────────────────────────────────────┘
```

| Zone | Contenu | Taille | Défile ? | Débordement |
|---|---|---|---|---|
| Bandeau B | titre, budget, période, onglets | 100 % × 64 px + 32 px onglets | Non | montant jamais tronqué ; la ligne « dépensé · reconstitué » se replie en infobulle sous 115 % |
| À traiter | file triée par urgence | 52 % × 45 % | Vertical | « + n autres » ouvre l'onglet concerné |
| Mouvements prévus | arrivées, départs, bilan | 52 % × 30 % | Non | lignes résumées, liens |
| Calendrier | 6 dates + jokers | 48 % × 45 % | Non | dates passées grisées **et** barrées (« passé ») |
| Besoins (rappel) | 3 priorités, pistes suivies | 48 % × 15 % | Non | lien vers Pistes |
| Échos du marché | 5 derniers mouvements du Monde | 48 % × 15 % | Non | « Voir l'historique » |

**Focus à l'ouverture** : premier élément d'« À traiter » ; file vide : bouton « Trouver un joueur ».

**Ordre de la file « À traiter »** (fixe, puis date la plus proche dans chaque groupe) : (1) offres reçues qui expirent cette semaine ; (2) négociations qui attendent ta réponse ; (3) accords différés exécutés ou tombés depuis ta dernière visite ; (4) échéances du calendrier à 7 jours ou moins ; (5) autres offres reçues. Chaque ligne : phrase (≤ 90 caractères, 2 lignes), date en mots, un seul bouton. Un élément quitte la file quand il est traité, jamais au bout d'un délai.

**Infobulle du budget** (bandeau B, et clic = Finances) : reprise de la fiche 09 §6.1 : enveloppe fixée, « Report de la saison passée : X € » (si > 0), « Rallonges accordées par le conseil : X € (n sur m possibles) », dépensé, reconstitué par les ventes, caisse libre, rappel « les salaires n'entrent pas dans l'enveloppe ». La ligne visible « dépensé · reconstitué » ajoute « rallonge » et « report » seulement si elle tient (50 caractères).

### 5.2 Négociations (n)

```
│ (bandeau commun B)                                                                                  │
│ (Toutes)(Arrivées)(Prolongations)        Tri : échéance ↑                                           │
│ ┌ Joueur            Poste      Club          Type            Étape                 Échéance ┐┌Détail─────────┐
│ │ Léo MARTIN        Ailier     libre         Joueur libre    Ta proposition (2/3)  31/12    ││Léo MARTIN      │
│ │ Paul DUBOIS       Pilier g.  Toulon        Entre clubs     Contrat du joueur     30/06    ││Dernière réponse│
│ │ Jean ROUX         Talonneur  (ton club)    Prolongation    Réponse reçue         30/06    ││« Il demande    │
│ └──────────────────────────────────────────────────────────────────────────────────────────┘│ 1 900 €/sem. » │
│ 3 négociations · 1 attend ta réponse                                                         │[Reprendre la   │
│                                                                                              │ négociation]   │
│                                                                                              │[Abandonner…]   │
```

Colonnes (tableau socle E3) : Joueur · Poste · Club (ou « libre », « ton club ») · Type (Joueur libre / Entre clubs / Prolongation / Pré-contrat) · Étape (mots : Accord avec le club · Contrat du joueur · Ta proposition (n/3) · Réponse reçue · Concurrence en cours) · Échéance (date de la fenêtre qui la limite). Tri par défaut : « attend ta réponse » d'abord, puis échéance. Action principale du panneau : **Reprendre la négociation** (ouvre l'écran §5.7) ; secondaire : **Abandonner…** (W1, focus sur Annuler).

### 5.3 Offres reçues (n)

Reprend **intégralement** le contenu et les règles de la fenêtre « Offres reçues » (`player_sales_view.gd`, fiche 09 sur la PR #1009), en tableau + panneau au lieu d'une pile de cartes.

```
│ (bandeau commun B)                                                                                  │
│ Période des mutations : du 1er mai au 30 juin. Hors période : une vente acceptée devient un accord  │
│ effectif le 1er mai ; le joueur reste et joue jusque-là.                                            │
│ ┌ Joueur       Poste    Âge  Club       Offre      Valeur est.  Type        Expire      ┐┌Offre──────────────┐
│ │ Tom ROUX     Talonn.  32   Dax        60 000 €   70 000 €     Proposé     sem. proch. ││Dax propose 60 000€│
│ │ Max LEROY    Ouvreur  24   Bayonne    410 000 €  350 000 €    Spontanée   cette sem.  ││Caisse après …     │
│ └───────────────────────────────────────────────────────────────────────────────────────┘│Effectif après 39  │
│ VENTES EN ATTENTE (1) : Hugo PETIT → Bayonne · 120 000 € · départ le 1er mai               │Budget : +30 000 € │
│                                                                                            │« Ce départ        │
│                                                                                            │ touchera le       │
│                                                                                            │ vestiaire… »      │
│                                                                                            │[CONCLURE L'ACCORD…]│
│                                                                                            │[+5 %][+10 %][+15 %]│
│                                                                                            │[Refuser]          │
```

Panneau (dans l'ordre) : phrase d'offre ; note (« Offre spontanée : tu ne l'avais pas proposé. ») ; validité ; caisse après, effectif après (+ joueurs de complément), budget de transferts (+50 % ou « enveloppe à son plafond »), JIFF, feuille de match, **conséquences légères** ; boutons **ACCEPTER…** (hors période **CONCLURE L'ACCORD…**), **Demander +5 / +10 / +15 %** (une fois), **Refuser**. Blocage : bouton grisé **et** raison écrite sur le panneau, avant le clic. Confirmation de vente : inchangée (W1, libellé = action, focus sur ANNULER).

### 5.4 Joueurs proposés (n) — statut de transfert de mon effectif

```
│ (bandeau commun B)                                                                                  │
│ (Proposés)(Tout l'effectif)(Fins de contrat 6)                                                      │
│ ┌ Joueur        Poste     Âge  Contrat   Valeur est.  Statut                     ┐┌Statut──────────────┐
│ │ Tom ROUX      Talonn.   32   2027      70 000 €     Offre reçue (Dax)           ││Tom ROUX            │
│ │ Hugo PETIT    Centre    29   2028      120 000 €    Accord conclu · 1er mai     ││Proposé depuis le   │
│ │ Noé BLANC     Pilier d. 19   2029      —            Non vendable : espoir < 20  ││05/11 · 1 offre     │
│ └────────────────────────────────────────────────────────────────────────────────┘│[RETIRER DU MARCHÉ] │
```

Statut (F2, toujours en mots) : Non proposé · Proposé aux autres clubs · Offre reçue (club) · Accord conclu · départ le 1er mai · Non vendable : {raison} (espoir de moins de 20 ans, recrue de moins de 3 journées, prêté…). Actions : **Proposer aux autres clubs** / **Retirer du marché** (commande `sale_list`). Le filtre « Fins de contrat » liste les contrats qui finissent le 30 juin, avec « Prolonger » (ouvre la Négociation en mode Prolongation) — la vue Contrats de l'Effectif (fiche 07) reste la référence.

### 5.5 Pré-contrats (n)

```
│ (bandeau commun B)                                                                                  │
│ Pré-contrats possibles depuis le 1er janvier : joueurs dont le contrat finit le 30 juin.            │
│ Pas d'indemnité : tu négocies seulement le contrat du joueur. Il arrive le 1er juillet.             │
│ (Signés 1)(Possibles)(Mes joueurs convoités 2)                                                      │
│ ┌ Joueur        Poste    Âge  Club actuel   Fin de contrat  Salaire demandé  État        ┐┌───────────┐
│ │ Yann MOREL    Pilier g. 27  Castres       30/06           1 600 €/sem.     Signé · 1/07 ││ [Approcher│
│ │ …                                                                                      ││  le joueur]│
```

Trois vues : **Signés** (arrivées du 1er juillet, salaire, durée), **Possibles** (joueurs en dernière année ailleurs, issus des pistes suivies et des rapports ; action **Approcher le joueur** → Négociation en mode Pré-contrat, étape « Accord avec le club » sautée), **Mes joueurs convoités** (mes fins de contrat qu'un autre club peut approcher ; action **Prolonger**). Avant le 1er janvier : état « Fermé » (§8).

### 5.6 Historique

```
│ (bandeau commun B)                                                                                  │
│ Saison ▾ 2026-2027   (Arrivées)(Départs)(Tout)                 Bilan : dépensé 410 000 € · reçu 50 000 €│
│ ┌ Date    Joueur        Poste    De → Vers             Type            Montant      ┐               │
│ │ 12/09   Léo MARTIN    Ailier   libre → ton club      Joueur libre    prime 20 000 €│               │
│ │ 03/07   Paul DUBOIS   Pilier   Toulon → ton club     Entre clubs     180 000 €     │               │
│ └─────────────────────────────────────────────────────────────────────────────────┘               │
```

Lecture seule. Entrée sur une ligne : fiche joueur.

### 5.7 Négociation · {Joueur} (écran plein dédié)

```
┌────┬────────────────────────────────────────────────────────────────────────────────────────────────┐
│Nav │ Recrutement › Transferts › Négociation · Paul DUBOIS                     [Retour aux transferts]│
│    │ ① Accord avec Toulon  ✓ ─── ② Contrat du joueur  ● ─── ③ Conclusion                           │
│    ├──────────────────┬──────────────────────────────────────────────┬──────────────────────────────┤
│    │ JOUEUR           │ ② CONTRAT DU JOUEUR                          │ TON BUDGET (toujours visible)│
│    │ photo            │ Salaire /sem.   [ 1 800 € ]  demandé 2 000 € │ Disponible     1 240 000 €   │
│    │ Paul DUBOIS      │ Durée           [ 2 saisons ▾ ] (1 à 3)      │ Cette offre   −180 000 €     │
│    │ Pilier gauche·27 │ (pas de prime : indemnité réglée à l'étape ①)│ Après         1 060 000 €    │
│    │ Toulon           │ Fin de contrat proposée : 2028               │ sur l'enveloppe 1 600 000 €  │
│    │ Niv 71 · Pot 74  │                                              │ ──────────────────────────── │
│    │ (rapport 02/11)  │ RÉPONSES                                     │ Masse salariale après        │
│    │ Contrat : 2027   │ ① Toulon : « Le vendeur accepte cette        │ 48 % des recettes (max 52 %) │
│    │ Salaire 1 500 €  │   indemnité. » (180 000 €)                   │ Caisse après   2 310 000 €   │
│    │ » Fiche          │ ② Paul DUBOIS : « Il demande au moins        │ JIFF : 16 → 17               │
│    │ » Rapport        │   2 000 €/sem. » · proposition 1/3           │ ──────────────────────────── │
│    │                  │ Autres clubs sur le coup : 2                 │ Date d'effet : 1er juillet   │
│    │                  │                                              │ (hors période des mutations) │
│    │                  │        [Annuler]   [ENVOYER LA PROPOSITION]  │                              │
├────┴──────────────────┴──────────────────────────────────────────────┴──────────────────────────────┤
│ Échap Retour · Tab Champ suivant · ↑↓ ±1 000 € · Pg↑/Pg↓ ±10 000 € · Entrée Envoyer · F1 Aide       │
└─────────────────────────────────────────────────────────────────────────────────────────────────────┘
```

| Zone | Contenu | Taille | Défile ? | Débordement |
|---|---|---|---|---|
| Fil + étapes | fil d'Ariane, 3 étapes numérotées (mot + numéro + coche) | 100 % × 12 % | Non | libellés d'étape ≤ 24 |
| Joueur | identité, niveau observé, contrat actuel, liens | 22 % × 78 % | Vertical | « ? » si non observé |
| Étape en cours | champs + journal des réponses + action | 46 % × 78 % | Journal seul | journal : 6 dernières réponses, plus « Voir tout » |
| Ton budget | disponible avant/après, enveloppe, masse salariale, caisse, JIFF, date d'effet, rallonge | 32 % × 78 % | Non | jamais masqué ; montants jamais tronqués |

**Étapes selon le type** :

| Type | ① Accord avec le club | ② Contrat du joueur | ③ Conclusion |
|---|---|---|---|
| Entre clubs | indemnité (seuil du vendeur), date d'effet | salaire, durée | récapitulatif + concurrence + **SIGNER** (W1) |
| Joueur libre | sautée (« Joueur libre : pas d'indemnité ») | prime à la signature, salaire, durée ; propositions n/3 | récapitulatif + **SIGNER** |
| Pré-contrat | sautée (« Contrat en fin : pas d'indemnité ») | salaire, durée, prime | récapitulatif, arrivée le 1er juillet |
| Prolongation | sautée | salaire, durée, prime de prolongation (hors enveloppe, R2) | récapitulatif |

**Étape ① (entre clubs)** : champ **Indemnité** (pré-rempli avec le seuil connu du vendeur, `quote.fee`) ; **Date d'effet** en lecture : « Immédiate » si la période est ouverte, sinon « 1er juillet » (ou « 1er mai » selon le GDD du calendrier, voir Q) ; ligne « Échéancier : non proposé par ce club » réservée (P3, voir §13). Bouton **Proposer cette indemnité** → réponse du club dans le journal (accepte / demande au moins X). Accepté : coche ① et passage à ②.

**Étape ③ (conclusion)** : récapitulatif « Ce que tu signes » (indemnité, salaire × durée = coût total, prime, date d'effet, budget après, masse salariale après) ; si d'autres clubs sont sur le coup, la phrase « 2 autres clubs ont fait une offre : le joueur choisit l'offre la plus haute (salaire, puis indemnité). » ; bouton **SIGNER {NOM}…** → confirmation W1 (focus sur Annuler). Résultat : écran « Signé » (ou « Le joueur a choisi {Club} ») avec retour à l'onglet d'origine.

## 6. Blocs et données

### 6.1 Sources (le Centre affiche ; il ne possède aucune donnée de jeu)

| Donnée | Source moteur (existante sauf mention) | Rafraîchie | Absence |
|---|---|---|---|
| Disponible, enveloppe, dépensé, reconstitué, report, rallonges n/m | `finance.transferBudget` (`disponible`, `enveloppe`, `report`, `rallonge`, `depense`, `reconstitue`, `rallongesAccordees`, `rallongeMax`, `caisseLibre`, `matelas`), calcul de rallonge `ui/transfer_budget.gd` `extension_amount` | à chaque commande et chaque jour | `actif` faux ou absent : bandeau « Trésorerie du club X € » seul (comme fiche 09 §6.1) |
| Offres reçues, ventes en attente, joueurs proposés, période de vente | `sales` (`offers[]`, `pending[]`, `listed[]`, `window`, `minimum`, `squadSize`) et `squad[].sale` (PR #1009) | à la clôture de semaine et après `sale_list` / `sale_answer` | onglet vide F8 ; `sales.available` faux : onglet grisé avec raison |
| Marché entre clubs (candidats, seuil d'indemnité, salaire, raison d'indisponibilité) | `clubLife.interclubMarket.candidates[]` (`fee`, `salary`, `contractEnd`, `available`, `reason`) | chaque jour | « Marché entre clubs indisponible » F9 |
| Réponses entre clubs, concurrence | `meta.interclubNegotiation` (`seller{accepted,counter,reason}`, `player`, `humanReady`, `humanReason`, `offers[]`, `winner`) puis `meta.interclubTransfer` | à chaque commande | journal vide |
| Négociation joueur libre / prolongation (propositions n/3, demandes, durée min/max) | devis de `contract_negotiation.gd` (`quote.minYears`, `maxYears`, `negotiation.salary`, `years`, n° de proposition) | à chaque commande | « Devis indisponible » + raison |
| Masse salariale (part des recettes, plafond 52 %) | Finances (A2R, `a2rRefusRecrue`) | à chaque commande | ligne masquée + « Voir Finances » |
| JIFF | effectif (`squad`, quota JIFF) | à chaque commande | ligne masquée |
| Besoins du club, pistes suivies | même source que fiche 09 (analyse de l'effectif, suivis) | chaque jour | « Aucun besoin urgent » |
| **Calendrier des mutations** (dates, recrues supplémentaires restantes, jokers médicaux éligibles, ouverture des pré-contrats) | **à créer** par le chantier calendrier LNR : projection `transfers.calendar` attendue `{today, periods[], freeAgentsUntil, extraSignings{used,max,until}, medicalJokers[], preContractsFrom, arrivalsOn}` | chaque jour | tant qu'absente : seule la période de vente (`sales.window`) est affichée ; les autres lignes « à venir » ne sont **pas** inventées |
| **Négociations en cours** (persistantes) | **à créer** : projection `transfers.negotiations[]` agrégeant les négociations joueur libre/prolongation en cours, les accords entre clubs en attente, les pré-contrats ; `{id, playerId, type, step, awaitingYou, deadline, lastAnswer}` | à chaque commande | onglet affiche ce qui existe déjà (négociation en cours d'un joueur libre) et le dit |
| **Pré-contrats** (possibles, signés, convoités) | **à créer** par le chantier calendrier LNR | chaque jour | onglet « Fermé » ou F8 |
| **Historique et échos du marché** | **à créer** : projection `transfers.history[]` à partir des lignes de caisse (« Vente : », « Libération anticipée négociée : », primes) et des actualités `transferEvent` | à chaque mouvement | « Aucun mouvement cette saison. » |

Les quatre projections « à créer » sont des **dépendances moteur** (§14) ; la vue n'en déduit rien elle-même.

### 6.2 Événements et commandes

| Action | Commande / événement | Payload |
|---|---|---|
| Proposer / retirer un joueur | `sale_list` | `{playerId, listed}` |
| Répondre à une offre | `sale_answer` | `{offerId, action: accept\|counter\|decline, percent?, confirmed?}` |
| Proposer une indemnité / conditions (entre clubs) | `interclub_negotiate` | `{playerId, sellerId, fee, salary, sourceSalary, contractEnd, context}` |
| Signer (entre clubs, concurrence) | `interclub_auction` | `{…, expectedWinner, expectedFee, expectedSalary, confirmed:true}` |
| Proposer / signer (joueur libre) | `recruit` | `{playerId, salary, years, premium…}` (contrat existant) |
| Prolonger | `extend_contract` | `{playerId, salary, years…}` (contrat existant) |
| Demander une rallonge | `transfer_budget_extension` | `{amount, confirmed:true}` |
| Pré-contrat | **à créer** (chantier calendrier) | `{playerId, salary, years, premium}` |
| Abandonner une négociation | **à créer** avec `transfers.negotiations` | `{negotiationId}` |
| Changer d'onglet, filtrer, trier, ouvrir le détail | aucun (état d'affichage local, non sauvegardé sauf l'onglet de retour) | — |

## 7. Actions et raccourcis

| Action | Souris | Clavier | Réponse |
|---|---|---|---|
| Changer d'onglet | clic | Ctrl+Tab / Ctrl+Maj+Tab ; ← → sur la barre d'onglets focalisée | onglet remplacé, focus sur sa première ligne |
| Changer de chapitre Pistes ↔ Transferts | bouton N2 | Tab jusqu'au bouton de chapitre, Entrée (N2 n'a pas de raccourci dédié ; Alt+← / → reste l'historique N3) | chapitre remplacé |
| Choisir une ligne | clic | ↑ ↓, Pg↑/Pg↓, Début/Fin | panneau de détail mis à jour |
| Ouvrir la fiche joueur | double-clic sur le nom | Entrée sur la colonne Joueur, ou **F** sur la ligne (hors champ de saisie) | fiche 08, retour ici |
| Action principale du panneau | bouton | Tab jusqu'au bouton, Entrée | commande ou écran Négociation |
| Traiter un élément « À traiter » | [Voir] / [Reprendre] | ↑ ↓ puis Entrée | onglet concerné, ligne sélectionnée |
| Filtres | pastilles E2 | Tab, Espace | liste filtrée, compteur « n / N » |
| Trier | clic en-tête | en-tête focalisé, Entrée (E3) | tri, flèche + mot dans l'infobulle |
| Négociation : modifier un montant | champ numérique | saisie ; ↑ ↓ ±1 000 € ; Pg↑/Pg↓ ±10 000 € | budget « Après » recalculé < 100 ms |
| Négociation : envoyer | bouton nommé | Entrée dans le dernier champ, ou Tab + Entrée | réponse dans le journal |
| Négociation : étape précédente | clic sur l'étape cochée | Maj+Tab jusqu'à l'étape cochée, Entrée | étape rouverte, valeurs conservées |
| Rallonge | « Demander X € au conseil » | Tab, Entrée | W1, focus sur Annuler |
| Retour | [Retour aux transferts] | Échap | Centre, onglet et ligne d'origine |

Aucun raccourci à une lettre n'agit pendant la saisie d'un champ (K5). Les chiffres 1-9 restent aux menus globaux (N5).

## 8. États

| État | Déclencheur | Rendu | Comportement |
|---|---|---|---|
| Première visite | aucune affaire, aucun joueur proposé | « À traiter » vide : « Rien à traiter. Trouve un joueur dans Pistes, ou propose un joueur aux autres clubs. » + [Trouver un joueur] | focus sur le bouton |
| Chargement | commande en cours (F7) | panneau d'attente F7 sur la zone d'action ; lectures libres | boutons d'envoi grisés « Réponse en cours… » |
| Vide (par onglet) | aucune donnée | message + action (F8) : Négociations « Aucune négociation en cours. » + [Trouver un joueur] ; Offres reçues : texte de la fiche 09 (PR #1009) ; Joueurs proposés « Aucun joueur proposé pour l'instant. » + [Voir l'effectif] ; Historique « Aucun mouvement cette saison. » | focus sur l'action |
| **Période fermée** (achats entre clubs) | hors 1er mai – 30 juin | bandeau B « Période des mutations : FERMÉE · réouverture le 1er mai » ; Négociation entre clubs : date d'effet = ouverture, **ou** bouton grisé + raison si le GDD calendrier interdit l'accord anticipé (à trancher, §13) | Observer, suivre, préparer restent possibles |
| Période ouverte | 1er mai – 30 juin | bandeau « OUVERTE · fermeture le 30 juin (J-n) » ; dernière semaine : « Dernière semaine des mutations » en tête d'« À traiter » | aucun minuteur, aucune alerte qui disparaît seule |
| Échéance proche | ≤ 7 jours avant 31/12, 31/01 ou 30/06 | ligne d'« À traiter » « Il reste n jours pour … » (mot + date) | rien ne bloque |
| Joueurs libres clos | après le 31/12 | « Joueurs libres : signatures closes depuis le 31/12. Recrues supplémentaires : 2 restantes jusqu'au 31/01. » | Négociation joueur libre : envoi grisé + raison si plus aucune recrue supplémentaire |
| Joker médical | joueur blessé longue durée éligible | calendrier : « Jokers médicaux : n joueur(s) éligible(s) » + lien ; la Négociation affiche « Recrue au titre du joker médical de {Nom} » | règles du GDD calendrier |
| **Budget insuffisant** | indemnité ou prime > `disponible` | raison écrite sous les champs, en mots : « Hors budget de transferts : il reste X € sur l'enveloppe de Y € fixée par le conseil. » ; colonne Budget : ligne « Après » en négatif **avec le mot « dépassement »** | envoi grisé ; si `reste < offre ≤ caisseLibre` : bouton « Demander X € au conseil » ; sinon la raison dit que la caisse limite |
| **Rallonge** | clic « Demander X € au conseil » | W1 « Rallonge du budget de transferts » : effet sur la confiance (−3 / −1), rallonges n/m, focus sur Annuler | réponse immédiate dans le journal ; budget recalculé ; accordée : envoi réactivé |
| **Accord différé** | vente acceptée hors période | statut « Accord conclu · départ le 1er mai » (Offres reçues, Joueurs proposés, Vue d'ensemble) ; à l'ouverture : « vente exécutée » ou « accord tombé : raison » dans À traiter et le courrier | le joueur reste et joue |
| **Pré-contrat** | joueur en dernière année, à partir du 1er janvier | onglet « Possibles » actif ; avant le 1er janvier : « Pré-contrats possibles à partir du 1er janvier. » ; signé : « Arrive le 1er juillet » | pas d'indemnité ; budget : seule la prime compte |
| Concurrence | d'autres clubs ont fait une offre | « Autres clubs sur le coup : n » + phrase de règle à l'étape ③ ; résultat écrit (« Le joueur a choisi {Club} : offre de X €/sem. ») | jamais de silence (G3) |
| Devis périmé | marché changé entre deux commandes | « Les conditions ont changé : vérifie à nouveau. » + [Actualiser] | valeurs saisies conservées |
| Joueur plus disponible | signé ailleurs, retiré | ligne « Plus disponible » + raison ; Négociation : bandeau + [Retour aux transferts] | message conservé jusqu'à l'action suivante (M6) |
| Erreur | commande refusée ou données illisibles (F9) | bandeau d'erreur avec la raison écrite par le moteur + [Réessayer] | pas de crash, saisie conservée |
| Moteur occupé | Continuer en cours | actions grisées + « Le jour avance… » | lecture libre |
| Budget inactif | carrière sans budget de saison | bandeau B : « Trésorerie du club X € » | les refus viennent de la caisse |

## 9. Accessibilité (palier Standard, exception de densité FM)

- Densité FM : corps ~13 px, tableaux 12-13 px, en-têtes 11-12 px, jamais sous 11 px à 1080p ; lignes 24-26 px ; échelle 90/100/115/130 % ; à 130 % (1280×720) la Négociation passe le journal sous les champs et garde la colonne Budget visible.
- Contraste : texte ≥ 4,5:1 sur son fond réel ; contours, focus, coches d'étape ≥ 3:1 (C1, C3).
- **Couleur jamais seule** : statut de transfert, étape, période ouverte/fermée, dépassement de budget, offre spontanée, urgence : toujours un **mot** (et une icône quand utile) ; capture en niveaux de gris : tout reste distinguable.
- Montants entiers, séparateur de milliers, devise toujours présente ; jamais tronqués (T5).
- Focus visible ≥ 2 px. Ordre : rail → chapitres → bandeau budget → onglets → filtres → tableau → panneau de détail → pied. Négociation : étapes → champs de l'étape → bouton d'envoi → colonne Budget (rallonge) → Retour.
- Aucun délai imposé (K7) : expirations et échéances écrites en dates, jamais de compte à rebours animé ; aucune notification qui disparaît seule.
- Confirmations d'argent (signer, vendre, conclure, abandonner, rallonge) : W1, libellé = action, focus sur Annuler, focus piégé, Échap annule.
- Tout au clavier ; aucun glisser-déposer ; aucune précision de souris (champs numériques au clavier).

## 10. Ce qu'on retire, déplace, garde

| Élément actuel | Décision |
|---|---|
| Fenêtre « Négociation » d'un joueur libre (`contract_negotiation.gd`) | **Remplacée** par l'écran Négociation (types Joueur libre, Prolongation) ; mêmes règles et commandes (`recruit`, `extend_contract`), même rallonge |
| Fenêtre « Marché entre clubs » (`interclub_market_view.gd`) | **Scindée** : la liste des candidats devient une **source** de l'onglet Recherche de la fiche 09 (pastille « Entre clubs », déjà prévue) ; la négociation et l'enchère passent dans l'écran Négociation (type Entre clubs) |
| Fenêtre « Offres reçues » (`player_sales_view.gd`, PR #1009) et bouton « Offres reçues · n » du Recrutement | **Déplacée** dans l'onglet Offres reçues ; le bouton du Recrutement devient un lien vers cet onglet ; le courrier « offre_transfert » y mène directement |
| Bandeau « Disponible pour les transferts » de la fiche 09 §6.1 | **Gardé** dans Pistes (même source) et repris dans le bandeau B : une seule règle d'affichage |
| Bandeau « n fins de contrat » de la fiche 09 §6.1 bis | Gardé ; repris dans Joueurs proposés (filtre) et Mouvements prévus |
| **Ce qui reste dans la fiche 09 (chapitre « Pistes »)** | Besoins du club, Recherche (sources Marché joueurs / Entre clubs / Relève), Joueurs suivis, Rapports, missions du recruteur, comparaison à 2. « Approcher le joueur » y ouvre désormais l'écran Négociation. Les §6.6 (fenêtre de négociation) et le paragraphe « Fenêtre Offres reçues » de la PR #1009 renvoient à cette fiche |
| Carte « Marché des transferts » de la fiche joueur (onglet Contrat) | Gardée ; « Voir les offres » ouvre l'onglet Offres reçues filtré sur le joueur |

## 11. Déviations et nouveaux motifs

- **N2** : premier usage de la sous-navigation de chapitre pour Recrutement (Pistes / Transferts).
- **E3** : tableau socle étendu à 5 onglets ; tri au clavier.
- **W1** : libellé = action, focus sur Annuler pour tout engagement d'argent (déviation déjà voulue, fiche 09).
- **W3** : sortie des fenêtres de négociation et d'offres au profit d'écrans pleins (décision de Léo, 19/11/2026).
- **Nouveaux motifs à ajouter à la bibliothèque** : **P1 · Écran à étapes** (stepper numéroté, étape cochée rouvrable, valeurs conservées) ; **P2 · Colonne budget fixe** (avant / cette offre / après, recalcul immédiat, dépassement en mot) ; **P3 · File « À traiter »** (éléments triés par urgence, chacun avec date et action). À inscrire dans `design/ux/interaction-patterns.md` à l'implémentation (phase 3 de `/team-ui`).

## 12. Transitions, localisation, entrées

**Transitions** : ouverture du Centre et changement d'onglet instantanés (≤ 100 ms en « Normales », 0 en « Aucune ») ; passage Centre ↔ Négociation : remplacement instantané, sans animation latérale ; étape suivante : la coche apparaît, pas de glissement ; « Mouvement réduit » sans effet visible (M1, M2). Aucun effet sonore propre à cet écran hors événements audio existants.

**Localisation** (+40 % prévu ; nom, poste, montant jamais tronqués) : titre ≤ 30 ; onglet ≤ 20 + compteur ; libellé d'étape ≤ 24 ; en-tête de colonne ≤ 14 ; statut ≤ 32 (sinon 2 lignes) ; ligne d'« À traiter » ≤ 90 sur 2 lignes ; bouton ≤ 28 (« CONCLURE L'ACCORD… », « ENVOYER LA PROPOSITION ») ; montant ≤ 12 caractères avec devise ; message de vide ≤ 100 ; dates au format jj/mm ou « 1er mai » en toutes lettres.

**Entrées** (souris + clavier ; manette hors périmètre du projet) : [x] onglets, lignes, filtres, tri, actions, étapes, champs à la souris ; [x] les mêmes au clavier (§7) ; [x] ordre de focus (§9) ; [x] aucun glisser-déposer ; [x] aucune précision requise.

## 13. Critères d'acceptation

- [ ] Le Centre s'ouvre (focus placé) en < 200 ms hors chargement moteur ; changer d'onglet < 100 ms ; dans la Négociation, la colonne Budget se recalcule en < 100 ms après chaque saisie.
- [ ] À 1280×720 et à 130 %, sans défiler : le budget disponible, l'état de la période et le premier élément « À traiter » sont visibles sur la Vue d'ensemble ; dans la Négociation, le bouton d'envoi et la ligne « Après » du budget sont visibles.
- [ ] Une offre, une vente en attente, une recrue libre ou entre clubs ne s'ouvrent **jamais** dans une fenêtre empilée : seul un écran plein ou une confirmation W1 apparaît.
- [ ] Le courrier « offre_transfert » ouvre l'onglet Offres reçues avec l'offre sélectionnée ; Alt+← (historique N3) ramène à la Réception ; Échap suit la règle unique (§3).
- [ ] Une indemnité ou prime supérieure au disponible grise l'envoi et affiche, sous les champs, la phrase « Hors budget de transferts : il reste X € sur l'enveloppe de Y € … » ; si la caisse le permet, un bouton « Demander X € au conseil » apparaît (X = offre − reste, arrondi au millier supérieur).
- [ ] Hors période (date de carrière entre le 1er juillet et le 30 avril), accepter une offre affiche « CONCLURE L'ACCORD… » et le joueur passe au statut « Accord conclu · départ le 1er mai » dans trois onglets.
- [ ] Une négociation entre clubs montre les trois étapes ; l'étape ② n'est accessible qu'après l'accord du club ; revenir à ① conserve les valeurs.
- [ ] Après un Retour depuis la Négociation, l'onglet et la ligne d'origine sont restaurés.
- [ ] Capture en niveaux de gris : statut, étape, période et dépassement restent lisibles (mots présents).
- [ ] Chaque onglet vide affiche son message et une action focalisée.
- [ ] Toutes les actions de §7 sont faisables au clavier seul ; aucun raccourci à une lettre n'agit pendant une saisie.
- [ ] Aucun texte « fin(s) », aucun jargon technique, pluriels corrects ; aucun montant tronqué à 130 %.

## 14. Dépendances

| Système | Sens | Contrat |
|---|---|---|
| Budget de transferts (`docs/gdd/budget-transferts.md`) | amont | `finance.transferBudget`, `transfer_budget_extension` ; R2 (prolongation hors enveloppe), R3/R3 bis (refus, rallonge) |
| Vente de joueurs (`docs/gdd/vente-joueurs.md`, PR #1009) | amont | `sales`, `squad[].sale`, `sale_list`, `sale_answer` ; textes de la fenêtre et de la confirmation repris tels quels |
| Marché entre clubs (`interclub-market.cjs`) | amont | `clubLife.interclubMarket`, `interclub_negotiate`, `interclub_auction` |
| Recrutement (fiche 09) | voisin | chapitre « Pistes » ; « Approcher » ouvre la Négociation ; la fiche 09 doit renvoyer ici (§10) |
| **Calendrier des mutations LNR et pré-contrats** (chantier en cours) | amont, **bloquant pour 3 blocs** | projections `transfers.calendar`, pré-contrats, commande de pré-contrat ; tant qu'absent, seuls budget, ventes et marché entre clubs sont branchés |
| **Projection des négociations et de l'historique** | amont, à créer (moteur) | `transfers.negotiations[]`, `transfers.history[]` (§6.1) |
| Courrier (`club-mail.json`) | aval | liens « Ouvrir · Offres reçues » / « Négociations » vers l'onglet |
| Finances (fiche 17) | voisin | clic sur le bloc budget ; masse salariale |

## 15. Questions ouvertes

| Question | Propriétaire | Statut |
|---|---|---|
| Place dans le rail : chapitre « Transferts » du Recrutement (proposé) ou entrée de rail à part ? | Léo | À trancher |
| Échéancier de l'indemnité, pourcentage à la revente, prêts : fonctions FM absentes du moteur. Les ajouter (chantier moteur + économie) ou rester sur l'indemnité unique ? Proposé : plus tard, la ligne « Échéancier » est réservée dans l'étape ① | Léo / economy-designer | À trancher |
| Négociations au fil des jours (réponse du club le lendemain, comme FM) ou réponse immédiate comme aujourd'hui ? Proposé : immédiate (cap « consolider »), la liste Négociations garde les affaires ouvertes | Léo / game-designer | À trancher |
| Hors période, un accord d'achat entre clubs peut-il être conclu d'avance (effet à l'ouverture, symétrique de la vente) ? | game-designer (GDD calendrier) | À trancher par le chantier calendrier |
| Date d'arrivée d'un achat conclu en période : immédiate ou 1er juillet ? | game-designer (GDD calendrier) | À trancher |
| Curseur « transferts ↔ salaires » de FM : non retenu (la masse salariale est un plafond de ligue, pas une enveloppe) | ux-designer | Proposé : écarté |
