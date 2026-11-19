# Rugby Legacy 27 — Préparation de la page magasin Steam

Brouillon de travail. Rien n'est créé sur Steamworks : tout est à valider par Léo.
Les formats ci-dessous sont ceux que nous connaissons : **à vérifier dans la doc Steamworks au moment du dépôt** (ils changent).

## 1. Liste de contrôle des éléments de la page

Visuels (sans texte lisible hors logo ; sans mention de prix ni de promotion)
- [ ] Capsule header 920×430
- [ ] Capsule small 462×174
- [ ] Capsule main 1232×706
- [ ] Capsule vertical 748×896
- [ ] Library capsule (capital) 600×900
- [ ] Library hero 3840×1240 (sans logo dessus)
- [ ] Logo (PNG transparent, ~1280 de large max ; à vérifier)
- [ ] Icône du client / jeu (à vérifier : format demandé)
- [ ] Au moins 5 captures d'écran 1920×1080 (match 3D, composition, tableau de bord, recrutement, presse/Gabi)
- [ ] Bande-annonce (facultative, mais très conseillée) : 1080p, format MP4/H.264 ; à vérifier

Textes et fiche
- [ ] Nom du jeu (FR et EN)
- [ ] Description courte (≤ 300 caractères)
- [ ] « À propos de ce jeu » (FR et EN)
- [ ] Configuration minimale et recommandée
- [ ] Langues prises en charge (voir section 3)
- [ ] Tags (section 4)
- [ ] Questionnaire de contenu et déclaration IA (section 5)
- [ ] Prix et régions (section 6)
- [ ] Page « Bientôt disponible » publiée, liste de souhaits ouverte
- [ ] Revue de la page par Valve, puis revue de la version (délais à prévoir ; à vérifier)

Technique (hors page, mais nécessaire)
- [ ] Compte Steamworks, forme juridique, coordonnées bancaires et fiscales (à faire par Léo)
- [ ] Droit d'inscription Steamworks par jeu (montant à vérifier)
- [ ] Build Windows déposé via SteamPipe ; tests sur une machine propre

## 2. Textes proposés

### Français

**Nom** : Rugby Legacy 27

**Description courte** (≈ 205 caractères) :
Dirigez un club de rugby à XV : composition, entraînement, recrutement, finances et matchs en 3D. 116 clubs, quatre championnats, des saisons sans fin, et Gabi, votre adjoint, à vos côtés. Hors ligne, en solo.

**À propos de ce jeu**
- Prenez les rênes d'un club parmi 116 : championnats de France, d'Angleterre, du Pacifique et du Japon, divisions inférieures et coupes d'Europe.
- Composez votre feuille de match à 23, réglez les tactiques, puis vivez le match en 3D ; passez la main à votre adjoint pour la fin de la partie.
- Entraînez, recrutez, négociez les contrats et bâtissez votre effectif : chaque club compte au moins 40 pros, 30 U18 et 30 U21.
- Formez vos jeunes au centre de formation et gérez les staffs, les finances, les sponsors, les supporters et les rivalités.
- Vivez la saison comme un manager : vestiaire, presse, calendrier, montées et descentes, phases finales et saisons suivantes.
- Gabi, votre adjoint, vous conseille tout au long de la carrière, avec sa voix.
- Importez vos propres packs d'identités (noms, images) pour personnaliser le monde du rugby ; les règles restent les mêmes.
- Hors ligne, sans compte, sans publicité : vos carrières restent sur votre ordinateur.

**Fonctionnalités clés**
- 116 clubs, 114 jouables, quatre régions de championnats
- Match 3D, journal de match filtrable
- Formation, recrutement, contrats, staffs
- Presse, vestiaire, sponsors, supporters, mobilité du manager
- Histoire du club, carnet du coach, sauvegardes exportables
- Packs d'identités importables par le joueur
- Ctrl+K pour tout chercher, six rubriques claires

### English

**Name**: Rugby Legacy 27

**Short description** (≈ 205 characters):
Manage a rugby union club: line-ups, training, recruitment, finances and 3D matches. 116 clubs across four championships, endless seasons, and Gabi, your assistant, at your side. Offline, single-player.

**About this game**
- Take charge of one of 116 clubs across French, English, Pacific and Japanese championships, lower divisions and European cups.
- Pick your 23-player squad, set tactics, then live the match in 3D; hand over to your assistant for the closing stages if you wish.
- Train, recruit, negotiate contracts and build your squad: every club starts with at least 40 pros, 30 U18s and 30 U21s.
- Develop youngsters in the academy and manage staff, finances, sponsors, supporters and rivalries.
- Live the season as a manager: dressing room, press, calendar, promotion and relegation, play-offs and the seasons that follow.
- Gabi, your assistant, advises you throughout your career, with a voice of his own.
- Import your own identity packs (names, images) to reshape the rugby world; the rules stay the same.
- Offline, no account, no ads: your careers stay on your computer.

**Key features**: 116 clubs; 3D match and filterable match log; academy, recruitment, contracts, staff; press, dressing room, sponsors, supporters; club history and coach's notebook; importable identity packs.

> Gabi (Gaston Darroux) est un homme : « his » est correct.

