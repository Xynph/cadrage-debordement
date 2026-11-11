# Réceptions complémentaires interface, guide et lisibilité

La branche de suivi conserve la base `96f5370` et projette dans une copie privée
les six fichiers UI exacts de `d83a817` (PR 566). Le reçu porte leurs SHA256.
Aucun fichier de production n’est modifié ici. Les profils sont jetables ;
Godot Linux 4.7.2, Node 22.23.4, X11 `:102`, audio Dummy, une acquisition du
verrou par scénario et limite de 180 secondes pour Node hors attente.

| Scénario | Qualification reçue | Temps Node hors verrou | Preuve |
| --- | --- | --- | --- |
| Guide dock/stretch | 160 contrôles, 0 échec | 49,244 s | [reçu](qa-sdk-preloads-20261111-layout-final/guide-dock-stretch-receipt.json), [log complet](qa-sdk-preloads-20261111-layout-final/guide-dock-stretch.log), [sources figées](qa-sdk-preloads-20261111-layout-final/guide-dock-stretch-source-manifest.json) |

Le GD et le wrapper guide restent ceux de `bfc4a99` : `setup(app,false)`, zéro
signal vocal `requested`, muted et aucun lecteur. Aucun TTS réel n’est appelé.
Les deux scénarios natifs précédemment qualifiés restent documentés dans le
[gel](qa-sdk-preloads-20261111.md) et le
[complément](qa-sdk-preloads-20261111-complement.md), sur la base de production
`96f5370`. Ils ne sont pas présentés comme de nouveaux replays sur `d83a817`.
Le wrapper guide sans filtre n’est pas qualifié sous 180 secondes : la CI doit
sélectionner chaque couple `CD_GUIDE_LAYOUT_CASE` / `CD_GUIDE_LAYOUT_MODE`.

Un premier essai privé layout/stretch a été invalidé : la copie omettait
`dist/` au lancement du worker. Le worker a ensuite été vérifié réellement
avec snapshot et shutdown, sans stderr. Cette erreur de préparation ne prouve
aucun résultat sur le produit. Aucun replay rouge ni compteur incomplet
n’est classé vert par ce document.
