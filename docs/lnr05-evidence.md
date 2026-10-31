# LNR-02 — Cellule de preuves et rotation, optionnelle et jouable

## Source et authenticité
Les **240 profils** DATA-05-BULK/BULK2/BULK3 (90 + 60 + 90) ont été rapprochés par ID LNR, slug et URL individuelle avec les **1 592 joueurs** du catalogue DATA-03. Aucune divergence ni doublon détecté. L'asset `dist/lnr05-enriched-data.js` contient uniquement [ID, âge rapporté, taille cm, poids kg, URL source LNR, club]. Datation : **31/10/2026**, pas de certification d'effectif ou d'âge au **01/07/2026**.

**Fictifs dans le moteur** : postes spécialisés réglementaires, capacité, note, âge de simulation, charge, fatigue, forme, salaires, contrats, finances, résultats et calendrier. Ils ne sont jamais remplacés automatiquement par les valeurs LNR. Aucun nouveau champ de sauvegarde ni aucune mutation du moteur de rugby. L'univers fictif historique n'affiche pas le nouveau panneau.

## Fonctionnalités jouables
Dans l'onglet **Effectif** d'une carrière LNR optionnelle, le nouveau panneau « Cellule LNR · preuves et rotation » montre les joueurs du club courant et quatre filtres (tous, mesurés, sans mesures, à ménager). Un clic sur un joueur révèle ses faits LNR sourcés et ses paramètres simulés nettement séparés. Liens vers chaque source officielle. Le joueur peut comparer les profils via la commande native, ouvrir gestion physique et feuille à 23, ou demander une **prévisualisation de remplacement dans la feuille native** en utilisant `buildSheet`, `slotEligible` et `benchEligible`. Aucune sauvegarde lors d'une consultation. Une confirmation explicite, contrôlée par empreinte anti-obsolescence, réévalue les 23 postes sans blessé ni doublon et exécute **un seul save()**. Pas d'inférence de qualification réglementaire à partir de taille/poids.

## Audit réel des 240 profils sans réseau
Le test `node --test tests/lnr05-real-import.cjs` exécute **véritablement** la fonction `run()` du collecteur unifié `tools/data05-unified.cjs` sur les 15 fichiers JSON du checkout, avec `limit=0`, `budget=0`, clé absente, transports injectés strictement interdits et répertoire temporaire. Il exige **240 entrées importées**, 1 352 restants, zéro requête ou crédit et seconde exécution idempotente (0 nouvel import), avec vérification des sorties et de tous les IDs/URLs/clubs. Ce n'est pas une collecte HTTP des pages LNR.

Le chantier distinct DATA-05-AUDIT du producteur est réservé à `tools/data05-audit.cjs`, `tests/data05-audit.cjs`, `docs/data05-audit.md`. Sa PR/CI doit être examinée une fois publiée. Aucun de ses fichiers ou de ceux du collecteur unifié n'est modifié.

## Validation
- `node tests/lnr05-evidence.cjs` : mode classique préservé, 240 fiches, aperçu sans mutation, confirmation, sauvegardes, cas verrouillés.
- `node tests/lnr05-evidence-long.cjs` : quatre saisons de jeu et exports compatibles.
- `python tests/lnr05-evidence-browser.py` : Chromium Linux 1280/768/390/320, interface, comportement et reprise.
- Les 3 jobs CI dédiés et tous les workflows PR y compris `Tests JavaScript` et `Validation CI` sur HEAD exact, sans contournement. Aucune certification Windows native.
