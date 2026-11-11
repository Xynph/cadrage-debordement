# Recette des liens du carnet — nuit du 11 au 12 novembre 2026

Base de préparation : `6648cd6338e1eb62cc4a8c014b23dd3ec20ba174`.
Les résultats ci-dessous seront renseignés après exécution sur le candidat commun.
Ce document ne revendique ni recette Windows, ni campagne SDK globale verte.

## Contrat et périmètre

Le contrôleur ouvre une entité par `open_entity({kind,id,route?,section?})`.
La recette indépendante utilise le vrai worker, les contrôles rendus et les
identifiants de sa projection. Les données sportives ne sont jamais modifiées
pour fabriquer une rencontre historique ou une nation gérée.

| Cas | Preuve attendue | État |
| --- | --- | --- |
| France depuis une carrière gérant une autre nation | France affichée, mandat inchangé, aucun appel métier | À exécuter |
| Joueur du club | Même ID depuis clic et clavier, fiche complète | À exécuter |
| Joueur hors club | Dossier existant, informations limitées fidèles à la projection | À exécuter |
| Club adverse | Détail du bon club réutilisé | À exécuter |
| Rencontre historique | Vrai résultat du moteur et statistiques de son ID | À exécuter |
| Aller-retour | Recherche, filtres, tri, défilement, sélection et brouillons restaurés | À exécuter |
| Tri et glisser-déposer | Aucune ouverture accidentelle d’une fiche | À exécuter |
| Scène obligatoire | Refus propre sans changement de scène, commande ou sauvegarde | À exécuter |
| Consultation | Compteur de commandes, export sportif/RNG et octets de sauvegarde inchangés | À exécuter |
| Silence de Gabi | Audio Dummy, zéro demande et début de parole | À exécuter |
| Affichage | Captures natives 2560×1440 et contrôles aux tailles déjà prises en charge | À exécuter |

## Exécution ciblée

Chaque lancement Godot acquiert le verrou partagé
`/workspace/work/rg27-godot.lock`. Les groupes `reading`, `nation` et `guards`
s’exécutent séparément avec un profil jetable. Le délai enfant reste 180 secondes.
`provenance.json` conserve le SHA Git et les empreintes des sources du candidat ;
`report.json`, `godot.log` et `engine.log` consignent les résultats réels.

```sh
flock /workspace/work/rg27-godot.lock env CD_GODOT_EXECUTABLE=/chemin/godot \
  CD_NIGHT_NAV_CASE=reading CD_NIGHT_NAV_OUTPUT=/chemin/preuves \
  node --test tests/rg27-night-navigation.cjs
```

Pour les captures, ajouter `CD_NIGHT_NAV_GRAPHICS=1` et utiliser le vrai serveur
d’affichage disponible. Un lancement headless ne constitue pas une capture.

## Réserves à maintenir

- La réussite d’un groupe ciblé ne vaut pas validation de la campagne complète.
- Les identités sont recherchées par identifiant, jamais par homonyme.
- Une projection limitée n’autorise pas à retrouver un joueur caché dans les données internes.
- Les sujets moteurs, économie, calendriers et 3D réservés à Claude ne sont pas corrigés ici.

## Inventaire ciblé complémentaire : recrutement et promesses

Constat source sur la base de préparation, avant les nouveaux liens communs.
Cet inventaire ne prétend pas avoir reçu graphiquement ces fenêtres.

| Information | Destination déjà présente | Limite ou lien manquant |
| --- | --- | --- |
| Piste du marché | Ligne `MarketPlayer_ID` → `_profile` dans `recruitment_canvas.gd` | La fiche existe ; le nom ou portrait d’une alerte doit cibler son ID. |
| Rapport conservé | `OpenScoutReport` → `RecruitmentReport` → `Decisions.scout_report` | Le rapport possède son propre ID. Le contrôleur commun ne propose pas encore de cible `report` ; ouvrir le joueur ne remplace pas l’archive datée. |
| Rapport d’un joueur parti | Même détail du rapport conservé, affichage `assessment` | `_market_player` peut être vide ; ne pas inventer une disponibilité actuelle ou un dossier joueur caché. |
| Besoin d’un poste | `RecruitmentNeeds` → « Voir les pistes » → filtre de poste | Navigation déjà réelle, sans démarrer de mission. |
| Relève, candidat projeté | Carte de `RegenScouting`, filtrable et paginée | Nom et portrait statiques ; aucune fiche distincte existante. Un candidat absent de `model.market` n’est pas une cible `market` valide. |
| Relève, archive de suivi absente | Placeholder et raison de `clubLife.regenScouting.shortlist` | ID seul : garder l’absence explicite, ne pas reconstruire une identité. |
| Joueur sous contrat d’un autre club | Carte projetée `InterclubMarket` | `_offer` prépare une négociation ; ce n’est pas une destination de consultation. Un détail limité peut être extrait de la carte projetée, sans charger le joueur interne. |
| Club vendeur | Détail club de `CompetitionCanvas` | Lier seulement le `clubId` projeté et connu du détail existant. |
| Promesse ou engagement | `Relations` → `management_ui.relationships.playerId` → `_player` | Les noms d’engagements, événements et historiques sont statiques ; la fiche d’un joueur toujours dans `squad` est une destination sûre. |
| Promesse archivée d’un joueur parti | Texte conservé dans `relationships` | `_name` indique « Joueur parti du club » ; aucune identité manquante ne doit être retrouvée par homonymie. |

Les actions « Observer », « Suivre », « Approcher », « Confier la mission » et
« Promettre » restent des décisions explicites. Elles ne constituent jamais
la destination d’un simple nom, portrait ou rapport.

Les drapeaux ne sont des liens que si leur pays possède une équipe projetée
dans `international.teams`. Dans une carrière `common` sans cette projection,
le drapeau visuel reste conservé sans destination inventée. La recette des
drapeaux utilise donc une vraie carrière de club `world-champ` ; France depuis
un autre mandat utilise une vraie carrière nationale anglaise.
