# Réception Work V17 — 2 novembre 2026

Réception producteur de la PR #209, depuis `8401f273510b5611489f843c46ce470d18c77802`. Aucune fusion autorisée ni effectuée.

## Trois anomalies reproduites et corrigées

- Le snapshot omettait `pos` et `fam`, indispensables à `slotEligible` : une feuille native valide était refusée par le laboratoire consultatif. Ces deux valeurs scalaires sont maintenant copiées depuis les joueurs natifs.
- `root.ATTACKS` n'existe pas dans le jeu ; les tactiques natives sont dans la constante globale lexicale `TACTICS`. Le connecteur lit maintenant ses clés, sans nouvelle liste parallèle.
- Dans Dossiers du club, la carte flex V17 était réduite à 46 px, avec débordement masqué malgré plus de 2 000 px de contenu. `flex: 0 0 auto` sur cette seule carte conserve sa hauteur ; le défilement reste celui de la page native.

Le moteur rugby, le stockage, les migrations et les workflows ne sont pas modifiés.

## Vérifications réellement exécutées

`tests/v17-native-browser.py` : **241 contrôles réussis, 0 échec, 0 exception navigateur**, Chromium Headless Shell 145.0.7632.6 sous Linux. Carrière neuve : Analyste et Tribune, 1440×900 et 1920×1080. Carrière restaurée : 1440×900 et 1920×1080, thème Tribune. Huit sections présentes et titres atteignables, masquage/réactivation, deux densités, vrais joueurs et adversaires, aucun calendrier daté inventé, aucune duplication du montage V17, absence de débordement horizontal. Vérification géométrique explicite contre la compression de la carte, et captures réellement inspectées.

Sauvegarde historique : code **V16** extrait par `git archive` du commit `dbcb0f3a31647ebc21de8450cf35582fd3e9004d` (30 octobre 2026). Un navigateur isolé exécute le vrai `start`, une journée avec `finishRound`, puis `createSaveDocument`. Ce n'est pas une sauvegarde actuelle dont les champs auraient été supprimés. Export produit pendant cette réception, pas un fichier personnel préexistant. Export du run vert : SHA-256 `9d1637f01bd07dc1ce1b33075b1238e6e0db059f64088a46ded147fbc3d2941c` (les nouvelles exécutions produisent naturellement un autre export).

Import par le vrai sélecteur fichier : aperçu et annulation sans mutation, confirmation, conservation de la carrière remplacée dans la copie de secours, export valide et reprise après rechargement. Club, saison/journée, résultats, joueurs/conditions/blessures/minutes, composition, finances et calendrier comparés aux valeurs V16. Après restauration, les lectures, sections et densités V17 préservent intégralement `JSON.stringify(S)` et **toutes** les clés/valeurs localStorage. Les migrations normales de l'import natif restent permises ; aucune égalité brute avant/après migration n'est revendiquée.

Autres commandes :

```sh
node --test tests/v17-unified-pc.test.cjs
node tests/saves.cjs
node tests/lnr-save-integrity-guards.cjs
node --check dist/v17-native-adapter.js
python -m py_compile tests/v17-native-browser.py
git diff --check
```

Résultats : 5/5 tests V17 ; suite sauvegardes réussie ; 5/5 tests intégrité ; syntaxe/diff réussis. La phase rouge a reproduit les deux faux refus et la compression de carte avant correction.

## Reproduction et limites

```sh
python -m pip install playwright
python -m playwright install chromium
python tests/v17-native-browser.py
# ou V17_CHROMIUM=/chemin/chromium V17_REPORT_DIR=/tmp/reception-v17 python tests/v17-native-browser.py
```

Le dépôt complet et son historique Git sont nécessaires pour extraire V16. Le script écrit le rapport JSON, l'export historique et les captures dans `/tmp/v17-native-report` par défaut. Avec `V17_CHROMIUM`, les options de lancement permettent l'exécution en processus unique dans cet environnement restreint ; aucun profil personnel n'est ouvert.

Aucun test Windows natif ni mobile revendiqué. Staff et mémoire affichent explicitement l'absence de données : aucun historique ou conseil inventé. Le laboratoire est consultatif ; il ne remplace pas les validations natives complètes de feuille de match. Le script ciblé est lancé explicitement, sans modification des sélecteurs CI existants. CI du nouveau HEAD à vérifier sur GitHub ; la CI 7/7 de l'ancien HEAD ne la remplace pas. `DEVELOPPEMENT.md` est laissé au chantier Fast Lane, la passation de ce lot étant publiée dans #73 et ici.

Revue indépendante en lecture seule : aucun défaut critique ou important relevé. La réception historique couvre une carrière après une journée, et compare les valeurs sportives et financières listées ; elle ne prouve pas une identité de tous les champs après migration.
