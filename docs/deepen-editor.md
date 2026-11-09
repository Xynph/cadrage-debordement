# Compétition fictive jouable depuis l’atelier

## Conception et contraintes
Le moteur historique simule 14 clubs, 26 journées aller-retour et ses phases finales. Les autres tailles ne sont pas adaptées à ce moteur : leurs calendriers restent échangeables. Une compétition personnalisée de 14 clubs reprend effectifs, économie et règlement abstrait historiques ; seuls les noms des clubs, leurs abréviations et les paires du calendrier changent. Les couleurs, installations, budgets et niveaux initiaux restent ceux des quatorze emplacements fictifs.

La création exige une confirmation et le choix du club, refuse un match en cours et passe par la transaction atomique du worker. Elle n’édite aucune carrière en place : elle crée une nouvelle carrière qui remplace la carrière courante après l’avertissement explicite. Un marqueur `customCompetition` conserve nom, identités et calendrier. La validation refuse mode réel, identité divergente, calendrier différent ou incomplet et métadonnées inconnues. À la saison suivante, le calendrier personnalisé est réappliqué, sans changer les règles de phases finales. Les sauvegardes sans marqueur suivent exactement leurs validations antérieures.

Les packs d’identités réelles sont incompatibles avec cette compétition fictive. Les noms de carrière respectent les caractères autorisés par les sauvegardes ; les caractères de balisage réservés restent possibles dans un simple export mais empêchent son lancement jouable, avec explication.

## Plan
- [ ] Ajouter tests de document14clubs, identités, calendrier et refus avant création.
- [ ] Implémenter domaine strict et hook annuel ; raccorder validateur d’identité avec accord root.
- [ ] Ajouter sélection du club, capacité jouable et confirmation dans l’atelier.
- [ ] Réceptionner vrai worker : création, import/reprise, saison complète et saison2 ; ancienne carrière intacte après refus.
- [ ] Réceptionner vrai Godot et documenter résultats/limites.
