# Oval Legacy 27 — base commune et packs, Godot 0.3

Réception Windows du 7 novembre 2026. Code de l'exécutable reçu : `d1a2788`, après intégration des tâches base commune, packs et interface. La documentation ultérieure ne change pas ce binaire. Publication et CI GitHub constituent des preuves distinctes ; aucun statut futur n'est compté réussi ici.

## Ce qui est livré

Le jeu s'appelle **Oval Legacy 27 — Rugby Manager**. Son accueil utilise le logo au ballon et le lettrage validés par Léo ; son icône de fenêtre est transparente. L'interface conserve anthracite, ivoire, accents du club et soixante photos créditées des villes et stades. Le stade de match 3D reste générique.

Les nouvelles carrières utilisent la base `rugby-common-2026-10-31-v1` : **30 clubs, 1 592 joueurs**, dans deux divisions reliées de 14 et 16. Identifiants, âges, postes, 36 attributs, 11 compétences, notes, potentiels et traits proviennent exactement des données actives du mod. Seuls les noms sont anonymisés dans la base distribuée. Aucun recalibrage ni proposition BDD en brouillon n'est activé.

Les packs sont une couche d'identité : noms, abréviations, blasons et portraits suivent les IDs, y compris après transfert. Changer de pack dans une carrière conserve les joueurs, notes, contrats, progression, calendrier, résultats et générateur aléatoire. Les renforts créés ensuite par le jeu gardent leurs identités fictives lorsqu'aucune entrée du pack ne leur correspond.

Le pack fourni est conservé **séparément pour l'usage privé de Léo**, dans son profil sur E:. Ses médias ne sont ni publiés dans ce dépôt ni inclus dans le ZIP de base. Il couvre les 30 clubs et 1 592 joueurs : 30 logos, **1 549 portraits officiels et 43 illustrations IA**, ces dernières signalées sur les fiches. « Officiel » décrit la provenance, pas une autorisation de redistribution commerciale.

## Utiliser un pack

À la création : **Packs et identités**, puis **Importez un pack personnalisé**. Dans une carrière commune existante : **Menu → Paramètres → Packs et identités**. Choisir un ZIP, lire l'analyse, confirmer l'installation, puis sélectionner le pack. Le choix d'une future carrière reste indépendant du pack de la carrière ouverte.

La présentation **Base anonymisée** est toujours disponible. Un pack absent est annoncé, sa liaison reste conservée dans la sauvegarde et le jeu utilise la présentation de base ; réimporter le même pack rétablit les images. Les sauvegardes exportées ne contiennent ni images ni chemins de fichiers du pack. Les anciennes carrières générées à 14 ou 30 clubs restent lisibles ; elles ne sont pas converties en base commune. Le départ propre de Léo est une opération locale explicitement demandée, pas une suppression automatique chez tous les joueurs.

## Format personnalisé

`pack.json` doit être à la racine du ZIP. L'exemple `Packs/Exemple-identites.zip` est livré sans image et peut être modifié :

```json
{
  "schema": "cd-identity-pack-v1",
  "id": "mon-club",
  "name": "Mon univers",
  "version": "1.0.0",
  "databaseId": "rugby-common-2026-10-31-v1",
  "rightsStatus": "user-provided",
  "clubs": [{ "id": 0, "name": "Les Albatros XV", "abbr": "ALB" }],
  "players": [{ "id": "lnr:2399", "name": "Mon premier joueur" }],
  "assets": []
}
```

Les champs racine sont requis ; noms et images peuvent être partiels. Les IDs de club sont numériques, de 0 à 29 ; ceux des joueurs sont ceux de la base commune. Les clés supplémentaires, statistiques et IDs inconnus sont refusés.

Pour une image, ajouter un élément `assets` de forme `{ "id": "portrait-1", "path": "images/portrait.png", "sha256": "EMPREINTE_SHA256_64_HEXA", "bytes": 12345 }`. Référencer cet ID dans `clubs[].logo` ou `players[].portrait`. Un portrait exige `synthetic: true` pour une illustration IA, `false` pour une photographie. Ne pas renseigner `synthetic` sans portrait. Formats PNG, JPEG ou WebP ; chemins relatifs, aucun script, téléchargement ni HTML exécuté. Chaque asset déclaré doit être utilisé.

Limites : archive 512 Mio, décompression totale 768 Mio, 5 000 entrées, manifeste 4 Mio, image 16 Mio et 40 millions de pixels. Les signatures, dimensions, CRC, tailles et SHA sont vérifiés. Traversal, doublons Unicode/casse, liens, chiffrement, ZIP64 et chevauchements sont refusés. L'installation passe par un dossier temporaire et un renommage atomique ; une erreur conserve le pack précédent. Le fichier est réanalysé après l'aperçu. L'interface réduit les textures à 512 pixels maximum et borne le cache à 48 entrées.

## Réception réellement exécutée

Machine : Windows 11, Godot 4.7.2 officiel, GL Compatibility/OpenGL 3.3, RTX 4080 SUPER ; Node Windows 26.13.0 embarqué. Aucun contrôle de souris ou clavier système. Les scénarios utilisent les contrôles de nos instances Godot.

