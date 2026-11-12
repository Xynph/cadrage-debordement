# Photos de territoire des packs Monde

Depuis Windows 0.7.6, le registre Monde + Champ reçoit aussi un pack de
présentation `cd-identity-pack-v3`. Les packs v1/v2 et les carrières des
éditions précédentes gardent leur format et leurs contraintes. Le pack v3
n’ajoute aucun champ à une sauvegarde : il projette des images et des crédits
sur la fiche du club piloté, sous l’identifiant déjà utilisé pour ses noms et
son blason.

Dans `clubs`, la clé facultative `photos` contient `city` ou `stadium`.
Chaque photo référence un identifiant déjà déclaré dans `assets` et fournit
le texte de crédit, la page source et la page de licence HTTPS.

```json
{
  "id": 30,
  "photos": {
    "stadium": {
      "asset": "atlas-30-stadium",
      "credit": "Vue de l’enceinte · auteur · licence",
      "source": "https://example.org/photo",
      "license": "https://example.org/licence"
    }
  }
}
```

Les images sont bornées à 2 Mio chacune, au moins 320 × 160 et au plus
2 400 px sur chaque côté. Les empreintes, les chemins ZIP, les fichiers
installés et les champs d’attribution sont validés. La limite globale
d’archive et le nombre maximal d’entrées restent ceux des packs Monde.
L’activation ou le retrait ne change ni les identifiants, ni la progression,
ni les résultats. Une photo altérée rend le pack indisponible et la carrière
reste chargeable dans sa présentation de base.

Le jeu de base utilise des illustrations photoréalistes générées pour les stades
et les villes. Leur [provenance](../native/godot/art/territories/provenance.json)
donne les prompts, les empreintes et l’ordre des clubs dans les planches.

Les photos du pack actif prennent la priorité à la création, dans Club →
Territoire et dans les aperçus du Bureau. Club → Territoire affiche les crédits,
les pages sources et les licences. Le ZIP privé Rugby Réel complet fournit les
deux photos pour chacun des 116 clubs. L’ancienne version qui omettait les
30 premiers clubs retrouve leurs photographies dans l’atlas d’archives intégré
uniquement quand Rugby Réel est actif. Une vue d’archive peut précéder des travaux
ou le déménagement d’un club. Les manifestes privés en gardent le détail.

`tests/world-venue-media.cjs` couvre la projection, le retrait, la reprise,
les refus et l’altération d’une photo. Les contrôles Windows utilisent un
pack privé en profil jetable. Aucun média nouveau de ce pack ne fait partie
du dépôt ou de l’exécutable.


## Identités de compétition

Le schéma `cd-identity-pack-v4` conserve les médias de territoire et ajoute le tableau
`competitions`. Chaque entrée utilise l’identifiant d’une compétition de
l’édition et un `name`. Elle peut ajouter un `shortName` pour les commandes
compactes et un `logo` référant un média déclaré dans `assets`. Le lecteur
contrôle les identifiants, les références, les formats et les empreintes.
Les packs précédents utilisent les noms fictifs pour leurs compétitions.

Le nom et le logo suivent la sélection de création et le pack lié à la
carrière. Les calendriers, les résultats et les identifiants de compétition
restent indépendants de ces éléments visuels. Les logos du pack privé
Rugby Réel sont fournis avec le pack local.

## Identités de presse

Le jeu de base présente des journalistes et des rédactions propres au jeu. Un
pack peut leur donner d’autres noms avec la rubrique facultative `press`. Elle
est acceptée par les schémas `cd-identity-pack-v1` à `v4`, dans toutes les
éditions : la presse existe dans chaque carrière, alors que les schémas v3 et
v4 sont réservés à l’édition Monde + Champ. Un pack sans rubrique `press` garde
exactement son contenu, son empreinte, son identifiant et son affichage. Un
jeu antérieur refuse un pack qui porte la rubrique (« champ non autorisé »).

```json
"press": {
  "journalists": [{ "id": "presse-0", "name": "Journaliste Test" }],
  "outlets": [{ "id": "redaction-0", "name": "Rédaction Test" }]
}
```

Les identifiants viennent de la banque de presse (`dist/press-question-bank.js`) :
`presse-0` à `presse-9` et `fiction-0` à `fiction-19` pour les journalistes,
`redaction-0` à `redaction-9` pour les rédactions (champ `outletId` de chaque
journaliste). Les dix journalistes `presse-*` écrivent pour `redaction-0` à
`redaction-3`. Un journaliste garde sa rédaction : le pack renomme la
rédaction, pas l’affectation.

Les deux listes sont facultatives, mais la rubrique doit contenir au moins une
entrée. Chaque entrée contient exactement `id` et `name`. Sont refusés : un
identifiant inconnu ou dupliqué, une clé supplémentaire (`source` comprise), un
nom vide, entouré d’espaces ou de plus de 80 caractères, un caractère de
contrôle, `< > [ ] { } \`, une adresse (`https://…`, `www.…`). Le nom reste du
texte : aucun HTML, balisage ou lien n’est interprété. Le manifeste installé
porte `meta.pressIdentityVersion: 1` et la rubrique normalisée ; il est
revalidé à chaque lecture et un pack altéré devient indisponible. L’aperçu
d’import compte les journalistes et les rédactions renommés.

