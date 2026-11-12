# Réceptions ciblées du socle silencieux — 12 novembre 2026

Source exacte commune : `d8f8a12470442caa8f00561990e43aa511fbfaba`.
Six suites séparées exécutées séquentiellement par l’intégrateur : **cinq wrappers
verts et un wrapper rouge**. Le SHA de rédaction 10ee90e6 n’est pas un SHA de test.
Aucune campagne SDK globale verte n’est déduite de cette reprise.

| Suite/cas | Résumé Godot | Verdict wrapper | Sous-test TAP (ms) | Total TAP (ms) | Wrapper Node (ms) |
| --- | ---: | --- | ---: | ---: | ---: |
| gestion-carnet | 273/0 | **Rouge — ERROR popup** | 48808.036157 | 48876.375921 | 48980 |
| entity-navigation | 51/0 | Vert | 17405.866398 | 17458.911456 | 17522 |
| navigation | 156/0 | Vert | 49783.732715 | 49832.13426 | 49883 |
| management-reading-flow | 61/0 | Vert | 35630.770516 | 35638.895579 | 35720 |
| analysis-club-graphics | 72/0 | Vert | 73548.18434 | 73591.90691 | 73655 |
| night-guards | 103/0 | Vert | 121014.397013 | 121062.557466 | 121102 |

Les décimales ci-dessus sont celles des journaux, sans arrondi. Le sous-test
mesure son corps, le total TAP le runner, et elapsed_ms de results.json mesure
le wrapper Node via le superviseur. Ces trois durées ne s’additionnent pas et ne
sont pas substituées à une durée Godot isolée. Les six logs/suites et leurs
empreintes de sources restent distincts dans le [reçu structuré](evidence/sdk-silent-core-20261112/receipt.json).

## Portée des cinq succès

- Entity-navigation 51/0 et navigation 156/0 : vrais hôtes et worker, identifiants,
  historique, refus et lecture pure, avec signal vocal requests/starts/id imprimé.
- Management 61/0 graphique : mêmes lecteurs/reçus, focus et scroll ; les trois
  compteurs vocaux sont sérialisés dans son rapport brut.
- Analyse/Club/Bureau 72/0 graphique : nouvelle carrière publique Common 0 puis
  consultation du vrai résultat `s1-elite-league-0-0`, **43–12 dans cette nouvelle
  carrière**. Les anciens résultats 15–20/19–10 ne lui sont pas substitués. Préparation publique et
  source-copy conservées ; ce n’est pas le replay WorldChamp copié. Le test
  vérifie les trois compteurs dans son assertion finale ; son rapport **ne les
  sérialise pas**. Ils ne sont pas ajoutés au JSON original.
- Guards 103/0 graphique : rendez-vous, presse par invitation exacte, causerie,
  match immersif et vrai résultat historique. Les trois compteurs sont sérialisés.

Ces cinq résultats sur d8f8 ne remplacent pas les réceptions antérieures par leurs
SHA ni n’ajoutent de destinations distinctes simplement parce qu’ils sont rejoués.
Aucun PNG n’est recopié : les rapports gardent les références/hashes des captures
locales de ce passage. Les preuves graphiques déjà publiées conservent leurs
SHA et limites propres. Aucun profil ni export complet ne figure dans ce dossier.

## Gestion : statut rouge maintenu

Le composant imprime 273 contrôles/0 échec et les trois compteurs vocaux à 0, mais
le wrapper termine avec code 1 et son test TAP échoue. L’erreur bloquante est :

```text
ERROR: Window 0 spawned at invalid position: (-738, -398).
  at: _popup_base (scene/main/window.cpp:2282)
  [0] show_centered (res://ui/immersive08/dialogs.gd:23)
  [1] open (res://ui/contract_negotiation.gd:169)
```

Elle apparaît lors de l’ouverture de la prolongation. Le wrapper refuse les
ERROR ; ni le compteur fonctionnel ni le silence ne compensent cette erreur.
Ce passage est **non qualifié**. La correction de viewport du test était en
travail lors de cette réception ; aucun résultat de cette correction n’est
anticipé, ni attribué au source d8f8.

## Mesure de silence et pièces conservées

Audio Dummy et mise en sourdine précoce sont ceux de la recette. Les trois
valeurs effectivement vérifiées sont demande de parole, début de parole et
identifiant de parole : 0/0/0 dans les six suites, y compris celle qui reste rouge.
Le reçu précise pour chacune la source exacte de cette preuve : ligne imprimée,
rapport brut ou assertion dans le script exact. Aucune synthèse vocale n’est lancée
pour fabriquer une preuve. Ces assertions ne constituent pas une recette Windows.

[Résultats du superviseur originaux](evidence/sdk-silent-core-20261112/results.json)
· [index, hashes, durées et verdicts](evidence/sdk-silent-core-20261112/receipt.json).
Chaque extrait est une sélection de lignes originales **numérotées**, limitée
aux versions, compteurs, résumé, erreur pertinente et verdict/durées TAP. Le SHA
et la taille du log intégral d’origine permettent de le distinguer de l’extrait.
Les gros dumps debug et répétitions de stack/JSON dus à l’assertion sont exclus.
Les rapports légers sont copiés sans retouche, sans pixels ni profils privés.
Vérification locale des pièces : `sha256sum --check SHA256SUMS` dans le dossier
d’évidence. Documentation uniquement : aucun SDK, import ou input exécuté.
