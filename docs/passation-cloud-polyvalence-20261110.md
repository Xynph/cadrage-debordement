# Reprise Cloud — 10 novembre 2026 : polyvalence, Tactique et information joueurs

## Situation de l’environnement — incident résolu
Le Cloud est devenu indisponible pendant les dernières réceptions, puis est revenu avec les worktrees préservés. Les paragraphes de coupure ci-dessous sont historiques ; voir la mise à jour de réception en fin de document. Le service indique offline ; wait_for_environment refuse car l’environnement n’est ni prêt ni starting utilisable. Ne pas annoncer le raccord sportif terminé. Préserver les worktrees et fichiers non committés avant toute opération Git ou reconstruction.

## Dernières demandes de Léo
- Cloud uniquement, 2560×1440 ; interface dense type FM, textes petits, aucun grand vide, portraits utiles.
- Salaires affichés arrondis à la centaine, sans décimales ; préférence hebdomadaire/mensuelle/annuelle conservée.
- Fin de contrat en année civile (S1 interne → 2027), couleurs niveau vert et potentiel orange uniformes.
- Note au poste supprimée de l’Effectif ; elle n’appartient qu’à la feuille tactique.
- Deux colonnes Effectif : Poste principal, Autres en numéros avec noms au survol.
- Polyvalence calculée comme mécanique de jeu, SANS étiquette d’estimation dans l’interface.
- Dépannage permis hors première ligne : pilier au 10 avec forte chute de note et efficacité réellement dégradée en match ; niveau permanent inchangé.
- Tactique EXISTANTE conservée : portraits + numéros + notes sur le terrain à gauche ; Banc et Hors groupe simultanés juste à droite du terrain ; Identité de jeu à droite. Hors groupe remplace Joueur sélectionné. Listes défilantes internes, glisser-déposer et alternative clavier/clic.
- Nouvelle demande à cadrer : niveau exact des joueurs du club ; niveau inconnu avant observation à l’extérieur, puis toujours une fourchette jusqu’au recrutement. Potentiel JAMAIS exact : fourchette immédiate pour notre club, seulement après observation pour les autres.
- Nouvelle demande : outil de variation légère de niveau/potentiel pour TOUS les joueurs de la BDD à chaque nouvelle carrière.

## Proposition information / variété, pas encore implémentée
Proposition adressée à Léo : première observation niveau large ~68–80, potentiel ~72–90 ; observation approfondie niveau ~75–79, potentiel ~80–87 ; minimum d’incertitude 3–4 points en niveau extérieur, 6–8 en potentiel. Fourchettes stables entre observations, pas systématiquement centrées sur la vraie valeur. Précision liée au recruteur, durée et matchs observés. Appliquer partout, sans fuite dans fiches/comparateurs/infobulles/projections secondaires. Niveau exact révélé au recrutement, potentiel toujours en fourchette.
Variation proposée : niveau jusqu’à ±3, potentiel jusqu’à ±5, distribution concentrée sur petites variations ; qualités cohérentes en match ; une seule génération à la création avec graine persistée ; recharger ne reroule jamais ; carrières existantes inchangées ; choix BDD fixe / Variation légère à la création, légère par défaut. Attendre le retour de Léo sur ce calibrage avant de traiter cette proposition comme un réglage validé. Ne pas ajouter ces chantiers aux fichiers partagés en parallèle avant réception de la polyvalence.

## Déjà publié et reçu
PR #520, branche cloud/oval-lot2-gestion-1440-20261110.
72ade9099e874ece1ae017ff7ab8e9c2cf8a78be : salaires à 100 €, années, couleurs uniformes, suppression Note. Suites 48 / 109 graphiques / 153 / 43 sans échec. Capture publique :
docs/oval-lot2-cloud-1440-20261110/effectif-annees-centaines-sans-note-1440.png
d175323 : capture de Tactique AVANT nouveau cadrage :
docs/oval-lot2-cloud-1440-20261110/tactique-existante-1440.png
Aucune fusion de main. Main vérifié : 978803ba727e51c5af23f458868c6d56cc878966.

## Intégration en cours
PR #529, branche cloud/oval-polyvalence-tactique-20261110, base #520.
HEAD distant vérifié avant cette passation : 277b0a2f83092fb367f8628255654f83c34b9283.
Il contient plan + première UI des deux colonnes Effectif. Des commits supplémentaires sont présents dans le dépôt local mais N’ONT PAS été poussés avant coupure :
7e562eb = cherry API c45557e
ccd6301 / 041e504 = banc/doc/captures Effectif
00d9b89 / 272e6d5 = frontend Tactique et cadrage
Ne pas confondre commit local et publication GitHub. Le futur fetch de cette passation fera diverger la branche distante d’un commit documentaire ; réconcilier sans écraser les commits locaux.

