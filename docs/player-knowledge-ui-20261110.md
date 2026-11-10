# Lecture des niveaux et potentiels

PR UI [531](https://github.com/Xynph/cadrage-debordement/pull/531), base `803db66`.
Moteur canonique fourni séparément par la PR 532 (`380a0db`, dépendance de
variation `73eb191`). Ce lot ne modifie ni le moteur ni le format de sauvegarde.

## Ce que voit le manager

- Dans son club, le niveau reste exact et le potentiel affiche la fourchette
  fournie par le moteur, en orange : par exemple `79–83`.
- Un joueur extérieur non observé affiche `—` pour son niveau et son potentiel.
  Première observation : intervalles de neuf et onze valeurs ; approfondissement :
  cinq et cinq. L'interface ne construit ni ne resserre aucun intervalle.
- Les attributs étrangers restent cachés jusqu'au suivi approfondi. Les anciennes
  projections sans métadonnées ne rendent jamais un potentiel scalaire ; les
  contextes explicitement issus de l'effectif propre peuvent lire leur niveau.
- Les tris et les filtres utilisent la borne basse visible, avec les valeurs
  inconnues à la fin dans les deux sens et les égalités départagées par ID.
- Le comparateur affiche les intervalles et leur écart possible : `70–78` contre
  `72–80` donne `-6 à +10`. Il ne présente pas un écart exact entre des moyennes
  artificielles. Le potentiel garde sa couleur orange.
- Les barres des rapports visualisent aussi la portion couverte par l'intervalle,
  y compris lorsque le joueur sous contrat ne figure pas dans le marché.

Les helpers partagés se trouvent dans `player_knowledge_text.gd`, exposés par
`game_skin.gd` et `carnet_skin.gd` : `rating_text`, `potential_text`,
`knowledge_sort_value`, `knowledge_bounds`, `knowledge_delta`, `attributes_known`.
L'appartenance explicite du moteur a priorité sur le contexte de la vue.

## Observation ciblée

La fiche de recrutement, le comparateur et le parcours marché historique proposent
`Observer` ou `Approfondir` seulement si l'API `person.scouting` est présente.
La confirmation reprend le coût et le délai fournis (`workUnit: week`). Elle
transmet `observe_player` avec le véritable `playerId`, y compris depuis un
rapport dont l'ID désigne le rapport lui-même. Le délai dépend du recruteur et
reste celui annoncé par le moteur ; aucune règle de staff n'est calculée ici.

La lecture et l'annulation ne créent aucun travail. L'attente d'une réponse, un
match, une observation déjà en cours, l'appartenance au club et les motifs de
refus du moteur désactivent l'action. Le travail en cours conserve le délai
restant fourni. Les missions et rapports existants restent accessibles.

## Périmètre audité

Effectif immersif et historique, fiche complète et profil latéral, contrats,
développement, formation/centres, vivier, recrutement, archives, comparateur,
recommandation Bureau, feuille nationale et convocations. Les historiques de
progression et moyennes de l'effectif propre restent des données connues.
Les moyennes collectives adverses ne sont pas des notes individuelles.
La moyenne du groupe affiche `—` si un niveau est inconnu ou en intervalle ;
aucune moyenne partielle ni conversion de `null` en zéro.

`entry_screens.gd` (création) et les deux modules Tactique sont réservés aux autres
chantiers. Tactique consomme uniquement des notes au poste de l'effectif propre.
Aucun changement partagé dans `main.gd` n'a été nécessaire : l'export de carrière
n'y avait déjà aucun aperçu JSON affiché. Le banc vérifie que le fichier écrit
reste identique à `meta.exportText`, constitue un document restaurable et ne
s'affiche pas dans les labels du jeu.

## Vérifications Linux natives

Godot 4.7.2 et Node 22. Recette graphique sur display privé, 2560 × 1440 uniquement.

- Helpers et agrégat de groupe : 26 contrôles, aucun échec.
- Réexécution headless sur le worker final `380a0db` : 199 contrôles, aucun échec.
- Contrats : 154 contrôles, aucun échec.
- Tris recrutement : 153 contrôles, aucun échec ; clavier, inconnus en dernier,
  liste intégrale et absence d'écriture.
- Comparateur : 33 contrôles, aucun échec ; recherche, identité, Échap et retour
  du focus, mêmes règles de consultation.
- Banc connaissance natif graphique : 207 contrôles, aucun échec. Carrière
  réellement créée par le worker ; observations initiale et approfondie issues de
  quatre vrais matchs/missions du banc moteur, sans mesures inventées côté UI.
  Le seul écran de comparaison synthétique porte explicitement `cas-ui-controle`
  dans son nom de fichier. Consultation et annulation : empreinte de carrière
  inchangée. Confirmation réelle : débit exact et état `pending` sans révélation.

Les profils de test sont jetables sous `/tmp`, hors du dossier application.
Les JSON de modèle de réception sont sous `/tmp/oval-knowledge-models/` et ne sont
pas inclus dans la PR. L'export produit par le banc reste un fichier privé de QA.

Commandes après intégration du moteur canonique :

```bash
CD_GODOT_EXECUTABLE=/chemin/Godot \
  node --test --test-concurrency=1 \
  tests/godot-player-knowledge-text.cjs \
  tests/godot-player-knowledge-ui.cjs \
  tests/godot-contract-review.cjs \
  tests/godot-recruitment-sorting.cjs

QA_RESOLUTION=2560x1440 CD_GODOT_EXECUTABLE=/chemin/Godot \
  node --test tests/godot-recruitment-comparison.cjs

DISPLAY=:94 LIBGL_ALWAYS_SOFTWARE=1 LP_NUM_THREADS=2 \
  CD_GODOT_EXECUTABLE=/chemin/Godot \
  CD_KNOWLEDGE_GRAPHICS=1 \
  CD_KNOWLEDGE_OBSERVED_MODEL=/tmp/oval-knowledge-models/first.json \
  CD_KNOWLEDGE_DEEP_MODEL=/tmp/oval-knowledge-models/deep.json \
  CD_KNOWLEDGE_OUTPUT=/tmp/oval-knowledge-1440 \
  node --test tests/godot-player-knowledge-ui.cjs
```

`CD_KNOWLEDGE_WORKER` permet de tester une copie isolée du moteur avant son
intégration. Sans moteur canonique ni SDK, le banc d'intégration le signale comme
ignoré ; les contrôles du helper restent autonomes avec le SDK.

Captures inspectées dans la copie de travail de réception :
`work/knowledge-native-final-1440/`. Les fichiers `report.json`, `engine.log` et
`godot.log` accompagnent les images. Le rapport de réception condensé est versionné
à côté de cette note.
