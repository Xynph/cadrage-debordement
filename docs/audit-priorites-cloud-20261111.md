# Audit des priorités demandées par Codex Cloud

Relevé du 11 novembre 2026 sur la tête publiée de #539,
`fe79c36530273f453f66cbdf591669fa6fa5e0a7`. Lecture seule : aucune correction
commune, aucun test partagé modifié.

Trois priorités traitées : fuites de qualités cachées, archivage littéral des
déclarations de presse, portée des fixtures historiques. Les autres
(qualifications au poste, reçus Windows, budget) ne sont pas examinées ici.

## Résumé

| N° | Gravité | Constat | Déjà sur `main` ? |
| --- | --- | --- | --- |
| P1 | Élevée | Les salaires de départ des 1 596 joueurs sous contrat ne dépendent pas de leur niveau. L'indemnité de transfert en découle : le meilleur joueur de la base coûte moins cher qu'un remplaçant. | Oui |
| P2 | Élevée | Dix journalistes réels, avec leur média et un lien vers leur page d'auteur, figurent dans la base du jeu. Le jeu leur prête une personnalité et des questions inventées. | Oui |
| P3 | Moyenne | Pour un joueur libre jamais observé, le salaire demandé donne son niveau à trois points près : plus précis que l'intervalle de neuf points d'un joueur observé. | À vérifier |
| P4 | Moyenne | Aucune fixture ne provient d'une version livrée. Les trois sauvegardes figées datent des 7, 8 et 9 novembre 2026 ; les cas « historiques » des finances sont le worker actuel dont le source est modifié à la volée. | — |
| P5 | Faible | Les adversaires d'un match ne deviennent « observés » qu'à la clôture de la semaine, pas à la confirmation du résultat. | — |
| P6 | Faible | La vraie valeur n'est jamais le centre de l'intervalle affiché. | — |

Ce qui tient :

- **Aucune note cachée ne fuit par les champs du modèle.** Sur 3 283 joueurs
  non observés, aucun champ numérique ou texte ne suit le niveau ou le
  potentiel réels, sauf P3.
- **Les déclarations de presse sont archivées mot pour mot** : 12 sur 12,
  stables sur quatre semaines, identiques après fermeture et relance.
- **Le jeu avance jour par jour sans blocage** sur quatre semaines et quatre
  matchs, par les seules commandes publiques du worker.

## Méthode

Les sondes pilotent le vrai worker par `createBridge`, avec les aides de test
du dépôt (`tests/helpers/club-meetings.cjs`, `scene-match-talks.cjs`). Elles
sont dans `docs/audit-20261111/sondes/` :

```bash
node docs/audit-20261111/sondes/jouer.cjs  <racine du dépôt> 2   # fuites, 2 matchs
node docs/audit-20261111/sondes/presse.cjs <racine du dépôt> 4   # presse, 4 matchs
```

Scénario : carrière « common », club 29 (Valence Romans Drôme XV), graine 27,
calendrier quotidien, composition automatique, match délégué. Les réunions
obligatoires sont traitées par la réponse de moindre effet, comme dans les
tests du dépôt.

La sonde de fuites compare le modèle envoyé à l'interface à l'état exporté.
Pour chaque joueur que le modèle déclare « non observé », elle relève tous les
champs qui lui sont rattachés et mesure leur lien avec le niveau et le
potentiel réels : corrélation des champs numériques, part de variance
expliquée par les champs texte à peu de valeurs, présence du niveau en
chiffres dans les textes, ordre des listes, objets sans identifiant qui
gardent une note.

Limites : un seul club, un seul mode, quatre semaines au plus. Ni mission de
recruteur, ni négociation, ni centre de formation, ni intersaison n'ont été
joués. L'interface Godot n'a pas été relue écran par écran : la sonde regarde
ce que le moteur envoie, pas ce que chaque écran affiche.

## P1 — Salaires sans lien avec le niveau

**Fichier** : `dist/lnr-career.js:54`, `salary:3500+(seed%18…)` : le salaire
de départ est tiré d'une empreinte de l'identifiant. Présent à l'identique
sur `main` `1c83195d`.

