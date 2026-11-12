# Réception finale des familles guide, interface et lisibilité

Les trois familles disposent de reçus complets pour tous leurs scénarios.
Onze des treize cas de la recette GitHub initiale sont verts ; les deux rouges,
`reading720` et `reading1080`, ont ensuite été corrigés et reçus localement.
Le [registre des cas et provenances](qa-sdk-preloads-20261111-layout-final/qualified-cases-with-provenance.json)
conserve cette distinction. **Le premier run GitHub reste à 11/13 ; aucun run
GitHub unique n’a encore qualifié le patch final.** Aucune preuve ancienne ne
reçoit le SHA d’un fichier modifié après son exécution.

La production de référence est `d83a817` (PR 566). Les replays locaux projettent
ses six fichiers UI exacts sur la copie privée issue de `96f5370`, avec leurs
SHA dans les reçus. Aucun fichier de production n’est modifié par ce travail.
Godot Linux 4.7.2, Node 22.23.4, X11 et audio Dummy sont utilisés avec profils
jetables et une acquisition du verrou par scénario. Chaque durée Node complète
ci-dessous reste sous 180s ; aucun plafond Node ni budget de VM n’est augmenté.
Aucune exécution native Windows ni test de DPI matériel n’est revendiqué.

## Résultats

Les résultats GitHub viennent du job `130723697599`, tête `561f898`, avec le
helper final `2f1c4d11…`. Le [summary original](qa-sdk-preloads-20261111-layout-final/github-561-layouts-results.json)
est conservé sans réécriture, accompagné des [lignes de résultat](qa-sdk-preloads-20261111-layout-final/github-561-layouts-excerpt.log)
et des [SHA des sources de cette tête](qa-sdk-preloads-20261111-layout-final/github-561-layouts-source-hashes.json).

| Famille / scénario | Contrôles / échecs | Node hors attente | Provenance du reçu vert |
| --- | --- | --- | --- |
| Guide layout/native | 260 / 0 | 46,737s | GitHub 561 |
| Guide layout/stretch | 256 / 0 | 38,489s | GitHub 561 |
| Guide dock/native | 160 / 0 | 48,082s | GitHub 561 |
| Guide dock/stretch | 160 / 0 | 48,263s | GitHub 561 |
| Interface management | 857 / 0 | 111,891s | GitHub 561 |
| Interface journal | 33 / 0 | 106,704s | GitHub 561 |
| Lisibilité reading720 | 254 / 0 | 126,095s | [Local, patch final](qa-sdk-preloads-20261111-layout-final/readability-reading720-receipt.json) |
| Lisibilité reading900 | 260 / 0 | 54,734s | GitHub 561 |
| Lisibilité reading1080 | 275 / 0 | 87,915s | [Local, patch final](qa-sdk-preloads-20261111-layout-final/readability-reading1080-receipt.json) |
| Lisibilité reading1440 | 259 / 0 | 70,621s | GitHub 561 |
| Lisibilité responsive | 124 / 0 | 46,243s | GitHub 561 |
| Lisibilité drafts | 101 / 0 | 53,213s | GitHub 561 |

Le treizième cas distant, lineup, est également vert :867 contrôles en 40,146 s.
Il confirme sa réception antérieure ; aucun nouveau replay local inutile n’a
été ajouté pour cette famille.

## Deux corrections finales de contrat

À 1280×720, les quatre cartes secondaires du Bureau mesurent263,81 px de haut
dans un viewport de258,93 px. Leur rectangle entier ne peut pas y entrer.
Le test conserve l’assertion de lecture de chaque carte : largeur bornée et
chaque Label ou commande entièrement révélé par ses vrais parents
ScrollContainer. Les cartes qui tiennent gardent le contrôle du rectangle
entier. Les quatre cartes surdimensionnées ont 11, 43, 7 et 8 faits/commandes
vérifiés, soit 69. Les cinq accès métier conservent focus et visibilité, dont
le calendrier. Aucune tolérance géométrique n’est augmentée. [Rapport720](qa-sdk-preloads-20261111-layout-final/readability-reading720-report.json),
[log et mesures](qa-sdk-preloads-20261111-layout-final/readability-reading720.log),
[sources exécutées](qa-sdk-preloads-20261111-layout-final/readability-reading720-source-manifest.json).

