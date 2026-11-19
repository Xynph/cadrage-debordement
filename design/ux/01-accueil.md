# UX Spec : Accueil (avec écran titre)

> **Statut** : En conception (brouillon autonome, rigueur `minimal`)
> **Auteur** : ux-designer (CCGS)
> **Dernière mise à jour** : 19/11/2026
> **Phase du parcours** : 1.1 Première heure, étape « Écran titre » ; retour de chaque session
> **Identifiant** : `EntryWelcome` (code : `entry_canvas.gd`, nœud `ImmersiveWelcome`)
> **Plateforme** : PC Windows, souris + clavier, 1280×720 à 2560×1440 (calque 2560×1440). Pas de manette (voir `accessibility-requirements.md` §6).
> **Palier d'accessibilité** : Standard
> **Entrées liées** : `design/player-journey.md` (écran 01), `design/ux/interaction-patterns.md` (N5, E1, F7, F9, G2), `design/accessibility-requirements.md`
> **Écrans liés** : `02-creation.md`, `03-chargement.md`, Réglages, Crédits, menu pause
> **Sans style visuel** : couleurs et polices relèvent du directeur artistique.

## 1. But

- **Joueur** : reprendre sa carrière d'un clic, ou en commencer une, sans lire.
- **Jeu** : savoir s'il existe une carrière, un profil à récupérer ou un pack manquant, et router vers Bureau (reprise), Création ou Import.
- **Émotion visée** : envie d'ambiance (stade) puis évidence du choix.

## 2. Ce qu'il doit voir en 5 secondes

1. **Principal** : le bouton de reprise (« Reprendre la carrière ») avec le nom du club et la saison, focus d'ouverture. Sans carrière : « Nouvelle carrière » prend ce rôle.
2. **Secondaires** (3) : « Nouvelle carrière », « Importer une carrière », « Paramètres ».
3. **Le reste** : « Quitter », « Crédits », « Identités et packs », aide de Gabi, accroche éditoriale.

## 3. Navigation

```
Lancement du jeu
  └── Intro (stade, animée, passable)
        └── ACCUEIL  <-- cet écran
              ├── Reprendre la carrière --> 03 Chargement --> 04 Bureau
              ├── Nouvelle carrière --> 02 Création
              ├── Importer une carrière --> fenêtre de fichier --> 03 Chargement
              ├── Paramètres, Crédits (fenêtres, retour ici)
              ├── Identités et packs --> 02 Création, étape packs
              └── Quitter (ferme l'application, aucune carrière en cours donc sans confirmation)
```

Arrivée : lancement, « Retour à l'accueil » depuis la Création ou le menu pause. Modal : non.

## 4. Wireframe 1280×720

```
+----------------------------------------------------------------------------------------------+
| [logo RUGBY LEGACY 27]  CARRIÈRE DE MANAGER                                    [Crédits (i)] |
+----------------------------------------------------------------------------------------------+
|                                                          +----------------------------------+|
|                                                          | OUVRIR LE CARNET                 ||
|   Un club. Un territoire.                                | Ton prochain chapitre            ||
|   Une saison à écrire.                                   | +------------------------------+ ||
|                                                          | | {écusson} CARRIÈRE EN COURS  | ||
|   Prends les rênes. Prépare le XV, fais grandir          | |  Alder Fen XV                | ||
|   le club et vis la saison.                              | |  Saison 2026-2027 · Div. ... | ||
|                                                          | |  · Journée 1                 | ||
|        { stade de nuit, plein fond }                      | +------------------------------+ ||
|                                                          | [● Reprendre la carrière     ->] ||
|                                                          | [  Nouvelle carrière         ->] ||
|                                                          | [  Importer une carrière     ->] ||
|                                                          | [  Paramètres ->] [ Quitter ->]  ||
|                                                          |  Identités et packs (lien discret)||
|                                                          +----------------------------------+|
+----------------------------------------------------------------------------------------------+
| Gabi · ?  (Visite : première fois seulement)                                  RUGBY LEGACY 27|
+----------------------------------------------------------------------------------------------+
```

## 5. Blocs de contenu et données exactes

