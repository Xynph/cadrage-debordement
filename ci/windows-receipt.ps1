# Native Windows receipt for the exact official ZIP. Requires PowerShell 7.
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$PackageZip,
    [Parameter(Mandatory=$true)][ValidatePattern('^[0-9a-f]{40}$')][string]$SourceCommit,
    [Parameter(Mandatory=$true)][string]$EvidenceRoot,
    [Parameter(Mandatory=$true)][string]$MesaRoot,
    [switch]$GraphicsSmoke
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
$ReportPath = Join-Path $EvidenceRoot 'windows-report.json'
$Report = [ordered]@{schema='oval-windows-receipt-v1';passed=$false;proof='native-windows';platform='Windows';sourceCommit=$SourceCommit;sourceTree='';process=@{};limits=@();failure=$null}
$game = $null; $archive = $null; $extrasPath = $null; $manifestPath = $null

function Read-Json([string]$Path) { return Get-Content -LiteralPath $Path -Raw -Encoding utf8 | ConvertFrom-Json -AsHashtable }
function Write-Json($Value,[string]$Path) { $Value | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $Path -Encoding utf8NoBOM }
function Hash([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function Set-QA-Mode([string]$Game,[ValidateSet('graphics','resume')][string]$Mode,[hashtable]$Extras) {
    $path = Join-Path $Game 'override.cfg'
    if (Test-Path -LiteralPath $path) {
        if (-not $Extras.ContainsKey('override.cfg') -or (Hash $path) -cne $Extras['override.cfg'].sha256) { throw 'Refuse an undeclared or modified QA override.cfg.' }
    }
    $class = if ($Mode -eq 'graphics') { 'WindowsGraphicsSmoke' } else { 'WindowsReceiptResume' }
    $config = "[application]`nrun/main_loop_type=`"$class`"`nrun/main_scene=`"res://windows_qa/entry.tscn`"`n"
    [IO.File]::WriteAllText($path,$config,[Text.UTF8Encoding]::new($false))
    $Extras['override.cfg'] = @{sha256=(Hash $path);bytes=(Get-Item -LiteralPath $path).Length;source='Explicit QA-only embedded main loop selection'}
}
function Read-Driver-Ack([string]$Path,[string]$Mode,[int]$ExpectedPid,[string]$Exe,[string]$CareerProfile) {
    $ack = Read-Json $Path
    $expectedMode = if ($Mode -eq 'graphics') { 'graphics-smoke' } else { 'resume' }
    $chain = @('res://windows_qa/windows-resume.gd')
    if ($Mode -eq 'graphics') { $chain = @('res://windows_qa/windows-graphics-smoke.gd') + $chain }
    foreach ($key in @('schema','mode','pid','executable','data_dir','exported','entry_scene','script_chain')) {
        if (-not $ack.ContainsKey($key)) { throw "Embedded driver ACK omitted $key." }
    }
    $identity = $ack.schema -ceq 'oval-windows-driver-v1' -and $ack.mode -ceq $expectedMode -and $ack.pid -eq $ExpectedPid -and
        $ack.exported -is [bool] -and $ack.exported -and $ack.entry_scene -ceq 'res://windows_qa/entry.tscn' -and
        ($ack.script_chain -join "`n") -ceq ($chain -join "`n") -and
        [string]::Equals([IO.Path]::GetFullPath($ack.executable),[IO.Path]::GetFullPath($Exe),[StringComparison]::OrdinalIgnoreCase) -and
        [string]::Equals([IO.Path]::GetFullPath($ack.data_dir),[IO.Path]::GetFullPath($CareerProfile),[StringComparison]::OrdinalIgnoreCase)
    if (-not $identity) { throw 'Embedded driver ACK has an unexpected mode, script, entry, export or process/profile identity.' }
    return $ack
}
function Read-Game-Log([string]$Path) {
    $stream = [IO.FileStream]::new($Path,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite)
    $reader = [IO.StreamReader]::new($stream)
    try { return $reader.ReadToEnd() } finally { $reader.Dispose() }
}
function Python-Check([string[]]$Arguments) {
    & $Python $Verifier @Arguments
    if ($LASTEXITCODE -ne 0) { throw "Windows package validator failed: $($Arguments[0])" }
}
function Game-Environment([string]$Mode,[string]$CareerProfile,[string]$Output) {
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
        CD_GODOT_DATA_DIR=$CareerProfile; CD_GODOT_SELF_TEST=$(if($Mode -eq 'fresh'){'1'}else{'0'});
        CD_GODOT_QA_CAPTURES=$Output; CD_GODOT_RESUME_OUTPUT=$Output; QA_RESOLUTION='2560x1440';
        CD_GODOT_FRESH_REPORT=(Join-Path $EvidenceRoot 'fresh/report.json');
        CD_GODOT_SEED='13'; CD_GODOT_STARTUP_TRACE='1';
        GALLIUM_DRIVER='llvmpipe'
    }
}
function Run-Game([string]$Mode,[string[]]$Arguments,[string]$CareerProfile,[string]$Output,[string]$Exe,[string]$NodeExe,[int]$TimeoutSeconds=7200,[int]$AckTimeoutSeconds=15) {
    New-Item -ItemType Directory -Path $Output | Out-Null
    $info = [Diagnostics.ProcessStartInfo]::new()
    $info.FileName = $Exe; $info.WorkingDirectory = Split-Path $Exe
    $info.UseShellExecute = $false; $info.RedirectStandardOutput = $true; $info.RedirectStandardError = $true
    $info.Environment.Clear()
    $environment = Game-Environment $Mode $CareerProfile $Output
    foreach ($item in $environment.GetEnumerator()) { $info.Environment[$item.Key] = [string]$item.Value }
    foreach ($argument in $Arguments) { $info.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::new(); $process.StartInfo = $info
    $node = $null; $observations = [Collections.Generic.List[object]]::new(); $shutdown = $false; $launched = $false
    $started = [DateTime]::UtcNow
    $stdoutPath = Join-Path $Output 'stdout.log'; $stderrPath = Join-Path $Output 'stderr.log'
    $stdoutFile = $null; $stderrFile = $null; $stdout = $null; $stderr = $null
    $lastLogCheck = $started; $lastHeartbeat = $started
    $runtimeError = '(?m)^(?:\x1b\[[0-9;]*m)*(?:SCRIPT ERROR:|ERROR:)|Parse Error:'
    $loadedModules = @{}; $moduleError = $null
    $needsAck = $Mode -in @('graphics','resume'); $driverAck = $null
    $ackPath = Join-Path $Output 'driver-ack.json'
    try {
        # Stream the complete bytes to disk while the EXE runs. A script error
        # must not leave a silent two-hour loop or disappear behind passed=true.
        $stdoutFile = [IO.FileStream]::new($stdoutPath,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::ReadWrite,1,[IO.FileOptions]::Asynchronous)
        $stderrFile = [IO.FileStream]::new($stderrPath,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::ReadWrite,1,[IO.FileOptions]::Asynchronous)
        if (-not $process.Start()) { throw 'Exported EXE did not start.' }
        $launched = $true
        $stdout = $process.StandardOutput.BaseStream.CopyToAsync($stdoutFile); $stderr = $process.StandardError.BaseStream.CopyToAsync($stderrFile)
        Write-Host "::notice title=Windows process ${Mode}::Started $([IO.Path]::GetFileName($Exe)), PID $($process.Id); complete logs are streaming to disk."
        while (-not $process.HasExited) {
            if ($needsAck -and $null -eq $driverAck) {
                if (Test-Path -LiteralPath $ackPath) { $driverAck = Read-Driver-Ack $ackPath $Mode $process.Id $Exe $CareerProfile }
                elseif (([DateTime]::UtcNow-$started).TotalSeconds -gt $AckTimeoutSeconds) { throw "Embedded driver ACK absent after ${AckTimeoutSeconds}s; the requested QA main loop did not acknowledge startup." }
            }
            if ($IsWindows) {
                try {
                    foreach ($module in @($process.Modules)) {
                        if ($module.ModuleName -match '^(opengl32|libgallium_wgl|libEGL.*|libGLES.*|d3d11|dxgi|d3d10warp)\.dll$' -and -not $loadedModules.ContainsKey($module.ModuleName)) {
                            $loadedModules[$module.ModuleName] = @{name=$module.ModuleName;path=$module.FileName;sha256=(Hash $module.FileName)}
                            Write-Json @{modules=@($loadedModules.Values);error=$moduleError} (Join-Path $Output 'loaded-modules.json')
                        }
                    }
                } catch { $moduleError = $_.Exception.Message }
            }
            foreach ($child in @(Get-CimInstance Win32_Process -Filter "ParentProcessId = $($process.Id)")) {
                if ($child.Name -ieq 'node.exe' -and $child.CommandLine -like '*worker.cjs*') {
                    $sample = @{pid=[int]$child.ProcessId;parentPid=[int]$child.ParentProcessId;executable=[string]$child.ExecutablePath;commandLine=[string]$child.CommandLine}
                    if ($null -eq $node) { $node = $sample; $observations.Add($sample) }
                    if (-not [string]::Equals([IO.Path]::GetFullPath($sample.executable),[IO.Path]::GetFullPath($NodeExe),[StringComparison]::OrdinalIgnoreCase)) { throw 'CIM observed a host/unexpected Node executable.' }
                }
            }
            if (([DateTime]::UtcNow-$lastLogCheck).TotalSeconds -ge 1) {
                foreach ($log in @($stdoutPath,$stderrPath)) {
                    if ((Read-Game-Log $log) -match $runtimeError) { throw "Godot runtime/script error during native $Mode; inspect the complete captured logs." }
                }
                $lastLogCheck = [DateTime]::UtcNow
            }
            if (([DateTime]::UtcNow-$lastHeartbeat).TotalSeconds -ge 300) {
                Write-Host "::notice title=Windows process ${Mode}::Still running; elapsed $([int]([DateTime]::UtcNow-$started).TotalSeconds)s; worker identity observed=$($null -ne $node)."
                $lastHeartbeat = [DateTime]::UtcNow
            }
            if (([DateTime]::UtcNow-$started).TotalSeconds -gt $TimeoutSeconds) { throw "Native $Mode exceeded its bounded ${TimeoutSeconds}s deadline." }
            Start-Sleep -Milliseconds 250
            $process.Refresh()
        }
        $process.WaitForExit()
        [void]$stdout.GetAwaiter().GetResult(); [void]$stderr.GetAwaiter().GetResult()
        $stdoutFile.Dispose(); $stderrFile.Dispose()
        foreach ($log in @($stdoutPath,$stderrPath)) {
            if ((Read-Game-Log $log) -match $runtimeError) { throw "Godot runtime/script error in native $Mode output." }
        }
        if ($needsAck -and $null -eq $driverAck) {
            if (-not (Test-Path -LiteralPath $ackPath)) { throw 'Embedded driver ACK absent when the EXE exited.' }
            $driverAck = Read-Driver-Ack $ackPath $Mode $process.Id $Exe $CareerProfile
        }
        if ($null -eq $node) { throw 'No CIM observation of the owned packaged worker.' }
        $deadline = [DateTime]::UtcNow.AddSeconds(5)
        while ((Get-Process -Id $node.pid -ErrorAction SilentlyContinue) -and [DateTime]::UtcNow -lt $deadline) { Start-Sleep -Milliseconds 100 }
        $shutdown = -not [bool](Get-Process -Id $node.pid -ErrorAction SilentlyContinue)
        $receipt = @{executable=$Exe;exeSha256=(Hash $Exe);pid=$process.Id;nodeExecutable=$node.executable;nodePid=$node.pid;nodeParentPid=$node.parentPid;nodeSha256=(Hash $NodeExe);exitCode=$process.ExitCode;shutdown=$shutdown;argv=$Arguments;environmentNames=@($environment.Keys|Sort-Object);systemRoot=$environment.SystemRoot;cim=@($observations.ToArray());durationSeconds=([DateTime]::UtcNow-$started).TotalSeconds;startedUtc=$started.ToString('o');loadedModules=@($loadedModules.Values);moduleError=$moduleError;driverAck=$driverAck}
        Write-Json $receipt (Join-Path $Output 'process.json')
        if ($process.ExitCode -ne 0 -or -not $shutdown) { throw "Native $Mode failed or its owned worker survived shutdown." }
        return $receipt
    } finally {
        try {
            if ($launched) {
                if (-not $process.HasExited) { $process.Kill($true); $process.WaitForExit() }
                if ($null -ne $stdout) { [void]$stdout.GetAwaiter().GetResult() }
                if ($null -ne $stderr) { [void]$stderr.GetAwaiter().GetResult() }
                if (-not (Test-Path -LiteralPath (Join-Path $Output 'process.json'))) {
                    Write-Json @{executable=$Exe;pid=$process.Id;argv=$Arguments;exitCode=$process.ExitCode;shutdown=$shutdown;cim=@($observations.ToArray());environmentNames=@($environment.Keys|Sort-Object);systemRoot=$environment.SystemRoot;driverAck=$driverAck;incomplete=$true} (Join-Path $Output 'process.json')
                }
            }
        } finally {
            try { Write-Json @{modules=@($loadedModules.Values);error=$moduleError} (Join-Path $Output 'loaded-modules.json') } catch { $moduleError = $_.Exception.Message }
            if ($null -ne $stdoutFile) { $stdoutFile.Dispose() }
            if ($null -ne $stderrFile) { $stderrFile.Dispose() }
            if ($null -ne $node -and -not $shutdown) {
                $owned = Get-CimInstance Win32_Process -Filter "ProcessId = $($node.pid)"
                if ($owned -and $owned.ParentProcessId -eq $node.parentPid -and $owned.ExecutablePath -eq $node.executable) { Stop-Process -Id $node.pid -Force }
            }
            $process.Dispose()
        }
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
    if ($GraphicsSmoke) {
        $Report.scope = 'graphics-smoke-only'
        $Report.attempts = @()
        $Report.qaExtras = @{}
        Set-QA-Mode $game 'graphics' $Report.qaExtras
        $extrasPath = Join-Path $EvidenceRoot 'qa-extras.json'
        Write-Json $Report.qaExtras $extrasPath
        foreach ($variant in @('angle-clean','mesa-native','mesa-local')) {
            if ($variant -eq 'mesa-native') {
                $mesaPath = Join-Path $EvidenceRoot 'mesa-qa.json'
                Python-Check @('mesa','--mesa-root',$MesaRoot,'--game-root',$game,'--manifest',$manifestPath,'--output',$mesaPath)
                $Report.mesa = Read-Json $mesaPath
                foreach ($extra in $Report.mesa.extras.GetEnumerator()) { $Report.qaExtras[$extra.Key] = $extra.Value }
            }
            if ($variant -eq 'mesa-local') {
                $marker = Join-Path $game 'OvalLegacy27.exe.local'
                if (Test-Path -LiteralPath $marker) { throw 'QA marker cannot overwrite a game file.' }
                [IO.File]::WriteAllBytes($marker,[Text.Encoding]::ASCII.GetBytes("dummy`r`n"))
                $Report.qaExtras['OvalLegacy27.exe.local'] = @{sha256=(Hash $marker);bytes=(Get-Item $marker).Length;source='Documented Mesa per-app QA marker'}
            }
            Write-Json $Report.qaExtras $extrasPath
            $output = Join-Path $EvidenceRoot $variant
            $driver = if ($variant -eq 'angle-clean') { 'opengl3_angle' } else { 'opengl3' }
            try {
                $processReceipt = Run-Game 'graphics' @('--verbose','--audio-driver','Dummy','--rendering-method','gl_compatibility','--rendering-driver',$driver,'--windowed','--resolution','2560x1440','--disable-vsync','--max-fps','10') (Join-Path $EvidenceRoot "profiles/$variant/PrototypeGodot") $output $exe $nodeExe 90
                Python-Check @('graphics','--report',(Join-Path $output 'report.json'),'--process',(Join-Path $output 'process.json'),'--manifest',$manifestPath,'--executable',$exe,'--driver',$driver)
                $Report.attempts += @{variant=$variant;passed=$true;report=(Read-Json (Join-Path $output 'report.json'));process=$processReceipt}
                $Report.passed = $true
                $Report.selectedGraphicsDriver = $driver
                break
            } catch {
                $Report.attempts += @{variant=$variant;passed=$false;failure=$_.Exception.ToString()}
                Write-Host "::warning title=Graphics smoke ${variant}::$($_.Exception.Message)"
            }
        }
        $afterPath = Join-Path $EvidenceRoot 'manifest-after.json'
        Python-Check @('tree','--root',$game,'--manifest',$manifestPath,'--extras',$extrasPath,'--output',$afterPath)
        $Report.manifestAfter = Read-Json $afterPath
        $Report.package.shaAfter = Hash $PackageZip
        if ($Report.package.shaAfter -cne $Report.package.shaBefore) { throw 'The original game ZIP changed.' }
        Write-Json $Report $ReportPath
        if (-not $Report.passed) { throw 'All bounded native graphics preflights failed; no graphical receipt.' }
        Write-Host '::notice title=Windows graphics smoke::Actual exported EXE, observed renderer, packaged Node and nonblank native 1440p PNG received. This is not a full-season receipt.'
        return
    }
    # Received by the real exported EXE in smoke 43003649410: static ANGLE,
    # system D3D11, VSync disabled and 10 fps. Keep this QA copy free of Mesa.
    $Report.selectedGraphicsDriver = 'opengl3_angle'
    $Report.qaExtras = @{}
    Set-QA-Mode $game 'resume' $Report.qaExtras
    $extrasPath = Join-Path $EvidenceRoot 'qa-extras.json'; Write-Json $Report.qaExtras $extrasPath
    $beforePath = Join-Path $EvidenceRoot 'manifest-before.json'
    Python-Check @('tree','--root',$game,'--manifest',$manifestPath,'--extras',$extrasPath,'--output',$beforePath)
    $Report.manifestBefore = Read-Json $beforePath
    $CareerProfile = Join-Path $EvidenceRoot 'private-profiles/PrototypeGodot'
    New-Item -ItemType Directory -Path $CareerProfile | Out-Null
    $fresh = Join-Path $EvidenceRoot 'fresh'
    $Report.process.fresh = Run-Game 'fresh' @('--headless','--audio-driver','Dummy','--max-fps','120') $CareerProfile $fresh $exe $nodeExe
    $Report.fresh = Read-Json (Join-Path $fresh 'report.json')
    $resume = Join-Path $EvidenceRoot 'resume'
    $Report.process.resume = Run-Game 'resume' @('--audio-driver','Dummy','--rendering-method','gl_compatibility','--rendering-driver',$Report.selectedGraphicsDriver,'--windowed','--resolution','2560x1440','--disable-vsync','--max-fps','10') $CareerProfile $resume $exe $nodeExe
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
