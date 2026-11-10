# Polyvalence et efficacité au poste — réception native du 10 novembre 2026

Périmètre : XV adulte professionnel, saison simulée 2026–2027. Source de travail :
`72ade9099e874ece1ae017ff7ab8e9c2cf8a78be`, API initiale `c45557e`, puis le commit
sportif portant ce document. Aucun fichier de Godot ni le moteur web historique
n'est modifié par ce lot. Le worker natif injecte une seule fonction canonique
après les qualifications Nationale et Japon.

## Contrat et utilisation

Chaque joueur projeté possède :

| Champ | Sens |
| --- | --- |
| `primaryPosition` | Numéro 1–15 du poste principal, sans changer `pos`, `fam`, `rating` ou `note`. Les doublons d'une même famille utilisent son premier numéro canonique. |
| `secondaryPositions` | Autres numéros maîtrisés, hors principal, triés par aptitude décroissante puis numéro. Les postes naturels équivalents restent présents. |
| `positionRatings` | Notes permanentes entières par clé `"1"` à `"15"`. La condition n'est pas incluse. |
| `qualifiedFrontRowPositions` | Copie des seules qualifications 1/2/3 déjà reconnues par les hooks du moteur. Une note ou de bons attributs ne constituent jamais cette qualification. |
| `selection.slots[].positionNumber` | Référence canonique de couverture : XV 1–15 ; banc 2, 1, 3, 4, 6, 9, 10, 11. |
| `decisions.lineupDefence` | Entier 0–100, plaquage effectif du XV sélectionné, fourni même sans dossier d'adversaire. |

L'interface choisit les joueurs depuis `selection.slots[].eligibleIds` ; elle ne
déduit pas leur éligibilité d'une note. Le payload de déplacement demeure
`set_lineup {slot, playerId}`. Le reçu `meta.lineupChange` donne `fromSlot`,
`swapped`, `vacatedSlot` et `displacedPlayerId`. Un échange n'est produit que si
les deux affectations sont autorisées. Sinon la source peut rester vacante,
explicitement signalée. Les quotas et l'absence de doublon sont vérifiés avant
la modification de la composition.

Exemple reçu sur une vraie carrière common, seed 213 : `lnr:2399`, pilier gauche,
note principale 73 ; note à l'ouverture 13. Le déplacer du 1 au 10 est autorisé,
libère le 1 si le demi ne peut y jouer, et fait baisser le plaquage effectif du XV.
Un arrière sans qualification de première ligne reste refusé au 1.

## Modèle sportif volontaire

Le calcul lit les onze qualités déjà utilisées par `roleNote`, avec les bonus
permanents de spécialisation. Il ne tire aucun nombre aléatoire. Si un ancien
joueur n'a pas encore ses qualités, leur génération déterministe se fait sur une
copie privée. Blessure, charge et condition ne modifient pas la polyvalence
permanente ; la condition est appliquée ensuite par les mécanismes existants.

Le poste principal conserve exactement sa note habituelle ; ses numéros naturels
équivalents peuvent l'égaler. Au plus une famille supplémentaire est maîtrisée :

| Famille principale | Familles candidates, par préférence à qualités égales |
| --- | --- |
| Pilier | Aucune nouvelle famille maîtrisée |
| Talonneur | Troisième ligne / n°8 |
| Deuxième ligne | Troisième ligne / n°8 |
| Troisième ligne / n°8 | Deuxième ligne |
| Demi de mêlée | Ouverture, aile |
| Ouverture | Mêlée, arrière, centre |
| Aile | Centre, arrière |
| Centre | Aile, arrière, ouverture |
| Arrière | Aile, ouverture, centre |

Une famille candidate doit atteindre `max(55, 90 % de la note principale)` par les
poids de rôle existants et satisfaire ses qualités clés à
`max(50, 72 % de la note principale)`. La meilleure est retenue. Sa note vaut au
plus la principale moins 3, et la note brute du rôle moins 4. Les paires de
qualités clés sont explicites dans `position-aptitudes.cjs`.

Le dépannage est autorisé aux postes 4–15, avec une forte réduction : coefficient
0,64 pour une famille voisine, 0,49 dans la même unité avants/arrières et 0,32 entre
unités, plafonné sous la note principale. Les postes 1/2/3 demeurent strictement
réservés aux qualifications déjà reconnues. Ces coefficients sont une mécanique
du jeu, pas des règles de World Rugby.

