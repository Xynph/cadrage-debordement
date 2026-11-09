# Oval Legacy 27 — Rugby Manager

**Un jeu de management de rugby à XV, en français : préalpha Windows native Godot 0.7 et version web historique.**

Dirigez votre club : composez les 23, préparez votre équipe, recrutez, gérez les contrats et suivez les rencontres.

Ce dépôt contient le code du jeu, sa documentation et ses tests. Les carrières Windows restent dans un profil local indépendant de l'exécutable ; les parties web restent dans le navigateur. Aucune sauvegarde personnelle n'est stockée sur GitHub.

## Préalpha Windows native Godot 0.7

La création propose le **Monde**, avec 56 clubs jouables en Élite, Accession, PREM et URC. Deux clubs invités disputent uniquement les coupes européennes. Les 3 208 joueurs et 808 membres de staff ont des identifiants communs à la base anonymisée et aux packs personnalisés. Les coupes des champions et le Challenge européen se jouent dans la même carrière que le championnat ; les promotions françaises et les qualifications européennes sont recalculées à chaque intersaison.

L'édition **France 30** reste disponible, avec ses 1 592 profils conservés. Les sauvegardes historiques restent lisibles avec leur limite de 8 Mio ; le Monde dispose d'un format borné à 16 Mio. Les packs et préférences de création sont propres à chaque édition. Les [règles et sources](docs/world-competition-rules-20261109.md), le [calibrage des effectifs](docs/world-data-calibration-20261109.md) et la [réception progressive](docs/mission-database-20261109.md) détaillent ce qui est vérifié et les conventions de simulation.

Le jeu dispose d'un accueil photographique, d'une création de carrière par club et de vingt écrans de carrière regroupés dans six rubriques : **Bureau, Équipe, Développement, Club, Compétitions et Carrière**. Chaque rubrique conserve son dernier sous-menu. L'interface associe anthracite, ivoire, couleurs du club, portraits fictifs et soixante photographies des trente territoires. Le [tableau de portage natif](docs/portage-natif-20261108.md) distingue les fonctionnalités reçues en source, les limites et la réception de la distribution.

Le Bureau **« Le carnet du club »** réunit un journal ivoire, les décisions de contrats et de sélection, le prochain rendez-vous photographique, quatre rencontres à venir, cinq fiches du groupe et un classement de proximité de huit clubs. Ses chiffres proviennent de la carrière ; les panneaux défilent localement pour garder une lecture confortable. Les boutons ouvrent les vraies fiches et les vues de préparation, calendrier, classement et finances. Voir [la réception du Bureau](docs/bureau-carnet-20261107.md).

La même direction artistique habille tous les menus natifs. Préparation sépare **Dossier / Consignes / Entraînement**. Le match propose **Direct / Journal / Banc / Stats** ; le Journal filtre tous les faits sans remonter le temps. **Club → Histoire** compare les divisions, rangs, titres et mouvements réellement archivés. Les points ou budgets historiques absents ne sont pas inventés. Voir aussi la [première déclinaison du carnet](docs/da-carnet-20261107.md).

L'effectif et le recrutement proposent recherche sans accents, filtres, tri et comparaison des vrais dossiers. Les joueurs suivis sont désormais conservés dans la carrière, y compris à effectif plein. `Ctrl+K` recherche un écran ou un joueur ; `Alt+←/→` parcourt l'historique. Le jeu démarre en **plein écran** ; **Paramètres → Fenêtré 1440×900** permet de réduire l'affichage pour la session. Les paramètres conservent volume, caméra, qualité et mouvement réduit indépendamment de la carrière. Le pied de page rappelle le dernier choix pris en charge ; **Dernières décisions** permet de relire dix reçus de la session, au clavier aussi. Une contre-offre n'est pas présentée comme une signature et une erreur de sauvegarde reste prioritaire.

La presse réunit **500 questions, cinq réponses par question dont Humour et 30 journalistes** référencés ou fictifs. Les personnalités sont simulées ; la relation et les échanges suivent le coach. Vestiaire, duos, promesses, rivalités, sponsors, objectifs, projets et supporters ont des décisions et conséquences persistantes. La mobilité entre clubs se prépare à l'intersaison.

Dans les deux éditions, les packs personnalisés changent les identités et images ; progression, contrats, résultats et notes de la carrière restent les mêmes. Composition à 23, entraînement, charges individuelles, tactiques, changements et offres de contrats ont des effets réels. Une promotion de secours peut compléter une feuille, après confirmation de son coût salarial.

La Formation expose les quinze espoirs du club et la progression des professionnels. Les parcours avancés s'activent explicitement : détection, réseau, prêts, suivi, générations et compétitions juniors simulées. Les 44 centres incluent 14 invités fictifs ; ce dispositif ne reproduit pas un championnat officiel. Les promotions historiques et avancées partagent leurs quotas et places, y compris les retours de prêt. La capacité du mode commun suit l'effectif initial du club +6, minimum 42 et maximum 100 ; les modes historiques gardent 42. Le dossier adverse, les besoins, échéances, missions et bilans restent accessibles. Voir les [décisions initiales](docs/decisions-natives-20261108.md) et le [portage actuel](docs/portage-natif-20261108.md).

Les trente staffs disposent de 428 références anonymisées. Un pack v2 peut présenter leurs identités et portraits sans modifier la simulation ; les packs v1 restent compatibles. Le relevé distingue les dates et références historiques. Le pack privé enrichi contient 324 photos officielles et reste séparé de la distribution de base. Voir la [couverture des staffs](docs/staff-20261108.md).

Décompressez l'archive complète puis lancez `OvalLegacy27.exe`. Godot et Node sont embarqués : aucune installation supplémentaire ni navigateur n'est nécessaire. Le profil est conservé dans `%APPDATA%\CadrageDebordement\PrototypeGodot`, hors de l'exécutable. Le menu conserve export, import et reprise des anciennes carrières fictives à 14 ou 30 clubs ; elles ne sont pas converties automatiquement en base commune.

Depuis la création d'une carrière ou ses paramètres : **Importez un pack personnalisé**. L'analyse annonce la couverture et distingue photos officielles et illustrations IA ; l'installation et la sélection sont explicites. Les images du pack privé restent séparées du jeu de base. Deux exemples de packs de noms, dont un avec staff, sont livrés dans `Packs/`.

Le [rapport Godot 0.3 et packs](docs/rugby-real-native-packs-20261107.md) détaille la réception Windows, le format personnalisé et les lacunes des données. Le [rapport Godot 0.2](docs/godot-carriere-20261107.md) reste historique. La scène 3D est générique, les finances sont fictives, le monde est fermé sans Nationale et la cadence de 34 semaines est une abstraction. Le format de compétition 2026–2027 reste distinct des lois de match historiques partiellement couvertes. Cette préalpha prépare une version commerciale ; aucune publication Steam n'est annoncée.

