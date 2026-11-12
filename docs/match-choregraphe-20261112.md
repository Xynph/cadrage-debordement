# Chorégraphe de temps forts — conception et première tranche (12 novembre 2026)

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
