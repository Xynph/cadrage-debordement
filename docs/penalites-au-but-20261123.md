# Réussite au but : pénalités et transformations (23/11/2026)

Choix de Léo : la réussite des pénalités de près doit tourner autour de 85-90 % en moyenne, dépendre nettement du
buteur (très bon ≈ 93-95 %, mauvais ≈ 70 %), de la distance et de l'angle (loin ou en coin : nettement plus bas).

## Formule

Rencontres « essais réalistes » (`essaisRules`), `dist/rugby.js`, coefficients dans `BUT` :

- une seule formule pour la pénalité et la transformation (`goalShotSuccess`) ;
- buteur noté 80 face aux poteaux à 22 m : 95 % ; ± 0,85 point de réussite par point de note au but ;
- largeur apparente des poteaux (cos(angle) / distance, rapportée au tir de référence) : le manque est retiré au carré
  × 0,9 (une transformation en coin vaut un tir de face à ~45 m) ;
- au-delà de 40 m, la puissance manque : −2,6 points par mètre ;
- mental, météo, confiance et sang-froid : inchangés (même poids qu'avant, × `ESSAIS.but`) ;
- au-dessus de 92 %, la réussite s'approche de 99 % sans l'atteindre (`goalCeiling`) : le meilleur buteur reste
  sensible au vent ; plancher 10 %.

Avant : `1 − (1 − brut) × 0,6`, brut = 0,23 (0,28 en transformation) + note × 0,006 − 0,005 par mètre au-delà de 25 m −
0,13 × angle : la compression par 0,6 écrasait l'écart entre buteurs et l'effet de la distance.

La pénalité n'était tirée que face aux poteaux. La marque a désormais un écart latéral de 0 à 20 m (`penaltySpotY`),
tiré sans hasard à partir de l'état du match (aucun tirage ajouté), repris dans le fait du tir (`from.y`). Les
rencontres sans `essaisRules` gardent l'ancienne formule et la pénalité face aux poteaux. Les tirs au but de
départage (Japon, Nationale) gardent leur propre formule.

Choix du staff (`wantsPosts`, consigne « Selon le contexte ») : au but si la réussite attendue (sans la pression du
moment) atteint 40 % (« Chercher les points » : 30 %), jamais au-delà de 53 m. Avant : toute pénalité à moins de 53 m.
Seuil choisi pour garder la part des points sur pénalité dans la borne de `tests/hierarchie-penalites-monde.cjs`
(17-36 %) : à 50 %, l'IA ne tentait plus que 3,8 pénalités par match (16,6 % des points).

## Mesure (`scripts/mesure-buteurs.cjs`, Top 14, vrais effectifs, IA contre IA, 800 matchs)

| | Avant | Après |
| --- | --- | --- |
| Pénalités de près (< 30 m) | 82,5 % | **88,4 %** |
| Pénalités 30-40 m | 78,3 % | 80,0 % |
| Pénalités à 40 m et plus | 76,9 % | **59,3 %** |
| De près, buteur noté 85 et plus | 85,7 % | **93,1 %** |
| De près, buteur noté 75-84 | 81,8 % | 87,4 % |
| De près, buteur noté moins de 65 (attendu, ~20 tirs) | 74,8 % | 70,6 % |
| Transformations face / en coin | 83,7 / 77,4 % | 93,2 / 74,4 % |
| Réussite pénalités / transformations / tous les tirs | 80,1 / 81,0 / 80,7 % | 77,3 / 84,1 / 81,6 % |
| Pénalités tentées (réussies) par match | 4,48 (3,59) | 4,03 (3,12) |
| Choix au but / pénaltouche / à la main | 36 / 57 / 7 % | 33 / 60 / 7 % |
| Points / essais par match | 53,9 / 6,52 | 54,8 / 6,81 |

Toutes distances confondues, les meilleurs buteurs ne réussissent guère plus que les autres : ils tentent de plus loin.

## Pénaltouche contre tir au but (XV identiques, 1 000 matchs)

| Consigne | Avant | Après |
| --- | --- | --- |
| « Chercher la pénaltouche » contre « Selon le contexte », victoires | 57,0 % (600 matchs) | 54,9 % |
| « Chercher les points » contre « Selon le contexte », victoires | 49,1 % (600 matchs) | 49,3 % |
| Pénaltouche contre « Chercher les points » | 54,7 % | 56,1 % |
| Idem, avec des buteurs à 98 % (contrôle) | | 55,1 % |

Constat : l'avantage de la pénaltouche **ne vient pas de la réussite au but**. Même à 98 % au but, l'équipe qui joue
toujours la touche gagne 55 % des matchs contre celle qui prend les points. Par décision, le tir rapporte pourtant
autant ou plus sur les dix minutes qui suivent (+1,8 à +2,0 points nets, touche +1,4 à +1,8, même mesure) : l'écart se
fait ailleurs (occupation du camp adverse, enchaînement des pénalités dans les 22, relance après un tir réussi).
Chantier séparé.
