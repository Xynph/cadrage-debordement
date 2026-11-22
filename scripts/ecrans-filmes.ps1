<#
Tour des écrans filmé : capturer tous les écrans de gestion du vrai jeu sans déranger la personne qui utilise le PC.

Même lanceur que le match filmé (scripts/bureau-cache.ps1) :
  1. prépare une carrière Monde de test (profil jetable : une rencontre jouée, arrêtée le jour du match suivant ;
     tools/ecrans-filmes/preparer-carriere.cjs, environ une minute) — ou reprend une carrière exportée (-Export) ;
  2. lance le vrai jeu Godot sur un BUREAU WINDOWS SÉPARÉ, dans un job Windows surveillé (une fenêtre ou le
     premier plan pris sur le bureau de l'utilisateur arrête Godot sur-le-champ), pilote audio muet ;
  3. tools/ecrans-filmes/visite.gd ouvre chaque écran (liste de tests/small-window-geometry.gd, puis fiche joueur,
     fiche d'un club adverse, calendrier en semaine, options, et pour finir le direct et la fenêtre Équipe), ferme
     les bulles de Gabi, attend une image stable et l'enregistre à chaque taille ;
  4. écrit dans -Sortie : <ecran>-<largeur>.png, planche-<largeur>.png, report.json (statut de chaque écran :
     ok, redirige, indisponible, echec, non_visite ; débordements : contrôles hors de l'écran, textes probablement
     tronqués), surveillance.json (« premier_plan_godot » et « fenetres_visibles_sur_le_bureau_utilisateur »
     doivent valoir 0) et godot.log.

Utilisation (PowerShell, depuis n'importe quel dossier) :
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts\ecrans-filmes.ps1 -Sortie E:\temp\ecrans
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts\ecrans-filmes.ps1 -Sortie E:\temp\ecrans -Tailles 1280x720 -Ecrans "bureau,effectif,fiche-joueur,equipe" -Export E:\Cadrage-Debordement\temp\carriere-ressenti.json

Paramètres :
  -Sortie    dossier des images (créé ; défaut : %TEMP%\ecrans-filmes-<date>)
  -Tailles   tailles LxH séparées par des virgules, 1280x720 au moins (défaut 1920x1080,1280x720)
  -Ecrans    écrans à filmer, séparés par des virgules (nom de fichier ou nom de l'écran, accents indifférents ;
             alias : transferts, classement, equipe, joueur, options) ; défaut : tous
  -Export    carrière exportée à reprendre (lue seulement, importée dans le profil jetable) : saute la préparation
  -DureeMax  arrêt des captures après ces secondes (défaut 900) ; les écrans restants sont « non_visite »
  -SansDirect      ne donne pas le coup d'envoi (pas de direct ni de fenêtre Équipe)
  -SansPlanche     pas de planche par taille
  -Club, -Graine, -Matchs  carrière préparée (défauts 102, 4242, 1 rencontre jouée)
  -GarderCarriere  copie la carrière préparée dans -Sortie (carriere.json) pour la rejouer avec -Export
  -AttenteGodot  attente maximale d'une des 8 places Godot partagées (défaut 3600 s ; aucune si le script tourne déjà sous godot-slot.ps1)
  -Profil    dossier parent des profils jetables (défaut : E:\Cadrage-Debordement\temp\profils\captures-<nom du dossier du dépôt>)
  -Godot, -Node  comme scripts/match-filme.ps1

Code de sortie : 0 si au moins un écran est filmé, aucun en échec, et ni fenêtre ni premier plan pris.
#>
[CmdletBinding()]
param(
  [string]$Sortie = '',
  [ValidatePattern('^\s*\d+x\d+(\s*,\s*\d+x\d+)*\s*$')][string]$Tailles = '1920x1080,1280x720',
  [string[]]$Ecrans = @(),
  [string]$Export = '',
  [ValidateRange(30, 14400)][int]$DureeMax = 900,
  [switch]$SansDirect,
  [switch]$SansPlanche,
  [int]$Club = 102,
  [int]$Graine = 4242,
  [ValidateRange(0, 30)][int]$Matchs = 1,
  [switch]$GarderCarriere,
  [string]$Godot = '',
  [string]$Node = '',
  [int]$AttenteGodot = 3600,
  [string]$Profil = ''
)
$ErrorActionPreference = 'Stop'
$depot = Split-Path -Parent $PSScriptRoot
$projet = Join-Path $depot 'native\godot'
$outil = Join-Path $depot 'tools\ecrans-filmes\visite.gd'
$preparer = Join-Path $depot 'tools\ecrans-filmes\preparer-carriere.cjs'
. (Join-Path $PSScriptRoot 'bureau-cache.ps1')

if (-not $Sortie) { $Sortie = Join-Path ([IO.Path]::GetTempPath()) ('ecrans-filmes-' + (Get-Date -Format 'yyyyMMdd-HHmmss')) }
$Sortie = [IO.Path]::GetFullPath($Sortie)
New-Item -ItemType Directory -Force $Sortie | Out-Null
$Tailles = ($Tailles -split ',' | ForEach-Object { $_.Trim().ToLowerInvariant() } | Where-Object { $_ }) -join ','
# -Ecrans "a,b" ou -Ecrans a,b : une seule liste séparée par des virgules pour Godot.
$listeEcrans = (@($Ecrans) -join ',' -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }) -join ','
$premiere = ($Tailles -split ',')[0]

$outils = Resolve-OutilsBureauCache -Godot $Godot -Node $Node
$Godot = $outils.Godot; $Node = $outils.Node

# Profil jetable isolé par chantier (nom du dossier du dépôt/worktree) : jamais la sauvegarde de l'utilisateur,
# jamais le profil d'un autre chantier. -Profil impose un autre dossier parent.
if (-not $Profil) { $Profil = if (Test-Path 'E:\Cadrage-Debordement\temp\profils') { Join-Path 'E:\Cadrage-Debordement\temp\profils' ('captures-' + (Split-Path -Leaf $depot)) } else { [IO.Path]::GetTempPath() } }
$travail = Join-Path $Profil ('ecrans-filmes-profil-' + [guid]::NewGuid().ToString('N').Substring(0, 12))
$donnees = Join-Path $travail 'PrototypeGodot'
New-Item -ItemType Directory -Force $donnees | Out-Null
$place = $null
$anciens = @{ CD_GODOT_DATA_DIR = $env:CD_GODOT_DATA_DIR; CD_NODE_EXECUTABLE = $env:CD_NODE_EXECUTABLE; CD_GODOT_SELF_TEST = $env:CD_GODOT_SELF_TEST; CD_GODOT_IMMERSIVE_SELF_TEST = $env:CD_GODOT_IMMERSIVE_SELF_TEST }
try {
  if ($Export) {
    $Export = [IO.Path]::GetFullPath($Export)
    if (-not (Test-Path $Export)) { throw "Carrière introuvable : $Export" }
  } else {
    $Export = Join-Path $travail 'carriere.json'
    Write-Host 'Préparation de la carrière Monde de test (environ une minute)…'
    & $Node $preparer $Export --club $Club --graine $Graine --matchs $Matchs
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $Export)) { throw 'Préparation de la carrière impossible.' }
  }
  if ($GarderCarriere) { Copy-Item $Export (Join-Path $Sortie 'carriere.json') -Force }

  # Une des 8 places Godot partagées (verrou commun à tous les chantiers) : plusieurs captures peuvent tourner en parallèle.
  $place = Enter-PlaceGodot -Libelle ('ecrans-filmes ' + (Split-Path -Leaf $depot)) -AttenteGodot $AttenteGodot

  $env:CD_GODOT_DATA_DIR = $donnees
  $env:CD_NODE_EXECUTABLE = $Node
  $env:CD_GODOT_SELF_TEST = $null
  $env:CD_GODOT_IMMERSIVE_SELF_TEST = $null
  $q = { param($v) ConvertTo-ArgumentCite $v }
  $arguments = @('--path', (& $q $projet), '--rendering-driver', 'opengl3', '--audio-driver', 'Dummy', '--windowed', '--resolution', $premiere,
    '--log-file', (& $q (Join-Path $Sortie 'godot.log')), '--script', (& $q $outil), '--',
    '--ecrans-filmes', '--sortie', (& $q $Sortie), '--export', (& $q $Export), '--tailles', $Tailles, '--duree-max', $DureeMax)
  if ($listeEcrans) { $arguments += @('--ecrans', (& $q $listeEcrans)) }
  if ($SansPlanche) { $arguments += '--sans-planche' }
  if ($SansDirect) { $arguments += '--sans-direct' }

  # Démarrage, import et coup d'envoi en plus de -DureeMax (les captures s'arrêtent seules à -DureeMax).
  $bilan = Invoke-GodotSurBureauCache -Godot $Godot -Arguments $arguments -Sortie $Sortie -Prefixe 'EcransFilmes' -LimiteSecondes ($DureeMax + 600)
  $code = $bilan.code_sortie; $volS = $bilan.premier_plan_godot; $visibles = $bilan.fenetres_visibles_sur_le_bureau_utilisateur; $arret = $bilan.arret_force

  $rapport = Join-Path $Sortie 'report.json'
  $reussis = 0; $echecs = 0
  if (Test-Path $rapport) {
    $r = Get-Content -Raw -Encoding utf8 $rapport | ConvertFrom-Json
    $reussis = [int]$r.reussis; $echecs = [int]$r.echecs
    Write-Host ("Tour des écrans : {0} captures, {1} en échec, {2} redirigées, {3} non visitées ; {4} débordements, {5} textes tronqués ; {6} s ; premier plan pris : {7} fois ; fenêtres visibles : {8}." -f $reussis, $echecs, $r.redirections, $r.non_visites, $r.debordements, $r.textes_tronques, $r.duree_s, $volS, $visibles)
    foreach ($e in @($r.ecrans_en_echec)) { if ($e) { Write-Warning "Écran en échec : $e" } }
  } else {
    Write-Warning "Aucun rapport : voir $(Join-Path $Sortie 'godot.log')"
  }
  Write-Host "Dossier : $Sortie"
  if ($code -ne 0 -or $reussis -eq 0 -or $echecs -gt 0 -or $volS -gt 0 -or $visibles -gt 0 -or $arret) { exit 1 }
  exit 0
} finally {
  Exit-PlaceGodot $place
  foreach ($nom in $anciens.Keys) { Set-Item -Path "env:$nom" -Value $anciens[$nom] -ErrorAction SilentlyContinue; if ($null -eq $anciens[$nom]) { Remove-Item "env:$nom" -ErrorAction SilentlyContinue } }
  Remove-Item -Recurse -Force $travail -ErrorAction SilentlyContinue
}