## Coach, prise en main et références des effectifs

Gaston Darroux, dit **Gabi**, présente son passé de pilier et d'entraîneur du Sud-Ouest. Bourru, chaleureux et drôle, il dispose de seize poses et de 74 fragments courts sur 25 pages. Premières visites et décisions importantes déclenchent un conseil, puis il reste discret. La petite bulle BD flotte sans panneau extérieur ni espace réservé ; une invitation garde accessible un conseil qui ne peut pas être montré sans masquer une commande. Aide et visite manuelles restent disponibles dans **Paramètres → Aide du coach**, avec des préférences séparées de la carrière.

**Les 74 répliques finales sont enregistrées avec la voix ElevenLabs retenue**, après activation de Starter par Léo. Elles sont lues localement ; les essais Free restent hors de la distribution commerciale. Les 38 prises historiques et leurs empreintes restent intactes dans l'archive. La bouche respecte les silences du signal enregistré, avec un cache borné ; le mouvement réduit reste disponible. Le repli système intervient seulement si un enregistrement manque ou devient illisible. Voir la [production et les vérifications finales](docs/native07-gabi-finalisation.md). Le [guide initial](docs/coach-guide-20261107.md) reste historique.

Les [preuves de production et conditions vérifiées](docs/voix-gabi-production-20261108.md) précisent cette limite, sans promettre de droits exclusifs ou de quotas futurs.

## Lot natif 0.6 — en réception, non livré

Léo a demandé une nouvelle passe de **densité PC pour le2560×1440** : référence native sans agrandissement depuis le1080p, corps12px, commandes28px, tableau plus riche et dossier réparti en petites tuiles. Cette disposition est en réception ; elle remplace la première passe présentée ci-dessous.

La fiche en source affiche jusqu'à36joueurs par page en1440p, six panneaux de faits et quatre panneaux contextuels : **Concurrence au poste / Développement / Forme et prestations / Staff et carnet**. La progression annuelle provient des vrais bilans de carrière ; aucune série individuelle par match n'est inventée. Cette présentation a reçu ses contrôles de disposition et une capture Windows réelle ; son nouvel exécutable reste à recevoir.

Ce lot réduit la typographie et les marges communes ; l'effectif, le marché, le calendrier et le classement utilisent des pages ou des onglets pour garder les commandes essentielles visibles. Les paramètres sont regroupés sous **Confort / Son / Affichage**. Le Bureau et les dossiers des joueurs ouvrent un **carnet du coach** : ses notes libres suivent la carrière et restent intactes lors des changements de pack. Voir [lisibilité](docs/native06-lisibilite-20261108.md), [carnet](docs/native06-carnet-20261108.md) et [raccordements](docs/native06-raccordements-20261108.md).

La presse reprend une déclaration réellement archivée lors d'une relance du même journaliste. Les rapports de recrutement séparent faits, avis et réserves sans dévoiler les attributs cachés. Le match améliore les démarrages, rotations, appuis et transitions du ballon ; les contacts à deux corps restent incomplets. Six sons procéduraux originaux apportent une première ambiance, avec des volumes interface et stade distincts. Voir [presse et recrutement](docs/native06-presse-recrutement-20261108.md), [mouvement](docs/native06-match-20261108.md) et [son](docs/native06-son-20261108.md).

Les joueurs 3D portent désormais maillot, short et chaussettes hautes, avec une carrure renforcée et des carnations et cheveux variés. Cette adaptation du modèle CC0 conserve ses articulations et animations. Les captures réelles du prototype montrent le résultat ; elles ne constituent pas une réception sur PC modeste. Voir [silhouettes, performances et limites](docs/native06-silhouettes-20261108.md).

Les contrôles ciblés et revues de ces lots ont été exécutés. Le [nouveau candidat Windows](docs/native07-reception-windows-20261108.md) passe **1 450 contrôles**, reçoit **103 captures aux quatre résolutions** et décode les74répliques depuis son PCK. Le premier lancement dans le nouveau chemin reste à28,2secondes ; sa cause n'est pas entièrement isolée. L'[optimisation des sauvegardes](docs/native06-performance-20261108.md), isolée dans la PR398, est fusionnée : CI exacte et sept jobs post-fusion réussis sur `f335fb76`. La CI propre au lot graphique et son installation restent à contrôler.

La finition des menus ajoute une coque anthracite, une identité de club, des pictogrammes originaux et des tuiles plus distinctes. Les classements présentent V/N/D en vert, ambre et rouge avec lettres et légende ; un indicateur absent reste inconnu. Le Bureau rassemble des cartes compactes, trois échéances réelles et les vues de la ville et du stade. La palette et l'historique rendent visible le joueur demandé même s'il se trouve sur une autre page. Voir [direction artistique](docs/direction-artistique-20261108.md), [menus](docs/native07-direction-menus.md) et [couleurs](docs/native06-couleurs-20261108.md).

Le contact 3D reçoit une préparation debout et une protection du ballon lorsque les deux corps sont réellement proches. Ce rendu ne fabrique ni plaquage, chute, blessure ni décision sportive ; les trajectoires et la simulation restent inchangées. Les [mesures et limites](docs/native07-contacts.md) distinguent cette finition visuelle d'un futur système complet de contacts.

Le [récapitulatif initial des idées GitHub](docs/idees-github-20261108.md) confronte dix-huit familles au code alors chargé. Son [tableau de réception](docs/portage-natif-20261108.md) suit les 31 candidats : presse, rivalités et formation avancée sont portées ; la voix finale est complète et les contacts à deux corps restent partiels. Les branches déjà reprises ou supplantées ne sont pas refusionnées.

Les nouvelles carrières communes utilisent le **registre effectifs v2 : 241 postes, 86 échéances et 9 statuts documentés** ; le reste est estimé explicitement. Les statistiques de la base active sont conservées. Les anciennes carrières v1 gardent leurs références sans migration, et les packs changent les identités sans remplacer les progrès. Voir les [sources et limites du lot2](docs/roster-foundation-lot2.md) et le [protocole de réception Windows](docs/oval-legacy-27-carnet-coach-20261108.md).

## Lot 1 effectifs — étape historique

Les 1 592 joueurs disposent désormais d’une référence initiale traçable : 12 postes précis corroborés, 20 échéances officielles dans les deux divisions et un contrat mixte espoir/professionnel confirmé. Les informations restantes sont des estimations de jeu explicites ; les salaires, 36 attributs, 11 compétences, notes, potentiels et traits restent ceux de la base active. La fiche distingue la référence contractuelle initiale du contrat courant après une signature. Les anciennes carrières restent inchangées, sans migration automatique. Voir [couverture, sources et limites](docs/roster-foundation-lot1.md), notamment la contradiction officielle sur Traini conservée en quarantaine. Aucune nouvelle règle de rugby ou de recrutement n’est introduite.

