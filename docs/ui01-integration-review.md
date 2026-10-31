# Réception UI-01 — PR producteur #79

Base : main `d3afa283359b13d9e393eb90d305d7411bf638c7`, producteur `967de0bef4b6ae6854406a1615323097cfa73f43`. Les six fichiers UI-01 sont repris sur `integration/ui01-reviewed` sans modifier la branche du producteur ; les tests de carrières #80 restent présents.

## Défauts reproduits à la revue

La nouvelle navigation masque la barre latérale hors match. Les commandes `resetDialog()`, `CDOfflineAction('quit')` et la localisation du stockage étaient absentes de l'en-tête visible. Le statut de sauvegarde était dans une zone masquée à moins de 800 px. Enfin l'en-tête (z-index 90) passait devant le fond de confirmation natif (50). Les cartes d'accueil et certains boutons conservaient un fond clair avec la couleur de texte claire du thème Analyste.

Corrections ciblées : bande de session accessible aux différentes tailles, appel des fonctions natives sans nouvelle logique de stockage, erreur annoncée par role alert, confirmations au-dessus de la navigation, surfaces sombres explicites. Aucun moteur de match ni format de sauvegarde changé. Les préférences visuelles restent séparées de `bdt-v1`.

## Vérification

- `node tests/ui01-interface.cjs` : suite originale du producteur conservée.
- `node tests/ui01-integration.cjs` : 15 groupes supplémentaires du vrai harness, vues, commandes historiques, ancien format et match exportable ; cette suite a réussi localement.
- `python tests/ui01-browser.py` : réception Chromium du vrai jeu, 14 destinations, 5 largeurs, deux thèmes forcés et suivi Système, confirmations, erreurs visibles, captures et pont portable simulé. Résultat GitHub Actions à vérifier, non présumé.
- Le workflow UI01 est en lecture seule et peut valider la branche d'intégration sans fusion. Il exécute toutes les suites natives et la réception navigateur ; les logs et captures restent des artefacts privés à durée limitée.

## État de publication et limites

La création de la PR d'intégration a été refusée par les contrôles de sécurité de l'outil pendant cette session. Ne pas contourner cette décision en créant une PR par une autre méthode ni fusionner #79 sans les corrections. La branche reste un travail préparé : aucune livraison sur main ne doit être annoncée avant un parcours PR validé et la CI post-fusion.

Le navigateur local démarre mais le chargement de fichier est bloqué par sa politique administrateur ; aucun rendu graphique local réussi n'est revendiqué. Les tests navigateur sont confiés au runner GitHub, sans modifier la politique locale. Aucun test Windows natif, mobile physique ou certification générale d'accessibilité. #75 intacte. La passation opérationnelle est publiée dans #73.
