# Rugby Réel V16 — postes, calibration individuelle et profondeur réellement jouable

Audit sur copies de PR #389, base `cd419bce0ed15d6f0cf08389ffe387222cb0c364`. Main vérifié au départ : `712d0254ef738c1367fda486f8428d5a2569d1a8`. Réservations #73 : 6709095664, 6709190563, 6709211287 et 6709256272. Aucune fusion, READY ni commande de gate. Réception CI exacte publiée dans la PR et la passation #73 ; les anciens verts ne qualifient pas le nouveau commit.

## Résultat utile

**23 joueurs distincts approfondis : 16 discordances de première ligne et neuf dossiers individuels, avec deux joueurs communs.** Les 1592 fiches/30 clubs restent intacts. Douze postes natifs sont contredits précisément par une source officielle ; six profils V12 sont contredits au moins sur la spécialité pilier/talonneur. Ces ensembles se chevauchent sur quatre joueurs : **14 dossiers avec anomalie de poste confirmée**, deux encore secondaires. Les 16 discordances ne sont donc ni16 erreurs moteur prouvées, ni une validation des191 autres premières lignes.

Treize mappings exacts officiellement corroborés sont expérimentés sur copies. Trois restent quarantainés. Trois révisions individuelles de note sont des propositions provisoires de gameplay, six amplitudes +1/+2 ; neuf profils × trois doses signées produisent27 scénarios de sensibilité, pas27 erreurs confirmées. Aucune valeur physique exacte n’est présentée comme une mesure sportive.

Le gain principal est la correction du diagnostic : la note55 d’Akhaladze vient de son emploi au talon ; Fourcade et Narisia nécessitent également une reconstruction de profil36 attributs, pas seulement un nouveau libellé. La simulation longue antérieure omettait `trainWeek()` : blessures et fatigue ne récupéraient jamais en cours de saison. Ce protocole est désormais un contrôle négatif explicite.

## 16 discordances exhaustives

Lecture : « natif » est observé après `start(0,'lnr')`, « V12 » vient du tuple actif, « preuve » vient des sources numérotées ci-dessous. La LNR confirme le groupe `1ère ligne`, pas le poste précis. La copie « poste seul » garde les36 attributs/11 compétences initiaux ; elle modifie pos/fam/gameplayPosition pour les13 mappings officiels. La copie « projetée » recalcule les11 compétences sans réinventer les36 attributs.

| Joueur / ID | Club | Natif | V12 | Preuve précise | Note native → copie poste | Statut |
| --- | --- | --- | --- | --- | --- | --- |
| Barnabé MASSA / lnr:862 | clermont | Pilier gauche | Talonneur | Talonneur | 73 → 70 | official |
| Giorgi DZMANASHVILI / lnr:3233 | clermont | Talonneur | Pilier droit | Pilier droit | 61 → 78 | official |
| Giorgi AKHALADZE / lnr:184 | clermont | Talonneur | Pilier gauche | Pilier gauche | 55 → 69 | official |
| Noah TRAINI / lnr:13516 | clermont | Pilier droit | Pilier gauche | Talonneur | 68 → 55 | official |
| Nohem EZ ZAHOUANY / lnr:13531 | clermont | Pilier gauche | Talonneur | Pilier, côté inconnu | 72 → 72 | partial-prop-only |
| Mathéo FRISACH / lnr:655 | clermont | Talonneur | Pilier droit | Pilier gauche | 59 → 75 | official |
| Etienne FOURCADE / lnr:657 | clermont | Pilier droit | Pilier gauche | Talonneur | 77 → 61 | official |
| Cristian OJOVAN / lnr:694 | clermont | Pilier gauche | Talonneur | Pilier droit | 75 → 75 | official |
| Peniami Nasali NARISIA / lnr:2176 | clermont | Talonneur | Pilier droit | Talonneur | 56 → 56 | official |
| Tevita TATAFU / lnr:2674 | bayonne | Pilier gauche | Pilier droit | Pilier droit | 79 → 79 | official |
| Emosi TUMANIA / lnr:13650 | bayonne | Pilier droit | Pilier gauche | Pilier gauche | 73 → 73 | secondary-only |
| Ignacio CALLES / lnr:1885 | bayonne | Pilier droit | Pilier gauche | Pilier gauche | 71 → 71 | official |
| Emerick SETIANO / lnr:2349 | bayonne | Pilier gauche | Pilier droit | Pilier droit | 73 → 73 | official |
| Andy BORDELAI / lnr:2565 | bayonne | Talonneur | Pilier gauche | Pilier gauche | 58 → 72 | official |
| Facundo BOSCH / lnr:2658 | bayonne | Pilier gauche | Talonneur | Talonneur | 73 → 70 | official |
| Hugo GONZÁLEZ HERNÁNDEZ / lnr:13711 | bayonne | Talonneur | Pilier droit | Pilier gauche | 58 → 58 | secondary-only |

Nohem Ez Zahouany : club confirme pilier, donc V12 talonneur erroné, sans preuve que sa position native à gauche soit fausse. Tumania/González : indices secondaires de poste à gauche, non utilisés dans le correctif simulé. Narisia est déjà talonneur natif : sa discordance révèle surtout le profil V12 de pilier. Traini, Frisach, Fourcade et Ojovan montrent pourquoi recopier aveuglément le rôle V12 serait incorrect.

### Sources des postes et éléments sportifs

