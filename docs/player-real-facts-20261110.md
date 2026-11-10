# Faits joueurs du 10 novembre 2026

Le relevé couvre le registre actif Monde + Champ de la saison 2026-2027. Les 5 878 identifiants actifs incluent les joueurs transférés entre éditions. Les six alias historiques sont hors périmètre. La date désigne le relevé, avec des preuves plus anciennes pour certains champs. Elle ne reconstitue pas les effectifs ni les sélections au 1er juillet 2026.

| Champ | Fiches documentées | Fiches sans donnée |
| --- | ---: | ---: |
| Taille | 3 873 | 2 005 |
| Poids | 3 934 | 1 944 |
| Nationalité affichée par la source | 1 634 | 4 244 |
| Sélections du XV national senior | 599 | 5 279 |
| Au moins un champ | 4 304 | 1 574 |
| Quatre champs | 135 | 5 743 |

Parmi les 599 compteurs, 566 sont positifs et 33 sont des zéros explicitement publiés. Les 66 dossiers du groupe de France incluent 62 compteurs positifs. Les 597 dossiers portant une indication de sélection documentent une présence dans un groupe officiel à la date de la source. Cette présence ne détermine ni une citoyenneté ni une qualification permanente. [Règlement 8 de World Rugby](https://www.world.rugby/organisation/governance/regulations/reg-8?lang=en)

## Sources et rapprochements

- La LNR a répondu pour 1 591 des 1 592 profils cherchés. Les fiches utilisées concordent avec l’identifiant de l’URL canonique et le nom publié. Les champs vides et les mesures hors bornes restent absents. Un profil a renvoyé une 404. Une mesure complémentaire a été reprise du relevé DATA-06. [Ligue Nationale de Rugby](https://www.lnr.fr/) · [Relevé DATA-06](data06-all-players.md)
- Le Japon et la Nationale réemploient les mesures publiées déjà compilées. La Premiership emploie les identifiants du fournisseur de la ligue. L’URC réemploie les concordances de naissance de la collecte initiale. Le Pacifique et le Champ utilisent les références des compilateurs privés qui ont établi les identifiants du registre. Les mesures physiques sont arrondies au centimètre ou au kilogramme. [League One](https://league-one.jp/) · [Compétitions FFR](https://competitions.ffr.fr/) · [PREM Rugby](https://www.premiershiprugby.com/) · [URC](https://www.unitedrugby.com/) · [Super Rugby Pacific](https://super.rugby/superrugby/) · [Champ Rugby](https://www.champrugby.co.uk/)
- Le Nations Championship publie le nombre de sélections par joueur pour douze équipes du XV senior. Le relevé rapproche les fiches officielles des identifiants du pack privé par le nom normalisé et un recoupement de club ou d’âge. Les variantes de prénom, de nom composé et d’ordre des noms exigent une correspondance unique dans le club documenté. Les totaux de chaque groupe ont été rapprochés du nombre de fiches et du cumul affichés par le site. [Nations Championship, groupe France](https://nationschampionshiprugby.com/en/teams/fra/squad)
- Les publications de la JRFU, de la FER et de Rugby Canada complètent ces groupes. Chaque observation garde la date de son relevé ou de sa publication. Le total correspond à l’équipe publiée avec le chiffre, sans extrapolation après la date de la source. Les contradictions non résolues, les compteurs de club, du VII ou des jeunes et les simples inscriptions sur une feuille de match sont écartés. [JRFU](https://www.rugby-japan.jp/news/54297) · [FER](https://ferugby.es/alineacion-de-los-leones-para-el-exigente-duelo-ante-uruguay-en-el-central-sabado-1600h/) · [Rugby Canada](https://rugby.ca/en/news/2026/10/36-players-selected-to-canada-s-men-s-rugby-team-for-november-nations-cup-fixtures-in-europe)

## Reconstruction hors ligne

`data/player-real-facts/observations.json` garde chaque observation sous la forme `[id, source, champs, empreinte facultative]`. L’empreinte identifie la capture HTML LNR ou Champ, ou l’URL de profil déjà réconciliée pour les archives PREM, URC et Pacifique. Certaines sources de groupe portent directement l’empreinte de leur capture. Les identités du pack, les URL nominatives, les pages brutes et les photos restent hors de ces fichiers. Le relevé utilise une correspondance privée une fois à la collecte, puis la compilation part uniquement des observations figées et des registres publics.

`native/engine/player-real-facts.json` est le catalogue compact produit pour le moteur. Les champs absents sont inconnus. `seniorCaps: 0` signifie zéro publié à la date de la preuve. `seniorNation` désigne l’équipe associée à un compteur positif, `eligibilityNations` les groupes officiels documentés et `flagCode` le drapeau associé à la nationalité de la fiche. Le catalogue ne déduit aucun de ces champs d’un autre. Les valeurs fictives affichées par la simulation relèvent de la projection du moteur.

```text
node scripts/build-player-real-facts.cjs
node scripts/build-player-real-facts.cjs --check
node --test tests/player-real-facts.cjs
```
