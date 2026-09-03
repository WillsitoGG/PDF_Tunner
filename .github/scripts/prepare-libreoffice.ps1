[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$PortableRoot,
    [Parameter(Mandatory = $true)][string]$LibreOfficeVersion,
    [Parameter(Mandatory = $true)][string]$LibreOfficeMsiUrl,
    [Parameter(Mandatory = $true)][ValidatePattern('^[0-9a-fA-F]{64}$')][string]$LibreOfficeMsiSha256,
    [Parameter(Mandatory = $true)][string]$LauncherSource
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$core = Join-Path $PSScriptRoot 'prepare-libreoffice-core.ps1'
$fonts = Join-Path $PSScriptRoot 'prepare-conversion-fonts.ps1'
foreach ($requiredScript in @($core, $fonts)) {
    if (-not (Test-Path -LiteralPath $requiredScript -PathType Leaf)) {
        throw "Required PDF_Tunner LibreOffice preparation script is missing: $requiredScript"
    }
}

$coreParams = @{}
foreach ($key in $PSBoundParameters.Keys) { $coreParams[$key] = $PSBoundParameters[$key] }
& $core @coreParams
& $fonts -PortableRoot $PortableRoot
