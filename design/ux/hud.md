# HUD Design — Rugby Legacy 27 (match en direct, 3D)

> **Statut** : en conception (proposé, non validé par Léo)
> **Auteur** : ux-designer (CCGS), mode autonome, rigueur `minimal`
> **Dernière mise à jour** : 19/11/2026
> **Jeu** : Rugby Legacy 27 (un seul HUD : l'écran 13 « Match en direct »)
> **Plateforme** : PC, souris + clavier, 1280×720 à 2560×1440. Pas de manette.
> **GDD liés** : `docs/rugby-rules-reference.md` (lois, cartons, mi-temps) ; `design/player-journey.md` § 1.3 ; aucun GDD de match sous `design/gdd/` (non vérifié).
> **Palier d'accessibilité** : Standard (`design/accessibility-requirements.md`, ID T2, C5, D5, M2-M4, S1-S3, S6, K7)
> **Référence de style** : aucune charte écrite ; style = direction artistique (ce document ne choisit ni couleur ni police)
> **Sources** : capture `temp/ecrans-vivants/direct-1920.png`, planche `temp/mrapide/figee10/planche.png`, `ui/contextual/match_between.gd` (commandes, arrêt). Code du HUD 3D (vérifié à la revue UX du 19/11) : `native/godot/ui/contextual/live_view.gd` (bandeau score/horloge, bouton PAUSE, ligne météo `MatchWeather`, barre de commandes, tiroir Stats/Journal) et `ui/contextual/match_temps_forts.gd` (bande de commandes en mode temps forts) ; `native/godot/match_view.gd` est seulement la scène 3D (terrain, stade, ballon), sans HUD. **Écart fiche/code** : la barre actuelle du code porte ÉQUIPE, STATS, JOURNAL, TV, VUE DE DESSUS, CONTACT, Cadence ×1/×4/×12, CONFIER LA FIN À L'ADJOINT, VALIDER LA JOURNÉE → ; PAUSE est dans le bandeau du score. La fiche décrit la cible (4 boutons ÉQUIPE, PARAMÈTRES, PLUS, PAUSE) : STATS, JOURNAL, caméras, cadence et CONFIER LA FIN passent sous PARAMÈTRES / PLUS ; le bouton de fin (« VALIDER LA JOURNÉE → » aujourd'hui) reste le bouton principal de fin de match. Les mesures de §7 restent à prendre sur capture.
> **Périmètre** : tout ce qui recouvre le 3D pendant le direct. L'entracte 2D est un écran (`14-match-entracte.md`) ; l'après-match aussi (`15-apres-match.md`).

---

## 1. Philosophie du HUD

**Relation avec l'information** : le match est un spectacle que le manager pilote. On lit le score et l'horloge sans chercher, le reste se devine à l'image, et chaque fait important est écrit une fois, en une phrase.

**Principe de visibilité** : CONTEXTUEL. En cas de doute, on cache, sauf score et horloge.

**Règle de nécessité** : « Un élément HUD gagne sa place quand le joueur ne peut pas le déduire de l'image 3D en 2 secondes et qu'il peut agir dessus ou perdre le fil sans lui. »

**Protégés (jamais masqués, jamais estompés)** : le score et l'horloge. Rien ne se superpose à eux (bandeau d'essai, carton, tooltip, fenêtre Équipe incluse sur sa partie haute).

---

## 2. Architecture de l'information

### 2.1 Inventaire (ce que le match produit)

Score, horloge de jeu, mi-temps/fin, possession (qui a le ballon, où), phase (mêlée, touche, ruck, jeu courant), dernier fait écrit (journal), essais, pénalités et coups de pied, cartons, blessures/saignement/choc à la tête, remplacements, météo (« Temps sec »), momentum, stats (possession, territoire, plaquages), notes de joueurs, fatigue des joueurs, consignes en place, autres matchs de la journée, classement en direct, avis de l'adjoint (Gabi).

### 2.2 Catégorisation

