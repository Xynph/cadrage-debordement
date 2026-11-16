# V4 — direction artistique et visualisation métier

**Décision de reprise :** le premier habillage est insuffisant. Ajouter de la valeur à la lecture et à la décision, pas des décorations ou des chiffres inventés. Travail autonome autorisé ; aucune fusion.

**Architecture :** nouveau module de présentation `art-direction-v4.js`, calculs sur copies de données natives, graphiques SVG sémantiques et tableaux accessibles. Un point d’accroche final après le rendu DOM du jeu ; aucune mutation du document de carrière. Aucun framework ou service distant.

**Composition :** bureau éditorial (prochain adversaire, état du groupe, calendrier visuel et priorités), effectif (nuage âge/niveau au poste, répartition des disponibilités), finances (trajectoire du modèle natif et salaires par famille), recrutement (terrain de priorités par poste, coûts publics du marché), formation (niveau actuel/potentiel des espoirs et passerelle pro), championnat (course aux points et calendrier graphique). Les contrôles et détails natifs restent accessibles ; les longs panneaux annexes du bureau deviennent des dossiers repliables.

**Rigueur :** chaque graphique a des axes, unités, légende, texte de contexte, valeurs accessibles et état vide. Aucun faux historique, portrait de joueur inventé, potentiel de candidat non observé révélé ou coefficient natif remplacé. Les graphiques ne se contentent pas de redire les mêmes listes.

- [x] Écrire puis exécuter les tests rouges : modèles sans mutation, grille 15 postes, série financière native, données de graphique fidèles, candidats publics seulement.
- [x] Implémenter modèles et graphiques, puis les compositions et interactions de lecture.
- [x] Examiner captures réelles à 1440/390, deux thèmes ; vérifier 320–1920, clavier et tableaux alternatifs.
- [x] Tester les détails/actions natifs, sauvegardes et anciennes carrières ; suite complète et revue indépendante.
- [x] Mettre à jour #162, sa description et sa galerie autour du nouveau résultat ; vérifier publication et CI sans fusion.
