# Développer Cadrage Débordement depuis Chat

## Principe

Chat pilote GitHub ; GitHub Actions fournit le dépôt complet, Node, Python et Chromium. Un environnement Work local n'est donc plus un prérequis pour les tâches du dépôt couvertes par ces runners. Aucun nouveau jeton, machine personnelle ou accès administrateur n'est nécessaire.

Les outils GitHub connectés doivent rester accessibles dans la conversation Chat. Leur disponibilité future dépend de la session et des permissions du compte ; ce document ne les active pas et ne garantit pas leur disponibilité permanente.

## Circuit courant

1. Lire en lot main, AGENTS.md, DEVELOPPEMENT.md, #73 et la PR ; réserver les chemins. GitHub reste la référence.
2. Écrire le lot sur une branche dédiée par le connecteur : fichiers ou blobs/arbre/commit, puis déplacement de référence avec `expected_sha`. Cela ne nécessite ni clone local ni push Git authentifié depuis Chat. Vérifier le contenu publié et le HEAD.
3. Ouvrir ou mettre à jour la PR. La CI Node officielle et les workflows Chromium pertinents se déclenchent automatiquement. Un commit de test est un vrai changement à publier, pas une validation à supposer.
4. Pour V17 et les sauvegardes historiques, le nouveau workflow `chat-native-qa.yml` exécute explicitement `tests/v17-native-browser.py` sur le **HEAD exact de la PR**, pas uniquement sur le commit de fusion temporaire de GitHub. L'historique complet est récupéré pour extraire le vrai code V16. Aucun élargissement de permissions : contents read, identifiants non persistés, aucun secret fourni au test.
5. Lire une fois les conclusions sur le SHA exact. En cas d'échec, lire les logs utiles, corriger en un lot et publier un nouveau HEAD. Un job échoué peut être relancé avec le connecteur GitHub lorsque ses permissions Actions le permettent. Ne pas inventer une commande `/cd-qa` : elle n'existe pas.
6. Lire les artefacts via les outils GitHub : liste des artefacts d'un run, téléchargement de l'archive, lecture du JSON et inspection des PNG avec les outils de fichiers/images disponibles dans Chat. Le run fournit aussi le verdict, les nombres de contrôles, le SHA testé et la provenance V16 dans son résumé et ses logs. Si une session ne peut pas afficher une image, elle doit déclarer la revue visuelle non effectuée et s'appuyer sur une revue humaine des captures ; un succès automatique n'est pas une appréciation esthétique.
7. Publier la passation #73. Aucun passage en Work n'est requis pour créer la PR, obtenir les résultats du runner ou utiliser les commandes de release déjà installées.

## Couverture de réception distante

Le workflow `Reception native PC depuis Chat` se déclenche sur les PR vers main modifiant `dist/**`, son fichier YAML ou le test V17. Il est aussi disponible en lancement manuel GitHub. Modifier seulement un document ne provoque pas de nouvelle réception native.

Le runner vérifie huit sections natives, deux thèmes et deux résolutions PC sur carrière neuve, puis importe un export authentiquement produit par le code V16 du 30 octobre 2026 après une journée jouée. Les valeurs sportives/financières sont comparées à la carrière historique ; les interactions V17 comparent tout S et tout localStorage. L'identité brute de tous les champs après migration n'est pas exigée. Aucun fichier personnel n'est utilisé.

Rapport `report.json`, export de test et captures sont conservés 14 jours dans `chat-native-qa-report`. Les fichiers du dépôt et le script restent la source durable de reproduction. Le test ne remplace ni les autres suites Chromium, ni la CI officielle, ni le release gate.

Pour une nouvelle fonctionnalité, ajouter les assertions ou un scénario reproductible dans une PR et raccorder sa suite au workflow approprié. GitHub exécute le test ; Chat analyse les résultats et produit le correctif. Les besoins futurs qui ne sont pas couverts doivent être ajoutés à ces runners avant d'annoncer leur validation.

## Fusion depuis Chat

Les commandes exactes existantes dans #73 restent :

```
/cd-check NUMERO_PR SHA_COMPLET
/cd-merge NUMERO_PR SHA_COMPLET
```

Une commande check ne lance pas cette réception Chromium ; elle vérifie le gate existant. Une commande merge exige l'autorisation explicite de Léo sur la PR et le HEAD, un rôle d'intégrateur distinct après passation, les protections serveur et les contrôles requis. Ne pas déclencher de fusion depuis une session producteur. Le reçu officiel et la CI post-fusion 7/7 doivent être vérifiés sur le SHA effectivement fusionné. La réception native est un contrôle supplémentaire, sans changement des critères du gate.

## Activation et limites

Le workflow peut se prouver dès la PR qui l'ajoute. Son installation durable sur main nécessite ensuite une revue et une fusion autorisée de cette PR. Tant qu'elle reste non fusionnée, ne pas annoncer le dispositif comme installé sur main.

Ce circuit couvre le développement, les tests, la réception Chromium PC Linux et les sauvegardes reproductibles du projet. Il ne donne pas la main sur le PC de Léo ni sur les réglages GitHub qui n'ont pas d'API accessible. Un essai Windows natif demanderait un runner Windows et un test dédié ; aucun succès Windows n'est déduit de Chromium Linux. Les fichiers personnels doivent être fournis explicitement si un futur défaut n'est reproductible qu'avec ceux-ci.

Aucune dépense supplémentaire ni modification de quota n'est activée par le code. Les exécutions consomment les minutes GitHub Actions selon le compte ; si la capacité Actions est indisponible, les essais distants sont bloqués et cela doit être signalé.
