# Notation façon FM — planche du 24/11/2026

Branche `claude/fm-notation`, **planche** (rien n'est branché au moteur). Choix de Léo : PASSATION.md de la revue
FM27 (16e conversation), section « RESTE » point 0 et lignes « CHOIX DE LÉO ».

## Ce qui est caché, ce qui est montré

| Valeur cachée (moteur) | Aujourd'hui | Montrée au manager |
| --- | --- | --- |
| **Niveau** (= CA de FM) | `rating` 15-99 | lettre E- à S+ **relative à notre effectif** + **palier** vague (4 familles absolues) |
| **Potentiel** (= PA) | `dev.potential`, évolue (potential-evolution.cjs) | lettre E- à S+ (même échelle) + **phrase** par cran de marge |

Jamais un chiffre du moteur. L'estimation vient du **staff** : sa justesse dépend de son jugement (45-85).

## 1. Niveau calculé (module isolé `native/engine/niveau-calcule.cjs`)

```
poids(q)  = poidsPoste[famille][q]  (défaut : 0,5 pour la lecture du jeu, 0,25 sinon)
          + 2 si q est une qualité clé du rôle, + 1 si q est utile au rôle      (rôles de la fiche : fiche_roles.gd)
QP        = Σ poids(q) × q / Σ poids(q)                                         (36 qualités)
brut      = 0,92 × QP + 0,04 × régularité + 0,04 × grands matchs                (hiddenTraitsV2 ; 61 si absent)
Niveau    = clamp(round(A × brut + B), 15, 99)        A = 1,108  B = −5,86  (calage unique tous postes)
Niveau du joueur = meilleur rôle de son poste principal (le rôle choisi par le club quand il existera)
```

| Symbole | Type | Plage | Rôle |
| --- | --- | --- | --- |
| q | entier | 20-97 | une des 36 qualités (attributesV2, ou nativeAttributesV1 décompressé) |
| poidsPoste | réel | 0,25-4 | importance de la qualité au poste (10 familles) |
| régularité, grands matchs | entier | 41-80 | qualités cachées `consistency`, `bigMatches` |
| A, B | réel | — | calage : même moyenne et même dispersion que `rating` sur les 116 clubs du Monde |
| Niveau | entier | 15-99 (borné) | nouvelle valeur cachée ; bornes atteintes seulement par des qualités hors base |

Poids au poste (4 = cœur du poste) : pilier → mêlée 4, force 3 ; talonneur → lancer 4, talonnage 3, mêlée 3 ;
2e ligne → saut en touche 4, détente 3, force 3 ; 3e ligne aile → plaquage 4, grattage 3, activité 3, endurance 3 ;
n° 8 → portage 3, plaquage 3 ; demi de mêlée → passe 4, décision 3 ; ouvreur → décision 4, passe/vision/jeu au pied/
sang-froid 3 ; centre → portage 3, plaquage 3 ; ailier → vitesse de pointe 4, accélération 3, évitement 3 ;
arrière → placement, réception, jeu aérien 3. Tableau complet dans le module.

Exemple (Kyle FAIRCLOUGH, pilier gauche d'Alder Fen, Conquérant) : Niveau 63. +10 en technique de mêlée → 65 ;
+10 en plaquage → 64 ; +10 en distance au pied ou en vitesse de pointe → 63 (la mêlée pèse 14 % du calcul, le jeu au
pied 0,6 %).

### Écart avec l'actuel (export Monde d'Alder Fen XV, 21/11)

`node tools/notation/ecart-niveau.cjs <carriere.json> [--caler] [--md]`

- Monde (5 959 joueurs) : écart moyen absolu **1,2 point**, corrélation 0,988, 77 joueurs à 5 points ou plus.
- Par famille : piliers −2,1, n° 8 −1,3, ouvreurs −1,2 ; talonneurs +1,3, arrières +1,4, ailiers +1,1.
- Alder Fen XV (36) : 13 inchangés, 14 à ±1, 8 à ±2, 1 à −3.

**Constat important** : les 36 qualités de la base sont aujourd'hui *déduites* de la note (player-attributes.cjs,
`initialize`/`progressed` : elles suivent `rating`). Toute pondération raisonnable retombe donc presque sur la note
actuelle. Le calcul par poste et rôle prendra son sens quand l'entraînement fera progresser **certaines** qualités
(chantier des flèches de progression, choix de Léo) : le Niveau suivra alors ce qui a vraiment été travaillé, au lieu de
l'inverse. Ordre conseillé : 1) progression par qualités, 2) Niveau calculé à partir d'elles, 3) bascule de `rating`.

## 2. Estimation du staff et affichage (`native/godot/ui/notation_staff.gd`)

- **Erreur du staff** : 6 points (jugement 45) à 1,5 point (jugement 85), empreinte fixe par couple (club, joueur) ;
  autres clubs : milieu de la fourchette d'observation (player-knowledge) + la même erreur.
- **Lettre** : référence = moyenne estimée de nos 15 meilleurs = **B** ; 1 cran = 2 points ; bornée E- … S+.
  Un joueur baisse de lettre si on recrute meilleur que lui. Le potentiel utilise la même échelle.
- **Palier** (absolu, vague) : Niveau amateur < 60 ≤ Niveau pro < 72 ≤ Haut niveau < 82 ≤ Élite (XV moyens du Monde :
  Champ/Nationale 63-65, Pro D2 75, Japon D1 78, Top 14/Prem/URC/SRP 83-85). Fourchette du staff à cheval →
  « Entre pro et haut niveau ».
- **Phrase de potentiel** : marge ≥ 9 beaucoup / ≥ 3,5 de la marge / sinon peu ; 31 ans et plus sans marge : déclin ;
  fourchette trop large : staff incertain. 3-4 tournures par cran, tirées par empreinte (staff, joueur).
- Palette des lettres validée par Léo (texte clair sur les sombres, foncé sur C/C+/B+, blanc sur E+/D+/A+/S+).

## 3. Option de nouvelle carrière

« Qualités des joueurs » : **Précises** (défaut) / **En fourchette tant que pas observé** (deux pilules, un clic
choisit). Planche : le choix reste à l'écran ; à brancher sur player-knowledge (attributs en fourchette pour nos
propres joueurs tant que le staff ne les a pas assez vus).

## Variantes à trancher (CD_VARIANTE_VISUELLE)

- **A** : lettre en case arrondie (rayon 6) ; palier en jauge 4 crans dorés + mot.
- **B** : lettre en pastille ronde ; palier en mot dans une pilule.

## Reste à faire après le choix

Brancher le Niveau calculé (après la progression par qualités), passer l'estimation du staff dans le moteur
(projection `notation` par joueur : jamais de valeur cachée vers l'écran), retirer les chiffres restants (tuile
« Niveau moyen du XV », « note moyenne » de la création, mini-fiche, carte au survol, comparateur), aligner la lettre
d'avis du recruteur (ancienne échelle A+ … D) sur la nouvelle, mettre à jour tests/godot-immersive08.gd
(`PlayerGlobalRating` n'est plus un Label).
