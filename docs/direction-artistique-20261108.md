# Oval Legacy 27 — direction artistique et critères de réception

## Intention

Un jeu de gestion de rugby sur PC doit donner envie d'habiter le club tout en permettant de lire, comparer et décider vite. Léo retient anthracite, ivoire et couleurs du club, demande une densité native en 2560 × 1440 et rejette les grandes cartes de téléphone comme la reproduction de Football Manager. Les photos et personnages servent le lieu et les personnes ; l'information sportive reste prioritaire.

Les corrections de taille précédentes améliorent l'espace de travail, mais ne constituent pas une identité visuelle aboutie. Les défauts visibles sont des surfaces beige/gris trop proches, des commandes peu différenciées, une silhouette d'application générique, des graphiques sommaires et des panneaux parfois trop vides. Ces constats appellent des corrections de composition et de composants, pas une multiplication décorative des couleurs.

## Références professionnelles et application critique

L'entretien d'[Ubisoft avec son directeur artistique](https://news.ubisoft.com/en-us/article/281pEx0ab2CKA6x5ENK9N4/rainbow-six-sieges-art-director-on-learning-to-develop-a-live-game) décrit la vision commune, la coordination entre personnages, décors, présentation et animation, puis l'itération sur le résultat joué. Application ici : une charte partagée et une réception des vrais écrans, au lieu d'évaluer séparément une couleur ou un test de code.

Le retour technique de [Riot sur la clarté visuelle](https://www.riotgames.com/en/news/valorant-shaders-and-gameplay-clarity) articule direction artistique, compréhension du jeu et performance. Son contexte de jeu compétitif diffère du nôtre : on reprend la discipline d'arbitrage, pas son style graphique ni ses budgets de rendu. Pour nos menus, l'effet visuel ne doit masquer ni une valeur, ni une sélection, ni une action.

Les recommandations [Xbox 102 sur le contraste](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/102) et [103 sur les signaux complémentaires](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/103) fournissent des critères mesurables : viser au moins 4,5:1 pour les petits textes importants, conserver un repère autre que la couleur et contrôler les états de sélection. Ce sont des objectifs de conception ; leur citation ne certifie pas l'accessibilité complète du jeu.

## Compétences mobilisées dans la production

| Domaine | Décision pour le jeu | Preuve attendue |
| --- | --- | --- |
| Identité et cohérence | Anthracite structurel, ivoire de lecture, identité du club à des emplacements stables ; logo original approuvé. | Même famille visuelle sur Bureau, joueur, presse, finances et paramètres. |
| Composition | Navigation principale puis sous-menu clairement distincts ; titres, contenu et commandes avec niveaux lisibles. | Capture réduite reconnaissable ; bonne destination et retour au clavier. |
| Typographie | Corps dense autour de 12 px au canvas natif, titres de section 16–20 px ; grandes valeurs réservées aux vrais indicateurs. | Densité 1440p préservée, noms et messages longs reçus à 720p. |
| Surfaces et séparation | Fond ivoire neutre, cartes plus claires, traits discrets et quelques surfaces sombres d'ancrage. | Deux tuiles voisines se distinguent immédiatement sans bordures lourdes partout. |
| Couleur sémantique | V vert, N ambre, D rouge ; absences neutres. Les couleurs de club identifient, les couleurs de statut informent. | Valeurs inchangées, lettres/légende, contraste sur sélection et survol. |
| Iconographie | Pictogrammes originaux simples, accompagnés de mots ; pas de bibliothèque de symboles décoratifs hétérogènes. | Navigation compréhensible sans deviner une icône. |
| Visualisation de données | Axes/grilles sobres, points et séries lisibles ; chiffres et unités restent accessibles. | Pas de fausse courbe sur un historique absent ni de confusion entre note au poste et note de match. |
| Interaction et mouvement | Sélection, focus, survol et confirmation perceptibles ; état et brouillon conservés au redimensionnement. | Commandes réelles testées, pas uniquement émission de signaux. |
| Personnage et narration | Gabi bourru, drôle et enraciné dans le rugby ; petites bulles libres, intervention discrète. | Texte exact, voix et pose cohérentes, absence de récit technique dans ses paroles. |
| Rendu 3D | Silhouette de rugby, appuis et ballon crédibles ; contact uniquement lorsque l'événement fourni le permet. | Images et mouvement examinés ; aucun événement sportif inventé par la présentation. |
| Technique et production | Composants partagés, ressources locales, provenance et limites explicites ; pas d'achat implicite. | Même résultat dans le vrai EXE déplacé, pas seulement dans le SDK. |
| Critique et itération | Rejeter une passe qui ne se voit pas ou dégrade l'usage ; corriger avant de déclarer le lot reçu. | Avant/après et liste des défauts observés puis corrigés. |

## Palette et hiérarchie retenues

La passe suivante utilise comme neutres de travail un ivoire `#F0F1EC`, des cartes `#FCFCF8`, une encre `#20282C`, une encre secondaire `#5F6A6E` et un trait `#CCD2D0`. Les photos et panneaux sombres conservent leur propre contraste clair. La couleur de chaque club est adaptée selon le fond, avec un repère géométrique de sélection qui subsiste même si le rouge et le vert sont mal distingués.

Les badges de résultat utilisent un fond opaque pour rester stables : V `#24583B` sur `#DFEBDF`, N `#77520B` sur `#F3E5B9`, D `#8A342F` sur `#F2DED8`. Les contrastes mesurés de l'étude sont respectivement 6,74:1, 5,58:1 et 6,21:1. Ces valeurs ne s'étendent pas automatiquement aux autres textes ou à l'écran complet.

## Réception obligatoire du lot

- Examiner le jeu réel en 2560 × 1440 et le repli en petite fenêtre ; couvrir aussi 1600 × 900 et 1920 × 1080 avec les contrôles existants.
- Comparer des pages variées, leur navigation et leurs états : Bureau, Effectif, Composition, Classements, Presse, Finances et paramètres au minimum.
- Vérifier les actions, les noms longs, le focus, les sélections, les brouillons et les états sans données. Ne pas remplacer un contenu absent par une fiction statistique.
- Contrôler la pureté des consultations : état, export, RNG et disque ne changent pas pour afficher un menu.
- Construire un nouveau paquet Windows après gel, puis l'exécuter depuis un chemin déplacé avec son Node embarqué, un profil de recette et les quatre tailles. Garder visibles les refus d'écriture.
- Mesurer le démarrage de l'EXE : les 117 757 ms du candidat précédent restent un défaut tant que la cause et un résultat corrigé ne sont pas prouvés.

Figma est l'outil souhaité pour les maquettes, mais ses commandes ne sont pas exposées dans cette session. Aucune maquette Figma n'est annoncée. La refonte autorisée continue dans les composants natifs Godot ; un raccord Figma ultérieur devra refléter ces composants et leurs contraintes réelles.
