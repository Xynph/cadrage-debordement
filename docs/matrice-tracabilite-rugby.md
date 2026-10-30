# Matrice de traçabilité réglementaire — Cadrage Débordement

**Création : 30 octobre 2026.** Document de contrôle, sans modification du moteur. Complète [le référentiel existant](rugby-rules-reference.md), qui reste la référence de détail.

## Portée et règle de validation

- Rugby à XV adulte professionnel français. Le profil moteur documenté dans `DEVELOPPEMENT.md` est `fr-pro-2025` (2025/26). Ne pas appliquer automatiquement les nouveautés 2026/27.
- Une source World Rugby fixe la loi générale ; la LNR et la FFR fixent les dispositions spécifiques de compétition/saison. En cas d'incertitude, classer **à vérifier** et ne pas modifier la simulation.
- Les colonnes « couverture » ci-dessous décrivent les **points de contrôle à auditer**, pas une conformité déjà démontrée. La présence d'un fichier de test ne garantit pas qu'il teste le scénario.
- Les coefficients de simulation (probabilités, fatigue, choix tactiques) sont des abstractions du jeu, **pas des lois officielles**.

## Matrice loi → comportement → tests à vérifier

| Loi / domaine | Comportement attendu ou point de contrôle | Code à auditer | Test à vérifier / ajouter | Couverture |
|---|---|---|---|---|
| 3 — Équipe | Maximum 15 sur terrain ; remplacements qualifiés, notamment première ligne et mêlées non disputées | `dist/rugby.js`, modules de match | `tests/frontrow.cjs`, `tests/match-rules.cjs` | À auditer |
| 5 — Temps | 2 × 40 min ; fin de période conditionnelle, pas arrêt automatique à 80:00 | modules de match | `tests/matchflow.cjs` | À auditer |
| 7 — Avantage | Conserver équipe bénéficiaire, type, emplacement et sanction initiale ; avantage tactique/territorial **réel** ; retour si non obtenu ; arrêt immédiat si danger | modules de match et discipline | `tests/match-rules.cjs`, scénarios dédiés à ajouter | À auditer |
| 8 — Score | Essai 5, transformation 2, pénalité/drop 3, essai de pénalité 7 sans transformation ; géométrie de transformation | `dist/rugby.js`, modules de tir | `tests/goalkicking.cjs`, `tests/rugby.cjs` | À auditer |
| 9 — Jeu déloyal | Motif et gravité explicites ; pénalité distincte du carton ; jaune 10 min de temps de jeu ; rouge définitif vs rouge remplaçable après 20 min selon profil de compétition | modules de discipline et de match | `tests/match-rules.cjs`, cas dédiés à ajouter | À auditer |
| 10–11 — Hors-jeu / en-avant | Hors-jeu et remise en jeu selon phase ; en-avant involontaire vs volontaire, avantage et sanction | `dist/rugby.js`, modules de match | `tests/rugby.cjs`, `tests/match-rules.cjs` | À auditer |
| 12 — Renvois | Après score, renvoi par équipe ayant encaissé ; distinguer renvois 22 m / ligne d'essai | modules de match | `tests/restarts.cjs` | À auditer |
| 14–16 — Plaquage, ruck, maul | Distinguer phases, obligations de libération, hors-jeu et fautes dangereuses | modules de match | `tests/match-actions.cjs`, scénarios dédiés | À auditer |
| 18 — Touche | Lancer selon cause de sortie ; 50:22 et pénaltouche avec conditions propres | modules de match | `tests/match-rules.cjs` | À auditer |
| 19 — Mêlée | Premières lignes aptes, engagement, sanctions, effectif après exclusion | modules de match | `tests/frontrow.cjs` | À auditer |
| 20 — Pénalité / coup franc | Options et sanctions distinctes, repli adverse à 10 m | modules de match | `tests/match-rules.cjs` | À auditer |
| 21 — En-but | Essai, tenu en en-but, touche de but et ballon mort : reprises distinctes | modules de match | `tests/restarts.cjs` | À auditer |
| LNR — Classement | Points de victoire/nul/défaite, bonus et départages par ordre officiel de la saison | modules de compétition | `tests/manager.cjs` et tests de classement dédiés | À auditer |
| Sauvegardes | Les nouveaux états d'avantage/cartons restent compatibles avec anciennes carrières ; défauts explicites pour données absentes | modules de sauvegarde | `tests/saves.cjs` | À auditer |

