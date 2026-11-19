# Fiche UX 11 — Préparation du match et entraînement

Décisions de Léo du 19/11/2026 intégrées : densité « Football Manager » (corps ~13 px, tableaux 12-13 px, en-têtes 11-12 px, jamais sous 11 px à 1080p ; lignes de tableau 24-26 px ; échelle d'interface 90/100/115/130 %) ; règle unique d'Échap (ferme la fenêtre, sinon retour de fiche/sous-écran, sinon menu pause) et bouton « Menu » visible dans la coque.

> **Template**: UX Spec
> **Statut** : proposé (ux-designer CCGS, 19/11/2026, mode autonome, rigueur `minimal`)
> **Écrans** : `Préparation` (route « Préparation », onglets Dossier adverse · Consignes · Entraînement) et `Entraînement` (route « Entraînement », onglets Semaine · Groupes · Individuel · Staff · Fatigue) · carrière Monde · souris + clavier
> **Phases du parcours** : semaine type (début de semaine, veille de match), première heure (première semaine)
> **Palier d'accessibilité** : Standard (D2 : forme V/N/D avec lettre et forme)
> **Liés** : fiche 10 (composition, consignes), fiche 12 (avant-match), fiche 07 (condition), `design/ux/interaction-patterns.md` (F6 pastilles V/N/D, N2, W1, motif manquant n°1 barres face à face)
> **Limite de relevé** : l'écran Préparation est lu sur capture et sur le code ; l'écran Entraînement est lu **dans le code seulement** (aucune capture disponible pour la route « Entraînement » ; la vue du calendrier de semaine sert de preuve des séances). Les états de ce dernier sont à vérifier à l'écran.

## 1. But

- **Joueur** : arriver au coup d'envoi en sachant **contre qui il joue, ce qu'il craint, et que sa semaine est bien faite** (séances, feuille, consignes), sans oublier une étape.
- **Jeu** : convertir la semaine en préparation lisible, qui nourrit l'après-match (« Pourquoi »).
- **Dans les 5 secondes (Préparation)** : (1) **le danger principal de l'adversaire** en une phrase, (2) **sa forme** (V/N/D des 5 derniers), (3) **ce qu'il me reste à faire** avant le match.
- **Dans les 5 secondes (Entraînement)** : (1) **la charge retenue** pour la semaine, (2) **l'état physique du groupe**, (3) **la prochaine séance** et un seul bouton pour l'effectuer.

## 2. Contexte d'arrivée

| Question | Réponse |
|---|---|
| Venu de | Bureau (« Préparer le match », bouton Préparer de la barre haute), rail, Composition, après-match |
| État d'esprit | Maîtrise tranquille, anticipation ; attente avant le match |
| Charge cognitive | Moyenne à haute : adversaire + groupe + semaine |
| Veut | Voir la menace, ajuster, valider, continuer |
| Craint | Oublier une étape, blesser un joueur par une charge excessive, sous-estimer l'adversaire |

**Cible émotionnelle** : « Je sais ce qui m'attend, je suis prêt. »

## 3. Navigation

```
Carrière Monde › Tactique (chapitre : Composition / Préparation / Plan de jeu / Match)
  └── Préparation                          ← partie A
        ├── Onglet Dossier adverse (défaut)
        ├── Onglet Consignes               ← même composant que Composition › Consignes
        └── Onglet Entraînement            ← ouvre la partie B (raccourci)
Carrière Monde › Entraînement (rail)       ← partie B
        └── Onglets : Semaine · Groupes · Individuel · Staff · Fatigue
```

- **Modalité** : écrans pleins, non modaux ; confirmation de séance en fenêtre.
- **Entrées** : rail, Bureau, barre haute (« Préparer » devient « Jour de match » la veille), Composition, accès rapide.
- **Sorties** : Composition (« Revoir la composition ») · Plan de jeu (« Carnet de jeu ») · Avant-match (« Aller au jour de match », principal) · Fiche du club adverse (nom cliquable) · Fiche joueur (joueur à surveiller) · Calendrier.
- **Échap** : ferme la fenêtre ; sinon retour d'un sous-écran ; sur l'écran principal sans rien d'ouvert, ouvre le menu pause (règle unique de Léo, 19/11/2026).

## 4. Hiérarchie

### A. Préparation

1. **Principal** : le rapport de force (6 secteurs, nous face à eux) **avec la phrase du danger principal** au-dessus.
2. **Secondaires** : « À faire avant le match » (liste d'étapes avec état) ; forme récente de l'adversaire ; joueurs à surveiller.
3. **Reste** : XV adverse projeté, faits récents (confrontations directes), ambiance du club, schéma de notre XV (lien vers la composition).

### B. Entraînement (onglet Semaine)

1. **Principal** : la charge de la semaine (3 choix) et le bouton « Effectuer la séance ».
2. **Secondaires** : bandeau des 7 jours (séances faites / à venir / match) ; état du groupe (charge moyenne, joueurs sous 80 %, blessés).
3. **Reste** : onglets Groupes, Individuel, Staff, Fatigue ; plans, délégation, niveau adverse.

## 5. Wireframes 1280×720

### 5.A Préparation, onglet « Dossier adverse »

```
┌────┬──────────────────────────────────────────────────────────────────────────────────────┐
│    │ Préparer la prochaine rencontre.  Meadowbridge R. – Alder Fen XV · J1 · À l'extérieur   │
│ Nav│ sam. 19/09 17:00 · Riverbank Field                                                       │
│124 │ [Dossier adverse][Consignes][Entraînement]  [Revoir la composition][Plus ▾][Aller au jour de match →]│
│ px │ ▶ Danger : « Ils jouent au près ; leurs avants sont leur point fort. »                   │
│    │ ┌ Rapport de force ───────────────────────────────┐ ┌ À faire avant le match ────────┐│
│    │ │ Alder Fen XV     (nous)        (eux)  Meadowb.   │ │ ✓ Feuille valide               ││
│    │ │ 60 ▬▬▬▬▬▬▬  Mêlée        ▬▬▬▬▬▬ 58              │ │ ✓ Condition du XV 100 %        ││
│    │ │ 62 ▬▬▬▬▬▬▬  Touche       ▬▬▬▬▬▬ 63  (écart −1)  │ │ ! Séances : 4 faites sur 5     ││
│    │ │ 65 …        Puissance    …      63              │ │ ! 1 absence internationale     ││
│    │ │ 63 …        Passe/vitesse…      62              │ │ ○ Consignes à vérifier         ││
│    │ │ 63 …        Jeu au pied  …      60              │ │ [Voir le détail →]             ││
│    │ │ 64 …        Discipline   …      63              │ │ [Adopter le plan du staff]     ││
│    │ └──────────────────────────────────────────────────┘ └────────────────────────────────┘│
│    │ ┌ Forme de l'adversaire ──────┐ ┌ Joueurs à surveiller ───────────────────────────────┐│
│    │ │ (V)(V)(N)(D)(V)  5 derniers │ │ F. BUSH · ailier · vitesse      M. IRELAND · ouvreur ││
│    │ │ ou « Pas de match cette     │ │ buteur pressenti    « Pas de signal fort » sinon     ││
│    │ │ saison »                    │ │                                                       ││
│    │ └─────────────────────────────┘ └──────────────────────────────────────────────────────┘│
├────┴──┬───────────────────────────────────────────────────────────────────────────────────────┤
│ pied  │ Échap Retour · Ctrl+Tab Onglet · F1 Aide                                              │
└───────┴───────────────────────────────────────────────────────────────────────────────────────┘
```

### 5.B Entraînement, onglet « Semaine »

```
┌────┬──────────────────────────────────────────────────────────────────────────────────────┐
│    │ Entraînement · Ta semaine                          Charge moyenne 42/100 · 0 blessé     │
│ Nav│ [Semaine][Groupes][Individuel][Staff][Fatigue]                                          │
│124 │ Lun Puissance ✓│Mar Analyse adverse ✓│Mer Ateliers ✓│Jeu Transitions ✓│Ven Passes ○│Sam ★ Match│Dim — │
│ px │ ┌ Charge de la séance du jour ─────────────────┐ ┌ État du groupe ─────────────────────┐│
│    │ │ ( ) Récupération  (●) Charge normale  ( ) Intensive │ │ Condition moyenne 96 %          ││
│    │ │ Effet attendu : condition ▲ / progression ▼ (selon le mode) │ │ Sous 80 % : 0 joueur   ││
│    │ │ [Effectuer la séance →]                       │ │ Blessés : 0 · Fatigue haute : 2     ││
│    │ └───────────────────────────────────────────────┘ │ Plus chargés : P. Haines, K. Wake…  ││
│    │ ┌ Exceptions individuelles ─┐ ┌ Charge par poste ───────────────────────────────────┐   │
│    │ │ 1 joueur ménagé [Ajuster →]│ │ Piliers 40 · Talonneurs 38 · Deuxièmes lignes 45 …  │   │
│    │ └───────────────────────────┘ └─────────────────────────────────────────────────────┘   │
├────┴──┬──────────────────────────────────────────────────────────────────────────────────────┤
│ pied  │ Échap Retour · ← → Onglet · Entrée Choisir · F1 Aide                                  │
└───────┴──────────────────────────────────────────────────────────────────────────────────────┘
```

| Zone (A) | Contenu | Taille | Défile ? | Débordement |
|---|---|---|---|---|
| En-tête | titre, match, lieu, boutons | 100 % × 22 % | Non | « Plus ▾ » regroupe les boutons secondaires |
| Danger | une phrase | 100 % × 6 % | Non | 2 lignes max |
| Rapport de force | 6 lignes face à face | 62 % × 40 % | Non | chiffres seuls sous 1100 px utiles |
| À faire | 5 lignes + 2 boutons | 36 % × 40 % | Non | « Voir le détail » replie le reste |
| Forme + surveillés | strip V/N/D, 2 joueurs | 100 % × 20 % | Non | « + n autres » |

**Focus à l'ouverture** : onglet « Dossier adverse » (A) ; onglet « Semaine » puis le choix de charge (B) ; depuis une alerte : la ligne concernée de « À faire ».

## 6. Blocs et données

### 6.1 Phrase de danger (nouvelle ligne)

Une phrase tirée du dossier adverse (plan probable + point fort), par ex. « Ils jouent au près ; leurs avants sont leur point fort. » Source : plan probable adverse (déjà affiché sur l'écran Avant-match). Absente : « Pas encore de dossier : observe-les après leur premier match. » Retire la répétition du même message aux écrans 11 et 12 en le gardant ici.

### 6.2 Rapport de force

Six lignes : **Mêlée, Touche, Puissance des avants, Passe et vitesse, Jeu au pied (même libellé qu'à l'écran Composition), Discipline**. Chaque ligne : chiffre nôtre, barre, libellé, barre adverse, chiffre adverse, **écart signé** (+2 / −1). Titre : « Rapport de force · évaluations sur 100 ajustées à la condition ». Motif « barres face à face » (manquant n°1). Pas de couleur seule : chiffres aux deux bouts.

### 6.3 « À faire avant le match » (remplace « Avant le coup d'envoi »)

Liste ordonnée, chaque ligne = **icône + mot d'état + texte + lien** :

| Ligne | États |
|---|---|
| Séances de la semaine | ✓ faites (n/n) · ! n sur N · ○ aucune |
| Feuille de match | ✓ valide · ! avertissements · ✗ incomplète |
| Condition du XV | ✓ ≥ 80 % pour tous · ! n joueurs sous 80 % |
| Absences (sélection, blessés) | ✓ aucune · ! n joueur(s) (retour jj/mm) |
| Consignes | ✓ vérifiées · ○ à vérifier |

Les lignes actuelles (« C'est le jour du match », « Vérifier le rendez-vous », cartes à bords ambre/menthe) sont **fusionnées** : date et lieu passent en en-tête. Les deux lignes « Avec ballon · Équilibré / Sans ballon · Équilibré » vont dans l'onglet Consignes. « Tous les repères (5) » et « Conseils détaillés » → **un** bouton « Voir le détail ». « Adopter le plan proposé par le staff » devient secondaire (message avec Annuler après usage).
Bouton principal : « Aller au jour de match » (déjà présent). Désactivé avec la raison tant que le moteur ne l'ouvre pas (jour ≠ veille ou jour de match).

### 6.4 Forme de l'adversaire (F6)

5 dernières rencontres, ordre chronologique, pastilles **avec lettre et forme** : V plein, N demi, D vide/croix ; infobulle : adversaire, score, date ; « Pas de match cette saison » si vide (cas actuel : le texte « Aucun résultat adverse enregistré cette saison » et la grande photo d'ambiance sont remplacés par ce libellé).

### 6.5 Joueurs à surveiller

2 à 3 joueurs adverses : photo, Prénom NOM, poste, raison en mots (« vitesse à surveiller », « buteur pressenti ») ; clic = fiche. Vide : « Pas de signal fort dans les observations disponibles. »

### 6.6 Entraînement : Semaine

| Bloc | Contenu |
|---|---|
| Bandeau des jours | 7 jours : nom du jour, séance (Puissance, Analyse adverse, Ateliers par poste, Transitions, Passes légères, Activation), état (✓ faite, ○ à venir, ★ match) ; match du jour marqué |
| Charge de la séance | choix unique : **Récupération · Charge normale · Intensive** (valeurs du moteur) ; sous le choix, l'**effet attendu** en une ligne (condition, progression, risque ; source : moteur d'entraînement, valeurs à fournir, question 2 ; **si la valeur manque, la ligne est masquée**, pas remplie par une phrase générique) |
| Bouton | « Effectuer la séance » (principal) ; états : « Charge appliquée » (déjà faite), « Séance indisponible » (avec raison : jour de match, blessé collectif…) |
| Confirmation | « Effectuer la séance · Charge retenue : Intensive. Elle sera effectuée et ses effets enregistrés. » boutons « Effectuer la séance » / « Annuler » |
| État du groupe | charge moyenne /100, condition moyenne, joueurs sous 80 %, blessés, 3 plus chargés (noms + chiffre) |
| Exceptions individuelles | « n joueur(s) ménagé(s) · Ajuster » → onglet Individuel |
| Charge par poste | piliers, talonneurs, deuxièmes lignes, troisièmes lignes, charnière, centres, trois-quarts : **libellés en toutes lettres** (aujourd'hui « PIL., TAL., 2e L., 3e L., CHAR., CEN., 3/4 ») |

Les 14 cartes-raccourcis de l'onglet actuel (Séance collective, Travail spécifique, Plan des groupes, … Délégation) sont **ramenées à 4 visibles** (Charge, Exceptions individuelles, Plan des groupes, Conseil du staff) ; les autres (Délégation, Niveau adverse, Suivi médical…) passent sous « Plus ». *À valider écran par écran : relevé de code seul.*

### 6.7 Autres onglets d'Entraînement (structure)

| Onglet | Contenu | Remarque |
|---|---|---|
| Groupes | avants / arrières, charges effectives, plans | tableau triable (E3) |
| Individuel | liste de joueurs, mode individuel (« Suivre le collectif », Récupération, Charge normale, Intensive) | un joueur blessé : « Récupération » imposée, grisée avec raison |
| Staff | préparateur, adjoint, cellule médicale ; responsabilité | texte court ; délégation |
| Fatigue | vue d'ensemble de la charge cumulée | seuils écrits (« repos conseillé au-dessus de … ») |

### 6.8 Données et événements

| Donnée | Source | Rafraîchie | Absence |
|---|---|---|---|
| Dossier adverse, rapport de force, XV projeté | moteur (rapport d'avant-match) | à chaque jour, chaque affectation | « Aucun dossier disponible pour cette rencontre. » + Voir le calendrier |
| Forme adverse | résultats du championnat | après chaque journée | « Pas de match cette saison » |
| Séances, charge, condition | moteur (entraînement) | à chaque séance | « — » |

| Action | Événement | Payload |
|---|---|---|
| Choisir la charge | `TrainingModeSelected` | `{mode}` |
| Effectuer la séance | `TrainingSessionPerformed` | `{mode}` |
| Charge individuelle | `PlayerLoadSet` | `{playerId, mode}` |
| Adopter le plan du staff | `StaffPlanAdopted` | `{}` |

## 7. Actions et raccourcis

| Action | Souris | Clavier | Réponse |
|---|---|---|---|
| Changer d'onglet | clic | ← → (déjà en code), Ctrl+Tab | focus conservé par onglet |
| Aller au jour de match | bouton | Tab, Entrée | fiche 12 |
| Revoir la composition | bouton | Tab, Entrée | fiche 10, retour à Préparation |
| Ouvrir une ligne de « À faire » | clic | Tab, Entrée | écran concerné |
| Ouvrir la fiche d'un joueur adverse | clic nom | Entrée | fiche joueur |
| Choisir la charge | clic | ← → (groupe de boutons radio) | effet attendu mis à jour |
| Effectuer la séance | bouton | Entrée | fenêtre de confirmation, W1 nommée |
| Adopter le plan du staff | bouton | Entrée | message avec Annuler |

## 8. États

| État | Déclencheur | Rendu |
|---|---|---|
| Normal | — | voir §5 |
| Première fois | première semaine | liseré sur « À faire », phrase de Gabi : « Vois d'abord ce qu'ils savent faire de mieux. » |
| Pas de rencontre | hors saison / calendrier vide | « Pas de match cette semaine. » + « Voir le calendrier » ; Aller au jour de match grisé avec raison |
| Dossier absent | adversaire inconnu | panneau « Aucun dossier disponible » + calendrier, rapport de force masqué |
| Dossier en préparation | début de saison | « Le dossier sera publié après la première journée. » |
| Chargement | commande moteur | boutons grisés avec raison ; barres grises |
| Séance déjà faite | charge appliquée | bouton « Charge appliquée » grisé, charge visible |
| Séance indisponible | jour de match, groupe inapte | raison écrite sous le bouton |
| Avertissement physique | joueurs sous 80 % | ligne « ! » dans « À faire » + liste |
| Erreur | données illisibles | bandeau + Réessayer, onglets restent actifs |

## 9. Accessibilité (T1, C1, C3, D2, D6, K1, K2, K6, K8)

- **V/N/D** : lettre + forme + infobulle ; capture en niveaux de gris et simulation de deutéranopie (D2).
- **Rapport de force** : chiffres aux deux bouts, écart signé ; pas de lecture par la longueur de barre seule (D6).
- **« À faire »** : icône + mot (« faite », « à vérifier ») ; fin des bords ambre/menthe comme seul porteur.
- Texte ~13 px à 1920 (aujourd'hui « Dossier adverse 6 secteurs », « Évaluations sur 100… » sont minuscules) ; aucune étiquette < 11 px.
- Onglets : ← → déjà gérés (K1) ; Ctrl+Tab ajouté ; ordre de focus : rail → onglets → boutons d'en-tête → danger → rapport → À faire → forme → surveillés → pied.
- Choix de charge : groupe radio, ← → ; chaque option avec nom et effet en texte.
- Confirmation de séance : focus piégé, Échap annule.
- Mouvement réduit : barres et décors statiques.
- **Contraste** : texte ≥ 4,5:1 sur son fond réel ; barres, pastilles V/N/D, focus et icônes d'état ≥ 3:1 (C1, C3) ; jetons à valider avec la direction artistique.

## 10. Ce qu'on retire, déplace, garde

| Écran actuel | Décision |
|---|---|
| 4 boutons + 3 onglets en une rangée (Préparer la suite, Revoir la composition, Carnet de jeu, Aller au jour de match) | 3 onglets + « Revoir la composition » + « Plus ▾ » (Carnet de jeu, Préparer la suite, La reprise) + « Aller au jour de match » (principal) |
| Cartes « Avant le coup d'envoi » (5 lignes à bords colorés) + 3 mini-indicateurs | « À faire avant le match » (5 lignes iconifiées) |
| « C'est le jour du match » et « Vérifier le rendez-vous » | Fusionnées dans l'en-tête (date, lieu) |
| « Avec ballon · Équilibré / Sans ballon · Équilibré » | Déplacées vers l'onglet Consignes |
| Mini-terrain « Ton XV projeté » | Retiré (doublon avec Composition) ; lien « Revoir la composition » |
| « Faits récents » (3 étapes avec grande photo) | Réduit à la forme V/N/D ; confrontations directes sous « Plus » |
| Entraînement : 14 cartes d'entrée | 4 visibles, autres sous « Plus » |
| Libellés abrégés des postes (PIL., TAL., CHAR.) | En toutes lettres |
| Rapport de force, joueurs à surveiller, séances, Avant-match | **Gardés** |

## 11. Déviations des motifs

- **Motif manquant n°1** : barres face à face adoptées pour le rapport de force.
- **F6** : pastilles V/N/D généralisées et dotées de formes.
- **W1** : confirmation de séance avec bouton nommé (« Effectuer la séance »).
- **N2** : onglets avec Ctrl+Tab en plus des flèches.
- **N5** : Échap ferme la fenêtre, puis revient du sous-écran, et n'ouvre le menu pause que sur l'écran principal (règle unique de Léo, 19/11/2026).

## 11 bis. Transitions, localisation, entrées

**Transitions** : ouverture/sortie instantanées (100 ms au plus en « Normales », 0 en « Aucune ») ; changement d'onglet : remplacement instantané, focus conservé par onglet ; fenêtre de confirmation de séance : apparition instantanée avec voile, focus piégé ; passage de séance appliquée : changement d'état immédiat ; barres de rapport de force : valeurs immédiates ; chargement : squelette gris 0,35 s ; « Mouvement réduit » : décors statiques (M1, M2).

**Localisation** (+40 % prévu ; aucun libellé de poste abrégé) : titre ≤ 40 ; phrase de danger ≤ 2 lignes de 60 ; libellé de secteur ≤ 22 (« Puissance des avants ») ; ligne de « À faire » ≤ 50 ; bouton ≤ 26 (« Aller au jour de match ») ; nom de séance ≤ 22 ; libellé de charge ≤ 18 ; effet attendu ≤ 70 ; poste en toutes lettres ≤ 24 (« Troisièmes lignes »).

**Entrées (souris + clavier ; manette hors périmètre)** : [x] onglets, boutons, ligne de « À faire », choix de charge, joueur surveillé à la souris ; [x] les mêmes au clavier (§7) ; [x] ordre de focus (§9) ; [x] aucun glisser-déposer ; [x] aucune précision de souris requise.

## 12. Critères d'acceptation

- [ ] Chaque onglet s'ouvre et place le focus en < 200 ms (hors chargement).
- [ ] Danger, forme adverse et reste-à-faire visibles sans défiler à 1280×720 / 130 %.
- [ ] La forme adverse a une lettre et une forme dans chaque pastille ; lisible en niveaux de gris.
- [ ] « Aller au jour de match » est le seul bouton plein ; grisé = raison écrite à côté.
- [ ] Séance : choix de charge au clavier, confirmation nommée, état « Charge appliquée » ensuite.
- [ ] Aucun libellé abrégé de poste dans le tableau de charge.
- [ ] Dossier absent : message + lien calendrier, pas d'écran vide.
- [ ] Parcours Préparation → Composition → retour sans perte de l'onglet ni du focus.

## 13. Questions ouvertes

| Question | Propriétaire | Statut |
|---|---|---|
| L'onglet « Consignes » de la Préparation et celui de la Composition : même composant ? | ui-programmer | Proposé : oui |
| Effets de chaque mode de charge à afficher (valeurs du moteur) | game-designer | À fournir |
| Capture de l'écran Entraînement à produire avant la passe de design | ui-programmer | Manquante |
| Plafond d'avertissement « sous 80 % » : seuil de la feuille (voir fiche 12) | game-designer | À confirmer |
| Échap sur Préparation / Entraînement sans fenêtre ouverte : retour ou pause ? | Léo | **Résolue le 19/11/2026** : retour d'un sous-écran, sinon menu pause |

## 11. Décision de Léo et intégration (revue DA du 19/11/2026)

- **Choix** : variante 1, « Le rapport de force d'abord » ; emprunt à la variante 2 : colonne « Remarque de ton adjoint » dans « Leur XV probable ». Maquettes : `direction-artistique/interface/revue-20261119/apercus/11-preparation-1.png` et `-2.png`.
- **Écran Dossier adverse** : bandeau Danger (phrase lue dans les signaux du dossier, sinon le plus gros écart de secteur ; le plan conseillé mène aux conseils) · Rapport de force (nous plein, eux anneau, chiffre et écart toujours écrits en mots ; chaque ligne mène à l'écran d'action : Composition, Plan de jeu ou Entraînement) · À faire avant le match (une ligne cliquable par repère) · Forme récente (pastilles ovales V/N/D, résultats, confrontations) · Joueurs à surveiller (portrait, nom = fiche) · Leur XV probable (15 lignes, banc, remarque de l'adjoint dérivée des vraies statistiques : disponibilité, rôle du dossier, essais, homme du match).
- **L'adjoint** : nom et fonction lus dans le staff du club (fonction « adjoint »), jamais figés ; son nom ouvre sa fiche de staff. Sans adjoint, la colonne s'intitule « Remarque du staff ».
- **Plus de petite fenêtre** : « Tous les repères » et « Conseils détaillés » sont des sous-pages du dossier (bouton « Retour au dossier adverse », étapes d'historique Précédent / Suivant). Restent des fenêtres hors périmètre : « Préparer la suite » (planning du manager) et « La reprise », partagées avec d'autres parcours.
- **Noms** : tout joueur adverse cité ouvre sa fiche (marché ou club) ou, à défaut, l'onglet XV de la fiche de son club ; survol = mini-fiche quand une fiche existe ; clubs = fiche club.
- **Humeur** : lumière froide de salle d'analyse, aucune photo ; panneaux sans rayon ni ombre ; aucun or (le seul ivoire plein est « Aller au jour de match », ou « Carnet de jeu » quand le match n'est pas ouvert).
