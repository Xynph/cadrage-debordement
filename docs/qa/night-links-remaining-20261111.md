# Liens restants après la tranche commune de navigation

Relevé ciblé sur `37ede657` le 11 novembre 2026. Inspection de code uniquement :
ce relevé ne constitue ni une nouvelle recette graphique, ni un reçu SDK, ni un
audit des travaux de Claude. Aucun produit ni import Godot n'est modifié ici.
Les destinations décrites sont les points d'entrée réellement présents dans ce
SHA ; leur ajout doit être reçu sur le candidat commun avant d'être annoncé.

## Trois suites recommandées sans nouveau renderer

1. **Échéances de l'effectif** : lier identité, portrait, salaire et échéance dans
   `contract_review.gd::_row`. Le bouton Fiche existe, mais `_open_profile`
   modifie directement la sélection et rend la page ; il ne passe pas par le
   contrôleur commun. Réutiliser `open_entity({kind: player, id, section:
   contract})` pour les conditions et la fiche standard pour l'identité, en
   conservant `_remember`, les filtres, le tri et le défilement.
2. **Promesses et mémoire du vestiaire** : lier les noms/portraits actuels dans
   `relationships_view.gd` quand l'identifiant est encore consultable. Les
   événements et engagements ont leurs `playerId`, les fiches individuelles
   leur `id`. Garder les citations et choix archivés mot pour mot ; ajouter une
   action de lecture distincte. Coordonner ce fichier avec le propriétaire du
   lot qualité de gestion avant toute édition.
3. **Classements et convocations internationales** : les lignes de
   `InternationalView._edition_standings` possèdent `teamId`, mais leur nom de
   nation est statique. Les noms de joueurs de `_callups` ont un ID publié et
   restent statiques. Réutiliser les cibles `nation` et `player` déjà reçues,
   seulement si `entity_available` les accepte dans le contexte/mandat courant.

Ces trois suites n'exigent ni lookup worker, ni commande métier, ni nouvelle
fiche. Une cible absente de la projection doit rester du texte ; une route
simple vers Sélections ne remplace jamais le ciblage exact par nation.

## Inventaire priorisé

