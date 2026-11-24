# Notation façon FM — planche du 24/11/2026

Branche `claude/fm-notation`. Planche du 24/11 puis **intégration de l'option B** choisie par Léo (17e conversation) :
lettre dans une pastille ronde, palier écrit dans une pilule, partout (fiche joueur, Effectif, Formation, rapport du
recruteur, discussion avec l'agent). 18e conversation : note au poste et note au rôle en lettre partout, mode fourchette
sans fuite par les chiffres dérivés, Niveau calculé selon le poste et le rôle branché à l'écran (§ 1, § 5).

## Ce qui est caché, ce qui est montré

| Valeur cachée (moteur) | Aujourd'hui | Montrée au manager |
| --- | --- | --- |
| **Niveau** (= CA de FM) | `rating` 15-99 | lettre E- à S+ **relative à notre effectif** + **palier** vague (4 familles absolues) |
| **Potentiel** (= PA) | `dev.potential`, évolue (potential-evolution.cjs) | lettre E- à S+ (même échelle) + **phrase** par cran de marge |

Jamais un chiffre du moteur. L'estimation vient du **staff** : sa justesse dépend de son jugement (45-85).

## 1. Niveau calculé (`native/engine/niveau-calcule.cjs`, branché à l'écran le 24/11)

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

## 3. Option de nouvelle carrière (branchée)

« Qualités des joueurs » : **Précises** (défaut) / **En fourchette tant que pas observé** (deux pilules, un clic choisit
et valide). Envoyée avec `new_career` (`qualites: 'fourchette'`, toute autre valeur refusée), sauvegardée dans la
carrière : `S.qualitesJoueurs = {version: 1, mode: 'fourchette', debut: {season, week}}` (absent = Précises, carrières
d'avant inchangées). `player-knowledge.cjs` (`suivi`) : nos joueurs suivis depuis moins de 4 semaines (début de carrière
ou arrivée au club) → fourchettes de 9 points, 4 à 7 semaines → 5 points, ensuite précises ; la projection ajoute
`attributesV2Range` (36 qualités) et `knowledge.qualitesLargeur`. Fiche, carte au survol et mini-fiche montrent
« 58-66 » (moyennes de famille « ~62 »). Test : `tests/qualites-fourchette.cjs`, `tests/godot-creation-da.gd`.

## 4. Une seule échelle, plus de chiffres

- Rapport du recruteur : l'ancienne lettre d'avis A+ … D (écart avec notre n° 1) est remplacée par la lettre du staff
  E- … S+ ; barème = les 18 pastilles, rang et note au poste, lettre de notre n° 1. « Marge de progression +17 » →
  phrase de potentiel du staff (sans chiffre).
- Effectif : tuile « Niveau moyen du XV » → « Niveau du XV » en palier écrit (tendance ▲/▼ sans écart) ; total de liste
  « niveau moyen » → lettre moyenne relative à l'effectif ; en-tête « niveau du groupe » en palier.
- Création : « note moyenne » / niveau chiffré du club → palier écrit (`Notation.palier_groupe`).
- La lettre du conseil (Club › Vue d'ensemble, A+ … E, barème validé le 22/11) est une note de confiance, pas un
  joueur : non touchée.

## Variante retenue

**B** (Léo, 24/11) : lettre en pastille ronde ; palier en mot dans une pilule. Variante A et `CD_VARIANTE_VISUELLE` retirés.

## 5. Note au poste et note au rôle en lettre (décision de Léo, 24/11, 18e conversation)

- **Plus aucun chiffre de note au poste** : Postes et rôles, rapport du recruteur, Composition (terrain, candidats,
  glisser-déposer), carte et mini-fiche au survol, comparateur, recherche ciblée, planificateur, discussion avec l'agent,
  Préparation (joueurs à surveiller), menu du joueur en match, avis de Gabi. Même échelle E- à S+ que le Niveau
  (référence = nos 15 meilleurs = B, 2 points par cran), même palette, même pastille ronde (`Notation.pastille_note`,
  `Familiarite.poser_note`). Les tris gardent la valeur cachée (seul l'ordre se voit).
- **Une seule erreur du staff par joueur** (celle du Niveau) : son meilleur rôle au poste principal a la même lettre que
  son Niveau ; les écarts entre postes et rôles restent ceux du moteur.
- **Notes au poste calées sur le Niveau calculé** : au poste principal, note au poste = Niveau (même lettre) ; aux autres
  postes, les écarts du moteur (`positionRatings` : familiarité, qualités du poste) restent (`Notation.decalage_poste`).
- **Staff pas sûr → pastille double « B/A »** (deux moitiés aux couleurs des deux lettres) : lettre basse et haute =
  valeur ± 0,7 × demi-largeur d'incertitude. Recrue jamais publiée au poste (tout joueur d'un autre club : le moteur ne
  publie pas ses notes au poste) : estimée depuis la fourchette d'observation du Niveau, aux postes qu'il connaît
  (Naturel, Confirmé) ; ailleurs ou sans fourchette : « ? ».
- **Niveau au rôle** (colonne NOTE de Postes et rôles, rôles du menu en match) = `niveauCalcule.roles[rôle]` ; « Son
  rôle » = rôle du Niveau calculé (`niveauCalcule.role`).
- Carte au survol : Niveau et Potentiel en lettres (palier en pilule, phrase de potentiel), plus de jauges ni de « ▲ +3 ».
  Mini-fiche : lettres. Bulle de la flèche du Niveau : sens de la courbe seulement (▲/▼), sans chiffre.

## 6. Mode fourchette : tout ce qui est dérivé part de la fourchette

Projection (`player-knowledge.cjs`, `derive`, copie envoyée à l'écran seulement, rien dans S) pour nos joueurs encore
en fourchette :
- `attributesV2` = **milieu de chaque fourchette** (jamais la vraie valeur ; radar, moyennes « ~ », points forts,
  qualités du rôle, entraînement, Niveau au rôle en dérivent) ;
- `positionRatings` décalées de l'écart pondéré (poids du poste) entre milieux et vraies qualités, arrondies ;
- ni `releve` (relevé hebdomadaire au dixième), ni `fleches`, ni `nativeAttributesV1` ;
- incertitude `qualitesLargeur / 2` ajoutée aux lettres (notes au poste et au rôle en « B/A »).

Le Niveau calculé (`niveauCalcule` = {niveau, role, roles}) est ajouté pour nos joueurs et les joueurs observés en
profondeur ; l'estimation du staff part de lui au lieu de `rating`. Le moteur du match garde `rating` (bascule : § Reste).

Tests : `tests/qualites-fourchette.cjs` (milieux, notes au poste décalées, Niveau calculé par poste et rôle),
`tests/godot-creation-da.gd` (fiche en fourchette : lettres doubles, aucune flèche), `tests/godot-immersive08.gd`
(Postes et rôles en lettres, « Son rôle », aucune décimale), suites de la Composition, du recrutement, du planificateur,
du menu en match.

## Reste à faire

Bascule de `rating` (moteur du match) sur le Niveau calculé, rôle choisi par le club enregistré au moteur, estimation du
staff calculée dans le moteur (projection `notation` par joueur). Chiffres de Niveau restants hors note au poste
(comparateur Niveau/Potentiel, « Niveau / 100 » de la comparaison du recrutement, colonne niveau des vues héritées,
« NIV. EN JUILLET » de la Formation, bureau).
