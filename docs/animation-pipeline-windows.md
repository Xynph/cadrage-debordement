# Réception Windows — chaîne d’animation Blender → Godot

Cette recette est destinée à **Codex PC sur Windows**, après les contrôles techniques Cloud. Elle décrit du travail à exécuter ; elle ne constitue pas une réception Windows déjà effectuée. Aucun changement de Gabi n’est inclus. Effort GPT‑6.1 Sol : **Élevé** pour la chaîne et les diagnostics ; **Moyen** pour exécuter une recette déjà stabilisée.

## Périmètre et preuves à conserver

Utiliser Godot **4.7.2**. Deux parcours Blender sont distincts : **A — reproduire le diagnostic Cloud avec Blender 4.3.2**, puis **B — qualifier Blender 5.2**, ce qui nécessite une revue de compatibilité encore non effectuée. Le wrapper actuel refuse volontairement toute version autre que 4.3.2 pour son correctif privé de poids ; lancer sa commande inchangée sur 5.2 produirait un refus attendu, pas un essai compatible. Le contrat source versionné est l’athlète `dist/match3d/assets/quaternius-rugby-athlete.glb`. Le chemin `native/godot/assets/match3d/quaternius-rugby-athlete.glb` est une copie de staging ignorée par Git, à préparer avant les tests du lecteur. Les nombres historiques 31 bones / 11 clips sont une référence à confronter à l’inventaire courant, jamais une valeur à injecter dans les résultats. Garder séparés source, candidat, contrôles techniques, captures et mesures. Le candidat n’est pas installé dans le jeu principal par cette recette.

Créer une copie de travail dédiée à ce lot depuis le commit de PR reçu, distincte de l’installation jouée et du profil personnel. Toutes les commandes ci-dessous partent de la racine de cette copie. La version finale de l’exécutable reste à recevoir séparément après intégration.

## 1. Préparer PowerShell et vérifier les versions

Le bloc suivant est de la syntaxe PowerShell exécutable. Les trois chemins marqués **À ADAPTER** sont des exemples, pas des chemins détectés sur le PC. Le répertoire de preuve doit être nouveau, **hors du dépôt et hors du projet lecteur** ; ne pas employer un répertoire de profil. Le runner contrôle aussi ces exclusions.

```powershell
$ErrorActionPreference = 'Stop'
$GodotExe = 'C:\Outils\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' # À ADAPTER
$BlenderExe = 'C:\Outils\Blender-4.3.2\blender.exe' # À ADAPTER, parcours A seulement
$Proof = 'E:\OvalLegacy27-Receptions\animation-pipeline-reception' # À ADAPTER, dossier nouveau hors dépôt
foreach ($Exe in @($GodotExe, $BlenderExe)) {
    if (-not (Test-Path -LiteralPath $Exe -PathType Leaf)) { throw "Exécutable absent : $Exe" }
}
if (Test-Path -LiteralPath $Proof) { throw 'Choisir un nouveau dossier de preuve.' }
New-Item -ItemType Directory -Path $Proof | Out-Null
$GodotVersion = & $GodotExe --version 2>&1
if ($LASTEXITCODE -ne 0 -or "$GodotVersion" -notmatch '4\.7\.2') { throw "Godot non reçu : $GodotVersion" }
$BlenderVersion = & $BlenderExe --version 2>&1
if ($LASTEXITCODE -ne 0 -or "$BlenderVersion" -notmatch 'Blender 4\.3\.2(?:\s|$)') { throw "Blender non reçu : $BlenderVersion" }
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

### Python des comparateurs, isolé de Blender

`compare_skin.py` et les contrôles de peau/normales du runner exigent **NumPy et SciPy dans le même Python que celui qui lance `run_checks.py`**. Créer un environnement local au dossier de preuve et installer les versions reçues dans `tools/animation-pipeline/requirements.txt` (NumPy 2.3.5, SciPy 1.17.0) ; aucun compte ni secret n’est requis pour ces paquets publics. Utiliser une version Python compatible avec ces versions ; la réception Cloud utilise Python 3.12, ce qui ne prouve pas toutes les autres versions. L’installation peut accéder au dépôt public de paquets Python : en cas de blocage réseau ou de version Python incompatible, conserver l’erreur et ne pas déclarer les comparateurs exécutés. Ne pas installer ces paquets globalement et ne pas activer un environnement au hasard.

```powershell
$VenvDir = Join-Path $Proof 'python-env'
python -m venv $VenvDir
if ($LASTEXITCODE -ne 0) { throw 'Création venv impossible.' }
$PythonExe = Join-Path $VenvDir 'Scripts\python.exe'
& $PythonExe -m pip install -r tools/animation-pipeline/requirements.txt 2>&1 |
    Tee-Object -FilePath "$Proof\python-dependencies.log"
