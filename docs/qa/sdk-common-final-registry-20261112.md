# Registre SDK commun — inventaire et campagne finale du 12 novembre 2026

Ce document prépare une seule campagne SDK commune après stabilisation. **Aucun dispatch global commun n’est revendiqué ici.** Le nouveau parcours graphique `public-career` a atteint sa limite enfant de 150 s pendant la préparation, avant les contrôles UI ; sa préparation par les seules API publiques Node est en cours de correction. La réception sur copie qualifiée reste distincte.

## Source exacte du registre

- Commit commun lu : `bd6a5fe63fe52fbb5ecf4a55859676876c7d983e`.
- Les deux JSON ont été relus depuis cet objet Git, sans prendre un worktree mouvant pour une source gelée.
- Registre followup : blob `58b45f5307832f0e075dc62e20da9b00930803fb` ; SHA-256 `9d2448c9a3c37bcdce5cc0cd95bc0d38df81fc8f010ae4c5505dc99174f4cf72`.
- [Registre followup](../../ci/godot-sdk-followup.json), [socle historique](../../ci/godot-sdk.json), [contrôleur strict](../../ci/run-godot-sdk.cjs).
- Il s’agit de données de test versionnées. Aucun workflow `.github`, permission, protection, paramètre serveur GitHub, quota, runner payant ou service n’a été modifié.

## Inventaire final des déclarations

| Job existant | Wrappers déclarés | Exécutions de registre |
| --- | ---: | ---: |
| sdk — socle historique | 12 | 12 |
| sdk-portraits-staff | 14 | 20 |
| sdk-parcours | 18 | 21 |
| sdk-layouts | 13 | 22 |
| **Total** | **56 distincts** | **75** |

Le followup contient **45 wrappers et 63 exécutions**. Le socle ajoute douze exécutions. Le même couple `tests/godot-guide-layout.cjs / layout-native` est volontairement conservé dans les deux registres : il y a donc **74 couples suite/cas distincts**, sans faire passer ce doublon historique pour une couverture supplémentaire.

Les matrices P1 historiques du job `sdk` sont exécutées après le contrôleur ; elles sont **hors du décompte des 75 `SDK_RESULT`**. Leur succès reste nécessaire au verdict du job, sans suppression de cas ni changement de budget.

### Les 21 inscriptions ajoutées, soit 27 exécutions

Tous les fichiers ci-dessous sont dans `tests/`. Les trois groupes restent ceux du workflow existant.

| Groupe | Nouveau wrapper | Cas explicites |
| --- | --- | --- |
| portraits-staff | `godot-entity-projections.cjs` | `default` |
| portraits-staff | `godot-prospect-profile.cjs` | `default` |
| portraits-staff | `godot-staff-fictional-labels.cjs` | `default` |
| portraits-staff | `rg27-night-navigation.cjs` | `reading`, `nation`, `guards`, `prospects`, `staff`, `quote`, `report` |
| portraits-staff | `godot-world-entity-targets.cjs` | `default` |
| portraits-staff | `godot-analysis-club-graphics.cjs` | `default` |
| parcours | `godot-entity-navigation.cjs` | `default` |
| parcours | `godot-management-reading-flow.cjs` | `default` |
| parcours | `godot-gestion-carnet.cjs` | `default` |
| parcours | `godot-observed-training-consequences.cjs` | `default` |
| parcours | `godot-effective-training-receipt.cjs` | `default` |
| parcours | `godot-office-entity-links.cjs` | `default` |
| layouts | `godot-finance-ledger-links.cjs` | `default` |
| layouts | `godot-reader-history.cjs` | `default` |
| layouts | `godot-training-identity-links.cjs` | `default` |
| layouts | `godot-navigation.cjs` | `default` |
| layouts | `godot-relationships-memory.cjs` | `default` |
| layouts | `godot-management-reading-links.cjs` | `default` |
| layouts | `godot-national-reading-links.cjs` | `default` |
| layouts | `godot-profile-reading.cjs` | `default` |
| layouts | `godot-analysis-club-links.cjs` | `default` |

Les 24 anciennes inscriptions followup, leurs groupes, leurs variantes et leurs environnements ont été conservés. `godot-fatigue-overview.cjs` était déjà inscrit : ses nouveaux contrôles sont repris par cette même entrée. Aucun préparateur de checkpoint n’est une suite : le CLI du rapport reste dans `tests/rg27-night-helpers/report-prepare.cjs`, hors découverte Node à la racine.

