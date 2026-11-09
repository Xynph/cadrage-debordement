# Réception native réelle — population et staff

Source du raccord : `ee23433001c7014c3452cdea886dcf30f00ae63e`, avec population b04d508 et trois commits staff 8d4c85b/f7369d8/f2f1c1c. Node 22.23.4, mode commun, club 0, graine 827381, horloge 1794178800000.

**Verdict : réussi. Deux saisons réellement jouées de 34 semaines et 433 résultats chacune**, deux transitions jusqu'à S3, trois réouvertures d'export et de profil privé strictement identiques. Aucune saison n'a été obtenue en incrémentant manuellement l'état. Durée réelle : **152,638 s**.

| Saison terminée | Semaines réelles | Résultats | Staffs existants vérifiés +1 an | Nouvelles reconversions réelles |
| --- | ---: | ---: | ---: | ---: |
| 1 | 34 | 433 | 545 | 3 |
| 2 | 34 | 433 | 548 | 3 |

Chaque membre conservé garde son `appearanceAge` initial malgré le vieillissement réel ; chaque nouvelle reconversion conserve son âge d'entrée après la transition, sans second vieillissement. Son ancien joueur n'est plus professionnel, et la preuve de reconversion indique la saison réellement terminée. Le compteur `lastAdvancedSeason` et chaque `ageSeason` sont strictement vérifiés aux cinq points initiaux/clôture/ouverture. Les empreintes des huit fichiers de production surveillés sont identiques au début et à la fin.

| Point | Saison | Dernière saison staff avancée | Staff présents | Candidats staff | Retraites joueurs capturées | Reconversions encore présentes |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| initial | 1 | 0 | 545 | 15 | 0 | 0 |
| end-S1 | 1 | 0 | 545 | 15 | 0 | 0 |
| opening-S2 | 2 | 1 | 548 | 18 | 28 | 3 |
| end-S2 | 2 | 1 | 548 | 18 | 28 | 3 |
| opening-S3 | 3 | 2 | 551 | 27 | 16 | 6 |

Les tests courts du worker ont également réussi : **8/8** en 21,433 s, incluant import d'ancienne forme sans activation, activation indépendante des deux cycles, refus stricts et disque réellement bloqué avec réessai. La recette des packs staff est réussie : sources/command IDs distincts, identité présentée cohérente dans l'annuaire et `clubLife`, portraits, corruption et reprise.

Les réouvertures exactes de cette campagne sont `end-S1`, `end-S2` et `opening-S3`. Les profils de cette recette sont synthétiques et ont été supprimés après réception. Aucun média privé ou profil personnel utilisé, aucune dépense réelle ou publication externe.

Preuves : `/workspace/work/lifecycle-native-seasons.json`, `/workspace/work/lifecycle-native-seasons.log`, `/workspace/work/lifecycle-native-seasons.cjs`, `/workspace/work/lifecycle-native-tests-final.log`, `/workspace/work/lifecycle-staff-packs.log`. Le fichier JSON contient les empreintes exactes de production.
