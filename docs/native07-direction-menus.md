# Direction des menus natifs 0.7

## Intention et périmètre

Direction retenue par Léo : anthracite, ivoire et couleurs du club, avec une lecture dense sur un vrai canvas PC. Corps de 12 px, commandes de 28 px, titres de 16 à 20 px ; le 2560 × 1440 gagne de l'espace utile. Les lois, projections sportives, commandes, formats et sauvegardes restent hors de ce lot.

La passe ne se limite pas au remplacement du beige. La silhouette combine un bandeau éditorial encadré, une carte d'identité du club dans la navigation, six pictogrammes originaux dessinés en vecteurs, une bande de sous-navigation et des panneaux à contraste de surface. Les photographies et surfaces sombres conservent leur propre encre claire ; les badges sémantiques ont priorité sur les accents décoratifs. L'ardoise reste une couleur neutre de structure, sans devenir l'identité d'un club.

## Réalisation et réception

1. Écrire et exécuter le témoin réel `godot-art-direction07`, sur scène et worker isolés. Il reçoit les quatre tailles 1280 × 720, 1600 × 900, 1920 × 1080 et 2560 × 1440, les contrastes des commandes, les bornes de la coque et l'absence d'écriture sportive pendant la navigation.
2. Modifier les primitives partagées `theme.gd`, `game_skin.gd`, `carnet_skin.gd`, `visual_widgets.gd`, puis la seule construction de coque de `main.gd`. `art_widgets.gd` dessine les signes de chapitre ; aucun fichier de vue métier du collègue n'est modifié.
3. Recevoir visuellement de vrais PNG Windows sur plusieurs menus, critiquer la réduction et les petits textes puis corriger avant gel. Une exécution headless ne prouve aucune qualité graphique.
4. Rejouer la réception de disposition existante. L'intégrateur vérifie ensuite la source exacte publiée et le paquet exporté ; les PNG du SDK ne prouvent pas cette dernière étape.

## Limites

Ce document décrit le lot de présentation. Le bilan des tests, captures et limites réellement observés est ajouté après réception, sans transformer un résultat vert en jugement esthétique.

## Réception du producteur — 8 novembre 2026

La réception graphique Windows utilise le SDK Godot 4.7.2 stable, Node 22.23.4 et le renderer Compatibility sur RTX 4080 SUPER. `tests/godot-art-direction07.cjs` copie physiquement les scripts, fige leurs empreintes, exécute le vrai worker avec un profil jetable sur E et compare l'export et le fichier de carrière avant/après les déplacements de lecture. Il reçoit dix menus à quatre résolutions, puis crée réellement une carrière commune de saison 1 à Toulouse pour retrouver les 61 joueurs et le portrait initial de la comparaison.

Résultat : **793 contrôles, zéro échec, 43 PNG** dans `E:/Cadrage-Debordement/artefacts/native07-menus/cd-art07-TPcwCW`. Les six fichiers de production de ce lot ont été comparés par SHA-256 à cette copie reçue et sont identiques. Les captures réellement regardées comprennent la fiche S1 à 2560, le Bureau S1, le Club, les finances et les menus compacts à 1280. Elles ont conduit à limiter la couleur du cadre aux seuls liserés et à renforcer les entêtes sans agrandir le corps.

Le témoin a aussi reproduit puis reçu deux corrections concrètes : un sélecteur préparé avant insertion figeait le thème gris de Godot ; le focus d'une action primaire claire sur fond sombre manquait de contraste. Le style détaché est désormais résolu dans le thème du carnet et le focus primaire utilise l'encre claire.

`tests/godot-interface-layout.cjs` : **832 contrôles, zéro échec**, en mode headless, preuves `E:/Cadrage-Debordement/artefacts/native07-menus/cd-layout-65WYhm`.

Un supplément avec `CD_ART07_MATCHES=1` crée deux rencontres réelles de la carrière S1 : **234 contrôles, zéro échec**. La capture `E:/Cadrage-Debordement/artefacts/native07-menus/cd-art07-HKGr9o/toulouse-bureau-deux-matchs-2560.png` montre le graphique sur des écarts réellement obtenus de −1 puis +13, avec grille, aire légère et points. Une sonde externe de rendu `[0, 0]` reçoit aussi la ligne horizontale sans erreur de polygone ; cette donnée de test n'entre jamais dans une carrière.

Le témoin existant `godot-navigation.gd`, exécuté sur la copie figée, reste **rouge : 2 échecs sur 121 contrôles**, exactement reproduits sur la copie prise avant toute modification 0.7 (`cd-art07-b0UDzp`). Les assertions « Palette depuis un effectif filtré : cible ID réellement visible » et « Deuxième dossier proposé dans le vrai effectif » ne trouvent pas la ligne sur la page courante. Le contrôleur de navigation restaure l'ID, mais la pagination de l'effectif n'expose pas toujours la page correspondante. Aucun correctif hors périmètre ni affaiblissement de ce témoin ; l'intégrateur reçoit ce constat.

Après ce gel du producteur, l'intégrateur a corrigé la révélation d'un dossier à travers la pagination dans `squad_views.gd`, en conservant la page volontaire et les assertions de sélection/historique. Le témoin courant reçoit **128 contrôles, zéro échec**, également reproduits par une revue indépendante ; les deux rouges décrits plus haut restent la preuve historique du défaut. La surface des tuiles a été éclaircie. Le second producteur a terminé les cartes du Bureau et les classements complets selon `native06-couleurs-20261108.md`. Les captures de ce lot ne valident ni le binaire exporté ni une livraison publiée sur GitHub ; ces étapes appartiennent à la réception finale de l'intégrateur.