## Producteur moteur : work/polyvalence
Branche cloud/polyvalence-native-20261110, base72ade90.
API locale c45557e : position-aptitudes.cjs + worker/model + tests, 12 assertions canoniques reçues.
API : primaryPosition, secondaryPositions, positionRatings (numéros1–15), qualifiedFrontRowPositions ; selection.slots[].positionNumber.
Le raccord SPORTIF reste NON COMMITTÉ :
native/engine/{position-aptitudes,worker,gestion,international-callups,international-career,international-native}.cjs
tests/native-position-{aptitudes,integration,match,editions,japan-registration}.cjs
Derniers résultats reçus : common20 assertions export/import/restart ; match/replay11 ; 21 régressions ; 3 tests attributs. Deux matchs depuis même état/RNG strictement identiques, lock légalement entré au8, première ligne après carton respectée.
Derniers tests Japon/Nationale lancés, résultats non récupérés ; sessions perdues36790 et g7:183.
Logs /tmp/poly-{integration,match,regressions,attributes,editions}.tap.
À faire : relire résultats, finir tests Japon/Nationale, docs/benchmark, revue puis commit et push sportif.
Points corrigés en cours : activeClub(S,team.id), calendrier du bon club pour libérations, vue éphémère de famille active dans strategicPlayerScore pour éviter double malus. Réserver les six spécialistes de première ligne avant auto-composition. Pas de nouvelle qualification1/2/3 déduite des attributs.

## Producteur UI Effectif
PR #526, HEAD annoncé vérifié e95fa34a8918a3bafe3326db4821f4ac09bb1702.
Commits87cc9be,d125f4c,0304ada,e95fa34.
180 headless vraie API,186 graphiques1440,33 profils natifs sur40 ;179 fallback et105 tri/scroll.
Photos et notes générales inchangées, Autres en numéros bleus + noms au survol ; aucune formule de polyvalence UI.
Source privée work/squad-secondary ; worker QA APIc455 ignoré par Git.

## Producteur UI Tactique : work/tactics-position-drag
Branche cloud/tactics-position-drag-20261110.
PR #528 distant vérifié : ce84555c76ebbb8676845502d6f4180502307089 (plan/test initial seulement).
f2f49a8 est COMMITTÉ LOCALEMENT mais introuvable sur GitHub lors du contrôle après coupure : pousser ce commit après reprise, il contient le vrai cadrage.
Ne pas recherry b69bbe1 : copie locale d’APIc45557e.
192 contrôles graphiques et261 actions reçus : 15 portraits+notes,105 paires de hitboxes sans intersection ; échange ailier11→14 réel, Échap annule sans commande/écriture, clavier depuis Hors groupe.
Nouvelle image locale :
work/tactics-position-drag/docs/tactique-polyvalence-20261110/tactique-portraits-horsgroupe-1440.png
Également cherry locale root docs/tactique-polyvalence-20261110/.
Recette supplémentaire banc→terrain/horsgroupe→terrain/live NON VÉRIFIÉE et tests NON COMMITTÉS. Recevoir avec le commit sportif final.
Annulation : gui_cancel_drag consomme Échap avant raccourci Pause. Les boutons existants Consignes sont à vérifier après remplacement de Joueur sélectionné.

## Réception root à reprendre
Root /workspace/cadrage-debordement. Node22 et Godot4.7.2 dans /workspace/.cloud-setup/tools/.
Profils QA /tmp hors application, caches Godot séparés par worktree. Aucun SDK concurrent sur cache root.
Avant nouveau rendu : stage, import et contrôle des erreurs de compilation avant les longues suites. Capture réelle 2560×1440 ; publier PNG puis lien raw GitHub (les images outils seules ne sont pas visibles chez Léo).
Loi3 World Rugby consultée :3.10 postes de première ligne désignés ;3.11 un remplaçant de première ligne peut débuter ailleurs ;3.12 formation et expérience. Préserver les protections existantes.
Revue indépendante déjà transmise : vérifier banc, remplacements, international, hooks Nationale/Japon et calculs collectifs selon slot actif sans muter pos/fam sources. Sauvegarde/état/RNG doivent rester déterministes.

## Mise à jour après reprise — polyvalence reçue

La passation distante a été fusionnée sans écraser les commits locaux. API c45557e et sport2a1f767 sont intégrés ; UI f2f49a8, bd003b5, ee05e55 et captures9e57394 également. Root reçoit cinq suites natives sans échec puis les deux bancs UI X11 cumulés (Tactique et Effectif). Rapports et captures dans docs/polyvalence-cumulative-20261110/. Le n°10 reprend effectivement une note très faible pour un pilier, la première ligne source est laissée à compléter, et les projections collectives et Défense suivent le nouveau poste.

La demande connaissance/variation est maintenant explicitement approuvée par Léo : observation initiale9 valeurs de niveau/11 de potentiel ; approfondie5/5 ; club niveau exact/potentiel5. Variation PA toujours active, CA facultative cochée par défaut. Les agents travaillent dans des branches indépendantes après la base sportive803db66 ; ne pas confondre ces travaux en cours avec le lot polyvalence reçu.

Main a avancé à283ecd0 (PR525, lieux/causeries). Le présent lot reste volontairement empilé sur520 ; le raccord au main courant et le gate officiel restent des opérations d’intégration distinctes.
