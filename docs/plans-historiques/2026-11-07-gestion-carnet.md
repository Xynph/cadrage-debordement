# Itération de gestion — après la refonte graphique

État : plan préparé, pas encore implémenté. Autorisation : objectif autonome utilisateur 11h maximum. Tout travail E:, sans profil personnel. Base à fixer après commit DA ; BDDv2 et guide intégrés séparément avec revues.

## Problèmes observés

Effectif de61 joueurs dans la capture réelle : aucun champ de recherche, filtre de familles seulement et position de lecture perdue au clic sur une fiche/rerender. Comparaison oblige à mémoriser les chiffres. Mercato en cartes sans filtre/recherche. L'offre montre salaire/durée/prime mais ne distingue pas les coûts immédiats et récurrents. Les classements ne présentent que la saison courante alors que le moteur conserve yearbook15saisons. Ces problèmes sont résolus avec des données existantes, sans rééquilibrage économique ou sportif.

## Réalisations attendues

1. Recherche insensible à la casse et accents sur nom/poste pour Effectif et Recrutement. Filtres de poste, blessure/disponibilité et échéance de contrat dans Effectif ; tri stable explicite avec direction. Afficher nombre de résultats, état vide clair et réinitialisation. Préserver focus et caret pendant la frappe, sans rerendre tout le monde à chaque caractère.
2. Maintenir recherche/filtres/tri/sélection et scroll au retour d'une fiche, d'un contrat ou d'un autre menu. État UI en mémoire hors carrière. Réinitialiser ou nettoyer les IDs quand la carrière change/pack change, sans comparer un joueur disparu ni mélanger deux carrières.
3. Comparer deux joueurs de l'effectif via vraisIDs : identité/poste, âge, niveau, condition, salaire courant/échéance et attributs déjà exposés. Valeurs côte à côte, unité/échelle expliquées, pas de score composite inventé ou de promesse de supériorité à un poste différent. Petit panneau/dialogue scrollable lisible aux3tailles. Changer/retirer les joueurs, fermer et retrouver la liste.
4. Liste de suivi de recrutement optionnelle si réalisation propre : IDs en état UI hors sauvegarde, filtre Suivis et suppression des entrées sorties du marché. Pas de nouvelles données cachées exposées.
5. Offre de contrat : montant immédiat de prime/coût acquisition et salaire hebdomadaire proposés, différence de salaire pour prolongation, durée et trésorerie actuelle. Mise à jour du récapitulatif quand champs changent. Ne pas convertir en engagement annuel certain sans la cadence et le nombre de semaines réels. Conserver les commandes et la confirmation existantes ; refus/contre-offre ne valent pas signature.
6. Archives sportives si le modèle est étendu en lecture seule : exposer les données yearbook existantes par IDs (champions, division/rang du club et mouvements réels), limites15saisons. Afficher dans Club ou Classements, noms par catalogue/pack courant, aucune reconstruction historique de points non enregistrés. Pas de changementS ou de format sauvegarde. Nouvelle carrière vide claire.

## Technique et validation

Lire les composants après commitDA et s'appuyer sur carnet_skin. Ne pas réintroduire du texte clair sur papier. Tests rouges significatifs puis verts : frappe réelle/focus, recherche accentuée, résultats exacts, tri stable, retour sur mêmeID/scroll, dialogue comparaison et contrat avec vraies données. Navigation/tri/recherche/comparaison ne modifient pas export de carrière ni RNG ni disque sportif. Les offres ne mutent qu'après soumission explicite par les commandes déjà existantes. Vérifier noms pack changés/IDstable et joueurs disparus via projection de cas limites clairement distinguée des vrais parcours.

Pour archives, tests moteur sur saison réelle et projection avant/après identique, pack applique identité parID, absence d'archive en fiction14 clairement gérée. Les tests5saisons ont déjà réussi et ne sont pas à rejouer sans modification pertinente ; les nouveaux tests de projection portent sur un checkpointS2 réel existant.

Captures réelles aux3tailles pour Effectif/comparaison/recrutement/offre. Inspection critique des débordements et clarté, non seulement tests verts. Documenter puis commit local. Rapport, revue globale et réception du vrai ZIP suivent l'intégration du guide et du registre v2. Ne pas modifier plafonds42/5Mio/650k, attributsBDD, règles de match/économie centrale, renderer3D ou pack privé.
