# Recommandation provisoire — amortissement de la réputation V51

## Périmètre et preuve

Dernier benchmark confirmé : commit `fdcb86bb532f56142897d6b46ac7c8c78f0ed2b3`, GitHub Actions [run #41151827140](https://github.com/Xynph/cadrage-debordement/actions/runs/41151827140), conclusion **success**. Tests additionnels de contrats et de checkpoints également verts. Simulation de laboratoire : 80 graines × 4 forces × 2 profils de départ × 15 saisons = **9 600 saisons** (134 400 clubs-saisons), sans matchs réels et avec finances fictives.

Les deux distributions ont été simulées avec les mêmes graines, des clubs de mêmes effectifs numériques et les vrais adaptateurs V46–V50. La seule variation entre réglages est le facteur appliqué à la variation annuelle produite par `CDReputation.update` dans le test, sans changement du moteur.

| Force | Part du dominant (égaux / inégaux) | Champions distincts (égaux / inégaux) | Déficit inégaux | Restrictions inégaux | Investissements inégaux | Changements d'entraîneur inégaux |
| --- | --- | --- | --- | --- | --- | --- |
| 15 % | 53,50 % / 61,17 % | 4,7875 / 3,4625 | 2,27 % | 7,06 % | 722 268 000 | 562 |
| **25 %** | **63,42 % / 67,25 %** | **3,6875 / 3,0625** | **3,77 %** | **8,73 %** | **702 228 000** | **555** |
| 40 % | 74,75 % / 69,83 % | 2,8125 / 2,9 | 5,72 % | 11,51 % | 685 272 000 | 578 |
| 100 % (référence) | 89,33 % / 83,83 % | 1,95 / 2,2 | 11,09 % | 16,27 % | 636 276 000 | 622 |

## Décision suggérée

**Candidat principal : 25 %** pour un prototype réglable, **15 %** comme alternative favorisant davantage le renouvellement des champions. Le facteur 25 % diminue la part du dominant de **25,91 points** pour les clubs égaux et de **16,58 points** pour les clubs inégaux, sans immobiliser la réputation. Il se situe entre l'extrême à 15 % et le déséquilibre plus marqué à 40 %.

Il ne s'agit **pas d'un coefficient de production validé** : le moteur sportif V51 classe les clubs à partir de réputation, infrastructure et bruit aléatoire, sans simulation de rencontres, recrutement réel ou calendrier. De plus, modifier la progression de réputation change indirectement recettes et finances ; il faut valider ce comportement avec des matchs et des carrières du jeu avant d'adopter un réglage. Les investissements sont des montants fictifs et la fréquence des changements d'entraîneurs est un événement interne au simulateur.

## Conditions avant intégration

- Conserver les tests et les résultats sur la branche de laboratoire ; ne modifier aucun moteur de production avant coordination avec le développeur intégrateur.
- Tester 15 % et 25 % sur des équipes de niveaux variés et avec de vraies saisons du jeu ; conserver un réglage configurable et réversible.
- Définir des critères d'équilibrage métiers indépendants de la simple parité entre clubs : l'avantage des meilleures équipes doit rester réel, mais pas irréversible.
- Vérifier les taux de déficit, les transferts, la stabilité des entraîneurs et la compatibilité des sauvegardes réelles après toute intégration.

**Décision de ce cycle : recommandation publiée, aucune modification fonctionnelle ni fusion.**
