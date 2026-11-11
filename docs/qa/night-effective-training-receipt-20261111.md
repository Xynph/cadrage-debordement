# Mode demandé et mode collectif réellement appliqué

Base : `1910f03f7a5ec3a121d09608de1400f60952baf4`. Tranche produit
`297f0165`, complétée par les gardes de types `cfbd4cbe`. Seul fichier produit :
`native/godot/ui/decision_feedback.gd`. Aucun moteur, seuil de décision,
économie, calendrier ou style modifié.

## Contrat public constaté avant modification

`clubLife.clubSupport.training.session` publie seulement :

- `status`, `pending` avant la séance ou `applied` après ;
- `reason`, texte du compte rendu public, ou `null`.

La session ne possède **ni champ de mode, ni horodatage propre**. Son enveloppe
`clubSupport.context` publie `club`, `season` et `week`. Le mode collectif courant
est publié séparément dans `meta.training` et son application dans `meta.trained`.
Le moteur écrit le choix effectif dans cet état pendant `applyStaffPreparation`.
Le texte du compte rendu du staff reste disponible après un changement ultérieur
de délégation. Aucun texte n’a besoin d’être analysé pour retrouver un code mode.

L’ancien détail de reçu reprenait seulement `payload.mode`, qui pouvait annoncer
« Travail intense » alors que le collectif avait effectivement été placé au
repos. Les effets physiques observés ne permettent pas de corriger ce libellé
par déduction : les exceptions individuelles, récupérations et autres traitements
de séance existent déjà.

## Nouveaux reçus

Lorsqu’une transition publique `pending → applied` accompagne
`meta.trained : false → true`, avec le même contexte de club, univers de carrière,
saison et semaine avant/après, le nouveau reçu utilise le `meta.training` publié
à réception. Le contexte de l’enveloppe doit aussi correspondre à celui de la
carrière au départ et à l’arrivée. Les statuts mal typés et IDs de contexte
convertibles mais différents ne sont pas forcés vers une correspondance.

Si une demande intense est remplacée par du repos :

> Mode collectif appliqué : Repos · choix demandé : Travail intense.

Si le mode demandé et le mode connu sont identiques :

> Mode collectif appliqué : Travail normal.

Sans session concordante, sans mode actuel reconnu ou avec un contexte incertain,
la formulation affirme seulement la demande :

> Choix demandé : Travail intense.

Si la demande elle-même n’est pas publiée, le texte reste générique :
« Choix d’entraînement transmis. » Le réglage public précédent est employé
seulement lorsque la commande utilise réellement ce mode par défaut, sans champ
`mode` explicite.

Une `reason` textuelle et non vide de la session validée est copiée intégralement,
sous « Compte rendu de la séance ». Aucun rôle, motif ou seuil n’est ajouté s’il
n’est pas publié. La citation conserve même ses espaces et retours à la ligne ;
elle n’est jamais parsée pour déduire un mode. Le libellé **collectif** évite
d’affirmer que les exceptions individuelles ont suivi le même travail.

Ces changements concernent seulement les reçus créés après une nouvelle commande.
Les anciens objets de reçu, leurs titres, synthèses et citations ne sont pas
normalisés à la lecture ou réécrits lorsqu’un réglage change. Les coûts, valeurs
financières avant/après et observations de joueurs de la tranche précédente
restent inchangés. Aucun second reçu n’est produit pour une séance déjà appliquée.

## Deux ajustements atteints par les commandes publiques

Node `v22.23.4`, données reçues sur la source `297f0165`. Le runner
`tools/qa/effective-training-receipt.cjs` crée une carrière Fiction, club 13,
seed 427 et horloge fixe, puis traite les rendez-vous existants. La délégation
de l’entraînement est activée par sa commande publique avant la demande intense.

