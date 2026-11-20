# UX Spec : Bureau

Décisions de Léo du 19/11/2026 intégrées : densité « Football Manager » (corps ~13 px, tableaux 12-13 px, en-têtes 11-12 px, jamais sous 11 px à 1080p ; lignes de tableau 24-26 px ; échelle d'interface 90/100/115/130 %) ; règle unique d'Échap (ferme la fenêtre, sinon retour de fiche/sous-écran, sinon menu pause) et bouton « Menu » visible dans la coque.

## Choix de Léo, revue DA du 19/11/2026 (intégré dans `office_canvas.gd`)

**Variante 1 · Affiche et Gabi** (maquette `04-bureau-1.png`). Emprunts : le **face-à-face chiffré** de la variante 3
(classement, 5 derniers, bilan, différence de points des deux clubs du prochain match, uniquement des données connues) et
**« Prochains matchs » dans la colonne de Gabi** (3 matchs).
- Gauche : affiche du prochain match (bandeau d'illustration voilé ≤ 160 px, « PROCHAIN MATCH · JOURNÉE · DOMICILE » et compte à rebours),
  « Préparer le match » (bouton ivoire plein, l'or reste à Continuer), « Vérifier les 23 → » ; puis « Tes trois priorités »
  (avec « Objectif du conseil : … » ou « Aucun objectif fixé ») et « État du groupe » ; dessous Classement (6 lignes), Courrier, Profil à suivre.
- Droite : colonne de Gabi (« Ta semaine, vue par Gabi », Prochains matchs, buste 160-200 px et bulle panneau-2 + filet incliné).
- **Tout ouvre quelque chose** : priorité → écran concerné ; ligne du classement → fiche du club (notre club : écran Club) ;
  message du courrier → la lettre en Réception ; match → avant-match (le prochain) ou calendrier du jour ; compteurs
  disponibles / blessés → Effectif (blessés filtrés) ; nom d'un blessé ou profil à suivre → fiche du joueur, mini-fiche au survol ;
  « Suivre le conseil → » → Composition (rien ne change sans validation).
- Aucune fenêtre : tout clic change d'écran. Aucune couleur or hors Continuer ; couleurs du club pour le liseré et le nom du club.
- Écran étroit (< 1600 px de large) : la composition compacte historique (`office.gd`) reste, hors de ce chantier.

> **Statut** : En conception (brouillon autonome, rigueur `minimal`)
> **Auteur** : ux-designer (CCGS)
> **Dernière mise à jour** : 19/11/2026
> **Phase du parcours** : 1.1 (premier bureau), 1.2 Semaine type (centre de la boucle), 1.4 Fin de saison
> **Identifiant** : `OfficeCanvas` (`ui/immersive08/office_canvas.gd`, dans la coque `shell.gd`)
> **Plateforme** : PC Windows, souris + clavier, 1280×720 à 2560×1440
> **Palier d'accessibilité** : Standard
> **Entrées liées** : `player-journey.md` (écran 04, friction n°1), `interaction-patterns.md` (N1, N3, N5, N6, E1, F2, F3, F4, G1), `accessibility-requirements.md` (T1, C1, C5, D6, K8, M1, S2)
> **Écrans liés** : `05-reception.md`, Effectif, Composition, Préparation, Calendrier, Classements, Recrutement
> **Sans style visuel** : couleurs et polices relèvent du directeur artistique (bureau « Carnet du club » validé par Léo ; v4 rejeté pour surcharge).

## 1. But

- **Joueur** : savoir en 5 s où en est la semaine et lancer l'action suivante, sans fouiller.
- **Jeu** : router vers Préparer / Composition / Réception selon l'urgence ; rendre visibles l'échéance et la conséquence.
- **Émotion visée** : maîtrise tranquille. Une seule chose pressante ; le reste attend sans angoisse.

## 2. Ce qu'il doit voir en 5 secondes

1. **Principal (1)** : le prochain match (adversaire, jour, lieu) et le bouton unique « Préparer le match ».
2. **Secondaires (3)** : « Tes trois priorités » ; l'avis de Gabi ; l'état du groupe (disponibles, blessés, condition).
3. **Le reste** : classement court, courrier (aperçu), frise des prochains matchs, profil à suivre (déplacé, voir §9).

## 3. Navigation

```
Barre latérale (Réception 1 · Bureau 2 · Effectif 3 · Tactique 4 · Entraînement 5 · Recrutement 6 · Club 7 · Finances 8 · Compétitions 9 · Formation · Sélections)
  └── BUREAU  <-- cet écran (racine ; atterrissage après chargement et après l'après-match)
        ├── Préparer le match  --> Préparation / Composition
        ├── Priorité n  --> écran concerné
        ├── Consulter le groupe --> Effectif
        ├── Classement complet --> Classements
        ├── Courrier --> Réception
        ├── Tout le calendrier --> Calendrier
        └── Suivre le conseil --> Composition (changement présélectionné)
```

Modal : non. Écran racine : Échap ouvre le menu pause (décision de Léo du 19/11/2026, règle unique de `interaction-patterns.md` ; on l'**annonce** dans le pied : « Échap : menu »). Le menu est aussi ouvert par le bouton « Menu » de la coque (écusson du club en haut du rail ou bouton de la barre haute).

## 4. Wireframe 1280×720

```
+------+-------------------------------------------------------------------------------------+
|Logo  | <- ->  [Rechercher... Ctrl K]           [19 SEPT. 2026]            [Continuer ->]   |
|Club  +-------------------------------------------------------------------------------------+
|      | LE BUREAU · Ta semaine commence ici.                                               |
|Récep.| +-------------------------------------------------+ +-----------------------------+ |
|Bureau| | PROCHAIN MATCH  Journée 1 · EXTÉRIEUR            | | TA SEMAINE, VUE PAR GABI    | |
|Effec.| |  {écu} MEADOWBRIDGE ROVERS  vs  {écu} ALDER FEN | |  Match : ...                | |
|Tacti.| |  19/09/2026 · 17:00 · Division d'accession...   | |  Le groupe : ...            | |
|Entra.| |  Riverbank Field · Feuille complète             | |  L'alerte : ...             | |
|Recru.| |  [● PRÉPARER LE MATCH ->]  [Vérifier les 23]    | |  Mon conseil : ...          | |
|Club  | +-------------------------------------------------+ |  [Suivre le conseil ->]     | |
|Fin.  | +------------------------------+ +----------------+ |        {Gabi en pied}       | |
|Comp. | | TES TROIS PRIORITÉS          | | ÉTAT DU GROUPE | |                             | |
|Form. | | 1 Préparer le match du jour ->| | 40 dispo · 0 bl| |                             | |
|Sél.  | | 2 Anticiper 1 absence ... ->  | | Condition 100 %| |                             | |
|      | | 3 Préparer 10 échéances ... ->| | Moral 81/100   | |                             | |
|      | +------------------------------+ | Confiance 94   | |                             | |
|Réglg.| +------------------------------+ +----------------+ +-----------------------------+ |
|Sauv. | | Classement (extrait) | Courrier (3 derniers)      | Prochains matchs (3) -> Tout |
+------+-------------------------------------------------------------------------------------+
| Sauvegarde auto · dernière 19/09        Espace Suite · 1-9 Menus · Échap Menu · Ctrl F · F1 |
+---------------------------------------------------------------------------------------------+
```

Nombre de blocs : **7** = 4 cartes (Prochain match, Tes trois priorités, État du groupe, Gabi) + un bandeau bas de 3 aperçus d'une ligne (Classement, Courrier, Prochains matchs) ; contre 9 cartes aujourd'hui, plus 3 pastilles en haut.

## 5. Blocs de contenu et données exactes

| Bloc | Données | Source / remarque |
|---|---|---|
| Titre | « LE BUREAU », « Ta semaine commence ici. » | constante |
| **Prochain match** | adversaire (nom, « Pas encore classé · 0 pts » ou rang + points), journée, domicile/extérieur (mot, pas seulement icône), date `JJ/MM/AAAA · HH:MM (heure locale)`, compétition, stade, état de la feuille (« Feuille complète » / « À compléter · n postes »), photo du stade | calendrier + composition |
| Boutons du match | « Préparer le match » (principal), « Vérifier les 23 » (secondaire) | une seule route principale |
| **Tes trois priorités** | 3 lignes : numéro, titre court, échéance (« Aujourd'hui », « avant le 21/09 »), 1 ligne de détail, flèche | générées par le moteur, jamais plus de 3 ; ordre = urgence |
| Liens bas de carte | « Entraînement », « Mon carnet personnel » | **retirés** (déjà dans le rail) |
| **Objectif du conseil** | une ligne sous le titre de la carte « Tes trois priorités » : « Objectif du conseil : [texte court] » ; absent : « Aucun objectif fixé » | promis par le brief (première minute) et par la fiche 02 (« Ta feuille de route ») ; donnée de l'objectif de saison du conseil, propriétaire : moteur (club) ; existence sous cette forme à confirmer (§11) |
| **Gabi** | 4 notes courtes : Prochain match, Le groupe, L'alerte, Mon conseil ; « Suivre le conseil » ; visage en pied | notes ≤ 2 lignes ; source : guide de Gabi (`coach_guide`) alimenté par le moteur, jamais écrit par l'écran ; note absente : « Rien à signaler cette semaine. » ; l'action ouvre l'écran concerné sans rien changer sans validation |
| **État du groupe** | `40 disponibles` · `0 blessés` · condition physique % avec barre · confiance du conseil `94 / 100` · moral du vestiaire `81 / 100` · alerte physique (texte) · « Consulter le groupe » | chaque barre porte **sa valeur chiffrée** et un repère de seuil (D6) |
| Classement (extrait) | rang, club, J, diff., pts : 3 lignes (celle du joueur et ses voisines) + forme V/N/D avec lettre ; « Classement complet » | début de saison : « Début de saison : aucun match joué » |
| Courrier | 3 derniers courriers (catégorie, titre), compte « n non lus » ; « Courrier » | cohérent avec le badge du rail |
| Prochains matchs | 3 matchs : date, heure, adversaire, **Domicile / Extérieur** (mot), compétition·journée ; « Tout le calendrier » | 5 aujourd'hui → 3 |

## 6. Actions et raccourcis

| Entrée | Effet |
|---|---|
| Clic / Entrée « Préparer le match » | ouvre Préparation (dossier adverse) ; Continuer reste séparé |
| Clic ligne de priorité | ouvre l'écran qui la traite |
| Espace | ouvre le prochain message non lu ; sinon active Continuer (N5) |
| 1 à 9 | menus de gauche (à afficher en pastille dans le rail, incohérence n°11) |
| Ctrl K / Ctrl F | accès rapide |
| Ctrl J | jour suivant (aujourd'hui seulement dans une infobulle ; à afficher dans le pied) |
| F1 | Gabi |
| Échap | menu pause (annoncé « Échap Menu » au pied) |
| Alt ← / → | historique |
| Tab | rail, barre haute, Prochain match, priorités, Gabi, groupe, classement, courrier, frise |

Plus de bouton « Préparer » **dans la barre haute** quand le Bureau est affiché : le bouton de barre « Continuer » suffit (voir §9).

## 7. États

| État | Déclencheur | Ce qui change |
|---|---|---|
| **Première semaine** | carrière créée, aucun match joué | seuls Prochain match + Gabi + État du groupe affichés pleins ; priorités, classement, courrier, frise réduits à une ligne avec « Voir plus » ; Gabi se présente en 2 phrases, sans visite bloquante |
| Jour de match | match aujourd'hui | Prochain match en tête avec « AUJOURD'HUI » écrit ; bouton principal = « Préparer le match » puis « Jouer le match » ; Continuer = « Aller au match » |
| Semaine normale | match dans 2 à 7 jours | compte à rebours « dans n jours » |
| Alerte groupe | blessés, fatigués, absences internationales | priorité n°1 = alerte, liste de noms dans l'État du groupe, icône **et** mot (« blessé grave ») |
| Après-match | match joué, « Pourquoi » à lire | priorité n°1 : « Lire le Pourquoi » ; classement mis à jour |
| Fin de saison | dernière journée jouée | priorité n°1 : « Bilan de la saison » ; priorité n°2 : file « Contrats à trancher (n) » en une seule ligne |
| Pas de match | semaine de repos | « Pas de match cette semaine » ; bouton principal = Continuer ; priorité « Entraînement » |
| Vide (classement) | avant la 1re journée | « Début de saison : aucun match joué. » (pas de 0 pts alignés) |
| Courrier vide | aucun message | « Aucun nouveau message. » + « Ouvrir la boîte » |
| Erreur moteur | moteur arrêté | Continuer = « Relancer le moteur », explication visible dans la carte Prochain match |
| Chargement | commande longue | écran 03 par-dessus |

## 8. Accessibilité

- **Texte** : corps ~13 px à 1080p (aujourd'hui 9 px, T1) ; étiquettes secondaires en capitales (« PROCHAIN MATCH », « LE GROUPE ») 11-12 px mais jamais seul porteur de sens ; pied de page ≥ 11 px, contraste ≥ 4,5:1 (C1).
- **Couleur** : domicile/extérieur par mot + icône ; barres de condition, confiance, moral avec chiffre et repère de seuil (D6) ; forme V/N/D par lettre et forme (D2) ; « Hors groupe » reste en mot (D1).
- **Texte sur photo** : adversaire et stade sur la photo : aplat derrière (C5).
- **Focus** : ordre visuel, liseré 2 px ; focus d'arrivée sur « Préparer le match » (K8) ; carte entière atteignable par Tab.
- **Mouvement** : Gabi en pied sans balancement sous « Mouvement réduit » (M5).
- **Gabi** : texte toujours lisible, sans lecture audio obligatoire (S2).
- **Cognitif** : 7 blocs (dont 3 aperçus d'une ligne), 3 priorités dans un seul bloc : dans 7±2 ; le principal est unique.
- **Cibles** : lignes de priorité 24-26 px de haut (K6, comme Football Manager).

## 9. Ce qu'on retire ou déplace par rapport à l'écran actuel

| Élément actuel | Décision | Raison |
|---|---|---|
| 3 pastilles en haut à droite (« Pas classé · 0 pts », « 40 disponibles », « 0 blessé ») | **Retirer** | répétées dans Classement et État du groupe |
| Trois routes vers la même action : bouton de barre « Préparer », « Préparer le match », priorité n°1 « Préparer le match du jour » | **Fusionner** : un seul bouton principal dans la carte ; priorité n°1 ne répète pas l'action, elle dit pourquoi | une chose principale |
| Liens « Entraînement » et « Mon carnet personnel » en pied de la carte priorités | **Retirer** | rail et accès rapide les couvrent |
| « Le profil à suivre » (joueur, offre possible, salaire) | **Déplacer** vers Recrutement (rappel de 1 ligne dans Gabi si pertinent) | secondaire, décision de recrutement, non liée au match |
| Carte « Dans ton bureau » (courrier) à 3 titres longs | **Réduire** à un compteur + 3 titres ; ou fondre dans la ligne du bas | doublon avec le badge du rail |
| Classement à 6 lignes + forme | **Réduire** à 3 lignes autour du club | secondaire |
| Frise de 5 matchs + « Préparer la suite du club » | **Réduire** à 3 matchs ; « Préparer la suite du club » → priorité si nécessaire | trop de boutons |
| Visage de Gabi dans la barre haute (hors Bureau) | **Inchangé** | cohérence |
| Étiquettes en capitales grises très petites | **Agrandir**, mettre en casse normale | T1, C1 |
| Pied de page « Espace Suite · 1 à 9 Menus … » gris sur gris | **Contraste**, ajout « Ctrl J » et « Échap Menu » | C1, incohérences 1 et 11 |

Déviation aux motifs : N6 (Continuer) : on propose de remplacer les libellés en majuscules avec flèche par une phrase simple ; « Suivre le conseil » ouvre l'écran avec le changement présélectionné sans l'appliquer (motif E5, deux temps).

## 10. Critères d'acceptation

- [ ] Prochain match + un bouton principal visibles sans défilement à 1280×720.
- [ ] Au plus 4 cartes, 1 bandeau de 3 aperçus et 3 priorités ; aucune pastille de résumé en haut.
- [ ] L'objectif du conseil est lisible sur le Bureau, sans clic (« Objectif du conseil : … » ou « Aucun objectif fixé »).
- [ ] Une seule action « Préparer » visible (pas de doublon avec la barre haute).
- [ ] Domicile/extérieur lisibles sans icône ni couleur ; V/N/D avec lettres.
- [ ] Chaque jauge affiche sa valeur numérique ; texte ~13 px à 1920×1080.
- [ ] État « première semaine » : trois cartes pleines maximum.
- [ ] Focus d'arrivée sur « Préparer le match » ; Tab suit l'ordre visuel ; Échap pas de piège.
- [ ] Les 11 états du §7 rendent sans débordement.

## 11. Questions ouvertes

| Question | Propriétaire | Statut |
|---|---|---|
| Comment le moteur choisit-il les 3 priorités et leur ordre ? À documenter pour garantir « l'urgent d'abord » | game-designer | non vérifié |
| « Suivre le conseil » applique-t-il le changement aujourd'hui ? | ui-programmer | non vérifié |
| État « première semaine » : validé avec la direction artistique ? | art-director / Léo | à valider |
| L'objectif du conseil est-il une donnée du moteur affichable en une ligne ? | game-designer / ui-programmer | non vérifié |
| Corps de texte : densité du Bureau | Léo | **Résolue le 19/11/2026** : densité « Football Manager », corps ~13 px à 1080p, échelle d'interface 90/100/115/130 % |
| Échap sur écran racine : pause ou rien ? | Léo | **Résolue le 19/11/2026** : Échap ouvre le menu pause ; bouton « Menu » visible dans la coque en plus |

## 12. Compléments de revue (ux-review, 19/11/2026)

### Événements émis
| Action du joueur | Événement / commande |
|---|---|
| Préparer le match, Vérifier les 23, lignes de priorité, Consulter le groupe, Classement complet, Courrier, Tout le calendrier | navigation : aucun événement moteur |
| Continuer / Aller au match | commande d'avance du temps (`continue`, nom à confirmer) ; panneau d'attente 03 |
| Ctrl J (jour suivant) | commande « +1 jour » |
| Suivre le conseil | navigation vers Composition avec changement **présélectionné** ; aucune commande tant que le joueur ne valide pas (la validation émet `set_lineup`) |
| Relancer le moteur | commande de relance du moteur |
| Échap | menu pause : aucun événement moteur |

### Transitions et animations
- Entrée dans le Bureau : fondu de contenu de 0,18 s ; instantané sous « Mouvement réduit » ou « Transitions : Aucune » (M1, M2).
- Changement d'état (jour de match, alerte) : aucun mouvement ; les barres changent de valeur sans animation.
- Gabi en pied : balancement lent seulement hors « Mouvement réduit » (M5).

### Contrôle d'entrée (souris + clavier ; manette hors périmètre)
- [x] Tout atteignable au clavier : ordre de Tab défini (§6) ; raccourcis 1 à 9, Espace, Ctrl J, Ctrl K/F, F1, Alt ← →.
- [x] Tout atteignable à la souris ; lignes de priorité 24-26 px.
- [x] Focus d'arrivée sur « Préparer le match » (K8) ; carte entière atteignable.
- [x] Aucun glisser ; aucune limite de temps.
- [x] Échap : menu pause, annoncé au pied (décision de Léo du 19/11/2026).

### Localisation (français seul ; limites pour +40 %)
| Élément | Max. actuel | Prévoir |
|---|---|---|
| Nom d'adversaire | 28 caractères | 2 lignes |
| Titre de priorité | 40 caractères | 56 |
| Détail de priorité | 1 ligne de 60 caractères | 2 lignes |
| Note de Gabi | 2 lignes de 60 caractères | 3 lignes |
| Bouton principal | 20 caractères (« Préparer le match ») | 28 |
| Libellé de Continuer | 26 caractères (« Relancer le moteur ») | 36 |
| Objectif du conseil | 70 caractères | 98, 2 lignes |

### Critères supplémentaires
- [ ] Le Bureau est affiché et utilisable ≤ 500 ms après la fin du chargement (aperçus de photo différés).
- [ ] Rendu vérifié à 1280×720, 1920×1080, 2560×1440 et 21:9, y compris à 130 % de taille de texte, sans contenu coupé.
- [ ] Les 11 états du §7 sont chacun capturables sans consulter un autre document (jeu d'essai nommé par état).
