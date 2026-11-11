# Native Windows receipt for the exact official ZIP. Requires PowerShell 7.
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$PackageZip,
    [Parameter(Mandatory=$true)][ValidatePattern('^[0-9a-f]{40}$')][string]$SourceCommit,
    [Parameter(Mandatory=$true)][string]$EvidenceRoot,
    [Parameter(Mandatory=$true)][string]$MesaRoot
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if (-not $IsWindows) { throw 'This receipt must run on native Windows, never Wine/Linux.' }
if ($PSVersionTable.PSVersion.Major -lt 7) { throw 'PowerShell 7 is required.' }
$EvidenceRoot = [IO.Path]::GetFullPath($EvidenceRoot)
if (Test-Path -LiteralPath $EvidenceRoot) { throw 'EvidenceRoot must be new; refuse overwriting an old receipt.' }
New-Item -ItemType Directory -Path $EvidenceRoot | Out-Null
$PackageZip = (Resolve-Path -LiteralPath $PackageZip).Path
$MesaRoot = (Resolve-Path -LiteralPath $MesaRoot).Path
$Python = (Get-Command python -ErrorAction Stop).Source
$Verifier = Join-Path $PSScriptRoot 'windows-package.py'
$ResumeScript = Join-Path $PSScriptRoot 'windows-resume.gd'
$ReportPath = Join-Path $EvidenceRoot 'windows-report.json'
$Report = [ordered]@{schema='oval-windows-receipt-v1';passed=$false;proof='native-windows';platform='Windows';sourceCommit=$SourceCommit;sourceTree='';process=@{};limits=@();failure=$null}
$game = $null; $archive = $null; $extrasPath = $null; $manifestPath = $null

