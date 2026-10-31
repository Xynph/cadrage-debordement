# R5 — Contrat de convergence R1–R4

**Situation GitHub au départ :** PR #97, #99, #100 et #101 toujours ouvertes et non fusionnées. PR #98 de l'intégrateur réservant `dist/index.html` et `dist/game.js`. Ne pas raccorder directement au jeu avant leur réception.

## Décision d'architecture

Conserver **un seul gestionnaire d'univers** pour l'intégration finale :
- **R1** : schéma de catalogue mondial et données fictives d'essai, sans réalités officielles dans le jeu de base ;
- **R4** : installation ZIP et stockage de fichiers dans l'application locale (à durcir avant exposition publique) ;
- **R3** : validation SHA réelle et composant navigateur, à convertir en *vue* du gestionnaire commun, pas en deuxième registre ;
- **R2** : contrat manifeste/dépendances, à faire converger avec la validation R1 ;
- **R5 `universe-contract.cjs`** : contrat testable pur de sélection de monde, dépendances, collisions d'entités et compatibilité des nouvelles sauvegardes.

## Garanties et limitations
`createUniverse(base)` travaille sur une copie du monde fictif. `install(pack)` prépare une collection **en mémoire**, `select(ids)` valide dépendances et conflits avant activation, `reset()` restaure le monde fictif, `prepareNewCareer(config)` ajoute `modBinding` seulement lors de la création d'une **nouvelle** carrière, `checkCareer(save)` reconnaît les sauvegardes historiques sans champ mod et les autorise uniquement en monde non modé. Les versions exactes de packs doivent correspondre.

Le moteur actuel et les vrais fichiers de sauvegarde ne sont pas modifiés. La partie ne devient pas jouable avec mods par cette PR seule. Prévoir une migration explicite, facultative et sauvegardée lors de l'intégration, sans mutation silencieuse des anciennes parties.

## Tests
`node tests/mod-unified-r5.cjs`. Cas : base non modifiée, activation volontaire, contrats de versions, conflit, dépendance, retour à la base et ancienne sauvegarde.

## Passage à R6
Après validation CI et réception par l'intégrateur des PR R1–R4, brancher une unique interface dans le jeu avec tests Chromium : installer depuis fichier, sélectionner univers à la **création** de carrière, reprendre une carrière avec contrôle de packs et restaurer le mode fictif. L'intégrateur peut décider de fermer/remplacer des composants concurrents après avoir comparé leurs tests. Aucun contenu réel n'est distribué par le jeu de base.
