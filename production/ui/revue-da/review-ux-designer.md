# Revue UX des maquettes DA (19 écrans x 3 directions)

> Rôle : ux-designer CCGS, phase 4 de `/team-ui`. Mode autonome. Date : 19/11/2026.
> Directions : **A** Programme (clair, serif, rouge sombre) · **B** Direct (sombre, condensé, biseaux, rouge/bleu) · **C** Tableau noir (sombre, mono, jaune).
> Sources : 57 captures 1280x720 (`scratchpad\da2\apercus\<NN>-<id>-1|2|3.png`) comparées aux fiches `design/ux/01…19`, `hud.md`, `interaction-patterns.md`.
> Méthode : j'ai cherché où chaque maquette échoue à la fiche, pas où elle y correspond. Seuls les écarts sont listés ; une absence de remarque = conforme sur ce point.
> Légende : **[BLOQ]** = la fiche n'est pas tenue (principal flou, bouton principal double, donnée ou état exigé absent, libellé faux). **[MIN]** = écart corrigeable sans refonte.

## Limites de cette revue

- Une seule capture par écran et par direction : **les états de la fiche (vide, erreur, désactivé, première fois, attente moteur) ne sont pas montrés**, sauf mention. Je ne les note pas comme absents de la maquette quand rien ne prouvait qu'ils devaient y figurer, mais je les liste en « à livrer » dans la synthèse finale.
- Les tailles de texte sont estimées à l'œil sur capture 1280x720 (non mesurées).
- Écran 13 : les trois captures montrent **trois états différents** (A = jeu courant, B = essai, C = pause + carton). Comparaison partielle (voir 13).
- Ne pas confondre : ici je juge la conformité UX (hiérarchie, blocs, boutons, états, libellés, motifs), pas le style, qui reste à l'art-director.

---

## 0. Constats transversaux (valent pour les trois directions, sauf mention)

### T1 [BLOQ] Trois coques différentes selon les écrans, dans chacune des trois directions
Le rail, la barre haute et le pied ne sont pas la même coque d'un écran à l'autre (interaction-patterns N1, N3, N5) :

| Famille | Écrans | Rail | Barre haute |
|---|---|---|---|
| (a) | 04, 05, 06, 07, 08, 09 | 11 entrées, logo + « Alder Fen XV / Division d'accession », **Réception = 1, Bureau = 2**, Réglages/Sauvegarder en bas | flèches ← →, recherche « Rechercher un joueur, un club… », date, **Continuer** en bouton |
| (b) | 10, 11, 12 | idem mais **plus étroit (~136 px au lieu de ~172)** + sous-navigation Composition/Préparation/Plan de jeu/Match sous Tactique | fil « Tactique › Composition » seul, date, Continuer ; **ni flèches ni recherche** |
| (c) | 16, 17, 18, 19 | **9 entrées seulement, autre ordre : Bureau = 1, Réception = 2**, Préparation et Compétitions à d'autres rangs (Compétitions = 6 au lieu de 9), pas de Tactique/Entraînement/Sélections/Réglages ; logo de jeu au lieu du bloc club | fil « Alder Fen XV › Finances », recherche, date, **visage de Gabi**, Continuer ; pas de flèches |

Conséquences pour le joueur : la touche « 1 » ouvre Réception sur un écran et Bureau sur un autre ; Tactique, Entraînement, Sélections et Réglages disparaissent du rail sur 16-19 ; la largeur du rail saute de 172 à 136 px en passant de Préparation à Effectif.
**Correction** : une seule coque (famille a) pour les 19 écrans de carrière ; la sous-navigation de chapitre (b) s'ajoute **sous** l'entrée active sans réduire le rail ; les maquettes 16-19 sont à refaire avec le rail de 04-09. Les écrans 01-03 et 13-15 sont hors coque (voulu).

### T2 [BLOQ pour C, MIN pour A et B] « Continuer » change de style et, chez C, double le bouton principal
- **A** : bouton à liseré noir sur 04-12 ; **lien souligné** sur 16-19. MIN, aligner.
- **B** : bloc blanc biseauté, très contrasté, sur 04-12 (il **rivalise avec le rouge** de « Préparer le match », « Envoyer la réponse »…) ; texte nu « CONTINUER ▸ » sur 16-19. MIN, passer Continuer en secondaire (contour) partout.
- **C** : contour blanc sur 04-12 (bon) ; **jaune plein sur 16, 17, 18, 19**, à côté d'un second bouton jaune plein (Préparer le match, Ajuster le budget, Fixer un jalon, Promouvoir). **Deux boutons principaux par écran : BLOQ** (fiches 16 §3, 17, 18, 19 : un seul bouton principal). Correction : Continuer en contour comme sur 04-12.

### T3 [MIN] Format de date différent d'une famille à l'autre
A : « Mardi 17 novembre 2026 » (04-09) puis « Mar. 17 nov. 2026 » (16-19). C : « 17.11.2026 » puis « mar. 17/11/2026 ». B seul est stable. Fixer un format par direction (la fiche 04 donne `JJ/MM/AAAA` pour les matchs).

### T4 [MIN] « Presse » apparaît dans le rail seulement sur l'écran Presse
Sur 06, les trois directions ajoutent une entrée « Presse » en bas du rail, absente sur tous les autres écrans : l'écran n'est pas atteignable depuis le rail ailleurs, et la liste bouge. La fiche 06 laisse l'emplacement « à confirmer ». Décider : entrée permanente (ex. sous Réception) ou la retirer et passer par Réception/Bureau.

