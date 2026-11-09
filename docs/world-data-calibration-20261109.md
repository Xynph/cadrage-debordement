# Registre mondial 2026/27 — données et estimations

L’édition `rugby-world-2026-11-08-v1` fige un état des sources au 8 novembre 2026. Elle contient 58 clubs et 3 208 joueurs : 1 592 joueurs français repris à l’identique, 637 joueurs de PREM, 888 d’URC et 91 des deux clubs invités en Challenge Cup. Les listes réunissent les joueurs des groupes seniors, les inscriptions de ligue recoupées et les jeunes effectivement listés par les clubs. Une fiche d’académie n’est pas la preuve d’un contrat professionnel.

| IDs | Groupe | Nombre de clubs | Joueurs |
| --- | --- | ---: | ---: |
| 0–13 | Élite française | 14 | 805 |
| 14–29 | Accession française | 16 | 787 |
| 30–39 | PREM | 10 | 637 |
| 40–55 | URC | 16 | 888 |
| 56–57 | Invités de Challenge Cup | 2 | 91 |

Les objets des 1 592 joueurs français sont comparés intégralement par identifiant à `rugby-common-2026-10-31-v1`, attributs, potentiel et historique compris. Le nouveau registre est autonome. Il conserve les clés historiques des 30 clubs français. Les identifiants étrangers proviennent de l’identifiant du fournisseur ou de l’empreinte d’une URL officielle stable. Une annonce de transfert recoupée avec la date de naissance complète permet de conserver un identifiant de ligue lorsque le club change. Un rapprochement avec la France sur le seul nom ou la seule année de naissance ne crée ni doublon ni transfert.

## Sources, dates et limites

