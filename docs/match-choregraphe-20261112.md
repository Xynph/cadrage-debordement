# Chorégraphe de temps forts — conception, trois tranches (12 novembre 2026)

Branche `claude/match-choregraphe-20261112`, partie de `claude/match-nuit-20261111`
(PR 578 : temps forts #560, animations adaptées #571). Drapeau **`CD_MATCH_CHOREGRAPHE=1`**,
éteint par défaut : sans lui, rien ne change (moteur et vue).

## 1. Pourquoi

Le moteur simule environ une action par minute (≈ 200 événements par match). Un temps
fort rejoue ces actions en 3D en interpolant entre des positions espacées : les plans sont
courts (un essai dure 3,5 s), les trajectoires peu crédibles (joueurs qui glissent d'une
place à l'autre). Léo veut des temps forts plus longs, plus fluides, plus réalistes.

Le **chorégraphe** est une micro-simulation de présentation écrite dans le moteur Node : pour
une action déjà décidée par le moteur, il produit 12 à 25 s de mouvement continu pour les
trente joueurs et le ballon, au pas de 0,1 s, par rôle. **Le moteur reste la source de
vérité** : le chorégraphe ne lit ni n'écrit la carrière, ne consomme aucun tirage, ne
change ni le score, ni le marqueur, ni le point d'essai. Il met en scène ce qui a été décidé.

> **Deuxième tranche (§ 10)** : les pistes couvrent désormais tout le temps fort (remise en
> jeu formée, récupération, temps de jeu du moteur), et deux types s'ajoutent : le
> franchissement sans essai et le jeu au pied avec chasse. La défense suit la consigne
> tactique. Les §§ 2 à 9 décrivent la première tranche ; le § 10 dit ce qui a changé.
>
> **Troisième tranche (§ 11)** : ballon porté depuis la touche (essai ou arrêt), pénalité
> tentée au but et pénalité jouée en touche ; la défense lit l'attaque (côté fort, couverture
> du pied) ; correction du premier temps fort du match (joueurs absents de l'écran) ; capture
> dans l'interface complète.

Première tranche : **un seul type d'action, l'essai en jeu courant** (fait `origin:'open'`
de `scoreTry`). Les essais sur ballon porté et sur mêlée gardent les gestes actuels.

## 2. Entrées (faits structurés du moteur)

`entreeDepuisTempsFort(tf, events, {profils, avant, cle})`
(`native/engine/match-choregraphe.cjs`) lit le temps fort projeté par `match-direct.cjs` :

| Champ | Origine |
| --- | --- |
| `type` | `essai_jeu_courant` (seul type de cette tranche) |
| `equipe`, `marqueur` | fait `try` du journal : `team`, `actor` (le marqueur du commentaire) |
| `essai` | ballon de la scène d'essai : `x` = ligne d'en-but (0 ou 100), `y` = point d'essai du moteur |
| `joueurs`, `ballon`, `possession`, `porteur` | scène affichée juste avant l'essai : plan précédent du temps fort, sinon `depart`, sinon la dernière scène jouable du journal |
| `profils` | `{vmax, amax}` par joueur, calculés depuis la compétence « Vitesse » du moteur, forme comprise (`skill(p,'speed',true)`, lue sans rien écrire) ; repli par poste |
| `graine` | empreinte FNV-1a de la clé du temps fort et de l'index du fait d'essai |
| `duree_cible` | facultative ; sinon tirée de la graine entre 14 et 22 s |

Profil : allure de pointe `6,2 + 0,034 × (vitesse − 15)` bornée à [6,2 ; 9,4] m/s,
accélération `3 + 0,015 × vitesse` bornée à [3,2 ; 4,6] m/s². Ordres de grandeur d'un XV
d'élite (pilier ≈ 7 m/s, ailier ≈ 9 m/s) ; **valeurs choisies, non mesurées**.

## 3. Sorties (pistes)

`composer(entree)` rend (JSON, ≈ 50 à 80 Ko) :

- `joueurs[]` : `id`, `side`, `slot`, `vmax`, `amax` et, au pas `pas` = 0,2 s, les tableaux
  `x`, `y` (mètres, repère du moteur), `v` (m/s), `cap` (radians, angle sur le terrain depuis
  l'axe des x) ; `etats` = changements `[t, état]`. États : `course` (l'allure décide de
  l'animation), `passe`, `reception`, `plaquage`, `plaque`, `plaquage_rate`, `au_sol`,
  `se_relever`, `ruck`, `ramassage`, `aplati`, `joie`, `deception`.
- `ballon` : `x`, `y`, `h` (hauteur) au même pas, `porteurs` = changements `[t, id|null]`.
- `evenements` : `course`, `plaquage`, `ruck`, `ramassage` (avec `horsJeuRespecte`), `passe`
  (point de lâcher), `reception`, `percee`, `plaquage_rate`, `aplati`.
- `contacts` : fenêtres `[t0, t1, a, b]` où deux joueurs peuvent se toucher.
- `duree`, `graine`, `phases` (nombre de rucks), `marqueur`, `essai` (point d'aplati), `plan`
  (index du plan d'essai dans le temps fort).

La projection `live.direct.tempsFort.choregraphie` porte ces pistes quand le drapeau est posé ;
en cas d'échec, `choregraphieErreur` donne la raison et le temps fort part sans pistes.
Le calcul (≈ 0,2 à 0,5 s) est mis en cache par temps fort.

## 4. Déroulé et règles par rôle

Le metteur en scène enchaîne : **temps de jeu** (porteur plaqué, ruck) × `phases`, puis le
**jeu final** (passes vers le marqueur, percée, plaquages ratés, aplati, joie). `phases`
va de 0 à 4 : le chorégraphe essaie chaque nombre et garde la durée la plus proche de la
cible dans [12 ; 25] s. Ballon adverse au départ (le moteur a donné une récupération) :
le premier temps de jeu est le plaquage du porteur adverse et le ballon récupéré au ruck.

| Rôle | Comportement |
| --- | --- |
| Porteur (temps de jeu) | court vers le point visé (2,5 à 6 m plus loin), plaqué par le défenseur désigné, pose le ballon derrière lui (loi 14) |
| Plaqueur | vise où sera le porteur (anticipation bornée) ; relais par le défenseur le plus proche s'il est distancé |
| Soutiens (2) | suivent le porteur en retrait, puis se lient au ruck au-dessus du ballon |
| Demi (n° 9) | rejoint la base du ruck, ramasse quand tout le monde est en jeu et le receveur en retrait, passe |
| Prochain porteur | un avant placé en retrait, lancé depuis le ruck |
| Relais (n° 10) | si le marqueur est un trois-quarts : le demi passe à l'ouvreur, qui fixe et donne |
| Marqueur | en attente en retrait et au large, reçoit la dernière passe, perce, aplatit 2 m derrière la ligne dans l'axe du point d'essai du moteur |
| Autres attaquants | avants en grappes derrière le ballon, arrières en ligne en retrait du côté du jeu |
| Ligne défensive | étalée sur la largeur (6,2 m entre deux joueurs), en jeu derrière la ligne de hors-jeu pendant le ruck, glisse vers le ballon puis monte quand il est joué |
| Défenseur au ruck (1) | se lie en face |
| Arrière (n° 15) | en profondeur dans l'axe du ballon, coupe la course du marqueur |
| Défense pendant la percée | deux défenseurs et l'arrière tentent le plaquage (raté) ; tout défenseur qui arrive au contact tente aussi et rate ; les autres reculent vers leur ligne en s'écartant de la course ou poursuivent sans rattraper |
| Après l'aplati | partenaires proches vers le marqueur (`joie`), adversaires proches (`deception`) ; fin 2,6 à 4,5 s après l'aplati |

Mouvement : vitesse voulue vers la cible (freinage à l'arrivée), évitement anticipé
(plus courte approche sur 1,4 s, joueur au sol contourné plus large), freinage aux limites
du terrain, puis **accélération et vitesse plafonnées** par le profil. Chutes et plongeons
décélèrent à 9 m/s² au plus. Cadrage-débordement : le marqueur s'écarte du côté opposé à un
plongeon pendant 0,7 s.

## 5. Garanties (et comment elles sont contrôlées)

`tests/match-choregraphe.cjs` sur neuf essais en jeu courant du moteur natif (graines 7,
11, 42 et 99 ; `tests/fixtures/match-choregraphe-essais.json`) et sur un match natif :

| Garantie | Contrôle |
| --- | --- |
| Déterminisme par graine | même entrée → pistes identiques ; autre graine → autre mise en scène ; entrée non modifiée |
| Issue identique au moteur | marqueur du moteur dernier porteur et seul à aplatir ; ballon au sol au point d'essai (ligne + 2 m, `y` du moteur) ; aucun plaquage réussi pendant la percée ; match natif : même journal, même score, mêmes temps forts avec ou sans drapeau |
| Durée | 12 à 25 s ; un échantillon par pas |
| Vitesses, accélérations | ≤ profil de chaque joueur (tolérances d'arrondi au centimètre : 0,06 m/s, 0,6 m/s²), hors chutes et plongeons |
| Pas de chevauchement | deux joueurs hors fenêtre de contact restent à 0,6 m au moins (première seconde exclue : places de départ du moteur) |
| Hors-jeu (loi 15) | le ballon n'est joué au ruck qu'une fois tous les joueurs hors du ruck en jeu (pied le plus en arrière du ruck) |
| Passes (loi 11) | jamais en avant : le receveur prend le ballon en retrait du point de lâcher |
| Plaquage (loi 14) | le plaqué pose le ballon avant le ruck |
| Ballon continu | jamais plus de 25 m/s entre deux échantillons |

Ce qui reste une abstraction : pas de contestation au sol ni de grattage, pas de jeu au
pied, la défense ne « lit » pas l'attaque (lignes et poursuites géométriques), la ligne de
hors-jeu en jeu courant (loi 10) n'est appliquée qu'aux receveurs. **La réussite de ces
tests n'établit pas la conformité aux règles** ; elle établit que la mise en scène ne montre
pas les fautes listées.

## 6. Côté Godot

- `native/godot/match_choregraphie.gd` (nouveau) lit les pistes : interpolation de
  Catmull-Rom entre deux échantillons, raccord de 0,6 s depuis la place réelle de chaque
  joueur (la scène précédente a pu être mise en scène par les gestes), cap converti en lacet.
  États : avec la bibliothèque `CD_MATCH_ANIMATIONS`, gestes `plaquage`, `plaque_cote` /
  `plaque_jambes` (fin du clip tenue tant que la piste dit « au sol »), `se_relever`,
  `reception`, `joie`, `joie_poing`, `deception` ; sans elle, pose procédurale (buste incliné,
  joueur au sol, liaison au ruck) qui change à vitesse bornée.
- `native/godot/match_view.gd` : `jouer_choregraphie(pistes, vitesse)`,
  `choregraphie_active/temps/finie`, `figer_choregraphie`, `arreter_choregraphie`. Les joueurs
  suivis sont placés par les pistes ; l'animation de déplacement reste celle de la vue (paliers
  marche, trot, course, sprint selon l'allure réelle à l'écran). Ballon : dans les mains du
  porteur des pistes, sinon sur sa trajectoire ; tout changement de source (prise, lâcher,
  ramassage, aplati) est raccordé en 0,2 s. Une nouvelle image (`apply_frame`) met fin aux
  pistes ; à la fin, chacun reste en place et l'interpolation d'origine reprend.
- `native/godot/ui/contextual/match_temps_forts.gd` (régie) : quand le plan courant est celui
  des pistes et que `CD_MATCH_CHOREGRAPHE=1`, la vue les suit à la place du plan d'essai
  (pas d'interpolation, pas de geste d'essai). Légende et clameur de l'essai **à l'aplati**,
  jamais avant ; journal ouvert arrêté avant l'essai jusqu'à l'aplati ; pause : les pistes
  se figent ; échéance : durée + 5 s (événement `echeance`, cause `choregraphie`) ; cadrage
  d'une course. Puis le plan se termine comme avant (score, transformation).
- **Repli** : pistes absentes, d'une autre version ou incomplètes → refusées, le plan se joue
  par l'interpolation et les gestes actuels (`choregraphie_refusee` dans le suivi de la régie).

## 7. Exécuté (12 novembre 2026, Linux, 2 cœurs, Godot 4.7.2, une suite à la fois)

| Suite | Résultat |
| --- | --- |
| `tests/match-choregraphe.cjs` (nouveau) | 9 sur 9, 40 s : neuf essais du moteur (durées 15,4 à 22 s, 0 à 2 rucks) ; match natif graine 7 avec et sans drapeau : même journal, même score, mêmes temps forts hors pistes |
| `tests/godot-match-choregraphie.cjs` (nouveau) | 14 520 contrôles, 0 échec : la vue suit chaque piste (écart ≤ 0,76 m, soit un demi-échantillon à 7,6 m/s), allure à l'écran ≤ 7,7 m/s, ballon ≤ 11,9 m/s, dans les mains du porteur, aplati au point d'essai ; repli (pistes absentes, autre version, incomplètes), fin des pistes sans saut |
| `tests/godot-match-temps-forts.cjs` | 6 modes, 296 contrôles, 0 échec, dont le nouveau mode `choregraphie` (13 contrôles : essai de la 14e minute joué par les pistes, ni légende ni journal avant l'aplati, pause qui fige, ni échéance ni refus, le temps fort continue) |
| Relancés sans échec | `match-direct`, `match-highlights`, `match-essai-visible`, `match-structured-facts`, `match-actions`, `godot-match-essai`, `godot-match-gestes`, `godot-match-gestes-adaptes`, `godot-match-cadrage-arret`, `godot-match-animations`, `godot-match-framing`, `godot-match-cut`, `godot-match-presentation`, `godot-match-journal` (351) |

Vidéo de contrôle (hors dépôt) : capture Xvfb, rendu logiciel `llvmpipe`, `--fixed-fps 30`
(une image par 1/30 s de jeu, quelle que soit la lenteur du rendu), 1280×720, graine 7,
club 0, bibliothèque Mixamo `CD_MATCH_ANIMATIONS` : l'essai de la 14e minute **sans** le
drapeau (≈ 9 s de temps fort, gros plan des gestes) puis **avec** (pistes de 14,4 s jouées en
14,47 s : récupération du ballon, ruck, percée du demi, plaquages ratés, aplati, joie).

Commande (depuis la racine, après staging et import) :

```
CD_MATCH_CHOREGRAPHE=1 CD_MATCH_ANIMATIONS=/chemin/mixamo-match.res \
CD_GODOT_EXE=/chemin/Godot_v4.7.2-stable_linux.x86_64 \
CD_MATCH_TEMPS_FORTS_PROOF=/chemin/captures CD_MATCH_TEMPS_FORTS_SEED=7 \
CD_MATCH_TEMPS_FORTS_MINUTES=15 CD_MATCH_TEMPS_FORTS_HORLOGE=eclair \
CD_MATCH_TEMPS_FORTS_EVERY=1 CD_MATCH_TEMPS_FORTS_MAX=5000 \
CD_MATCH_TEMPS_FORTS_GODOT_ARGS="--fixed-fps 30" \
xvfb-run -a -s "-screen 0 1280x720x24" node tests/godot-match-temps-forts-capture.cjs
```

Sous Windows : mêmes variables (`set …`), sans `xvfb-run`.

## 8. Limites et suite conseillée

- Un seul type d'action. Suite naturelle, par ordre d'intérêt : **franchissement sans essai**
  (porteur finalement plaqué), **jeu au pied et chasse**, **touche et ballon porté**, **mêlée**,
  puis la défense qui récupère le ballon (grattage). La structure (rôles, plafonds, tests) est
  commune ; chaque type ajoute un enchaînement de phases.
- Les plans précédant l'essai dans le même temps fort (touche, ballon récupéré) restent
  joués comme avant ; les pistes commencent au plan d'essai. Étendre les pistes à tout le
  temps fort donnerait la continuité complète.
- Gestes manquants dans la bibliothèque : pas de clip d'aplati (le marqueur joue la chute
  « jambes »), pas de passe, pas de liaison au ruck (pose procédurale).
- La défense ne tient pas compte des consignes tactiques (pression, prudente) : à brancher
  sur `record.plans.defence`.
- Le calcul (≈ 0,3 s) se fait dans le pas « minute » du moteur, une fois par essai.

## 9. Non vérifié

- Rien sous Windows ni avec une carte graphique ; fluidité réelle inconnue (rendu logiciel).
- Un seul essai vu à l'œil dans la vraie interface (graine 7, 14e minute) ; les huit autres
  essais du jeu d'entrées ne sont contrôlés que par les tests.
- Gestes Mixamo pendant les pistes jugés sur cette seule capture.
- Crédibilité rugbystique (placements, timing des rucks, nombre de plaquages ratés) : à juger
  par Léo sur la vidéo ; les valeurs (profils, écarts, durées) sont des choix, non des mesures.

## 10. Deuxième tranche (12 novembre 2026, nuit)

Pistes **version 2** (la vue refuse la version 1 et repart sur les gestes).

### 10.1 Ce qui est couvert

`entreeDepuisTempsFort(tf, events, {profils, avant, cle})` choisit le **fait clé** du temps
fort, puis remonte les plans qui y mènent tant qu'elle sait les montrer :

| Type (`type`) | Fait clé | Plans couverts en amont | Suite couverte |
| --- | --- | --- | --- |
| `essai_jeu_courant` | essai `origin:'open'` | temps de jeu (`carry`) de l'équipe qui marque, récupération (`turnover`), remise en jeu gagnée (mêlée ou touche formée + `setpiece-win`/`setpiece-loss`), coup d'envoi + réception | — |
| `franchissement` | `carry` d'au moins 22 m sans essai | idem | un temps de jeu de la même équipe, ou le ballon récupéré par l'adversaire (`turnover`) |
| `jeu_au_pied` | `kick` (réception), `touch` sur coup de pied (`direct-touch`, `indirect-touch`, `50-22`), ou coup d'envoi + réception | idem | ballon récupéré ensuite par l'équipe qui a botté |

Non couverts (le temps fort garde alors les gestes existants à partir de ces plans) : ballon
porté (`move:'maul'`) et pénalités (couverts depuis la troisième tranche, § 11), fautes de main, cartons, sorties en touche sur un ballon
porté, transformations. Une touche gagnée en ballon porté, par exemple, se joue comme avant,
et les pistes partent du plan suivant.

### 10.2 Entrée

En plus des champs du § 2 : `etapes` (liste ordonnée des faits du moteur : `porte`, `franchi`,
`essai`, `pied`, `recup`, avec le joueur, le point `x` du moteur, `depuis` et l'index du plan),
`ouverture` (`jeu`, `melee`, `touche`, `envoi`, avec le point de remise en jeu, l'équipe qui
introduit ou lance, le botteur et le receveur), `premier`/`dernier` (plans couverts),
`jalonsAttendus`, `defense` (consigne `plans.defence` de chaque équipe) et, hors essai,
`vedette` (joueur clé) et `sens`.

### 10.3 Sorties ajoutées

`premier`, `dernier` (plans du temps fort couverts), `jalons` (`[t, plan]` : instant où le
fait de chaque plan est montré : remise en jeu en place, ballon gagné, porteur plaqué au bout
de son gain, réception ou ballon sorti, ballon récupéré, essai aplati), `ouverture`, `coupe`
(vrai sur une remise en jeu formée : la première image est posée d'emblée), `vedette`,
`dureeMax`. États ajoutés : `melee`, `lancer`, `saut`, `soutien_saut`, `jeu_au_pied`.
Événements ajoutés : `introduction`, `lancer`, `jeu_au_pied`, `touche` ; `plaquage` et
`reception` portent la position et le point du moteur (`cible`).

### 10.4 Déroulé

Le metteur en scène suit une **file d'étapes** : celles du moteur, puis, devant le fait clé,
0 à 4 temps de jeu ajoutés pour la durée (hors essai, ils ne gagnent que 1 à 2,5 m et ne
dépassent pas le point de départ du fait suivant). À chaque ballon disponible (remise en jeu,
ruck joué, réception), il prépare la chaîne de receveurs de l'étape suivante.

- **Mêlée formée** (loi 20) : seize avants liés (état `melee`), demis à leur place, arrières à
  5 m derrière le dernier pied ; introduction, ballon talonné vers le n° 8 du gagnant, poussée
  lente, puis le demi ramasse (ou le n° 8 garde si le moteur le désigne porteur).
- **Touche formée** (loi 18) : deux alignements à 1 m l'un de l'autre, de 5 à 15 m de la
  touche, lanceur, talonneur adverse à 2 m, demis en retrait, arrières à 10 m ; lancer, sauteur
  levé par ses deux voisins (`saut`, `soutien_saut`), prise, passe au demi. Le premier porteur
  désigné par le moteur, s'il est un arrière, vient se placer pendant la phase, derrière sa
  ligne de hors-jeu.
- **Coup d'envoi** (loi 12) : partenaires derrière le ballon, adversaires à 10 m ; coup de pied
  en cloche vers la réception du moteur (`to.x` du fait `reception`), chasse, réception par le
  receveur désigné, plaquage par la chasse, ruck.
- **Temps de jeu du moteur** (`porte`) : le porteur désigné reçoit et court jusqu'au `to.x` du
  fait ; le plaqueur l'attend au bout du gain (le plaquage n'est accepté qu'à moins de 4 m du
  point) ; un gain d'au moins 10 m est montré comme une percée (`franchi`).
- **Franchissement** : percée, plaquages ratés des deux défenseurs les plus proches, puis
  plaquage réussi par la couverture (l'arrière, sinon le défenseur le plus profond) au point
  du moteur, ruck ; ensuite la suite décidée par le moteur, ou fin 1,8 s après le ruck formé.
- **Récupération** (`recup`) : le ruck est gagné par l'équipe que le moteur désigne ; le
  gratteur nommé par le moteur ramasse (il a le temps d'arriver ; jamais un ramassage de loin).
- **Jeu au pied** (loi 10) : le botteur garde le ballon 0,6 s puis frappe ; trajectoire en
  cloche (1,9 à 4,2 s de vol) jusqu'au point du moteur ; les partenaires devant le botteur
  s'arrêtent et reculent jusqu'à être remis en jeu (un partenaire en jeu les dépasse, ou
  l'adversaire a joué le ballon depuis une seconde) ; la chasse s'arrête à distance du
  receveur tant que le ballon est en l'air ; réception (si le receveur est en retard, le ballon
  tombe au point du moteur et il le ramasse), plaquage par le premier chasseur, ruck, fin ; ou
  ballon sorti en touche au point du moteur, fin. Botteur d'un coup de pied en touche que le
  moteur ne nomme pas : l'ouvreur, sinon l'arrière, sinon le demi (choix de mise en scène).
- **Consigne défensive** (`plans.defence`) : `pression` = ligne plus près du ruck (0,6 m
  derrière la ligne de hors-jeu) et montée plus rapide jusqu'à 0,9 m du ballon ; `prudente` =
  2,6 m derrière la ligne de hors-jeu, montée lente, 3,2 m de profondeur ; `equilibre` comme
  en première tranche (valeurs choisies, non mesurées).
- **Durée** : 12 s au moins ; au plus 25 s + 6 s par fait du moteur montré en amont
  (plafond 50 s). Si aucun tirage ne tombe dans l'intervalle, un second tirage est essayé.

### 10.5 Garanties ajoutées et contrôles

`tests/match-choregraphe.cjs` (13 tests) sur les 9 essais de la première tranche et sur
**32 temps forts entiers** du moteur natif (`tests/fixtures/match-choregraphe-tranche2.json` :
graines 3, 7, 11, 42 et 99 au niveau dynamique, plus 5 jeux au pied de la graine 7 au niveau
intégral ; entrées réelles, profils compris, obtenues par l'option d'essai
`matchChoreography:'entrees'` du pont).

| Garantie | Contrôle |
| --- | --- |
| Chaque type et chaque ouverture | essai, franchissement, jeu au pied ; jeu ouvert, mêlée, touche, coup d'envoi |
| Chaque fait montré, dans l'ordre | un jalon par plan couvert (`jalonsAttendus`), dans la durée, temps croissants |
| Issue du moteur | chaque porteur désigné a le ballon ; chaque gain finit par un plaquage à 6 m au plus du point du moteur ; essai : marqueur, point d'essai ; hors essai : jamais d'aplati ni de ballon dans l'en-but adverse ; franchissement : percée du porteur désigné ; jeu au pied : un coup de pied du botteur, réception à 2 m au plus du point du moteur (par le receveur du moteur au coup d'envoi) ou sortie en touche à 0,5 m du point ; récupération : ballon chez l'équipe désignée |
| Lois | mêlée : arrières à 5 m du dernier pied jusqu'au ballon sorti ; touche : arrières à 10 m jusqu'à la passe du sauteur ; jeu au pied : un partenaire devant le botteur n'avance pas plus que sa distance de freinage tant qu'il n'est pas remis en jeu ; hors-jeu au ruck, passes, plaqué (comme au § 5) |
| Consigne défensive | au ruck, la ligne en pression attend plus près que la prudente (≥ 75 % des cas), même issue |
| Vitesses, accélérations, ballon continu, déterminisme | comme au § 5, sur tous les temps forts |
| Chevauchement | 0,6 m hors contact ; **0,35 m** entre un joueur au sol et celui qui l'enjambe |
| Match natif | même journal, même score, mêmes temps forts avec ou sans drapeau ; aucune erreur de mise en scène ; chaque essai en jeu courant mis en scène, et au moins autant d'autres temps forts |

Évolutions du moteur de mouvement : évitement anticipé sur 2 s (au lieu de 1,4 s), écart visé
0,8 m, séparation qui peut reprendre une part de l'accélération du pas (toujours sous le
plafond), freinage prioritaire devant les lignes de touche et de ballon mort, le porteur en
percée n'ignore que ses adversaires (plus ses partenaires). Correction : le porteur qui attend
son receveur avance de 5 m au plus pour fixer (il reculait sans fin).

### 10.6 Côté Godot

- `match_choregraphie.gd` : version 2 ; sur une coupe (`coupe`), ni raccord de position ni
  raccord du ballon ; poses procédurales `melee` (lié, bas), `saut` (levé de 1 m, monté et
  descendu à 3 m/s), `soutien_saut` ; gestes de la bibliothèque `lancer`, `reception_haute`
  (sauteur), `coup_de_pied`.
- Régie (`match_temps_forts.gd`) : les pistes démarrent au plan `premier` et couvrent jusqu'au
  plan `dernier` ; à chaque jalon, le plan courant avance (légende, journal ouvert, score),
  jamais avant (l'essai jamais avant l'aplati) ; cadrage large pour le jeu au pied, de longue
  course pour le franchissement ; coupe d'entrée sur une remise en jeu formée. Pistes sans
  `premier`/`dernier`/`jalons` cohérents : refusées, repli sur les plans habituels.
- `tests/godot-match-choregraphie.{cjs,gd}` : la vue suit un temps fort par type et par
  ouverture (neuf pistes en plus de l’essai de la première tranche).
- `tests/godot-match-choregraphie-capture.{cjs,gd}` : outil manuel de capture (vue 3D seule,
  cadrage rapproché des temps forts, une image par 1/30 s) ; sans `CD_CHOREGRAPHIE_CAPTURE`, il
  ne fait rien.

### 10.7 Choix faits sans Léo (12 novembre, nuit)

- Gains du moteur montrés « à 6 m près » : la course du porteur et l'arrivée du plaqueur sont
  simulées, le point exact varie.
- Un temps de jeu d'au moins 10 m est montré comme une percée (plaquages ratés, couverture).
- Tolérance de 0,35 m près d'un joueur au sol (on l'enjambe), au lieu de 0,6 m.
- Durée jusqu'à 50 s pour un temps fort de quatre ou cinq faits (mêlée, trois temps de jeu,
  essai) : un tel temps fort dure ce qu'il dure. À juger sur la vidéo.
- Botteur d'un coup de pied en touche non nommé par le moteur : l'ouvreur.
- Largeur des coups de pied (le moteur ne donne que `x`) : près d'un receveur possible.
- Option d'essai `matchChoreography:'entrees'` du pont : joint l'entrée du chorégraphe au temps
  fort, pour refaire le jeu d'entrées ; jamais utilisée par le jeu.

### 10.8 Limites

- Ballon porté, pénalité, faute de main et touche sur ballon porté restent aux gestes
  (ballon porté et pénalités : couverts par la troisième tranche, § 11).
- Pas de contestation au sol, de jeu au pied rasant ni de rebond simulé (un ballon non pris
  tombe et le receveur le ramasse) ; pas de 50:22 vu dans le jeu d'entrées.
- La défense ne lit toujours pas l'attaque ; la consigne ne change que la profondeur et la
  vitesse de montée.
- Gestes manquants dans la bibliothèque : aplati, passe, liaison au ruck et en mêlée (poses
  procédurales).
- Au niveau dynamique, les jeux au pied de jeu courant sont rares dans les temps forts (seuil
  d'intérêt) : on les voit surtout aux coups d'envoi ou au niveau « match complet ».

### 10.9 Exécuté (Linux, 2 cœurs partagés, Godot 4.7.2, une suite à la fois)

| Suite | Résultat |
| --- | --- |
| `tests/match-choregraphe.cjs` | 13 sur 13 (≈ 60 s) : 9 essais de la première tranche et 32 temps forts entiers ; match natif graine 7 avec et sans drapeau identique |
| `tests/godot-match-choregraphie.cjs` | 207 923 contrôles, 0 échec : la vue suit dix pistes (essai de la première tranche, puis une par type et ouverture) |
| `tests/godot-match-temps-forts.cjs` | 6 modes, 297 contrôles, 0 échec ; mode `choregraphie` (14) : temps fort de la 14e minute joué par les pistes depuis sa remise en jeu, rien annoncé avant son jalon, pause qui fige, ni échéance ni refus |
| Relancés sans échec | `match-direct` (4), `match-highlights` (12), `match-essai-visible` (7), `match-structured-facts` (3), `match-actions` (1), `godot-match-essai`, `godot-match-gestes`, `godot-match-gestes-adaptes`, `godot-match-cadrage-arret`, `godot-match-animations`, `godot-match-framing`, `godot-match-cut`, `godot-match-presentation`, `godot-match-journal` |

Vidéo de contrôle (hors dépôt, `choregraphe-tranche2.mp4`) : `tests/godot-match-choregraphie-capture.cjs`
sous Xvfb, rendu logiciel, `--fixed-fps 30` (vitesse réelle), 1280×720, bibliothèque Mixamo
`CD_MATCH_ANIMATIONS`, sept séquences du jeu d'entrées (2 min 30, 4 496 images) avec un titre
court incrusté au montage : essai depuis une mêlée (30,6 s de pistes), essai depuis une touche
(21,6 s), franchissement plaqué puis ballon récupéré (19,6 s), franchissement après le coup
d'envoi (20,6 s), jeu au pied avec chasse et réception (24 s), jeu au pied en touche (13,6 s),
coup d'envoi avec chasse et récupération (12,8 s) :

```
CD_CHOREGRAPHIE_CAPTURE=/chemin/images CD_GODOT_EXE=/chemin/Godot_v4.7.2-stable_linux.x86_64 \
CD_MATCH_ANIMATIONS=/chemin/mixamo-match.res \
CD_CHOREGRAPHIE_SOURCES="graine 3, club 0, 10′;graine 7, club 0, 67′;graine 42, club 0, 30′;graine 11, club 0, 40′;graine 7, club 0, 58′ (intégral);graine 7, club 0, 74′ (intégral);graine 99, club 0, 6′" \
xvfb-run -a -s "-screen 0 1280x720x24" node tests/godot-match-choregraphie-capture.cjs
```

### 10.10 Non vérifié

- Rien sous Windows ni avec une carte graphique ; vidéo en vue 3D seule (pas dans l'interface
  complète : légende, bandeau et journal ne sont contrôlés que par le test de la régie).
- Crédibilité rugbystique des remises en jeu (forme de la mêlée, timing de la touche), des
  chasses et des couvertures : à juger par Léo sur la vidéo.
- Les jeux au pied de jeu courant et en touche ne viennent que de la graine 7 au niveau
  intégral ; aucun 50:22 ni renvoi aux 22 vu.

## 11. Troisième tranche (12 novembre 2026, fin de nuit)

Pistes toujours en **version 2** : les ajouts (types, états, événements) ne changent pas le
format ; la vue d'avant les lirait sans les poses nouvelles.

### 11.1 Ce qui est couvert

| Type (`type`) | Fait clé | Plans couverts | Fin |
| --- | --- | --- | --- |
| `ballon_porte` | `setpiece-win` d'une touche avec `move:'maul'` ou `porte:true` (le moteur écrit `porte` sur la conquête quand un essai sur ballon porté suit) | la touche (`lineout`), la conquête, et l'essai `origin:'maul'` s'il suit | essai aplati par le marqueur du moteur, ou arrêt au gain du moteur et ballon sorti vers le demi |
| `penalite_au_but` | `goal` ou `miss` précédé du coup de sifflet (`penalty`, cartons éventuels entre les deux) | le coup de sifflet, les cartons, le tir | ballon passé entre les poteaux ou à côté, puis mort dans l'en-but |
| `penalite_en_touche` | `touch` de cause `penalty-touch` précédé du coup de sifflet | le coup de sifflet, les cartons, la frappe | ballon sorti en touche au point du moteur |

Ordre de choix du fait clé dans un temps fort : essai (en jeu courant ou sur ballon porté),
franchissement, ballon porté sans essai, pénalité au but, jeu au pied, pénaltouche. La touche
gagnée après une pénaltouche se joue ensuite par les gestes existants (une seule série de
pistes par temps fort).

**Pénalité « jouée à la main » : non montrée.** Le moteur (`executePenaltyChoice`) ne connaît
que le tir au but et la pénaltouche ; une pénalité jouée vite à la main n'existe pas dans ses
faits. La montrer inventerait une décision : le moteur reste la source de vérité. À ajouter au
moteur d'abord si Léo la veut (choix tactique, risque, gain).

Au niveau « dynamique », la sélection des temps forts retire la pénaltouche de ses plans
(`match-highlights.cjs`) : `penalite_en_touche` ne se voit qu'au niveau « match complet ».

### 11.2 Déroulé

- **Ballon porté** (lois 16 et 18) : la touche formée de la deuxième tranche (alignements,
  lancer, sauteur levé), puis, à la retombée du sauteur, les avants de l'équipe qui lance se
  lient autour de lui (sauteur devant, ses leveurs de chaque côté, les autres derrière, le
  porteur au fond) et six avants adverses se lient en face (talonneur et n° 8 restent en garde
  sur les côtés). État `maul` à l'arrivée à sa place. Formé quand le porteur, trois partenaires
  et un adversaire sont liés ; le ballon est transmis de main en main au porteur du fond, puis
  le ballon porté avance (montée en allure, 1,3 à 1,9 m/s selon la distance que le moteur
  donne) jusqu'au gain du moteur (`to.x` de la conquête). Avec essai : il continue dans
  l'en-but et le marqueur du moteur aplatit au point d'essai (jalon de l'essai à l'aplati,
  joie, déception) ; sans essai : il s'arrête, et une seconde plus tard le ballon sort vers le
  demi (passe en retrait), les liés se délient. Hors du ballon porté, chacun reste derrière le
  pied le plus en arrière de ses joueurs liés ; les arrières restent à 10 m (ou sur leur ligne
  de but) jusqu'à la fin de l'alignement (tous les pieds du ballon porté au-delà de la ligne de
  touche) ou au ballon sorti.
- **Porteur du fond** : le marqueur du moteur s'il y a essai ; sinon le joueur que le moteur
  nomme sur la conquête s'il est un avant, sinon le n° 8.
- **Pénalité au but** (loi 20) : le botteur du moteur va au point de la faute (au trot s'il
  est loin), prend le ballon, le pose (état `placement`), recule de 4,2 m et s'écarte de 1,8 m
  (élan), attend, court, frappe. Le ballon passe la ligne de but entre les poteaux (5,6 m) à
  4,6 m de haut (réussite) ou au point du moteur à côté (`to.y` = 42), puis retombe 7 m dans
  l'en-but. Le jalon du tir (score) tombe au passage de la ligne, jamais avant. Adversaires à
  10 m au moins du point, vers leur ligne ; partenaires derrière le ballon.
- **Pénaltouche** : même arrivée au point, puis frappe de volée jusqu'au point de sortie du
  moteur (trajectoire et règles de jeu au pied de la deuxième tranche) ; les avants se
  rapprochent de la touche. Botteur non nommé par le moteur : l'ouvreur, sinon l'arrière,
  sinon le demi.
- **Cartons** entre le coup de sifflet et le tir : leur jalon tombe une seconde après le début
  (la légende montre le carton avant le tir).

### 11.3 La défense lit l'attaque

En jeu courant et pendant les rucks, la ligne défensive (hors arrière) compte les attaquants
debout à moins de 30 m du ballon de chaque côté : elle glisse vers le côté fort de 1,3 m par
attaquant d'écart (9 m au plus), avec **5,2 m entre deux défenseurs** (au lieu d'une ligne
étalée sur toute la largeur, qui restait centrée sur le terrain quel que soit le ballon).
L'ailier du côté faible (n° 11 ou 14) sort de la ligne et recule à 11 m en second rideau, à
17 m du ballon en largeur : avec l'arrière, il couvre le jeu au pied. La consigne
(pression, prudente) règle toujours la profondeur et la montée. Valeurs choisies, non mesurées.

### 11.4 Corrections de la régie

Quand les pistes ouvraient le premier temps fort du match (coup d'envoi, sans scène de
départ), aucun joueur n'était encore créé dans la vue : seuls le ballon et son anneau se
voyaient pendant tout le coup d'envoi. La régie pose maintenant la scène du plan (figée)
avant les pistes si un joueur des pistes manque à l'écran. Le défaut existait depuis la
deuxième tranche ; il n'apparaissait pas dans la vidéo de la deuxième tranche (vue 3D seule,
qui posait une première image).

Pendant les pistes, un tir au but devient le plan courant à son jalon (passage du ballon) :
la légende montre maintenant son résultat et la clameur part à cet instant, au lieu de
« Tir au but. » jusqu'à la fin des pistes. Le bandeau du score, lui, avance à la fin du plan
(après l'essai ou le tir), comme sans pistes.

### 11.5 Garanties ajoutées et contrôles

`tests/match-choregraphe.cjs` (17 tests) ajoute le jeu d'entrées
`tests/fixtures/match-choregraphe-tranche3.json` : **20 temps forts entiers** du moteur
natif, profils compris (option `matchChoreography:'entrees'`) : 8 ballons portés (6 essais,
2 arrêts ; graines 3, 7, 11, 13, 21, 99, le club dirigé jouant la combinaison de touche
« ballon porté » via `playbook_set`), 8 pénalités au but (6 réussies, 2 manquées, dont 3 après
un carton ; graines 3, 5, 7, 42, 99) et 4 pénaltouches (graines 3 et 11, niveau « match
complet »).

| Garantie | Contrôle |
| --- | --- |
| Chaque type, chaque fait montré | jalons = plans couverts, dans l'ordre, dans la durée ; coupe d'entrée sur la touche, pas sur une pénalité |
| Ballon porté | lancer et saut ; au moins 6 attaquants et 4 défenseurs liés ; porteur du fond ; loi 16 (hors du ballon porté, derrière le pied le plus en arrière des liés de son équipe, contrôlé tant que le ballon porté est dans le champ de jeu) ; loi 18 (arrières à 10 m ou sur leur ligne jusqu'à la fin de l'alignement) ; essai : marqueur du moteur, aplati au point d'essai, aucun plaquage, jalon à l'aplati ; arrêt : au gain du moteur (à 0,1 m), ballon sorti vers le demi, jamais dans l'en-but |
| Pénalités | seul le botteur a le ballon ; frappe du botteur ; adversaires à 10 m du point à la frappe (loi 20) ; au but : ballon posé, frappé du point, passage entre les poteaux au-dessus de la barre (réussite) ou à côté (échec), jalon au passage ; en touche : sortie au point du moteur, jalon à la sortie |
| Défense qui lit l'attaque | aux rucks des 32 temps forts de la deuxième tranche où l'écart d'attaquants d'un côté à l'autre est d'au moins 3 : ligne vers le côté fort dans 37 cas sur 40 (30 avant), ailier en second rideau à 6 m au moins derrière la ligne dans 29 cas sur 40 (0 avant) ; seuils du test : 85 % et 65 % |
| Communes | vitesses et accélérations, chevauchements, ballon continu, déterminisme, passes, ruck : sur les 61 temps forts des trois jeux d'entrées ; match natif identique avec ou sans drapeau |

`tests/godot-match-choregraphie` lit en plus un ballon porté avec essai, un sans essai, une
pénalité réussie, une manquée et une pénaltouche (liés du ballon porté, sauteur, ballon posé,
frappe montrés). Le mode `choregraphie` du test de la régie contrôle que chaque joueur des
pistes est à l'écran pendant les pistes.

### 11.6 Exécuté (Linux, 2 cœurs partagés, Godot 4.7.2)

| Suite | Résultat |
| --- | --- |
| `tests/match-choregraphe.cjs` | 17 sur 17, match natif graine 7 avec et sans drapeau identique |
| `tests/godot-match-choregraphie.cjs` | 269 524 contrôles, 0 échec (quinze pistes) |
| `tests/godot-match-temps-forts.cjs` | 6 modes, 298 contrôles, 0 échec ; mode `choregraphie` : 15 contrôles, dont « chaque joueur des pistes à l’écran » |
| Relancés sans échec | `match-direct` (4), `match-highlights` (12), `match-essai-visible` (7), `match-structured-facts` (3), `match-actions` (1), `godot-match-essai`, `godot-match-gestes`, `godot-match-gestes-adaptes`, `godot-match-cadrage-arret`, `godot-match-animations`, `godot-match-framing`, `godot-match-cut`, `godot-match-presentation`, `godot-match-journal` |

`node scripts/build-rugby-common.cjs --check` : base commune inchangée après la fusion de
`origin/main` (conflit de `docs/ressources-utiles.md` résolu en gardant les deux ajouts).

### 11.7 Vidéo de contrôle dans l'interface complète

Vidéo hors dépôt `choregraphe-tranche3.mp4` (1 min 50, 1280×720, 30 images/s) : **la vraie
interface** (bandeau du score, légende, commandes, écran intermédiaire), le vrai moteur lancé
par Godot, `CD_MATCH_CHOREGRAPHE=1`, bibliothèque Mixamo, Xvfb en rendu logiciel,
`--fixed-fps 30` (vitesse réelle). Cinq séquences, un titre incrusté au montage :

| Séquence | Match | Pistes |
| --- | --- | --- |
| Ballon porté depuis la touche, essai (11′) | graine 3, club 0, combinaison de touche « ballon porté » | 27,2 s lues en 27,23 s ; légende de l'essai à l'aplati, score à la transformation |
| Pénalité tentée au but, réussie (10′) | idem | 16 s lues en 16,07 s ; « Pénalité réussie » au passage du ballon |
| Essai en jeu courant (14′) | graine 7, club 0 | 18 s lues en 18,03 s ; légende vide avant l'aplati |
| Franchissement (14′) | idem | 25,6 s lues en 25,63 s ; légende qui avance à chaque jalon |
| Coup d'envoi, chasse et réception (0′) | graine 3 | 12 s lues en 12,07 s ; joueurs à l'écran (correction du § 11.4) |

Aucune échéance ni piste refusée dans les deux captures. La pénaltouche n'y figure pas : au
niveau « match complet », aucune n'est tombée entre la 21e et la 46e minute de la graine 11
dans Godot (le match lancé par l'interface diffère de celui du pont pour une même graine) ;
elle n'est vue que dans les tests et la vue 3D.

Commandes (depuis la racine) :

```
# Ballon porté, pénalité, coup d'envoi
CD_MATCH_CHOREGRAPHE=1 CD_MATCH_ANIMATIONS=/chemin/mixamo-match.res \
CD_GODOT_EXE=/chemin/Godot_v4.7.2-stable_linux.x86_64 CD_MATCH_TEMPS_FORTS_PROOF=/chemin/capA \
CD_MATCH_TEMPS_FORTS_SEED=3 CD_MATCH_TEMPS_FORTS_MINUTES=14 CD_MATCH_TEMPS_FORTS_HORLOGE=eclair \
CD_MATCH_TEMPS_FORTS_EVERY=1 CD_MATCH_TEMPS_FORTS_GEL=3000 CD_MATCH_TEMPS_FORTS_LIMITE=6000 \
CD_MATCH_TEMPS_FORTS_GODOT_ARGS="--fixed-fps 30" CD_MATCH_TEMPS_FORTS_TOUCHE=maul \
CD_MATCH_TEMPS_FORTS_TYPES=jeu_au_pied,penalite_au_but,ballon_porte \
xvfb-run -a -s "-screen 0 1280x720x24" node tests/godot-match-temps-forts-capture.cjs
# Essai et franchissement : graine 7, CD_MATCH_TEMPS_FORTS_DEPUIS=13, MINUTES=30,
# TYPES=essai_jeu_courant,franchissement (sans TOUCHE)
```

Le rendu logiciel est lent (environ 0,5 s par image) : une capture de ce type prend 30 min.
`GEL` doit dépasser la durée réelle d'un plan de pistes (sinon faux diagnostic « figé »).

### 11.8 Choix faits sans Léo

- Pénalité jouée à la main non montrée : absente des faits du moteur (§ 11.1).
- Porteur du fond d'un ballon porté sans essai : le joueur nommé par le moteur s'il est un
  avant, sinon le n° 8 ; avec essai, le marqueur (un avant, d'après le moteur).
- Six avants adverses liés, talonneur et n° 8 en garde ; poussée de 1,3 à 1,9 m/s.
- Ballon porté sans essai : jalon de la conquête à la prise du sauteur (comme une touche),
  arrêt au gain du moteur puis ballon sorti vers le demi.
- Pénalité au but : élan de 4,2 m en arrière et 1,8 m de côté ; ballon 4,6 m au-dessus de la
  ligne de but sur une réussite ; un échec passe à côté (point du moteur), jamais sous la barre.
- Pénaltouche : botteur non nommé par le moteur = l'ouvreur.
- Défense : 5,2 m entre deux défenseurs, glissement de 1,3 m par attaquant d'écart, ailier du
  côté faible en second rideau à 11 m.
- Outil de capture : temps forts non retenus joués à vitesse 6 sans image.

### 11.9 Limites

- Le moteur donne des essais sur ballon porté lancés à 25 ou 30 m de la ligne : ils sont
  montrés tels quels (environ 16 s de poussée), ce qui reste long pour un ballon porté.
- Pas de ballon porté qui s'écroule, qui tourne ou qui sort en touche (le moteur ne le décide
  pas) ; pas de contestation dans le ballon porté.
- Les pistes s'arrêtent au fait clé : la touche qui suit une pénaltouche est jouée par les
  gestes existants.
- Un ballon porté suivi d'un temps de jeu puis d'un essai en jeu courant reste aux gestes
  jusqu'au ballon porté compris : les pistes de l'essai partent du temps de jeu suivant.
- Bibliothèque Mixamo sans clip de liaison ni de pose du ballon : poses procédurales `maul`
  et `placement`.
- La lecture de l'attaque ne vaut que pour la ligne défensive en jeu courant et au ruck ; pas
  de montée ciblée sur le receveur.

### 11.10 Non vérifié

- Rien sous Windows ni avec une carte graphique ; fluidité réelle inconnue (rendu logiciel).
- Crédibilité rugbystique du ballon porté (forme, allure), de l'élan du botteur et de la
  glissade défensive : à juger par Léo sur la vidéo ; valeurs choisies, non mesurées.
- Pénaltouche vue dans les tests et la vue 3D, pas dans l'interface complète (§ 11.7).
- Pénalité manquée et ballon porté sans essai vus dans les tests et la vue 3D seulement.

### 11.11 Suite conseillée

1. Juger la vidéo ; régler la forme et l'allure du ballon porté, l'élan du botteur.
2. Ajouter au moteur la pénalité jouée à la main (décision, risque, gain), puis la mettre en
   scène.
3. Enchaîner pénaltouche, touche et ballon porté dans une même série de pistes.
4. Faute de main, ballon porté qui s'écroule ou sort, contestation au sol.
5. Clips Mixamo de liaison (ruck, mêlée, ballon porté), de pose du ballon et d'aplati.
