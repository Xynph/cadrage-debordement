# Portraits fictifs composés localement

Ce moteur d’apparence fonctionne entièrement hors ligne, sans clé, service distant, modèle lourd ou inférence d’IA à l’exécution. Il compose localement des visages à partir de **48 portraits fictifs prégénérés par IA** : 32 joueurs des atlas existants du 7 novembre 2026 et 16 membres de staff d’un nouvel atlas du 9 novembre. Les fichiers et leurs SHA-256 sont déclarés dans `native/godot/art/regen-portraits-manifest.json`.

La composition utilise une géométrie du visage légèrement variable, un cadrage, une saturation/exposition bornées, une teinte de vêtement et un traitement illustratif de l’âge. Elle ne se limite pas au choix d’un numéro parmi les atlas, mais ne produit pas non plus une nouvelle photographie par intelligence artificielle. Les paramètres distincts ne garantissent ni unicité visuelle, ni ressemblance réelle. Les collisions et ressemblances restent possibles.

## Identité et âge

La clé déterministe est `appearanceId` si fourni, sinon `sourcePlayerId`, puis `id`. Si aucune identité n’est fournie, un fallback commun `anonymous` est utilisé ; le nom et le club ne servent jamais à fabriquer une identité visuelle. Le hash et le générateur local n’utilisent pas le RNG sportif du jeu.

Un joueur devenant membre du staff conserve `sourcePlayerId` égal à son identifiant d’origine, donc son atlas joueur et sa cellule de visage. Son âge courant peut faire évoluer légèrement le traitement visuel ; il ne remplace jamais sa base par un visage de staff différent.

Pour un staff créé directement, **`appearanceAge` doit être l’âge initial immuable de l’apparence**. Il choisit une rangée de référence de l’atlas (environ 40–49, 50–59, 60–69 ou 70 ans et plus), tandis que le hash choisit la cellule dans cette rangée. Modifier l’âge courant ne change pas cette cellule. Sans `appearanceAge`, la cellule reste fixée par le hash et l’âge est explicitement déclaré illustratif. Les personnes plus jeunes que les rangées disponibles ne disposent pas d’une promesse d’âge exact ; un âge inconnu n’est jamais converti en fait biographique.

Ces champs appartiennent au contrat d’apparence. Le module n’ajoute ni ne modifie de sauvegarde : les producteurs de nouveaux staffs doivent conserver `appearanceId`, `sourcePlayerId` et `appearanceAge` selon leur politique de création. Les annuaires existants sans ces champs continuent à recevoir un fallback stable et illustratif.

## Raccordement

`native/engine/portraits.cjs` exporte `describe(person)` et `hash(id)`. Le descripteur est pur, déterministe, indépendant des noms, club, niveau et condition. Le rôle staff est indiqué par `portraitRole:'staff'` ou `appearanceRole:'staff'` ; en leur absence, un champ `role` sans poste de joueur est reconnu comme une fiche de staff. `sourcePlayerId` impose toujours une origine joueur.

`native/godot/ui/regen_portrait.gd` fournit :

- `describe(person)` : même descripteur, contrôlé contre Node, y compris pour les clés UTF-8 ;
- `texture(person)` : cellule recadrée en texture locale de 256 × 256 ;
- `material(person)` : shader de composition associé ;
- **`apply(texture_rect,person)`** : raccordement complet du crop et du shader, avec tooltip d’origine et de limites ; renvoie false si la source visuelle ne peut être chargée ;
- `cache_info()` et `clear_cache()` pour la qualification.

Le raccordement du jeu doit appeler `apply` **seulement après le test prioritaire du portrait fourni par un pack**. La fonction est un fallback de portrait fictif, pas un sélecteur de photo officielle. Elle ne télécharge rien et ne remplace pas les médias réels du pack. Le contrôle de priorité des packs appartient au raccordement dans `game_skin.gd` et les vues joueur/staff.

La texture source est recadrée une seule fois par cellule via les opérations natives d’Image : le shader reçoit ainsi des UV locaux et ne peut pas déborder dans une autre case de l’atlas. Pas de boucle de traitement d’image par frame. Le cache contient au plus **48 crops** (environ 12 Mio de pixels RGBA) et **128 matériaux**. Les atlas et un shader partagé sont chargés localement ; aucune ressource n’est créée à chaque frame d’un portrait déjà en cache.

## Qualification

`node --test tests/regen-portraits.cjs` couvre déterminisme, identité sous changement de nom/club, continuité joueur→staff, ancrage de l’âge de référence, limites de paramètres et hashes des sources. Un échantillon de 200 IDs reçoit des profils de paramètres distincts ; cela n’est pas présenté comme une preuve d’unicité perceptuelle.

Après le staging officiel et l’import des assets, `CD_GODOT_EXECUTABLE=/chemin/Godot_4.7.2 node --test tests/godot-regen-portraits.cjs` compare les descripteurs Node/Godot, vérifie de vrais crops et matériaux, la même base joueur/staff, le tooltip et les bornes du cache après 220 identités.

Réception Linux Node 22.23.4, Godot 4.7.2 sans fenêtre : **376 contrôles réussis, zéro échec**. La qualification headless vérifie les ressources et paramètres ; elle ne remplace pas l’examen graphique du shader sur une fenêtre native ni la réception Windows. Le nouvel atlas staff et les deux atlas joueurs ont été examinés visuellement comme sources ; aucune promesse de vieillissement photoréaliste individuel n’en découle.