### Variantes et environnements

- Night : `reading`, `nation`, `guards`, `prospects`, `staff`, `quote`, `report`, sélectionnés par `CD_NIGHT_NAV_CASE` ; `CD_NIGHT_NAV_GRAPHICS=1` pour les sept réceptions graphiques.
- Art : `routes-1280`, `routes-1600`, `routes-1920`, `progression`, inchangés. Les trois premiers sont une matrice de routes à trois résolutions.
- Guide : `layout-native`, `layout-stretch`, `dock-native`, `dock-stretch` ; interface : `management`, `journal` ; lisibilité : `reading720`, `reading900`, `reading1080`, `reading1440`, `responsive`, `drafts`.
- Les autres nouveaux wrappers ont un seul cas `default`, avec leur mode headless inchangé, sauf le wrapper graphique Analyse/Club opt-in ci-dessous.
- Mode effectif : `CD_EFFECTIVE_TRAINING_REUSE_CASES=""` force la collecte publique des cas dans la qualification, même si un environnement appelant proposait un fichier local.
- Analyse/Club graphique : `CD_ANALYSIS_CLUB_GRAPHICS=1`, `CD_ANALYSIS_CLUB_GRAPHICS_SOURCE=""`. La qualification doit préparer sa propre carrière par API publique ; aucun chemin `/tmp` de recette locale n’est un prérequis CI.
- Les environnements graphiques antérieurs Guide, Interface, Lisibilité et Presse sont conservés. Aucun mode graphique supplémentaire n’est ajouté aux composants headless.
- Le wrapper GestionCarnet impose désormais le pilote audio Dummy explicitement. Le nouveau wrapper de lookup World est headless/Dummy et conserve 30 s.

## Scopes des preuves

- Les contrats Node du registre et les seize cas VM du contrôleur vérifient déclaration, refus SKIP/erreurs, sélection et limites. Ils ne démarrent pas le jeu et ne constituent pas un reçu SDK.
- Les composants SDK synthétiques — projections, dossiers prospect, libellés staff, cibles World, liens de gestion, convocations/classements et Bureau — vérifient les contrats locaux sans être présentés comme des carrières réelles complètes.
- Mémoire des relations, conséquences observées et mode effectif associent des commandes publiques de préparation à des projections contrôlées. Les copies de fixtures publiques locales restent identifiées ; les générations fraîches du futur SDK doivent garder leur propre preuve.
- Les wrappers de parcours du vrai main — notamment profile-reading, reader-history, entity-navigation, navigation, training-identity-links, finance-ledger-links, management-reading-flow, GestionCarnet et Night — exercent le vrai client/worker ou une archive importée prévue par leur recette. Les lecteurs purement consultatifs ne doivent pas déclencher de commande métier, modifier l’export/profil ou consommer le RNG sportif.
- Sur le candidat commun : entity-navigation 50/0 est reçu sur 58e ; graphique partagé sur copie 72/0 en 65,703 s et reader-history 115/0 en 113,959 s sont reçus sur bd6. Ces reçus ciblés ont leurs SHA propres.
- La première variante graphique `public-career` sur bd6 a expiré à 150 s pendant la préparation, jusqu’au 30 août, **avant les contrôles UI**. La copie qualifiée 72/0 n’est pas utilisée pour la déclarer verte. La préparation Node des mêmes étapes publiques puis le même replay UI est attendue sous **180 s au total, enfant Godot au plus 150 s, VM 15 s**.
- Les quatre réceptions Art sur c8a5 restent dans [leur passation](night-ci-20261111.md) : elles ne sont ni la campagne commune ni la performance du nouveau code UI.
- Les PNG locaux réels et les PNG produits sur runners restent distincts. Aucun résultat Windows, ZIP PC, fluidité, cadence ou validation exhaustive de toutes les fenêtres n’est revendiqué par ce registre. Claude conserve le ZIP et la recette PC.

## Répartition et budgets

Le workflow conserve quatre jobs, ses trois familles followup, 45 minutes par job et les limites 150/180 s existantes ainsi que VM 15 s. Les recettes courtes à 30/90 s restent à leur limite propre. Aucun délai n’a été relevé.

L’enveloppe ci-dessous est un plan conservateur : somme des durées SDK observées sur 7b23, plus 180 s par nouvelle exécution, plus 180 s de préparation. Le run de référence 7b23 reste rouge à 47/48 ; ses temps sont utilisés pour dimensionner, pas comme reçu vert du nouveau candidat.

