# Liens de consultation du Bureau — 12 novembre 2026

Base de tranche : `096f3d8f`. Réservation des deux fichiers dans le brouillon
#576 avant édition. Cette tranche possède uniquement `office.gd` et
`office_canvas.gd` pour le produit ; aucune commande, action primaire, séance,
moteur, donnée, salaire, calendrier ou CTA métier n'est modifié.

## Coordination vérifiée

Listes de fichiers GitHub consultées le 12 novembre, heure de Paris : aucun des
deux chemins `native/godot/ui/immersive08/office.gd` et `office_canvas.gd` dans
les PR suivantes. Cette lecture porte sur les collisions, pas sur la qualité
ou la recette du travail de Claude.

| PR | Tête au relevé | État observé |
| --- | --- | --- |
| #550 | `a978475efacb0dddd5a3d5239ae21116ab5717e9` | Fusionnée ; socle distinct, aucune édition dans ce lot |
| #552 | `5666193089a9cd4dd9b37ab6d71f934c1aa2a0c8` | Ouverte |
| #553 | `fb8ee0f4646a2bbf2f94af3072e3fc4d5ac646b8` | Ouverte |
| #571 | `e6704e8af4efc2a8ed75481646315c363591c2aa` | Ouverte |
| #573 | `499903807fa05349b78eb2ea0e1067d29566d6db` | Ouverte |
| #574 | `4bf801b1e5af153b563a1cdf6a12931825620da0` | Ouverte |
| #575 | `35132b3c37d9ad193a263e4c5aeb8042769d0046` | Ouverte |

Le socle n'est pas activé par ce lot. Les fichiers et conversions Mixamo ne sont
ni lus ni copiés. Aucun chantier match/animation/Windows concurrent n'est lancé.

## Inventaire de livraison

| Surface | Destination | Limites conservées |
| --- | --- | --- |
| Exemple d'alerte physique du Bureau canvas | Fiche du joueur squad par son ID | Le bouton collectif de joueurs surveillés reste séparé ; aucun portrait ou alerte supplémentaire n'est inventé. |
| Noms et blasons domicile/extérieur du prochain match | Fiche de chaque club par ID | Match courant projeté uniquement ; Préparer et Vérifier les 23 restent leurs actions d'origine. |
| Date publiée du prochain match | Calendrier sur la date ISO exacte | Une indication Semaine sans date publiée reste du texte. |
| Adversaire et date pendant semaine exempte / préparation | Club exact et date publiés de la fixture annoncée | Sans fixture ou sans adversaire concordant avec le club géré : aucun lien arbitraire. |
| Frise des prochaines rencontres | Nom/blason→club ; date→calendrier | Les IDs des fixtures servent aux noms des contrôles ; pas de prochain match implicite ni d'action primaire. |
| Résultats récents structurés | Score→fiche de rencontre ; nom/blason→club | Score cliquable uniquement si lookup exact concorde en score, domicile/extérieur, date et vainqueur publié. Un ID absent, ambigu ou deux scores publiés divergents laissent le score statique. |
| Hôtes de test / anciens hôtes visuels sans navigation | Contrôles et textes d'origine | Le contrôleur est optionnel pour ces nouveaux liens. Aucun bouton mort ni lookup supplémentaire quand il est absent. |

Les identités, dates, scores et visuels existants restent les mêmes contrôles.
Le canvas ajoute des zones transparentes ; le gabarit compact garde le contenu
dans un contrôle de lecture transparent, sans changer la palette ou les fontes.
Les deux gabarits utilisent les mêmes cibles et helpers de disponibilité. La
branche de Bureau en direct n'est pas remaniée.

Noms stables des contrôles : `OfficeWatchedPlayer_<ID>`,
`OfficeNextHomeClubName`/`OfficeNextHomeClubCrest`, variantes Away,
`OfficeNextDate`, `OfficeScheduledOpponent`/`OfficeScheduledDate`,
`OfficeTimelineDateLink_<fixture>`, `OfficeTimelineClubName_<fixture>`,
`OfficeTimelineClubCrest_<fixture>`, `OfficeRecentFixture_<fixture>`,
`OfficeRecentClubName_<fixture>` et `OfficeRecentClubCrest_<fixture>`.
La vraie cible réside dans `entity_kind`/`entity_id` ; la normalisation du nom de
nœud ne sert jamais à retrouver une entité par son libellé.

## Réception à effectuer après assemblage

`tests/godot-office-entity-links.gd/.cjs` prépare le scope composants : vrais
contrôles des deux gabarits, dispatch par ID, absence de commande/action primaire,
labels conservés, hôte sans navigation, scores inversés, autre date, absence
 d'ID et ambiguïté de score. Il utilise le vrai lookup Competition, avec un
contrôleur de dispatch isolé ; il ne remplace pas un reçu client/worker.

Second scope demandé : vrai client/worker, clic et Back sur adversaire/date du
prochain match, puis score et alerte si les données les publient. Réutiliser une
**copie jetable** du checkpoint reader-history proposé par l'intégrateur ; le
profil source n'est jamais modifié. La préparation du wrapper partagé est
coordonnée avec le propriétaire des liens du monde pour éviter plusieurs setups
lourds et un cumul dépassant le délai existant.

Aucun Godot/import ni SDK n'est lancé dans ce worktree avant le GO de
l'intégrateur. Les tests préparés ne sont pas annoncés verts ; les résultats,
les captures réelles et le SHA commun seront consignés après exécution.
Aucune recette Windows ou nouvelle campagne globale n'est revendiquée.


## Réception graphique ciblée du 12 novembre 2026

Les préparations et attentes des sections précédentes sont historiques.
Le parcours commun Analyse/Club/Bureau est reçu sur
`bd6a5fe63fe52fbb5ecf4a55859676876c7d983e` : **72 contrôles, zéro échec, sortie 0,
65,703 s**, trois PNG originaux 2560×1440 inspectés. Les actions reçues sont
énumérées dans le rapport par ID et activation réelle ; ce résultat commun
ne compte pas comme trois suites séparées. Les consultations conservent les
lecteurs/retours, choix de joueur, sauvegarde et état sportif/RNG.

[Preuves exactes, visites, copie source et historiques rouges](evidence/night-analysis-club-office-20261112/README.md).
Le test passe l’assertion de silence avec audio Dummy ; ses compteurs ne sont
pas sérialisés dans le rapport. Une bulle textuelle Gabi est visible sur la
capture Analyse. Aucun import/SDK n’a été relancé pour cette documentation.