if ($LASTEXITCODE -ne 0) { throw 'Installation NumPy/SciPy impossible.' }
& $PythonExe -c "import sys,numpy,scipy; print(sys.version); print('NumPy',numpy.__version__); print('SciPy',scipy.__version__)" 2>&1 |
    Tee-Object -FilePath "$Proof\python-modules.txt"
if ($LASTEXITCODE -ne 0) { throw 'Modules absents du Python retenu.' }
& $PythonExe -m pip freeze | Set-Content -LiteralPath "$Proof\python-requirements-received.txt" -Encoding UTF8
if ($LASTEXITCODE -ne 0) { throw 'Versions des modules non enregistrées.' }
```

Utiliser ensuite **`& $PythonExe`** pour les scripts Python de cette recette. Blender possède son **propre Python et son NumPy embarqué** : l’environnement ci-dessus ne modifie pas Blender. Les étapes de rétablissement du bind et des normales utilisent ce NumPy embarqué ; une erreur de module Blender reste bloquante. Ne pas copier le venv dans l’installation Blender.

L’enregistrement du SHA ne prouve pas que la branche est à jour ni que la CI est verte : contrôler la PR et son HEAD exact sur GitHub avant de recevoir un candidat. Ne pas réutiliser un ancien candidat d’un autre SHA sans le nommer explicitement.

## 2. Parcours A — reproduire le candidat avec Blender 4.3.2

La commande suivante utilise le wrapper du lot et le script amont EL4CTEO à une révision fixée. Elle ne vise que **Blender 4.3.2** ; sa reproduction sur Windows reste à exécuter. Le correctif en mémoire de conservation des très faibles influences vérifie à la fois la version exacte 4.3.2 et l’empreinte de la fonction privée amont. Même avec le bon numéro de version, une implémentation différente est refusée. Le candidat doit être un nouveau fichier ; ne jamais pointer vers la source.

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

Conserver le journal d’export, la ligne `ROUNDTRIP_EXPORT` et tous les avertissements. Le wrapper importe sans deviner le bind, désactive l’optimisation des clés, préserve les échelles statiques et les influences positives, récupère le bind pondéré puis rétablit explicitement les normales source avec correspondance topologique. Ces adaptations sont enregistrées dans le rapport : il ne s’agit pas d’un export brut inchangé. Un export qui termine avec exit 0 ne constitue pas une réception du candidat : les contrôles de poses, de peau/normales et l’inspection qui suivent peuvent et doivent encore le refuser.

Le comparateur utilise des unités de transformation GLB/Godot ; l’asset comporte des facteurs d’échelle. Ne pas rebaptiser ses erreurs en mètres sans conversion physique explicitement validée. Pour l’aller-retour sans modification artistique, contrôler : noms/hierarchie des bones, pose de repos, noms/durées/boucles des clips, pistes résolues, échelles, matériaux, poids et transformations échantillonnées. Une comparaison de transforms de bones ne prouve pas l’égalité du maillage skinné, des normales, des UV ni des matériaux. Compléter l’inventaire par des mesures spécifiques de géométrie/poids et observer les captures ; une empreinte BIN différente n’identifie pas à elle seule la cause du changement.

Les CLI Python reçues inventorient le GLB et lancent le comparateur Godot dans un projet temporaire isolé. `--self-test` vérifie aussi un témoin source/source et un vrai GLB dont des clés de translation ont été modifiées de +0,05 sur une composante locale (sans prétention de distance physique en mètres) ; ce contrôle doit être rejeté. Les seuils ci-dessous sont des seuils d’essai d’aller-retour, pas des tolérances sportives ou une garantie perceptuelle ; ils doivent correspondre à ceux reçus dans la PR.

```powershell
& $PythonExe tools/animation-pipeline/test_compare_cli.py 2>&1 |
    Tee-Object -FilePath "$Proof\compare-cli-guards.log"