### T5 [MIN] Contraste des textes secondaires non prouvé
B : gris moyen sur bleu nuit pour les sous-lignes (ex. 09 « Smart blessé, relève à 40 min », 11 « Ouvre la veille »). C : mono gris pâle pour étiquettes et pieds. A est le plus lisible. Les fiches exigent 4,5:1 et 14 px à 1080p : mesurer avant validation.

### T6 [MIN] Échap annoncé « Menu » dans le pied des écrans racines
Conforme aux fiches 04-06 (« Échap Menu »). Sur 07-09, le pied dit « Échap Retour/Retirer le filtre », conforme. Rien à corriger, mais la décision de Léo sur Échap (interaction-patterns #1) reste à trancher : les maquettes la figent provisoirement.

---

## 1. Accueil (01-accueil.md)

**Fiche** : principal = « Reprendre la carrière » (nom du club, saison) ; secondaires = Nouvelle carrière, Importer, Paramètres ; reste = Quitter, Crédits, Identités et packs (lien discret), Gabi ; accroche éditoriale ; aucune mention technique.

- **A** : conforme à l'essentiel : bouton principal plein, focus visible, carte carrière complète (écusson, saison, division, **journée et date**), Quitter à côté de Paramètres, « Identités et packs » en lien discret. [MIN] « 01 / Ouvrir le carnet » suggère une étape numérotée : à retirer sur un écran racine. [MIN] « Rugby à XV · Édition Windows » est un résidu proche du pied technique que la fiche retire (§9) ; la fiche l'autorise dans le bloc Marque, donc tolérable.
- **B** : conforme (principal rouge + liseré, 3 secondaires, 2 demi-boutons, lien discret). [MIN] le bandeau « Carrière de manager » en haut est lisible mais la carte carrière **omet la date** (« Journée 9 » seul) : acceptable selon fiche (« Journée N »). Aucune erreur bloquante.
- **C** : [BLOQ léger] une **règle graduée « 22 · 10 · 50 · 10 » et une flèche en arc** décorent l'écran sans rien dire : jargon de terrain que le joueur ne peut pas lire, contraire à l'esprit « aucun jargon » de la fiche ; la flèche part de Gabi vers le bouton et ajoute un second centre d'attention. [MIN] « Entrée → » dans le bouton principal : utile, mais seulement sur ce bouton. [MIN] la carte carrière n'a ni écusson ni liseré de club : l'élément « CARRIÈRE EN COURS » est plus faible que dans A et B.
- **États non montrés** : première fois, profil illisible, pack absent (raison écrite sous le bouton), moteur arrêté.
- **Qui sert le mieux la fiche** : **A**, de peu sur B ; C est pénalisée par le décor non signifiant.

## 2. Création de carrière (02-creation.md)

**Fiche** : principal = grille de clubs ; secondaires = sélecteur pays/ligue, panneau du club choisi (niveau, **budget, ambition, stade**), bouton « Continuer avec [Club] » ; cartes avec « Niveau » et « joueurs » écrits ; sélection = liseré **et** coche ; pagination ; recherche Ctrl F ; fil « 1 Club > 2 Carrière ».

- **A** : tout est là, y compris coche « Choisi ». [MIN] la pagination « Page 1/3 ‹ › » : flèches de ~10 px (cible bien en dessous de 32 px, K6). [MIN] le gros numéro de rang (1…6) en filigrane : n'est expliqué nulle part, concurrence le niveau ; renommer « 4e » ou retirer.
- **B** : [MIN] même pagination minuscule ; filigrane de rang à ~5 % d'opacité, illisible donc inutile. Le panneau du club (Niveau/Budget/Effectif/Départ/Ambition) en 2 colonnes est dense mais complet. Libellé de bouton raccourci : « CONTINUER AVEC ALDER FEN XV » conforme.
- **C** : [MIN] ajoute la note de Gabi dans le panneau : conforme à la fiche (aide non bloquante) mais **pousse le bouton vers le bas** (il reste visible). Cartes : « Effectif 52 joueurs » redondant avec la fiche (« Niveau », « joueurs ») : correct mais plus verbeux. [MIN] pagination en « p. 1/3 ‹ › » minuscule.
- **Commun** : le bouton d'inactivité « Choisis un club » et ses raisons ne sont pas montrés ; aucune ne montre « Identités et packs » comme secondaire discret : présent en haut à droite dans les trois, conforme.
- **Qui sert le mieux la fiche** : **A** (lecture la plus claire du panneau « Ambition du conseil » en toutes lettres, cartes lisibles) ; C a le meilleur ajout (Gabi).

## 3. Chargement (03-chargement.md)

**Fiche** : principal = phrase d'état ; secondaires = progression (%/étape n/m) + conseil de Gabi ; « Échap : arrêter » seulement si annulable ; bouton déclencheur en « … » (gel invisible) ; disquette de sauvegarde ; panneau ~40 % de largeur, texte du panneau lisible sur fond propre.

- **A** : conforme : phrase d'état dominante, barre + « 38 % » + « étape 2 sur 5 », conseil de Gabi, « Échap · arrêter au dernier jour calculé », bouton « … » en haut à droite (motif manquant n°7 appliqué). [MIN] « Sauvegarde en cours… » en étiquette permanente à côté de la disquette : la fiche la veut en infobulle seulement (une écriture rapide n'affiche rien).
- **B** : [BLOQ léger] les **deux pastilles de date « MAR. 17 NOV. ▸ MER. 18 NOV. » débordent au-dessus du panneau** et chevauchent le titre du Bureau en arrière-plan : lecture confuse, et le panneau n'est plus « centré ». [MIN] « ÉCHAP ARRÊTER » est composé comme un **bouton** (fond clair, étiquette pleine) alors qu'il n'est pas cliquable avant 20 s : faux affordance. [MIN] pourcentage cyan très grand : il concurrence la phrase d'état (la phrase doit rester le principal).
- **C** : [MIN] le pourcentage (38 %) est petit et gris-vert, la barre « terrain » avec ballon et graduations 22/50/22 est décorative et lente à lire ; l'étape n/m est dans un mono pâle. La phrase d'état est bien le principal. [MIN] « J-3 avant Northmere » : information utile non prévue par la fiche (acceptable). Même remarque sur l'étiquette « Sauvegarde en cours… ».
- **Qui sert le mieux la fiche** : **A**.

