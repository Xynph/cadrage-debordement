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
        return [pscustomobject]@{Name='node.exe';CommandLine='unit-worker.cjs';ProcessId=99999999;ParentProcessId=[int]$Matches[1];ExecutablePath=$childExe}
    }
    return @()
}
try {
    $script:mockWorker = $true
    $output = Join-Path $EvidenceRoot 'shape'
    $body = '[Console]::WriteLine([Environment]::GetEnvironmentVariable("GITHUB_TOKEN")); [Console]::WriteLine("UNIT_CAPTURE_MARKER"); Start-Sleep -Milliseconds 1500'
    $record = Run-Game 'fresh' @('-NoLogo','-NoProfile','-NonInteractive','-Command',$body) (Join-Path $EvidenceRoot 'profile') $output $childExe $childExe
    if ($record -isnot [Collections.IDictionary]) { throw 'Async task results polluted the process receipt: exactly one dictionary required.' }
    if ($record.exitCode -ne 0 -or -not $record.shutdown) { throw 'Diagnostic process did not shut down cleanly.' }
    $captured = Get-Content -LiteralPath (Join-Path $output 'stdout.log') -Raw
    if ($captured -notmatch 'UNIT_CAPTURE_MARKER' -or $captured -match 'UNIT_SENTINEL') { throw 'Captured output is incomplete or the child inherited a forbidden token.' }
    Write-Output 'Controller unit: one receipt dictionary, complete bytes, no token inheritance.'

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
