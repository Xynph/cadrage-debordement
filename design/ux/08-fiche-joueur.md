# Fiche UX 08 — Fiche joueur

Décisions de Léo du 19/11/2026 intégrées : densité « Football Manager » (corps ~13 px, tableaux 12-13 px, en-têtes 11-12 px, jamais sous 11 px à 1080p ; lignes de tableau 24-26 px ; échelle d'interface 90/100/115/130 %) ; règle unique d'Échap (ferme la fenêtre, sinon retour de fiche/sous-écran, sinon menu pause) et bouton « Menu » visible dans la coque.

## Révision validée par Léo (19/11/2026, maquette `revue-20261119/apercus/08-fiche-joueur-retouche.png`)

Ces règles priment sur la suite de la fiche quand elles la contredisent.

- **Accès** : un clic sur le **nom** d'un joueur ouvre cette fiche en plein écran (comme Football Manager), depuis
  Effectif, Recrutement, Formation et tout nom joueur branché sur `open_entity`. Survoler le nom ou le petit « i »
  voisin montre la **mini-fiche** (voir `mini-fiche-joueur.md`), sans changer d'écran.
- **Plus de petite fenêtre** pour montrer un joueur : le suivi individuel des Espoirs et des jeunes pros
  (spécialisation, historique) vit dans l'onglet Développement ; les fiches fixes à droite d'Effectif et de
  Formation disparaissent, le tableau prend la largeur. Recrutement garde provisoirement son panneau (actions
  Suivre / Observer / Approcher) jusqu'à la refonte de l'étape 3.
- **Barre haute de la fiche** : « ← Retour à {origine} · Échap », « ‹ précédent · 4 / 40 · tri : … · suivant › »
  (Maj+← / Maj+→, liste d'origine, pas de bouclage), à droite « Comparer → », « Ma note → ».
- **Bandeau** : vignette + n°, « FICHE JOUEUR · POSTE », NOM en capitales italiques, **drapeau en couleur**
  (`art/flags/<flagCode>.svg`, sinon le code pays écrit) + pays · âge · taille · poids · sélections, autres postes,
  verdict (statut · condition · contrat), à droite Niveau /100 et Potentiel. Chaque morceau qui ressemble à un lien
  ouvre quelque chose (nation → Sélections, contrat → prolongation, adversaire → fiche du club).
- **Onglets** : Vue d'ensemble · Performances · Contrat · Développement · Repères. **L'onglet Attributs disparaît** :
  les 36 attributs sont sur la première page.
- **Vue d'ensemble** : carte **Attributs** (4 familles réelles du jeu × 9 clés réelles de `attributesV2`, moyenne
  par famille, légende du barème), carte **Postes** + courbe « note match par match » (notes enregistrées de la
  saison, `NotesMatch.historique[].note`, moyenne en pointillé) ; colonne droite **Disponibilité**, **Valeur**
  (3 points forts / 3 à travailler), **Contrat** (bouton prolonger).
- **Barème des attributs** (jetons `Charte.ATTRIBUT_*`) : chiffre toujours écrit, couleur par palier —
  0-39 #EE6F5F · 40-54 #F2A04A · 55-64 #EADB55 · 65-74 #A8D878 · 75-84 #4FCB78 · 85+ #3DEBB4. Légende visible.
- **Attributs inconnus** (brouillard de connaissance) : « — » en ivoire-3 et « Fais-le observer pour connaître
  ses attributs », cliquable vers l'observation du recrutement.
- **Rien de figé** : toute valeur vient des données du joueur ; une donnée absente (date de retour, « au club
  depuis ») est dérivée d'une vraie source ou la ligne est omise.

> **Template**: UX Spec
> **Statut** : proposé (ux-designer CCGS, 19/11/2026, mode autonome, rigueur `minimal`) ; révision ci-dessus validée
> **Écran** : `Fiche joueur` (lecteur ouvert depuis une liste ; titre « Fiche joueur : NOM ») · carrière Monde · souris + clavier
> **Phases du parcours** : première heure (appropriation), semaine type, fin de saison (contrat)
> **Palier d'accessibilité** : Standard
> **Liés** : fiche 07 (effectif), fiche 09 (recrutement), fiche 10 (composition), `design/ux/interaction-patterns.md` (N2, N5, F3, F8, W1)

## 1. But

- **Joueur** : comprendre qui est ce joueur, s'il est utile cette semaine et ce qu'il faut décider pour lui (prolonger, ménager, comparer, noter).
- **Jeu** : relier un nom à un rôle dans l'équipe et à une échéance (contrat, condition).
- **Dans les 5 secondes** : poste et niveau, **dispo ou pas**, contrat (jusqu'à quand), puis une action claire.

## 2. Contexte d'arrivée

| Question | Réponse |
|---|---|
| Venu de | Effectif (double-clic/Entrée), Composition (clic joueur), Recrutement, accès rapide, Bureau (alerte) |
| État d'esprit | Curieux ou inquiet (blessure, contrat) |
| Charge cognitive | Faible à moyenne : une personne, trois questions |
| Veut | Vérifier un état, décider d'une prolongation, relire des stats |
| Craint | Perdre un bon joueur, aligner un joueur diminué |

**Cible émotionnelle** : « Je connais cet homme. »

## 3. Navigation

```
Origine (Effectif | Composition | Recrutement | Bureau)
  └── Fiche joueur                    ← cet écran (lecteur plein écran, garde le rail)
        ├── Onglets : Vue d'ensemble · Attributs · Performances · Contrat · Développement · Repères
        └── Négociation (fenêtre)     ← Prolonger
```

- **Modalité** : écran plein, non modal ; « lecteur » (fermer = revenir à l'origine).
- **Entrées** : voir ci-dessus ; la fiche garde la liste d'origine (précédent/suivant) quand elle vient de l'effectif ou d'une liste de recrutement.
- **Sorties** : Échap ou « Retour à {origine} » (libellé dynamique : « Retour à l'effectif », « à la composition », « au recrutement ») · Prolonger (négociation) · Comparer · autre menu du rail.
- **Échap** = retour d'une fiche (étape 2 de la règle unique, N5) ; la pause ne s'ouvre qu'une fois revenu sur un écran principal (règle de Léo, 19/11/2026).

## 4. Hiérarchie

1. **Principal** : le bandeau d'identité (n° + nom + poste) et, juste dessous, une **ligne de verdict** : « Titulaire · 100 % · contrat jusqu'en 2027 ».
2. **Secondaires** : niveau/potentiel, disponibilité (condition, fatigue, blessure), contrat avec l'action « Prolonger ».
3. **Reste** : attributs détaillés, performances, développement, repères de carrière, note personnelle.

## 5. Wireframe 1280×720 (vue d'ensemble)

```
┌────┬──────────────────────────────────────────────────────────────────────────────────────┐
│    │ Effectif › Fiche joueur : A. MCCULLOCH            [‹ préc.] [suiv. ›]  [Retour effectif]│
│ Nav│ ┌────────┐ 7  ALASDAIR MCCULLOCH                          Niveau 62      Potentiel 62-66│
│124 │ │ photo  │ Troisième ligne centre · 30 ans · Angleterre   [Comparer] [Ma note]          │
│ px │ │        │ 187 cm · 107 kg · 0 sélection XV                                             │
│    │ └────────┘ ► Titulaire · 100 % · contrat jusqu'en 2027   (verdict en 1 ligne)           │
│    │ [Vue d'ensemble][Attributs][Performances][Contrat][Développement][Repères]  (Ctrl+Tab)  │
│    │ ┌ Disponibilité ──────────┐ ┌ Points forts / à travailler ─┐ ┌ Contrat ───────────────┐│
│    │ │ Condition 100 % ▬▬▬|80  │ │ + Plaquage 74  + Mêlée 71    │ │ 500 € /sem.            ││
│    │ │ Fatigue 0/100 (↓ = mieux)│ │ + Mobilité 68                │ │ Fin : 2027 · fin de    ││
│    │ │ Plan de charge : collectif│ │ – Pied 41 – Vitesse 47 – Passe 49│ │ saison                ││
│    │ │ [Régler la charge →]    │ │ [Voir les 36 attributs →]    │ │ [Proposer une prolong.]││
│    │ └─────────────────────────┘ └──────────────────────────────┘ └────────────────────────┘│
│    │ ┌ Postes ────────────────┐ ┌ Saison 2026-27 ─────────────────────────────────────────┐│
│    │ │ Principal : 3e ligne c.│ │ 0 apparition · 0 min · Moy. — · Forme (5 derniers) —     ││
│    │ │ Autres : 2e ligne, 3e L│ │ « Aucun match joué cette saison. »                       ││
│    │ └────────────────────────┘ └──────────────────────────────────────────────────────────┘│
├────┴──┬─────────────────────────────────────────────────────────────────────────────────────┤
│ pied  │ Échap Retour · Ctrl+Tab Onglet · Maj+←/→ Joueur précédent/suivant · F1 Aide          │
└───────┴─────────────────────────────────────────────────────────────────────────────────────┘
```

| Zone | Contenu | Taille | Défile ? | Débordement |
|---|---|---|---|---|
| Bandeau d'identité | photo, n°, nom, poste, âge, nation, taille/poids, verdict, niveau/potentiel, actions | 100 % × 30 % | Non | Nom jamais tronqué ; verdict sur 2 lignes possible |
| Onglets | 6 onglets | 100 % × 6 % | Non | Passent en liste déroulante sous 900 px utiles |
| Contenu d'onglet | 3 cartes + 2 cartes | 100 % × 58 % | Verticalement si > 1 écran | Cartes empilées à 130 % |
| Pied | raccourcis | 100 % × 5 % | Non | — |

**Focus à l'ouverture** : l'onglet courant ; deep-link depuis une alerte : le premier contrôle utile (« Proposer une prolongation » pour contrat, « Condition » pour blessure) (K8).

## 6. Blocs et données

### 6.1 Bandeau d'identité

| Donnée | Format | Absence |
|---|---|---|
| N° de feuille | pastille numérique ; « — » si hors groupe | « — » |
| Prénom NOM | texte capitales | jamais absent |
| Poste principal | mot complet | — |
| Âge · nation (drapeau **et** nom) · taille · poids · sélections XV | texte | « — » |
| Verdict | statut (mot) + condition + fin de contrat | « Non communiqué » si inconnu |
| Niveau (/100) | grand chiffre ; une seule fois sur l'écran | « — » |
| Potentiel | fourchette ; « ? » si non observé (recrutement) | « ? » |

Retiré : le niveau répété dans la carte « Évaluation du joueur » (la même valeur 62 était affichée deux fois).

### 6.2 Onglet « Vue d'ensemble » (défaut) — cartes

| Carte | Contenu exact |
|---|---|
| **Disponibilité** | Condition % + barre + repère 80 % ; fatigue n/100 avec « (plus bas = mieux) » ; plan de charge (mot) ; satisfaction n/100 ; si blessé : type, gravité en mots, retour prévu ; bouton « Régler la charge individuelle » |
| **Points forts / à travailler** | 3 meilleurs et 3 plus faibles attributs du poste, valeur numérique ; bouton « Voir les 36 attributs » (remplace la carte « Évaluation » qui ne montrait que le niveau) |
| **Contrat** | salaire/sem., fin de contrat (année + « fin de saison » si échéance en cours), prolongation (Disponible / Refusée / Impossible, raison) ; bouton « Proposer une prolongation » (principal si échéance ≤ 1 saison, sinon secondaire) ; **vente** (GDD `docs/gdd/vente-joueurs.md`) : carte « Marché des transferts » de l'onglet Contrat. Ligne d'état : « Valeur estimée {montant}. Il n'est pas proposé aux autres clubs. » · « Proposé aux autres clubs · valeur estimée {montant} » · « Offre reçue : à traiter dans Offres reçues. » · vente en attente (« effectif au 1er mai », en doré). Boutons : « **Proposer aux autres clubs** » / « **Retirer du marché** » (le second, secondaire) et « **Offres reçues** » (ou « Offres reçues · n ») qui ouvre la fenêtre des offres (fiche 09 §6.5). Bloqué (espoir de moins de 20 ans, recrue de moins de 3 journées, prêt, joueur appelé du centre) : « Proposer » grisé + raison écrite en rouge sous l'état ; pendant un match ou une vente en attente : grisé aussi. Le dossier de l'Effectif (fiche 07) reprend la même ligne d'état et les mêmes boutons |
| **Postes** | poste principal et autres postes en mots ; note au poste de chaque ; schéma des 15 postes en petit, avec les mots (le schéma illustre, ne porte pas l'information seul) |
| **Saison** | apparitions, minutes, moyenne, forme des 5 derniers matchs (note) ; « Aucun match joué cette saison. » si 0 |

### 6.3 Autres onglets

| Onglet | Contenu |
|---|---|
| Attributs | 36 attributs groupés comme aujourd'hui, valeur chiffrée + barre, tri par défaut : groupe puis valeur décroissante ; indisponible : « Le détail n'est pas disponible pour ce profil. » |
| Performances | tableau des matchs : date, adversaire, rôle (n°), minutes, note ; tri par défaut : date décroissante |
| Contrat | salaire, durée, historique des offres, clauses (prime, prolongation) ; action Proposer |
| Développement | niveau → potentiel, progression par saison, marge ; objectif de poste |
| Repères | équipes de la saison où il figure, comparaison au poste dans la division |

### 6.4 Note personnelle

« Ma note » : un seul point d'entrée dans le bandeau (le bouton du carnet personnel dans la carte « Performances » est retiré ; il faisait doublon).

### 6.4 bis Sources et rafraîchissement

| Donnée | Source (propriétaire) | Rafraîchie | Absence |
|---|---|---|---|
| Identité, poste, âge, nation, taille, poids, sélections | état de carrière (moteur) | à chaque jour avancé | « — » |
| Niveau, potentiel, attributs | état de carrière ; potentiel : rapports de recrutement | à chaque jour, à chaque rapport reçu | « — » ou « ? » |
| Condition, fatigue, plan de charge, satisfaction, blessure, suspension | moteur (soins, charge, discipline) | à chaque jour, à chaque séance | « Non communiqué » |
| Contrat, prolongation | moteur (contrats) | à chaque jour, à chaque commande de contrat | « — » |
| Numéro de feuille, statut de feuille | feuille de match courante (moteur) | à chaque validation de composition | « — » / « Hors groupe » |
| Performances, forme | résultats de la saison (moteur) | après chaque match | « Aucun match joué cette saison. » |
| Note personnelle | note du joueur (carnet de carrière, moteur) | à l'enregistrement | vide |
| Origine, onglet, liste précédent/suivant | état d'interface | à l'action | origine : rail |

L'interface ne possède aucune de ces données.

### 6.5 Événements (l'interface n'écrit rien elle-même)

| Action | Événement | Payload |
|---|---|---|
| Proposer une prolongation | `ContractNegotiationRequested` | `{playerId}` |
| Proposer aux autres clubs / Retirer du marché | commande `sale_list` | `{playerId, listed}` |
| Régler la charge | `LoadPlanDialogRequested` | `{playerId}` |
| Ma note | `PlayerNoteSaved` | `{playerId, text}` |
| Comparer | `CompareToggled` | `{playerId}` |

## 7. Actions et raccourcis

| Action | Souris | Clavier | Réponse |
|---|---|---|---|
| Retour | « Retour à … » | Échap | origine, même place |
| Joueur précédent/suivant (liste d'origine) | ‹ › | Maj+← / Maj+→ | garde l'onglet courant ; pas de bouclage silencieux (le bouton se grise aux extrémités avec raison) |
| Changer d'onglet | clic | Ctrl+Tab, Ctrl+Maj+Tab ; ← → sur la rangée | un seul motif d'onglet (manquant n°11) |
| Prolonger | bouton | Tab, Entrée | négociation (fenêtre) |
| Comparer | bouton | Tab, Entrée | ajoute au comparateur (max 2) |
| Ma note | bouton | Tab, Entrée | fenêtre de saisie ; Échap annule, texte non vide demande confirmation |
| Voir les attributs | bouton | Entrée | onglet Attributs |

## 8. États

| État | Déclencheur | Rendu |
|---|---|---|
| Normal | — | voir §5 |
| Blessé | blessure | bandeau pleine largeur sous le verdict : icône + « Blessé · gravité (léger/grave) · retour prévu jj/mm » ; condition et verdict en conséquence |
| Suspendu | carton/commission | bandeau : « Suspendu · n matchs » |
| En sélection nationale | convocation | bandeau : « En sélection · retour prévu jj/mm » |
| Contrat qui s'achève | échéance ≤ saison | pastille « Fin de contrat » (mot + icône) dans le verdict ; bouton Contrat en principal |
| Jeune / potentiel inconnu | profil non observé | « Potentiel ? » + « Observe-le pour estimer son potentiel » (lien vers Recrutement) |
| Saison vide | aucun match | « Aucun match joué cette saison. » (au lieu de 0 · 0 · — · tirets) |
| Chargement | ouverture, retour moteur | squelette de cartes ; photo : silhouette neutre jusqu'au chargement |
| Erreur | joueur introuvable (libéré, parti) | « Ce joueur n'est plus dans ton club. » + « Retour à {origine} » ; Échap fonctionne |
| Moteur occupé | Continuer | boutons d'action désactivés avec la raison en infobulle ; lecture libre |
| Vente bloquée | espoir < 20 ans, recrue < 3 journées, prêt | « Proposer aux autres clubs » grisé ; raison écrite en rouge dans la carte (pas seulement en infobulle) |
| Vente en attente | accord conclu hors période des mutations | état « vente en attente » en doré (date d'effet 1er mai) ; « Proposer » grisé ; « Offres reçues » reste actif ; le joueur reste disponible jusqu'au départ |

## 9. Accessibilité (T1, T5, C1, C3, D1, D3, D6, K1, K2, K6, K8)

- Texte ~13 px à 1920 (12-13 px dans le tableau des matchs) ; aucune étiquette < 11 px (aujourd'hui « NIVEAU / 100 », « MON CARNET PERSONNEL » sont minuscules et grises : C1).
- Statut de disponibilité jamais en couleur seule : mot + icône ; blessure : icône spécifique + gravité en mots (D3).
- Condition, fatigue : chiffre à côté de la barre et repère visible au seuil (D6).
- **Alternative au clic** : tout est au clavier (onglets, précédent/suivant, boutons) ; aucun glisser-déposer sur cet écran.
- Focus visible ≥ 2 px, ordre : rail → Retour → précédent/suivant → Comparer / Ma note → onglets → cartes (gauche→droite, haut→bas) → boutons de carte → pied.
- Photo : nom accessible « Portrait de Prénom NOM » ; drapeau avec nom du pays en texte.
- Mouvement réduit : pas d'effet sur les cartes ; surbrillance du schéma des postes statique.
- Textes de verdict courts (≤ 2 lignes de 40 caractères) pour tenir à 130 %.
- **Contraste** : texte ≥ 4,5:1 sur son fond réel, contours de barre, focus et icônes porteuses de sens ≥ 3:1 (C1, C3) ; jetons à valider avec la direction artistique.

## 10. Ce qu'on retire, déplace, garde

| Écran actuel | Décision |
|---|---|
| Niveau répété (bandeau + carte Évaluation) | Carte « Évaluation » retirée ; « Points forts / à travailler » la remplace |
| « Ma note » + « Mon carnet personnel / Ouvrir ma note » | Un seul bouton « Ma note » dans le bandeau |
| Performances de la saison à zéro (0 · 0 · — · tirets) | État « Aucun match joué » |
| Bouton « Retour à l'effectif » au bout de la rangée d'onglets | Déplacé en tête de bandeau, libellé dynamique selon l'origine, + Échap |
| Carte « Poste principal » avec le terrain en grande surface | Réduite en carte « Postes » (mots d'abord) |
| Carte « Disponibilité » (satisfaction, plan de charge) | **Gardée**, enrichie (seuil, retour de blessure) |
| Onglets, bouton Comparer, Contrat | **Gardés** |
| Précédent / suivant | **Ajoutés** (déplacement dans la liste d'origine) ; amélioration de confort, pas une nouvelle fonction de jeu |

## 11. Déviations des motifs

- **N2** : un seul motif d'onglet avec raccourci Ctrl+Tab (le motif actuel n'en a pas).
- **N5** : Échap = retour d'une fiche, pas pause, même si la fiche vient d'être ouverte par accès rapide (règle unique du 19/11/2026).
- **F3** : jauge toujours avec valeur numérique et seuil (le motif actuel peut afficher une barre seule).

## 11 bis. Transitions, localisation, entrées

**Transitions** : ouverture et retour sans fondu obligatoire (instantané ; 100 ms au plus en « Transitions : Normales », 0 en « Aucune ») ; changement d'onglet et précédent/suivant : mise à jour instantanée ; squelette de chargement 0,35 s avant affichage (§8) ; « Mouvement réduit » : aucun effet visible (M1, M2).

**Localisation** (+40 % prévu ; nom, poste et montant jamais tronqués) : Prénom NOM ≤ 28 ; verdict ≤ 2 lignes de 40 ; libellé de bouton ≤ 24 (« Proposer une prolongation ») ; titre de carte ≤ 28 ; bandeau de blessure/suspension ≤ 60 ; nom d'attribut ≤ 22 ; message d'état ≤ 70.

**Entrées (souris + clavier ; manette hors périmètre)** : [x] tout contrôle à la souris ; [x] tout contrôle au clavier (§7, §9) ; [x] ordre de focus défini (§9) ; [x] aucun glisser-déposer ; [x] aucune précision de souris requise.

## 12. Critères d'acceptation

- [ ] La fiche s'ouvre et le focus est placé en < 200 ms (hors chargement) ; le changement d'onglet répond en < 100 ms.
- [ ] Poste, niveau, statut (mot) et fin de contrat visibles sans défiler à 1280×720 / 130 %.
- [ ] Le niveau n'apparaît qu'une fois dans l'onglet « Vue d'ensemble ».
- [ ] Un joueur blessé affiche type, gravité en mots et retour prévu ; capture en niveaux de gris lisible.
- [ ] Échap revient à l'origine (effectif, composition ou recrutement), position conservée.
- [ ] Maj+→ passe au joueur suivant de la liste d'origine ; grisé en fin de liste avec infobulle.
- [ ] Saison sans match : message textuel, pas de « 0 · 0 · — ».
- [ ] Tous les contrôles atteignables sans souris, focus visible.
- [ ] Onglet Contrat : « Proposer aux autres clubs » devient « Retirer du marché » une fois le joueur proposé ; un joueur bloqué affiche sa raison écrite et le bouton grisé ; « Offres reçues » ouvre la fenêtre des offres.

## 13. Questions ouvertes

| Question | Propriétaire | Statut |
|---|---|---|
| Quels 6 attributs montrer dans « Points forts / à travailler » (clés par poste) ? | game-designer | À définir |
| Libellés de gravité de blessure : léger / modéré / grave ? | game-designer | À confirmer avec le moteur |
| Précédent/suivant depuis la composition : dans le XV, dans le groupe, ou aucun ? | Léo | À trancher |
| Écran de comparaison (2 joueurs) ouvert par « Comparer » : aucune fiche ne le spécifie | ux-designer | À spécifier (fiche à créer) |
