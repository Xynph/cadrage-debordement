# Liens des échéances et des lectures internationales

Base de tranche : `a4326db5ff9d079dfabf64b79ad6100314d5145d`.
Réservation des deux fichiers publiée dans le brouillon #576 le 11 novembre
avant édition. Aucun moteur, donnée, règle, socle expérimental #550, composant
réservé à #574, réglage GitHub, ZIP ou Windows modifié.

## Destinations

| Surface | Avant | Lecture ajoutée |
| --- | --- | --- |
| Revue des échéances : nom et portrait | Valeurs statiques dans un Panel | Même fiche complète du joueur par ID stable |
| Revue des échéances : salaire et année de fin | Valeurs statiques | Même fiche, onglet Contrat |
| Bouton Fiche de la revue | Sélection et rendu directs | Contrôleur commun, gardes et historique |
| Convocation : nom de la sélection | Titre statique | Dossier nation exact, sans modifier le mandat |
| Convocation : joueur | Texte statique | Fiche existante uniquement si le contrôleur accepte l'ID projeté |
| Classement international : ligne d'une nation | Texte statique avec teamId publié | Dossier de cette nation par teamId |

Les labels, portraits, montants, noms, dates, notes et fourchettes restent les
mêmes contrôles et les mêmes textes, placés dans un bouton transparent doté du
focus existant. Les colonnes et les boutons de tri sont distincts. Les joueurs
hors des destinations publiées et les mandats refusant une route conservent
leur texte : aucun nom cliquable ne promet une fiche inexistante.

Les contrôles de revue utilisent `action_id(prefix, player_id)` avec les
préfixes `ContractNameLink`, `ContractPortraitLink`, `ContractSalaryLink` et
`ContractEndLink`. `ContractProfile` et ses métadonnées restent disponibles.
Les identifiants nationaux sont `InternationalCallupNation_<ID>`,
`InternationalCallupPlayer_<ID>` et `InternationalStandingNation_<ID>` ; la
partie ID passe par la normalisation de nom de nœud et la vraie cible reste
dans les métadonnées `entity_kind`/`entity_id`.

## Conservation de lecture : dépendance commune

`ContractReview._open_profile` mémorise le focus et le défilement puis appelle
uniquement `open_entity`. Il ne recopie pas de dictionnaire après la navigation.
Le contrôleur commun doit préserver la lecture de l'effectif pour une fiche
complète/Contrat ; seul un accès à la table explicite (`section: roster`) a
besoin de remettre les filtres à zéro. Le lookup de la fiche complète lit
`P.player(model, selected_player)` indépendamment des filtres. Cette correction
commune appartient au propriétaire du contrôleur et doit être assemblée avant
la recette de cette tranche. Elle permet aussi au bouton natif Retour à
l'effectif de retrouver les échéances, au-delà du retour Alt+gauche.

## Vérification préparée — état historique du 11 novembre 2026

La préparation ci-dessous précède les réceptions communes. La revue contrats
a ensuite reçu 270/0 sur `096f3d8f`, avec captures réelles et nom long synthétique
explicitement distingué dans le [reçu phase 9](evidence/night-phase9-20261111/README.md).
La lecture nationale 13/0 sur `d896d631` est consignée dans l’[inventaire](night-links-inventory-20261112.md) ;
le vrai parcours France depuis mandat anglais, 23/0 sur `8ad4b023`, est conservé
dans le [reçu navigation](evidence/night-navigation-20261111/README.md).
Ces portées ne sont pas additionnées comme une campagne unique.

- `godot-contract-review.gd` garde ses vérifications existantes de tri,
  géométrie, molette, filtres, prolongation sans signature et sauvegarde. Il
  exerce en plus de vrais clics et Entrée sur les quatre nouvelles zones,
  l'onglet Contrat, le retour natif, le focus exact, les filtres, le tri et le
  défilement, ainsi que l'absence de commande métier par ces liens.
- `godot-national-reading-links.gd/.cjs` vérifie le dispatch par ID, le maintien
  des textes et fourchettes, le ciblage France depuis une autre nation gérée,
  les refus de destinations et l'absence de modification du mandat. C'est un
  test du contrat entre vue et contrôleur, avec acceptation explicite simulée ;
  il ne remplace pas la recette du contrôleur réel et du worker.

Aucun Godot lourd, import ou test SDK n'est lancé dans le worktree de cette
tranche pendant le benchmark commun gelé. Les reçus réels et les captures
seront attachés au SHA commun réellement assemblé ; aucun résultat vert ni
recette Windows n'est revendiqué dans cette passation.
