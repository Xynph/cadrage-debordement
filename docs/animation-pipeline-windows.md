# Réception Windows — chaîne d’animation Blender → Godot

Cette recette est destinée à **Codex PC sur Windows**, après les contrôles techniques Cloud. Elle décrit du travail à exécuter ; elle ne constitue pas une réception Windows déjà effectuée. Aucun changement de Gabi n’est inclus. Effort GPT‑6.1 Sol : **Élevé** pour la chaîne et les diagnostics ; **Moyen** pour exécuter une recette déjà stabilisée.

## Périmètre et preuves à conserver

Utiliser Godot **4.7.2** et Blender **5.2.x**. Le contrat source versionné est l’athlète `dist/match3d/assets/quaternius-rugby-athlete.glb`. Le chemin `native/godot/assets/match3d/quaternius-rugby-athlete.glb` est une copie de staging ignorée par Git, à préparer avant les tests du lecteur. Les nombres historiques 31 bones / 11 clips sont une référence à confronter à l’inventaire courant, jamais une valeur à injecter dans les résultats. Garder séparés source, candidat, contrôles techniques, captures et mesures. Le candidat n’est pas installé dans le jeu principal par cette recette.

Créer une copie de travail dédiée à ce lot depuis le commit de PR reçu, distincte de l’installation jouée et du profil personnel. Toutes les commandes ci-dessous partent de la racine de cette copie. La version finale de l’exécutable reste à recevoir séparément après intégration.

## 1. Préparer PowerShell et vérifier les versions

Le bloc suivant est de la syntaxe PowerShell exécutable. Les trois chemins marqués **À ADAPTER** sont des exemples, pas des chemins détectés sur le PC. Le répertoire de preuve doit être nouveau ; ne pas employer un répertoire de profil.

```powershell
$ErrorActionPreference = 'Stop'
$GodotExe = 'C:\Outils\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' # À ADAPTER
$BlenderExe = 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe' # À ADAPTER
$Proof = 'E:\Cadrage-Debordement\artefacts\animation-pipeline-reception' # À ADAPTER, dossier nouveau
foreach ($Exe in @($GodotExe, $BlenderExe)) {
    if (-not (Test-Path -LiteralPath $Exe -PathType Leaf)) { throw "Exécutable absent : $Exe" }
}
if (Test-Path -LiteralPath $Proof) { throw 'Choisir un nouveau dossier de preuve.' }
New-Item -ItemType Directory -Path $Proof | Out-Null
$GodotVersion = & $GodotExe --version 2>&1
if ($LASTEXITCODE -ne 0 -or "$GodotVersion" -notmatch '4\.7\.2') { throw "Godot non reçu : $GodotVersion" }
$BlenderVersion = & $BlenderExe --version 2>&1
if ($LASTEXITCODE -ne 0 -or "$BlenderVersion" -notmatch 'Blender 5\.2\.') { throw "Blender non reçu : $BlenderVersion" }
$GodotVersion | Set-Content -LiteralPath "$Proof\godot-version.txt" -Encoding UTF8
$BlenderVersion | Set-Content -LiteralPath "$Proof\blender-version.txt" -Encoding UTF8
node --version | Set-Content -LiteralPath "$Proof\node-version.txt" -Encoding UTF8
if ($LASTEXITCODE -ne 0) { throw 'Node absent.' }
python --version 2>&1 | Set-Content -LiteralPath "$Proof\python-version.txt" -Encoding UTF8
if ($LASTEXITCODE -ne 0) { throw 'Python absent.' }
git rev-parse HEAD | Set-Content -LiteralPath "$Proof\commit.txt" -Encoding UTF8
if ($LASTEXITCODE -ne 0) { throw 'La copie doit être un checkout Git.' }
$Source = (Resolve-Path -LiteralPath 'dist/match3d/assets/quaternius-rugby-athlete.glb').Path
$SourceHashBefore = (Get-FileHash -Algorithm SHA256 -LiteralPath $Source).Hash
Copy-Item -LiteralPath $Source -Destination "$Proof\source.glb"
$SourceHashBefore | Set-Content -LiteralPath "$Proof\source.sha256.txt" -Encoding UTF8
$Candidate = Join-Path $Proof 'candidate.glb'
```