function Read-Json([string]$Path) { return Get-Content -LiteralPath $Path -Raw -Encoding utf8 | ConvertFrom-Json -AsHashtable }
function Write-Json($Value,[string]$Path) { $Value | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $Path -Encoding utf8NoBOM }
function Hash([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function Python-Check([string[]]$Arguments) {
    & $Python $Verifier @Arguments
    if ($LASTEXITCODE -ne 0) { throw "Windows package validator failed: $($Arguments[0])" }
}
function Game-Environment([string]$Mode,[string]$Profile,[string]$Output) {
    $privateUser = Join-Path $EvidenceRoot 'private-user'
    $temp = Join-Path $privateUser 'Temp'
    $roaming = Join-Path $privateUser 'AppData/Roaming'
    $local = Join-Path $privateUser 'AppData/Local'
    foreach ($directory in @($temp,$roaming,$local)) { New-Item -ItemType Directory -Path $directory -Force | Out-Null }
    # Deliberate whitelist: no GitHub variables, tokens, host Node or tool PATH.
    return @{
        SystemRoot=$env:SystemRoot; WINDIR=$env:SystemRoot; COMSPEC=(Join-Path $env:SystemRoot 'System32/cmd.exe');
        PATH="$(Join-Path $env:SystemRoot 'System32');$env:SystemRoot";
        TEMP=$temp; TMP=$temp; USERPROFILE=$privateUser; APPDATA=$roaming; LOCALAPPDATA=$local;
        CD_GODOT_DATA_DIR=$Profile; CD_GODOT_SELF_TEST=$(if($Mode -eq 'fresh'){'1'}else{'0'});
        CD_GODOT_QA_CAPTURES=$Output; CD_GODOT_RESUME_OUTPUT=$Output; QA_RESOLUTION='2560x1440';
        CD_GODOT_FRESH_REPORT=(Join-Path $EvidenceRoot 'fresh/report.json');
        CD_GODOT_SEED='13'; CD_GODOT_STARTUP_TRACE='1';
        GALLIUM_DRIVER='llvmpipe'
    }
}
function Run-Game([string]$Mode,[string[]]$Arguments,[string]$Profile,[string]$Output,[string]$Exe,[string]$NodeExe) {
    New-Item -ItemType Directory -Path $Output | Out-Null
    $info = [Diagnostics.ProcessStartInfo]::new()
    $info.FileName = $Exe; $info.WorkingDirectory = Split-Path $Exe
    $info.UseShellExecute = $false; $info.RedirectStandardOutput = $true; $info.RedirectStandardError = $true
    $info.Environment.Clear()
    $environment = Game-Environment $Mode $Profile $Output
    foreach ($item in $environment.GetEnumerator()) { $info.Environment[$item.Key] = [string]$item.Value }
    foreach ($argument in $Arguments) { $info.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::new(); $process.StartInfo = $info
    $node = $null; $observations = [Collections.Generic.List[object]]::new(); $shutdown = $false; $launched = $false
    $started = [DateTime]::UtcNow
    try {
        if (-not $process.Start()) { throw 'Exported EXE did not start.' }
        $launched = $true
        $stdout = $process.StandardOutput.ReadToEndAsync(); $stderr = $process.StandardError.ReadToEndAsync()
        while (-not $process.HasExited) {
            foreach ($child in @(Get-CimInstance Win32_Process -Filter "ParentProcessId = $($process.Id)")) {
                if ($child.Name -ieq 'node.exe' -and $child.CommandLine -like '*worker.cjs*') {
                    $sample = @{pid=[int]$child.ProcessId;parentPid=[int]$child.ParentProcessId;executable=[string]$child.ExecutablePath;commandLine=[string]$child.CommandLine}
                    if ($null -eq $node) { $node = $sample; $observations.Add($sample) }
                    if (-not [string]::Equals([IO.Path]::GetFullPath($sample.executable),[IO.Path]::GetFullPath($NodeExe),[StringComparison]::OrdinalIgnoreCase)) { throw 'CIM observed a host/unexpected Node executable.' }
                }
            }
            if (([DateTime]::UtcNow-$started).TotalSeconds -gt 7200) { throw "Native $Mode reception exceeded two hours." }
            Start-Sleep -Milliseconds 250
            $process.Refresh()
        }
        $process.WaitForExit()
        $stdout.GetAwaiter().GetResult() | Set-Content -LiteralPath (Join-Path $Output 'stdout.log') -Encoding utf8NoBOM
        $stderr.GetAwaiter().GetResult() | Set-Content -LiteralPath (Join-Path $Output 'stderr.log') -Encoding utf8NoBOM
        if ($null -eq $node) { throw 'No CIM observation of the owned packaged worker.' }
        $deadline = [DateTime]::UtcNow.AddSeconds(5)
        while ((Get-Process -Id $node.pid -ErrorAction SilentlyContinue) -and [DateTime]::UtcNow -lt $deadline) { Start-Sleep -Milliseconds 100 }
        $shutdown = -not [bool](Get-Process -Id $node.pid -ErrorAction SilentlyContinue)
        $receipt = @{executable=$Exe;exeSha256=(Hash $Exe);pid=$process.Id;nodeExecutable=$node.executable;nodePid=$node.pid;nodeParentPid=$node.parentPid;nodeSha256=(Hash $NodeExe);exitCode=$process.ExitCode;shutdown=$shutdown;argv=$Arguments;environmentNames=@($environment.Keys|Sort-Object);cim=@($observations.ToArray());durationSeconds=([DateTime]::UtcNow-$started).TotalSeconds;startedUtc=$started.ToString('o')}
        Write-Json $receipt (Join-Path $Output 'process.json')
        if ($process.ExitCode -ne 0 -or -not $shutdown) { throw "Native $Mode failed or its owned worker survived shutdown." }
        return $receipt
    } finally {
        if ($launched) {
            if (-not $process.HasExited) { $process.Kill($true); $process.WaitForExit() }
            $stdout.GetAwaiter().GetResult() | Set-Content -LiteralPath (Join-Path $Output 'stdout.log') -Encoding utf8NoBOM
            $stderr.GetAwaiter().GetResult() | Set-Content -LiteralPath (Join-Path $Output 'stderr.log') -Encoding utf8NoBOM
            if (-not (Test-Path -LiteralPath (Join-Path $Output 'process.json'))) {
                Write-Json @{executable=$Exe;pid=$process.Id;argv=$Arguments;exitCode=$process.ExitCode;shutdown=$shutdown;cim=@($observations.ToArray());environmentNames=@($environment.Keys|Sort-Object);incomplete=$true} (Join-Path $Output 'process.json')
            }
        }
        if ($null -ne $node -and -not $shutdown) {
            $owned = Get-CimInstance Win32_Process -Filter "ProcessId = $($node.pid)"
            if ($owned -and $owned.ParentProcessId -eq $node.parentPid -and $owned.ExecutablePath -eq $node.executable) { Stop-Process -Id $node.pid -Force }
        }
        $process.Dispose()
    }
}

try {
    $repo = Split-Path $PSScriptRoot
    $head = (& git -C $repo rev-parse HEAD).Trim()
    if ($LASTEXITCODE -ne 0 -or $head -cne $SourceCommit) { throw 'Receipt checkout does not match SourceCommit.' }
    $Report.sourceTree = (& git -C $repo rev-parse "${SourceCommit}^{tree}").Trim()
    if ($LASTEXITCODE -ne 0 -or $Report.sourceTree -cnotmatch '^[0-9a-f]{40}$') { throw 'Source Git tree cannot be resolved.' }
    $toolsPath = Join-Path (Split-Path $MesaRoot) 'toolchain-receipt.json'
    $tools = Read-Json $toolsPath
    if (-not [string]::Equals([IO.Path]::GetFullPath($tools.mesaRoot),$MesaRoot,[StringComparison]::OrdinalIgnoreCase)) { throw 'MesaRoot differs from the prepared toolchain.' }
    $Report.tools = @{receipt=$tools;receiptSha256=(Hash $toolsPath);powershell=$PSVersionTable.PSVersion.ToString();python=$Python}
    $archiveReceipt = Join-Path $EvidenceRoot 'archive.json'
    Python-Check @('extract','--zip',$PackageZip,'--source-commit',$SourceCommit,'--source-tree',$Report.sourceTree,'--destination',(Join-Path $EvidenceRoot 'Relocated QA with spaces'),'--receipt',$archiveReceipt)
    $archive = Read-Json $archiveReceipt
    $game = $archive.gameRoot; $exe = Join-Path $game 'OvalLegacy27.exe'; $nodeExe = Join-Path $game 'runtime/node.exe'
    $nodePin = $tools.pins['node-runtime'].sha256
    if ((Hash $tools.nodeExe) -cne $nodePin -or $archive.manifest.files['runtime/node.exe'].sha256 -cne $nodePin) { throw 'Packaged Node does not match the prepared official runtime pin.' }
    $Report.package = @{path=$PackageZip;shaBefore=$archive.zipSha256;shaAfter=$null;manifestSha256=$archive.manifestSha256;files=$archive.files}
    $manifestPath = Join-Path $game 'manifest-build.json'
    $mesaPath = Join-Path $EvidenceRoot 'mesa-qa.json'
    Python-Check @('mesa','--mesa-root',$MesaRoot,'--game-root',$game,'--manifest',$manifestPath,'--output',$mesaPath)
    $mesa = Read-Json $mesaPath
    $Report.mesa = $mesa; $Report.qaExtras = $mesa.extras
    $extrasPath = Join-Path $EvidenceRoot 'qa-extras.json'; Write-Json $mesa.extras $extrasPath
    $beforePath = Join-Path $EvidenceRoot 'manifest-before.json'
    Python-Check @('tree','--root',$game,'--manifest',$manifestPath,'--extras',$extrasPath,'--output',$beforePath)
    $Report.manifestBefore = Read-Json $beforePath
    $profile = Join-Path $EvidenceRoot 'private-profiles/PrototypeGodot'
    New-Item -ItemType Directory -Path $profile | Out-Null
    $fresh = Join-Path $EvidenceRoot 'fresh'
    $Report.process.fresh = Run-Game 'fresh' @('--headless','--audio-driver','Dummy','--max-fps','120') $profile $fresh $exe $nodeExe
    $Report.fresh = Read-Json (Join-Path $fresh 'report.json')
    $resume = Join-Path $EvidenceRoot 'resume'
    $Report.process.resume = Run-Game 'resume' @('--audio-driver','Dummy','--rendering-method','gl_compatibility','--windowed','--resolution','2560x1440','--max-fps','60','--script',$ResumeScript) $profile $resume $exe $nodeExe
    $Report.resume = Read-Json (Join-Path $resume 'report.json')
    $afterPath = Join-Path $EvidenceRoot 'manifest-after.json'
    Python-Check @('tree','--root',$game,'--manifest',$manifestPath,'--extras',$extrasPath,'--output',$afterPath)
    $Report.manifestAfter = Read-Json $afterPath
    $Report.package.shaAfter = Hash $PackageZip
    Write-Json $Report $ReportPath
    Python-Check @('finalize','--report',$ReportPath,'--source-commit',$SourceCommit,'--executable',$exe)
    $Report = Read-Json $ReportPath
    Write-Host "Native Windows receipt passed: $ReportPath"
} catch {
    $Report.passed = $false; $Report.failure = $_.Exception.ToString()
    foreach ($mode in @('fresh','resume')) {
        $partial = Join-Path (Join-Path $EvidenceRoot $mode) 'process.json'
        if (Test-Path -LiteralPath $partial) { $Report.process[$mode] = Read-Json $partial }
    }
    if ($null -ne $archive) { $Report.package.shaAfter = Hash $PackageZip }
    if ($null -ne $game -and $null -ne $extrasPath -and (Test-Path -LiteralPath $extrasPath)) {
        try {
            $afterPath = Join-Path $EvidenceRoot 'manifest-after.json'
            Python-Check @('tree','--root',$game,'--manifest',$manifestPath,'--extras',$extrasPath,'--output',$afterPath)
            $Report.manifestAfter = Read-Json $afterPath
        } catch { $Report.limits += "Post-failure tree verification also failed: $($_.Exception.Message)" }
    }
    Write-Json $Report $ReportPath
    throw
} finally {
    Write-Json $Report $ReportPath
}
