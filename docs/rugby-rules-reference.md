# Référentiel rugby à XV — Cadrage Débordement

Recherche et audit du 29 octobre 2026, sur le code `88da449`.
Cette synthèse personnelle guide le développement ; elle ne remplace pas les
textes officiels et ne certifie pas la conformité du moteur. Aucun comportement
du jeu n'a été corrigé pendant cette phase d'étude.

## Périmètre et méthode

Rugby à XV adulte professionnel français. Distinguer les lois World Rugby, leurs
précisions et directives, les expérimentations applicables, puis les dispositions
FFR et le règlement de compétition LNR de la saison simulée. Le rugby amateur,
les jeunes et le VII ont des variantes différentes.

Référence générale : [les 21 lois World Rugby](https://passport.world.rugby/fr/les-regles-du-jeu/regles-du-jeu-par-numero/).
Le livre PDF annuel seul ne suffit pas : consulter aussi les mises à jour et leur
date d'application. La carrière devra annoncer sa version réglementaire.

## Les 21 chapitres et leurs conséquences

Chaque lien mène au texte complet à consulter pour ses exceptions.

| Loi | Points retenus pour le moteur |
| --- | --- |
| [1 — Terrain](https://passport.world.rugby/fr/les-regles-du-jeu/regles-du-jeu-par-numero/1-le-terrain/) | Distinguer champ de jeu, en-but, touche et ballon mort ; représenter les lignes des 5, 10, 15, 22 et 50 mètres. Les limites ont des statuts différents. |
| [2 — Ballon](https://passport.world.rugby/fr/les-regles-du-jeu/regles-du-jeu-par-numero/2-le-ballon/) | Ballon ovale réglementaire. Le remplacement du ballon ne change pas la possession ; une touche rapide exige notamment le même ballon. |
| [3 — Équipe](https://passport.world.rugby/fr/les-regles-du-jeu/regles-du-jeu-par-numero/3-l-equipe/) | Maximum quinze sur le terrain ; jusqu'à huit remplaçants selon l'organisateur. Une feuille à 23 exige six premières lignes formées couvrant les postes requis. Distinguer tactique, blessure, saignement, HIA et exclusion. |
| [4 — Équipement](https://passport.world.rugby/fr/les-regles-du-jeu/regles-du-jeu-par-numero/4-l-equipement-des-joueurs/) | Équipements conformes et contrôle de sécurité ; aucune protection dangereuse ni bijou. Ne pas inventer une obligation universelle à partir d'une recommandation ou d'une variation locale. |
| [5 — Temps](https://passport.world.rugby/fr/les-regles-du-jeu/regles-du-jeu-par-numero/5-duree-de-la-partie/) | Deux périodes de quarante minutes, arrêts de chronomètre et exceptions de fin de période. À 80 minutes le ballon n'est pas automatiquement mort : pénalité, transformation et remise en jeu déjà accordée peuvent prolonger la partie. |
| [6 — Officiels](https://passport.world.rugby/fr/les-regles-du-jeu/regles-du-jeu-par-numero/6-officiels-de-match/) | L'arbitre contrôle temps, score, sécurité et entrées ; assistants et vidéo interviennent selon leurs compétences et le protocole disponible. Une pause du manager n'est pas une autorisation arbitrale de changement. |
| [7 — Avantage](https://passport.world.rugby/fr/les-regles-du-jeu/regles-du-jeu-par-numero/7-l-avantage/) | Avantage tactique ou territorial réel ; sinon retour à la faute. Conserver type et lieu de la faute. Aucun avantage lorsque poursuivre serait dangereux. |
| [8 — Score](https://passport.world.rugby/fr/les-regles-du-jeu/regles-du-jeu-par-numero/8-etablissement-du-score/) | Essai 5, transformation 2, pénalité et drop 3. Essai de pénalité 7 sans transformation ; sanction personnelle appropriée. La transformation dépend du point d'essai et doit respecter son délai. |
| [9 — Jeu déloyal](https://passport.world.rugby/fr/les-regles-du-jeu/regles-du-jeu-par-numero/9-jeu-deloyal/) | Obstruction, fautes répétées, plaquages dangereux et déblayages illégaux. Distinguer sanction de jeu et sanction personnelle. La gravité d'un contact à la tête ne peut être remplacée par un tirage de carton sans motif. |
| [10 — Hors-jeu](https://passport.world.rugby/fr/les-regles-du-jeu/regles-du-jeu-par-numero/10-hors-jeu-et-en-jeu-dans-le-jeu-courant/) | Joueur devant le dernier coéquipier ayant joué le ballon potentiellement hors-jeu ; participation et remise en jeu encadrées. Après un coup de pied, appliquer aussi le repli des dix mètres ; une simple réception adverse ne remet pas tout le monde en jeu. |
| [11 — En-avant](https://passport.world.rugby/fr/les-regles-du-jeu/regles-du-jeu-par-numero/11-en-avant-ou-passe-en-avant/) | En-avant ou passe avant involontaire : mêlée adverse sauf avantage ou option prévue. Volontaire : pénalité, éventuellement carton/essai de pénalité. Un contre n'est pas un en-avant. |
| [12 — Envois et renvois](https://passport.world.rugby/fr/les-regles-du-jeu/regles-du-jeu-par-numero/12-coup-d-envoi-et-renvois/) | Coup d'envoi en drop, dix mètres à atteindre sauf jeu adverse ; après un score, renvoi par l'équipe qui l'a encaissé. Distinguer renvoi aux 22 et sur ligne d'essai selon l'origine et la fin du ballon. |
| [13 — Joueurs au sol](https://passport.world.rugby/fr/les-regles-du-jeu/regles-du-jeu-par-numero/13-joueurs-au-sol-dans-le-jeu-courant/) | Le jeu se dispute debout. Au sol avec le ballon : le jouer, le libérer ou se relever immédiatement ; sans ballon : ne pas intervenir. Ne pas tomber sur un joueur au sol. |
| [14 — Plaquage](https://passport.world.rugby/fr/les-regles-du-jeu/regles-du-jeu-par-numero/14-le-plaquage/) | Porteur tenu et amené au sol ; plaqueur libère et s'écarte/se relève, plaqué rend immédiatement le ballon disponible. Contestants debout et venant de leur côté. Un plaquage n'est pas encore nécessairement un ruck. |
| [15 — Ruck](https://passport.world.rugby/fr/les-regles-du-jeu/regles-du-jeu-par-numero/15-le-ruck/) | Au moins un joueur de chaque équipe, debout, en contact au-dessus du ballon au sol. Lignes de hors-jeu, entrée régulière et liaison. Pas de mains après formation, sauf prise préalable régulière maintenue debout. Respecter la sortie après « jouez ». |
| [16 — Maul](https://passport.world.rugby/fr/les-regles-du-jeu/regles-du-jeu-par-numero/16-le-maul/) | Porteur debout lié à au moins un partenaire et un adversaire. Entrée par sa ligne de hors-jeu et liaison ; interdiction d'écrouler. Blocage, premier/deuxième arrêt et disponibilité déterminent la suite ; l'introduction après échec comporte des exceptions. |
| [17 — Marque](https://passport.world.rugby/fr/les-regles-du-jeu/regles-du-jeu-par-numero/17-le-marque/) | Réception de volée d'un coup de pied adverse dans ses 22/en-but et annonce simultanée : arrêt et coup franc. Pas sur coup d'envoi ni renvoi après score. |
| [18 — Touche](https://passport.world.rugby/fr/les-regles-du-jeu/regles-du-jeu-par-numero/18-touche-remise-en-jeu-rapide-et-alignement/) | Identifier dernier contact, touche directe/indirecte, origine dans les 22 et pénaltouche. Le 50:22 régulier conserve le lancer après sortie indirecte, sous conditions d'origine. Touche rapide et alignement ont des contraintes distinctes ; ne pas inventer le lanceur. |
| [19 — Mêlée](https://passport.world.rugby/fr/les-regles-du-jeu/regles-du-jeu-par-numero/19-la-melee-ordonnee/) | Cause et emplacement identifiés, premières lignes qualifiées, séquence d'engagement, stabilité avant introduction. Poussée droite ; sanctions selon faute. Non-participants à cinq mètres, demi adverse soumis à sa règle spécifique. Un effondrement dangereux impose l'arrêt immédiat. |
| [20 — Pénalité / coup franc](https://passport.world.rugby/fr/les-regles-du-jeu/regles-du-jeu-par-numero/20-penalite-et-coup-franc/) | Ce sont deux sanctions différentes. Pénalité : poteaux, touche, jeu rapide ou mêlée selon règles. Ne pas proposer automatiquement une mêlée sur coup franc. Repli adverse à dix mètres. |
| [21 — En-but](https://passport.world.rugby/fr/les-regles-du-jeu/regles-du-jeu-par-numero/21-l-en-but/) | Distinguer essai aplati, ballon tenu sans aplatir, touché défensif, touche de but et ballon mort. La reprise dépend notamment de qui a amené le ballon dans l'en-but et du type de coup de pied ; aucun renvoi générique ne couvre tous les cas. |

## Points sensibles vérifiés

**Première ligne et remplacements — loi 3.** Une famille de poste n'est pas une
qualification. Pilier gauche, droit et talonneur doivent être identifiés. Un
carton peut obliger un autre joueur à sortir pour faire entrer un spécialiste.
À défaut, appliquer la procédure des mêlées non disputées et son effectif selon
le motif ; ne pas supprimer artificiellement les cartons des premières lignes.
Les remplacements temporaires ont leurs propres délais en temps réel, distincts
du temps de jeu des exclusions.

**Retours français : source datée, reconfirmation de saison nécessaire.**
La [clarification FFR du 13 septembre 2025](https://formation.ffr.fr/sites/default/files/documents/doc/2025-10/QRCODE%20Retour%20en%20jeu%20des%20joueurs%20remplac%C3%A9s%20tactiquement%20pdf.pdf)
autorise quatre retours supplémentaires pour tout motif dans le secteur
professionnel, outre les cas particuliers sans décompte : saignement, HIA,
blessure par jeu déloyal validée, ajustement de première ligne et remplacement
après rouge de vingt minutes. Ce n'est ni « huit permutations maximum » ni un
retour illimité. Le document est de 2025 : confirmer les dispositions 2026/27
avant de coder ce quota pour cette saison. La FFR annonce des changements
2026/27 dans son [avis 1172](https://amp.www.ffr.fr/actualites/avis-hebdomadaire-n1172),
mais le texte consolidé des dispositions spécifiques n'a pas été récupéré ici.

**Cartons — [directive officielle](https://passport.world.rugby/fr/les-regles-du-jeu/directives-sur-l-application-des-regles/mise-en-oeuvre-du-carton-rouge-de-20-minutesdefinitif-aout-2025/).**
Jaune : dix minutes de jeu. Un joueur exclu sur rouge ne revient jamais lui-même.
Le rouge autorisant un remplacement permet à un autre joueur disponible d'entrer
après vingt minutes de jeu. Deux jaunes relèvent de ce mécanisme ; un second
incident très dangereux et intentionnel peut relever du rouge sans remplacement.
Le rouge sans remplacement demeure donc distinct. Ne pas transformer tous les
rouges en retours collectifs après vingt minutes, ni tous en infériorité jusqu'à
la fin. Prévoir le protocole d'examen réellement retenu par la compétition.

**Compétition française — [LNR Livre 2, 2026/27, consolidé au 1 juillet 2026](https://assets.lnr.fr/3/0/4/6/9/8/LIVRE-2_Sportif-et-Comp%C3%A9titions_2627_V2_703069b00e686885076f1b627c8c5441.pdf).**
Art. 2031 : victoire 4, nul 2, défaite 0 ; bonus offensif à trois essais d'écart,
défensif à cinq points d'écart au maximum. Art. 2034 : égalité départagée par
points des confrontations, différence générale, différence des confrontations,
différence d'essais des confrontations, différence générale d'essais, points
marqués, essais marqués, forfaits puis rang de saison précédente. Appliquer
successivement aux équipes restant concernées. Les prolongations et mesures administratives nécessitent leurs articles propres avant
implémentation. Accession et relégation : voir la section « Classement, phases finales,
accession et relégation — saison 2026/27 (19/11/2026) » ci-dessous ; une pénalité décisive aléatoire n'est pas une procédure officielle.

## Classement, phases finales, accession et relégation — saison 2026/27 (19/11/2026)

Niveaux de preuve : règlement officiel, communiqué, presse, Wikipédia. Les règlements détaillés et leurs URL sont aussi dans `docs/world-competition-rules-20261109.md`.

| Compétition (id) | Clubs | Qualifiés et phases finales | Barrage | Relégation / montée directe | Bonus | Ce que le jeu applique | Source |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Top 14 (`elite`) | 14 | 6 ; 1–2 en demi directe ; barrages 3–6 et 4–5 | Access Match : le finaliste de Pro D2 reçoit le 13e, match sec | 14e relégué | 3 essais d'écart / défaite ≤ 5 | Format complet (Access Match chez le finaliste de Pro D2) | [LNR Livre 2 2026/27](https://assets.lnr.fr/3/0/4/6/9/8/LIVRE-2_Sportif-et-Comp%C3%A9titions_2627_V2_703069b00e686885076f1b627c8c5441.pdf) — LNR — 2026 — règlement officiel |
| Pro D2 (`accession`) | 16 | Même format que le Top 14 | Access Match (finaliste) ; 15e joue un barrage chez le finaliste de Nationale le 30/05/2027 | Champion monte ; 16e descend en Nationale | 3 essais d'écart / défaite ≤ 5 | Access Match, barrage 15e/Nationale, montée et descente | Livre 2 (ci-dessus) ; point du 15e : [Dicodusport](https://dicodusport.fr/blog/narbonne-et-nice-sur-un-fil-beziers-et-biarritz-en-danger-les-clubs-concernes-par-la-lutte-pour-le-maintien-en-pro-d2-2026-2027/) — 2026 — presse ; [livret FFR Nationale 2025/26](https://api.www.ffr.fr/wp-content/uploads/2025/08/2025-2026_nationale_livret-de-la-competition.pdf) — FFR — 2025 — officiel, saison précédente |
| Nationale (`nationale`) | 14 | 1–2 en demi (chez eux) ; barrages 3–6 ; finale en terrain neutre | Le finaliste reçoit le 15e de Pro D2 | Champion monte en Pro D2 ; aucune relégation en Nationale 2 en 2026/27 (16 clubs en 2027/28) | 3 essais d'écart / défaite ≤ 7 | Montée, barrage, pas de descente | [Wikipédia](https://fr.wikipedia.org/wiki/Championnat_de_France_de_rugby_à_XV_de_Nationale_2026-2027) — modifié 14/11/2026 — Wikipédia ; [Rugby Amateur](https://rugbyamateur.fr/nationale-2026-2027-clubs-saison-sans-relegation/) — presse ; [Itsrugby](https://itsrugby.fr/nationale-2026-2027-saison-sans-relegation-reforme-ffr/) — 19/08/2026 — presse |
| Gallagher PREM (`prem`) | 10 | 4 ; demies 1–4 et 2–3 chez 1 et 2 ; finale | Aucun | Aucune relégation automatique fin 2026/27 (décision RFU du 27/02/2026) | 4 essais marqués / défaite ≤ 7 | Format complet, sans descente | [RFU, règlement PREM 2026/27](https://rfu.widen.net/s/bpmdldld6m/prem-rugby-league-regulations-2026-27) — RFU — 2026 — règlement officiel |
| Champ Rugby (`champ`) | 14 | 6 ; 1–2 en demi ; quarts 3–6 et 4–5 | Réel : 12e contre 13e en match sec, le perdant contre le 2e de National League 1 | Pas de montée en PREM en 2026/27 ; réel : 14e relégué en National League 1 | 3 essais d'écart / défaite ≤ 7 | Phases finales ; ni montée ni descente | [Règlement RFU §3.2](https://rfu.widen.net/s/x2dmh2dxjn/champ-rugby-league-competition-regulations-2026-27) — officiel ; relégation : [Wikipédia](https://en.wikipedia.org/wiki/2026–27_Champ_Rugby) citant The Times, 23/05/2026 |
| URC (`urc`) | 16 | 8 ; quarts 1–8, 2–7, 3–6, 4–5 | Aucun | Ligue fermée | 4 essais marqués / défaite ≤ 7 | Format 2025/26 en repli (2026/27 non publié) | [URC 2025/26](https://d19fc3vd0ojo3m.cloudfront.net/irfu/wp-content/uploads/2025/09/26090041/001.-Championship-Rules-25_26__CLEAN.pdf) — URC — 2025 — règlement officiel |
| Super Rugby Pacific (`srp`, saison 2027) | 10 | 6 ; 3–6 et 4–5 chez 3 et 4 ; demies : 1 contre le moins bien classé des vainqueurs, 2 contre l'autre ; finale chez le mieux classé | Aucun | Ligue fermée ; 17 journées dont 1 exempte | 3 essais d'écart / défaite ≤ 7 (non confirmé pour 2027) | Format 2027 | [Phases finales](https://www.rugby.com.au/news/expanded-season-singleelimination-finals-confirmed-for-2027-super-rugby-pacific-season-2026630) — 01/07/2026 — communiqué ; [départ de la 11e franchise](https://www.rugby.com.au/news/new-zealand-rugby-confirm-moana-pasifikas-2027-super-rugby-pacific-departure-ten-team-competition-2026623) — 23/06/2026 — communiqué |
| League One D1 (`jlo-d1`) | 12 (18 matchs) | 6 ; 1–2 en demi | 11e contre 2e de D2, 12e contre 1er de D2, deux manches (format 2025/26) | Via barrage | 3 essais d'écart / défaite ≤ 7 | Format officiel 2025/26 reconduit | [League One, 01/07/2026](https://league-one.jp/en/news/197) — communiqué ; [format 2025/26](https://league-one.jp/news/4669) — officiel ; [Rugby Republic](https://rugby-rp.com/2026/08/06/domestic/145178) — 06/08/2026 — presse |
| League One D2 (`jlo-d2`) | 8 (double aller-retour) | Selon le format D2 | Contre D1 (ci-dessus) ; barrage D2/D3 non joué | Pas de descente dans la carrière (D3 de 7 clubs non jouée) | 3 essais d'écart / défaite ≤ 7 | Montée par barrage ; pas de descente | Mêmes sources que D1 |
| Champions Cup (`champions`) | 24 (4 poules de 6) | 3 premiers + 4 meilleurs restants en huitièmes ; 4 suivants en Challenge | Aucun | Sans objet | 3 essais d'écart / défaite ≤ 7 | Format complet | [Règlement EPCR 2026/27](https://www.epcrugby.com/champions-cup/champions-cup-rules) — EPCR — 2026 — officiel |
| Challenge Cup (`challenge`) | 18 (3 poules de 6) | 12 : 3 premiers + 3 meilleurs restants, plus 4 reversés de Champions | Aucun | Sans objet | 3 essais d'écart / défaite ≤ 7 | Format complet | [Règlement EPCR 2026/27](https://www.epcrugby.com/challenge-cup/reglement-ecc) — EPCR — 2026 — officiel |

**Affichage.** Le classement montre ces zones par liseré, symbole et mot : ★ demi-finale directe, ● phase finale, ▲ barrage de montée, ◆ barrage de maintien, ▼ relégation, ○ repêchage possible. Une note « pas de relégation » apparaît quand il n'y en a pas.

### Écarts assumés du jeu

- Champ : la National League 1 n'est pas jouée, donc ni descente ni barrage de maintien, malgré la règle réelle.
- Japon : la D3 n'est pas jouée, donc pas de descente de D2.
- Nationale : aucune relégation, conforme à 2026/27.
- Japon : le format des barrages 2025/26 est reconduit, faute d'annonce 2026/27.
- Nationale : le barrage avec le 15e de Pro D2 est conservé, même si une réforme pourrait le supprimer.

### Points non confirmés

- Livret FFR Nationale 2026/27 introuvable ; le jeu s'appuie sur la presse et Wikipédia.
- Convention FFR/LNR du 04/02/2026 ([synthèse](https://api.www.ffr.fr/wp-content/uploads/2026/02/synthese-convention_ffr-lnr-1-1.pdf), non lue) : deux montées et descentes directes sans barrage ; date d'effet (2026/27 ou 2027/28) contestée dans la presse.
- Barrage du 15e de Pro D2 : Livre 2 non relu sur ce point.
- Relégation réelle du Champ : règlement RFU §3.2 non relu sur ce point.
- Playoffs League One D1 : Wikipédia japonais dit l'inverse du communiqué officiel ; le communiqué prime. Matchs de remplacement 2026/27 non annoncés.
- Bonus du Super Rugby Pacific 2027 et règlement URC 2026/27 non publiés.

## Actualité des textes à ne pas manquer

- [Juillet 2026](https://passport.world.rugby/laws-of-the-game/whats-new/2026-07-law-updates/) : pied frein, dispositions élite sur porteurs d'eau, remplacement après rouge de vingt minutes et rôle du TMO intégrés aux lois. Application aux nouvelles compétitions après le 1 juillet ; vérifier les compétitions déjà commencées. Certains renvois d'en-but changent également.
- [Maul, juin 2026](https://passport.world.rugby/laws-of-the-game/whats-new/2026-06-law-application-guideline-players-on-the-wrong-side-of-the-maul/) : le joueur dépassé par le ballon, sorti de la contestation et gênant du mauvais côté doit quitter le maul ; directive d'application, pas nouvelle définition du maul.
- [Précision 2-2026](https://passport.world.rugby/laws-of-the-game/law-clarifications/2026/clarification-2-2026/) : les actions du demi pour sortir le ballon du ruck s'apprécient aussi au regard de la continuité, uniquement lorsque la contestation est clairement terminée. Ne pas pénaliser mécaniquement toute manipulation de sortie.
- [Knee-drop, 5 octobre 2026](https://passport.world.rugby/laws-of-the-game/law-application-guidelines/dangerous-tackles-october-2026/) : distinction entre se mettre au sol avant de plaquer et contact simultané non dangereux ; les lois 13 et 9 restent déterminantes.
- [Hip-drop, 1 novembre 2026](https://passport.world.rugby/laws-of-the-game/whats-new/2026-11-law-change-hip-drop-tackles/) : amendement annoncé mais encore futur à la date de cet audit. Ne pas antidater son libellé.
- Les seuils de plaquage amateur approuvés en 2026 ne s'appliquent pas automatiquement au secteur professionnel.

## Audit du moteur actuel — constats, pas corrections effectuées

| Priorité | Emplacement | Problème et travail nécessaire |
| --- | --- | --- |
| 1 | `rugby.js` : `makeSub`, `liveSubPanel` ; `opposition.js` : `manageSubstitutions` | Retour interdit dès qu'un joueur figure dans `used`, plafond global de huit permutations et sortant absent du banc. Remplacer par statuts/motifs et compteurs réglementaires vérifiés pour la saison. |
| 1 | `rugby.js` : `awardPenalty` | Deux jaunes : poste vidé définitivement, sans possibilité de remplacement après vingt minutes. Cartons directs et motifs absents. |
| 1 | `rugby.js` : `awardPenalty` | Filtre `fam >= 2` évite les cartons de première ligne. Ajouter procédure de spécialiste et mêlées non disputées plutôt que protéger ces postes. |
| 1 | `rugby.js` : `advanceRugby`, `contestSetPiece` | Mêlées/touches tirées au sort sans faute ou sortie préalable. Une faute de main peut produire un simple changement de possession. Construire des états et reprises avec une cause explicite. |
| 1 | `rugby.js` : `awardPenalty`, `scoreTry` | Après tentative de pénalité, ballon/possession replacés génériquement ; après essai, renvoi réduit à une inversion. Représenter les différentes reprises et leurs options. |
| 2 | `rugby.js` : `advanceRugby` | Arrêt automatique à 40/80, puis éventuelle pénalité gagnante aléatoire. Ajouter ballon mort, exceptions de fin de période et vraie procédure de départage. |
| 2 | `game.js` : `ranked` | Points puis différence générale directement : manque le premier critère des confrontations et les critères suivants. |
| 2 | Moteur de phases | Ruck, maul, avantage, hors-jeu, 50:22, marque, drop et essai de pénalité insuffisamment représentés ou absents. Une abstraction doit conserver les conséquences réglementaires observables. |
| 3 | Compétition / effectifs | Accession-relégation : documentées le 19/11/2026 (section « Classement, phases finales, accession et relégation »). JIFF, sélections internationales, qualifications et discipline après match restent à documenter et modéliser. Ne pas annoncer ces sujets comme déjà maîtrisés/implémentés. |

Le calcul de base des bonus est cohérent avec le texte vérifié. Les probabilités,
attributs, météo, fatigue et tactiques sont des choix de simulation : aucune loi
ne donne un pourcentage de victoire en mêlée ou d'essai par minute.

## Vérification avant toute correction

Pour chaque règle modifiée : noter source, édition, compétition, date d'effet,
événement déclencheur, équipe bénéficiaire, position de reprise, temps et effectif.
Écrire des scénarios issus du texte, y compris exceptions pertinentes ; ne pas
se contenter de figer l'ancien moteur dans des tests de régression. Prévoir la
migration des matchs en cours et distinguer correction faite et règle seulement
documentée. Reprendre d'abord les erreurs de priorité 1 ; aucune nouvelle couche
de gestion n'est nécessaire pour cette phase.


## État après le premier lot de corrections — version 7

Le tableau d'audit ci-dessus reste le constat historique sur `88da449`.
Les nouveaux matchs utilisent désormais un profil limité aux changements et au
remplacement après exclusion, édition professionnelle française 2025/26. Les
sources FFR septembre 2025 et World Rugby août 2025 de cette note fondent ce
choix ; la conformité 2026/27 reste à confirmer. Ce profil demeure fixe pendant
la carrière fictive et n'annonce pas l'application exhaustive des 21 lois.

Corrigés : banc conservant les sortants, quatre retours tactiques distincts des
premières entrées, remplacement après vingt minutes après second jaune,
exclusion individuelle définitive, timing de dix minutes du jaune, mêmes
contrôles pour les deux équipes, persistance et validation des compteurs.
Les rencontres déjà engagées sans ce profil terminent sous l'ancien modèle.

Restent prioritaires : exclusions de première ligne et mêlées non disputées,
puis causes et reprises des phases. Les HIA/saignements, blessures en match,
rouges directs pour jeu déloyal et autorisations sur ballon mort ne sont pas
encore simulés. Le moteur distingue en interne un rouge sans remplacement,
mais ne génère pas encore ces incidents. Voir README.md et
`tests/match-rules.cjs` pour le périmètre réellement vérifié.


## État après le deuxième lot — version 8

Sources de ce lot : loi 3.13–3.20 et [grille World Rugby d’août 2025](https://passport.world.rugby/media/gfshsk2b/uc-scrums-2025-fr.png), consultées le 29 octobre 2026.
Les premières lignes ne sont plus protégées des cartons dans les nouveaux
matchs. À la prochaine mêlée, un spécialiste entre contre la sortie désignée par
le staff. Une carence impose des mêlées non disputées et le retrait supplémentaire
prévu ; reprise de la contestation dès qu'une première ligne qualifiée revient.
La grille a notamment servi aux scénarios de deux rouges temporisés au même
poste : douze joueurs, puis treize, puis quatorze après leurs périodes si aucun
spécialiste ne reste disponible. L'introduction non disputée est conservée, sans
poussée ni gain. Les retours réglementaires restent hors quota tactique.

La procédure est automatique pour les deux équipes. Les blessures, HIA et
saignements ne sont pas encore simulés. Les anciennes rencontres sans
`frontRowVersion: 1` conservent leur ancien comportement. Voir les scénarios de
`tests/frontrow.cjs` ; prochaine priorité : causes des mêlées/touches et reprises.


## État après le troisième lot — version 9, 30 octobre 2026

Édition de référence : [livre World Rugby 2025](https://passport.world.rugby/media/dafo2cbl/2501en-world-rugby-laws-2025-compressed.pdf), avec consultation des lois 12, 18, 19 et 21 pour les cas inchangés. Les nouveaux cas introduits en juillet 2026 ne sont pas appliqués au profil fixe 2025/26.

Les nouveaux matchs lient les mêlées et touches à un événement explicite,
conservent le bénéficiaire et la marque, distinguent faute de main et récupération,
et séparent le botteur d'un renvoi de l'équipe qui réceptionne. Les pénalités
manquées ne replacent plus génériquement le ballon au centre. Les cas d'en-but
sont résolus selon leur origine. L'état des droits au gain en touche/50:22 et les
faits des reprises sont conservés et contrôlés à l'import.

Le moteur reste une succession de séquences atomiques à la minute : avantage,
chronomètre fin, ballon mort autorisant les changements, exceptions de fin de
période et prolongations réglementaires constituent les prochaines corrections.
Les anciennes rencontres sans `restartVersion: 1` conservent leur ancien modèle.
Voir `tests/restarts.cjs` et le périmètre détaillé du README.


## État après le quatrième lot — version 10, 30 octobre 2026

Sources de ce lot : [World Rugby, loi 5 — Durée](https://passport.world.rugby/fr/les-regles-du-jeu/regles-du-jeu-par-numero/5-duree-de-la-partie/) et [loi 7 — Avantage](https://passport.world.rugby/fr/les-regles-du-jeu/regles-du-jeu-par-numero/7-l-avantage/), consultées pour le profil fixe 2025/26.

La loi 5 lie la fin de période au ballon mort et prévoit des exceptions pour les reprises encore dues, pénalités, pénaltouches et la suite d’un essai. Les nouveaux matchs laissent donc jouer après le temps écoulé et conservent quarante minutes pour chaque mi-temps. Le journal distingue les périodes et le temps dépassé. Les reprises restent atomiques : toutes les reformations et procédures de remise en jeu ne sont pas simulées.

La loi 7 exige un bénéfice territorial ou tactique réel ; sinon, retour à la faute initiale. Le moteur conserve désormais cette sanction et sa marque, traite une faute du bénéficiaire et les fautes répétées, et exclut les situations dangereuses couvertes. Les seuils de mètres et de séquences sont une politique fictive d’arbitrage, pas une prescription réglementaire.

La vue 2D représente les joueurs réellement présents, avec des positions et trajectoires indicatives. Elle ne produit aucun résultat sportif. `tests/matchflow.cjs` et `tests/match2d.cjs` couvrent ces ajouts. Les anciennes rencontres sans `flowVersion: 1` restent inchangées jusqu’à leur fin. Les prolongations réglementaires, le chronomètre fin, les changements sur ballon mort et les procédures médicales restent à traiter ; aucune conformité complète n’est revendiquée.


## Présentation des actions — version 12, 30 octobre 2026

Ce lot ne modifie pas les dispositions réglementaires : il enregistre les faits des actions produites par le moteur existant et synchronise le terrain 2D, le journal, le score et l’horloge affichés. Les séquences restent atomiques à la minute ; l’essai et sa transformation sont encore un seul événement. Les pauses du manager restent une abstraction et ne constituent pas une nouvelle autorisation arbitrale sur ballon mort. Les positions latérales et formations sont schématiques. Les anciennes actions sans enregistrement spatial ne sont pas reconstruites a posteriori.


## Consignes tactiques — version 13, 30 octobre 2026

Ce lot ajoute des politiques de simulation, sans modifier les lois ou le profil réglementaire 2025/26. Les probabilités de réussite, gains de terrain, fautes de main, fautes défensives et fatigue dépendent des plans et des qualités disponibles pour les deux équipes. Les paramètres sont fictifs et mesurés dans `tests/tactical-plans.cjs` ; ils ne sont pas des pourcentages tirés des lois du rugby. Les reprises restent résolues par le moteur causal existant, et les changements en pause gardent leur abstraction d’autorisation déjà documentée. Les formations 2D sont schématiques ; aucune conformité physique des lignes de hors-jeu n’est revendiquée. Les matchs sans `tacticalVersion: 1` conservent leur ancien calcul jusqu’à leur fin.


## Politiques par zone et conquête — version 14, 30 octobre 2026

Ce lot conserve le profil réglementaire fixé pour 2025/26. Les quatre zones, les choix de mêlée/touche et leurs coefficients de conservation, gain et finition sont des politiques fictives de simulation. Un renvoi court au centre parcourt 10 à 14 mètres dans cette abstraction ; le minimum de dix mètres est conservé (loi 12, source déjà référencée). Le choix ne modifie ni les renvois aux 22 ni les drops de ligne d’essai. Les mêlées non disputées restent sans poussée, gain ou contest de l’introduction et passent avant tout coefficient tactique. Les matchs sans `playbookVersion: 1` gardent leurs anciens calculs. Le carnet ne prétend pas simuler les combinaisons joueur par joueur, les secondes exactes ni toutes les infractions de conquête.


## Rapports et suivi des consignes — version 15

Ce lot ne modifie aucune loi, disposition de compétition ou probabilité sportive. Les projections et recommandations sont des outils de gestion fictifs fondés sur les qualités de la carrière. Le suivi est observationnel, sans consommation de tirages aléatoires. Les résultats par plan sont attribués à la consigne effective au début de chaque minute simulée ; un changement de possession peut intervenir ensuite. Ils ne constituent ni une simulation physique détaillée ni une preuve de causalité. Le profil réglementaire 2025/26 et le comportement des matchs déjà commencés restent conservés.

## Carrière native France30 — format 2026–2027, réception du 7 novembre 2026

Le mode natif `france30` possède ses calendriers, classements et transitions propres. Le format retenu se réfère au [Livre II sportif LNR 2026–2027, version du 1er juillet 2026](https://assets.lnr.fr/3/0/4/6/9/8/LIVRE-2_Sportif-et-Comp%C3%A9titions_2627_V2_703069b00e686885076f1b627c8c5441.pdf), notamment aux articles 2005–2013, 2034 et 2085. La source et le schéma sont détaillés dans le plan France reliée ; les départages par groupes, les phases finales et les deux issues du barrage sont vérifiés dans les tests `france-rules`, `france-knockout` et `france-transitions`.

Cette édition de compétition ne remplace pas le profil de lois de match `fr-pro-2025` du moteur existant. Les prolongations utilisent ce même moteur. Les drops et les exclusions de staff ne sont pas produits par la simulation actuelle ; leur présence dans un ordre de départage ne signifie pas que ces événements sont implémentés. Les tirs sont résolus atomiquement, avec buteurs choisis automatiquement ; pas de sauvegarde au milieu d'une tentative.

Abstractions déclarées : monde fermé à trente clubs sans Nationale, cadence commune de 34 semaines et calendrier sans dates réelles. Les calendriers générés suivent des tables de Berger avec alternance (au plus deux réceptions ou deux déplacements de suite, retour en miroir de l’aller) ; l’ordre des journées n’est pas celui du calendrier LNR publié ([détail](calendrier-alternance-20261111.md)). À égalité encore indiscernable après les critères disponibles, la convention de classement antérieur puis d'ID stable reste une convention du jeu. Aucun forfait administratif ni conformité intégrale du rugby 2026–2027 n'est annoncé. Le stade 3D conserve des dimensions de présentation ; il ne certifie ni une enceinte réelle ni sa conformité réglementaire.

Le [rapport de réception natif](godot-carriere-20261107.md) distingue les tests moteur, les sauvegardes et la réception graphique Windows. Les modes historiques restent séparés : aucune conversion automatique fiction14/LNR14 vers France30.

## Protocole commotion (HIA) — carrière Monde, 18 novembre 2026

Règles World Rugby du rugby d'élite en vigueur depuis le 1er juillet 2022
([communiqué](https://www.world.rugby/news/726094), [suite](https://www.world.rugby/news/730239),
[détail SA Rugby 2022](https://www.sarugby.co.za/media/lg0owndp/changes-to-return-to-play-guidelines-following-concussion-explained-for-elite-hia-tournaments-only-2022.pdf)),
appliquées aux 116 clubs (`native/engine/club-support.cjs`) :

- signes évidents (critère 1) : sortie définitive immédiate, remplacement normal ;
- choc suspect : HIA1 de 12 minutes hors du terrain, remplacement temporaire
  hors quota tactique (comme la clarification FFR ci-dessus) ; retour s'il passe
  le test, sinon le remplaçant reste ;
- diagnostic après le match (HIA2 le soir, HIA3 à 36-48 h) : 12 jours de repos
  au moins, comptés en jours de calendrier ; exception au 7e jour seulement sans
  antécédent (moins de 3 mois, 3 commotions sur 12 mois nouvelle comprise,
  5 en carrière), hors critère 1, HIA3 revenu à la normale et avis favorable
  d'un spécialiste indépendant. Décision médicale : aucun protocole générique.
- Proportions : Fuller et al., Sports Medicine 2020
  ([texte](https://eprints.whiterose.ac.uk/155999/)). Fréquence : hypothèse
  prudente de 0,9 choc évalué par match (≈ 0,52 commotion confirmée par match,
  ≈ 13 pour 1 000 heures-joueur). Non publiés, réglés à une chance sur deux :
  HIA3 normal, avis favorable du spécialiste.
- Non suivis : récupération de plus de 21 jours, seuil d'impact abaissé,
  troubles psychologiques (autres cas d'antécédent du SCRM). Un joueur sans
  remplaçant éligible à son poste n'est pas tiré au sort pour un choc.

## Chrono des arrêts de jeu (18/11/2026)

Vérifié le 18/11/2026 ; détail et mesures dans `docs/chrono-arrets-de-jeu-20261118.md`.

- Loi 8.21 ([loi 8](https://passport.world.rugby/laws-of-the-game/laws-by-number/8-scoring/)) :
  pénalité tentée au but dans les 60 s (temps de jeu) après l'annonce du tir,
  sinon tir refusé et mêlée.
- Loi 8.8c : transformation dans les 60 s (temps de jeu) après l'essai accordé.
  C'était 90 s jusqu'en 2024 ; 60 s est un essai mondial de World Rugby
  ([essais du 1er janvier 2025](https://passport.world.rugby/laws-of-the-game/laws-news/2025-01-global-law-trials/)),
  repris dans le texte en ligne des lois.
- Top 14 2026-2027 (LNR) : 45 s pour pénalités et transformations, chrono lancé
  au bras levé de l'arbitre (annonce du calendrier 2026-2027 et mesures LNR
  pour le temps de jeu effectif). Pro D2 : non vérifié, gardé à 60 s.
- Loi 18.12 : alignement formé dans les 30 s après la marque ; mêlée prête dans
  les 30 s (directives de 2023).
- Temps de jeu effectif réel (Opta, rapport World Rugby) : Top 14 ≈ 33,6 min en
  2025-2026 (34,5 en 2023-2024), Premiership ≈ 36,3 min (37,9), Super Rugby
  ≈ 36,8 min. Le moteur ne distingue pas encore ballon vivant et ballon mort
  dans une action : il ne prétend pas reproduire ce chiffre.
- Moteur (`chronoVersion: 1`) : tir au but et transformation comptés au délai
  de la compétition, plus la mise en place du renvoi ; pénaltouche : coup de
  pied en touche et alignement. Le renvoi après des points se joue au moment
  dû ; dû après la fin du temps réglementaire, il termine la période (loi 5).

## Fin de période et prolongations (19/11/2026)

Sources : [loi 5 — Durée](https://passport.world.rugby/fr/les-regles-du-jeu/regles-du-jeu-par-numero/5-duree-de-la-partie/)
(déjà citée pour la version 10 ; non relue ce jour) et loi 8 (pénalité tentée au but).

- Loi 5 : le temps écoulé, la période ne s'arrête qu'au ballon mort ; une
  pénalité ou un coup franc accordé avant ou à la fin du temps est joué. Le
  moteur le faisait déjà (`flowVersion: 1`) ; les rencontres créées avec
  `endPeriodVersion: 1` le disent : sirène annoncée une fois par période
  (mi-temps, fin du match, fin de chaque prolongation) si le ballon est vivant,
  rien si un renvoi était dû (ballon mort : la période s'arrête).
- Pénalité après la sirène : annoncée (« tente les poteaux pour la gagne »,
  « joue la pénaltouche, dernière action »). Choix de simulation, consigne
  « auto » seulement, dans la période qui décide du résultat : pas de tir au
  but si trois points ne changent rien, sauf pour aller chercher le bonus
  défensif ; les poteaux à moins de 40 m si trois points égalisent ou font
  gagner. La consigne du manager (points, touche, à la main) prime. Le tir
  réussi ou manqué et mort termine la période ; la pénaltouche est jouée.
- Prolongations des phases finales Monde (règlement de chaque compétition,
  inchangé) : horloge 80′–90′ puis 90′–100′ (arrêts de jeu « 90+2′ »),
  annonces de début et de fin de chaque période avec le score, sirène et fin
  sur ballon mort comme en temps réglementaire.
- Tirs au but : séance commentée tir par tir à partir de la preuve enregistrée,
  sans tirage ajouté ni changement du vainqueur ; critère de départage écrit en
  français (essais marqués, pénalités réussies, drops, exclusions, tirs au but).
- Non traité : coup franc après la sirène (le moteur n'en accorde pas), temps
  mort de l'arbitre, prolongation « mort subite » des règlements qui en
  prévoient une hors Pacific et Japon, chemin hérité hors Monde (« prolongation
  simplifiée »). `tests/fin-de-periode.cjs`.

## Arbitrage fin : touche, ruck, maul (19/11/2026)

Rencontres créées avec `arbitrageVersion: 1` (`dist/arbitrage.js`) ; les autres gardent leurs textes et statistiques.
Lois World Rugby en ligne relues pour le principe, numéros de sous-articles non recopiés ici.

- Chaque pénalité garde l'incident déjà tiré (fréquence, carton et `serious` inchangés) et reçoit une cause
  détaillée, choisie sans tirage, puis une famille comptée par équipe (`penaltyFamilies`, `penaltyCauses`) :
  - ruck ([loi 15](https://passport.world.rugby/fr/les-regles-du-jeu/regles-du-jeu-par-numero/15-le-ruck/)) :
    hors-jeu au ruck, entrée sur le côté, mains au sol (ballon joué à la main dans le ruck), ballon tenu une fois
    le ruck formé, ballon non libéré par le porteur (loi 14), scellement ;
  - maul ([loi 16](https://passport.world.rugby/fr/les-regles-du-jeu/regles-du-jeu-par-numero/16-le-maul/)) :
    écroulement (jamais attribué à l'équipe qui lance), entrée illégale par le côté ;
  - touche ([loi 18](https://passport.world.rugby/fr/les-regles-du-jeu/regles-du-jeu-par-numero/18-touche-remise-en-jeu-rapide-et-alignement/)) :
    obstruction dans l'alignement ;
  - mêlée (loi 19) : faute générique (écroulement, poussée non droite) ;
  - jeu courant (lois 9 et 10) : hors-jeu hors regroupement, obstruction, plaquage dangereux.
- Lancer pas droit (loi 18) : faute sans pénalité, l'adversaire choisit une touche ou une mêlée. Le moteur en fait
  environ une touche perdue sur cinq (taux de touches perdues inchangé), compte `lineoutNotStraight` et rend le
  ballon à l'adversaire sans rejouer de phase : il ne simule pas ce choix (une mêlée ajoutée changerait la
  fréquence des pénalités de mêlée). Le commentaire dit « récupère l'introduction » ou « rend le ballon ».
- Réserves : répartition entre causes fixée par le jeu (pas de statistique officielle par cause) ; la scène 3D
  d'un lancer pas droit reste celle d'une touche perdue.

## Combinaisons de phases arrêtées (23/11/2026)

Rencontres créées avec `combiVersion: 1` (`dist/playbook.js`) ; carnet sans combinaisons (clubs de l'ordinateur) : effets et tirages inchangés.

- Touche ([loi 18](https://passport.world.rugby/fr/les-regles-du-jeu/regles-du-jeu-par-numero/18-touche-remise-en-jeu-rapide-et-alignement/)) :
  l'équipe qui lance fixe le nombre de joueurs alignés (7, 5 ou 4 ici, au moins deux par équipe) ; l'adversaire peut
  en aligner moins, pas plus. Le contre (devant, fond, contrer le maul) ne change que la probabilité de conserver,
  les mètres et l'essai sur ballon porté ; aucun contact avant le saut n'est simulé.
- Mêlée ([loi 19](https://passport.world.rugby/fr/les-regles-du-jeu/regles-du-jeu-par-numero/19-la-melee-ordonnee/)) :
  le n° 8 peut ramasser le ballon au pied de la mêlée (« 8 qui part ») ; poussée défensive sur l'introduction
  adverse : plus de pénalités sifflées en faveur de l'équipe qui introduit. Mêlée non disputée : aucun effet (inchangé).
- Pénalité ([loi 20](https://passport.world.rugby/fr/les-regles-du-jeu/regles-du-jeu-par-numero/20-penalite-et-coup-franc/)) :
  poteaux, touche, jeu rapide ou mêlée au point de la faute (cause `penalty-scrum`), choisis avant le match par zone
  (dans les 22 adverses, 22-40 m, au-delà) ; « Selon le score » garde la décision du staff. Après la sirène, la règle
  de fin de période (loi 5) prime ; une consigne du direct autre que « Selon le contexte » prime sur le plan.
  Choix de simulation : une consigne figée répétée dans le match est lue par l'adversaire (pénaltouche, mêlée,
  jeu vite moins dangereux à chaque répétition).
- Renvoi ([loi 12](https://passport.world.rugby/fr/les-regles-du-jeu/regles-du-jeu-par-numero/12-coup-d-envoi-et-renvois/)) :
  le renvoi court parcourt toujours au moins dix mètres, quelle que soit la réception adverse.
- Coefficients fictifs, recalés par mesure sur des matchs simulés (aucune option dominante) ; ils ne sont pas tirés des lois.
