# Liens de lecture du vestiaire et des dernières décisions

Base : `0d19ddfa21332c846b086b496ebb7f9a81f2fa4f`. Tranche distincte du
candidat commun gelé. Propriétés de fichiers réservées dans la PR brouillon 576 :
`relationships_view.gd` et `decision_feedback.gd`. Aucun moteur, nouvelle règle
de coût, consommation de RNG ou nouvelle direction artistique.

## Inventaire avant modification

| Surface | Identifiant déjà disponible | Situation initiale | Destination retenue |
| --- | --- | --- | --- |
| Nom et portrait du joueur sélectionné | `players[].id`, rapproché de `squad[].id` | Lecture sans lien | Fiche complète de ce même joueur |
| Joueur de l’événement hebdomadaire | `event.playerId` | Nom en sous-titre | Même fiche, aucune décision de vestiaire |
| Engagement de temps de jeu | `commitments[].playerId` | Nom inclus dans le texte | Même fiche, engagement inchangé |
| Historique collectif | `history[].playerId` | Nom et titre archivés | Même fiche si le joueur est toujours projeté dans l’effectif |
| Relais du groupe | `leaderId` | Nom en lecture | Même fiche |
| Partenaires d’un duo | `pairs[].a/b` | Deux noms en lecture | Deux liens indépendants vers les IDs exacts |
| Reçu individuel de charge, entretien ou promesse | `payload.playerId` au vrai envoi | Identifiant perdu après création du reçu | Fiche de la personne exacte, identifiant retenu localement |
| Reçu de duo | `payload.a/b` au vrai envoi | Identifiants perdus | Deux fiches, aucun travail de duo déclenché |
| Reçu d’événement | `eventKey` et `event.playerId` avant décision | L’événement disparaît après décision | Personne de l’événement uniquement si sa clé correspond exactement |
| Reçu de contrat | `playerId`, `agent_negotiate.id` ou `talk.id` retrouvé par `talk.key` | Texte seul | Section contrat de la fiche ; dossier de recrutement si l’ID est encore hors club et projeté |

## Liens volontairement impossibles dans ce contexte

- Un ancien joueur absent de `squad` reste une archive du vestiaire. Son nom
  n’est jamais utilisé pour retrouver un homonyme. Le titre de l’événement et les
  textes archivés restent intacts.
- Un ancien reçu peut conserver son ID exact tout en perdant sa destination
  actuelle. Le contrôleur est interrogé sur la projection courante avant de
  créer le bouton ; le reçu reste lisible si la cible n’est plus disponible.
- Une décision globale n’est pas attribuée artificiellement à une personne.
- Une cible d’académie sans fiche accessible par le contrôleur ne reçoit pas de
  bouton trompeur, même si son ID est connu de la décision.
- Un reçu de presse n’ouvre pas une route générique « Presse » : aucune invitation
  exacte n’est conservée dans ces reçus, donc aucun nouveau lien n’est ajouté.
- Le texte d’une variation de trésorerie ne fournit pas à lui seul l’identifiant
  d’une écriture comptable. Aucune opération n’est devinée en analysant son titre
  ou le nom du joueur. Les liens financiers précis restent ceux du journal commun.

## Contrat de lecture

Tous les nouveaux contrôles utilisent `G.button` et `EntityLink.bind`. Le nom
sélectionné garde la taille et la police existantes de sa présentation de
personne ; le portrait utilise la même ressource. Focus et libellé accessible
proviennent du composant commun. Le tabulateur de la fenêtre de reçus parcourt
les nouveaux liens avant la barre de défilement puis revient à « FERMER ».

Les métadonnées de reçu sont capturées au vrai envoi dans la session UI, à partir
des payloads et correspondances de clés existants. Elles n’ajoutent aucun champ
à la sauvegarde sportive. Aucun nom, fragment de phrase ou position dans une
liste n’est utilisé comme identifiant. `receipts()` conserve sa copie profonde.

Le titre, le texte, la synthèse et les valeurs avant/après des reçus ne sont pas
modifiés. Les coûts, engagements différés et limites de causalité existants ne
sont ni recalculés ni renforcés par ces liens. Une consultation n’est pas une
commande de contrat, de promesse, d’entraînement ou d’entretien.

`DecisionFeedbackDialog` est marqué `navigation_read_only`. Ses liens transmettent
la fenêtre source au contrôleur commun, qui conserve les gardes des autres
fenêtres et des scènes obligatoires. Le retour à cette même instance, à son
scroll et à son focus dépend de la tranche commune de suspension des lecteurs,
possédée par `navigation_core`. Aucun mécanisme concurrent de suspension ou de
scroll n’est ajouté ici.

## Recette prévue — état historique du 11 novembre 2026

La préparation ci-dessous a été suivie du module 43/0 sur `fbc642e1`,
consigné dans l’[inventaire](night-links-inventory-20261112.md), puis du
[parcours graphique réel 61/0 sur `d40311c0`](evidence/night-management-reading-20261111/README.md).
Ce dernier conserve la même fenêtre de reçus, le focus et les défilements.
Les trois tentatives rouges précédentes restent séparées dans ses preuves.

- `tests/godot-management-reading-links.cjs` : vraie construction des composants
  Godot dans un host isolé ; homonymes et départ, identifiants d’envoi/événement/
  négociation, textes de reçu intacts, clavier et fenêtre source, absence de
  commande. Ce test ne qualifie pas le contrôleur de retour modal à lui seul.
- `tests/godot-management-reading-flow.cjs` : vrai client et worker, entretiens et
  engagement réellement effectués ; Vestiaire → fiche → retour avec sélection,
  scroll et brouillon conservés ; ancien reçu → fiche → retour vers la même
  instance de fenêtre, son scroll et son focus ; reçus inchangés, aucune commande
  induite, profil/état/RNG/horloge conservés ; compteurs Gabi sans demande ni
  démarrage. Deux captures natives 2560×1440 si lancé avec le rendu graphique.
- Les tests doivent être exécutés sur le candidat commun déjà importé, sous le
  verrou Godot partagé et avec audio Dummy. Aucune importation lourde de ce
  worktree, recette Windows, fusion ou publication par l’agent de tranche.

Les commandes, SHA d’assemblage et résultats effectivement reçus seront ajoutés
après recette ; les scénarios ci-dessus ne sont pas encore annoncés comme verts.