| Information | Toujours | Contextuel | À la demande | Caché / 3D | Raison |
|---|---|---|---|---|---|
| Score | X | | | | Besoin n° 1, lisible en < 2 s |
| Horloge | X | | | | idem ; passe à « MT » / « FIN » |
| Qui a le ballon, où | X | | | | Une ligne, remplace l'ancienne ligne libre sur le gazon |
| Dernier fait (journal) | X | | | | Texte, équivalent visuel du sifflet (S3, S6) |
| Essai, carton, blessure | | X | | | Bandeau temporaire, prend la place du journal |
| Remplacement, fatigue | | X | | | Alerte seulement si urgent (voir §8) |
| Météo | | | X | | Dans PLUS > Statistiques ; plus dans la barre (le libellé « Sec » est coupé) |
| Stats, notes, momentum | | | X | | Entracte 2D ou PLUS |
| Journal complet | | | X | | PLUS > Journal du match |
| Autres matchs, classement | | | | X | Entracte uniquement |
| Phase (mêlée, touche) | | | | X | Se lit à l'image |

---

## 3. Zones de l'écran

### 3.1 Diagramme (1280×720)

```
 0%                                                          100%
 ┌────────────────────────────────────────────────────────────┐ 0%
 │ [12']  Meadowbridge R. [é] 0 – 0 [é] Alder Fen XV          │
 │        (HAUT : barre unique, ≤ 9 % de la hauteur)          │
 │                         [ÉQUIPE][⚙ PARAMÈTRES][PLUS ▾][PAUSE]
 ├────────────────────────────────────────────────────────────┤ ~9%
 │ ▌Alder Fen XV a le ballon dans son camp  (HAUT-GAUCHE,     │
 │  ligne 1, fond ≥ 70 %)                                      │
 │                                                            │
 │                                                            │
 │              ZONE CENTRALE 40 % × 40 % :                   │ 30-70 %
 │              AUCUN élément permanent                       │
 │                                                            │
 │                                                            │
 │ ┌─────────────────────────────────────┐                    │ ~88%
 │ │ ESSAI · Donal GANNON (bandeau)       │  BAS-GAUCHE :      │
 │ │ AFN commet un en-avant : introd...   │  journal, 2 lignes │
 │ └─────────────────────────────────────┘                    │
 └────────────────────────────────────────────────────────────┘ 100%
   marge de sécurité 24 px (PC fenêtré ; pas de zone TV)
```

### 3.2 Tableau des zones

