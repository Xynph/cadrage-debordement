# Navigation commune — lot de nuit du 11 novembre 2026

Base de travail : `6648cd6338e1eb62cc4a8c014b23dd3ec20ba174` (correctif QA Art,
lot #572). Réservation de fichiers partagés : PR brouillon #576. Aucune fusion
avant le 12 novembre à 09 h, Paris ; Windows et ZIP restent à Claude.

## Inventaire initial et destination retenue

| Entité / contexte | Existant à la reprise | Travail du contrôleur commun | Destination |
| --- | --- | --- | --- |
| Menu, joueur effectif, piste marché | Palette typée, ID, historique roster | Une seule validation et ouverture publique | Écrans existants |
| Joueur hors club projeté | Piste marché par ID | Le type `player` résout effectif puis marché ; jamais un nom | Dossier recrutement limité à la projection |
| Contrat joueur | Fiche complète, onglet contrat | `section: contract` choisit l’onglet 3 sans proposition de contrat | Fiche joueur |
| Nation | Route générale surtout nation gérée | Adaptateur valide ID projeté, aucun mandat ni candidature | Consultation nation de `InternationalView` |
| Staff | Annuaire et parcours | Adaptateur ID, validation à la reprise historique | Consultation de `StaffView` |
| Club / rencontre | Détails dans `CompetitionCanvas` | Adaptateur ID, aucun écran réécrit | Fenêtre existante sur l’appelant |
| Compétition / date / finances | Écrans et états locaux existants | Adaptateurs ; passage par la même garde | Classement / calendrier / onglet financier |
| Rapport observation projeté | Rapport de recrutement existant | Adaptateur par `report.id` exact, sans exiger joueur encore marché | Fenêtre rapport existante |
| Entraînement équipe | Entrée existante préparation | Type `training`, ID vide ou `team` seulement | Préparation, onglet entraînement |
| Presse | Invitation de courrier exacte | Aucun menu générique vers Presse | Courrier et invitation d’origine conservés |
| Rendez-vous, causerie, match immersif | Gardes de scènes | Refus avant changement de sélection ou de filtre | Aucun nouveau chemin parallèle |
| Fenêtre métier avec brouillon | Fenêtre transactionnelle | Refus ; aucune fermeture automatique | Reste ouverte et intacte |

## Contrat public et responsabilités

`app.navigation_controller.entity_available(target: Dictionary) -> bool` valide
uniquement la projection courante. `open_entity(target, source_window = null)`
applique aussi les gardes puis ouvre la cible. Types pris en charge : `menu`,
`player` (alias `squad`), `market`, `nation`, `staff`, `club`, `fixture`,
`competition`, `date`, `finance`, `training`, `report`. Le type `prospect` est
validable via `entity_available` mais son ouverture requiert `inspect_entity`
et une fenêtre métier propriétaire qualifiée. Le champ `route` est une entrée
libre uniquement pour `menu`, parmi les routes déjà permises ; Presse reste
exclue. Les autres types choisissent leur destination, indépendamment d’une
route fournie par l’appelant.

Une fiche joueur complète, y compris `section: contract`, conserve l’état entier
de lecture de l’effectif : recherche, groupe, tri, scroll, focus, onglet et
horizon de contrats. Son ID est résolu directement dans l’effectif projeté,
même si ce joueur est exclu des filtres. Le bouton natif « Retour à l’effectif »
réutilise cet état. Seule `section: roster`, utilisée par la palette pour montrer
une ligne précise, remet les filtres à zéro ; l’historique conserve son origine.

Les adaptateurs Nation et Staff préparent seulement leur état local ; le
contrôleur navigue ensuite. Competition et Finance réutilisent leurs propres
points d’entrée d’écran ou de fenêtre. Aucun appel n’interroge le worker pour
obtenir des données supplémentaires.

`EntityLink.button(app, label, target, id, source_window)` et
`EntityLink.bind(button, app, target, label, source_window)` réutilisent le skin
existant, les boutons clavier et le focus existants. Ils ajoutent les métadonnées
`entity_kind` / `entity_id` et un libellé accessible. Ils n’installent aucun
traitement de molette, de tri ou de glisser-déposer.

Une fenêtre source n’est ignorée par la garde que si elle appartient à l’app,
porte explicitement `navigation_read_only=true`, et qu’aucune autre fenêtre ou
scène obligatoire ne bloque. Après validation, elle reste suspendue dans son arbre d’origine afin de préserver son contexte. Ne jamais
attribuer ce marqueur à une négociation, une décision ou une fenêtre contenant
un brouillon métier.

## Consultation d’un prospect depuis une fenêtre métier

`inspect_entity({kind: prospect, source, id}, owner_window)` est distincte de
`open_entity`, qui refuse ce type. Sources admises : `regen-candidates`,
`regen-shortlist`, `interclub` ; l’adaptateur ne mélange pas ces listes et
n’interroge jamais le worker. L’ID est recherché dans la projection courante.

Seules les fenêtres existantes `RegenScouting` / `InterclubMarket`, appartenant
à l’app, visibles, portant leur rôle exact `navigation_inspection_source` et
répondant positivement à `inspection_allowed(target)`, peuvent ouvrir ce lecteur.
Une commande en attente, une confirmation, une autre fenêtre visible, un
rendez-vous, une causerie ou un match immersif refusent l’ouverture. Le marqueur
`navigation_read_only` n’est jamais donné à ces fenêtres métier.

Le détail est un enfant de la fenêtre propriétaire. Il ne navigue pas, ne ferme
pas la fenêtre métier, n’ajoute pas de parcours historique et ne rejoue aucun
callback de brouillon. Fermer le lecteur restitue le focus si son contrôle
source existe encore. Cette tranche est à recevoir avec un test réel qui
compare brouillon, filtres, pagination, scroll, état sportif et RNG avant/après.

## Lecture, historique et limites

Le snapshot de lecture est local à la session : `management_ui`, sélection,
mode de fiche, division, mode de calendrier, focus/caret et surfaces de scroll.
Les clés qui reflètent la carrière courante (`career`, `shortlist`, `compare`)
ne sont pas rembobinées. Le modèle sportif, le worker, la sauvegarde et le RNG
ne sont jamais restaurés ou modifiés. Les callbacks de saisie et les commandes
ne sont pas rejoués lors du retour. L’historique reste limité à 60 entrées et
ignore les entités qui ont disparu de la projection.

Les détails club/rencontre restent des fenêtres de consultation. Un lien depuis
une fenêtre readonly la conserve cachée, sans reparentage ni destruction,
sous un nom privé enregistré ; son nom public revient au moment de l’affichage.
Après navigation vers une page, Précédent restitue la même instance du lecteur,
son focus et son scroll. Après ouverture d’un autre lecteur, Échap, FERMER ou
Alt + gauche ferme ce nouveau lecteur et restitue son parent. Revenir vers une
entité déjà présente dans cette chaîne réutilise l’ancêtre, sans doublon.

Seules les fenêtres enregistrées comme sources suspendues survivent à
`_clear_dialogs`. Leur nombre est borné par les 60 entrées de lecture ; les
sources rendues inaccessibles par une nouvelle branche d’historique sont
libérées. Chaque commande envoyée, réponse du worker, reset de carrière ou
fermeture invalide les lecteurs enregistrés et leurs descendants. Aucun
lecteur d’une ancienne projection n’est ressuscité ; la navigation ne produit
elle-même aucun appel worker. Les fenêtres de métier et leurs brouillons ne
reçoivent jamais cette suspension readonly. Les détails prospects restent des
enfants de leur fenêtre métier via `inspect_entity`, avec leur garde séparée.
Les champs dont l’écran conserve déjà les valeurs dans `management_ui` sont
restaurés. Les brouillons internes à une fenêtre métier ne sont pas migrés :
la navigation depuis cette fenêtre est refusée.

## Vérifications — état historique de la copie initiale (11 novembre 2026)

Les attentes décrites dans cette section concernent cette copie initiale. Les
[sept reçus communs de navigation](evidence/night-navigation-20261111/README.md)
et le [parcours management 61/0 sur `d40311c0`](evidence/night-management-reading-20261111/README.md)
qualifient ensuite leurs cas précis et SHA respectifs. Ils ne constituent pas
un verdict global ni un reçu autonome ajouté pour les deux suites citées
ci-dessous.

- Import réel SDK Godot 4.7.2 sur cette copie : aucune erreur de parsing observée.
- `tests/godot-navigation.cjs` : premier lancement de cette copie interrompu,
  non qualifiant. Le staging des données catalogue manquait : erreur JSON dans
  `main.gd:148`, puis absence du timer. Défaut de préparation de la copie ;
  aucun verdict produit tiré de ce lancement. La nouvelle suite ciblée en file
  a été annulée avant lancement. Validation à réaliser dans la copie commune
  déjà préparée, avec Node 22 épinglé, sur le SHA assemblé.
- Nouvelle suite `tests/godot-entity-navigation.cjs` : ouverture ID effectif et
  marché, section contrat, refus sans mutation, état lecture et brouillon,
  fenêtres source, clavier accessible, sauvegarde octet pour octet et état/RNG.
  Résultat à recevoir sur le candidat assemblé.
- Les tests intégrés nation/staff/club/rencontre dépendent des adaptateurs des
  autres lots ; aucun résultat de cette copie seule ne les qualifie.

Tous les Godot lourds passent par `/workspace/work/rg27-godot.lock`, audio Dummy.
Aucun reçu Windows, faux aperçu ou lancement TTS n’est revendiqué ici.

## Réception du scroll du vestiaire

Le scénario graphique gestion sur `d40311c053aba931756df212c2690adb04a76994`
reçoit 61 contrôles / 0 échec, 0 demande / 0 démarrage de parole et deux PNG
réels 2560×1440. Les noms stables des deux listes du vestiaire permettent
le retour exact à la position 90 sans relâcher le résolveur commun.
Le [diagnostic rouge et la réception par SHA](night-management-scroll-20261111.md)
distinguent la préparation du bon onglet du défaut produit de défilement.
