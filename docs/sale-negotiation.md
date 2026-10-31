# Négociation des offres de vente
Le joueur peut demander +5 %, +10 % ou +15 % lors de l'examen d'une offre de transfert déjà reçue dans l'onglet Ventes. Le club IA accepte si la somme reste compatible avec sa trésorerie (réserve de 350 000 €) et l'urgence de son besoin au poste, ou retire immédiatement son offre. Les montants sont arrondis par tranches de 10 000 €. Les montants sont fictifs.

Une seule contre-proposition est possible par offre. Aucun transfert, changement de joueur ou paiement n'a lieu avant le bouton de confirmation original. Si la négociation aboutit, le montant final est bien celui payé par le club acheteur et crédité au club vendeur.

Compatibilité : aucun champ nouveau ajouté aux offres ou aux sauvegardes ; la contre-proposition est identifiée par un suffixe dans l'ID de l'offre. Les anciennes offres restent valides. Aucune mutation des règles de rugby, aucune modification du marché libre concurrentiel PR #95. Les offres expirent toujours comme auparavant. Attention : le suffixe de l'identifiant est une convention fonctionnelle de cette version, à vérifier lors de la revue.

Tests ciblés : `node tests/sale-negotiation.cjs`, `node tests/economy.cjs`, `node tests/saves.cjs`. Validation CI complète et contrôle de compatibilité requis avant fusion.
