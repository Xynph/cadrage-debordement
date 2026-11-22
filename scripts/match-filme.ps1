<#
Match filmé : regarder un match 3D du vrai jeu sans déranger la personne qui utilise le PC.

Ce que fait le script :
  1. prépare une carrière Monde de test arrêtée au coup d'envoi (profil jetable, dossier temporaire ;
     aucune vraie carrière n'est lue ni écrite) — ou reprend une carrière déjà préparée (-Export) ;
  2. lance le vrai jeu Godot sur un BUREAU WINDOWS SÉPARÉ (CreateDesktop) : aucune fenêtre sur
     l'écran, aucune entrée dans la barre des tâches, le premier plan n'est jamais pris, et le rendu
     OpenGL produit quand même de vraies images ; pilote audio muet (--audio-driver Dummy) en plus
     du son coupé dans le jeu ;
  3. passe les causeries, enregistre une image PNG toutes les -Cadence secondes, puis quitte seul à
     la fin du match, à la minute -Minutes ou après -DureeMax secondes ; ces durées sont du temps de
     jeu : par défaut Godot tourne à pas fixe (--fixed-fps 30 --disable-vsync), chaque image avance
     de 1/30 s de jeu et le film se calcule aussi vite que le PC le permet (mêmes images qu'en temps
     réel) ; -TempsReel revient à l'ancien comportement (30 images/s à l'horloge murale) ;
  4. écrit dans -Sortie : image-0001.png…, planche.png (planche-contact de 24 images au plus),
     report.json (minute, score, état et luminance de chaque image ; « noires » doit valoir 0),
     surveillance.json (relevé toutes les 100 ms : « premier_plan_godot » et
     « fenetres_visibles_sur_le_bureau_utilisateur » doivent valoir 0 ; détail de chaque fenêtre de notre
     arbre de processus et des fenêtres d'autres programmes apparues) et godot.log.
     Notre arbre = un job Windows (appartenance exacte) ; une fenêtre ou le premier plan pris par lui sur le
     bureau de l'utilisateur arrête Godot sur-le-champ (« arret_force »). Aucune boîte d'erreur Windows.

Utilisation (PowerShell, depuis n'importe quel dossier) :
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts\match-filme.ps1 -Sortie E:\temp\film -Camera tv -Cadence 2 -Minutes 10
  # Sans bloquer une console visible : Start-Process powershell -WindowStyle Hidden -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','<dépôt>\scripts\match-filme.ps1','-Sortie','E:\temp\film'

Paramètres :
  -Sortie    dossier des images (créé ; défaut : %TEMP%\match-filme-<date>)
  -Camera    tv | tactical | action (défaut tv)
  -Cadence   secondes entre deux images (défaut 2)
  -CadenceMoments  secondes entre deux images pendant un grand moment : essai, sortie des joueurs à
             la mi-temps et en fin de match (défaut 0,5 ; report.json les liste dans « moments »)
  -DureeMax  arrêt au plus tard après ces secondes de direct, en temps de jeu (défaut 600)
  -TempsReel Godot suit l'horloge murale (sans --fixed-fps 30 --disable-vsync) : film en temps réel
  -Attente   reelle | figee | libre (défaut reelle) : pendant que le moteur calcule une réponse, le
             temps de jeu avance de la durée réelle de ce calcul, comme en jeu (reelle), pas du tout
             (figee) ou d'un pas entier par image, donc plus vite qu'en jeu (libre)
  -Minutes   arrêt à cette minute de match (défaut 0 : match entier)
  -Niveau    temps forts : aucun | resume | cles | etendus | dynamique | integral (défaut dynamique, le réglage du jeu)
  -Taille    LxH de la fenêtre et des images, 1280x720 au moins (défaut 1280x720)
  -Club, -Graine  carrière préparée (défauts 102 et 4242 : même graine, même match)
  -Export    carrière déjà préparée (tools/match-filme/preparer-carriere.cjs) : saute la préparation (~1 min)
  -GarderCarriere  copie la carrière préparée dans -Sortie (carriere.json) pour la rejouer avec -Export
  -SansPlanche     pas de planche-contact
  -Godot     exécutable Godot 4.7.2 (défaut : $env:CD_GODOT_EXE, la version fenêtre est préférée à _console)
  -Node      exécutable Node (défaut : $env:CD_NODE_EXECUTABLE, sinon node du PATH)
  -AttenteGodot  secondes d'attente d'une des 8 places Godot partagées (verrou commun, défaut 600)

Code de sortie : 0 si des images non noires ont été produites et que le premier plan n'a jamais été pris.
#>
[CmdletBinding()]
param(
  [string]$Sortie = '',
  [ValidateSet('tv', 'tactical', 'action')][string]$Camera = 'tv',
  [ValidateRange(0.2, 600)][double]$Cadence = 2,
  [ValidateRange(0.2, 600)][double]$CadenceMoments = 0.5,
  [ValidateRange(10, 14400)][int]$DureeMax = 600,
  [ValidateRange(0, 120)][int]$Minutes = 0,
  [ValidateSet('aucun', 'resume', 'cles', 'etendus', 'dynamique', 'integral')][string]$Niveau = 'dynamique',
  [ValidatePattern('^\d+x\d+$')][string]$Taille = '1280x720',
  [int]$Club = 102,
  [int]$Graine = 4242,
  [string]$Export = '',
  [switch]$GarderCarriere,
  [switch]$SansPlanche,
  [switch]$TempsReel,
  [ValidateSet('reelle', 'figee', 'libre')][string]$Attente = 'reelle',
  [string]$Godot = '',
  [string]$Node = '',
  [int]$AttenteGodot = 600
)
$ErrorActionPreference = 'Stop'
$depot = Split-Path -Parent $PSScriptRoot
$projet = Join-Path $depot 'native\godot'
$outil = Join-Path $depot 'tools\match-filme\match_filme.gd'
$preparer = Join-Path $depot 'tools\match-filme\preparer-carriere.cjs'
# Lanceur commun (bureau séparé, job Windows, surveillance) : partagé avec scripts/ecrans-filmes.ps1.
. (Join-Path $PSScriptRoot 'bureau-cache.ps1')

if (-not $Sortie) { $Sortie = Join-Path ([IO.Path]::GetTempPath()) ('match-filme-' + (Get-Date -Format 'yyyyMMdd-HHmmss')) }
$Sortie = [IO.Path]::GetFullPath($Sortie)
New-Item -ItemType Directory -Force $Sortie | Out-Null

$outils = Resolve-OutilsBureauCache -Godot $Godot -Node $Node
$Godot = $outils.Godot; $Node = $outils.Node

$travail = Join-Path ([IO.Path]::GetTempPath()) ('match-filme-profil-' + [guid]::NewGuid().ToString('N').Substring(0, 12))
$donnees = Join-Path $travail 'PrototypeGodot'
New-Item -ItemType Directory -Force $donnees | Out-Null
$anciens = @{ CD_GODOT_DATA_DIR = $env:CD_GODOT_DATA_DIR; CD_NODE_EXECUTABLE = $env:CD_NODE_EXECUTABLE; CD_GODOT_SELF_TEST = $env:CD_GODOT_SELF_TEST; CD_GODOT_IMMERSIVE_SELF_TEST = $env:CD_GODOT_IMMERSIVE_SELF_TEST }
try {
  if ($Export) {
    $Export = [IO.Path]::GetFullPath($Export)
    if (-not (Test-Path $Export)) { throw "Carrière introuvable : $Export" }
  } else {
    $Export = Join-Path $travail 'carriere.json'
    Write-Host 'Préparation de la carrière Monde de test (environ une minute)…'
    & $Node $preparer $Export --club $Club --graine $Graine
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $Export)) { throw 'Préparation de la carrière impossible.' }
  }
  if ($GarderCarriere) { Copy-Item $Export (Join-Path $Sortie 'carriere.json') -Force }

  # Une des 8 places Godot partagées (verrou commun à tous les chantiers).
  $place = Enter-PlaceGodot -Libelle 'match-filme' -AttenteGodot $AttenteGodot

  $env:CD_GODOT_DATA_DIR = $donnees
  $env:CD_NODE_EXECUTABLE = $Node
  $env:CD_GODOT_SELF_TEST = $null
  $env:CD_GODOT_IMMERSIVE_SELF_TEST = $null
  $q = { param($v) ConvertTo-ArgumentCite $v }
  # Pas fixe (défaut) : chaque image vaut 1/30 s de jeu, le film se calcule au plus vite.
  $pasFixe = if ($TempsReel) { @() } else { @('--fixed-fps', '30', '--disable-vsync') }
  $arguments = @('--path', (& $q $projet), '--rendering-driver', 'opengl3', '--audio-driver', 'Dummy', '--windowed', '--resolution', $Taille) + $pasFixe + @(
    '--log-file', (& $q (Join-Path $Sortie 'godot.log')), '--script', (& $q $outil), '--',
    '--match-filme', '--sortie', (& $q $Sortie), '--export', (& $q $Export), '--camera', $Camera,
    '--cadence', $Cadence.ToString([Globalization.CultureInfo]::InvariantCulture),
    '--cadence-moments', $CadenceMoments.ToString([Globalization.CultureInfo]::InvariantCulture), '--duree-max', $DureeMax, '--minutes', $Minutes, '--niveau', $Niveau, '--taille', $Taille, '--attente', $Attente)
  if ($SansPlanche) { $arguments += '--sans-planche' }
  # Godot retire --fixed-fps de ses arguments visibles : l'outil reçoit le pas fixe après « -- ».
  if (-not $TempsReel) { $arguments += @('--fixed-fps', '30') }

  $bilan = Invoke-GodotSurBureauCache -Godot $Godot -Arguments $arguments -Sortie $Sortie -Prefixe 'MatchFilme' -LimiteSecondes ($DureeMax + 900)
  $code = $bilan.code_sortie; $volS = $bilan.premier_plan_godot; $visibles = $bilan.fenetres_visibles_sur_le_bureau_utilisateur; $arret = $bilan.arret_force

  $rapport = Join-Path $Sortie 'report.json'
  $images = 0; $noires = 0
  if (Test-Path $rapport) {
    $r = Get-Content -Raw -Encoding utf8 $rapport | ConvertFrom-Json
    $images = @($r.images).Count; $noires = [int]$r.noires
    Write-Host ("Match filmé : {0} images ({1} noires), minute {2}, score {3}, {4} s de jeu en {5} s réelles ; premier plan pris : {6} fois ; fenêtres visibles : {7}." -f $images, $noires, $r.minute, ($r.score -join ' – '), $r.duree_s, $r.duree_reelle_s, $volS, $visibles)
  } else {
    Write-Warning "Aucun rapport : voir $(Join-Path $Sortie 'godot.log')"
  }
  Write-Host "Dossier : $Sortie"
  if ($code -ne 0 -or $images -eq 0 -or $noires -ge $images -or $volS -gt 0 -or $visibles -gt 0 -or $arret) { exit 1 }
  exit 0
} finally {
  Exit-PlaceGodot $place
  foreach ($nom in $anciens.Keys) { Set-Item -Path "env:$nom" -Value $anciens[$nom] -ErrorAction SilentlyContinue; if ($null -eq $anciens[$nom]) { Remove-Item "env:$nom" -ErrorAction SilentlyContinue } }
  Remove-Item -Recurse -Force $travail -ErrorAction SilentlyContinue
}