À 1920×1080, le bandeau de famille consomme une ligne au début de la table.
Le vrai défilement révèle le 24ejoueur ; les 24 mêmes premières lignes de faits
sont ensuite toutes exigées entières simultanément. Le rapport mesure bien
24 lignes dans677,75 px, sans remplacer24 par 23. Les identifiants et toutes les
données de la liste continue restent contrôlés. [Rapport1080](qa-sdk-preloads-20261111-layout-final/readability-reading1080-report.json),
[log](qa-sdk-preloads-20261111-layout-final/readability-reading1080.log),
[sources exécutées](qa-sdk-preloads-20261111-layout-final/readability-reading1080-source-manifest.json).

Le GD final de ces deux replays porte le SHA256
`894365e4ce171c3e013670e7bb1729bae81941d3d53dce9dc72ebd66cfc85f71`.
Il a réellement compilé avant replay. Le [gel final](qa-sdk-preloads-20261111-layout-final/layout-source-freeze.json)
et le [gel initial](qa-sdk-preloads-20261111-layout-final/layout-source-freeze-initial.json)
restent distincts. Le helper local réellement exécuté est l’original
`d9c2c579…` ; le helper distant final `2f1c4d11…` ajoute des procédures sans
changer celles utilisées ici. Les autres scénarios de lisibilité gardent leurs
assertions et comportements précédents : le patch ne vise que 720 et 1080.

## Couverture et reproduction

| Wrapper | Variables de sélection | Cas indépendants |
| --- | --- | --- |
| `godot-guide-layout.cjs` | `CD_GUIDE_LAYOUT_CASE`, `CD_GUIDE_LAYOUT_MODE` | produit de `layout`/`dock` et `native`/`stretch` |
| `godot-interface-layout.cjs` | `CD_LAYOUT_CASE` | `management`, `journal` |
| `godot-readability06.cjs` | `CD_READABILITY06_CASE` | `reading720`, `reading900`, `reading1080`, `reading1440`, `responsive`, `drafts` |

La CI doit choisir un seul scénario par invocation. Les wrappers sans filtre
conservent la couverture cumulée ; leur durée totale sous 180s n’est pas
revendiquée. La [tentative interface cumulée](qa-sdk-preloads-20261111-layout-final/interface-cumulative-budget-receipt.json)
reste non qualifiée : 180,298 s, compteur final absent. Les cas isolés conservent
composition, candidats autorisés, vrai clavier et focus, brouillons, accès
Presse via son courrier, reçus N10, Journal de la vraie surface contextuelle,
recherche réellement saisie, même caméra et mêmes instances au resize.

La lisibilité vérifie les quatre formats, les 36 attributs du worker, les données
de contrat publiées, tous les identifiants de la liste continue sans doublon,
Début/Fin/Page↓, notes ciblées, comparateur et brouillons Unicode. Chaque cas
crée une vraie carrière et persiste sa note avant de prendre ses références.
Les consultations, saisies non validées et redimensionnements conservent les
octets du profil et l’export complet, y compris le RNG.

Le guide reste configuré par `setup(app,false)` : zéro signal vocal `requested`,
muted et aucun lecteur audio. Aucun TTS réel n’est appelé, aucun ERROR n’est
filtré. Les [quatre reçus locaux antérieurs](qa-sdk-preloads-20261111-layout-final/guide-four-cases.json)
conservent leur provenance exacte ; le nouveau run GitHub reçoit désormais les
quatre couples directement sur d83 avec le helper final. Le premier essai privé
stretch invalidé par l’omission de `dist/` ne constitue aucune qualification.

Les [reçus interface locaux](qa-sdk-preloads-20261111-layout-final/interface-management-receipt.json)
et [Journal](qa-sdk-preloads-20261111-layout-final/interface-journal-receipt.json)
restent archivés, ainsi que les premiers reçus lisibilité
[responsive](qa-sdk-preloads-20261111-layout-final/readability-responsive-receipt.json)
et [900](qa-sdk-preloads-20261111-layout-final/readability-reading900-receipt.json).
Le [gel des neuf fixtures](qa-sdk-preloads-20261111.md) et son
[complément](qa-sdk-preloads-20261111-complement.md) restent inchangés.
