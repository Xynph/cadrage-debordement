# Banque versionnée de 200 bases de portraits

Le catalogue compte 160 bases joueurs et 40 bases staff : 32 joueurs et 16 staff conservés, plus 128 joueurs et 24 staff originaux. Les cheveux, yeux, barbe, corpulence et marques distinctives appartiennent aux images IA prégénérées. Le shader conserve uniquement ses variations locales discrètes existantes ; aucune coiffure ou inférence IA n’est produite à l’exécution, aucune unicité perceptuelle n’est garantie.

Une personne sans `appearanceBankVersion`, ou avec la valeur1, conserve exactement son ancien descripteur et son rendu parmi les48bases historiques. Les nouveaux joueurs générés et nouveaux membres fictifs du staff enregistrent la valeur2 à leur création. Les références d’annuaire restent historiques, même lors de leur activation en carrière. Une reconversion hérite exactement de la version du joueur et de son `sourcePlayerId` ; nom, club, rôle et âge courant ne choisissent jamais une nouvelle base. Aucun champ n’est ajouté lors d’une consultation ou d’un import.

Pour la banque2, le hash stable de l’identité choisit une des160bases joueurs. Le staff conserve sa bande d’âge initiale : quatre anciennes et six nouvelles bases par bande40/50/60/70. Les variantes suivent le même tirage déterministe local existant, sans consommer le RNG du jeu. Les photos valides des packs gardent priorité.

Plan : figer des exemples legacy avant modification ; vérifier les descripteurs Node/Godot et la couverture200 ; ajouter uniquement les métadonnées de naissance, projections et validations nécessaires ; exercer création, promotion, conversion, import et réouverture par le vrai worker ; après réception de tous les PNG, vérifier leurs empreintes, les crops4×4/6×4 et le rendu X11. Les caches restent bornés à48textures de visage et128matériaux. Les anciens fichiers et leur manifeste ne sont pas réécrits.

Les nouvelles images et leurs traits observés doivent encore être reçus avant toute qualification graphique complète. L’absence d’un asset n’autorise pas une réception fictive de la banque200.

Réception du code avant livraison des huit planches : 19 tests Node réussis, un contrôle d’assets explicitement non exécuté (`CD_REGEN_ASSETS_PENDING=1`), et526contrôles Godot réussis sur les descripteurs partagés Node/Godot et les textures historiques. La réception complète des200crops et des planches graphiques reste en attente. Les bornes des cellules se calculent par fractions de l’image (4×4 ou6×4) ; une planche1254×1254 n’est pas divisée en cellules supposées entières de256pixels.

La compilation commune a été régénérée. La comparaison complète des fichiers avant/après, après neutralisation des deux empreintes `dist/game.js` et `dist/development.js`, est strictement identique : les1592profils des30clubs ne changent pas.
