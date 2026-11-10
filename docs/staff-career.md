# Cycle persistant du staff et reconversions

## Activation et compatibilité

`native/engine/staff-career.cjs` est un domaine natif sérialisable, indépendant des registres d'origine. `S.staffCareer` version1, politique `staff-career-v1`, conserve une trajectoire propre à la carrière. L'annuaire initial n'est jamais édité. L'absence du marqueur garde l'ancien comportement ; une carrière existante demande une activation explicite. Le raccord worker initialise les nouvelles carrières prises en charge. Une nouvelle carrière fictive ou France sans catalogue de référence reçoit les fonctions minimales de la politique de complétion, explicitement fictives, sans inventer un annuaire officiel. Les anciens cycles sans cette politique conservent leurs cibles CORE historiques. Les anciennes carrières restent sans cycle tant qu'elles ne l'activent pas.

La source readonly injectée dans la VM est `nativeStaffCareerSources[databaseId] = registry.clubs`, tableau de `{id,members}`. Le domaine ignore les références expressément historiques, reprend les autres profils et complète les rôles manquants par des personnages de jeu identifiés comme fictifs. Les rôles cibles de chaque club restent séparés de l'annuaire.

## Âges, contrats et retraites

Un âge publié fourni par la source est dérivé selon la saison de carrière et indiqué comme tel. En son absence, le staff de référence reçoit un âge de jeu déterministe40–65ans à la date initiale, explicitement estimé. Les nouveaux compléments fictifs commencent à29–59ans selon la fonction ; les médecins fictifs ont36–56ans. Les anciens profils générés sans politique de complétion gardent leur estimation historique30–49ans. `appearanceAge` reste fixé à la création du membre ; son âge courant progresse séparément, pour que le rendu puisse conserver la même base de visage.

La retraite de jeu est estimée entre **68 et80ans**, avec possibilités75–80 ; ce n'est pas une prédiction du départ réel de la personne. Le cycle annuel vieillit les membres une seule fois. Dans un état persistant, `lastAdvancedSeason` doit égaler la saison courante moins un et l'horloge individuelle doit correspondre à cette saison ; un import qui gèle les âges ou omet une transition est refusé. Seule une reconversion capturée pendant la clôture peut porter provisoirement l'horloge de la saison suivante, liée au témoin de retraite. Les IA renouvellent leurs contrats expirés et remplacent les membres retraités ou manquants, en choisissant d'abord un candidat du rôle disponible. L'effectif humain n'est pas renouvelé silencieusement : les contrats expirés rejoignent le marché.

Le manager peut recruter, prolonger, libérer et demander une retraite volontaire à partir de60ans, avec confirmation et contexte de saison/semaine/club à jour. Les durées sont bornées1–3ans et ne peuvent dépasser l'échéance de retraite. Une personne ne peut être simultanément candidate et employée ; la projection expose les opérations réellement disponibles.

## Reconversion des joueurs

Le hook reçoit le joueur déjà vieilli lors de la clôture, avant perte de sa référence. Certains retraités deviennent candidats selon une politique déterministe explicitement de jeu : âge au moins28ans, niveau au moins60, au moins800minutes suivies ou niveau75, puis une sélection stable d'environ un tiers par identifiant. Le niveau du futur encadrant est une estimation fondée sur le niveau et le mental du joueur ; aucun trait caché n'est utilisé.

Les rôles proposés sont entraîneur, adjoint, formation, recruteur et analyste. Un ancien joueur ne devient **jamais automatiquement médecin** et aucun diplôme ou agrément officiel n'est déduit de sa carrière sportive. Le choix de rôle, le niveau et les critères sont conservés dans un témoin `conversion` explicite. Il ne s'agit pas d'un certificat professionnel réel.

Le membre possède un identifiant de staff distinct, `sourcePlayerId` conserve l'identifiant exact du joueur et `appearanceId` reste égal à celui-ci. La projection ajoute `identity.id` pour que le pack et le rendu retrouvent le nom et la même base de visage. Le portrait n'ajoute aucun bonus sportif. La validation refuse un visage différent, une reconversion médicale, une chronologie incohérente ou un joueur encore présent parmi les actifs/agents libres/jeunes.

Les deux hooks éventuels (capture IA pendant la clôture et wrapper natif après la clôture) sont dédoublonnés. Les nouveaux reconvertis ont `entrySeason` et `ageSeason` sur la saison suivante : ils ne vieillissent pas une seconde fois immédiatement lors du passage annuel.

## Économie descriptive explicite

Politique financière **`descriptive-no-cost-v1`** : salaires et primes sont explicitement **nuls** dans cette première version. Aucun débit de trésorerie, changement de coefficient ou avantage de match n'est ajouté. Une éventuelle économie de staff nécessitera un lot calibré distinct. Les recrutements et contrats changent réellement l'état, l'appartenance au club et le vivier disponible ; il ne s'agit pas de boutons décoratifs.

## API d'intégration

L'instance unique `CDStaffCareer` expose :

- `initialize(state, teams?)` : source readonly de l'édition, no-op si actif ; source vide et profils fictifs si édition sans catalogue ;
- `captureRetirement(state, player, ownerId?)` : no-op sans marqueur, capture idempotente du joueur vieilli ;
- `advance(state, completedSeason)` : après incrément de `state.season`, une seule application par année ;
- `validate(state)` : absence de marqueur compatible, sinon schéma fermé, contrats, provenance, âges et visages contrôlés ;
- `project(state)` : état visible, disponibilités, équipes, candidats et historique ;
- `execute(command,payload)` : commandes publiques du domaine, au sein de la transaction du worker.

