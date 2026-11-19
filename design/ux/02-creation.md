# UX Spec : Création de carrière

Décisions de Léo du 19/11/2026 intégrées : densité « Football Manager » (corps ~13 px, tableaux 12-13 px, en-têtes 11-12 px, jamais sous 11 px à 1080p ; lignes de tableau 24-26 px ; échelle d'interface 90/100/115/130 %).

> **Statut** : En conception (brouillon autonome, rigueur `minimal`)
> **Auteur** : ux-designer (CCGS)
> **Dernière mise à jour** : 19/11/2026
> **Phase du parcours** : 1.1 Première heure, étape « Création »
> **Identifiant** : `ImmersiveCreationWorkspace` (code : `entry_canvas.gd`) ; sous-vue packs : `ImmersiveIdentityWorkspace`
> **Plateforme** : PC Windows, souris + clavier, 1280×720 à 2560×1440
> **Palier d'accessibilité** : Standard
> **Entrées liées** : `player-journey.md` (écran 02), `interaction-patterns.md` (E1, E2, V8, F8, N2), `accessibility-requirements.md`
> **Écrans liés** : `01-accueil.md`, `03-chargement.md`, `04-bureau.md`
> **Sans style visuel** : couleurs et polices relèvent du directeur artistique.

## 1. But

- **Joueur** : choisir un club en sachant ce qu'il implique (niveau, ambition, stade, ce qu'on attend de lui), puis lancer la carrière, sans peur de mal choisir.
- **Jeu** : obtenir `club` + options de carrière et lancer `new_career`.
- **Émotion visée** : excitation guidée ; on peut toujours revenir en arrière sans rien perdre.

## 2. Ce qu'il doit voir en 5 secondes

1. **Principal** : la grille des clubs de la division choisie, un club sélectionnable d'un clic.
2. **Secondaires** (3) : le sélecteur de division (pays puis ligue), le panneau de présentation de la division/club choisi, le bouton de validation avec son état.
3. **Le reste** : packs et identités, aide Gabi, compteur global (« 114 clubs jouables »).

## 3. Étapes (existant à clarifier)