## 4. Bureau (04-bureau.md)

**Fiche** : principal = Prochain match (adversaire, jour, lieu, **domicile/extérieur en mot**, feuille) + bouton unique « Préparer le match » (+ « Vérifier les 23 ») ; secondaires = **« Tes trois priorités »** avec **« Objectif du conseil »**, avis de Gabi en **4 notes** (Match, Le groupe, L'alerte, Mon conseil) + « Suivre le conseil », État du groupe avec valeurs chiffrées et repères de seuil ; bandeau bas : classement 3 lignes + forme V/N/D, courrier, 3 prochains matchs ; titre « Le bureau · Ta semaine commence ici. » ; pas de pastilles de résumé en haut.

- **A** : [MIN] le bloc des priorités est **renommé « À décider »** (fiche : « Tes trois priorités », qui promet exactement trois) ; la numérotation « 01 / À décider, 02 / L'avis de Gabi, 03 / Le groupe » ne suit pas l'ordre de lecture gauche→droite (01 à gauche, 02 à droite, 03 au centre). [MIN] titre OK. Prochain match : fort (photo sombre, bouton plein avec focus), **domicile en mot**, « dans 4 jours », feuille à compléter. Gabi : 4 notes, « Suivre le conseil » en simple lien. Groupe : barres avec repère et valeur. Classement : forme V/N/D à lettres. **Conforme sur le fond.**
- **B** : principal le plus fort des trois (J-4, écussons VS, bouton rouge). [MIN] **« Ta semaine commence ici. » absent** (remplacé par « Prochain match · Journée 9 ») ; la date, l'heure et le jour sont **éloignés** du nom des clubs (en haut à droite, petits). [MIN] échéances de priorités abrégées « AVANT SAM. » au lieu d'une date (« avant le 21/11 »). [MIN] Continuer blanc plein concurrence « Préparer le match » (voir T2). Gabi : 4 notes étiquetées MATCH/GROUPE/ALERTE/CONSEIL, bien.
- **C** : [BLOQ] **le principal n'est pas le plus fort** : « Le groupe » (38 et 3 en gros) est la première chose lue en haut à gauche ; « Prochain match » est relégué en 3e colonne, avec un bouton jaune bien visible mais une carte étroite. [BLOQ] **Gabi** : pas de titre « Avis de Gabi », visage petit sans étiquette, **la note « Le groupe » est absente** (3 notes sur 4), « Suivre » est un mini-lien vert. [MIN] décors sans signification (« notre camp ——— vers samedi », « milieu → leur 22 », chiffres 22/10 dans les angles). [MIN] la feuille « À compléter · 1 poste » en rouge seul + texte : ok (mot présent). Classement : forme V/N/D avec formes (carré/rond) : bon point.
- **Commun** : « Vérifier les 23 » présent (A, B, C). Aucune pastille en haut : conforme. Objectif du conseil présent dans les trois.
- **Qui sert le mieux la fiche** : **B** (hiérarchie), **A** très proche (plus conforme aux libellés mais renommage à corriger) ; C à reprendre (ordre des colonnes et Gabi).

## 5. Réception (05-reception.md)

**Fiche** : principal = courrier prioritaire ouvert avec l'attente ; liste groupée par jour, filtres Tous/Non lus/À faire + Sujet ; actions Favori/Lu/Archiver ; **réponses en deux temps** (carte choisie puis « Envoyer la réponse » + « Annuler ») ; **raison de l'indisponibilité écrite** ; dossier du courrier réduit à une ligne ; « Courrier suivant non lu » avec Espace ; pas de photo, pas de Gabi dans la barre.

- **A** : conforme : réponse « ✓ Choisie · conseil de Gabi », « Envoyer la réponse » plein + « Annuler » + rappel « Tu réponds : accepter la rallonge », raison écrite sur la carte indisponible (liseré ambre). [MIN] le conseil de Gabi est signalé par un texte seulement dans la carte : correct. Aucun écart de fond.
- **B** : [MIN] titres de courrier en capitales condensées plus durs à lire sur 2 lignes ; reste conforme. [MIN] « À FAIRE · AVANT LE 19/11 » en étiquette jaune pleine : la couleur domine le mot ; le texte reste là (D1 respecté).
- **C** : [MIN] l'étiquette « URGENT » est en rouge contour et « À faire » en pointillé jaune : les deux se ressemblent (contour fin), distinction surtout par la couleur et le mot ; la raison d'indisponibilité en **rouge seul** : le mot « Indisponible » est écrit, donc conforme. [MIN] **le bas du volet est serré** : dossier du courrier et « Courrier suivant non lu » se touchent.
- **Qui sert le mieux la fiche** : **A** (aération, séparation nette entre réponses, annulation et récapitulatif).

## 6. Presse (06-presse.md)

**Fiche** : principal = état de la conférence + « Préparer la conférence » ; secondaires = journal du jour, 3 indicateurs (Médias, Supporters, Pression) avec `n/100` + mot de seuil + barre, mémoire des échanges ; 4 onglets avec indication « Ctrl Tab ou 1 à 4 » ; **pas de classement complet**, lien « Voir le classement » ; réglage « Conférences ordinaires » déplacé dans l'onglet Conférence.

- **A** : [MIN] le titre du journal (serif très grand) est **plus fort que l'état de la conférence** : en 5 s on lit « Northmere, la machine à mêlées… » avant « Conférence ouverte ». Le bouton plein avec focus rattrape en partie. Indicateurs : valeur, mot (Correct/Confiants/Modérée), barre à repère : conforme. T4 (entrée « Presse »).
- **B** : état en pastille verte et bouton rouge bien identifiables ; titre du journal en capitales ; indicateurs conformes. [MIN] le classement des résultats (5 lignes) reste, c'est « Les résultats conservés » : conforme (ce n'est pas le classement de 13 lignes).
- **C** : [MIN] titres de presse en vert mono (« Fenland Courier ») : lisibles mais le bouton jaune est le seul point chaud ; **état « CONFÉRENCE OUVERTE » le plus net** des trois avec le bouton. Indicateurs conformes (mots en vert).
- **Commun** : l'onglet « Conférence » porte une pastille « 3 » : bon. États indisponible/brouillon/tenue non montrés.
- **Qui sert le mieux la fiche** : **C**, de peu sur B (principal le plus évident) ; A devrait réduire la taille du titre du journal.

