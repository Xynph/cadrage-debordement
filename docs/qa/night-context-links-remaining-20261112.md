# Navigation contextuelle restante : alertes, séances, rencontres et composition

Relevé ciblé sur le candidat commun **`d896d631bd2ea141283c0e09609695a547a6b200`**.
Inspection du code uniquement. Aucun produit, import Godot, test SDK ou moteur
n'est modifié/exécuté dans cette tranche. Ce tableau ne remplace pas la recette
fonctionnelle de chaque nouveau lien et ne constitue pas un audit de Claude.

L'intégrateur a signalé pendant ce relevé le passage de `main` à `eb2b1833`
par fusion de #550 : le socle, ses tests/documents et l'activation conditionnelle
`SocleEffectif.actif` dans le shell sont distincts de ce candidat commun. Le
socle reste OFF par défaut selon la coordination. Il n'est ni modifié ni reçu
par cet inventaire ; les observations ci-dessous portent sur les écrans du SHA
commun indiqué, sans leur substituer un résultat de ce nouveau main.

## Trois suites prudentes immédiatement utiles

1. **Exemple d'alerte physique du Bureau** : le texte à
   `office_canvas.gd:199–204` est produit depuis un vrai joueur de `model.squad`.
   Le clic peut ouvrir ce joueur par ID, en gardant l'action existante qui ouvre
   toute la liste des joueurs à surveiller.
2. **Identités et dates du prochain match / frise du Bureau** : les clubs et
   fixtures sont déjà des dictionnaires structurés ; ouvrir le club ou le jour
   exact ne demande aucune nouvelle donnée. Garder Préparer le match comme
   action séparée et ne jamais remplacer cette lecture par `primary_action`.
3. **Résultats récents du Bureau** : score, adversaire et fixture viennent du
   calendrier joué. Réutiliser les fiches existantes par ID exact lorsqu'elles
   sont disponibles ; aucun rapprochement de score ou de nom n'est nécessaire.

Les alertes médicales du courrier historique, en revanche, ne disposent pas
d'un `playerId` : leurs textes seuls ne permettent pas cette même amélioration.

## Notifications, alertes et promesses

