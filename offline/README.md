# Application Windows portable

Cette distribution embarque le même jeu que `dist/`, ses polices et un petit
lanceur local. Elle ne requiert ni Python, ni Node.js, ni Go sur l’ordinateur du
joueur. Le lancement vise Windows 10/11 x64, avec Edge ou Chrome en fenêtre
d’application ; le navigateur par défaut sert de repli.

La [notice utilisateur](LIRE-MOI.txt) explique le lancement, le transfert JSON et
les mises à jour. Le démarrage de la fenêtre sur un véritable Windows n’a pas pu
être exécuté dans l’environnement Linux de cette livraison. Le binaire Windows
est compilé et son format PE x64 contrôlé ; le serveur, les sauvegardes et le
jeu sont testés sur la version native Linux du même lanceur et dans le navigateur.

## Stockage

`dist/storage.js` utilise le stockage du navigateur sur le web. Dans l’application,
`offline-bridge.js`, chargé avant le jeu, fournit la même interface de lecture,
écriture et suppression, reliée à des fichiers dans
`%LOCALAPPDATA%\CadrageDebordement`.

Les écritures attendent leur confirmation réelle sur disque. Une erreur remonte
aux contrôles de sauvegarde et d’import existants ; il n’y a aucun repli silencieux
sur un profil de navigateur. Le dossier de données est indépendant de l’emplacement
et du nom de l’exécutable. Les ressources servies sont incorporées au binaire.

- `donnees.json` : clés de la carrière, préférences et copies de secours du jeu.
- `donnees-precedentes.json` : état précédent du stockage complet.
- `donnees-illisibles-*.json` : copie conservée avant récupération d’un fichier illisible.
- `Profil/` : préférences de la fenêtre Edge ou Chrome.

Un verrou empêche deux lanceurs d’écrire simultanément dans le même dossier.
Les révisions refusent aussi les écritures obsolètes venant de fenêtres distinctes.
Les fichiers sont écrits via un fichier temporaire dans le même dossier, synchronisé
avant renommage. Une copie précédente est enregistrée avant chaque modification.
Ces précautions ne remplacent pas un export sur un autre support.

## Fonctionnement local

Le serveur écoute uniquement `127.0.0.1`, sur un port libre. Un cookie de session
aléatoire et les contrôles d’origine protègent ses opérations. Les ressources et
polices restent locales ; la politique de contenu refuse les chargements externes.
Le serveur ne fait aucun appel à Internet et n’emploie aucune API d’IA. Les liens
d’aide peuvent ouvrir un site externe si le joueur les utilise volontairement.

Les battements de présence maintiennent le lanceur actif. « Enregistrer et quitter »
enregistre une éventuelle rencontre en pause, puis demande l’arrêt du serveur.
Sans activité de la fenêtre, il s’arrête après environ cinq minutes.

## Construire la distribution

Pour les développeurs seulement : Python 3 et Go 1.24 ou plus récent sont nécessaires.
Aucune dépendance Go externe n’est utilisée.

```sh
python scripts/build-offline.py --go go --out offline/out
```

Le script prépare les ressources embarquées, lance les tests Go, compile
`CadrageDebordement.exe` pour Windows x64 et crée le ZIP avec la notice et les
licences. Les compilations désactivent CGO et les téléchargements automatiques
de modules ou d’outils Go. Le manifeste `verification.json` contient les empreintes
SHA-256 des ressources et de la livraison. L’exécutable est non signé.

Pour produire également le binaire Linux destiné aux tests :

```sh
python scripts/build-offline.py --native-test
node tests/offline.cjs
python tests/offline-server.py --binary offline/out/cadrage-test-linux
```

La compilation Linux de test ne change pas la cible Windows de l’archive.
Les dossiers `offline/launcher/app/` et `offline/out/` sont générés et exclus de Git.

## Polices et licences

Barlow Condensed et DM Sans sont livrées sans modification depuis le catalogue
[Google Fonts](https://github.com/google/fonts), avec leurs licences SIL OFL 1.1
dans `dist/fonts/`. La licence BSD du runtime Go est incluse dans l’archive.