La sauvegarde ne reçoit jamais ces noms. Comme pour les joueurs, les staffs et
les clubs, le pack de la carrière les applique à l’affichage du jeu natif :
questions de conférence, relations, historique et tout texte du modèle qui
cite un journaliste ou une rédaction renommés. Retirer le pack ou
revenir à la présentation de base rétablit les noms du jeu ; le reprendre les
rétablit à nouveau. Une conférence tenue sous le pack archive la signature de
base.

Les archives de conférence gardent la signature écrite le jour de l’échange
(identifiant, nom, rédaction). L’écran présente l’identité actuelle du même
identifiant : la base, ou le pack actif. Une ancienne carrière qui portait les
anciens identifiants est migrée au chargement (table d’empreintes
`legacyJournalistIds`) ; sa signature d’époque reste dans la sauvegarde, sans
réécriture, mais n’est plus affichée. Les déclarations du manager restent
citées mot pour mot. L’import d’un export ancien contrôle désormais son
empreinte avant cette migration, puis enregistre l’empreinte de l’état vérifié.

`tests/press-identity-pack.cjs` couvre le schéma, les refus, le pack sans
rubrique, la bascule pack → base → pack, la reprise, l’altération du pack
installé et l’import d’une ancienne sauvegarde. Le pack Rugby Réel privé fournit
sa rubrique dans son dépôt de données (`pack/journalistes.json`).

## Identités des directions de club (présidents, directeurs sportifs)

Chaque club géré d'une carrière mondiale a une direction (président,
directeur sportif, entraîneur ; voir `docs/effectifs-export-20261112.md`,
section 5). Le jeu de base donne au président et au directeur sportif un nom
inventé, tiré du générateur de noms du staff (`staff-completion.cjs`, culture
de nom selon le pays du club). Un pack peut leur donner leur vrai nom avec la
rubrique facultative `boards`, acceptée dans un `pack.json` de schéma v1 à v4.
Un pack sans rubrique garde exactement son contenu, son empreinte et son
affichage ; un jeu antérieur refuse un pack qui la porte.

```json
"boards": [
  { "id": "pres-0", "name": "Prénom Nom" },
  { "id": "ds-0", "name": "Prénom Nom" }
]
```

- Identifiants : `pres-<club>` (président) et `ds-<club>` (directeur sportif),
  où `<club>` est l'identifiant numérique du club dans l'édition du pack
  (`clubs[].id` du registre, le même que pour la rubrique `clubs`). Un club
  inconnu de l'édition est refusé.
- Chaque entrée contient exactement `id` et `name` ; liste non vide, au plus
  deux entrées par club. Mêmes refus que la presse : identifiant inconnu ou
  dupliqué, clé supplémentaire (`source`, `traits`…), nom vide, entouré
  d'espaces ou de plus de 80 caractères, caractère de contrôle,
  `< > [ ] { } \`, adresse (`https://…`, `www.…`).
- Le manifeste installé porte `meta.boardIdentityVersion: 1` et la rubrique
  normalisée, revalidée à chaque lecture.
- La sauvegarde ne reçoit jamais ces noms : le pack actif remplace, à
  l'affichage, le nom inventé de base (nouvelles, profil de direction).
- Seuls les dirigeants de départ sont concernés : un successeur arrivé en cours
  de carrière (`pres-<club>-s<saison>`, `ds-<club>-s<saison>`) garde un nom
  inventé.
- **Entraîneurs** : ce sont les entraîneurs principaux du staff de la carrière.
  Leur vrai nom passe par la rubrique `staff` existante, par l'identifiant du
  registre de staff (`staff:<club>:<empreinte>`). L'entraîneur retenu est le
  membre actif dont le rôle désigne l'entraîneur principal (« Head Coach »,
  « Entraîneur principal », « Manager », « Director of Rugby »…), sinon le
  meilleur entraîneur du club. Le collecteur signale les clubs dont
  l'entraîneur principal manque dans le registre de staff ou y est marqué
  historique : ils doivent être ajoutés au registre de staff (pas à `boards`).
- Les traits (ambition, patience, prudence ; compétence, goût formation,
  préférence nationale, réseau) restent ceux du jeu. Une version 2 de la
  rubrique pourra les préciser par une clé `traits` ; elle est refusée tant
  qu'elle n'est pas définie.

Pour le dépôt privé `rugby-reel-donnees`, fichier proposé
`pack/directions.json` : `[{ "id": "pres-0", "name": "…" }, …]`, avec, hors du
pack, la source et la date de chaque nom dans un fichier de provenance (le
pack lui-même n'accepte que `id` et `name`). `tests/board-identity-pack.cjs`
couvre le schéma, les refus, le nom de base et le remplacement.
