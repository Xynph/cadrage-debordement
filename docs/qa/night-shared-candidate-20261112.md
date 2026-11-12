# Candidat partagé de nuit — réception avant campagne commune

Le lot reste dans les brouillons [#572](https://github.com/Xynph/cadrage-debordement/pull/572),
[#576](https://github.com/Xynph/cadrage-debordement/pull/576) et
[#577](https://github.com/Xynph/cadrage-debordement/pull/577).
#572 contient déjà #566. Le correctif Art et ses compteurs de silence sont aussi
présents dans le lot commun #576 : ne pas appliquer deux fois leurs patchs.
Aucune fusion Cloud dans main avant **12 novembre 2026, 09 h Europe/Paris**.
La passation de cette session est prévue à 08 h 30 ; Claude garde ZIP et recette PC.

## Navigation reçue par cas

Les liens utilisent seulement les IDs de la projection et les détails existants.
Les lecteurs gardent leur contexte ; les fenêtres métier gardent leurs brouillons.
Les absences ou ambiguïtés restent du texte ou un refus sans commande métier.
La campagne commune du candidat final reste à recevoir : les lignes ci-dessous
sont des reçus ciblés, chacun attaché à son propre SHA.

| Parcours ou module | Contrôles / échecs | SHA reçu | Preuve et portée |
| --- | ---: | --- | --- |
| France depuis un mandat anglais | 23 / 0 | `8ad4b023` | [Navigation](night-navigation-20261111.md), mandat inchangé |
| Lecture joueur/club, tri, clavier, drag annulé | 133 / 0 | `37ede657` | Même document, vraie consultation et cinq tailles |
| Prospect limité et brouillon | 70 / 0 | `37ede657` | Pas de connaissance adverse supplémentaire |
| Rendez-vous, presse exacte et rencontre jouée | 103 / 0 | `0d19ddfa` | Gardes réelles, calendrier historique |
| Staff corrigé | 54 / 0 | `fbc642e1` | Trois tailles et retour annuaire |
| Devis interclubs réellement non vide | 66 / 0 | `dbe6a7e2` | Offre préparée explicitement, consultation sans confirmation |
| Rapport réellement obtenu | 47 / 0 | `d896d631` | 37 commandes publiques avant baseline, zéro après |
| Journal financier depuis graphique | 40 / 0 | `0d19ddfa` | Écriture exacte, page/focus et invalidation d’un journal modifié |
| Revue des contrats | 270 / 0 | `096f3d8f` | [Phase9](evidence/night-phase9-20261111/README.md), quatre captures dont nom long synthétique |
| Fatigue | 685 / 0 | `096f3d8f` | Même dossier, vraie carrière et cas UI isolés explicités |
| Reçus/vestiaire et double défilement | 61 / 0 | `d40311c0` | [Retour de lecture](evidence/night-management-reading-20261111/README.md), scroll à 90 px, fenêtre exacte, parole 0/0 |
| Retour depuis un lecteur issu d’une page | 50 / 0 | `58e4651e` | [Correctif](night-page-reader-back-20261112.md), confirmations métier protégées |
| Analyse/Club/Bureau sur copie WorldChamp | 72 / 0 | `bd6a5fe6` | [Trois PNG](evidence/night-analysis-club-office-20261112/README.md), source externe inchangée |
| Chaîne de lecteurs après correctif | 115 / 0 | `bd6a5fe6` | [Régression](night-page-reader-back-20261112.md), pas de nouveau verdict Windows |
| Analyse/Club/Bureau depuis carrière publique common0 | 72 / 0 | `0e644e61` | [Préparation et replay](office-public-preparation-20261112.md), vingt commandes réelles, 72,938s au total |

L’[inventaire des liens](night-links-inventory-20261112.md) distingue ajouts,
réutilisations, sources sans IDs et périmètres réservés. Les inventaires plus
anciens sont datés et ne remplacent pas ce tableau de réception.

## Gestion observée

- [Arbitrages](night-management-20261111.md) : trois checkpoints, quatorze
  alternatives terminées sur huit matchs, soit 112 matchs ; dix-huit matchs de
  préparation commune. Une stratégie de deux recrues reste bloquée par une
  seule place disponible. Coûts non égalisés ; pas de gagnant universel ni de
  certitude causale sur les scores.
- [Conséquences de séance](night-observed-training-20261111.md) : quatre
  politiques publiques depuis le même checkpoint ; condition et charge connues
  comparées sur les mêmes IDs. Reçu Godot 50/0 exact `5fd450b3`.
- [Mode effectif](night-effective-training-receipt-20261111.md) : 45/0 sur
  `096f3d8f`. Deux ajustements publics intense→normal et intense→repos ; les
  nouveaux reçus distinguent demande et mode appliqué, sans réécrire les anciens.
- [Concurrence](night-rival-comparison-20261112.md) : neuf dossiers, dix-huit
  transferts confirmés/repris, quarante-cinq offres de dix clubs. Les 63 non-offres
  n’ont pas de motif inventé. Les styles tactiques et fenêtres autonomes ne sont
  pas qualifiés par une négociation publique. Les lots bornés restent séparés.
- [Histoire de personnage](night-character-story-persistence-20261112.md) : deux
  choix depuis le même profil, deux journées enregistrées par branche, mémoire,
  échéances et redémarrage vérifiés. Le refus de la troisième clôture préserve
  profil, état exporté, RNG et horloge. **Limite moteur réservée à Claude :**
  249 minutes cumulées font face à une borne de validation à 240 ; hypothèse précise
  étayée, cause unique non instrumentée. Aucun contournement ni correctif moteur.

## Validation globale et coordination

Les [quatre reprises Art](night-ci-20261111.md) sont vertes sur `c8a5a61d` :
848 contrôles, 146 captures, parole 0/0. Elles ne rendent pas vert l’ancien SDK
`43099288304` sur 7b23 : 47 succès sur 48 exécutions. La marge progression CI reste
2,954s. Le benchmark local du commun sur a432 est distinct.

Le [registre partagé](sdk-common-final-registry-20261112.md) contient 75 exécutions,
56 suites distinctes et 74 couples suite/cas ; le doublon guide-layout/layout-native
est conservé. Les nouvelles inscriptions rejoignent les familles existantes,
sans modifier workflows, paramètres, permissions ou limites. Une seule campagne
SDK full et une campagne JavaScript du HEAD publié sont à recevoir après gel.

Main observé `f05708e2` a intégré #550 puis #549 (documentation uniquement).
Le dernier vert JavaScript reçu reste celui de `eb2b1833`,
[43120082969](https://github.com/Xynph/cadrage-debordement/actions/runs/43120082969)
avec sept jobs verts. La CI du nouveau main
[43128362425](https://github.com/Xynph/cadrage-debordement/actions/runs/43128362425)
est en cours au relevé. Cela ne qualifie pas le lot commun SDK ou Windows. Une
fusion virtuelle Git du lot commun avec `f05708e2` ne présente pas de conflit ;
ce n’est ni une intégration réelle ni une recette du cumul futur de Claude.

Aucun diff moteur, données, économie, calendrier, workflow, project.godot,
ressource Gabi/3D ou art depuis 6648. Les PNG Gabi générés non suivis ne sont
pas ajoutés. Aucune ressource Mixamo, conversion ou chargement GLTF à l’exécution.
La [revue indépendante](night-independent-review-20261112.md) et les essais
rouges conservés délimitent les conclusions.

Après 09 h : reprendre main réellement intégré par Claude, réconcilier les
brouillons sans double patch #566/Art, recevoir les nouveaux SHA et le gate
serveur avant fusion. Ne fermer aucune PR familiale avant intégration et
réception réelles. Le ZIP et la recette Windows restent au chantier de Claude.