Fil actuel : `01 Réalité · 02 Club · 03 Carrière`.
- **01 Réalité** (jeu de base ou pack importé) : **sort du fil principal** ; par défaut « Jeu de base » préchoisi, étape ouverte seulement via « Identités et packs » (le joueur ordinaire n'a pas de décision à y prendre).
- **02 Club** : pays > ligue > club (cet écran).
- **03 Carrière** (« Options de carrière », lu dans `creation_options/layout.gd`, non capturé : à vérifier à l'écran) : page sans défilement à 1920×1080, grille de 3 colonnes sur 2 rangs.
  - Rang 1 : « Ton club » (carte club, photo du stade) · « Ta première saison » (frise et choix du départ : `creation_start`) · « Gabi se présente ».
  - Rang 2, colonne gauche : « Le mot du président », « Rivalités » ; colonne centrale : « Championnats suivis », puis les deux actions **« ← Changer de club »** et **« Prendre les rênes → »** (principal) ; colonne droite : « Ton vestiaire » (visages, niveau de départ) et « Les rendez-vous qui t'attendent » (conférence d'arrivée, point avec la direction, reprise des premiers clubs, retour des internationaux, tests de novembre).
  - « Prendre les rênes » est inactif si une commande est en cours, si le pack choisi n'est pas installé, ou si le rôle « sélection » n'a pas de sélection choisie.
  - Aperçu moteur en attente : emplacements vides, puis repli sur le catalogue de création si le moteur ne répond pas.
  - Le bouton final s'appelait « Commencer » dans les versions précédentes de cette fiche : le libellé réel est « Prendre les rênes ».

Le fil devient `1 Club · 2 Carrière`.

## 4. Navigation

```
01 Accueil
  └── Nouvelle carrière
        ├── [Identités et packs]  (secondaire)  --> retour ici
        └── 1 CLUB  <-- cet écran
              └── 2 CARRIÈRE (récap + options)
                    └── Prendre les rênes --> 03 Chargement --> 04 Bureau
```

Sorties : « Accueil » (haut gauche, toujours visible), Échap = retour d'une étape, puis à l'accueil. Aucune donnée n'est écrite avant « Prendre les rênes » ; donc pas de confirmation de sortie.

## 5. Wireframe 1280×720 (étape Club)

```
+----------------------------------------------------------------------------------------------+
| [<- Accueil]  1 Club  >  2 Carrière                          [Identités et packs] Gabi · ?  |
+----------------------------------------------------------------------------------------------+
| Choisir son club                                             [Rechercher un club... Ctrl F]  |
| [● France] [Angleterre] [Japon] [International]                                              |
| [ Élite · 14 ] [ Accession · 16 ] [ Fédérale · 14 ]                                          |
+-----------------------------+----------------------------------------------------------------+
| {photo de la ligue}         | Élite française                                14 clubs        |
| Élite française             | Trier : [Niveau v]                                             |
| 14 clubs · saison 2026-2027 | +-----------------+ +-----------------+ +-----------------+    |
| FORMAT ET ENJEUX            | |{écusson} Club A | |{écusson} Club B | |{écusson} Club C |    |
| 26 matchs par club...       | | Ville           | | Ville           | | Ville           |    |
| Les six premiers : phases   | | Niveau 80,0     | | Niveau 77,2     | | Niveau 75,3     |    |
| finales. Le dernier         | | 61 joueurs      | | 58 joueurs      | | 58 joueurs      |    |
| descend...                  | +-----------------+ +-----------------+ +-----------------+    |
|                             |  ... (grille 3 colonnes, page 1/2  [< >])                      |
| [ Choisis un club ]         |                                                                |
+-----------------------------+----------------------------------------------------------------+
| 114 clubs jouables · 5962 joueurs                                                              |
+----------------------------------------------------------------------------------------------+
```

Une fois un club choisi, le panneau gauche affiche le club (écusson, stade, niveau, budget et ambition en une ligne chacun) et le bouton devient « Continuer avec [Club] ».

## 6. Blocs de contenu et données exactes

| Bloc | Contenu | Remarque |
|---|---|---|
| Pays | France, Angleterre, Japon, International (drapeau + nom) | onglets ; l'actif porte le soulignement **et** un état « sélectionné » programmatique |
| Ligues | nom + nombre de clubs (« Élite · 14 ») | idem |
| Panneau ligue | image, nom, « 14 clubs du championnat », « 2026-2027 saison de départ », « FORMAT ET ENJEUX » (texte de règles) | texte ≥ 13 px, 3 lignes visibles puis « Lire la suite » |
| Carte club | écusson, nom, ville, **niveau** (ex. 80,0), **nombre de joueurs** | aujourd'hui « 80,0 » seul et « 61 j. » : libellés manquants/abrégés → écrire « Niveau » et « 61 joueurs » |
| Pagination | « page n/m », ‹ › | existante (`CreationPagination`) |
| Bouton | « Choisis un club » (inactif) puis « Continuer avec [Club] » | raison de l'inactivité écrite dans le bouton |
| Pied | « 114 clubs jouables · 5962 joueurs » | repris de l'accueil |

À ajouter par club sélectionné (données déjà présentes dans le jeu, à confirmer) : budget, ambition du conseil, stade. Sans cela le « peur de mal choisir » n'est pas levée.

## 7. Actions et raccourcis

| Entrée | Effet |
|---|---|
| Clic carte club | sélectionne (1er clic), met à jour le panneau gauche |
| Double-clic / Entrée sur carte sélectionnée | passe à l'étape 2 |
| Flèches ← → ↑ ↓ | déplacent le focus dans la grille ; Pg↑/Pg↓ changent de page |
| Tab | ordre : retour, pays, ligues, recherche, tri, grille, pagination, bouton, packs, Gabi |
| Ctrl F / Ctrl K | focalise la recherche de club (proposé : filtre local insensible aux accents) |
| Échap | retour d'une étape ; en 1 Club : retour à l'accueil |
| F1 | Gabi |
| Entrée sur bouton « Continuer » | étape suivante |
| Étape 2 : « Prendre les rênes » (ou « ← Changer de club » pour revenir) | lance `new_career` (écran 03) |

## 8. États

| État | Déclencheur | Visuel / comportement |
|---|---|---|
| Aucun choix | ouverture | bouton inactif « Choisis un club », focus sur la première carte |
| Club choisi | clic | carte sélectionnée avec liseré **et** coche (pas la couleur seule), panneau gauche mis à jour |
| Recherche vide | aucun club ne correspond | « Aucun club ne correspond. » + bouton « Effacer la recherche » (F8) |
| Pack manquant | pack de création absent | bandeau d'alerte haut + « Installer ou choisir un pack » ; carte inactive avec raison visible |
| Chargement | `new_career` lancé | écran 03 ; boutons inactifs, pas de double envoi |
| Erreur | création refusée | avis nommant la cause et l'action (« Choisis un autre club », « Relance depuis l'accueil ») ; la sélection est conservée |
| Club non jouable | hors périmètre | **retiré de la grille** (pas grisé), comme le fait l'accès rapide |