if ($LASTEXITCODE -ne 0) { throw 'Protections CLI échouées.' }
if (-not (Test-Path -LiteralPath $Candidate -PathType Leaf)) { throw 'Candidat GLB absent.' }
& $PythonExe tools/animation-pipeline/inventory.py "$Proof\source.glb" --output "$Proof\source-inventory.json"
if ($LASTEXITCODE -ne 0) { throw 'Inventaire source échoué.' }
& $PythonExe tools/animation-pipeline/inventory.py $Candidate --output "$Proof\candidate-inventory.json"
if ($LASTEXITCODE -ne 0) { throw 'Inventaire candidat échoué.' }
& $PythonExe tools/animation-pipeline/compare_poses.py "$Proof\source.glb" $Candidate --godot $GodotExe --out "$Proof\poses.json" --samples 21 --position-units 0.0001 --rotation-rad 0.001 --scale 0.0001 --self-test 2>&1 |
    Tee-Object -FilePath "$Proof\poses.log"
if ($LASTEXITCODE -ne 0) { throw 'Comparaison des poses échouée : lire poses.json et poses.log.' }
Get-FileHash -Algorithm SHA256 -LiteralPath $Candidate |
    Format-List | Out-File -LiteralPath "$Proof\candidate.sha256.txt" -Encoding UTF8
if ((Get-FileHash -Algorithm SHA256 -LiteralPath $Source).Hash -ne $SourceHashBefore) {
    throw 'Le GLB source a changé pendant la recette.'
}
```

Pour une réception complète, vérifier `candidate.passed=true`, `candidate.complete_clip_coverage=true`, `identity.passed=true`, `negative_control.passed=false`, `self_test_passed=true`, `inputs_unchanged=true` et des nombres de clips, bones, poses et comparaisons positifs. L’inventaire et `candidate.available_clips` doivent couvrir les onze clips attendus du modèle courant, avec `candidate.per_clip` pour chacun ; ne pas remplacer une valeur mesurée par ce compte historique. L’inventaire fournit des comptes, noms, durées et empreintes ; il ne décode pas toutes les valeurs de géométrie/poids et ne certifie pas leur égalité à lui seul. Aucun résultat absent, crash ou test ignoré ne vaut réussite. Vérifier également que source et candidat n’ont pas été inversés et que la commande ne compare pas deux fois le même chemin. Un hash source=candidat est acceptable uniquement pour le **contrôle témoin identité**, pas comme preuve d’un vrai réexport Blender.

## 3. Tests existants du lecteur et du match

Les tests suivants utilisent le vrai projet. Le lecteur vérifie le modèle stagé et la cohérence des empreintes MD5 de son cache d’import avec le fichier chargé ; ces vérifications de cache ne remplacent pas la provenance SHA-256 du candidat. Node 22 est conseillé pour reproduire les reçus ; enregistrer la version réellement sélectionnée. Le staging existant copie les assets contrôlés et vérifie aussi les registres et les voix ; une erreur de donnée doit être conservée et diagnostiquée, pas ignorée pour poursuivre. Il ne lance pas de génération de voix. Le résultat lecteur exige un **nouveau chemin absolu terminé par .json**, ce qui est assuré par le nouveau dossier `$Proof`. Ils ne doivent pas être lancés en parallèle d’une autre opération Godot graphique sur la machine. Les suites sont exécutées successivement ; ne pas changer de fichier de sauvegarde ou importer un profil personnel.

```powershell
$NodeExe = (Get-Command node -ErrorAction Stop).Source
& $PythonExe scripts/build-godot-prototype.py --stage-only --node $NodeExe 2>&1 |
    Tee-Object -FilePath "$Proof\stage.log"
