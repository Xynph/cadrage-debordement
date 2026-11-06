# Économie V2 E2.8 — arrêt brutal, reprise supervisée et concurrence (R&D)

**Module uniquement expérimental, non importé par le jeu.** Empilé sur PR #347, sans édition des modules E1–E2.7 ni des sauvegardes natives. Toute facture de test et son règlement appartiennent à un monde financier isolé. Aucune dette préexistante reconstituée, aucun mécanisme financier punitif ajouté au joueur.

## Tests de crash authentiques

Les enfants Node.js sont tués par un véritable signal **SIGKILL** exactement sur l'appel `fs.renameSync` de la transaction de règlement :
- **avant rename** : le fichier source reste intégralement non payé ; verrou orphelin fail-closed ; après approbation de reprise, l'opération peut être rejouée avec un seul débit ;
- **après rename** : le fichier contient le registre E1 **et** le reçu E2.5 réglés ; après récupération manuelle du verrou, le même paiement ne débite pas une seconde fois.

Cela vérifie une interruption du **processus**, pas le crash du noyau, du contrôleur ou une panne de courant avant synchronisation de l'entrée de répertoire. L'ordre fsync/rename/fsync du module E2.7 reste la seule hypothèse de durabilité au niveau filesystem local. Aucune garantie de NFS ou Windows.

## Supervision des verrous

`ci/economy-v2-crash-supervisor.cjs` ne supprime jamais automatiquement un verrou. `recover` requiert une autorisation **explicite** en callback ainsi que PID, host local, révision du stockage et empreinte inchangée, plus absence de processus propriétaire vivant selon `kill(pid,0)`. Les métadonnées inode/dev du verrou et de son propriétaire sont vérifiées une deuxième fois pour repérer les changements durant l'approbation. Un PID réutilisé reste bloquant, et un propriétaire étranger n'est pas automatiquement récupérable. Une autorisation dans ces tests est une fixture opérateur, pas une authentification métier.

Limites : l'absence de PID ne prouve pas que tous les descripteurs distants sont fermés, l'identité par PID peut être recyclée, et les contrôles de filesystem n'empêchent pas un acteur hostile ayant les permissions d'écriture. Un outil de production nécessiterait une autorité de récupération et un protocole durci.

## Concurrence et garanties de paiement

Douze véritables processus Node indépendants tentent des règlements simultanés de douze factures explicitement préparées. Le répertoire verrou exclusif sérialise les écritures. En cas de verrou présent, un appelant contrôlé réessaie de manière bornée, sans supprimer le lock ni transformer une erreur métier en succès. Résultat attendu : douze reçus, douze écritures E1 correspondantes, cash initial moins la somme exacte, zéro double paiement et registre validable après fermeture de tous les processus.

Les tests rejettent les montants modifiés, signatures d'une autre clé, faux reçus, rejouages contradictoires, verrou d'un PID vivant et verrou d'hôte différent.

## Campagnes et jouabilité

Workflow : `reference / modeste / alternatif × 827381 / 99173`, soit six campagnes natives × quinze saisons, trois imports natifs chacune. La parité des états sauvegardés et checksums est contrôlée et les sorties sont six JSON. La dette historique non observable reste inconnue : aucune conversion implicite en payable. Les scénarios de crise testent le refus atomique d'une dépense insolvable, et ne modifient ni les règles de salaires ni la difficulté du jeu.

**Non couvert** : attestation par une autorité réelle et gestion permanente des secrets, robustesse à corruption disque malveillante, essais Windows, longues saturations de plusieurs milliers de workers, crash noyau/disque, conception UX de crises récupérables sur données réelles. Ce lot ne permet ni READY ni fusion ni activation de l'économie V2.
