# Réserve de projection des citations presse — reproduction isolée

Source exacte : `f9c55a92939a4699f08c3bbce78fb69e07d81aee` (#553). Revue follow-up séparée : produit/tests `2d366010`, sans confondre avec la suite documentaire `860f`.

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
