# Qualités et potentiel à la création d’une carrière

Le potentiel varie à chaque nouvelle carrière, sans option pour le désactiver.
La création propose une case **Faire légèrement varier le niveau actuel**,
cochée par défaut. La décocher conserve les qualités et le niveau actuels de
départ ; le potentiel continue de varier. Ce choix n’envoie aucune commande
tant que le joueur n’active pas la création de sa carrière.

## Contrat moteur

Après la génération complète des professionnels, libres, espoirs et centres
initiaux, `career-variation.cjs` applique une seule passe explicite. La graine
est celle du worker **avant** cette génération. Le manifeste enregistré est :

```js
S.careerVariation = { version: 1, seed: 0 /* uint32 */, varyCurrent: true };
```

Il est conservé à l’export, l’import et la reprise. Version, bornes de graine,
type booléen et liste exacte des clés sont validés au chargement. Un appel
répété avec le même manifeste est sans effet ; une configuration contradictoire
est refusée. Le payload de création ne permet ni de choisir la graine, ni de
désactiver le potentiel, ni d’injecter un manifeste.

Le calcul est un hash versionné de la graine, de l’ID et du canal. Il ne dépend
pas du club humain ou de l’ordre d’itération et ne consomme pas le générateur
aléatoire de compétition. Les consultations ne l’appellent jamais. Les anciens
profils sans manifeste restent sans manifeste et gardent les contrôles sources
antérieurs ; aucune variation n’est appliquée à leur reprise ou à leur import.

## Distribution et qualités réelles

| Écart | Potentiel | Niveau actuel, si activé |
|---|---:|---:|
| 0 | 28 % | 36 % |
| −1 / +1 | 20 % chacun | 24 % chacun |
| −2 / +2 | 10 % chacun | 6,5 % chacun |
| −3 / +3 | 4 % chacun | 1,5 % chacun |
| −4 / +4 | 1,5 % chacun | — |
| −5 / +5 | 0,5 % chacun | — |

Les bornes réduisent l’écart effectif près d’un minimum ou d’un maximum.
Le même delta de potentiel canonique est appliqué aux deux références :
`potential`, plafond des attributs sources borné à 20–97, et `dev.potential`,
capacité de développement bornée au niveau actuel–99. Ces deux grandeurs ont
des domaines distincts et ne sont pas deux tirages.

Les 36 attributs réels changent dans leurs bornes. L’effet de cette variation
sur les 11 compétences est calculé par différence des projections avant/après,
en conservant l’étalonnage de départ. Pour les joueurs générés, les compétences
et attributs compacts changent également. La note et `skillBase` suivent le même
écart effectif, afin de conserver leur différence sans doubler le bonus.
Les références initiales du suivi des jeunes suivent ce changement unique.

Les identifiants, positions, familles, profils sources et traits cachés restent
identiques. Les copies du marché sont alignées sur la même identité canonique.
Les catalogues de référence ne sont pas modifiés. Les validations de potentiel
des joueurs sources comparent leur plafond au delta canonique, sans assouplir
les autres contrôles d’identité ou de traits.

## Réception reproductible

```sh
node --test --test-concurrency=1 tests/career-variation.cjs tests/career-variation-worker.cjs
CD_GODOT_EXECUTABLE=/chemin/Godot node --test tests/godot-career-variation.cjs
```

Les tests purs couvrent les distributions, les bornes, les qualités complètes et
compactes, l’option désactivée, les copies et l’idempotence sans `Math.random`.
La matrice réelle worker compare tous les joueurs de la base commune entre
deux clubs humains, répète une graine et en change une, compare le RNG avec et
sans variation actuelle, rejette des imports modifiés, conserve les lectures
octet pour octet et reprend les huit éditions natives et la carrière fictive personnalisée. Le cas historique sans
manifeste reste accepté sans ajout automatique.

La confirmation de création fictive de l’atelier expose la même case, cochée
par défaut à chaque ouverture, et transmet le choix sans modifier son calendrier.
Comme la création standard, un remplacement depuis l’atelier conserve une copie
de sécurité du profil précédent. La forme du payload, le document et le contexte
de match sont validés avant toute copie : un refus laisse le profil, le RNG,
l’horloge et les copies existantes intacts. Le test ciblé restaure réellement
cette copie et compare l’export, la graine et l’horloge de la carrière d’origine.

Le banc Godot utilise l’application et son worker réels. Il teste la case et
la sélection du club au clavier, l’absence de commande lors des réglages, la
commande explicite unique, le manifeste réellement créé et le retour au défaut
coché lors de la prochaine ouverture. Les assertions de calibrage senior
utilisent volontairement `varyCurrent:false`, pour continuer à contrôler leur
barème exact ; elles tiennent compte du potentiel toujours variable.

Pour produire les deux captures de création en 2560×1440 sur le serveur
graphique de réception :

```sh
CD_GODOT_EXECUTABLE=/chemin/Godot \
CD_VARIATION_UI_GRAPHICS=1 \
CD_VARIATION_UI_OUTPUT="$PWD/work/variation-1440" \
node --test tests/godot-career-variation.cjs
```

Le banc utilise un profil temporaire hors de l’application. Cette réception
Linux ne constitue pas une exécution Windows native.