## 7. Effectif (07-effectif.md)

**Fiche** : principal = tableau (>55 % de la largeur) ; 4 **compteurs cliquables** (Aptes, Blessés/indisponibles, Fins de contrat, Niveau moyen du XV) ; bandeau d'alerte XV ; pastille de n° pleine/cerclée/vide ; condition % + barre + repère 80 % ; statut en mot + icône ; panneau du joueur : 3 points forts, « Ouvrir la fiche » principal, Prolonger, Comparer ; groupes Avants/Arrières ; pied « tri : … ».

- **A** : [MIN] **les compteurs n'ont aucune apparence cliquable** (texte nu). [MIN] « Prolonger → · Comparer » collent au bord bas du panneau, contre le pied : risque de coupure. Pastilles : cercle plein (titulaire) / contour (remplaçant) : conforme. 11 lignes visibles : la meilleure densité.
- **B** : mêmes compteurs non cliquables, [MIN]. Panneau du joueur : **photo rouge énorme avec « 2 »** : l'identité du joueur est lisible mais le panneau dévore la zone ; « Prolonger → Comparer » aussi au bord. Barre « BLESSÉ DANS LE XV » : bon (mot + icône).
- **C** : [MIN] **sous-groupes « 1-3 Première ligne », « 4-5 Deuxième ligne »** ajoutés (fiche : Avants / Arrières seulement) : plus lisible, mais seulement **9 lignes visibles**. [MIN] « ← notre en-but : avants n° 1 à 8 / arrières n° 9 à 15 → » : décor/jargon à retirer. Sélection par cadre vert, pastille remplaçant en pointillé : lisible.
- **Commun** : colonne Pot. retirée à 1280 (priorité 3 : conforme). Vues Condition/Contrats/Développement présentes. États vide/filtre non montrés. Fiche exige un bandeau d'alerte avec lien « Ouvrir la composition » : présent partout.
- **Qui sert le mieux la fiche** : **A**.

## 8. Fiche joueur (08-fiche-joueur.md)

**Fiche** : principal = bandeau d'identité + **ligne de verdict** « Titulaire · 88 % · contrat jusqu'à … » ; niveau/potentiel une seule fois ; 6 onglets + Ctrl Tab ; cartes Disponibilité, **Points forts / à travailler (3 + 3)**, Contrat (Proposer une prolongation), Postes (**mots complets**, schéma qui illustre), Saison (forme V/N/D) ; « Retour à l'effectif » ; précédent/suivant ; Comparer, Ma note.

- **A** : conforme ; ligne de verdict en tête avec pastille « Fin de contrat » ; points forts 3 + 3 ; postes en mots + schéma ; Saison avec forme à lettres. [MIN] le « 2 » filigrane gris derrière le niveau est décoratif.
- **B** : [BLOQ léger] **« À travailler » n'affiche que 2 attributs** (Jeu au pied, Vitesse) : la fiche en exige 3 (il manque « Passe »). [MIN] carte Postes réduite à une ligne **abrégée** (« Pilier g. · 3e ligne aile ») : la fiche exige les mots complets et le schéma, et l'absence de « Autres : » rend l'information moins claire. [MIN] verdict en **bande séparée** sous le bandeau rouge : bien lisible, mais le bandeau lui-même est très chargé (« 2 » géant, photo, 65/65-69, boutons).
- **C** : conforme (3 + 3, postes en mots, schéma). [MIN] libellés en minuscules mono (« âge · pays », « gabarit ») : lisibles mais plus pâles. « Retour à l'effectif » en petit lien vert.
- **Qui sert le mieux la fiche** : **A**.

## 9. Recrutement (09-recrutement.md)

