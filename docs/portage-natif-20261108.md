# Portage des idées GitHub — réception du jeu natif

État local du 8 novembre 2026, sur `feature/portage-inventaire-20261108`, avant publication du nouveau lot. Ce document complète l'[audit initial des 31 candidats](idees-github-20261108.md). « Reçu source » désigne du code et des tests réellement exécutés ; cela ne signifie ni fusion GitHub ni réception du futur exécutable. Les preuves de livraison seront ajoutées après ces étapes.

## Ce qui devient jouable

| Candidat | Comportement disponible dans la source native | Réception et limites |
|---|---|---|
| C01 — Postes | Registre v2 conservé ; rapprochement par ID des16dossiersV16 | Douze conformes, quatre quarantaines exactes ; aucune réapplication globale. |
| C02 — Notes et potentiel | Courbes de progression existantes observées dans neuf carrières réelles | Neuf S1, huit S2semaine2,53checkpoints ; une limite de banc. Aucune recalibration activée. |
| C03 — Adversaire | Dossier, résultats récents, forces projetées et choix de préparation | Estimation du staff distinguée des faits observés ; aucune tactique adverse annoncée certaine. |
| C04 — Zones et préparation | Plan avec quatre zones, phases arrêtées, priorités et conseils locaux | Les suggestions de zone restent visibles même si le plan général convient ; changements bornés et contrôlés. |
| C05 — Pause et infériorité | Conseils du staff reliés à la situation réelle du match | Lecture et commandes disponibles à la pause ; aucun temps de jeu ne remonte. |
| C06 — Débrief | Plan initial, utilisation et bilan tactique conservés après validation | Un match ancien sans détail n'obtient pas de données inventées. |
| C07 — Besoins et horizon | Couverture de postes, échéances et projection à trois saisons | Salaires et trésoreries de simulation ; prévision fondée sur les engagements connus. |
| C08 — Recrutement | Missions, rapports et liste de joueurs suivis persistante | Suivre ou retirer un joueur reste possible à effectif plein ; identité suivie par ID après changement de pack. |
| C09 — Développement | Dossier des jeunes, conseils et trajectoires individuelles | Attributs, rating scalaire et note au poste sont distingués. |
| C10 — Centre et générations | Parcours, prêts, observations, réseau et saisons Espoirs | Activation explicite ;44centres simulés, dont14invités fictifs, sans prétention de reproduire une compétition officielle. |
| C11 — Travail du staff | Réunion, conseil, plans de travail, décisions médicales | Effets, coûts, verrous hebdomadaires et reprise contrôlés. Le médical reste une abstraction ludique. |
| C12 — Identités du staff | Staff anonymisé dans le programme, fonctions et portraits par pack | Pack privé :428personnes,324photos officielles. Les104autres portraits ne sont pas présentés comme disponibles. |
| C13 — Direction sportive | Priorité, projets et bilan de saison | Les dossiers administratifs restent liés au club lors d'une mobilité du coach. |
| C14 — Finances | Investissement formation/installations, engagements et décisions | Montants fictifs ; aucun budget réel attribué à un club. |
| C15 — Vestiaire hebdomadaire | Événement, trois décisions et conséquences persistantes | Gardes de contexte ; décision unique, rollback en cas d'échec d'écriture. |
| C16 — Monde et rivalités | Événements interclubs, mémoire, bilan et archives | Faits issus des rencontres simulées ; histoire antérieure absente non inventée. |
| C17 — Mobilité | Candidature, offre et changement de club à l'intersaison | Deux sens entre divisions reçus ; pas de salaire personnel fictif ajouté. |
| C18 — Supporters | Politique de prix, campagne et accueil | Coûts et prévisions raccordés au calendrier ; pas de seconde recette de billetterie. |
| C19 — Présentation3D | Ballon tenu, bras ajustés, course, caméras et niveaux de détail | **Partiel** : le contact à deux corps et un système complet de plaquage ne sont pas qualifiés. |
| C20 — Gabi | Première visite, vraies décisions importantes, aide et visite manuelles | **Partiel pour la voix finale** :38anciens clips provisoires,36nouveaux textes explicitement en attente ;13fichiers Google préparés hors programme avant un nouveau quota429. |
| C21 — Fiches et DA | Carnet original, tuiles distinctes, fiches, comparaisons et six rubriques | Captures réelles des pages et sous-onglets ; la lisibilité à720p fait l'objet d'une seconde passe. |
| C22 — Journal rugby | Articles factuels, nouvelles et chroniques contextualisées | Les classements utilisés correspondent aux tables canoniques du championnat. |
| C23 — Conférences |500questions, cinq réponses chacune dont Humour ;30journalistes | Personnalités ludiques, relation et mémoire avec le coach ; texte de la variante effectivement posée archivé. |
| C24 — Sponsors et conseil | Choix du sponsor, revenu prévu et bilan de direction | Signature unique et effets financiers contrôlés ; aucun doublon de versement. |
| C25 — Confrontations | Dossier des rivalités, palmarès et mémoire du club | Comparaison des saisons limitée aux rangs, divisions, titres et mouvements réellement conservés. |
| C26 — Liens et engagements | Duos, médiation, leadership, conversations et promesses | Effets sportifs et obligations durables ; pas de simple choix décoratif. |
| C27 — Échéances du conseil | Objectifs datés et revues de direction | Semaine de saison et semaine comptable cumulative distinguées, y compris en S2. |
| C28 — Espoirs natifs | Dossier et promotion des15jeunes du club | Ancienne et nouvelle promotion partagent les plafonds et quotas ; places de retour des prêts réservées. |
| C29 — Agents | Devis, stratégie de négociation, mandat et confirmation | Coûts et durée connus avant signature ; reçus cumulés S2 reçus sans conversion de date. |
| C30 — Briefing | Choix ciblé, contrepartie et plan figé au coup d'envoi | Le live conserve son briefing après reprise ; remise au neutre à la nouvelle saison. |
| C31 — Délégation | Préparation et sélection confiées explicitement au staff | Les décisions restent soumises aux mêmes gardes de séance et de feuille. |