## Vous découvrez GitHub ?

Commencez par le [guide GitHub en français](docs/guide-github.md). Vous n’avez pas besoin de savoir programmer pour suivre l’avancement du projet.

| Élément | À quoi il sert |
|---|---|
| `README.md` | Cette page : présentation, fonctionnement et historique |
| `dist/` | Les fichiers qui font fonctionner le jeu |
| `tests/` | Les vérifications automatiques du moteur et des sauvegardes |
| `docs/` | Les guides et le référentiel des règles de rugby |
| `AGENTS.md` | Les consignes à respecter lors des développements |
| `DEVELOPPEMENT.md` | Journal partagé des travaux, décisions, problèmes et priorités |

Les noms de fichiers, commandes et identifiants techniques restent identiques pour préserver les liens et le fonctionnement du projet. La documentation est rédigée en français.

## Fonctions de la version web historique

- **Bureau du manager** : calendrier, messages, décisions et échéances du club.
- **Effectif** : tableau triable, comparaison de joueurs, couverture des postes et feuille à 23.
- **Staff** : délégation de l’entraînement et de la sélection.
- **Recrutement** : missions sur les agents libres, rapports, joueurs suivis et négociations.
- **Plan de jeu** : attaque et défense, consignes par zone, mêlées, touches et renvois.
- **Préparation adverse** : résultats observés, projection des qualités, conseils argumentés et accès aux comparaisons par poste.
- **Bilan des consignes** : plan initial conservé, plans effectifs et statistiques par phase.
- **Matchs** : terrain entier en 2D, commentaires synchronisés, pauses, remplacements et statistiques.
- **Carrière** : championnat, phases finales simplifiées, finances, contrats, formation, progression et retraite.
- **Sauvegardes** : enregistrement local, export et import de la carrière.

## Ancien lanceur portable hors ligne

Une version portable est maintenant prévue pour Windows 10/11 x64. Décompressez
l’archive de livraison puis ouvrez `CadrageDebordement.exe`. Le jeu et les polices
sont embarqués ; aucune installation de Python ou Node.js n’est nécessaire.

Les sauvegardes restent dans `%LOCALAPPDATA%\CadrageDebordement`, indépendamment
du dossier de l’application. Pour reprendre la version en ligne, exportez votre
carrière JSON depuis Sauvegardes puis importez-la dans l’application. Les mises
à jour ne déplacent ni ne remplacent automatiquement ce dossier de données.

Consultez la [notice de lancement](offline/LIRE-MOI.txt) et la
[documentation de la version portable](offline/README.md). La fenêtre sur un
véritable Windows reste à confirmer ; le stockage, le transfert, les reprises
et la fermeture ont été vérifiés avec le lanceur natif Linux et le navigateur.

## Repères techniques

La version web fonctionne dans le navigateur, sans étape de compilation ; son point d'entrée est `dist/index.html`. Le projet Windows natif se trouve dans `native/godot/project.godot` et son export autonome est produit par `scripts/build-godot-prototype.py` avec un SDK Windows Godot explicite. Le moteur JavaScript partagé communique avec Godot par un processus Node embarqué et des pipes privés.

Les modules principaux sont `dist/rugby.js` pour les attributs et la simulation, `dist/economy.js` pour les contrats et transferts, `dist/game.js` pour la carrière et l’interface, et `dist/style.css` pour la présentation. Les autres fichiers de `dist/` complètent les règles, les tactiques et la gestion.

Pour consulter une copie locale avec Python installé, lancez à la racine du dépôt :

```sh
python -m http.server 8000 --directory dist
```

Puis ouvrez `http://localhost:8000` dans votre navigateur. Cette adresse locale possède ses propres sauvegardes ; utilisez l’export/import pour déplacer une carrière depuis un autre hébergement.

## Vérifier le projet

Les tests nécessitent Node.js. Aucun paquet supplémentaire n’est nécessaire. Depuis la racine du dépôt :

```sh
node --check dist/game.js
node --check dist/rugby.js
node tests/rugby.cjs
node tests/goalkicking.cjs
node tests/economy.cjs
node tests/development.cjs
node tests/saves.cjs
node tests/opposition.cjs
node tests/match-rules.cjs
node tests/frontrow.cjs
node tests/restarts.cjs
node tests/matchflow.cjs
node tests/match2d.cjs
node tests/match-actions.cjs
node tests/tactical-plans.cjs
node tests/manager.cjs
node tests/playbook.cjs
node tests/preparation.cjs
node tests/offline.cjs
```

Les 17 suites JavaScript couvrent notamment la sélection des 23, les spécialistes de première ligne, les remplacements, la discipline, les reprises de jeu, les sauvegardes, les finances, la formation, les tactiques, le recrutement et la cohérence de la 2D. Les scénarios comprennent 250 matchs indépendants, deux saisons complètes, dix intersaisons et des comparaisons tactiques contrôlées.

Un test réussi ne prouve pas qu’une règle de rugby est correcte : les lois et dispositions applicables doivent être vérifiées dans le [référentiel rugby](docs/rugby-rules-reference.md).

## Version 17 — tirs au but (en cours de validation)

- La probabilité des transformations tient compte d'une géométrie indicative du point d'essai : distance et angle par rapport aux poteaux. Le point d'essai latéral reste une approximation du moteur, non une trajectoire individuelle reconstituée.
- Le buteur choisi parmi les joueurs présents conserve une précision dépendant de sa compétence et de sa condition physique ; la météo continue d'influencer les tirs.
- Un test ciblé `tests/goalkicking.cjs` et une automatisation GitHub Actions sont ajoutés. **Leur exécution effective doit être confirmée avant de déclarer la version validée.**
- Le moteur continue de traiter essai et transformation comme une action unique ; les tirs ne sont pas encore une phase interactive distincte.

## Historique des versions

Les paragraphes suivants décrivent chaque version au moment de sa livraison. Certaines limites anciennes ont été levées dans les versions suivantes. Les mesures de simulation sont des résultats internes datés, pas des probabilités du rugby réel ni une garantie d’équilibre pour toutes les équipes.

### Version 2 — effectif et simulation

- Onze attributs propres aux rôles ; la note au poste et la condition physique sont affichées séparément.
- Quinze titulaires et huit remplaçants désignés, avec un talonneur et des spécialistes des deux postes de pilier sur le banc. Le reste de la couverture est choisi avant la rencontre.
- Une minute par phase simulée, pause automatique à la mi-temps, pauses tactiques et changements individuels. À cette version, seuls les remplaçants désignés peuvent entrer, sans retour tactique.
- Même moteur pour les matchs interactifs et ceux des clubs adverses : possession, territoire, conquête, pénalités, météo, jeu au pied et fatigue. Les jaunes durent dix minutes simulées. À cette version, deux jaunes provoquent une exclusion définitive simplifiée.
- Rapport, statistiques et diagnostic après le match. Les minutes réellement jouées influencent le risque de blessure calculé après la rencontre.
- La récupération hebdomadaire normale permet d’enchaîner les matchs avec une rotation ; les clubs adverses suivent un entraînement normal.
- La sauvegarde reste sous la clé `bdt-v1` sur la même origine. Une copie `bdt-backup-v1` précède une seule fois l’ajout des attributs et du banc aux anciennes carrières. Le score, la minute et les événements d’un match en cours sont conservés ; les nouvelles statistiques commencent au moment de la migration.