**Mesure** (état exporté, 1 596 joueurs des 30 clubs) : corrélation entre
salaire et niveau **−0,01** ; par club, 0,00 en moyenne. 21 salaires
distincts, de 1 800 à 9 110.

**Conséquence** : `native/engine/interclub-market.cjs:21-23` calcule
l'indemnité à partir du seul salaire et de la durée du contrat.

| Toulouse Capitole XV | Niveau réel | Indemnité | Salaire proposé |
| --- | --- | --- | --- |
| Meilleur joueur de la base | 96 | 220 000 € | 4 400 € |
| Deuxième | 91 | 100 000 € | 5 800 € |
| Troisième | 90 | 60 000 € | 3 700 € |
| Un des moins bons | 69 | 470 000 € | 9 600 € |
| Le moins bon | 68 | 300 000 € | 9 300 € |

**Scénario** : dès le premier jour, le marché entre clubs propose les
meilleurs joueurs du championnat au prix d'un remplaçant. La masse salariale
d'un club ne dit rien de la qualité de son effectif.

**Gravité** : élevée pour l'équilibre du recrutement et des finances. Ce
n'est pas une fuite : c'est l'inverse, le prix ne porte aucune information.

**Piste** : faire dépendre le salaire de départ du niveau, de l'âge et du
club, à la création d'une carrière seulement. Les carrières existantes
gardent leurs contrats. À traiter hors du gel de livraison.

Les joueurs libres, eux, ont un salaire lié au niveau (P3) : les deux marchés
suivent des règles opposées.

## P2 — Journalistes réels dans la base du jeu

**Fichier** : `dist/press-question-bank.js:10`, constante `JOURNALISTS` : 30
entrées, dont 10 sans le marqueur `fictional`, avec nom, média et adresse de
la page d'auteur. Présent sur `main`.

**À l'écran** : `native/engine/press.cjs:222` les étiquette « Journaliste
référencé » et leur attache une personnalité rédigée par le jeu, par exemple
« Précis et concret : attend des repères de terrain, goûte peu les
esquives ». Le jeu leur fait poser des questions inventées et tient un score
de relation avec le manager. L'avertissement « aucune citation réelle » est
présent.

**Gravité** : élevée. C'est le même sujet que les noms de joueurs, en plus
exposé : le jeu attribue des propos et un caractère à des personnes nommées,
sous la marque de leur employeur.

**Piste** : les traiter dans le plan de retrait des identités
(`docs/retrait-noms-reels-plan-20261111.md`) : journalistes et médias
inventés dans la base, noms réels fournis par le pack importé.

## P3 — Le salaire demandé révèle le niveau des joueurs libres

**Mesure** (9 joueurs libres, tous « non observés ») : `salary` et `fee` du
modèle suivent le niveau réel avec une corrélation de 0,95. Pour un même
salaire, le niveau varie de trois points au plus.

| Salaire demandé | Niveau réel |
| --- | --- |
| 2 100 | 53 |
| 2 300 | 54 |
| 2 500 | 55, 57, 58 |
| 2 800 | 57 |
| 3 900 | 61 |
| 4 100 | 62 |
| 4 400 | 65 |

**Scénario** : le manager n'a envoyé aucun recruteur. La liste des joueurs
libres affiche « niveau inconnu », mais classer par salaire donne le
classement réel. Une observation payante (5 000 €) rend un intervalle de neuf
points : moins précis que le salaire, gratuit.

**Gravité** : moyenne. Un salaire demandé est une information légitime ;
c'est sa précision qui pose problème. Échantillon réduit à neuf joueurs.

**Piste** : arrondir ou masquer le salaire demandé tant que le joueur n'est
pas observé, ou afficher une fourchette.

## P4 — Portée réelle des fixtures historiques

| Fixture | Taille | Créée le | Suites qui la lisent |
| --- | --- | --- | --- |
| `tests/fixtures/france-long-career-s6.json.gz` | 206 Ko | 7 novembre 2026 | 6 |
| `tests/fixtures/roster-foundation-v1-s2.json.gz` | 472 Ko | 8 novembre 2026 | 6 |
| `tests/fixtures/regen-portraits-legacy-v1.json` | 5 Ko | 9 novembre 2026 | 1 |

