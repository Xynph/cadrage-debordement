<#
Lanceur commun du « match filmé » (scripts/match-filme.ps1) et du « tour des écrans filmé »
(scripts/ecrans-filmes.ps1) : lance le vrai jeu Godot sur un BUREAU WINDOWS SÉPARÉ (CreateDesktop +
CreateProcess lpDesktop), dans un job Windows, et surveille le bureau de l'utilisateur toutes les 100 ms.

À charger par dot-sourcing (`. "$PSScriptRoot\bureau-cache.ps1"`), puis :
  $outils = Resolve-OutilsBureauCache -Godot $Godot -Node $Node   # exécutables Godot (version fenêtre) et Node
  $place = Enter-PlaceGodot -Libelle 'film' -AttenteGodot 3600     # une des 8 places Godot (verrou commun), puis Exit-PlaceGodot $place dans un finally
  $bilan = Invoke-GodotSurBureauCache -Godot $outils.Godot -Arguments $arguments -Sortie $Sortie -Prefixe 'MatchFilme' -LimiteSecondes 1500
  # $bilan : code_sortie, arret_force, premier_plan_godot, fenetres_visibles_sur_le_bureau_utilisateur… ; surveillance.json écrit dans -Sortie.

Notre arbre de processus = un job Windows (appartenance exacte) : Godot y entre suspendu, avant sa première
instruction, et tous ses sous-processus (node, consoles…) y entrent d'office. (L'ancienne méthode suivait les
ParentProcessId : un processus étranger dont le parent mort avait le même numéro que Godot était compté comme
le nôtre — d'où une « fenêtre visible » fantôme le 18/11.) Une fenêtre visible ou le premier plan pris par ce
job sur le bureau de l'utilisateur arrête tout l'arbre sur-le-champ (« arret_force »). Aucune boîte d'erreur Windows.
#>

