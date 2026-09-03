[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$PortableRoot,
    [Parameter(Mandatory = $true)][string]$PythonVersion,
    [Parameter(Mandatory = $true)][string]$PythonDownloadUrl,
    [Parameter(Mandatory = $true)][ValidatePattern('^[0-9a-fA-F]{64}$')][string]$PythonSha256,
    [Parameter(Mandatory = $true)][string]$OcrMyPdfVersion,
    [Parameter(Mandatory = $true)][ValidatePattern('^[0-9a-fA-F]{64}$')][string]$OcrMyPdfWheelSha256,
    [Parameter(Mandatory = $true)][string]$NumPyVersion,
    [Parameter(Mandatory = $true)][ValidatePattern('^[0-9a-fA-F]{64}$')][string]$NumPyWheelSha256,
    [Parameter(Mandatory = $true)][string]$DependencyLockPath,
    [Parameter(Mandatory = $true)][ValidatePattern('^[0-9a-fA-F]{64}$')][string]$DependencyLockSha256,
    [Parameter(Mandatory = $true)][string]$LauncherSource
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$core = Join-Path $PSScriptRoot 'prepare-ocrmypdf-core.ps1'
$aux = Join-Path $PSScriptRoot 'prepare-ocr-aux.ps1'
foreach ($requiredScript in @($core, $aux)) {
    if (-not (Test-Path -LiteralPath $requiredScript -PathType Leaf)) {
        throw "Required PDF_Tunner OCR preparation script is missing: $requiredScript"
    }
}

$coreParams = @{}
foreach ($key in $PSBoundParameters.Keys) {
    $coreParams[$key] = $PSBoundParameters[$key]
}

& $core @coreParams
& $aux -PortableRoot $PortableRoot