L’enregistrement du SHA ne prouve pas que la branche est à jour ni que la CI est verte : contrôler la PR et son HEAD exact sur GitHub avant de recevoir un candidat. Ne pas réutiliser un ancien candidat d’un autre SHA sans le nommer explicitement.

## 2. Contrat de fabrication et comparaison du candidat

La commande suivante utilise le wrapper du lot et le script amont EL4CTEO à une révision fixée. **Son exécution Blender 5.2 Windows reste à recevoir** ; l’existence de la commande et un résultat Cloud sur une autre version ne prouvent pas cette compatibilité. Le candidat doit être un nouveau fichier ; ne jamais pointer vers la source.

```powershell
$Upstream = Join-Path $Proof 'EL4CTEO'
git clone https://github.com/EL4CTEO/blender-skills.git $Upstream
if ($LASTEXITCODE -ne 0) { throw 'Clone amont échoué.' }
git -C $Upstream checkout --detach 389f28addc79b87b28764898e38e7bf408d14b77
if ($LASTEXITCODE -ne 0) { throw 'Révision EL4CTEO indisponible.' }
$UpstreamHead = git -C $Upstream rev-parse HEAD
if ($LASTEXITCODE -ne 0 -or $UpstreamHead -ne '389f28addc79b87b28764898e38e7bf408d14b77') {
    throw 'La révision amont ne correspond pas.'
}
if (Test-Path -LiteralPath $Candidate) { throw 'Le candidat doit être nouveau.' }
& $BlenderExe -b --factory-startup --python-exit-code 2 -P tools/animation-pipeline/export_roundtrip.py -- $Upstream "$Proof\source.glb" $Candidate 2>&1 |
    Tee-Object -FilePath "$Proof\blender-export.log"
if ($LASTEXITCODE -ne 0) { throw 'Export Blender échoué.' }
if (-not (Test-Path -LiteralPath $Candidate -PathType Leaf)) { throw 'Export sans candidat.' }
if ((Get-FileHash -Algorithm SHA256 -LiteralPath $Source).Hash -ne $SourceHashBefore) {
    throw 'La source du jeu a changé.'
}
if ((Get-FileHash -Algorithm SHA256 -LiteralPath "$Proof\source.glb").Hash -ne $SourceHashBefore) {
    throw 'La copie source a changé.'
}
```

Conserver le journal d’export et tous les avertissements. Un export qui termine avec exit 0 ne constitue pas une réception du candidat : les contrôles et l’inspection qui suivent peuvent et doivent encore le refuser.

Le comparateur utilise des unités de transformation GLB/Godot ; l’asset comporte des facteurs d’échelle. Ne pas rebaptiser ses erreurs en mètres sans conversion physique explicitement validée. Pour l’aller-retour sans modification artistique, contrôler : noms/hierarchie des bones, pose de repos, noms/durées/boucles des clips, pistes résolues, échelles, matériaux, poids et transformations échantillonnées. Une comparaison de transforms de bones ne prouve pas l’égalité du maillage skinné, des normales, des UV ni des matériaux. Compléter l’inventaire par des mesures spécifiques de géométrie/poids et observer les captures ; une empreinte BIN différente n’identifie pas à elle seule la cause du changement.

Les CLI Python reçues inventorient le GLB et lancent le comparateur Godot dans un projet temporaire isolé. `--self-test` vérifie aussi un témoin source/source et un vrai GLB dont des clés de translation ont été modifiées de +0,05 sur une composante locale (sans prétention de distance physique en mètres) ; ce contrôle doit être rejeté. Les seuils ci-dessous sont des seuils d’essai d’aller-retour, pas des tolérances sportives ou une garantie perceptuelle ; ils doivent correspondre à ceux reçus dans la PR.