- **asm-roster** — [club, 2026-2027](https://www.asm-rugby.com/equipe/effectif) : Postes pilier/talonneur des professionnels ; ne précise pas systématiquement le côté.
- **asm-academy** — [club, 2026-2027](https://www.asm-rugby.com/asm-omnisports/asm-rugby-academy) : Traini talonneur, Ez Zahouany et Frisach piliers. Côté Ez Zahouany non établi.
- **asm-arrivals** — [club, 2024-06-11](https://www.asm-rugby.com/actus/2024-06-11-bilan-et-officialisations) : Akhaladze pilier gauche, Massa talonneur, Hamdaoui arrière.
- **asm-dz** — [club, 2026-2027](https://www.asm-rugby.com/equipe/joueurs/giorgi-dzmanashvili-pilier) : Dzmanashvili à droite avec Montagne et Ojovan ; prêt Biarritz2024-25,14 feuilles et7 titularisations. Stats courantes8 matchs/3 starts ne sont pas2025-26.
- **asm-fourcade** — [club, 2026-2027](https://www.asm-rugby.com/equipe/joueurs/etienne-fourcade-talonneur) : Fourcade talonneur, concurrence Massa et Narisia. Mobilité et jeu de combat décrits qualitativement.
- **asm-frisach** — [club, 2026-2027](https://www.asm-rugby.com/equipe/joueurs/matheo-frisach-pilier) : Frisach s’est spécialisé à gauche ; bonnes mains et mobilité. Sept rencontres à la découverte du Top14 dont une titularisation ; ne pas confondre avec5 matchs/1 start courants.
- **asm-ojovan** — [club, 2026-2027](https://www.asm-rugby.com/equipe/joueurs/cristian-ojovan-pilier) : Ojovan pilier ; côté droit corroboré par portrait club Dzmanashvili.
- **bay-roster** — [club, 2026-2027](https://www.abrugby.fr/equipe/effectif) : Tatafu et Setiano piliers droits, Calles et Bordelai piliers gauches, Bosch talonneur.
- **lnr-clermont** — [league, 2026-2027](https://top14.lnr.fr/club/clermont/effectif-staff) : Groupe première ligne ; insuffisant pour le côté ou talonneur.
- **lnr-bayonne** — [league, 2026-2027](https://top14.lnr.fr/club/bayonne/effectif-staff) : Groupe première ligne ; inclut les deux jeunes Tumania et González.
- **emosi-secondary** — [secondary-search-excerpt, 2026-2027](https://www.turnover-rugby.fr/nextgen/emosi-tumania) : Présenté comme pilier gauche. Extrait secondaire seulement ; pas de poste précis activable.
- **hugo-secondary** — [secondary-search-excerpt, 2026-2027](https://www.ultimaterugby.com/www.ultimaterugby.com/var/www/vhosts/ultimaterugby.com/app/public/index.php/bayonne/squad) : Présenté comme pilier gauche ; côté non corroboré officiellement dans ce cycle.
- **mhr-ngandebe** — [club, biographie-non-datee](https://www.montpellier-rugby.com/equipes/equipe-pro/joueurs/gabriel-ngandebe) : Le club décrit une vitesse distinctive et un parcours régulier ; ne mesure ni vitesse maximale ni accélération.
- **rct-tuicuvu** — [club, 2025-02-05](https://rctoulon.com/setariki-tuicuvu-toulonnais-jusquen-2028/) : Polyvalence centre/ailier/arrière, qualités défensives et finition ; prolongation2028. Discours promotionnel, aucune valeur technique mesurée.
- **rcv-bouthier** — [club, 2025-03-12](https://www.rugbyclubvannes.bzh/anthony-bouthier-officiellement-de-retour-au-rc-vannes-a-partir-de-la-saison-prochaine/) : Retour annoncé pour2025-26 ; arrière international8 sélections. Les minutes PRO D2 ne valent pas une performance TOP14 équivalente.
- **rcv-kalamafoni** — [club, 2026-02-02](https://www.rugbyclubvannes.bzh/sione-kalamafoni-prolonge-avec-le-rcv/) : Numéro8 international, porteur de balle et régularité ; prolongation2027. Ne justifie pas de restaurer la vitesse à38 ans.
- **ffr-fickou** — [federation, 2020-02-06](https://www.ffr.fr/actualites/xv-de-france/tournoi-des-6-nations-une-victoire-a-bonifier) : Responsabilité défensive documentée historiquement ; source ancienne, pas preuve de niveau physique en2026.
- **arata-secondary** — [sport-press-search-excerpt, 2024-10-06](https://www.americasrugbynews.com/2024/10/06/santiago-arata-scores-as-castres-upset-toulouse/) : Essai et victoire de Castres, demi de mêlée uruguayen. Un seul match ne justifie pas une note globale.

Les sources ont été consultées le07/11/2026. Les pages de club courantes confirment un rôle mais ne reconstituent pas toutes un instantané au01/07. Les statistiques courantes2026-27 et les titularisations actuelles sont séparées des historiques2023-26. Trois saisons d’une même page LNR restent une seule provenance indépendante. Les extraits secondaires sont explicitement moins probants qu’une page lue.

## Neuf décisions et corrections candidates

Les âges ci-dessous sont ceux de l’initialisation native au01/07/2026, conservateurs lorsque seule l’année est connue ; ils peuvent différer de l’âge actuel affiché par les sources. Les homologues ci-dessous sont les joueurs du même poste natif après les13 corrections de copie, pas des classements sportifs officiels. Les titularisations historiques ne sont pas disponibles dans les lignes LNR collectées : valeur inconnue, jamais déduite des minutes.

### Gabriel NGANDEBE — Note probablement trop faible

ID `lnr:1444`, montpellier, Ailier, âge simulé28, rating scalaire75, note au poste72, place automatique `depth`. 1950 minutes/8 essais après deux saisons >1000 minutes ; profil rapide corroboré par le club. Hausse limitée de qualités de finisseur, sans présenter de vitesse mesurée.

| Saison | Compétition | Club historique | Matchs | Minutes | Essais |
| --- | --- | --- | --- | --- | --- |
| 2025-2026 | TOP 14 | Montpellier Hérault Rugby | 25 | 1950 | 8 |
| 2024-2025 | TOP 14 | Montpellier Hérault Rugby | 14 | 1018 | 5 |
| 2023-2024 | TOP 14 | Montpellier Hérault Rugby | 14 | 1036 | 3 |

Concurrence au même poste : Maël MOUSTIN (79, XV), Donovan TAOFIFENUA (78, XV), Jon ECHEGARAY (75, depth), Rupeni CAUCAUNIBUCA JNR (72, depth).

Preuves : [historique LNR](https://top14.lnr.fr/joueur/1444-gabriel-ngandebe) ; [mhr-ngandebe](https://www.montpellier-rugby.com/equipes/equipe-pro/joueurs/gabriel-ngandebe).

| Dose | Attributs initiaux → candidats | Compétences recalculées : deltas non nuls | Note au poste |
| --- | --- | --- | --- |
| -1 | evasion 77→76, acceleration 79→78, topSpeed 76→75 | speed -0.75 | 72 |
| 1 | evasion 77→78, acceleration 79→80, topSpeed 76→77 | speed +0.75 | 73 |
| 2 | evasion 77→79, acceleration 79→81, topSpeed 76→78 | speed +1.50 | 73 |

Les36 deltas d’attributs et11 deltas de compétences, y compris les zéros, ainsi que les valeurs de contrôle, figurent dans `data/scouting/shadow-v16-20261107.json` (`results.candidatePlans`). La dose−1 est une contre-hypothèse ; elle n’est pas une recommandation d’abaisser le joueur. Hamdaoui et Fickou restent des hypothèses provisoires : source club de poste / source défensive ancienne, à recouper avant toute activation.

### Giorgi AKHALADZE — Preuves encore insuffisantes

ID `lnr:184`, clermont, Pilier gauche, âge simulé26, rating scalaire69, note au poste69, place automatique `depth`. 1063/854 minutes TOP14 après821 PRO D2 ; erreur de poste prioritaire. Le55 jouable au talon ne prouve pas une sous-note au pilier.

| Saison | Compétition | Club historique | Matchs | Minutes | Essais |
| --- | --- | --- | --- | --- | --- |
| 2025-2026 | TOP 14 | ASM Clermont | 21 | 1063 | 5 |
| 2024-2025 | TOP 14 | ASM Clermont | 19 | 854 | 2 |
| 2023-2024 | PRO D2 | AS Béziers Hérault | 20 | 821 | 2 |

Concurrence au même poste : Mathéo FRISACH (75, XV), Sacha LOTRIAN (72, bench), Nohem EZ ZAHOUANY (72, depth).

Preuves : [historique LNR](https://top14.lnr.fr/joueur/184-giorgi-akhaladze) ; [asm-arrivals](https://www.asm-rugby.com/actus/2024-06-11-bilan-et-officialisations).

| Dose | Attributs initiaux → candidats | Compétences recalculées : deltas non nuls | Note au poste |
| --- | --- | --- | --- |
| -1 | ballCarry 68→67, workRate 72→71 | stamina -0.20, power -0.20 | 69 |
| 1 | ballCarry 68→69, workRate 72→73 | stamina +0.20, power +0.20 | 69 |
| 2 | ballCarry 68→70, workRate 72→74 | stamina +0.40, power +0.40 | 70 |

Les36 deltas d’attributs et11 deltas de compétences, y compris les zéros, ainsi que les valeurs de contrôle, figurent dans `data/scouting/shadow-v16-20261107.json` (`results.candidatePlans`). La dose−1 est une contre-hypothèse ; elle n’est pas une recommandation d’abaisser le joueur. Hamdaoui et Fickou restent des hypothèses provisoires : source club de poste / source défensive ancienne, à recouper avant toute activation.

### Setariki TUICUVU — Note cohérente

ID `lnr:429`, toulon, Centre, âge simulé30, rating scalaire68, note au poste69, place automatique `depth`. 998/1158/1569 minutes ; baisse d’exposition non assimilée à baisse de niveau, polyvalence et qualités défensives club. Pas de hausse globale recommandée.

| Saison | Compétition | Club historique | Matchs | Minutes | Essais |
| --- | --- | --- | --- | --- | --- |
| 2025-2026 | TOP 14 | RC Toulon | 16 | 998 | 4 |
| 2024-2025 | TOP 14 | RC Toulon | 21 | 1158 | 5 |
| 2023-2024 | TOP 14 | RC Toulon | 25 | 1569 | 6 |

Concurrence au même poste : Juan Ignacio BREX (76, XV), Antoine FRISCH (76, XV), Mathieu SMAILI (72, depth), Jérémy SINZELLE (72, depth), Rayan REBBADJ (71, depth), Huw JONES (71, depth), Oliver COWIE (71, depth), Gael FICKOU (70, depth).

Preuves : [historique LNR](https://top14.lnr.fr/joueur/429-setariki-tuicuvu) ; [rct-tuicuvu](https://rctoulon.com/setariki-tuicuvu-toulonnais-jusquen-2028/).

| Dose | Attributs initiaux → candidats | Compétences recalculées : deltas non nuls | Note au poste |
| --- | --- | --- | --- |
| -1 | tackling 68→67, positioning 72→71 | tackle -0.85 | 68 |
| 1 | tackling 68→69, positioning 72→73 | tackle +0.85 | 69 |
| 2 | tackling 68→70, positioning 72→74 | tackle +1.70 | 69 |

Les36 deltas d’attributs et11 deltas de compétences, y compris les zéros, ainsi que les valeurs de contrôle, figurent dans `data/scouting/shadow-v16-20261107.json` (`results.candidatePlans`). La dose−1 est une contre-hypothèse ; elle n’est pas une recommandation d’abaisser le joueur. Hamdaoui et Fickou restent des hypothèses provisoires : source club de poste / source défensive ancienne, à recouper avant toute activation.

### Anthony BOUTHIER — Note cohérente

ID `lnr:1426`, vannes, Arrière, âge simulé33, rating scalaire74, note au poste73, place automatique `depth`. 1456 minutes/7 essais PRO D2 après706/943 TOP14 ;34 ans. Préserver technique et expérience sans restaurer le physique ni survaloriser la division inférieure.

| Saison | Compétition | Club historique | Matchs | Minutes | Essais |
| --- | --- | --- | --- | --- | --- |
| 2025-2026 | PRO D2 | RC Vannes | 24 | 1456 | 7 |
| 2024-2025 | TOP 14 | Montpellier Hérault Rugby | 11 | 706 | 1 |
| 2023-2024 | TOP 14 | Montpellier Hérault Rugby | 13 | 943 | 1 |

Concurrence au même poste : Paul SURANO (79, XV), Joe JONAS (76, bench), Pierre POPELIN (75, depth).

Preuves : [historique LNR](https://top14.lnr.fr/joueur/1426-anthony-bouthier) ; [rcv-bouthier](https://www.rugbyclubvannes.bzh/anthony-bouthier-officiellement-de-retour-au-rc-vannes-a-partir-de-la-saison-prochaine/).

| Dose | Attributs initiaux → candidats | Compétences recalculées : deltas non nuls | Note au poste |
| --- | --- | --- | --- |
| -1 | receiving 76→75, positioning 73→72 | tackle -0.15, pass -0.15 | 73 |
| 1 | receiving 76→77, positioning 73→74 | tackle +0.15, pass +0.15 | 73 |
| 2 | receiving 76→78, positioning 73→75 | tackle +0.30, pass +0.30 | 73 |

Les36 deltas d’attributs et11 deltas de compétences, y compris les zéros, ainsi que les valeurs de contrôle, figurent dans `data/scouting/shadow-v16-20261107.json` (`results.candidatePlans`). La dose−1 est une contre-hypothèse ; elle n’est pas une recommandation d’abaisser le joueur. Hamdaoui et Fickou restent des hypothèses provisoires : source club de poste / source défensive ancienne, à recouper avant toute activation.

### Kylan HAMDAOUI — Note probablement trop faible

ID `lnr:1793`, clermont, Arrière, âge simulé31, rating scalaire73, note au poste73, place automatique `depth`. 1368 minutes/6 essais après545 puis1446 ; régularité non linéaire,32 ans. Test ciblé troisième rideau, pas de bonus de vitesse. La source club établit le poste, pas une qualité aérienne mesurée ; proposition provisoire.

| Saison | Compétition | Club historique | Matchs | Minutes | Essais |
| --- | --- | --- | --- | --- | --- |
| 2025-2026 | TOP 14 | ASM Clermont | 19 | 1368 | 6 |
| 2024-2025 | TOP 14 | ASM Clermont | 8 | 545 | 0 |
| 2023-2024 | TOP 14 | Stade Français Paris | 20 | 1446 | 2 |

Concurrence au même poste : Etene NANAI SETURO (78, XV), Axel GUILLAUD (74, depth).

Preuves : [historique LNR](https://top14.lnr.fr/joueur/1793-kylan-hamdaoui) ; [asm-arrivals](https://www.asm-rugby.com/actus/2024-06-11-bilan-et-officialisations).

| Dose | Attributs initiaux → candidats | Compétences recalculées : deltas non nuls | Note au poste |
| --- | --- | --- | --- |
| -1 | receiving 77→76, positioning 76→75, aerialAbility 77→76 | lineout -0.15, tackle -0.15, pass -0.15 | 73 |
| 1 | receiving 77→78, positioning 76→77, aerialAbility 77→78 | lineout +0.15, tackle +0.15, pass +0.15 | 73 |
| 2 | receiving 77→79, positioning 76→78, aerialAbility 77→79 | lineout +0.30, tackle +0.30, pass +0.30 | 73 |

Les36 deltas d’attributs et11 deltas de compétences, y compris les zéros, ainsi que les valeurs de contrôle, figurent dans `data/scouting/shadow-v16-20261107.json` (`results.candidatePlans`). La dose−1 est une contre-hypothèse ; elle n’est pas une recommandation d’abaisser le joueur. Hamdaoui et Fickou restent des hypothèses provisoires : source club de poste / source défensive ancienne, à recouper avant toute activation.

### Barnabé MASSA — Preuves encore insuffisantes

ID `lnr:862`, clermont, Talonneur, âge simulé21, rating scalaire72, note au poste70, place automatique `XV`. 1310 minutes/7 essais après739/6 ; historique PRO D2 distinct. Talonneur confirmé, mais comparateurs Fourcade/Narisia ont eux-mêmes de mauvais profils de poste ; corriger la correspondance avant de conclure sur la note.

| Saison | Compétition | Club historique | Matchs | Minutes | Essais |
| --- | --- | --- | --- | --- | --- |
| 2025-2026 | TOP 14 | ASM Clermont | 24 | 1310 | 7 |
| 2024-2025 | TOP 14 | ASM Clermont | 20 | 739 | 6 |
| 2023-2024 | TOP 14 | FC Grenoble Rugby | 1 | 67 | 1 |
| 2023-2024 | PRO D2 | FC Grenoble Rugby | 29 | 1481 | 8 |

Concurrence au même poste : Etienne FOURCADE (61, bench), Peniami Nasali NARISIA (56, depth), Noah TRAINI (55, depth).

Preuves : [historique LNR](https://top14.lnr.fr/joueur/862-barnabe-massa) ; [asm-arrivals](https://www.asm-rugby.com/actus/2024-06-11-bilan-et-officialisations), [asm-fourcade](https://www.asm-rugby.com/equipe/joueurs/etienne-fourcade-talonneur).

| Dose | Attributs initiaux → candidats | Compétences recalculées : deltas non nuls | Note au poste |
| --- | --- | --- | --- |
| -1 | ballHandling 67→66, hooking 75→74, lineoutThrow 75→74 | scrum -0.15, lineout -0.75, pass -0.15 | 70 |
| 1 | ballHandling 67→68, hooking 75→76, lineoutThrow 75→76 | scrum +0.15, lineout +0.75, pass +0.15 | 71 |
| 2 | ballHandling 67→69, hooking 75→77, lineoutThrow 75→77 | scrum +0.30, lineout +1.50, pass +0.30 | 71 |

Les36 deltas d’attributs et11 deltas de compétences, y compris les zéros, ainsi que les valeurs de contrôle, figurent dans `data/scouting/shadow-v16-20261107.json` (`results.candidatePlans`). La dose−1 est une contre-hypothèse ; elle n’est pas une recommandation d’abaisser le joueur. Hamdaoui et Fickou restent des hypothèses provisoires : source club de poste / source défensive ancienne, à recouper avant toute activation.

### Sione KALAMAFONI — Note cohérente

ID `lnr:11840`, vannes, Troisième ligne, âge simulé37, rating scalaire72, note au poste72, place automatique `depth`. 1304 minutes PRO D2,1708 TOP14,919 PRO D2 ;38 ans. Le porteur de balle reste utile sans effacer le vieillissement ; test technique seulement. Poste numéro8 documenté hors liste16.

| Saison | Compétition | Club historique | Matchs | Minutes | Essais |
| --- | --- | --- | --- | --- | --- |
| 2025-2026 | PRO D2 | RC Vannes | 24 | 1304 | 6 |
| 2024-2025 | TOP 14 | RC Vannes | 23 | 1708 | 1 |
| 2023-2024 | PRO D2 | RC Vannes | 18 | 919 | 3 |

Concurrence au même poste : Juan Bautista PEDEMONTE (81, XV), Francisco GORRISSEN (79, XV), Léon BOULIER (78, XV), Simon AUGRY (76, bench), Joseph EDWARDS (74, depth), Rudi BROWN (73, depth), Ioane IASHAGASHVILI (72, depth), Steeve BLANC MAPPAZ (70, depth).

Preuves : [historique LNR](https://top14.lnr.fr/joueur/11840-sione-kalamafoni) ; [rcv-kalamafoni](https://www.rugbyclubvannes.bzh/sione-kalamafoni-prolonge-avec-le-rcv/).

| Dose | Attributs initiaux → candidats | Compétences recalculées : deltas non nuls | Note au poste |
| --- | --- | --- | --- |
| -1 | ballCarry 70→69, workRate 79→78 | stamina -0.20, power -0.20 | 72 |
| 1 | ballCarry 70→71, workRate 79→80 | stamina +0.20, power +0.20 | 73 |
| 2 | ballCarry 70→72, workRate 79→81 | stamina +0.40, power +0.40 | 73 |

Les36 deltas d’attributs et11 deltas de compétences, y compris les zéros, ainsi que les valeurs de contrôle, figurent dans `data/scouting/shadow-v16-20261107.json` (`results.candidatePlans`). La dose−1 est une contre-hypothèse ; elle n’est pas une recommandation d’abaisser le joueur. Hamdaoui et Fickou restent des hypothèses provisoires : source club de poste / source défensive ancienne, à recouper avant toute activation.

### Gael FICKOU — Note probablement trop faible

ID `lnr:2168`, toulon, Centre, âge simulé31, rating scalaire70, note au poste70, place automatique `depth`. 1255/1436/1154 minutes TOP14,6/5/2 essais. Responsabilité défensive historique, changement Racing→Toulon,32 ans. Test défensif prudent ; aucune augmentation de vitesse. Source défensive ancienne : proposition provisoire à recouper avant activation.

| Saison | Compétition | Club historique | Matchs | Minutes | Essais |
| --- | --- | --- | --- | --- | --- |
| 2025-2026 | TOP 14 | Racing 92 | 20 | 1255 | 6 |
| 2024-2025 | TOP 14 | Racing 92 | 20 | 1436 | 5 |
| 2023-2024 | TOP 14 | Racing 92 | 15 | 1154 | 2 |

Concurrence au même poste : Juan Ignacio BREX (76, XV), Antoine FRISCH (76, XV), Mathieu SMAILI (72, depth), Jérémy SINZELLE (72, depth), Rayan REBBADJ (71, depth), Huw JONES (71, depth), Oliver COWIE (71, depth), Setariki TUICUVU (69, depth).

Preuves : [historique LNR](https://top14.lnr.fr/joueur/2168-gael-fickou) ; [ffr-fickou](https://www.ffr.fr/actualites/xv-de-france/tournoi-des-6-nations-une-victoire-a-bonifier).

| Dose | Attributs initiaux → candidats | Compétences recalculées : deltas non nuls | Note au poste |
| --- | --- | --- | --- |
| -1 | tackling 70→69, anticipation 70→69, positioning 72→71 | tackle -0.85, mental -0.15 | 70 |
| 1 | tackling 70→71, anticipation 70→71, positioning 72→73 | tackle +0.85, mental +0.15 | 71 |
| 2 | tackling 70→72, anticipation 70→72, positioning 72→74 | tackle +1.70, mental +0.30 | 71 |

Les36 deltas d’attributs et11 deltas de compétences, y compris les zéros, ainsi que les valeurs de contrôle, figurent dans `data/scouting/shadow-v16-20261107.json` (`results.candidatePlans`). La dose−1 est une contre-hypothèse ; elle n’est pas une recommandation d’abaisser le joueur. Hamdaoui et Fickou restent des hypothèses provisoires : source club de poste / source défensive ancienne, à recouper avant toute activation.

### Santiago ARATA PERRONE — Preuves encore insuffisantes

ID `lnr:555`, castres, Demi de mêlée, âge simulé29, rating scalaire73, note au poste75, place automatique `depth`. 1048/1175/983 minutes,4/6/5 essais ; rôle utile mais minutes et essais ne mesurent pas qualité de passe/décision. Un article de match ne suffit pas.

| Saison | Compétition | Club historique | Matchs | Minutes | Essais |
| --- | --- | --- | --- | --- | --- |
| 2025-2026 | TOP 14 | Castres Olympique | 17 | 1048 | 4 |
| 2024-2025 | TOP 14 | Castres Olympique | 24 | 1175 | 6 |
| 2023-2024 | TOP 14 | Castres Olympique | 19 | 983 | 5 |

Concurrence au même poste : Jérémy FERNANDEZ (82, XV), Colin DUPUY (74, bench).

Preuves : [historique LNR](https://top14.lnr.fr/joueur/555-santiago-arata-perrone) ; [arata-secondary](https://www.americasrugbynews.com/2024/10/06/santiago-arata-scores-as-castres-upset-toulouse/).

| Dose | Attributs initiaux → candidats | Compétences recalculées : deltas non nuls | Note au poste |
| --- | --- | --- | --- |
| -1 | passing 76→75, decisions 74→73, vision 77→76 | pass -0.60, kick -0.10, mental -0.50 | 75 |
| 1 | passing 76→77, decisions 74→75, vision 77→78 | pass +0.60, kick +0.10, mental +0.50 | 75 |
| 2 | passing 76→78, decisions 74→76, vision 77→79 | pass +1.20, kick +0.20, mental +1.00 | 76 |

Les36 deltas d’attributs et11 deltas de compétences, y compris les zéros, ainsi que les valeurs de contrôle, figurent dans `data/scouting/shadow-v16-20261107.json` (`results.candidatePlans`). La dose−1 est une contre-hypothèse ; elle n’est pas une recommandation d’abaisser le joueur. Hamdaoui et Fickou restent des hypothèses provisoires : source club de poste / source défensive ancienne, à recouper avant toute activation.

## Matchs natifs élargis

**7776 matchs expérimentaux natifs**, plus36 répétitions de contrôle strict,24 matchs de sentinelle de sensibilité et14 matchs de parité d’instrumentation. Ils remplacent les essais antérieurs sans exposition réelle : neuf joueurs, trois adversaires choisis sur les qualités faible/médiane/forte disponibles, deux domiciles, huit blocs de graines, quatre configurations et contrôle/−1/+1/+2. Les moyennes de chaque bloc regroupent les six matchs adversaire×domicile ; intervalle t95% calculé sur huit blocs (t7=2,365), et non sur48 pseudo-réplications indépendantes. Pour les postes : douze blocs (t11=2,201). Intervalles exploratoires, sans correction des comparaisons multiples ; aucune dose n’est validée par le seul signe de la moyenne.

Les expériences individuelles rendent le club cible contrôlé par le manager : sélection automatique fraîche, XV légal préféré avec le joueur titulaire, banc légal préféré, joueur indisponible. Les règles natives de qualification, sélection préférée et remplacements restent intactes ; l’adversaire reste IA. Les neuf joueurs commencent réellement48/48 essais « titulaire » et sont nommés48/48 fois sur le banc des essais « banc », avec du temps de jeu positif dans chacun des neuf dossiers. Les carrières, séparément, observent la sélection IA naturelle. Les premières lignes de correction de poste conservent le club utilisateurClermont et les13 clubs IA de la carrière initialisée.

| Joueur | Minutes moy. titulaire / banc contrôle | Entrées avec minutes banc /48 | Marge +2 titulaire, IC95% | Marge +2 banc, IC95% |
| --- | --- | --- | --- | --- |
| Gabriel NGANDEBE | 83.25 / 7.125 | 47 | +0.000 [+0.000 ; +0.000] | +0.146 [-0.199 ; +0.491] |
| Giorgi AKHALADZE | 79.896 / 14.438 | 48 | +0.354 [-0.253 ; +0.961] | +0.167 [-0.457 ; +0.790] |
| Setariki TUICUVU | 80.896 / 3.5 | 46 | +0.000 [+0.000 ; +0.000] | +0.000 [+0.000 ; +0.000] |
| Anthony BOUTHIER | 81.875 / 7.354 | 39 | +0.000 [+0.000 ; +0.000] | +0.000 [+0.000 ; +0.000] |
| Kylan HAMDAOUI | 82.563 / 7.75 | 47 | +0.000 [+0.000 ; +0.000] | +0.000 [+0.000 ; +0.000] |
| Barnabé MASSA | 80.854 / 32.813 | 48 | -0.333 [-0.929 ; +0.263] | +0.000 [+0.000 ; +0.000] |
| Sione KALAMAFONI | 80.438 / 2.438 | 34 | +0.000 [+0.000 ; +0.000] | +0.042 [-0.057 ; +0.140] |
| Gael FICKOU | 81.021 / 8.958 | 48 | +0.000 [+0.000 ; +0.000] | -0.250 [-0.644 ; +0.144] |
| Santiago ARATA PERRONE | 81.792 / 0.438 | 9 | +0.000 [+0.000 ; +0.000] | +0.063 [-0.338 ; +0.463] |

Le temps natif peut dépasser80 minutes (temps de jeu additionnel). Les remplaçants entrés à la toute dernière séquence avec zéro minute ne sont pas comptés comme apparitions. Tous les contrôles indisponibles donnent zéro minute et zéro écart de marge. Des variations existent, mais les intervalles incluent généralement zéro ; une petite hausse technique peut rester sous les seuils d’événements discrets malgré une vraie titularisation. La sentinelle +10 de36 attributs sur un groupe entier fait varier les scores : elle vérifie le raccordement au moteur, **n’est pas une proposition de calibration**.

| Club / configuration | XV contrôle → postes | Banc contrôle → postes | Marge postes, IC95% | Marge projection, IC95% |
| --- | --- | --- | --- | --- |
| ASM Clermont Auvergne / fresh | 76.4→77 | 72.625→73.25 | +1.542 [-0.717 ; +3.800] | +1.583 [-0.707 ; +3.874] |
| ASM Clermont Auvergne / fatigued | 72.933→73.867 | 73→72.375 | +0.903 [-1.850 ; +3.656] | +0.903 [-1.850 ; +3.656] |
| Aviron Bayonnais / fresh | 77.933→78 | 74.625→74.875 | +0.028 [-1.261 ; +1.317] | +0.028 [-1.261 ; +1.317] |
| Aviron Bayonnais / fatigued | 74.6→74.867 | 73.75→73.125 | +0.069 [-1.178 ; +1.317] | +0.028 [-1.149 ; +1.204] |

Les véritables XV de la première rencontre de chaque configuration sont également consignés (`actualFixture`) ; les listes `changes` sont les feuilles potentielles du sélectionneur simple et sont nommées comme telles. Les corrections modifient bien au moins un XV réellement entré sur le terrain. Corriger l’éligibilité améliore la cohérence rugby même sans effet de score significatif.

## Hiérarchie des30 clubs : deux périmètres distincts

| Club TOP14 natif | XV contrôle | XV postes vérifiés sur copie | Delta |
| --- | --- | --- | --- |
| ASM Clermont Auvergne | 76.4 | 77 | 0.6 |
| Aviron Bayonnais | 77.933 | 78 | 0.067 |
| Castres Olympique | 78.133 | 78.133 | 0 |
| LOU Rugby | 78.333 | 78.333 | 0 |
| Montpellier Hérault Rugby | 78.667 | 78.667 | 0 |
| RC Toulon | 78.267 | 78.267 | 0 |
| RC Vannes | 78.667 | 78.667 | 0 |
| Racing 92 | 78.133 | 78.133 | 0 |
| Section Paloise | 78.267 | 78.267 | 0 |
| Stade Français Paris | 78.4 | 78.4 | 0 |
| Stade Rochelais | 77.8 | 77.8 | 0 |
| Stade Toulousain | 80.333 | 80.333 | 0 |
| USA Perpignan | 78.067 | 78.067 | 0 |
| Union Bordeaux-Bègles | 78.733 | 78.733 | 0 |

Le tableau suivant utilise le laboratoire V12 existant pour conserver les30 clubs et1592 joueurs ; il ne prouve pas que les postes V12 sont tous justes. Une feuille incomplète reste signalée, sans ajout artificiel de joueurs. La PRO D2 ne fait pas partie des saisons historiques ci-dessous.

| Club catalogue | Division | Joueurs | XV | Banc | Qualité XV laboratoire |
| --- | --- | --- | --- | --- | --- |
| clermont | top14 | 50 | 15 | 8 | 77.733 |
| bayonne | top14 | 56 | 15 | 8 | 78.067 |
| castres | top14 | 56 | 15 | 8 | 78.2 |
| lyon | top14 | 61 | 15 | 8 | 78.333 |
| montpellier | top14 | 60 | 15 | 8 | 78.667 |
| toulon | top14 | 53 | 15 | 8 | 78.267 |
| vannes | top14 | 61 | 15 | 8 | 78.667 |
| racing-92 | top14 | 52 | 15 | 8 | 78.4 |
| pau | top14 | 65 | 15 | 8 | 78.267 |
| paris | top14 | 63 | 15 | 8 | 78.6 |
| la-rochelle | top14 | 58 | 15 | 8 | 77.933 |
| toulouse | top14 | 61 | 15 | 8 | 80.333 |
| perpignan | top14 | 51 | 15 | 8 | 78.133 |
| bordeaux-begles | top14 | 58 | 15 | 8 | 78.733 |
| beziers | prod2 | 47 | 14 | 8 | 70.571 |
| biarritz | prod2 | 51 | 15 | 8 | 70.067 |
| brive | prod2 | 53 | 14 | 8 | 70.5 |
| colomiers | prod2 | 45 | 15 | 8 | 70.533 |
| grenoble | prod2 | 52 | 15 | 8 | 70.4 |
| nice | prod2 | 51 | 15 | 8 | 70.133 |
| oyonnax | prod2 | 54 | 15 | 8 | 70.067 |
| provence-rugby | prod2 | 58 | 15 | 8 | 70.867 |
| narbonne | prod2 | 48 | 15 | 8 | 70.333 |
| agen | prod2 | 45 | 15 | 8 | 70 |
| angouleme | prod2 | 51 | 15 | 8 | 70.267 |
| aurillac | prod2 | 45 | 13 | 8 | 70.538 |
| dax | prod2 | 36 | 15 | 8 | 70.2 |
| montauban | prod2 | 50 | 14 | 8 | 71 |
| nevers | prod2 | 61 | 15 | 8 | 70.533 |
| valence-romans | prod2 | 40 | 13 | 7 | 70.385 |

Les petites doses individuelles ne bouleversent pas la hiérarchie à effectif frais ; les corrections de poste déplacent surtout Clermont. Aucun bonus de club, malus de division ou recrutement fictif n’a été activé pour fabriquer un classement.

## Six transitions de carrière : préparation native rétablie

Deux graines731/1907 × contrôle/postes13 × six saisons = **24 saisons natives,4488 matchs**. Même graine de départ et même graine par journée/transition entre les deux bras. Les décisions natives, contrats, retraites, promotions et recrutements sont exécutés sans les remplacer. Les événements de chaque match consomment un nombre variable de tirages : alignement par journée, pas tirage par tirage ; les classements et transactions sont donc exploratoires, sans attribution causale certaine aux postes et sans intervalle de population fondé sur seulement deux graines. Aucun contrat n’est géré activement pour le club utilisateur ; la préparation collective normale reste exécutée pour tous.

| Graine / bras | Ouverture S7 total / IA / utilisateur | XV / banc complets | Renouvelés | Libérés | Recrutés | Promus / urgence |
| --- | --- | --- | --- | --- | --- | --- |
| 731 / control | 426 / 403 / 23 | 14 / 14 | 1410 | 384 | 20 | 27 / 8 |
| 731 / position | 428 / 405 / 23 | 14 / 14 | 1406 | 381 | 15 | 29 / 7 |
| 1907 / control | 427 / 404 / 23 | 14 / 14 | 1411 | 384 | 20 | 31 / 7 |
| 1907 / position | 429 / 406 / 23 | 14 / 14 | 1415 | 383 | 21 | 26 / 8 |

Départs observés≠retraites : les compteurs natifs de contrats et de retraite sont séparés dans les résultats JSON. Les renouvellements comptent des événements annuels, pas des joueurs distincts. Les sorties/arrivées par club sont des mouvements d’effectif, pas forcément un transfert entre deux clubs.

| Saison | Titulaires distincts IA moy. | Blessés IA moy. | Fatigue IA moy. | Semaines-club XV incomplet /676 | Banc incomplet /676 | Banc sans trainWeek /676 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 34 | 0.496 | 12.51 | 2 | 3 | 177 |
| 2 | 33.577 | 0.627 | 13.506 | 16 | 9 | 285 |
| 3 | 31.385 | 0.573 | 14.623 | 61 | 26 | 394 |
| 4 | 30.538 | 0.676 | 16.466 | 65 | 60 | 494 |
| 5 | 29.885 | 0.604 | 17.693 | 72 | 59 | 487 |
| 6 | 28.423 | 0.654 | 18.885 | 96 | 112 | 553 |

Les676 observations annuelles sont2 graines ×13 clubs IA ×26 journées, pas676 matchs indépendants. Titulaires, nominations banc, apparitions et minutes proviennent des véritables feuilles des matchs réguliers via une observation hors état ; les minutes cumulées de carrière incluent aussi les phases finales. La parité d’un tour natif avec/sans observateur vérifie l’état et le tirage suivant identiques. Les moyennes de blessés/fatigue restent des paramètres du jeu, pas des taux médicaux réels.

### Profondeur des clubs et risque de couverture

| Club | Gestion | Effectif S1 | S7,2 graines | Titulaires distincts S6 moy. | Banc incomplet S6,semaines moy. | Couverture S7 par poste,graines731/1907 |
| --- | --- | --- | --- | --- | --- | --- |
| clermont | utilisateur sans contrats | 50 | 23–23 | 21.5 | 17.5 | Pilier gauche:2/2; Talonneur:2/2; Pilier droit:2/2; Demi de mêlée:2/2; Arrière:1/1 |
| bayonne | IA | 56 | 28–28 | 27.5 | 10 | Pilier gauche:2/2; Talonneur:3/3; Pilier droit:2/2; Demi de mêlée:2/2; Arrière:2/2 |
| castres | IA | 56 | 29–30 | 26 | 4 | Pilier gauche:4/4; Talonneur:3/3; Pilier droit:2/2; Demi de mêlée:2/2; Arrière:2/2 |
| lyon | IA | 61 | 33–33 | 31 | 2.5 | Pilier gauche:3/3; Talonneur:3/3; Pilier droit:2/3; Demi de mêlée:2/2; Arrière:2/2 |
| montpellier | IA | 60 | 34–34 | 25.5 | 3 | Pilier gauche:4/4; Talonneur:3/2; Pilier droit:2/2; Demi de mêlée:2/3; Arrière:1/1 |
| toulon | IA | 53 | 29–30 | 25 | 7.5 | Pilier gauche:2/2; Talonneur:2/5; Pilier droit:2/2; Demi de mêlée:3/2; Arrière:2/2 |
| vannes | IA | 61 | 27–30 | 29.5 | 5.5 | Pilier gauche:4/4; Talonneur:2/2; Pilier droit:2/2; Demi de mêlée:2/2; Arrière:2/2 |
| racing-92 | IA | 52 | 29–30 | 29 | 6 | Pilier gauche:2/2; Talonneur:3/3; Pilier droit:3/3; Demi de mêlée:3/2; Arrière:2/2 |
| pau | IA | 65 | 28–28 | 28.5 | 1 | Pilier gauche:5/5; Talonneur:2/2; Pilier droit:2/2; Demi de mêlée:2/2; Arrière:2/2 |
| paris | IA | 63 | 34–35 | 30.5 | 0.5 | Pilier gauche:3/3; Talonneur:3/3; Pilier droit:2/2; Demi de mêlée:2/2; Arrière:3/3 |
| la-rochelle | IA | 58 | 37–39 | 32 | 0.5 | Pilier gauche:4/4; Talonneur:4/4; Pilier droit:2/3; Demi de mêlée:2/2; Arrière:3/3 |
| toulouse | IA | 61 | 30–32 | 29.5 | 3.5 | Pilier gauche:3/3; Talonneur:2/2; Pilier droit:2/2; Demi de mêlée:2/2; Arrière:2/2 |
| perpignan | IA | 51 | 28–28 | 28 | 6.5 | Pilier gauche:2/2; Talonneur:2/2; Pilier droit:2/2; Demi de mêlée:2/2; Arrière:2/2 |
| bordeaux-begles | IA | 58 | 31–33 | 27.5 | 5.5 | Pilier gauche:2/2; Talonneur:3/5; Pilier droit:2/2; Demi de mêlée:2/2; Arrière:2/2 |

Le groupe utilisateurClermont passe50→31→26→23 sans renouvellement actif : ce comportement ne doit pas être attribué à l’IA. Les clubs IA réduisent des groupes initiaux souvent >50 vers des tailles proches de30, mais les feuilles incomplètes en cours de saison et certains postes à deux spécialistes restent un risque réel. Les absences de libellé « Numéro8 » ne prouvent pas une vacance : le moteur autorise la famille de troisième ligne sur les trois postes. Le JSON conserve les11 libellés et les disponibilités par club/saison.

### Vieillissement et joueurs prioritaires

| Graine | Saison | Joueurs LNR survivants appariés | Vitesse nette moyenne clubs | Force nette moyenne clubs | Décisions nettes moyenne clubs |
| --- | --- | --- | --- | --- | --- |
| 731 | 1 | 671 | -0.22 | 0.328 | 0.352 |
| 731 | 2 | 590 | -0.314 | 0.289 | 0.342 |
| 731 | 3 | 505 | -0.357 | 0.29 | 0.351 |
| 731 | 4 | 428 | -0.316 | 0.327 | 0.381 |
| 731 | 5 | 376 | -0.3 | 0.324 | 0.396 |
| 731 | 6 | 349 | -0.365 | 0.262 | 0.389 |
| 1907 | 1 | 671 | -0.22 | 0.327 | 0.352 |
| 1907 | 2 | 590 | -0.321 | 0.288 | 0.342 |
| 1907 | 3 | 503 | -0.349 | 0.293 | 0.353 |
| 1907 | 4 | 430 | -0.313 | 0.328 | 0.379 |
| 1907 | 5 | 380 | -0.311 | 0.316 | 0.393 |
| 1907 | 6 | 351 | -0.375 | 0.256 | 0.388 |

Ces différences nettes englobent entraînement, exposition, courbe annuelle et sélection des survivants ; elles n’isolent pas un effet physiologique de l’âge. Les trajectoires individuelles, minutes, apparitions, titularisations et indisponibilités des neuf dossiers sont conservées par saison dans le JSON. Une absence ultérieure n’est pas qualifiée de retraite sans événement natif correspondant.

## Anomalies confirmées et transmission au producteur responsable

1. **Correspondance poste native** :12 rôles précis contredits officiellement dans les16 discordances. Reproduction automatisée et13 mappings exacts sur copies. Corriger l’initialisation de nouvelles carrières et tester explicitement les anciennes sauvegardes dans un chantier moteur autorisé ; ne pas réécrire les postes des carrières existantes depuis cette PR.
2. **Profil V12 mal spécialisé** :6 joueurs officiellement pilier/talonneur mal classés, dont Fourcade (77→61 au vrai poste en gardant ses compétences de pilier) et Narisia déjà talonneur natif mais profil de pilier. Revoir les36 attributs au rôle réellement corroboré dans une future calibration de données ; ne pas appliquer automatiquement les13 postes seuls comme correctif complet.
3. **Protocole QA ancien incomplet** :`finishRound()` sans`trainWeek()` ne fait pas progresser les soins hebdomadaires. Les nouveaux tests prouvent directement cette distinction et la rétablissent. Les4488 matchs sans préparation sont gardés comme contrôles négatifs, pas comme preuve d’un défaut moteur de récupération.
4. **Couverture en cours de saison** :des manques existent encore avec préparation normale ; les totaux par club/saison rendent la reproduction possible. Examiner la couverture disponible et le renfort IA en cours de saison dans son chantier réservé. Une baisse805→environ430 seule ne prouve pas une panne de recrutement.

Restent ouverts : trois mappings précis moins sûrs ; technique/mental individuels non mesurés ; qualité actuelle Hamdaoui/Fickou insuffisamment corroborée pour activation ; portée étroite des intervalles et deux seules graines longues ; aucune carrière PRO D2 native, promotion ou relégation ; aucun test Godot/France30 ou de migration de sauvegarde prétendu. Aucun correctif actif dans cette PR.

## Exécution et vérification

Commandes exécutées localement : `node tests/rugby-real-position-calibration-v16-20261107.cjs`, les cinq fichiers `tests/rugby-real-individual-v16-[a-e]-20261107.cjs`, les deux fichiers `tests/rugby-real-depth-v16-[a-b]-20261107.cjs`. Les tests CI généraux découvrent ces suites sans modification de workflow. Chaque fichier reste sous180s dans les derniers essais locaux ; la CI exacte reste l’autorité pour ses propres délais. Résultats complets optionnels vers un dossier scratch via`V16_RESULTS_DIR`, aucun gros JSON écrit dans les logs. Chaque ligne résumée est bornée à48000octets.

Les données de résultats et vecteurs sont persistées dans le fichier de scénarios réservé, sans charger ce fichier en production. Signature des données actives inchangée ; diff de PR exclusivement nouveaux tests/outilQA/scénarios/rapports et ancien rapportV15. Le journal DEVELOPPEMENT.md demeure réservé au chantier Godot/France30 : cette note et la passation#73 portent le bilan du producteur BDD. Aucun READY, /cd-check, /cd-merge, fusion ou changement de sauvegarde.
