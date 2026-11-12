# Petites fenêtres — réception du11 novembre2026

Les listes défilent dans leur zone ; les invitations, actions de préparation et barres de calendrier restent fixes. Les dimensions, couleurs, polices et données sportives ne sont pas redessinées. Base : `96f537040bf9f2e37bf10b0a9b09518b732244a2`.

## Résultats reçus

| Lot | Résultat | Portée |
| --- | --- | --- |
| Matrice principale | **4330 assertions,0 échec**,328 records |1280×720,1366×768,1440×900,1920×1080 et2560×1440 ;25 routes demandées, calendrier semaine et entraînement |
| Complément | **1648 assertions,0 échec**,133 records |17 familles de dialogue aux cinq tailles ;8 copies de présentation et10 confirmations effectivement annulées |
| Contrats, reçus distincts |37 cas,169 contrôles ; complément live21 | Négociation maintenue ouverte2560→1280→2560, brouillons et clavier ; mêmes sources qualifiées, aucune nouvelle relance locale union |

Les profils et les manifestes de sources restent identiques avant/après les deux lots graphiques. La préparation utilise le vrai moteur Node, une carrière commune actuelle, puis les commandes publiques du helper de rendez-vous. Les lectures suivantes n’envoient aucune commande et ne modifient pas `donnees.json`.

[JSON de lecture](small-window-geometry-20261111/evidence.json) · [rapport principal intégral compressé](small-window-geometry-20261111/main-report.json.gz) · [complément intégral compressé](small-window-geometry-20261111/extra-report.json.gz). Les archives conservent les données exactes ; leurs empreintes non compressées sont dans le JSON. Les98 captures principales et125 captures du complément ont des dimensions physiques contrôlées. Six PNG sont sélectionnés ici ; les deux comparatifs contrats déjà versionnés portent la sélection de cette branche à huit PNG.

## RED → GREEN

| Défaut mesuré | Avant | Après |
| --- | --- | --- |
| Réception1920×1080 | Défilement extérieur119 |0 ; invitations fixes, contenu exposable |
| Préparation, entraînement1920×1080 |39 |0 ; action Observer fixe |
| Calendrier mensuel1920×1080 | minimum958, défilement extérieur69 |0 ; programme et détail du jour défilent séparément, toolbar fixe |
| Bureau1280/1366/1440 |143 /119 /14 |0 aux trois tailles ; rencontre/priorités fixes |
| Copies de sécurité1280×720 | fenêtre1370×983, dépassement droit90px/bas299px |1252×652, zéro dépassement |

`outer_scroll` est la plage locale Godot ; les rectangles globaux sont en pixels physiques, après transformation du shell. Un défilement interne volontaire ne constitue pas un échec. Les contrôles sont exposés avec `ensure_control_visible`, puis comparés à l’intersection de tous les masques et de la fenêtre physique. Les axes désactivés sont enregistrés explicitement. Les boutons/champs hors périmètres réservés sont tous contrôlés ; les images et paragraphes ne sont pas assimilés à des commandes.

Les copies de sécurité ont aussi été reçues avec une projection de présentation de8 entrées : boutons Reprendre/Supprimer exposés, confirmations ouvertes par clic et **Annuler réellement cliqué**. Les dix annulations ont un delta de commandes égal à zéro. Aucun fichier n’est repris ni supprimé. La même fenêtre est conservée pendant2560→1280→2560, avec le même identifiant d’instance. Les positions des sous-fenêtres embarquées utilisent les coordonnées racine, sans additionner les positions des parents.

Les RED propres sont archivées dans [red-targets](small-window-geometry-20261111/red-targets-report.json.gz) et [red-profile](small-window-geometry-20261111/red-profile-report.json.gz). Le premier diagnostic Bureau provient de `/tmp/rg27-geometry-green-all/report.json`, sur10212d6 avant le correctif Bureau ; il ne constitue pas une réception globale sans clips.

## Captures sélectionnées

- [Bureau, contenu secondaire exposé](small-window-geometry-20261111/bureau-1280.png)
- [Réception, invitations fixes](small-window-geometry-20261111/reception-1280.png)
- [Préparation, action Observer](small-window-geometry-20261111/preparation-1280.png)
- [Calendrier, fin du programme exposée](small-window-geometry-20261111/calendrier-1280.png)
- [Copies de sécurité8/8](small-window-geometry-20261111/sauvegardes-1280.png)
- [Confirmation ensuite annulée](small-window-geometry-20261111/confirmation-1280.png)

## Limites explicites

