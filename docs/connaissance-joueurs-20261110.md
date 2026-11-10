# Connaissance des joueurs — contrat canonique

Politique approuvée le 10 novembre 2026. Les vraies notes restent dans le moteur ; la dernière frontière de projection applique la visibilité à toutes les copies affichables, y compris rapports, aperçu de négociation, sélections et Espoirs. Le JSON de sauvegarde reste un document interne restaurable.

| Joueur | Niveau | Potentiel | Attributs |
|---|---|---|---|
| Notre club | valeur exacte actuelle | intervalle de 5 valeurs | connus |
| Extérieur non observé | inconnu | inconnu | inconnus |
| Première observation | intervalle de 9 valeurs | intervalle de 11 valeurs | inconnus |
| Suivi approfondi | intervalle de 5 valeurs | intervalle de 5 valeurs | connus |

Les intervalles sont inclusifs, asymétriques, déterministes, bornés de 0 à 100 ; cinq valeurs signifie `max-min=4`. Le niveau au poste reste exact seulement dans notre club. Toutes les copies publiques portent `rating`, `ratingRange`, `potential:null`, `potentialRange`, et `knowledge:{version:1,owned,stage,observedAt}`. Les alias de rapport et les textes ne doivent pas réintroduire une note exacte.

Une mission distincte terminée constitue une observation ; deux missions distinctes donnent le suivi approfondi. Une rencontre terminée réellement jouée par notre club compte également, seulement pour ses participants dont les minutes sont strictement positives. Les rencontres mondiales simulées, la shortlist et la découverte ne comptent pas. Les commandes de formation payantes produisant réellement un rapport comptent également ; une découverte seule ne compte pas.

Les intervalles extérieurs sont figés à l'observation. Le suivi approfondi reste dans le premier intervalle si les vraies notes n'ont pas changé. Le potentiel du club utilise un intervalle stable, qui change seulement quand le vrai potentiel évolue. Un départ de notre effectif conserve une connaissance approfondie sous forme d'intervalles, jamais une ancienne valeur exacte.

Un manifeste `playerKnowledge` facultatif et versionné conserve les observations après la rotation des rapports. Il est validé strictement et borné à 32 000 joueurs, avec deux jetons d’événement par joueur, stockés en tuples dans au plus 16 blocs de 2 000. Cette borne dépasse le registre actif du jeu. Les archives sans joueur actif ni rapport consultable sont les seules entrées compactables ; aucun suivi actif n’est effacé et une fin de match ne rencontre pas l’ancienne limite de 2 000. Les anciennes sauvegardes restent lisibles : les rapports archivés peuvent fournir une première connaissance sans écrire ni migrer le document pendant une consultation. Aucune lecture ne consomme de RNG ni ne crée de manifeste.

Le choix d'une projection unique finale évite la divergence entre les vues. Modifier chaque interface séparément laisserait des fuites dans les rapports et aperçus ; filtrer seulement Godot laisserait les vraies notes dans le protocole. L'implémentation conserve les prix et salaires métier existants.

Le hash utilise la graine immuable `careerVariation.seed` quand elle existe, sinon l'identifiant d'édition et celui du joueur. Il ne lit jamais la graine RNG vivante du worker.

L'observation ciblée complète le trou des missions historiques, qui ne recherchent que des agents libres. `observe_player` reçoit `{playerId,confirmed:true,context:{season,week,club}}`. Le coût de 5 000 € et les deux cycles de travail utilisent le même registre et la même cadence que le recrutement existant. Les missions ciblées et historiques partagent quatre places et une file FIFO. Les emplois ciblés restent dans le manifeste optionnel, sans changer le schéma historique des missions. Planifier n'accorde aucune connaissance ; le rapport terminé le fait. La projection `player.scouting` annonce disponibilité, motif, coût, cycles restants et contexte.

Un recruteur réellement actif de la carrière (`role:scout`, affectation au club, contrat en cours) de niveau 70 ou plus termine une observation ciblée en une semaine ; les autres cas restent à deux semaines. Le meilleur niveau actif est retenu, égalités par ID. Ce délai est figé au lancement, avec `sourceScoutId` et `sourceScoutLevel`, sans dépendre de la consultation ni changer les coûts ou les intervalles de notes. La référence de staff désactivée ne donne aucun effet. Le terme semaine désigne la cadence `managerWeek` existante, pas un clic journalier.

`knowledge.owned` signifie connaissance du club, pas propriété juridique : les joueurs présents dans notre effectif, même empruntés, sont exactement connus ; nos joueurs prêtés ailleurs restent connus grâce au suivi du prêt. Une vente ou un départ définitif conserve seulement des intervalles approfondis. Les anciennes semaines cumulées des rapports ne sont pas présentées comme de fausses dates de saison : la semaine locale est reconstruite si elle est vérifiable dans la saison courante, sinon `observedAt.week=null`.

Un test supplémentaire exécute le vrai `dist/manager.js` pour vérifier la file FIFO commune aux missions historiques et ciblées, avec un seul avancement par semaine.

Vérification : `node --test tests/native-player-knowledge.cjs` couvre 21 scénarios purs (bornes, stabilité, non-observation gratuite, doublons, seuil recruteur, prêts, archives et validation). `node --test tests/native-player-knowledge-worker.cjs` traverse quatre vraies rencontres et clôtures hebdomadaires : deux rapports payants d'un joueur sous contrat, lecture/export sans écriture, sauvegarde/reprise, manifeste corrompu avec checksum valide, puis panne de renommage simulant un disque plein. Fichiers, trésorerie et graine durable restent inchangés lors des refus. Recettes worker reçues à 51,4 s puis 54,9 s ; l'UI est vérifiée séparément par le lot Bureau en 1440p.

La revue indépendante a ajouté une protection de capacité : `safeTree` accorde au seul sous-arbre `playerKnowledge` un budget séparé de 460 000 nœuds, uniquement après validation stricte du manifeste. Le budget global du reste de la carrière reste inchangé, ainsi que profondeur, texte et taille des tableaux. La borne de 32 000 tuples (deux jetons chacun) tient dans ce budget. Le test `tests/native-player-knowledge-capacity.cjs` vérifie export sous 8 Mio, vraie réouverture worker sans écriture, refus d’un intervalle corrompu et refus d’une surcharge hors connaissance. Une date de rapport terminé antérieure à sa planification est refusée ; l’égalité est conservée pour les phases historiques dont la semaine locale reste fixe pendant plusieurs clôtures.