L'efficacité d'une qualité en contexte vaut la qualité avec condition existante,
multipliée par `min(1, noteAuPoste / noteBruteDuRôleCible)`. Ce même calcul alimente
les unités du match, la conquête, le style et la sélection IA, les gains de
remplacement, le dossier du XV sélectionné et ses conseils. Les familles des
filtres collectifs proviennent du maillot actif. Les vrais objets joueurs restent
utilisés par le calcul de condition ; aucune identité permanente n'est changée.
Les performances au but restent fondées sur l'aptitude intrinsèque du buteur.
Les sélections internationales utilisent les mêmes notes projetées pour classer
les candidats et calculer leur force au poste.

L'auto-composition réserve par appariement les six places de première ligne avant
les choix de dépannage. Elle écarte les joueurs libérés en sélection à la date du
match de leur club et les non-inscrits japonais. Les hooks existants de quotas
restent l'autorité finale. Les remplaçants hors première ligne sont choisis sur
leur note de couverture plutôt que sur leur seule note principale.

## Réception reproductible

Node utilisé : v22.23.4. Profils temporaires privés sous `/tmp` ; aucune carrière
personnelle. Commandes depuis la racine de ce worktree :

```sh
node tests/native-position-aptitudes.cjs
node tests/native-position-japan-registration.cjs
node tests/native-position-integration.cjs
node tests/native-position-match.cjs
node tests/native-position-editions.cjs
node --test tests/frontrow.cjs tests/international-callups.cjs tests/international-career.cjs tests/japan-quota-runtime.cjs tests/japan-quota-frontrow.cjs tests/japan-quota-card-return.cjs tests/world-nationale-squad.cjs
node --test tests/native-player-attributes.cjs
```

Réceptions effectuées :

- API : toutes les notes, première ligne interdite même avec qualités maximales,
  centre/aile, deuxième ligne/n°8, lecture sans mutation ni RNG, condition sans
  changement de maîtrise, cache invalidé par entraînement en place/spécialisation.
- Worker common : choix/refus atomiques, source vacante et reçu, échange réel,
  notes principales inchangées, export/import puis redémarrage sans réparation
  implicite de la feuille, auto-composition valide, snapshots sans écriture.
- Match : remplacement réel d'un deuxième ligne au n°8, sauvegarde valide, deux
  matchs complets reproduits exactement depuis le même état et le même RNG,
  puis carton de pilier avec couverture qualifiée et 14 joueurs actifs.
- Japon 68 et Nationale 88 : vraies créations, 23 joueurs distincts, six
  qualifications vérifiées, auto-composition et export/import valides. Japon :
  inscriptions, éligibles et quotas vérifiés. Un autre test exécute les vrais
  hooks japonais avec un pilier 99 non inscrit, plus fort que les inscrits :
  ni build ni manager ne l'utilisent ; leurs six spécialistes restent complets.
- Régressions : 21 tests première ligne, international, Japon et Nationale verts ;
  les trois scénarios attributs common/world-champ/fiction verts.

## Coût mesuré et limites

Comparatif séquentiel sur cette machine, seed 213, une création common, trois
snapshots, une auto-composition ; archive de la base exacte 72ade90 puis candidat :

| Opération | Base | Candidat avec cache |
| --- | ---: | ---: |
| Création | 3 188 ms | 3 250 ms |
| Snapshots successifs | 245 / 159 / 189 ms | 370 / 340 / 308 ms |
| Auto-composition | 500 ms | 738 ms |
| Ensemble, initialisation incluse | 5 273 ms | 5 907 ms |

Commande : `node tests/native-position-benchmark.cjs /chemin/vers/base-locale`.
L'argument désigne un checkout local de 72ade90 contenant `native/engine` et
`dist`. Les profils de chaque exécution sont créés puis supprimés sous `/tmp`.
Ce relevé borne une opération représentative ; il ne constitue pas une mesure de
FPS, ni une campagne de carrière longue. Avant le cache pur, les snapshots
atteignaient 625–655 ms. Le cache conserve les résultats dérivés sans les écrire
dans le profil et vérifie les qualités, bonus et preuves de qualification à
chaque lecture. Les nombres dépendent de la charge machine.

Référence métier : [référentiel rugby du projet](rugby-rules-reference.md) et
[loi 3 World Rugby](https://passport.world.rugby/fr/les-regles-du-jeu/regles-du-jeu-par-numero/3-l-equipe/),
consultée par l'intégrateur le 10 novembre 2026 : 3.10–3.12 maintiennent la
désignation et la formation de première ligne ; un spécialiste peut débuter à un
autre poste. Ce lot ne prétend pas établir la conformité de toutes les autres
mécaniques historiques. Aucun nouveau moteur de récupération ou blessure, aucune
migration de format et aucune promesse de maîtrise obtenue par simple placement.