## 9. Accessibilité

- **Contraste** : texte des cartes sur fond sombre ≥ 4,5:1 ; chiffres de niveau ≥ 13 px (T1), carte entière ≥ 24 px de haut, cible souris ≥ 28 px (K6). Écussons sur fond : aplat de rattrapage si l'écusson est clair (C5).
- **Couleur** : un club n'est jamais distingué par la seule couleur de son écusson ; le nom reste toujours écrit (D1). Aucun état ne passe par la seule teinte (liseré + coche).
- **Focus** : 2 px, 3:1, ordre visuel ; focus sur la première carte à l'ouverture (K8) ; flèches dans la grille (K1).
- **Pas de glisser**, pas de limite de temps (K6, K7).
- **Mouvement** : transitions entre pays/ligue sans animation sous « Mouvement réduit » (M1).
- Cognitive : 4 pays x ligues x 14 à 16 clubs ; on affiche un seul niveau à la fois ; tri par niveau par défaut ; aide Gabi sur « Quel club choisir ? » (non bloquante).

## 10. Ce qu'on retire ou déplace par rapport à l'écran actuel

| Élément actuel | Décision | Raison |
|---|---|---|
| Barre haute : « RÉALITÉ ACTIVE / JEU DE BASE », « Rôle · Club », « Jeu de base », « Importer une autre réalité », « PACKS ET IDENTITÉS » | **Retirer 4 sur 5** ; garder « Identités et packs » | 5 commandes de configuration pour un choix de club ; mot « réalité » = jargon |
| Étape « 01 Réalité » (écran « Choisir sa réalité », jeu de base ou import ZIP) | **Déplacer** hors du fil, ouverte par « Identités et packs » | décision inutile pour la majorité des joueurs |
| Bandeau décoratif « Choisir son club » (photo large) | **Réduire** à un titre fin | prend 140 px de haut sur 1080 ; la grille doit monter |
| « 61 j. » et « 80,0 » sans libellé | **Libeller** | sens ambigu |
| Compteur « 5962 joueurs · 114 clubs jouables » | **Garder** en pied, une ligne | contexte non décisionnel |
| Bouton « Choisis un club » inactif sans raison (texte pâle) | **Remplacer** par bouton avec raison écrite | G3 |
| Bouton Gabi/Visite flottant sur la grille | **Garder**, hors zone de contenu | recouvre la dernière carte |
| Noms de clubs réels visibles à l'écran | **Vérifier** : en dépôt public uniquement des clubs fictifs (AGENTS.md) | voir ci-dessous |

Déviations aux motifs : propose un seul motif « filtre de liste » (E2) avec effacement, et un état vide avec action (F8).

## 11. Critères d'acceptation

