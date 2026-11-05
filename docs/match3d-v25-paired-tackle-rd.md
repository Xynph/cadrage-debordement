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

## Verdict de stabilité après raccordement Idle — refus confirmé

Le run `42126024200`, HEAD `612d692abd77fefa4266e952239268568e5c1dbf`, a **échoué à bon droit** sur le garde-fou pré-impact, sans panne de téléchargement ni de maillage. Artefact `13460427378`, ZIP SHA256 `7e1eeef7f15e8def7735f1cf72f121d75b4945199c578b640e195eb18f03c68d`, identique au digest GitHub, rapports complets pour les neuf scénarios.

Les **12 vraies animations** sont bien reconnues : `fall, idle, idle_breathe, idle_fidget, idle_look, jump, land, run, strafe_left, strafe_right, walk, walk_back`. L'animation `idle` a été sélectionnée et jouée en boucle sur les deux personnages de chaque LOD.

Malgré cela, la descente du torse entre début et fin d'approche est de **0,80 à 0,82 m** dans les neuf scénarios, **avant** le choc. Le seuil de stabilité `preImpactChestDropM <= 0.35 m` rejette donc **9/9** scénarios. Cela invalide toute revendication de plaquage/récupération crédible dans la scène actuelle. Le moteur Kickback a réussi ses tests amont et son test élémentaire à deux rigs, mais l'**adaptation de sa cible d'animation/ressorts au vrai squelette canonique en séquence n'est PAS stabilisée**. La cause profonde (calibrage des ressorts, poses cibles, boucle de synchronisation) reste à investiguer ; ne pas lui attribuer une cause précise non mesurée.

**Décision produit R&D** : conserver l'audit des 53 os, les 221 tests amont, la déquantification en copies, le duo CMU synchronisé et les 90 captures comme résultats techniques vérifiés. Mettre le montage Kickback+PinJoint en statut **NON QUALIFIÉ**, sans intégration moteur, PR #300, GLB ni runtime. La prochaine recherche doit isoler la stabilité du ragdoll animé avant de réexaminer tout geste de plaquage.

## Résultat nouveau — isolation de la cause de l'effondrement, correction vérifiée

Le banc `godot_idle_stability_probe.gd` utilise les 3 vrais GLB 53 os, l'animation `idle` canonique, sans approche, choc ou liaison des bras. Il compare `animated_only`, `kickback_default`, `no_foot_ik`, `no_root_strip` et `no_foot_ik_no_root_strip`. Run GitHub `42128781410`, HEAD `0e5197e4b4c5533f320e4953e92c1ca0207d9b79`, archive `13463085157`, **618 446 octets**, SHA256 **`59a7eca5118249541401f63072aff166815d5153dc431689ba2cd200655408b4`** égal digest GitHub. 54 vraies images face/profil, 15 modes (3 LOD × 5) et rapport temporel `idle-stability-3lod.json`.

**Cause identifiée :** `RagdollTuning.strip_root_motion=true` supprime le XZ de la hanche, mais sur le squelette canonique cette suppression modifie la composition de sa cible mondiale : la cible de `Chest` mesurée passe de **1,092 m (vrai idle)** à **0,218 m**. Le contrôleur poursuit ce mauvais niveau, d'où le squat pré-impact. Désactiver seulement `foot_ik_enabled` ne corrige pas la chute. Avec `strip_root_motion=false`, le modèle réel reste debout et suit la vraie animation : LOD0/1/2 descente **0,007/0,006/0,006 m** en 60 frames contre **0,649/0,812/0,638 m** en configuration par défaut ; écart cible torse final **0,0096/0,0091/0,0095 m**. Les autres modes sans root-strip et sans foot IK restent stables, mais le réglage du root-strip suffit. **Qualification limitée à la stabilité idle, pas au rugby.** Captures réelles inspectées et montage avant/après sur 3 LOD.

**Application au duel exclusivement R&D :** dans `godot_paired_tackle_probe.gd`, on crée une `RagdollTuning` de test par joueur avec `strip_root_motion=false`, sans modifier Kickback amont, moteur Three.js ou GLB. Run GitHub `42129343186`, HEAD `243a4d6bfe2bf1c04f0a29337f8a36fb47ad727c`, artefact `13461784234`, ZIP **1 090 997 octets**, SHA256 **`31d18aba759448e0e848af58843a4374e5978e49d71b6a85dce485f18fe52eff`** vérifié. **9/9 scénarios exécutés, 2 PinJoint3D par duel**, 90 captures front/side réelles. À l'approche les chutes des torses ne dépassent plus **0,0039–0,0061 m**. En revanche, le choc est trop faible pour produire une vraie chute, les bras n'enveloppent pas la peau : distances centres main→torse 0,8m, contact skinné NON vérifié. Les captures ont été réellement ouvertes et **plaquage toujours visuellement NON QUALIFIÉ**.

**Étape suivante après cette stabilité :** test autonome `cmu_duo_retarget_probe.py` + `cmu_duo_retarget_runner.py` : Blender 4.5.3 checksum officiel, Rigger GPL-3, CMU/Bruce Hahne duo BVH 18_03+19_03 593 frames synchronisées et SHA256 connus ; essai d'un premier transfert de 90 frames réelles sur chacun des trois LOD / deux acteurs. Les résultats sur la licence, la compatibilité des importeurs, le mouvement des poignets et les clips transférés doivent être prouvés par la nouvelle CI, et jamais présumés. Aucune copie des BVH bruts n'est archivée dans les rapports. Le geste reste une traction/résistance, pas un plaquage rugby.

**Toujours bloquant :** les six appuis sur sommets réellement skinnés par la physique et les intersections triangle/triangle des deux personnages au fil du temps n'ont pas encore été mesurés. Aucun glissement d'appui, absence d'intersection ou qualification visuelle de rugby ne peut être affirmé sur ces simples corps physiques et captures.
