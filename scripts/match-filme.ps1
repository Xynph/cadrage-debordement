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
     la fin du match, à la minute -Minutes ou après -DureeMax secondes ;
  4. écrit dans -Sortie : image-0001.png…, planche.png (planche-contact de 24 images au plus),
     report.json (minute, score, état et luminance de chaque image ; « noires » doit valoir 0),
     surveillance.json (échantillons du premier plan : « premier_plan_godot » doit valoir 0) et godot.log.

Utilisation (PowerShell, depuis n'importe quel dossier) :
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts\match-filme.ps1 -Sortie E:\temp\film -Camera tv -Cadence 2 -Minutes 10
  # Sans bloquer une console visible : Start-Process powershell -WindowStyle Hidden -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','<dépôt>\scripts\match-filme.ps1','-Sortie','E:\temp\film'

Paramètres :
  -Sortie    dossier des images (créé ; défaut : %TEMP%\match-filme-<date>)
  -Camera    tv | tactical | action (défaut tv)
  -Cadence   secondes entre deux images (défaut 2)
  -DureeMax  arrêt au plus tard après ces secondes de direct (défaut 600)
  -Minutes   arrêt à cette minute de match (défaut 0 : match entier)
  -Niveau    temps forts : aucun | resume | cles | etendus | dynamique | integral (défaut dynamique, le réglage du jeu)
  -Taille    LxH de la fenêtre et des images, 1280x720 au moins (défaut 1280x720)
  -Club, -Graine  carrière préparée (défauts 102 et 4242 : même graine, même match)
  -Export    carrière déjà préparée (tools/match-filme/preparer-carriere.cjs) : saute la préparation (~1 min)
  -GarderCarriere  copie la carrière préparée dans -Sortie (carriere.json) pour la rejouer avec -Export
  -SansPlanche     pas de planche-contact
  -Godot     exécutable Godot 4.7.2 (défaut : $env:CD_GODOT_EXE, la version fenêtre est préférée à _console)
  -Node      exécutable Node (défaut : $env:CD_NODE_EXECUTABLE, sinon node du PATH)
  -AttenteGodot  secondes d'attente si un autre Godot tourne déjà (un seul Godot à la fois ; défaut 600)

Code de sortie : 0 si des images non noires ont été produites et que le premier plan n'a jamais été pris.
#>
[CmdletBinding()]
param(
  [string]$Sortie = '',
  [ValidateSet('tv', 'tactical', 'action')][string]$Camera = 'tv',
  [ValidateRange(0.2, 600)][double]$Cadence = 2,
  [ValidateRange(10, 14400)][int]$DureeMax = 600,
  [ValidateRange(0, 120)][int]$Minutes = 0,
  [ValidateSet('aucun', 'resume', 'cles', 'etendus', 'dynamique', 'integral')][string]$Niveau = 'dynamique',
  [ValidatePattern('^\d+x\d+$')][string]$Taille = '1280x720',
  [int]$Club = 102,
  [int]$Graine = 4242,
  [string]$Export = '',
  [switch]$GarderCarriere,
  [switch]$SansPlanche,
  [string]$Godot = '',
  [string]$Node = '',
  [int]$AttenteGodot = 600
)
$ErrorActionPreference = 'Stop'
$depot = Split-Path -Parent $PSScriptRoot
$projet = Join-Path $depot 'native\godot'
$outil = Join-Path $depot 'tools\match-filme\match_filme.gd'
$preparer = Join-Path $depot 'tools\match-filme\preparer-carriere.cjs'

if (-not $Sortie) { $Sortie = Join-Path ([IO.Path]::GetTempPath()) ('match-filme-' + (Get-Date -Format 'yyyyMMdd-HHmmss')) }
$Sortie = [IO.Path]::GetFullPath($Sortie)
New-Item -ItemType Directory -Force $Sortie | Out-Null

if (-not $Godot) { $Godot = $env:CD_GODOT_EXE }
if (-not $Godot) { $Godot = $env:CD_GODOT_EXECUTABLE }
if (-not $Godot -or -not (Test-Path $Godot)) { throw 'Godot 4.7.2 introuvable : passer -Godot ou définir CD_GODOT_EXE.' }
# La version fenêtre de Godot est lancée directement (la version _console n'est qu'un relais).
$fenetre = $Godot -replace '_console\.exe$', '.exe'
if (Test-Path $fenetre) { $Godot = $fenetre }
if (-not $Node) { $Node = $env:CD_NODE_EXECUTABLE }
if (-not $Node) { $Node = (Get-Command node -ErrorAction SilentlyContinue).Source }
if (-not $Node -or -not (Test-Path $Node)) { throw 'Node introuvable : passer -Node ou définir CD_NODE_EXECUTABLE.' }

Add-Type -TypeDefinition @'
using System; using System.Runtime.InteropServices; using System.Text; using System.Collections.Generic;
public static class MatchFilmeBureau {
  [DllImport("user32.dll", SetLastError=true, CharSet=CharSet.Unicode)] static extern IntPtr CreateDesktopW(string name, IntPtr dev, IntPtr mode, int flags, uint access, IntPtr sa);
  [DllImport("user32.dll")] public static extern bool CloseDesktop(IntPtr h);
  [DllImport("user32.dll")] static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
  delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc f, IntPtr l);
  [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)] struct SI { public int cb; public string reserved; public string desktop; public string title; public int x, y, w, h, cx, cy, fill, flags; public short show, r2; public IntPtr r3, i, o, e; }
  [StructLayout(LayoutKind.Sequential)] struct PI { public IntPtr process, thread; public int pid, tid; }
  [DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Unicode)] static extern bool CreateProcessW(string app, StringBuilder cmd, IntPtr pa, IntPtr ta, bool inherit, uint flags, IntPtr env, string dir, ref SI si, out PI pi);
  [DllImport("kernel32.dll")] public static extern bool CloseHandle(IntPtr h);
  [DllImport("kernel32.dll")] public static extern uint WaitForSingleObject(IntPtr h, uint ms);
  [DllImport("kernel32.dll")] static extern bool GetExitCodeProcess(IntPtr h, out uint code);
  public static IntPtr Creer(string name) {
    IntPtr h = CreateDesktopW(name, IntPtr.Zero, IntPtr.Zero, 0, 0x10000000, IntPtr.Zero);
    if (h == IntPtr.Zero) throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
    return h;
  }
  // Processus créé sur le bureau désigné, sans console. Renvoie {handle, pid}.
  public static long[] Lancer(string desktop, string exe, string cmd, string dir) {
    var si = new SI(); si.cb = Marshal.SizeOf(typeof(SI)); si.desktop = desktop; si.flags = 1; si.show = 0; PI pi;
    if (!CreateProcessW(exe, new StringBuilder(cmd), IntPtr.Zero, IntPtr.Zero, false, 0x08000000, IntPtr.Zero, dir, ref si, out pi)) throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
    CloseHandle(pi.thread);
    return new long[] { pi.process.ToInt64(), pi.pid };
  }
  public static int Code(IntPtr h) { uint c; GetExitCodeProcess(h, out c); return unchecked((int)c); }
  public static uint PremierPlan() { uint p; GetWindowThreadProcessId(GetForegroundWindow(), out p); return p; }
  // Fenêtres visibles de ces processus sur le bureau de l'utilisateur (celui de ce script).
  public static int Visibles(HashSet<uint> pids) {
    int n = 0;
    EnumWindows((h, l) => { uint p; GetWindowThreadProcessId(h, out p); if (pids.Contains(p) && IsWindowVisible(h)) n++; return true; }, IntPtr.Zero);
    return n;
  }
}
'@