- Sélections et Presse sont refusées dans cette carrière commune : la route réelle reste Carrière, donc ces demandes ne comptent pas comme deux écrans couverts. Le brouillon EPCR est absent de la fixture.
- Match est mesuré sans rencontre en cours. Gestes, ralenti, phases de match et dialogues conditionnels de match restent hors recette. Aucun code réservé Effectif/gestes/lineout/salaires/journaliste/calendrier sportif/validation des sauvegardes n’est modifié.
- Effectif/Composition/Match sont mesurés mais réservés. Les40 bornes `SquadPlayer*` restent partiellement hors masque gauche en1920 et2560 (environ8px). Elles sont conservées dans les diagnostics ; aucune assertion globale « zéro clip » n’est revendiquée.
- Les états vides ou non éligibles de promotion/prêt et les archives de première saison ne prouvent pas leurs états peuplés. Tous les sous-onglets, offres interclubs, confirmations de mobilité/agent et dialogues conditionnels de formation ne sont pas ouverts. [Inventaire :36 constructeurs directs et8 sous-classes](small-window-dialog-inventory-20261111.md).
- Les8 copies sont une projection de présentation restaurée après mesure, pas huit fichiers de sauvegarde. Seules les annulations sont exécutées.
- Les contrats ont leurs [reçus propres](../../tests/small-window-contracts.md). Ils ne sont pas présentés comme un nouveau rejeu local sur l’union.
- Linux/Xvfb/Mesa llvmpipe, audio Dummy, guide désactivé. Aucun test natif Windows ni verdict de lisibilité typographique ou conformité sportive n’est revendiqué.

## Reproduction et budgets

Préparer les données de la branche avec le constructeur existant :

```sh
python scripts/build-godot-prototype.py --stage-only --node "$CD_NODE_EXECUTABLE"
```

Importer le projet avec un cache privé et ses fichiers sources `.import`. Copier seulement `.godot` ne suffit pas : les polices et une texture extraite du GLB peuvent manquer. Le rendu reçu utilise Godot4.7.2 `ed1daf0bf`, Node22.23.4 et Xvfb2560×1440.

Commandes reçues (Node et Godot proviennent de `/workspace/.cloud-setup/tools/`) :

```sh
DISPLAY=:101 CD_GODOT_EXECUTABLE=/workspace/.cloud-setup/tools/godot472/Godot_v4.7.2-stable_linux.x86_64 CD_GEOMETRY_SEED_PROFILE=/tmp/oval-small-profile-Zc3KVN CD_GEOMETRY_OUTPUT=/tmp/rg27-geometry-final-union /workspace/.cloud-setup/tools/node-v22.23.4-linux-x64/bin/node tests/small-window-geometry.cjs

DISPLAY=:101 CD_GODOT_EXECUTABLE=/workspace/.cloud-setup/tools/godot472/Godot_v4.7.2-stable_linux.x86_64 CD_GEOMETRY_SCRIPT=small-window-geometry-extra-dialogs.gd CD_GEOMETRY_ROUTES=Bureau CD_GEOMETRY_TIMEOUT=720 CD_GEOMETRY_SEED_PROFILE=/tmp/oval-small-profile-Zc3KVN CD_GEOMETRY_OUTPUT=/tmp/rg27-geometry-final-extra-green /workspace/.cloud-setup/tools/node-v22.23.4-linux-x64/bin/node tests/small-window-geometry.cjs
```

Le seed est la copie d’un profil jetable créé par la recette, après ses rendez-vous initiaux ; il n’est pas un profil utilisateur. Sans `CD_GEOMETRY_SEED_PROFILE`, le pilote crée sa propre carrière. Prévoir alors le temps de cette préparation dans `CD_GEOMETRY_TIMEOUT`.

Chaque processus Godot prend `/tmp/rg27-godot-sdk.lock` : attente maximale600s, exécution **360s par défaut**, override **720s pour le complément**, plafond global du lanceur850s. Le pilote échoue rapidement sur `SCRIPT ERROR`, `Parse Error` ou `ERROR:`. Les contrats existants gardent leur borne de **90s par processus** ; ils ne doivent pas être enveloppés dans un second flock.

Les premiers essais avec cache incomplet, le pilote héritant d’une variable non typée, une référence à Gabi nul et une session coupée lors du redémarrage exec-server sont exclus des reçus. Un pilote souris Window.push_input qui n’ouvrait pas les confirmations a été corrigé avant la réception ; seul le clic via viewport racine reçu est compté.

Après réception, la seule modification du lanceur est la garde SDK absent : elle produit maintenant un SKIP explicite, conformément aux autres tests Godot, afin de ne pas casser les shards Node sans SDK. Cette branche a été vérifiée avec Node sans SDK et `node --check`. Le chemin exécuté avec SDK reste identique. La [copie exacte du lanceur reçu](small-window-geometry-20261111/launcher-received.cjs.txt), ses manifests et le changement de garde sont identifiés dans le JSON ; aucun nouveau verdict Godot n’est inventé pour ce changement.