### Configuration (brouillon, **à mesurer** sur une machine de test)

| | Minimale | Recommandée |
| --- | --- | --- |
| Système | Windows 10 64 bits | Windows 11 64 bits |
| Processeur | à mesurer (double cœur 2,5 GHz) | à mesurer (quadricœur) |
| Mémoire | 4 Go de RAM | à mesurer (8 Go) |
| Graphismes | compatible OpenGL 3.3 | à mesurer (carte dédiée récente) |
| Stockage | ~2 Go (à mesurer) | ~2 Go sur SSD (à mesurer) |
| Divers | Aucune connexion requise | Écran 1920×1080 |

## 3. Langues

| Langue | Interface | Sous-titres | Voix |
| --- | --- | --- | --- |
| Français | oui | oui | oui (Gabi) |
| Anglais | non | non | non |

- La page peut être rédigée en anglais (et dans d'autres langues), **mais** Steam affichera le jeu comme « français uniquement » : prévenir les acheteurs en tête de la description EN (« Game currently in French only »).
- Ne pas cocher l'anglais dans la liste des langues tant que le jeu n'est pas traduit (avis négatifs, remboursements).
- Note du LISEZ-MOI actuel : « Gabi est en pause dans cet export » ; vérifier l'état réel des voix avant de cocher « voix » en français.

## 4. Tags suggérés

Sports, Management, Simulation, Stratégie, Solo, Rugby, Simulation sportive, Moddable, Indépendant (ne pas ajouter de tag multijoueur ou en ligne). Garder 5 tags principaux : **Rugby, Sports, Management, Simulation, Solo**.

## 5. Classification et déclarations

- **Questionnaire de contenu Steam** : pas de violence graphique, pas de contenu sexuel ni adulte, pas de jeu d'argent, pas de propos choquants ; sport de contact représenté en 3D sans sang ni brutalité. À remplir honnêtement ; Valve vérifie.
- **Déclaration de contenu généré par IA (obligatoire dans le formulaire Steam)** : à cocher et à décrire :
  - une partie des portraits et des illustrations est produite avec des outils d'IA (provenance détaillée dans `Licences/` du jeu) ;
  - la voix de Gabi est une voix de synthèse ElevenLabs (abonnement payant ; aucune voix d'une personne réelle imitée).
  Dans le formulaire, être exact et complet : une omission peut faire rejeter la version. Dans les textes marketing de la page, la règle d'immersion du projet reste valable (aucun badge ni rappel dans le texte vendeur) ; la déclaration Steam est un champ réglementaire à part.
- **IARC / autres boutiques** : si Léo veut sortir ailleurs (Microsoft Store, itch.io, etc.), faire le questionnaire IARC à ce moment-là ; Steam utilise son propre système, sans équivalence automatique.
- **Mentions légales** : le jeu n'est affilié à aucune fédération, ligue, compétition, club ou joueur (cf. `native/godot/legal/credits.json`). Ne citer aucun vrai nom (pas de ligue ou compétition officielle) sur la page ni dans les visuels. Vérifier que les captures ne montrent que le jeu de base anonymisé, pas un pack d'identités réelles.
- **Éditeur** : les champs `editeur` de `credits.json` sont encore vides ; les remplir avant la sortie (nom, forme, adresse, contact).
- **Mention Valve** : « Steam et le logo Steam sont des marques de Valve Corporation » (déjà dans les crédits).

## 6. Décisions de Léo

1. **Prix**. Ne pas trancher ici. Repères habituels pour des jeux de management indépendants (ordres de grandeur à vérifier sur Steam avant décision) : petits titres de gestion sportive indépendants autour de 10 à 20 €, jeux plus fournis (football, basket, rugby de niche) de 20 à 35 €, grosses simulations établies 40 € et plus. À arbitrer : prix de lancement, remise de lancement (souvent 10 à 20 % la première semaine), tarifs régionaux proposés par Steam.
2. **Date de sortie et mode**. Sortie complète, accès anticipé, ou lancement après une version de démonstration ? Points à peser : le LISEZ-MOI parle de « préalpha » ; l'accès anticipé demande une feuille de route honnête et l'anglais manque encore. Une démo ou un « Playtest » Steam est possible avant.
3. **Nom d'éditeur / développeur** : personne physique, micro-entreprise ou société ? Il apparaît sur la page et dans `credits.json`.
4. **Page « Bientôt disponible »** : publier tôt (la liste de souhaits compte beaucoup pour la visibilité au lancement). Nécessite capsules, au moins quelques captures et une description ; ne pas mettre de date précise avant d'être sûr.
5. **Liste de souhaits** : objectif de départ à fixer (repère courant : plusieurs milliers avant le lancement pour être visible ; à relativiser pour un titre de niche). Prévoir un plan d'annonces (réseaux, communautés de rugby, médias spécialisés).
6. **Langue anglaise** : traduire avant la sortie ou accepter « français uniquement » ?
7. **Voix de Gabi** : confirmer qu'elles sont bien incluses dans la version publiée.
8. **Packs d'identités** : les présenter comme une fonction du jeu, sans fournir de vrais noms dans le dépôt public ni sur la page.