| Priorité | Écran / point précis | État réel et parent éventuel | Destination ou blocage précis |
| --- | --- | --- | --- |
| P1 | `contract_review.gd::_row`, identité/portrait/salaire/échéance | Vraie absence de lien sur ces valeurs ; parent Panel non cliquable. Bouton Fiche séparé présent. | Joueur squad par ID ; section Contrat pour salaire/échéance. Migrer aussi le bouton Fiche vers le contrôleur pour recevoir l'historique commun. |
| P1 | `relationships_view.gd`, événement hebdomadaire, engagements et historique | Vraie absence ; texte dans les panneaux, sans parent d'ouverture. Les boutons voisins prennent des décisions et ne sont pas des liens de consultation. | Fiche joueur si l'ID existe encore dans squad/market. Garder l'historique affiché si un ancien joueur n'a plus de destination. Propriété lot gestion à coordonner. |
| P1 | `relationships_view.gd::_details`, nom et portrait du `G.person` | Vraie absence ; `CarnetSkin.person` construit HBox, portrait et Labels, sans action parent. | Même fiche joueur par `p.id`, sans déclencher Conversation ou Promesse. |
| P1 | `international_view.gd::_edition_standings` | Vraie absence ; chaque classement est un Label. | Cible nation par `row.teamId`, dossier de consultation existant. Garder le choix année/édition/poule dans l'historique. |
| P1 | `international_view.gd::_callups` | Vraie absence ; titre nation et noms des joueurs sont des Labels. | Nation par `callup.nation` ; joueur uniquement si squad/market publie le même ID et si le mandat autorise la route. |
| P1 | `immersive08/club_canvas.gd::_staff` | Vraie absence sur les quatre noms/portraits. Le bouton Annuaire voisin ouvre Staff sans viser une personne ; le panneau n'est pas un bouton. | Cible staff par `person.id`, profil existant ; ne pas utiliser le nom ou l'index dans l'annuaire. |
| P1 | `immersive08/club_canvas.gd::_footer`, trésorerie et salaires | Vraie absence ; le bouton voisin présente une demande à la direction et ne doit pas servir de lien financier. | `finance/cash` et `finance/wages` existants ; aucune modification de montant ni du lot salaires Claude. |
| P1 | `performance_analysis_view.gd`, résultats collectifs | Texte statique, parent non cliquable ; projection contient `fixtureId` et `opponent`. | Score→fixture si lookup exact disponible ; adversaire→club par ID. Conserver la phrase d'analyse, sans déduire une date ou une rencontre à partir du score. |
| P1 | `performance_analysis_view.gd::_individual`, joueur choisi | Nom statique dans le détail. Le menu choisit le joueur dont les mesures sont affichées ; ce parent est un sélecteur, pas une ouverture de fiche. | Fiche du joueur courant par `player.id`, disponible dans l'effectif actuel selon la projection `playerMatchHistory`. |
| P2 | `international_availability.gd::_person` | Bouton Voir la fiche déjà présent ; nom statique. `_player` change directement selected_player puis la route. | Réutiliser ce bouton et le nom via ouverture commune player ; ce suivi ne présente les joueurs du club que lorsque `clubManaged` est vrai. |
| P2 | `international_availability.gd`, nations annoncées | Noms concaténés dans un Label ; aucun parent cliquable. | Nations publiées par `window.nations` et identifiant de nation ; respecter l'absence de convocations futures connues. |
| P2 | `international_view.gd::_edition_fixtures`, noms des sélections | Ligne complète en Label ; les boutons Précédent/Suivant sont seulement la pagination. | Sélections homeId/awayId via dossier nation existant. |
| P2 | `international_view.gd::_edition_fixtures`, score et date | Vraie absence mais destination commune non compatible actuellement. | Les fixtures internationales sont dans `international.editions`; `CompetitionCanvas._target_fixture` ne les parcourt pas et attend des clubs home/away. Il faut un adaptateur international explicite, pas détourner le lookup club ni fabriquer une fixture. |
| P2 | `international_availability.gd`, noms de compétition/fenêtres | Texte statique ; `competitionId` est publié. | Le kind competition commun cherche `model.leagues`, pas les éditions internationales. Réutilisation future du sélecteur d'édition de Sélections par son ID, sans candidature ni changement de rôle. |
| P2 | `immersive08/academy_canvas.gd::_staff_card` | Noms/portraits statiques dans les petits panneaux ; aucun lien individuel. | Fiche staff si l'ID du membre apparaît dans la projection staff existante. Ne pas remplacer un membre indisponible par le premier de l'annuaire. |
| P2 | `immersive08/academy_canvas.gd::_junior`, blasons/abréviations | Statiques, pas de parent d'ouverture. | Club par ID seulement s'il est réellement présent dans le catalogue/projection ; `_club` a un repli visuel Centre sans ID, qui ne doit pas devenir une destination. |
| P2 | `immersive08/academy_canvas.gd::_junior`, score des Espoirs | Texte statique ; résultat junior distinct du calendrier professionnel. | Pas de `fixtureId` professionnel garanti. Ne pas ouvrir une rencontre pro de même journée ; réutiliser un détail junior seulement après définition de son identité stable. |
| P2 | `decision_views.gd::dossier`, nom du club adverse | Texte dans un dialogue comportant l'action Adopter le plan. | Club par `data.opponent.id`, mais ouverture enfant conservant le contexte nécessaire. `open_entity` ne doit pas contourner ce popup métier. |
| P2 | `decision_views.gd::dossier`, menaces adverses | Texte statique avec identifiants projetés, sans fiche universelle pour tous ces joueurs. | Si absent squad/market : dossier limité d'adversaire depuis la projection threats, sans données cachées. L'adaptateur prospect actuel ne couvre pas cette source. |
| P2 | `immersive08/recruitment_comparison.gd`, noms/portraits des deux pistes | Vraie absence sur les cartes de comparaison ; sélecteurs déjà actifs pour changer les deux joueurs. | IDs market connus, mais fenêtre MarketComparison non autorisée comme source du contrôleur. Préserver deux choix, filtres et scroll par inspection enfant plutôt que fermer implicitement la comparaison. |
| P2 | `prospect_profile.gd::_squad`, vos joueurs au même poste | Texte statique volontaire à ce SHA ; dossier enfant d'une fenêtre métier conservant un brouillon. | Besoin d'une fiche joueur enfant de lecture sans sortie de la source. Ajouter un `open_entity(player)` serait systématiquement refusé par les popups ou détruirait le brouillon si on élargissait aveuglément la garde. Aucun faux lien ajouté. |
| P2 | `interclub_market_view.gd`, club vendeur dans l'en-tête et le dossier | Texte statique, source métier et conditions conservées. | Club connu par clubId, mais détail Competition utilise la fabrique de dialogue qui efface les fenêtres. Adapter son parentage/retour pour inspection enfant, sans dupliquer la fiche club. |
| P2 | `youth_development_view.gd::_person`, nom/portrait | Texte statique dans une fenêtre avec objectifs locaux et confirmations. | Professionnels parfois dans squad ; académie hors squad/market. Étendre l'inspection enfant à cette source en réutilisant le vrai dossier académie ; conserver `state.drafts`, contexte et filtres. |
| P3 | `performance_analysis_view.gd`, apparitions individuelles | Clubs affichés par numéro ; le joueur peut avoir changé de club. | Clubs par clubId/opponent si connus. Les apparitions projetées exposent une clé de registre, pas leur fixtureId : ne pas reconstituer la rencontre depuis saison/semaine et adversaires. |
| P3 | `coach_notes_view.gd`, cible d'une note et picker | Choix de cible actif pour éditer la note ; pas une ouverture. Éditeur et brouillon présents. | Inspection enfant du joueur/staff ciblé avec conservation du texte non enregistré, pas navigation immédiate sur sélection du picker. |
| Réservé | `immersive08/tactics_canvas.gd`, `preparation_canvas.gd`, `lineup_board.gd` | Joueurs terrain/banc mêlés aux commandes de composition et au drag ; certains parents sélectionnent/changent un poste. | Fichiers touchés par #574 selon la coordination. Pas de modification concurrente ni remplacement d'un clic de sélection/drag par une navigation. Prévoir une action de lecture séparée après intégration Claude. |
| Réservé | `ui/contextual/medical_room_view.gd` et directeur contextuel | Noms/portraits dans une scène médicale ; consultation/choix de protocole et rendez-vous peuvent être obligatoires. | Périmètre de l'intégrateur déjà annoncé, hors nouveau lot d'inventaire. Exiger une lecture qui ne quitte pas la scène obligatoire ; ne pas ouvrir arbitrairement une route. |

