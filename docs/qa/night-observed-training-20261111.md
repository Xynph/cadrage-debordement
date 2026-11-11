# Conséquences observées dans le reçu de séance

Base : `a4326db5ff9d079dfabf64b79ad6100314d5145d`. Produit et scénarios
publics au commit `6d120934b8edada837c388a08391d16e98842081`, précision de test
de capture figée dans `07f85d95`. Un seul fichier produit :
`native/godot/ui/decision_feedback.gd`. Aucun moteur, coefficient, économie,
calendrier, donnée sportive ou style modifié.

## Inventaire avant modification

Le reçu de `train` indiquait déjà la séance réellement appliquée, son mode, les
variations de trésorerie, salaires et moral. Ces textes, montants et résumés
restent son préfixe inchangé. Les fiches et la préparation exposent déjà les
valeurs actuelles de condition, charge physique et niveau des joueurs connus du
club ; ce lot les rapproche seulement dans le reçu.

`nativeModel().squad` fournit `id`, `name`, `condition`, `physicalLoad` numérique
et `rating`. La projection de connaissance fournit `knowledge.owned` ; le niveau
exact reste accessible pour les joueurs du club, les informations adverses sont
conditionnées par l’observation. Le potentiel n’est pas une mesure de résultat
de séance et n’est pas consulté par cette amélioration.

## Comportement ajouté

Au vrai envoi de `train`, une copie limitée aux identifiants, noms et trois
valeurs publiques est retenue, uniquement pour les lignes avec
`knowledge.owned == true` de type booléen. À réception réussie, chaque mesure
compare les mêmes identifiants présents et connus avant **et** après, dans le
même club, mode, saison et semaine. Les arrivées et départs ne changent pas le
dénominateur. Les IDs dupliqués, valeurs absentes, non numériques, infinies ou
hors 0–100 sont exclus ; une ancienne projection sans propriété explicite
n’ajoute aucune observation.

Au plus trois lignes sont ajoutées, selon les données valables et les différences
effectivement affichées, par exemple :

> Condition moyenne de 40 joueurs présents avant et après : 89,4 → 96,9 %.
>
> Charge moyenne de 40 joueurs présents avant et après : 6,7 → 2,9 / 100.

Les valeurs sont affichées au dixième, sans zéro décimal inutile. Une moyenne
affichée inchangée ne crée ni ligne `0 → 0`, ni lien vers du bruit numérique.
L’absence de ligne ne prouve pas l’absence de variation individuelle : les
valeurs peuvent être absentes ou la moyenne arrondie peut rester identique.
Chaque ligne indique son nombre de joueurs comparables si les champs disponibles
diffèrent.

Deux liens au plus permettent de consulter les joueurs dont les variations
connues sont les plus marquées sur les mesures effectivement affichées. L’ordre
utilise leurs variations absolues, sans diagnostic ni jugement sur leur valeur
sportive. Les fiches restent ciblées par l’API d’ID existante et revalidées contre
la projection au moment de l’ouverture.

Le texte décrit un avant/après observé, sans « grâce à », bonus garanti, nouvel
effet annoncé ou attribution de toute la variation à un facteur unique. Une
commande refusée, une erreur de sauvegarde ou une séance déjà appliquée ne crée
pas de nouveau reçu. Aucun potentiel, attribut caché, joueur adverse, académie
ou prévision d’entraînement n’entre dans cette capture.

## Scénarios publics réellement exécutés

Node `v22.23.4`, source `6d120934b8edada837c388a08391d16e98842081`.
Le runner `tools/qa/observed-training-consequences.cjs` crée une carrière Fiction,
club 13, joue une première journée par les commandes publiques avec délégation,
traite ses rendez-vous existants et désactive la délégation de l’entraînement.
Il copie ensuite le **profil sauvegardé complet**, RNG et horloge compris, pour
chaque alternative. Aucun fichier de carrière n’est édité pour fabriquer une
condition, une blessure ou un niveau.

- Profil commun SHA-256 :
  `0f72da5ba607f2d9622320137c6eea2a949d36e9270ab6641176276abeb0d66f`.
- RNG initial : `3161170221` ; horloge sauvegardée : `1794434400000`.
- Même groupe comparable de 40 joueurs explicitement connus avant et après.

| Commande réelle | Condition moyenne | Charge moyenne | Niveau moyen affiché |
| --- | --- | --- | --- |
| Repos | 89,4 → 99,6 % | 6,7 → 0 / 100 | 67,1 → 67,1, ligne supprimée |
| Normal | 89,4 → 96,9 % | 6,7 → 2,9 / 100 | 67,1 → 67,1, ligne supprimée |
| Intense | 89,4 → 91,6 % | 6,7 → 12,7 / 100 | 67,1 → 67,1, ligne supprimée |
| Intense, avec une exception individuelle de repos | 89,4 → 92,2 % | 6,7 → 12,1 / 100 | 67,1 → 67,1, ligne supprimée |

Le joueur de l’exception est choisi sur sa charge publique déjà accumulée. Dans
ces deux branches comparables, sa condition observée passe à 72,7 % et sa charge
à 24 en collectif intense, contre 96,7 % et 0 avec son repos individuel. Cela
montre que le réglage individuel a réellement été appliqué dans ce scénario ;
aucune garantie de résultat sportif ou de progression à long terme n’en découle.

Une répétition de la séance normale répond avec succès mais laisse le profil
strictement inchangé et ne doit pas produire un second reçu. Après chaque séance,
les lectures de contrôle `snapshot` et `export` préservent les octets du profil,
son RNG et son horloge. Les commandes de séance ont naturellement leur propre
évolution du RNG, consignée séparément ; celle-ci n’est pas masquée comme une
consultation.

[Données publiques par mêmes IDs et provenance](evidence/night-observed-training-20261111/public-worker-observations.json),
[journal Node](evidence/night-observed-training-20261111/node-run.log),
[empreintes](evidence/night-observed-training-20261111/SHA256SUMS.json).
Le profil complet et la fixture privée du SDK ne sont pas ajoutés au dépôt.

## Validation et limites

Les wrappers Node passent la vérification syntaxique ; `git diff --check` passe.
La comparaison au commit de base ne montre aucun changement dans `native/engine`,
`dist` ou `project.godot`.

`tests/godot-observed-training-consequences.cjs` est préparé pour l’assemblage
commun déjà importé, sous le verrou partagé, avec audio Dummy et limite enfant
150 secondes. Il confronte le reçu aux quatre vraies séances et à leur répétition,
puis vérifie les cas de confidentialité, réordre, homonymes, arrivées/départs,
doublons, nombres invalides, contexte différent, manque de connaissance,
stabilité d’affichage et conservation des préfixes financiers. La fixture Node
déjà obtenue peut être réutilisée avec `CD_OBSERVED_TRAINING_REUSE_CASES`.

**Le reçu Godot de cette nouvelle tranche reste à obtenir.** Aucun lancement
Godot ou nouvel import du worktree, recette Windows, nouveau graphique, campagne
CI globale ou verdict d’équilibrage n’est revendiqué ici.
