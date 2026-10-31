# Extraction groupée ItsRugby — DATA-06

## Résultat réel du 31 octobre 2026

Base : `main 916096b90a289d4fae171bff29b6f4b5b8636566`, rôle PRODUCTEUR.
L'utilisateur confirme l'autorisation d'extraction automatisée et d'intégration
dans son jeu. Cette déclaration est enregistrée ; aucun document de licence
fourni par le site n'est présenté comme archivé dans le dépôt.

Le workflow de #153 a **réellement été exécuté**, mais sa collecte a échoué :
[run 41242212197](https://github.com/Xynph/cadrage-debordement/actions/runs/41242212197).
L'artefact `13057917152` (385 octets) a été téléchargé et ouvert : manifeste
horodaté `2026-10-31T21:09:10.131Z`, **0/3 captures**, HTTP 403 sur Clermont,
Toulouse et Brive. Aucun HTML d'effectif dans cette archive. Le SHA256 de
l'archive est conservé dans le fichier de capture. Les tests de #153 étaient
verts : cela ne prouvait donc pas une extraction réseau réussie.

La voie publique **navigateur Work** a fonctionné. Sur chaque page : saison
2026-27, rubrique « Effectif », expansion « Voir tout l'effectif », puis lecture
groupée des lignes DOM `#effectif-list .fd-eff-row`. Aucun parcours individuel
des joueurs, service payant, changement d'identité de client ou contournement
de contrôle. Les 30 liens ont été découverts dans les classements publiés,
puis explicitement associés aux codes LNR par `CLUB_MAP`, sans correspondance
fondée sur l'ordre des tableaux. Le lien de Toulouse est `stade-toulousain`,
et non `toulouse`.

| Mesure | Résultat |
| --- | ---: |
| Pages clubs collectées | 30 |
| Lignes publiées | 1 539 |
| Identifiants ItsRugby distincts | 1 506 |
| Lignes avec taille ou poids | 1 431 |
| Identités retenues par rapprochement strict | 1 174 |
| Identités retenues avec au moins un champ de profil | 1 171 |
| Lignes mises en examen | 365 |
| Écarts de taille/poids avec la base précédente | 153 champs |
| Profils LNR déjà présents et préservés | 240 |
| Profils supplémentaires partiellement enrichis | 974 |
| Couverture cumulée préparée | 1 214 / 1 592 |
| Identifiants restant sans enrichissement | 378 |

« Enrichi » signifie au moins un poste, âge publié ou une mensuration sourcée,
**pas une biographie complète**. Les cartes d'effectif ne donnent ni nationalité
ni date de naissance exacte : ces champs restent `null` dans ce lot. Aucun âge
n'est converti en date de naissance. Trois identités retenues n'ont aucun de
ces champs et ne font donc pas augmenter le compteur de profils enrichis.

## Fichiers et traçabilité

- `modding/data06/itsrugby-browser-capture-2026-10-31.json` : observations de
  chaque club, URL et date de collecte, nom publié, poste, âge, mensurations
  publiées avec unités, valeurs normalisées et ID ItsRugby extrait du lien.
  Aucun portrait ou logo. Clermont a une date au jour ; les autres pages ont
  l'heure exacte observée. Ne pas inventer une précision horaire pour Clermont.
- `modding/data06/itsrugby-browser-reconciliation-2026-10-31.json` : observations
  acceptées avec IDs LNR, file d'examen, conflits champ par champ, IDs restants,
  SHA256 du contenu de capture et SHA256 des quinze fichiers sources antérieurs.
- L'export intermédiaire de trois lots a été comparé aux lectures navigateur
  par empreintes FNV1a sur les chaînes UTF-16 : `c6e77586`, `ed5ca87b`,
  `4d26128f`. Ce contrôle détecte les erreurs de transfert ; **ce n'est pas une
  signature d'authenticité du site**. Les SHA256 des exports sont aussi conservés.

Les 1 539 lignes sont des **observations publiées**, pas 1 539 joueurs distincts
appartenant tous aux effectifs LNR. Le rapport refuse les cartes d'un même
ID ItsRugby dans plusieurs clubs. Il ne modifie aucun effectif du jeu.

## Rapprochement et conservation des profils

Le traitement hors réseau réutilise `tools/data06-itsrugby-bulk.cjs` :

```sh
node tools/data06-itsrugby-bulk.cjs --reconcile-browser modding/data06/itsrugby-browser-capture-2026-10-31.json --output modding/data06/itsrugby-browser-reconciliation-2026-10-31.json
```

Seuls un nom complet normalisé exact et un club explicitement associé peuvent
retenir une identité, avec unicité du nom LNR, de l'ID source et du nom dans le
club. Normalisation : accents, casse, ponctuation et entités HTML ; pas de
distance approximative, nom tronqué, permutation de tokens ou alias inventé.
Ainsi, Thibault/Thibaud LANEN demeure à examiner.

Les 365 lignes en examen comprennent 300 noms sans égalité exacte, 64 lignes
d'IDs source présents plusieurs fois et une divergence de club. Ce sont des
lignes source et non un nombre de personnes manquantes ; les 378 IDs LNR
restants sont listés séparément. Les homonymes et doubles cibles éventuels
sont également refusés par le programme et couverts par les tests.

Les fichiers des 240 profils DATA-05 restent inchangés octet pour octet.
Les nouvelles valeurs de taille ou poids contradictoires sont conservées dans
`conflicts` ; le champ correspondant de l'observation acceptée est mis à
`null` et ne remplace pas la valeur existante. Les autres champs existants
doivent également rester prioritaires lors de la réception du supplément.
Les valeurs originales ItsRugby restent récupérables dans la capture.

## Période et intégration réservée

La saison affichée est 2026-27 et la collecte date d'octobre. **L'appartenance
au 1er juillet 2026 n'est pas établie**. `historicalJuly2026=false` et
`validAtCareerStart=null` sont conservés. Ne pas utiliser ce lot pour réécrire
les clubs au départ d'une carrière, les contrats, les mutations ou les notes.

La PR livre un supplément de données et son audit hors ligne. Elle ne change
ni `dist/**`, ni une sauvegarde, ni le catalogue réservé à #148/#149, ni le lot
#150. Elle ne prétend pas avoir déjà rendu ces joueurs jouables dans `main`.
L'intégrateur unique pourra réceptionner les observations retenues dans le
catalogue réel optionnel en gardant la provenance, les données précédentes
et la distinction entre observation d'octobre et situation au départ de carrière.
**Aucune fusion autorisée au producteur.**

## Collecteur HTTP et vérifications

```sh
node tools/data06-itsrugby-bulk.cjs --clubs clermont,stade-toulousain,brive
node --test tests/data06-itsrugby-bulk.test.cjs tests/data06-itsrugby-browser.cjs
node tools/data05-audit.cjs
```

La voie HTTP reste disponible, mais son accès réseau n'est **pas réparé** par
la réussite du navigateur. Elle s'arrête désormais au premier HTTP 401/403/429,
sans nouvelle requête pour les clubs suivants, en enregistrant leur absence
de tentative. Les mots « effectif » et « joueurs » seuls ne suffisent plus :
des lignes d'effectif rendues sont nécessaires. Une coquille JavaScript vide
n'est pas annoncée comme une capture de joueurs.

Les tests vérifient les refus, les faux positifs, les unités incomplètes
(107 kg ne devient pas 107 cm), le rapprochement, les collisions, la
reproductibilité intégrale et les empreintes des sources antérieures.
L'audit DATA-05 reste à 240 imports et zéro appel Firecrawl.
La CI de la tête exacte de PR et la revue de l'intégrateur restent requises.