### Version 3 — contrats et transferts

- Les carrières gardent leurs finances et leurs salaires. Les contrats existants reçoivent des échéances déterministes réparties sur la saison en cours et les deux suivantes. Une copie unique `bdt-backup-economy` précède la migration, sans modifier le match en cours.
- Recrutements et prolongations passent par une offre de salaire et une durée d’une à trois saisons. Trois propositions par joueur et par semaine de jeu ; une offre trop basse peut recevoir une contre-proposition. Un troisième échec termine les discussions pour la semaine. Le paiement nécessite une confirmation distincte de l’accord.
- Une prolongation étend l’échéance existante et change immédiatement le salaire. La prime est payée une seule fois. Les estimations salariales utilisent les 29 échéances payées par saison dans le jeu, sans reproduire les budgets annuels réels.
- Un joueur mis en vente peut recevoir une offre après une journée. Elle peut être acceptée ou refusée jusqu’à la semaine de jeu suivante incluse. Le transfert déplace le joueur et fait passer le montant de l’acheteur au vendeur. Un match en cours bloque les transactions d’effectif.
- Les contrats non prolongés sont revus avant la saison suivante. Les joueurs partent libres et rejoignent le marché ; des joueurs de formation couvrent les postes nécessaires. Les clubs adverses prolongent automatiquement, sans négociations autonomes.
- Un jeune ne peut être vendu avant 20 ans. Une recrue doit attendre trois journées de championnat avant d’être revendue. Les fenêtres réelles de transfert, agents, clauses libératoires et finances complètes des clubs adverses ne sont pas simulés.
- Les tests économiques couvrent signatures, contre-offres, persistance, nombres invalides, limites de dépenses, échéances, ventes, salaires et migration. Les tests sportifs conservent les contrôles de matchs et de saisons.

### Version 4 — formation et carrières des joueurs

- Des plafonds de potentiel déterministes préservent les notes et attributs sauvegardés. Les données ajoutées suivent l’expérience d’entraînement, les minutes réelles, les apparitions, les minutes de carrière et les douze derniers bilans de saison. Une copie unique `bdt-backup-development` précède la migration. Les minutes déjà présentes dans un match servent de référence, sans inventer d’apparitions passées.
- Les jeunes progressent plus vite. L’entraînement normal ou intense apporte une expérience fractionnée ; les minutes jouées ajoutent de l’expérience. La récupération et les joueurs blessés ne reçoivent pas d’expérience de développement. Les gains s’arrêtent au plafond. Les clubs adverses utilisent le même modèle.
- Quatre espoirs nommés arrivent par saison. Ils restent au centre jusqu’à 21 ans inclus, avec un maximum de douze. Une promotion ajoute un contrat et 2 000 € de salaire hebdomadaire, sans prime. Les matchs de jeunes ne sont pas simulés ; la couverture d’urgence reste distincte.
- Une courbe d’âge fictive provoque un déclin progressif, plus précoce chez les arrières, et un âge de retraite annoncé. Une migration ne modifie pas à elle seule les qualités, l’âge ou les contrats. Retraites et expirations sont revues ensemble avant la saison suivante. Le retraité et son salaire quittent le club sans indemnité dans ce modèle simplifié.
- Un nouveau contrat ne peut dépasser la retraite annoncée. Les contrats existants sont conservés. Les retraités ne deviennent jamais agents libres. Les clubs adverses reconstituent leur couverture et intègrent de nouveaux jeunes chaque saison.
- L’écran Formation présente les espoirs, le potentiel, les évolutions, les minutes et les retraites. Les fiches distinguent le développement général et la note pondérée au poste, avec un historique de carrière.
- Les tests couvrent plafonds, temps de jeu, migrations, unicité des promotions et cohortes, salaires, blessures, récupération, déclin, retraites, durées de contrat et dix intersaisons successives, en plus des régressions sportives et économiques.

### Version 5 — sauvegardes transportables

- L’export contient `format: cadrage-debordement-save`, `exportVersion: 1`, une date ISO, une somme de contrôle FNV-1a et un état complet de carrière au format interne version 2. La somme de contrôle détecte une modification accidentelle, sans garantir l’authenticité du fichier. Un match exporté est mis en pause dans le fichier, sans changer le match ouvert.
- Les imports JSON sont lus localement, limités à 5 Mio et présentés avant remplacement. Structure, nombres bornés, calendrier, identifiants, unicité des joueurs entre clubs, références d’effectif, état du match et modules sont contrôlés. Les formats inconnus, versions futures, clés d’objet dangereuses et textes contenant du balisage ou des attributs sont rejetés. Les anciens enregistrements du navigateur continuent à migrer au démarrage normal.
- Avant remplacement, `bdt-before-import` conserve un export complet de la carrière ouverte. Un échec d’écriture de la copie ou de la sauvegarde principale laisse la carrière en mémoire inchangée. La copie peut être consultée, restaurée ou téléchargée ; sa restauration sauvegarde à son tour la carrière remplacée.
- Aucune synchronisation en ligne. L’écran Sauvegardes propose export et import ; l’import est aussi disponible à l’accueil. Les échecs de stockage restent signalés. Des données locales invalides sont conservées sous `bdt-recovery-invalid`, avec un accueil et un import toujours accessibles.
- Les tests couvrent allers-retours, annulation, retour à l’état précédent, manque de stockage, matchs repris en pause, mi-temps, phases finales, fins de saison, dix intersaisons, textes et identifiants malveillants, fichiers trop grands ou corrompus et références absentes. Le contrôle dans le navigateur télécharge puis réimporte un véritable JSON et vérifie la copie de secours.

### Version 6 — adversaires et difficulté

