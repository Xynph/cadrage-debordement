# UX Spec : Chargement / attente

Décisions de Léo du 19/11/2026 intégrées : densité « Football Manager » (jamais sous 11 px à 1080p ; échelle d'interface 90/100/115/130 %).

## Direction artistique (choix de Léo, 20/11/2026 : « les deux, selon la durée »)

Trois présentations, choisies par la durée et le type d'attente (maquettes `apercus/03-chargement-1/2/3.png`). Plancher 12 px réels (conseil 13), couleurs et polices de `ui/charte.gd`, mouvements réduits = image fixe, jamais de petite fenêtre. Les noms de club, de stade et de division sont lus dans le modèle ; donnée absente = ligne omise.

| Présentation | Quand | Contenu | Or |
|---|---|---|---|
| **1 · Panneau sur le bureau** (`command_wait_overlay.gd`) | chargements courts (passage de jour, fin de journée, sauvegarde, avance de préparation) | panneau carré ≈ 40 % de la largeur, rayons 0, sans ombre ni dégradé, filet de tête ; cartes de date jour → lendemain ; titre ; barre indéterminée ; conseil de Gabi ou fait du club ; après 20 s « Plus long que prévu (N s)… » et « Arrêter → » | non |
| **2 · L'ovale du ballon** (`continue_progress.gd`) | « Continuer » | écran sombre plein cadre ; anneau ovale + « NN % » ; « JOUR n SUR m » ; titre « Passage au jour suivant… » ; cartes de date ; « Arrêt prévu » (plan du moteur) ; liste des jours ✓ ▸ · tirée des vraies dates ; conseil de Gabi ; « Échap : arrêter » et « Arrêter → » | oui, l'anneau seulement |
| **3 · Le stade, puis le terrain** (même fichier que 1, `photo`) | longs chargements hors semaine : ouverture du jeu, création, nouvelle saison, import, restauration, coup d'envoi | photo plein cadre (banque d'images), logo, lieu (stade du club), bandeau bas : surtitre, titre en capitales, club · division · saison, barre en segments ivoire, « En coulisses » avec « Anecdote suivante → » | non |

Règles d'honnêteté : barre indéterminée tant que le moteur ne donne aucun pourcentage (aucun n'existe aujourd'hui hors Continuer : jamais inventé, ni étapes) ; l'anneau de Continuer mesure les jours écoulés sur les jours jusqu'à l'arrêt prévu, sans arrêt prévu il n'a ni pourcentage ni liste ; « Arrêter → » n'est actif que si l'arrêt est réel (Continuer) — sur les autres commandes il est grisé avec sa raison écrite (« Arrêt impossible : le jeu termine cette opération… ») dans le panneau, et absent du chargement long (« Ne ferme pas le jeu »).

Cliquable : « Anecdote suivante → » (et Entrée) change la note ; « Arrêter → » (Continuer) arrête au jour en cours (Échap aussi) ; « Fermer → » ferme le motif d'arrêt. Rien d'autre n'a l'air cliquable : la liste des jours, les cartes de date et la barre sont du texte et du dessin.

Ce qui change par rapport au §4-§9 ci-dessous : le calendrier qui tourne, le terrain animé, les rebonds du ballon, le « ballon ovale » de la barre et le panneau arrondi à ombre disparaissent ; Continuer n'est plus une carte non bloquante mais un écran plein cadre (clics retenus, Arrêter et Échap actifs).

> **Statut** : En conception (brouillon autonome, rigueur `minimal`)
> **Auteur** : ux-designer (CCGS)
> **Dernière mise à jour** : 19/11/2026
> **Phase du parcours** : toutes (surtout 1.2 Semaine type : Continuer)
> **Identifiant** : `CommandWaitOverlay` (`ui/command_wait_overlay.gd`) + `SaveIndicator` (`ui/save_indicator.gd`)
> **Plateforme** : PC Windows, souris + clavier
> **Palier d'accessibilité** : Standard
> **Entrées liées** : `player-journey.md` (écran 03), `interaction-patterns.md` (F5, F7, F9, N5, N6), `accessibility-requirements.md` (M1, M4, S2, G4)
> **Sans style visuel** : couleurs et polices relèvent du directeur artistique.