| Vérification | Résultat observé |
|---|---|
| Compilation commune | Parité exhaustive des 1 592 profils avec les données actives ; pseudonymes distincts et uniques ; sources BDD inchangées |
| Carrière commune | Clubs 0 et 29, matchs des deux divisions, saison complète, intersaison V11 active, export/import/reprise ; anciennes sauvegardes et rollback disque/RNG réussis |
| Installation du vrai ZIP | 1 622 images et leurs empreintes reçues ; sélection indépendante, identité après transfert, sauvegarde inchangée sauf liaison du pack |
| Entrées hostiles et erreurs disque | Bornes ZIP, chemins, corruption, empreintes, source remplacée, staging et persistance refusés sans écraser l'installation précédente |
| Décodage réel des images dans Godot | 1 622 décodages réussis, aucun échec ; maximum source 33 151 500 pixels ; 39,4 secondes pour la campagne séquentielle |
| Parcours graphique de packs depuis le SDK Windows | **86/86 contrôles à 1440×900 et 86/86 à 1920×1080**, import fourni et second personnalisé par les vrais contrôles, création et paramètres, réel/base/réel, mention IA |
| EXE release extrait et déplacé | **505/505 contrôles**, dix vues et deux résolutions, offre, renforts explicitement confirmés, matchs, saison complète, saison 2, export puis réimport |
| Autonomie de cette archive | 68 fichiers du manifeste vérifiés ; PATH sans Node installé, redémarrage avec le Node embarqué ; zéro connexion TCP observée, zéro processus orphelin |
| Redémarrage en lecture | Club 29, saison 2, mode commun ; fichier de sauvegarde inchangé après snapshot |

Le premier scénario de réception commun échouait avant le premier match car il omettait les renforts explicitement nécessaires à Valence. Le scénario a été corrigé pour utiliser le vrai bouton de composition et sa confirmation salariale ; aucun poste ni règle n'a été modifié pour faire passer le test. Un essai supplémentaire de lancer le script externe de test dans l'export release n'est pas une preuve : `--script` est réservé aux builds de développement. Il a été arrêté, sans modifier le produit. Les 86 contrôles de packs restent une preuve SDK distincte des 505 contrôles de l'EXE.

Archive reçue : `OvalLegacy27-PrototypeGodot-Windows-x64.zip`, **179 295 315 octets**.

SHA256 : `64c14b14548232e815735869ad2b6db4943a125abcb4fa1cf41310b6d440e32a`.

Décompresser le dossier complet et lancer `OvalLegacy27.exe`. Aucun navigateur, Godot ni Node à installer. Le profil historique `%APPDATA%/CadrageDebordement/PrototypeGodot` reste distinct de l'exécutable ; sur le poste de Léo, sa jonction vise `E:/Cadrage-Debordement/donnees/PrototypeGodot`. Garder les erreurs d'écriture visibles ; aucun repli de stockage silencieux.

```text
node scripts/build-rugby-common.cjs --check
python scripts/build-godot-prototype.py --sdk SDK_GODOT_WINDOWS_4.7.2 --node NODE_WINDOWS --output NOUVEAU_DOSSIER
```

Le constructeur inclut seulement les modules du worker, la compilation anonymisée et le module pur de progression déjà actif. Il refuse les autres fichiers LNR et une sortie déjà existante. Les licences du moteur, des fontes, du modèle et des photos accompagnent le ZIP. Les preuves privées sont sous `E:/Cadrage-Debordement/artefacts/` : `godot-native-qa/oval-legacy-27-final02`, `mod-packs-ui-logo-final-*` et `mod-packs-image-decode-report.json`. Aucun portrait officiel n'est publié ici par une capture d'écran.

## Ce qui manque au mod, par priorité

1. **Fiabiliser les postes et qualifications avant de réévaluer les notes.** L'audit de l'autre producteur en [PR #389](https://github.com/Xynph/cadrage-debordement/pull/389) signale 14 anomalies connues, dont des positions précises et familles incohérentes. Ces propositions restent séparées et ne sont pas activées ici. Les données actives laissent cinq clubs sans couverture initiale complète : Béziers, Brive, Aurillac, Montauban et Valence. Les promotions payantes sont un recours de jeu, pas une correction de la BDD.
2. **Distinguer professionnels, espoirs et conditions contractuelles.** Les effectifs importés comptent 36 à 65 joueurs, alors que le recrutement conserve son plafond historique de 42. Contrats, salaires et trésoreries restent calculés par le jeu ; ce ne sont pas des données financières réelles. La taille des effectifs demande un chantier produit distinct, sans modifier les notes en cours de collecte.
3. **Compléter et harmoniser les portraits.** Les 43 illustrations IA ne sont pas des photographies vérifiées des joueurs. Certains originaux officiels sont en pied, très grands ou cadrés différemment ; un recadrage homogène améliorerait les fiches. Les abréviations de clubs sont dérivées des titres des galeries, pas toutes certifiées comme usages officiels.
4. **Maintenir une base datée et traçable.** Snapshot du 31 octobre 2026, âges de saison et mouvements doivent rester cohérents ; les mises à jour sportives ne passent pas par un pack d'identité. Sources, date de vérification et incertitudes des attributs doivent accompagner les futurs travaux BDD.
5. **Préparer la commercialisation et l'international.** L'interface reste en français, le monde comprend trente clubs français sans Nationale ni ligues étrangères, et les corps/stades 3D sont génériques. Il reste à localiser le jeu et à tester d'autres configurations. La couverture des lois de match est partielle, profil historique 2025 ; aucune conformité complète 2026/27 n'est revendiquée.

Pour Steam, il faut aussi établir les droits commerciaux des contenus retenus : la provenance officielle d'une photo ou l'anonymisation ne les garantit pas. Le pack privé ne fait pas partie du produit commercial reçu. Le logo et les illustrations originales générées nécessitent la déclaration de contenu IA applicable ; l'antériorité du nom n'est pas certifiée. Voir les exigences officielles de [droits de distribution Steam](https://partner.steamgames.com/doc/gettingstarted/onboarding) et le [questionnaire sur les contenus IA](https://partner.steamgames.com/doc/gettingstarted/contentsurvey). Aucune mise en vente Steam, signature de binaire ou fonctionnalité Steam Cloud n'est annoncée par ce lot.