| Bloc | Contenu | Source | Si absent |
|---|---|---|---|
| Marque | « RUGBY LEGACY 27 », « CARRIÈRE DE MANAGER », « Rugby à XV / Édition Windows » | constantes | — |
| Accroche | « Un club. Un territoire. Une saison à écrire. » + « Prends les rênes. Prépare le XV, fais grandir le club et vis la saison. » | constantes | — |
| Carte carrière | écusson, « CARRIÈRE EN COURS », nom du club, « Saison AAAA-AAAA · division · Journée N » (ou « Début de saison ») | profil de carrière | état « première fois » |
| Reprendre | « Reprendre la carrière » | moteur | masqué sans carrière |
| Nouvelle carrière | idem | — | toujours présent |
| Importer une carrière | idem | — | toujours présent, rang 3 |
| Paramètres, Quitter, Crédits | idem | — | toujours présents |
| Identités et packs | lien discret en pied de carte (nom à trancher, §11) | gestionnaire de packs | toujours présent |
| Aide | « Gabi · ? », « Visite » | guide | « Visite » seulement tant que jamais suivie |

## 6. Actions et raccourcis

| Entrée | Effet |
|---|---|
| Clic / Entrée sur un bouton | l'active (focus d'ouverture : « Reprendre » ou « Nouvelle carrière ») |
| Tab / Maj+Tab, flèches ↑ ↓ | parcourent le menu dans l'ordre visuel |
| Espace | active le bouton focalisé |
| Échap pendant l'intro | passe l'intro |
| Échap sur l'accueil | ne fait rien (jamais de menu pause ici, jamais de « Quitter » direct) |
| F1 | ouvre Gabi |
| Tout clic / touche pendant l'intro | passe l'intro (M3) |

Aucun raccourci chiffre : 1 à 9 n'ont pas de sens ici (les menus de la coque n'existent pas).

## 7. États

| État | Déclencheur | Ce qui change |
|---|---|---|
| Intro | lancement | stade animé plein écran, logo ; mention discrète « Espace : passer » ; première fois : avertissement photosensible d'une phrase avant l'intro |
| Menu (carrière) | carrière trouvée | carte carrière + « Reprendre » en focus |
| **Première fois** | aucune carrière | pas de carte carrière ; carte « UNE SAISON À ÉCRIRE : Choisis un club, prends les rênes et lance la première journée. » ; « Nouvelle carrière » en principal ; « Reprendre » absent |
| Chargement | profil en lecture | libellé « Ouverture du profil… », boutons inactifs avec raison en infobulle (voir 03) |
| Profil illisible | `recoveryRequired` | carte : « Le profil ne peut pas être chargé. Sa copie sera conservée avant récupération. » ; boutons « Récupérer le profil » (principal) et « Réessayer la connexion » ; confirmation avec libellé de l'action et focus sur « Annuler » |
| Pack absent | pack de création ou de carrière manquant | « Reprendre » et « Nouvelle carrière » inactifs, raison écrite sous le bouton (pas seulement en infobulle) : « Pack de création absent » + lien « Identités et packs » |
| Erreur moteur | moteur arrêté | libellé « Relancer le moteur », explication visible |

## 8. Accessibilité

- **Contraste** : carte et boutons sur photo : aplat sous le texte, 4,5:1 mesuré au pire pixel (C1, C5). Chiffres, saison et division en 14 px mini à 1080p (T1).
- **Focus** : liseré 2 px, 3:1, distinct du survol (K2). Ordre : Reprendre, Nouvelle, Importer, Paramètres, Quitter, Crédits, Gabi, Visite.
- **Mouvement** : intro fixe (image) si « Mouvement réduit » (M1) ; passable dès la première seconde (M3) ; pas de flash (M4).
- **Couleur** : bouton principal reconnaissable aussi par sa position et son focus, pas seulement par sa teinte (D1).
- **Texte non image** : l'accroche est du texte, pas une texture (E4).
- Cognitive : 4 actions + 2 secondaires, sous le seuil.

## 9. Ce qu'on retire ou déplace par rapport à l'écran actuel

| Élément actuel | Décision | Raison |
|---|---|---|
| Pastilles « Monde · 114 clubs jouables » et « 5962 joueurs au départ » | **Retirer** de l'accueil ; reprendre en pied de la Création | chiffres sans décision à prendre, 10 px, bleu/vert sur fond sombre |
| Pied « APPLICATION WINDOWS NATIVE · CARRIÈRE LOCALE » | **Retirer** | jargon technique (brief : « jamais de jargon technique ») |
| « Identités et packs » en 4e bouton du menu principal | **Déplacer** vers un lien discret (pied de carte) | action de configuration, pas un choix de parcours ; renommage à décider |
| Bouton « Visite » permanent | **Limiter** à la première fois, ensuite dans l'aide Gabi | bruit |
| Ligne « Paramètres / Quitter » en deux demi-boutons | **Garder**, mais Quitter reste dernier | alignement sur la bibliothèque (E1) |
| Destination de « Reprendre » : le code ouvre aujourd'hui **Réception** (`app._navigate("Réception")`) | **Cible : Bureau** (via 03), comme le parcours (écran 04, atterrissage) | le Bureau est la racine ; changement de comportement à valider (§11) |