| Famille | Anciennes durées de suites observées | Nouveaux cas réservés | Préparation réservée | Enveloppe | Marge sur 45 min |
| --- | ---: | ---: | ---: | ---: | ---: |
| portraits-staff | 164,022 s | 12 × 180 s | 180 s | 41 min 44 s | 3 min 16 s |
| parcours | 1 343,432 s | 6 × 180 s | 180 s | 43 min 23 s | 1 min 37 s |
| layouts | 802,874 s | 9 × 180 s | 180 s | 43 min 23 s | 1 min 37 s |

Ces enveloppes ne garantissent pas le temps maximal si toutes les anciennes recettes dérivent jusqu’à leur propre timeout. Les plafonds demeurent des critères de refus ; un timeout de job ou de cas rend la campagne incomplète/rouge. Aucune famille ni limite supplémentaire n’est proposée.

## Une seule demande de campagne, après le gel final

La commande ci-dessous est une **commande future à exécuter par root**, pas un dispatch déjà effectué. Attendre la réception du nouveau parcours graphique public et le gel final intégrant cette documentation ; publier ce HEAD puis remplacer le SHA d’exemple par ses quarante caractères exacts. Le SHA d’inventaire bd6 ne remplace pas ce futur HEAD publié.

Avant le POST :

1. Vérifier le HEAD distant de la branche, les sources/recettes propres et tous les prérequis locaux. Garder la branche figée pendant la campagne.
2. Vérifier qu’aucun run actif du workflow SDK ne concerne déjà cette branche ou ce HEAD ; sinon suivre celui qui convient. Le groupe de concurrence peut annuler une exécution précédente : ne pas s’en servir comme file de lancements.
3. Conserver les IDs de runs existants avant le POST pour identifier le nouveau reçu sans prendre un ancien succès.

```bash
rg27_sdk_ref='cloud/rg27-night-common-20261111'
rg27_sdk_sha='REMPLACER_PAR_LE_HEAD_PUBLIE_40_CARACTERES'
rg27_sdk_head=$(gh api "repos/Xynph/cadrage-debordement/branches/$rg27_sdk_ref" --jq '.commit.sha')
[[ "$rg27_sdk_head" == "$rg27_sdk_sha" ]] || exit 2
mkdir -p /workspace/work/sdk-final-dispatch
python - "$rg27_sdk_ref" <<'PYREQUEST' > /workspace/work/sdk-final-dispatch/request.json
import json, sys
print(json.dumps({"ref": sys.argv[1], "inputs": {"scope": "full"}}))
PYREQUEST
gh api --method POST \
  repos/Xynph/cadrage-debordement/actions/workflows/414839585/dispatches \
  --input /workspace/work/sdk-final-dispatch/request.json
```

Le seul POST demande `scope=full` au workflow SDK existant. Il ne demande ni workflow Windows, ni merge, ni nouvelle configuration serveur. Un accusé sans ID immédiat ne justifie pas un second POST.

Identifier ensuite un nouveau run unique correspondant à la branche, au SHA attendu, au workflow 414839585 et à `event=workflow_dispatch`. Refuser toute ambiguïté, changement de tête ou mauvaise identité avant de compter les résultats. Les quatre jobs attendus sont `sdk`, `sdk-portraits-staff`, `sdk-parcours`, `sdk-layouts`.

Pour annoncer la campagne reçue : les quatre jobs doivent être terminés avec succès, les **75 `SDK_RESULT` attendus** doivent tous être présents et verts (12 + 20 + 21 + 22), sans cas omis ou SKIP, et les matrices P1 du job historique doivent être reçues. Un retour ciblé après un échec doit rester décrit comme ciblé ou composite, jamais comme une nouvelle campagne complète verte. Aucun retry automatique ni hausse de timeout n’est prévu.

Relevé de coordination du 12 novembre à 00:23:17 UTC (01:23:17 Paris) : main est `eb2b1833ca514773f35aa347ce405bd404f0005e`, fusion #550, sans nouvelle fusion ensuite au relevé. Sa CI JavaScript [43120082969](https://github.com/Xynph/cadrage-debordement/actions/runs/43120082969) a ses sept jobs réussis ; ce reçu ne qualifie pas le SDK du lot commun. Aucun rebase ou intégration de main n’est revendiqué par ce document.

Aucune fusion Cloud avant le 12 novembre à 09 h, heure de Paris. Arrêt et passation à 08 h 30 ; le présent document ne modifie ni cette réservation ni les responsabilités de Claude.
