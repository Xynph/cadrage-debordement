# Réexaminer un objectif depuis le Bureau

Le suivi individuel comportait déjà des objectifs datés, mais leur échéance
n'était pas remontée dans les trois priorités du Bureau. Ce lot ajoute un seul
rappel, après les urgences et les contrats, avant les suggestions générales.
Il reprend le joueur, son objectif, les valeurs observées disponibles et la
date de réexamen. Il n'attribue pas de progrès au plan.

Le clic ouvre son suivi par identifiant, même avec un homonyme ou des filtres
conservés d'une visite précédente. Le bouton « Revenir à tous les jeunes »
retrouve la liste. Recherche et filtres permettent aussi de quitter ce ciblage.
Une échéance future, un suivi inactif, une rupture de contexte ou une mesure
indisponible ne déclenchent pas de rappel ; pas de rappel pendant un direct ni
à la clôture sportive. Une nouvelle confirmation du plan utilise le parcours
existant pour dater son prochain réexamen.

Aucune modification du moteur, des règles sportives, des salaires ou du format
de sauvegarde. Aucun nouveau champ persistant. Aucune donnée figée régénérée.

## Vérifications observées

Cloud Linux, Node 22.23.4 et Godot 4.7.2 officiels déjà disponibles :

- Nouvelle recette `office-youth-review-reminders` : **38 contrôles, 0 échec**
  en headless ; **40 contrôles, 0 échec** avec rendu X11/Mesa à 1280×720,
  dont deux captures techniques d'un scénario de projection contrôlé.
- `godot-office-priorities` : **107 contrôles, 0 échec**. Urgences, échéances,
  navigation consultative et trois tailles testées par la recette existante.
- `youth-development-review` et `youth-development-observation` : **20 tests
  réussis**. Le lancement ciblé totalise 22 tests réussis et 1 échec ci-dessous ;
  les décomptes internes Godot ne sont pas des tests Node supplémentaires.
- La nouvelle recette vérifie le clic jusqu'au bon dossier, les homonymes,
  les filtres résiduels, le retour à la liste et l'absence de commande moteur,
  de mutation du modèle et de modification du fichier de sauvegarde.
- RED observé avant implémentation : absence du rappel sur une échéance publiée.
  Les erreurs initiales de la nouvelle recette (paramètre seed interdit et
  attente du menu vide, puis recherche non récursive des cartes) ont été
  corrigées dans la recette, sans modifier le produit pour les contourner.

## Échec voisin conservé et signalé

`tests/godot-youth-development-review.cjs` échoue : commandes `snapshot` et
`new_career` refusées, puis dialogue absent. Le helper démarre ses commandes
immédiatement après l'instanciation, pendant le snapshot initial ; la garde du
produit refuse alors cette requête. Les trois fichiers de produit de ce lot ont
été temporairement restaurés depuis main `664867a1` pour comparer : **mêmes
quatre assertions en échec**, puis modifications de la branche restaurées.

Les tests et helpers existants n'ont pas été modifiés. Réparation réservée à
Claude dans #594, signalée dans #591. Ne pas annoncer une validation globale
verte. La CI distante reste à recevoir sur le HEAD publié ; aucune preuve
Windows ni recette de carrière réellement avancée jusqu'au réexamen.

## Modèle et quota

Conception, implémentation, exécution des tests et auto-revue : modèle principal
de cette session ; identifiant et effort effectif non exposés par le runtime.
Aucun sous-agent ni session de modèle supplémentaire. Recommandation
GPT-6.1 Sol : moyen. La règle permanente de Léo est consignée dans AGENTS et
dans les décisions du tableau #591 ; le lien de référence est enregistré sans
prétendre avoir consulté l'article.

## Intégration

Branche `codex/office-review-reminders-20261112`, distincte de #588. Ne pas
reprendre l'économie, les tests réservés ni les autres PR de Claude. Attendre
la CI et le créneau d'intégration, appliquer le gate officiel et vérifier la
CI du commit fusionné avant de signaler FUSIONNÉ/validé. Pas d'auto-merge.