```powershell
if (-not (Test-Path -LiteralPath $Candidate -PathType Leaf)) { throw 'Candidat GLB absent.' }
python tools/animation-pipeline/inventory.py "$Proof\source.glb" --output "$Proof\source-inventory.json"
if ($LASTEXITCODE -ne 0) { throw 'Inventaire source échoué.' }
python tools/animation-pipeline/inventory.py $Candidate --output "$Proof\candidate-inventory.json"
if ($LASTEXITCODE -ne 0) { throw 'Inventaire candidat échoué.' }
python tools/animation-pipeline/compare_poses.py "$Proof\source.glb" $Candidate --godot $GodotExe --out "$Proof\poses.json" --samples 21 --position-units 0.0001 --rotation-rad 0.001 --scale 0.0001 --self-test 2>&1 |
    Tee-Object -FilePath "$Proof\poses.log"
if ($LASTEXITCODE -ne 0) { throw 'Comparaison des poses échouée : lire poses.json et poses.log.' }
Get-FileHash -Algorithm SHA256 -LiteralPath $Candidate |
    Format-List | Out-File -LiteralPath "$Proof\candidate.sha256.txt" -Encoding UTF8
if ((Get-FileHash -Algorithm SHA256 -LiteralPath $Source).Hash -ne $SourceHashBefore) {
    throw 'Le GLB source a changé pendant la recette.'
}
```

Vérifier `candidate.passed=true`, `identity.passed=true`, `negative_control.passed=false`, `self_test_passed=true`, `inputs_unchanged=true` et des nombres de clips, bones, poses et comparaisons positifs. L’inventaire fournit des comptes, noms, durées et empreintes ; il ne décode pas toutes les valeurs de géométrie/poids et ne certifie pas leur égalité à lui seul. Aucun résultat absent, crash ou test ignoré ne vaut réussite. Vérifier également que source et candidat n’ont pas été inversés et que la commande ne compare pas deux fois le même chemin. Un hash source=candidat est acceptable uniquement pour le **contrôle témoin identité**, pas comme preuve d’un vrai réexport Blender.

## 3. Tests existants du lecteur et du match

Les tests suivants utilisent le vrai projet. Le staging existant copie les assets contrôlés et vérifie aussi les registres et les voix ; une erreur de donnée doit être conservée et diagnostiquée, pas ignorée pour poursuivre. Il ne lance pas de génération de voix. Le résultat lecteur exige un **nouveau chemin absolu terminé par .json**, ce qui est assuré par le nouveau dossier `$Proof`. Ils ne doivent pas être lancés en parallèle d’une autre opération Godot graphique sur la machine. Les suites sont exécutées successivement ; ne pas changer de fichier de sauvegarde ou importer un profil personnel.

```powershell
$NodeExe = (Get-Command node -ErrorAction Stop).Source
python scripts/build-godot-prototype.py --stage-only --node $NodeExe 2>&1 |
    Tee-Object -FilePath "$Proof\stage.log"
if ($LASTEXITCODE -ne 0) { throw 'Staging natif échoué.' }
& $GodotExe --headless --path native/godot --editor --import --quit 2>&1 |
    Tee-Object -FilePath "$Proof\source-import.log"
if ($LASTEXITCODE -ne 0) { throw 'Import natif échoué.' }
python tools/animation-pipeline/test_compare_cli.py 2>&1 |
    Tee-Object -FilePath "$Proof\compare-cli-guards.log"
if ($LASTEXITCODE -ne 0) { throw 'Protections CLI échouées.' }
$env:CD_GODOT_EXE = $GodotExe
$env:CD_ANIMATION_READER_RESULTS = Join-Path $Proof 'reader-results.json'
& $GodotExe --headless --path native/godot --script ../../tools/animation-pipeline/check_match_reader.gd 2>&1 |
    Tee-Object -FilePath "$Proof\reader.log"
if ($LASTEXITCODE -ne 0) { throw 'Contrôle du lecteur échoué.' }
node --test --test-concurrency=1 tests/godot-match-silhouettes.cjs tests/godot-match-motion.cjs tests/godot-match-presentation.cjs tests/godot-match-framing.cjs tests/godot-match-contact07.cjs 2>&1 |
    Tee-Object -FilePath "$Proof\match-headless.log"
if ($LASTEXITCODE -ne 0) { throw 'Tests match échoués.' }
```

