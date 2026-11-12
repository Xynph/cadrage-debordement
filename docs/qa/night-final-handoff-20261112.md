# Passation Cloud — Rugby Legacy 27, nuit du 12 novembre 2026

État intermédiaire à 04:08 UTC (05:08 Paris). Échéance de travail : 07:30 UTC,
08:30 Paris. **Aucune fusion Cloud dans main avant 08:00 UTC / 09:00 Paris.**
Les PR restent en brouillon. Claude garde le ZIP Windows et la recette PC.

## Branches livrées et ordre de lecture

| PR | Branche / tête figée | Rôle |
| --- | --- | --- |
| [#572](https://github.com/Xynph/cadrage-debordement/pull/572) | `7b23f7af01938928b0e29f1a4676486421e89bbc` | Base, contient déjà #566 ; ne pas réintégrer #566 séparément |
| [#576](https://github.com/Xynph/cadrage-debordement/pull/576) | `cloud/rg27-night-common-20261111` · `37e085b687b4e9a603085beaa50fecf9d6cace22` | Lot commun navigation, gestion et Art ; SDK initial rouge conservé |
| [#582](https://github.com/Xynph/cadrage-debordement/pull/582) | `cloud/rg27-night-followup-20261112` · `76077ed3f2af0ff029c8a413fc26451a25ac647f` | Correctifs de réception ; SDK complet 75/75 et JavaScript sept jobs verts sur cette même tête |
| [#583](https://github.com/Xynph/cadrage-debordement/pull/583) | `cloud/rg27-night-closeout-20261112` · `1a7b083b8a090d735ef1b08245b5f4faf430f76b` | Séance exacte, retour/brouillon et libellés de recherche ; tête finale figée pour CI |
| [#581](https://github.com/Xynph/cadrage-debordement/pull/581) | `cloud/rg27-night-receipts-20261112` | Preuves et présente passation ; branche documentaire, distincte du produit figé |
| [#577](https://github.com/Xynph/cadrage-debordement/pull/577) | `c8a5a61d1dd708f662592bf971fe8d5a25ad1742` | Reçu Art ciblé historique déjà incorporé au lot ; pas de second patch à appliquer |

Le lot est empilé #572 → #576 → #582 → #583. #581 complète les preuves et ne
constitue pas une deuxième source produit à fusionner aveuglément. Aucune PR
familiale n'est clôturée comme incorporée avant intégration réelle et reçu.

## Navigation et contexte conservé

L'[inventaire final des liens](https://github.com/Xynph/cadrage-debordement/blob/1a7b083b8a090d735ef1b08245b5f4faf430f76b/docs/qa/night-links-inventory-20261112.md)
distingue ajouts, destinations réutilisées et références indisponibles. Les
cibles passent par kind/id/route et la projection publique courante ; aucune
résolution par nom ou lecture cachée n'est ajoutée.

- France depuis un mandat anglais ouvre bien France (23/0 dans le SDK 7607),
  sans candidature, prise de poste ou changement de nation contrôlée.
- Joueurs/portraits, contrat/salaire, rapports, staff, clubs, compétitions,
  rencontres historiques et dates réutilisent les destinations et composants
  existants. Les prospects disposent d’un nouveau dossier de lecture utilisant
  les composants existants, limité aux données connues. Le dossier non observé
  garde ses informations limitées.
- Finance ouvre l'onglet ou l'écriture exacte du journal ; la barre de fatigue
  ouvre sa tranche ; les engagements et entretiens ouvrent la personne connue.
- La séance publiée ouvre son programme au jour exact par session.id. Une date
  passée n'est pas une preuve d'entraînement exécuté. Les données sans ID unique
  ou date valide restent du texte, sans lien mort ou destination inventée.
- Le retour restitue recherche, filtres, tri, sélection, défilement, focus et
  brouillons selon les parcours reçus. Le choix non appliqué de semaine type
  survit au trajet séance/retour ; modèle supprimé, déjà actif ou prochain match
  changé l'invalident, sans application ni commande.
- Presse reste liée à son courrier et à son invitation exacte. Les gardes de
  rendez-vous, causerie et match restent prioritaires, y compris si une même
  cible est déjà ouverte. Clic, clavier, tri et drag gardent leurs fonctions.

Limites explicites : courrier historique réduit à du texte sans référence
structurée, pays sans sélection projetée, cible partie/absente ou non observable.
Le suffixe technique de l'ancien résultat joueur de palette préexistait au lot ;
les nouveaux résultats Staff/Nation/Compétition ont des libellés humains.

## Réception technique, sans transfert de verdict entre SHA

| Source exacte | Reçu | Résultat / portée |
| --- | --- | --- |
| `37e085b6…` | [SDK initial 43129063385](night-common-sdk-initial-20261112.md) | **71/75**, quatre échecs conservés ; la reprise gardes 103/0 n'en fait pas un vert global |
| `37e085b6…` | [JavaScript 43129066843](night-common-javascript-20261112.md) | Sept jobs verts, 645 CJS distincts ; conditions internes SKIP SDK conservées |
| `76077ed3…` | [SDK complet 43138356742](night-followup-sdk-full-20261112.md) | **75/75**, quatre jobs ; 56 suites, 74 couples distincts et doublon Guide historique conservé ; matrices P1 4797/0 et 1905/0 + trois contrats séparés |
| `76077ed3…` | [JavaScript 43138359860](night-followup-javascript-20261112.md) | Sept jobs verts, 645 CJS distincts, gate `130946563545` |
| `b860cf95…` | [Séance et brouillon](https://github.com/Xynph/cadrage-debordement/blob/1a7b083b8a090d735ef1b08245b5f4faf430f76b/docs/qa/night-calendar-session-reading-20261112.md) | **146/0**, graphique X11 52,234 s TAP ; Agenda 61/0 et Navigation 156/0 séparés ; six contrats de registre verts |
| `1a7b083b…` | [SDK complet 43152464850](https://github.com/Xynph/cadrage-debordement/actions/runs/43152464850) | Lancé une fois à 04:05 UTC ; **en cours**, 76 exécutions attendues / 57 suites / 75 couples distincts |
| `1a7b083b…` | [JavaScript 43152477147](https://github.com/Xynph/cadrage-debordement/actions/runs/43152477147) | Lancé une fois à 04:05 UTC ; **en cours**, 646 CJS racine attendus ; aucun verdict anticipé |

Sur 7607, les quatre variantes Art passent avec **840 contrôles, 146 captures
annoncées, zéro échec**, progression 135593 ms sous son délai enfant 150 s.
Les 848 contrôles de l'ancien reçu #577 appartiennent à son autre source.
Délais enfants 150/180 s, limite VM 15 s et workflows inchangés. Le nouveau
wrapper séance garde un enfant 90 s et le superviseur existant 180 s.

Les échecs d'acceptation (absence initiale d'adaptateur, caption/Back, brouillon)
et les erreurs de harness/parsing restent séparés des verts. La revue finale
indépendante a trouvé puis reçu un unique point Important sur le brouillon ;
le correctif a son rouge 143/1 avant production, son vert 146/0 et une revue
ciblée approuvée. Aucun test qui ne fait que recopier le correctif n'a été ajouté.

## Captures et interactions réellement obtenues

- [Parcours OS natif 7607](night-native-os-nonzero-20261112.md) : **59/0**, XTest
  réel sur Linux, deux matchs préparés publiquement, rencontre historique exacte,
  score domicile/extérieur 20–10 et lecture côté club visiteur 10–20. Retour avec
  défilement **45/45**, même focus/instance et invariants inchangés. Trois PNG
  2560×1440 ; les pixels prêt/retour diffèrent à cause de la bulle Gabi transitoire,
  sans prétendre à des images identiques. Ce n'est pas une recette Windows.
- [Séance exacte et brouillon](https://github.com/Xynph/cadrage-debordement/blob/1a7b083b8a090d735ef1b08245b5f4faf430f76b/docs/qa/night-calendar-session-reading-20261112.md) :
  un PNG original 2560×1440 par reçu, contrôles 1280×720 / 1920×1080 /
  2560×1440. Événements injectés dans le viewport SDK, portée distincte de XTest.
  Le PNG précède le trajet brouillon ; ce sont les assertions réelles qui
  prouvent le choix restauré et Appliquer actif.
- Analyse/Club/Bureau ont trois [captures publiques réelles](https://github.com/Xynph/cadrage-debordement/blob/1a7b083b8a090d735ef1b08245b5f4faf430f76b/docs/qa/evidence/night-analysis-club-office-20261112/README.md),
  72/0 sur leur source propre. Les autres captures et tailles gardent leurs
  sources et nombres dans les manifestes ; aucune image synthétique n'est donnée
  comme aperçu réel.

Audio Dummy, mute précoce, compteurs réellement nuls sur les parcours qui les
sérialisent. Séance et navigation finales : demandes/débuts/identifiant 0/0/0.
Modèle complet, sauvegarde, bridge, last_command, horloge et RNG sont contrôlés
sans mutation par consultation. Les diagnostics séance ne sérialisent pas une
paire de hashes sportifs : aucun hash avant/après n'est inventé. Les manifestes
hashent les pièces publiées et les sources exactes ; aucun profil complet ou
history UI répétitif n'est publié.

## Gestion : arbitrages, concurrence et mémoire

Les améliorations de lecture réutilisent les systèmes et composants existants,
avec tableaux compacts, portraits, pictogrammes, priorités et liens de détail.
Aucune nouvelle palette, police ou direction artistique. Les effets connus sont
expliqués sans causalité certaine ou potentiel caché inventé.

- [Arbitrages](night-management-20261111.md) : 14 alternatives, huit matchs par
  branche, trois checkpoints, **112 matchs** et 18 matchs de préparation
  commune. Une stratégie à deux recrues est bloquée par la capacité réelle.
  L'académie coûte 96000, avec progression supplémentaire observée de
  +1,033 / +1,05 / +1,10 sur les trois paires à RNG et scores identiques ; aucun
  vainqueur global ni rendement salarial garanti n'est conclu.
- [Concurrence](night-rival-comparison-20261112.md) : 45 offres de dix clubs,
  neuf joueurs / trois checkpoints, 18 transferts confirmés après rechargement.
  Neuf victoires IA à l'offre demandée et neuf victoires humaines après surenchère ;
  neuf offres humaines au-delà de la trésorerie refusées sans mutation.
  L'absence de 63 offres n'a pas de cause publique certaine ; ni style tactique
  ni recrutement autonome général ne sont qualifiés. Scénarios de reprise pour
  Claude fournis sans correction économique concurrente.
- [Conséquences observées](night-observed-training-20261111.md) et
  [mode réellement appliqué](night-effective-training-receipt-20261111.md) gardent
  des preuves séparées : un mode demandé ne prouve pas le mode appliqué. La
  projection UI distingue les facteurs connus et la lecture des bilans.
- [Personnages et mémoire](night-character-story-persistence-20261112.md) : deux
  choix depuis un même profil, deux échéances, personnalité, promesse et histoire
  conservées après reprise. La troisième clôture est refusée transactionnellement,
  sans mutation. Les 249 minutes cumulées contre le plafond du validateur de 240 minutes sont une hypothèse forte,
  pas une cause unique démontrée ; moteur réservé laissé à Claude.

## Coordination et limites réservées

Main observé : `44c7ebef0edb8a04310a4c6fe9b4a221ce630e83` (#574), après
`b30c331c…` (#575) et `f9c55a92…` (#553). Les interfaces lues pour nos liens
conservent id/name et les entrées de lecture ; les garde-fous de sauvegarde par
ID restent présents. Ce constat statique ne qualifie pas les migrations runtime.

`git merge-tree --write-tree 1a7b083b… 44c7ebef…` reçoit le 12 novembre un arbre
virtuel propre `5f08188bd7c0c3c11e15bfef13b47b7f54e9a048`, code 0. Aucune
branche main déplacée et aucune recette du cumul réel n'en est déduite.

Le [repro d'archive presse](night-claude-press-archive-compatibility-20261112.md)
sur f9 puis 44 montre qu'un pack presse compatible peut transformer un fragment
de citation affichée, alors que l'entrée archive reste inchangée. C'est une
projection représentative isolée, pas une occurrence de carrière ni une migration
qualifiée. Aucun patch du moteur réservé ; reprise précise livrée à Claude.

Branches réservées, rendu, animations, économie, calendriers métier, identité et
assets Mixamo n'ont pas de développement concurrent. Aucun fichier Mixamo ou
conversion ajouté au dépôt public ; les neuf PNG Gabi non suivis sont laissés
intacts et exclus des commits. Tenue Gabi préservée, aucun chargement GLTF runtime
introduit. Aucun ZIP/Windows, nouvelle dépense, changement de permissions ou
configuration GitHub, ni clôture familiale anticipée.

## Décisions d'intégration et prochaine étape après 09 h

L'utilisateur autorise explicitement autonomie, branches et PR brouillons ; les
choix réversibles n'ont pas redemandé confirmation. Un seul auteur possède le
contrôleur commun ; chaque spécialiste travaille en worktree séparé. Tous les
Godot locaux sont sérialisés par le même verrou, sans campagne complète par agent.

Décisions de revue : sélection du programme existant plutôt qu'un bilan inventé,
ID unique et date valide obligatoires, origine capturée avant changement de vue,
focus interne par hash sans identifiant visible, données synthétiques limitées aux
cas négatifs isolés, brouillon uniquement UI validé contre les choix publics.
La proposition de délai parent 120 s aurait été ignorée par le runner : elle
n'a pas été ajoutée ; superviseur existant 180 s conservé. L'estimation de marge
famille 15,978 s reste une estimation, pas une promesse de durée CI.

Après 09 h Paris seulement : prendre le dernier main effectivement intégré par
Claude, vérifier les interfaces et conflits, construire le cumul en branche,
recevoir ses tests et gates exacts, puis intégrer en série. Les verts de sources
antérieures ne qualifient pas ce futur cumul. Ne retirer/clore les PR familiales
qu'après intégration réelle et reçu. La recette PC et le ZIP restent à Claude.