- Découverte, Classique et Expert changent uniquement les décisions des entraîneurs. Aucun bonus d’attribut, de budget, de probabilité au pied ou de résultat selon le niveau. Le réglage est figé au coup d’envoi. Classique est la valeur par défaut lors d’une migration.
- Les entraîneurs composent des feuilles uniques et éligibles selon les postes, la fraîcheur, les qualités, le style et la charge récente des titulaires. Les niveaux supérieurs couvrent explicitement l’ouverture et échelonnent les changements en tenant compte du buteur et des remplaçants disponibles. Météo, score et qualités guident les révisions tactiques, visibles dans le journal.
- Le moral des clubs du joueur et des adversaires varie selon les mêmes incréments de victoire, nul ou défaite et les mêmes bornes. Le moral adverse est visible avant le match. Les anciennes valeurs par défaut restent identiques après import ou rechargement. La charge de titularisations est remise à zéro à l’intersaison.
- En pause, le joueur choisit sur pénalité entre contexte, points ou touche. Les entraîneurs Expert et la politique contextuelle considèrent un besoin d’essai en fin de match ou un bonus offensif atteignable. Le buteur, la météo et la distance continuent à déterminer les tirs réels.
- Les nouveaux matchs utilisent `balanceVersion: 2` : les différences d’attributs comptent, avec une réduction des avantages cumulés en attaque, conquête et maul. Les matchs en cours sans ce marqueur gardent leurs anciens coefficients. Aucun taux de victoire imposé ni bonus de remontée lié au score.
- Mesure interne de cette version : 400 matchs neutres entre équipes identiques donnent 49,25 % de victoires à la première et 42,75 points cumulés en moyenne. Sur 400 matchs fort/faible avec domicile alterné, le favori gagne 91 % des matchs, avec neuf nuls et 46,47 points moyens. Ces résultats sont fictifs et propres à ce moteur.
- Les contrôles couvrent effectifs, changements autorisés et échelonnés, décisions selon météo et score, attributs inchangés, difficulté figée, compatibilité des sauvegardes, carrières, finances, saisons et longues séries d’intersaisons. L’interface est contrôlée pour la conservation du niveau et du choix sur pénalité.
- Les négociations des clubs adverses restent simples ; cette version porte sur les décisions sportives.

### Version 7 — remplacements et deuxième carton jaune

- Les nouveaux matchs enregistrent `rulesProfile: fr-pro-2025`, limité au cadre professionnel français 2025/26 des remplacements et des exclusions, documenté dans le référentiel. Cette édition reste fixe dans une carrière fictive ; aucune conformité complète ni conformité 2026/27 n’est revendiquée.
- Les 23 désignés sont immuables. Un sortant tactique reste disponible sur le banc ; quatre retours tactiques sont permis, indépendamment des remplaçants encore inutilisés. La première entrée d’un des huit remplaçants ne consomme pas ce quota. Les deux équipes suivent les mêmes contrôles.
- Un deuxième jaune exclut définitivement le joueur. Un autre joueur désigné et disponible peut occuper sa place après vingt minutes de jeu, hors quota de retours tactiques. L’adversaire comble les places autorisées indépendamment de son calendrier de changements ; le joueur choisit dans le panneau du banc. Un rouge sans remplacement est également représenté et testé, mais les incidents de rouge direct ne sont pas générés.
- Les durées d’exclusion et l’éligibilité au remplacement utilisent le temps de jeu. Mi-temps et pauses du manager ne comptent pas. Minutes et fatigue de l’intervalle écoulé sont affectées aux joueurs présents au début de celui-ci, corrigeant l’absence de seulement neuf minutes sur jaune.
- Les matchs en cours sans profil finissent selon leurs règles d’origine. Les imports vérifient joueurs désignés, répartition terrain/banc/exclus, places vacantes, journaux des changements et compteurs de retours. Les formats de sauvegarde et d’export restent compatibles.
- Les scénarios couvrent quatre retours malgré des réserves inutilisées, douze changements tactiques, refus du cinquième retour, jaune traversant la mi-temps, limite des vingt minutes, remplacement après rouge par un joueur déjà utilisé, refus du rouge permanent, restauration par l’adversaire, rechargement, import, données malveillantes et anciens matchs. Les contrôles de saisons, adversaires, économie, développement et sauvegardes passent également.
- Limites à cette étape : exclusions de première ligne, joueur désigné temporairement sorti et mêlées non disputées restent à traiter. La suppression des cartons de première ligne est alors une dette technique explicite. Les remplacements médicaux, le protocole commotion et les rouges directs ne sont pas générés. Les changements en pause restent une abstraction, sans autorisation complète de l’arbitre sur ballon mort.

### Version 8 — exclusions de première ligne et mêlées non disputées

- Les nouveaux matchs ajoutent `frontRowVersion: 1`. Les rencontres antérieures conservent leur comportement jusqu’à la fin, sans modifier score, minutes, fatigue ou journal en cours de match. Le cadre 2025/26 reste fixe.
- Les trois postes spécialistes peuvent recevoir un jaune, y compris leur remplaçant. À la mêlée suivante, le staff choisit un spécialiste désigné et qualifié et fait sortir un joueur actif hors première ligne. Couverture et restauration réglementaires ne consomment pas de retour tactique. Pendant une exclusion temporaire, le joueur désigné sorti ne revient pas avant l’heure ; après une exclusion permanente, il peut revenir par un changement ordinaire autorisé.
- Sans spécialiste disponible, les mêlées deviennent non disputées et une réduction supplémentaire d’effectif s’applique. Huit joueurs de chaque côté sont requis. L’équipe qui introduit garde le ballon, sans poussée, gain, récupération aléatoire ou essai sur mêlée. Deux spécialistes indisponibles au même poste laissent douze joueurs ; avec deux rouges de vingt minutes, l’équipe passe à treize puis quatorze après les délais si la pénurie persiste, selon la matrice World Rugby d’août 2025.
- Le retour d’un spécialiste permet de disputer à nouveau les mêlées. La fin d’un jaune restaure le spécialiste et les joueurs désignés éligibles sans quota tactique. Un rouge de première ligne arrivé à échéance comble une place réellement vacante, même si le joueur initialement sorti est déjà revenu ailleurs. Le joueur exclu ne revient jamais.
- Le banc affiche les effectifs actifs, la situation de mêlée et les absences désignées. Le rapport distingue les mêlées non disputées. Les deux équipes suivent les mêmes procédures automatiques. Import et rechargement valident et conservent exclusions, joueurs retenus hors terrain, postes, références aux rouges et effectif autorisé.
- Les tests couvrent les trois postes, la mêlée suivante, les minutes réelles, les quotas épuisés, les jaunes simultanés, la matrice 12/13/14, les rouges permanents, les joueurs réutilisés ailleurs, les deux équipes, les données malveillantes et les anciens matchs. Les contrôles existants passent.
- Le staff choisit automatiquement le joueur à faire sortir ; il n’existe pas de choix manuel. Blessures en cours de match, saignements, commotions et génération de rouges directs restent absents. À cette étape, les causes générales de reprise et l’autorisation sur ballon mort restent à traiter. Aucune conformité réglementaire complète n’est revendiquée.

### Version 9 — causes des conquêtes et reprises de jeu

