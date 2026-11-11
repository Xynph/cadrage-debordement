# Réceptions complémentaires interface, guide et lisibilité

La branche de suivi conserve la base `96f5370` et projette dans une copie privée
les six fichiers UI exacts de `d83a817` (PR 566). Le reçu porte leurs SHA256.
Aucun fichier de production n’est modifié ici. Les profils sont jetables ;
Godot Linux 4.7.2, Node 22.23.4, X11 `:102`, audio Dummy, une acquisition du
verrou par scénario et limite de 180 secondes pour Node hors attente.

| Scénario | Qualification reçue | Temps Node hors verrou | Preuve |
| --- | --- | --- | --- |
| Guide layout/stretch | 256 contrôles, 0 échec | 44,283 s | [reçu](qa-sdk-preloads-20261111-layout-final/guide-layout-stretch-receipt.json), [log complet](qa-sdk-preloads-20261111-layout-final/guide-layout-stretch.log), [sources figées](qa-sdk-preloads-20261111-layout-final/guide-layout-stretch-source-manifest.json) |
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

Les quatre couples guide ont chacun un reçu complet vert, avec le même GD et
wrapper silencieux : [manifeste des quatre cas](qa-sdk-preloads-20261111-layout-final/guide-four-cases.json).
Les temps natifs antérieurs restent 71,805 s pour layout (260 contrôles) et
117,572 s pour dock (160 contrôles). La provenance de production distingue les
deux reçus natifs anciens des deux nouveaux reçus stretch.

## Scénarios de diagnostic pour la recette distante

Les sources interface et lisibilité suivantes ont réellement compilé ensemble
avec Godot 4.7.2 (sortie `LAYOUT_SOURCE_COMPILE PASS`, code 0, 0,63 s).
**Elles ne sont pas encore qualifiées par un replay complet.** Ce dépôt fournit
les sélecteurs pour lancer leur diagnostic GitHub sans présenter la compilation
comme un résultat de test. Le [gel des sources locales](qa-sdk-preloads-20261111-layout-final/layout-source-freeze.json)
porte les SHA effectivement préparés, dont le helper original `d9c2c579…`.

| Wrapper | Variable | Scénarios indépendants |
| --- | --- | --- |
| `godot-interface-layout.cjs` | `CD_LAYOUT_CASE` | `management`, `journal` |
| `godot-readability06.cjs` | `CD_READABILITY06_CASE` | `reading720`, `reading900`, `reading1080`, `reading1440`, `responsive`, `drafts` |

L’interface conserve les contrôles de composition, de candidats autorisés, de
clavier, de focus, de brouillons, de Presse via son courrier et de reçus N10
dans `management`. Le cas `journal` importe séparément la fixture live et
conserve recherche réellement saisie, scroll, même caméra et mêmes instances
au redimensionnement. Les deux cas conservent les comparaisons disque et
export/RNG pertinentes. Le parcours cumulé précédent a été arrêté à 180,298 s,
sans assertion rouge ni compteur terminé : il reste non qualifié. Aucun plafond
n’est augmenté et aucun contrôle n’est supprimé pour tenir dans le budget.

La lisibilité sépare les quatre formats de lecture des scénarios de resize et
de brouillons. Chaque cas crée une vraie carrière, persiste la note par le
worker, puis compare export/RNG et octets du profil avant et après consultation.
Les attentes de pagination de l’effectif sont remplacées par la liste continue
complète, sans doublon d’identifiant, et de vraies ouvertures clavier aux deux
bords. Début, Fin et Page↓ sont contrôlés dans la table immersive. Les 24 lignes
de faits entières et chaque Label métier restent exigés ; seule la marge vide
du bouton sous la scrollbar n’est plus confondue avec une donnée coupée.
Salaires et échéances suivent leurs formats publiés (centaine, unité choisie,
année civile) à partir des données du worker. Le contexte compact est vérifié
après sélection explicite de son onglet Aperçu.

Sans filtre, les wrappers conservent tous leurs scénarios ; aucune durée
cumulée sous 180 s n’est revendiquée. La recette distante doit fournir un seul
sélecteur par invocation et conserver le plafond Node de 180 s.

## Réception locale interface management

Le premier scénario isolé est désormais qualifié : `CD_LAYOUT_CASE=management`,
**857 contrôles, aucun échec**, Node complet **125,846 s**, attente du verrou
0 s. Le [reçu](qa-sdk-preloads-20261111-layout-final/interface-management-receipt.json),
le [rapport](qa-sdk-preloads-20261111-layout-final/interface-management-report.json),
les [sources figées](qa-sdk-preloads-20261111-layout-final/interface-management-source-manifest.json)
et le [log complet](qa-sdk-preloads-20261111-layout-final/interface-management.log)
sont archivés. Le SHA du GD effectivement exécuté correspond au gel diagnostic.
Le cas Journal reste séparément à recevoir ; ce résultat ne le qualifie pas.

## Réception locale interface Journal

Le second scénario isolé est qualifié : `CD_LAYOUT_CASE=journal`,
**33 contrôles, aucun échec**, Node complet **119,380 s**, attente du verrou
0 s. Son [reçu](qa-sdk-preloads-20261111-layout-final/interface-journal-receipt.json),
[rapport](qa-sdk-preloads-20261111-layout-final/interface-journal-report.json),
[sources figées](qa-sdk-preloads-20261111-layout-final/interface-journal-source-manifest.json)
et [log](qa-sdk-preloads-20261111-layout-final/interface-journal.log) portent
le même SHA de harness que management. Les deux sélecteurs couvrent désormais
tous les contrôles de la famille interface. La [tentative cumulée antérieure](qa-sdk-preloads-20261111-layout-final/interface-cumulative-budget-receipt.json)
reste distincte et non qualifiée (180,298 s, compteur final absent).

## Réceptions locales de lisibilité

Les scénarios déjà reçus ci-dessous sont qualifiés individuellement. Ceux qui
ne sont pas cités restent au stade diagnostic compilé, sans résultat inventé.
Leurs SHA de harness sont comparés au même gel de source `ccf7090`.

| Scénario | Contrôles / échecs | Node hors verrou | Preuves |
| --- | --- | --- | --- |
| `responsive` | 124 / 0 | 62,978 s | [reçu](qa-sdk-preloads-20261111-layout-final/readability-responsive-receipt.json), [rapport](qa-sdk-preloads-20261111-layout-final/readability-responsive-report.json), [sources](qa-sdk-preloads-20261111-layout-final/readability-responsive-source-manifest.json), [log](qa-sdk-preloads-20261111-layout-final/readability-responsive.log) |
| `reading900` | 260 / 0 | 63,336 s | [reçu](qa-sdk-preloads-20261111-layout-final/readability-reading900-receipt.json), [rapport](qa-sdk-preloads-20261111-layout-final/readability-reading900-report.json), [sources](qa-sdk-preloads-20261111-layout-final/readability-reading900-source-manifest.json), [log](qa-sdk-preloads-20261111-layout-final/readability-reading900.log) |