**Fiche** : principal = le besoin sélectionné et ses pistes ; secondaires = montant disponible (clic = Finances), panneau de piste avec **une seule action principale** (« Approcher le joueur » si observé), 3 cartes de besoins (« Priorité 1 · urgent »…), bandeau fins de contrat, source (Marché des joueurs / Entre clubs / Relève) ; Lancer une mission, Comparer 1/2.

- **A** : conforme ; « Marché des joueurs » en toutes lettres ; primes écrites avec « € ». Panneau : bouton plein + « Observer à nouveau » en lien.
- **B** : [MIN] source raccourcie en **« Marché »** (fiche : « Marché joueurs » / libellé complet) ; [MIN] la ligne « Tes demis : moyenne 59 » est **coupée** au bord bas du panneau. Bonne hiérarchie (étiquette PRIORITÉ 1 · URGENT en jaune, montant disponible en grand).
- **C** : [MIN] **colonne Prime sans « € »** (la note « primes en € » est reléguée dans le pied) : pas de contexte à la lecture d'une ligne. [MIN] **▲ pour « rapport »** dans la colonne Observation collide avec le ▲ « bon » ailleurs (fiche 08) : symbole surchargé. Source « Marché » raccourci aussi.
- **Commun [MIN]** : le montant « disponible pour les transferts » (412 000 €) ne correspond à **aucune valeur de l'écran Finances 17** (trésorerie 3,54 M€) : voir 17.
- **Qui sert le mieux la fiche** : **A**.

## 10. Composition (10-composition.md)

**Fiche** : principal = terrain du XV avec la ligne de validité ; Valider la feuille **seul bouton plein** ; panneau Candidats en bas (non éligibles grisés, raison écrite) ; banc 8/8 avec « 1re ligne » ; impact en 6 barres face à face avec écart signé ; vigilance ; « Plan : Équilibré · Modifier » ; fil « Tactique › Composition ».

- **A** : conforme : « Valider la feuille → » seul bouton plein ; « Proposition du staff » et « Enregistrer » en liens soulignés. Impact : barres rouge sombre vs gris, écart en couleur et signe. [MIN] le signe « -4 » est en rouge sur fond blanc : lisible mais l'écart est rejeté à droite et pas « au centre ».
- **B** : [MIN] **trois boutons biseautés de poids voisin** (Proposition du staff, Enregistrer, Valider la feuille) : le rouge de Valider suffit à le distinguer, mais Continuer blanc, en haut à droite, rajoute un quatrième cadre plein. Terrain : numéros rouges très lisibles, **meilleur repérage du poste choisi** (étiquette « CHOISI » en jaune plein).
- **C** : [MIN] « Proposition du staff » et « Enregistrer » ont un **contour blanc épais** égal à celui de Continuer : Valider (jaune plein) reste le seul plein mais trois contours se disputent l'œil. Impact : ▲/▼ + écart : meilleur pour D1. [MIN] **cartes du terrain à faible contraste** (fond noir, texte crème) : le poste choisi (jaune) est la seule chose qui ressort.
- **Commun [MIN]** : T1 (coque b). La condition de McCulloch (79 %) ici contredit l'avant-match 12 (84 %) : à harmoniser dans les jeux d'essai.
- **Qui sert le mieux la fiche** : **A** (un seul plein, liens clairs) ; B a le meilleur terrain.

## 11. Préparation (11-preparation.md)

**Fiche** : principal = rapport de force (6 secteurs) avec **la phrase de danger au-dessus** ; « À faire avant le match » (icône + mot + texte + lien) ; forme V/N/D avec lettre et forme ; joueurs à surveiller ; « Aller au jour de match » seul bouton plein, **grisé avec raison écrite** tant que la veille n'est pas là ; « Plus ▾ ».

- **A** : [MIN] **« Aller au jour de match → » en contour pointillé**, plus discret que « Revoir la composition » : la raison (« Ouvre la veille, ven. 20/11 ») est écrite : conforme à l'état désactivé de la fiche, mais le bouton principal n'a **aucun état actif montré** : à livrer. Phrase « DANGER » en serif italique sur fond clair : lisible, sans écraser le rapport de force (bon équilibre).
- **B** : **bandeau jaune « DANGER » pleine largeur** : la phrase est la première chose lue (objectif n°1 de la fiche en 5 s). [MIN] « Aller au jour de match » en contour fin, plus faible que les boutons secondaires pleins : même remarque qu'en A ; le gros bandeau jaune est cependant **le plus fort élément coloré de l'écran**, plus que le rapport de force. Forme V/N/D : **formes différentes (losange, triangle, parallélogramme)** avec lettre : respecte D2 mieux que A et C.
- **C** : [MIN] « Revoir la composition » (contour plein) est visuellement **plus fort que « Aller au jour de match »** (pointillé) : inversion de hiérarchie ; **« → mêlée »** après la phrase de danger : repère utile, non prévu. Pastilles de forme à lettres, ok.
- **Commun** : « À faire » : états par icône (!, ✓, ○) mais pas de **mot d'état** (« faite », « valide ») ; seul le texte de la ligne en tient lieu : [MIN].
- **Qui sert le mieux la fiche** : **B** (phrase de danger et forme les plus nettes).

## 12. Avant-match (12-avant-match.md)

**Fiche** : principal = « Coup d'envoi » (seul bouton plein) + affiche ; bandeau « Feuille validée · condition » ; **« Ton équipe » écrit** ; classement, forme V/N/D (lettre + forme), **confrontations**, météo ; 4 tuiles (Ta feuille avec **valeur de condition par repère**, Conditions, Adversaire, Mot de Gabi) ; Déléguer secondaire ; pas de bouton hors schéma.