if ($LASTEXITCODE -ne 0) { throw 'Staging natif échoué.' }
& $GodotExe --headless --path native/godot --editor --import --quit 2>&1 |
    Tee-Object -FilePath "$Proof\source-import.log"
if ($LASTEXITCODE -ne 0) { throw 'Import natif échoué.' }
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

### Synthèse reproductible des contrôles demandés

Après préparation/import de la **copie candidate**, lancer le runner dans un sous-dossier de preuve nouveau. Il ne fabrique pas le candidat et ne fait aucun staging/import automatique. Le bloc demande explicitement la comparaison de tous les clips et le lecteur sur la copie candidate ; omettre une de ces options réduit le périmètre et n’est pas une validation globale.

```powershell
$CandidateStaged = Join-Path $CandidateProject 'assets/match3d/quaternius-rugby-athlete.glb'
$CandidateHashBefore = (Get-FileHash -Algorithm SHA256 -LiteralPath $Candidate).Hash
if ((Get-FileHash -Algorithm SHA256 -LiteralPath $CandidateStaged).Hash -ne $CandidateHashBefore) {
    throw 'Le lecteur ne pointe pas vers le GLB candidat comparé.'
}
$RunProof = Join-Path $Proof 'run-checks-candidate'
if (Test-Path -LiteralPath $RunProof) { throw 'Choisir un nouveau dossier run_checks.' }
& $PythonExe tools/animation-pipeline/run_checks.py --out $RunProof --source "$Proof\source.glb" --candidate $Candidate --godot $GodotExe --reader-project $CandidateProject --node $NodeExe 2>&1 |
    Tee-Object -FilePath "$Proof\run-checks-candidate.log"
if ($LASTEXITCODE -ne 0) { throw 'Runner en échec : lire summary.json et les journaux.' }
if ((Get-FileHash -Algorithm SHA256 -LiteralPath $CandidateStaged).Hash -ne $CandidateHashBefore) {
    throw 'Le GLB chargé par le lecteur a changé.'
}
if ((Get-FileHash -Algorithm SHA256 -LiteralPath $Source).Hash -ne $SourceHashBefore) {
    throw 'La référence versionnée a changé.'
}
```

Lire `summary.json`, les deux inventaires, `poses.json`, **`skin.json`**, `reader.json` et les logs. Le runner complet demande désormais **dix phases**, dont la comparaison CPU des positions skinnées, topologie et normales ; ne pas présenter les anciens reçus à huit ou neuf phases comme couvrant cette étape supplémentaire. Pour ce bloc complet, exiger `status="pass"`, `requested_checks_passed=true`, `all_checks_executed=true` et la couverture intégrale des clips dans `poses.json`. Exit 0 signifie **toutes les phases demandées reçues** ; il ne remplace pas la vérification du périmètre. Une invocation sans `--candidate` et sans `--reader-project` peut finir avec exit 0 tout en restant `partial`, ces phases apparaissant `not_run`. Exit 1 indique un échec de phase ; exit 2 un refus de préflight/arguments. Le runner compare globalement les poses des clips avec les paramètres par défaut du comparateur et exige aussi une comparaison de peau complète ; il ne remplace pas le passage plus dense à 21 échantillons et les témoins du bloc précédent. Dans `skin.json`, exiger `passed=true`, tous les clips source comparés, tous les sommets source couverts à chaque pose, aucun sommet source/candidat sans correspondance, des erreurs finies sous leurs seuils, des triangles orientés et normales de coins correspondants. Les valeurs, nombres d’échantillons, seuils et empreintes viennent du JSON réellement produit ; ne pas recopier un tableau d’une ancienne exécution. La comparaison CPU ne prouve pas l’apparence de tous les matériaux dans le renderer Windows.