| Zone | Position | Éléments | Max simultanés | Remarque |
|---|---|---|---|---|
| Haut (barre) | 0 à 9 % de la hauteur, pleine largeur utile | Horloge, score, 4 boutons | 6 | Une seule rangée. Aujourd'hui : 14 % de haut + une seconde rangée de boutons |
| Haut-gauche sous la barre | 9 à 13 % | Ligne « qui a le ballon » | 1 | Doit avoir un fond (aujourd'hui du texte nu sur le gazon, viole C5) |
| Centre | 30-70 % × 30-70 % | rien | 0 | Sauf alerte critique (§8) |
| Bas-gauche | 82 à 97 % | Journal ou bandeau d'événement (même emplacement) | 1 visible, 1 bandeau | Largeur ≤ 40 % |
| Bas-droite, haut-droite sous barre | — | libre | 0 | On ne remplit pas |

**Marges** : PC, pas de zone sûre TV. Marge fixe 24 px à 1080p autour de tout élément.

---

## 4. Éléments

### 4.1 Tableau

| Élément | Zone | Toujours | Déclencheur | Source | Mise à jour | Taille max | Taille min lisible | Priorité | Alternative accessible |
|---|---|---|---|---|---|---|---|---|---|
| Horloge | Haut-gauche | Oui | — | moteur (`live`) | chaque seconde de jeu | 8 % largeur | 24 px | 1 | « MT », « FIN » en lettres ; pas de couleur seule |
| Score + noms + écussons | Haut-centre | Oui | — | moteur | à l'essai, au coup de pied | 36 % | score 36 px ; noms 20 px | 1 | écusson + nom ; D5 |
| PAUSE / REPRENDRE | Haut-droite | Oui | — | commande | au clic | 7 % | 16 px | 2 | libellé change, icône en plus |
| ÉQUIPE | Haut-droite | Oui | — | commande | — | 7 % | 16 px | 2 | l'infobulle dit « le match se met en pause » |
| PARAMÈTRES | Haut-droite | Oui | — | préférences | — | 9 % | 16 px | 3 | idem |
| PLUS ▾ | Haut-droite | Oui | — | commande | — | 6 % | 16 px | 3 | Statistiques, Journal, Adjoint, caméras |
| Ligne de possession | Haut-gauche bas | Oui | changement de possession | moteur | à chaque changement | 30 % | 16 px | 4 | texte, pas d'icône seule |
| Journal (dernier fait) | Bas-gauche | Oui | à chaque fait | moteur | à chaque fait, reste ≥ 4 s | 40 % | 16 px | 3 | est lui-même l'alternative au son (S3) |
| Bandeau d'événement | Bas-gauche, au-dessus du journal | Non | essai, carton, blessure | moteur | 4 s min, relisible dans le journal | 40 % | 20 px | 2 | mot + nom + équipe, jamais couleur seule |

### 4.2 Détails

- **Horloge** : pastille ; format `12'` ; `MT` à la mi-temps, `FIN` au sifflet final ; reste visible en pause. Jamais animée.
- **Score** : `0 – 0` avec écusson et nom de chaque équipe, noms complets (ex. « Meadowbridge Rovers ») sans troncature ; à 1280 px, abréviation à 3 lettres uniquement si le nom ne tient pas, avec infobulle. Aucun flash au changement : fondu doux 300 ms (M4).
- **Boutons** : ÉQUIPE reste le seul bouton plein (action principale). REPRENDRE remplace PAUSE en pause. Libellés en lettres, ≥ 32 px de haut à 1080p (K6).
- **Ligne de possession** : une phrase du moteur (« Alder Fen XV a le ballon dans son camp »). Fond ≥ 70 % d'opacité.
- **Journal** : 2 lignes max visibles, 40 caractères par ligne max conseillés à 16 px ; pas de troncature d'un nom (T5). Texte complet en infobulle et dans PLUS > Journal.
- **Bandeau d'événement** : « ESSAI · Donal GANNON · Alder Fen XV » ; carton « CARTON JAUNE · n° 8 AFN » ; blessure « BLESSURE · n° 7 ». Contient toujours un mot, jamais seulement une couleur ou une icône.

---

## 5. États du HUD par contexte

| Contexte | Montré | Caché | Modifié | Transition |
|---|---|---|---|---|
| Direct, jeu courant | tout §4 sauf bandeau | — | — | — |
| Fait important (essai, carton) | + bandeau d'événement | — | journal décalé de 1 ligne | fondu 200 ms, reste 4 s |
| Pause | tout | — | PAUSE devient REPRENDRE ; voile 0 % (pas d'assombrissement) | immédiat |
| Fenêtre Équipe ouverte | barre haute | journal, bandeau | match en pause automatique | immédiat ; Échap ferme et reprend |
| Temps fort (caméra changée) | tout | — | PLUS affiche la caméra courante | immédiat |
| Mi-temps / arrêt de jeu long | barre haute avec `MT` | journal | bascule vers l'entracte 2D | fondu 250 ms (instantané en mouvement réduit) |
| Arrêt pour blessure, carton | + bandeau, + panneau de choix (voir `14-match-entracte.md`, arrêt) | journal | le match est en pause tant que la décision n'est pas prise ou reprise | immédiat |
| Fin du match | score final, `FIN` | boutons Équipe, Paramètres | bandeau « Coup de sifflet final » + bouton principal vers l'après-match | fondu |
| Avant-match (tunnel, écran 12) | rien (le HUD n'existe pas encore) | tout §4 | HUD apparaît au coup d'envoi | fondu 250 ms (instantané en mouvement réduit) ; tunnel passable d'une touche (M3) |
| Pas de données moteur / moteur arrêté | barre haute figée, message | — | bouton principal « Relancer le moteur » | voir `design/ux/interaction-patterns.md` F9 |

---

## 6. Hiérarchie de l'information

| Élément | Niveau | Raison | Si caché |
|---|---|---|---|
| Score | MUST KEEP | Raison d'être du match | — |
| Horloge | MUST KEEP | idem | — |
| Journal | MUST KEEP | Seul équivalent écrit des événements sonores (S3) | PLUS > Journal |
| Bouton principal (ÉQUIPE / PAUSE) | MUST KEEP | Agir et s'arrêter (K7) | clavier : Espace |
| Ligne de possession | SHOULD KEEP | Contexte, mais l'image le dit | Se lit à l'image |
| PARAMÈTRES, PLUS | SHOULD KEEP | Rarement utilisés pendant le jeu | Clavier |
| Bandeau d'événement | SHOULD KEEP | Pointe l'important ; redondant avec le journal | Journal |
| Météo, momentum, stats | CAN HIDE | À la demande | PLUS |
| Libellé « Sec » sous le score | ALWAYS HIDE | Coupé (« Temps sec » devient « Sec »), ne dit pas ce que c'est | PLUS > Statistiques |

---

## 7. Budget visuel

| Contrainte | Limite | Mesure | Estimation actuelle (capture 1920, à l'œil) | Statut |
|---|---|---|---|---|
| Éléments HUD simultanés | **8** permanents + 1 bandeau | Compte à une image donnée | 8 permanents + 1 libellé « Sec » + bandeau | À corriger : retirer « Sec » |
| Surface HUD, jeu courant | **≤ 12 %** de l'écran | Pixels HUD / pixels écran | ≈ 15 % (barre 14 % de haut, 2 rangées) | Dépasse |
| Surface HUD, avec bandeau | ≤ 14 % | idem | ≈ 17 % | Dépasse |
| Hauteur de la barre haute | **≤ 9 %** de la hauteur (≤ 97 px à 1080p) | Mesure | ≈ 130 px sur 1080 (12 %) | Dépasse : fusionner les deux rangées |
| Zone centrale 40 % × 40 % | **0 %** permanent | Mesure | 0 % | OK |
| Opacité max d'un fond de texte | **85 %** | Alpha du panneau | à mesurer | À vérifier |
| Opacité min d'un fond de texte | **70 %** (S1, C5) | idem | à mesurer | À vérifier |
| Contraste texte HUD | ≥ 4,5:1 au pire pixel, sur 3 décors (jour, nuit, gradins clairs) | Outil de contraste | ligne de possession sans fond : échec probable | À corriger |
| Taille minimale du texte | 16 px à 1920 (T2), 14 px à 1280 | Mesure | journal OK (~22 px) ; boutons à vérifier | À vérifier |
| Score | ≥ 36 px à 1920 | Mesure | ≈ 50 px | OK |

Règle : tout ajout au-delà de ces limites remplace ou réduit un élément existant, avec l'accord de Léo.

---

## 8. Retours et notifications

| Type | Déclencheur | Position | Durée | Animation | Max | Priorité | File | Fermable |
|---|---|---|---|---|---|---|---|---|
| Essai, transformation, pénalité réussie | moteur | Bas-gauche (bandeau) | 4 s | fondu 200 ms | 1 | Haute | remplace le précédent après 4 s | Non (relisible dans le journal) |
| Carton, blessure, choc à la tête | moteur | Bas-gauche + panneau de choix | jusqu'à la décision | fondu 200 ms | 1 | Critique | jamais en file, passe devant | Non |
| Fait courant (en-avant, touche) | moteur | Journal | ≥ 4 s | aucune | 1 | Basse | écrase le précédent | Non |
| Alerte de fatigue d'un joueur | adjoint | Ligne de l'adjoint (PLUS) | — | aucune | 1 | Moyenne | non affichée en direct, seulement à l'entracte | — |
| Erreur de sauvegarde ou moteur | système | Bandeau haut sous la barre | jusqu'à action | aucune | 1 | Critique | passe devant | Oui |

**Règles de file**
1. Au plus 1 bandeau. Un fait plus important remplace un fait moins important ; à égalité, le nouveau attend 4 s.
2. Faits identiques en moins de 500 ms (deux en-avant de suite) : fusionnés en une ligne.
3. Carton, blessure, erreur : jamais mis en file ni fusionnés.
4. Tout ce qui disparaît seul reste relisible (M6) : PLUS > Journal du match.

---

## 9. Adaptation plateforme

| Plateforme | Zone sûre | Résolutions | Entrée | Notes |
|---|---|---|---|---|
| PC Windows (fenêtré, plein écran, ultra-large) | marge 24 px | 1280×720 à 2560×1440, 21:9 | Souris + clavier | Barre ancrée en haut ; bandeaux ancrés bas-gauche, sans étirement en 21:9 |
| Steam Deck | — | 1280×800 | non ciblé | Seul le 720p compte |

À 1280×720 : texte à l'échelle 130 % proposée par défaut (E1) ; la barre garde 2 lignes max.
Repositionnement des éléments par le joueur : **non requis** (palier Standard, pas de console).

---

## 10. Accessibilité

### 10.1 Couleur seule
| Élément | Risque | Correction |
|---|---|---|
| Maillots orange / blanc | Daltonisme, deux équipes confondables | Écusson dans le bandeau, bandeau ou motif de manche (D5) |
| Bandeau ESSAI | couleur | Le mot ESSAI + nom du joueur |
| Cartons | jaune/rouge | Le mot « jaune » / « rouge » |
| Score qui change | flash | Fondu doux, jamais de flash (M4) |

### 10.2 Taille du texte
| Élément | 100 % | 130 % | Débordement |
|---|---|---|---|
| Score | 36 px mini (code : 46 px au calque) | 47 px | Noms : passage à 3 lettres + infobulle |
| Journal | 16 px mini | 21 px | 3 lignes max puis « … » avec texte complet en infobulle |
| Boutons | 16 px mini, 32 px de haut | 21 px, 42 px de haut | La barre passe sur 2 lignes (limite : 2 lignes, voir §9) |

### 10.3 Mouvement
| Élément | Sévérité | Désactivé par « Mouvement réduit » ? | Remplacement |
|---|---|---|---|
| Fondu des bandeaux | Faible | Oui | Apparition instantanée |
| Caméra qui bouge, replay | Moyenne | Oui (vue fixe TV proposée) | Caméra fixe, saut direct |
| Effet d'essai | Faible | Oui | Bandeau seul |

### 10.4 Sous-titres et voix
- Défaut : activés (S1). Position : sous le journal, bas-gauche ; 2 lignes de 40 caractères max ; fond ≥ 70 % ; 16 px à 1920 ; nom du locuteur toujours écrit (« Gabi : … ») ; reste ≥ durée audio + 0,5 s.
- Légendes d'événements sonores : « sifflet de la mi-temps », « essai » dans le journal (S6).

### 10.5 Réglages (déjà prévus dans `accessibility-requirements.md` §5)
Taille du texte (100/115/130 %), échelle de l'interface, mouvement réduit, vitesse des transitions, sous-titres, mode daltonien. Pas de réglage d'opacité du HUD requis au palier Standard ; **proposé** : « Fond des textes du match » 70 / 85 %.

### 10.6 Clavier (K7, K1)
Pendant le direct les raccourcis globaux sont coupés (`raccourcis_clavier.actif()`). **Proposé, à implémenter** : Espace = Pause / Reprendre ; Échap = pause (jamais « quitter » : décision du 16/11 « pas de sortie en plein match ») ; T = Équipe ; 1, 2, 3 = caméra TV, dessus, contact (hors saisie). Tab parcourt les 4 boutons dans l'ordre de lecture ; focus visible 2 px.

---

## 11. Réglages à externaliser

| Paramètre | Valeur | Plage | Effet | Joueur ? |
|---|---|---|---|---|
| Durée du bandeau d'événement | 4 s | 3-6 s | plus long = plus lisible | Non |
| Opacité du fond des textes | 80 % | 70-85 % | contraste | Oui (proposé) |
| Hauteur de la barre haute | 9 % | 8-10 % | place à l'image | Non |
| Taille du texte du journal | 16 px à 1080p | 16-22 | lisibilité | Via « Taille du texte » |
| Fusion de faits identiques | 500 ms | 300-800 | moins de répétitions | Non |

---

## 12. Critères de réception

**Disposition**
- [ ] Barre haute ≤ 9 % de la hauteur à 1280×720, 1920×1080 et 2560×1440.
- [ ] Surface HUD ≤ 12 % en jeu courant (mesure sur capture).
- [ ] Aucun élément permanent dans le centre 40 % × 40 %.
- [ ] Score et horloge jamais recouverts, y compris par la fenêtre Équipe et les bandeaux.
- [ ] Aucun élément sous 24 px des bords.

**Accessibilité**
- [ ] Tout texte ≥ 4,5:1 sur 3 décors (jour, nuit, gradins clairs).
- [ ] Texte du journal ≥ 16 px à 1920 ; score ≥ 36 px.
- [ ] Capture en niveaux de gris : équipes, cartons, essais restent distinguables.
- [ ] Aucun flash > 3 par seconde ; aucun flash rouge plein écran.
- [ ] « Mouvement réduit » supprime fondus et mouvements de caméra annoncés en §10.3.
- [ ] Pause, Équipe et Reprendre atteignables au clavier seul.

**Retours**
- [ ] Un essai, un carton et une blessure ont chacun un bandeau avec mot + nom.
- [ ] Deux faits identiques < 500 ms ne produisent qu'une ligne.
- [ ] Un bandeau disparu est relisible dans PLUS > Journal du match.

**Plateforme**
- [ ] 1280×720 sans coupe ni chevauchement ; 21:9 sans étirement.

---

## 13. À retirer, déplacer, trancher

| Sujet | Décision proposée |
|---|---|
| Seconde rangée de boutons (ÉQUIPE, PARAMÈTRES, PLUS sous la barre) | Remonter dans la barre, à droite de PAUSE |
| Libellé « Sec » sous le score | Retirer de la barre ; météo dans PLUS > Statistiques |
| Ligne de possession sans fond | Lui donner un fond ≥ 70 % |
| Journal en bas ~22 px, très large | Limiter à 40 % de largeur, 2 lignes |
| Bandeau « ESSAI » | Garder ; l'aligner sur le journal (même emplacement) |

| Question | Propriétaire | Échéance | Résolution |
|---|---|---|---|
| Où est le code du HUD 3D ? | ui-programmer | — | Résolue (revue UX 19/11) : `ui/contextual/live_view.gd` et `match_temps_forts.gd` ; les valeurs §7 restent à mesurer sur capture |
| Léo accepte Espace = Pause et T = Équipe pendant le direct ? | Léo | avant implémentation | Ouverte |
| Fusionner les deux rangées de boutons fait-il tenir la barre à 1280 px ? | ui-programmer | prototype | Ouverte |
| Quel est le libellé exact de « Sec » (météo ?) | game-designer | — | Résolue (revue UX 19/11) : c'est la ligne météo `MatchWeather` (« Temps sec », `meteo_texte.gd`), coupée par `clip_text` + points de suspension ; décision de §6 maintenue (hors barre, dans PLUS > Statistiques) |
