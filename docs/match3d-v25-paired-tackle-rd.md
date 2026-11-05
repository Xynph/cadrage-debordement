# MATCH 3D V25 — Comparatif des plaquages à deux joueurs (R&D isolée)

État : **prototype expérimental**, sans connexion au moteur sportif, aux sauvegardes ni à PR #300.

## Ce qui est réellement testé

- Deux instances des GLB canoniques à **53 os** sur chacun des trois LOD, après conversion *de copies* (suppression de l'extension `KHR_mesh_quantization` avec glTF-Transform 4.5.1 MIT).
- Construction Kickback/Godot 4.7 de **16 corps rigides par joueur**, sol en collision réelle Jolt.
- Trois scénarios appariés par LOD : **approche sans choc**, **approche et choc**, **approche/choc et deux liaisons physiques entre vrais corps rigides de mains et du porteur**.
- Relevés temporels à l'approche, à l'impact, à la chute et à la récupération : position des deux torses, séparation, distance des deux rigid bodies de main aux torses/bassin, hauteur des centres des pieds.
- Les liaisons main-corps sont des **ressorts physiques expérimentaux**. Elles ne constituent pas une preuve de contact à la vraie peau, de saisie anatomique crédible ou de respect des 53 poids de skinning.
- La CI archive `paired-tackle-3lod.json`, les logs, les empreintes et les conditions d'exécution ; **aucun test absent n'est compté comme réussi**.

## Suite visuelle indispensable avant qualification

Rejouer des animations et produire de vraies captures rendues face/profil avec les **GLB habillés d'origine**, synchronisées aux échantillons physiques. Comparer des images appariées contrôle/choc/saisie avec les mêmes caméras, plus des zooms mains/épaules. Ne pas se contenter de captures de géométries proxy.

Renseigner : écart de chaque **poignet à la surface réellement skinnée**, intersections triangle-triangle des deux corps *et des vêtements*, plus bas sommet skinné sur les six surfaces d'appui (poitrine, bassin, genoux L/R, pieds L/R), glissement des appuis et stabilité temporelle. L'absence de chevauchement sur un simple sous-échantillon n'est pas une certification exhaustive.

**Seuil de qualification visuelle** : vues face et profil en TV et gros plan sur les trois LOD, sur approche, saisie, impact, chute et récupération. Les deux mains doivent former une prise lisible autour du porteur, sans bras traversant le torse et sans corps flottant ni doigts/coudes qui transpercent le terrain. Mesurer les erreurs sur les mêmes instants/LOD ; une amélioration de métrique non visible ou qui crée une nouvelle collision est rejetée. Exiger 9/9 validations du HEAD exact et comparatif CPU apparié avant tout raccordement au match.

## Sources réutilisables et restrictions

- **Kickback** (MIT), code Godot/Jolt pouvant inspirer un portage contrôlé vers le runtime Three.js : https://github.com/blugart-dev/kickback . Ses tests amont ne prouvent pas un plaquage de rugby.
- **ActiveRagdoll** (MIT), algorithmes PID Unity/C# uniquement étudiés : https://github.com/ashleve/ActiveRagdoll .
- **CMU MoCap** (autorisation gratuite, conditions propres à la base) : https://mocap.cs.cmu.edu/ . Inclusion dans un jeu commercial permise ; ne pas commercialiser les fichiers de capture indépendamment, même convertis. Les captures à deux sujets pertinentes restent **à identifier et à vérifier**.
- **Mixamo** : https://helpx.adobe.com/creative-cloud/faq/mixamo-faq.html . Adobe permet les animations dans les jeux commerciaux ; ne pas redistribuer les fichiers bruts en bibliothèque d'assets. Aucun clip « Soccer Tackle » n'est actuellement téléchargé, possédé, vérifié ni intégré dans ce banc d'essai.
- **PhysicsFC** : licence NVIDIA non commerciale ; analyse seulement, pas de copie de code en produit.
- **Striker 3D / autres dépôts sans licence** : le code public ne donne pas droit à sa réutilisation ; consultation technique uniquement.

## Décision bloquante

**Interdit de proclamer ce prototype qualifié** tant que l'interaction à deux joueurs n'a pas passé la qualification visuelle, la vraie peau skinnée, les appuis temporels et la comparaison avec/sans choc sur les trois LOD. Un script avec deux ressorts physiques peut démontrer une interaction mais ne remplace pas un geste de plaquage capturé/réutilisable.

Aucune modification autorisée : PR #300, moteur V24, GLB originaux, 30 rigs runtime, PRODUCTEUR, DATA/LNR, sauvegardes, auto-release, gate ou fusion.
