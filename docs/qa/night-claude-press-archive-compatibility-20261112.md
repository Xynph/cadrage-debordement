# Réserve de projection des citations presse — reproduction isolée

Première source exacte : `f9c55a92939a4699f08c3bbce78fb69e07d81aee` (#553). La seconde vérification sur `44c7ebef` reste séparée ci-dessous. Revue follow-up séparée : produit/tests `2d366010`, sans confondre avec la suite documentaire `860f`.

Le [script de reproduction](evidence/night-claude-press-archive-compatibility-20261112/repro.cjs) charge une copie Git isolée des modules de `f9c55a92` et appelle uniquement l’interface publique `media-packs.createStore → inspect → install → project`. Le ZIP v2 contenant une rubrique presse qui renomme `presse-0` est réellement accepté et installé dans le répertoire isolé `profile/`. Aucun worker, Godot, changement de branche, moteur ou donnée de référence modifié.

Résultat exécuté : sortie 0, assertions passées. Preuve détaillée : [receipt.json](evidence/night-claude-press-archive-compatibility-20261112/receipt.json).

Entrée exacte, champ `clubLife.press.history[0].answer` :

> Je réponds à Nathan Delcourt : le groupe garde ma confiance.

Sortie exacte du même champ :

> Je réponds à Journaliste Test Zéro : le groupe garde ma confiance.

La question passe également de `Nathan Delcourt vous interroge sur le groupe.` à `Journaliste Test Zéro vous interroge sur le groupe.`. La signature du journaliste est renommée comme attendu. Les assertions vérifient que l’objet archive source et l’objet projection d’entrée restent strictement identiques après l’appel.

Limite : la fixture est un fragment représentatif de projection publique, pas une carrière importée et validée. Ce repro établit la transformation de chaînes par l’interface media-packs ; il ne démontre aucune occurrence dans les textes de la banque standard ni dans une carrière réelle.

## Proposition pour le propriétaire presse

`native/engine/media-packs.cjs:198` ajoute les noms presse aux substitutions ; `walk` aux lignes 206–207 traite ensuite toutes les chaînes hors exclusions existantes. Pour respecter un contrat de citation verbatim, distinguer la présentation courante des identités des champs d’archive :

- Continuer à présenter les signatures `journalist.name/outlet` avec le pack actif.
- Exclure des substitutions les champs `questionText`, `answerText`, `question`, `answer` des entrées `clubLife.press.history` et les `question/answer` de `clubLife.press.people[].memory[]`.
- Préserver `conference.questions[].followUp.quote` et `.question`. La relance affichée `conference.questions[].question` contient elle-même la citation entre guillemets ; préserver ce segment archivé, ou reconstruire l’affichage depuis les champs structurés sans substituer son contenu. Ne pas filtrer simplement toutes les propriétés nommées `question` dans le modèle entier.
- Vérifier avec une fixture d’archive validée par le propriétaire : pack/base/pack, texte cité exact à chaque étape, signature courante renommée, archive et RNG inchangés.

Ce document ne propose aucun patch moteur. L’arbitrage produit reste nécessaire si la substitution des identités *dans* les citations est volontaire : dans ce cas, ne pas annoncer que l’affichage est verbatim.

## Reproduire sans worker ni Godot

Depuis le dépôt, extraire les sources exactes dans un dossier temporaire :

```sh
PRESS_REPRO_SOURCE=$(mktemp -d)
git archive f9c55a92939a4699f08c3bbce78fb69e07d81aee native/engine dist | tar -x -C "$PRESS_REPRO_SOURCE"
CD_PRESS_REPRO_SOURCE_ROOT="$PRESS_REPRO_SOURCE" node docs/qa/evidence/night-claude-press-archive-compatibility-20261112/repro.cjs
```

Le script crée son ZIP, le stockage de pack et son reçu dans un dossier temporaire distinct. Seuls la présente note, le script autonome et le reçu JSON sont versionnés ; aucun profil, ZIP, moteur ou dépendance n’est inclus.

## Revue follow-up distincte

Lecture seule du diff `37e085b6..2d366010` : aucun effet métier ni affaiblissement QA constaté. La correction géométrique augmente la cible de date ; le helper staff sélectionne explicitement l’onglet équipe ; Dummy change le périphérique SDK et les nouvelles traces conservent les critères d’erreur/code de sortie. Cette conclusion de revue ne vaut pas exécution de ces recettes et reste distincte de la suite documentaire `860f`.

## Seconde source : suivi après #574, sans qualification de migration

Source exacte testée : `44c7ebef0edb8a04310a4c6fe9b4a221ce630e83`. Le
[repro distinct](evidence/night-claude-press-archive-compatibility-20261112/source-44c7ebef/repro.cjs)
a reçu une copie privée de seulement douze modules et dépendances nécessaires,
extraits avec `git show` sur ce SHA. Leur
[inventaire](evidence/night-claude-press-archive-compatibility-20261112/source-44c7ebef/snapshot-files.json)
est publié, sans inclure leurs contenus. Aucun worker, Godot, simulation ou asset
n’a été chargé. Le nom de `presse-0` est dérivé du catalogue public courant :
**Nathan Delcourt**, et non supposé depuis la première exécution.

L’API publique `createStore → inspect → install → project` accepte le ZIP v2
renommant `presse-0` en **Journaliste Test Zéro**. Le résultat reste identique
pour le fragment représentatif :

| Champ | Entrée exacte | Sortie exacte |
| --- | --- | --- |
| `question` | Nathan Delcourt vous interroge sur le groupe. | Journaliste Test Zéro vous interroge sur le groupe. |
| `answer` | Je réponds à Nathan Delcourt : le groupe garde ma confiance. | Je réponds à Journaliste Test Zéro : le groupe garde ma confiance. |

[Reçu de la seconde exécution](evidence/night-claude-press-archive-compatibility-20261112/source-44c7ebef/receipt.json) :
sortie Node **0**, pack accepté, assertions d’intégrité de l’objet archive source
et de l’objet projection d’entrée réussies. Les signatures sont renommées comme
attendu, mais les textes `question/answer` le sont aussi. La réserve conditionnelle
sur l’affichage verbatim persiste donc sur cette seconde source.

Le changement #574 ajoute une collecte de noms portés par des identifiants
`lnr:`, `world:` et `staff:` aux substitutions ; il ne filtre pas les champs
d’archives presse dans le chemin examiné. Ce constat n’est ni un audit de #574,
ni une qualification de sa migration runtime. Le fragment n’est pas une carrière
importée/validée ; aucune occurrence réelle dans une carrière ou la banque
standard n’est démontrée. La proposition de filtre ci-dessus reste une passation
au propriétaire presse, sans patch moteur concurrent.

Pour rejouer cette seconde source, extraire dans un dossier temporaire chacun
des chemins de `snapshot-files.json` par `git show 44c7ebef0edb8a04310a4c6fe9b4a221ce630e83:CHEMIN`,
en conservant son chemin relatif. Puis définir `CD_PRESS_REPRO_SOURCE_ROOT` vers
ce dossier et lancer le second `repro.cjs`. Le script crée séparément son stockage
temporaire. Seuls le script, le reçu et l’inventaire sont joints : aucun ZIP,
profil, module moteur, dépendance ou asset copié n’est versionné.
