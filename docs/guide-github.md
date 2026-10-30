# Prendre en main le projet sur GitHub

Ce guide sert à suivre **Cadrage Débordement**, même sans connaître la programmation.

## À quoi sert GitHub ?

GitHub conserve les fichiers du projet et l’historique de leurs modifications.
Le dépôt est le dossier du projet. Il est privé : son contenu est accessible
aux personnes et applications autorisées.

Le dépôt contient le code, la documentation et les tests. Votre partie sauvegardée
reste dans le navigateur où vous jouez, ou dans le fichier JSON que vous exportez.
Le jeu hébergé et son code sur GitHub sont deux éléments distincts : modifier un
fichier ici ne publie pas automatiquement le jeu.

## Par où commencer ?

1. Ouvrez le dépôt `Xynph/cadrage-debordement`.
2. Sous la liste des fichiers, lisez la présentation : c’est le fichier `README.md`.
3. Cliquez sur un dossier pour voir son contenu, puis sur un fichier pour le lire.
4. Pour revenir à l’accueil, cliquez sur le nom `cadrage-debordement` en haut.

Vous pouvez laisser Codex gérer les modifications techniques. Il n’est pas
nécessaire d’installer un logiciel ou de modifier un fichier pour suivre le projet.

## Comprendre les principaux termes

| Terme affiché | Signification en français | Utilité |
|---|---|---|
| Code | Fichiers du projet | Consulter le code et les documents |
| Issues | Sujets à traiter | Noter un bug ou une idée |
| Pull requests | Propositions d’intégration | Examiner des modifications avant leur ajout |
| Actions | Automatisations | Consulter les tâches configurées ; leur présence dépend du projet |
| Settings | Paramètres | Gérer les réglages du dépôt |
| Private | Privé | Indique la visibilité du dépôt |
| Commit | Version enregistrée | Retrouver un ensemble de modifications daté |
| Branch | Branche de travail | Préparer une évolution séparément de la version principale |
| main | Branche principale | Consulter la version principale du code |
| README | Présentation | Comprendre le projet depuis sa page d’accueil |
| Clone | Copie liée au dépôt | Travailler sur le code depuis un ordinateur |

Un *commit* enregistre les modifications des fichiers. Il ne contient pas les
sauvegardes de votre partie et ne signifie pas forcément qu’une nouvelle version
du jeu a été publiée.

## Afficher les menus en français

Les textes de ce projet sont en français. Les menus du site GitHub sont gérés
par GitHub ; la langue des fichiers du projet ne les change pas.

Dans **Google Chrome sur ordinateur** :

1. Ouvrez la page GitHub à traduire.
2. Faites un clic droit dans une zone de texte ou une zone vide de la page.
3. Choisissez **Traduire en français**.
4. Si besoin, utilisez l’icône de traduction à droite de la barre d’adresse et
   choisissez **Français** comme langue cible.

Pour automatiser la traduction de l’anglais : ouvrez les paramètres de Chrome,
puis **Langues**, et ajoutez l’anglais aux langues à traduire automatiquement
dans la partie **Google Traduction**. Ce réglage concerne aussi les autres sites
en anglais.

La traduction du navigateur peut varier selon les termes et les pages. Les noms
de fichiers et commandes techniques doivent rester tels qu’ils sont écrits.

Source : [Aide officielle de Chrome : traduire des pages](https://support.google.com/chrome/answer/173424?hl=fr).

## Où trouver quoi ?

| Élément du dépôt | Contenu |
|---|---|
| `README.md` | Présentation, fonctionnalités, historique et limites |
| `dist/` | Interface et moteur du jeu |
| `tests/` | Scénarios automatiques de vérification |
| `docs/rugby-rules-reference.md` | Sources, règles applicables et limites de la simulation |
| `docs/guide-github.md` | Le présent guide |
| `AGENTS.md` | Consignes pour les personnes ou assistants qui développent le jeu |

## Signaler une idée ou un problème

Vous pouvez continuer à le décrire dans la conversation avec Codex. Pour un bug,
précisez l’écran, l’action effectuée, ce qui s’est produit et ce que vous attendiez.
Une capture peut aider. Pour un souci en match, indiquez aussi la minute et la
phase de jeu si elles sont visibles.