Add-Type -TypeDefinition @'
using System; using System.Runtime.InteropServices; using System.Text; using System.Collections.Generic;
public class BureauCacheFenetre {
  public long hwnd; public uint pid; public string processus = "?"; public string classe = ""; public string titre = "";
  public int x, y, largeur, hauteur; public bool reduite; public double vue_a_s;
}
public static class BureauCache {
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
    // Nouveau job à chaque lancement : réinitialise aussi le relevé des fenêtres.
    Nos.Clear(); Etrangeres.Clear(); Processus.Clear(); vuesNos.Clear(); vuesEtrangeres.Clear();
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
  public static List<BureauCacheFenetre> Nos = new List<BureauCacheFenetre>();
  public static List<BureauCacheFenetre> Etrangeres = new List<BureauCacheFenetre>();
  public static int EtrangeresAuDepart = 0;
  static HashSet<long> vuesNos = new HashSet<long>(), vuesEtrangeres = new HashSet<long>(), depart = new HashSet<long>();
  static BureauCacheFenetre Decrire(IntPtr h, uint pid, double t) {
    var f = new BureauCacheFenetre(); f.hwnd = h.ToInt64(); f.pid = pid; f.processus = Nom(pid); f.vue_a_s = Math.Round(t, 1);
    var c = new StringBuilder(256); GetClassNameW(h, c, 256); f.classe = c.ToString();
    var ti = new StringBuilder(256); GetWindowTextW(h, ti, 256); f.titre = ti.ToString();
    RECT r; if (GetWindowRect(h, out r)) { f.x = r.l; f.y = r.t; f.largeur = r.r - r.l; f.hauteur = r.b - r.t; }
    f.reduite = IsIconic(h); return f;
  }
  // Fenêtres visibles au lancement sur le bureau de l'utilisateur : ne sont pas réécrites ensuite.
  public static void Depart() {
    depart.Clear();
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

## Exécutables Godot (la version fenêtre est préférée à _console, qui n'est qu'un relais) et Node.
function Resolve-OutilsBureauCache {
  param([string]$Godot = '', [string]$Node = '')
  if (-not $Godot) { $Godot = $env:CD_GODOT_EXE }
  if (-not $Godot) { $Godot = $env:CD_GODOT_EXECUTABLE }
  if (-not $Godot -or -not (Test-Path $Godot)) { throw 'Godot 4.7.2 introuvable : passer -Godot ou définir CD_GODOT_EXE.' }
  $fenetre = $Godot -replace '_console\.exe$', '.exe'
  if (Test-Path $fenetre) { $Godot = $fenetre }
  if (-not $Node) { $Node = $env:CD_NODE_EXECUTABLE }
  if (-not $Node) { $Node = (Get-Command node -ErrorAction SilentlyContinue).Source }
  if (-not $Node -or -not (Test-Path $Node)) { throw 'Node introuvable : passer -Node ou définir CD_NODE_EXECUTABLE.' }
  return @{ Godot = $Godot; Node = $Node }
}

## Une des 8 places Godot partagées par tous les chantiers (même verrou que E:\Cadrage-Debordement\temp\godot-slot.ps1 :
## fichiers godot-1..8.lock en création exclusive). Attend qu'une place se libère (exception après -AttenteGodot secondes),
## écrit « <PID> <Libelle> » dedans et renvoie son chemin ($null si le script tourne déjà sous godot-slot.ps1, qui tient
## la place : variable CD_GODOT_PLACE, rien à prendre). Une place dont le PID écrit n'existe plus est libérée d'office.
## À rendre avec Exit-PlaceGodot dans un finally.
function Enter-PlaceGodot {
  param([string]$Libelle = 'captures', [int]$AttenteGodot = 3600)
  if ($env:CD_GODOT_PLACE) { return $null }
  $dossier = if ($env:CD_GODOT_VERROUS) { $env:CD_GODOT_VERROUS } else { 'E:\Cadrage-Debordement\temp' }
  $attente = [Diagnostics.Stopwatch]::StartNew()
  while ($true) {
    foreach ($i in 1..8) {
      $p = Join-Path $dossier "godot-$i.lock"
      try {
        $flux = [IO.File]::Open($p, 'CreateNew', 'Write', 'None')
        $b = [Text.Encoding]::UTF8.GetBytes("$PID $Libelle"); $flux.Write($b, 0, $b.Length); $flux.Close()
        return $p
      } catch {
        try {
          $texte = (Get-Content -Raw -ErrorAction Stop $p)
          if ($texte -match '^\s*(\d+)\s' -and -not (Get-Process -Id ([int]$Matches[1]) -ErrorAction SilentlyContinue)) { Remove-Item $p -Force -ErrorAction SilentlyContinue }
        } catch {}
      }
    }
    if ($attente.Elapsed.TotalSeconds -ge $AttenteGodot) { throw "Aucune des 8 places Godot ne s'est libérée en $AttenteGodot s : rien n'a été lancé." }
    Start-Sleep -Seconds 5
  }
}

## Rend la place prise par Enter-PlaceGodot (sans effet si elle valait $null).
function Exit-PlaceGodot { param([string]$Place) if ($Place) { Remove-Item $Place -Force -ErrorAction SilentlyContinue } }

## Argument de ligne de commande entre guillemets (chemins avec espaces).
function ConvertTo-ArgumentCite { param([string]$Valeur) return '"' + $Valeur + '"' }

## Lance `-Godot` avec `-Arguments` (déjà cités) sur un bureau séparé nommé `<Prefixe><PID>`, dans un job,
## surveille le bureau de l'utilisateur toutes les 100 ms jusqu'à la fin du processus (ou -LimiteSecondes),
## écrit <Sortie>\surveillance.json et renvoie le bilan (dictionnaire ordonné).
function Invoke-GodotSurBureauCache {
  param(
    [Parameter(Mandatory)][string]$Godot,
    [Parameter(Mandatory)][string[]]$Arguments,
    [Parameter(Mandatory)][string]$Sortie,
    [string]$Prefixe = 'BureauCache',
    [int]$LimiteSecondes = 1500
  )
  $ligne = (ConvertTo-ArgumentCite $Godot) + ' ' + ($Arguments -join ' ')
  # Déjà sous E:\Cadrage-Debordement	emp\godot-slot.ps1 (CD_GODOT_PLACE) : on est déjà sur un bureau séparé, dans un job
  # qui interdit d'en créer un autre (« Accès refusé ») et qui surveille et tue l'arbre entier : lancer Godot directement.
  if ($env:CD_GODOT_PLACE) {
    $chrono = [Diagnostics.Stopwatch]::StartNew()
    $p = Start-Process -FilePath $Godot -ArgumentList $ligne.Substring((ConvertTo-ArgumentCite $Godot).Length + 1) -PassThru -WindowStyle Hidden
    $arret = $null
    if (-not $p.WaitForExit([int]([int64]$LimiteSecondes * 1000))) { try { $p.Kill() } catch {}; $arret = 'delai_depasse'; Write-Warning 'Délai dépassé : arrêt de Godot.' }
    $code = if ($arret) { -1 } else { $p.ExitCode }
    $surveillance = [ordered]@{
      bureau = 'bureau du verrou godot-slot.ps1'; pid = $p.Id; code_sortie = $code; secondes = [Math]::Round($chrono.Elapsed.TotalSeconds, 1); arret_force = $arret
      echantillons_premier_plan = 0; premier_plan_godot = 0; fenetres_visibles_sur_le_bureau_utilisateur = 0
      protections = 'surveillance assurée par godot-slot.ps1 (bureau séparé, job)'; audio = 'Dummy'
    }
    $surveillance | ConvertTo-Json -Depth 4 | Set-Content -Encoding utf8 (Join-Path $Sortie 'surveillance.json')
    return $surveillance
  }
  $nomBureau = $Prefixe + $PID
  $bureau = [IntPtr]::Zero
  $processus = [IntPtr]::Zero
  try {
    $bureau = [BureauCache]::Creer($nomBureau)
    $premierPlanAvant = [BureauCache]::PremierPlan()
    [BureauCache]::Depart()
    $lance = [BureauCache]::Lancer("WinSta0\$nomBureau", $Godot, $ligne, $Sortie)
    $processus = [IntPtr]$lance[0]; $godotPid = [int]$lance[1]
    Write-Host "Godot lancé sur un bureau séparé (pid $godotPid) : sorties dans $Sortie"

    # Une fenêtre visible ou le premier plan pris par NOTRE arbre (job) ne doit jamais arriver : si c'est le
    # cas, tout l'arbre est tué sur-le-champ.
    $echantillons = 0; $volS = 0; $visibles = 0; $arret = $null
    $chrono = [Diagnostics.Stopwatch]::StartNew()
    $limite = [int64]$LimiteSecondes * 1000
    while ([BureauCache]::WaitForSingleObject($processus, 100) -ne 0) {
      $echantillons++
      $nous = $false
      $n = [BureauCache]::Releve($chrono.Elapsed.TotalSeconds, [ref]$nous)
      if ($nous) { $volS++ }
      $visibles = [Math]::Max($visibles, $n)
      if ($n -gt 0 -or $nous) {
        [BureauCache]::Arreter()
        $arret = if ($n -gt 0) { 'fenetre_de_notre_arbre_sur_le_bureau_utilisateur' } else { 'premier_plan_pris' }
        Write-Warning "Arrêt immédiat de Godot : $arret."
        break
      }
      if ($chrono.ElapsedMilliseconds -gt $limite) {
        Write-Warning 'Délai dépassé : arrêt de Godot.'
        [BureauCache]::Arreter(); $arret = 'delai_depasse'
        break
      }
    }
    [void][BureauCache]::WaitForSingleObject($processus, 10000)
    $code = [BureauCache]::Code($processus)
    $avantPP = Get-Process -Id $premierPlanAvant -ErrorAction SilentlyContinue
    $apresPid = [BureauCache]::PremierPlan(); $apresPP = Get-Process -Id $apresPid -ErrorAction SilentlyContinue
    $surveillance = [ordered]@{
      bureau = $nomBureau; pid = $godotPid; code_sortie = $code; secondes = [Math]::Round($chrono.Elapsed.TotalSeconds, 1); arret_force = $arret
      echantillons_premier_plan = $echantillons; premier_plan_godot = $volS
      # Fenêtres visibles de NOTRE arbre sur le bureau de l'utilisateur (maximum par relevé) : doit valoir 0.
      fenetres_visibles_sur_le_bureau_utilisateur = $visibles
      fenetres_de_notre_arbre = @([BureauCache]::Nos)
      processus_de_notre_arbre = @([BureauCache]::Processus.GetEnumerator() | ForEach-Object { [ordered]@{ pid = $_.Key; nom = $_.Value } })
      # Fenêtres d'AUTRES programmes apparues pendant le film (l'utilisateur, d'autres sessions) : information seulement.
      fenetres_etrangeres_au_depart = [BureauCache]::EtrangeresAuDepart
      fenetres_etrangeres_apparues = @([BureauCache]::Etrangeres)
      premier_plan_avant = [ordered]@{ pid = $premierPlanAvant; nom = $(if ($avantPP) { $avantPP.ProcessName } else { '?' }) }
      premier_plan_apres = [ordered]@{ pid = $apresPid; nom = $(if ($apresPP) { $apresPP.ProcessName } else { '?' }) }
      protections = 'job Windows (kill-on-close, die-on-unhandled-exception, pas de bureau ni presse-papiers), SetErrorMode sans boîte d''erreur, CREATE_NO_WINDOW, bureau séparé'
      audio = 'Dummy'
    }
    $surveillance | ConvertTo-Json -Depth 6 | Set-Content -Encoding utf8 (Join-Path $Sortie 'surveillance.json')
    return $surveillance
  } finally {
    if ($processus -ne [IntPtr]::Zero) { [void][BureauCache]::CloseHandle($processus) }
    # Fermer le job tue tout sous-processus resté en vie (KILL_ON_JOB_CLOSE).
    [BureauCache]::Fermer()
    if ($bureau -ne [IntPtr]::Zero) { [void][BureauCache]::CloseDesktop($bureau) }
  }
}
