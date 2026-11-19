# Fiche UX 12 — Avant-match

Décisions de Léo du 19/11/2026 intégrées : densité « Football Manager » (corps ~13 px, tableaux 12-13 px, en-têtes 11-12 px, jamais sous 11 px à 1080p ; lignes de tableau 24-26 px ; échelle d'interface 90/100/115/130 %) ; règle unique d'Échap (ferme la fenêtre, sinon retour de fiche/sous-écran, sinon menu pause) et bouton « Menu » visible dans la coque.

> **Template**: UX Spec
> **Statut** : proposé (ux-designer CCGS, 19/11/2026, mode autonome, rigueur `minimal`)
> **Écran** : `Match` avant le coup d'envoi (route « Match », ouverture du match ; maquette « Retenue » validée par Léo le 17/11/2026 : on **resserre**, on ne refond pas) · carrière Monde · souris + clavier
> **Phases du parcours** : jour de match (premier écran), première heure (premier match)
> **Palier d'accessibilité** : Standard (C5 texte sur image, M3 tunnel passable, D1)
> **Liés** : fiche 10 (composition), fiche 11 (préparation), `design/ux/interaction-patterns.md` (N5, N6, W1, F7, F9), `design/player-journey.md` §1.3, décision de Léo du 16/11 (« pas de sortie en plein match : arrêt forcé = reprise avant le match »)
> **Hors périmètre** : le match en direct (13), l'entracte (14), le tunnel animé du direct (non relevé ici, voir §14)

## 1. But

- **Joueur** : **savoir que tout est prêt** et lancer le match (ou le déléguer), avec une dernière vérification de feuille, de météo et d'adversaire.
- **Jeu** : poser le contexte (qui, où, quand, conditions) pour que le match 3D et le « Pourquoi » aient un point de départ lisible.
- **Dans les 5 secondes** : (1) **contre qui, où, quand** ; (2) **suis-je prêt ?** (feuille, condition) ; (3) **le bouton « Coup d'envoi »**.

## 2. Contexte d'arrivée

| Question | Réponse |
|---|---|
| Venu de | Préparation (« Aller au jour de match »), barre haute (« Jour de match »), Bureau, rail Tactique › Match |
| État d'esprit | Tension, anticipation ; premier match : excitation + doute |
| Charge cognitive | Faible : tout est déjà préparé ; il s'agit de confirmer |
| Veut | Lancer, ou corriger une dernière chose |
| Craint | Découvrir un blessé ou une feuille invalide trop tard ; lancer sans le vouloir |

**Cible émotionnelle** : « Je suis prêt, j'ai envie de siffler le coup d'envoi. »

## 3. Navigation

```
Carrière Monde › Tactique (chapitre)
  └── Match (avant-match)                  ← cet écran
        ├── Composition (10)               ← « Vérifier la feuille »
        ├── Plan de jeu (10)               ← « Ouvrir le plan de jeu »
        ├── Préparation › Dossier adverse (11)
        ├── Déléguer le match              ← fenêtre de confirmation
        └── Match en direct (13)           ← COUP D'ENVOI
```

- **Modalité** : écran plein ; la délégation est une fenêtre.
- **Entrées** : Préparation, barre haute, Bureau, rail, **reprise après arrêt forcé** (si le jeu est fermé en plein match, on revient ici, décision du 16/11).
- **Sorties** : Match en direct (coup d'envoi) ; résultat direct (délégation, vers l'après-match) ; Composition, Plan de jeu, Dossier adverse ; autre menu du rail (le match n'est pas lancé, rien n'est perdu).
- **Échap** : ferme la fenêtre ; sinon retour à l'écran précédent ; sans historique, ouvre le menu pause (règle unique de Léo, 19/11/2026). Le match n'est pas lancé : la pause du match n'existe pas ici.

## 4. Hiérarchie

1. **Principal** : le bouton « Coup d'envoi » et l'affiche du match (clubs, heure, lieu).
2. **Secondaires** : « Prêt ? » (état de la feuille et de la condition), conditions du match (météo, arbitre), danger de l'adversaire.
3. **Reste** : Déléguer le match, mot de Gabi (3 clés), confrontations (bilan en pastille d'affiche), liens vers Composition / Plan / Dossier.

## 5. Wireframe 1280×720

```
┌────┬──────────────────────────────────────────────────────────────────────────────────────┐
│    │ ● Feuille validée · condition 100 %          sam. 19/09/2026   [Déléguer le match] [COUP D'ENVOI →]│
│ Nav│ ┌ affiche (voile sombre derrière le texte) ──────────────────────────────────────────┐ │
│124 │ │ DIVISION D'ACCESSION ANGLAISE · JOURNÉE 1 · RIVERBANK FIELD                          │ │
│ px │ │ DOMICILE                17:00 sam. 19 sept.                  TON ÉQUIPE · EXTÉRIEUR  │ │
│    │ │ MEADOWBRIDGE ROVERS [écu]  PREMIÈRE CONFRONTATION  [écu] ALDER FEN XV                │ │
│    │ │ Classement : ouvert après la J1 · forme (V)(N)(D)…                  Classement …    │ │
│    │ │                          ☀ Sec · pas de vent                                         │ │
│    │ └──────────────────────────────────────────────────────────────────────────────────────┘ │
│    │ ┌ Ta feuille ──────────────────┐ ┌ Conditions du match ────────────────────────────────┐│
│    │ │ 23 / 23 · condition 100 %     │ │ ☀ Sec, pelouse souple · pas de vent                  ││
│    │ │ ▮▮▮▮▮▮▮▮▮▮▮▮▮▮▮ 1…15 |80 %    │ │ Arbitre : Isla Strachan · Rucks souple · Hors-jeu    ││
│    │ │ Aucun blessé · titulaires ≥ 80│ │ pointilleux · Cartons souple                         ││
│    │ │ [Vérifier la feuille →]       │ │ « Terrain sec : le jeu technique s'exprime. »        ││
│    │ └───────────────────────────────┘ └─────────────────────────────────────────────────────┘│
│    │ ┌ L'adversaire ────────────────┐ ┌ Le mot de Gabi ─────────────────────────────────────┐│
│    │ │ Plan probable : jouer au près │ │ 1 Ils vont jouer au près · 2 Gagne les collisions    ││
│    │ │ Leurs avants : point fort     │ │ 3 Réussis les 20 premières minutes                    ││
│    │ │ 10 Ireland · 9 Yarwood        │ │ [Ouvrir le plan de jeu] [Préparer la causerie]       ││
│    │ │ [Dossier adverse →]           │ │                                                       ││
│    │ └───────────────────────────────┘ └──────────────────────────────────────────────────────┘│
├────┴──┬──────────────────────────────────────────────────────────────────────────────────────┤
│ pied  │ Entrée ou Espace sur le bouton · Échap Retour · F1 Aide                           │
└───────┴──────────────────────────────────────────────────────────────────────────────────────┘
```

| Zone | Contenu | Taille | Défile ? | Débordement |
|---|---|---|---|---|
| Bandeau | statut de feuille, date, Déléguer, Coup d'envoi | 100 % × 8 % | Non | libellé de statut sur une ligne ; date seule en infobulle si étroit |
| Affiche | compétition, journée, lieu, clubs, heure, météo | 100 % × 36 % | Non | noms de clubs sur 2 lignes max, jamais tronqués |
| Quatre tuiles | Ta feuille, Conditions, L'adversaire, Gabi | 100 % × 51 % (2×2) | Non | texte de tuile ≤ 3 lignes ; « + » pour le reste |
| Pied | raccourcis | 100 % × 5 % | Non | — |

**Focus à l'ouverture** : bouton « Coup d'envoi » (action principale) ; si la feuille est invalide : « Vérifier la feuille » (le bouton principal est grisé).

## 6. Blocs et données

### 6.1 Bandeau

| Élément | Contenu | États |
|---|---|---|
| Statut | « Feuille validée » · « Feuille incomplète » · « Feuille à vérifier (2 avertissements) » : icône + mot | voir §8 |
| Date | « sam. 19 sept. 2026 » | — |
| Déléguer le match | secondaire ; fenêtre de confirmation (6.5) | grisé comme le Coup d'envoi |
| Coup d'envoi | seul bouton plein ; le libellé suit celui du bouton de lancement du direct (« Coup d'envoi », « Jouer à 22 »…) | grisé avec la **raison écrite** à côté (« Corrige la feuille : il manque un talonneur ») |

### 6.2 Affiche

Compétition, journée, stade (lieu en toutes lettres) ; Domicile / Extérieur et **« Ton équipe »** écrit (la position gauche/droite ne suffit pas) ; noms, écussons, classement (rang et points, ou « Classement ouvert après la 1re journée »), forme des 5 derniers matchs (pastilles V/N/D avec lettre et forme, F6), heure, date, **bilan des confrontations** (« Première confrontation » ou « 3 V · 1 N · 1 D »), météo (icône + mot + vent). Un **voile** garantit le contraste du texte posé sur la photo (C5).
Retiré : « Pas encore de match cette saison » en petit gris sous chaque club : remplacé par la forme ou, absente, par rien.

### 6.3 Tuile « Ta feuille » (remplace « Ta feuille » + « Forces en présence »)

- « 23 / 23 · feuille complète », condition moyenne du XV en pourcentage ;
- 15 repères numérotés avec **valeur de condition** et repère à 80 % ;
- une ligne en mots : « Aucun blessé · tous les titulaires à 80 % ou plus » ou la liste des problèmes (« 2 titulaires sous 80 % : … ») ;
- « Vérifier la feuille → » (Composition).
La tuile « Forces en présence » (vide jusqu'à la 1re journée, doublon du rapport de force de la Préparation) est **retirée** ; un lien « Rapport de force » vit dans la tuile Adversaire.

### 6.4 Autres tuiles

| Tuile | Contenu | Absence |
|---|---|---|
| Conditions du match | météo (mot + icône), pelouse, vent (flèche + force, mot), conséquence en une phrase, arbitre (nom) et ses 4 tendances **en mots** (souple / équilibré / pointilleux) avec petits repères | « Météo annoncée la veille » |
| L'adversaire | plan probable (mot « Probable »), point fort en une phrase, 2 joueurs à surveiller (n°, nom, rôle), liens « Dossier adverse → » et « Rapport de force » | « Pas encore de statistiques cette saison : plan et XV probables. » |
| Le mot de Gabi | 3 clés numérotées (1, 2, 3 + titre + précision : pas de ✓, qui dirait « fait »), « Ouvrir le plan de jeu », « Préparer la causerie » (→ Vestiaire) ; transcription toujours lisible (S2) | « Gabi n'a pas de clés pour ce match. » |

La tuile « Confrontations directes » est retirée : son contenu (« Première confrontation » / bilan) est déjà dans l'affiche.

### 6.5 Déléguer le match (fenêtre)

Titre : « Déléguer le match au staff ? ». Corps : « Tu ne verras pas le match. Le résultat sera calculé avec ta feuille et tes consignes. **Tu ne pourras pas le rejouer.** » Boutons : « Déléguer le match » / « Annuler » (focus sur **Annuler**, action irréversible).

### 6.6 Données et événements

| Donnée | Source | Rafraîchie | Absence |
|---|---|---|---|
| Rencontre, date, lieu, météo annoncée | calendrier (moteur) | à chaque jour | « Aucune rencontre à préparer pour le moment. » |
| Forme, forces, confrontations, joueurs, clés de Gabi | `avant-match` (moteur) | à chaque jour, chaque feuille validée | phrase d'absence par tuile |
| Feuille, condition | sélection + effectif | à chaque affectation, blessure | « Feuille à vérifier » |

| Action | Événement | Payload |
|---|---|---|
| Coup d'envoi | `MatchKickoffRequested` | `{fixtureId}` |
| Déléguer | `MatchDelegationRequested` | `{fixtureId}` |

L'écran ne calcule ni la validité ni le résultat.

## 7. Actions et raccourcis

| Action | Souris | Clavier | Réponse |
|---|---|---|---|
| Coup d'envoi | bouton | Entrée / Espace **sur le bouton focalisé**, après le verrou d'ouverture de 0,5 s (voir garde-fou) | passe au direct |
| Déléguer | bouton | Tab, Entrée | fenêtre (focus Annuler) |
| Vérifier la feuille | lien | Tab, Entrée | Composition (retour ici) |
| Ouvrir le plan de jeu | bouton | Tab, Entrée | Plan de jeu |
| Préparer la causerie | bouton | Tab, Entrée | ouvre le Vestiaire (relevé dans le code : navigation vers la route « Vestiaire », où se prépare la causerie) ; retour par Échap |
| Dossier adverse | lien | Tab, Entrée | Préparation › Dossier adverse |
| Retour | — | Échap | écran précédent |

**Garde-fou proposé** : le focus initial reste sur « Coup d'envoi » (K8), donc un Espace répété depuis le Bureau tomberait sur un bouton déjà actif. Pour l'éviter : (1) **verrou d'ouverture de 0,5 s** : tout appui clavier (Espace, Entrée) reçu pendant ce délai, ou répété automatiquement (touche maintenue), est ignoré ; le bouton affiche alors un état « prêt dans un instant » en mot, pas seulement grisé ; (2) un appui ultérieur, volontaire, active le bouton focalisé. Le libellé du pied dit « Entrée ou Espace sur le bouton ». La souris n'est pas concernée.

## 8. États

| État | Déclencheur | Rendu | Comportement |
|---|---|---|---|
| Prêt | feuille valide | « Feuille validée » + Coup d'envoi actif | — |
| Feuille incomplète | blocage de feuille | « Feuille incomplète » + cause ; Coup d'envoi grisé, **raison à côté** ; focus sur « Vérifier la feuille » | lien direct à la correction |
| Avertissements | blessure légère, condition < 80 % | « Feuille à vérifier » (n avertissements) ; Coup d'envoi actif | pas de modale |
| Reprise après arrêt forcé | jeu fermé en plein match | bandeau : « Ton match a été interrompu. Il reprend avant le coup d'envoi. » | feuille et consignes conservées |
| Pas de rencontre | calendrier vide | « Aucune rencontre à préparer pour le moment. » + « Voir le calendrier » | Coup d'envoi absent |
| Rencontre déjà jouée | résultat existant | « Match joué. » + « Voir l'après-match » | — |
| Données adverses absentes | début de saison | phrases d'absence par tuile (jamais de tuile vide) | — |
| Chargement | moteur occupé | boutons grisés avec raison ; tuiles en gris | 0,35 s avant affichage |
| Erreur | données illisibles | bandeau + Réessayer ; Coup d'envoi grisé avec raison | pas de crash |
| Première fois | premier match de la carrière | tuile Gabi mise en avant ; liseré sur « Coup d'envoi » | disparaît au lancement |

## 9. Accessibilité (T1, C1, C5, D1, D2, D5, K1, K2, K8, M3, S2)

- **Texte sur photo** : voile ou aplat sous tout texte de l'affiche (C5) ; test sur les 5 photos de météo (sec, vent, chaleur, pluie, forte pluie).
- **Texte** : tuiles ~13 px à 1920 ; « Classement ouvert… », « Pas encore de match… », « Rucks / Mêlée / Hors-jeu / Cartons » aujourd'hui sous le plancher à 1280 : ≥ 11 px réels, ≥ 12-13 px à 1920.
- **Couleur non seule** : forme V/N/D avec lettre ; météo icône + mot ; arbitre mot + repères ; « Probable » en mot ; statut de feuille icône + mot.
- **Focus** : liseré ≥ 2 px ; ordre : rail → bandeau (Déléguer, Coup d'envoi) → Ta feuille → Conditions → L'adversaire → Gabi → pied ; focus initial sur « Coup d'envoi ».
- **Délégation** : focus piégé, Échap annule, focus par défaut sur Annuler.
- **Gabi** : texte lisible sans audio ; pas d'autolecture (S1/S2).
- **Contraste** : texte courant ≥ 4,5:1 (au pire pixel sous le voile), éléments d'interface et focus ≥ 3:1 (C1, C3) ; jetons à valider avec la direction artistique.
- **Verrou d'ouverture** : les 0,5 s sont annoncées par le mot d'état du bouton ; aucune limite de temps sur la décision elle-même (K7).
- **Mouvement** : l'affiche est statique ; transition vers le direct passable (M3) ; réglage « Transitions » respecté (M2).
- **Équipes** : écusson + mot « Ton équipe » plutôt que position ou couleur seules (D5).

## 10. Ce qu'on retire, déplace, garde

| Écran actuel | Décision |
|---|---|
| 6 tuiles | **4 tuiles** : Ta feuille, Conditions du match, L'adversaire, Le mot de Gabi |
| Tuile « Forces en présence » (vide avant la J1) | Retirée ; lien vers le rapport de force de la Préparation |
| Tuile « Confrontations directes » | Retirée ; bilan en pastille d'affiche |
| « Météo du match » + météo de l'affiche (deux fois) | Une seule fois, dans « Conditions du match » ; icône + mot dans l'affiche |
| Lignes grises « Pas encore de match cette saison » sous chaque club | Retirées (forme V/N/D à la place quand elle existe) |
| Statut « FEUILLE VALIDÉE » (vert) seul | Statut en mots + icône, avec condition |
| Bouton « Coup d'envoi » avec raison seulement en infobulle | Raison écrite à côté quand il est grisé |
| « Déléguer le match » sans confirmation décrite | Fenêtre avec avertissement d'irréversibilité, focus sur Annuler |
| Affiche, bouton Coup d'envoi, Déléguer, Gabi | **Gardés** (maquette validée par Léo) |

## 11. Déviations des motifs

- **N5/N6** : verrou de 0,5 s à l'ouverture et touche maintenue ignorée ; pression volontaire sur le bouton focalisé.
- **N5 (Échap)** : fenêtre, puis retour, puis menu pause de la carrière (règle unique de Léo, 19/11/2026) ; jamais de lancement ni d'abandon du match.
- **W1** : délégation = action irréversible : bouton nommé, focus sur Annuler.
- **F9** : raison d'un blocage visible à l'écran, pas seulement en infobulle.

## 11 bis. Transitions, localisation, entrées

**Transitions** : ouverture instantanée (100 ms au plus en « Normales », 0 en « Aucune ») ; fenêtre de délégation : apparition instantanée avec voile, focus piégé ; passage au direct : transition passable d'une touche dès la première seconde (M3), durée selon « Transitions » (M2) ; affiche statique ; chargement 0,35 s avant affichage.

**Localisation** (+40 % prévu ; noms de clubs sur 2 lignes, jamais tronqués) : statut de feuille ≤ 40 ; raison de blocage ≤ 70 ; nom de club ≤ 28 ; compétition + journée + lieu ≤ 60 sur la ligne d'affiche ; bouton ≤ 24 (« Déléguer le match ») ; texte de tuile ≤ 3 lignes de 45 ; clé de Gabi ≤ 60 ; message de reprise ≤ 80.

**Entrées (souris + clavier ; manette hors périmètre)** : [x] coup d'envoi, délégation, liens et boutons de tuile à la souris ; [x] les mêmes au clavier (§7) ; [x] ordre de focus et focus initial (§5, §9) ; [x] aucun glisser-déposer ; [x] aucune précision de souris requise.

## 12. Critères d'acceptation

- [ ] L'écran s'ouvre et place le focus en < 200 ms (hors chargement) ; aucun appui clavier dans les 0,5 s suivant l'ouverture, ni touche maintenue, ne lance le match.
- [ ] Feuille valide : un seul bouton plein, « Coup d'envoi », focalisé à l'ouverture.
- [ ] Feuille incomplète : Coup d'envoi grisé et la cause est écrite à l'écran avec un lien de correction.
- [ ] L'affiche passe le contraste C1/C5 sur les cinq photos de météo.
- [ ] Les pastilles de forme ont lettre et forme (capture en niveaux de gris).
- [ ] « Déléguer » exige une confirmation avec focus sur Annuler.
- [ ] Un arrêt forcé pendant le match ramène à cet écran avec le bandeau de reprise.
- [ ] À 1280×720 et 130 % : les quatre tuiles sans défilement, aucun texte < 12 px.
- [ ] Espace pressé en rafale depuis le Bureau n'atteint jamais le direct : il faut un nouvel appui volontaire après le verrou de 0,5 s.
- [ ] « Préparer la causerie » ouvre le Vestiaire ; Échap ramène ici.

## 13. Questions ouvertes

| Question | Propriétaire | Statut |
|---|---|---|
| « Préparer la causerie » : que fait ce bouton ? | ui-programmer | Relevé : ouvre le Vestiaire (code `match_avant.gd`) ; contenu du Vestiaire hors fiche |
| Le verrou de 0,5 s + touche maintenue ignorée est-il acceptable pour Léo (changement de N5/N6) ? | Léo | À trancher |
| Faut-il une confirmation avant le coup d'envoi quand des avertissements sont ouverts ? | Léo / game-designer | Proposé : non (pas de modale ; avertissement visible) |
| La reprise après arrêt forcé : rejouer depuis le coup d'envoi ou résultat conservé ? | game-designer | Décision du 16/11 : reprise avant le match ; détail à confirmer |
| Échap sur l'avant-match : retour (proposé) ou pause ? | Léo | **Résolue le 19/11/2026** : retour, sinon menu pause |

## 14. Limites du relevé

Le **tunnel** (entrée des joueurs) apparaît ici comme photo selon la météo et, côté direct, comme séquence : sa durée, son passage d'une touche (M3) et son comportement en mouvement réduit ne sont **pas relevés** dans cette fiche (écran 13).