Ces suites valident les invariants du modèle chargé dans le projet. La suite silhouettes a des comptes/topologies propres au modèle courant et compare deux instances de ce modèle ; elle **ne compare pas, à elle seule, le GLB source au candidat**. Ne pas assouplir ses assertions pour faire passer un export incompatible.

Pour tester le candidat dans le rendu, créer une copie neuve du projet **sans son cache** avec `robocopy` (outil Windows). Cette commande copie le projet, pas les profils de carrière. Le remplacement touche uniquement cette copie ; il ne constitue pas une décision d’intégration.

```powershell
$CandidateProject = Join-Path $Proof 'candidate-project'
if (Test-Path -LiteralPath $CandidateProject) { throw 'La copie candidate doit être nouvelle.' }
$NativeProject = (Resolve-Path -LiteralPath 'native/godot').Path
robocopy $NativeProject $CandidateProject /E /XD .godot /NFL /NDL /NJH /NJS |
    Out-File -LiteralPath "$Proof\candidate-copy.log" -Encoding UTF8
if ($LASTEXITCODE -ge 8) { throw 'Copie candidate échouée.' }
Copy-Item -LiteralPath $Candidate -Destination (Join-Path $CandidateProject 'assets/match3d/quaternius-rugby-athlete.glb')
& $GodotExe --headless --path $CandidateProject --editor --import --quit 2>&1 |
    Tee-Object -FilePath "$Proof\candidate-import.log"
if ($LASTEXITCODE -ne 0) { throw 'Import candidat échoué.' }
$env:CD_MATCH_PROJECT = $CandidateProject
try {
    node --test --test-concurrency=1 tests/godot-match-silhouettes.cjs tests/godot-match-motion.cjs tests/godot-match-presentation.cjs tests/godot-match-framing.cjs tests/godot-match-contact07.cjs 2>&1 |
        Tee-Object -FilePath "$Proof\candidate-match-headless.log"
    if ($LASTEXITCODE -ne 0) { throw 'Tests du projet candidat échoués.' }
} finally {
    Remove-Item Env:CD_MATCH_PROJECT -ErrorAction SilentlyContinue
}
```

Si le candidat échoue, arrêter la réception et conserver les preuves. Ne pas contourner l’échec en remplaçant les assertions du modèle courant.

## 4. Fixture graphique reproductible, trente joueurs

Le harness existant `tests/godot-match-motion-capture.gd` produit une scène de trente acteurs, trois captures de caméra (`tv`, `tactical`, `action`), une séquence de mouvement et `bench.json` pour les profils `economy`, `balanced`, `detail`. Ses données sont une fixture de présentation, pas une carrière ni un nouveau simulateur de match.

Commande **graphique**, sans `--headless`, à exécuter une fois pour la source, puis sur la copie du projet contenant le candidat avec les mêmes réglages et un autre dossier. Le premier bloc ci-dessous vise le projet source. Pour la copie, remplacer seulement l’argument `--path` par le chemin absolu de la copie ; `--script` doit alors être le chemin absolu du harness de ce checkout.

```powershell
$env:CD_MATCH_PROOF = Join-Path $Proof 'source-graphics'
$CaptureScript = (Resolve-Path -LiteralPath 'tests/godot-match-motion-capture.gd').Path
& $GodotExe --path native/godot --script $CaptureScript --max-fps 120 2>&1 |
    Tee-Object -FilePath "$Proof\source-graphics.log"
if ($LASTEXITCODE -ne 0) { throw 'Capture graphique source échouée.' }
```

Le fichier produit ne doit pas contenir un adaptateur logiciel (`SwiftShader`, `llvmpipe`, etc.) si l’on revendique une réception GPU Windows. Conserver le modèle CPU/GPU, le pilote, la résolution, le renderer, l’alimentation secteur, les réglages VSync et la limite d’images. Ne pas interpréter un plafond de 16,67 ms ou celui de `--max-fps` comme une réserve de performance GPU.

