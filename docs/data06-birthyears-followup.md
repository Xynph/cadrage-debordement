# DATA-06 — complément de 122 années, 1er novembre 2026

Producteur sur la PR #160, depuis `cf10270f46c74b1c5e37cce7950f0cb9485e8c86`.
La CI Tests JavaScript de cette tête précédente est réussie
([41288332930](https://github.com/Xynph/cadrage-debordement/actions/runs/41288332930)).
Le nouveau lot demande sa propre CI. Aucune fusion ni activation du mod jouable.

## Résultat mesuré

Le fichier `modding/data06/birthyears-followup-2026-11-01.json` ajoute
**122 identifiants LNR précédemment sans année rattachée**, au-delà des 1 245
du lot précédent. Couverture cumulée : **1 367 / 1 592**, encore **225** années
inconnues ou non rapprochées. Les quatre fichiers du bilan précédent restent
inchangés. Ce compteur mesure des années rattachées et sourcées, pas des
biographies complètes ni des données automatiquement intégrées au jeu.

Les apports concernent 29 clubs : **67 joueurs TOP 14**, **55 joueurs PRO D2**.

| Club prioritaire | Nouvelles années | Couverture cumulée | Restantes |
| --- | ---: | ---: | ---: |
| Dax | 3 | 34 / 36 | 2 |
| Nevers | 8 | 56 / 61 | 5 |
| Soyaux-Angoulême | 5 | 46 / 51 | 5 |
| Valence Romans | 3 | 38 / 40 | 2 |
| Narbonne | 3 | 45 / 48 | 3 |
| Nice | 1 | 49 / 51 | 2 |

Les six clubs reçoivent **23** années, les autres **99**. Il reste **19**
lacunes dans ces six clubs et **206** dans les autres.

## Collecte et preuves

L'accès HTTP à Rugby Data a été revalidé par une fiche pilote réelle, puis
**175 fiches candidates distinctes** ont été ouvertes. Un second essai borné a
réussi pour 8 des 9 échecs initiaux ; Latu Latu reste indisponible (HTTP 503).
Les noms rapprochés par patronyme ou mots communs dans les effectifs servent
uniquement à proposer des fiches à lire. L'acceptation dépend du nom complet
effectivement publié dans la fiche individuelle et de l'unicité dans les
1 592 identités LNR.

| Résultat des 175 fiches Rugby Data | Nombre |
| --- | ---: |
| Nouvelle année avec identité établie | 114 |
| Nom complet insuffisant ou incompatible | 58 |
| HTTP 503 persistant | 1 |
| Contradiction avec l'âge officiel publié | 1 |
| Conflit officiel antérieur encore non résolu | 1 |

Les **114** preuves Rugby Data sont complétées par **8** autres années : deux
effectifs U20 Wikipédia avec club français explicite, la fédération espagnole
pour Samuel Derek Wasley, des biographies sportives pour Matthew Beukeboom,
Erik Meroi et Inoke Kurukuruvakatini, la fiche ItsRugby de Pone Faamausili et le
profil public indexé d'Efitusi Tupola Ma'afu. La fédération italienne confirme
également la date d'Erik Meroi ; les deux lignes PDF ont été inspectées
visuellement.

Les 155 fiches candidates ItsRugby ont été exploitées, en réutilisant les
captures déjà présentes lorsqu'elles existaient. **59** des années Rugby Data
retenues sont corroborées par une fiche ItsRugby dont le nom affiché est
exactement identique après normalisation. Leurs années concordent toutes.
Les 13 pages nationales U20 ont été consultées ; seuls deux nouveaux noms
avec un club français explicitement rapproché sont retenus ici.

Chaque observation conserve URL, date de collecte, texte factuel du nom et de
la date, identifiant source et SHA256 du HTML ou PDF quand le fichier source
a été obtenu. Les révisions Wikipédia et pages PDF sont indiquées. Le profil
Sofascore d'Efitusi est identifié comme une récupération par l'index web :
la page HTTP directe présentait un écran technique et n'est pas prétendue
extraite. Aucune empreinte d'un écran technique n'est présentée comme celle
d'une fiche factuelle.

## Identités et dates

Le nom LNR doit être soit le nom publié normalisé, soit la même suite de
lettres avec une variation d'espacement ou d'apostrophe, soit une suite
ordonnée de composants explicitement présents dans le nom complet publié.
Dans ce dernier cas, les prénoms ou patronymes supplémentaires sont conservés
dans la preuve et tous les composants LNR doivent apparaître. Le contrôle
parcourt l'ensemble des 1 592 identités et exige un seul résultat.

Exemples : `Charles Matthews` est explicitement contenu dans
`Charles Walter Watson Matthews`, et `Samuel Simmonds` dans
`Samuel David Simmonds`. Aucune lettre manquante n'est corrigée pour satisfaire
le rapprochement : `Jason-colin` et `Jason-Collin` restent distincts dans ce lot.

Les records exposent uniquement `birthYear` ; `birthDate` et
`validAtCareerStart` restent `null`. Les deux dates source au 1er janvier sont
signalées : elles ne constituent pas une preuve de jour et mois exacts. Les
années proviennent toujours d'une date explicitement publiée, jamais d'un âge.

Les contrôles supplémentaires isolent notamment :

- **Lylian Zelioli, `lnr:13497`** : l'année Rugby Data est incompatible avec
  l'âge officiel LNR ; aucun choix d'année n'est fait.
- **Dylan Idrissi, `lnr:11779`** : des sources secondaires concordent, mais les
  deux années différentes du site officiel VRDR restent un conflit non résolu.
- **Giorgi Zazadze, `lnr:13834`** : la fiche proposée de Rati Zazadze appartient
  à une autre identité. Une liste U20 publie le nom exact de Giorgi, mais son
  club indiqué n'est pas Nevers : la liaison de club reste à établir.
- Les propositions pour **Sandro Dubois Martin / Karl Martin**,
  **Gaétan Ngassa Manac'h / Jean Cotarmanac'h**, **Harrison Asi / Braxton Asi**
  et **Jules Martin Bonnard / Roméo Bonnard Martin** sont également rejetées.

## Vérification et réception

Commandes réellement exécutées :

```sh
node --test tests/data06-birthyears-six-clubs.cjs tests/data06-birthyears-followup.cjs
```

**20/20 tests ciblés réussis**, dont 10 nouveaux : correspondance ID/club/URL,
nouveauté par rapport aux quatre fichiers précédents, absence de doublons,
unicité des noms complets et composants, années concordantes, dates valides,
traçabilité, âge officiel, exclusions et comptage des 175 tentatives.
La suite complète du jeu n'est pas exécutée localement dans cette copie
partielle. La CI complète doit être contrôlée sur la nouvelle tête publiée.

Les fichiers moteur, interface, V4, sauvegardes, normaliseurs et preuves
antérieures restent inchangés. Aucun service payant ou appel Firecrawl.
La collecte est terminée pour ce lot, sans traitement en arrière-plan.

Priorité suivante : les 19 lacunes des six clubs, en cherchant des preuves
officielles d'identité et de naissance pour les aliases et conflits restants,
puis les 206 autres lacunes. L'intégrateur garde la réception et l'activation
du mod après revue et CI verte ; le producteur ne fusionne pas.
