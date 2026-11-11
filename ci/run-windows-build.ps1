# One official build and native receipt. Run only on a standard Windows runner.
[CmdletBinding()]
param([Parameter(Mandatory=$true)][ValidatePattern('^[0-9a-f]{40}$')][string]$SourceCommit)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
if (-not $IsWindows) { throw 'Native Windows is required.' }
$root = Join-Path $env:RUNNER_TEMP 'oval-windows-delivery'
if (Test-Path -LiteralPath $root) { throw 'Refuse a previously used delivery workspace.' }
New-Item -ItemType Directory -Path $root | Out-Null
$tools = Join-Path $root 'tools'
$build = Join-Path $root 'official-build'
$evidence = Join-Path $root 'evidence'
$zip = Join-Path $build 'OvalLegacy27-PrototypeGodot-Windows-x64.zip'
foreach ($pair in @(@('root',$root),@('package',$zip),@('evidence',$evidence))) {
    "$($pair[0])=$($pair[1])" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
}
$head = (& git rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $head -cne $SourceCommit) { throw 'The checkout must be the exact source commit.' }
& python (Join-Path $PSScriptRoot 'prepare-windows-toolchain.py') --root $tools --config (Join-Path $PSScriptRoot 'windows-toolchain.json') *> (Join-Path $root 'prepare.log')
if ($LASTEXITCODE -ne 0) { Get-Content (Join-Path $root 'prepare.log'); throw 'Pinned Windows tool preparation failed.' }
$receipt = Get-Content (Join-Path $tools 'toolchain-receipt.json') -Raw | ConvertFrom-Json
& python (Join-Path (Split-Path $PSScriptRoot) 'scripts/build-godot-prototype.py') --sdk $receipt.sdkRoot --node $receipt.nodeExe --node-notices $receipt.nodeNotices --source-commit $SourceCommit --output $build *> (Join-Path $root 'build.log')
if ($LASTEXITCODE -ne 0) { Get-Content (Join-Path $root 'build.log'); throw 'The official Windows constructor failed.' }
& (Join-Path $PSScriptRoot 'windows-receipt.ps1') -PackageZip $zip -SourceCommit $SourceCommit -EvidenceRoot $evidence -MesaRoot $receipt.mesaRoot
if (-not (Test-Path (Join-Path $evidence 'windows-report.json'))) { throw 'Native receipt report is missing.' }
$qa = Get-Content (Join-Path $evidence 'windows-report.json') -Raw | ConvertFrom-Json
if ($qa.passed -ne $true) { throw 'The native Windows receipt is incomplete or failed.' }