## Navigation et améliorations supplémentaires

Les rubriques sont **Bureau**, **Équipe**, **Développement**, **Club**, **Compétitions** et **Carrière**. Chaque rubrique garde son dernier sous-menu. La palette `Ctrl+K` cherche les écrans et de vrais joueurs ; `Alt+←/→` parcourt l'historique sans détourner les touches d'un champ de texte ou d'une fenêtre de confirmation.

Dans Club, **Territoire / Histoire** permet de comparer deux saisons archivées sans fabriquer de points ou de budgets anciens. Dans Match, **Direct / Journal / Banc / Stats** distingue les cinq derniers faits de la lecture filtrable de tous les événements. Le journal conserve recherche, filtre et position pendant le match, puis reconnaît un remplacement de carrière.

Les paramètres locaux conservent volume, qualité, caméra et mouvement réduit entre les carrières. Le mode calme fixe la caméra tactique et immobilise les animations décoratives de Gabi ; le match et sa voix continuent. Ces préférences n'entrent pas dans la sauvegarde sportive. Un échec d'écriture reste visible et conserve le dernier fichier valide.

La seconde passe de lisibilité restructure Préparation en **Dossier / Consignes / Entraînement**, compacte le Journal et adapte Gabi. Elle reste en réception au moment de cette rédaction. Le passage global aux pixels natifs sera décidé après comparaison de vraies captures ; aucun confort à125/150%DPI,4K ou ultrawide n'est annoncé validé.

## Fiabilité et limites explicites

Le worker garde l'autorité unique sur les transactions, les sauvegardes et le hasard. Les domaines optionnels ont des schémas fermés et reconnaissent les anciennes carrières. Les erreurs disque annulent la décision et préservent état/RNG/fichier. Pour les fichiers UI et exports Godot, le remplacement partagé sous Windows évite la suppression préalable du fichier cible ; aucun contournement ou repli silencieux n'est utilisé.

Les campagnes longues de quinze saisons et les imports hostiles sont des observations de compatibilité, pas une preuve de toutes les combinaisons possibles ni une certification des lois du rugby. Le catalogue initial est un monde fictif de30clubs : il ne publie pas la composition officielle d'une saison réelle. Les dossiers BDD contradictoires et le plafond historique de60agents libres restent documentés dans le [rapprochement BDD](conciliation-bdd-20261108.md).

La présentation3D a été mesurée sur RTX4080SUPER. Une machine modeste reste à recevoir. La production vocale Google a rencontré un quota ; aucune facturation ni substitution finale dissimulée n'a été activée. Le pack privé, les photos du staff et la clé locale restent exclus du programme public et de GitHub.
