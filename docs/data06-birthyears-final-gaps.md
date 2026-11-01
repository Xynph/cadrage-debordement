# DATA-06 — effectifs Espoirs et noms abrégés, 1er novembre 2026

PRODUCTEUR sur la PR #160, depuis `f2998abf0c518989af2440ddf5e87304434d3031`.
La CI précédente est réussie : [Tests JavaScript #41289656701](https://github.com/Xynph/cadrage-debordement/actions/runs/41289656701).
La nouvelle tête demande sa propre CI ; aucune fusion ni activation automatique du mod.

## Résultat vérifié

**75 années supplémentaires** rattachées à des IDs LNR uniques, au-delà du
cumul précédent 1367 : **1442 / 1592**, encore **150** années inconnues ou
sans identité suffisamment établie. Les cinq jeux de preuves précédents sont
conservés. Ce sont des données de recherche préparées, pas des biographies complètes.

| Club prioritaire | Nouvelles années | Couverture cumulée | Restantes |
| --- | ---: | ---: | ---: |
| Dax | 1 | 35 / 36 | 1 |
| Nevers | 2 | 58 / 61 | 3 |
| Soyaux-Angoulême | 1 | 47 / 51 | 4 |
| Valence Romans | 0 | 38 / 40 | 2 |
| Narbonne | 2 | 47 / 48 | 1 |
| Nice | 0 | 49 / 51 | 2 |

Encore **13** lacunes dans ces six clubs, **137** ailleurs.

## Nouvelle collecte Espoirs

Les 30 URLs d'effectifs Espoirs ont été examinées. **27 pages HTTP 200**
publient **1195 lignes** portant explicitement `data-saison=2026-27`. Chaque
page conserve URL, titre, date/période et empreinte HTML. Les clubs sont reliés
explicitement au catalogue ; leur position dans une liste n'est pas utilisée.
Ces lignes ne sont ni 1195 joueurs inédits ni des effectifs certifiés au 1er juillet.

Trois pages ont répondu HTTP 429 (Colomiers, Nice, Nevers). Les accès ont été
mis en pause au moins 180 secondes avant la reprise des fiches individuelles,
avec une pause minimale de 3,2 secondes entre requêtes et arrêt de cette
collecte de profils sur 401/403/429. Les trois pages limitées restent déclarées
non récupérées. Aucun changement de domaine pour contourner leur limitation.

Les pages récupérées donnent **108 noms correspondant exactement et de manière
unique aux identités LNR encore incomplètes dans le même club**. Les 108 fiches
liées ont été analysées, avec réutilisation signalée d'une capture antérieure.
**50 années** proviennent de cette voie : nom exact dans l'effectif et
dans le `Person` JSON-LD, ID du profil inchangé, date publiée valide et année
compatible avec l'âge officiel lorsqu'il est disponible. Les dates manquantes,
`0000-00-00`, noms de profils incompatibles et contradictions restent exclus.

Les sources Espoirs résolvent aussi des propositions de mauvaise identité du
lot précédent : le nouveau profil doit porter son propre nom complet et son
propre ID. La fiche de Karl Martin ne devient jamais une preuve pour Sandro
Dubois Martin, ni celle de Braxton Asi pour Harrison Asi.

## Noms abrégés vérifiés

**23 correspondances ont été revues explicitement** pour des noms publiés
avec des prénoms omis : par exemple Mamoudou Meïté / Mamoudou Alain Meïté et
Abraham Pole / Abraham Anthony Pole. Le tableau conserve chaque paire et ses
preuves, avec quatre conditions cumulatives :

1. Tous les composants du nom court apparaissent dans l'ordre dans le nom LNR,
   avec même premier prénom et même dernier patronyme ; un seul ID parmi les
   1592 satisfait cette relation.
2. La page LNR de l'ID exact confirme le nom complet, le club explicite, le
   poste et l'âge publié. Son HTML est conservé par empreinte.
3. Le nom court appartient au même club dans l'effectif Rugby Data déjà capturé,
   avec son ID individuel stable ; les noms et URLs de cette observation sont conservés.
4. Deux éditeurs distincts publient une date portant la même année. L'âge
   officiel sert uniquement à rejeter une contradiction ; il ne crée aucune année.

Les variantes `Jason-colin` / `Jason-Collin` ne sont pas assimilées par une
correction de lettre. Pour Jason Fraser, la correspondance utilise le nom
court publié **Jason Fraser**, le club officiel USON et sa date explicite
**15 avril 1991**, également publiée par Rugby Data. Les deux graphies longues
restent intactes dans leurs observations.

Les noms seulement voisins, surnoms non documentés et relations ambiguës restent
rejetés. La méthode ne généralise pas une correspondance floue à tous les joueurs.

## Compléments et conflits

- Duacake Vulainabuwaha : année **2006**, explicitement publiée dans le profil
  sportif public indexé, avec nom exact et identité LNR officielle Dax.
- Giorgi Zazadze : année **2007**, concordante dans la liste U20 Wikipédia et
  Ultimate Rugby. Le profil ItsRugby de **Giorgi**, ID 67888, atteste Nevers,
  Géorgie U20, 19 ans, 189 cm et 101 kg ; la page LNR confirme l'identité.
  Les sources divergent sur juin/juillet : seule l'année est retenue et le
  désaccord de jour/mois est signalé. La fiche Rugby Data 2065 de **Rati**
  Zazadze n'est jamais utilisée pour la naissance de Giorgi.
- Lylian Zelioli et Dylan Idrissi restent exclus : contradictions d'année
  non résolues. Noah Brown est également exclu de la nouvelle voie lorsque
  l'année du profil est incompatible avec l'âge officiel.

Les récupérations par index web sont distinguées des HTML factuels obtenus.
Une page technique ou refusée n'est pas présentée comme une capture de biographie.
Les records conservent uniquement `birthYear` ; `birthDate` et
`validAtCareerStart` restent `null`. Les faits publiés, noms originaux, dates,
URLs, identifiants et empreintes sont conservés dans le nouveau JSON.

## Tests et réception

```sh
node --test tests/data06-birthyears-six-clubs.cjs tests/data06-birthyears-followup.cjs tests/data06-birthyears-final-gaps.cjs
```

**32/32 tests ciblés réellement réussis**, dont 12 nouveaux : IDs/URLs/clubs,
nouveauté, absence de doublons, unicité des noms, effectifs/saison/profils liés,
dates littérales, noms abrégés revus, deux éditeurs, identité officielle,
distinction Rati/Giorgi et bilan complet des 108 fiches. Suite complète du jeu
non exécutée localement ; CI complète de la nouvelle tête à contrôler.

Quatre chemins seulement pour ce lot : nouveau JSON, nouveau test, cette note,
appendice DATA du journal. Aucun fichier UI/V4, moteur, sauvegarde ou preuve
antérieure modifié. Aucun service payant/Firecrawl ni collecteur laissé en
arrière-plan. Réception et activation réservées à l'intégrateur après revue
et CI verte ; aucune fusion par le producteur.

Priorité suivante : les **13** lacunes prioritaires par preuves publiques
explicites, puis les **137** autres. Les inconnues restent inconnues.
