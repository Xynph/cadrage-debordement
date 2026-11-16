# Clubs & Territoires — direction artistique et carrière française

## Demande et décisions de Léo

Le 7 novembre 2026, Léo demande une amélioration significative de l'interface inspirée de Golden Boy FM27, des photographies réelles des villes et stades des trente clubs du projet, des clubs de base anonymisés mais reconnaissables et une version Windows téléchargeable. Ses QCM fixent trente clubs jouables dans deux divisions, une direction anthracite/ivoire/couleurs du club, puis une carrière complète avec montées et descentes même si elle demande un chantier plus long. Exécution autonome ; QCM lorsqu'une incertitude produit importante demeure.

La BDD Rugby Réel, les notes, âges, joueurs et effectifs de l'autre producteur sont exclus de toute écriture. Les trente territoires correspondent au snapshot du projet au 31 octobre 2026 ; ils ne constituent pas une certification de la composition réelle des championnats. Les nouvelles identités, joueurs générés et finances sont fictifs.

## Direction artistique

Une interface de management sportif, nette et immersive. Fond anthracite #15191d, panneaux #1e242a/#252d34, ivoire #f1eee6, secondaires #aab5bf ; couleur du club utilisée pour l'accent, les repères et les maillots. DM Sans pour textes et chiffres, Barlow Condensed pour titres et navigation, polices locales. Les grands aplats et les images occupent un rôle précis : reconnaître un lieu ou une personne. Les chiffres gardent la priorité de lecture.

La référence Golden Boy est étudiée par son README fourni : identité joueur dense, vue du club associant stade/ville/jeune talent et résultats récents. Aucun bundle Unity, script d'installation, logo ou pack d'images du skin n'est incorporé ni exécuté. Les photographies n'étant pas dans son ZIP, notre atlas est acquis séparément avec auteur, source, licence, date et éventuelles limites de cadrage/ancienneté. Pas de faux stade, d'image IA présentée comme photo réelle ou de blanc silencieux.

### Identités et atlas

`CDFranceClubs` fournit trente objets immuables : `id`, `slug`, `division`, `city`, `name`, `abbr`, `color`, `stadium`, `cityImage`, `stadiumImage`. Identifiants 0–13 dans l'ordre historique des territoires (Toulouse, Bordeaux, La Rochelle, Toulon, Pau, Bayonne, Clermont, Lyon, Montpellier, Castres, Hauts-de-Seine, Paris, Perpignan, Vannes), puis les seize territoires PRO D2 du snapshot. Le slug identifie le lieu et les crédits ; il ne dépend pas des attributs LNR.

Les noms conservent la ville et inventent une identité de club, par exemple Toulouse Capitole XV, Bordeaux Estuaire Rugby, La Rochelle Océan XV. Les blasons sont des créations vectorielles propres au jeu, sans reprendre les logos officiels. Les anciennes carrières gardent leurs identités sauvegardées ; le nouvel univers utilise les nouvelles identités. Le mode réel conserve ses propres noms et joueurs.

### Composition de l'application

Cadre anthracite commun, navigation lisible, titre de page compact, contexte club/saison toujours visible. La couleur du club ne remplace pas les codes d'état (alerte, blessure, disponible). L'accessibilité dépend aussi de libellés et valeurs explicites.

Un véritable centre Club présente la ville et le stade dans deux photographies complémentaires, l'identité, le classement, les résultats réels de la carrière, l'état financier fictif et un joueur à suivre sélectionné sur les données existantes. Les actions ouvrent les pages natives Effectif, Préparation, Contrats et Finances. Un répertoire permet de parcourir les trente clubs et leurs lieux. Aucune histoire, statistique, hauteur, sélection nationale ou trophée n'est inventé pour remplir une tuile.

Le Bureau garde ses décisions et son prochain match ; sa hiérarchie visuelle est raccordée au nouveau cadre. L'effectif dense, les quatre onglets joueurs et les commandes de match restent natifs. Les photographies sont locales et intégrées au paquet Windows. Réception de référence : 1440×900 et 1920×1080, deux clubs de couleurs différentes, carrière neuve et avancée, noms longs, images manquantes signalées, zéro défilement global sur les vues PC conçues pour un écran.

## Carrière à deux divisions — contrat produit

Nouveau mode versionné `france`, séparé des anciennes carrières `fiction` et `lnr`. Trente clubs, quatorze dans Élite 14 et seize dans Division 2, avec joueurs générés par le moteur natif. Aucun écrasement du catalogue ou des notes Rugby Réel. Calendriers aller-retour, phases finales à six, accession directe et barrage d'accession ; lieux des demi-finales distincts selon les règles de compétition 2026/27 vérifiées dans les sources LNR. Un monde fermé à trente clubs implique explicitement l'absence de relégation vers une troisième division non simulée.

Les autres rencontres doivent réellement utiliser le moteur et conserver leur contexte de championnat/phase finale : aucun score fabriqué et aucun nul de championnat forcé en victoire. Les identifiants restent stables lors des changements de division. Le calendrier de carrière permet de traverser les semaines sans rencontre de son club. Les anciens contrôles 14 clubs/26 journées restent stricts pour les anciens modes. Le nouveau mode obtient ses propres contrôles de partitions, calendrier, résultats, phases, références et sauvegardes ; aucune validation générale n'est désactivée.

Les modules avancés présupposant quatorze clubs doivent être raccordés par identifiants ou gardés explicitement hors du nouveau mode, avec formation native disponible pour les trente clubs et limites affichées/documentées. Il est interdit de laisser les clubs de seconde division se confondre avec les clubs invités Espoirs.

L'audit d'architecture moteur détermine les raccordements exacts avant tout changement de compétition. Les trois ensembles livrables sont : fondations artistiques/atlas, compétition/sauvegardes, paquet Windows. L'objectif final comprend les trois.

## Distribution et réception

**Décision ultérieure prioritaire : version commerciale Steam.** Léo refuse une fenêtre Chrome/Edge et choisit par QCM un prototype Godot natif avant la poursuite du portage. Le ZIP Go/Edge audité reste une preuve technique de l'ancien lanceur, pas la cible de la version Steam. Les deux divisions complètes restent l'objectif de simulation ; leur implémentation attend la validation du prototype natif. Voir `2026-11-07-godot-native-prototype-design.md`. Aucune installation Blender demandée ; Godot est retenu pour l'épreuve native, sans promesse de publication Steam ou de migration complète déjà réalisée.

ZIP Windows 10/11 x64 contenant un exécutable et toutes les ressources, sans Node/Python/Go à installer pour le joueur. Stockage utilisateur hors dossier exécutable, erreurs visibles, sauvegarde et reprise vérifiées sur Windows réel avec profil temporaire. Le lanceur existant est la base retenue ; sa fenêtre d'application et ses flux doivent être réellement réceptionnés. Aucun auto-release activé. Provenance et empreintes des ressources/ZIP conservées, licences des images livrées et consultables.

Branches réservées et PR, CI sur HEAD exact, un intégrateur, gate officiel et sept jobs post-fusion avant annonce d'intégration. Revues indépendantes pour les changements importants. Les résultats en attente et les tests non exécutés restent explicitement identifiés.