| Surface et source précise | Liens déjà présents / parent | Identifiants réellement disponibles | Proposition ou limite |
| --- | --- | --- | --- |
| Courrier historique, `native/godot/ui/immersive08/reception_canvas.gd:56–75` | Les lignes sélectionnent le courrier ; le corps est un texte dans un ScrollContainer (`:514–524`). Le bouton de dossier générique existe (`:599–607`). | `model.messages` est un tableau de strings. L'UI crée un ID de réception par hash du texte et occurrence ; aucun joueur, blessure, promesse ou fixture n'est identifié par ce contrat. | **Impossible de viser un joueur précisément dans ce contrat.** Garder l'ouverture du dossier pertinent. Pour de futurs messages structurés, prévoir type + ID métier publié sans modifier les citations historiques. Ne pas extraire une identité d'une phrase. |
| Journal du Bureau, `native/godot/ui/immersive08/office_canvas.gd:238–252` | Snippets statiques ; bouton Tout le courrier vers Réception. Aucun parent cliquable sur chaque snippet. | Les mêmes strings historiques, sans ID d'entité. Les IDs de réception sont construits ailleurs, pas portés par ces cartes. | Une ouverture du courrier exact demande un partage du mapping de réception texte/occurrence, pas un lien joueur déduit. Une simple route Réception ne garantit pas le bon message. |
| Exemple d'alerte physique du Bureau, `office_canvas.gd:196–207` | Action de liste `OfficeWatchedAction` déjà vers le groupe surveillé ; exemple nom + raison statique à `:202`. | La boucle parcourt `model.squad` et dispose de `player.id`. | **Lien joueur sûr à ajouter** sur cet exemple si le contrôleur accepte l'ID. Garder l'action collective et le texte de raison. |
| Échéances actuelles depuis un courrier, `reception_canvas.gd:338–355` et `:382–383` | Les cartes `InboxExpiryPlayer_*` sont déjà des boutons, portrait et nom enfants ; ouverture commune vers le joueur, section Contrat. | IDs des échéances projetées recoupés avec squad. | **Existant : ne pas doubler les boutons.** L'étiquette dit bien Échéances actuelles ; elle ne prétend pas reconstituer les joueurs d'un courrier ancien. |
| Courrier de reprogrammation, `reception_canvas.gd:309–321` | `InboxContextFixture` ouvre la fixture exacte ou le calendrier sur `toDate`. | `calendar_notice.fixtureId` et `toDate`. | **Existant.** Les commandes Recaler/Conserver (`:577–583`) sont séparées du lien de consultation et doivent le rester. |
| Courrier international, `reception_canvas.gd:585–598`, `:623–630` | Bouton Sélections, offres, feuille de match ou retour effectif selon l'événement ; pas de clic distinct sur le nom de nation du corps. | `international_event.nation`, `id`, `kind` et `action`. | Ajouter éventuellement un accès de consultation à la nation exacte, distinct des offres/feuille. La clé `international_nation` actuelle sert au contexte d'offres ; elle n'est pas le nouveau ciblage de dossier `international.navigation_id`. Ne pas confondre mandat et consultation. |
| Contexte générique d'un ancien courrier, `reception_canvas.gd:322–328` et `:545–548` | Préparation du **prochain match** ou calendrier déjà accessibles. | `model.next`, indépendant d'un courrier historique dépourvu de fixtureId. | Ne pas présenter ce prochain match comme la rencontre historique du message. Un nouveau lien exact n'est possible qu'avec une référence structurée publiée. |
| Presse, `reception_canvas.gd:565–575` | Invitation exacte et reçu publié déjà utilisés ; bouton désactivé si invitation/contexte non concordants. | `press_invitation.id`, contexte et `lastOutcome.invitationId`. | **Existant et à préserver.** Aucune route Presse générique ni nouveau raccourci qui contournerait le courrier/invitation. |
| Promesses et engagements, `native/godot/ui/relationships_view.gd:89–113` | `RelationshipEventPlayerLink`, `RelationshipCommitmentPlayerLink` et `RelationshipHistoryPlayerLink` déjà présents. | `event.playerId`, `commitment.playerId`, `history.playerId`, validés contre squad par `:14–27`. | **Existant dans ce candidat.** Un joueur parti reste du texte ; aucun homonyme ni biographie absente n'est inventé. Les phrases archivées restent affichées séparément. |
| Blessure / promesse individuelle, `relationships_view.gd:178–210` | L'identité au-dessus dispose déjà des liens nom et portrait (`:45–68`). Les paragraphes parlent du même joueur. | `p.id`, blessure et promesse projetées. | Pas de seconde ouverture de la même fiche nécessaire sur chaque nombre. Les boutons Conversation/Promesse sont des décisions, pas des liens de lecture. |
| Priorités du Bureau, `office_canvas.gd:155–174` et `native/godot/ui/immersive08/office.gd:433–446` | Les titres sont déjà des boutons : dossier, match, sélection, finances, joueur de contrat, entraînement, etc. | Pour le contrat, `item.player`; pour les autres priorités, un type/action de dossier. | **Ne pas compter leurs enfants textuels comme absents.** Le helper joueur `office.gd:116–118` reste un accès direct à Effectif ; une migration vers le contrôleur commun améliorerait l'historique et la section Contrat sans changer la priorité ni déclencher de commande. |

## Entraînement et séances datées

