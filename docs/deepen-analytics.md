# Historique individuel mesuré

## Conception

Une activation explicite ajoute un registre borné à 40 rencontres. Il capture seulement les matchs réellement joués dans la carrière, à leur clôture, depuis les feuilles finales `l.sheets[].minutes` et les scènes structurées `l.events[].scene`. Les deux équipes sont conservées avec le club à la date du match. Les joueurs du club actuel peuvent ensuite consulter leurs cinq dernières apparitions mesurées, y compris s'ils changent de club ou de saison.

Les seuls événements individuels retenus sont les essais, pénalités réussies et tirs de pénalité manqués ayant un acteur et une équipe identifiés. Les totaux attribués sont rapprochés des statistiques collectives : une attribution incomplète reste inconnue pour le joueur, sans transformer l'absence de scène en zéro. Plaquages, passes, conversions et mètres individuels restent inconnus. Aucun commentaire de match n'est analysé pour inventer des actions.

Les ratios par 80 minutes utilisent exclusivement les minutes réellement conservées et les matchs ayant une couverture complète de l'indicateur. Les autres lignes sont exclues du dénominateur avec une couverture visible. Zéro minute et minute absente ne produisent aucun ratio. Les résultats historiques capturés sont des copies : aucun recalcul depuis le niveau ou le club actuel.

Architecture retenue : domaine natif `playerMatchHistory`, commande d'activation et hook autour de `recordDevelopmentMatch`, après le traitement existant. Aucun changement des règles, du hasard, de la croissance ni des résultats. L'absence du champ conserve le comportement des anciennes parties et aucune donnée antérieure n'est reconstruite.

## Plan

- [x] Tester activation, captures de vrais matchs, minutes absentes, actions sans identité, couverture et ratios.
- [x] Implémenter capture bornée, validation stricte, anti-doublon et pureté des projections.
- [x] Ajouter le choix du joueur et son historique dans les analyses Godot.
- [x] Vérifier reprise/import, rollback, saisons/clubs et parcours UI réels.

## Raccordement

Ajouter `playerMatchHistory:require('./player-match-history.cjs')` aux domaines de `native-systems.cjs`, puis embarquer ce fichier dans la liste fermée du paquet moteur. L'installation du domaine enveloppe `recordDevelopmentMatch` et garde ses marqueurs. La vue existante lit `clubLife.playerMatchHistory` ; pas de changement de navigation.

## Réception

Les onze cas Node22 couvrent le vrai moteur et les scénarios de données manquantes, attribution par identité sans analyse du texte, ratio pondéré par les minutes, zéro minute, arrêt à 40 rencontres, fenêtre de cinq feuilles, état multi-saison/club, imports hostiles et anti-doublons. Une paire activée/témoin conserve exactement le même état moteur hors registre et le même RNG après une rencontre complète.

Le vrai worker est reçu avec un manifeste temporaire intégrant le domaine (sans modifier le manifeste de production réservé à l'intégrateur) : trois matchs fictifs persistants, une vraie rencontre Monde liée à son identifiant de calendrier, reprise sous une autre graine/horloge, activation atomique en cas de refus disque, export/import d'état et RNG identiques. Les octets du profil sont conservés en consultation et à la reprise. Un import explicite peut réécrire l'enveloppe du profil : il n'est pas présenté comme une opération de lecture seule.

Avec `CD_GODOT_EXE`, le test lance la vue réelle sur le modèle du worker : 28 contrôles aux formats 1280×720, 1600×900, 1920×1080 et 2560×1440, choix du joueur, lecture de ses minutes/ratios, largeur bornée, immuabilité et commande d'activation après confirmation. Recette Godot4.7.2 Linux ; pas de réception Windows revendiquée.

Une première version du banc comparait par `deepEqual` deux Buffers complets de profil après import explicite sous une nouvelle horloge. Le diff d'échec a consommé la mémoire et déclenché des SIGKILL. L'échec a été isolé sans modifier le moteur : assertions booléennes bornées, invariant d'octets positionné sur la consultation/reprise, invariant d'état/RNG maintenu après import. Les boucles de simulation du banc sont bornées à 600 pas.

## Limites

Seuls les matchs joués en direct ou délégués avec leurs feuilles finales et événements structurés sont capturés. Les simulations adverses sans scènes nominatives ne sont pas présentées comme des historiques individuels. Les joueurs partis ne sont pas listés dans l'effectif actuel, mais leurs captures demeurent dans les 40 rencontres archivées ; une même identité retrouve ses captures si elle rejoint le club actuel. Les données collectives et les apparitions antérieures à l'activation ne sont jamais converties artificiellement en statistiques individuelles.