Les commandes sont `staff_career_enable`, `staff_hire`, `staff_renew`, `staff_release`, `staff_retire`. Tous les payloads contiennent `context:{season,week,club}` et `confirmed:true`. Recrutement : `candidateId,years` ; prolongation : `staffId,years` ; départ/retraite : `staffId`. Les champs inconnus et le contexte périmé sont refusés.

`project()` retourne `active,canEnable,reason,context,teams,candidates,retired,history,costs,roles,maxYears`. Les alias `enabled`, `market` et `archives` permettent le raccord existant. Chaque membre expose `canHire/canRenew/canRelease/canRetire`, ses bornes de durée, ses identifiants d'origine et son âge de base immuable. Le worker reste propriétaire du disque, de la validation de sauvegarde, du rollback et des packs ; le domaine ne les contourne pas.

## Bornes et qualification

Le stockage des personnes est paginé par256 pour respecter la limite générique de2000éléments par tableau de sauvegarde. L'historique conserve512événements ; le marché192candidats ; le cache de captures récentes1900identifiants sur deux saisons. Les personnes actives gardent leur provenance propre même après expiration du cache. Les joueurs hérités contenant guillemets ou esperluettes ne sont pas modifiés et ne bloquent pas le hook de retraite. Les rôles et noms source contenant des guillemets ou `&` sont normalisés uniquement dans leur copie persistée ; le registre source reste byte-identique.

`node --test tests/staff-career.cjs` : neuf tests de domaine réussis sous Node22, zéro échec/ignoré, environ0,3seconde. Ils couvrent activation, commandes réelles du domaine, contexte périmé,18transitions de cycle, retraite et renouvellement IA, croissance bornée, sérialisation, reconversion/visage/dédoublonnage, et le registre complet Monde+Champ. Le témoin actualisé de complétion initialise3134personnes sur13pages, pour1 753 638octets de cycle dans le scénario de domaine mesuré (3104employés et30candidats). Ce sont des transitions du domaine, pas une nouvelle simulation de dix-huit saisons sportives.

Le raccord natif séparé doit recevoir les commandes par le vrai worker, vérifier import/réouverture et refus disque avec rollback. Ses tests et le rendu sont distincts de ces preuves de domaine ; aucune recette Windows n'est revendiquée ici.


## Complétion fonctionnelle initiale — 10 novembre 2026

La politique optionnelle `completionPolicy:staff-completion-v1` concerne les nouveaux cycles. `staff-completion.cjs` compose les références inchangées avec des ajouts `sourceKind:generated`, jamais reclassés comme références. Les fichiers JSON documentés et les IDs autorisés aux packs restent inchangés. Le relevé [France30/Monde116](staff-completion-20261110.md) donne les effectifs et ajouts par club, avec son détail JSON.

Les cibles de jeu sont15 pour base<72,20 entre72et81 et26 à partir de82, sans diminuer les grands staffs. Les15fonctions minimales comprennent quatre postes techniques, trois postes physiques, médecin et deux kinés, analyse, recrutement, formation, team manager et intendance. Chaque personne couvre au plus une fonction minimale dans un appariement déterministe. Des coachs/adjoints génériques peuvent couvrir les fonctions techniques, des préparateurs les trois fonctions physiques, et la direction/intendance les fonctions support : c’est une affectation estimée de jeu, sans renommer la source ni prétendre documenter une spécialité officielle. Les fonctions médecin/kiné exigent un intitulé explicite ; un soigneur n’est jamais transformé en médecin ou kiné.

Chaque club de la source composée possède un contexte de création immuable. Le cycle conserve `completionOrigins[{clubId,base,country}]`, validé contre ce contexte, et des cibles de fonctions typées. La puissance sportive `club.base` peut ensuite évoluer, franchir71/72ou81/82, sans recréer les noms, visages, niveaux ou cibles des employés initiaux. Un nouveau recrutement peut recevoir une estimation fondée sur le club à sa création, conservée dans son témoin `generation`.

Les compléments emploient un nom complet fictif stable, une apparence de la banque2 locale et les marqueurs `identityStatus:fictional`/`portraitStatus:synthetic`, également dans `identity` pour le raccord de présentation. Les références gardent leurs données et leur mécanisme de pack. Le marché conserve les rôles canoniques et propose aussi les fonctions manquantes. L’IA remplace annuellement les fonctions/catégories cibles ; le club humain n’est jamais rempli après un licenciement ou une expiration choisie. Les retraités ne réapparaissent pas via l’annuaire initial.

Les anciennes carrières actives sans marqueur restent validées avec leur contrat antérieur : aucune migration, génération ou activation à la lecture/import/reprise. Aucun coût, bonus ou tirage RNG ajouté. Les nouvelles données de provenance sont strictes : une personne fictive ne peut être importée comme référence, ni changer de visage ou de témoin de génération.

Preuves dédiées : `tests/staff-completion.cjs`, `tests/native-staff-completion.cjs`, `tests/native-staff-completion-season.cjs`. Le dernier exerce la vraie commande native `next_season` depuis une fixture de fin de saison compatible (ce n’est pas une simulation sportive complète), avec deux hausses réelles de l’IA qui franchissent les seuils et un redémarrage conservant les identités/cibles.
