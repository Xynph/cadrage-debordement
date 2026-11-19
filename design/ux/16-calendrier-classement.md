# UX Spec : 16 — Calendrier, classement, rivalités (chapitre « Compétitions »)

Décisions de Léo du 19/11/2026 intégrées : densité « Football Manager » (corps ~13 px, tableaux 12-13 px, en-têtes 11-12 px, jamais sous 11 px à 1080p ; lignes de tableau 24-26 px ; échelle d'interface 90/100/115/130 %) ; règle unique d'Échap (ferme la fenêtre, sinon retour de fiche/sous-écran, sinon menu pause) et bouton « Menu » visible dans la coque ; zones de classement lues par compétition dans les données.

> **Statut** : en conception (proposé, non validé par Léo)
> **Auteur** : ux-designer (CCGS), mode autonome, rigueur `minimal`
> **Dernière mise à jour** : 19/11/2026
> **Phase du parcours** : 1.2 semaine type, 1.4 fin de saison
> **Identifiants** : routes Classements, Calendrier, Rivalités (rail « Compétitions », sous-navigation de chapitre)
> **Plateforme** : PC souris + clavier, 1280×720 à 2560×1440 ; palier Standard
> **Sources** : captures `calendrier-1920.png`, `classements-1920.png`, `rivalites-1920.png` (état : 19/09, journée 1, avant le premier match) ; `design/ux/interaction-patterns.md` N2 (trois façons de faire des onglets).
> **Non vérifié** : onglets Phases finales, Statistiques, Palmarès, Échos des clubs, Carnet complet, vue Semaine et Tableau du calendrier ; états de milieu et de fin de saison.

---

## 1. But

**Besoin** : situer son club dans le temps (quand je joue, contre qui) et dans la compétition (où je me classe, ce que ça implique).
**But du joueur** : voir en 5 secondes la date et l'adversaire du prochain match, sa place, et si un tournant approche (phases finales, barrage, relégation, selon la compétition).
**Besoin du jeu** : donner un fil de saison et de la mémoire (rivalités) pour nourrir « encore une semaine ».

### 5 secondes
1. Ma place au classement (ligne du club surlignée) et mes points.
2. Mon prochain match : adversaire, date, domicile ou extérieur, bouton « Préparer le match ».
3. Ce qui est en jeu, **selon les zones propres à la compétition** (qualification aux phases finales, barrage d'accession ou de relégation, relégation directe, ou aucune zone quand le championnat modèle n'en a pas).

### Hiérarchie (par onglet)
| Onglet | Principale | Secondaires |
|---|---|---|
| Classements | Tableau de ma compétition, ligne du club en évidence | Prochain rendez-vous ; calendrier du club (6 prochains) ; légende des zones |
| Calendrier | Mois avec matchs et séances | Programme du jour ; fil de préparation ; absences |
| Rivalités | Duels de mon club | Dossier du duel sélectionné ; compteurs |

---

## 2. Contexte à l'arrivée

| Question | Réponse |
|---|---|
| Venait de faire | Bureau (prochain match, classement court), ou fin de match |
| Émotion | Curiosité, besoin de se situer ; en fin de saison, tension |
| Charge cognitive | Basse |
| Sait déjà | Sa division, son prochain adversaire |
| Cherche | Une date, un écart de points, un dossier d'adversaire |
| Craint | Rater un match, ne pas voir la zone qui le menace |

**Cible émotionnelle** : « Je suis dans ma saison, je vois où ça se joue. »

---

## 3. Navigation

```
Compétitions (rail)
  ├── Classements   [onglets internes : Championnat · Phases finales · Calendrier · Statistiques]
  ├── Calendrier    [Mois · Semaine · Tableau ; filtres Tout · Matchs · Entraînements · Absences · Extérieur]
  └── Rivalités     [Confrontations · Échos des clubs · Palmarès · Carnet complet]
```
**Mode** : écran plein (non modal).
**Constat** : trois rangées d'onglets pour aller du Calendrier au Classement : la barre de chapitre (CLASSEMENTS / CALENDRIER / RIVALITÉS), puis les onglets internes de Classements (dont « Calendrier »), puis des boutons « Rivalités », « Classements », « Calendrier », « Parcours du manager » en haut à droite de chaque page. Une seule rangée doit rester (voir §8).

| Entrée | Déclencheur |
|---|---|
| Rail > Compétitions | clic, touche chiffre (rang du rail) |
| Bureau > classement court, prochains matchs | clic |
| Barre haute > date | ouvre le Calendrier au jour courant |
| Réception > courrier d'un match | lien |
| Fin de saison | alerte du bureau |

| Sortie | Destination |
|---|---|
| « Préparer le match » / « Préparer » (barre haute) | Préparation (adversaire) |
| « À jouer » sur une ligne | Préparation de cette rencontre |
| Clic sur un club | fiche du club |
| Clic sur un duel | dossier du duel (même page) |
| Échap | règle unique (décision de Léo, 19/11/2026) : ferme la fenêtre, sinon retour (historique), sinon menu pause ; bouton « Menu » de la coque en plus |

---

## 4. Disposition

### 4.1 Wireframe 1280×720 — Classements (onglet par défaut)

```
┌────┬───────────────────────────────────────────────────────────────────────┐
│Rail│ ‹ Alder Fen XV › Classements   [Rech.]  [Gabi]  19 sept.   [Préparer →]│
│    ├───────────────────────────────────────────────────────────────────────┤
│    │ [Classements] [Calendrier] [Rivalités]        (une seule rangée)      │
│    │ Accession anglaise · Saison 2026-2027 · Journée 1   [Championnat▾]    │
│    ├──────────────────────────────────────────┬────────────────────────────┤
│    │ # Club        J  V  N  D  PF PC Diff Bon Pts Forme│ PROCHAIN RENDEZ-VOUS │
│    │ ▌1 Alder Fen   0  0  0  0  0  0   0   0   0  ─     │ Meadowbridge R.      │
│    │  2 Northmere…                                   │ 19/09 17:00 · Extérieur│
│    │  …                                              │ [ Préparer le match → ]│
│    │ ── Zone (libellé lu dans la donnée) ───────      │ DERNIERS / PROCHAINS   │
│    │ ── Zone (libellé lu dans la donnée) ───────      │ 26/09 Trentwood (D)    │
│    │ Légende : uniquement les zones de la compétition │ 02/10 Hawthorn (E)     │
│    ├──────────────────────────────────────────┴────────────────────────────┤
│    │ Pied : Espace Suite · 1 à 9 Menus · Échap Retour · Ctrl K · F1         │
└────┴───────────────────────────────────────────────────────────────────────┘
```

### 4.2 Zones (Classements)
| Zone | Contenu | Taille | Défilable | Débordement |
|---|---|---|---|---|
| Barre de chapitre | 3 onglets | pleine × 5 % | Non | — |
| Sélecteur de compétition | chips (11 compétitions aujourd'hui) | une ligne | Non | **remplacé par un menu** ; ma compétition par défaut |
| Tableau | 14 lignes, colonnes #, Club, J, V, N, D, PF, PC, Diff, Bonus, Pts, Forme | 65 % × 70 % | Oui | colonnes de moindre priorité masquées (PF, PC) |
| Prochain rendez-vous | adversaire, date, lieu, bouton | 30 % × 30 % | Non | — |
| Calendrier du club | 6 lignes (date, adversaire, D/E, « À jouer ») | 30 % × 40 % | Non | « Toute la saison » |
| Bandeau décoratif (« La course au classement. ») | **retiré** | — | — | rend 190 px de hauteur |

### 4.3 Composants
| Composant | Rôle | Existant ? |
|---|---|---|
| Tableau de classement | lire sa place | Existant, **hors socle `tableau.gd`** (pas de tri ni de navigation clavier unifiée) : migrer |
| Pastille de forme V/N/D avec lettre | derniers résultats | Existant en Préparation, à généraliser (pattern F6) |
| Liseré + libellé de zone (qualification phases finales, barrage d'accession / de relégation, relégation directe : **selon la compétition**) | D4 | **Absent sur la capture** (aucune zone visible) : à ajouter ; pas de zone par défaut |
| Carte « Prochain rendez-vous » | action principale | Existant |
| Grille de mois | calendrier | Existant |
| Programme du jour | détail du jour | Existant |
| Tableau des duels | rivalités | Existant |
| Dossier du duel | détail | Existant |

**Focus à l'ouverture** : Classements : ligne du club ; Calendrier : case du jour ; Rivalités : premier duel **de mon club**.

---

## 5. États

| État | Déclencheur | Visuel | Comportement |
|---|---|---|---|
| Début de saison (J0) | avant la 1re journée | tous les compteurs à 0, place « – », forme vide | **Aujourd'hui : colonnes vides sans explication.** Afficher « Le championnat s'ouvre le 19/09 » dans le tableau et masquer FORME |
| Saison en cours | normal | club surligné + liseré | — |
| Zone de classement (qualification, barrage, relégation directe, selon la compétition) | selon position et selon la donnée | liseré latéral + libellé + légende | D4 |
| Fin de saison | dernière journée | bandeau « Dernière journée : il te faut X points » | — |
| Phases finales | après la saison régulière | onglet Phases finales actif par défaut | non vérifié |
| Compétition non disputée par le club | filtre autre compétition | bandeau « Ton club ne joue pas cette compétition » ; ligne du club absente | — |
| Rivalités : aucun duel de mon club | début de carrière | « Pas encore de duel. Ton premier derby apparaîtra ici. » | **Aujourd'hui, le défaut « Tous les clubs » montre 66 duels d'autres clubs** |
| Rivalités : première fois | 1er affichage | note Gabi sur la tension | une fois |
| Calendrier : jour vide | pas d'événement | case vide | — |
| Chargement / erreur | moteur | « … » ; bandeau d'erreur avec Réessayer | — |
| Match déjà joué | ligne passée | score + pastille V/N/D | — |

---

## 6. Interactions

### 6.1 Souris
| Cible | Action |
|---|---|
| Ligne de classement | clic = choisir ; double-clic = fiche du club |
| En-tête de colonne | clic = tri (comme le socle) |
| « À jouer » | ouvre la préparation |
| Case de jour | clic = programme du jour à droite |
| Mois précédent / suivant, Aujourd'hui | clic |
| Mois / Semaine / Tableau | clic |
| Duel | clic = dossier |

### 6.2 Clavier
| Touche | Effet | Statut |
|---|---|---|
| ↑ ↓ Début Fin Entrée | parcourt le tableau, ouvre la fiche | à brancher (socle) |
| ← → dans le calendrier | jour précédent / suivant | proposé |
| Pg↑ Pg↓ | mois précédent / suivant | proposé |
| Ctrl+Tab / Ctrl+Maj+Tab | onglet suivant / précédent | proposé (motif manquant n° 11) |
| Entrée sur un jour | programme du jour | proposé |
| Tri au clavier | flèche sur l'en-tête + Entrée | proposé |
| Espace, 1-9, Échap, Ctrl K, F1 | globaux, inchangés | existant |

### 6.3 Restrictions
Aucune : pas de saisie ni de décision sur ces écrans (consultation). Seul « Préparer » lance une action.

---

## 7. Données

| Donnée | Source | Mise à jour | Format | Si manquant |
|---|---|---|---|---|
| Classement de la compétition | moteur (compétition) | après chaque match | lignes | message de J0 |
| Forme (5 derniers) | historique des matchs | après chaque match | V/N/D | masquée |
| Zones | **donnée de la compétition** (rangs concernés et type de zone, par championnat réel modèle ; peut être vide) | à la saison | liste (rang de début, rang de fin, type) | aucune zone, aucune légende |
| Prochain match | calendrier | à chaque jour | date, lieu | « Aucun match programmé » |
| Séances publiées | plan d'entraînement | à la semaine | liste | « Aucune séance » |
| Absences / sélections | convocations | quotidien | texte | masqué |
| Duels (V/N/V, tension 0-100) | historique | après chaque match | entiers | « Pas encore de duel » |

Cet écran n'écrit rien. Événements : « ouvrir la préparation », « ouvrir la fiche club ».

---

## 8. Ce qu'on retire ou déplace

| Élément | Décision | Raison |
|---|---|---|
| Bandeaux décoratifs (« La course au classement. », « La mémoire des duels. ») | Retirer ou réduire à un titre d'une ligne | 190 px d'écran perdus ; Léo refuse la surcharge |
| Chips de 11 compétitions | Menu déroulant ; ma compétition en premier | Réduire le bruit |
| Onglets internes de Classements (dont « Calendrier ») | Retirer la répétition : ne garder que la barre de chapitre | Une seule façon de naviguer |
| Boutons de croisement (« Rivalités », « Classements », « Calendrier », « Parcours du manager ») | Retirer sauf « Archives des saisons » | Doublon avec les onglets |
| Duels « Tous les clubs » par défaut | Défaut = « Notre club » | Le joueur veut ses rivalités |
| Colonne FORME vide en J0 | Masquer ou « — » avec explication | Pas de colonne morte |
| Panneau bas « L'ouverture de la saison » (3 cartes) | Garder en J0 seulement | Hors J0, redondant |
| « Match à l'extérieur · aucune date de voyage distincte n'est publiée » | Reformuler « Déplacement le jour du match » | Jargon de données |
| « Comptage des créneaux, sans estimation de charge physique » | Retirer | Jargon technique |
| Sélection de la case de jour sans Tab | Ajouter un ordre de focus clair | K1 |

**À conserver** : légende V/N/D en haut du tableau (bonne pratique, lettre dans la pastille), « Préparer » dans la barre haute, programme du jour, légende du calendrier (Domicile / Extérieur / Neutre / Entraînement / Créneau passé).

---

## 9. Animations
| Transition | Durée | Réduit |
|---|---|---|
| Changement d'onglet | fondu 150 ms | instantané |
| Mois précédent / suivant | glissement 150 ms | instantané |
| Mise à jour du tableau après un match | aucune (pas de ligne qui glisse) | — |

---

## 10. Accessibilité (Standard : D2, D4, K1, K2, K6, T1)

| Texte | Fond | Seuil |
|---|---|---|
| Lignes du tableau | fond sombre | 4,5:1 ; chiffres V (vert) et D (rouge) à valider |
| Cases du calendrier (mini-textes ≈ 9-10 px à 1920) | cases sombres | ≥ 11 px réels, 12-13 px visé (T1 dense) |
| Étiquettes de colonne | idem | 4,5:1 |
| Pied de page des raccourcis (gris sur sombre) | idem | 4,5:1 (C1, défaut connu) |

| Élément | Risque | Mitigation |
|---|---|---|
| V / N / D | vert/gris/rouge | lettre dans la pastille + forme (V plein, N demi, D vide) |
| Zones de classement | teinte | liseré + libellé + légende toujours visible |
| Colonnes V (vert) / D (rouge) | couleur de chiffre | en-tête de colonne lisible, pas de sens porté par la couleur |
| Événements du calendrier | icône seule | icône + mot (déjà : Domicile, Extérieur) |

**Focus** : barre de chapitre → tableau (ligne du club) → boutons du panneau droit → pied. Calendrier : onglets → filtres → grille (jours) → programme du jour.
**Annonces** : « Classement, Accession anglaise : Alder Fen XV, 1er, 0 point », « 19 septembre, match contre Meadowbridge Rovers à 17 h ».
**Charge cognitive** : classement 14 lignes × 11 colonnes → réduire à 8 colonnes par défaut (#, Club, J, V, N, D, Diff, Pts) + Forme.

---

## 11. Critères de réception

- [ ] Ma compétition est ouverte par défaut, ma ligne surlignée.
- [ ] Les 14 lignes tiennent à 1280×720 sans défilement (colonnes secondaires masquées).
- [ ] Zones de classement identifiables en niveaux de gris (liseré + libellé).
- [ ] Forme V/N/D avec lettre, lisible en deutéranopie.
- [ ] Une seule rangée d'onglets de chapitre.
- [ ] Rivalités s'ouvre sur « Notre club ».
- [ ] Texte du calendrier ≥ 11 px réels à 1920 ; cible de jour ≥ 24 px de côté.
- [ ] Tableau parcourable au clavier (↑ ↓ Début Fin Entrée) et triable au clavier.
- [ ] À J0, aucune colonne vide sans explication.

## 12. Questions ouvertes

| Question | Propriétaire | Résolution |
|---|---|---|
| Règles exactes de promotion, barrage, relégation par compétition : source ? | game-designer | Résolue (19/11/2026) : voir `docs/rugby-rules-reference.md`, section « Classement, phases finales, accession et relégation » |
| Onglets Phases finales / Statistiques / Palmarès non capturés | ui-programmer | À capturer |
| Fusionner Classements et Calendrier en un seul écran ? | Léo | Ouverte (recommandé non : garder trois pages, une seule rangée) |

## 13. Ajouts de la revue UX (19/11/2026)

**Zones de classement** : `docs/rugby-rules-reference.md` (§ accession-relégation) documente ces règles depuis le 19/11/2026. Les zones viennent des données de compétition sourcées : liseré, libellé et légende s'affichent seulement pour les zones que la donnée fournit. Sans donnée : pas de zone, pas de légende ; une note « pas de relégation » apparaît quand il n'y en a pas.

Légende : ★ demi-finale directe, ● phase finale, ▲ barrage de montée, ◆ barrage de maintien, ▼ relégation, ○ repêchage possible. Chaque zone porte liseré, symbole et mot (jamais la couleur seule).


**Échap** : règle unique décidée par Léo le 19/11/2026 (`interaction-patterns.md` #1) : fenêtre, sinon retour, sinon menu pause ; conforme au code actuel.

**Localisation (longueurs max, +40 % prévus)** : nom de club 24 caractères (infobulle au-delà) ; en-tête de colonne 4 ; bouton « Préparer le match » 24 ; libellé de zone 22 ; case de jour : 2 lignes de 14 caractères.

**Méthodes d'entrée (PC)**
- Souris : §6.1 ; jours de calendrier ≥ 24×24 px.
- Clavier seul : Tab dans l'ordre de §10, flèches dans le tableau et la grille, Entrée, Ctrl+Tab pour les onglets ; aucun glisser-déposer.
- Manette : hors périmètre.

**Critères supplémentaires**
- [ ] Chaque onglet s'ouvre en moins de 400 ms.