## Scénarios de référence à transformer en tests automatisés

1. **Avantage non concrétisé :** faute A, ballon conservé sans gain réel ; revenir à la sanction A et à son emplacement.
2. **Avantage acquis :** progression territoriale ou option tactique réelle ; continuer sans revenir à A.
3. **Deux infractions :** seconde faute de l'équipe fautive sans avantage ; choix de la sanction la plus favorable selon loi 7.2(d).
4. **Danger ou blessure grave suspectée :** arrêter immédiatement, même si un avantage semblait possible (loi 7.3).
5. **Jaune :** joueur indisponible pendant 10 minutes de temps de jeu ; contrôler l'effectif et le retour autorisé.
6. **Rouge remplaçable (élite applicable) :** joueur exclu ne revient jamais ; autre joueur éligible après 20 minutes de temps de jeu, pas avant.
7. **Rouge définitif :** aucun remplacement au titre du rouge, y compris après 20 minutes.
8. **Deux jaunes :** vérifier la qualification du rouge selon directive et le cas d'un second incident intentionnel et très dangereux.
9. **Première ligne exclue :** respecter le processus de remplacement et les conséquences sur la mêlée, sans effacer la sanction.
10. **Ancienne sauvegarde :** reprise d'une partie dépourvue des nouveaux champs d'état de match, sans perte ni mutation silencieuse.

## Sources officielles et dates

- [World Rugby — Loi 7, avantage](https://passport.world.rugby/fr/les-regles-du-jeu/regles-du-jeu-par-numero/7-l-avantage/) — consultée le 30/10/2026.
- [World Rugby — Loi 9, jeu déloyal](https://passport.world.rugby/laws-of-the-game/laws-by-number/9-foul-play/) — consultée le 30/10/2026.
- [World Rugby — Loi 3, équipe](https://passport.world.rugby/laws-of-the-game/laws-by-number/3-team/) — consultée le 30/10/2026.
- [World Rugby — directive cartons rouges 20 min, août 2025](https://passport.world.rugby/laws-of-the-game/law-application-guidelines/implementation-of-the-20minute-red-card-replacement-in-elite-rugby-august-2025/) — consultée le 30/10/2026.
- [World Rugby — nouveautés réglementaires](https://passport.world.rugby/laws-of-the-game/whats-new/) — consultée le 30/10/2026. Vérifier date d'entrée en vigueur, notamment modifications futures.
- [LNR — Livre 2, saison 2026/27](https://assets.lnr.fr/3/0/4/6/9/8/LIVRE-2_Sportif-et-Comp%C3%A9titions_2627_V2_703069b00e686885076f1b627c8c5441.pdf) — référence identifiée dans `rugby-rules-reference.md` ; applicabilité à confirmer pour le profil 2025/26.

## Procédure avant chaque changement réglementaire

1. Identifier le profil de saison et les dispositions LNR/FFR applicables.
2. Comparer le code réel et les tests existants à la ligne de matrice correspondante.
3. Documenter la divergence, les cas limites et l'abstraction éventuellement volontaire.
4. Ajouter les tests de non-régression, y compris une sauvegarde ancienne lorsque l'état persistant change.
5. Modifier le moteur sur branche dédiée ; exécuter toutes les validations pertinentes et fusionner uniquement si elles réussissent.
6. Mettre à jour cette matrice, `rugby-rules-reference.md` et `DEVELOPPEMENT.md` avec références de commits et résultats effectivement vérifiés.
