# Analyses des cinq dernières rencontres

## Conception

Le carnet du club présente les cinq dernières rencontres réellement conservées dans `S.history`, pour le club actuel et la saison actuelle. Les scores, essais, pénalités concédées, mêlées et touches proviennent des résultats du moteur. Les statistiques manquantes restent absentes ; un taux sans tentative reste indéfini. Les taux agrégés sont pondérés par les tentatives. Aucun indicateur individuel ni ratio par 80 minutes n'est déduit.

La comparaison des trois rencontres récentes avec les deux précédentes décrit un écart observé, sans prétendre identifier une cause ni une tendance statistiquement établie. Les conseils de travail citent leurs dénominateurs et demandent au manager de vérifier le contexte. Une victoire après départage est distinguée d'un score nul.

Architecture retenue : domaine natif `performanceAnalysis` consultatif, projeté dans `clubLife`, puis panneau Godot dans le carnet existant. L'alternative d'un nouvel historique individuel est écartée : les minutes et événements individuels ne sont pas durablement conservés pour chaque rencontre. Aucun état, commande, aléatoire ou stockage supplémentaire.

## Plan

- [x] Tester fenêtre, orientation domicile/extérieur, saison/club, départage et couverture manquante.
- [x] Implémenter la projection et les conseils sourcés ; vérifier l'immuabilité.
- [x] Ajouter le panneau Godot au carnet, tester son affichage.
- [x] Vérifier une véritable carrière et documenter le raccordement du manifeste.

## Raccordement réservé à l'intégrateur

Ajouter `performanceAnalysis:require('./performance-analysis.cjs')` aux domaines de `native/engine/native-systems.cjs`. Le domaine ne déclare ni fichier dist, ni commande, ni hook. `club_memory_view.gd` inclut le nouveau panneau ; aucun changement de navigation principal.

## Vérification et limites

`tests/performance-analysis.cjs` : tests de projection puis cinq matchs délégués dans une véritable carrière du worker. Les totaux sont comparés aux résultats conservés, la projection après sérialisation est identique, l'export (état/RNG) et les octets du profil ne changent pas. Avec `CD_GODOT_EXE`, le même test lance la recette UI sur ce modèle réel : 24 contrôles aux formats 1280×720, 1600×900, 1920×1080 et 2560×1440, couverture statistique, comparaison, états vide et moteur ancien, largeur et immuabilité. Un cas supplémentaire de contexte Monde distingue la semaine globale de la journée de compétition et conserve le terrain neutre. Sans preuve du lieu, la vue l'indique comme non conservé.

Le module ne modifie aucune sauvegarde et ne fournit pas d'analyse individuelle. La fenêtre recommence au début d'une saison, comme le registre des résultats existant. Les lieux, adversaires et phases peuvent différer entre périodes : aucun effet causal d'un changement tactique n'est annoncé. Les seuils de conseil (trois matchs et dix conquêtes, ou neuf pénalités par match) sont des repères de lecture fictifs explicites dans le code, sans effet sur la simulation. Aucun test Windows n'est revendiqué.
