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
| Entraînement équipe | Entrée existante préparation | Type `training`, ID vide ou `team` seulement | Préparation, onglet entraînement |
| Presse | Invitation de courrier exacte | Aucun menu générique vers Presse | Courrier et invitation d’origine conservés |
| Rendez-vous, causerie, match immersif | Gardes de scènes | Refus avant changement de sélection ou de filtre | Aucun nouveau chemin parallèle |
| Fenêtre métier avec brouillon | Fenêtre transactionnelle | Refus ; aucune fermeture automatique | Reste ouverte et intacte |

## Contrat public et responsabilités

`app.navigation_controller.entity_available(target: Dictionary) -> bool` valide
uniquement la projection courante. `open_entity(target, source_window = null)`
applique aussi les gardes puis ouvre la cible. Types pris en charge : `menu`,
`player` (alias `squad`), `market`, `nation`, `staff`, `club`, `fixture`,
`competition`, `date`, `finance`, `training`. Le champ `route` est une entrée
libre uniquement pour `menu`, parmi les routes déjà permises ; Presse reste
exclue. Les autres types choisissent leur destination, indépendamment d’une
route fournie par l’appelant.

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
scène obligatoire ne bloque. Elle n’est fermée qu’après succès. Ne jamais
attribuer ce marqueur à une négociation, une décision ou une fenêtre contenant
un brouillon métier.

## Lecture, historique et limites

Le snapshot de lecture est local à la session : `management_ui`, sélection,
mode de fiche, division, mode de calendrier, focus/caret et surfaces de scroll.
Les clés qui reflètent la carrière courante (`career`, `shortlist`, `compare`)
ne sont pas rembobinées. Le modèle sportif, le worker, la sauvegarde et le RNG
ne sont jamais restaurés ou modifiés. Les callbacks de saisie et les commandes
ne sont pas rejoués lors du retour. L’historique reste limité à 60 entrées et
ignore les entités qui ont disparu de la projection.

Les détails club/rencontre restent des fenêtres de consultation : Échap ou
FERMER revient à l’appelant intact. Le retour global est bloqué tant qu’une
fenêtre est ouverte ; il n’y a pas d’historique supplémentaire des fenêtres.
Les champs dont l’écran conserve déjà les valeurs dans `management_ui` sont
restaurés. Les brouillons internes à une fenêtre métier ne sont pas migrés :
la navigation depuis cette fenêtre est refusée.

## Vérifications

- Import réel SDK Godot 4.7.2 sur cette copie : aucune erreur de parsing observée.
- `tests/godot-navigation.cjs` : exécution demandée sous le verrou partagé ;
  résultat à consigner par l’intégrateur sur le SHA assemblé.
- Nouvelle suite `tests/godot-entity-navigation.cjs` : ouverture ID effectif et
  marché, section contrat, refus sans mutation, état lecture et brouillon,
  fenêtres source, clavier accessible, sauvegarde octet pour octet et état/RNG.
  Résultat à recevoir sur le candidat assemblé.
- Les tests intégrés nation/staff/club/rencontre dépendent des adaptateurs des
  autres lots ; aucun résultat de cette copie seule ne les qualifie.

Tous les Godot lourds passent par `/workspace/work/rg27-godot.lock`, audio Dummy.
Aucun reçu Windows, faux aperçu ou lancement TTS n’est revendiqué ici.
