# Gestion : mémoire individuelle et comparaisons du 11 novembre 2026

## Périmètre et séparation avec Claude

Base de travail : `6648cd6338e1eb62cc4a8c014b23dd3ec20ba174`. Le commit
produit `3feda0a8d850fc9e535bb7f19467e3b935f9b2fe` concerne seulement
`relationships_view.gd` et sa recette dédiée. Aucun moteur, coefficient,
salaire, budget, calendrier, identité, animation ou ressource 3D n’est modifié.
Les scripts de scénario passent par les commandes publiques du worker sur des
profils temporaires. Aucune fusion Cloud avant le 12 novembre à 09 h, heure de
Paris ; livraison et recette Windows réservées à Claude.

## Ce qui fonctionnait déjà

- `decision_preview.gd` distingue débit immédiat et engagement futur. Pour la
  formation, régler le montant ne débite rien ; chaque séance prélève ensuite
  l’investissement choisi, sans garantie de progression individuelle.
- `decision_feedback.gd` conserve dix reçus de session avec les variations de
  trésorerie, salaires et moral effectivement projetées. Les contre-offres et
  accords à confirmer ne sont pas annoncés comme des signatures.
- Le vestiaire dispose de personnalités, d’entretiens individuels, de promesses
  sur trois rencontres, de duos et d’événements hebdomadaires archivés. Les
  engagements du groupe ont leur propre échéance et leur statut persistant.
- Les rapports de match distinguent les observations des preuves de causalité.
  La projection de la préparation et les intervalles de joueurs observés
  conservent leurs limites de connaissance.
- Le marché entre clubs expose un devis, une négociation concurrente puis une
  confirmation distincte. Son calcul d’offres considère les besoins publics de
  poste et la provision financière ; le devis ne réalise pas de transfert.

Ce constat porte sur les points d’entrée réutilisés, sans nouvel audit général
des travaux de Claude.

## Amélioration réalisée

Dans le détail d’un joueur du vestiaire :

- afficher le trait et le leadership déjà présents dans la projection ;
- nommer le choix réellement fait pendant les trois derniers entretiens, à côté
  de la variation de satisfaction déjà archivée ;
- rapprocher les trois derniers événements de ce même joueur et la décision
  prise, en conservant leur titre d’origine.

L’affichage filtre par identifiant stable, conserve le joueur sélectionné et ne
crée aucune commande métier. Il ne déduit pas une variation chiffrée pour un
événement dont cette variation n’est pas archivée. Une projection ancienne sans
personnalité ou mémoire reste utilisable, sans données inventées. Aucun nouveau
style, police ou palette.

## Méthode des comparaisons

`tools/qa/management-strategy-comparison.cjs` crée une carrière Fiction du club
13 avec une horloge fixe. Il observe réellement trois pistes choisies à partir
des salaires, indemnités et familles de poste publics, en passant les rendez-vous
obligatoires par leurs décisions existantes. Cette préparation commune dure six
semaines dans le pilote 427.

Le checkpoint est le **profil sauvegardé complet**, pas seulement l’export de
carrière. Le JSON exporté ne suffit pas à rétablir le RNG du worker. Le dossier
complet est copié pour chaque alternative ; empreintes SHA-256 du profil et de
l’état, RNG de départ et identité du checkpoint sont vérifiés avant tout choix.
Le scénario n’édite aucun état ni coefficient. Les lectures répétées préservent
les octets du profil et l’état.

Les alternatives sont : conserver les moyens ; signer la piste au salaire élevé ;
signer la meilleure des trois pistes selon le minimum de l’intervalle observé ;
recruter deux autres familles de poste ; investir 12 000 € à chaque séance de
formation. Les coûts totaux diffèrent et sont consignés : il ne s’agit pas de
dépenses égalisées. Les recrutements de cette comparaison utilisent l’accord
direct existant ; la concurrence d’enchères est reçue séparément ci-dessous.

