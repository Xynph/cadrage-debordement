# Planches A/B des survols : lance planches.gd une fois par variante (à lancer sous E:\Cadrage-Debordement\temp\godot-slot.ps1,
# qui fournit le bureau caché, le son coupé et CD_GODOT_EXECUTABLE). Profil jetable sous temp\profils\planches-survols.
param([string]$Export = 'E:\Cadrage-Debordement\temp\options-visuel\survols-commun\carriere-j2.json',
      [string]$Racine = 'E:\Cadrage-Debordement\temp\options-visuel',
      [string[]]$Variantes = @('ECUSSON_A','ECUSSON_B','COURBE_A','COURBE_B','REBOURS_A','REBOURS_B'))
$depot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$projet = Join-Path $depot 'native\godot'
$outil = Join-Path $PSScriptRoot 'planches.gd'
$dossiers = @{ ECUSSON = 'survol-ecusson'; COURBE = 'mini-courbe'; REBOURS = 'compte-a-rebours' }
$code = 0
foreach ($v in ($Variantes -join "," -split ",")) {
  $idee = $v.Split('_')[0]
  $sortie = Join-Path $Racine $dossiers[$idee]
  New-Item -ItemType Directory -Force $sortie | Out-Null
  $env:CD_VARIANTE_VISUELLE = $v
  $env:CD_PLANCHE_SORTIE = $sortie
  $env:CD_PLANCHE_EXPORT = $Export
  $env:CD_GODOT_DATA_DIR = "E:\Cadrage-Debordement\temp\profils\planches-survols\$v"
  Remove-Item -Recurse -Force $env:CD_GODOT_DATA_DIR -ErrorAction SilentlyContinue
  $env:CD_GODOT_SELF_TEST = $null
  $env:CD_GODOT_IMMERSIVE_SELF_TEST = $null
  & $env:CD_GODOT_EXECUTABLE --path $projet --rendering-driver opengl3 --audio-driver Dummy --windowed --resolution 2560x1440 --log-file (Join-Path $sortie "godot-$v.log") --script $outil 2>&1 | Select-String 'PLANCHE|SCRIPT ERROR|ERROR:' | ForEach-Object { $_.Line }
  "VARIANTE $v CODE $LASTEXITCODE"
  if ($LASTEXITCODE -ne 0) { $code = 1 }
}
exit $code
