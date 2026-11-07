# Godot — une première version de carrière

Léo demande une vraie étape dans l'interface, les graphismes et les menus, livrée en autonomie belle et jouable. Il a retenu Godot natif pour Windows, anthracite/ivoire/couleurs du club, les trente territoires anonymisés, deux divisions avec montées/descentes et un objectif commercial Steam. Ce lot fait progresser la preuve technique vers une version de jeu utilisable. Il ne constitue pas une publication Steam ni une certification complète des lois du rugby.

## Choix de réalisation

Je poursuis le moteur natif Godot et le pont JavaScript éprouvé. Un simple habillage des quatre panneaux laisserait trop de décisions absentes ; réécrire toute la simulation en GDScript retarderait le jeu sans améliorer son apparence. Le choix de réalisation est donc une interface Godot composée en vues spécialisées, reliée aux vraies commandes de gestion, et le mode France30 isolé demandé auparavant. Ce choix est celui du développeur dans l'autonomie accordée, pas une nouvelle préférence attribuée à Léo.

## Expérience attendue

Au lancement : menu d'accueil plein écran avec photographie locale, identité CD, Continuer si une carrière existe, Nouvelle carrière, Importer, Paramètres et Quitter. Aucune carrière créée automatiquement à l'arrivée. Un assistant de création présente les deux divisions, les trente clubs, ville/stade/couleurs et objectifs fictifs. Le choix déclenche une création réelle, après confirmation si un profil existe. L'import conserve les vérifications et la copie précédente.

Dans le jeu : navigation stable regroupée en Club et Compétition, titre/date et progression de semaine, action principale contextuelle (préparer, jouer, reprendre, valider ou saison suivante). Bureau avec prochain rendez-vous au bon stade, situation du groupe, résultats et décisions. Effectif filtrable/triable, fiche complète et onze compétences ; Composition avec quinze titulaires/huit remplaçants modifiables et validation réelle. Préparation avec attaque/défense et charge réelle. Calendrier, classements des deux divisions, Club/Territoire et Finances utilisent uniquement l'état de carrière. Recrutement et prolongations accessibles lorsqu'ils sont exposés par les contrôleurs natifs validés ; aucun bouton décoratif ni faux chiffre. Les contrôles indisponibles expliquent leur cause.

Le match conserve un score et une horloge permanents, terrain dominant, banc et tactiques consultables, vrai changement si autorisé, pause/reprise, vitesses cohérentes et résultat lisible. Consulter un écran ne modifie pas les décisions ni le RNG ; le match en cours conserve sa cadence normale. Échap ouvre un menu de pause explicite ; quitter ou changer de carrière demande confirmation pendant une rencontre. Sauvegarde automatique visible, refus disque stable sans répétition et fermeture propre du seul moteur enfant.

## Direction artistique

Une composition de jeu de gestion sportif, pas une accumulation de rectangles. Typographie Barlow Condensed pour les titres, DM Sans pour les chiffres/textes ; fond presque noir, panneaux à séparations sobres, photographies dominantes, accent club limité aux repères et choix. Cartes et tableaux alignés, espacements réguliers, badges de forme/condition, portraits fictifs explicites. Écran d'accueil cinématique, transitions courtes et focus clavier visible. Paramètres de fenêtre et affichage réellement appliqués ; pas de contrôle de volume sans audio.

La scène3D garde les mêmes athlètes/animations CC0, les positions de l'adapter et les deux cadrages éloignés. Améliorer profondeur, lumière, pelouse, enceinte, signalétique originale et ambiance des tribunes ; aucun mouvement sportif ou joueur ajouté à la trame. Le stade reste générique, pas une reconstruction des trente enceintes. Les photos réelles et leurs licences/provenances sont réutilisées.

Réception à1440×900 et1920×1080, noms longs, accents clair/sombre, menu initial sans sauvegarde et reprise d'une ancienne carrière. Le terrain entier, les actions et la fiche doivent rester lisibles. Les captures sont produites par le rendu Windows réel, sans souris/CUA ni activation des fenêtres de Léo.

## Carrière France30

Référence métier : le plan `2026-11-07-france-connected-career.md` et l'audit existant. Trente IDs stables, partitions14/16, calendriers26/30, championnat et phases finales reliés, promotion directe et barrage, passage aux saisons suivantes. Mode explicite distinct, aucune conversion silencieuse de fiction14/LNR14. Les deux divisions utilisent les vrais joueurs générés et le moteur de match existant, aucune table de résultats préfabriqués. Les effets hebdomadaires sont appliqués une seule fois. Le monde fermé sans Nationale et la cadence commune34 étapes sont déclarés comme abstractions. Format de compétition2026/27 et profil de lois de match existant restent distingués.