Entraînement normal, composition automatique et délégation du match sont communs
aux branches. Si la feuille n’est pas complète, le runner de reprise peut
confirmer uniquement le devis de renfort déjà projeté, avec ses places exactes
et son coût. Sans place suffisante, la stratégie reste bloquée. Il ne crée pas
de qualification ou de joueur par édition du fichier. Le rapport conserve
toutes les commandes réellement envoyées et
les résultats, trésorerie, masse salariale, niveau moyen, condition, fatigue,
blessures, moral et confiance. Le même RNG **initial** ne signifie pas que des
trajectoires différentes consommeront ensuite les mêmes tirages : aucun résultat
isolé n’est présenté comme la preuve causale de la qualité du recrutement.
La fatigue moyenne porte sur tout l’effectif : recruter change son dénominateur,
et une moyenne plus faible ne prouve pas que les joueurs déjà présents ont moins
travaillé. La trésorerie finale comprend aussi les recettes des rencontres ; le
coût certain de la décision et le solde final doivent donc rester distincts.

Le pilote 427 sur deux matchs était une validation du protocole, pas la campagne
finale. Les quatre premières politiques y ont toutes gagné leurs deux matchs.
La formation a réellement débité 24 000 € et le niveau moyen de l’académie est
passé de 59,25 à 60,167 ; ces moyennes ne garantissent rien pour un joueur donné.

## Comparaison finale reçue

**Trois checkpoints, quatorze alternatives réalisées jusqu’à huit matchs,
112 matchs de comparaison, 18 matchs de préparation commune et une alternative
impossible.** La tentative initiale complète reste marquée en échec : elle a
terminé le seed 427, puis rencontré la feuille incomplète du seed 731. Les
40 matchs du seed 427 sont réutilisés tels quels. Le seed 1299 a été exécuté
indépendamment. La reprise 731 utilise le devis de renfort et ne masque pas la
limite de capacité qui suit.

Au seed 731, la semaine 5 n’avait qu’un seul pilier droit apte pour deux places.
Le coup d’envoi a été refusé. Le devis propose un renfort à 2 500 € par période,
avec deux places professionnelles disponibles. Sa confirmation, par la commande
publique et sur les places exactes, rétablit une feuille qualifiée. Le checkpoint
commun suivant compte 41 professionnels : **deux recrutements deviennent
impossibles avec une seule place**. La branche correspondante ne signe personne
et reste explicitement bloquée. Aucun plafond d’effectif ni aptitude n’a été
modifié pour terminer le test.

| Seed | Profil complet SHA-256 | RNG initial |
| --- | --- | ---: |
| 427 | `db1127e6a4ae01bbd65596426966474f5bba682b5f549d144d6ee590d15f90c6` | 2599053760 |
| 731 | `0eb7dfac0b8d15596c46abce11bbaab9b55122c56e064e08a51448606a0df610` | 2434446489 |
| 1299 | `5978fa0bd9943f8baab844a053b14ffcdd600d4b76f0dea9b09597076694ae98` | 1870054293 |

Chaque alternative d’un seed vérifie ces mêmes octets de profil, le même hash
d’état et le même RNG avant décision. Les résultats suivants sont des variations
depuis ce checkpoint ; les montants sont ceux effectivement calculés par le jeu.

