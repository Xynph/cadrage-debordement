# Concurrence : besoins publics, offres et moyens observables

Complément de [la première enchère reçue](night-management-20261111.md#concurrence-effectivement-observée).
Collecte Node uniquement, trois carrières Fiction publiques, neuf joueurs et
**dix-huit transferts confirmés puis relus après redémarrage du worker**.
Aucun moteur, donnée, économie, calendrier ou profil n’a été édité. Aucun Godot,
import, service extérieur ou dépense. Les profils temporaires sont supprimés ;
aucun profil complet ni export de carrière n’est publié.

## Protocole borné et provenance

Les checkpoints utilisent l’horloge fixe `1794434400000`. Les trois joueurs de
chaque checkpoint sont choisis dans les seuls devis disponibles : un deuxième
ligne, un ailier et un demi de mêlée, avec priorité à l’indemnité puis au salaire
les plus faibles. Aucun niveau, potentiel, attribut ou condition adverse caché
ne sélectionne ces joueurs. Ce n’est pas une comparaison de leur qualité.

| Seed / club humain | Profil complet SHA-256 | RNG initial |
| --- | --- | ---: |
| 427 / 13 | `45d6d09ed1a591c95e8c1446e346e8296347073e9a7dedb0c5a5700822692684` | 3668155195 |
| 731 / 6 | `e0d03f8dbd350419c33f94ac05a2b3312877cbe09ab7d3d54736a56ff8dc7e43` | 3369175147 |
| 1299 / 0 | `181286c062660db2b42b6d1b2dbc5c219bedb2c6221db9511ff7dd448148377c` | 2810554531 |

Le premier profil est exactement celui de l’ancienne preuve du talonneur. Ces
neuf nouveaux dossiers portent sur trois autres familles. Les différents seeds
et clubs humains ne constituent pas le même monde ni un test causal entre clubs.
À l’intérieur d’un dossier, chaque alternative reprend cependant les mêmes octets
sauvegardés, le même RNG et la même horloge.

Pour chaque joueur, le runner répète le devis, vérifie son identité et sa pureté,
puis présente une offre humaine supérieure à la trésorerie humaine publiée. Il
compare ensuite deux copies du profil : offre au prix demandé et surenchère
au-dessus de l’offre gagnante publique. La confirmation transmet le gagnant,
l’indemnité et le salaire exacts à revalider. Le propriétaire unique et le contrat
sont contrôlés dans les projections publiques (`squad` et candidats interclubs),
les débits/crédits dans les trésoreries publiques. Le profil et le hash de l’état
sportif sont vérifiés après redémarrage, sans publier cet état.

Un premier essai s’est arrêté avant toute confirmation : le verrou de processus
`profil.lock` avait été copié. Le runner exclut désormais ce seul verrou vivant,
conserve les données persistantes et vérifie leur hash. La protection de profil
n’a pas été contournée ni désactivée.

La tentative suivante a reçu les seeds 427 et 731, puis atteint son budget interne
de 120 secondes au début de 1299 : **509 contrôles observés, arrêt sur la garde
de durée à 121,579 s**, sans échec métier antérieur. Ses six dossiers et douze
transferts complets sont réutilisés. La reprise du seul 1299 reçoit **206 contrôles,
zéro échec, 54,240 s**, avec trois dossiers et six transferts. Le profil 1299
reconstruit correspond exactement au hash/RNG de son début dans la première
exécution. Aucun délai de SDK ou de VM n’a été relevé. Il s’agit d’un reçu
composite ciblé, pas d’une campagne globale unique verte.

Source moteur de la tentative : `8c2f8d157d48c95ba6b675fc462615b0dcb6655e`.
Le runner de cette tentative est conservé dans `8d709cda` ; son hash correspond
au reçu. La reprise utilise le runner `ef11379192ec7c29775c85b61f4ef20f8d2f8985`
et le même moteur, avec sélection explicite d’un seed
par invocation. Les SHA-256 de tous les fichiers de production examinés sont
identiques entre les deux reçus.

## Résultats réellement confirmés

Les montants de la colonne centrale sont les conditions effectivement obtenues
par le rival, et ceux de droite la confirmation humaine après surenchère. Il
s’agit d’accords de libération anticipée, pas d’une qualification réglementaire
des fenêtres de transferts.

| Seed / humain | Poste | Clubs offrant, humain inclus | Rival au prix demandé : club / indemnité / salaire | Humain après surenchère : indemnité / salaire |
| --- | --- | ---: | --- | --- |
| 427 / 13 | Deuxième ligne | 6 | 0 / 87 000 € / 6 000 € | 88 000 € / 6 100 € |
| 427 / 13 | Ailier | 5 | 0 / 76 000 € / 5 100 € | 77 000 € / 5 200 € |
| 427 / 13 | Demi de mêlée | 8 | 3 / 90 000 € / 6 200 € | 91 000 € / 6 300 € |
| 731 / 6 | Deuxième ligne | 9 | 4 / 96 000 € / 5 900 € | 97 000 € / 6 000 € |
| 731 / 6 | Ailier | 6 | 0 / 87 000 € / 5 500 € | 88 000 € / 5 600 € |
| 731 / 6 | Demi de mêlée | 8 | 4 / 76 000 € / 5 100 € | 77 000 € / 5 200 € |
| 1299 / 0 | Deuxième ligne | 5 | 10 / 79 000 € / 5 200 € | 80 000 € / 5 300 € |
| 1299 / 0 | Ailier | 3 | 8 / 87 000 € / 5 500 € | 88 000 € / 5 600 € |
| 1299 / 0 | Demi de mêlée | 4 | 8 / 76 000 € / 5 100 € | 77 000 € / 5 200 € |

Les salaires sont ceux par période publiés dans cet univers Fiction. Dix clubs
adverses distincts ont soumis **45 offres**, avec des besoins projetés de 1, 2,
3 ou 5. Au prix demandé, un adversaire remporte chacun de ces neuf cas. La
surenchère humaine gagne chacun des neuf dossiers, avec un coût réellement payé
et un contrat réellement conservé. Cela montre une concurrence de prix et une
conséquence concrète de l’arbitrage, sans garantir que cette surenchère soit une
bonne décision sportive ou financière à long terme.

## Ce que les besoins permettent de comparer

Le champ `need` des offres concurrentes est réellement publié. Sur le deuxième
ligne du seed 427, quatre clubs proposent 87 000 € / 6 000 € pour un besoin 2,
alors que le club 7 propose 84 000 € / 5 900 € pour un besoin 1. Le joueur et le
devis vendeur sont les mêmes. Les neuf devis répétés sont identiques et ne
changent ni profil, ni RNG, ni horloge.

La fonction [`publicNeed`](../../native/engine/interclub-market.cjs#L47)
utilise la couverture de la famille et les professionnels sous contrat au-delà
de la saison, sans blessure et en condition suffisante. Les offres observées
sont cohérentes avec ce mécanisme et avec les majorations calculées dans
[`negotiate`](../../native/engine/interclub-market.cjs#L69). Nous ne reconstituons
pas les conditions médicales ou la profondeur réellement apte des adversaires à
partir de valeurs cachées. Les comptes de joueurs et contrats publiés sont
consignés comme tels, sans les transformer en un besoin adverse non communiqué.

## Ce que les moyens permettent de comparer

Les trésoreries des clubs et les salaires sources des candidats sont présents
dans la projection. Les 45 offres adverses observées conservent toutes la réserve
de 400 000 € et huit périodes du nouveau salaire sur cette semaine initiale.
Les trésoreries des enchérisseurs vont de 4,3 à 7,5 M€ ; le plus petit reliquat
observé après indemnité, réserve et provision est encore de 3 765 200 €. Cet
échantillon ne teste donc pas un adversaire proche de la limite de liquidité.

Les neuf contrôles d’offre humaine dépassant sa trésorerie sont déclarés non
recevables, avec le motif financier/places projeté. Les offres adverses restent
exactement les mêmes ; ce contrôle ne fabrique pas un autre besoin ni une autre
réaction adverse. Il ne consomme pas de tirage ni d’écriture.

La trésorerie ne suffit pas à expliquer les participants ou le gagnant. Pour le
demi de mêlée du seed 427, le club 3 à 5,6 M€ remporte l’offre de base devant
le club 0 à 7,5 M€, avec une meilleure offre salariale et un besoin publié plus
élevé. Le classement public vérifié est salaire, indemnité, besoin, puis ID ;
la recevabilité financière est une condition séparée.

**63 absences d’offre** parmi les 108 positions de rival potentiel n’ont aucun
motif individuel dans la projection. Elles restent « motif non publié ». Une
trésorerie élevée, un total salarial ou un compte de contrats ne justifient pas
d’inventer un refus par manque de besoin, dette, plafond salarial ou style.
Le filtre [`affordable`](../../native/engine/interclub-market.cjs#L53) contient
plusieurs conditions ; nous n’attribuons pas une condition cachée à un club absent.

## Style et recrutement autonome : limites précises

Les styles de réaction de coaches ne sont pas projetés à ces trois départs :
aucune valeur disponible dans les 126 lignes club/dossier observées. Même
lorsqu’ils deviennent visibles dans les réactions de match, « Analytique »,
« Prudent » ou « Combattif » décrivent une personnalité de réaction ; ils ne
prouvent pas un système tactique ni une préférence de recrutement.

Dans le seul canal négocié examiné, les propositions sont construites à partir
du besoin, de la recevabilité et des conditions vendeur/joueur ; le style de
réaction ou le plan tactique ne figure pas parmi ses arguments. C’est un constat
sur [`interclub-market.cjs`](../../native/engine/interclub-market.cjs#L57), pas
une affirmation sur tous les comportements du jeu.

La fenêtre autonome est une autre chaîne :
[`aiRosterMarketProposals`](../../dist/ai-roster-cycle.js#L194),
[`aiRosterAuctionWinner`](../../dist/ai-roster-cycle.js#L189), puis
[`aiRosterRecruitmentWeek`](../../dist/ai-roster-cycle.js#L217).
La lecture ciblée montre des filtres de besoin, frais, paie, trésorerie et
éligibilité, puis un arbitrage besoin/provision/ID. **Aucune fenêtre autonome
n’a été exécutée par ce runner** et aucune motivation cachée n’est déduite de
son code. Ce lot ne qualifie donc ni son résultat ni l’intérêt de ses stratégies.

## Scénarios de reprise pour Claude, sans correction concurrente

1. Rejouer les trois lots sur le SHA exact après #552, puis comparer mêmes
   familles, besoins publiés, participation, devis et engagements. Si un joueur
   n’est plus disponible, consigner ce changement plutôt que modifier le monde.
2. Préparer par commandes publiques un checkpoint juste avant une vraie fenêtre
   autonome : semaine 13 en Fiction ou 15 en France30 dans ce code. Copier le
   profil complet pour comparer des décisions humaines distinctes. Relever les
   propriétaires/contrats publiés avant et après la progression publique réelle,
   sans appeler la fonction privée ni éditer l’état.
3. Les nouveaux propriétaires peuvent prouver des signatures ; une variation
   globale de trésorerie contient aussi d’autres opérations et ne prouve pas
   seule l’indemnité ou la motivation. Pour comparer leurs critères, prévoir une
   projection de lecture du reçu autonome avec IDs, poste/besoin retenu, montant
   effectivement payé, salaire et contraintes connues. Ne pas exposer de niveau
   exact non observé ou d’attribut caché pour justifier cette projection.
4. Ne comparer une préférence de style que si une politique tactique explicite
   de club est publiée et reliée à une règle de décision. Sinon, garder ce point
   comme hypothèse de conception, distincte de la personnalité des personnages.

## Reproduction et preuves

Runner : [management-rival-comparison.cjs](../../tools/qa/management-rival-comparison.cjs).
Chaque invocation choisit explicitement **un** des trois checkpoints autorisés
et conserve son budget interne de 120 secondes entre commandes, ainsi que la
limite VM existante. Par exemple avec Node 22.23.4 :

```sh
node tools/qa/management-rival-comparison.cjs --checkpoint-seed=427 --output=work/rival-427.json
node tools/qa/management-rival-comparison.cjs --checkpoint-seed=731 --output=work/rival-731.json
node tools/qa/management-rival-comparison.cjs --checkpoint-seed=1299 --output=work/rival-1299.json
```

[Synthèse des neuf dossiers](evidence/night-rival-comparison-20261112/summary.json),
[reçu initial borné](evidence/night-rival-comparison-20261112/initial-bounded.json),
[reprise 1299](evidence/night-rival-comparison-20261112/checkpoint-1299.json),
[empreintes des reçus](evidence/night-rival-comparison-20261112/SHA256SUMS.json).
Les reçus gardent les devis, contrôles, paramètres confirmés, propriétaires et
flux publics réconciliés, commandes, empreintes et reprises exactes. Les profils
et exports complets restent hors du dépôt et ont été supprimés après exécution.