- **A** : conforme ; seule réserve [MIN] : **la barre de 15 repères n'affiche pas de valeur par poste** (fiche : « 15 repères numérotés avec valeur de condition ») ; la valeur n'est donnée qu'en phrase pour le n° 7. [MIN] la date apparaît **deux fois** (haut droit et bandeau) et le bouton « Jour de match » de la barre haute pointe vers l'écran même, à côté du Coup d'envoi.
- **B** : [BLOQ] **« EN DIRECT DE Division d'accession… » au-dessus de l'affiche** : le match n'est pas commencé (« Rien n'est lancé » en pied). Libellé faux, source possible d'erreur de lecture. Remplacer par le nom de la compétition seul. [MIN] même absence de valeur par repère, même doublon de date, bouton « Jour de match » en plus. [MIN] le bleu de Northmere (fond) ne correspond pas au maillot blanc du direct (voir 13).
- **C** : [MIN] mêmes absences ; le n° 7 est distingué par un **cadre jaune seul** (couleur), sans valeur : l'icône ou le chiffre manque. Barres crème toutes identiques : la lecture « tous ≥ 80 % » ne se voit qu'avec la ligne en pointillés.
- **Commun** : Déléguer le match en secondaire : conforme ; fenêtre de confirmation non montrée.
- **Qui sert le mieux la fiche** : **A**.

## 13. Match en direct / HUD (hud.md)

**Fiche** : barre haute unique (horloge, score + écussons + noms, **ÉQUIPE seul bouton plein**, PARAMÈTRES, PLUS, PAUSE→REPRENDRE) ; ligne de possession avec fond ≥ 70 % ; journal bas-gauche (2 lignes) ; bandeau d'événement mot + nom + équipe (**essai, carton**) ; centre vide ; horloge « MT/FIN ».

**Limite** : trois états différents (voir « Limites »).

- **A** (jeu courant) : conforme : barre unique, ÉQUIPE plein, journal 2 lignes, possession avec fond. [MIN] PARAMÈTRES/PLUS/PAUSE en **texte souligné** (aspect de liens, pas de boutons) ; cible réduite. **Pas d'événement ni de pause montrés** : états à livrer.
- **B** (essai) : bandeau « ESSAI +5 · DONAL GANNON · n° 13 · Alder Fen XV » : conforme (mot + nom + équipe). [MIN] **le journal répète l'essai** en dessous ; la fiche dit « journal décalé d'une ligne », donc ok, mais l'espace bas-gauche dépasse 40 % de largeur. [MIN] **le bleu de Northmere sur la barre n'est pas la couleur de son maillot** (blanc) : l'écusson et le nom sont là (D5), mais la correspondance couleur/maillot est fausse ; supprimer le bleu ou colorer la barre comme les maillots.
- **C** (pause + carton) : conforme : « EN PAUSE » en mot, **Reprendre remplace Pause**, carton « CARTON JAUNE n° 6 Harlan Voss · Northmere Blues » + minuteur. [MIN] **deux boutons pleins en pause** : ÉQUIPE (jaune plein) et Reprendre (anneau de focus vert) : la fiche réserve le plein à ÉQUIPE seul. [MIN] ligne de possession en mono petit, plus difficile à lire sur gazon.
- **Qui sert le mieux la fiche** : **B** sur l'événement, **C** sur la pause ; aucune direction ne couvre les trois états. À faire montrer les trois états (jeu courant, événement, pause) dans chaque direction avant de choisir.

## 14. Entracte (14-match-entracte.md)

**Fiche** : barre haute identique au direct ; Mon XV (nom complet, énergie, note, **alerte épuisé = mot + icône**) ; terrain 2D ; **4 duels** de chiffres clés (possession, occupation, pénalités, 22 m) ; frise de domination ; **carte de l'adjoint** : une phrase + « Remplacer le N » ; **« Reprendre le match »** ; pas de « Passer », pas de compte à rebours ; focus d'ouverture sur ÉQUIPE.