| Seed | Stratégie | V–N–D | Points | Trésorerie nette | Niveau moyen académie | Fatigue moyenne | Confiance |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: |
| 427 | Conserver les moyens | 4–1–3 | +19 | +2 359 640 € | +0,950 | +3,725 | +12 |
| 427 | Renfort au salaire élevé | 4–1–3 | +19 | +2 092 840 € | +0,950 | +3,257 | +12 |
| 427 | Meilleur intervalle observé | 4–0–4 | +17 | +2 430 240 € | +0,950 | +4,477 | +10 |
| 427 | Deux familles de poste | 4–0–4 | +19 | +2 430 840 € | +0,950 | +4,883 | +10 |
| 427 | Formation | 4–1–3 | +19 | +2 263 640 € | +1,983 | +3,725 | +12 |
| 731 | Conserver les moyens | 1–1–6 | +8 | +2 220 928 € | +0,983 | +1,634 | −3 |
| 731 | Renfort au salaire élevé | 2–0–6 | +10 | +1 476 128 € | +0,983 | +2,536 | 0 |
| 731 | Meilleur intervalle observé | 0–1–7 | +3 | +1 968 528 € | +0,983 | +2,298 | −8 |
| 731 | Deux familles de poste | Bloquée | — | Aucune signature | — | — | — |
| 731 | Formation | 1–1–6 | +8 | +2 124 928 € | +2,033 | +1,634 | −3 |
| 1299 | Conserver les moyens | 1–1–6 | +7 | +2 249 616 € | +1,000 | +3,700 | −3 |
| 1299 | Renfort au salaire élevé | 1–1–6 | +9 | +1 739 816 € | +1,000 | +4,404 | −3 |
| 1299 | Meilleur intervalle observé | 1–1–6 | +8 | +2 265 216 € | +1,000 | +3,794 | −3 |
| 1299 | Deux familles de poste | 0–1–7 | +5 | +1 939 816 € | +1,000 | +2,383 | −8 |
| 1299 | Formation | 1–1–6 | +7 | +2 153 616 € | +2,100 | +3,700 | −3 |

Sur ces trois paires, l’investissement de formation prélève exactement
**96 000 €** sur huit séances, sans nouveau salaire professionnel. Il produit
respectivement +1,033 / +1,050 / +1,100 point de niveau moyen d’académie
supplémentaire face à la référence. Les huit scores et le RNG final sont
identiques à la référence dans chacune de ces trois paires. Cela rend le coût
et l’effet de formation lisibles dans ces cas, sans prouver sa valeur après
promotion ou sur plusieurs saisons.

Le renfort cher coûte 170 000 / 500 000 / 340 000 € d’indemnité selon le seed,
puis 12 100 € par période. La meilleure piste selon son intervalle observé coûte
70 000 € puis 4 800 € ; les deux autres familles coûtent 140 000 € puis 9 600 €
dans les deux cas réalisables. Ces engagements sont distincts des recettes
aléatoires qui expliquent aussi les soldes finaux. Le coût, la capacité et les
objectifs de temps constituent déjà des arbitrages, mais cet échantillon ne
permet pas de déclarer une stratégie globalement gagnante.

[Synthèse vérifiable](evidence/night-management-20261111/management-strategy-summary.json)
avec empreintes, coûts, métriques de moral/condition/blessure, et liens vers les
trois reçus bruts : [tentative initiale et seed 427](evidence/night-management-20261111/management-strategy-initial-attempt.json),
[reprise 731](evidence/night-management-20261111/management-strategy-731.json),
[campagne indépendante 1299](evidence/night-management-20261111/management-strategy-1299.json).
Les reçus gardent les commandes et leurs paramètres réellement envoyés. Le
runner original est celui du commit `1840c1a06258462cd882a95c6345c90b13515b8c`,
le runner avec renforts et refus par alternative celui du commit
`90b9f35a5f05a7fa06da1fcbd374a7ded7dd65e3` ; leurs SHA-256 exacts figurent dans
les rapports. Il s’agit de reçus composites ciblés, sans campagne globale verte.

## Concurrence effectivement observée

Runner : `tools/qa/management-rival-observation.cjs`, Node `v22.23.4`, moteur au
commit `3feda0a8d850fc9e535bb7f19467e3b935f9b2fe`, sans modification de
`native/engine` ou `dist` par rapport à la base.

Checkpoint complet :
`45d6d09ed1a591c95e8c1446e346e8296347073e9a7dedb0c5a5700822692684`.
RNG initial : `3668155195`.

Un talonneur sous contrat est approché sur les seules conditions publiques, sans
lecture de son niveau caché. Les deux branches partent du même profil :

| Décision | Gagnant réellement confirmé | Indemnité | Nouveau salaire par période |
| --- | --- | ---: | ---: |
| Offre humaine au devis 280 000 € / 10 100 € | Club 8 | 303 000 € | 10 700 € |
| Surenchère sur l’offre publique adverse | Club humain 13 | 304 000 € | 10 800 € |

