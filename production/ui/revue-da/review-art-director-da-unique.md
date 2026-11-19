# Relecture art-director : maquettes en direction unique (DA3)

> Phase 4 de `/team-ui` (relecture). Agent : art-director (CCGS), mode autonome.
> Référence unique : `design/art/art-bible.md` (19/11/2026).
> Objet : 19 écrans × 3 mises en page à 1920×1080 (`scratchpad/da3/apercus/`), coque `coque-1.png` / `coque-2.png`, avis `da3/frag/*.html`.
> Toutes les captures ont été regardées (57 + 2). Les avis ont été lus en extrait (bloc `.avis`).

VERDICT : CONCERNS. La langue visuelle tient presque partout : mêmes jetons, mêmes polices, l'inclinaison au bon endroit, et l'or n'est jamais pris pour autre chose que Continuer ou l'héritage. Ce qui trahit la charte, ce sont des **formes** (cercles parfaits partout où le logo demande l'ovale ou la plaque inclinée), deux **verts interdits**, un **étalonnage d'image** absent qui fait du jour de match un autre jeu, et des **données contradictoires d'un écran à l'autre** qui cassent l'impression d'un seul jeu bien davantage que n'importe quel style.

---

## 1. Défauts transversaux (à corriger une fois, partout)

### T1 · Cercles parfaits au lieu de l'ovale ou de la plaque : BLOQUANT
Règle §3 B : « Jamais : cercle parfait, pastille ronde, numéro de maillot dans un rond ».
- **Écusson du club** (rail de la coque, accueil, création, bureau, avant-match 90 px, après-match, classement) : rond partout.
  Correction : l'écusson devient une **plaque `club`** rectangulaire, bord droit incliné de 10°, initiales en BC ExtraBold Italic `ivoire` (40 × 28 px dans le rail, 28 × 20 dans les tableaux, 120 × 84 à l'affiche). C'est déjà la plaque du bandeau de score : le bureau et le direct parlent alors la même langue.
- **Médaillon de Gabi** (barre haute, accueil, chargement) : cercle plein. L'art bible veut l'**ovale tracé `ivoire-2`** de 40 px (deux virgules qui s'affinent, sans fermer).
- **Numéros de joueurs dans des ronds** : composition (10-1/2/3 : pastilles rondes pleines), préparation (« Leur XV probable », 11-1/3), avant-match (« 8 », « 10 » à surveiller), fiche joueur (mini-terrain 1, 2, 6). Correction : **ovale 1,5:1**, nous = plein `club-trait`, adversaire = anneau 2 px à sa couleur dérivée. L'entracte (14) le fait déjà juste : c'est la référence.
- Points « non lu » ronds (réception, presse « conférence ouverte ») : remplacer par le filet incliné 3 px de sélection en `ivoire` (non lu) ou un petit ovale.

### T2 · Pastille N « demi-pleine » illisible : BLOQUANT (tranché)
Aujourd'hui la limite plein/vide coupe la lettre N en deux (bureau, classements, fiche joueur, après-match) : à 16-20 px de haut, la lettre disparaît dans la frontière.
**Forme retenue** (règle : la lettre est toujours sur un fond uni) :
- **V** : ovale plein `v`, lettre `nuit`.
- **N** : ovale à fond `panneau-3`, **anneau en tirets** 2 px `n` (tiret 3 px, espace 2 px), lettre N `ivoire` (12,85:1). « Ni plein ni vide » se lit par le tiret, pas par une moitié.
- **D** : ovale vide, anneau continu 2 px `d`, lettre `d`.
- Taille unique : 24 × 16 px dans les tableaux, 36 × 24 dans les fiches, 72 × 48 au verdict d'après-match. Rapport 1,5:1 partout (aujourd'hui les petites pastilles des formes sont presque rondes).
- À reporter dans l'art bible §4.4 (la ligne « N ovale demi-plein » devient « N ovale à anneau en tirets »).