Déviations aux motifs : aucune. Résout l'incohérence n°1 (Échap) pour cet écran.

## 10. Critères d'acceptation

- [ ] Au lancement avec carrière, un clic ou Entrée sur le bouton déjà focalisé ouvre le Bureau (via 03).
- [ ] Sans carrière : pas de bouton « Reprendre », « Nouvelle carrière » focalisé.
- [ ] Échap ne quitte jamais et n'ouvre aucun menu sur l'accueil.
- [ ] Texte du menu ≥ 14 px à 1920×1080 ; contraste ≥ 4,5:1 sur la photo.
- [ ] Aucune mention « fictif », « IA », « application native ».
- [ ] « Profil illisible » : aucune action destructive sans libellé précis ni focus sur « Annuler ».
- [ ] Capture à 1280×720 : aucun texte coupé, menu entièrement visible.

## 11. Questions ouvertes

| Question | Propriétaire | Statut |
|---|---|---|
| Afficher la date de dernière sauvegarde sur la carte carrière ? (donnée à confirmer dans le profil) | game-designer / ui-programmer | proposé |
| Nom du lien « Identités et packs » (« Contenu du jeu » ?) | Léo | à trancher |
| Plusieurs carrières sauvegardées : sélection de profil ? Le code relevé n'en montre qu'une. | game-designer | non vérifié |
| « Reprendre » doit-il atterrir au Bureau (cible) plutôt qu'en Réception (code actuel) ? | Léo | à trancher |

## 12. Compléments de revue (ux-review, 19/11/2026)

### Événements émis
| Action du joueur | Événement / commande |
|---|---|
| Reprendre la carrière | ouverture du profil (commande d'ouverture, nom à confirmer au code) puis navigation vers 03 |
| Nouvelle carrière, Importer, Identités et packs, Crédits, Paramètres | navigation seule : aucun événement moteur (Importer : commande d'import après choix du fichier) |
| Récupérer le profil / Réessayer la connexion | commandes de récupération et de reconnexion (noms à confirmer) |
| Quitter | fermeture de l'application ; aucun événement moteur (aucune carrière en cours) |
| F1, Visite | ouverture du guide : aucun événement moteur |

### Transitions et animations
- Intro vers menu : fondu de 0,3 s ; sous « Mouvement réduit » ou transitions « Aucune » : changement instantané (M1, M2).
- Menu vers Création, Chargement : fondu de 0,18 s (valeur du panneau d'attente) ; mêmes règles de réglage.
- Fenêtres Paramètres, Crédits : apparition en fondu de 0,15 s ; Échap les ferme.

### Contrôle d'entrée (souris + clavier ; manette hors périmètre, décision projet)
- [x] Tout le menu atteignable au clavier (Tab, flèches, Entrée, Espace) ; ordre de focus défini (§8).
- [x] Tout le menu atteignable à la souris ; cibles ≥ 32 px de haut.
- [x] Focus d'ouverture défini ; aucun piège (Échap sans effet, pas de modale hors fenêtres).
- [x] Aucune action n'exige un glisser ni une limite de temps.

### Localisation (français seul aujourd'hui ; limites pour une extension de 40 %)
| Élément | Max. actuel | Prévoir |
|---|---|---|
| Libellé de bouton du menu | 28 caractères (« Importer une carrière ») | 40 caractères, retour à la ligne autorisé |
| Nom de club sur la carte | 24 caractères | 2 lignes, jamais tronqué |
| Ligne saison/division/journée | 48 caractères | 2 lignes |
| Phrase d'accroche | 2 lignes de 34 caractères | 2 lignes de 48 |
Tout texte passe par la table de textes du jeu, pas de chaîne écrite dans le nœud.

### Critères supplémentaires
- [ ] Le menu est affiché et utilisable ≤ 500 ms après la fin de l'intro.
- [ ] Rendu vérifié à 1280×720, 1920×1080, 2560×1440 et en 21:9 sans contenu coupé.
- [ ] Aucun critère n'exige la lecture d'un autre document (seuils chiffrés ci-dessus).