Quatre clubs ont une offre recevable dans ce cas. Chaque gagnant a été revalidé
par la commande de clôture avant transfert. Les deux essais vérifient propriétaire
unique, départ du vendeur, débit/crédit réconcilié, nouveau salaire et reprise
exacte du transfert après redémarrage réel du worker. Les consultations du devis
laissent le profil, le RNG et le disque inchangés.

Cette preuve ne qualifie qu’un joueur et un checkpoint. Elle montre une
concurrence réelle et un coût de surenchère. Le style tactique n’intervient pas
dans ce canal de négociation ; il reste à comparer aux choix de recrutement des
fenêtres autonomes, sans modifier leur moteur réservé à Claude.

## Constats et propositions pour la reprise

Dans le pilote 427, la piste au salaire le plus élevé est observée à 70–78 pour
12 100 € par période et 170 000 € d’indemnité ; un demi d’ouverture à 4 800 € et
70 000 € est observé à 77–81. Le salaire est donc une piste de recherche, pas une
preuve de vedette. L’alternative fondée sur le niveau connu sert à vérifier ce
compromis. Les intervalles restent des intervalles ; aucun niveau exact adverse
n’est utilisé pour décider.

Propositions pour Claude après intégration de son économie : rejouer les mêmes
scripts sur son SHA exact ; vérifier si les écarts de coût changent ; prolonger
la mesure jusqu’au renouvellement de contrats et à la sortie de formation avant
de conclure sur plusieurs saisons. Pour les styles de clubs, comparer les achats
des fenêtres autonomes au besoin public, à la provision de trésorerie et au style
déjà déclaré, puis distinguer absence de besoin, refus financier et absence de
critère stylistique. Aucun correctif économique concurrent n’est proposé ici.

## Reçu visuel du composant sur le candidat commun

- `tests/godot-relationships-memory.cjs` crée une vraie projection worker à
  partir de deux entretiens différents et d’un événement confirmé, puis rend le
  composant de vestiaire aux formats 1280×720, 1920×1080 et 2560×1440. Le host de
  rendu est isolé ; ce contrôle n’est pas annoncé comme un parcours complet du
  client. Audio Dummy, aucune TTS. Le rapport et le PNG 1440p proviennent de
  Godot, jamais d’un faux aperçu.
- Reçu par l’intégrateur avec le composant produit
  `3feda0a8d850fc9e535bb7f19467e3b935f9b2fe` : **23 contrôles, zéro échec**,
  sur le candidat commun `3773aa1b3f80728e38623117fec3b425c10d35a0`, le
  11 novembre à 23 h 15 min 50 s, heure de Paris,
  Godot 4.7.2, Node 22.23.4, audio Dummy, Xvfb `:91`. Le wrapper vérifie profil et
  export inchangés. Le composant est rendu depuis la vraie projection de ses
  décisions worker, dans un host isolé, sans Gabi chargé ; ce n’est pas le shell
  entier. Avertissements non bloquants : `libspeechd` absent et VSync indisponible.
  Aucune erreur de script. [Rapport](evidence/night-management-20261111/relationships-memory-report.json),
  [journal](evidence/night-management-20261111/relationships-memory-run.log),
  [capture réelle 2560×1440](evidence/night-management-20261111/relationships-memory-2560.png),
  [empreintes et limites](evidence/night-management-20261111/relationships-memory-manifest.json).
- Campagne comparative finale : trois seeds reçus, quatorze alternatives sur
  huit matchs et une alternative bloquée par la capacité réelle. Le résultat de
  la première tentative arrêtée est conservé. Le pilote de deux matchs n’est
  pas substitué à cette réception.
- Aucune recette Windows et aucune CI globale ne sont revendiquées dans ce lot.

Le [manifeste SHA-256 des preuves](evidence/night-management-20261111/SHA256SUMS.json)
permet de vérifier les fichiers conservés. Les profils complets et la grosse
projection de fixture restent temporaires et ne sont pas ajoutés au dépôt.