| Surface et source précise | État réel | Identité / destination | Proposition ou limite |
| --- | --- | --- | --- |
| Vigilance physique de l'entraînement, `native/godot/ui/immersive08/training_canvas.gd:285–301` | Carte parent vers réglage individuel ; **zone du nom déjà liée** à la fiche par `TrainingRiskPlayer_*`. | Joueur squad par ID, garde `entity_available` dans `:325–330`. | Existant. Le reste de la carte conserve le réglage métier ; ne pas absorber ce callback dans la navigation. |
| Axes individuels, `training_canvas.gd:308–321` | Nom et portrait disposent déjà de `TrainingAxisPlayerName_*` / `TrainingAxisPlayerPortrait_*`. Parent vers réglage individuel. | ID projeté du professionnel, recoupé avec la destination disponible. | Existant, pas de deuxième overlay à ajouter. |
| Tableau individuel, `training_canvas.gd:380–398` | Colonne identité déjà dans `TrainingOpenPlayer_*`. Boutons de tri séparés ; le reste de la ligne ouvre le plan individuel. | Joueur squad par ID. | Existant ; conserver tri, molette de liste et différence identité/réglage. |
| Staff d'entraînement, `training_canvas.gd:332–350` | Nom et portrait déjà liés lorsqu'un membre a un ID accepté. Les cartes illustratives de repli restent sans cible. | `person.id` du staff projeté. | Existant. Un visuel de préparateur sans membre réel ne doit pas ouvrir le premier collaborateur de l'annuaire. |
| Cases du plan de semaine, `training_canvas.gd:173–196` et `:212–245` | Les cases `TrainingStep*` sont déjà des boutons sélectionnant un sujet ; le panneau Séance sélectionnée et son bouton ouvrent le réglage correspondant. | Index local de sujet (`SLOTS`), **pas** une séance datée du calendrier. | Parent déjà actif. Ne pas transformer l'index de sujet en sessionId ni prétendre ouvrir une séance future/historique. |
| Effectuer la séance, `training_canvas.gd:439–468` | Action métier explicite avec confirmation ou choix de charge ; `train` enregistre les effets. | Séance collective courante, une par semaine, sans ID de détail autonome. | Ne jamais utiliser ces callbacks pour un lien libellé Consulter une séance. |
| Séances du calendrier, `native/godot/ui/immersive08/month_calendar.gd:502–534`, `:641–668`, `:685–688` | Chips et lignes descriptives, pas de parent d'ouverture de fiche. | Sessions publiées avec `id`, `date`, `kind`, `label`, `forwards`, `backs`, éventuellement `fixtureId` ; contrat construit dans `native/engine/calendar-planning.cjs:79–85`. | **ID présent mais destination absente.** Ajouter un adaptateur de lecture par sessionId, relisant uniquement la session publiée et ses champs. Ne pas lier à l'entraînement courant à la place. Aucun moteur de calendrier à modifier en parallèle de Claude. |
| Entraînement de la semaine depuis le jour courant, `month_calendar.gd:693–694` et `:708–719` | Bouton existant seulement lorsque le jour sélectionné est aujourd'hui ; ouvre le sujet courant de travail. | Contexte d'aujourd'hui et état de lecture d'entraînement. | Existant et correctement borné. Ne pas supprimer la garde sur la date pour rendre artificiellement cliquables les séances futures. |
| Fil de préparation, `month_calendar.gd:771–782` | Séances liées au prochain match affichées en texte. | `session.fixtureId == next_fixture.id`, ID et date de chaque session conservés. | Même besoin d'adaptateur session que ci-dessus. Le contexte fixture connu peut ouvrir une rencontre, mais ne remplace pas le détail de la séance. |
| API commune d'entraînement, `native/godot/ui/navigation_controller.gd:482–483` | Accepte uniquement les identifiants vide ou `team`, puis la route Préparation. | Aucun lookup par sessionId. | C'est la preuve de limite de destination : ne pas annoncer un lien session reçu grâce à cette seule API. |
| Graphique charge par poste, `training_canvas.gd:258–270` | Barres et infobulles, pas de clic de détail. | Sous-ensemble réel de squad filtré par codes de famille ; moyenne calculée depuis physicalLoad. | Proposition P2 : ouvrir la liste exacte des membres du sous-ensemble, par IDs publiés, avec valeurs individuelles. Définir d'abord ce preset de lecture ; ne pas attribuer une cause au niveau moyen ni ouvrir un joueur arbitraire. |

## Prochaines rencontres et résultats du Bureau