- [ ] Depuis l'accueil, un club choisi et la carrière lancée en ≤ 4 interactions (Nouvelle carrière, club, Continuer, Prendre les rênes).
- [ ] Toutes les cartes club atteignables aux flèches ; sélection visible sans couleur.
- [ ] Chaque carte affiche le mot « Niveau » (ou une infobulle) et « joueurs ».
- [ ] Le bouton de validation dit pourquoi il est inactif.
- [ ] Échap revient d'une étape sans rien écrire ; aucune carrière créée tant que « Prendre les rênes » n'est pas activé.
- [ ] 1280×720 : aucune carte coupée, aucune troncature de nom de club ; 130 % de texte sans coupe.
- [ ] Aucun nom réel (club, joueur) dans les fixtures publiques.

## 12. Questions ouvertes

| Question | Propriétaire | Statut |
|---|---|---|
| Les captures montrent des noms de clubs réels : pack local actif, ou fuite dans le jeu de base ? | Léo / data | **à vérifier** |
| Budget, ambition, stade du club : quelles données existent déjà dans la carte club ? | ui-programmer | non vérifié |
| Étape 03 (« Options de carrière ») : contenu relevé dans le code (§3), rendu à capturer | ux-designer | relevé, capture à faire |
| Bloc « Défis de départ » (`creation_options/defis.gd`, « choisis-en une, ou prends le club de ton choix ») : où apparaît-il (étape Club ?) et le garder ? | Léo / ux-designer | à capturer |
| « Identités et packs » : garder ce nom ? | Léo | à trancher |

## 13. Compléments de revue (ux-review, 19/11/2026)

### Événements émis
| Action du joueur | Événement / commande |
|---|---|
| Choisir pays, ligue, club, trier, paginer, rechercher | état d'interface (`management_ui`) : aucun événement moteur |
| Changer le départ de saison (frise) | état d'interface `creation_start` ; met à jour la note de Gabi |
| Aperçu d'un club | demande d'aperçu au moteur (`club_preview`), en lecture seule |
| Prendre les rênes | commande `new_career` (club, pack, départ) ; une seule émission, bouton inactif ensuite |
| Identités et packs, Accueil, Changer de club | navigation : aucun événement moteur |

### Transitions et animations
- Changement de pays/ligue : bascule instantanée de la grille, fondu de 0,12 s ; instantané sous « Mouvement réduit » (M1).
- Étape Club vers Carrière : fondu de 0,18 s ; retour identique. Réglage « Transitions » respecté (M2).
- Aucune animation obligatoire ; aucune ne bloque la saisie.

### Contrôle d'entrée (souris + clavier ; manette hors périmètre)
- [x] Grille de clubs, onglets, pagination, recherche, tri, boutons atteignables au clavier (§7).
- [x] Sélection et validation à la souris seule.
- [x] Ordre de focus défini (§7) ; focus d'arrivée sur la première carte.
- [x] Pas de glisser, pas de limite de temps ; Échap sort sans perte.
- [x] Étape Carrière : page à défilement vertical avec suivi du focus (`follow_focus`) à petite fenêtre ; aucun contenu inatteignable au clavier.

### Localisation (français seul ; limites pour +40 %)
| Élément | Max. actuel | Prévoir |
|---|---|---|
| Nom de club sur carte | 28 caractères | 2 lignes, jamais tronqué |
| Ville | 20 caractères | 28 |
| « Niveau 80,0 » / « 61 joueurs » | 14 caractères | 20 |
| Libellé de bouton | 28 caractères (« Continuer avec [Club] » : nom compris) | 2 lignes autorisées |
| Texte « Format et enjeux » | 3 lignes visibles puis « Lire la suite » | 5 lignes |

### Critères supplémentaires
- [ ] L'étape Club s'affiche, grille comprise, ≤ 500 ms après « Nouvelle carrière » (aperçus moteur chargés en différé, emplacements d'attente visibles).
- [ ] Étape Carrière : « Prendre les rênes » inactif écrit sa raison (pack absent, commande en cours, sélection manquante).
- [ ] Rendu vérifié à 1280×720, 1920×1080, 2560×1440 et 21:9.
- [ ] Après `new_career` refusé, la sélection du club est conservée.
