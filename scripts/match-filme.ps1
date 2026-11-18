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

# Notre arbre de processus = un objet tâche Windows (job) : Godot y entre suspendu, avant sa première
# instruction, et tous ses sous-processus (node, consoles…) y entrent d'office. L'appartenance est donc
# exacte. (L'ancienne méthode suivait les ParentProcessId : un processus étranger dont le parent mort avait
# le même numéro que Godot était compté comme le nôtre — d'où une « fenêtre visible » fantôme le 18/11.)
Add-Type -TypeDefinition @'
using System; using System.Runtime.InteropServices; using System.Text; using System.Collections.Generic;
public class MatchFilmeFenetre {
  public long hwnd; public uint pid; public string processus = "?"; public string classe = ""; public string titre = "";
  public int x, y, largeur, hauteur; public bool reduite; public double vue_a_s;
}
public static class MatchFilmeBureau {
  [DllImport("user32.dll", SetLastError=true, CharSet=CharSet.Unicode)] static extern IntPtr CreateDesktopW(string name, IntPtr dev, IntPtr mode, int flags, uint access, IntPtr sa);
  [DllImport("user32.dll")] public static extern bool CloseDesktop(IntPtr h);
  [DllImport("user32.dll")] static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] static extern bool IsIconic(IntPtr h);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetClassNameW(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetWindowTextW(IntPtr h, StringBuilder s, int n);
  [StructLayout(LayoutKind.Sequential)] struct RECT { public int l, t, r, b; }
  [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr h, out RECT r);
  delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc f, IntPtr l);
  [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)] struct SI { public int cb; public string reserved; public string desktop; public string title; public int x, y, w, h, cx, cy, fill, flags; public short show, r2; public IntPtr r3, i, o, e; }
  [StructLayout(LayoutKind.Sequential)] struct PI { public IntPtr process, thread; public int pid, tid; }
  [DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Unicode)] static extern bool CreateProcessW(string app, StringBuilder cmd, IntPtr pa, IntPtr ta, bool inherit, uint flags, IntPtr env, string dir, ref SI si, out PI pi);
  [DllImport("kernel32.dll")] public static extern bool CloseHandle(IntPtr h);
  [DllImport("kernel32.dll")] public static extern uint WaitForSingleObject(IntPtr h, uint ms);
  [DllImport("kernel32.dll")] static extern bool GetExitCodeProcess(IntPtr h, out uint code);
  [DllImport("kernel32.dll")] static extern uint ResumeThread(IntPtr h);
  [DllImport("kernel32.dll")] static extern bool TerminateProcess(IntPtr h, uint code);
  [DllImport("kernel32.dll")] static extern uint SetErrorMode(uint mode);
  [DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Unicode)] static extern IntPtr CreateJobObjectW(IntPtr sa, string name);
  [DllImport("kernel32.dll", SetLastError=true)] static extern bool SetInformationJobObject(IntPtr job, int cls, IntPtr info, uint len);
  [DllImport("kernel32.dll", SetLastError=true)] static extern bool QueryInformationJobObject(IntPtr job, int cls, IntPtr info, uint len, IntPtr ret);
  [DllImport("kernel32.dll", SetLastError=true)] static extern bool AssignProcessToJobObject(IntPtr job, IntPtr process);
  [DllImport("kernel32.dll", SetLastError=true)] static extern bool TerminateJobObject(IntPtr job, uint code);
  [StructLayout(LayoutKind.Sequential)] struct BASIC { public long a, b; public uint flags; public UIntPtr minWs, maxWs; public uint active; public UIntPtr affinity; public uint prio, sched; }
  [StructLayout(LayoutKind.Sequential)] struct UI { public uint flags; }
  [StructLayout(LayoutKind.Sequential)] struct EXT { public BASIC basic; public ulong io1, io2, io3, io4, io5, io6; public UIntPtr pm, jm, ppm, pjm; }

  public static IntPtr Job = IntPtr.Zero;
  public static IntPtr Creer(string name) {
    IntPtr h = CreateDesktopW(name, IntPtr.Zero, IntPtr.Zero, 0, 0x10000000, IntPtr.Zero);
    if (h == IntPtr.Zero) throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
    return h;
  }
  static void Regler(int cls, object valeur) {
    int n = Marshal.SizeOf(valeur); IntPtr p = Marshal.AllocHGlobal(n);
    try { Marshal.StructureToPtr(valeur, p, false); if (!SetInformationJobObject(Job, cls, p, (uint)n)) throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error()); }
    finally { Marshal.FreeHGlobal(p); }
  }
  // Godot créé SUSPENDU sur le bureau désigné, sans console, mis dans le job puis relâché. Renvoie {handle, pid}.
  public static long[] Lancer(string desktop, string exe, string cmd, string dir) {
    // Aucune boîte d'erreur Windows (plantage, disque absent, fichier introuvable) : mode hérité par Godot et ses enfants.
    SetErrorMode(0x0001 | 0x0002 | 0x8000);
    Job = CreateJobObjectW(IntPtr.Zero, null);
    if (Job == IntPtr.Zero) throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
    var ext = new EXT();
    ext.basic.flags = 0x2000 | 0x0400; // KILL_ON_JOB_CLOSE | DIE_ON_UNHANDLED_EXCEPTION (pas de rapport d'erreur Windows)
    Regler(9, ext);
    // Interdit de créer ou basculer de bureau, de toucher au presse-papiers, aux réglages système et d'affichage.
    var ui = new UI(); ui.flags = 0x40 | 0x80 | 0x02 | 0x04 | 0x08 | 0x10;
    Regler(4, ui);
    var si = new SI(); si.cb = Marshal.SizeOf(typeof(SI)); si.desktop = desktop; si.flags = 1; si.show = 0; PI pi;
    // CREATE_SUSPENDED | CREATE_NO_WINDOW ; le mode d'erreur est hérité (pas de CREATE_DEFAULT_ERROR_MODE).
    if (!CreateProcessW(exe, new StringBuilder(cmd), IntPtr.Zero, IntPtr.Zero, false, 0x00000004 | 0x08000000, IntPtr.Zero, dir, ref si, out pi)) throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
    if (!AssignProcessToJobObject(Job, pi.process)) {
      int e = Marshal.GetLastWin32Error(); TerminateProcess(pi.process, 1); CloseHandle(pi.thread); CloseHandle(pi.process);
      throw new System.ComponentModel.Win32Exception(e);
    }
    ResumeThread(pi.thread);
    CloseHandle(pi.thread);
    return new long[] { pi.process.ToInt64(), pi.pid };
  }
  public static void Arreter() { if (Job != IntPtr.Zero) TerminateJobObject(Job, 0xDEAD); }
  public static void Fermer() { if (Job != IntPtr.Zero) { CloseHandle(Job); Job = IntPtr.Zero; } }
  public static int Code(IntPtr h) { uint c; GetExitCodeProcess(h, out c); return unchecked((int)c); }
  public static uint PremierPlan() { uint p; GetWindowThreadProcessId(GetForegroundWindow(), out p); return p; }
  static string Nom(uint pid) { try { return System.Diagnostics.Process.GetProcessById((int)pid).ProcessName; } catch { return "?"; } }

  // Processus actuellement dans notre job (liste exacte tenue par Windows).
  public static HashSet<uint> NosPids() {
    var s = new HashSet<uint>(); if (Job == IntPtr.Zero) return s;
    int taille = 8 + 4096 * IntPtr.Size; IntPtr p = Marshal.AllocHGlobal(taille);
    try {
      if (QueryInformationJobObject(Job, 3, p, (uint)taille, IntPtr.Zero)) {
        int n = Marshal.ReadInt32(p, 4);
        for (int i = 0; i < n; i++) s.Add((uint)Marshal.ReadIntPtr(p, 8 + i * IntPtr.Size).ToInt64());
      }
    } finally { Marshal.FreeHGlobal(p); }
    return s;
  }

  public static Dictionary<uint, string> Processus = new Dictionary<uint, string>();
  public static List<MatchFilmeFenetre> Nos = new List<MatchFilmeFenetre>();
  public static List<MatchFilmeFenetre> Etrangeres = new List<MatchFilmeFenetre>();
  public static int EtrangeresAuDepart = 0;
  static HashSet<long> vuesNos = new HashSet<long>(), vuesEtrangeres = new HashSet<long>(), depart = new HashSet<long>();
  static MatchFilmeFenetre Decrire(IntPtr h, uint pid, double t) {
    var f = new MatchFilmeFenetre(); f.hwnd = h.ToInt64(); f.pid = pid; f.processus = Nom(pid); f.vue_a_s = Math.Round(t, 1);
    var c = new StringBuilder(256); GetClassNameW(h, c, 256); f.classe = c.ToString();
    var ti = new StringBuilder(256); GetWindowTextW(h, ti, 256); f.titre = ti.ToString();
    RECT r; if (GetWindowRect(h, out r)) { f.x = r.l; f.y = r.t; f.largeur = r.r - r.l; f.hauteur = r.b - r.t; }
    f.reduite = IsIconic(h); return f;
  }
  // Fenêtres visibles au lancement sur le bureau de l'utilisateur : ne sont pas réécrites ensuite.
  public static void Depart() {
    EnumWindows((h, l) => { if (IsWindowVisible(h)) depart.Add(h.ToInt64()); return true; }, IntPtr.Zero);
    EtrangeresAuDepart = depart.Count;
  }
  // Un relevé : renvoie le nombre de fenêtres visibles de NOTRE job sur le bureau de l'utilisateur (celui
  // de ce script ; EnumWindows ne voit pas le bureau caché) et note toute fenêtre étrangère apparue.
  public static int Releve(double t, out bool premierPlanNous) {
    var nos = NosPids();
    foreach (var p in nos) if (!Processus.ContainsKey(p)) Processus[p] = Nom(p);
    premierPlanNous = nos.Contains(PremierPlan());
    int n = 0;
    EnumWindows((h, l) => {
      if (!IsWindowVisible(h)) return true;
      uint p; GetWindowThreadProcessId(h, out p); long k = h.ToInt64();
      if (nos.Contains(p)) { n++; if (vuesNos.Add(k)) Nos.Add(Decrire(h, p, t)); }
      else if (!depart.Contains(k) && Etrangeres.Count < 200 && vuesEtrangeres.Add(k)) Etrangeres.Add(Decrire(h, p, t));
      return true;
    }, IntPtr.Zero);
    return n;
  }
}
'@


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
    '--cadence', $Cadence.ToString([Globalization.CultureInfo]::InvariantCulture),
    '--cadence-moments', $CadenceMoments.ToString([Globalization.CultureInfo]::InvariantCulture), '--duree-max', $DureeMax, '--minutes', $Minutes, '--niveau', $Niveau, '--taille', $Taille)
  if ($SansPlanche) { $arguments += '--sans-planche' }
  $ligne = (& $q $Godot) + ' ' + ($arguments -join ' ')

  $nomBureau = 'MatchFilme' + $PID
  $bureau = [MatchFilmeBureau]::Creer($nomBureau)
  $premierPlanAvant = [MatchFilmeBureau]::PremierPlan()
  [MatchFilmeBureau]::Depart()
  $lance = [MatchFilmeBureau]::Lancer("WinSta0\$nomBureau", $Godot, $ligne, $Sortie)
  $processus = [IntPtr]$lance[0]; $godotPid = [int]$lance[1]
  Write-Host "Godot lancé sur un bureau séparé (pid $godotPid) : images dans $Sortie"

  # Relevé toutes les 100 ms. Une fenêtre visible ou le premier plan pris par NOTRE arbre (job) ne doit
  # jamais arriver : si c'est le cas, tout l'arbre est tué sur-le-champ.
  $echantillons = 0; $volS = 0; $visibles = 0; $arret = $null
  $chrono = [Diagnostics.Stopwatch]::StartNew()
  $limite = ($DureeMax + 900) * 1000
  while ([MatchFilmeBureau]::WaitForSingleObject($processus, 100) -ne 0) {
    $echantillons++
    $nous = $false
    $n = [MatchFilmeBureau]::Releve($chrono.Elapsed.TotalSeconds, [ref]$nous)
    if ($nous) { $volS++ }
    $visibles = [Math]::Max($visibles, $n)
    if ($n -gt 0 -or $nous) {
      [MatchFilmeBureau]::Arreter()
      $arret = if ($n -gt 0) { 'fenetre_de_notre_arbre_sur_le_bureau_utilisateur' } else { 'premier_plan_pris' }
      Write-Warning "Arrêt immédiat de Godot : $arret."
      break
    }
    if ($chrono.ElapsedMilliseconds -gt $limite) {
      Write-Warning 'Délai dépassé : arrêt de Godot.'
      [MatchFilmeBureau]::Arreter(); $arret = 'delai_depasse'
      break
    }
  }
  [void][MatchFilmeBureau]::WaitForSingleObject($processus, 10000)
  $code = [MatchFilmeBureau]::Code($processus)
  $avantPP = Get-Process -Id $premierPlanAvant -ErrorAction SilentlyContinue
  $apresPid = [MatchFilmeBureau]::PremierPlan(); $apresPP = Get-Process -Id $apresPid -ErrorAction SilentlyContinue
  $surveillance = [ordered]@{
    bureau = $nomBureau; pid = $godotPid; code_sortie = $code; secondes = [Math]::Round($chrono.Elapsed.TotalSeconds, 1); arret_force = $arret
    echantillons_premier_plan = $echantillons; premier_plan_godot = $volS
    # Fenêtres visibles de NOTRE arbre sur le bureau de l'utilisateur (maximum par relevé) : doit valoir 0.
    fenetres_visibles_sur_le_bureau_utilisateur = $visibles
    fenetres_de_notre_arbre = @([MatchFilmeBureau]::Nos)
    processus_de_notre_arbre = @([MatchFilmeBureau]::Processus.GetEnumerator() | ForEach-Object { [ordered]@{ pid = $_.Key; nom = $_.Value } })
    # Fenêtres d'AUTRES programmes apparues pendant le film (l'utilisateur, d'autres sessions) : information seulement.
    fenetres_etrangeres_au_depart = [MatchFilmeBureau]::EtrangeresAuDepart
    fenetres_etrangeres_apparues = @([MatchFilmeBureau]::Etrangeres)
    premier_plan_avant = [ordered]@{ pid = $premierPlanAvant; nom = $(if ($avantPP) { $avantPP.ProcessName } else { '?' }) }
    premier_plan_apres = [ordered]@{ pid = $apresPid; nom = $(if ($apresPP) { $apresPP.ProcessName } else { '?' }) }
    protections = 'job Windows (kill-on-close, die-on-unhandled-exception, pas de bureau ni presse-papiers), SetErrorMode sans boîte d''erreur, CREATE_NO_WINDOW, bureau séparé'
    audio = 'Dummy'
  }
  $surveillance | ConvertTo-Json -Depth 6 | Set-Content -Encoding utf8 (Join-Path $Sortie 'surveillance.json')

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
  if ($code -ne 0 -or $images -eq 0 -or $noires -ge $images -or $volS -gt 0 -or $visibles -gt 0 -or $arret) { exit 1 }
  exit 0
} finally {
  if ($processus -ne [IntPtr]::Zero) { [void][MatchFilmeBureau]::CloseHandle($processus) }
  # Fermer le job tue tout sous-processus resté en vie (KILL_ON_JOB_CLOSE).
  [MatchFilmeBureau]::Fermer()
  if ($bureau -ne [IntPtr]::Zero) { [void][MatchFilmeBureau]::CloseDesktop($bureau) }
  foreach ($nom in $anciens.Keys) { Set-Item -Path "env:$nom" -Value $anciens[$nom] -ErrorAction SilentlyContinue; if ($null -eq $anciens[$nom]) { Remove-Item "env:$nom" -ErrorAction SilentlyContinue } }
  Remove-Item -Recurse -Force $travail -ErrorAction SilentlyContinue
}