| Surface et source précise | État réel | ID disponible et proposition |
| --- | --- | --- |
| Prochain match principal, `native/godot/ui/immersive08/office_canvas.gd:97–132` | Blasons, noms, compétition et date statiques ; boutons Préparer le match / Vérifier les 23 déjà présents. La carte est un Panel, pas un bouton global. | `model.next.home.id`, `away.id`, `next.id`, date et contexte de compétition. Club→fiche club ; date ISO→jour exact ; compétition seulement si son ID existe dans la projection de classement. Conserver les actions existantes distinctes. |
| Semaine exempte ou préparation, `office_canvas.gd:59–95` | Adversaire/date publiés sous certaines branches ; parfois uniquement une indication de préparation, sans fixture. | `P.next_nationale_fixture` / `P.next_scheduled_fixture` peuvent retourner une fixture réelle. Ajouter les liens seulement dans ces branches avec cible validée. En l'absence de fixture, conserver le texte, pas de prochaine rencontre inventée. |
| Frise Prochains matchs, `office_canvas.gd:278–331` | Date, nom et blason dans des Panels descriptifs ; seul Tout le calendrier est un bouton. Aucun parent cliquable sur une tuile. | Chaque `fixture` et `opponent` porte les données structurées nécessaires. Date→calendrier exact, nom/blason→club. Une éventuelle fiche de rencontre doit passer par le lookup exact, pas par la position de la tuile. |
| Résultats récents, `native/godot/ui/immersive08/office.gd:203–259` | Score dans PanelContainer, nom/blason adversaire et résultat statiques. Les parents ne sont pas des boutons. | Les fixtures proviennent du calendrier `played` avec score ; conserver leur `fixture.id` et `opponent.id`. Priorité utile : score→fiche rencontre existante, nom/blason→club si `entity_available`. |
| Vue Bureau compacte, `office.gd:682–722` | Même frise descriptive en conteneurs ; liens génériques de calendrier présents. | Réutiliser les mêmes identifiants et la même politique que la version canvas ; ne pas livrer les liens uniquement à une taille d'écran. |
| Contexte en direct du Bureau, `office_canvas.gd:137–153` | Noms/blasons et score statiques ; action primaire et Revoir le match existent, ce dernier visible après fin seulement. | Déterminer une vraie fixture avec l'identité conservée (`office.gd:18–33`), puis respecter le contexte de match en cours. Ne pas utiliser `primary_action` comme lecture : il peut faire avancer le parcours. Ne pas quitter une immersion obligatoire. |
| Calendrier : fiche de rencontre, `month_calendar.gd:739–768` | Blasons et nom adverse déjà liés ; score lié si fixture connue. Bouton Préparer ce match uniquement si la fixture correspond exactement au prochain match. | **Existant et précisément borné** par `Agenda.fixture_key`. Ne pas ajouter un bouton Préparer sur chaque fixture future qui ouvrirait en réalité le prochain match. |
| Petit classement du Bureau, `office_canvas.gd:217–224`, `office.gd:573–586` | Parent `OfficeStandingRow_*` cliquable, mais il ouvre le classement complet, pas la fiche du club nommé. | Ne pas le compter comme totalement statique. Si l'identité doit ouvrir le club, ajouter une zone distincte ou changer un libellé explicite ; garder la consultation du classement et son focus. |

## Terrain, banc et garde de scène

