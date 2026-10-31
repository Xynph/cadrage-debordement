# Bureau du manager — alertes contextuelles
Cette amélioration complète les priorités affichées dans le bureau existant, sans nouvelle interface ni données sauvegardées.
- Rapports d'observation produits lors des deux dernières journées de la saison : raccourci vers les rapports de recrutement.
- Missions de scouting en cours : raccourci vers les missions existantes.
- Au moins trois titulaires sous 65 % de condition : conseil de consulter la préparation, uniquement hors match et avant la fin de saison.
- Les alertes initiales (feuille à 23, contrats expirants, offres, blessés, trésorerie) sont préservées et non dupliquées.

Les alertes sont calculées à la consultation, ne déclenchent aucune transaction, ne lisent aucun attribut secret et n'ajoutent aucun champ aux sauvegardes. Le seuil de fatigue est un **conseil fictif de gestion**, pas une règle de rugby ni une modification du moteur. Les rapports ne sont pas automatiquement marqués comme lus.

Test : `node tests/office-alerts.cjs`. Les suites et la CI de la PR devront être vérifiées par leur verdict réel.