Chacune n'a qu'un commit : elles n'ont pas été régénérées, c'est leur valeur.
Mais la plus ancienne a quatre jours.

`tests/world-finance-flow-audit.cjs:4-34` ne lit aucune sauvegarde ancienne.
Il recompile `native/engine/worker.cjs` après avoir remplacé trois morceaux
de son source par des chaînes exactes (service de profondeur, crochet des
postes, entrée de la machine virtuelle) et force `aiRoster.version=1`. Il
prouve le comportement du worker **actuel sans la profondeur**. Il ne prouve
pas qu'une carrière créée par un exécutable livré se rouvre. Il casse dès
que l'une des trois chaînes change, ce que ses assertions signalent bien.

**Ce qui manque** : un profil `donnees.json` écrit par chaque exécutable
réellement distribué (0.3 à 0.7.x), figé dans le dépôt avec son empreinte et
la version qui l'a produit. Les exécutables sont sur le PC de Léo. Tant que
ces profils n'existent pas, « les anciennes carrières se rouvrent » repose
sur des états fabriqués par le code actuel.

**Gravité** : moyenne. Aucune perte constatée ; c'est la preuve qui est plus
étroite que son nom.

## P5 — Observation des adversaires décalée

Après le premier match (Béziers, semaine 0) et `finish_round`, aucun
adversaire n'est marqué observé. Après le deuxième match, 22 le sont : tous
de Béziers, avec le jeton `match:1:0:league:14-29`. Ceux du deuxième match
n'apparaissent pas encore. L'enregistrement suit la clôture de la semaine,
pas la confirmation du résultat (`native/engine/player-knowledge.cjs:115`,
appelé depuis `recordDevelopmentMatch`).

**Scénario** : le lendemain d'un match, la fiche d'un adversaire que le
manager vient d'affronter affiche encore « non observé ».

## P6 — Intervalle jamais centré

`native/engine/player-knowledge.cjs:23` écarte l'intervalle dont le centre
est la vraie valeur. Un joueur qui le sait élimine une valeur sur cinq, neuf
ou onze. Sans conséquence pratique ; noté pour mémoire.

## Fuites : ce qui a été vérifié sans défaut

Après deux matchs : 3 405 joueurs connus de l'état, 100 du club (effectif et
centre), 22 observés, 3 283 non observés.

- `rating`, `potential`, `ratingRange` et `potentialRange` valent `null` pour
  tous les non observés.
- `clubLife.interclubMarket.candidates` (1 534 non observés) : `fee`,
  `salary`, `sourceSalary`, `age`, `contractEnd`, `family` sont sans lien avec
  le niveau (corrélations de −0,02 à 0,14). Voir P1 pour la raison.
- `clubLife.coachNotebook.targets` (3 283) : aucun champ variable.
- Ordre des listes : à l'intérieur d'un même club, l'ordre ne suit pas le
  niveau (corrélation de rang moyenne 0,06 pour le marché, 0,18 pour le
  carnet). L'ordre global suit celui des clubs.
- Aucun objet sans identifiant ne garde une note de joueur. Les seuls niveaux
  en clair sont ceux des membres de staff, affichés volontairement.

Non couvert par construction : la commande `export` renvoie l'état complet,
et `donnees.json` est lisible sur le disque. Les qualités cachées le sont
pour l'interface, pas pour qui ouvre la sauvegarde.

## Presse : détail

12 déclarations faites sur quatre semaines. Chacune est retrouvée dans
`clubLife.press.history` avec la question et la réponse exactes proposées à
l'écran au moment du choix. Aucune entrée ne change ensuite. L'état les
conserve en clair dans `S.pressConference.history`
(`questionText`, `answerText`, journaliste) : le texte n'est pas recomposé à
la lecture. Le modèle n'envoie que les 40 dernières
(`native/engine/press.cjs:238`).

Non testé : la relance qui cite une déclaration archivée, le changement de
club, l'intersaison, l'effet d'un pack d'identités sur les noms archivés.
