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

## Mesures réellement obtenues — protocole R&D à deux joueurs

Le run `42124620151` (HEAD `beb7e4913284d5b2f99e8f0d23fbcf3077c4d92f`) a exécuté sur les trois LOD les trois scénarios contrôle / impact / impact avec deux PinJoint3D entre les corps physiques des vraies mains et ceux du porteur. **3/3 LOD, 9/9 scénarios terminés**, 2/2 joints créés par LOD. Artefact GitHub `13459474083`, digest SHA256 `a04bcc741686cf974b923ae51cef038478c4b0eb12fcc764c444a8d60b0035e3` vérifié sur les octets téléchargés.

Les distances **centre de la main rigide → centre du torse adverse** sont encore comprises souvent entre 0,8 et 1,0 m. Il serait faux d'en déduire une saisie visible, un contact peau-peau ou une non-intersection des triangles. Au moment de l'approche, le centre rigide d'un pied descend parfois sous y=0 selon le scénario, **ce qui ne mesure pas directement le point le plus bas de la véritable chaussure skinnée** ; la physique ne remplace pas un audit de surfaces.

La paire CMU **18_03 / 19_03**, « A pulls B; B resists », a été téléchargée à partir de `una-dinosauria/cmu-mocap` commit `09a07f54f3bbb58797325f009282d0b2048a2871` et analysée comme source potentielle de saisie : **593 frames par sujet, ≈4,94 s synchronisées**, empreintes individuelles enregistrées dans `cmu-two-actor-pull-source.json`. La conversion BVH Bruce Hahne revendique explicitement n'ajouter aucune restriction à CMU dans `READMEFIRST.txt`. **Aucun retargeting ni rendu sur nos GLB n'est encore qualifié.**

Les images Godot face/profil issues d'une simulation réellement rendue restent **obligatoires** avant d'identifier une amélioration visuelle ; les chiffres physiques ci-dessus ne comptent pas comme qualification.

## Capture visuelle réellement reçue — constat non qualifié

Le run `42125241449`, SHA `e56827726f8a243d1a3f8ccdd94a7b632edc1f21`, a publié l'artefact GitHub `13461210599` (ZIP **1 020 666 octets**, SHA256 **`26ee284ae66759e6bb8d5272883537ac511999d617900e2e4e95209474e16758`**, vérifié sur les octets) avec **90 vraies captures Godot/OpenGL logiciel** : face/profil × cinq phases × trois scénarios × trois LOD. Les images sont archivées sous `paired-images/` et les mesures de la même fenêtre sous `paired-render-3lod.json`. L'audit source CMU (593 frames × deux acteurs synchronisés, 4,94 s), la physique Kickback et les imports canoniques sont PASS.

**Conclusion visuelle après inspection de l'impact et de la récupération : échec de qualification.** Le témoin et les scénarios à impact montrent une flexion excessive des jambes et un effondrement trop précoce des torses, avec pieds et genoux en posture de squat à la place d'une course/prise rugby. Les deux liaisons `PinJoint3D` fonctionnent dans la physique (2/2 sur chaque LOD), mais les centres des mains restent typiquement à 0,8–1,0 m des centres du torse cible et les mains n'enveloppent pas réellement sa peau. Des centres de pieds rigides passent par des valeurs y négatives pendant l'approche ; sans test de sommets skinnés cela ne démontre ni ne réfute une pénétration réelle.

**Aucun rendu/pose de ce run ne doit être considéré comme qualifié**. Le prochain test d'animation idle + rigid body cible précisément la stabilisation AVANT impact ; aucune pose ni ressource n'est transférée au moteur Three.js.