### Diagnostic locomotion partiel : aucune réception globale

Le lecteur de match choisit les clips dont le nom se termine par `Man_Idle`, `Man_Walk` et `Man_Run`. Le comparateur accepte `--clip NOM_EXACT` répétable. Pour isoler ces trois mouvements, la commande suivante est un **diagnostic facultatif séparé**, à lancer après avoir conservé un éventuel verdict global rouge. Elle ne permet pas de poursuivre l’intégration du candidat refusé.

```powershell
& $PythonExe tools/animation-pipeline/compare_poses.py "$Proof\source.glb" $Candidate --godot $GodotExe --out "$Proof\poses-locomotion.json" --samples 21 --position-units 0.0001 --rotation-rad 0.001 --scale 0.0001 --clip 'HumanArmature|Man_Idle' --clip 'HumanArmature|Man_Walk' --clip 'HumanArmature|Man_Run' 2>&1 |
    Tee-Object -FilePath "$Proof\poses-locomotion.log"
if ($LASTEXITCODE -ne 0) { throw 'Diagnostic locomotion non reçu ; lire son JSON.' }
```

Les noms exacts viennent de l’inventaire : si le GLB courant les change, ne pas deviner un remplacement. Même avec exit 0, ce résultat porte `candidate.complete_clip_coverage=false` et `candidate.validation_scope="selected clips only; not global asset acceptance"`. Lire les erreurs, durées et pires localisations de `candidate.per_clip`. Les trajectoires échantillonnées des pieds sont des mesures brutes du clip, **pas une preuve de pied planté ou de faible glissement en situation de match**. Les contrôles globaux de manifeste restent exigés, mais les poses des huit autres clips ne sont pas reçues par cette sélection.

Un candidat corrigé et testé sous **Blender 4.3.2 Linux** reste un artefact de diagnostic tant que les contrôles complets et la recette graphique ne sont pas reçus. Un passage locomotion au vert sur cette version n’est ni une conservation globale des onze clips ni une preuve Blender **5.2 Windows**. Il est possible de commencer la recette graphique Windows/Godot 4.7.2 avec un candidat explicitement fabriqué en 4.3.2 et ayant passé tous les contrôles techniques ; le reçu doit conserver cette version de fabrication. Il ne devient pas un reçu 5.2. Conserver les verdicts rouges précédents et les corrections appliquées.

## Parcours B — qualifier Blender 5.2 avant toute fabrication

Ce parcours est **non reçu et ne dispose pas encore d’une commande d’export approuvée**. Le wrapper actuel refuse 5.2 volontairement : ne pas changer son test de version, son empreinte de fonction ou ses seuils pour le faire démarrer.

Pour rendre ce parcours exécutable, un lot technique distinct doit identifier la fonction d’export des poids de Blender 5.2, vérifier le comportement des petites influences et les API d’import/export, puis conserver ou remplacer proprement le correctif 4.3.2. Fixer les versions/pins et empreintes réellement revus ; exécuter les gardes positives/négatives, fabriquer dans un nouveau dossier, comparer source/candidat sur **tous les onze clips**, tous les sommets source, positions skinnées et normales de coins, puis recevoir le lecteur et les captures Windows. Un correctif devenu inutile doit être retiré par une modification testée, jamais contourné au lancement.

Jusqu’à cette revue, la version 5.2 peut être inspectée et documentée, mais aucun export 5.2 n’est annoncé compatible. Le tableau final doit distinguer « fabrication Blender 4.3.2 », « qualification 5.2 non faite » et « réception graphique Godot Windows ».

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