| Surface et source précise | Parent actif / données | Proposition prudente et réservation |
| --- | --- | --- |
| XV projeté dans Préparation, `native/godot/ui/immersive08/preparation_canvas.gd:367–387` | Numéros `PreparationXIPlayer_*` déjà des boutons avec player_id et infobulle ; le nom est texte voisin. `_open_sheet_player` sélectionne directement le joueur puis route Effectif. | L'ouverture existe, mais n'utilise pas encore le contrat commun de fiche complète. Après coordination, migrer ce helper vers `open_entity(player,id)` et lier le nom au même ID. **Fichier réservé #574** selon la coordination : aucune édition concurrente. |
| Terrain de Composition, `native/godot/ui/immersive08/tactics_canvas.gd:79–106` | `Selection.PlayerButton` sélectionne un slot ; portrait et nom sont des enfants. `Selection.wire` apporte drag/drop. ID joueur connu par slot. | Ce n'est pas une fiche manquante sous un Label inerte : c'est un contrôle de composition. Ajouter ultérieurement une action de lecture séparée, sans remplacer le clic de sélection ni intercepter le drag. **Fichier réservé #574.** |
| Banc de Composition, `tactics_canvas.gd:237–260` | Boutons de slot + drag, tableau trié distinct, molette contenue. IDs joueurs par slot. | Même besoin d'action de lecture séparée ; garder le tri et le focus des slots. **Réservé #574**, pas de callback métier à réaffecter. |
| Hors groupe / candidats, `tactics_canvas.gd:332–357` | Nom/portrait sous un bouton qui affecte le joueur au poste, ou affiche un refus ; drag actif. | Lier aveuglément le nom ferait concurrence à une commande réelle. Prévoir un contrôle Fiche explicite après coordination, avec lookup squad exact, sans affectation. **Réservé #574.** |
| Terrain compact, `native/godot/ui/lineup_board.gd:14–46` | Boutons `LineupSlot*` sélectionnant le poste ; portrait/nom enfants inertes. Joueur identifié par shirtNumber dans squad. | Lecture supplémentaire possible par l'ID réel trouvé, mais garder la sélection du slot. **Fichier réservé #574.** Ne pas prendre le numéro de maillot comme ID stable. |
| Banc pendant match, `native/godot/ui/match_screen.gd:439–475` | Boutons sortants sélectionnent un slot ; boutons entrants exécutent `substitute`. Leurs noms ne sont pas des liens de consultation. IDs présents dans `live.lineup` / `reserves`. | Une lecture future doit être un contrôle séparé, sans substitution, avec fiche de consultation dans le contexte de match. Respecter le chantier match coordonné avec Claude ; ne pas élargir la navigation pour quitter une immersion. Aucun diff match Claude réaudité ici. |
| Avant-match, `native/godot/ui/immersive08/match_canvas.gd:136–142` | Vérifier la feuille à 23 et Dossier adverse existent déjà ; ce sont des routes de préparation, pas de joueur arbitraire. | Existant. Ne pas annoncer ces boutons comme des fiches individuelles ni lancer une préparation/rencontre par un nom. |
| Garde commune, `native/godot/ui/navigation_controller.gd:422–434` | Bloque attente/fermeture/erreur, rendez-vous actif et match immersif, puis toute autre popup non autorisée. | Contrainte à préserver dans tous les cas. Un ID disponible ne suffit pas à autoriser une sortie de scène. Pour une lecture dans une scène obligatoire, proposer un dossier enfant explicitement prévu et testé, sans exemption générique de la garde. |
| Socle Effectif #550 | Réservé, flag OFF ; intégré sur le main signalé après le SHA d'inventaire, pas dans les reçus communs de ce relevé. | Ne pas confondre sa présence sur main et l'activation dans une carrière. Réutiliser les mêmes contrats d'identité après intégration, sans modifier son écran en parallèle ni affirmer sa recette ici. |

## Limites et réception requise

Les strings du courrier, un numéro de maillot, une date seule ou une position
dans une frise ne sont pas des IDs de joueur/rencontre. Un sessionId publié ne
prouve pas qu'un renderer de détail existe. Les contrôles de composition et de
remplacement ont déjà une fonction métier ; un nouveau lien ne la remplace pas.

Avant de recevoir une suite : vrai clic et Entrée, bonne entité, focus visible,
retour avec état de lecture, clic distinct du tri/drag, refus de sortie de scène,
aucune commande métier depuis la lecture et état/sauvegarde/RNG inchangés. Les
captures doivent venir du SHA réellement assemblé. Aucun test ni reçu graphique
nouveau, et aucune recette Windows, n'est revendiqué par ce document.