### T3 · Verdict « Sous tension » sans couleur dédiée : BLOQUANT (tranché)
Problèmes vus : en Finances, le verdict actif est une **pastille `ivoire` pleine** qui se lit comme le bouton ivoire (17-1 en a deux par écran avec « Ajuster le budget ») ; « Dans le rouge » porte un ▲ ; et le Club affiche « Solide » avec une **coche verte** (vert hors V/disponible). Deux verdicts, deux systèmes.
**Composant unique « verdict à trois paliers »**, partagé par Finances (trésorerie), Club (confiance du conseil), Presse (pression) :
- Mot du palier en BC Bold Italic 18 `ivoire`, précédé d'un pictogramme : ✓ (sain), **!** dans un parallélogramme incliné (sous tension), ✕ (en danger).
- Sous le mot, jauge en 3 segments `panneau-2` ; le segment actif passe en `panneau-3` avec le marqueur incliné 3 px `ivoire` à gauche (même geste que la ligne choisie). Seuils écrits sous la jauge.
- Couleur : **aucune** pour sain et sous tension (`ivoire`) ; `d` autorisé **seulement** pour le palier « en danger » (c'est une alerte), toujours avec ✕. Jamais `v`, jamais `or`, jamais d'aplat ivoire.
- Vocabulaire : éviter « dans le vert / dans le rouge », qui appellent des couleurs interdites. Proposé : Finances « Saine / Sous tension / En danger » ; Club « Solide / Fragile / Menacé » (déjà juste, retirer la coche verte) ; Presse « Calme / Sous tension / Tempête ».
- Les trois paliers ne sont pas des boutons : pas d'onglets cliquables comme en 17-1/2/3.

### T4 · Vert hors V / disponible : BLOQUANT
- Club (18-1/2/3) : coche ronde verte devant « SOLIDE » → composant T3.
- Composition (10-1/2/3) : « ✓ Feuille valide » en `v` → ✓ `ivoire` ; la validité de la feuille n'est ni une victoire ni une disponibilité.

### T5 · Étalonnage des illustrations absent : le jour de match sent un autre jeu : BLOQUANT
L'interface est la même, mais les images ne le sont pas : tunnel à joueurs en **survêtements verts** et **drapeaux français** (12), vestiaire en **maillots verts** (15) alors que le club est bordeaux, accueil 3 avec **montagnes** pour un « Fenbank Ground » de marais, presse et recrutement à dominante vert-bleu, stade du direct bleu-gris froid. Résultat : le bureau est noir chaud, le match est vert et froid.
Correction :
- appliquer l'étalonnage commun §6 à la source (ombres vers `fond`, hautes lumières vers `or-vif`/`ivoire`, verts −20 %) ; pour les maquettes, un filtre CSS de prévisualisation suffit ;
- écarter les images qui contredisent l'identité du club : tunnel et vestiaire doivent montrer le **bordeaux** (ou des maillots neutres), sans drapeau national ; accueil 3 : reprendre `entry-ground.jpg` (même stade que 01-1 et 13).
- Personnages du direct (13) : les silhouettes 2D posées sur une photo font « autre jeu ». Acceptable comme maquette d'habillage, à condition d'écrire sur la planche qu'elles tiennent la place de la 3D.

### T6 · Données contradictoires d'un écran à l'autre : BLOQUANT pour la revue avec Léo
Ce n'est pas du style, mais c'est ce qui casse le plus « un seul jeu » : Léo lira les écrans à la suite.
- Postes : Kyle Fairclough est centre (bureau), pilier gauche (effectif, composition), pilier droit (entracte), 2e ligne (finances). Brodie Jowett est talonneur (effectif, fiche), n° 8 (composition), 3e ligne (bureau), ailier (finances). Sebastian Atherton : pilier droit (composition) puis ouvreur (entracte, direct).
- Blessés : bureau (Gannon, Ollerenshaw), effectif (Marland, Hargreave), club (Smart, Fairclough, Marsh), formation (Dupuis).
- Résultats : J8 = victoire 22-17 à Kingsey (presse) ; 27-19 contre Trentwood (classement, finances) ; 22-18 à Westmoor (fiche joueur).
- Points de Northmere : 31 (bureau), 33 (classement), 34 (préparation, avant-match).
- Stade : 6 200 places (création) / 8 400 (club). Président : Martin Holloway / Margaret Holloway / Arthur Bellamy. Salaire de Jowett : 1 450 €/sem. (effectif) / 4 100 € (finances).
Correction : une **fiche de données de maquette unique** (effectif 40 avec poste, numéro, état ; classement J8 ; résultats J1-J8 ; club) à laquelle tous les générateurs lisent, puis régénération des 57 captures.

### T7 · Zones de classement de la Division d'accession : BLOQUANT (tranché)
Référence juste : **16 Compétitions** (« 1er à 4e : phases finales (demi-finales croisées, 1er contre 4e) · pas de relégation automatique », liseré + ▲ + mot). Et 18 Club (« finir dans les 4 premiers et disputer les phases finales »).
Écrans qui contredisent :
- **02 Création** (1, 2, 3) : « le premier monte en Élite si son stade remplit le cahier des charges ; du 2e au 5e, barrages pour le titre ; le dernier passe devant la commission » → remplacer par « Les quatre premiers jouent les phases finales (demi-finales croisées, 1er contre 4e) ; le champion joue le barrage d'accession contre le 13e de l'Élite. Pas de relégation automatique. » La colonne « Attente du conseil » garde « Finir dans les 4 premiers ».
- **04 Bureau** (1, 2, 3) : « ◆ 2e à 5e : barrages d'accession » et « Objectif du conseil : finir dans les 5 premiers » → « ▲ 1er à 4e : phases finales · pas de relégation automatique » ; objectif « Finir dans les 4 premiers ». Symbole ▲, pas ◆.
- **06 Presse** (2, 3) : « dans la zone des barrages d'accession » → « dans la zone des phases finales ».
- **15 Après-match** (2) : légende « ▲ montée directe · ◆ barrages d'accession », ▲ sur le 1er et ◆ du 2e au 5e → ▲ sur 1 à 4, rien au 5e, légende du 16.
- 16-3 (Élite, 13e « barrage d'accession contre le champion de la Division d'accession ») : cohérent avec ce qui précède, à garder.

### T8 · Échap en match = pause + menu : BLOQUANT (tranché, décision de Léo)
Règle unique pour tous les écrans hors coque (avant-match, direct, entracte, après-match, chargement) : **Échap ferme d'abord ce qui est ouvert ; s'il n'y a rien, met le match en pause et ouvre le même menu pause que la coque** (`coque-2.png` : Reprendre en tête, focus dessus, Échap le referme). Espace reste la pause seule, sans menu.
- 12 Avant-match : le haut dit « Menu Échap », le pied dit « Échap retour » (12-1, 12-3) → pied « Échap menu ».
- 13 Direct 1 et 2 : seul « Pause Espace » est écrit → ajouter « Menu Échap » à côté (comme 13-3), et livrer une capture « menu ouvert en match » : panneau 480 px sur voile `nuit` 70 %, bandeau de score visible au-dessus du voile, « Reprendre le match » en premier.
- 14 Entracte : « Échap : ferme la fenêtre, sinon pause » → « sinon menu » (le match est déjà arrêté).
- 15 Après-match 3 : « Échap ne quitte pas cet écran » → Échap ouvre le menu ; « Reprendre » ramène ici.
- 03 Chargement 1 : « Échap : arrêter » est juste (on ferme ce qui est ouvert).

### T9 · Coque strictement identique : MINEUR
- Identique sur 04-11 et 16-19 (rail, barre haute, bouton Menu + Échap, Continuer, date, Gabi F1) : bon.
- 10 Composition : Continuer porte « Feuille à valider » et pousse la recherche de 40 px vers la gauche → largeur fixe de Continuer (220 px), le motif de blocage tronqué si besoin, la recherche ne bouge jamais.
- 03 Chargement 1 et 2 : la coque sous le voile est redessinée (sans écusson, sans recherche, autres tailles) → poser le vrai `coque.html` sous le voile.
- Écart avec l'art bible, à faire trancher, pas à corriger dans les maquettes : le rail des maquettes n'a pas « Entraînement » et ajoute Presse, Sélections et Carrière ; l'art bible §7 cite dix entrées pour neuf numéros. Mettre l'art bible à jour sur la coque des maquettes.

### T10 · Gabi et portraits : MINEUR (dette d'asset déjà signalée)
- L'atlas opaque de Gabi dessine un rectangle bleu-gris visible sur chaque écran (bureau, composition, avant-match, après-match, finances, classement). En attendant l'export transparent : poser Gabi dans une vignette `panneau-2` à bord droit incliné de même taille, pour que le rectangle devienne voulu. Taille 160-200 px de buste : le bureau 2 (≈ 360 px) dépasse.
- Portraits joueurs : photos studio sur fond gris clair (effectif, fiche, recrutement, préparation, formation) = interdit §5 « pas de photo studio grise ». À noter sur les planches comme vignettes provisoires ; fond attendu `panneau-2`.

### T11 · Cadres complets : MINEUR
Le seul cadre permis est le focus clavier (un par écran) : la plupart des cadres blancs vus sont bien ce focus. Restent :
- 03-3 : la barre de progression est encadrée sur ses quatre côtés → fond `panneau-2` + remplissage, filet bas seulement.
- 12-1/2 : la barre du n° 6 (« !78 ») est encadrée en `d` → barre `ivoire-3` + « ! » et valeur en `d`, sans contour.
- 13 et 14 : le bouton Pause / Reprendre est toujours encadré alors que le focus est ailleurs dans d'autres états → c'est un bouton texte (§7 : texte `ivoire` + flèche), sans cadre hors focus.

### T12 · Boutons ivoire : un seul par écran : MINEUR
- 17-1 : pastille de verdict ivoire + « Ajuster le budget » (réglé par T3).
- 14-3 : « Valider le choix » + « Équipe » (désactivé mais toujours en aplat ivoire) → « Équipe » en bouton texte barré quand il est désactivé.
- Étiquettes « Ton équipe » en aplat ivoire (12) : elles se lisent comme des boutons → texte BC SemiBold 12 `ivoire-2` en capitales, sans aplat.

---

## 2. Défauts par écran

**01 Accueil**
- Bloquant : écusson rond (T1) ; image 3 hors identité (montagnes, T5).
- Mineur : image 1 à dominante bleu-vert (T5) ; médaillon Gabi rond (T1).

**02 Création**
- Bloquant : zones fausses (T7) ; écussons ronds (T1).
- Mineur : 1 = cartes FM26 qui remplacent le tableau (référence à éviter, §9) ; Gabi dans un rectangle gris (T10) ; « Promu » dans la colonne 25-26 du 11e à vérifier.

**03 Chargement**
- Mineur : coque redessinée sous le voile (T9) ; barre encadrée en 3 (T11) ; 2 : incohérence « jeu. 19 → ven. 20 » mais « jour 3 sur 4 » alors que la liste en montre 4 dont 2 faits.
- Bon : l'ovale tracé `or-vif` du 2 est exactement l'usage réservé à Continuer.

**04 Bureau**
- Bloquant : zones et objectif à 5 (T7) ; données (T6).
- Mineur : 1 laisse un vide de ≈ 300 px dans la colonne Gabi (entre « Mon conseil » et le buste) → y descendre « Prochains matchs » ou réduire la colonne ; 2 : Gabi trop grand (T10) ; « 2 blessés » en `d` sans pictogramme → « ! 2 ».

**05 Réception**
- Mineur : points non lus ronds (T1) ; Gabi rectangle (T10).
- Bon : la lettre en `papier` est le seul document de l'écran, les trois réponses sont nettes.

**06 Presse**
- Bloquant : verdict « Pression » sans palier lisible (T3) ; « zone des barrages » (T7).
- Mineur : 1 et 2 : photo de salle de presse verte (T5) ; point rond « Conférence ouverte » (T1).

**07 Effectif**
- Mineur : portraits gris (T10) ; 1 : pastilles N (T2) dans « 5 derniers matchs » ; 3 : bandeau photo vert (T5).
- Bon : vraie densité FM (40 lignes, 24 px, tri, filtres, fiche à droite).

**08 Fiche joueur**
- Bloquant : numéros dans des ronds sur le mini-terrain (T1) ; résultats J1-J8 contradictoires (T6).
- Mineur : 1 laisse le quart bas-gauche vide sous « Postes » → y mettre la courbe de notes de la 3 ; portrait gris (T10).

**09 Recrutement**
- Mineur : 1 : bande vide de 80 px au-dessus du titre (titre à y 145 au lieu de 90 comme les autres écrans) → aligner le titre sur la coque ; 3 : photo de terrain verte (T5).
- Bon : budget de transferts séparé de la trésorerie, lisible partout.

**10 Composition**
- Bloquant : pastilles de joueurs rondes (T1) ; « Feuille valide » en vert (T4) ; données de postes (T6).
- Mineur : coque décalée par Continuer (T9) ; étiquettes « 1RE L. » tronquées et sous 12 px dans le banc → « 1re ligne » en 12 px ou colonne dédiée.

**11 Préparation**
- Bloquant : numéros adverses dans des ronds (T1).
- Mineur : plaque « Northmere Blues » pleine au rapport de force : acceptable comme plaque d'identité, mais les pastilles adverses restent en anneau ; pastille N pleine grise ici, demi ailleurs (T2).

**12 Avant-match**
- Bloquant : écussons ronds de 90 px (T1) ; Échap « retour » (T8) ; image verte avec drapeaux français (T5).
- Mineur : barre « !78 » encadrée (T11) ; étiquette « Ton équipe » en aplat (T12).

**13 Match en direct**
- Bloquant : Échap absent en 1 et 2 (T8) ; capture « menu ouvert en match » manquante.
- Mineur : 3 met le score au centre : contraire à §7 (haut-gauche), à écarter ; « 2e MT » (2) et « 2e période » (3) : choisir un libellé ; Pause encadré (T11) ; image froide (T5).

**14 Entracte**
- Bloquant : Échap = « pause » seulement (T8) ; noms et postes du XV différents de la composition (T6).
- Mineur : la série adverse est en bleu plein dans « Chiffres clés » et « Domination » ; §4.2 veut la comparaison en `ivoire-2` (tirets pour une courbe, barres vides pour l'histogramme, ce que 14 fait déjà pour la domination) ; « Équipe » ivoire désactivé (T12).
- Bon : pastilles ovales pleines / anneaux sur le terrain : la référence de T1.

**15 Après-match**
- Bloquant : zones fausses dans le classement du 2 (T7) ; vestiaire en maillots verts (T5) ; Échap (T8).
- Mineur : 1 et 3 : vide de 80-120 px entre le fil du score et Gabi, et à droite de Gabi → y loger le classement après J9 (emprunt au 2) ; petites pastilles de forme presque rondes (T2).

**16 Compétitions (calendrier, classement)**
- Mineur : points des clubs incohérents avec le bureau et la préparation (T6) ; pastilles N (T2).
- Bon : zones justes, liseré + symbole + mot, légende visible : la référence de T7.

**17 Finances**
- Bloquant : verdict « Sous tension » en aplat ivoire, « Dans le rouge » avec ▲ (T3).
- Mineur : 1 : le graphe des 12 semaines prend la moitié de l'écran pour peu de valeurs et mêle deux échelles (solde 3,40-4,00 M€ et barres 0-200 k€) sur le même axe → hauteur 240 px et un second axe à droite pour les barres ; 3 : texte incrusté visible dans la photo (« BROMES ») ; salaires et postes contradictoires (T6).

**18 Club**
- Bloquant : coche verte « Solide » (T4, T3).
- Mineur : 1 : quart bas-gauche vide sous Installations → tableau « ce qui a fait bouger la confiance » du 2 ; données du stade et du président (T6).

**19 Formation**
- Mineur : pictogrammes de statut dans des ronds (« ⊘ En formation ») : acceptable comme pictogramme, mais le passer au trait 1,5 px aux extrémités coupées à 10° (§7) ; 3 : bandeau photo vert (T5).
- Bon : Suivi des jeunes intégré à Progression (décision de Léo), densité FM.

---

## 3. Ce qui tient (à ne pas casser)
- L'or : seulement Continuer, Reprendre, Coup d'envoi, Ouvrir la conférence de presse et l'ovale de progression. Aucun écran ne l'utilise pour un statut.
- Typographie : Barlow Condensed italique pour titres, DM Sans pour les données, partout, match compris.
- Inclinaison : titres, marqueur de sélection, bords de bouton, plaques du score ; aucun tableau penché.
- Le direct et l'entracte reprennent les plaques inclinées et les jetons du bureau : une fois T1 (écusson en plaque) et T5 (étalonnage) faits, le jour de match sentira le même jeu.

---

## 4. Tableau final : mise en page retenue par écran et emprunts

| Écran | Retenue | Emprunts | Accord avec l'avis des maquettes |
|---|---|---|---|
| 01 Accueil | 1 | état « première fois » de la 2 ; légende du lieu de la 3 | oui ; image étalonnée (T5) |
| 02 Création | 2 | en-tête de fiche de la 3 réduit en bandeau ≤ 160 px (règle Semaine) | oui ; zones T7 |
| 03 Chargement | 2 (Continuer), 3 (création, nouvelle saison), 1 (court) | « Arrêter » de la 1 dans la 2 après 20 s | oui ; vraie coque sous le voile |
| 04 Bureau | 1 | face-à-face chiffré de la 3 sous l'affiche ; « Prochains matchs » remonté dans le vide de la colonne Gabi | oui |
| 05 Réception | 1 | filtre « Sujet » de la 3 en menu déroulant seulement | oui |
| 06 Presse | 3 | barre pleine largeur de la 2 pour l'état « conférence tenue » ; verdict T3 pour la pression | oui |
| 07 Effectif | 1 | « Équilibre par poste » de la 2 dans l'infobulle « Aptes » | oui |
| 08 Fiche joueur | 1 | tableau de matchs de la 2 (onglet Performances) ; courbe de notes de la 3 dans le vide bas-gauche | oui |
| 09 Recrutement | 1 | bloc « Ce que coûte l'offre » de la 3 ; titre aligné à y 90 | oui |
| 10 Composition | 1 | encart « première ligne » de la 3 dans les candidats ; pastilles ovales | oui |
| 11 Préparation | 1 | forme côte à côte de la 3 ; « remarque de ton adjoint » de la 2 | oui |
| 12 Avant-match | 1 | plaques inclinées de la 3 à la place des écussons ronds | oui |
| 13 Direct | 1 | bannière d'essai de la 2 ; « Menu Échap » de la 3 ; capture menu ouvert à ajouter | oui ; la 3 est écartée (score centré) |
| 14 Entracte | 1 | panneau d'arrêt de la 3 ; colonne Plaquages de la 2 ; série adverse en `ivoire-2` | oui, sauf le bleu plein des séries |
| 15 Après-match | 1 | classement après J9 de la 2 (zones corrigées) posé dans le vide sous le fil du score | oui |
| 16 Compétitions | 1 | bloc des trois écarts de la 2 ; zones de la 3 = règle pour toutes les compétitions | oui |
| 17 Finances | 1 | « Alloué / Engagé / Restant » de la 3 ; verdict T3 en colonne fixe de la 2 sur chaque onglet | oui ; verdict refait |
| 18 Club | 1 | tableau « ce qui a fait bouger la confiance » de la 2 ; règle des onglets denses de la 3 | oui ; vert retiré |
| 19 Formation | 1 | raisons écrites de la file « à décider » de la 3 ; Progression = la 2 | oui |

## 5. À reporter dans l'art bible (proposé, pas appliqué)
- §4.4 : N = ovale à anneau en tirets (T2).
- §3 B / §7 : écusson = plaque `club` inclinée, plus de rond (T1).
- §7 : composant « verdict à trois paliers » sans couleur, `d` seulement pour le dernier palier (T3).
- §7.1 : liste réelle du rail (sans Entraînement ; Presse, Sélections, Carrière) (T9).
- §7.2 conflit 3 : préciser « Échap hors coque = pause + menu » (T8).
