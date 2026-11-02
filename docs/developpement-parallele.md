# Développement parallèle sûr — Cadrage Débordement

**Décision du 2 novembre 2026.** Léo autorise deux développeurs GitHub simultanés sur des branches et fichiers compatibles. Source de coordination : [issue #73](https://github.com/Xynph/cadrage-debordement/issues/73#issuecomment-6573792553). Le présent document complète `AGENTS.md` ; aucune protection technique n'est désactivée.

## Modèle de travail

1. **Avant de coder :** consulter une fois le main et son SHA, AGENTS.md, l'issue #73 et les PR actives. Publier une prise de chantier courte indiquant le rôle, la branche, le SHA de base, les fichiers ou motifs de chemins réservés, les dépendances et exclusions.
2. **En parallèle :** chaque producteur écrit sur sa branche et ses chemins. Les tests, captures et PR indépendantes peuvent s'exécuter simultanément. Ne pas traiter l'absence de chevauchement nominal comme une preuve de compatibilité : vérifier les API, les imports, les sauvegardes, les workflows et les données partagés.
3. **Conflit :** si deux chantiers nécessitent le même fichier, un contrat partagé incompatible ou une mise à jour de branche concurrente, STOP sur la zone touchée, signaler la collision dans #73 et choisir un propriétaire du fichier ou un ordre d'intégration. Ne jamais forcer un push pour résoudre le conflit.
4. **Livraison :** lot cohérent, tests ciblés locaux lorsque possible, un commit final stable, une PR, CI sur le HEAD exact. Passation courte dans #73 précisant SHA, chemins, tests réellement exécutés, sauvegardes, dépendances, risques et chemins libérés. Les verdicts pending ne sont pas verts ; ne pas multiplier les consultations.
5. **Intégration unique :** un seul intégrateur intervient sur les opérations de fusion à un instant donné. Pour chaque PR : autorisation explicite de Léo pour la PR et son HEAD, vérifications du main/HEAD et de la CI complète, `/cd-check`, puis procédure officielle `/cd-merge` avec SHA verrouillé. Après fusion, sept jobs obligatoires de la CI post-fusion réussis avant clôture. Aucun bypass et aucun push sur main.

## Priorités et cas concrets

- Les modifications de `AGENTS.md` et des guides de coordination se font dans une PR dédiée. Si `DEVELOPPEMENT.md` est déjà réservé par une PR, ne pas le modifier en parallèle : consigner la passation dans #73.
- Le lot V17 sur PR #209 utilise ses propres fichiers d'interface et de tests. La coordination documentaire n'y touche pas. Toute modification ultérieure de son adapter/API commune doit être coordonnée.
- La PR Fast Lane #208 est indépendante : son bilan rapide reste **informatif**, jamais un remplacement du release gate ni de l'autorisation de fusion.
- Les fichiers `dist/`, les sauvegardes, DATA et Business restent soumis aux restrictions spécifiques de chaque chantier.

## Contrôles de réussite

Sur les trois prochaines évolutions jouables, mesurer les conflits évités, le délai demande → PR prête, le délai PR verte → intégration, le nombre de vérifications manuelles et les éventuelles CI redondantes. Objectif : moins de coordination et d'interruptions, **sans réduire les tests obligatoires**.

Cette politique ne modifie ni règles GitHub côté serveur, ni secrets, ni permissions, ni moteur de jeu.