- Les nouveaux matchs ajoutent `restartVersion: 1`, avec les lois World Rugby 2025 comme référence. Les matchs sans ce marqueur gardent leurs phases antérieures, sans migration du score, de l’horloge, de la fatigue ou des événements.
- Une mêlée ou une touche exige une cause explicite : en-avant ou passe en avant, porteur ou coup de pied en touche, pénaltouche, 50:22 éligible, défenseur rendant mort un ballon rentré dans son en-but, ou choix défensif après un coup de pied trop long. Un simple appel de `contestSetPiece` ne peut créer une conquête. L’événement enregistre bénéficiaire, acteur, marque, origine, cause et minute, avec un maximum de 300 faits de reprise.
- Une touche directe perd le gain hors des 22, ou après un ballon rentré sans phase rétablissant ce droit. Pénaltouche et 50:22 indirect éligible conservent le lancer. Prise de possession et séquences achevées de plaquage/ruck actualisent les droits au pied. Le moteur ne produit pas encore de courses vers l’arrière, mais les cas de ballon rentré sont représentés et testés.
- L’équipe qui encaisse effectue le renvoi après les points ; le coup d’envoi de seconde période revient à l’autre équipe que celui de première période. Kicker et récupération sont distincts. Une pénalité manquée peut rester en jeu, sortir pour une touche défensive ou devenir morte pour un renvoi aux 22. Attaquant tenu dans l’en-but, en-avant offensif dans l’en-but ou ballon offensif au pied aplati par la défense provoquent un drop de ligne d’essai. Un ballon botté au-delà de l’en-but permet au staff défensif de choisir entre mêlée de retour et renvoi aux 22. Le cas du défenseur rentrant puis rendant mort le ballon est représenté, mais n’apparaît pas naturellement dans le modèle de courses vers l’avant.
- Les attaques manquées distinguent faute de main et récupération défensive autorisée. Un essai issu d’une mêlée est nommé comme tel, plutôt que comme un maul. Les procédures de première ligne et de mêlée non disputée suivent ces mêmes causes.
- Les faits de reprise et droits au pied sont validés à l’import et au rechargement. Versions inconnues, causes inventées, mauvais bénéficiaires, marques invalides et dates incohérentes sont rejetés. Les huit suites de cette version couvrent les deux sens, touches ordinaires et sur pénalité, ballon rentré, exclusions du 50:22, en-but, tirs manqués, renvois, anciens matchs et carrières complètes.
- Les reprises se résolvent d’un seul bloc au cours d’une minute simulée. À cette étape restent à traiter : horloge fine, avantage, autorisation des changements sur ballon mort, exceptions de fin de période, fautes détaillées de touche/ruck/maul et prolongations réelles. Les probabilités de réception et de territoire sont fictives.

### Version 10 — terrain 2D, avantage et fins de période

- Le centre de match affiche un terrain SVG avec les identités des joueurs actifs et le ballon. Les transitions illustrent les séquences ; formations et trajectoires sont indicatives, sans simulation physique des déplacements. Les exclus et joueurs temporairement désignés hors terrain sont absents ; les remplaçants apparaissent et les équipes changent de côté à la mi-temps. À cette version, les caméras large/proche et les trois rythmes ne modifient que la présentation. Pause et préférence de réduction des animations coupent les transitions. L’affichage ne consomme aucun tirage aléatoire du match et ne change pas la carrière.
- Les nouveaux matchs ajoutent `flowVersion: 1`. L’avantage conserve bénéficiaire, sanction et marque ; il revient à la faute initiale sans la compter deux fois et garde la pénalité la plus favorable lors de fautes répétées. Les seuils de bénéfice et la revue après trois séquences sont des politiques arbitrales fictives, sans distance ou durée réglementaire imposée. Les situations dangereuses et de carton arrêtent le jeu.
- Le ballon vivant peut prolonger la période au-delà des 40/80 minutes affichées. Les reprises ordinaires sur ballon mort terminent la période ; une pénaltouche protégée, une mêlée de retour d’avantage ou une transformation peuvent se terminer. Chaque mi-temps compte ses propres quarante minutes de jeu, indépendamment du dépassement de la première. Le manager peut demander de sortir le ballon pour finir la période : c’est une action tactique explicite, pas un coup de sifflet sur ballon vivant. Un nul en phase finale conserve la pénalité décisive simplifiée antérieure.
- Les dépassements comptent dans la charge et les exclusions. Période, avantage, marques et dates sont conservés et validés après export/import ou rechargement. Les matchs antérieurs sans ce marqueur gardent leur moteur et peuvent utiliser la 2D.
- Dix suites couvrent le rugby, l’économie, dix intersaisons, les sauvegardes, 800 matchs de calibration des adversaires, remplacements, première ligne, reprises, déroulement et 2D. Le navigateur est contrôlé pour terrain, caméras, rythme et pause. Le moteur reste à la minute : secondes détaillées, toutes les fautes, changements sur ballon mort, médecine et prolongations réelles restent à traiter.

### Version 11 — suivre le terrain et les commentaires ensemble

- Score et commandes forment une barre compacte qui reste visible au défilement. Sur ordinateur, terrain et commentaires occupent la première rangée ; sous 900 px de largeur, le journal suit le terrain. Statistiques, consignes et banc viennent ensuite.
- Les commentaires défilent dans leur propre panneau de hauteur limitée. Les actions récentes sont en premier, la dernière est mise en évidence, avec catégories et couleurs discrètes. Le filtre Temps forts conserve points, pénalités, avantage, discipline, remplacements, consignes et fins de période. Il reste actif pendant le match et se réinitialise au rechargement.
- Cette version ne change ni règles, événements, résultats, tirages aléatoires ou format de sauvegarde. Les tests 2D passent ; les contrôles dans le navigateur vérifient alignement, hauteur du journal, filtres, mises à jour, pause et score fixe, sans débordement horizontal à la taille d’écran testée.

### Version 12 — synchronisation des actions affichées