- **A** : [BLOQ] **aucun bouton principal** : « Remplacer le 7 → » et « Reprendre le match → » sont deux liens de même poids ; la seule action qui reprenne la partie est la plus discrète de l'écran. Le pied de commandes (« Espace : pause… ») est conforme. [MIN] **5 duels** au lieu de 4 (Plaquages réussis en plus). [MIN] pas de focus visible sur ÉQUIPE.
- **B** : [MIN] **« Remplacer le 7 » (jaune plein) domine « Reprendre le match »** (contour) : le conseil de Gabi devient l'action principale. La fiche garde « Reprendre le match » comme sortie unique ; décider lequel est principal (voir recommandation). [MIN] **5 duels**, en-tête « AFN · NOR » (abréviations sans définition ailleurs). Bon : focus visible sur ÉQUIPE, « épuisé » en mot + icône, légende ▲▼ de la frise.
- **C** : [MIN] même hiérarchie que B (Remplacer plein, Reprendre en contour) ; **4 duels exactement comme la fiche**, légende « ● nous ○ eux » (non coloriel), trajectoire du ballon en pointillé : bon pour D1. [MIN] pas de focus visible sur ÉQUIPE.
- **Recommandation** : les trois laissent la question de la hiérarchie ouverte ; je propose **« Reprendre le match » en plein** (c'est la seule sortie, décision de Léo : pas de sortie en plein match) et « Remplacer le N » en secondaire fort uniquement quand l'alerte existe.
- **Qui sert le mieux la fiche** : **C** (4 duels, légendes), B très proche (focus ÉQUIPE).

## 15. Après-match (15-apres-match.md)

**Fiche** : principal = les 3 raisons classées, chacune avec ▲/▼ **et mot** et un levier ; score + issue + note + évolution de classement ; Gabi ; « Voir plus » ; **un seul bouton** de suite avec focus ; « Le résultat est validé quand tu continues ».

- **A** : **le plus conforme** : titre « Pourquoi on a gagné », ▲ Point fort / ▼ À corriger, leviers en liens, Voir plus, Gabi en colonne, bouton principal avec focus, note de bas de page « Le résultat est validé quand tu continues. » [MIN] le portrait de Gabi est grand et **concurrence les raisons** ; réduire.
- **B** : [MIN] **trois boutons biseautés « VOIR LA… »** en colonne de droite : trois cibles de poids égal, proches du bouton principal par la forme ; les chiffres en cyan dans les textes sont lisibles. La note « le résultat est validé… » est **absente**. Bouton principal rouge avec anneau : conforme.
- **C** : les chiffres clés en très grand (6, 71 % · 58 %, 11) donnent le **meilleur 5 secondes** sur le « pourquoi », mais **le texte des raisons passe au second plan** et le titre « Pourquoi on a gagné » est petit. [MIN] le levier de la raison « À corriger » est en **contour rouge** quand les deux autres sont blancs : distinction par la couleur du bouton, non par la forme. [MIN] note de validation absente.
- **Qui sert le mieux la fiche** : **A**.

## 16. Calendrier / classement (16-calendrier-classement.md)

**Fiche** : principal = classement avec la ligne du club en évidence ; « Prochain rendez-vous » avec bouton « Préparer le match » ; calendrier du club (6 prochains) ; **zones** (promotion, barrage, relégation) avec **liseré + libellé + légende** (D4) ; forme V/N/D à lettres ; **une seule rangée d'onglets** ; sélecteur de compétition en menu ; T1/T2 s'appliquent.

- **A** : zones par liseré coloré + colonne « Zone » en mot + légende : conforme. [MIN] « Prochain rendez-vous » : **le mot « Domicile » manque** (déduit de « reçoit ») ; bouton plein avec focus. Phrase d'orientation « Tu tiens la dernière place de barrage… » : excellent ajout. 6 dates : conforme.
- **B** : **meilleur codage des zones** : ▲ MONTÉE / ◆ BARRAGE / ▼ RELÉGATION en symbole + mot + couleur ; « DOMICILE » écrit ; 6 dates. [MIN] T2 (Continuer plus pâle qu'un lien).
- **C** : lignes de séparation « LIGNE DE MONTÉE / BARRAGES / RELÉGATION » avec trait plein/pointillé/plein : très lisible et non coloriel. [BLOQ léger] **le titre « Notre calendrier » annonce « 6 dates » mais n'en liste que 5** (14/11 à 12/12). [BLOQ] T2 : Continuer jaune plein à côté de « Préparer le match » jaune plein.
- **Commun** : T1 (coque c).
- **Qui sert le mieux la fiche** : **B** (zones D4), C près pour la lisibilité mais pénalisée par les deux boutons pleins.

## 17. Finances (17-finances.md)

**Fiche** : principal = **verdict** (Dans le vert / Sous tension / Dans le rouge) + trésorerie + **« Disponible pour recruter »** (ou « Budget non fixé » tant que la donnée n'existe pas) ; 2 chiffres au lieu de 4 ; vigilances (2-3 lignes + action) ; échéances ; « Où va l'argent » ; courbe 12 semaines à **axe daté** ; « Ajuster les engagements → ».

- **A** : [BLOQ] **« Disponible pour recruter » absent, sans mention « Budget non fixé »** (but n°2 en 5 s non servi). [MIN] le verdict est une **étiquette de taille moyenne**, moins forte que « +620,0 k€ » et « 3,54 M€ » : le verdict n'est pas le principal. Courbe : axe daté, légende, motif hachuré en plus de la couleur (bon). Bouton « Ajuster le budget → » plein : conforme (libellé fiche : « Ajuster les engagements »).
- **B** : verdict **dominant** (bloc jaune « SOUS TENSION » avec icône) : meilleure hiérarchie. [BLOQ] même absence de « Disponible pour recruter ». [MIN] **trois chiffres** (trésorerie, marge saison, marge courante) au lieu de deux. [MIN] « Ajuster le budget » placé **dans la carte de la courbe**, à distance du verdict.
- **C** : verdict en pavé avec icône, liste sobre de chiffres (5 lignes), « plus grosses sorties du mois » (ajout utile), flèche annotée sur la courbe. [BLOQ] même absence ; [MIN] plus de 2 chiffres ; **T2** (Continuer jaune + Ajuster jaune).
- **Commun [MIN]** : Recrutement 09 affiche « 412 000 € disponibles pour les transferts » alors que Finances ne montre aucune valeur équivalente : un joueur croira à deux budgets. Décision à prendre avec le game-designer (la fiche 17 §261 reconnaît que la source n'existe pas) ; en attendant afficher « Budget non fixé ».
- **Qui sert le mieux la fiche** : **B** (verdict dominant).

## 18. Club (18-club.md)

**Fiche** : principal = **Confiance du conseil + objectif de la saison** (une carte) ; À décider (3 lignes) ; Vestiaire (moral, disponibles, leader) ; Installations (3 lignes) ; hero réduit à nom + stade ; 5 onglets.

- **A** : conforme ; jauge en demi-cercle avec repères 40/70, « Solide » avec coche, objectif complet, « Fixer un jalon » seul plein. [MIN] « Repères : 40 fragile, 70 solide » en petit.
- **B** : [MIN] **l'objectif est tronqué** (« Finir dans les quatre premiers ») : « et jouer les barrages » disparaît, c'est le contenu que la fiche veut lisible. [MIN] moral « 81 » sans « /100 ». Barre à repères 40/70 : bonne.
- **C** : [MIN] la **frise « menacé · fragile · solide » avec ovale** est difficile à lire (jargon graphique, grande boîte) et laisse un grand vide en bas à gauche ; liens « voir → / présenter → » en mono vert minuscule (faible affordance). [BLOQ] T2 (Continuer jaune + Fixer un jalon jaune).
- **Qui sert le mieux la fiche** : **A**.

## 19. Formation (19-formation.md)

**Fiche** : principal = tableau des jeunes ; compteurs (60 espoirs, 2 pépites, 4 à décider) ; 4 onglets + U21/U18 ; filtres Poste/Potentiel/Statut + recherche ; statut = icône + mot ; panneau du jeune avec mini-courbe ; **Promouvoir** (confirmation) ; Garder/Libérer **seulement pendant la revue d'effectif** (fiche §13 : absents sinon, jamais grisés) ; ligne « À décider ».

- **A** : conforme, y compris le **libellé « Promouvoir en équipe première »** et le texte explicatif « Garder ou libérer : revue d'effectif de juin ». [MIN] pas de mini-courbe de progression ; recherche présente.
- **B** : [MIN] **pas de champ de recherche** ; panneau dominé par la grande photo rouge avec « 15 » ; libellé « PROMOUVOIR » seul (sans « en équipe première ») ; pas de mini-courbe. Colonne Prog en ▲/▼ + valeur : bon.
- **C** : conforme avec **mini-courbe 52 → 62** ; [MIN] **pas de recherche** ; [BLOQ] T2 (Continuer jaune + Promouvoir jaune).
- **Qui sert le mieux la fiche** : **A** (recherche + libellé complet), C pour la mini-courbe mais pénalisée par T2.

---

## Synthèse

| # | Écran | Meilleure pour la fiche | Raison en une ligne |
|---|---|---|---|
| 01 | Accueil | A | principal net, aucun décor muet (C en a) |
| 02 | Création | A | panneau complet et le plus lisible |
| 03 | Chargement | A | phrase d'état dominante, pas de débordement (B) |
| 04 | Bureau | B (A proche) | prochain match le plus fort ; A conforme aux libellés |
| 05 | Réception | A | aération, deux temps lisibles |
| 06 | Presse | C (B proche) | état + bouton principal le plus net |
| 07 | Effectif | A | densité (11 lignes) et conformité |
| 08 | Fiche joueur | A | 3+3 attributs, postes en mots |
| 09 | Recrutement | A | libellés complets |
| 10 | Composition | A | un seul bouton plein |
| 11 | Préparation | B | danger et forme les plus nets |
| 12 | Avant-match | A | aucun libellé faux (B : « EN DIRECT DE ») |
| 13 | HUD | B / C (états différents) | non comparable : états à aligner |
| 14 | Entracte | C (B proche) | 4 duels, légendes non coloriel |
| 15 | Après-match | A | raisons + note de validation |
| 16 | Calendrier/classement | B | zones symbole + mot |
| 17 | Finances | B | verdict dominant |
| 18 | Club | A | principal unique, objectif complet |
| 19 | Formation | A | recherche + libellé complet |

**Verdict global** : **A (Programme)** sert le mieux les fiches (12 écrans sur 19, et le moins d'écarts bloquants). **B (Direct)** est la meilleure hiérarchie visuelle sur 5 écrans (04, 11, 16, 17, et l'événement du HUD) mais porte deux écarts de libellé/affichage (12 « EN DIRECT DE », 03 pastilles qui débordent). **C (Tableau noir)** a de bonnes idées d'accessibilité non coloriel (14, 16) mais **échoue à « un seul bouton principal » sur 16-19**, garde du décor sans signification (01, 03, 04, 07) et rend le principal moins évident au Bureau.

### Bloquants communs aux trois, à lever quelle que soit la direction retenue
1. **T1** : une seule coque (rail, barre haute, pied) pour les 19 écrans ; refaire 16-19 avec le rail de 04-09.
2. **17** : « Disponible pour recruter » (ou « Budget non fixé ») absent ; harmoniser avec les 412 000 € du Recrutement.
3. **14** : décider quel bouton est le principal (je recommande « Reprendre le match »).
4. **Pied/états** : montrer au moins les états désactivés et vides de la fiche (Préparation « Aller au jour de match » actif, Composition « Valider » désactivé avec raison, Accueil « première fois ») avant la validation.

### À livrer en complément (états exigés par les fiches, non montrés)
01 première fois/profil illisible/pack absent ; 02 aucun club trouvé + « Effacer la recherche » ; 03 état « Long » (« Arrêter ») et « Moteur arrêté » ; 04 première semaine / jour de match ; 05 filtre vide + « Tout afficher » ; 06 indisponible/brouillon ; 07 filtre vide ; 10 feuille incomplète avec correction ; 12 feuille invalide (Coup d'envoi grisé avec raison) et fenêtre de délégation ; 13 trois états par direction ; 15 défaite et nul ; 17 « Dans le vert » / « Dans le rouge ».
