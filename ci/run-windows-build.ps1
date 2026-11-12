# One official build and native receipt. Run only on a standard Windows runner.
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][ValidatePattern('^[0-9a-f]{40}$')][string]$SourceCommit,
    [switch]$GraphicsSmoke,
    [ValidateNotNullOrEmpty()][string]$HardwareAnimations
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
if (-not $IsWindows) { throw 'Native Windows is required.' }
if ($GraphicsSmoke -and $HardwareAnimations) { throw 'Select only one receipt mode.' }
$root = Join-Path $env:RUNNER_TEMP 'oval-windows-delivery'
if ($HardwareAnimations) {
    $root = Join-Path $env:RUNNER_TEMP ('oval-windows-hardware-' + [guid]::NewGuid())
}
if (Test-Path -LiteralPath $root) { throw 'Refuse a previously used delivery workspace.' }
New-Item -ItemType Directory -Path $root | Out-Null
$tools = Join-Path $root 'tools'
$build = Join-Path $root 'official-build'
$evidence = Join-Path $root 'evidence'
$zip = Join-Path $build 'OvalLegacy27-PrototypeGodot-Windows-x64.zip'
foreach ($pair in @(@('root',$root),@('package',$zip),@('evidence',$evidence))) {
    "$($pair[0])=$($pair[1])" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
}
if ($HardwareAnimations) {
    $hardwareEvidence = Join-Path $evidence 'hardware-evidence'
    "hardware_evidence=$hardwareEvidence" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
}
$head = (& git rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $head -cne $SourceCommit) { throw 'The checkout must be the exact source commit.' }
$unit = Join-Path (Split-Path $PSScriptRoot) 'tests/windows-controller.ps1'
& (Get-Process -Id $PID).Path -NoLogo -NoProfile -NonInteractive -File $unit -Source (Join-Path $PSScriptRoot 'windows-receipt.ps1') *> (Join-Path $root 'controller-unit.log')
if ($LASTEXITCODE -ne 0) { Get-Content (Join-Path $root 'controller-unit.log'); throw 'The Windows receipt controller failed its fast diagnostics.' }
& python (Join-Path $PSScriptRoot 'prepare-windows-toolchain.py') --root $tools --config (Join-Path $PSScriptRoot 'windows-toolchain.json') *> (Join-Path $root 'prepare.log')
if ($LASTEXITCODE -ne 0) { Get-Content (Join-Path $root 'prepare.log'); throw 'Pinned Windows tool preparation failed.' }
$receipt = Get-Content (Join-Path $tools 'toolchain-receipt.json') -Raw | ConvertFrom-Json
Write-Host '::notice title=Windows tools::Pinned Godot, Node, Mesa and component notices verified.'
& python (Join-Path (Split-Path $PSScriptRoot) 'scripts/build-godot-prototype.py') --sdk $receipt.sdkRoot --node $receipt.nodeExe --node-notices $receipt.nodeNotices --source-commit $SourceCommit --output $build *> (Join-Path $root 'build.log')
if ($LASTEXITCODE -ne 0) { Get-Content (Join-Path $root 'build.log'); throw 'The official Windows constructor failed.' }
Write-Host '::notice title=Windows ZIP::Official archive constructed; beginning native EXE receipt.'
$arguments = @{PackageZip=$zip; SourceCommit=$SourceCommit; EvidenceRoot=$evidence; MesaRoot=$receipt.mesaRoot; GraphicsSmoke=$GraphicsSmoke}
if ($HardwareAnimations) { $arguments.HardwareAnimations = $HardwareAnimations }
& (Join-Path $PSScriptRoot 'windows-receipt.ps1') @arguments
if (-not (Test-Path (Join-Path $evidence 'windows-report.json'))) { throw 'Native receipt report is missing.' }
$qa = Get-Content (Join-Path $evidence 'windows-report.json') -Raw | ConvertFrom-Json
if ($qa.passed -ne $true) { throw 'The native Windows receipt is incomplete or failed.' }
