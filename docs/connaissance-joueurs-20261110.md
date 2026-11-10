# Connaissance des joueurs — contrat canonique

Politique approuvée le 10 novembre 2026. Les vraies notes restent dans le moteur ; la dernière frontière de projection applique la visibilité à toutes les copies affichables, y compris rapports, aperçu de négociation, sélections et Espoirs. Le JSON de sauvegarde reste un document interne restaurable.

| Joueur | Niveau | Potentiel | Attributs |
|---|---|---|---|
| Notre club | valeur exacte actuelle | intervalle de 5 valeurs | connus |
| Extérieur non observé | inconnu | inconnu | inconnus |
| Première observation | intervalle de 9 valeurs | intervalle de 11 valeurs | inconnus |
| Suivi approfondi | intervalle de 5 valeurs | intervalle de 5 valeurs | connus |

Les intervalles sont inclusifs, asymétriques, déterministes, bornés de 0 à 100 ; cinq valeurs signifie `max-min=4`. Le niveau au poste reste exact seulement dans notre club. Toutes les copies publiques portent `rating`, `ratingRange`, `potential:null`, `potentialRange`, et `knowledge:{version:1,owned,stage,observedAt}`. Les alias de rapport et les textes ne doivent pas réintroduire une note exacte.

Une mission distincte terminée constitue une observation ; deux missions distinctes donnent le suivi approfondi. Une rencontre terminée réellement jouée par notre club compte également, seulement pour ses participants dont les minutes sont strictement positives. Les rencontres mondiales simulées, la shortlist et la découverte ne comptent pas. Les commandes de formation payantes produisant réellement un rapport comptent également ; une découverte seule ne compte pas.

Les intervalles extérieurs sont figés à l'observation. Le suivi approfondi reste dans le premier intervalle si les vraies notes n'ont pas changé. Le potentiel du club utilise un intervalle stable, qui change seulement quand le vrai potentiel évolue. Un départ de notre effectif conserve une connaissance approfondie sous forme d'intervalles, jamais une ancienne valeur exacte.

Un manifeste `playerKnowledge` facultatif et versionné conserve les observations après la rotation des rapports. Il est validé strictement et borné à 2 000 joueurs, avec deux jetons d'événement par joueur. Une capacité atteinte produit un refus explicite et transactionnel, sans oubli silencieux. Les anciennes sauvegardes restent lisibles : les rapports archivés peuvent fournir une première connaissance sans écrire ni migrer le document pendant une consultation. Aucune lecture ne consomme de RNG ni ne crée de manifeste.

Le choix d'une projection unique finale évite la divergence entre les vues. Modifier chaque interface séparément laisserait des fuites dans les rapports et aperçus ; filtrer seulement Godot laisserait les vraies notes dans le protocole. L'implémentation conserve les prix et salaires métier existants.

Le hash utilise la graine immuable `careerVariation.seed` quand elle existe, sinon l'identifiant d'édition et celui du joueur. Il ne lit jamais la graine RNG vivante du worker.