## 1. But

- **Joueur** : comprendre que le jeu travaille, ce qu'il fait, et pouvoir l'arrêter ou sortir si ça traîne.
- **Jeu** : empêcher toute action pendant une commande moteur, sans faire croire à un plantage.
- **Émotion visée** : patience légère, même vivante, jamais d'inquiétude.

## 2. Ce qu'il doit voir en 5 secondes

1. **Principal** : une phrase qui dit ce qui se passe (ex. « Passage au jour suivant… »).
2. **Secondaires** (2) : une progression (barre ou indicateur de mouvement) ; un conseil de Gabi ou un fait du club.
3. **Le reste** : décor animé (calendrier qui tourne, terrain, ballon), mention « Échap : arrêter » quand c'est possible.

## 3. Position et modalité

Superposition (`z=100`) au-dessus de l'écran en cours, **modal** : absorbe les clics dès l'appel de la commande (même avant d'être visible), jamais de focus clavier (`FOCUS_NONE`). Pas de dismiss manuel, sauf arrêt de la progression de « Continuer » par Échap.

| Déclencheur | Message actuel | Annulable |
|---|---|---|
| Accueil : lecture du profil | « Ouverture du profil… » (message cité par 01) | non |
| Ouverture du jeu | « Ouverture du bureau du manager… » | non |
| Nouvelle carrière | « Création de la carrière… » | non |
| Import / export | « Importation de la carrière… » / « Préparation de l'export… » | non |
| Sauvegarde | « Sauvegarde de la carrière… » | non |
| Récupération | « Préservation et récupération du profil… » / « Reprise de la copie de sécurité… » | non |
| Packs | « Analyse / Installation / Application du pack d'identités… » | non |
| Coup d'envoi | « Préparation du coup d'envoi… » | non |
| Match délégué | « Simulation de la rencontre… » | non |
| Fin de journée | « Mise à jour de la journée… » | non |
| Jour suivant | « Passage au jour suivant… » | oui (barre Continuer) |
| Avant-saison | « Avance de l'avant-saison… » / « Avance de la préparation… » | oui |
| Nouvelle saison | « Préparation de la nouvelle saison… » | non |

Seuls les vrais chargements ont un panneau (décision du 16/11) ; décisions et menus restent instantanés.

## 4. Wireframe 1280×720

```
+----------------------------------------------------------------------------------------------+
|  (écran en cours, assombri)                                                                  |
|                                                                                              |
|                  +----------------------------------------------+                           |
|                  |  [calendrier qui tourne : 19 SEPT.]          |                           |
|                  |  Passage au jour suivant…                    |   <- état (annoncé)       |
|                  |  [=====>......................  38 %  ]      |   <- progression          |
|                  |  LE CONSEIL DE GABI                          |                           |
|                  |  « Regarde la fatigue avant de composer. »   |   <- 2 lignes max, 4,6 s  |
|                  |                          Échap : arrêter     |   <- seulement si annulable |
|                  +----------------------------------------------+                           |
|                                                                        [disquette sauvegarde]|
+----------------------------------------------------------------------------------------------+
```

Panneau ≈ 40 % de la largeur. Mise à l'échelle depuis un calque de 640×396.

## 5. Blocs et données

| Bloc | Contenu | Source |
|---|---|---|
| État | une phrase de `COMMAND_WAIT_MESSAGES` (vide : « Un instant… ») | contrôleur de commande, jamais écrite par le panneau |
| Progression | barre « ligne d'en-but » + pourcentage ou « étape n/m » quand le moteur la fournit (`progress_label`) ; indéterminée sinon | `continue_progress` |
| Conseil | « LE CONSEIL DE GABI » ou « EN COULISSES » (fait du club), texte ≤ 2 lignes | notes du contexte, rotation toutes les 4,6 s |
| Décor | calendrier (jour de départ vers arrivée), terrain, ballon | contexte (`date`, `flip`, `accent`) |
| Indication d'arrêt | « Échap : arrêter » | affichée seulement si annulable |
| Disquette de sauvegarde | icône 26 px, bas droite, non bloquante | `save_indicator` |

## 6. Actions et raccourcis

| Entrée | Effet |
|---|---|
| Échap | arrête la progression de « Continuer » (le jeu reste cohérent au dernier jour calculé) ; sur les autres chargements : sans effet, et l'indication d'arrêt est absente |
| Clic, autre touche | absorbés (aucun effet) |
| Survol disquette | infobulle « Sauvegarde en cours… » / « Carrière sauvegardée » |

Aucun bouton « Annuler » en usage normal. Seule exception (§7, état « Long ») : après 20 s, une commande annulable affiche un bouton « Arrêter » ; il reçoit alors le focus clavier (le panneau reste sans focus tant que ce bouton n'existe pas) et Échap fait la même chose. Les autres commandes ne deviennent annulables qu'après décision du technical-director (§11).

## 7. États

| État | Déclencheur | Comportement |
|---|---|---|
| Rapide | < 0,5 s (`COMMAND_WAIT_REVEAL_SECONDS`) | rien d'affiché (pas de flash) |
| **Gel invisible** | 0 à 0,5 s | **à traiter** : curseur « occupé » dès l'appel et bouton déclencheur en état « … » (motif manquant n°7) |
| Normal | > 0,5 s | panneau, fondu 0,18 s |
| Long | > 20 s (proposé) | l'état se précise (« Ça prend plus de temps que prévu… ») ; si annulable : bouton « Arrêter » visible ; sinon : « Ne ferme pas le jeu » |
| Fin | commande terminée | fondu 0,14 s, focus rendu à l'élément d'origine (K8) |
| Échec de commande | moteur refuse | panneau fermé, **avis** (pas seulement le pied de page) qui dit quoi faire (G3) |
| Échec de sauvegarde | écriture impossible | disquette rouge restant jusqu'à la prochaine réussite ; ajout : un clic ouvre « Sauvegardes » (action « Réessayer » ou « Choisir un autre dossier ») |
| Mouvement réduit | réglage actif | image fixe, aucun défilement du calendrier, aucun rebond ; la barre avance par paliers ; apparition et disparition du panneau instantanées (ou fondu de 100 ms au plus, M1) au lieu de 0,18 s / 0,14 s |
| Moteur arrêté | arrêt du moteur | libellé « Relancer le moteur », jamais de panneau infini |

## 8. Accessibilité

- Phrase d'état annoncée poliment (`LIVE_POLITE`) : maintenu (existant). Chaque nouvelle phrase est une nouvelle annonce ; le pourcentage n'est annoncé que par paliers de 25 %.
- Texte d'état ≥ 16 px à 1920 (T2 par analogie), conseil ≥ 13 px, **`progress_label` actuellement à 11 px : à passer à 12** (T1, jamais sous 11 px).
- Contraste panneau : texte ≥ 4,5:1 sur fond de panneau, pas sur la capture assombrie (C5).
- Pas de flash, pas de rebond rapide (M4) ; décor optionnel sous « Mouvement réduit » (M1).
- Information jamais portée par le décor seul : la phrase et la barre suffisent (D6).
- Le conseil de Gabi reste consultable ailleurs (S2).
- Aucun piège de focus : le panneau n'a pas de focus ; Échap documenté seulement quand il agit.

## 9. Ce qu'on retire ou déplace

| Élément actuel | Décision | Raison |
|---|---|---|
| Interface gelée avant l'apparition du panneau (0,5 s) | **Ajouter** curseur occupé et bouton « … » | gel sans retour (F7) |
| `progress_label` à 11 px | **Agrandir** | sous le plancher (T1) |
| Échap non annoncé | **Annoncer** « Échap : arrêter » quand actif | pas de sortie lisible |
| Disquette sans action en cas d'échec | **Ajouter** clic vers Sauvegardes | F5 : « où aller ? » |
| Sauvegarde annoncée à 3 endroits (rail, pied, disquette) | **Unifier** : disquette seule pendant l'écriture, le pied pour la dernière sauvegarde | cohérence |
| Photo plein écran (`chargement-0N`) pour les longs chargements | **Garder** sous aplat de lisibilité | ambiance |

## 10. Critères d'acceptation

- [ ] Une commande < 0,5 s n'affiche aucun panneau ; elle montre un curseur occupé.
- [ ] Une commande > 0,5 s montre une phrase d'état conforme au tableau 3.
- [ ] « Échap : arrêter » n'apparaît que si Échap arrête effectivement la commande.
- [ ] Après 20 s sans fin, un message et une sortie (Arrêter ou consigne) sont visibles.
- [ ] Sous « Mouvement réduit », aucun élément du panneau ne bouge sauf la barre par paliers.
- [ ] Tout échec laisse un avis écrit, jamais un panneau qui disparaît sans explication.
- [ ] À la fin, le focus clavier retrouve son élément d'origine.
- [ ] Aucun texte < 11 px, `progress_label` ≥ 12 px à 1080p.

## 11. Questions ouvertes

| Question | Propriétaire | Statut |
|---|---|---|
| Quelles autres commandes peuvent être arrêtées proprement (nouvelle saison, simulation) ? | technical-director | à trancher |
| Seuil « long » à 20 s : mesure sur machine modeste | ui-programmer | à mesurer |
| Le moteur fournit-il un pourcentage fiable pour toutes les commandes ? | ui-programmer | non vérifié |

## 12. Compléments de revue (ux-review, 19/11/2026)

### Événements émis
| Action du joueur | Événement / commande |
|---|---|
| Échap pendant « Continuer » (ou bouton « Arrêter ») | demande d'arrêt de la progression (`request_stop`, `main.gd`) ; le jeu reste au dernier jour calculé |
| Clic ou touche pendant l'attente | aucun (absorbé) |
| Clic sur la disquette en échec | ouverture de « Sauvegardes » : navigation, aucun événement moteur |
| Survol de la disquette | aucun |
Le panneau n'émet aucune commande de jeu : il affiche l'état d'une commande émise ailleurs (état de la commande = propriétaire du contrôleur de commande).

### Contrôle d'entrée (souris + clavier ; manette hors périmètre)
- [x] Aucune interaction requise en usage normal ; Échap documenté seulement quand il agit.
- [x] « Arrêter » (état Long) atteignable à la souris et au clavier ; focus rendu à l'élément d'origine à la fin (K8).
- [x] Aucune limite de temps imposée au joueur ; aucun glisser.

### Localisation (français seul ; limites pour +40 %)
| Élément | Max. actuel | Prévoir |
|---|---|---|
| Phrase d'état | 40 caractères | 56, 2 lignes autorisées |
| Conseil de Gabi / fait du club | 2 lignes de 44 caractères | 2 lignes de 62, ou 3 lignes en réduisant la durée de rotation à 6 s |
| `progress_label` (« étape n/m ») | 14 caractères | 20 |
| « Échap : arrêter » / « Arrêter » | 16 caractères | 24 |

### Critères supplémentaires
- [ ] Le panneau est affiché ≤ 500 ms après l'appel de la commande (seuil `COMMAND_WAIT_REVEAL_SECONDS`) et son fond rend le texte à ≥ 4,5:1.
- [ ] Rendu vérifié à 1280×720, 1920×1080, 2560×1440 et 21:9 : panneau centré, aucun texte coupé, y compris à 130 % de taille de texte.
- [ ] Sous « Transitions : Aucune », le panneau apparaît et disparaît sans fondu.
