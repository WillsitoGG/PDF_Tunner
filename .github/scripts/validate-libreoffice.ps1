[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$PortableRoot,
    [Parameter(Mandatory = $true)][string]$LibreOfficeVersion,
    [Parameter(Mandatory = $true)][ValidatePattern('^[0-9a-fA-F]{64}$')][string]$LibreOfficeMsiSha256,
    [string]$BackendBaseUrl,
    [string]$BackendLogRoot,
    [switch]$RequireRelocation
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$core = Join-Path $PSScriptRoot 'validate-libreoffice-core.ps1'
$fonts = Join-Path $PSScriptRoot 'validate-conversion-fonts.ps1'
foreach ($requiredScript in @($core, $fonts)) {
    if (-not (Test-Path -LiteralPath $requiredScript -PathType Leaf)) {
        throw "Required PDF_Tunner LibreOffice validation script is missing: $requiredScript"
    }
}

$coreParams = @{}
foreach ($key in $PSBoundParameters.Keys) { $coreParams[$key] = $PSBoundParameters[$key] }
& $core @coreParams
& $fonts `
    -PortableRoot $PortableRoot `
    -BackendBaseUrl $BackendBaseUrl `
    -BackendLogRoot $BackendLogRoot `
    -RequireRelocation:$RequireRelocation
