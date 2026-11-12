# Passer de « sympa » à « génial » : dossier de décision

Rédigé le 11 novembre 2026 à la demande de Léo. Cible donnée : des menus
fonctionnels et beaux du niveau de Football Manager 24, Pro Cycling Manager
ou Tennis Manager, un match lisible à la manière de FM, 100 € de budget au
maximum et de préférence rien, quitte à changer de moteur.

Ce document recommande ; les durées sont des estimations, pas des mesures.

## Ma réponse en trois phrases

1. **Ne change pas de moteur.** Ce qui manque au jeu n'est pas dans Godot.
2. **Arrête d'ajouter des systèmes pendant six semaines** et reconstruis deux
   choses : le socle des menus et la présentation du match.
3. **Décide sur pièces** : une tranche de démonstration de deux semaines,
   avec des critères écrits à l'avance.

## Ce que font vraiment les jeux cités

Ils ne gagnent pas par leur 3D. Ils gagnent par cinq mécanismes d'interface,
présents sur tous leurs écrans :

| Mécanisme | Chez eux | Dans le jeu aujourd'hui (#543) |
| --- | --- | --- |
| Un tableau commun : tri, filtres, colonnes au choix, vues enregistrées | Partout, identique | Tri et filtres refaits écran par écran ; PR séparées pour l'effectif, le recrutement, les contrats |
| Tout nom est un lien vers une fiche, avec retour arrière | Systématique | Recherche `Ctrl+K` et historique présents ; liens partiels |
| Une boîte de réception qui pilote la semaine, un bouton « Continuer » | Cœur de la boucle | Réception et « Jour suivant » présents : bonne base |
| Une réponse immédiate à chaque clic | Oui | Non : 5,3 Mo échangés par commande, environ une seconde sur la machine de mesure |
| Un match qui explique le résultat : temps forts, statistiques, zones | Oui | Journal et statistiques présents ; mise en scène plate |

Deux faits utiles sur les références :

- **Football Manager 26 a changé de moteur** (passage à Unity, après une
  année sans sortie). La critique salue le match et juge les menus
  désorientants, à corriger par de nombreux correctifs. Même un grand studio
  a perdu son interface en changeant de moteur.
- **Pro Cycling Manager 25 est passé à Unreal Engine 5** pour ses courses en
  3D, avec un studio complet. Ce n'est pas un chantier pour une personne.

Le moteur de Tennis Manager n'a pas été vérifié.

## Trois scénarios

| | A. Godot, socle refait | B. Unity | C. Unreal |
| --- | --- | --- | --- |
| On garde | Simulation, sauvegardes, données, illustrations, 149 scripts | Simulation et données | Simulation et données |
| On refait | Socle des menus, trois écrans pilotes, présentation du match | Toute l'interface (37 000 lignes), le match, la chaîne de build | Idem, avec un outillage d'interface peu adapté aux tableaux |
| Premier résultat visible | 2 semaines | 2 à 3 mois | 3 mois ou plus |
| Retour au niveau actuel | Immédiat, on n'en descend pas | 4 à 6 mois | 6 mois ou plus |
| Gain sur un match « à la FM » | Suffisant | Équivalent | Supérieur, mais inutile pour cette cible |
| Coût | 0 € | 0 € en dessous des seuils de licence | 0 € en dessous des seuils |
| Risque principal | Discipline : ne pas rouvrir 40 PR | Perdre des mois sans jeu jouable | Idem, plus un jeu de plusieurs Go |

Recommandation : **A**. B ou C ne se justifieraient que pour une 3D proche
d'une retransmission télévisée, que tu n'as pas demandée.

## Ce que « refaire le socle » veut dire

**Menus**

- Un tableau commun (tri, filtres, colonnes, sélection, clavier), utilisé
  par l'effectif, le recrutement, les contrats, les classements et la
  formation. C'est la pièce qui manque le plus.