- [PREM, clubs et équipes](https://www.premrugby.com/clubs) et les pages officielles de chacun des dix clubs. Les 606 cartes de joueurs et 538 fiches de ligue ont été rapprochées ; 45 fiches de ligue restaient sans correspondance directe. Une fiche non rapprochée n’entre au registre que si le dossier ne présente pas de conflit de nom ou d’appartenance. Les divergences sont conservées dans les archives privées.
- [URC, centre de statistiques](https://stats.unitedrugby.com/) et pages d’effectifs des seize clubs. Les cartes de club, l’académie et les annonces datées complètent le répertoire. Un profil isolé du répertoire n’est pas considéré comme un joueur actif sans preuve complémentaire. Les deux groupes géographiques d’Écosse et d’Italie partagent un shield ; l’Ulster est au Royaume-Uni pour le code pays et dans le shield irlandais pour la compétition.
- [Effectif des Cheetahs](https://www.fscheetahs.co.za/players) et [effectif EPCR de Black Lion](https://www.epcrugby.com/challenge-cup/clubs/black-lion/squad), complétés par la Fédération géorgienne. Les dates de départ futures restent des annonces, pas des changements déjà effectués à la date de référence.
- [Poules Champions Cup](https://www.epcrugby.com/champions-cup/matches/pool-tables), [poules Challenge Cup](https://www.epcrugby.com/challenge-cup/matches/pool-tables), [calendrier URC](https://stats.unitedrugby.com/match-centre/tables/2026-27) et [calendrier PREM](https://www.premrugby.com/fixtures-results). Le registre contient les 42 qualifiés, 144 rencontres URC, 90 de PREM et 84 de poules européennes. Un créneau Challenge et 45 créneaux PREM restent provisoires. Un match de PREM est avancé du 28 au 27 décembre dans le jeu pour respecter le rythme d’une rencontre par club et semaine. Sa date officielle et le motif de l’ajustement restent enregistrés. Les dates éliminatoires domestiques représentent les fenêtres publiées. Aucun score, vainqueur ou classement réel n’est importé.

Sur les 1 616 nouveaux profils, 1 466 âges sont calculés à partir d’une date de naissance publiée et non contradictoire. Les 150 autres âges sont des paramètres de jeu signalés comme estimés. Cela inclut 55 divergences de date de naissance entre sources : 22 PREM et 33 URC. Aucune date de naissance précise n’est publiée sur ces profils tant que la divergence subsiste. Le poste provient d’une source explicite pour 1 327 profils ; 289 postes restent des affectations de jeu. Deux listes de poste omettaient l’arrière ; les rôles ont été corrigés à partir d’une fiche ou d’une composition officielle. Pour un pilier dont le côté n’est pas publié, une affectation signalée comme estimée peut couvrir un côté du banc. Un côté publié n’est pas inversé par cet équilibrage.

## Calcul des notes

Les notes et le potentiel sont des **estimations de simulation**. L’estimation part des distributions françaises inchangées, par poste et tranche d’âge, puis applique les observations de performance disponibles et une variation individuelle déterministe. Le rang d’une observation est calculé parmi les joueurs du même poste. Le poids des métriques baisse quand le temps de jeu ou le nombre d’actions est faible. Les 36 attributs sont projetés sur les 11 compétences du moteur, avec les règles de touche propres au talonneur et au deuxième ligne. Aucun bonus n’est appliqué automatiquement selon le championnat.

347 profils ont un temps de jeu exploitable pour un calcul par 80 minutes ; 1 040 profils ont au moins une métrique exploitable. Pour 704 profils URC, les zéros d’apparitions et de minutes sont des valeurs de remplissage contredites par d’autres événements. Ils restent inconnus dans le modèle. Seuls les ratios dont le dénominateur est publié et exploitable sont alors utilisés. En l’absence d’observations, la note provient du poste et de la tranche d’âge. Les notes étrangères s’étendent de 62 à 79 et le potentiel de 63 à 89. La confiance est faible dans ce lot : les échantillons de temps de jeu du début de saison ne justifient pas une hiérarchie fine entre joueurs d’élite.

Le potentiel dépend de la note, de la marge de progression par âge et d’une variation déterministe. Il ne peut être inférieur à la note. Les traits cachés, la trésorerie, les salaires et les fins de contrat non publiées sont des paramètres de simulation. La règle des contrats initiaux estimés répartit les échéances entre la fin des saisons 1 à 3. Une échéance publiée et recoupée conserve sa provenance officielle. Les fiches anonymisées n’embarquent ni nom réel, ni image, ni lien de profil. Le mod privé associe des identités à ces mêmes IDs ; il ne change aucune note.

## Salaires de départ en PREM

La politique `world-prem-starting-payroll-v1` ramène les 637 salaires initiaux fictifs de PREM à 85 % du barème calculé à partir des notes, avec arrondi à l’euro. Le registre enregistre ce coefficient dans `provenance.premStartingSalary`. Le calibrage s’applique aux contrats de départ. Les recrutements et les renouvellements suivent le barème du moteur.

Une saison en mode monde a été rejouée avec Bath, la graine 827381, une horloge fixe et les 23 matchs du club délégués. Après 46 semaines, deux clubs de PREM sur dix terminent avec une trésorerie négative, contre six dans l’audit de référence. Les deux déficits sont de 861 406 € et 155 536 €. Les 791 résultats sportifs et les soldes des autres ligues sont identiques entre les deux campagnes. Cette mesure porte sur une seule graine.

## Recompiler et contrôler

`node scripts/build-world-registry.cjs` compile le JSON depuis `data/world/` et le registre français existant. La compilation se fait hors ligne ; les sources nominatives et les médias restent dans les archives privées. Les empreintes des entrées et des calendriers figurent dans `provenance`. `node scripts/build-world-registry.cjs --check` vérifie que le fichier compilé correspond aux entrées actuelles.

`node tests/world-registry.cjs` vérifie les 58 IDs de club, les 1 592 profils français exacts, la projection des attributs, les notes et contrats estimés, le coefficient des salaires PREM, le déterminisme, les doublons et les dates ambiguës. Il fait aussi produire une feuille de 23 joueurs aux 28 clubs étrangers avec le sélecteur du jeu. Le calendrier vérifie les 318 rencontres, l’équilibre domicile/extérieur, les poules et l’absence de collision hebdomadaire entre PREM, URC et Europe. Ce test de données ne valide pas, à lui seul, la simulation d’une saison ni ses sauvegardes.
