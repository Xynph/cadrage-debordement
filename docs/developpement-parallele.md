# Développement parallèle

1. Consulter `main` et les PR pertinentes sur GitHub. Partir d’une base vérifiée
   sur une branche dédiée.
2. En cas de travail simultané, comparer les chemins et les interfaces avec
   les chantiers actifs. Ouvrir ou actualiser la PR en brouillon avant de
   modifier un périmètre partagé. Signaler le recouvrement ou la dépendance
   dans sa description et suspendre les écritures concernées jusqu’à
   résolution. Poursuivre sur les parties indépendantes.
3. Exécuter les tests ciblés. Vérifier la rétrocompatibilité des sauvegardes
   si le format, l’import ou la reprise change. Renforcer les validations
   pour les migrations, la sécurité, les règles du rugby, les finances
   sensibles, l’architecture et les données réelles.
4. Publier la branche et vérifier son HEAD sur GitHub. Actualiser la
   description de la même PR avec les résultats et l’état de la livraison.
5. L’intégrateur vérifie l’absence de conflit, le `main` courant, le HEAD exact,
   les contrôles exigés et les protections serveur. Il utilise le gate
   officiel en production selon [sa procédure](chat-release-gate.md), y compris
   si une autorisation spécifique est exigée. En cas de contrôle rouge,
   manquant ou en attente, indiquer le blocage dans la PR. Vérifier la CI du
   commit fusionné avant d’annoncer la livraison validée.

## Passation dans la description de la PR

- **Périmètre** — résultat attendu, chemins concernés et HEAD vérifié.
- **Collisions** — uniquement si plusieurs chantiers se recoupent. Indiquer la
  PR concernée, les chemins ou interfaces partagés et la décision à prendre.
- **Tests** — résultats effectivement observés, échecs, contrôles non exécutés
  et lien GitHub pour la CI du HEAD. Indiquer si la CI est en attente.
- **Prochaine action** — geste précis pour reprendre, intégrer ou lever un
  blocage, avec l’état de la fusion si elle a eu lieu.

La passation vit dans la PR du brouillon à la livraison. L’[issue #73](https://github.com/Xynph/cadrage-debordement/issues/73)
et le [journal de développement](../DEVELOPPEMENT.md) restent des archives de
coordination. Mettre à jour le journal seulement si une décision durable ou
une information de référence change.
