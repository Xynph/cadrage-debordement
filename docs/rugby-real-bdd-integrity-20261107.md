# Rugby Réel — audit indépendant de la BDD active au 7 novembre 2026

**Base analysée :** `main` `044e83d2a9f860d59c2aeac2a22df94235bf04c9` (PR #383 intégrée). Ceci n'est pas une nouvelle calibration de notes ; la BDD active de `dist/lnr-ratings-v12.js` diffère délibérément du candidat `data/scouting/review-v12/candidate.json` en raison du réglage de profondeur. Ne jamais écraser l'actif avec le candidat brut.

## Audit réel des 1 592 joueurs

Lecture directe du candidat (identifiants, postes, division) et de la BDD active (notes et attributs) par le connecteur GitHub et calcul sur la totalité des profils :

| Mesure | TOP 14 | PRO D2 |
| --- | ---: | ---: |
| Joueurs | 805 | 787 |
| Note moyenne **active** | 74,35 | 66,79 |
| Intervalle actif | 66–90 | 58–80 |
| Écart moyen TOP14 − PRO D2 | **7,57 points** | — |
| Candidat brut V12 (pour comparaison, **non actif**) | 76,33 | 68,53 |

* **1 592/1 592** identifiants distincts ; **57 312** cellules de 36 attributs ; **0** attribut absent / invalide (bornes 20–97 dans le candidat).
* Écart actif par poste (TOP14 − PRO D2) : pilier droit **7,33**, deuxième ligne **7,80**, demi de mêlée **7,75**, talonneur **8,10**, centre **7,65**, numéro 8 **7,46**, arrière **7,83**, ailier **7,04**, troisième ligne **7,56**, pilier gauche **7,62**, demi d'ouverture **7,26**.
* **520** profils portent un avertissement de divergence d'échelle potentiel/capacité dans le candidat V12 : **signal à étudier**, pas 520 joueurs mal notés de manière démontrée.
* **627** joueurs avec au moins une preuve de performance rapprochée dans le candidat (420 TOP14, 207 PRO D2) ; les autres restent des estimations de gameplay. Les notes ne doivent pas être présentées comme officielles.

Les 36 attributs actifs couvrent technique, défense, attaque, vision, mental et physique. Leurs moyennes sont sensibles aux distributions de postes : comparer les divisions **par poste** plutôt que supposer qu'une faible note de but chez un pilier est une erreur. La comparaison des 36 attributs du candidat est documentée dans `docs/rugby-real-v12/audit.json` ; ce contrôle ajoute une protection de l'**actif**, distinct de la source candidate.

## Âge et potentiel

Le modèle V11 de `dist/lnr-v11-aging.js` a des pics variables par poste et par famille : vitesse/explosivité plus précoce, force plus tardive, mental plus durable. Un test contrôlé sur un joueur synthétique à 20 et 38 ans vérifie l'évolution de la force jeune, le déclin de vitesse après 35 ans, la conservation du potentiel et l'idempotence lors d'une seconde application dans la même saison. Cela **ne constitue pas** une preuve de déclin longitudinal réel des 1 592 joueurs. La réception #383 couvre séparément dix saisons et dix exports/imports avec la mécanique native.

## Réalisme sportif et limites de décision

Dans les campagnes historiques déjà exécutées sur le moteur, la différence de niveau était perceptible mais pas assez robuste pour garantir une promotion difficile, ni un retour immédiat après relégation : à coefficient natif 0,004, le promu de référence gagnait 29,69 % contre le TOP14 médian mais 40,63 % face au meilleur adversaire testé, et cinq départs de titulaires avaient un effet trop faible sur le relégué (voir `docs/rugby-real-v12/calibration.md`). Ces chiffres sont ceux de scénarios de feuilles d'équipe et **non** de saisons avec une vraie montée/descente.

**Décision de ce lot : ne pas modifier les notes de production**, la mécanique d'âge, le coefficient moteur ou le potentiel. Sans migration des tests de promotion/relégation et sans preuve externe individuelle additionnelle, un bonus/malus global serait arbitraire. Ajouter à la place un test régressif précis et indépendant pour éviter une régression accidentelle de la base active. Une future PR métier pourra comparer plusieurs effectifs, 64+ graines, vrais changements de profondeur et sauvegardes de longue durée ; réservation nouvelle requise.

## Test régressif livré (sans données mutées)

```sh
node --test tests/rugby-real-bdd-integrity-20261107.cjs
```

Contrôle : unicité des 1 592 IDs, 36 attributs et 11 compétences par joueur, bornes, six traits, écarts par poste, divergences de profondeur entre candidat et notes actives, cohérence des courbes d'âge sur copie. Aucun fichier `dist/**`, catalogue `modding/**`, UI, MATCH3D, effectif, calendrier, moteur, économie, sauvegarde ou données officielles n'est modifié. Les contrôles GitHub Actions sur le SHA de PR doivent être réceptionnés séparément. PR DRAFT, aucune fusion.