| Situation réellement jouée | Préparation publique | Condition moyenne du XV avant | Demande | `meta.training` après |
| --- | --- | ---: | --- | --- |
| Carrière fraîche | Aucun match, rendez-vous traités | 94,333 % | `intense` | `normal` |
| Après une journée | Séance normale, composition automatique, match délégué et journée terminée | 71,692 % | `intense` | `repos` |

Les deux raisons publiques exactes sont respectivement :

> Travail collectif retenu avec une condition moyenne de 94%.

> Récupération retenu avec une condition moyenne de 72%.

La seconde phrase conserve volontairement sa rédaction source. Les deux séances
sont réellement reçues comme `applied`, dans le même contexte public qu’avant
leur commande. Elles montrent deux demandes intenses effectivement remplacées,
sans édition de condition, de fichier de carrière ou de seuil. Il s’agit de deux
moments différents d’une carrière, **pas** d’une comparaison de stratégies depuis
un checkpoint identique. Le runner n’utilise la condition du XV que pour situer
le scénario de recette ; le composant UI n’utilise jamais cette condition pour
déduire le résultat.

Chaque cas conserve les commandes, contexte, demande, mode actuel, citation,
empreintes de profils et valeurs de RNG/horloge avant/après. Après la vraie
commande de séance, `snapshot` et `export` laissent son profil de résultat
inchangé. Les changements de RNG provoqués par l’action métier sont distingués
des lectures de contrôle.

[Cas publics et provenance](evidence/night-effective-training-20261111/public-worker-cases.json),
[journal Node](evidence/night-effective-training-20261111/node-run.log),
[empreintes des preuves et sources](evidence/night-effective-training-20261111/SHA256SUMS.json).

## Reçu Godot ciblé sur le candidat commun

`tests/godot-effective-training-receipt.cjs` a reçu le composant sur
`096f3d8f6a879bc2e240e99b2184ab7f3d688182` : **45 contrôles, zéro échec,
wrapper terminé avec le code 0**. Le produit `297f0165` est incorporé par
`545cd07ff4417ebf32014cdac539d50410200fd5` et les gardes `cfbd4cbe` par
`096f3d8f6a879bc2e240e99b2184ab7f3d688182`. Les quatre fichiers de produit et
de recette sont identiques octet pour octet à ces sources de tranche.

Godot 4.7.2 stable, Node 22.23.4, mode headless et audio Dummy. Les deux cas publics
ont été réutilisés par copie exacte, empreinte vérifiée, sans rejouer les actions
métier. La limite enfant reste 150 secondes. Aucune durée murale n’a été
instrumentée dans ce wrapper : aucune durée n’est déduite des dates de fichier.

Les cas de projection sont délimités comme synthétiques : raison exacte, mode
inconnu/absent, session manquante ou en attente, contexte incohérent/changé,
statut ou identifiant mal typé, absence de raison/acteur publié, prévision
contradictoire, seuil de 75 % cité mais jamais recalculé par l’UI, anciennes
citations intouchées, coût conservé, répétition et refus. La borne citée dans une
projection ne prétend pas constituer un essai natif à exactement 75 %. Les deux
ajustements publics, eux, sont de vraies commandes du worker.

[Rapport SDK et deux textes de reçu réellement obtenus](evidence/night-effective-training-20261111/godot-report.json),
[journal Godot](evidence/night-effective-training-20261111/godot.log),
[journal du wrapper](evidence/night-effective-training-20261111/wrapper.log).
Les cas atteints donnent bien « Travail normal appliqué, choix intense » puis
« Repos appliqué, choix intense », avec les raisons publiques exactes.

Ce reçu qualifie le composant de reçu dans Godot avec les deux vraies données
publiques et les contre-exemples synthétiques. Il ne constitue pas un parcours
graphique complet du client. Aucun nouveau Godot ou import de ce worktree,
recette Windows, nouveau calcul sportif, campagne CI globale ou nouvelle
certitude causale n’est revendiqué. Les 50 contrôles de la tranche précédente
d’observations appartiennent à leur reçu sur `1910f03f`, sans substitution de SHA.