À chaque capture, observer et noter explicitement :

- **Caméras** : corps entier, ballon visible, pas de clipping, marqueurs et tenues lisibles ; comparer les mêmes instants et la même caméra.
- **Appuis** : pied planté, glissement, genoux, pivots, accélération/freinage, absence de téléportation et de déformation des membres.
- **Ballon** : bonne main/porteur, réception sans saut parasite, absence d’étirement ; l’animation ne décide jamais d’un essai ou d’une possession.
- **Pose et tenue** : proportions, épaules/coudes/poignets, maillot/short/chaussettes, normales et couleurs de club ; cas bras hauts et inclinaison du buste.
- **Contact** : préparation visuelle proche seulement ; aucun plaquage ou chute ne doit être revendiqué si le moteur ne fournit pas les participants et états correspondants.

## 5. Pause/reprise et lecture dans le vrai jeu Windows

Le harness de captures n’exécute pas tous les parcours de l’application distribuée. Sur une **carrière de test créée pour la recette**, jouer un match avec trente joueurs visibles, changer les trois caméras, mettre en pause dix secondes, reprendre, changer de qualité, terminer puis relancer un match. Enregistrer la version du jeu et le SHA associé. Utiliser un profil de recette explicitement séparé (`CD_GODOT_DATA_DIR` est reconnu par le projet source) ; ne pas ouvrir ni modifier la carrière personnelle.

À la pause : joueurs, squelette et ballon doivent être immobiles sans dérive ; à la reprise : pas de remise en T-pose, de rattrapage d’animation brutal, d’événement répété ni de téléportation. Tester une transition de porteur et la disparition d’un joueur de la scène ; vérifier l’absence de bras resté accroché à une cible précédente. Noter les gestes absents comme des limites, sans les inventer.

La commande exacte de lancement de l’exécutable dépend du candidat Windows effectivement livré et de son lanceur. **Aucun chemin d’EXE distribué ni profil de carrière n’est supposé ici.** Le test doit nommer le fichier réellement lancé et la méthode d’isolation employée.

## 6. Mesures et verdict

Conserver deux campagnes comparables, source/candidat, sur la même machine. Pour chaque profil : trente acteurs, 180 échantillons du harness, médiane/p95 temps d’image et CPU de projection, draw calls et primitives, adaptateur. Le harness ne mesure pas directement le temps GPU ni les pics de mémoire de toute l’application : employer le profiler Godot et les outils Windows pour ces points, ou marquer **non mesuré**.

Faire au moins trois répétitions si une décision de performance dépend d’un petit écart ; noter la dispersion et l’ordre des passages. Ne pas déclarer un gain lorsque les mesures sont plafonnées, bruitées ou incomparables. Vérifier aussi le premier chargement à cache froid et le lancement suivant, en les étiquetant séparément.

Table de réception à remplir avec les vraies preuves :

| Critère | Source | Candidat | Verdict / preuve |
| --- | --- | --- | --- |
| SHA GLB, SHA code, versions outils | À mesurer | À mesurer | Non reçu |
| Bones/clips/repos/durées/boucles | À mesurer | À mesurer | Non reçu |
| Erreurs maximales de pose / seuils | Témoin | À mesurer | Non reçu |
| Géométrie/poids/matériaux | À mesurer | À mesurer | Non reçu |
| Trente acteurs, trois caméras/qualités | À observer | À observer | Non reçu |
| Appuis, ballon, pause/reprise | À observer | À observer | Non reçu |
| Temps image, CPU, draw calls/primitives | À mesurer | À mesurer | Non reçu |
| Temps GPU/mémoire/premier chargement | À mesurer | À mesurer | Non reçu |
| EXE Windows réellement lancé | À nommer | À nommer | Non reçu |

Bloquer la substitution si le candidat altère la référence, perd un clip/bone, change l’échelle, échoue aux contrôles ou dégrade le rendu sans décision produit explicite. Un candidat techniquement reçu reste soumis à la PR, à sa CI exacte et au gate du dépôt. La recette n’autorise aucun bypass ni fusion.