function Enfants([int]$racine) {
  $tous = @(Get-CimInstance Win32_Process -Property ProcessId, ParentProcessId)
  $ids = New-Object 'System.Collections.Generic.HashSet[uint32]'
  [void]$ids.Add([uint32]$racine)
  do {
    $avant = $ids.Count
    foreach ($p in $tous) { if ($ids.Contains([uint32]$p.ParentProcessId)) { [void]$ids.Add([uint32]$p.ProcessId) } }
  } while ($ids.Count -ne $avant)
  return , $ids
}


$travail = Join-Path ([IO.Path]::GetTempPath()) ('match-filme-profil-' + [guid]::NewGuid().ToString('N').Substring(0, 12))
$donnees = Join-Path $travail 'PrototypeGodot'
New-Item -ItemType Directory -Force $donnees | Out-Null
$bureau = [IntPtr]::Zero
$processus = [IntPtr]::Zero
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

  # Un seul Godot à la fois : attendre que l'autre se termine.
  $attente = [Diagnostics.Stopwatch]::StartNew()
  while (Get-Process | Where-Object { $_.ProcessName -like 'Godot*' }) {
    if ($attente.Elapsed.TotalSeconds -ge $AttenteGodot) { throw "Un autre Godot tourne encore après $AttenteGodot s : rien n'a été lancé." }
    Start-Sleep -Seconds 5
  }

  $env:CD_GODOT_DATA_DIR = $donnees
  $env:CD_NODE_EXECUTABLE = $Node
  $env:CD_GODOT_SELF_TEST = $null
  $env:CD_GODOT_IMMERSIVE_SELF_TEST = $null
  $q = { param($v) '"' + $v + '"' }
  $arguments = @('--path', (& $q $projet), '--rendering-driver', 'opengl3', '--audio-driver', 'Dummy', '--windowed', '--resolution', $Taille,
    '--log-file', (& $q (Join-Path $Sortie 'godot.log')), '--script', (& $q $outil), '--',
    '--match-filme', '--sortie', (& $q $Sortie), '--export', (& $q $Export), '--camera', $Camera,
    '--cadence', $Cadence.ToString([Globalization.CultureInfo]::InvariantCulture), '--duree-max', $DureeMax, '--minutes', $Minutes, '--niveau', $Niveau, '--taille', $Taille)
  if ($SansPlanche) { $arguments += '--sans-planche' }
  $ligne = (& $q $Godot) + ' ' + ($arguments -join ' ')

  $nomBureau = 'MatchFilme' + $PID
  $bureau = [MatchFilmeBureau]::Creer($nomBureau)
  $premierPlanAvant = [MatchFilmeBureau]::PremierPlan()
  $lance = [MatchFilmeBureau]::Lancer("WinSta0\$nomBureau", $Godot, $ligne, $Sortie)
  $processus = [IntPtr]$lance[0]; $godotPid = [int]$lance[1]
  Write-Host "Godot lancé sur un bureau séparé (pid $godotPid) : images dans $Sortie"

  $echantillons = 0; $volS = 0; $visibles = 0
  $pids = Enfants $godotPid
  $chrono = [Diagnostics.Stopwatch]::StartNew()
  $limite = ($DureeMax + 900) * 1000
  while ([MatchFilmeBureau]::WaitForSingleObject($processus, 100) -ne 0) {
    $echantillons++
    if ($echantillons % 20 -eq 0) { $pids = Enfants $godotPid }
    if ($pids.Contains([MatchFilmeBureau]::PremierPlan())) { $volS++ }
    $visibles = [Math]::Max($visibles, [MatchFilmeBureau]::Visibles($pids))
    if ($chrono.ElapsedMilliseconds -gt $limite) {
      Write-Warning 'Délai dépassé : arrêt de Godot.'
      & taskkill.exe /T /F /PID $godotPid | Out-Null
      break
    }
  }
  [void][MatchFilmeBureau]::WaitForSingleObject($processus, 10000)
  $code = [MatchFilmeBureau]::Code($processus)
  $surveillance = [ordered]@{
    bureau = $nomBureau; pid = $godotPid; code_sortie = $code; secondes = [Math]::Round($chrono.Elapsed.TotalSeconds, 1)
    echantillons_premier_plan = $echantillons; premier_plan_godot = $volS; fenetres_visibles_sur_le_bureau_utilisateur = $visibles
    premier_plan_avant_pid = $premierPlanAvant; premier_plan_apres_pid = [MatchFilmeBureau]::PremierPlan(); audio = 'Dummy'
  }
  $surveillance | ConvertTo-Json | Set-Content -Encoding utf8 (Join-Path $Sortie 'surveillance.json')

  $rapport = Join-Path $Sortie 'report.json'
  $images = 0; $noires = 0
  if (Test-Path $rapport) {
    $r = Get-Content -Raw -Encoding utf8 $rapport | ConvertFrom-Json
    $images = @($r.images).Count; $noires = [int]$r.noires
    Write-Host ("Match filmé : {0} images ({1} noires), minute {2}, score {3}, {4} s ; premier plan pris : {5} fois ; fenêtres visibles : {6}." -f $images, $noires, $r.minute, ($r.score -join ' – '), $r.duree_s, $volS, $visibles)
  } else {
    Write-Warning "Aucun rapport : voir $(Join-Path $Sortie 'godot.log')"
  }
  Write-Host "Dossier : $Sortie"
  if ($code -ne 0 -or $images -eq 0 -or $noires -ge $images -or $volS -gt 0 -or $visibles -gt 0) { exit 1 }
  exit 0
} finally {
  if ($processus -ne [IntPtr]::Zero) { [void][MatchFilmeBureau]::CloseHandle($processus) }
  if ($bureau -ne [IntPtr]::Zero) { [void][MatchFilmeBureau]::CloseDesktop($bureau) }
  foreach ($nom in $anciens.Keys) { Set-Item -Path "env:$nom" -Value $anciens[$nom] -ErrorAction SilentlyContinue; if ($null -eq $anciens[$nom]) { Remove-Item "env:$nom" -ErrorAction SilentlyContinue } }
  Remove-Item -Recurse -Force $travail -ErrorAction SilentlyContinue
}
