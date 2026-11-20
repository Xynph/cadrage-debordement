# UX Spec : 14 — Entracte du match (2D)

Décisions de Léo du 19/11/2026 intégrées : densité « Football Manager » (corps ~13 px, tableaux 12-13 px, en-têtes 11-12 px, jamais sous 11 px à 1080p ; lignes de tableau 24-26 px ; échelle d'interface 90/100/115/130 %) (hors direct : le texte du match garde ses minimums T2) ; en match, Échap = pause.

> **Statut** : direction artistique choisie par Léo (19/11/2026), intégrée le 20/11/2026
> **Auteur** : ux-designer (CCGS), mode autonome, rigueur `minimal`
> **Dernière mise à jour** : 20/11/2026

## 0. Choix de Léo (revue DA du 19/11/2026) — prime sur la suite de la fiche

Maquettes : `direction-artistique/interface/revue-20261119/apercus/14-match-entracte-1.png` (base), `-3.png`, `-2.png`.

- **Variante 1 · Terrain au centre** : barre (horloge, plaques des clubs — nous plein, adversaire vide —, score 40 px, phase du match, ÉQUIPE ivoire plein + « T », Réglages, Plus ▾, Reprendre/Pause) ; Mon XV + banc à gauche ; terrain 2D tracé ivoire 1 px, sans pelouse ; chiffres clés à droite (barres face à face : nous plein à gauche, eux vide à droite) ; domination minute par minute en largeur (barres pleines nous / vides eux, repères E · P · C) ; Gabi en largeur avec son action (« Remplacer le 7 par X · Entrée ») ; pied des raccourcis.
- **Emprunt 1 — panneau d'arrêt de la variante 3** : il remplace les chiffres clés dans la colonne de droite (titre « BLESSURE · 38′ », ce qui se passe, choix proposés par le staff, « Valider le choix · Entrée » ; Équipe et Réglages attendent le choix).
- **Emprunt 2 — colonne Plaquages de la variante 2** dans Mon XV (N°, joueur, énergie, plaq., note).
- **Jamais de petite fenêtre** : Réglages (vitesse, temps forts), « Autres matchs et classement » et « Confier la fin à l'adjoint » s'ouvrent à la place des chiffres clés (« ← Chiffres clés », Échap). Seul « Plus ▾ » reste un menu déroulant (exception de Léo).
- **Noms** : clic = fiche complète posée sur l'entracte (match en pause, « ← Retour au match », Échap) ; survol = mini-fiche. Ligne de Mon XV (clic, ↑ ↓ puis Entrée) = fenêtre Équipe sur ce joueur.
- **Clavier** : Espace reprend / met en pause ; T Équipe ; Échap referme la fiche ou le panneau, sinon ouvre le menu du match de la vue 13 (pause ; jamais de sortie) ; Entrée = action de Gabi ou du panneau d'arrêt.
- **Données réelles seulement** : plaquages par joueur (feuille du moteur), plaquages réussis = réussis / tentés, entrées dans les 22 (`zone22`) ; donnée absente = ligne omise.
- **Retirés de l'écran** : vue Terrain de Mon XV, carte Changement, anneaux, faits marquants (→ Journal, menu Plus), multiplex et classement en bas (→ Plus > Autres matchs).
> **Phase du parcours** : 1.3 jour de match (mi-temps, arrêt demandé, pause tactique)
> **Identifiant** : `MatchBetween` (`native/godot/ui/contextual/match_between.gd`)
> **Plateforme** : PC souris + clavier, 1280×720 à 2560×1440
> **Palier d'accessibilité** : Standard
> **Sources** : code ci-dessus (lu) ; planche `temp/mrapide/figee10/planche.png` (vignettes 2D, petites). **Pas de capture 1920 de l'entracte** : détails visuels non vérifiés.
> **Décisions de Léo à respecter** : une seule mise en page (12/11) ; pas de bouton « Passer », pas de compte à rebours (le match défile en 2D à la vitesse choisie) ; pas de sortie en plein match (16/11).
> **Liens** : `design/ux/hud.md` (même barre haute), `15-apres-match.md` (même écran, état « fini »)

---

## 1. But

**Besoin du joueur** : souffler, lire ce qui se passe et corriger avant de repartir, sans perdre le fil du match.
**But du joueur** : comprendre qui domine et décider (changement, consigne) en moins d'une minute.
**Besoin du jeu** : recueillir des ajustements tactiques et des remplacements pendant que le match continue de défiler.

### Ce qu'il voit en 5 secondes
1. Le score et l'horloge (barre haute, identique au direct).
2. Qui domine (la frise de domination) et où est le ballon (terrain 2D).
3. Ce que l'adjoint conseille (une phrase + un bouton d'action s'il y a lieu).

### Hiérarchie
| Rang | Bloc | Pourquoi |
|---|---|---|
| Principale | Terrain 2D + frise de domination | Lire le match d'un coup d'œil |
| Secondaire 1 | Carte de l'adjoint (phrase + « Remplacer le N » ou « Appliquer ») | Dit quoi faire, une chose à la fois |
| Secondaire 2 | Mon XV (noms, énergie, note) | Savoir à qui on peut toucher |
| Secondaire 3 | Chiffres clés (possession, occupation, pénalités) | Prouver la lecture |
| Derrière un bouton | Statistiques, journal, caméras, vitesse, classement en direct, autres matchs | À la demande |

---

## 2. Contexte à l'arrivée

| Question | Réponse |
|---|---|
| Qu'était-il en train de faire ? | Regarder le direct 3D ; la mi-temps ou un arrêt vient de commencer |
| État émotionnel | Tension, besoin de reprendre la main |
| Charge cognitive | Moyenne : score, fatigue, discipline |
| Ce qu'il sait déjà | Score, derniers faits |
| Ce qu'il veut | Remplacer un joueur fatigué, corriger une consigne |
| Ce qu'il craint | Rater un changement, voir le match reprendre sans avoir fini |

**Cible émotionnelle** : « Je lis le match, je garde la main. »

---

## 3. Position dans la navigation

```
Match en direct 3D (13)
  └── Entracte 2D (14)  [overlay, match en pause ou en défilement 2D]
        ├── Fenêtre Équipe (composition, banc, consignes)
        ├── Panneau Paramètres (vitesse, temps forts)
        ├── PLUS : Statistiques, Journal, Confier la fin à l'adjoint, Caméras
        └── Panneau d'arrêt (blessure, carton, choc à la tête)
```

**Mode** : overlay, jeu en défilement 2D à la vitesse choisie (pas de pause par défaut ; ÉQUIPE met en pause).
**Échap** : ferme la fenêtre ou le panneau ouvert ; sans fenêtre : **pause du match** (jamais quitter, jamais menu carrière ; décision 16/11, confirmée par la règle unique d'Échap du 19/11/2026 : en match, Échap = pause).

| Entrée | Déclencheur | Note |
|---|---|---|
| Mi-temps | fin de la 1re période | automatique |
| Arrêt de jeu | blessure, saignement, choc à la tête, carton, première ligne | panneau d'arrêt |
| Pause tactique demandée | bouton PAUSE ou ÉQUIPE | — |

| Sortie | Destination | Données |
|---|---|---|
| REPRENDRE LE MATCH | Direct 3D | changements et consignes validés |
| Fin du match (sifflet) | Même écran en état « fini » (spec 15) | résultat |
| Confier la fin à l'adjoint | Après-match, résultat joué par l'adjoint | — |

---

## 4. Disposition

### 4.1 Wireframe 1280×720

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ [45'] Meadowbridge R. [é] 0 – 0 [é] Alder Fen XV [ÉQUIPE][⚙][PLUS ▾][PAUSE]  │ barre ≤ 9 %
├───────────────┬─────────────────────────────────────────────┬────────────────┤
│ MON XV        │              TERRAIN 2D                      │ CHIFFRES CLÉS  │
│ 1 N. Dupuis 92│     {30 pastilles + ballon + phase}          │ Possession 58/42│
│ 2 T. Roussel 88│    ●  ◯                                      │ Occupation 61/39│
│ ...           │                                              │ Pénalités   3/1 │
│ 15 M. Garcia 76│   "Alder Fen a le ballon, dans son camp"     │ 22 m  2 / 1     │
│ banc (8)      │                                              │ [voir stats]    │
├───────────────┴─────────────────────────────────────────────┴────────────────┤
│  FRISE DE DOMINATION  (minute par minute)  ░░▓▓▓▓░░▓▓░░                      │
├──────────────────────────────────────────────────────────────────────────────┤
│ [Gabi]  « N° 7 est à bout (40 %) : un remplacement s'impose. »  [Remplacer le 7]│
└──────────────────────────────────────────────────────────────────────────────┘
  Pied discret : Vitesse : Normale ▸ (dans ⚙) · Échap Pause · Espace Reprendre
```
Les autres matchs de la journée et le classement en direct (aujourd'hui dans la page) : repliés sous PLUS > « Autres matchs » (voir §8).

### 4.2 Zones

| Zone | Contenu | Taille | Défilable | Débordement |
|---|---|---|---|---|
| Barre haute | horloge, score, 4 boutons | pleine largeur × ≤ 9 % | Non | — |
| Colonne gauche « Mon XV » | 15 lignes + banc, nom complet, énergie % | ~23 % × 60 % | Oui (banc) | défilement |
| Centre : terrain 2D | 30 pastilles, ballon | ~50 % × 60 % | Non | — |
| Colonne droite : chiffres clés | 4 duels à barres face à face | ~25 % × 60 % | Non | bouton « voir stats » |
| Frise de domination | momentum par minute | pleine largeur × 12 % | Non | — |
| Carte de l'adjoint | portrait Gabi, 1 phrase (2 lignes), 1 bouton | pleine largeur × 12 % | Non | texte complet en infobulle |

### 4.3 Composants (existant : `Domination`, `Formation`, `Anneau`, `Terrain2D`)

| Composant | Type | Rôle | Obligatoire | Réutilise |
|---|---|---|---|---|
| Barre haute | partagé | Score, horloge, commandes | Oui | HUD (13) |
| Terrain 2D (`Terrain2D`) | dessin | Lire le ballon | Oui | Existant |
| Frise de domination | dessin | Qui domine, minute par minute | Oui | Existant (`Domination`) |
| Mon XV | liste | Choisir qui remplacer | Oui | Existant (`xv`) |
| Chiffres clés | barres face à face | Possession, occupation, pénalités | Oui | **Nouveau motif** « barres face à face » (interaction-patterns, Manquants n° 1) ; remplace les anneaux |
| Carte de l'adjoint | carte | Une phrase, une action | Oui | Existant |
| Panneau d'arrêt | modal | Choix du staff (carton, blessure) | Si arrêt | Existant (`arret`) |
| Paramètres (vitesse, temps forts) | popup | Vitesse : Posée / Normale / Rapide / Éclair ; temps forts | Oui | Existant |
| PLUS ▾ | menu | Statistiques, Journal, Adjoint, caméras, autres matchs, classement | Oui | Existant (étendu) |

**Focus à l'ouverture** : ÉQUIPE. Si un panneau d'arrêt est présent : le choix proposé par le staff, puis REPRENDRE LE MATCH (comportement existant).

### 4.4 Ordre de lecture
1. Score et horloge ; 2. ligne « qui a le ballon » et terrain ; 3. frise ; 4. phrase de l'adjoint ; 5. Mon XV ; 6. chiffres clés. Reste derrière PLUS.

---

## 5. États

| État | Déclencheur | Visuel | Comportement | Note |
|---|---|---|---|---|
| Défilement 2D | mi-temps ou temps fort | horloge qui avance | boutons actifs, vitesse choisie | Normal |
| En pause | PAUSE, ÉQUIPE, Échap | bouton devient REPRENDRE ; texte « Match en pause » | décisions possibles | — |
| Alerte joueur | fatigué (< seuil), blessé | phrase ambre + « Remplacer le N » | clic ouvre Équipe sur le joueur | |
| Conseil de consigne | l'adjoint propose autre chose que la consigne en place | « Appliquer » | actif seulement en pause ; sinon désactivé avec la raison en infobulle | |
| Équilibré (rien à dire) | pas d'alerte, début de match | phrase en ton posé (« Début de match équilibré… ») | pas de bouton | Début de match : pas d'alarme sur échantillon court |
| Arrêt : choix | blessure, carton, choc | panneau « BLESSURE · 12' » + options (« J. Dupont · Talonneur · 82 % ») | clic = choix enregistré, puis focus REPRENDRE LE MATCH | |
| Arrêt : staff décide | choix devenu impossible | options grisées + « Le staff garde sa décision. Reprends quand tu veux. » | seul REPRENDRE actif | |
| Première fois | premier match de la carrière | infobulle Gabi sur la frise (« ça, c'est qui domine ») | une seule fois, passable | proposé |
| Erreur moteur | moteur arrêté | bandeau + bouton « Relancer le moteur » | | F9 |
| Fini | sifflet final | spec `15-apres-match.md` | | |

---

## 6. Interactions

### 6.1 Souris
| Cible | Action | Réponse |
|---|---|---|
| ÉQUIPE | clic | ouvre la fenêtre Équipe, match en pause |
| PARAMÈTRES | clic | popup vitesse + temps forts (déjà existant, valeurs : Posée, Normale, Rapide, Éclair) |
| PLUS | clic | menu |
| Ligne de Mon XV | clic | sélectionne ; double-clic = Équipe sur ce joueur |
| « Remplacer le N » / « Appliquer » | clic | comme ci-dessus |
| Frise | survol | infobulle de la minute |
| Pastille du terrain | survol | « 7 · Troisième ligne · Nom · Note 6,5 » (existant) |

### 6.2 Clavier
| Touche | Effet | Statut |
|---|---|---|
| Espace | Reprendre / Pause | **à créer** (aujourd'hui coupé pendant un match immersif) |
| Échap | ferme fenêtre ; sinon Pause | **à créer** ; jamais de sortie |
| Tab / Maj+Tab | boutons de la barre, puis Mon XV, puis carte adjoint | à vérifier |
| T | ouvre Équipe | proposé |
| ↑ ↓ dans Mon XV | change de joueur sélectionné | proposé |
| Entrée sur un joueur | Équipe sur ce joueur | proposé |
| 1 / 2 / 3 | Caméra TV / dessus / contact | proposé, voir HUD |
| 1 à 9 (menus), Ctrl+F | désactivés pendant le match | existant |

### 6.3 Restrictions par état
| État | Désactivé | Raison |
|---|---|---|
| Arrêt avec choix | Équipe, Paramètres | une décision à la fois |
| Match terminé | ÉQUIPE, vitesse, caméras | plus d'action possible |
| Moteur occupé | boutons de commande | `app.waiting` ; doit afficher « … » plutôt que griser seul |

---

## 7. Données (l'écran lit, il n'écrit pas)

| Donnée | Source | Mise à jour | Format | Si manquant |
|---|---|---|---|---|
| Score, horloge, mi-temps | `live` (moteur) | chaque seconde de jeu | entiers | « — – — » |
| Possession, occupation, pénalités, 22 m | `live.direct.tableau` | chaque minute de jeu | % / entiers | « trop tôt pour conclure » (existant) |
| Domination par minute | `live.direct.domination.minutes` | chaque minute | −100 à +100 | frise vide |
| Positions du terrain | `live.direct` | chaque temps fort | coordonnées | pastilles absentes |
| Alertes joueur | `live` (condition, alerte) | chaque minute | texte | pas de phrase |
| Conseil de l'adjoint | `live.direct.conseil` | chaque temps fort | attackReason, defenceReason, canAct | phrase générale |
| Arrêt | `live.direct.arret` | à l'événement | raison, options | panneau masqué |

### Événements fournis (commandes, jamais d'écriture directe)
`match_incident_choice {cle, id}` ; remplacement et consignes via la fenêtre Équipe ; `horloge_choisie` ; `niveau_choisi` ; `camera_demandee` ; `delegation_demandee` ; `reprise_demandee`.

---

## 8. Ce qu'on retire ou déplace

| Élément | Décision | Raison |
|---|---|---|
| Anneaux de possession / occupation (`Anneau`) | Remplacer par barres face à face avec chiffres | Comparer deux valeurs sans lire un anneau |
| Multiplex (autres matchs) en pied de page | Replier sous PLUS > Autres matchs | Hors du besoin en 5 s ; à garder pour l'envie de classement |
| Classement en direct (rang, flèche de places, bonus) | Replier sous PLUS | Idem |
| « Faits marquants » (liste) | Replier dans PLUS > Journal | Dupliqué avec le journal |
| Duel en chiffres (stats par thème) | Garder derrière « voir stats » | Progressive disclosure |
| Pastilles du terrain : couleur seule | Ajouter numéro + contour distinct (forme) | D5 |
| Texte du terrain en 11-12 px | Plancher 12 px (jamais sous 11 px, T1 dense) | Lisibilité |
| Colonnes multiples en 1280 | La colonne Mon XV passe sous le terrain à < 1100 px | Éviter la police 11 px |

### Conflit à signaler
Le code a un point d'entrée « Une seule mise en page » (Léo, 12/11). Cette spec ne propose **pas** une seconde mise en page : elle réorganise l'ordre de lecture et replie des blocs dans la même.

---

## 9. Animations

| Transition | Déclencheur | Durée | Interruptible | Mouvement réduit |
|---|---|---|---|---|
| Apparition de l'écran | début d'entracte | 250 ms, fondu | Oui | instantané (déjà respecté) |
| Pastilles du terrain qui glissent | temps fort | selon vitesse | Oui | téléportation |
| Barres de chiffres clés | mise à jour | 300 ms | Oui | valeur directe |
| Pulsation d'une alerte | alerte joueur | **aucune** | — | — |

Aucun flash. Pas d'animation qui porte seule l'information.

---

## 10. Accessibilité (Standard)

| Texte | Fond | Seuil | Mesure |
|---|---|---|---|
| Carte de l'adjoint (phrase) | panneau sombre | 4,5:1 | TBD |
| Noms de Mon XV | panneau | 4,5:1 | TBD |
| Chiffres clés, étiquettes | panneau | 4,5:1 | TBD |
| Texte du terrain (numéros) | pastille | 3:1 (grand) | TBD |

| Élément | Risque | Mitigation |
|---|---|---|
| Pastilles des deux équipes | couleurs proches | numéro + contour de forme différent par équipe (D5) |
| Domination | dégradé | signe + / − écrit, côté marqué par le nom de l'équipe |
| Alerte joueur | ambre seul | mot « épuisé / fatigué / blessé » + icône |
| Barres de condition | couleur | valeur % à côté, seuil marqué (D6) |

**Ordre de focus** : barre (ÉQUIPE, PARAMÈTRES, PLUS, PAUSE) → Mon XV (haut en bas) → bouton de l'adjoint → REPRENDRE. Pas de piège : Échap sort de toute fenêtre.
**Annonces d'état** : « Match en pause », « Mi-temps », « Choix enregistré : J. Dupont entre ».
**Charge cognitive** : 6 flux (score, horloge, ballon, domination, adjoint, Mon XV) ; chiffres clés repliables pour rester ≤ 7. Voix de Gabi : toujours aussi en texte (S1, S2).

---

## 11. Critères de réception

- [ ] Score et horloge visibles et inchangés entre le direct et l'entracte.
- [ ] Tout joueur de Mon XV atteignable et remplaçable au clavier seul.
- [ ] Phrase de l'adjoint ≥ 16 px à 1920, jamais coupée sans infobulle.
- [ ] À 1280×720 : aucun texte sous 12 px, aucun chevauchement.
- [ ] En niveaux de gris, les deux équipes du terrain restent distinguables.
- [ ] Mouvement réduit : aucun mouvement non essentiel.
- [ ] Après un choix d'arrêt, le focus est sur REPRENDRE LE MATCH.
- [ ] Échap ne quitte jamais le match.

## 12. Questions ouvertes

| Question | Propriétaire | Résolution |
|---|---|---|
| Capture 1920 de l'entracte (aucune disponible) | ui-programmer | À faire |
| Léo accepte le repli du multiplex et du classement sous PLUS ? | Léo | Ouverte |
| Espace / Échap en match : implémentation et conflit avec `actif()` | ui-programmer | Ouverte |
| « Confier la fin à l'adjoint » : confirmation nécessaire (irréversible) ? | game-designer | Ouverte |

## 13. Ajouts de la revue UX (19/11/2026)

**Localisation (longueurs max, +40 % prévus)** : nom d'équipe 22 caractères (barre) ; nom de joueur dans Mon XV 24 ; phrase de l'adjoint 90 caractères sur 2 lignes (au-delà : infobulle) ; libellé de bouton 24 (« Remplacer le N », « Confier la fin à l'adjoint ») ; étiquette de chiffre clé 18. Aucun texte dans une image (E4).

**Méthodes d'entrée (PC)**
- Souris : tout ce qui est en §6.1 ; cibles ≥ 24×24 px, boutons de la barre ≥ 28 px de haut (K6).
- Clavier seul : Tab / Maj+Tab dans l'ordre de §10, ↑ ↓ et Entrée dans Mon XV, Espace = Reprendre / Pause, Échap = ferme la fenêtre puis pause. Aucune action n'exige un glisser-déposer.
- Manette : hors périmètre.

**Critères supplémentaires**
- [ ] L'entracte s'ouvre en moins de 500 ms après le sifflet de mi-temps, sans image figée.
- [ ] Rendu sans coupe ni chevauchement à 1280×720, 1920×1080 et 2560×1440.
