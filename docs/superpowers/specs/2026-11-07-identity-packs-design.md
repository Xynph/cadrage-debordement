# Base commune anonymisée et packs d’identité natifs

## Décisions de Léo

Une seule base de trente clubs et 1 592 joueurs : les mêmes joueurs, identifiants et statistiques sous des noms proches mais fictifs dans le jeu de base. Rugby Réel révèle les noms et images réels. Les bonnes statistiques sont celles du mod publié, à reprendre sans les réévaluer. Un pack personnalisé s’importe à la création et dans les paramètres d’une carrière. Les anciennes carrières générées peuvent être supprimées ; repartir d’une base propre est explicitement autorisé. Travail et livraisons sur E:, raccourci bureau conservé.

## Approche retenue par l’intégrateur

La poursuite autonome a été demandée dans la conversation ; les deux décisions de contenu ci-dessus ont été clarifiées. Pas de nouvelle demande d’approbation du présent document.

- **Base commune et couche d’identité séparée — retenue.** Les données sportives anonymisées sont construites depuis les fichiers actifs LNR/V12/naissances de GitHub. Les packs changent uniquement la projection des noms/images ; les sauvegardes conservent les identifiants et la progression. Une préférence de création est distincte du pack de la carrière ouverte.
- Embarquer les images officielles dans le jeu de base : écarté. Le ZIP privé reste un import séparé ; son inventaire indique que les droits de redistribution ne sont pas établis.
- Remplacer les effectifs d’une carrière générée : écarté par Léo au profit d’un départ propre. Les lecteurs d’anciens formats restent fonctionnels ; aucune fausse correspondance avec les 900 anciens joueurs n’est inventée.

## Contrat produit

Le jeu reste Godot natif Windows avec son moteur Node embarqué privé, sans navigateur ni téléchargement automatique. L’édition de base ne contient pas le catalogue de vrais noms ni les images officielles du pack. Les notes, 36 attributs, 11 compétences, traits, potentiel et rôles actifs sont conservés tels quels. Les propositions d’audit BDD en DRAFT ne sont pas activées et aucun fichier source BDD du producteur n’est modifié. Les données financières demeurent simulées.

La création propose Base anonymisée et les packs installés, avec aperçu club/joueurs, couverture et distinction officielle/IA. Importer ouvre un sélecteur ZIP, une analyse puis un récapitulatif avant installation. Dans une carrière commune, activer ou retirer un pack garde les mêmes IDs, attributs, RNG, résultats, contrats et effectifs. Le pack peut modifier toutes les identités qu’il déclare ; les identités absentes conservent la présentation de base, avec couverture annoncée. Les recrues générées après le début de carrière restent des joueurs fictifs.

Le pack fourni `Rugby_Reel.zip`, SHA256 `8ed496a2c9588892f35768b701ba12d3b4e5443a19796bf1b13d0783a32f5716`, contient un inventaire `rugby-real-unified-pack-v2`, 30 logos et 1 592 portraits (1 549 officiels, 43 IA). Ce format doit être importable directement, sans exécuter ni copier ses galeries HTML. Les illustrations IA restent signalées dans le jeu.

Un format personnalisé documenté `cd-identity-pack-v1` permet de fournir noms de clubs/joueurs et images par identifiant stable. Les noms/images sont des données ; aucun script, HTML, programme ou URL distante ne s’exécute. Les packs s’installent hors exécutable, dans le profil sur E:. Une sauvegarde exportée ne contient que la liaison ID/empreinte du pack, aucun chemin arbitraire. Un pack manquant est signalé et peut être réimporté ; les données de carrière restent utilisables avec la présentation de base explicitement annoncée.

## Frontières techniques

Les carrières historiques restent `fiction`/`france`. La nouvelle création utilise `new_career {mode:'common',club:0..29}` et la compétition France existante ; un marqueur versionné de base commune distingue ses initialisations/validations. Les clubs conservent les IDs de `CDFranceClubs`, les joueurs les IDs `lnr:…`. Pas de nouvelle loi, calendrier ou règle économique.

Le modèle expose `meta.database` pour la base commune. Le gestionnaire de packs expose `model.packs = {installed, creation, career, missing, preview}` et projette `meta.catalogue` selon la sélection de création, puis les identités de la carrière selon sa liaison. Les objets de présentation de clubs contiennent `logoPath` et les joueurs `portraitPath`/`portraitStatus` quand disponibles. Aucun de ces chemins locaux n’entre dans la sauvegarde.

Commandes du worker : `pack_inspect {path}`, `pack_install {path,digest}`, `pack_select {id,scope:'creation'|'career'}` ; `id:'base'` retire la couche. L’analyse est en lecture seule ; l’installation exige l’empreinte analysée et reste atomique. La sélection de carrière enregistre sa seule liaison, avec rollback disque/état/RNG en cas d’échec. Une sélection de création ne modifie pas la carrière ouverte.

ZIP : limites explicites (512 Mio compressés, 768 Mio décompressés, 5 000 entrées, 16 Mio par image, 4 Mio de manifeste, 20 millions de pixels par image), chemins et Unicode normalisés, doublons insensibles à la casse, traversal/liens/chiffrement/ZIP64 refusés, décompression bornée et contrôles taille/CRC/SHA. Répertoire de staging et fichiers finaux confinés au profil physique ; aucune écriture au chemin déclaré par le ZIP. Rejet visible et ancien pack/carrière conservés. Les textures ont un cache borné ; pas de chargement simultané des 1 622 images.

## Réception et limites

Comparer les 1 592 profils construits aux statistiques actives du mod. Vérifier les trente clubs, un match TOP14 et PRO D2, une saison/intersaison, export/import/reprise, anciens formats et échecs d’écriture. Vérifier ZIP hostiles et vrais 1 622 fichiers fournis, reprise après déplacement, import par les deux entrées UI, bascule réel/base sur une carrière ayant évolué, images et mentions IA, pack absent et sélection indépendante. Réception graphique réelle Windows avant mise à jour de l’exécutable du bureau. Aucun actif officiel publié sur GitHub. L’audit final distingue manques BDD, couverture des images, gameplay et préparation commerciale.