- Suppression de la vue proche : seul le terrain entier reste disponible. Les nouveaux événements enregistrent type d’action, acteur, équipe, positions initiale/finale du ballon, score, essais, période, style et identités présentes. La scène utilise ces faits, sans déduire l’action du texte ou de la dernière reprise de la minute. Les anciennes actions sans faits montrent explicitement l’état courant ; les nouvelles actions d’anciens matchs reçoivent ces enregistrements sans changer leurs règles.
- Chaque événement est montré avant de calculer une autre minute. Commentaire surligné, ballon, joueur mis en évidence, score et horloge décrivent la même action ; les commentaires futurs restent cachés. L’action courante reste visible sous le filtre Temps forts. Un essai atteint le bon en-but avant le renvoi de l’équipe qui encaisse, puis la réception. Mêlées et touches montrent la préparation à la marque avant leur résultat. Les placements restent schématiques.
- Chaque progression réussie est enregistrée et nomme un participant actif choisi de manière déterministe, avec des descriptions variées et le style actuel. La suite de tirages aléatoires et les probabilités ne changent pas ; essai et transformation restent atomiques. Les matchs automatisés gardent le même moteur sportif sans stocker les scènes visuelles.
- Des options de pause après essai ou carton arrêtent le match après affichage de la séquence déjà calculée. Les retours de carton ne déclenchent pas cette pause. Ces préférences restent dans le navigateur, hors carrière exportée. Une pause manuelle ou consultation de joueur rejoint l’état réellement calculé sans avancer l’horloge, pour gérer l’effectif légal actuel. L’avance rapide saute l’animation et respecte les pauses d’incident choisies.
- Un clic ou une activation clavier d’un joueur permet d’inspecter identité, attributs, condition et minutes, en pause. Seuls les remplaçants du joueur actuellement éligibles sont proposés via les contrôles existants ; les adversaires sont en lecture seule. Les faits visuels sont exportables et validés pour géométrie, versions, équipes, identifiants, positions, score et périodes. Le rechargement reprend au dernier événement calculé.
- Onze suites passent, avec cohérence visuelle, pauses, effectifs historiques, remplacement depuis le terrain, données malveillantes et restauration, en plus des carrières, saisons, finances et adversaires. Le contrôle dans le navigateur compare l’action du terrain et du journal et effectue un remplacement depuis le SVG. Aucune nouvelle disposition réglementaire n’est introduite.

### Version 13 — effets sportifs de l’attaque et de la défense

- Les nouveaux matchs enregistrent `tacticalVersion: 1`, plans offensif/défensif indépendants et compteurs mesurés. Les matchs antérieurs gardent leurs coefficients jusqu’à la fin. La préférence de carrière `defence` est équilibrée par défaut et s’applique au prochain coup d’envoi, sans migration tactique silencieuse en match. L’import valide plans, versions, scènes et compteurs bornés, y compris les mètres fractionnaires après un coup de pied.
- Attaque équilibrée, au près (`conquete`, clé conservée), au large ou d’occupation. La réussite pondère les qualités des joueurs réellement actifs : puissance des avants au près, passe et vitesse des arrières au large. Distance, fautes de main, finition et charge dépendent du choix. La pluie augmente le risque au large. L’occupation augmente le jeu au pied surtout dans son camp, moins dans les 22 adverses. Distance au pied, météo et réception conservent leurs causes existantes.
- Défense équilibrée, montée agressive ou glissée prudente. La montée réduit la réussite initiale de l’attaque et augmente les fautes de main provoquées, au prix de fatigue et de pénalités ; une montée battue expose à plus de mètres et d’occasions. La glissée concède davantage de progressions initiales mais en limite la longueur, les grands gains, la finition, la fatigue et les pénalités. Ces coefficients sont fictifs, sans bonus direct de difficulté, de résultat ou d’attribut.
- Les deux équipes et les matchs automatisés utilisent les mêmes calculs. L’adversaire choisit une défense selon qualités et fraîcheur et, en Expert, selon score et temps restant, à son rythme habituel de révision. Les changements sont journalisés. Le joueur peut éditer les deux plans avant le match et en pause ; les changements invalides, après fin, sans pause ou avec lecture en attente sont refusés.
- Les scènes conservent les plans des deux côtés. Largeur, soutiens et profondeur défensive varient sur le terrain. La lecture utilise les plans enregistrés plutôt qu’un changement ultérieur de l’adversaire. La légende les indique. Collisions, passes et lignes de hors-jeu ne sont pas calculées physiquement.
- Les observations de mi-temps citent progressions, mètres, erreurs, avancée adverse et pénalités mesurés. Les recommandations sont conditionnelles, jamais automatiques ni garanties. Les joueurs sous 70 % de condition sont consultables par les contrôles de pause/remplacement. Les compteurs apparaissent en direct puis dans le rapport final.
- Douze suites passent, dont 640 matchs comparatifs, qualités propres aux styles, formations enregistrées, conseils de mi-temps, données malveillantes, territoire fractionnaire et conservation des anciens moteurs. Le navigateur est contrôlé pour préparation, commandes séparées, changement de défense à la mi-temps et rapport fondé sur les faits du match.

Comparaison contrôlée : 80 matchs par cas, qualités uniformes à 75, côté testé alterné, mêmes graines aléatoires et aucun changement de plan ou de joueur par l’adversaire. Sur terrain sec, le large produit **19,47 m par progression réussie** contre **12,27 m** au près, avec **11,99 contre 7,03 fautes de main par match**. Sous la pluie : **15,50 contre 10,34 fautes**. L’occupation produit **10,97 coups de pied en jeu par match** contre **1,29** en équilibré. Face à la montée, les attaques progressent sur **46,8 %** des portées contre **50,8 %** face à la glissée. Les défenseurs en montée concèdent **7,75 pénalités par match** contre **4,28** et finissent à **63,13 % de condition** contre **71,87 %**, sans changements. Ces échantillons illustrent des compromis du moteur, sans classement universel ni référence au rugby réel.

### Version 14 — bureau du manager et carnet de jeu

- Le bureau remplace l’ancien tableau de bord : quatre prochains matchs de championnat, messages filtrables et non lus, contrats, offres, blessures, couverture et dernier résultat. Les décisions ouvrent le bon écran. Les contrôles financiers et de signature restent les mêmes.
- L’effectif s’ouvre sur un tableau triable : poste, recherche, échéance, condition, salaire, minutes et potentiel. Deux joueurs peuvent être comparés attribut par attribut. La couverture des quinze postes respecte les spécialistes de première ligne. La feuille à 23 conserve son onglet.
- Entraînement et sélection peuvent être délégués. Le préparateur choisit récupération sous 75 % de condition moyenne du XV, sinon entraînement normal. L’adjoint complète une feuille incomplète avant le coup d’envoi puis sélectionne après entraînement. Il utilise l’éligibilité et les effets réels, sans bonus. Recrutement de staff, qualités individuelles et masse salariale du staff ne sont pas encore simulés.
- Les missions recherchent les agents libres disponibles selon famille de poste, âge maximal, prime et salaire hebdomadaire. Elles coûtent 5 000 € et prennent deux semaines de jeu : une mission active et trois en attente au maximum. Jusqu’à trois rapports comparent les candidats au premier choix du club. Leurs appréciations décrivent les attributs connus à la date du rapport. Joueurs suivis et candidats sont conservés parmi les agents libres dans la limite existante de 60. L’incertitude des informations et l’observation de joueurs sous contrat adverse ne sont pas simulées. La négociation suit les contrôles habituels de salaire, durée et confirmation.
- Les nouveaux matchs ajoutent `playbookVersion: 1`. Quatre zones orientées depuis son en-but peuvent remplacer l’attaque/défense principale. L’héritage conserve les coefficients précédents. Sécuriser la mêlée améliore la conservation au détriment du gain et de la finition ; pousser fait l’inverse. Touches courtes, fond de touche et mauls ont leurs compromis. Les renvois au centre peuvent être courts (10 à 14 m) ou longs (25 à 35 m), avec différentes chances de récupération. Renvois aux 22 et drops de ligne d’essai restent inchangés ; les mêlées non disputées contournent ces effets. Ces choix sont des politiques fictives, pas de nouvelles lois.
- Le moteur est commun aux deux équipes. L’adversaire hérite actuellement de sa stratégie générale dans chaque zone. Les changements en direct exigent pause et absence d’action en attente. Les faits enregistrés gardent plans effectifs et choix de conquête pour des commentaires cohérents et une vue entière schématique. Les anciens matchs gardent leur moteur ; les préférences de carrière s’appliquent aux suivants.
- Bureau et carnet sont conservés après rechargement et export/import, avec validation bornée et migration des anciennes carrières. Quatorze suites couvrent missions, délégation, spécialistes, orientation, décisions réelles au pied, conquête et renvois, en plus des carrières, finances, formation, règles et animations. Les contrôles dans le navigateur couvrent bureau, comparaison, consignes, staff et soumission de mission.
- Le code est original, inspiré de principes d’interaction documentés publiquement dans les jeux de management. Aucun code propriétaire de Football Manager ou d’un jeu de rugby n’a été obtenu ou copié.

