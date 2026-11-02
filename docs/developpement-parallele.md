# Développement parallèle — cycle court

**Décision de Léo du 2 novembre 2026** : deux comptes producteurs peuvent écrire simultanément sur branches et chemins compatibles. Un seul intégrateur gère les fusions. Le propriétaire donne une autorisation générale pour les **fusions ordinaires**, sans demande répétée à chaque PR.

## Cycle de travail par lot

1. Consulter une fois le main et l'issue #73 ; signaler les chemins réservés seulement en cas de travail simultané ou d'interface partagée.
2. Développer un lot fonctionnel sur une branche dédiée, sans toucher aux DATA ou aux fichiers réservés par l'autre chantier.
3. Exécuter les tests ciblés. Préserver les sauvegardes : tests de rétrocompatibilité en cas de changement de schéma/import. Ne jamais présenter « non exécuté » comme « réussi ».
4. Publier une PR avec HEAD et résultats vérifiés, puis transmettre une passation courte. Éviter de relire plusieurs fois les mêmes workflows.
5. L'intégrateur juge l'utilité, écarte les doublons, vérifie l'absence de conflits et applique le chemin de fusion techniquement autorisé. Aucune revue externe n'est exigée comme condition **interne** nouvelle.
6. Après livraison, bilan concis : fonctionnalité, tests, commit de main, risque éventuel. Si la CI obligatoire ou les protections refusent la fusion, STOP technique documenté.

## Déploiement du nouveau régime

Ce fichier et AGENTS.md fixent la **politique humaine voulue**. Ils ne modifient pas les protections serveur ni `ci/release-gate.cjs` : le gate historique peut encore exiger une autorisation spécifique ou une CI complète. Une PR séparée devra adapter le gate et ses tests de sécurité pour autoriser le cycle de fusion autonome sur les travaux ordinaires. Ne pas utiliser d'API directe ou de bypass pour esquiver un refus de ce gate avant cette adaptation.

## Exceptions

Renforcer les validations pour migration de sauvegardes, sécurité, règles du rugby, finances sensibles, changements d'architecture et données réelles. Ne pas fusionner deux branches concurrentes sans résoudre leurs dépendances. Pas de push direct vers main ; ne pas effacer les preuves d'intégration.
