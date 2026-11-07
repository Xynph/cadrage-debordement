# Rugby Réel V15 — 47 potentiels sans marge, observation native

## Objectif et méthode
La PR #388 a vérifié **47/1592** joueurs dont la marge de potentiel de carrière recalculé est nulle, sans conclure à une anomalie. Ce lot n'ajoute aucune note et n'abaisse aucun niveau : il observe une vraie carrière TOP14 du moteur existant et les sauvegardes natives.

Le test `tests/rugby-real-zero-room-native-v15-20261107.cjs` recalcule la liste exhaustive des 47 identifiants à partir du catalogue actif `dist/lnr-ratings-v12.js`. Il démarre une carrière réelle LNR dans `tests/harness.cjs`, vérifie `dev.potential` après initialisation, puis déroule **6 saisons natives**, 26 journées régulières et les phases finales par saison, avec export/import `createSaveDocument` / `parseSaveDocument` après chaque changement de saison (6 passages). Pour chacun des joueurs de la cohorte **instanciés dans le TOP14 jouable**, il enregistre individuellement âge, note, potentiel, vitesse, force, décisions, activité, présence/absence et club, en fin de saison et après reprise de sauvegarde. Les événements de changement de club et de sortie d'effectif sont mesurés ; les mécanismes de recrutement natifs restent inchangés.

## Limite fondamentale
Le jeu LNR ne simule actuellement que les **14 clubs TOP14** comme carrière active. Les joueurs de PRO D2 présents dans le catalogue mais non instanciés ne peuvent pas avoir de vraie trajectoire multi-saisons observée par ce banc sans modification du moteur ou des effectifs. Le test rapporte explicitement les 47 identifiants et le nombre absent de la carrière native plutôt que d'inventer des parcours.

La carrière conserve les mêmes équipes, paramètres et lois que le jeu : aucune modification de moteur, mutation du registre, recrutement forcé ou transfert factice. Les statistiques publiées dans les logs ne valent preuve de recrutement que lorsqu'un changement de club est réellement observé. Un départ d'effectif n'est pas automatiquement une retraite, ni une preuve d'erreur de potentiel. Les joueurs survivants sont affectés par le biais de sélection.

## Critères de décision
Ne proposer un ajustement individuel de potentiel que si le joueur présente une incohérence de progression **répétée et reproductible sur des saisons natives**, non expliquée par l'âge, l'absence de temps de jeu, l'évolution des 36 attributs, le départ du club ou la disparition à la retraite. Une marge de note nulle n'est pas un motif suffisant. Les 47 dossiers restent initialement `no-change / observation`. Les tests doivent être reçus sur le SHA final de la PR avant toute conclusion empirique.

## Gouvernance
Base `main` au démarrage : `044e83d2a9f860d59c2aeac2a22df94235bf04c9`. PR DRAFT strictement diagnostique. Fichiers nouveaux exclusivement : ce rapport, le test dédié et son workflow. Aucun `dist/**`, master, DATA/LNR, effectif, identité, club, calendrier, interface, MATCH3D, moteur, sauvegarde ni autre PR modifié. Sans fusion.

## Exécution
`node --test tests/rugby-real-zero-room-native-v15-20261107.cjs`

Le workflow GitHub `Rugby Reel - zero-room native V15 QA` exécute la commande sur GitHub Actions. Ne pas revendiquer un résultat avant consultation des logs terminaux.