## Contrôles existants à ne pas compter comme des liens manquants

- `immersive08/academy_canvas.gd::_draw_rows` : les noms et portraits sont des enfants
  de `AcademyRow_*`, un bouton qui sélectionne déjà le vrai dossier académie.
  Même constat pour `AcademyPathway_*` dans les parcours. Ajouter un second
  bouton superposé ferait concurrence à cette sélection sans nouvelle destination.
- Les identités et portraits des dossiers joueur/staff/nation déjà ouverts
  n'ont pas besoin d'un lien vers eux-mêmes. Un détail supplémentaire doit avoir
  une destination distincte, pas créer une fenêtre identique.
- Le journal de match présente déjà `JournalActionLink`, activable au clavier
  et au clic, pour relire l'événement et sa position. Son texte d'événement n'a
  pas de nom d'entité suffisamment structuré pour devenir plusieurs liens sans
  adaptateur ; ne pas extraire un joueur depuis une citation ou une phrase.
- Les boutons Prolonger, Approcher, Observer, Suivre, Conversation, Promesse et
  les choix de composition sont des commandes ou leurs confirmations. Ils ne
  remplacent pas une action de lecture et ne doivent jamais être déclenchés par
  un simple nom cliquable.

## Limites de projection et des sources

Une carrière sans `model.international.teams` ne fournit pas de destination
nation depuis son drapeau. Un ancien joueur absent des projections consultables
n'a pas automatiquement une fiche publique complète. Les anciennes rencontres
sans identifiant ne sont pas retrouvées par rapprochement de score. Un blason
visuel de repli ne prouve pas un club. Ces cas restent du texte tant qu'un
contrat de lecture précis et testable n'existe pas.

Le contrôleur inspecte actuellement les prospects des trois sources explicites
`regen-candidates`, `regen-shortlist` et `interclub`. Il ne faut pas déclarer une
fenêtre métier `navigation_read_only` pour obtenir l'exemption d'un popup.
L'extension pour joueurs du club, adversaires, clubs ou rapports depuis une
fenêtre métier doit préserver propriétaire, champs, focus, scroll et retour.

## Recette minimale avant chaque suite

Clic réel et Entrée vers le bon ID ; focus visible ; tri et drag distincts ;
retour avec filtres/tri/scroll/drafts ; refus propre en scène obligatoire ;
absence de commande métier ; sauvegarde et RNG inchangés. Les lieux où le
contrôleur est déjà disponible ne sont donc pas annoncés comme reçus simplement
par la présence de son API dans ce document. Aucun essai Windows revendiqué.