- Des fiches liées : joueur, club, match, staff. Tout nom affiché y mène.
- Un thème unique (plan dans la PR #548) et des écrans construits en
  conteneurs, qui s'adaptent de 1280×720 à 2560×1440.
- Un moteur qui ne renvoie que ce qui a changé : objectif, une réponse en
  moins de 100 ms pour les actions courantes.

**Match**

- Trois modes comme FM : tout le match, temps forts, résultat immédiat.
- Une caméra latérale stable (PR #545) et des plans de coupe sur les essais,
  les pénalités et les cartons.
- Des animations propres au rugby : passe, réception, plaquage, ruck, mêlée,
  touche avec porteurs, coup de pied, essai. Aujourd'hui les joueurs courent
  et se tiennent debout.
- Un stade modelé, des tribunes animées, une pelouse texturée.
- Après le match : zones d'occupation, origine des points, duels gagnés.

## Avec 0 à 100 €

| Besoin | Piste | Coût | État |
| --- | --- | --- | --- |
| Courses, appuis, chutes, gestes génériques | Universal Animation Library de Quaternius, plus de 120 animations | Gratuit, CC0 | Licence et formats vérifiés sur la page de l'auteur ; non essayée |
| Gestes de rugby | À créer dans Blender avec la chaîne d'animation déjà présente dans le dépôt ; Blender semble installé sur le PC | 0 € | À essayer sur un geste (la passe) |
| Gestes de rugby, autre voie | Mixamo (coups de pied, plaquages, réceptions) ou capture de mouvement à partir d'une vidéo | Gratuit avec compte ; conditions à vérifier | Non vérifié |
| Stade et accessoires | Modélisation dans Blender ; génération locale d'images et de modèles (ComfyUI et Tripo semblent installés sur le PC) | 0 € | À essayer sur les poteaux et une tribune |
| Réserve | Un lot d'animations de sport payant, seulement si la tranche montre un manque précis | 100 € au plus | Rien d'identifié à ce jour |

Je n'ai trouvé aucun lot d'animations spécifique au rugby. C'est le vrai
point dur du match, quel que soit le moteur.

## La tranche de démonstration (deux semaines)

1. **L'écran Effectif** refait sur le tableau commun et le thème unique,
   d'après la maquette, avec réponse instantanée.
2. **Vingt secondes de match** : une touche, un ballon porté, un essai, avec
   les nouvelles animations, la caméra latérale et un plan de coupe.

Critères fixés avant de commencer :

- trier, filtrer et ouvrir une fiche sans attente perceptible ;
- lisible sans réglage en 1280×720 et en 2560×1440 ;
- les trois gestes de rugby se reconnaissent sans légende ;
- 60 images par seconde sur le PC en qualité « Équilibré » ;
- tu regardes le résultat et tu dis « c'est ce niveau ».

Si le dernier critère échoue à cause du rendu ou des animations, et
seulement dans ce cas, on rouvre la question du moteur avec un essai
comparatif de la même séquence.

## Ce que je déconseille

- Ouvrir de nouveaux systèmes (économie V2, nouvelles ligues, nouveaux
  personnages 3D) avant la fin de la tranche. Le jeu a déjà plus de
  profondeur qu'il n'en montre.
- Corriger l'interface par petites PR indépendantes : 49 correctifs du 10
  novembre touchent les écrans que l'intégration réécrit.
- Viser le photoréalisme. La cible est la lisibilité.

## Sources consultées le 11 novembre 2026

- [Critique de Football Manager 26, Top Gear](https://www.topgear.com/car-news/gaming/football-manager-26-review-fantastic-match-engine-tangled-mess-menus)
- [Universal Animation Library, Quaternius](https://quaternius.com/packs/universalanimationlibrary.html)
- [Tour de France et Pro Cycling Manager sous Unreal Engine 5, communiqué](https://gamespress.westeu-v2.propressroom.com/Tour-de-France-and-Pro-Cycling-Manager-Are-Using-Unreal-Engine-5) : titre relevé dans les résultats de recherche, page non lue