La cible de ce lot est d'abord native : pas d'activation d'un mode partiellement compatible dans toute l'interface web. Les modules partagés peuvent être ajoutés à dist/ ; les raccordements aux anciens contrôleurs restent conditionnels. Les modules Espoirs tardifs non chargés par le worker ne doivent pas être instanciés par accident. Le producteur choisit les plus petits raccordements compatibles et prouve les anciennes carrières par tests appariés.

## Contrat du modèle natif et des commandes

Le protocole1, les champs actuels club/league/squad/next/history/messages/ledger/live/meta et les méthodes du pont restent compatibles. Le mode complet ajoute `meta.mode='france30'`, `meta.week`, `meta.roundLabel`, `meta.canAdvanceSeason`, `meta.hasCareer`, `lineup`, `reserves`, `captain`, `kicker`, `tactics`, `calendar`, `leagues`, `market` et `finance`. Pour un modèle sans carrière, club vaut null ; le menu reste consultable sans mutation.

`lineup` et `reserves` sont les IDs natifs ; `selection` contient erreurs/validité de la feuille et les affectations ; `tactics` contient `attack`, `defense`, `attacks:[{id,label,description}]`, `defenses:[{id,label,description}]` ; `calendar` contient les affiches du club `{id,label,week,home,away,score,played,phase,leagueId}` ; `leagues` est une liste `{id,name,rows:[résumés classés existants]}` ; `market` contient des joueurs fictifs natifs `{id,name,pos,age,rating,salary,fee,available,reason}` ; `finance` contient cash, wage (hebdomadaire), ledger et explications fictives. `live` expose les joueurs réellement sur le terrain/banc et les possibilités natives de changement. Les contrats/rôles doivent être revalidés côté moteur à chaque commande.

Création `new_career:{club:0..29,mode:'france'}` ; ancien mode fiction14 reste importable/jouable. Commandes nouvelles : `set_lineup:{playerId,slot:0..22}`, `set_tactics:{attack,defense}`, `set_player_load:{playerId,mode}`, `extend_contract:{playerId,years:1..3,salary}`, `recruit:{playerId,years:1..3,salary}`, `next_season:{confirmed:true}`, `substitute:{outId,inId}`. L'offre salariale et les frais sont affichés avant confirmation, puis passent par la négociation/confirmation native ; aucun recrutement acquis si le joueur refuse. Les choix de capitaine/buteur ne sont pas ajoutés sans contrôleur ayant un effet natif : la V2 n'affiche pas de rôle fictivement actif. Les noms ou payloads doivent être resserrés si une API native l'exige, puis documentés avant raccordement UI ; aucune commande arbitraire, aucun eval client. Les commandes historiques restent disponibles.

### Décisions du bâtisseur après contrôle

La revue de conception n'a identifié aucune question nécessitant de solliciter Léo. Je retiens : salaire explicite et confirmation de l'offre ; pas de choix de capitaine/buteur sans effet ; systèmes métier annoncés limités aux modules effectivement chargés par le manifeste natif. Le plan France web conserve sa valeur d'audit, mais n'impose pas de charger les modules Espoirs/supporters tardifs pour ce lot natif.

Un profil corrompu doit laisser le menu stable et une explication, avec reprise explicite après réparation ou conservation d'une copie avant remplacement/import. La commande de récupération exige une confirmation utilisateur dans le jeu ; aucune carrière n'est créée ou écrasée automatiquement après refus de chargement. Cette reprise doit préserver les octets du profil endommagé. Le canal reste utilisable ou redémarre explicitement dans le même profil ; aucun changement silencieux de stockage.

Une indisponibilité métier est un refus visible, pas une réussite silencieuse. Les imports France30 ont une validation stricte distincte et ne peuvent exploiter les anciens plafonds14 ; plafond fini mesuré sur plusieurs saisons, UTF-8 et transport cohérents. Les erreurs/transactions/snapshots/arrêts conservent les garanties reçues du pont.

## Livrable et preuves

ZIP Windows autonome, profil hors exécutable et compatible avec le prototype14 existant, licences et crédits embarqués. Tests de trente départs, saisons et mobilité de division, parité des anciens modes, sauvegardes hostiles/rollback, commandes de gestion et consultation sans effet. Réception réelle menu→création→composition→préparation→match→résultat→semaine suivante→export/reprise, puis au moins une intersaison complète. Revue indépendante avant publication de la branche ; gate et CI exacts, aucun contournement. Préalpha explicitement présentée, pas de promesse commerciale achevée.
