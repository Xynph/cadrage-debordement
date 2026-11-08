# Données du jeu et intégration de données réelles

## État courant — Oval Legacy 27, Godot 0.3 — 8 novembre 2026

Les nouvelles carrières natives emploient `rugby-common-2026-10-31-v1` : 30 clubs et 1 592 joueurs compilés depuis les données actives, avec les mêmes IDs, âges, attributs, compétences, potentiels et traits, sous des identités anonymisées. Le [lot effectifs 2](roster-foundation-lot2.md) porte la couche documentaire à **241 postes corroborés, 86 échéances contractuelles et 9 statuts documentés**. Le registre initial v1 reste disponible pour les anciennes carrières ; les nouvelles utilisent v2 sans migration implicite. Aucune source BDD du producteur n'est modifiée. Les notes restent des estimations de jeu, pas des mesures officielles ; corriger un poste peut changer sa note calculée sans recalibrer ses attributs.

Les packs importés à la création ou dans les paramètres d'une carrière commune projettent noms et images par ID. Ils ne remplacent ni statistiques ni progression. Le pack fourni à Léo reste privé, hors de l'exécutable et de GitHub : 30 logos, 1 549 photos officielles et 43 illustrations IA explicitement distinguées. Le [rapport 0.3](rugby-real-native-packs-20261107.md) décrit le format, la réception et les lacunes conservées.

Les nouvelles carrières communes utilisent les 86 échéances publiées retenues et des durées estimées déterministes pour les 1 506 autres joueurs. Les 1 583 statuts et 1 351 postes non documentés restent estimés. Salaires et trésoreries restent fictifs. Les pages de postes observées le 7 novembre corroborent leur état courant, pas une photographie certaine au 31 octobre ; les dates et précisions figurent dans les preuves. Les calibrations candidates de la PR389 et les dossiers contradictoires restent exclus. Plafond de recrutement historique de 42 et effectifs source de 36 à 65 demeurent des limites documentées ; l'interface affiche le motif lorsque cette limite bloque une offre. Les anciennes carrières, y compris communes sans marqueur documentaire, restent inchangées, sans conversion automatique. Les sections ci-dessous décrivent les étapes antérieures.

## État de la version 15

`dist/world-data.js` rassemble le catalogue initial des clubs et les listes de
prénoms et noms servant à générer les joueurs. Ce fichier est séparé du moteur
et chargé avant les autres modules. Cette extraction conserve les valeurs et
l’ordre existants, sans modifier les effectifs ou les parties en cours.

Les noms de clubs et de stades sont ceux déjà présents dans le jeu. Leur liste
ne constitue pas une base certifiée d’une saison réelle. Les joueurs sont générés.
Les notes, salaires, primes, recettes et montants financiers sont des paramètres
fictifs de simulation.

La valeur monétaire initiale d’un club représente une **trésorerie de jeu en
millions d’euros**. Elle ne représente pas un budget annuel de club, une masse
salariale ou une valeur d’effectif. Ces notions devront être renseignées
séparément si des données réelles sont intégrées.

## Au moment de constituer une base réelle

Le travail devra commencer par le choix d’une saison et d’une date d’arrêt des
données. Les mutations, blessures et budgets peuvent changer pendant la saison.
La saison des données et le profil des règles simulées sont deux choix distincts.

| Donnée | Informations à conserver avec sa source |
|---|---|
| Club | Identifiant stable, nom, compétition, saison, stade et date de vérification |
| Joueur | Identifiant stable, club à la date retenue, nom, naissance et postes vérifiés |
| Première ligne | Qualification distincte de pilier gauche, pilier droit et talonneur |
| Finances | Nature exacte du montant, période, unité, source et date de publication |
| Attributs de jeu | Méthode d’estimation, auteur et date ; distinguer une note fictive d’un fait publié |
| Valeurs inconnues | Les indiquer comme inconnues ou estimées, sans présenter une estimation comme un chiffre officiel |

## Ce qui restera à développer

L’extraction du catalogue est un premier point d’entrée, pas encore un importeur
de base réelle. Le moteur de carrière suppose actuellement quatorze clubs ; les
sauvegardes vérifient leurs noms, abréviations et couleurs contre le catalogue.
Les identifiants de joueurs générés et les contrats appartiennent aux carrières.

Une nouvelle base devra donc avoir sa propre version et une correspondance
stable des identifiants. Il faudra décider explicitement quelles données servent
aux **nouvelles carrières**, et comment préserver les anciennes. Remplacer le
catalogue sans cette migration pourrait invalider les sauvegardes existantes.

Pour l’instant, aucun vrai joueur ni budget réel n’a été ajouté. Les rapports
adverses utilisent les données de la carrière ouverte ; ils continueront ainsi à
refléter ses transferts, sa progression et son calendrier, plutôt qu’une base
extérieure qui évoluerait indépendamment de la partie.

## Édition native fictive à trente clubs — 7 novembre 2026

Le catalogue `dist/france-clubs.js` fournit trente identités de jeu originales, liées à des territoires réels. Il sert à créer une carrière `france30`, répartie en deux divisions fictives de 14 et 16 clubs. Les divisions initiales appartiennent à ce catalogue ; elles ne constituent pas une publication des effectifs ou de la situation officielle d'une saison réelle.

Joueurs, compétences, contrats, objectifs et trésoreries sont générés ou calculés par le moteur fictif. Les salaires affichés sont hebdomadaires ; la saison France emploie 34 semaines comptables. Une promotion de secours humaine coûte 2 500 € par semaine et par joueur, après confirmation ; les renforts IA ont leurs contrats natifs propres. Aucun de ces montants ne représente le budget d'un club réel.

Les soixante photos de villes/stades sont des archives réelles dont les auteurs, pages sources, licences et transformations sont conservés dans `club-atlas-credits.md` et le manifeste de l'atlas, également embarqués dans le ZIP. Les portraits de cette édition sont fictifs, générés par IA et explicitement légendés. Les blasons sont des créations de présentation du jeu. Aucun asset du skin Golden Boy n'est redistribué par cet export.

Ce lot ne charge ni ne modifie la BDD Rugby Réel, ses identités, postes ou calibrations en cours chez l'autre producteur. Le worker natif accepte les carrières fictives historiques à 14 clubs et les nouvelles France30 ; l'import LNR n'est pas annoncé comme disponible dans cette édition. Les constats BDD de la PR389 restent un chantier distinct.