### Version 15 — préparer l’adversaire et analyser ses choix

- Le Centre de match présente les cinq derniers résultats disponibles de l’adversaire, les statistiques de conquête réellement archivées et ses pénalités. Sans historique, le manque de données est annoncé ; aucun résultat n’est inventé.
- Les forces comparées reposent sur votre XV sélectionné et une projection adverse sans blessés, sur terrain sec et avec la condition actuelle. Mêlée, touche, puissance, passe/vitesse, pied et discipline sont distingués. Les joueurs à surveiller sont pressentis, pas une composition confirmée ; entraînement, météo et décisions adverses peuvent changer le tableau.
- Le staff recommande une attaque et une défense avec leurs raisons et compromis. Adopter ce plan règle les deux choix principaux, sans changer les 23, les consignes locales, les attributs ou les probabilités du moteur. Les zones personnalisées restent prioritaires. Les boutons par secteur ouvrent une comparaison de deux joueurs aptes et éligibles au poste, avec accès à la feuille et à la couverture.
- Les nouveaux matchs du joueur conservent le plan et le carnet au coup d’envoi, ainsi que les recommandations données avant la préparation finale. Le bilan montre les portées, progressions, mètres, erreurs et coups de pied selon l’attaque effective au début de la phase ; les organisations sans ballon suivent les avancées adverses et les pénalités. Les changements en pause et consignes par zone sont pris en compte. L’attribution est à la minute simulée : un changement de possession peut intervenir pendant cette minute. Elle ne démontre pas de causalité ni une supériorité générale d’un plan.
- Le bilan apparaît en fin de match et reste accessible à la préparation suivante. Les données sont conservées après rechargement, export et import, avec contrôles de structure, de compteurs et de références. Les anciennes rencontres n’acquièrent pas rétroactivement de plan initial ou de suivi ; les statistiques disponibles restent consultables.
- Aucun changement des lois, coefficients, tirages ou résultats. Les comparaisons contrôlées du moteur restent identiques. Les 15 suites passent, dont les nouveaux scénarios de rapport sans mutation, absence d’aléatoire d’affichage, conseils, actions de préparation, suivi dans les deux sens, changements de plan, export/import, données hostiles et conservation des anciens matchs. Le scénario économique ancien a été corrigé pour ne pas contenir le bureau du manager apparu après son époque.
- Le catalogue initial est extrait dans `dist/world-data.js`, sans changement des valeurs. Le [document sur les données](docs/donnees-du-jeu.md) prépare une future base réelle : saison, sources, identifiants et distinction entre trésorerie de jeu et budget annuel. Les joueurs et montants restent fictifs ; l’import et la migration d’une base réelle restent à réaliser.

### Version 16 — distribution Windows portable

- Un exécutable Windows x64 embarque les ressources du jeu et un serveur local, sans dépendance d’exécution à Python ou Node.js. Edge ou Chrome servent d’affichage dans une fenêtre dédiée, avec repli sur le navigateur par défaut. Aucun compte, accès Internet ou appel à une IA n’est nécessaire pour jouer.
- `dist/storage.js` conserve l’interface du stockage existant. Sur le web, il utilise le navigateur ; dans la version portable, il reçoit l’adaptateur de fichiers. Les données restent dans un dossier Windows indépendant de l’exécutable. Les écritures sont confirmées sur disque, avec copie précédente, refus des conflits et récupération conservant un fichier illisible.
- Les sauvegardes JSON existantes permettent le transfert dans les deux sens ; les matchs importés reprennent en pause. Une erreur de disque empêche une fausse confirmation de sauvegarde. « Enregistrer et quitter » sauvegarde avant de demander l’arrêt du lanceur.
- Les polices Barlow Condensed et DM Sans deviennent locales, avec leurs licences. Le moteur et les règles sportives ne changent pas. La version en ligne n’est pas automatiquement remplacée par cette livraison Windows.
- Les 16 suites JavaScript passent, ainsi que les tests Go du stockage, des accès locaux, du verrouillage et des erreurs. Le test du binaire natif vérifie l’écriture réelle, l’arrêt puis la reprise avec une nouvelle origine. L’interface a été contrôlée avec le stockage sur disque : création, match, pause, rechargement et fermeture. La compilation Windows et le format PE x64 sont vérifiés ; le double-clic Windows, l’ouverture du navigateur sur ce système et l’acceptation de l’exécutable non signé restent à confirmer sur le poste cible.

## Limites actuelles

Joueurs et finances fictifs. Départages du championnat et prolongations simplifiés. Pas de blessures en cours de rencontre, protocole commotion, génération de rouges directs, compétitions européennes, règles JIFF ou promotion/relégation. La polyvalence au-delà de la famille de poste n’est pas simulée. Le terrain 2D illustre les actions sans simulation physique complète. Les sauvegardes restent locales au navigateur pour la version web, ou au dossier de données pour la version Windows, sans synchronisation en ligne.

### Épreuve Windows native Godot — novembre 2026

Un prototype Godot autonome est désormais développé pour éprouver la direction artistique et le raccord avec la simulation avant le portage Steam : Bureau, Club avec60 photographies, Effectif/Fiche et scène de match native. Aucun navigateur nécessaire ; Godot et Node sont embarqués. Le catalogue présente30 territoires anonymisés, mais la carrière raccordée reste le mode historique à14 clubs. La carrière complète30 clubs/deux divisions et les montées/descentes conservent leur chantier distinct. Voir le [rapport illustré et les limites vérifiées](docs/godot-prototype-20261107.md). Cette épreuve ne constitue pas une publication Steam.
