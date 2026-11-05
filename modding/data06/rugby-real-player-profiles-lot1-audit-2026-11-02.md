# Rugby Réel — lot 1 : index vérifiable des 1 592 joueurs (02/11/2026)

## Périmètre réel

TOP 14 et PRO D2, snapshot LNR du 31/10/2026 et saison 2026-2027. Le fichier `rugby-real-player-profiles-lot1-2026-11-02.json` indexe **exactement les 1 592 identifiants uniques** du fichier existant `consolidated-birthyears-1592-2026-11-01.json` en lecture seule. Les noms, clubs et années de naissance restent dans cet ancien fichier et ne sont pas recopiés. Ce nouveau fichier est un **index de recherche non jouable**, pas une extension du moteur ni un remplacement de données de jeu.

| Information | Vérifiés ici | Inconnus ici | Couverture |
| --- | ---: | ---: | ---: |
| IDs LNR couverts | 1 592 | 0 | 100 % |
| Années historiques DATA-06 (fichier de référence) | 1 592 | 0 | 100 % |
| Dates de naissance complètes | 4 | 1 588 | 0,25 % |
| Tailles en centimètres | 4 | 1 588 | 0,25 % |
| Poids en kilogrammes | 4 | 1 588 | 0,25 % |
| Postes précis | 4 | 1 588 | 0,25 % |
| Polyvalence **actuelle** attestée | 0 | 1 592 | 0 % |

Répartition des identités : **805 TOP 14**, **787 PRO D2**, **30 clubs**. Provenance des *années historiques* : 1 442 `research-evidence`, 150 `user-supplied` ; cela ne certifie pas que les 1 592 dates exactes ont été indépendamment vérifiées. Les années ne permettent pas de déduire un jour et un mois. Ici, inconnu est explicitement représenté par `null`, pas par zéro, chaîne vide, poste déduit du groupe, poids estimé ou absence de polyvalence.

## Quatre profils directement documentés

| ID | Joueur | Date complète | Taille | Poids retenu | Poste vérifié |
| --- | --- | --- | ---: | ---: | --- |
| `lnr:862` | Barnabé MASSA | 13/05/2004 | 180 cm | 101 kg | Talonneur |
| `lnr:921` | Régis MONTAGNE | 30/09/2000 | 186 cm | 132 kg | Pilier droit |
| `lnr:3233` | Giorgi DZMANASHVILI | 16/06/2002 | 186 cm | 122 kg | Pilier droit |
| `lnr:1707` | Thomas LACLAYAT | 02/10/1997 | 176 cm | 125 kg | Pilier droit |

**Sources par champ dans le JSON** (chacune est une URL complète) :
- Massa : [LNR — fiche](https://top14.lnr.fr/joueur/862-barnabe-massa), [LNR — talonneur](https://top14.lnr.fr/actualite/massa-banos-meliande-ces-jeunes-a-surveiller-lors-de-cette-saison-de-top14), [TF1 — date](https://www.tf1info.fr/actualite/fiche-joueur-barnabe-massa-14386/). **Discordance de poids** : TF1 103 kg, LNR 101 kg ; la valeur LNR est retenue.
- Montagne : [LNR — taille et poids](https://top14.lnr.fr/joueur/921-regis-montagne), [LNR — pilier droit](https://top14.lnr.fr/actualite/decouvrez-votre-xv-de-la-mi-saison-de-top-14), [RugbyData — date](https://rugbydata.fr/players/view/193).
- Dzmanashvili : [L'Équipe — date, taille et poids](https://www.lequipe.fr/Rugby/RugbyFicheJoueur12963.html), [Turnover Rugby — pilier droit](https://www.turnover-rugby.fr/top14/asm-clermont-auvergne/giorgi-dzmanashvili). Le groupe LNR « première ligne » seul ne suffit pas à prouver ce côté.
- Laclayat : [Section Paloise — date et autre mesure](https://www.section-paloise.com/joueurs-de-la-section/thomas-laclayat), [LNR — taille et poids retenus](https://top14.lnr.fr/joueur/1707-thomas-laclayat), [RugbyData — pilier droit](https://rugbydata.fr/players/view/510). **Discordance** : Section Paloise 178 cm/126 kg, LNR 176 cm/125 kg ; la mesure LNR est retenue et la divergence conservée.

**Prudence métier** : la qualité « pilier droit / talonneur » dans une source publique n'atteste pas une qualification réglementaire de première ligne dans le moteur. Une ancienne pratique au poste n'est pas une polyvalence actuelle. Les profils physiques peuvent évoluer ; les URL sont datées au niveau de l'observation, sans les présenter comme valeurs permanentes.

## Validation reproductible

```sh
node modding/data06/validate-rugby-real-profiles-lot1.cjs
```

Ce validateur **sans réseau** vérifie les 1 592 IDs, leur unicité, le lien vers le fichier de référence, les 1 592 enregistrements, les quatre dates compatibles avec les années historiques, la syntaxe des dates, les unités/ordres de grandeur, la présence de sources HTTPS pour chaque attribut renseigné, les inconnus explicites et les chiffres de couverture. Il n'atteste pas que chaque page externe reste accessible, ni un droit de réutilisation générale.

**Collecte et droits** : aucune collecte payante, aucun scraping massif, aucun miroir de pages ni d'images. Ce lot ne reprend que quelques faits élémentaires avec attribution. Avant d'amplifier la réutilisation de données publiques : examiner les conditions de chaque site, les droits des bases de données, le volume autorisé et la validité temporelle des données.

**Suivant** : enrichir par sous-lots sourcés et révisables, en priorité les postes des autres joueurs de première ligne ; ajouter les dates précises et mesures quand elles sont publiées. Ne jamais transformer une valeur inconnue en estimation non signalée. Le lot ne touche pas les fichiers de jeu ni la sauvegarde V16.
