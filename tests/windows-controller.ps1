# Fast controller diagnostics only. The child is PowerShell, not the game.
# CIM is mocked inside this separate test process; no native game proof is made.
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$Source)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$tokens = $null; $parseErrors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile($Source,[ref]$tokens,[ref]$parseErrors)
if ($parseErrors.Count) { throw 'Controller source failed to parse.' }
foreach ($definition in $ast.FindAll({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst]},$true)) {
    Invoke-Expression $definition.Extent.Text
}
$EvidenceRoot = Join-Path ([IO.Path]::GetTempPath()) ('oval-controller-unit-'+[guid]::NewGuid())
New-Item -ItemType Directory -Path $EvidenceRoot | Out-Null
if (-not $env:SystemRoot) { $env:SystemRoot = Join-Path $EvidenceRoot 'system' }
$env:GITHUB_TOKEN = 'UNIT_SENTINEL_NOT_A_CREDENTIAL'
$childExe = (Get-Process -Id $PID).Path
$script:mockWorker = $false
function Get-CimInstance {
    param([string]$ClassName,[string]$Filter)
    if ($script:mockWorker -and $Filter -match '^ParentProcessId = ([0-9]+)$') {
        [pscustomobject]@{Name='node.exe';CommandLine='unit-worker.cjs';ProcessId=99999998;ParentProcessId=[int]$Matches[1];ExecutablePath=$null}
        return [pscustomobject]@{Name='node.exe';CommandLine='unit-worker.cjs';ProcessId=99999999;ParentProcessId=[int]$Matches[1];ExecutablePath=$childExe}
    }
    return @()
}
try {
    $qaGame = Join-Path $EvidenceRoot 'Relocated QA with spaces'
    New-Item -ItemType Directory -Path $qaGame | Out-Null
    $qaExtras = @{}
    Set-QA-Mode $qaGame 'resume' $qaExtras
    $overrideHash = Hash (Join-Path $qaGame 'override.cfg')
    Set-QA-Mode $qaGame 'resume' $qaExtras
    if ((Hash (Join-Path $qaGame 'override.cfg')) -cne $overrideHash -or $qaExtras['override.cfg'].sha256 -cne $overrideHash) { throw 'Stable QA override/hash changed.' }
    $config = Get-Content -LiteralPath (Join-Path $qaGame 'override.cfg') -Raw
    if ($config -notmatch 'run/main_loop_type="WindowsReceiptResume"' -or $config -notmatch 'run/main_scene="res://windows_qa/entry.tscn"') { throw 'QA override did not select the embedded entry.' }
    Add-Content -LiteralPath (Join-Path $qaGame 'override.cfg') -Value 'unexpected-change'
    try { Set-QA-Mode $qaGame 'graphics' $qaExtras; throw 'A modified override was accepted.' } catch { if ($_.Exception.Message -notlike '*undeclared or modified*') { throw } }
    $script:mockWorker = $true
    $output = Join-Path $EvidenceRoot 'shape'
    $body = '[Console]::WriteLine([Environment]::GetEnvironmentVariable("GITHUB_TOKEN")); [Console]::WriteLine("UNIT_CAPTURE_MARKER"); Start-Sleep -Milliseconds 1500'
    $record = Run-Game 'fresh' @('-NoLogo','-NoProfile','-NonInteractive','-Command',$body) (Join-Path $EvidenceRoot 'profile') $output $childExe $childExe
    if ($record -isnot [Collections.IDictionary]) { throw 'Async task results polluted the process receipt: exactly one dictionary required.' }
    if ($record.exitCode -ne 0 -or -not $record.shutdown) { throw 'Diagnostic process did not shut down cleanly.' }
    if ($record.systemRoot -cne $env:SystemRoot) { throw 'Process receipt omitted its actual Windows system module root.' }
    $captured = Get-Content -LiteralPath (Join-Path $output 'stdout.log') -Raw
    if ($captured -notmatch 'UNIT_CAPTURE_MARKER' -or $captured -match 'UNIT_SENTINEL') { throw 'Captured output is incomplete or the child inherited a forbidden token.' }
    Write-Output 'Controller unit: one receipt dictionary, complete bytes, no token inheritance.'

    $ackBody = @'
$ack = @{schema='oval-windows-driver-v1';mode='graphics-smoke';pid=$PID;executable=(Get-Process -Id $PID).Path;data_dir=$env:CD_GODOT_DATA_DIR;exported=$true;entry_scene='res://windows_qa/entry.tscn';script_chain=@('res://windows_qa/windows-graphics-smoke.gd','res://windows_qa/windows-resume.gd')}
$ack | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $env:CD_GODOT_RESUME_OUTPUT 'driver-ack.json.tmp')
Move-Item (Join-Path $env:CD_GODOT_RESUME_OUTPUT 'driver-ack.json.tmp') (Join-Path $env:CD_GODOT_RESUME_OUTPUT 'driver-ack.json')
Start-Sleep -Milliseconds 1500
'@
    foreach ($case in @('mode','pid','executable','script','profile','editor')) {
        $body = switch ($case) {
            'mode' { $ackBody.Replace("mode='graphics-smoke'", "mode='resume'") }
            'pid' { $ackBody.Replace('pid=$PID', 'pid=99999998') }
            'executable' { $ackBody.Replace('executable=(Get-Process -Id $PID).Path', "executable='C:/host/editor.exe'") }
            'script' { $ackBody.Replace('res://windows_qa/windows-graphics-smoke.gd', 'C:/external-driver.gd') }
            'profile' { $ackBody.Replace('data_dir=$env:CD_GODOT_DATA_DIR', "data_dir='C:/wrong-profile'") }
            'editor' { $ackBody.Replace('exported=$true', 'exported=$false') }
        }
        try {
            $null = Run-Game 'graphics' @('-NoLogo','-NoProfile','-NonInteractive','-Command',$body) (Join-Path $EvidenceRoot 'profile') (Join-Path $EvidenceRoot "ack-$case") $childExe $childExe 6
            throw 'An invalid driver ACK was accepted.'
        } catch {
            if ($_.Exception.Message -notlike '*driver ACK*' -or $_.Exception.Message -like '*was accepted*') { throw }
        }
    }
    $record = Run-Game 'graphics' @('-NoLogo','-NoProfile','-NonInteractive','-Command',$ackBody) (Join-Path $EvidenceRoot 'profile') (Join-Path $EvidenceRoot 'ack-valid') $childExe $childExe 6
    if ($record.driverAck.mode -ne 'graphics-smoke' -or $record.driverAck.pid -ne $record.pid) { throw 'Verified driver ACK absent from process receipt.' }
    $started = [DateTime]::UtcNow
    try {
        $null = Run-Game 'graphics' @('-NoLogo','-NoProfile','-NonInteractive','-Command','Start-Sleep -Seconds 30') (Join-Path $EvidenceRoot 'profile') (Join-Path $EvidenceRoot 'ack-absent') $childExe $childExe 6 -AckTimeoutSeconds 1
        throw 'A missing driver ACK was accepted.'
    } catch {
        if ($_.Exception.Message -notlike '*driver ACK*' -or $_.Exception.Message -like '*was accepted*') { throw }
    }
    if (([DateTime]::UtcNow-$started).TotalSeconds -gt 5) { throw 'Absent driver did not fail promptly.' }
    Write-Output 'Controller unit: absent/mismatched ACK refused; exact embedded driver identity retained.'

    $script:mockWorker = $false
    foreach ($case in @('exit-zero-error','error-before-stall')) {
        $output = Join-Path $EvidenceRoot $case
        $body = '[Console]::Error.WriteLine("SCRIPT ERROR: synthetic controller unit only")'
        if ($case -eq 'error-before-stall') { $body += '; Start-Sleep -Seconds 30' }
        $started = [DateTime]::UtcNow
        try {
            $null = Run-Game 'fresh' @('-NoLogo','-NoProfile','-NonInteractive','-Command',$body) (Join-Path $EvidenceRoot 'profile') $output $childExe $childExe
            throw 'A runtime error was accepted.'
        } catch {
            if ($_.Exception.Message -notlike '*Godot runtime/script error*') { throw }
        }
        if (([DateTime]::UtcNow-$started).TotalSeconds -gt 15) { throw 'Script error did not stop its process promptly.' }
        if ((Get-Content -LiteralPath (Join-Path $output 'stderr.log') -Raw) -notmatch 'SCRIPT ERROR: synthetic controller unit only') { throw 'Runtime-error output was lost.' }
        $record = Read-Json (Join-Path $output 'process.json')
        if (-not $record.incomplete -or (Get-Process -Id $record.pid -ErrorAction SilentlyContinue)) { throw 'A failed diagnostic was promoted or its process survived.' }
        Write-Output "Controller unit: $case refused, complete bytes retained, process stopped."
    }
    Write-Output 'Controller diagnostics passed. No game EXE or native Windows recipe is represented by these tests.'
} finally {
    Remove-Item -LiteralPath $EvidenceRoot -Recurse -Force
}
