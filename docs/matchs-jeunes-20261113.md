# Matchs des jeunes des centres de formation (13/11/2026)

Module : `native/engine/youth-matches.cjs` (domaine natif `youthMatches`, API VM `CDYouthMatches`).
Actif dès que la politique des centres 3 est en place (toutes les nouvelles carrières), hors ancien
parcours Espoirs v73 activé à la main (il a ses propres rencontres).

## Principe

- Chaque club engage deux équipes : **Crabos/U18** (16-17 ans, plus les rares 15 ans) et **Espoirs/U21**
  (18-21 ans ; des Crabos de 17 ans sont surclassés si le groupe Espoirs est trop court).
- Calendrier : vraies compétitions du pays, à leurs dates réelles (« MM-JJ » reprises chaque année,
  saison des jeunes du 1er juillet au 30 juin), puis matchs amicaux d'été, tournois à 7 et, si le pays
  n'a pas de championnat sur toute l'année, **matchs de clubs/écoles simulés** (adversaire virtuel :
  école, club partenaire, club en double licence…) jusqu'à ~20 matchs par équipe.
- Moteur de résultat rapide (jamais le moteur de match complet) : force = moyenne des titulaires
  (poste, polyvalence par famille), score par loi de Poisson sur les essais, temps de jeu
  (titulaires 80 min, remplaçants 8-38 min), essais attribués selon le poste. Générateur aléatoire
  dédié et déterministe (n'utilise pas le `Math.random` de la simulation).
- Aucune composition ni stratégie : rotation automatique (fatigue, charge de la saison, reprise).

## Charge, blessures, plafond (point 3)

Par joueur, `youthLoad` = [saison, matchs, titularisations, minutes, fatigue, jours de blessure,
reprise, sélections, essais, dernier jour].

- Blessure : **même risque que les pros** (`applyMatchInjuries` : 2,5 % par 80 min, 7 % si condition < 55),
  condition = 100 − fatigue ; **×1,5 au-delà de 25 matchs**. Durée : 88 % de 1 à 4 semaines (comme
  les pros), 12 % de blessures longues de 5 à 16 semaines (ajout : les pros n'ont pas de blessure longue
  dans ce modèle ; sans elles, pas de « retour progressif »).
- Après une blessure de 5 semaines ou plus : **3 matchs de reprise** à 50 min au plus, de préférence
  sur le banc.
- **Plafond de 30 matchs** (club + sélection) : au-delà, le joueur n'est plus aligné.
- Fatigue : +0,4 par minute jouée, −2,5 par jour de repos.
- Interface sélections (autre chantier) : `CDYouthMatches.recordSelection(S, idJoueur, minutes)`
  ajoute un match de sélection (compte dans le plafond et la fatigue ; refuse au-delà de 30) ;
  `CDYouthMatches.matches(S, joueur)` → `{club, selection, total, cap, available}`.

## Progression (point 2)

Chaque apparition alimente l'existant : `dev.minutes`, `dev.careerMinutes`, `dev.appearances`
(historique annuel et courbe d'âge), XP par `growPlayer` avec la formule des pros
(`minutes/80 × 0,12 × âge × condition × charge physique`) pondérée par le niveau de la compétition
(0,35 à 7 ; 0,7 en championnat Élite, 0,45 en match de club simulé, ×0,6 pour le rugby à 7), et le
**potentiel évolutif** (`nativePotentialEvolution.match` : minutes, forme collective, essais).
Sur 20 saisons, la note moyenne des jeunes passe de 59,5 à ~61,7 puis se stabilise (pas d'emballement).

## Sauvegarde (point 5)

Stocké : poules et classements de la saison en cours, phases finales en cours, 12 derniers résultats
par équipe du club joué, palmarès (20 saisons au plus). **Aucun match futur ni détail de match** :
le calendrier est recalculé. À chaque nouvelle saison, le détail précédent est purgé, ainsi que
les lignes du suivi du potentiel des joueurs qui ne sont plus dans aucun effectif.
Mesure : `node scripts/measure-youth-matches.cjs 20` (résultats dans la PR).

## Réel / estimé / inventé

| Pays | Compétition | Statut |
|---|---|---|
| France | Élite Crabos : 42 clubs, 7 poules de 6 A/R, puis 24 en championnat (6 poules de 4) et 18 en Challenge (3 poules de 6), quarts/demies/finale | **Réel** (FFR, présentation des compétitions 2025-26). Dates de poules réelles ; dates de 2e phase et finales réelles mais en partie ambiguës dans la source |
| France | Crabos à 7 : 2 tournois de qualification (6 et 13 sept.), finale à 16 (21 mars) | **Réel** (FFR 2025-26) |
| France | Reichel-Espoirs Élite : 24 clubs, 4 poules de 6, 16 en championnat / 8 en Challenge, quarts 23/05, demies 30/05, finale 06/06 | **Réel** (livret FFR 2025-26) |
| France | Reichel-Espoirs Accession : 20 clubs, 2 poules de 10, 18 journées, phase finale | **Réel** ; dates des quarts/demies **estimées** |
| France | Espoirs à 7 (2 tournois fin août) | **Réel** (calendrier FFR 2026-27, « IES7 ») ; dates exactes **estimées** |
| France | National U18 / Espoirs Nationaux pour les centres au-delà des 42/44 | Compétitions **réelles**, adversaires virtuels, dates **estimées** |
| France | Répartition des clubs : Top 14 + 10 meilleurs de Pro D2 en Espoirs Élite | **Estimé** (la vraie liste dépend des résultats de l'année précédente) |
| Angleterre | PREM Next Gen U18 : 9 journées (août, octobre, janvier), finales le 28/02 | **Réel** (calendrier 2026-27 publié par les clubs) ; journée 1 (8 août) **estimée** |
| Angleterre | Tournoi scolaire à 7 de Rosslyn Park (fin mars) | **Réel** ; date **estimée** |
| Angleterre | PREM Rugby Cup (Espoirs) : 2 poules de 5, 8 matchs, demies, finale 15/03 | **Réel** (2025-26) ; dates de poules **estimées** |
| Angleterre (Championship) | Pas de compétition de centre : amicaux + matchs d'écoles/clubs | **Simulé** |
| Irlande | Interprovinciaux U18 (6 journées, août) et U19 (3 journées, août) | **Réel** (PwC 2026) ; Connacht intégré aux U18 écoles (il joue la série clubs en réalité) |
| Galles | Championnat régional U18 (août-sept., reprise en janvier, finales 4/02) | **Réel** (WRU 2026) ; RGC absent du jeu |
| Galles | Championnat U19 des académies (juillet-août) | Compétition **réelle**, dates **estimées** |
| Écosse | Rencontres Glasgow-Edinburgh | **Inventé** ; reste en écoles/clubs (Super Series pour les Espoirs) |
| Italie | Campionato Under 18 Élite contre clubs du championnat | Compétition **réelle**, format et dates **estimés**, adversaires virtuels |
| Afrique du Sud | Craven Week (6-11 juillet 2026) | **Réel** |
| Afrique du Sud | Championnat provincial U21 (juillet-sept.) | Compétition **réelle** (format 2025) ; réforme 2026 non publiée, dates **estimées** |
| Nouvelle-Zélande / Fidji | Super Rugby U20 (Taupō, mars, 3 matchs) | **Réel** (2025) |
| Australie | Super Rugby Next Gen (7, 14, 21 février 2026) | **Réel** |
| Japon | Aucun championnat de centres : rencontres entre centres + lycées/clubs | **Inventé** (pas de modèle universitaire) |
| Géorgie, autres | Matchs de clubs simulés | **Simulé** |
| Tous | Amicaux d'été (1 Crabos, 2 Espoirs) | Décision de Léo ; dates **inventées** |

Sources : FFR (présentation des compétitions fédérales 2025-26 et calendriers 2026-27, livret
Reichel-Espoirs Élite 2025-26), Northampton Saints (PREM Next Gen 2025-26 et 2026-27), PREM Rugby Cup
2025-26, IRFU (PwC Underage Interprovincial Series 2026), WRU (championnat U18 des académies 2026),
SA Rugby (calendrier 2026), Rugby Australia (Super Rugby Next Gen 2026), Super Rugby U20 (2025).
