# Atlas : historique et inventaire local sans transférer les photos

**L’atlas public de30clubs n’a pas perdu de photos dans Git.** Son manifeste original du commit `712d025` et celui de la base `9011537` sont identiques à l’octet : SHA256 `63fa870af008f4c4ef2b2a6df3997d2b0afc896b54721aff0dd04d4ba3d8a21d`. Le manifeste compte30villes+30stades. Les60fichiers sont présents et leurs60SHA distincts concordent. Ce constat porte sur les fichiers du dépôt, sans accès au profil personnel.

## Deux autres reçus, pas deux inventaires additionnables

| Preuve | Mesure disponible | Limite |
| --- | --- | --- |
| `dist/assets/club-atlas/manifest.json`, historique `712d025`→`9011537` |60références/60fichiers/60SHA vérifiés,30clubs avec les deux catégories | Atlas public intégré seulement |
| [Réception immersive](immersive08-coverage.md), paragraphe « ZIP Windows Atlas2761850 » |54photos de ville+49de stade documentées dans un pack privé | Les165fichiers vérifiés cités dans ce paragraphe appartiennent au paquet applicatif : ne pas les compter comme165photos Atlas |
| Même document, paragraphe « Atlas Sayama exact » |86photos de ville+86de stade documentées, recette source157contrôles |172références documentées ne prouvent ni172images distinctes ni couverture de116clubs |
| Passations#73 capturées le9novembre |05:27UTC : recette source157 ;05:46–06:14 : recettes Windows Atlas222 | Le SHA du ZIP0.7.8 cité dans ces messages identifie l’application, pas une empreinte du ZIP privé Atlas |

La recherche locale autorisée a couvert les fichiers du workspace, `library-files` et les partages connus. Les deux derniers sont vides ; aucune archive Atlas privée ni son manifeste détaillé n’a été retrouvé. Aucun téléchargement privé ou accès au disqueE n’a été entrepris. Ces reçus historiques prouvent qu’un pack a été reçu à ces moments, pas son installation actuelle sur le PC.

Le recouvrement entre les60images publiques et les172références Sayama reste **inconnu**. Il ne faut ni additionner60+172 ni présenter86+86comme une collecte publique accessible ici. La vérification d’un éventuel reçu déjà présent sur le PC précède un nouvel audit ; aucune exécution locale personnelle n’est acquise côté cloud.

## Outil de comparaison prêt pour CodexPC

Python3.9+ standard uniquement, lecture seule, aucune extraction/installation/réseau/écriture de profil. Le script réutilise les helpers bornés de `scripts/audit-identity-pack.py` : conserver les deux scripts du même dépôt.

Pour le manifeste public réel (les chemins `file` y sont relatifs à `dist`) :

```text
python scripts/audit-atlas-photos.py --public dist/assets/club-atlas/manifest.json dist --verify-assets
```

Pour comparer ce socle avec une archive native locale déjà disponible :

```text
python scripts/audit-atlas-photos.py --public dist/assets/club-atlas/manifest.json dist --pack "CHEMIN_DU_PACK_ATLAS.zip" --verify-assets
```

Répéter `--pack` pour comparer plusieurs ZIP ou `--public MANIFESTE RACINE_ASSETS` pour plusieurs manifestes publics, au plus16entrées. Les médias restent sur le PC. Seul le JSON agrégé est à rapporter. La redirection stdout éventuelle vise un nouveau fichier de résumé hors du profil du jeu.

Le format public lu est celui du vrai `manifest.json` : `version:1`, tableau `photos` avec `slug`, `kind`, `file`, `sha256`, `file_bytes`. Le format privé est le format natif `pack.json` : `clubs[].photos.city/stadium.asset` relié à `assets[]`. Les packsv1/v2 sans photos peuvent être recensés avec couverture territoriale0 ; les photos natives nécessitentv3. Le script ne traite pas un ZIP documentaire arbitraire ni un dossier installé comme une archive native.

## Ce que les compteurs signifient

Chaque entrée expose son type, son empreinte globale et son databaseId reconnu s’il s’agit d’un ZIP natif. Aucun nom de club/personne, slug, URL, ID individuel, chemin de photo ou chemin d’entrée n’est écrit dans le JSON.

- `byCategory.city/stadium` distingue références déclarées, couples club/catégorie, références à un fichier présent et références aux octets vérifiés. `uniqueFilesReferenced/Present/Verified` distingue les fichiers référencés des fichiers réellement présents. Sans `--verify-assets`, les compteurs vérifiés valent `null`.
- Les SHA distincts sont comptés par catégorie et globalement. Une même photo utilisée comme ville et stade compte2références et1SHA unique. Copier un ZIP ou répéter un manifeste n’ajoute pas de photo distincte dans `combined`.
- `overlaps` compte les SHA partagés entre deux entrées, puis les couples club/catégorie partagés et les triplets club/catégorie/SHA partagés. Les empreintes déclarées et celles vérifiées restent séparées. Une concordance SHA prouve l’identité des octets ; elle ne prouve pas que deux recadrages différents représentent des lieux différents.
- Le rapprochement public↔natif utilise la relation explicite `id`↔`slug` du registre public `native/engine/world-registry.json`, jamais la position d’une ligne. Si elle manque pour un atlas public, les SHA restent comparables, mais le rapprochement de ses clubs avec un ZIP natif vaut `null` : aucun faux « zéro recouvrement ».
- Les fichiers absents, références d’assets manquantes, métadonnées invalides, écarts de taille/SHA et erreurs de lecture sont quantifiés. Vérifier un SHA n’est pas décoder une image, certifier le lieu/sa date, ni certifier la couverture intégrale de116clubs.

Codes de sortie :0inventaire obtenu sans incohérence constatée ;2inventaire obtenu avec incohérences comptées ;1source illisible/non prise en charge, avec JSON à code constant. Aucun message d’exception ou chemin privé n’est affiché. Les JSON/ZIP/entrées et tailles sont bornés comme dans l’outil d’identité ; un chemin public ne peut sortir de la racine d’assets approuvée, y compris via un lien.

## Réception cloud

Les tests utilisent de vrais mini-ZIP et fichiers fictifs : recouvrement partiel, même image partagée, changement de photo à même club/catégorie, source répétée, source absente, statut de correspondance club inconnu, fichier corrompu, deflate invalide, chemins sortants et manifeste trop grand. Le test Node22 lance uniquement ces fixtures temporaires avec Python.

```text
python tests/audit-atlas-photos.py
node --test tests/audit-atlas-photos.cjs
```

Le reçu sur les deux manifestes publics historiques donne120références lues au total mais60couples club/catégorie et60SHA distincts vérifiés ; les60triplets sont communs. C’est une preuve directe du recouvrement du socle public à ces deux versions. Le même calcul sur le pack privé attend ses données locales ou un reçu agrégé existant, sans transfert des photos.
